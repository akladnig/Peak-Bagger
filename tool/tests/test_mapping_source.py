"""Disposable source coordination tests; no canonical Mapping access."""
import importlib.util
import tempfile
import hashlib
import stat
import sys
import socket
import json
import subprocess
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location(
    "mapping_source", Path(__file__).parents[1] / "mapping_source.py")
source = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(source)


class SourceCoordinationTest(unittest.TestCase):
    def test_recovery_finishes_pending_commands_without_replaying_completed_ones(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            counter = coordinator.base/'counter'
            failed = coordinator.base/'failed-once'
            first = [sys.executable, '-c', 'import sys; from pathlib import Path; p=Path(sys.argv[1]); p.write_text((p.read_text() if p.exists() else "")+"x")']
            second = [sys.executable, '-c', 'import sys; from pathlib import Path; p=Path(sys.argv[1]); old=p.exists(); p.touch(); sys.exit(0 if old else 1)']
            bridge = source.DatasetBridge(coordinator, publishers={'promote': first, 'fingerprints': second})
            plan = [dict(publisher='promote', arguments=[str(counter)]),
                    dict(publisher='fingerprints', arguments=[str(failed)])]
            with self.assertRaises(source.SourceError):
                coordinator.maintenance(lambda: bridge.run_plan(plan), lambda: 'a'*64)
            self.assertEqual(coordinator.publication()['state'], 'recovery-required')
            def finish():
                bridge.finish_plan()
                return 'a'*64
            coordinator.recover(finish)
            self.assertEqual(counter.read_text(), 'x')
            self.assertEqual(coordinator.require_complete()['state'], 'complete')

    def test_writer_process_crash_does_not_make_free_lock_completion_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            code = ('import sys, os; sys.path.insert(0, "tool"); import mapping_source as s; '
                    's.Coordinator(sys.argv[1]).maintenance(lambda: os._exit(9), lambda: "a"*64)')
            result = subprocess.run([sys.executable, '-c', code, directory], capture_output=True)
            self.assertEqual(result.returncode, 9, result.stderr)
            coordinator = source.Coordinator(Path(directory))
            with coordinator.publication_lock():
                self.assertEqual(coordinator.publication()['state'], 'publishing')
                with self.assertRaisesRegex(source.SourceError, 'recovery'):
                    coordinator.require_complete()
            coordinator.recover(lambda: 'a'*64)
            self.assertEqual(coordinator.require_complete()['state'], 'complete')

    def test_surviving_child_retains_inherited_lifetime_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory), lock_wait=0)
            with coordinator.publication_lock('survivor'):
                child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(.2)'],
                    pass_fds=tuple(coordinator._fds))
            try:
                with self.assertRaisesRegex(source.SourceError, 'busy'):
                    with coordinator.publication_lock('survivor'):
                        self.fail('surviving work lost its lock')
            finally:
                child.wait(timeout=5)
            with coordinator.publication_lock('survivor'):
                pass

    def test_completion_publication_failure_exposes_no_export(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: 'a'*64)
            def capture(payload, generation):
                payload.mkdir(parents=True)
                return source.record('mapping-integrity', generationId=generation, files=[])
            def fail_completion(payload, generation):
                (payload.parent/'completion.json').mkdir()
                return dict(checks=[], diagnostics=[])
            with self.assertRaises(OSError):
                coordinator.prepare(capture, fail_completion)
            self.assertFalse(list((coordinator.base/'prepared').iterdir()))
            self.assertEqual(coordinator.last_operation()['state'], 'failed')

    def test_external_export_guard_rejects_mapping_cwd_before_snapshot_write(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            canonical = root/'Mapping'
            canonical.mkdir()
            script = root/'slovenia-highways.sh'
            script.write_text('#!/bin/sh\nprintf downloaded > slovenia-highways.json\n')
            script.chmod(0o755)
            source.install_external_guard(script, root/'original.sh', canonical_root=canonical)
            denied = subprocess.run([str(script)], cwd=canonical, capture_output=True, text=True)
            self.assertNotEqual(denied.returncode, 0)
            self.assertFalse((canonical/'slovenia-highways.json').exists())
            allowed = subprocess.run([str(script)], cwd=root, capture_output=True, text=True)
            self.assertEqual(allowed.returncode, 0, allowed.stderr)
            self.assertEqual((root/'slovenia-highways.json').read_text(), 'downloaded')

    def test_receipt_scope_requires_exact_completed_identity_and_no_transfer_pin(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: 'a'*64)
            def capture(payload, generation):
                payload.mkdir(parents=True)
                return source.record('mapping-integrity', generationId=generation, files=[])
            generation = coordinator.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
            export = coordinator.base / 'prepared' / generation
            completion, _ = source.completed_export(export)
            receipt = source.record('mapping-durable-receipt', receiptId=str(source.uuid.uuid4()),
                operationId=str(source.uuid.uuid4()), generationId=generation,
                inventorySha256=completion['inventorySha256'], sourceCompletionSha256=hashlib.sha256((export/'completion.json').read_bytes()).hexdigest(),
                localValidationReportSha256='a'*64, controllerRelease=source.DEVELOPMENT_CONTROLLER_ID, storedAtUtc=source.utc())
            with self.assertRaisesRegex(source.SourceError, 'protected'):
                with coordinator.receipt_cleanup_scope(receipt, protected_export_ids={generation}):
                    self.fail('live transfer lost its source')
            with coordinator.receipt_cleanup_scope(receipt, protected_export_ids=set()) as identity:
                self.assertEqual(identity, generation)
                with self.assertRaisesRegex(source.SourceError, 'busy'):
                    with source.Coordinator(coordinator.base, lock_wait=0).publication_lock('prepare'):
                        self.fail('preparation raced receipt-bound cleanup')
            self.assertTrue((coordinator.base/'receipts'/f'{generation}.json').exists())
            self.assertTrue(export.exists())

    def test_unsupported_completed_record_fails_closed_without_replacing_export(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: 'a'*64)
            def capture(payload, generation):
                payload.mkdir(parents=True)
                return source.record('mapping-integrity', generationId=generation, files=[])
            generation = coordinator.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
            completion = coordinator.base / 'prepared' / generation / 'completion.json'
            completion.chmod(0o644)
            value = source.read_json(completion)
            value['schemaVersion'] = 2
            completion.write_text(json.dumps(value))
            with self.assertRaisesRegex(source.SourceError, 'unsupported'):
                coordinator.prepare(capture, lambda *_: self.fail('unsupported export was validated/replaced'))
            self.assertTrue(completion.exists())

    def test_live_guard_socket_expires_with_transaction(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            def update():
                with coordinator.guard_server() as environment:
                    with socket.socket(socket.AF_UNIX) as client:
                        client.connect(environment['MAPPING_PUBLICATION_SOCKET'])
                        request = dict(action='ping', toolId='example', root=source.CANONICAL_ROOT,
                            ownershipToken=environment['MAPPING_PUBLICATION_TOKEN'])
                        client.sendall((json.dumps(request)+'\n').encode())
                        self.assertTrue(json.loads(client.recv(4096))['ok'])
                    self.assertTrue(Path(environment['MAPPING_PUBLICATION_SOCKET']).exists())
                self.assertFalse(Path(environment['MAPPING_PUBLICATION_SOCKET']).exists())
            coordinator.maintenance(update, lambda: 'a'*64)

    def test_process_budget_reports_unknown_and_preserves_surviving_work(self):
        states = []
        output = source.bounded_process([sys.executable, '-c',
            'import time; time.sleep(.05); print("finished")'],
            timeout=.001, on_unknown=lambda: states.append('outcome-unknown'))
        self.assertEqual(states, ['outcome-unknown'])
        self.assertEqual(output.strip(), 'finished')

    def test_failed_validation_records_owned_operation_and_never_completes_export(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: 'a'*64)
            def capture(payload, generation):
                payload.mkdir(parents=True)
                return source.record('mapping-integrity', generationId=generation, files=[])
            def invalid(*_):
                raise source.SourceError('DEM/cop30_hh.tif: truncated raster')
            with self.assertRaisesRegex(source.SourceError, 'truncated'):
                coordinator.prepare(capture, invalid)
            operation = coordinator.last_operation()
            self.assertEqual(operation['state'], 'failed')
            self.assertEqual(operation['releaseId'], source.DEVELOPMENT_RELEASE_ID)
            self.assertTrue(operation['owner']['processStartId'])
            self.assertFalse(list((coordinator.base / 'prepared').iterdir()))
            report = source.read_json(coordinator.base / 'validation' /
                (operation['generationId'] + '.json'))
            self.assertEqual(report['state'], 'failed')
            self.assertIn('DEM/cop30_hh.tif', report['diagnostics'][0])

    def test_changed_source_cannot_accumulate_unacknowledged_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: 'a'*64)
            content = [b'old']
            def capture(payload, generation):
                payload.mkdir(parents=True)
                (payload / 'region_manifest.json').write_bytes(content[0])
                return source.record('mapping-integrity', generationId=generation,
                    files=[dict(path='region_manifest.json', size=len(content[0]),
                                sha256=hashlib.sha256(content[0]).hexdigest())])
            coordinator.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
            content[0] = b'new'
            coordinator.maintenance(lambda: None, lambda: 'b'*64)
            with self.assertRaisesRegex(source.SourceError, 'durable receipt'):
                coordinator.prepare(capture, lambda *_: dict(checks=[], diagnostics=[]))
            self.assertEqual(len(list((coordinator.base / 'prepared').iterdir())), 1)

    def test_child_permission_journals_target_and_cannot_complete_outer_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.registered_outputs = {'example': [('region_manifest.json', 'file')]}
            def update():
                request = dict(action='prepare', toolId='example', root=source.CANONICAL_ROOT,
                               path='region_manifest.json', nextSha256='b'*64)
                with self.assertRaisesRegex(source.SourceError, 'token'):
                    coordinator.guard(dict(request, ownershipToken='wrong'))
                token = coordinator.publication()['owner']['ownershipToken']
                coordinator.guard(dict(request, ownershipToken=token))
                with self.assertRaisesRegex(source.SourceError, 'action'):
                    coordinator.guard(dict(action='complete', ownershipToken=token))
                coordinator.guard(dict(request, action='published', ownershipToken=token))
            coordinator.maintenance(update, lambda: 'b'*64)
            journal = source.read_json(coordinator.base / 'journals' /
                (coordinator.publication()['publicationId'] + '.json'))
            self.assertEqual(journal['steps'][0]['state'], 'published')

    def test_preparation_publishes_last_and_reuses_unchanged_completed_export(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory))
            coordinator.maintenance(lambda: None, lambda: "a" * 64)
            captures = []
            def capture(payload, generation):
                captures.append(generation)
                payload.mkdir(parents=True)
                (payload / 'region_manifest.json').write_bytes(b'fixture')
                return source.record('mapping-integrity', generationId=generation,
                    files=[dict(path='region_manifest.json', size=7,
                                sha256=hashlib.sha256(b'fixture').hexdigest())])
            validations = []
            def validate(payload, generation):
                self.assertFalse(list((coordinator.base / 'prepared').glob('*')))
                validations.append(generation)
                return dict(checks=[], diagnostics=[])
            first = coordinator.prepare(capture, validate)
            second = coordinator.prepare(capture, validate)
            self.assertEqual(first, second)
            self.assertEqual(len(validations), 1)
            self.assertEqual(len(captures), 1)
            export = coordinator.base / 'prepared' / first
            self.assertTrue((export / 'completion.json').exists())
            self.assertEqual((export / 'payload/region_manifest.json').read_bytes(), b'fixture')
            self.assertEqual(stat.S_IMODE((export / 'payload/region_manifest.json').stat().st_mode), 0o444)
            self.assertEqual(stat.S_IMODE((export / 'payload').stat().st_mode), 0o555)

    def test_failed_writer_blocks_capture_until_validated_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory), lock_wait=0.01)
            def interrupted():
                raise RuntimeError("writer interrupted")
            with self.assertRaisesRegex(RuntimeError, "interrupted"):
                coordinator.maintenance(interrupted, lambda: "a" * 64)
            with coordinator.publication_lock():
                with self.assertRaisesRegex(source.SourceError, "recovery"):
                    coordinator.require_complete()
            coordinator.recover(lambda: "b" * 64)
            with coordinator.publication_lock():
                self.assertEqual(coordinator.require_complete()["state"], "complete")

    def test_transaction_excludes_capture_across_related_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            coordinator = source.Coordinator(Path(directory), lock_wait=0.01)
            observed = []
            def update():
                for step in ("peaks", "fingerprints"):
                    with self.assertRaisesRegex(source.SourceError, "busy"):
                        with coordinator.publication_lock():
                            self.fail("capture entered an unfinished update")
                    observed.append(step)
            coordinator.maintenance(update, lambda: "a" * 64)
            self.assertEqual(observed, ["peaks", "fingerprints"])
            with coordinator.publication_lock():
                self.assertEqual(coordinator.publication()["state"], "complete")


if __name__ == "__main__":
    unittest.main()
