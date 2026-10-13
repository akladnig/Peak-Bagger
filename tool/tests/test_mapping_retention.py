"""Controller retention/receipt policy over disposable datasets and OS locks."""
import json
import subprocess
import shutil
import select
import sys
import uuid
import unittest

import test_mapping_replica as fixture

replica, source = fixture.replica, fixture.source


class RetentionTest(unittest.TestCase):
    setUp = fixture.ReplicaCaptureTest.setUp
    dispose = fixture.ReplicaCaptureTest.dispose
    write_export = fixture.ReplicaCaptureTest.write_export
    validate = fixture.ReplicaCaptureTest.validate
    capture = fixture.ReplicaCaptureTest.capture

    def generation_ready(self, number):
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        value = self.capture()
        # Deterministic eligibility ordering, including UUID tie-break coverage.
        value['eligibleAtUtc'] = f'2026-10-13T00:00:{number:02d}Z'
        self.controller.metadata(self.base/'eligibility'/f'{self.generation}.json', value)
        operation = self.controller.operation()
        operation['outcomeRecordSha256'] = source.digest(value)
        self.controller.save_operation(operation)
        receipt = self.controller.receipt(self.generation)
        self.controller.metadata(self.base/'acknowledgements'/f'{self.generation}.json', receipt)
        return self.generation

    def selection(self, active, recovery=None, revision=1):
        def entry(generation):
            value = self.controller.eligible(generation)
            return dict(generationId=generation, inventorySha256=value['inventorySha256'],
                eligibilitySha256=replica.file_sha(self.base/'eligibility'/f'{generation}.json'))
        value = source.record('mapping-selection', selectionId=str(uuid.uuid4()),
            active=entry(active), recovery=entry(recovery) if recovery else None,
            revision=revision, selectedAtUtc=source.utc())
        self.controller.metadata(self.base/'selection.json', value)
        return value

    def test_cleanup_keeps_active_one_recovery_and_newest_pending(self):
        superseded, recovery, active, older_pending, pending = [self.generation_ready(i) for i in range(5)]
        self.selection(active, recovery)
        result = self.controller.cleanup()
        self.assertEqual(set(p.name for p in (self.base/'generations').iterdir()), {active, recovery, pending})
        self.assertEqual(set(result['prunedGenerations']), {superseded, older_pending})
        self.assertIn('active', result['protectedGenerations'][active])
        self.assertIn('recovery', result['protectedGenerations'][recovery])
        self.assertEqual(self.controller.cleanup()['prunedGenerations'], [])
        self.assertEqual((self.export/'payload/DEM/tiny.tif').read_bytes(), self.files['DEM/tiny.tif'])

    def test_receipt_round_trip_retries_a_lost_acknowledgement_without_releasing_evidence(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0)
        mini.maintenance(lambda: None, lambda: 'a'*64)
        def capture(payload, generation):
            shutil.copytree(self.export/'payload', payload)
            return dict(self.inventory, generationId=generation)
        generation = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        self.generation = generation
        self.export = self.incoming/generation
        shutil.copytree(mini.base/'prepared'/generation, self.export)
        self.capture()
        expected = self.controller.receipt(generation)
        def lost(receipt):
            mini.acknowledge(receipt, protected_export_ids=set())
            raise OSError('lost SSH acknowledgement response')
        with self.assertRaisesRegex(replica.ReplicaError, 'stage=receipt.*lost SSH'):
            self.controller.acknowledge(generation, send=lost)
        self.assertFalse((self.base/'acknowledgements'/f'{generation}.json').exists())
        result = self.controller.cleanup()
        self.assertIn('durable-receipt-awaits-source-acknowledgement', result['protectedGenerations'][generation])
        self.assertTrue((mini.base/'prepared'/generation).exists())
        received = self.controller.acknowledge(generation,
            send=lambda receipt: mini.acknowledge(receipt, protected_export_ids=set()))
        self.assertEqual(received, expected)
        self.assertEqual(source.read_json(mini.base/'receipts'/f'{generation}.json'), expected)
        self.assertEqual(self.controller.acknowledge(generation, send=lambda _: self.fail('already acknowledged')), expected)

    def test_source_bounds_unacknowledged_production_then_prunes_only_acknowledged_old_export(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0)
        mini.maintenance(lambda: None, lambda: 'a'*64)
        captures = []
        def capture(payload, generation):
            captures.append(generation)
            shutil.copytree(self.export/'payload', payload)
            return dict(self.inventory, generationId=generation)
        first = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        self.generation = first
        self.export = self.incoming/first
        shutil.copytree(mini.base/'prepared'/first, self.export)
        self.capture()
        receipt = self.controller.receipt(first)
        mini.maintenance(lambda: None, lambda: 'b'*64)
        for _ in range(3):
            with self.assertRaisesRegex(source.SourceError, 'durable receipt'):
                mini.prepare(capture, lambda *_: self.fail('unacknowledged export bypassed'))
        self.assertEqual(len(captures), 1, 'blocked retries must not accumulate full scratch copies')
        blocked = source.read_json(mini.base/'logs'/'source-production.json')
        self.assertEqual(blocked['blockedExportId'], first)
        self.assertEqual(blocked['state'], 'blocked-awaiting-durable-receipt')
        self.assertIn(str(mini.base/'prepared'/first), blocked['diagnostic'])
        self.assertEqual(mini.cleanup(protected_export_ids=set())['prunedExports'], [])
        mini.acknowledge(receipt, protected_export_ids=set())
        self.assertEqual(mini.cleanup(protected_export_ids=set())['prunedExports'], [], 'current surface stays reusable')
        # New approved source bytes after the previous durable receipt.
        self.files['DEM/tiny.tif'] = b'new disposable source bytes'
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        second = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        result = mini.cleanup(protected_export_ids={first})
        self.assertEqual(result['state'], 'complete')
        self.assertIn('live-transfer/operation', result['protectedExports'][first])
        self.assertTrue((mini.base/'prepared'/first).exists())
        result = mini.cleanup(protected_export_ids=set())
        self.assertEqual(result['prunedExports'], [first])
        self.assertTrue((mini.base/'prepared'/second).exists())
        self.assertEqual(mini.acknowledge(receipt, protected_export_ids=set()), receipt, 'retry after pruning')
        self.assertEqual(mini.cleanup(protected_export_ids=set())['prunedExports'], [])

    def test_space_accounts_existing_storage_and_both_incoming_and_independent_copy(self):
        active = self.generation_ready(0)
        recovery = self.generation_ready(1)
        self.selection(active, recovery)
        (self.base/'candidates'/str(uuid.uuid4())).mkdir(parents=True)
        size = sum(entry['size'] for entry in self.inventory['files'])
        controller = replica.Replica(self.base, available_bytes=lambda: 64*1024*1024 + size)
        with self.assertRaisesRegex(replica.ReplicaError, 'stage=provision.*insufficient space'):
            controller.audit_space(self.inventory, stage='provision')
        report = source.read_json(self.base/'logs'/'space.json')
        self.assertEqual(report['additionalBytes'], 2*size)
        self.assertEqual(report['plannedBytes'], dict(incoming=size, independentCapture=size))
        self.assertGreaterEqual(report['existing']['generations']['logicalBytes'], 2*size)
        self.assertGreaterEqual(report['existing']['generations']['byIdentity'][active]['logicalBytes'], size)
        self.assertGreaterEqual(report['existing']['incoming']['logicalBytes'], 2*size)
        self.assertIn(str(self.base), report['diagnostic'])
        self.assertTrue((self.base/'generations'/active).exists())
        self.assertTrue((self.base/'generations'/recovery).exists())
        # Once the real transport reports remaining bytes, account only that
        # remainder; completed incoming still needs a full independent copy.
        result = controller.audit_space(self.inventory, stage='refresh', incoming_remaining_bytes=0)
        self.assertEqual(result['additionalBytes'], size)
        self.assertEqual(result['state'], 'sufficient')

    def test_unsupported_eligibility_blocks_destructive_cleanup_before_pruning(self):
        old, active, pending = [self.generation_ready(i) for i in range(3)]
        self.selection(active)
        path = self.base/'eligibility'/f'{pending}.json'
        value = source.read_json(path)
        value['schemaVersion'] = 2
        source.atomic_json(path, value)
        with self.assertRaisesRegex(replica.ReplicaError, 'unsupported'):
            self.controller.cleanup()
        self.assertTrue((self.base/'generations'/old).exists())
        self.assertTrue((self.base/'generations'/active).exists())
        self.assertTrue((self.base/'generations'/pending).exists())

    def test_session_pin_survives_ui_owner_and_cleanup_ignores_stale_pid_after_release(self):
        old, recovery, active, pending = [self.generation_ready(i) for i in range(4)]
        self.selection(active, recovery)
        identity = str(uuid.uuid4())
        value = source.record('mapping-session', sessionId=identity, owner=source.owner(),
            generationId=old, inventorySha256=self.controller.eligible(old)['inventorySha256'],
            appReaderRelease='e442ea38-fc1d-4ca0-b07d-223b01df6c35')
        self.controller.metadata(self.base/'sessions'/f'{identity}.json', value)
        with self.controller.lock('session-' + identity):
            result = self.controller.cleanup()
            self.assertIn('live-session/native:' + identity, result['protectedGenerations'][old])
            self.assertTrue((self.base/'generations'/old).exists())
        result = self.controller.cleanup()
        self.assertEqual(result['prunedGenerations'], [old])
        self.assertTrue((self.base/'sessions'/f'{identity}.json').exists(), 'stale record is not liveness')

    def test_committed_journal_retires_extra_recovery_but_prepared_intent_keeps_both_tuples(self):
        old, recovery, active, pending = [self.generation_ready(i) for i in range(4)]
        prior = self.selection(recovery, old, revision=1)
        next_selection = self.selection(active, recovery, revision=2)
        journal = source.record('mapping-selection-transaction', operationId=str(uuid.uuid4()),
            priorSelection=prior, nextSelection=next_selection, state='prepared')
        self.controller.metadata(self.base/'selection-transaction.json', journal)
        result = self.controller.cleanup()
        self.assertFalse(result['retiredSelectionTransaction'])
        self.assertIn('selection-transaction', result['protectedGenerations'][old])
        journal['state'] = 'committed'
        self.controller.metadata(self.base/'selection-transaction.json', journal)
        result = self.controller.cleanup()
        self.assertTrue(result['retiredSelectionTransaction'])
        self.assertEqual(result['prunedGenerations'], [old])
        self.assertFalse((self.base/'selection-transaction.json').exists())
        self.assertEqual(source.read_json(self.base/'selection.json'), next_selection)

    def test_unresolved_work_keeps_candidate_generation_release_until_reconciled(self):
        active = self.generation_ready(0)
        self.selection(active)
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        def invalid(*_):
            raise OSError('unfinished validation')
        with self.assertRaises(replica.ReplicaError):
            self.controller.capture(self.generation, transfer_complete=True, validate=invalid)
        operation = self.controller.operation()
        operation['state'] = 'outcome-unknown'
        self.controller.save_operation(operation)
        candidate = self.base/'candidates'/operation['operationId']
        result = self.controller.cleanup()
        self.assertTrue(candidate.exists())
        self.assertEqual(result['protectedReleases'], [self.controller.release_id])
        self.assertIn(operation['operationId'], result['unresolvedOperations'])
        self.controller.reconcile(operation['operationId'])
        result = self.controller.cleanup()
        self.assertEqual(result['prunedCandidates'], [operation['operationId']])
        self.assertFalse(candidate.exists())
        self.assertTrue((self.base/'generations'/active).exists())

    def test_cleanup_and_receipt_cannot_cross_surviving_child_or_selection_lock(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        with self.controller.lock('selection-retention'):
            with self.assertRaisesRegex(replica.ReplicaError, 'busy'):
                self.controller.cleanup()
        with self.controller.lock(), self.controller.lock('release-' + self.controller.release_id):
            child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'],
                pass_fds=tuple(self.controller._fds))
        try:
            with self.assertRaisesRegex(replica.ReplicaError, 'busy'):
                self.controller.cleanup()
            with self.assertRaisesRegex(replica.ReplicaError, 'busy'):
                self.controller.acknowledge(old, send=lambda _: self.fail('surviving child was bypassed'))
            self.assertTrue((self.base/'generations'/old).exists())
        finally:
            child.kill()
            child.wait(timeout=5)
        self.assertEqual(self.controller.cleanup()['prunedGenerations'], [old])

    def test_crashed_app_releases_session_pin_even_with_persistent_session_record(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        identity = str(uuid.uuid4())
        self.controller.metadata(self.base/'sessions'/f'{identity}.json', source.record('mapping-session',
            sessionId=identity, owner=source.owner(), generationId=old,
            inventorySha256=self.controller.eligible(old)['inventorySha256'],
            appReaderRelease='e442ea38-fc1d-4ca0-b07d-223b01df6c35'))
        child = subprocess.Popen([sys.executable, '-c',
            'import sys,fcntl,time; f=open(sys.argv[1],"a+b"); '
            'fcntl.flock(f,fcntl.LOCK_EX); print("owned",flush=True); time.sleep(30)',
            str(self.base/'locks'/f'session-{identity}.lock')], stdout=subprocess.PIPE)
        try:
            self.assertTrue(select.select([child.stdout], [], [], 5)[0], 'session owner did not start')
            self.assertEqual(child.stdout.readline().strip(), b'owned')
            self.assertEqual(self.controller.cleanup()['prunedGenerations'], [])
        finally:
            child.kill()
            child.wait(timeout=5)
            child.stdout.close()
        self.assertEqual(self.controller.cleanup()['prunedGenerations'], [old])

    def test_surviving_remote_outcome_blocks_duplicate_preparation_and_acknowledgement(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0)
        mini.maintenance(lambda: None, lambda: 'a'*64)
        def capture(payload, generation):
            shutil.copytree(self.export/'payload', payload)
            return dict(self.inventory, generationId=generation)
        generation = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        self.generation = generation
        self.export = self.incoming/generation
        shutil.copytree(mini.base/'prepared'/generation, self.export)
        self.capture()
        receipt = self.controller.receipt(generation)
        operation = mini.last_operation()
        operation['state'] = 'outcome-unknown'
        mini._save_operation(operation)
        with self.assertRaisesRegex(source.SourceError, 'unresolved'):
            mini.prepare(capture, lambda *_: self.fail('duplicate remote work'))
        with self.assertRaisesRegex(source.SourceError, 'unresolved'):
            mini.acknowledge(receipt, protected_export_ids=set())
        result = mini.cleanup(protected_export_ids=set())
        self.assertIn('unresolved-operation:' + operation['operationId'], result['protectedExports'][generation])
        self.assertEqual(result['protectedReleases'], [mini.release_id])
        self.assertEqual(mini.last_operation()['operationId'], operation['operationId'])

    def test_acknowledgement_rejects_mismatched_or_uncommitted_local_validation(self):
        generation = self.generation_ready(0)
        (self.base/'acknowledgements'/f'{generation}.json').unlink()
        receipt = self.controller.receipt(generation)
        with self.assertRaisesRegex(replica.ReplicaError, 'exact durable receipt'):
            self.controller.acknowledge(generation, send=lambda value: dict(value, sourceCompletionSha256='a'*64))
        self.assertFalse((self.base/'acknowledgements'/f'{generation}.json').exists())
        operation = self.controller.operation()
        operation['state'] = 'failed'
        self.controller.save_operation(operation)
        with self.assertRaisesRegex(replica.ReplicaError, 'durable publication outcome'):
            self.controller.acknowledge(generation, send=lambda _: self.fail('uncommitted capture sent a receipt'))
        self.assertTrue((self.base/'generations'/generation).exists())
        self.assertEqual(source.read_json(self.base/'receipts'/f'{generation}.json'), receipt)

    def test_confirmed_receipt_retry_remains_idempotent_after_local_generation_pruning(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        receipt = self.controller.receipt(old)
        self.selection(active)
        self.assertEqual(self.controller.cleanup()['prunedGenerations'], [old])
        self.assertEqual(self.controller.acknowledge(old, send=lambda _: self.fail('confirmed receipt resent')), receipt)

    def test_source_receipt_alias_cannot_publish_outside_its_non_store_owner(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0)
        mini.maintenance(lambda: None, lambda: 'a'*64)
        def capture(payload, generation):
            shutil.copytree(self.export/'payload', payload)
            return dict(self.inventory, generationId=generation)
        generation = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        self.generation = generation
        self.export = self.incoming/generation
        shutil.copytree(mini.base/'prepared'/generation, self.export)
        self.capture()
        outside = self.root/'not-source-state'
        outside.mkdir()
        (mini.base/'receipts').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(source.SourceError, 'symlink'):
            mini.acknowledge(self.controller.receipt(generation), protected_export_ids=set())
        self.assertEqual(list(outside.iterdir()), [])

    def test_mini_low_space_audit_blocks_capture_and_counts_retained_exports(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0, available_bytes=lambda: 0)
        shutil.copytree(self.export, mini.base/'prepared'/self.generation)
        script = self.root/'fake-dataset.py'
        calls = self.root/'dataset-calls.json'
        script.write_text('import json,sys\nfrom pathlib import Path\n'
            'json.load(sys.stdin)\nPath(sys.argv[1]).write_text(json.dumps(sys.argv[3:]))\n'
            'print(sys.argv[2])\n')
        bridge = source.DatasetBridge(mini, command=[sys.executable, str(script), str(calls), json.dumps(self.inventory)])
        with self.assertRaisesRegex(source.SourceError, 'stage=source-capture.*insufficient space'):
            bridge.capture(mini.base/'captures'/str(uuid.uuid4())/'payload', self.generation)
        report = source.read_json(mini.base/'logs'/'space.json')
        self.assertEqual(report['additionalBytes'], sum(file['size'] for file in self.inventory['files']))
        self.assertGreater(report['existing']['prepared']['logicalBytes'], 0)
        self.assertEqual(source.read_json(calls), ['inspect'])
        self.assertTrue((mini.base/'prepared'/self.generation).exists())

    def test_status_exposes_latest_policy_decisions_with_observation_times(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        self.controller.cleanup()
        status = self.controller.status()
        report = status['lastPolicyReports']['cleanup']
        self.assertEqual(report['prunedGenerations'], [old])
        self.assertEqual(report['protectedGenerations'][active], ['active'])
        self.assertIn('observedAtUtc', report)
        self.assertFalse(status['supervisorOrChildOwnsPipeline'])

    def test_unknown_operation_release_blocks_cleanup_without_discarding_retained_data(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        unknown = dict(self.controller.operation(), operationId=str(uuid.uuid4()), releaseId=str(uuid.uuid4()),
            state='failed', generationId=None, protectedGenerationIds=[], protectedExportIds=[])
        self.controller.save_operation(unknown)
        with self.assertRaisesRegex(replica.ReplicaError, 'unsupported operation release'):
            self.controller.cleanup()
        self.assertTrue((self.base/'generations'/old).exists())
        self.assertTrue((self.base/'generations'/active).exists())

    def test_incomplete_latest_generation_cannot_displace_newest_complete_pending(self):
        old, active, pending, broken = [self.generation_ready(i) for i in range(4)]
        self.selection(active)
        directory = self.base/'generations'/broken/'payload/DEM'
        directory.chmod(0o755)
        (directory/'tiny.tif').unlink()
        directory.chmod(0o555)
        result = self.controller.cleanup()
        self.assertEqual(set(result['prunedGenerations']), {old, broken})
        self.assertEqual(result['protectedGenerations'][pending], ['newest-pending'])
        self.assertTrue((self.base/'generations'/pending).exists())

    def test_cleanup_records_pruning_intent_before_any_destructive_work(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        def fail_log(path, value):
            if path.name == 'cleanup.json':
                raise OSError('cleanup intent could not be persisted')
            source.atomic_json(path, value)
        controller = replica.Replica(self.base, lock_wait=0, publish=fail_log)
        with self.assertRaisesRegex(OSError, 'intent could not be persisted'):
            controller.cleanup()
        self.assertTrue((self.base/'generations'/old).exists())
        self.assertTrue((self.base/'eligibility'/f'{old}.json').exists())

    def test_cleanup_retry_finishes_metadata_pruning_after_interrupted_directory_removal(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        directory = self.base/'eligibility'
        directory.chmod(0o555)
        try:
            with self.assertRaises(PermissionError):
                self.controller.cleanup()
            self.assertFalse((self.base/'generations'/old).exists())
            self.assertTrue((directory/f'{old}.json').exists())
            self.assertEqual(source.read_json(self.base/'logs'/'cleanup.json')['state'], 'planned')
        finally:
            directory.chmod(0o755)
        result = self.controller.cleanup()
        self.assertEqual(result['prunedEligibility'], [old])
        self.assertFalse((directory/f'{old}.json').exists())
        self.assertTrue((self.base/'receipts'/f'{old}.json').exists())
        self.assertTrue((self.base/'generations'/active).exists())

    def test_source_acknowledgement_cli_rejects_duplicate_receipt_keys(self):
        mini = source.Coordinator(self.root/'source', lock_wait=0)
        mini.maintenance(lambda: None, lambda: 'a'*64)
        def capture(payload, generation):
            shutil.copytree(self.export/'payload', payload)
            return dict(self.inventory, generationId=generation)
        generation = mini.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
        self.generation = generation
        self.export = self.incoming/generation
        shutil.copytree(mini.base/'prepared'/generation, self.export)
        self.capture()
        serialized = json.dumps(self.controller.receipt(generation)).replace('"schemaVersion": 1',
            '"schemaVersion": 2, "schemaVersion": 1')
        result = subprocess.run([sys.executable, 'tool/mapping_source.py', '--base', str(mini.base), 'acknowledge'],
            input=serialized, text=True, capture_output=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('duplicate metadata key', result.stderr)
        self.assertFalse((mini.base/'receipts'/f'{generation}.json').exists())

    def test_unknown_operation_stage_cannot_authorize_destructive_cleanup(self):
        old, active = [self.generation_ready(i) for i in range(2)]
        self.selection(active)
        value = dict(self.controller.operation(), operationId=str(uuid.uuid4()), stage='future-stage', state='failed')
        self.controller.save_operation(value)
        with self.assertRaisesRegex(replica.ReplicaError, 'unsupported operation stage'):
            self.controller.cleanup()
        self.assertTrue((self.base/'generations'/old).exists())
        self.assertTrue((self.base/'generations'/active).exists())


if __name__ == '__main__':
    unittest.main()
