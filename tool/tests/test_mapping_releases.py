"""Installed release behavior on disposable trees, never live Mapping/SSH."""
import os
import sys
import tempfile
import unittest
import uuid
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
import mapping_releases as releases
import mapping_source as source


class ReleaseTest(unittest.TestCase):
    def test_unknown_never_dispatched_identity_is_fenced_before_retry(self):
        old = self.make_bundle()
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = old['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        old['artifacts'] = releases.artifacts(self.bundle)
        source.atomic_json(self.bundle/'release.json', old)
        manager = releases.Releases(self.base)
        manager.install(self.bundle)
        manager.select(old['releaseId'], self.root/'peer.json', self.root/'data')
        identity = str(uuid.uuid4())
        outcome = manager.reconcile(identity)
        self.assertEqual(outcome['state'], 'failed')
        with self.assertRaisesRegex(source.SourceError, 'already exists'):
            with manager.pin(identity):
                self.fail('late dispatch bypassed durable fence')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.bundle = self.root/'bundle'
        self.bundle.mkdir()
        self.base = self.root/'installed'
        self.addCleanup(self.dispose)

    def dispose(self):
        for root, directories, _ in os.walk(self.root):
            Path(root).chmod(0o755)
            for directory in directories:
                (Path(root)/directory).chmod(0o755)
        self.temp.cleanup()

    def make_bundle(self, role='controller', identity=None):
        identity = identity or str(uuid.uuid4())
        (self.bundle/'helper').write_text('complete helper v1')
        for name in releases.required_artifacts(role):
            target = self.bundle/name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('disposable installed stage')
            if name.startswith('bin/') or name.endswith('.sh'):
                target.chmod(0o755)
        manifest = releases.manifest_for(self.bundle, role=role, release_id=identity,
            source_ids=[source.DEVELOPMENT_RELEASE_ID],
            controller_ids=[source.DEVELOPMENT_CONTROLLER_ID, identity], dependencies=[])
        source.atomic_json(self.bundle/'release.json', manifest)
        return manifest

    def test_install_is_complete_repeatable_and_independent_of_bundle(self):
        manifest = self.make_bundle()
        manager = releases.Releases(self.base, workspace_roots=[self.root/'workspace'])
        path = manager.install(self.bundle)
        self.assertEqual(path, self.base/'releases'/manifest['releaseId'])
        self.assertEqual(manager.install(self.bundle), path)
        (self.bundle/'helper').write_text('partial source delivery')
        self.assertEqual((path/'helper').read_text(), 'complete helper v1')
        self.assertEqual(manager.inspect()['releases'][manifest['releaseId']]['state'], 'complete')
        self.assertEqual((path/'helper').stat().st_mode & 0o222, 0)
        (path/'helper').chmod(0o644)
        (path/'helper').write_text('drift')
        self.assertEqual(manager.inspect()['releases'][manifest['releaseId']]['state'], 'drift')

    def test_atomic_selection_preserves_last_usable_release_on_failed_upgrade(self):
        old = self.make_bundle()
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = old['controllerReleases']
        peer_path = self.root/'peer.json'
        source.atomic_json(peer_path, peer)
        old['artifacts'] = releases.artifacts(self.bundle)
        source.atomic_json(self.bundle/'release.json', old)
        manager = releases.Releases(self.base)
        manager.install(self.bundle)
        manager.select(old['releaseId'], peer_path, self.root/'data')
        selected = source.read_json(self.base/'selected.json')
        new = self.make_bundle()
        new['controllerReleases'] = sorted(new['controllerReleases'] + [old['releaseId']])
        peer['controllerReleases'] = new['controllerReleases']
        source.atomic_json(peer_path, peer)
        source.atomic_json(self.bundle/'release.json', new)
        manager.install(self.bundle)
        def failed(path, value):
            if path.name == 'selected.json':
                raise OSError('atomic publication failed')
            source.atomic_json(path, value)
        failing = releases.Releases(self.base, publish=failed)
        with self.assertRaisesRegex(OSError, 'publication failed'):
            failing.select(new['releaseId'], peer_path, self.root/'data')
        self.assertEqual(source.read_json(self.base/'selected.json'), selected)
        manager.select(new['releaseId'], peer_path, self.root/'data')
        self.assertEqual(manager.inspect()['selected']['releaseId'], new['releaseId'])

    def test_pinned_helper_and_surviving_child_block_retirement_until_reconciliation(self):
        old = self.make_bundle()
        manager = releases.Releases(self.base)
        path = manager.install(self.bundle)
        data = self.root/'data'
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = old['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        manager.select(old['releaseId'], self.root/'peer.json', data)
        operation = str(uuid.uuid4())
        with manager.pin(operation) as pinned:
            child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'],
                pass_fds=(pinned['fd'],))
            self.addCleanup(lambda: child.poll() is None and child.kill())
            new = self.make_bundle()
            (self.bundle/'helper').write_text('complete helper v2')
            new['artifacts'] = releases.artifacts(self.bundle)
            new['controllerReleases'] = sorted(new['controllerReleases'] + [old['releaseId']])
            peer['controllerReleases'] = new['controllerReleases']
            source.atomic_json(self.root/'peer.json', peer)
            source.atomic_json(self.bundle/'release.json', new)
            manager.install(self.bundle)
            manager.select(new['releaseId'], self.root/'peer.json', data)
            self.assertEqual((pinned['path']/'helper').read_text(), 'complete helper v1')
            self.assertEqual((self.base/'releases'/new['releaseId']/'helper').read_text(), 'complete helper v2')
            self.assertEqual(pinned['manifest']['releaseId'], old['releaseId'])
        with self.assertRaisesRegex(source.SourceError, 'protected'):
            manager.retire(old['releaseId'])
        with self.assertRaisesRegex(source.SourceError, 'surviving'):
            manager.reconcile(operation)
        child.terminate()
        child.wait(timeout=5)
        with self.assertRaisesRegex(source.SourceError, 'protected'):
            manager.retire(old['releaseId'])
        result = manager.reconcile(operation)
        self.assertEqual(result['state'], 'failed')
        manager.retire(old['releaseId'])
        self.assertFalse(path.exists())
        new['contracts']['mapping-eligibility'] = 2
        source.atomic_json(self.bundle/'release.json', new)
        with self.assertRaisesRegex(source.SourceError, 'unsupported.*metadata'):
            manager.install(self.bundle)
        self.assertEqual(manager.inspect()['selected']['releaseId'], new['releaseId'])

    def test_compatible_upgrade_reads_retained_generation_and_incompatible_rejection_is_read_only(self):
        from tool.tests.test_mapping_replica import ReplicaCaptureTest
        fixture = ReplicaCaptureTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        eligible = fixture.capture()
        old = self.make_bundle()
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = old['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        old['artifacts'] = releases.artifacts(self.bundle)
        source.atomic_json(self.bundle/'release.json', old)
        manager = releases.Releases(self.base)
        manager.install(self.bundle)
        manager.select(old['releaseId'], self.root/'peer.json', fixture.base)
        new = self.make_bundle()
        new['controllerReleases'] = sorted(new['controllerReleases'] + [old['releaseId']])
        peer['controllerReleases'] = new['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        source.atomic_json(self.bundle/'release.json', new)
        manager.install(self.bundle)
        manager.select(new['releaseId'], self.root/'peer.json', fixture.base)
        self.assertEqual(fixture.controller.eligible(fixture.generation), eligible)
        record_path = fixture.base/'eligibility'/f'{fixture.generation}.json'
        incompatible = dict(eligible, schemaVersion=2)
        source.atomic_json(record_path, incompatible)
        before = {p.relative_to(fixture.base).as_posix(): p.read_bytes()
                  for p in fixture.base.rglob('*') if p.is_file()}
        selected = (self.base/'selected.json').read_bytes()
        with self.assertRaisesRegex(source.SourceError, 'unsupported.*metadata'):
            manager.select(old['releaseId'], self.root/'peer.json', fixture.base)
        self.assertEqual((self.base/'selected.json').read_bytes(), selected)
        self.assertEqual(before, {p.relative_to(fixture.base).as_posix(): p.read_bytes()
                  for p in fixture.base.rglob('*') if p.is_file()})

    def test_packaged_stages_use_release_helpers_with_checkout_unavailable(self):
        checkout = self.root/'workspace'
        (checkout/'tool').mkdir(parents=True)
        (checkout/'test/fixtures/mapping_store/v1').mkdir(parents=True)
        actual = Path(__file__).parents[1]
        for name in (*releases.PYTHON_STAGES, *releases.REFRESH_STAGES):
            (checkout/'tool'/name).write_bytes((actual/name).read_bytes())
        (checkout/'test/fixtures/mapping_store/v1/tool_manifest.json').write_text('{}')
        (checkout/'tool/publish_thelist_dem.sh').write_text('#!/bin/sh\nexit 0\n')
        def compiler(source_path, output):
            output.write_text('#!/bin/sh\nprintf "%s\\n" "installed compiled helper v1"\n')
            output.chmod(0o755)
        bundle = self.root/'packaged'
        identity = str(uuid.uuid4())
        releases.build(checkout, bundle, role='controller', release_id=identity,
            source_ids=[source.DEVELOPMENT_RELEASE_ID],
            controller_ids=[source.DEVELOPMENT_CONTROLLER_ID, identity], compile_executable=compiler,
            dependencies=[dict(path=sys.executable, sha256=releases.sha(Path(sys.executable)))])
        manager = releases.Releases(self.base, workspace_roots=[checkout])
        manager.install(bundle)
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = sorted([source.DEVELOPMENT_CONTROLLER_ID, identity])
        source.atomic_json(self.root/'peer.json', peer)
        manager.select(identity, self.root/'peer.json', self.root/'data')
        checkout.rename(self.root/'unavailable-checkout')
        result = manager.run(['status'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(manager.inspect()['invocations'][0]['releaseId'], identity)
        with manager.pin(str(uuid.uuid4())) as pin:
            helper = subprocess.run([str(pin['path']/'bin/mapping_source_dataset')],
                capture_output=True, text=True, check=True)
            self.assertEqual(helper.stdout.strip(), 'installed compiled helper v1')
            self.assertEqual(pin['manifest']['dependencies'][0]['sha256'], releases.sha(Path(sys.executable)))

    def test_detached_installed_capture_uses_pinned_validator_and_release_ownership(self):
        from tool.tests.test_mapping_replica import ReplicaCaptureTest
        import time
        fixture = ReplicaCaptureTest()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        checkout = Path(__file__).parents[2]
        def compiler(_, output):
            output.write_text(f'#!{sys.executable}\n' +
                'import sys,json,time,hashlib\nrequest=json.load(sys.stdin)\ntime.sleep(.3)\n' +
                'inventory=request["integrity"]\nchecks=[dict(path=f["path"],checkId="sha256-v1",result="passed") for f in inventory["files"]]\n' +
                'checks += [dict(path=p,checkId=c,result="passed") for p,c in [("region_manifest.json","manifest-paths-v1"),("Polygons/manifest.json","manifest-paths-v1"),("region_manifest.json","peak-fingerprints-v1")]]\n' +
                'print(json.dumps(dict(checks=checks,diagnostics=[],inventorySha256=hashlib.sha256(json.dumps(inventory,separators=(",",":"),ensure_ascii=False).encode()).hexdigest())))\n')
            output.chmod(0o755)
        identity = str(uuid.uuid4())
        bundle = self.root/'compiled'
        releases.build(checkout, bundle, role='controller', release_id=identity,
            source_ids=[source.DEVELOPMENT_RELEASE_ID], controller_ids=[source.DEVELOPMENT_CONTROLLER_ID, identity],
            compile_executable=compiler, dependencies=[dict(path=sys.executable, sha256=releases.sha(Path(sys.executable)))])
        manager = releases.Releases(self.base)
        manager.install(bundle)
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = sorted([source.DEVELOPMENT_CONTROLLER_ID, identity])
        source.atomic_json(self.root/'peer.json', peer)
        manager.select(identity, self.root/'peer.json', fixture.base)
        operation = str(uuid.uuid4())
        result = manager.run(['capture', fixture.generation, '--transfer-complete'], operation_id=operation)
        self.assertEqual(result.returncode, 0, result.stderr)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            state = fixture.controller.status(operation)['operation']
            if state and state['state'] in ('succeeded', 'failed'):
                break
            time.sleep(.05)
        self.assertEqual(state['state'], 'succeeded', (fixture.base/'logs'/f'{operation}.log').read_text())
        self.assertEqual(state['releaseId'], identity)
        while True:
            try:
                result = manager.reconcile(operation)
                break
            except source.SourceError as error:
                if 'surviving' not in str(error) or time.monotonic() >= deadline:
                    raise
                time.sleep(.05)
        self.assertEqual(result['state'], 'succeeded')

    def test_partial_bundle_and_unsafe_roots_fail_before_installation(self):
        manifest = self.make_bundle()
        (self.bundle/'helper').unlink()
        manager = releases.Releases(self.base)
        with self.assertRaisesRegex(source.SourceError, 'incomplete/drifted'):
            manager.install(self.bundle)
        self.assertFalse((self.base/'releases'/manifest['releaseId']).exists())
        for target in (self.root/'workspace/installed', self.root/'workspace', Path('/Volumes/Services/Mapping/releases')):
            with self.assertRaises(source.SourceError):
                releases.Releases(target, workspace_roots=[self.root/'workspace'])

    def test_dependency_drift_and_invocation_override_cannot_resolve_checkout_code(self):
        dependency = self.root/'python-stable'
        dependency.write_text('stable dependency version 1')
        manifest = self.make_bundle()
        manifest['dependencies'] = [dict(path=str(dependency), sha256=releases.sha(dependency))]
        source.atomic_json(self.bundle/'release.json', manifest)
        manager = releases.Releases(self.base)
        manager.install(self.bundle)
        with self.assertRaisesRegex(source.SourceError, 'override'):
            manager.run(['--release-id', str(uuid.uuid4()), 'status'])
        dependency.write_text('dependency unexpectedly upgraded')
        self.assertEqual(manager.inspect()['releases'][manifest['releaseId']]['state'], 'drift')

    def test_interrupted_selection_after_rename_recovers_complete_prior_selection(self):
        old = self.make_bundle()
        manager = releases.Releases(self.base)
        manager.install(self.bundle)
        peer = self.make_bundle('source-preparer', source.DEVELOPMENT_RELEASE_ID)
        peer['controllerReleases'] = old['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        manager.select(old['releaseId'], self.root/'peer.json', self.root/'data')
        new = self.make_bundle()
        new['controllerReleases'] = sorted(new['controllerReleases'] + [old['releaseId']])
        peer['controllerReleases'] = new['controllerReleases']
        source.atomic_json(self.root/'peer.json', peer)
        source.atomic_json(self.bundle/'release.json', new)
        manager.install(self.bundle)
        def interrupted(path, value):
            source.atomic_json(path, value)
            if path.name == 'selected.json':
                raise OSError('parent flush interrupted after rename')
        with self.assertRaisesRegex(OSError, 'interrupted'):
            releases.Releases(self.base, publish=interrupted).select(new['releaseId'], self.root/'peer.json', self.root/'data')
        with releases.Releases(self.base).pin(str(uuid.uuid4())) as pinned:
            self.assertEqual(pinned['manifest']['releaseId'], old['releaseId'])

    def test_manifest_cannot_omit_a_required_stage_even_when_remaining_hashes_match(self):
        value = self.make_bundle()
        (self.bundle/'bin/mapping_source_dataset').unlink()
        value['artifacts'] = releases.artifacts(self.bundle)
        source.atomic_json(self.bundle/'release.json', value)
        with self.assertRaisesRegex(source.SourceError, 'required installed'):
            releases.Releases(self.base).install(self.bundle)

    def test_stable_dispatcher_runs_installed_source_inspection_from_unrelated_cwd(self):
        checkout = Path(__file__).parents[2]
        identity = str(uuid.uuid4())
        def compile_fake(_, output):
            output.write_text('#!/bin/sh\nprintf "%s\\n" "$MAPPING_PREPARATION_BASE"\n')
            output.chmod(0o755)
        bundle = self.root/'source-bundle'
        releases.build(checkout, bundle, role='source-preparer', release_id=identity,
            source_ids=[source.DEVELOPMENT_RELEASE_ID, identity],
            controller_ids=[source.DEVELOPMENT_CONTROLLER_ID], compile_executable=compile_fake,
            dependencies=[dict(path=sys.executable, sha256=releases.sha(Path(sys.executable)))])
        manager = releases.Releases(self.base)
        manager.install(bundle)
        peer = self.make_bundle('controller', source.DEVELOPMENT_CONTROLLER_ID)
        peer['sourceReleases'] = sorted([source.DEVELOPMENT_RELEASE_ID, identity])
        source.atomic_json(self.root/'peer.json', peer)
        manager.select(identity, self.root/'peer.json', self.root/'data')
        launcher = manager.install_launcher()
        result = subprocess.run([sys.executable, '-I', str(launcher), 'run', '--', 'status'],
            cwd=self.root, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(identity, result.stderr)
        self.assertIn('preparedExports', result.stdout)
        self.assertEqual(manager.install_launcher(), launcher)
        with manager.pin(str(uuid.uuid4())) as pin:
            helper = subprocess.run([str(pin['path']/'bin/dart'), 'run', 'tool/elvis_dem.dart'],
                env=dict(os.environ, MAPPING_PREPARATION_BASE=str(self.root/'data/preparation')),
                cwd=pin['path'], capture_output=True, text=True, timeout=5)
            self.assertEqual(helper.returncode, 0, helper.stderr)
            self.assertEqual(helper.stdout.strip(), str(self.root/'data/preparation'))


if __name__ == '__main__':
    unittest.main()
