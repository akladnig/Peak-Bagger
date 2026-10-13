"""Disposable installed refresh state/transport/clock tests; no live Mapping."""
import sys
import tempfile
import unittest
import uuid
import json
import subprocess
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]))
import mapping_source as source


class ControllerTest(unittest.TestCase):
    def test_oversized_validation_evidence_fails_before_eligible_publication(self):
        from test_mapping_replica import ReplicaCaptureTest
        from mapping_replica import ReplicaError
        fixture = ReplicaCaptureTest(); fixture.setUp(); self.addCleanup(fixture.doCleanups)
        def oversized(payload,inventory):
            result=fixture.validate(payload,inventory)
            result['diagnostics']=['x'*(16*1024*1024)]
            return result
        with self.assertRaisesRegex(ReplicaError,'validation evidence.*16 MiB'):
            fixture.controller.capture(fixture.generation,transfer_complete=True,validate=oversized)
        self.assertFalse((fixture.base/'eligibility'/f'{fixture.generation}.json').exists())
        self.assertFalse((fixture.base/'generations'/fixture.generation).exists())

    def test_surviving_local_child_and_stalled_transfer_keep_identities_across_clock_ticks(self):
        import mapping_controller as controller
        with tempfile.TemporaryDirectory() as directory:
            identity,generation = str(uuid.uuid4()),str(uuid.uuid4())
            calls=[]
            def local(action, **kwargs):
                calls.append(action)
                return dict(operation=dict(operationId=identity,state='outcome-unknown',
                    progressAtUtc='2026-10-13T00:00:00Z'),supervisorOrChildOwnsPipeline=True)
            runner = controller.Controller(Path(directory),remote=lambda *_a,**_k: None,
                local=local,clock=lambda: 2000000000)
            runner.save(dict(kind='mapping-refresh-state',schemaVersion=1,phase='capture-wait',
                captureOperation=identity,generationId=generation,startedAtUtc='2026-10-13T00:00:00Z'))
            for _ in range(3):
                result=runner.tick()
                self.assertEqual(result['phase'],'capture-wait')
                self.assertEqual(result['captureOperation'],identity)
                self.assertIn('600',result['diagnostic'])
            self.assertEqual(calls,['status']*3)
            times=[1000]
            class Transfer:
                def observe(self,_): return dict(ready=False,progress=10,status='disconnected')
            runner.transfer=Transfer(); runner.clock=lambda: times[0]
            runner.save(dict(kind='mapping-refresh-state',schemaVersion=1,phase='transfer',
                generationId=generation,transferOperation=identity,cycle=10))
            runner.tick(); times[0]+=601
            result=runner.tick()
            self.assertEqual(result['phase'],'transfer')
            self.assertEqual(result['transferOperation'],identity)
            self.assertIn('600',result['diagnostic'])
            self.assertFalse((Path(directory)/'eligibility').exists())

    def test_real_disposable_one_way_session_reuses_and_catches_up_after_pause(self):
        import shutil,time
        from mapping_transport import Mutagen
        binary = shutil.which('mutagen')
        if not binary: self.skipTest('Mutagen prerequisite absent')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            alpha,beta = root/'prepared',root/'incoming'
            alpha.mkdir(); beta.mkdir()
            (alpha/'payload').mkdir()
            (alpha/'payload'/'rarely-read-dem').write_bytes(b'fixture DEM bytes')
            (beta/'destination-only').write_text('must not contain local metadata')
            (root/'selection.json').write_text('protected local selection')
            transfer = Mutagen(dict(mutagen=binary,sourceBase=str(root),incoming=str(beta)),
                alpha=dict(protocol='local',path=str(alpha)),name='replica-test-'+str(uuid.uuid4()))
            session = transfer.setup()
            try:
                self.assertEqual(transfer.setup()['identifier'],session['identifier'])
                cycle = transfer.start()
                deadline = time.monotonic()+10
                while time.monotonic()<deadline and not transfer.observe(cycle)['ready']: time.sleep(.05)
                self.assertTrue(transfer.observe(cycle)['ready'])
                self.assertEqual((beta/'payload'/'rarely-read-dem').read_bytes(),b'fixture DEM bytes')
                self.assertFalse((beta/'destination-only').exists())
                transfer.pause()
                (alpha/'payload'/'rarely-read-dem').write_bytes(b'changed source')
                self.assertEqual((beta/'payload'/'rarely-read-dem').read_bytes(),b'fixture DEM bytes')
                cycle = transfer.start()
                deadline = time.monotonic()+10
                while time.monotonic()<deadline and not transfer.observe(cycle)['ready']: time.sleep(.05)
                self.assertTrue(transfer.observe(cycle)['ready'])
                self.assertEqual((beta/'payload'/'rarely-read-dem').read_bytes(),b'changed source')
                self.assertEqual((root/'selection.json').read_text(),'protected local selection')
            finally:
                transfer.call('terminate',session['identifier'])

    def test_low_space_prevents_resume_and_keeps_transfer_identity_and_protected_data(self):
        import mapping_controller as controller
        from test_mapping_replica import ReplicaCaptureTest
        fixture = ReplicaCaptureTest(); fixture.setUp(); self.addCleanup(fixture.doCleanups)
        fixture.capture()
        protected = fixture.controller.eligible(fixture.generation)
        fixture.controller.available_bytes = lambda: 0
        resumed = []
        class Transfer:
            def start(self): resumed.append(True)
        runner = controller.Controller(fixture.base,remote=lambda *_a,**_k: None,
            replica=fixture.controller,transfer=Transfer())
        inventory = source.read_json(fixture.base/'incoming'/fixture.generation/'integrity.json')
        operation = str(uuid.uuid4())
        runner.save(dict(kind='mapping-refresh-state',schemaVersion=1,phase='transfer-start',
            transferOperation=operation,generationId=fixture.generation,export=dict(inventory=inventory)))
        result = runner.tick()
        self.assertEqual(result['phase'],'transfer-start')
        self.assertEqual(result['transferOperation'],operation)
        self.assertIn('insufficient',result['diagnostic'])
        self.assertFalse(resumed)
        self.assertEqual(fixture.controller.eligible(fixture.generation),protected)

    def test_bounded_process_timeout_is_unknown_and_receipt_payload_reaches_pinned_ssh(self):
        from mapping_transport import process, InstalledCalls
        from mapping_controller import CallUnknown
        with patch('mapping_transport.subprocess.run',side_effect=subprocess.TimeoutExpired('ssh',30)):
            with self.assertRaisesRegex(CallUnknown,'30s.*unknown'):
                process(['/usr/bin/ssh','mini','anything'])
        captured = []
        config = dict(remotePython='/stable/python',remoteInstall='/installed')
        def fake(argv, **kwargs):
            captured.append((argv,kwargs)); return '{"receipt":"exact"}'
        result = InstalledCalls(config,process=fake)('acknowledge',data={'receipt':'exact'})
        self.assertEqual(result,{'receipt':'exact'})
        self.assertIn('BatchMode=yes',captured[0][0])
        self.assertIn('mini',captured[0][0])
        self.assertEqual(captured[0][1]['timeout'],30)
        self.assertEqual(json.loads(captured[0][1]['input_text']),result)
        self.assertIn('/installed/mapping_release_launcher.py',captured[0][0][-1])

    def test_confirmed_failed_preparation_retries_only_after_release_reconciliation(self):
        import mapping_controller as controller
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def remote(action, **kwargs):
                calls.append(action)
                if action == 'status':
                    return dict(operation=dict(operationId=kwargs['target'],state='failed'),
                        supervisorOrChildOwnsPipeline=False)
                return dict(state='failed')
            runner = controller.Controller(Path(directory),remote=remote)
            identity = runner.tick()['sourceOperation']
            self.assertEqual(runner.tick()['phase'],'prepare-reconcile')
            self.assertEqual(runner.tick()['phase'],'prepare')
            newer = runner.tick()['sourceOperation']
            self.assertNotEqual(identity,newer)
            self.assertEqual(calls,['prepare','status','reconcile-release','prepare'])

    def test_unresolved_child_blocks_retry_until_bounded_reconciliation_succeeds(self):
        import mapping_controller as controller
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def remote(action, **kwargs):
                calls.append(action)
                if action == 'status':
                    return dict(operation=None,supervisorOrChildOwnsPipeline=False)
                if action == 'reconcile-release':
                    raise controller.CallUnknown('surviving invocation/child owns release')
                return dict(status='accepted')
            runner = controller.Controller(Path(directory),remote=remote)
            identity = runner.tick()['sourceOperation']
            runner.tick()
            for _ in range(3):
                result = runner.tick()
                self.assertEqual(result['phase'],'prepare-reconcile')
                self.assertEqual(result['sourceOperation'],identity)
            self.assertEqual(calls.count('prepare'),1)
            self.assertIn('surviving',result['diagnostic'])

    def test_transfer_idle_without_new_completed_cycle_cannot_capture(self):
        from mapping_transport import Mutagen
        session = dict(identifier='only',name='mapping-runtime-replica',labels={'mapping-runtime':'replica'},
            mode='one-way-replica',ignore=dict(paths=[],syntax='mutagen',vcs=False),
            alpha=dict(protocol='ssh',host='mini',path='/source/prepared',connected=True,scanned=True),
            beta=dict(protocol='local',path='/replica/incoming',connected=True,scanned=True),
            status='watching',successfulCycles=1,paused=False)
        transfer = Mutagen(dict(mutagen='/mutagen',sourceBase='/source',incoming='/replica/incoming'),
            process=lambda *_a,**_k: json.dumps([session]))
        self.assertFalse(transfer.observe(1)['ready'])
        session['successfulCycles'] = 2
        self.assertTrue(transfer.observe(1)['ready'])
        session['alpha']['connected'] = False
        self.assertFalse(transfer.observe(1)['ready'])
        session['alpha']['connected'] = True
        session['beta']['transitionProblems'] = ['corruption']
        self.assertFalse(transfer.observe(1)['ready'])

    def test_login_schedule_is_60_seconds_and_matching_agent_is_reused(self):
        from mapping_controller import LaunchAgent
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            config = dict(python=sys.executable, installation=str(root/'installed'))
            calls = []
            def process(argv, **kwargs):
                calls.append(argv)
                if argv[1] == 'print': raise source.SourceError('not loaded')
                return ''
            agent = LaunchAgent(root/'agents', root/'logs', config, process=process, uid=123)
            value = agent.desired()
            self.assertTrue(value['RunAtLoad'])
            self.assertEqual(value['StartInterval'],60)
            self.assertEqual(value['ProgramArguments'][-3:], ['--','controller','refresh'])
            agent.install()
            first = agent.path.read_bytes()
            agent.install()
            self.assertEqual(agent.path.read_bytes(),first)
            import plistlib
            wrong = dict(value,StartInterval=10)
            agent.path.write_bytes(plistlib.dumps(wrong))
            with self.assertRaisesRegex(source.SourceError,'drift'):
                agent.install()

    def test_mutagen_reuses_exact_direction_scope_and_mode_and_rejects_drift(self):
        import mapping_transport as transport
        with tempfile.TemporaryDirectory() as directory:
            config = dict(mutagen='/opt/homebrew/bin/mutagen', sourceBase='/remote/source',
                incoming=str(Path(directory).resolve()/'incoming'))
            session = dict(identifier='disposable', name='mapping-runtime-replica',
                labels={'mapping-runtime':'replica'}, alpha=dict(protocol='ssh',host='mini',path='/remote/source/prepared'),
                beta=dict(protocol='local',path=config['incoming']), mode='one-way-replica',
                ignore=dict(paths=[],syntax='mutagen',vcs=False))
            command = transport.Mutagen(config, process=lambda *_args, **_kwargs: json.dumps([session]))
            self.assertEqual(command.inspect()['identifier'], 'disposable')
            session['mode'] = 'two-way-safe'
            with self.assertRaisesRegex(source.SourceError, 'drift'):
                command.inspect()
            session['mode'] = 'one-way-replica'
            session['alpha']['path'] = '/Volumes/Services/Mapping'
            with self.assertRaisesRegex(source.SourceError, 'drift'):
                command.inspect()

    def test_source_transfer_pin_survives_controller_exit_and_requires_receipt_to_release(self):
        # Source exports/receipts are generated through existing disposable fixture.
        from test_mapping_replica import ReplicaCaptureTest
        capture = ReplicaCaptureTest()
        capture.setUp()
        self.addCleanup(capture.doCleanups)
        capture.capture()
        coordinator = source.Coordinator(capture.root/'source')
        import shutil
        shutil.copytree(capture.base/'incoming'/capture.generation,
            coordinator.base/'prepared'/capture.generation)
        identity = str(uuid.uuid4())
        coordinator.pin_transfer(identity, capture.generation)
        with self.assertRaisesRegex(source.SourceError, 'receipt'):
            coordinator.release_transfer(identity, capture.generation)
        status = coordinator.cleanup(protected_export_ids=set())
        self.assertIn(capture.generation, status['protectedExports'])
        coordinator.acknowledge(capture.controller.receipt(capture.generation), protected_export_ids=set())
        self.assertEqual(coordinator.release_transfer(identity, capture.generation)['state'], 'succeeded')
        self.assertEqual(coordinator.release_transfer(identity, capture.generation)['state'], 'succeeded')

    def test_completed_transfer_capture_receipt_cleanup_and_unchanged_reuse(self):
        import mapping_controller as controller
        from test_mapping_replica import ReplicaCaptureTest
        fixture = ReplicaCaptureTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        from mapping_replica import completed, file_sha
        completion, inventory, _ = completed(fixture.base/'incoming'/fixture.generation,
            {source.DEVELOPMENT_RELEASE_ID})
        calls = []
        def remote(action, **kwargs):
            calls.append(action)
            if action == 'status':
                return dict(operation=dict(operationId=kwargs['target'], state='succeeded',
                    releaseId=source.DEVELOPMENT_RELEASE_ID, generationId=fixture.generation),
                    supervisorOrChildOwnsPipeline=False)
            if action == 'export':
                return dict(completion=completion, inventory=inventory,
                    completionSha256=file_sha(fixture.base/'incoming'/fixture.generation/'completion.json'))
            if action == 'acknowledge':
                return kwargs['data']
            return dict(state='succeeded')
        def local(action, **kwargs):
            calls.append(action)
            if action == 'capture':
                fixture.controller.capture(fixture.generation, transfer_complete=True,
                    validate=fixture.validate, operation_id=kwargs['operation'])
                return dict(status='accepted')
            if action == 'status':
                return fixture.controller.status(kwargs['target'])
            return dict(state='succeeded')
        class Transfer:
            def pause(self): calls.append('pause')
            def start(self): calls.append('resume'); return 0
            def observe(self, cycle): return dict(ready=True, progress=1)
        runner = controller.Controller(fixture.base, remote=remote, local=local,
            replica=fixture.controller, transfer=Transfer())
        for _ in range(20):
            result = runner.tick()
            if result['phase'] == 'complete': break
        self.assertEqual(result['phase'], 'complete', result)
        self.assertEqual(result['generationId'], fixture.generation)
        self.assertEqual(calls.count('capture'), 1)
        self.assertLess(calls.index('transfer-pin'), calls.index('resume'))
        self.assertLess(calls.index('acknowledge'), calls.index('transfer-release'))
        self.assertEqual(fixture.controller.receipt(fixture.generation),
            source.read_json(fixture.base/'acknowledgements'/f'{fixture.generation}.json'))
        for _ in range(20):
            result = runner.tick()
            if result['phase'] == 'complete': break
        self.assertEqual(result['phase'], 'complete', result)
        self.assertEqual(calls.count('capture'), 1, 'unchanged eligibility must be reused')

    def test_healthy_preparer_spans_ticks_and_defers_conflicting_invocations(self):
        import mapping_controller as controller
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def remote(action, **kwargs):
                calls.append(action)
                if action == 'status':
                    return dict(operation=dict(operationId=kwargs['target'],
                        releaseId=source.DEVELOPMENT_RELEASE_ID, state='running',
                        progressAtUtc='2026-10-13T00:00:00Z'), supervisorOrChildOwnsPipeline=True)
                return dict(status='accepted')
            runner = controller.Controller(Path(directory), remote=remote)
            runner.tick()
            for _ in range(3):
                result = runner.tick()
                self.assertEqual(result['phase'], 'prepare-wait')
                self.assertEqual(result['availability'], 'owned-progress-or-inspect')
            with runner.ownership():
                result = controller.Controller(Path(directory), remote=remote).tick()
                self.assertEqual(result['status'], 'busy')
            self.assertEqual(calls.count('prepare'), 1)

    def test_prepare_timeout_records_identity_and_inspects_before_retry(self):
        import mapping_controller as controller
        with tempfile.TemporaryDirectory() as directory:
            calls = []
            def remote(action, **kwargs):
                calls.append((action, kwargs))
                raise controller.CallUnknown('SSH budget 30 expired')
            runner = controller.Controller(Path(directory), remote=remote)
            first = runner.tick()
            self.assertEqual(first['phase'], 'prepare-wait')
            identity = first['sourceOperation']
            self.assertIn('30', first['diagnostic'])
            restarted = controller.Controller(Path(directory), remote=remote)
            second = restarted.tick()
            self.assertEqual(second['sourceOperation'], identity)
            self.assertEqual([call[0] for call in calls], ['prepare', 'status'])
            self.assertEqual(calls[1][1]['target'], identity)
            self.assertFalse((Path(directory)/'eligibility').exists())


if __name__ == '__main__':
    unittest.main()
