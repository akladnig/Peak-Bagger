"""Local incoming-only observation, independent capture and eligibility owner."""
import hashlib
import json
import re
from datetime import datetime, timezone
import contextlib
import argparse
import fcntl
import os
import shutil
import signal
import subprocess
import stat
import time
import sys
import uuid
from pathlib import Path

from mapping_source import (PROFILE, DEVELOPMENT_RELEASE_ID, DEVELOPMENT_CONTROLLER_ID,
    SourceError, atomic_json, bounded_process, check_layout, check_record, completed_export, digest, freeze_export,
    OPERATION_FIELDS, decode_json, owner, read_json, record, require_uuid, sync_directory, utc, workspace_roots,
    installed_commands, release_fds)


class ReplicaError(SourceError):
    pass


ELIGIBILITY_FIELDS = {'generationId', 'inventorySha256', 'sourceCompletionSha256',
    'validationReportSha256', 'controllerRelease', 'validationProfile', 'eligibleAtUtc'}
VALIDATION_FIELDS = {'generationId', 'inventorySha256', 'operationId', 'validationProfile',
    'validatorRelease', 'state', 'checks', 'diagnostics', 'validatedAtUtc'}
RECEIPT_FIELDS = {'receiptId', 'operationId', 'generationId', 'inventorySha256',
    'sourceCompletionSha256', 'localValidationReportSha256', 'controllerRelease', 'storedAtUtc'}


def file_sha(path):
    with path.open('rb') as stream:
        result = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024*1024), b''):
            result.update(chunk)
        return result.hexdigest()


def reject_links(path):
    for component in [path, *path.parents]:
        if component.is_symlink():
            raise ReplicaError(f'path contains symlink: {component}')


def timestamp(value):
    if not isinstance(value, str) or 'T' not in value or not value.endswith('Z'):
        raise ReplicaError('metadata timestamp must be UTC ISO-8601')
    try:
        parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if parsed.tzinfo != timezone.utc:
            raise ValueError('not UTC')
    except ValueError as error:
        raise ReplicaError('invalid metadata UTC timestamp') from error


def completed(path, supported_sources):
    for name in ('integrity.json', 'completion.json'):
        target = path/name
        reject_links(target)
        if not target.is_file() or target.stat().st_size > 16*1024*1024:
            raise ReplicaError(f'invalid/oversized completed metadata: {target}')
    identity = (file_sha(path/'completion.json'), file_sha(path/'integrity.json'))
    completion, inventory = completed_export(path, supported_sources)
    timestamp(completion['validatedAtUtc'])
    if list(inventory) != ['kind', 'schemaVersion', 'generationId', 'files'] or any(list(entry) != ['path', 'size', 'sha256'] for entry in inventory['files']):
        raise ReplicaError('integrity object is not in reviewed canonical key order')
    paths = {entry['path'] for entry in inventory['files']}
    if not {'region_manifest.json', 'Polygons/manifest.json'}.issubset(paths) or 'tool_manifest.json' in paths:
        raise ReplicaError('integrity must contain the manifest pair and exclude tool-only metadata')
    if identity != (file_sha(path/'completion.json'), file_sha(path/'integrity.json')):
        raise ReplicaError('incoming metadata changed while observing completion')
    return completion, inventory, identity


def independent_copy(source, target):
    reject_links(source)
    reject_links(target)
    # A new inode, never a writable hard link. NoFollow rejects a final-component
    # swap; before/after identity checks detect replacement/truncation mid-copy.
    descriptor = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, 'rb') as incoming:
        before = os.fstat(incoming.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise ReplicaError(f'non-regular incoming file: {source}')
        with target.open('xb') as captured:
            shutil.copyfileobj(incoming, captured, length=1024*1024)
            captured.flush()
            os.fsync(captured.fileno())
        after = os.fstat(incoming.fileno())
        if (before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns) or source.stat().st_ino != before.st_ino:
            raise ReplicaError(f'incoming file changed during independent capture: {source}')
    reject_links(source)


def validation_result(value, inventory):
    if not isinstance(value, dict) or set(value) != {'checks', 'diagnostics', 'inventorySha256'} or value['inventorySha256'] != digest(inventory):
        raise ReplicaError('validation result does not bind exact inventory')
    if not isinstance(value['checks'], list) or not isinstance(value['diagnostics'], list) or not all(isinstance(item, str) for item in value['diagnostics']):
        raise ReplicaError('invalid validation result checks/diagnostics')
    passed = set()
    for check in value['checks']:
        if not isinstance(check, dict) or set(check) != {'path', 'checkId', 'result'} or check['result'] != 'passed':
            raise ReplicaError('validation result has a failed/skipped required check')
        passed.add((check['path'], check['checkId']))
    required = {('region_manifest.json', 'manifest-paths-v1'),
                ('Polygons/manifest.json', 'manifest-paths-v1'),
                ('region_manifest.json', 'peak-fingerprints-v1')}
    required.update((entry['path'], 'sha256-v1') for entry in inventory['files'])
    if not required.issubset(passed):
        raise ReplicaError('validation result omitted required manifest/integrity/fingerprint checks')
    return value


class DatasetValidator:
    """Runs the shared production profile against the peer's exact inventory.

    Installed callers supply a pinned executable vector/cwd; checkout defaults
    are explicit maintainer development only. No ObjectBox or canonical fallback.
    """
    def __init__(self, controller, *, command=None, cwd=None, timeout=7200):
        self.controller = controller
        installed = installed_commands()
        if installed:
            root, dataset, _ = installed
            command = command or dataset
            cwd = cwd or root
        self.command = list(command or ['dart', 'run', 'tool/mapping_source_dataset.dart'])
        self.cwd = str(Path(cwd or Path(__file__).resolve().parents[1]).resolve())
        self.timeout = timeout

    def progress(self, *, unknown=False):
        operation = self.controller.operation()
        if unknown:
            operation['state'] = 'outcome-unknown'
        operation['progressAtUtc'] = utc()
        self.controller.save_operation(operation)

    def validate(self, payload, inventory):
        output = bounded_process(self.command + ['validate'],
            input_text=json.dumps(dict(root=str(payload), generationId=inventory['generationId'], integrity=inventory)),
            cwd=self.cwd, pass_fds=tuple(self.controller._fds), timeout=self.timeout,
            on_unknown=lambda: self.progress(unknown=True), on_progress=self.progress)
        return json.loads(output)


class Replica:
    error_type = ReplicaError
    def __init__(self, base, *, lock_wait=5, release_id=DEVELOPMENT_CONTROLLER_ID,
                 compatible_sources=(), compatible_controllers=(), publish=atomic_json,
                 available_bytes=None, copy=independent_copy):
        self.base = Path(base).resolve()
        check_layout(self.base, workspace_roots())
        self.base.mkdir(parents=True, exist_ok=True)
        self.lock_wait = lock_wait
        self.release_id = require_uuid(release_id)
        self.sources = {DEVELOPMENT_RELEASE_ID, *compatible_sources}
        self.controllers = {self.release_id, DEVELOPMENT_CONTROLLER_ID, *compatible_controllers}
        self._fds = []
        self._children = []
        self.publish = publish
        self.available_bytes = available_bytes or (lambda: shutil.disk_usage(self.base).free)
        self.copy = copy

    def operation(self):
        return self.local_record(self.base/'operation.json', 'mapping-operation', OPERATION_FIELDS)

    def local_record(self, path, kind, fields):
        self.local_path(path)
        if not path.is_file() or path.stat().st_size > 16*1024*1024:
            raise ReplicaError(f'invalid/oversized local metadata: {path}')
        value = check_record(read_json(path), kind, fields)
        for key, item in value.items():
            if key.endswith('Sha256') and item is not None:
                if not isinstance(item, str) or not re.fullmatch('[0-9a-f]{64}', item):
                    raise ReplicaError(f'invalid metadata SHA-256: {path}:{key}')
            if key in {'operationId', 'generationId', 'receiptId', 'controllerRelease', 'validatorRelease', 'releaseId', 'publicationId', 'parentOperationId'} and item is not None:
                require_uuid(item)
            if key.endswith('AtUtc') and item is not None:
                timestamp(item)
        return value

    def local_path(self, path):
        if not path.is_relative_to(self.base) or path.is_relative_to(self.base/'incoming'):
            raise ReplicaError(f'local publication outside replica ownership: {path}')
        reject_links(path)
        return path

    def metadata(self, path, value):
        self.publish(self.local_path(path), value)

    def save_operation(self, operation):
        self.metadata(self.base/'operations'/f'{operation["operationId"]}.json', operation)
        self.metadata(self.base/'operation.json', operation)

    @contextlib.contextmanager
    def lock(self, name='pipeline', *, wait=None):
        target = self.local_path(self.base/'locks'/f'{name}.lock')
        target.parent.mkdir(exist_ok=True)
        reject_links(target)
        with target.open('a+b') as stream:
            deadline = time.monotonic() + (self.lock_wait if wait is None else wait)
            while True:
                try:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise ReplicaError(f'replica busy: {target}; inspect owning operation')
                    time.sleep(.05)
            self._fds.append(stream.fileno())
            try:
                yield
            finally:
                self._fds.remove(stream.fileno())
                # Closing our descriptor does not unlock a surviving child's
                # inherited descriptor. Never unlink a lifetime lock to recover.

    def cleanup(self):
        from mapping_retention import cleanup_replica
        try:
            return cleanup_replica(self)
        except SourceError as error:
            raise ReplicaError(f'stage=cleanup local={self.base}: {error}') from error

    def audit_space(self, inventory, *, stage, incoming_remaining_bytes=None, operation_id=None):
        from mapping_retention import audit_space
        try:
            return audit_space(self.base, inventory, stage=stage,
                available_bytes=self.available_bytes, incoming_remaining_bytes=incoming_remaining_bytes,
                operation_id=operation_id, publish=self.metadata)
        except SourceError as error:
            raise ReplicaError(str(error)) from error

    def acknowledge(self, generation, *, send):
        """send uses Item 08's bounded transport; exact peer echo is required.

        Retain capture/evidence until the source's durable acknowledgement is
        confirmed. A lost response retries the same receipt, never a new ID.
        """
        require_uuid(generation)
        with self.lock(), self.lock('selection-retention'):
            try:
                target = self.local_path(self.base/'acknowledgements'/f'{generation}.json')
                if target.exists():
                    confirmed = self.local_record(target, 'mapping-durable-receipt', RECEIPT_FIELDS)
                    receipt = self.receipt(generation) if (self.base/'generations'/generation).exists() else self.local_record(
                        self.base/'receipts'/f'{generation}.json', 'mapping-durable-receipt', RECEIPT_FIELDS)
                    if confirmed != receipt or receipt['generationId'] != generation or receipt['controllerRelease'] not in self.controllers:
                        raise ReplicaError('conflicting source acknowledgement')
                    return receipt
                receipt = self.receipt(generation)
                response = send(receipt)
                if response != receipt:
                    raise ReplicaError('source did not confirm the exact durable receipt')
                self.metadata(target, receipt)
                self.metadata(self.base/'logs'/'receipt.json', dict(stage='receipt', generationId=generation,
                    operationId=receipt['operationId'], receiptId=receipt['receiptId'], state='acknowledged',
                    local=str(self.base/'generations'/generation), observedAtUtc=utc()))
                return receipt
            except Exception as error:
                diagnostic = f'stage=receipt generation={generation} local={self.base/"generations"/generation}: {error}'
                self.metadata(self.base/'logs'/'receipt.json', dict(stage='receipt', generationId=generation,
                    state='acknowledgement-unconfirmed', diagnostic=diagnostic, observedAtUtc=utc()))
                raise ReplicaError(diagnostic) from error

    def capture(self, generation, *, transfer_complete, validate=None, operation_id=None):
        with self.lock(), self.lock('release-' + self.release_id):
            return self._capture(generation, transfer_complete=transfer_complete,
                                 validate=validate or DatasetValidator(self).validate, operation_id=operation_id)

    def start_capture(self, generation, *, transfer_complete, operation_id=None,
                      dataset_command=None, dataset_cwd=None):
        require_uuid(generation)
        operation_id = require_uuid(operation_id or str(uuid.uuid4()))
        with self.lock(), self.lock('release-' + self.release_id):
            if (self.base/'operation.json').exists() and self.operation()['state'] in ('running', 'outcome-unknown'):
                raise ReplicaError('prior operation outcome unresolved; reconcile before dispatch')
            request_path = self.local_path(self.base/'requests'/f'{operation_id}.json')
            if request_path.exists() or (self.base/'operations'/f'{operation_id}.json').exists():
                raise ReplicaError('operation identity already exists; do not replay')
            validator = DatasetValidator(self, command=dataset_command, cwd=dataset_cwd)
            self.metadata(request_path, dict(operationId=operation_id, generationId=generation,
                transferComplete=transfer_complete is True, datasetCommand=validator.command, datasetCwd=validator.cwd))
            log_path = self.local_path(self.base/'logs'/f'{operation_id}.log')
            log_path.parent.mkdir(exist_ok=True)
            with log_path.open('xb') as log:
                command = [sys.executable, str(Path(__file__).resolve()), '--base', str(self.base),
                    '--release-id', self.release_id, '--operation', operation_id,
                    *[arg for value in sorted(self.sources) for arg in ('--compatible-source-release', value)],
                    *[arg for value in sorted(self.controllers) for arg in ('--compatible-controller-release', value)],
                    '--worker', 'capture', generation]
                process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                    start_new_session=True, pass_fds=release_fds(self._fds),
                    env=dict(os.environ, MAPPING_REPLICA_FDS=json.dumps(self._fds)))
                self._children.append(process)
            return dict(status='accepted', operationId=operation_id, log=str(log_path))

    def status(self, operation_id=None):
        if operation_id is not None:
            require_uuid(operation_id)
        path = self.base/'operations'/f'{operation_id}.json' if operation_id else self.base/'operation.json'
        operation = self.local_record(path, 'mapping-operation', OPERATION_FIELDS) if path.exists() else None
        owned = False
        try:
            with Replica(self.base, lock_wait=0).lock():
                pass
        except ReplicaError:
            owned = True
        self._children = [child for child in self._children if child.poll() is None]
        from mapping_retention import policy_status
        return dict(operation=operation, supervisorOrChildOwnsPipeline=owned,
            lastPolicyReports=policy_status(self.base))

    def _capture(self, generation, *, transfer_complete, validate, operation_id=None):
        require_uuid(generation)
        previous = self.base/'operation.json'
        if previous.exists() and self.operation()['state'] in ('running', 'outcome-unknown'):
            raise ReplicaError('prior operation outcome unresolved; inspect/reconcile its exact operation ID')
        operation_id = require_uuid(operation_id or str(uuid.uuid4()))
        if (self.base/'operations'/f'{operation_id}.json').exists():
            raise ReplicaError('operation identity already exists; inspect/reconcile, do not replay')
        operation = record('mapping-operation', operationId=operation_id,
            parentOperationId=None, owner=owner(), releaseId=self.release_id, stage='transfer',
            state='running', generationId=generation, publicationId=None,
            protectedExportIds=[generation], protectedGenerationIds=[generation],
            startedAtUtc=utc(), progressAtUtc=utc(), outcomeRecordSha256=None)
        self.save_operation(operation)
        export = self.base/'incoming'/generation
        candidate = self.local_path(self.base/'candidates'/operation['operationId'])
        inventory = None
        try:
            if transfer_complete is not True:
                raise ReplicaError('transfer has not completed')
            completion, inventory, raw_identity = completed(export, self.sources)
            completion_sha = raw_identity[0]
            incoming_identity = (digest(completion), digest(inventory), *raw_identity)
            if (self.base/'eligibility'/f'{generation}.json').exists():
                existing = self.eligible(generation)
                if existing['inventorySha256'] != digest(inventory) or existing['sourceCompletionSha256'] != completion_sha:
                    raise ReplicaError('completed generation identity has changed; use a new generation ID')
                operation.update(state='succeeded', outcomeRecordSha256=digest(existing), progressAtUtc=utc())
                self.save_operation(operation)
                return existing
            operation.update(stage='capture', publicationId=completion['publicationId'])
            self.save_operation(operation)
            self.audit_space(inventory, stage='capture', incoming_remaining_bytes=0, operation_id=operation_id)
            payload = candidate/'payload'
            for entry in inventory['files']:
                target = self.local_path(payload/entry['path'])
                target.parent.mkdir(parents=True, exist_ok=True)
                self.copy(export/'payload'/entry['path'], target)
            self.verify_bytes(payload, inventory)
            operation.update(stage='validate', progressAtUtc=utc())
            self.save_operation(operation)
            validation = validation_result(validate(payload, inventory), inventory)
            self.verify_bytes(payload, inventory)
            current_completion, current_inventory, current_identity = completed(export, self.sources)
            if incoming_identity != (digest(current_completion), digest(current_inventory),
                    *current_identity):
                raise ReplicaError('incoming completion/inventory changed during capture/validation')
            report = record('mapping-validation-report', generationId=generation,
                inventorySha256=digest(inventory), operationId=operation['operationId'],
                validationProfile=PROFILE, validatorRelease=self.release_id, state='passed',
                checks=validation['checks'], diagnostics=validation['diagnostics'], validatedAtUtc=utc())
            if len(json.dumps(report, separators=(',', ':'), ensure_ascii=False).encode()) > 16*1024*1024:
                raise ReplicaError('validation evidence exceeds the 16 MiB reader limit; aggregate identical diagnostics or inspect distinct failures before retry')
            self.copy(export/'integrity.json', candidate/'integrity.json')
            self.copy(export/'completion.json', candidate/'completion.json')
            if file_sha(candidate/'completion.json') != completion_sha or file_sha(candidate/'integrity.json') != incoming_identity[3]:
                raise ReplicaError('incoming metadata changed during metadata capture')
            self.metadata(candidate/'validation.json', report)
            freeze_export(candidate)
            final = self.local_path(self.base/'generations'/generation)
            final.parent.mkdir(exist_ok=True)
            os.rename(candidate, final)
            final.chmod(0o555)
            sync_directory(final.parent)
            eligibility = record('mapping-eligibility', generationId=generation,
                inventorySha256=digest(inventory), sourceCompletionSha256=completion_sha,
                validationReportSha256=file_sha(final/'validation.json'), controllerRelease=self.release_id,
                validationProfile=PROFILE, eligibleAtUtc=utc())
            self.metadata(self.base/'eligibility'/f'{generation}.json', eligibility)
            operation.update(stage='receipt', progressAtUtc=utc())
            self.save_operation(operation)
            receipt = record('mapping-durable-receipt', receiptId=str(uuid.uuid4()),
                operationId=operation['operationId'], generationId=generation,
                inventorySha256=digest(inventory), sourceCompletionSha256=completion_sha,
                localValidationReportSha256=eligibility['validationReportSha256'],
                controllerRelease=self.release_id, storedAtUtc=utc())
            self.metadata(self.base/'receipts'/f'{generation}.json', receipt)
            operation.update(state='succeeded', stage='receipt', progressAtUtc=utc(),
                outcomeRecordSha256=digest(eligibility))
            self.save_operation(operation)
            return eligibility
        except BaseException as error:
            diagnostic = (f'stage={operation["stage"]} operation={operation["operationId"]} '
                f'generation={generation} incoming={export} candidate={candidate} '
                f'local={self.base/"generations"/generation}: {error}')
            operation.update(state='failed', progressAtUtc=utc())
            try:
                self.save_operation(operation)
                if inventory is not None:
                    self.metadata(self.base/'failures'/f'{operation["operationId"]}.json',
                        record('mapping-validation-report', generationId=generation,
                            inventorySha256=digest(inventory), operationId=operation['operationId'],
                            validationProfile=PROFILE, validatorRelease=self.release_id, state='failed',
                            checks=[], diagnostics=[diagnostic], validatedAtUtc=utc()))
            except Exception as publication_error:
                diagnostic += f'; failure-state publication also failed: {publication_error}'
            print(diagnostic, file=sys.stderr, flush=True)
            raise ReplicaError(diagnostic) from error

    def verify_bytes(self, payload, inventory):
        actual = set()
        for root, directories, files in os.walk(payload, followlinks=False):
            for name in directories:
                reject_links(Path(root)/name)
            for name in files:
                path = Path(root)/name
                reject_links(path)
                actual.add(path.relative_to(payload).as_posix())
        if actual != {entry['path'] for entry in inventory['files']}:
            raise ReplicaError(f'captured exact path set differs from inventory: {payload}')
        for entry in inventory['files']:
            path = payload/entry['path']
            if not stat.S_ISREG(path.stat().st_mode) or path.stat().st_nlink != 1:
                raise ReplicaError(f'non-independent captured file: {path}')
            if path.stat().st_size != entry['size'] or file_sha(path) != entry['sha256']:
                raise ReplicaError(f'captured size/SHA-256 mismatch: {path}')

    def eligible(self, generation):
        require_uuid(generation)
        value = self.local_record(self.base/'eligibility'/f'{generation}.json',
                             'mapping-eligibility', ELIGIBILITY_FIELDS)
        final = self.base/'generations'/generation
        completion, inventory, _ = completed(final, self.sources)
        report = self.local_record(final/'validation.json', 'mapping-validation-report', VALIDATION_FIELDS)
        if value['generationId'] != generation or value['inventorySha256'] != digest(inventory) or value['sourceCompletionSha256'] != file_sha(final/'completion.json'):
            raise ReplicaError('eligibility source/inventory identity mismatch')
        if value['validationReportSha256'] != file_sha(final/'validation.json') or report['generationId'] != generation or report['inventorySha256'] != value['inventorySha256'] or report['state'] != 'passed':
            raise ReplicaError('eligibility validation identity mismatch')
        if value['controllerRelease'] not in self.controllers or report['validatorRelease'] not in self.controllers or value['validationProfile'] != PROFILE or report['validationProfile'] != PROFILE:
            raise ReplicaError('unsupported eligibility/validation release/profile')
        require_uuid(report['operationId'])
        operation = self.local_record(self.base/'operations'/f'{report["operationId"]}.json',
                                 'mapping-operation', OPERATION_FIELDS)
        if operation['operationId'] != report['operationId'] or operation['releaseId'] != report['validatorRelease'] or operation['state'] != 'succeeded' or operation['generationId'] != generation or operation['outcomeRecordSha256'] != digest(value):
            raise ReplicaError('no successful durable publication outcome for eligibility')
        expected = {'integrity.json', 'completion.json', 'validation.json'} | {'payload/' + entry['path'] for entry in inventory['files']}
        actual = set()
        for root, directories, files in os.walk(final, followlinks=False):
            for path in [Path(root), *[Path(root)/name for name in directories + files]]:
                reject_links(path)
                observed = path.stat()
                if observed.st_mode & 0o222 or not (stat.S_ISREG(observed.st_mode) or stat.S_ISDIR(observed.st_mode)) or stat.S_ISREG(observed.st_mode) and observed.st_nlink != 1:
                    raise ReplicaError(f'published generation is not immutable/independent: {path}')
                if stat.S_ISREG(observed.st_mode):
                    actual.add(path.relative_to(final).as_posix())
        if actual != expected:
            raise ReplicaError(f'published generation is incomplete or has unexpected files: {final}')
        for entry in inventory['files']:
            if (final/'payload'/entry['path']).stat().st_size != entry['size']:
                raise ReplicaError(f'published generation file size changed: {entry["path"]}')
        return value

    def receipt(self, generation):
        value = self.eligible(generation)
        receipt = self.local_record(self.base/'receipts'/f'{generation}.json',
                               'mapping-durable-receipt', RECEIPT_FIELDS)
        report = read_json(self.base/'generations'/generation/'validation.json')
        if receipt['operationId'] != report['operationId'] or receipt['generationId'] != generation or receipt['inventorySha256'] != value['inventorySha256'] or receipt['sourceCompletionSha256'] != value['sourceCompletionSha256'] or receipt['localValidationReportSha256'] != value['validationReportSha256'] or receipt['controllerRelease'] != value['controllerRelease']:
            raise ReplicaError('durable receipt identity mismatch')
        require_uuid(receipt['receiptId'])
        return receipt

    def reconcile(self, operation_id):
        require_uuid(operation_id)
        with self.lock():
            operation = self.local_record(self.base/'operations'/f'{operation_id}.json',
                                     'mapping-operation', OPERATION_FIELDS)
            if self.operation()['operationId'] != operation_id:
                raise ReplicaError('reconciliation must inspect the current unresolved operation identity')
            if operation['state'] in ('running', 'outcome-unknown'):
                operation.update(state='failed', progressAtUtc=utc())
            self.save_operation(operation)
            return operation


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', type=Path, required=True)
    parser.add_argument('--operation', type=require_uuid)
    parser.add_argument('--lock-wait', type=float, default=5)
    parser.add_argument('--release-id', type=require_uuid, default=DEVELOPMENT_CONTROLLER_ID)
    parser.add_argument('--compatible-source-release', type=require_uuid, action='append', default=[])
    parser.add_argument('--compatible-controller-release', type=require_uuid, action='append', default=[])
    parser.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    subcommands = parser.add_subparsers(dest='command', required=True)
    capture = subcommands.add_parser('capture')
    capture.add_argument('generation', type=require_uuid)
    capture.add_argument('--transfer-complete', action='store_true')
    capture.add_argument('--dataset-executable', type=Path)
    for name in ('eligible', 'receipt'):
        subcommands.add_parser(name).add_argument('generation', type=require_uuid)
    subcommands.add_parser('status')
    subcommands.add_parser('reconcile')
    subcommands.add_parser('cleanup')
    space = subcommands.add_parser('space', help='audit a completed integrity inventory supplied on stdin')
    space.add_argument('--stage', choices=['provision', 'refresh'], default='refresh')
    space.add_argument('--incoming-remaining-bytes', type=int)
    arguments = parser.parse_args()
    controller = Replica(arguments.base, lock_wait=arguments.lock_wait, release_id=arguments.release_id,
        compatible_sources=arguments.compatible_source_release,
        compatible_controllers=arguments.compatible_controller_release)
    if arguments.worker:
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        descriptors = json.loads(os.environ['MAPPING_REPLICA_FDS'])
        # The parent hands the pipeline and release lifetime locks to this
        # detached supervisor; its validator children inherit both too.
        for descriptor, name in zip(descriptors, ['pipeline', 'release-' + controller.release_id], strict=True):
            if os.fstat(descriptor).st_ino != (controller.base/'locks'/f'{name}.lock').stat().st_ino:
                raise ReplicaError('invalid inherited replica ownership descriptor')
        controller._fds.extend(descriptors)
        request = read_json(controller.base/'requests'/f'{arguments.operation}.json')
        validator = DatasetValidator(controller, command=request['datasetCommand'], cwd=request['datasetCwd'])
        print(f'operation={arguments.operation} generation={arguments.generation} release={controller.release_id}', flush=True)
        result = controller._capture(arguments.generation, transfer_complete=request['transferComplete'],
            validate=validator.validate, operation_id=arguments.operation)
    elif arguments.command == 'capture':
        result = controller.start_capture(arguments.generation, transfer_complete=arguments.transfer_complete,
            operation_id=arguments.operation,
            dataset_command=[str(arguments.dataset_executable.resolve())] if arguments.dataset_executable else None)
    elif arguments.command == 'status':
        result = controller.status(arguments.operation)
    elif arguments.command == 'reconcile':
        if not arguments.operation:
            raise ReplicaError('reconcile requires the original --operation UUID')
        result = controller.reconcile(arguments.operation)
    elif arguments.command == 'cleanup':
        result = controller.cleanup()
    elif arguments.command == 'space':
        with controller.lock():
            result = controller.audit_space(decode_json(sys.stdin.read()), stage=arguments.stage,
                incoming_remaining_bytes=arguments.incoming_remaining_bytes, operation_id=arguments.operation)
    elif arguments.command == 'receipt':
        result = controller.receipt(arguments.generation)
    else:
        result = controller.eligible(arguments.generation)
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'local replica operation failed: {error}', file=sys.stderr, flush=True)
        sys.exit(1)
