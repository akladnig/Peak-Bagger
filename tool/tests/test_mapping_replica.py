"""Independent replica capture tests. Only disposable local data/processes."""
import hashlib
import json
import os
import stat
import sys
import tempfile
import unittest
import uuid
import subprocess
import contextlib
import io
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
import mapping_source as source
import mapping_replica as replica


class ReplicaCaptureTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.base = self.root / 'replica'
        self.incoming = self.base / 'incoming'
        self.generation = str(uuid.uuid4())
        self.export = self.incoming / self.generation
        self.files = {'region_manifest.json': b'{}', 'Polygons/manifest.json': b'[]',
                      'DEM/tiny.tif': b'disposable raster bytes'}
        self.write_export()
        self.validations = []
        self.controller = replica.Replica(self.base, lock_wait=0)
        self.addCleanup(self.dispose)
        self.diagnostics = io.StringIO()
        self.enterContext(contextlib.redirect_stderr(self.diagnostics))

    def dispose(self):
        for root, directories, _ in os.walk(self.root):
            Path(root).chmod(0o755)
            for directory in directories:
                (Path(root) / directory).chmod(0o755)
        self.temporary.cleanup()

    def write_export(self):
        for path, contents in self.files.items():
            target = self.export / 'payload' / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
        self.inventory = source.record('mapping-integrity', generationId=self.generation,
            files=[dict(path=path, size=len(contents), sha256=hashlib.sha256(contents).hexdigest())
                   for path, contents in sorted(self.files.items())])
        source.atomic_json(self.export/'integrity.json', self.inventory)
        source.atomic_json(self.export/'completion.json', source.record('mapping-source-completion',
            generationId=self.generation, inventorySha256=source.digest(self.inventory),
            operationId=str(uuid.uuid4()), publicationId=str(uuid.uuid4()),
            sourcePreparerRelease=source.DEVELOPMENT_RELEASE_ID,
            validationProfile=source.PROFILE, validatedAtUtc=source.utc()))

    def validate(self, payload, inventory):
        self.validations.append(str(payload))
        return dict(inventorySha256=source.digest(inventory), checks=[
            dict(path=f['path'], checkId='sha256-v1', result='passed') for f in inventory['files']
        ] + [dict(path=path, checkId=check, result='passed') for path, check in [
            ('region_manifest.json', 'manifest-paths-v1'),
            ('Polygons/manifest.json', 'manifest-paths-v1'),
            ('region_manifest.json', 'peak-fingerprints-v1')]], diagnostics=[])

    def capture(self, **kwargs):
        return self.controller.capture(self.generation, transfer_complete=True,
            validate=self.validate, **kwargs)

    def test_independent_capture_publishes_bound_eligibility_and_durable_receipt(self):
        result = self.capture()
        payload = self.base/'generations'/self.generation/'payload'
        self.assertEqual(result['generationId'], self.generation)
        self.assertEqual(result['inventorySha256'], source.digest(self.inventory))
        self.assertEqual(self.controller.eligible(self.generation), result)
        for path, contents in self.files.items():
            incoming = self.export/'payload'/path
            captured = payload/path
            self.assertEqual(captured.read_bytes(), contents)
            self.assertNotEqual(incoming.stat().st_ino, captured.stat().st_ino)
            self.assertEqual(stat.S_IMODE(captured.stat().st_mode), 0o444)
        self.assertEqual(stat.S_IMODE(payload.stat().st_mode), 0o555)
        receipt = source.read_json(self.base/'receipts'/f'{self.generation}.json')
        self.assertEqual(receipt['sourceCompletionSha256'], result['sourceCompletionSha256'])
        self.assertEqual(receipt['localValidationReportSha256'], result['validationReportSha256'])
        self.assertEqual(self.controller.operation()['state'], 'succeeded')
        self.assertFalse((self.export/'eligibility.json').exists())

    def test_changed_candidate_during_validation_cannot_receive_stale_eligibility(self):
        def changed(payload, inventory):
            result = self.validate(payload, inventory)
            (payload/'DEM/tiny.tif').write_bytes(b'changed captured bytes')
            return result
        with self.assertRaisesRegex(replica.ReplicaError, 'SHA-256 mismatch'):
            self.controller.capture(self.generation, transfer_complete=True, validate=changed)
        self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())
        self.assertFalse((self.base/'receipts'/f'{self.generation}.json').exists())

    def test_incoming_metadata_change_during_capture_rejects_inconsistent_generation(self):
        def changed(payload, inventory):
            completion = source.read_json(self.export/'completion.json')
            completion['operationId'] = str(uuid.uuid4())
            source.atomic_json(self.export/'completion.json', completion)
            return self.validate(payload, inventory)
        with self.assertRaisesRegex(replica.ReplicaError, 'incoming.*changed'):
            self.controller.capture(self.generation, transfer_complete=True, validate=changed)
        self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())

    def test_eligibility_reader_rejects_changed_validation_identity_without_payload_hashing(self):
        self.capture()
        report_path = self.base/'generations'/self.generation/'validation.json'
        report_path.chmod(0o644)
        report = source.read_json(report_path)
        report['generationId'] = str(uuid.uuid4())
        report_path.write_text(json.dumps(report))
        with self.assertRaisesRegex(replica.ReplicaError, 'validation'):
            self.controller.eligible(self.generation)

    def test_incoming_writes_during_and_after_validation_cannot_change_reused_capture(self):
        def incoming_write(payload, inventory):
            (self.export/'payload/DEM/tiny.tif').write_bytes(b'transport writes during validation')
            return self.validate(payload, inventory)
        first = self.controller.capture(self.generation, transfer_complete=True, validate=incoming_write)
        (self.export/'payload/DEM/tiny.tif').write_bytes(b'transport writes after validation')
        second = self.controller.capture(self.generation, transfer_complete=True,
            validate=lambda *_: self.fail('unchanged completed generation was revalidated'))
        self.assertEqual(first, second)
        self.assertEqual((self.base/'generations'/self.generation/'payload/DEM/tiny.tif').read_bytes(),
                         self.files['DEM/tiny.tif'])
        self.assertEqual(len(list((self.base/'generations').iterdir())), 1)
        self.assertEqual(len(self.validations), 1)
        completion = source.read_json(self.export/'completion.json')
        completion['operationId'] = str(uuid.uuid4())
        source.atomic_json(self.export/'completion.json', completion)
        with self.assertRaisesRegex(replica.ReplicaError, 'identity.*changed'):
            self.capture()
        self.assertEqual(self.controller.eligible(self.generation), first)

    def test_interrupted_publication_never_acknowledges_receipt_and_preserves_prior_data(self):
        prior_generation = self.generation
        prior = self.capture()
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        def interrupted(path, value):
            source.atomic_json(path, value)
            if path.parent.name == 'receipts':
                raise OSError('injected directory flush failure after rename')
        controller = replica.Replica(self.base, publish=interrupted)
        with self.assertRaisesRegex(replica.ReplicaError, 'stage=receipt.*flush failure'):
            controller.capture(self.generation, transfer_complete=True, validate=self.validate)
        with self.assertRaisesRegex(replica.ReplicaError, 'durable.*outcome'):
            controller.eligible(self.generation)
        self.assertEqual(self.controller.eligible(prior_generation), prior)
        self.assertEqual(controller.operation()['state'], 'failed')
        with self.assertRaisesRegex(replica.ReplicaError, 'durable.*outcome'):
            controller.receipt(self.generation)

    def test_validator_must_attest_exact_inventory_and_successful_required_checks(self):
        for response in [dict(inventorySha256='a'*64, checks=[], diagnostics=[]),
                         dict(inventorySha256=source.digest(self.inventory), checks=[
                             dict(path='DEM/tiny.tif', checkId='dem-full-band1-v1', result='failed')], diagnostics=[])]:
            with self.subTest(response=response), self.assertRaisesRegex(replica.ReplicaError, 'validation result'):
                self.controller.capture(self.generation, transfer_complete=True, validate=lambda *_: response)
            self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())

    def test_incoming_symlink_cannot_be_promoted_even_when_bytes_match(self):
        target = self.export/'payload/DEM/tiny.tif'
        external = self.root/'external.tif'
        external.write_bytes(target.read_bytes())
        target.unlink()
        target.symlink_to(external)
        with self.assertRaisesRegex(replica.ReplicaError, 'symlink'):
            self.capture()
        self.assertFalse(self.validations)

    def test_validation_holds_single_flight_and_surviving_child_retains_protection(self):
        other = replica.Replica(self.base, lock_wait=0)
        child = None
        def protected(payload, inventory):
            nonlocal child
            with self.assertRaisesRegex(replica.ReplicaError, 'busy'):
                other.capture(self.generation, transfer_complete=True, validate=self.validate)
            child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(.3)'],
                                     pass_fds=tuple(self.controller._fds))
            return self.validate(payload, inventory)
        self.controller.capture(self.generation, transfer_complete=True, validate=protected)
        try:
            with self.assertRaisesRegex(replica.ReplicaError, 'busy'):
                self.capture()
        finally:
            child.wait(timeout=5)
        self.capture()

    def test_crashed_capture_requires_same_operation_reconciliation_before_retry(self):
        code = ('import sys, os; sys.path.insert(0, "tool"); import mapping_replica as r; '
                'r.Replica(sys.argv[1]).capture(sys.argv[2], transfer_complete=True, '
                'validate=lambda *_: os._exit(9))')
        process = subprocess.run([sys.executable, '-c', code, str(self.base), self.generation], capture_output=True)
        self.assertEqual(process.returncode, 9, process.stderr)
        operation = self.controller.operation()
        self.assertEqual(operation['state'], 'running')
        with self.assertRaisesRegex(replica.ReplicaError, 'unresolved'):
            self.capture()
        self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())
        self.controller.reconcile(operation['operationId'])
        self.capture()
        self.assertTrue((self.base/'candidates'/operation['operationId']).exists())

    def test_source_completion_digest_binds_exact_persisted_bytes(self):
        path = self.export/'completion.json'
        path.write_text(json.dumps(source.read_json(path), indent=2))
        expected = hashlib.sha256(path.read_bytes()).hexdigest()
        result = self.capture()
        captured = self.base/'generations'/self.generation/'completion.json'
        self.assertEqual(captured.read_bytes(), path.read_bytes())
        self.assertEqual(self.controller.eligible(self.generation)['sourceCompletionSha256'], expected)
        self.assertEqual(result['sourceCompletionSha256'], expected)

    def test_incomplete_transfer_and_corrupt_incoming_preserve_previous_eligible_data(self):
        prior_generation = self.generation
        prior = self.capture()
        for failure in ['transfer', 'manifest-only', 'missing', 'truncated', 'digest', 'semantic', 'disconnected']:
            with self.subTest(failure=failure):
                self.generation = str(uuid.uuid4())
                self.export = self.incoming/self.generation
                self.write_export()
                target = self.export/'payload/DEM/tiny.tif'
                if failure == 'manifest-only':
                    (self.export/'completion.json').unlink()
                if failure in ('missing', 'disconnected'):
                    target.unlink()
                if failure == 'truncated':
                    target.write_bytes(b'cut')
                if failure == 'digest':
                    target.write_bytes(b'x'*len(self.files['DEM/tiny.tif']))
                def invalid(*_):
                    raise ValueError('DEM/tiny.tif: malformed raster')
                with self.assertRaises(replica.ReplicaError):
                    self.controller.capture(self.generation, transfer_complete=failure != 'transfer',
                        validate=invalid if failure == 'semantic' else self.validate)
                self.assertEqual(self.controller.eligible(prior_generation), prior)
                self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())
                self.assertFalse((self.base/'receipts'/f'{self.generation}.json').exists())
                self.assertEqual(self.controller.operation()['state'], 'failed')

    def test_local_metadata_and_capture_aliases_cannot_write_inside_incoming(self):
        (self.base/'operations').symlink_to(self.incoming, target_is_directory=True)
        before = set(self.incoming.iterdir())
        with self.assertRaisesRegex(replica.ReplicaError, 'symlink'):
            self.capture()
        self.assertEqual(set(self.incoming.iterdir()), before)

    def test_failed_candidate_records_stage_operation_dataset_and_affected_paths(self):
        (self.export/'payload/DEM/tiny.tif').write_bytes(b'cut')
        with self.assertRaises(replica.ReplicaError):
            self.capture()
        operation = self.controller.operation()
        report = source.read_json(self.base/'failures'/f'{operation["operationId"]}.json')
        self.assertEqual(report['state'], 'failed')
        self.assertEqual(report['generationId'], self.generation)
        text = report['diagnostics'][0]
        for expected in ['stage=capture', operation['operationId'], self.generation, 'DEM/tiny.tif', str(self.incoming)]:
            self.assertIn(expected, text)

    def test_process_validator_receives_completed_inventory_and_pinned_payload(self):
        script = self.root/'validator.py'
        script.write_text('import json, sys\nfrom pathlib import Path\n'
            'request=json.load(sys.stdin)\n'
            'assert sys.argv[3] == "validate"\n'
            'assert "/candidates/" in request["root"]\n'
            'Path(sys.argv[1]).write_text(json.dumps(request))\n'
            'print(sys.argv[2])\n')
        request_path = self.root/'request.json'
        response = json.dumps(self.validate(None, self.inventory))
        bridge = replica.DatasetValidator(self.controller,
            command=[sys.executable, str(script), str(request_path), response])
        self.controller.capture(self.generation, transfer_complete=True, validate=bridge.validate)
        request = source.read_json(request_path)
        self.assertEqual(request['integrity'], self.inventory)
        self.assertEqual(request['generationId'], self.generation)
        self.assertNotIn(str(self.incoming), request['root'])

    def test_small_metadata_read_rejects_writable_or_relinked_published_payload(self):
        self.capture()
        target = self.base/'generations'/self.generation/'payload/DEM/tiny.tif'
        target.chmod(0o644)
        with self.assertRaisesRegex(replica.ReplicaError, 'immutable'):
            self.controller.eligible(self.generation)

    def test_completed_metadata_requires_manifest_pair_and_supported_strict_identity(self):
        for failure in ['missing-pair', 'bad-time', 'unknown-version', 'extra-fields', 'metadata-link']:
            with self.subTest(failure=failure):
                self.generation = str(uuid.uuid4())
                self.export = self.incoming/self.generation
                self.write_export()
                completion = source.read_json(self.export/'completion.json')
                if failure == 'missing-pair':
                    self.inventory['files'] = [f for f in self.inventory['files'] if f['path'] != 'Polygons/manifest.json']
                    source.atomic_json(self.export/'integrity.json', self.inventory)
                    completion['inventorySha256'] = source.digest(self.inventory)
                if failure == 'bad-time':
                    completion['validatedAtUtc'] = 'not a UTC timestamp'
                if failure == 'unknown-version':
                    completion['schemaVersion'] = 2
                if failure == 'extra-fields':
                    completion['extra'] = True
                source.atomic_json(self.export/'completion.json', completion)
                if failure == 'metadata-link':
                    outside = self.root/'completion.json'
                    outside.write_bytes((self.export/'completion.json').read_bytes())
                    (self.export/'completion.json').unlink()
                    (self.export/'completion.json').symlink_to(outside)
                with self.assertRaises(replica.ReplicaError):
                    self.capture()
                self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())
        self.assertFalse(self.validations)

    def test_low_space_capture_reports_failure_without_deleting_previous_generation(self):
        prior_generation = self.generation
        prior = self.capture()
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        controller = replica.Replica(self.base, available_bytes=lambda: 0)
        with self.assertRaisesRegex(replica.ReplicaError, 'stage=capture.*insufficient space'):
            controller.capture(self.generation, transfer_complete=True, validate=self.validate)
        self.assertEqual(controller.eligible(prior_generation), prior)
        self.assertFalse((self.base/'candidates'/controller.operation()['operationId']).exists())

    def test_detached_capture_returns_operation_and_status_tracks_durable_outcome(self):
        script = self.root/'detached_validator.py'
        script.write_text('import sys,time; time.sleep(.2); print(sys.argv[1])')
        accepted = self.controller.start_capture(self.generation, transfer_complete=True,
            dataset_command=[sys.executable, str(script), json.dumps(self.validate(None, self.inventory))])
        self.assertEqual(accepted['status'], 'accepted')
        self.assertTrue(Path(accepted['log']).is_file())
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            status = self.controller.status()
            if not status['supervisorOrChildOwnsPipeline']:
                break
            time.sleep(.05)
        self.assertFalse(status['supervisorOrChildOwnsPipeline'])
        self.assertEqual(status['operation']['state'], 'succeeded', Path(accepted['log']).read_text())
        self.assertEqual(status['operation']['operationId'], accepted['operationId'])
        self.assertEqual(self.controller.receipt(self.generation)['generationId'], self.generation)

    def test_interrupted_independent_copy_is_ineligible_and_leaves_prior_capture_usable(self):
        prior_generation = self.generation
        prior = self.capture()
        self.generation = str(uuid.uuid4())
        self.export = self.incoming/self.generation
        self.write_export()
        def interrupted(incoming, target):
            replica.independent_copy(incoming, target)
            raise OSError('interrupted independent copy')
        controller = replica.Replica(self.base, copy=interrupted)
        with self.assertRaisesRegex(replica.ReplicaError, 'stage=capture.*interrupted independent copy'):
            controller.capture(self.generation, transfer_complete=True, validate=self.validate)
        self.assertEqual(controller.eligible(prior_generation), prior)
        self.assertFalse((self.base/'eligibility'/f'{self.generation}.json').exists())

    def test_reconciliation_restores_current_mirror_after_durable_outcome_crash(self):
        result = self.capture()
        operation = self.controller.operation()
        source.atomic_json(self.base/'operation.json', dict(operation, state='running', outcomeRecordSha256=None))
        self.controller.reconcile(operation['operationId'])
        self.assertEqual(self.controller.operation(), operation)
        self.assertEqual(self.capture(), result)

    def test_durable_receipt_must_bind_the_validating_operation_identity(self):
        self.capture()
        receipt_path = self.base/'receipts'/f'{self.generation}.json'
        receipt = source.read_json(receipt_path)
        receipt['operationId'] = str(uuid.uuid4())
        source.atomic_json(receipt_path, receipt)
        with self.assertRaisesRegex(replica.ReplicaError, 'receipt.*identity'):
            self.controller.receipt(self.generation)


if __name__ == '__main__':
    unittest.main()
