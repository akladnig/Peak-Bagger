"""Exercise the documented operator sequence, not a production locking system.

Real Mutagen uses isolated local endpoints. Git travels over an isolated loopback
SSH server to a disposable owner repository. These are not live commissioning.
"""

import getpass
import os
import shlex
import shutil
import socket
import subprocess
import time
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

from tool import mutagen_workspace as workspace
from tool.tests.test_mutagen_workspace import DisposableWorkspace


class OperationsTests(DisposableWorkspace):
    def setUp(self):
        super().setUp()
        # The harness represents saved buffers and stopped agents/formatters/
        # generators on BOTH endpoints in ALL projects. Only named fixture writes
        # occur; no real editor or user process is being stopped by these tests.
        self.writers = {'alpha': False, 'beta': False}
        self.events = ['save-all', 'stop-alpha-all', 'stop-beta-all']
        self.ssh_server = None

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            if self.ssh_server:
                self.ssh_server.terminate()
                self.ssh_server.wait(timeout=10)
                self.ssh_server.stderr.close()

    def frozen(self):
        self.assertEqual(self.writers, {'alpha': False, 'beta': False})

    def freeze(self):
        self.events.extend(['save-all', 'stop-alpha-all', 'stop-beta-all'])
        self.writers = {'alpha': False, 'beta': False}

    def ready(self, timeout=5):
        self.frozen()
        workspace.flush_ready(self.plans, timeout=timeout)
        self.events.append('ready-all-three')

    def resume(self, side):
        self.frozen()
        self.assertEqual(self.events[-1], 'ready-all-three')
        self.writers[side] = True
        self.events.append('resume-' + side + '-only')

    def edit(self, side, plan, path, text):
        self.assertTrue(self.writers[side])
        self.assertFalse(self.writers['beta' if side == 'alpha' else 'alpha'])
        self.events.append('edit-' + side + '-' + plan.project)
        return self.put(getattr(plan, side), path, text)

    def activate(self):
        workspace.setup(self.plans)
        workspace.activate(self.plans)
        self.ready()

    def start_git_ssh(self):
        """No system SSH config, keys, known_hosts or Remote Login changes."""
        sshd = shutil.which('sshd') or '/usr/sbin/sshd'
        if not Path(sshd).is_file():
            self.fail('isolated sshd unavailable; remote Git verification is pending')
        private = self.directory / 'ssh-private'
        private.mkdir(mode=0o700)
        key = private / 'client'
        host = private / 'host'
        for path in (key, host):
            workspace.run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(path)])
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            port = listener.getsockname()[1]
        config = private / 'sshd_config'
        config.write_text('\n'.join([
            f'Port {port}', 'ListenAddress 127.0.0.1', f'HostKey "{host}"',
            f'PidFile "{private / "pid"}"', f'AuthorizedKeysFile "{key}.pub"',
            'StrictModes no', 'PasswordAuthentication no',
            'KbdInteractiveAuthentication no', 'UsePAM no',
            'AllowAgentForwarding no', 'AllowTcpForwarding no',
            'X11Forwarding no', f'AllowUsers {getpass.getuser()}',
        ]) + '\n')
        known = private / 'known_hosts'
        known.write_text(f'[127.0.0.1]:{port} ' + Path(str(host) + '.pub').read_text())
        self.ssh_server = subprocess.Popen(
            [sshd, '-D', '-e', '-f', str(config)], stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True,
        )
        self.ssh = ['ssh', '-F', '/dev/null', '-T', '-p', str(port),
                    '-i', str(key), '-o', 'IdentitiesOnly=yes',
                    '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
                    '-o', 'UserKnownHostsFile=' + str(known),
                    '-o', 'ConnectTimeout=2', getpass.getuser() + '@127.0.0.1']
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if self.ssh_server.poll() is not None:
                self.fail('isolated sshd failed; verification pending: ' + self.ssh_server.stderr.read())
            try:
                workspace.run(self.ssh + ['true'], timeout=3)
                return
            except workspace.SetupError:
                time.sleep(0.1)
        self.fail('isolated SSH not reachable; verification pending')

    def owner_git(self, plan, *args):
        self.frozen()
        command = next((arg for arg in args if arg in ('init', 'add', 'commit', 'branch',
                                                      'show', 'checkout', 'status')), args[0])
        self.events.append('owner-git-' + command)
        return workspace.run(self.ssh + [shlex.join(['git', '-C', plan.alpha, *args])])

    def gated_git(self, plan, *args, replaces_files=False):
        self.ready(timeout=2)
        result = self.owner_git(plan, *args)
        self.frozen()
        if replaces_files:
            self.ready()
        return result

    def test_remote_commit_file_replacement_and_sequential_handover(self):
        self.start_git_ssh()
        plan = self.plans[0]
        # Repository preparation is outside ordinary development, with writers
        # frozen; per-command identity never changes a user's Git configuration.
        self.put(plan.alpha, 'tracked.dart', 'baseline\n')
        self.put(plan.beta, 'tracked.dart', 'baseline\n')
        for root in (plan.alpha, plan.beta):
            self.put(root, 'retained.dart', 'unchanged on both branches\n')
        self.owner_git(plan, 'init', '-q', '-b', 'initial')
        self.owner_git(plan, 'add', 'pubspec.yaml', 'tracked.dart', 'retained.dart')
        identity = ['-c', 'user.name=Disposable', '-c', 'user.email=disposable@example.invalid']
        self.owner_git(plan, *identity, 'commit', '-qm', 'baseline')
        self.owner_git(plan, 'branch', 'replacement')
        self.activate()
        self.resume('beta')
        self.edit('beta', plan, 'tracked.dart', 'saved mini edit\n')
        self.freeze()
        self.gated_git(plan, 'add', 'tracked.dart')
        self.assertEqual((Path(plan.alpha) / 'tracked.dart').read_text(), 'saved mini edit\n')
        self.gated_git(plan, *identity, 'commit', '-qm', 'mini-originating work')
        self.assertEqual(self.events[-2:], ['ready-all-three', 'owner-git-commit'])
        self.assertEqual(self.owner_git(plan, 'show', 'HEAD:tracked.dart'), 'saved mini edit\n')

        self.ready()
        self.resume('beta')
        self.edit('beta', plan, 'retained.dart', 'mini work before replacement\n')
        self.freeze()
        self.ready()
        self.assertEqual((Path(plan.alpha) / 'retained.dart').read_text(),
                         'mini work before replacement\n')
        self.gated_git(plan, 'checkout', 'replacement', replaces_files=True)
        self.assertEqual((Path(plan.beta) / 'tracked.dart').read_text(), 'baseline\n')
        self.assertEqual((Path(plan.beta) / 'retained.dart').read_text(),
                         'mini work before replacement\n')
        self.assertFalse((Path(plan.beta) / '.git').exists())
        self.assertEqual(self.events[-3:], ['ready-all-three', 'owner-git-checkout', 'ready-all-three'])
        self.resume('alpha')
        for member in self.plans:
            self.edit('alpha', member, 'handover.dart', member.project + '\n')
        self.freeze()
        self.ready()
        for member in self.plans:
            self.assertEqual((Path(member.beta) / 'handover.dart').read_text(), member.project + '\n')
        self.resume('beta')
        self.assertEqual(self.writers, {'alpha': False, 'beta': True})
        # A failure AFTER checkout blocks resumption too. Pause a dependency
        # session just after Git returns to simulate interrupted post-checks.
        self.freeze()
        dependency = workspace.find_session(self.plans[-1], workspace.sessions())['identifier']
        owner_git = self.owner_git

        def checkout_then_interrupt(*args):
            result = owner_git(*args)
            workspace.run(['mutagen', 'sync', 'pause', dependency])
            return result

        with (
            patch.object(self, 'owner_git', side_effect=checkout_then_interrupt),
            self.assertRaisesRegex(workspace.SetupError, 'flutter_map_tile_caching:.*paused'),
        ):
            self.gated_git(plan, 'checkout', 'initial', replaces_files=True)
        self.assertEqual(self.events[-1], 'owner-git-checkout')
        self.frozen()
        with self.assertRaises(AssertionError):
            self.resume('beta')
        workspace.run(['mutagen', 'sync', 'resume', dependency])
        self.ready()
        self.resume('beta')
        print('\nOPERATOR SEQUENCE:', ' -> '.join(self.events))

    def test_conflict_blocks_git_and_handover_until_deliberate_resolution(self):
        self.start_git_ssh()
        plan = self.plans[-1]  # A dependency conflict blocks Peak Bagger Git too.
        for root in (plan.alpha, plan.beta):
            self.put(root, 'conflict.dart', 'baseline')
        self.activate()
        identifier = workspace.find_session(plan, workspace.sessions())['identifier']
        workspace.run(['mutagen', 'sync', 'pause', identifier])
        # Explicit setup probes simulate two incompatible disconnected edits.
        self.put(plan.alpha, 'conflict.dart', 'MacBook independent edit')
        self.put(plan.beta, 'conflict.dart', 'mini independent edit')
        self.put(plan.beta, 'unconflicted.dart', 'independent path')
        workspace.run(['mutagen', 'sync', 'resume', identifier])
        for args in [('add', 'pubspec.yaml'), ('commit', '-m', 'must not run'), ('checkout', 'must-not-run')]:
            before = list(self.events)
            with self.assertRaisesRegex(workspace.SetupError, 'flutter_map_tile_caching:.*conflicts'):
                self.gated_git(self.plans[0], *args, replaces_files=args[0] == 'checkout')
            self.assertEqual(self.events, before)  # No Git dispatch or resumption.
            self.frozen()
        self.assertEqual((Path(plan.alpha) / 'conflict.dart').read_text(), 'MacBook independent edit')
        self.assertEqual((Path(plan.beta) / 'conflict.dart').read_text(), 'mini independent edit')
        self.assertEqual((Path(plan.alpha) / 'unconflicted.dart').read_text(), 'independent path')
        state = workspace.find_session(plan, workspace.sessions())
        self.assertTrue(state['conflicts'])
        workspace.run(['mutagen', 'sync', 'pause', identifier])
        recovery = self.directory / 'recovery-outside-roots'
        recovery.mkdir()
        for side in ('alpha', 'beta'):
            shutil.copyfile(Path(getattr(plan, side)) / 'conflict.dart', recovery / side)
        # The operator explicitly combines both versions; neither is chosen by
        # Mutagen, and the session/reconciliation history is never reset.
        agreed = 'MacBook independent edit\nmini independent edit\n'
        for root in (plan.alpha, plan.beta):
            self.put(root, 'conflict.dart', agreed)
        workspace.run(['mutagen', 'sync', 'resume', identifier])
        self.ready()
        self.assertEqual(workspace.find_session(plan, workspace.sessions())['identifier'], identifier)
        self.assertEqual((recovery / 'alpha').read_text(), 'MacBook independent edit')
        self.assertEqual((recovery / 'beta').read_text(), 'mini independent edit')
        self.assertEqual((Path(plan.alpha) / 'conflict.dart').read_text(), agreed)
        self.assertEqual((Path(plan.beta) / 'conflict.dart').read_text(), agreed)
        self.resume('beta')
        print('\nCONFLICT: blocked add/commit/checkout/handover; both versions preserved; '
              'unconflicted path delivered; explicit combined content resolved on same session')

    def test_each_disconnected_or_missing_session_blocks_operations(self):
        # Reserve an ephemeral port without listening. The user's Remote Login
        # can remain enabled on port 22, and another server cannot take this port.
        closed_endpoint = socket.socket()
        self.addCleanup(closed_endpoint.close)
        closed_endpoint.bind(('127.0.0.1', 0))
        port = closed_endpoint.getsockname()[1]
        tools = self.directory / 'ssh-tools'
        tools.mkdir(mode=0o700)
        config = tools / 'config'
        config.write_text('\n'.join([
            'Host disconnected-fixture', 'HostName 127.0.0.1', f'Port {port}',
            'BatchMode yes', 'StrictHostKeyChecking yes',
            'UserKnownHostsFile /dev/null',
        ]) + '\n')
        for name in ('ssh', 'scp'):
            executable = tools / name
            executable.write_text(
                f'#!/bin/sh\nexec /usr/bin/{name} -F {shlex.quote(str(config))} "$@"\n'
            )
            executable.chmod(0o700)
        # Mutagen captures its SSH executable search path at daemon startup.
        # Only the existing isolated test daemon is restarted; user settings,
        # credentials, known_hosts and the real controlling daemon stay separate.
        workspace.run(['mutagen', 'daemon', 'stop'])
        with patch.dict(os.environ, {
            'MUTAGEN_SSH_PATH': str(tools), 'MUTAGEN_SSH_CONNECT_TIMEOUT': '1',
        }):
            workspace.run(['mutagen', 'daemon', 'start'])
        for index, original in enumerate(list(self.plans)):
            with self.subTest(project=original.project):
                self.frozen()
                self.plans[index] = replace(original, host='disconnected-fixture')
                for member in self.plans:
                    identifier = workspace.create(member)
                    if member.host:
                        with self.assertRaisesRegex(workspace.SetupError, 'Connection refused|Operation timed out'):
                            workspace.run(['mutagen', 'sync', 'resume', identifier])
                    else:
                        workspace.run(['mutagen', 'sync', 'resume', identifier])
                for args in [('add', 'pubspec.yaml'), ('commit', '-m', 'blocked'), ('checkout', 'blocked')]:
                    with self.assertRaisesRegex(workspace.SetupError, original.project + ':'):
                        self.gated_git(self.plans[0], *args, replaces_files=args[0] == 'checkout')
                    self.frozen()
                state = workspace.find_session(self.plans[index], workspace.sessions())
                self.assertFalse(state['beta'].get('connected', False))
                self.assertTrue(workspace.problems(state))
                workspace.run(['mutagen', 'sync', 'terminate', state['identifier']])
                with self.assertRaisesRegex(workspace.SetupError, original.project + ':.*missing'):
                    self.ready(timeout=1)
                self.assertFalse(any(event.startswith(('owner-git', 'resume-'))
                                     for event in self.events))
                for state in workspace.sessions():
                    workspace.run(['mutagen', 'sync', 'terminate', state['identifier']])
                self.plans[index] = original
                print('\nNOT READY:', original.project, 'disconnected then missing; writers remain stopped')

    def test_unreachable_git_owner_has_no_mirror_repository_fallback(self):
        self.start_git_ssh()
        self.activate()
        self.ssh_server.terminate()
        self.ssh_server.wait(timeout=10)
        self.ready()
        with self.assertRaisesRegex(workspace.SetupError, 'ssh failed'):
            self.owner_git(self.plans[0], 'status', '--short')
        self.frozen()
        for plan in self.plans:
            self.assertFalse((Path(plan.beta) / '.git').exists())
        print('\nGIT UNAVAILABLE: unreachable SSH owner; no beta Git repository created')
