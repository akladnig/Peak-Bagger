"""Installed, bounded single-flight MacBook refresh; never invoked by the app."""
import contextlib
import fcntl
import json
import os
import time
import uuid
import argparse
import hashlib
import plistlib
import sys
from pathlib import Path

from mapping_source import (SourceError, atomic_json, check_layout, read_json, utc,
    workspace_roots, require_uuid, check_record, COMPLETION_FIELDS, digest)
from mapping_replica import reject_links, Replica, completed


class CallUnknown(SourceError):
    """A dispatch/inspection failed without proof that remote/local work ended."""


class Controller:
    def __init__(self, base, *, remote, local=None, replica=None, transfer=None, clock=time.time):
        self.base = Path(base).resolve()
        check_layout(self.base, workspace_roots())
        self.base.mkdir(parents=True, exist_ok=True)
        self.remote = remote
        self.local = local
        self.replica = replica or Replica(self.base)
        self.transfer = transfer
        self.clock = clock
        self.path = self.base/'refresh'/'state.json'
        reject_links(self.path)
        self.path.parent.mkdir(exist_ok=True)

    def save(self, state):
        atomic_json(self.path, state)
        return state

    @contextlib.contextmanager
    def ownership(self):
        target = self.path.parent/'controller.lock'
        reject_links(target)
        with target.open('a+b') as stream:
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise SourceError('refresh busy; scheduled/maintainer/provisioning owner active') from error
            yield

    def tick(self):
        try:
            with self.ownership():
                return self._tick()
        except SourceError as error:
            if str(error).startswith('refresh busy;'):
                return dict(status='busy', diagnostic=str(error))
            raise

    def _tick(self):
        state = read_json(self.path) if self.path.exists() else dict(
            kind='mapping-refresh-state', schemaVersion=1, phase='prepare',
            sourceOperation=None, diagnostic=None)
        if state.get('kind') != 'mapping-refresh-state' or type(state.get('schemaVersion')) is not int or state['schemaVersion'] != 1:
            raise SourceError('unsupported refresh state; preserve data and inspect installed compatibility')
        if state.get('executingController') and state['executingController'] not in self.replica.controllers:
            raise SourceError('unsupported retained controller operation release; preserve its helpers/protection')
        state['executingController'] = self.replica.release_id
        try:
            phase = state['phase']
            state['diagnostic'] = None
            if phase in ('prepare', 'complete'):
                if self.transfer: self.transfer.pause()
                state = dict(kind='mapping-refresh-state', schemaVersion=1,
                    phase='prepare-wait', sourceOperation=str(uuid.uuid4()), diagnostic=None,
                    startedAtUtc=utc(),executingController=self.replica.release_id)
                self.save(state)  # Intent precedes a potentially ambiguous dispatch.
                state['sourceDispatch'] = self.remote('prepare', operation=state['sourceOperation'])
            elif phase in ('prepare-wait', 'capture-wait'):
                remote = phase == 'prepare-wait'
                call = self.remote if remote else self.local
                identity = state['sourceOperation' if remote else 'captureOperation']
                observation = call('status', target=identity)
                state['stageStatus'] = observation
                operation = observation['operation']
                alive = observation['supervisorOrChildOwnsPipeline']
                state['availability'] = ('owned-progress-or-inspect' if alive else 'ownership-ended-inspect-outcome')
                if operation:
                    if operation['operationId'] != identity:
                        raise SourceError('operation inspection identity mismatch; conflicting mutation blocked')
                    state['observedOperation'] = operation
                    state['progressAtUtc'] = operation.get('progressAtUtc')
                if not alive:
                    state['phase'] = 'prepare-reconcile' if remote else 'capture-reconcile'
                else:
                    from datetime import datetime
                    progress = state.get('progressAtUtc') or state['startedAtUtc']
                    age = self.clock()-datetime.fromisoformat(progress.replace('Z','+00:00')).timestamp()
                    if age >= 600:
                        state['diagnostic'] = 'no reported progress for 600 seconds; owner remains alive; inspect stage log/child CPU; no retry authorized'
            elif phase in ('prepare-reconcile', 'capture-reconcile'):
                remote = phase == 'prepare-reconcile'
                call = self.remote if remote else self.local
                identity = state['sourceOperation' if remote else 'captureOperation']
                observed = state.get('observedOperation')
                if observed and observed['state'] in ('running', 'outcome-unknown'):
                    call('reconcile', target=identity)
                outcome = call('reconcile-release', target=identity)
                if outcome['state'] != 'succeeded':
                    state.update(phase='prepare' if remote else 'capture', diagnostic='confirmed failed stage; safe retry on next tick')
                elif remote:
                    if not observed or not observed.get('generationId'):
                        raise SourceError('source succeeded without generation completion evidence')
                    state.update(phase='export', generationId=require_uuid(observed['generationId']))
                else:
                    self.replica.eligible(state['generationId'])
                    state['phase'] = 'receipt'
            elif phase == 'export':
                info = self.remote('export', generation=state['generationId'])
                completion = check_record(info['completion'], 'mapping-source-completion', COMPLETION_FIELDS)
                inventory = check_record(info['inventory'], 'mapping-integrity', {'generationId','files'})
                if completion['generationId'] != state['generationId'] or inventory['generationId'] != state['generationId'] or digest(inventory) != completion['inventorySha256'] or completion['sourcePreparerRelease'] not in self.replica.sources:
                    raise SourceError('unsupported/mismatched source completion inventory')
                state.update(phase='pin', export=info, transferOperation=str(uuid.uuid4()))
            elif phase == 'pin':
                # Idempotent durable source protection survives any controller exit.
                self.remote('transfer-pin', operation=state['transferOperation'], generation=state['generationId'])
                state['phase'] = 'transfer-start'
            elif phase == 'transfer-start':
                self.replica.audit_space(state['export']['inventory'], stage='refresh', operation_id=state['transferOperation'])
                state['cycle'] = self.transfer.start()
                state['phase'] = 'transfer'
            elif phase == 'transfer':
                status = self.transfer.observe(state['cycle'])
                previous = state.get('transferStatus')
                if previous != status:
                    state['transferProgressSeconds'] = self.clock()
                elif self.clock()-state.get('transferProgressSeconds',self.clock()) >= 600:
                    state['diagnostic'] = 'transfer no progress/unavailable for 600s; bounded polling continues; transfer protection and Mutagen progress retained'
                state['transferStatus'] = status
                if status['ready']:
                    completion, inventory, identity = completed(self.base/'incoming'/state['generationId'], self.replica.sources)
                    if completion != state['export']['completion'] or inventory != state['export']['inventory'] or identity[0] != state['export']['completionSha256']:
                        raise SourceError('completed transfer differs from the pinned source export')
                    state['phase'] = 'capture'
            elif phase == 'capture':
                generation = state['generationId']
                self.replica.cleanup()  # Prune only confirmed unowned failed captures.
                if (self.base/'eligibility'/f'{generation}.json').exists():
                    self.replica.eligible(generation)
                    state['phase'] = 'receipt'
                else:
                    state.update(phase='capture-wait', captureOperation=str(uuid.uuid4()), startedAtUtc=utc())
                    state.pop('observedOperation', None)
                    self.save(state)
                    state['captureDispatch'] = self.local('capture', operation=state['captureOperation'], generation=generation)
            elif phase == 'receipt':
                self.replica.acknowledge(state['generationId'], send=lambda receipt: self.remote('acknowledge', data=receipt))
                state['phase'] = 'release-transfer'
            elif phase == 'release-transfer':
                self.remote('transfer-release', operation=state['transferOperation'], generation=state['generationId'])
                state['phase'] = 'cleanup-local'
            elif phase == 'cleanup-local':
                state['cleanup'] = self.replica.cleanup()
                state['phase'] = 'cleanup-source'
            elif phase == 'cleanup-source':
                state['sourceCleanup'] = self.remote('cleanup')
                if self.transfer: self.transfer.pause()
                state.update(phase='complete', completedAtUtc=utc(), activation='eligible for next app launch; running app root unchanged')
            else:
                raise SourceError('unsupported refresh phase; conflicting mutation blocked: '+str(phase))
        except (SourceError, OSError) as error:
            state['diagnostic'] = f'stage={state["phase"]} operation={state.get("sourceOperation")} generation={state.get("generationId")} local={self.base}: {error}'
        state['observedAtUtc'] = utc()
        return self.save(state)


class LaunchAgent:
    label = 'com.peakbagger.mapping-runtime-replica'

    def __init__(self, agents, logs, config, *, process, uid=None):
        self.agents, self.logs = Path(agents), Path(logs)
        self.config, self.process = config, process
        self.uid = os.getuid() if uid is None else uid
        self.path = self.agents/(self.label+'.plist')

    def desired(self):
        return dict(Label=self.label, ProgramArguments=[self.config['python'],'-I',
            str(Path(self.config['installation'])/'mapping_release_launcher.py'),'run','--','controller','refresh'],
            RunAtLoad=True, StartInterval=60, ProcessType='Background',
            StandardOutPath=str(self.logs/'runner.stdout.log'), StandardErrorPath=str(self.logs/'runner.stderr.log'))

    def inspect(self):
        reject_links(self.path)
        if self.path.exists() and plistlib.loads(self.path.read_bytes()) != self.desired():
            raise SourceError('LaunchAgent schedule/program/path drift; preserve it and explicitly reconcile')
        target = f'gui/{self.uid}/{self.label}'
        try:
            output = self.process(['/bin/launchctl','print',target], timeout=10)
        except SourceError as error:
            # Only explicit not-found, never a timeout or arbitrary launchctl failure.
            if 'Could not find service' not in str(error) and 'not loaded' not in str(error): raise
            return dict(installed=self.path.exists(), loaded=False)
        if str(self.path) not in output or 'run interval = 60 seconds' not in output or any(
            operand not in output for operand in self.desired()['ProgramArguments'][:3]):
            raise SourceError('loaded LaunchAgent effective program/schedule drift')
        return dict(installed=self.path.exists(),loaded=True)

    def install(self):
        observed = self.inspect()
        self.agents.mkdir(parents=True,exist_ok=True)
        self.logs.mkdir(parents=True,exist_ok=True)
        if not observed['installed']:
            from mapping_source import sync_directory
            temporary = self.path.with_suffix('.new')
            reject_links(temporary)
            with temporary.open('xb') as stream:
                stream.write(plistlib.dumps(self.desired()))
                stream.flush(); os.fsync(stream.fileno())
            os.rename(temporary,self.path)
            sync_directory(self.agents)
        if not observed['loaded']:
            self.process(['/bin/launchctl','bootstrap',f'gui/{self.uid}',str(self.path)],timeout=10)
        return self.desired()


CONFIG_FIELDS = {'remotePython','remoteInstall','sourceBase','installation','python',
    'mutagen','mutagenSha256','incoming','sourceRelease','controllerRelease','enabled'}


def load_config(base):
    path = Path(base)/'refresh'/'config.json'
    reject_links(path)
    value = check_record(read_json(path),'mapping-runner-config',CONFIG_FIELDS)
    for key in ('remotePython','remoteInstall','sourceBase','installation','python','mutagen','incoming'):
        if not isinstance(value[key],str) or not Path(value[key]).is_absolute() or '\0' in value[key]:
            raise SourceError('runner configuration requires absolute non-secret paths: '+key)
        check_layout(Path(value[key]),workspace_roots())
    if value['incoming'] != str(Path(base)/'incoming'):
        raise SourceError('runner destination must be exactly incoming staging')
    if type(value['enabled']) is not bool: raise SourceError('invalid runner enabled value')
    require_uuid(value['sourceRelease']); require_uuid(value['controllerRelease'])
    if hashlib.sha256(Path(value['mutagen']).read_bytes()).hexdigest() != value['mutagenSha256']:
        raise SourceError('Mutagen executable drift; inspect dependency and explicitly reconfigure installed runner')
    return value


def main():
    from mapping_transport import InstalledCalls, Mutagen, process
    from mapping_releases import manifest
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base',type=Path,required=True)
    parser.add_argument('--release-id',required=True,type=require_uuid)
    parser.add_argument('--compatible-source-release',action='append',default=[])
    parser.add_argument('--compatible-controller-release',action='append',default=[])
    commands = parser.add_subparsers(dest='action',required=True)
    setup = commands.add_parser('setup')
    setup.add_argument('--remote-python',required=True)
    setup.add_argument('--remote-install',required=True)
    setup.add_argument('--mutagen',default='/opt/homebrew/bin/mutagen')
    setup.add_argument('--upgrade',action='store_true',help='explicit compatible release reselection; runner must already be paused')
    for name in ('refresh','provision','status','pause','resume'):
        commands.add_parser(name)
    args = parser.parse_args()
    release = Path(os.environ['MAPPING_INSTALLED_RELEASE'])
    installation = release.parent.parent
    value = manifest(release/'release.json')
    replica = Replica(args.base,release_id=args.release_id,
        compatible_sources=args.compatible_source_release,compatible_controllers=args.compatible_controller_release)
    base = replica.base
    config_path = base/'refresh'/'config.json'
    # MacBook must use local attached storage; mount inspection never contacts SMB.
    mounts = process(['/sbin/mount'],timeout=5)
    for line in mounts.splitlines():
        if ' (' not in line or ' on ' not in line: continue
        mount = line.split(' on ',1)[1].split(' (',1)[0]
        if ('smbfs' in line or 'nfs' in line) and (str(base)==mount or str(base).startswith(mount+'/')):
            raise SourceError('runner replica base must be local; network-backed runtime staging forbidden')
    support = Path.home()/'Library/Application Support/com.example.peakBagger'
    app_config = support/'mapping-runtime.json'
    reject_links(app_config)
    expected = read_json(app_config) if app_config.exists() else dict(schemaVersion=1,mode='replica',replicaBase=str(support/'MappingRuntimeReplica'))
    if expected != dict(schemaVersion=1,mode='replica',replicaBase=str(base)):
        raise SourceError('installed runner/app machine-local replica root drift; reconcile configuration before setup/refresh')
    shell = Controller(base,remote=lambda *_a,**_k: None,replica=replica)
    if args.action == 'setup':
        with shell.ownership():
            from mapping_releases import check_layout
            for path in (Path(args.remote_install),Path(args.remote_python),Path(args.mutagen)):
                check_layout(path,workspace_roots())
            remote = dict(remotePython=args.remote_python,remoteInstall=args.remote_install)
            described = InstalledCalls(remote)('describe')
            peer = described['manifest']
            if peer['role'] != 'source-preparer' or peer['releaseId'] not in replica.sources or args.release_id not in peer['controllerReleases']:
                raise SourceError('installed peer release incompatible; upgrade supported pair first')
            source_base = described['selected']['dataBase']
            check_layout(Path(source_base),workspace_roots())
            python = next(item['path'] for item in value['dependencies'] if Path(item['path']).name.startswith('python'))
            desired = dict(kind='mapping-runner-config',schemaVersion=1,remotePython=args.remote_python,
                remoteInstall=args.remote_install,sourceBase=source_base,installation=str(installation),
                python=python,mutagen=args.mutagen,mutagenSha256=hashlib.sha256(Path(args.mutagen).read_bytes()).hexdigest(),
                incoming=str(base/'incoming'),sourceRelease=peer['releaseId'],controllerRelease=args.release_id,enabled=True)
            if config_path.exists():
                config = load_config(base)
                if config != dict(desired,enabled=config['enabled']):
                    allowed = {'sourceRelease','controllerRelease'}
                    if not args.upgrade or config['enabled'] or any(config[key] != desired[key] for key in CONFIG_FIELDS-allowed-{'enabled'}):
                        raise SourceError('runner installation/release/configuration drift; pause and explicitly upgrade configuration')
                    desired['enabled'] = False
                else:
                    desired = config
            # Validate both existing intended installations before creating either.
            transport = Mutagen(desired)
            transport.inspect(optional=True)
            agent = LaunchAgent(Path.home()/'Library/LaunchAgents',base/'logs',desired,process=process)
            agent.inspect()
            atomic_json(config_path,desired)
            reject_links(base/'incoming'); (base/'incoming').mkdir(exist_ok=True)
            transport.setup()
            result = agent.install()
    else:
        config = load_config(base)
        if config['controllerRelease'] != args.release_id:
            raise SourceError('runner selected controller release drift; pause and use explicit controller upgrade')
        calls = InstalledCalls(config)
        transport = Mutagen(config)
        runner = Controller(base,remote=calls,local=lambda action,**kwargs: calls(action,remote=False,**kwargs),
            replica=replica,transfer=transport)
        if args.action in ('refresh','provision'):
            result = runner.tick() if config['enabled'] else dict(status='paused',diagnostic='runtime refresh paused independently of source handover')
        elif args.action in ('pause','resume'):
            with runner.ownership():
                config['enabled'] = args.action == 'resume'
                atomic_json(config_path,config)
                if args.action == 'pause': transport.pause()
                elif runner.path.exists() and read_json(runner.path)['phase'] == 'transfer':
                    transport.call('resume',transport.inspect()['identifier'])
                    transport.call('flush','--skip-wait',transport.inspect()['identifier'])
                result = dict(status='enabled' if config['enabled'] else 'paused')
        else:
            result = dict(configuration=config,refresh=read_json(runner.path) if runner.path.exists() else None,
                transfer=transport.inspect(),activation=read_json(base/'selection.json') if (base/'selection.json').exists() else None,
                agent=LaunchAgent(Path.home()/'Library/LaunchAgents',base/'logs',config,process=process).inspect(),
                installedController=args.release_id)
    print(json.dumps(result),flush=True)


if __name__ == '__main__':
    try: main()
    except Exception as error:
        print('refresh controller failed: '+str(error),file=sys.stderr,flush=True)
        sys.exit(1)
