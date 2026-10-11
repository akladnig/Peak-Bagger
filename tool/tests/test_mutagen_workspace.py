"""Disposable operational verification; requires the inspected Mutagen binary.

An isolated daemon/data directory and local endpoints never touch user sessions,
source or databases. The full lifecycle exercises real Mutagen, not a fake sync.
"""

import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from tool import mutagen_scope as scope
from tool import mutagen_workspace as workspace


class ScopeTests(unittest.TestCase):
    def test_negation_keeps_placeholder_but_does_not_traverse_ignored_payload(self):
        patterns = ['/input/*', '!/input/.gitignore', '.git', '**/Flutter/ephemeral']
        self.assertFalse(scope.ignored('input/.gitignore', False, patterns))
        self.assertTrue(scope.ignored('input/payload', True, patterns))
        self.assertTrue(scope.ignored('example/.git', False, patterns))
        self.assertTrue(scope.ignored('example/macos/Flutter/ephemeral', True, patterns))
        self.assertFalse(scope.ignored('input', True, patterns))

    def test_readiness_rejects_every_error_surface_including_truncated_problems(self):
        clean = {'status': 'watching', 'successfulCycles': 1,
                 'alpha': {'connected': True, 'scanned': True},
                 'beta': {'connected': True, 'scanned': True}}
        self.assertEqual(workspace.problems(clean), [])
        for key, value in [('paused', True), ('status', 'staging-beta'),
                           ('conflicts', [{}]), ('excludedConflicts', 1),
                           ('lastError', 'offline'), ('successfulCycles', 0)]:
            with self.subTest(key=key):
                self.assertTrue(workspace.problems({**clean, key: value}))
        for key, value in [('connected', False), ('scanned', False),
                           ('scanProblems', [{}]), ('excludedScanProblems', 1),
                           ('transitionProblems', [{}]), ('excludedTransitionProblems', 1),
                           ('stagingProgress', {'received': 1})]:
            with self.subTest(key=key):
                self.assertTrue(workspace.problems({**clean, 'beta': {**clean['beta'], key: value}}))


class DisposableWorkspace(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not shutil.which('mutagen'):
            raise RuntimeError('Mutagen is required; verification must not silently skip')
        # Keep the daemon socket below macOS's sockaddr_un path-length limit.
        cls.temp = tempfile.TemporaryDirectory(prefix='m-', dir=os.environ.get('MUTAGEN_TEST_TMPDIR'))
        cls.base = Path(cls.temp.name).resolve()
        cls.environment = patch.dict(os.environ, {'MUTAGEN_DATA_DIRECTORY': str(cls.base / 'd')})
        cls.environment.start()
        # Registered start/stop route through launchctl, ignoring the fixture's
        # data directory. Own a foreground daemon instead of touching user jobs.
        cls.daemon_log = (cls.base / 'daemon.log').open('w+')
        try:
            cls.start_daemon()
            if workspace.sessions():
                raise RuntimeError('disposable daemon must start with no sessions')
        except Exception:
            cls.tearDownClass()
            raise

    @classmethod
    def start_daemon(cls, environment=None):
        cls.daemon = subprocess.Popen(['mutagen', 'daemon', 'run'],
                                      env={**os.environ, **(environment or {})},
                                      stdout=cls.daemon_log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 10
        socket = cls.base / 'd' / 'daemon' / 'daemon.sock'
        while not socket.exists():
            if cls.daemon.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('isolated Mutagen daemon did not start')
            time.sleep(0.05)

    @classmethod
    def stop_daemon(cls):
        cls.daemon.terminate()
        try:
            cls.daemon.wait(timeout=10)
        except subprocess.TimeoutExpired:
            cls.daemon.kill()
            cls.daemon.wait(timeout=10)

    @classmethod
    def tearDownClass(cls):
        try:
            cls.stop_daemon()
        finally:
            cls.daemon_log.close()
            cls.environment.stop()
            cls.temp.cleanup()

    def setUp(self):
        self.directory = self.base / self._testMethodName
        self.directory.mkdir()
        self.config = json.loads(workspace.CONFIG.read_text())
        self.plans = []
        for project, settings in self.config['projects'].items():
            alpha, beta = (self.directory / side / project for side in ('alpha', 'beta'))
            alpha.mkdir(parents=True)
            beta.mkdir(parents=True)
            for root in (alpha, beta):
                (root / 'pubspec.yaml').write_text('name: disposable\n')
            self.plans.append(workspace.Plan(project, 'verify-' + settings['name'], str(alpha), str(beta), '',
                                             self.config['common_ignores'] + settings['ignores']))

    def tearDown(self):
        for session in workspace.sessions():
            workspace.run(['mutagen', 'sync', 'terminate', session['identifier']])

    def put(self, root, path, contents='fixture'):
        target = Path(root) / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(contents)
        return target


class MutagenIntegrationTests(DisposableWorkspace):
    def test_bootstrap_three_sessions_scope_deletions_and_offline_conflicts(self):
        shared = ['lib/main.dart', 'test/source_test.dart', 'README.md', 'docs/guide.md',
                  'ai_specs/example/spec.md', 'assets/icon.svg', 'pubspec.lock',
                  'example/pubspec.lock', 'macos/Podfile.lock', 'lib/objectbox.g.dart',
                  'lib/objectbox-model.json', 'lib/libobjectbox.dylib',
                  'dart_defines.example.json', 'example/lib/main.dart',
                  'macos/Flutter/GeneratedPluginRegistrant.swift',
                  'local_topo/tasmania/config/server.yaml', 'local_topo/tasmania/styles/style.json',
                  'local_topo/tasmania/tests/source.test.mjs', 'local_topo/tasmania/package-lock.json']
        excluded = ['dart_defines.local.json', '.dart_defines.local.json.seed-private',
                    'objectbox/data.mdb', 'objectbox/lock.mdb', '.dart_tool/package_config.json',
                    'build/app', 'coverage/lcov.info', '.pub/cache', '.pub-cache/package',
                    '.cache/data', '.flutter-plugins-dependencies', 'node_modules/package/index.js',
                    '__pycache__/source.pyc', 'runtime.log', 'process.pid', 'file.tmp', '.DS_Store',
                    'example/.git', 'example/.dart_tool/config', 'example/build/app',
                    'example/macos/Pods/dep', 'macos/Flutter/ephemeral/path',
                    'example/windows/flutter/ephemeral/path', 'macos/Runner.xcodeproj/xcuserdata/state',
                    'example/android/local.properties', 'example/android/key.properties',
                    'example/android/.gradle/cache', 'example/ios/Flutter/Generated.xcconfig']
        print('\nFREEZE: saved fixture edits; no background source writers; remains through first ready')
        for plan in self.plans:
            paths = list(excluded)
            if plan.project == 'peak_bagger':
                paths += ['local_topo/tasmania/input/large.tif', 'local_topo/tasmania/output/tiles/1.png',
                          'local_topo/tasmania/runtime/state.json', 'local_topo/tasmania/.tmp-start-stack-tests/output']
                for folder in ('input', 'output', 'runtime'):
                    self.put(plan.alpha, 'local_topo/tasmania/' + folder + '/.gitignore', '*\n')
            elif plan.project == 'flutter_map_tile_caching':
                paths += ['test/lib/libobjectbox.dylib', 'test/download/archive', 'tile_server/bin/tile_server.exe']
            for path in shared:
                self.put(plan.alpha, path, 'MacBook baseline: ' + path)
            self.put(plan.beta, 'lib/main.dart', 'old mini version')
            self.put(plan.beta, 'lib/deleted_on_macbook.dart', 'stale mini-only')
            self.put(plan.beta, 'lib/unique_untracked.dart', 'unique mini work')
            for path in paths:
                self.put(plan.alpha, path, 'alpha private')
                self.put(plan.beta, path, 'beta private')

            # A real temporary Git repository preserves unique commits, a branch,
            # stash, staged/unstaged and untracked work outside every sync root.
            def git(*args, root=plan.beta):
                return workspace.run(['git', '-C', root, *args])

            git('init', '-q')
            git('add', 'pubspec.yaml')
            git('-c', 'user.name=Disposable', '-c', 'user.email=disposable@example.invalid', 'commit', '-qm', 'unique mini commit')
            git('branch', 'unique-mini-branch')
            self.put(plan.beta, 'pubspec.yaml', 'name: stashed\n')
            git('stash', 'push', '-m', 'unique stash')
            self.put(plan.beta, 'staged.dart', 'staged work')
            git('add', 'staged.dart')
            self.put(plan.beta, 'pubspec.yaml', 'name: unstaged\n')
            backup = self.directory / 'recovery' / plan.project
            shutil.copytree(plan.beta, backup)
            metadata = self.directory / 'git-metadata' / plan.project
            metadata.parent.mkdir(exist_ok=True)
            shutil.move(str(Path(plan.beta) / '.git'), metadata)
            self.assertIn('unique stash', workspace.run(['git', '-C', str(backup), 'stash', 'list']))
            self.assertIn('unique-mini-branch', workspace.run(['git', '-C', str(backup), 'branch']))
            self.assertIn('staged.dart', workspace.run(['git', '-C', str(backup), 'diff', '--cached', '--name-only']))
            self.assertEqual((backup / 'lib/unique_untracked.dart').read_text(), 'unique mini work')
            self.assertTrue(metadata.is_dir())
            with self.assertRaisesRegex(workspace.SetupError, 'baseline differs'):
                workspace.baseline(plan)
            workspace.seed(plan)
            workspace.baseline(plan)
            self.assertFalse((Path(plan.beta) / 'lib/deleted_on_macbook.dart').exists())
            self.assertFalse((Path(plan.alpha) / 'lib/deleted_on_macbook.dart').exists())
            self.assertFalse((Path(plan.beta) / 'lib/unique_untracked.dart').exists())
            for path in paths:
                self.assertEqual((Path(plan.beta) / path).read_text(), 'beta private', path)
                self.assertEqual((Path(plan.alpha) / path).read_text(), 'alpha private', path)

        workspace.setup(self.plans)
        ids = [s['identifier'] for s in workspace.sessions()]
        workspace.setup(self.plans)
        self.assertEqual(ids, [s['identifier'] for s in workspace.sessions()])
        with self.assertRaisesRegex(workspace.SetupError, 'NOT READY'):
            workspace.flush_ready(self.plans, timeout=1)
        # Baseline failure must block activation of ALL projects.
        probe = self.put(self.plans[-1].beta, 'unagreed.dart')
        with self.assertRaisesRegex(workspace.SetupError, 'baseline differs'):
            workspace.activate(self.plans)
        self.assertTrue(all(s['paused'] for s in workspace.sessions()))
        probe.unlink()
        workspace.activate(self.plans)
        print('FIRST THREE-SESSION READY: freeze may end only on selected development endpoint')
        for plan in self.plans:
            for path in shared:
                self.assertEqual((Path(plan.beta) / path).read_text(), 'MacBook baseline: ' + path)
            if plan.project == 'peak_bagger':
                for folder in ('input', 'output', 'runtime'):
                    self.assertEqual((Path(plan.beta) / 'local_topo/tasmania' / folder / '.gitignore').read_text(), '*\n')
            # Newly created exclusions must not propagate, including .git files.
            self.put(plan.alpha, '.git', 'gitdir: outside')
            self.put(plan.alpha, '.cache/alpha-only', 'private')
            self.put(plan.beta, 'objectbox/mini-only/lock.mdb', 'private')
            self.put(plan.beta, 'lib/from_mini.dart', 'saved mini edit')
            (Path(plan.alpha) / 'lib/main.dart').unlink()
        workspace.flush_ready(self.plans)
        for plan in self.plans:
            self.assertFalse((Path(plan.beta) / 'lib/main.dart').exists())
            self.assertFalse((Path(plan.beta) / '.git').exists())
            self.assertFalse((Path(plan.beta) / '.cache/alpha-only').exists())
            self.assertFalse((Path(plan.alpha) / 'objectbox/mini-only/lock.mdb').exists())
            self.assertEqual((Path(plan.alpha) / 'lib/from_mini.dart').read_text(), 'saved mini edit')

        # Pause simulates disconnected synchronization without claiming a real
        # SSH/network outage. Incompatible saved offline edits survive reconnect.
        for identifier in ids:
            workspace.run(['mutagen', 'sync', 'pause', identifier])
        for plan in self.plans:
            self.put(plan.alpha, 'README.md', 'offline alpha edit')
            self.put(plan.beta, 'README.md', 'offline beta edit')
            self.put(plan.alpha, 'lib/objectbox.g.dart', 'offline edit versus deletion')
            (Path(plan.beta) / 'lib/objectbox.g.dart').unlink()
        for identifier in ids:
            workspace.run(['mutagen', 'sync', 'resume', identifier])
        with self.assertRaisesRegex(workspace.SetupError, 'conflicts'):
            workspace.flush_ready(self.plans, timeout=2)
        for plan in self.plans:
            self.assertEqual((Path(plan.alpha) / 'README.md').read_text(), 'offline alpha edit')
            self.assertEqual((Path(plan.beta) / 'README.md').read_text(), 'offline beta edit')
            self.assertEqual((Path(plan.alpha) / 'lib/objectbox.g.dart').read_text(), 'offline edit versus deletion')
            # Mutagen 0.18.1 preserves a modification over a plain deletion:
            # it restores the edited file rather than reporting that as conflict.
            self.assertEqual((Path(plan.beta) / 'lib/objectbox.g.dart').read_text(), 'offline edit versus deletion')
            state = workspace.find_session(plan, workspace.sessions())
            self.assertGreaterEqual(len(state['conflicts']), 1)
        # Reapplying setup retains conflict state and does not resume/reset it.
        workspace.setup(self.plans)
        self.assertEqual(ids, [s['identifier'] for s in workspace.sessions()])
        self.assertTrue(all(s['conflicts'] for s in workspace.sessions()))
        print('FAILED READY: all three same-file conflicts reported; both edits retained; plain edit/delete preserves modification; writers remain stopped')

    def test_failed_seed_is_paused_recoverable_and_not_replayed(self):
        plan = self.plans[0]
        self.put(plan.alpha, 'lib/main.dart', 'agreed source')
        self.put(plan.beta, 'lib/main.dart', 'preserved old mini source')
        backup = self.directory / 'recovery'
        shutil.copytree(plan.beta, backup)
        # Model a failed independent verification AFTER replica transitions.
        with (
            patch.object(workspace, 'baseline', side_effect=workspace.SetupError('baseline differs')),
            self.assertRaisesRegex(workspace.SetupError, 'baseline differs'),
        ):
            workspace.seed(plan)
        state = workspace.sessions()[0]
        self.assertTrue(state['paused'])
        self.assertEqual(state['mode'], 'one-way-replica')
        self.assertEqual((backup / 'lib/main.dart').read_text(), 'preserved old mini source')
        with self.assertRaises(workspace.SetupError):
            workspace.seed(plan)
        self.assertEqual(len(workspace.sessions()), 1)
        self.assertEqual(state['identifier'], workspace.sessions()[0]['identifier'])

    def test_real_configuration_drift_retains_work_and_conflicts(self):
        plan = self.plans[0]
        for scenario in ('roots', 'mode', 'exclusions'):
            with self.subTest(scenario=scenario):
                altered = plan
                if scenario == 'roots':
                    wrong = self.directory / 'wrong-root'
                    wrong.mkdir()
                    altered = replace(plan, alpha=str(wrong))
                elif scenario == 'mode':
                    altered = replace(plan, mode='two-way-resolved')
                else:
                    altered = replace(plan, ignores=[p for p in plan.ignores if p != 'data.mdb'])
                self.put(altered.alpha, 'conflict.dart', 'alpha saved work')
                self.put(altered.beta, 'conflict.dart', 'beta saved work')
                identifier = workspace.create(altered)
                # Leave root/missing-ignore sessions genuinely conflicted; wrong
                # mode stays paused so its resolving semantics cannot choose a winner.
                if scenario != 'mode':
                    workspace.run(['mutagen', 'sync', 'resume', identifier])
                    workspace.run(['mutagen', 'sync', 'flush', identifier])
                before = workspace.sessions()[0]
                with self.assertRaisesRegex(workspace.SetupError, 'peak_bagger: configuration drift'):
                    workspace.setup(self.plans)
                after = workspace.sessions()[0]
                self.assertEqual(before['identifier'], after['identifier'])
                self.assertEqual(before.get('conflicts'), after.get('conflicts'))
                self.assertEqual(len(workspace.sessions()), 1)
                self.assertEqual((Path(altered.alpha) / 'conflict.dart').read_text(), 'alpha saved work')
                self.assertEqual((Path(altered.beta) / 'conflict.dart').read_text(), 'beta saved work')
                workspace.run(['mutagen', 'sync', 'terminate', identifier])

    def test_overlapping_session_and_endpoint_override_fail_closed(self):
        plan = self.plans[0]
        identifier = workspace.create(plan)
        state = workspace.sessions()[0]
        state['alpha']['ignore']['paths'] = ['data.mdb']
        with self.assertRaisesRegex(workspace.SetupError, 'override'):
            workspace.find_session(plan, [state])
        other = replace(plan, name='unrecognized-overlap')
        workspace.create(other)
        with self.assertRaisesRegex(workspace.SetupError, 'duplicate/overlapping'):
            workspace.setup(self.plans)
        self.assertIn(identifier, [s['identifier'] for s in workspace.sessions()])

    def test_missing_root_and_git_metadata_block_creation(self):
        plan = self.plans[0]
        self.put(plan.beta, '.git', 'gitdir: external-worktree')
        with self.assertRaisesRegex(workspace.SetupError, 'Git metadata'):
            workspace.setup(self.plans)
        self.assertEqual(workspace.sessions(), [])
        (Path(plan.beta) / '.git').unlink()
        shutil.rmtree(plan.beta)
        with self.assertRaisesRegex(workspace.SetupError, 'invalid disposable beta root'):
            workspace.setup(self.plans)
        self.assertFalse(Path(plan.beta).exists())


if __name__ == '__main__':
    unittest.main()
