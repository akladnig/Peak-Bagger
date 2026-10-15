"""Bounded installed SSH/Mutagen adapters; writes only incoming via Mutagen."""
import hashlib
import json
import os
import shlex
import subprocess
from pathlib import Path

from mapping_source import SourceError, decode_json
from mapping_controller import CallUnknown

SESSION = 'mapping-runtime-replica'


def process(arguments, *, input_text=None, timeout=30):
    try:
        result = subprocess.run(arguments, input=input_text, capture_output=True,
            text=True, timeout=timeout, stdin=None if input_text is not None else subprocess.DEVNULL)
    except subprocess.TimeoutExpired as error:
        raise CallUnknown(f'bounded call exceeded {timeout}s: {arguments[0]}; operation outcome unknown; inspect original identity') from error
    if result.returncode:
        raise CallUnknown(f'call failed ({result.returncode}): {arguments[0]}: {result.stderr[-4000:]}')
    if len(result.stdout) > 16*1024*1024:
        raise CallUnknown('bounded response exceeded 16 MiB; inspection unresolved')
    return result.stdout


class InstalledCalls:
    def __init__(self, config, *, process=process):
        self.config, self.process = config, process

    def __call__(self, action, *, operation=None, target=None, generation=None, data=None, remote=True):
        config = self.config
        if remote and action == 'prepare':
            described = self('describe')
            if described['selected']['dataBase'] != config['sourceBase'] or described['selected']['releaseId'] != config['sourceRelease']:
                raise SourceError('source installed release/root drift; preserve pipeline and explicitly upgrade runner configuration')
        python = config['remotePython' if remote else 'python']
        launcher = str(Path(config['remoteInstall' if remote else 'installation'])/'mapping_release_launcher.py')
        argv = [python, '-I', launcher]
        if action == 'describe':
            argv += ['describe']
        elif action == 'reconcile-release':
            argv += ['reconcile-release', target]
        else:
            argv += ['run']
            if operation and action in ('prepare','capture'): argv += ['--operation', operation]
            if target: argv += ['--target-operation', target]
            argv += ['--', action]
            if generation: argv.append(generation)
            if action == 'capture': argv.append('--transfer-complete')
            if action in ('transfer-pin', 'transfer-release'): argv += ['--transfer-operation', operation]
        if remote:
            argv = ['/usr/bin/ssh', '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
                '-o', 'ServerAliveInterval=5', '-o', 'ServerAliveCountMax=2', 'mini', shlex.join(argv)]
        raw = self.process(argv, input_text=json.dumps(data) if data is not None else None, timeout=30)
        return decode_json(raw)


def overlaps(a, b):
    return a == b or a.startswith(b.rstrip('/')+'/') or b.startswith(a.rstrip('/')+'/')


class Mutagen:
    def __init__(self, config, *, process=process, alpha=None, name=SESSION):
        self.config, self.process = config, process
        # Explicit construction seams only; installed CLI has no endpoint overrides.
        self.alpha = alpha or dict(protocol='ssh',host='mini',path=self.config['sourceBase']+'/prepared')
        self.name = name
        self.label = 'replica' if name == SESSION else name

    def call(self, *arguments):
        return self.process([self.config['mutagen'], 'sync', *arguments], timeout=30)

    def inspect(self, *, optional=False):
        alpha = self.alpha
        beta = dict(protocol='local', path=self.config['incoming'])
        sessions = decode_json(self.call('list', '--template', '{{json .}}'))
        matches = []
        for session in sessions:
            touching = False
            for side in ('alpha','beta'):
                actual = session[side]
                for expected in (alpha,beta):
                    same_transport = actual.get('protocol') == expected['protocol']
                    if same_transport and expected['protocol'] == 'ssh':
                        # Resolve SSH aliases to reject overlapping alternate names.
                        host = actual.get('host','')
                        if host != 'mini':
                            def identity(alias):
                                if not alias or alias.startswith('-'): raise SourceError('invalid session SSH alias')
                                lines = self.process(['/usr/bin/ssh','-G',alias], timeout=10).splitlines()
                                values = dict(line.split(' ',1) for line in lines if ' ' in line)
                                return tuple(values.get(key) for key in ('hostname','user','port'))
                            same_transport = identity(host) == identity('mini')
                    touching |= same_transport and overlaps(actual['path'], expected['path'])
            if touching or session.get('name') == self.name or session.get('labels',{}).get('mapping-runtime') == self.label:
                matches.append(session)
        if not matches and optional: return None
        if len(matches) != 1: raise SourceError('runtime session missing/duplicate/overlapping; inspect drift before creating or retrying')
        session = matches[0]
        ignores = dict(session.get('ignore',{}))
        ignores.setdefault('paths',[])
        if session.get('name') != self.name or session.get('labels',{}).get('mapping-runtime') != self.label or session.get('mode') != 'one-way-replica' or ignores != dict(paths=[], syntax='mutagen', vcs=False):
            raise SourceError('runtime Mutagen scope/mode/identity drift; session preserved')
        for side, expected in (('alpha',alpha), ('beta',beta)):
            actual = session[side]
            if any(actual.get(key,'') != value for key,value in expected.items()) or any(actual.get(key) for key in ('user','port','environment','parameters')):
                raise SourceError('runtime Mutagen effective endpoint drift: '+side)
            if any(actual.get(key) for key in ('ignore','mode','symlink','permissions','watch','compression')):
                raise SourceError('runtime Mutagen endpoint override drift: '+side)
        return session

    def setup(self):
        session = self.inspect(optional=True)
        if not session:
            alpha = self.alpha['path'] if self.alpha['protocol']=='local' else self.alpha['host']+':'+self.alpha['path']
            self.call('create', alpha, self.config['incoming'],
                '--paused', '--name', self.name, '--label', 'mapping-runtime='+self.label,
                '--no-global-configuration', '--mode', 'one-way-replica', '--ignore-syntax','mutagen','--no-ignore-vcs')
            session = self.inspect()
        return session

    def pause(self):
        self.call('pause', self.inspect()['identifier'])

    def start(self):
        session = self.inspect()
        cycle = session.get('successfulCycles',0)
        self.call('resume', session['identifier'])
        self.call('flush', '--skip-wait', session['identifier'])
        return cycle

    def observe(self, cycle):
        session = self.inspect()
        issues = []
        for key in ('lastError','conflicts','excludedConflicts'):
            if session.get(key): issues.append(key)
        for side in ('alpha','beta'):
            endpoint = session[side]
            if not endpoint.get('connected') or not endpoint.get('scanned'): issues.append(side+' unavailable/unscanned')
            for key in ('scanProblems','excludedScanProblems','transitionProblems','excludedTransitionProblems','stagingProgress'):
                if endpoint.get(key): issues.append(side+' '+key)
        ready = not issues and not session.get('paused') and session.get('status') == 'watching' and session.get('successfulCycles',0) > cycle
        return dict(ready=ready, progress=session.get('successfulCycles',0), status=session.get('status'),
            issues=issues, staging=session['beta'].get('stagingProgress'), paused=session.get('paused',False))
