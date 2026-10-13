"""Non-store controller cleanup and storage accounting, never app-launch work.

All callers hold pipeline ownership, plus selection-retention for app metadata
or dispatch/prepare/publication for source exports. No lock inode is removed.
"""
import os
import re
import shutil
import stat
from datetime import datetime
from pathlib import Path

from mapping_source import (SourceError, OPERATION_FIELDS, check_record, completed_export, read_json,
    require_uuid, sync_directory, utc)

RESERVE_BYTES = 64*1024*1024
SELECTION_FIELDS = {'selectionId', 'active', 'recovery', 'revision', 'selectedAtUtc'}
SESSION_FIELDS = {'sessionId', 'owner', 'generationId', 'inventorySha256', 'appReaderRelease'}


def policy_status(base):
    result = {}
    for name in ('cleanup', 'space', 'receipt', 'source-production'):
        path = base/'logs'/f'{name}.json'
        reject_links(path)
        if path.exists():
            if path.stat().st_size > 16*1024*1024:
                raise SourceError(f'oversized policy diagnostic: {path}')
            result[name] = read_json(path)
    return result


def storage_accounting(base):
    """Observed bytes, not historical dataset size or CoW savings assumptions."""
    result = {}
    for folder in ('incoming', 'candidates', 'generations', 'prepared', 'captures',
                   'releases', 'backups', 'publication-validation'):
        path = base/folder
        reject_links(path)
        logical = allocated = files = 0
        identities = {}
        for root, directories, names in os.walk(path, followlinks=False):
            for name in directories + names:
                target = Path(root)/name
                reject_links(target)
                observed = target.stat()
                if not (stat.S_ISDIR(observed.st_mode) or stat.S_ISREG(observed.st_mode)):
                    raise SourceError(f'non-regular space audit operand: {target}')
                if stat.S_ISREG(observed.st_mode):
                    logical += observed.st_size
                    allocated += observed.st_blocks*512
                    files += 1
                    identity = target.relative_to(path).parts[0]
                    entry = identities.setdefault(identity, dict(logicalBytes=0, allocatedBytes=0, fileCount=0))
                    entry['logicalBytes'] += observed.st_size
                    entry['allocatedBytes'] += observed.st_blocks*512
                    entry['fileCount'] += 1
        result[folder] = dict(logicalBytes=logical, allocatedBytes=allocated, fileCount=files, byIdentity=identities)
    return result


def audit_space(base, inventory, *, stage, available_bytes, incoming_remaining_bytes=None,
                source_capture=False, operation_id=None, publish):
    check_record(inventory, 'mapping-integrity', {'generationId', 'files'})
    require_uuid(inventory['generationId'])
    files = inventory['files']
    if not isinstance(files, list) or any(not isinstance(entry, dict) or set(entry) != {'path', 'size', 'sha256'} or type(entry['size']) is not int or entry['size'] < 0 for entry in files):
        raise SourceError('invalid space inventory sizes')
    size = sum(entry['size'] for entry in files)
    if incoming_remaining_bytes is not None and (type(incoming_remaining_bytes) is not int or not 0 <= incoming_remaining_bytes <= size):
        raise SourceError('invalid transport remaining-byte count')
    planned = dict(independentCapture=size) if source_capture else dict(
        incoming=size if incoming_remaining_bytes is None else incoming_remaining_bytes, independentCapture=size)
    existing = storage_accounting(base)
    free = available_bytes()
    if type(free) is not int or free < 0:
        raise SourceError('invalid available disk space observation')
    additional = sum(planned.values())
    enough = free >= additional + RESERVE_BYTES
    diagnostic = (f'stage={stage} operation={operation_id} generation={inventory["generationId"]} local={base} '
        f'{"sufficient" if enough else "insufficient"} space: available={free} additional={additional} '
        f'reserve={RESERVE_BYTES} planned={planned}')
    result = dict(stage=stage, operationId=operation_id, generationId=inventory['generationId'],
        local=str(base), observedAtUtc=utc(), datasetBytes=size, plannedBytes=planned,
        additionalBytes=additional, reserveBytes=RESERVE_BYTES, availableBytes=free,
        existing=existing, state='sufficient' if enough else 'insufficient', diagnostic=diagnostic)
    publish(base/'logs'/'space.json', result)
    if not enough:
        raise SourceError(diagnostic)
    return result


def checked_selection(value):
    check_record(value, 'mapping-selection', SELECTION_FIELDS)
    require_uuid(value['selectionId'])
    if type(value['revision']) is not int or value['revision'] < 1:
        raise SourceError('invalid selection revision')
    for name in ('active', 'recovery'):
        entry = value[name]
        if name == 'recovery' and entry is None:
            continue
        if not isinstance(entry, dict) or set(entry) != {'generationId', 'inventorySha256', 'eligibilitySha256'}:
            raise SourceError('invalid selected generation entry')
        require_uuid(entry['generationId'])
        for key in ('inventorySha256', 'eligibilitySha256'):
            if not isinstance(entry[key], str) or not re.fullmatch('[0-9a-f]{64}', entry[key]):
                raise SourceError('invalid selected generation digest')
    return value


def children(path):
    reject_links(path)
    return sorted(path.iterdir()) if path.exists() else []


def reject_links(path):
    for part in [path, *path.parents]:
        if part.is_symlink():
            raise SourceError(f'cleanup/accounting path contains symlink: {part}')


def remove_tree(path):
    """Only an already-unprotected owned tree; never follow links or hardlinks."""
    reject_links(path)
    for root, directories, files in os.walk(path, followlinks=False):
        for name in directories + files:
            target = Path(root)/name
            reject_links(target)
            mode = target.stat()
            if not (stat.S_ISREG(mode.st_mode) or stat.S_ISDIR(mode.st_mode)):
                raise SourceError(f'non-regular cleanup operand: {target}')
            if stat.S_ISREG(mode.st_mode) and mode.st_nlink != 1:
                raise SourceError(f'cleanup operand is hardlinked: {target}')
    # Frozen captures are readonly. Only directories need write permission for
    # deletion; do not change payload file contents/modes or an outside inode.
    for root, _, _ in os.walk(path):
        Path(root).chmod(0o755)
    shutil.rmtree(path)
    sync_directory(path.parent)


def operation_records(base, compatible_releases=None):
    operations = {}
    for path in children(base/'operations'):
        require_uuid(path.stem)
        reject_links(path)
        operation = check_record(read_json(path), 'mapping-operation', OPERATION_FIELDS)
        if operation['operationId'] != path.stem or operation['state'] not in ('running', 'outcome-unknown', 'succeeded', 'failed'):
            raise SourceError(f'invalid operation identity/state: {path}')
        if operation['stage'] not in ('prepare', 'transfer', 'capture', 'validate', 'receipt', 'cleanup'):
            raise SourceError(f'unsupported operation stage: {path}')
        require_uuid(operation['releaseId'])
        if compatible_releases is not None and operation['releaseId'] not in compatible_releases:
            raise SourceError(f'unsupported operation release: {path}')
        for key in ('protectedGenerationIds', 'protectedExportIds'):
            if not isinstance(operation[key], list):
                raise SourceError(f'invalid operation protections: {path}')
            for identity in operation[key]:
                require_uuid(identity)
        if operation['generationId'] is not None:
            require_uuid(operation['generationId'])
        operations[path.stem] = operation
    return operations


def acknowledged_export(coordinator, export):
    from mapping_replica import RECEIPT_FIELDS, file_sha, timestamp
    reject_links(export)
    for name in ('completion.json', 'integrity.json'):
        reject_links(export/name)
    completion, _ = completed_export(export, coordinator.supported_releases)
    target = coordinator.base/'receipts'/f'{export.name}.json'
    reject_links(target)
    if not target.exists():
        return False
    receipt = check_record(read_json(target), 'mapping-durable-receipt', RECEIPT_FIELDS)
    for key in ('receiptId', 'operationId', 'generationId', 'controllerRelease'):
        require_uuid(receipt[key])
    timestamp(receipt['storedAtUtc'])
    if receipt['controllerRelease'] not in coordinator.supported_controllers:
        raise SourceError('unsupported durable receipt controller')
    if receipt['generationId'] != export.name or receipt['inventorySha256'] != completion['inventorySha256'] or receipt['sourceCompletionSha256'] != file_sha(export/'completion.json'):
        raise SourceError('durable receipt does not acknowledge this exact export')
    if not isinstance(receipt['localValidationReportSha256'], str) or not re.fullmatch('[0-9a-f]{64}', receipt['localValidationReportSha256']):
        raise SourceError('invalid durable validation digest')
    return True


def cleanup_source(coordinator, *, protected_export_ids):
    from mapping_replica import timestamp
    for identity in protected_export_ids:
        require_uuid(identity)
    with coordinator.publication_lock('dispatch'), coordinator.publication_lock('prepare'), coordinator.publication_lock():
        base = coordinator.base
        operations = operation_records(base, coordinator.supported_releases | coordinator.supported_controllers)
        unresolved = {identity: op for identity, op in operations.items() if op['state'] in ('running', 'outcome-unknown')}
        protected = {}
        def protect(identity, reason):
            protected.setdefault(identity, []).append(reason)
        for identity in protected_export_ids:
            protect(identity, 'live-transfer/operation')
        for identity, op in unresolved.items():
            for export in set(op['protectedExportIds']) | ({op['generationId']} if op['generationId'] else set()):
                protect(export, 'unresolved-operation:' + identity)
        exports = children(base/'prepared')
        order = {}
        for export in exports:
            for path in (export, export/'completion.json', export/'integrity.json'):
                reject_links(path)
            completion, _ = completed_export(export, coordinator.supported_releases)
            timestamp(completion['validatedAtUtc'])
            order[export.name] = (datetime.fromisoformat(completion['validatedAtUtc'].replace('Z', '+00:00')), export.name)
            if not acknowledged_export(coordinator, export):
                protect(export.name, 'awaits-durable-receipt')
        if exports:
            protect(max(order, key=order.get), 'current-completed-surface')
        captures = children(base/'captures')
        for capture in captures:
            require_uuid(capture.name)
            reject_links(capture)
        pruned = []
        abandoned = []
        protected_captures = {}
        for capture in captures:
            matching = [op for op in operations.values() if op['generationId'] == capture.name]
            if capture.name in protected or not matching or any(op['state'] in ('running', 'outcome-unknown') for op in matching):
                protected_captures[capture.name] = protected.get(capture.name, ['producer-ownership-unresolved'])
        result = dict(stage='cleanup', state='planned', observedAtUtc=utc(), protectedExports=protected,
            prunedExports=pruned, prunedCaptures=abandoned, unresolvedOperations=sorted(unresolved),
            protectedReleases=sorted({op['releaseId'] for op in unresolved.values()}), protectedCaptures=protected_captures,
            plannedExports=[export.name for export in exports if export.name not in protected],
            plannedCaptures=[capture.name for capture in captures if capture.name not in protected_captures])
        coordinator.metadata(base/'logs'/'cleanup.json', result)
        for export in exports:
            if export.name not in protected:
                remove_tree(export)
                pruned.append(export.name)
        for capture in captures:
            if capture.name in protected_captures:
                continue
            remove_tree(capture)
            abandoned.append(capture.name)
        result.update(state='complete', observedAtUtc=utc())
        coordinator.metadata(base/'logs'/'cleanup.json', result)
        return result


def cleanup_replica(controller):
    # Same lock order for receipt and cleanup. App launches only take selection.
    with controller.lock(), controller.lock('selection-retention'):
        base = controller.base
        protected = {}
        def protect(identity, reason):
            protected.setdefault(identity, []).append(reason)
        selection_path = base/'selection.json'
        selected = checked_selection(read_json(controller.local_path(selection_path))) if selection_path.exists() else None
        journal_path = controller.local_path(base/'selection-transaction.json')
        journal = None
        if journal_path.exists():
            journal = controller.local_record(journal_path, 'mapping-selection-transaction',
                {'operationId', 'priorSelection', 'nextSelection', 'state'})
            prior = checked_selection(journal['priorSelection']) if journal['priorSelection'] else None
            next_selection = checked_selection(journal['nextSelection'])
            if journal['state'] not in ('prepared', 'committed') or next_selection['revision'] != (prior['revision'] if prior else 0) + 1:
                raise SourceError('invalid retained selection transaction')
        # Validate every referenced entry before any deletion or journal retirement.
        from mapping_replica import file_sha
        for value in [selected, *( [prior, next_selection] if journal else [])]:
            if value is None:
                continue
            for name in ('active', 'recovery'):
                entry = value[name]
                if entry is None:
                    continue
                eligible = controller.eligible(entry['generationId'])
                if entry['inventorySha256'] != eligible['inventorySha256'] or entry['eligibilitySha256'] != file_sha(base/'eligibility'/f'{entry["generationId"]}.json'):
                    raise SourceError('selected eligibility binding changed; cleanup blocked')
        if selected:
            for name in ('active', 'recovery'):
                if selected[name]:
                    protect(selected[name]['generationId'], name)
        retired = journal is not None and journal['state'] == 'committed' and selected == next_selection
        if journal and not retired:
            for value in (prior, next_selection):
                if value:
                    for name in ('active', 'recovery'):
                        if value[name]:
                            protect(value[name]['generationId'], 'selection-transaction')
        # A session record is diagnostic. Only its held flock protects data; an
        # unreadable held record blocks cleanup rather than guessing its identity.
        for path in children(controller.local_path(base/'sessions')):
            require_uuid(path.stem)
            try:
                with controller.lock('session-' + path.stem, wait=0):
                    pass
            except controller.error_type as error:
                if 'replica busy:' not in str(error):
                    raise
                session = controller.local_record(path, 'mapping-session', SESSION_FIELDS)
                if session['sessionId'] != path.stem:
                    raise SourceError('session identity mismatch')
                protect(session['generationId'], 'live-session/native:' + path.stem)
        operations = operation_records(base, controller.controllers)
        unresolved = {identity: op for identity, op in operations.items() if op['state'] in ('running', 'outcome-unknown')}
        for identity, op in unresolved.items():
            for generation in set(op['protectedGenerationIds']) | ({op['generationId']} if op['generationId'] else set()):
                protect(generation, 'unresolved-operation:' + identity)
        eligible = {}
        invalid = {}
        for path in children(controller.local_path(base/'eligibility')):
            require_uuid(path.stem)
            try:
                eligible[path.stem] = controller.eligible(path.stem)
            except Exception as error:
                if 'unsupported' in str(error):
                    raise SourceError(f'unsupported generation metadata at {path}; cleanup blocked: {error}') from error
                invalid[path.stem] = str(error)
        order = lambda identity: (datetime.fromisoformat(eligible[identity]['eligibleAtUtc'].replace('Z', '+00:00')), identity)
        selected_ids = [selected[name]['generationId'] for name in ('active', 'recovery') if selected and selected[name]]
        threshold = max((order(identity) for identity in selected_ids), default=None)
        pending = [identity for identity in eligible if identity not in selected_ids and (threshold is None or order(identity) > threshold)]
        if pending:
            protect(max(pending, key=order), 'newest-pending')
        for identity in eligible:
            receipt = controller.receipt(identity)
            ack = controller.local_path(base/'acknowledgements'/f'{identity}.json')
            if not ack.exists():
                protect(identity, 'durable-receipt-awaits-source-acknowledgement')
            elif read_json(ack) != receipt:
                raise SourceError('conflicting local source acknowledgement; cleanup blocked')
        candidates = children(controller.local_path(base/'candidates'))
        generations = children(controller.local_path(base/'generations'))
        # Preflight every destructive operand, preserving unknown-version records.
        for path in candidates + generations:
            require_uuid(path.name)
            reject_links(path)
        # An incomplete directory without a reconciled producer is not proof of
        # abandonment. Requests can survive before a supervisor writes its record.
        for path in generations:
            if path.name not in eligible:
                matching = [op for op in operations.values() if op['generationId'] == path.name]
                if not matching or any(op['state'] in ('running', 'outcome-unknown') for op in matching):
                    protect(path.name, 'producer-ownership-unresolved')
        pruned = []
        abandoned = []
        pruned_eligibility = []
        existing_ids = {path.name for path in generations}
        orphaned = [identity for identity in invalid if identity not in existing_ids and identity not in protected
            and any(op['generationId'] == identity for op in operations.values())
            and all(op['state'] in ('succeeded', 'failed') for op in operations.values() if op['generationId'] == identity)]
        protected_candidates = {path.name: ['producer-ownership-unresolved' if path.name not in operations else 'unresolved-operation']
            for path in candidates if path.name not in operations or path.name in unresolved}
        result = dict(stage='cleanup', state='planned', observedAtUtc=utc(), protectedGenerations=protected,
            prunedGenerations=pruned, prunedCandidates=abandoned, rejectedEligibility=invalid,
            unresolvedOperations=sorted(unresolved), protectedReleases=sorted({op['releaseId'] for op in unresolved.values()}),
            retiredSelectionTransaction=retired, protectedCandidates=protected_candidates,
            plannedGenerations=[path.name for path in generations if path.name not in protected],
            plannedCandidates=[path.name for path in candidates if path.name not in protected_candidates],
            plannedOrphanedEligibility=orphaned, prunedEligibility=pruned_eligibility)
        controller.metadata(base/'logs'/'cleanup.json', result)
        if retired:
            journal_path.unlink()
            sync_directory(base)
        for path in generations:
            if path.name in protected:
                continue
            remove_tree(controller.local_path(path))
            metadata = controller.local_path(base/'eligibility'/f'{path.name}.json')
            metadata.unlink(missing_ok=True)
            if metadata.parent.exists():
                sync_directory(metadata.parent)
            pruned.append(path.name)
        for identity in orphaned:
            metadata = controller.local_path(base/'eligibility'/f'{identity}.json')
            metadata.unlink()
            sync_directory(metadata.parent)
            pruned_eligibility.append(identity)
        for path in candidates:
            op = operations.get(path.name)
            # Missing evidence and unknown work survive for Item 08 reconciliation.
            if op is None or path.name in unresolved:
                continue
            remove_tree(controller.local_path(path))
            abandoned.append(path.name)
        result.update(state='complete', observedAtUtc=utc())
        controller.metadata(base/'logs'/'cleanup.json', result)
        return result
