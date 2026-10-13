"""Non-store release installer/selector. No workspace handover or dataset writes."""
import contextlib
import fcntl
import hashlib
import os
import shutil
import subprocess
import json
import argparse
import sysconfig
import sys
import time
import uuid
from pathlib import Path

from mapping_source import (SourceError, PROFILE, atomic_json, check_layout,
    check_record, freeze_export, read_json, record, require_uuid, safe_relative,
    sync_directory, utc, owner, workspace_roots as source_workspaces)
from mapping_retention import reject_links, remove_tree

APP_READER = 'e442ea38-fc1d-4ca0-b07d-223b01df6c35'
CONTRACTS = {kind: 1 for kind in ('mapping-integrity', 'mapping-source-completion',
    'mapping-publication', 'mapping-publication-journal', 'mapping-operation',
    'mapping-durable-receipt', 'mapping-validation-report', 'mapping-eligibility',
    'mapping-selection', 'mapping-selection-transaction', 'mapping-session')}
MANIFEST_FIELDS = {'releaseId', 'role', 'profile', 'contracts', 'appReaders',
    'sourceReleases', 'controllerReleases', 'artifacts', 'dependencies'}
PYTHON_STAGES = ('mapping_source.py', 'mapping_replica.py', 'mapping_retention.py',
    'mapping_releases.py', 'mapping_release_launcher.py')
SOURCE_STAGES = ('mapping_source_promote', 'mapping_source_restore', 'mapping_store',
    'update_region_peak_fingerprints', 'download_tasmania_thelist_dem', 'elvis_dem', 'non_store_paths')


def required_artifacts(role):
    result = {f'tool/{name}' for name in PYTHON_STAGES} | {'bin/mapping_source_dataset'}
    if role == 'source-preparer':
        result |= {f'bin/{name}' for name in SOURCE_STAGES} | {'bin/dart', 'tool/publish_thelist_dem.sh'}
        result |= {f'test/fixtures/mapping_store/v1/{name}' for name in
            ('region_manifest.json', 'Polygons/manifest.json', 'tool_manifest.json')}
    return result


def sha(path):
    with path.open('rb') as stream:
        value = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            value.update(chunk)
        return value.hexdigest()


def artifacts(path):
    result = []
    for root, directories, names in os.walk(path, followlinks=False):
        for name in directories + names:
            reject_links(Path(root)/name)
        for name in names:
            target = Path(root)/name
            if target == path/'release.json':
                continue
            if not target.is_file() or target.stat().st_nlink != 1:
                raise SourceError(f'non-independent release artifact: {target}')
            result.append(dict(path=target.relative_to(path).as_posix(),
                size=target.stat().st_size, sha256=sha(target), executable=bool(target.stat().st_mode & 0o111)))
    return sorted(result, key=lambda item: item['path'])


def manifest_for(path, *, role, release_id, source_ids, controller_ids, dependencies):
    return record('mapping-release', releaseId=release_id, role=role, profile=PROFILE,
        contracts=dict(CONTRACTS), appReaders=[APP_READER], sourceReleases=sorted(set(source_ids)),
        controllerReleases=sorted(set(controller_ids)), artifacts=artifacts(path), dependencies=dependencies)


def manifest(path):
    value = check_record(read_json(path), 'mapping-release', MANIFEST_FIELDS)
    require_uuid(value['releaseId'])
    if value['role'] not in ('controller', 'source-preparer'):
        raise SourceError('unsupported release role')
    if value['profile'] != PROFILE or value['contracts'] != CONTRACTS or any(type(version) is not int for version in value['contracts'].values()) or value['appReaders'] != [APP_READER]:
        raise SourceError(f'unsupported release metadata/profile/app-reader combination: {path}; require schemas=1 profile={PROFILE} reader={APP_READER}')
    for key in ('sourceReleases', 'controllerReleases'):
        if not isinstance(value[key], list) or value[key] != sorted(set(value[key])):
            raise SourceError('invalid compatible release identities')
        for identity in value[key]:
            require_uuid(identity)
    for item in value['artifacts']:
        if set(item) != {'path', 'size', 'sha256', 'executable'} or not safe_relative(item['path']):
            raise SourceError('invalid release artifact')
    return value


def verify(path):
    reject_links(path)
    value = manifest(path/'release.json')
    if artifacts(path) != value['artifacts']:
        raise SourceError(f'incomplete/drifted release artifacts: {path}')
    if not required_artifacts(value['role']).issubset({item['path'] for item in value['artifacts']}):
        raise SourceError('missing required installed stage/helper artifacts')
    for dependency in value['dependencies']:
        if set(dependency) != {'path', 'sha256'} or not Path(dependency['path']).is_absolute():
            raise SourceError('invalid stable machine dependency')
        target = Path(dependency['path']).resolve()
        check_layout(target, source_workspaces())
        if sha(target) != dependency['sha256']:
            raise SourceError(f'stable machine dependency drift: {target}; build/reselect a compatible release')
    return value


def compile_dart(source_path, output):
    subprocess.run(['dart', 'compile', 'exe', str(source_path), '-o', str(output)],
        cwd=source_path.parents[1], check=True, timeout=300)


def machine_dependencies():
    """Concrete stable interpreter/native paths, not mutable checkout resolution."""
    paths = {Path(sys.executable).resolve()}
    standard_library = Path(sysconfig.get_path('stdlib')).resolve()
    check_layout(standard_library, source_workspaces())
    for root, directories, names in os.walk(standard_library):
        directories[:] = [name for name in directories if name not in ('site-packages', '__pycache__', 'test', 'tests')]
        for name in names:
            if name.endswith(('.py', '.so', '.dylib', '.zip')):
                paths.add((Path(root)/name).resolve())
    gdal = Path('/opt/homebrew/lib/libgdal.dylib').resolve()
    if not gdal.is_file():
        raise SourceError('GDAL prerequisite missing: /opt/homebrew/lib/libgdal.dylib')
    pending = [gdal]
    visited = set()
    while pending:
        library = pending.pop()
        if library in visited:
            continue
        visited.add(library)
        paths.add(library)
        output = subprocess.check_output(['/usr/bin/otool', '-L', str(library)], text=True, timeout=30)
        for line in output.splitlines()[1:]:
            operand = line.strip().split(' (', 1)[0]
            if operand.startswith('/opt/homebrew/'):
                # Keep the loader's alias as well as its concrete Cellar target:
                # relinking opt/lib during an upgrade must be detected as drift.
                paths.add(Path(operand))
                child = Path(operand).resolve()
                if child not in visited:
                    pending.append(child)
            elif operand.startswith(('@rpath/', '@loader_path/')):
                child = (library.parent/operand.split('/', 1)[1]).resolve()
                if not child.is_file():
                    raise SourceError(f'unresolved native dependency {operand} of {library}')
                if child not in visited:
                    pending.append(child)
            elif operand.startswith('@'):
                raise SourceError(f'unresolved native dependency {operand} of {library}')
    proj = Path('/opt/homebrew/share/proj/proj.db').resolve()
    if not proj.is_file():
        raise SourceError('PROJ prerequisite missing: /opt/homebrew/share/proj/proj.db')
    paths.add(proj)
    for name in ('gdalinfo', 'gdalwarp', 'gdaldem', 'gdal_translate', 'gdalbuildvrt'):
        target = Path('/opt/homebrew/bin')/name
        if not target.is_file():
            raise SourceError(f'GDAL command prerequisite missing: {target}')
        paths.add(target.resolve())
    return [dict(path=str(path), sha256=sha(path)) for path in sorted(paths)]


def build(checkout, output, *, role, release_id, source_ids, controller_ids,
          compile_executable=compile_dart, dependencies=None):
    checkout, output = Path(checkout).resolve(), Path(output).resolve()
    check_layout(output, source_workspaces() + [checkout])
    if output.exists():
        raise SourceError('bundle output exists; use a new staging directory')
    dependencies = machine_dependencies() if dependencies is None else dependencies
    output.mkdir(parents=True)
    for folder in ('tool', 'bin'):
        (output/folder).mkdir()
    for name in PYTHON_STAGES:
        shutil.copyfile(checkout/'tool'/name, output/'tool'/name)
    stages = ['mapping_source_dataset']
    if role == 'source-preparer':
        stages += SOURCE_STAGES
        fixture = output/'test/fixtures/mapping_store/v1'
        fixture.mkdir(parents=True)
        for path in (checkout/'test/fixtures/mapping_store/v1').rglob('*'):
            if path.is_file():
                target = fixture/path.relative_to(checkout/'test/fixtures/mapping_store/v1')
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
        shutil.copyfile(checkout/'tool/publish_thelist_dem.sh', output/'tool/publish_thelist_dem.sh')
        (output/'tool/publish_thelist_dem.sh').chmod(0o755)
    for name in stages:
        compile_executable(checkout/'tool'/f'{name}.dart', output/'bin'/name)
    if role == 'source-preparer':
        # The canonical tool contract still uses dart run prefixes. This exact
        # installed shim accepts only the compiled publisher allowlist.
        shim = '#!/bin/sh\nset -eu\nroot="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"\n'
        shim += '[ "$#" -ge 2 ] && [ "$1" = run ] || exit 64\ncase "$2" in\n'
        for name in stages:
            shim += f'  tool/{name}.dart|"$root/tool/{name}.dart") program={name} ;;\n'
        shim += '  *) exit 64 ;;\nesac\nshift 2\nexec "$root/bin/$program" "$@"\n'
        (output/'bin/dart').write_text(shim)
        (output/'bin/dart').chmod(0o755)
    value = manifest_for(output, role=role, release_id=release_id,
        source_ids=source_ids, controller_ids=controller_ids, dependencies=dependencies)
    atomic_json(output/'release.json', value)
    verify(output)
    return value


class Releases:
    def __init__(self, base, *, workspace_roots=None, publish=atomic_json):
        reject_links(Path(base).absolute())
        self.base = Path(base).resolve()
        check_layout(self.base, source_workspaces() if workspace_roots is None else workspace_roots)
        if any(part in {'incoming', 'generations', 'candidates', 'prepared', 'captures', 'payload'} for part in self.base.parts):
            raise SourceError('release installation must be outside transport/dataset payload namespaces')
        self.publish = publish
        self.base.mkdir(parents=True, exist_ok=True)

    @contextlib.contextmanager
    def lock(self):
        target = self.base/'installation.lock'
        reject_links(target)
        with target.open('a+b') as stream:
            deadline = time.monotonic() + 5
            while True:
                try:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise SourceError('release installation busy; retry inspection')
                    time.sleep(.05)
            yield

    def install(self, bundle):
        bundle = Path(bundle).resolve()
        value = verify(bundle)
        with self.lock():
            target = self.base/'releases'/value['releaseId']
            reject_links(target)
            if target.exists():
                if verify(target) != value:
                    raise SourceError('release identity collision/drift; publish a new release identity')
                return target
            scratch = self.base/'installing'/str(uuid.uuid4())
            scratch.parent.mkdir(exist_ok=True)
            try:
                shutil.copytree(bundle, scratch)
                verify(scratch)
                freeze_export(scratch)
                for item in value['artifacts']:
                    if item['executable']:
                        (scratch/item['path']).chmod(0o555)
                        with (scratch/item['path']).open('rb') as stream:
                            os.fsync(stream.fileno())
                target.parent.mkdir(exist_ok=True)
                os.rename(scratch, target)
                target.chmod(0o555)
                sync_directory(target.parent)
            finally:
                if scratch.exists():
                    remove_tree(scratch)
            return target

    def inspect(self):
        with self.lock():
            self.recover_selection()
        installed = {}
        for path in sorted((self.base/'releases').glob('*')):
            try:
                value = verify(path)
                installed[path.name] = dict(state='complete', manifest=value)
            except Exception as error:
                installed[path.name] = dict(state='drift', diagnostic=str(error))
        selected = read_json(self.base/'selected.json') if (self.base/'selected.json').exists() else None
        uses = [read_json(path) for path in sorted((self.base/'uses').glob('*.json'))]
        return dict(base=str(self.base), releases=installed, selected=selected, invocations=uses)

    def select(self, identity, peer_path, data_base):
        require_uuid(identity)
        data_base = Path(data_base).resolve()
        check_layout(data_base, source_workspaces())
        if data_base == self.base or data_base.is_relative_to(self.base) or self.base.is_relative_to(data_base):
            raise SourceError('installed releases and pipeline data must be disjoint')
        with self.lock():
            self.recover_selection()
            value = verify(self.base/'releases'/identity)
            peer = manifest(Path(peer_path))
            source_release = value if value['role'] == 'source-preparer' else peer
            controller = value if value['role'] == 'controller' else peer
            if source_release['role'] != 'source-preparer' or controller['role'] != 'controller' or source_release['releaseId'] not in controller['sourceReleases'] or controller['releaseId'] not in source_release['controllerReleases']:
                raise SourceError('unsupported controller/source-preparer release combination; build explicit mutual v1 support')
            selected_path = self.base/'selected.json'
            previous = read_json(selected_path) if selected_path.exists() else None
            self.check_retained(value, data_base)
            if value['role'] == 'controller':
                data_base.mkdir(parents=True, exist_ok=True)
                self.publish(data_base/'reader-compatibility.json', record('mapping-reader-compatibility',
                    appReaderRelease=APP_READER, profile=PROFILE, contracts=CONTRACTS,
                    sourceReleases=value['sourceReleases'], controllerReleases=value['controllerReleases']))
            selection = record('mapping-release-selection', releaseId=identity,
                manifestSha256=sha(self.base/'releases'/identity/'release.json'),
                peerReleaseId=peer['releaseId'], dataBase=str(data_base))
            transaction = record('mapping-release-transaction', priorSelection=previous,
                nextSelection=selection, state='prepared')
            self.publish(self.base/'selection-transaction.json', transaction)
            self.publish(selected_path, selection)
            transaction['state'] = 'committed'
            self.publish(self.base/'selection-transaction.json', transaction)
            return selection

    def recover_selection(self):
        target = self.base/'selection-transaction.json'
        reject_links(target)
        if not target.exists():
            return
        transaction = check_record(read_json(target), 'mapping-release-transaction',
            {'priorSelection', 'nextSelection', 'state'})
        if transaction['state'] not in ('prepared', 'committed'):
            raise SourceError('unsupported release selection transaction state')
        selected = transaction['nextSelection'] if transaction['state'] == 'committed' else transaction['priorSelection']
        if selected:
            value = verify(self.base/'releases'/selected['releaseId'])
            if value['releaseId'] != selected['releaseId'] or sha(self.base/'releases'/selected['releaseId']/'release.json') != selected['manifestSha256']:
                raise SourceError('recovery selection release drift; retained state preserved')
            atomic_json(self.base/'selected.json', selected)
        else:
            (self.base/'selected.json').unlink(missing_ok=True)
            sync_directory(self.base)
        target.unlink()
        sync_directory(self.base)

    def check_retained(self, value, base):
        """Read small protocol evidence only, never rewrite old data or hash DEMs."""
        from mapping_source import COMPLETION_FIELDS, PUBLICATION_FIELDS, OPERATION_FIELDS, completed_export
        from mapping_replica import Replica, ELIGIBILITY_FIELDS, VALIDATION_FIELDS, RECEIPT_FIELDS
        from mapping_retention import checked_selection
        fields = {
            'mapping-integrity': {'generationId', 'files'},
            'mapping-source-completion': COMPLETION_FIELDS,
            'mapping-publication': PUBLICATION_FIELDS,
            'mapping-operation': OPERATION_FIELDS,
            'mapping-eligibility': ELIGIBILITY_FIELDS,
            'mapping-validation-report': VALIDATION_FIELDS,
            'mapping-durable-receipt': RECEIPT_FIELDS,
            'mapping-selection': {'selectionId', 'active', 'recovery', 'revision', 'selectedAtUtc'},
            'mapping-selection-transaction': {'operationId', 'priorSelection', 'nextSelection', 'state'},
            'mapping-session': {'sessionId', 'owner', 'generationId', 'inventorySha256', 'appReaderRelease'},
        }
        paths = [base/name for name in ('publication.json', 'operation.json', 'selection.json', 'selection-transaction.json') if (base/name).exists()]
        for folder in ('operations', 'eligibility', 'receipts', 'acknowledgements', 'validation', 'failures', 'sessions'):
            paths.extend((base/folder).glob('*.json'))
        for folder in ('generations', 'prepared'):
            for path in (base/folder).glob('*'):
                paths.extend(path/name for name in ('completion.json', 'integrity.json', 'validation.json') if (path/name).exists())
        for path in paths:
            reject_links(path)
            item = read_json(path)
            kind = item.get('kind')
            if kind not in fields:
                raise SourceError(f'unsupported retained metadata kind: {path}')
            check_record(item, kind, fields[kind])
            if 'validationProfile' in item and item['validationProfile'] != PROFILE:
                raise SourceError(f'unsupported retained metadata profile: {path}')
            for key, allowed in (('sourcePreparerRelease', value['sourceReleases']),
                    ('controllerRelease', value['controllerReleases']),
                    ('validatorRelease', value['sourceReleases'] + value['controllerReleases']),
                    ('releaseId', value['sourceReleases'] + value['controllerReleases']),
                    ('appReaderRelease', value['appReaders'])):
                if key in item and item[key] not in allowed:
                    raise SourceError(f'unsupported retained metadata {key}={item[key]} at {path}; include explicit v1 compatibility before selection')
            if kind == 'mapping-selection':
                checked_selection(item)
            if kind == 'mapping-selection-transaction':
                for key in ('priorSelection', 'nextSelection'):
                    if item[key] is not None:
                        checked_selection(item[key])
        if value['role'] == 'controller':
            controller = Replica(base, release_id=value['releaseId'], compatible_sources=value['sourceReleases'],
                compatible_controllers=value['controllerReleases'])
            for path in (base/'eligibility').glob('*.json'):
                controller.eligible(path.stem)
        else:
            for path in (base/'prepared').glob('*'):
                completed_export(path, set(value['sourceReleases']))

    @contextlib.contextmanager
    def pin(self, operation_id):
        require_uuid(operation_id)
        with self.lock():
            self.recover_selection()
            selection = check_record(read_json(self.base/'selected.json'), 'mapping-release-selection',
                {'releaseId', 'manifestSha256', 'peerReleaseId', 'dataBase'})
            require_uuid(selection['releaseId'])
            path = self.base/'releases'/selection['releaseId']
            value = verify(path)
            if sha(path/'release.json') != selection['manifestSha256']:
                raise SourceError('selected release manifest drift')
            uses = self.base/'uses'
            reject_links(uses)
            uses.mkdir(exist_ok=True)
            target = uses/f'{operation_id}.json'
            reject_links(target)
            if target.exists():
                raise SourceError('invocation identity already exists; inspect/reconcile, never replay')
            reject_links(uses/f'{operation_id}.lock')
            stream = (uses/f'{operation_id}.lock').open('a+b')
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.publish(target, record('mapping-release-use', operationId=operation_id,
                releaseId=value['releaseId'], role=value['role'], dataBase=selection['dataBase'],
                manifestSha256=selection['manifestSha256'], owner=owner(), state='running', observedAtUtc=utc()))
        try:
            yield dict(path=path, manifest=value, fd=stream.fileno(), dataBase=Path(selection['dataBase']))
        finally:
            # Close only: detached supervisors/children retain this same flock.
            stream.close()

    @contextlib.contextmanager
    def use_lock(self, operation_id):
        target = self.base/'uses'/f'{operation_id}.lock'
        reject_links(target)
        with target.open('a+b') as stream:
            try:
                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise SourceError(f'surviving invocation/child owns release: operation={operation_id}') from error
            yield

    def reconcile(self, operation_id):
        require_uuid(operation_id)
        with self.lock(), self.use_lock(operation_id):
            target = self.base/'uses'/f'{operation_id}.json'
            use = check_record(read_json(target), 'mapping-release-use', {'operationId', 'releaseId',
                'role', 'dataBase', 'manifestSha256', 'owner', 'state', 'observedAtUtc'})
            if use['operationId'] != operation_id:
                raise SourceError('release use operation mismatch')
            from mapping_source import Coordinator, OPERATION_FIELDS
            from mapping_replica import Replica
            value = verify(self.base/'releases'/use['releaseId'])
            base = Path(use['dataBase'])
            stage = (Coordinator(base, lock_wait=0, release_id=value['releaseId'],
                compatible_releases=value['sourceReleases'], compatible_controllers=value['controllerReleases'])
                if value['role'] == 'source-preparer' else Replica(base, lock_wait=0, release_id=value['releaseId'],
                compatible_sources=value['sourceReleases'], compatible_controllers=value['controllerReleases']))
            scope = stage.publication_lock('dispatch') if value['role'] == 'source-preparer' else stage.lock()
            with scope:
                operation_path = base/'operations'/f'{operation_id}.json'
                state = 'failed'
                if operation_path.exists():
                    operation = check_record(read_json(operation_path), 'mapping-operation', OPERATION_FIELDS)
                    if operation['operationId'] != operation_id or operation['releaseId'] != use['releaseId']:
                        raise SourceError('release operation outcome identity mismatch')
                    if operation['state'] in ('running', 'outcome-unknown'):
                        raise SourceError('stage outcome unresolved; reconcile original stage operation before release retirement')
                    state = operation['state']
                    if state == 'succeeded':
                        if value['role'] == 'controller':
                            stage.eligible(operation['generationId'])
                        elif operation['generationId']:
                            from mapping_source import completed_export
                            completion = base/'prepared'/operation['generationId']/'completion.json'
                            completed_export(completion.parent, stage.supported_releases)
                            if sha(completion) != operation['outcomeRecordSha256']:
                                raise SourceError('source operation completion witness mismatch')
                        else:
                            publication = stage.require_complete()
                            from mapping_source import digest
                            if digest(publication) != operation['outcomeRecordSha256']:
                                raise SourceError('publication operation witness mismatch')
                use.update(state=state, observedAtUtc=utc())
                self.publish(target, use)
                return use

    def retire(self, identity):
        require_uuid(identity)
        with self.lock():
            self.recover_selection()
            if (self.base/'selected.json').exists() and read_json(self.base/'selected.json')['releaseId'] == identity:
                raise SourceError('selected release is protected; select a compatible replacement first')
            with contextlib.ExitStack() as scopes:
                for use_path in sorted((self.base/'launcher-uses').glob('*.json')):
                    if read_json(use_path)['releaseId'] == identity:
                        with use_path.with_suffix('.lock').open('a+b') as stream:
                            try:
                                fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                            except BlockingIOError as error:
                                raise SourceError('release protected by live installed manager') from error
                for path in sorted((self.base/'uses').glob('*.json')):
                    use = read_json(path)
                    if use['releaseId'] == identity:
                        if use['state'] not in ('succeeded', 'failed'):
                            raise SourceError(f'release protected by unresolved operation: {use["operationId"]}')
                        scopes.enter_context(self.use_lock(use['operationId']))
                remove_tree(self.base/'releases'/identity)

    def run(self, arguments, *, operation_id=None, target_operation=None):
        forbidden = {'--base', '--release-id', '--compatible-source-release',
            '--compatible-controller-release', '--dataset-executable', '--worker', '--operation'}
        if any(argument.split('=', 1)[0] in forbidden for argument in arguments):
            raise SourceError('installed invocation cannot override pinned release/dependencies/base/ownership')
        operation_id = operation_id or str(uuid.uuid4())
        if target_operation is not None:
            require_uuid(target_operation)
            if not arguments or arguments[0] not in ('status', 'reconcile'):
                raise SourceError('target operation is for status/reconcile only; never replay it')
        with self.pin(operation_id) as pinned:
            value, path = pinned['manifest'], pinned['path']
            python = next((item['path'] for item in value['dependencies']
                if Path(item['path']).name.startswith('python')), None)
            if python is None:
                raise SourceError('release has no pinned Python interpreter dependency')
            environment = {key: os.environ[key] for key in ('HOME', 'USER', 'TMPDIR', 'LANG') if key in os.environ}
            environment.update(PATH=str(path/'bin')+':/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin',
                PYTHONDONTWRITEBYTECODE='1', PYTHONNOUSERSITE='1',
                MAPPING_INSTALLED_RELEASE=str(path), MAPPING_RELEASE_FD=str(pinned['fd']))
            environment['MAPPING_PREPARATION_BASE'] = str(pinned['dataBase']/'preparation')
            native = next((item['path'] for item in value['dependencies'] if Path(item['path']).name.startswith('libgdal')), None)
            if native:
                environment['GDAL_LIBRARY_PATH'] = native
            gdal_command = next((item['path'] for item in value['dependencies'] if Path(item['path']).name == 'gdalinfo'), None)
            if gdal_command:
                environment['PATH'] = str(path/'bin')+':'+str(Path(gdal_command).parent)+':/usr/bin:/bin:/usr/sbin:/sbin'
            proj = next((item['path'] for item in value['dependencies'] if Path(item['path']).name == 'proj.db'), None)
            if proj:
                environment['PROJ_DATA'] = str(Path(proj).parent)
            script = 'mapping_source.py' if value['role'] == 'source-preparer' else 'mapping_replica.py'
            argv = [python, '-I', str(path/'tool'/script), '--base', str(pinned['dataBase']),
                '--release-id', value['releaseId']]
            if arguments and arguments[0] in ('capture', 'prepare', 'maintenance'):
                argv += ['--operation', operation_id]
            elif target_operation:
                argv += ['--operation', target_operation]
            argv += [arg for identity in value['sourceReleases'] for arg in ('--compatible-source-release', identity)]
            argv += [arg for identity in value['controllerReleases'] for arg in ('--compatible-controller-release', identity)]
            argv += arguments
            print(f'installed release={value["releaseId"]} role={value["role"]} operation={operation_id} helpers={path}', file=sys.stderr, flush=True)
            # -I would hide the sibling modules; the runner uses a tiny pinned
            # bootstrap with only this release's tool directory on sys.path.
            bootstrap = 'import sys,runpy; sys.path.insert(0,sys.argv.pop(1)); sys.argv=sys.argv[1:]; runpy.run_path(sys.argv[0],run_name="__main__")'
            argv = [python, '-I', '-c', bootstrap, str(path/'tool'), *argv[2:]]
            result = subprocess.run(argv, cwd=path, env=environment, pass_fds=(pinned['fd'],),
                capture_output=True, text=True, timeout=30)
            return result

    def install_launcher(self):
        with self.lock():
            self.recover_selection()
            selected = read_json(self.base/'selected.json')
            path = self.base/'releases'/selected['releaseId']
            value = verify(path)
            target = self.base/'mapping_release_launcher.py'
            contents = (path/'tool/mapping_release_launcher.py').read_bytes()
            if target.exists():
                if target.read_bytes() != contents:
                    raise SourceError('stable launcher protocol drift; review before replacing the dispatcher')
                return target
            temporary = target.with_suffix('.tmp')
            with temporary.open('xb') as stream:
                stream.write(contents)
                stream.flush()
                os.fsync(stream.fileno())
            os.rename(temporary, target)
            sync_directory(self.base)
            return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, default=Path.home()/'.local/share/peak-bagger-mapping-releases')
    sub = parser.add_subparsers(dest='action', required=True)
    builder = sub.add_parser('build')
    builder.add_argument('--checkout', type=Path, default=Path(__file__).resolve().parents[1])
    builder.add_argument('--output', type=Path, required=True)
    builder.add_argument('--role', choices=['controller', 'source-preparer'], required=True)
    builder.add_argument('--release-id', type=require_uuid, required=True)
    builder.add_argument('--source-release', type=require_uuid, action='append', required=True)
    builder.add_argument('--controller-release', type=require_uuid, action='append', required=True)
    install = sub.add_parser('install')
    install.add_argument('bundle', type=Path)
    seal = sub.add_parser('seal', help='register host dependencies in an uninstalled, transferred bundle')
    seal.add_argument('bundle', type=Path)
    select = sub.add_parser('select')
    select.add_argument('release_id', type=require_uuid)
    select.add_argument('--peer-manifest', type=Path, required=True)
    select.add_argument('--data-base', type=Path, required=True)
    sub.add_parser('inspect')
    sub.add_parser('install-launcher')
    retire = sub.add_parser('retire')
    retire.add_argument('release_id', type=require_uuid)
    reconcile = sub.add_parser('reconcile-release')
    reconcile.add_argument('operation_id', type=require_uuid)
    run = sub.add_parser('run')
    run.add_argument('--operation', type=require_uuid)
    run.add_argument('--target-operation', type=require_uuid)
    run.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == 'build':
        result = build(args.checkout, args.output, role=args.role, release_id=args.release_id,
            source_ids=args.source_release, controller_ids=args.controller_release)
    elif args.action == 'seal':
        bundle = args.bundle.resolve()
        # A transferred uninstalled bundle runs its own installer. Its location
        # is an artifact root, not a fourth synchronized source workspace.
        script_root = Path(__file__).resolve().parents[1]
        roots = [root for root in source_workspaces()
            if root != script_root or not (script_root/'release.json').is_file()]
        check_layout(bundle, roots)
        value = manifest(bundle/'release.json')
        if artifacts(bundle) != value['artifacts']:
            raise SourceError('incomplete transferred bundle; cannot seal')
        value['dependencies'] = machine_dependencies()
        atomic_json(bundle/'release.json', value)
        result = verify(bundle)
    else:
        manager = Releases(args.base)
        if args.action == 'install':
            result = str(manager.install(args.bundle))
        elif args.action == 'select':
            result = manager.select(args.release_id, args.peer_manifest, args.data_base)
        elif args.action == 'inspect':
            result = manager.inspect()
        elif args.action == 'install-launcher':
            result = str(manager.install_launcher())
        elif args.action == 'retire':
            manager.retire(args.release_id)
            result = dict(retired=args.release_id)
        elif args.action == 'reconcile-release':
            result = manager.reconcile(args.operation_id)
        else:
            arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
            completed = manager.run(arguments, operation_id=args.operation, target_operation=args.target_operation)
            print(completed.stdout, end='')
            print(completed.stderr, end='', file=sys.stderr)
            return completed.returncode
    if isinstance(result, dict) and result.get('kind') == 'mapping-release':
        result = {key: result[key] for key in ('releaseId', 'role', 'profile', 'contracts', 'appReaders', 'sourceReleases', 'controllerReleases')} | dict(
            artifactCount=len(result['artifacts']), dependencyCount=len(result['dependencies']))
    print(json.dumps(result), flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(f'release operation failed: {error}', file=sys.stderr, flush=True)
        sys.exit(1)
