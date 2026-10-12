"""Mini-local publication/export owner. Canonical I/O belongs to Dart resolvers."""
import contextlib
import fcntl
import json
import os
import time
import uuid
import hashlib
import shutil
import socket
import threading
import subprocess
import re
import platform
import socketserver
import sys
import signal
import argparse
from pathlib import Path

CANONICAL_ROOT = '/Volumes/Services/Mapping'
PROFILE = 'mapping-runtime-v1'
RELEASE = 'source-preparer-v1'
DEVELOPMENT_RELEASE_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, 'peak-bagger:source-preparer-v1:development'))
DEVELOPMENT_CONTROLLER_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, 'peak-bagger:controller-v1:development'))
EXTERNAL_PUBLISHER = Path('/Volumes/Development/overpass_turbo/slovenia-highways.sh')


def external_guard(canonical_root=CANONICAL_ROOT):
    return '\n# mapping-source cwd guard revision 1\n' + \
        "python3 - \"$PWD\" <<'MAPPING_SOURCE_CWD_GUARD' || exit 1\n" + \
        'import pathlib, sys\n' + \
        f'root = pathlib.Path({str(canonical_root)!r}).resolve()\n' + \
        'cwd = pathlib.Path(sys.argv[1]).resolve()\n' + \
        'if cwd == root or root in cwd.parents:\n' + \
        '    sys.exit("Mapping publication requires named promotion under mapping_source maintenance; fetch outside Mapping")\n' + \
        'MAPPING_SOURCE_CWD_GUARD\n# end mapping-source cwd guard\n'


def install_external_guard(script, backup, canonical_root=CANONICAL_ROOT):
    script = script.resolve()
    root = Path(canonical_root).resolve()
    if script == root or script.is_relative_to(root):
        raise SourceError('external publisher installer cannot write canonical Mapping')
    contents = script.read_text()
    shebang, separator, body = contents.partition('\n')
    if not separator or not shebang.startswith('#!'):
        raise SourceError('external publisher must retain its reviewed shell shebang')
    prefix = external_guard(canonical_root)
    if contents.startswith(shebang + '\n' + prefix):
        return
    if 'mapping-source cwd guard' in contents:
        raise SourceError('external publisher guard drift; review before reinstall')
    backup.parent.mkdir(parents=True, exist_ok=True)
    if backup.exists() and backup.read_text() != contents:
        raise SourceError('external publisher backup conflicts with reviewed original')
    if not backup.exists():
        with backup.open('x') as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        sync_directory(backup.parent)
    temporary = script.with_name(script.name + '.guard-' + str(uuid.uuid4()))
    with temporary.open('x') as stream:
        stream.write(shebang + '\n' + prefix + body)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.chmod(script.stat().st_mode)
    os.replace(temporary, script)
    sync_directory(script.parent)


def external_guard_identity():
    contents = EXTERNAL_PUBLISHER.read_text()
    shebang = contents.partition('\n')[0]
    if not contents.startswith(shebang + '\n' + external_guard()):
        raise SourceError('external Slovenia publisher is noncompliant; install-external-guard before enabling export')
    return hashlib.sha256(contents.encode()).hexdigest()


def safe_relative(path):
    return isinstance(path, str) and bool(path) and not path.startswith('/') and '\\' not in path and ':' not in path and '\0' not in path and all(part not in ('', '.', '..') for part in path.split('/'))


def require_uuid(value):
    if str(uuid.UUID(value)) != value:
        raise SourceError('expected lowercase UUID: ' + value)
    return value


COMPLETION_FIELDS = {'generationId', 'inventorySha256', 'operationId', 'publicationId',
    'sourcePreparerRelease', 'validationProfile', 'validatedAtUtc'}
PUBLICATION_FIELDS = {'publicationId', 'operationId', 'owner', 'state', 'priorInventorySha256',
    'intendedPaths', 'backupId', 'resultInventorySha256', 'startedAtUtc', 'finishedAtUtc'}
OPERATION_FIELDS = {'operationId', 'parentOperationId', 'owner', 'releaseId', 'stage', 'state',
    'generationId', 'publicationId', 'protectedExportIds', 'protectedGenerationIds', 'startedAtUtc',
    'progressAtUtc', 'outcomeRecordSha256'}


def check_record(value, kind, fields):
    if not isinstance(value, dict) or value.get('kind') != kind or type(value.get('schemaVersion')) is not int or value['schemaVersion'] != 1:
        raise SourceError('unsupported ' + kind + ' metadata version/kind')
    if set(value) != {'kind', 'schemaVersion'} | fields:
        raise SourceError('unsupported fields in ' + kind)
    return value


def completed_export(path, supported_releases=None):
    require_uuid(path.name)
    completion = check_record(read_json(path / 'completion.json'), 'mapping-source-completion', COMPLETION_FIELDS)
    inventory = check_record(read_json(path / 'integrity.json'), 'mapping-integrity', {'generationId', 'files'})
    require_uuid(completion['sourcePreparerRelease'])
    if completion['validationProfile'] != PROFILE or completion['sourcePreparerRelease'] not in (supported_releases or {DEVELOPMENT_RELEASE_ID}):
        raise SourceError('unsupported completed export validation profile/release')
    for field in ('generationId', 'operationId', 'publicationId'):
        require_uuid(completion[field])
    if completion['generationId'] != path.name or inventory['generationId'] != path.name or completion['inventorySha256'] != digest(inventory):
        raise SourceError('completed export identity/inventory mismatch')
    files = inventory['files']
    if not isinstance(files, list) or [f['path'] for f in files] != sorted(set(f['path'] for f in files)):
        raise SourceError('unordered/duplicate inventory paths')
    for file in files:
        if set(file) != {'path', 'size', 'sha256'} or not safe_relative(file['path']) or type(file['size']) is not int or file['size'] < 0 or not re.fullmatch('[0-9a-f]{64}', file['sha256']):
            raise SourceError('invalid integrity entry')
    return completion, inventory


def read_json(path):
    def unique(pairs):
        value = {}
        for key, item in pairs:
            if key in value:
                raise SourceError(f'duplicate metadata key: {path}:{key}')
            value[key] = item
        return value
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)


def owner():
    if platform.system() == 'Darwin':
        boot = subprocess.check_output(['/usr/sbin/sysctl', '-n', 'kern.bootsessionuuid'], timeout=5, text=True).strip()
    else:
        boot = Path('/proc/sys/kernel/random/boot_id').read_text().strip()
    start = subprocess.check_output(['ps', '-p', str(os.getpid()), '-o', 'lstart='], timeout=5, text=True).strip()
    return dict(hostId=platform.node(), bootId=boot, pid=os.getpid(), processStartId=start,
                ownershipToken=str(uuid.uuid4()))


class SourceError(RuntimeError):
    pass


def bounded_process(command, *, input_text=None, timeout=7200, on_unknown=lambda: None,
                    on_progress=lambda: None, pass_fds=(), environment=None, cwd=None):
    """Budget expiry changes status, never kills/duplicates an unknown child.

    Invoked only inside a detached operation supervisor. Inspection RPCs remain
    bounded while this owner waits for definitive child exit and drains output.
    """
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, env=environment, cwd=cwd, pass_fds=pass_fds)
    deadline = time.monotonic() + timeout
    progress_at = time.monotonic()
    byte_count = 0
    unknown = False
    first = True
    while True:
        try:
            wait = 5 if unknown else min(5, max(.001, deadline-time.monotonic()))
            output, errors = process.communicate(input_text if first else None, timeout=wait)
            break
        except subprocess.TimeoutExpired as pending:
            first = False
            received = len(pending.stdout or b'') + len(pending.stderr or b'')
            if received != byte_count:
                byte_count = received
                progress_at = time.monotonic()
                on_progress()
            if not unknown and (time.monotonic() >= deadline or time.monotonic()-progress_at >= 600):
                on_unknown()
                unknown = True
    if process.returncode != 0:
        raise SourceError(f'child failed ({process.returncode}): {command[0]}: {errors}')
    if errors:
        print(errors, file=sys.stderr)
    return output


def record(kind, **fields):
    return dict(kind=kind, schemaVersion=1, **fields)


def utc():
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def digest(value):
    return hashlib.sha256(json.dumps(value, separators=(",", ":"),
                                    ensure_ascii=False).encode()).hexdigest()


def sync_directory(path):
    descriptor = os.open(path, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def freeze_export(path):
    for root, directories, files in os.walk(path, topdown=False, followlinks=False):
        for name in files:
            file = Path(root) / name
            if file.is_symlink() or not file.is_file():
                raise SourceError('non-regular export: ' + str(file))
            file.chmod(0o444)
            with file.open('rb') as stream:
                os.fsync(stream.fileno())
        for name in directories:
            directory = Path(root) / name
            if directory.is_symlink():
                raise SourceError('export symlink: ' + str(directory))
            directory.chmod(0o555)
        sync_directory(root)


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + str(uuid.uuid4()) + ".tmp")
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(value, stream, separators=(",", ":"), ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


class Coordinator:
    def __init__(self, base, lock_wait=5, release_id=DEVELOPMENT_RELEASE_ID,
                 compatible_releases=(), compatible_controllers=()):
        self.base = Path(base).resolve()
        check_layout(self.base, workspace_roots())
        self.base.mkdir(parents=True, exist_ok=True)
        self.lock_wait = lock_wait
        self.release_id = require_uuid(release_id)
        self.supported_releases = {self.release_id, DEVELOPMENT_RELEASE_ID, *compatible_releases}
        self.supported_controllers = {DEVELOPMENT_CONTROLLER_ID, *compatible_controllers}
        self.registered_outputs = {}
        self._publishing = False
        self._fds = []

    @contextlib.contextmanager
    def publication_lock(self, name='publication'):
        with (self.base / (name + '.lock')).open("a+b") as stream:
            deadline = time.monotonic() + self.lock_wait
            while True:
                try:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise SourceError("publication busy; retry inspection")
                    time.sleep(min(0.05, self.lock_wait))
            try:
                self._fds.append(stream.fileno())
                yield
            finally:
                self._fds.remove(stream.fileno())
                # Close, do not explicitly unlock a shared descriptor inherited
                # by surviving children. Their lifetime retains the lock.

    def publication(self):
        path = self.base / "publication.json"
        if not path.exists():
            return None
        publication = check_record(read_json(path), 'mapping-publication', PUBLICATION_FIELDS)
        for field in ('publicationId', 'operationId', 'backupId'):
            require_uuid(publication[field])
        if publication['state'] not in ('publishing', 'recovery-required', 'complete', 'rolled-back'):
            raise SourceError('unsupported publication state')
        if not isinstance(publication['intendedPaths'], list) or not all(safe_relative(path) for path in publication['intendedPaths']):
            raise SourceError('invalid publication intended paths')
        return publication

    def maintenance(self, action, validate, backup=None, operation_id=None):
        with self.publication_lock():
            previous = self.publication()
            if previous is not None:
                self.require_complete()
            publication_id = str(uuid.uuid4())
            self.prior_files = backup(publication_id) if backup else []
            publication = record("mapping-publication", publicationId=publication_id,
                                 operationId=operation_id or str(uuid.uuid4()), owner=owner(), state="publishing",
                                 priorInventorySha256=previous['resultInventorySha256'] if previous else None,
                                 intendedPaths=[], backupId=publication_id, resultInventorySha256=None,
                                 startedAtUtc=utc(), finishedAtUtc=None)
            self.journal = record('mapping-publication-journal', publicationId=publication_id,
                                  operationId=publication['operationId'], steps=[])
            self._save_journal()
            atomic_json(self.base / "publication.json", publication)
            self._publishing = True
            try:
                action()
                result = validate()
                publication = self.publication()
                if any(step['state'] == 'prepared' for step in self.journal['steps']):
                    raise SourceError('publication has unresolved prepared steps; recovery required')
                publication.update(state="complete", resultInventorySha256=result, finishedAtUtc=utc())
                atomic_json(self.base / "publication.json", publication)
            except BaseException:
                publication.update(state="recovery-required")
                atomic_json(self.base / "publication.json", publication)
                raise
            finally:
                self._publishing = False

    def _save_journal(self):
        atomic_json(self.base / 'journals' / (self.journal['publicationId'] + '.json'), self.journal)

    def guard(self, request):
        publication = self.publication()
        if not self._publishing or request.get('ownershipToken') != publication['owner']['ownershipToken']:
            raise SourceError('publication token has no live owning supervisor')
        action = request['action']
        if action not in ('ping', 'prepare', 'published'):
            raise SourceError('child cannot perform outer-owner action')
        if request.get('root') != CANONICAL_ROOT:
            raise SourceError('unexpected canonical root')
        if action == 'ping':
            return
        path = request['path']
        outputs = self.registered_outputs.get(request['toolId'], [])
        if not safe_relative(path) or not any(path == target or kind == 'directory' and path.startswith(target + '/')
                   or kind == 'override-file'
                   for target, kind in outputs):
            raise SourceError('unregistered publisher target: ' + path)
        if action == 'prepare':
            next_sha = request['nextSha256']
            if not re.fullmatch('[0-9a-f]{64}', next_sha):
                raise SourceError('invalid next digest')
            pending = [step for step in self.journal['steps'] if step['path'] == path and step['state'] == 'prepared']
            if pending and pending[-1]['nextSha256'] != next_sha and not getattr(self, '_restoring', False):
                raise SourceError('intended staged bytes changed; rollback or restore the original prepared input: ' + path)
            prior = request.get('priorSha256', next((f['sha256'] for f in self.prior_files if f['path'] == path), None))
            for step in self.journal['steps']:
                if step['path'] == path and step['state'] == 'published':
                    prior = step['nextSha256']
            self.journal['steps'].append(dict(path=path, priorSha256=prior, nextSha256=next_sha, state='prepared'))
            publishers_path = self.base / 'publication-publishers' / (publication['publicationId'] + '.json')
            publishers = read_json(publishers_path) if publishers_path.exists() else {}
            publishers.setdefault(path, request['toolId'])
            atomic_json(publishers_path, publishers)
            publication['intendedPaths'] = sorted(set(publication['intendedPaths'] + [path]))
            atomic_json(self.base / 'publication.json', publication)
        else:
            pending = [step for step in self.journal['steps'] if step['path'] == path and step['state'] == 'prepared']
            if not pending:
                raise SourceError('no prepared publication step: ' + path)
            pending[-1]['state'] = 'published'
        self._save_journal()

    @contextlib.contextmanager
    def guard_server(self):
        coordinator = self
        path = self.base / 'rpc.sock'
        path.unlink(missing_ok=True)
        mutex = threading.Lock()
        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                self.connection.settimeout(30)
                try:
                    raw = self.rfile.readline(65537)
                    if len(raw) > 65536:
                        raise SourceError('oversized publication request')
                    request = json.loads(raw)
                    with mutex:
                        coordinator.guard(request)
                    response = {'ok': True}
                except Exception as error:
                    response = {'ok': False, 'error': str(error)}
                self.wfile.write((json.dumps(response)+'\n').encode())
        with socketserver.ThreadingUnixStreamServer(str(path), Handler) as server:
            path.chmod(0o600)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                yield dict(os.environ, MAPPING_PUBLICATION_SOCKET=str(path),
                    MAPPING_PUBLICATION_BACKUP=str(self.base / 'backups' / self.publication()['backupId']),
                    MAPPING_PUBLICATION_TOKEN=self.publication()['owner']['ownershipToken'])
            finally:
                server.shutdown()
                thread.join()
                path.unlink(missing_ok=True)

    def require_complete(self):
        publication = self.publication()
        if publication is None or publication["state"] not in ("complete", "rolled-back"):
            raise SourceError("publication recovery required before capture")
        original_operation = self.base / 'operations' / (publication['operationId'] + '.json')
        if original_operation.exists():
            outcomes = [read_json(path) for path in (self.base/'operations').glob('*.json')]
            if not any(op['state'] == 'succeeded' and op['publicationId'] == publication['publicationId']
                       and op['outcomeRecordSha256'] == digest(publication) for op in outcomes):
                raise SourceError('publication recovery required: no durable successful supervisor outcome')
        return publication

    def recover(self, validate, restore=None):
        with self.publication_lock():
            publication = self.publication()
            if publication is None:
                raise SourceError("no publication to recover")
            self.journal = read_json(self.base / 'journals' / (publication['publicationId'] + '.json'))
            self.prior_files = []
            publication.update(state='publishing', owner=owner())
            atomic_json(self.base / 'publication.json', publication)
            self._publishing = True
            self._restoring = restore is not None
            try:
                if restore:
                    restore(publication)
                result = validate()
                for step in self.journal['steps']:
                    step['state'] = 'restored' if restore else 'published'
                self._save_journal()
                publication = self.publication()
                publication.update(state='rolled-back' if restore else 'complete',
                    resultInventorySha256=result, finishedAtUtc=utc())
            except BaseException:
                publication = self.publication()
                publication.update(state='recovery-required')
                atomic_json(self.base / 'publication.json', publication)
                raise
            finally:
                self._publishing = False
                self._restoring = False
            atomic_json(self.base / "publication.json", publication)

    def last_operation(self):
        return check_record(read_json(self.base / 'operation.json'), 'mapping-operation', OPERATION_FIELDS)

    @contextlib.contextmanager
    def receipt_cleanup_scope(self, receipt, *, protected_export_ids):
        """Item 06 integration: caller supplies frozen live transfer/operation pins.

        This scope retains source coordination through the caller's cleanup. It
        acknowledges exact durable receipt first, never deletes/replaces bytes on
        its own, and cannot be entered while a surviving source operation owns
        the pipeline. Cleanup must keep the current completed surface available
        or select its successor through this same ownership boundary.
        """
        fields = {'receiptId', 'operationId', 'generationId', 'inventorySha256', 'sourceCompletionSha256',
                  'localValidationReportSha256', 'controllerRelease', 'storedAtUtc'}
        check_record(receipt, 'mapping-durable-receipt', fields)
        for field in ('receiptId', 'operationId', 'generationId'):
            require_uuid(receipt[field])
        for field in ('inventorySha256', 'sourceCompletionSha256', 'localValidationReportSha256'):
            if not re.fullmatch('[0-9a-f]{64}', receipt[field]):
                raise SourceError('invalid durable receipt digest')
        require_uuid(receipt['controllerRelease'])
        if receipt['controllerRelease'] not in self.supported_controllers:
            raise SourceError('unsupported durable receipt controller')
        generation = receipt['generationId']
        with self.publication_lock('dispatch'), self.publication_lock('prepare'):
            if generation in protected_export_ids:
                raise SourceError('export is protected by a live transfer/operation: ' + generation)
            export = self.base / 'prepared' / generation
            completion, _ = completed_export(export, self.supported_releases)
            if receipt['inventorySha256'] != completion['inventorySha256'] or receipt['sourceCompletionSha256'] != hashlib.sha256((export/'completion.json').read_bytes()).hexdigest():
                raise SourceError('durable receipt does not acknowledge this exact export')
            target = self.base / 'receipts' / (generation + '.json')
            if target.exists() and read_json(target) != receipt:
                raise SourceError('conflicting durable receipt acknowledgement')
            if not target.exists():
                atomic_json(target, receipt)
            yield generation

    def _save_operation(self, operation):
        atomic_json(self.base / 'operations' / (operation['operationId'] + '.json'), operation)
        atomic_json(self.base / 'operation.json', operation)

    def prepare(self, capture, validate, operation_id=None):
        with self.publication_lock('prepare'):
            operation = record('mapping-operation', operationId=operation_id or str(uuid.uuid4()),
                parentOperationId=None, owner=owner(), releaseId=self.release_id, stage='prepare', state='running',
                generationId=str(uuid.uuid4()), publicationId=None, protectedExportIds=[],
                protectedGenerationIds=[], startedAtUtc=utc(), progressAtUtc=utc(), outcomeRecordSha256=None)
            self._save_operation(operation)
            try:
                generation = self._prepare(capture, validate, operation)
                completion = self.base / 'prepared' / generation / 'completion.json'
                operation.update(state='succeeded', generationId=generation, protectedExportIds=[generation],
                    progressAtUtc=utc(), outcomeRecordSha256=hashlib.sha256(completion.read_bytes()).hexdigest())
                self._save_operation(operation)
                return generation
            except BaseException as error:
                operation.update(state='failed', progressAtUtc=utc())
                self._save_operation(operation)
                inventory = self.base / 'captures' / operation['generationId'] / 'integrity.json'
                if inventory.exists():
                    report = record('mapping-validation-report', generationId=operation['generationId'],
                        inventorySha256=digest(read_json(inventory)), operationId=operation['operationId'], validationProfile=PROFILE,
                        validatorRelease=self.release_id, state='failed', checks=[], diagnostics=[str(error)], validatedAtUtc=utc())
                    atomic_json(self.base / 'validation' / (operation['generationId'] + '.json'), report)
                raise

    def _prepare(self, capture, validate, operation):
        generation = operation['generationId']
        candidate = self.base / "captures" / generation
        prepared = self.base / "prepared"
        prepared.mkdir(exist_ok=True)
        with self.publication_lock():
            publication = self.require_complete()
            for completed in prepared.iterdir():
                completion, _ = completed_export(completed, self.supported_releases)
                if completion['publicationId'] == publication['publicationId']:
                    return completed.name
            operation.update(stage='capture', publicationId=publication['publicationId'], protectedExportIds=[generation])
            self._save_operation(operation)
            integrity = capture(candidate / "payload", generation)
            atomic_json(candidate / 'integrity.json', integrity)
        for completed in prepared.iterdir():
            _, existing = completed_export(completed, self.supported_releases)
            if existing["files"] == integrity["files"]:
                shutil.rmtree(candidate)
                return completed.name
        if any(prepared.iterdir()):
            raise SourceError('Existing source export awaits durable receipt/receipt-bound cleanup; changed export blocked')
        inventory_hash = digest(integrity)
        operation.update(stage='validate', progressAtUtc=utc())
        self._save_operation(operation)
        validation = validate(candidate / "payload", generation)
        atomic_json(candidate / "integrity.json", integrity)
        report = record('mapping-validation-report', generationId=generation, inventorySha256=inventory_hash,
            operationId=operation['operationId'], validationProfile=PROFILE, validatorRelease=self.release_id,
            state='passed', checks=validation['checks'], diagnostics=validation['diagnostics'], validatedAtUtc=utc())
        atomic_json(self.base / "validation" / (generation + ".json"), report)
        completion = record("mapping-source-completion", generationId=generation,
                            inventorySha256=inventory_hash, operationId=operation['operationId'],
                            publicationId=publication["publicationId"],
                            sourcePreparerRelease=self.release_id,
                            validationProfile="mapping-runtime-v1", validatedAtUtc=utc())
        atomic_json(candidate / "completion.json", completion)
        freeze_export(candidate)
        os.rename(candidate, prepared / generation)
        (prepared / generation).chmod(0o555)
        sync_directory(prepared)
        return generation


PUBLISHERS = {
    'restore-output-snapshot': ['dart', 'run', 'tool/mapping_source_restore.dart'],
    'bootstrap-tool-contract': ['dart', 'run', 'tool/mapping_store.dart', 'bootstrap-tool-manifest'],
    'tool-contract': ['dart', 'run', 'tool/mapping_store.dart', 'replace-reviewed-tool-manifest'],
    'restore-tool-contract': ['dart', 'run', 'tool/mapping_store.dart', 'restore-tool-manifest'],
    'promote': ['dart', 'run', 'tool/mapping_source_promote.dart'],
    'fingerprints': ['dart', 'run', 'tool/update_region_peak_fingerprints.dart'],
    'thelist': ['dart', 'run', 'tool/download_tasmania_thelist_dem.dart'],
    'elvis': ['dart', 'run', 'tool/elvis_dem.dart'],
}


def validate_plan(plan):
    if not isinstance(plan, list):
        raise SourceError('maintenance plan must be a command array')
    for step in plan:
        if not isinstance(step, dict) or set(step) != {'publisher', 'arguments'} or step['publisher'] not in PUBLISHERS:
            raise SourceError('plan requires a registered named publisher, not a store-write shell')
        if not isinstance(step['arguments'], list) or not all(isinstance(arg, str) for arg in step['arguments']):
            raise SourceError('publisher arguments must be strings')
    return plan


class DatasetBridge:
    """Installed releases can inject their pinned dataset executable/commands.

    The checkout defaults are for explicit maintainer execution. Item 07 installs
    complete executable artifacts; Item 08 must select that release before use.
    """
    def __init__(self, coordinator, command=None, publishers=None, cwd=None):
        self.coordinator = coordinator
        self.command = list(command or ['dart', 'run', 'tool/mapping_source_dataset.dart'])
        self.publishers = {name: list(argv) for name, argv in (publishers or PUBLISHERS).items()}
        self.cwd = str(Path(cwd or Path(__file__).resolve().parents[1]).resolve())

    def unknown(self):
        path = self.coordinator.base / 'operation.json'
        if path.exists():
            operation = read_json(path)
            operation.update(state='outcome-unknown', progressAtUtc=utc())
            self.coordinator._save_operation(operation)

    def progress(self):
        path = self.coordinator.base / 'operation.json'
        if path.exists():
            operation = read_json(path)
            operation.update(progressAtUtc=utc())
            self.coordinator._save_operation(operation)

    def dataset(self, action, root, generation, **parameters):
        result = bounded_process(self.command + [action],
            input_text=json.dumps(dict(root=str(root), generationId=generation, **parameters)),
            pass_fds=tuple(self.coordinator._fds), on_unknown=self.unknown, on_progress=self.progress, cwd=self.cwd)
        return json.loads(result)

    def capture(self, payload, generation, root=CANONICAL_ROOT):
        # Space is checked before copying; the authoritative set/byte sizes are
        # resolver-derived, never a directory glob. Hashing remains background.
        inventory = self.dataset('inspect', root, generation, allowSourceLinks=True)
        required = sum(file['size'] for file in inventory['files'])
        if shutil.disk_usage(self.coordinator.base).free < required + 64*1024*1024:
            raise SourceError(f'capture has insufficient space: need {required} bytes plus 64 MiB reserve')
        return self.dataset('capture', root, generation, destination=str(payload))

    def validate(self, payload, generation):
        integrity = self.dataset('inspect', payload, generation)
        return self.dataset('validate', payload, generation, integrity=integrity)

    def backup(self, publication):
        target = self.coordinator.base / 'backups' / publication
        integrity = self.capture(target / 'payload', publication)
        atomic_json(target / 'integrity.json', integrity)
        freeze_export(target)
        sync_directory(target.parent)
        return integrity['files']

    def canonical_validation(self, *, recovering=False, rollback=False):
        publication = self.coordinator.publication()
        generation = str(uuid.uuid4())
        target = self.coordinator.base / 'publication-validation' / generation
        integrity = self.capture(target / 'payload', generation)
        atomic_json(target / 'integrity.json', integrity)
        report = self.validate(target / 'payload', generation)
        actual = {file['path']: file['sha256'] for file in integrity['files']}
        if recovering:
            if rollback:
                prior = read_json(self.coordinator.base / 'backups' / publication['backupId'] / 'integrity.json')
                if prior['files'] != integrity['files']:
                    raise SourceError('rollback differs from independently backed-up prior dataset')
            else:
                latest = {step['path']: step for step in self.coordinator.journal['steps']}
                for path, step in latest.items():
                    if path in actual and actual[path] != step['nextSha256']:
                        raise SourceError(f'recovery has not finished intended target: {path}')
        atomic_json(target / 'validation.json', record('mapping-validation-report',
            generationId=generation, inventorySha256=digest(integrity), operationId=publication['operationId'],
            validationProfile=PROFILE, validatorRelease=self.coordinator.release_id, state='passed', checks=report['checks'],
            diagnostics=report['diagnostics'], validatedAtUtc=utc()))
        result = digest(integrity)
        # Completed canonical evidence is durable before removing validation
        # scratch; backups and its journal remain until explicit recovery policy.
        return result

    def run_plan(self, plan, *, recovery=False):
        validate_plan(plan)
        publication = self.coordinator.publication()
        target = self.coordinator.base / 'plans' / (publication['publicationId'] + ('-rollback' if recovery else '') + '.json')
        if target.exists():
            progress = read_json(target)
            if progress['plan'] != plan:
                raise SourceError('maintenance plan changed while its publication is incomplete')
        else:
            progress = dict(plan=plan, states=['pending'] * len(plan))
            atomic_json(target, progress)
        atomic_json(self.coordinator.base / 'publication-capabilities' / (publication['publicationId'] + '.json'),
            self.coordinator.registered_outputs)
        with self.coordinator.guard_server() as environment:
            for index, step in enumerate(plan):
                if progress['states'][index] == 'succeeded':
                    continue
                progress['states'][index] = 'running'
                atomic_json(target, progress)
                output = bounded_process(self.publishers[step['publisher']] + step['arguments'],
                    environment=environment, cwd=self.cwd, pass_fds=tuple(self.coordinator._fds),
                    on_unknown=self.unknown, on_progress=self.progress)
                print(output, end='', flush=True)
                progress['states'][index] = 'succeeded'
                atomic_json(target, progress)

    def finish_plan(self):
        publication = self.coordinator.publication()
        target = self.coordinator.base / 'plans' / (publication['publicationId'] + '.json')
        if target.exists():
            self.run_plan(read_json(target)['plan'])

    def rollback(self, publication):
        backup = self.coordinator.base / 'backups' / publication['backupId']
        integrity = read_json(backup / 'integrity.json')
        modified = {step['path'] for step in self.coordinator.journal['steps']}
        publishers = read_json(self.coordinator.base/'publication-publishers'/(publication['publicationId']+'.json'))
        plan = [dict(publisher='restore-output-snapshot', arguments=[publishers[file['path']], file['path'],
            str(backup / 'payload' / file['path']), '--file']) for file in integrity['files'] if file['path'] in modified]
        topo = backup / 'outputs/DEM/Elvis/elvis_topo'
        if (topo/'snapshot.json').exists():
            plan.append(dict(publisher='restore-output-snapshot', arguments=['elvis-dem-topo', 'topo-dem', str(topo)]))
        tools = backup / 'extra' / 'tool_manifest.json'
        if tools.exists():
            plan.append(dict(publisher='restore-tool-contract', arguments=[str(tools)]))
        self.run_plan(plan, recovery=True)


def check_mini():
    if platform.system() != 'Darwin':
        raise SourceError('canonical source preparation must run on the mini macOS host')
    mounts = subprocess.check_output(['/sbin/mount'], timeout=5, text=True)
    for line in mounts.splitlines():
        if ' on /Volumes/Services (' in line and ('smbfs' in line or 'nfs' in line):
            raise SourceError('mini canonical source must be directly attached; SMB/NFS publication is forbidden')
    if not Path(CANONICAL_ROOT).is_dir():
        raise SourceError('mini canonical Mapping root unavailable: ' + CANONICAL_ROOT)


def check_layout(base, workspace_roots):
    root = Path(CANONICAL_ROOT).resolve()
    if base == root or base.is_relative_to(root) or root.is_relative_to(base):
        raise SourceError('source coordination/exports must be disjoint from canonical Mapping')
    for workspace in workspace_roots:
        if base == workspace or base.is_relative_to(workspace):
            raise SourceError('source exports/coordination cannot live under a source-workspace synchronization root')


def workspace_roots():
    names = ['peak_bagger', 'trip_routing', 'flutter_map_tile_caching']
    return [Path(__file__).resolve().parents[1]] + [
        (parent / name).resolve() for parent in [Path.home()/'Development/mapping', Path('/Volumes/Development/mapping')]
        for name in names]


def worker(coordinator, request):
    # Detached from SSH/client terminal. Children inherit lock descriptors, so
    # supervisor death does not release a surviving child's capture protection.
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    operation_id = require_uuid(request['operationId'])
    print(f'operation={operation_id} root={CANONICAL_ROOT} release={coordinator.release_id} role={RELEASE} action={request["action"]}', flush=True)
    bridge = DatasetBridge(coordinator)
    check_mini()
    if request['action'] == 'recover':
        publication = coordinator.publication()
        capabilities = {'tools': read_json(coordinator.base / 'publication-capabilities' / (publication['publicationId'] + '.json'))}
    elif request['action'] == 'maintenance' and request['plan'] and all(step['publisher'] in ('tool-contract', 'bootstrap-tool-contract') for step in request['plan']):
        capabilities = {'tools': {}}
    else:
        capabilities = bridge.dataset('capabilities', CANONICAL_ROOT, operation_id)
    coordinator.registered_outputs = dict(capabilities['tools'],
        **{'mapping-tool-manifest-maintenance': [('tool_manifest.json', 'file')]})
    action = request['action']
    with coordinator.publication_lock('release-' + coordinator.release_id):
        if action == 'prepare':
            if not (coordinator.base / 'publisher-compliance.json').exists():
                raise SourceError('source export disabled; complete publisher setup and run enable --confirm-publisher-register 1')
            policy = read_json(coordinator.base / 'publisher-compliance.json')
            if policy != dict(registerRevision=1, tools=capabilities['tools'], externalGuardSha256=external_guard_identity()):
                raise SourceError('publisher compliance drift; re-audit registered entrypoints before export')
            return coordinator.prepare(bridge.capture, bridge.validate, operation_id=operation_id)
        operation = record('mapping-operation', operationId=operation_id, parentOperationId=None,
            owner=owner(), releaseId=coordinator.release_id, stage='prepare', state='running', generationId=None,
            publicationId=None, protectedExportIds=[], protectedGenerationIds=[], startedAtUtc=utc(),
            progressAtUtc=utc(), outcomeRecordSha256=None)
        coordinator._save_operation(operation)
        try:
            if action == 'maintenance':
                coordinator.maintenance(lambda: bridge.run_plan(request['plan']),
                    bridge.canonical_validation, backup=bridge.backup, operation_id=operation_id)
            elif action == 'recover':
                def finish():
                    bridge.finish_plan()
                    return bridge.canonical_validation(recovering=True)
                coordinator.recover(lambda: bridge.canonical_validation(recovering=True, rollback=True)
                    if request['rollback'] else finish(), restore=bridge.rollback if request['rollback'] else None)
            else:
                raise SourceError('unknown source worker action')
            publication = coordinator.publication()
            operation.update(state='succeeded', publicationId=publication['publicationId'],
                outcomeRecordSha256=digest(publication), progressAtUtc=utc())
        except BaseException:
            operation.update(state='failed', progressAtUtc=utc())
            raise
        finally:
            coordinator._save_operation(operation)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, default=Path.home() / '.local/share/peak-bagger-mapping-source')
    parser.add_argument('--operation', type=require_uuid)
    parser.add_argument('--release-id', type=require_uuid, default=DEVELOPMENT_RELEASE_ID)
    parser.add_argument('--compatible-source-release', type=require_uuid, action='append', default=[])
    parser.add_argument('--compatible-controller-release', type=require_uuid, action='append', default=[])
    parser.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('prepare')
    sub.add_parser('status')
    sub.add_parser('reconcile')
    sub.add_parser('install-external-guard')
    enable = sub.add_parser('enable')
    enable.add_argument('--confirm-publisher-register', type=int, required=True, choices=[1])
    maintenance = sub.add_parser('maintenance')
    maintenance.add_argument('mode', choices=['run', 'recover'])
    maintenance.add_argument('--plan', type=Path)
    maintenance.add_argument('--rollback', action='store_true')
    args = parser.parse_args()
    base = args.base.resolve()
    check_layout(base, [Path(__file__).resolve().parents[1]])
    coordinator = Coordinator(base, release_id=args.release_id,
        compatible_releases=args.compatible_source_release, compatible_controllers=args.compatible_controller_release)
    if args.worker:
        coordinator._fds.append(int(os.environ['MAPPING_DISPATCH_FD']))
        operation = record('mapping-operation', operationId=args.operation, parentOperationId=None,
            owner=owner(), releaseId=coordinator.release_id, stage='prepare', state='running', generationId=None,
            publicationId=None, protectedExportIds=[], protectedGenerationIds=[], startedAtUtc=utc(),
            progressAtUtc=utc(), outcomeRecordSha256=None)
        coordinator._save_operation(operation)
        try:
            return worker(coordinator, read_json(base / 'requests' / (args.operation + '.json')))
        except BaseException:
            operation = coordinator.last_operation()
            operation.update(state='failed', progressAtUtc=utc())
            coordinator._save_operation(operation)
            raise
    if args.command == 'status':
        path = base / 'operations' / (args.operation + '.json') if args.operation else base / 'operation.json'
        state = read_json(path) if path.exists() else None
        alive = False
        probe = Coordinator(base, lock_wait=0)
        try:
            with probe.publication_lock('dispatch'):
                pass
        except SourceError:
            alive = True
        print(json.dumps(dict(operation=state, supervisorOrChildOwnsPipeline=alive,
            publication=coordinator.publication(), preparedExports=sorted(p.name for p in (base/'prepared').glob('*')))))
        return
    if args.command == 'reconcile':
        if not args.operation:
            raise SourceError('reconcile requires the original --operation UUID')
        with coordinator.publication_lock('dispatch'):
            path = base / 'operations' / (args.operation + '.json')
            operation = check_record(read_json(path), 'mapping-operation', OPERATION_FIELDS)
            if operation['state'] in ('running', 'outcome-unknown'):
                operation.update(state='failed', progressAtUtc=utc())
                coordinator._save_operation(operation)
            print(json.dumps(operation))
        return
    check_mini()
    if args.command == 'install-external-guard':
        with coordinator.publication_lock('dispatch'), coordinator.publication_lock():
            install_external_guard(EXTERNAL_PUBLISHER, base/'external-publishers/slovenia-highways.before.sh')
            print('External Slovenia snapshot fetch is now store-isolated; final promotion uses the guarded named capability.')
        return
    if args.command == 'enable':
        with coordinator.publication_lock('dispatch'), coordinator.publication_lock():
            bridge = DatasetBridge(coordinator)
            capabilities = bridge.dataset('capabilities', CANONICAL_ROOT, str(uuid.uuid4()))
            coordinator.require_complete()
            atomic_json(base / 'publisher-compliance.json', dict(registerRevision=1, tools=capabilities['tools'],
                externalGuardSha256=external_guard_identity()))
            print('Source export enabled for reviewed publisher register revision 1; automatic scheduling is installed separately.')
        return
    operation_id = args.operation or str(uuid.uuid4())
    request = dict(operationId=operation_id, action='prepare')
    if args.command == 'maintenance':
        request['action'] = 'maintenance' if args.mode == 'run' else 'recover'
        request['rollback'] = args.rollback
        if args.plan:
            plan_path = args.plan.resolve()
            if plan_path.is_relative_to(Path(CANONICAL_ROOT).resolve()):
                raise SourceError('maintenance plan must be prepared outside Mapping')
            request['plan'] = validate_plan(read_json(plan_path))
        else:
            request['plan'] = []
    with coordinator.publication_lock('dispatch'):
        if (base / 'requests' / (operation_id + '.json')).exists() or (base / 'operations' / (operation_id + '.json')).exists():
            raise SourceError('operation identity already exists; inspect/reconcile it, do not replay')
        previous_path = base / 'operation.json'
        if previous_path.exists() and read_json(previous_path)['state'] in ('running', 'outcome-unknown'):
            raise SourceError('prior outcome unresolved; bounded inspection/reconcile is required')
        atomic_json(base / 'requests' / (operation_id + '.json'), request)
        logs = base / 'logs'
        logs.mkdir(exist_ok=True)
        with (logs / (operation_id + '.log')).open('ab') as log:
            environment = dict(os.environ, MAPPING_DISPATCH_FD=str(coordinator._fds[-1]))
            subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--base', str(base),
                '--operation', operation_id, '--release-id', args.release_id,
                *[arg for value in args.compatible_source_release for arg in ('--compatible-source-release', value)],
                *[arg for value in args.compatible_controller_release for arg in ('--compatible-controller-release', value)],
                '--worker', 'prepare'], stdin=subprocess.DEVNULL,
                stdout=log, stderr=log, start_new_session=True, pass_fds=tuple(coordinator._fds), env=environment)
        print(json.dumps(dict(operationId=operation_id, status='accepted', log=str(logs/(operation_id+'.log')))))


if __name__ == '__main__':
    try:
        main()
    except BaseException as error:
        print(f'source operation failed: {error}', file=sys.stderr)
        sys.exit(1)
