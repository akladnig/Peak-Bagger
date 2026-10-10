"""Repeatable three-project Mutagen setup. Live seeding is a commissioning step.

Persistent JSON is the source of truth; sessions capture its settings on creation.
No implicit terminate/reset/replacement, filesystem mkdir, or winner selection.
"""

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

if __package__:
    from . import mutagen_scope
else:
    import mutagen_scope

CONFIG = Path(__file__).with_name('mutagen-workspace.json')
PROJECTS = ('peak_bagger', 'trip_routing', 'flutter_map_tile_caching')


class SetupError(RuntimeError):
    pass


def run(args, timeout=45, input=None):
    try:
        result = subprocess.run(args, input=input, text=True, capture_output=True,
                                timeout=timeout, check=True)
        return result.stdout
    except subprocess.TimeoutExpired as error:
        raise SetupError(f'{args[0]} timed out; readiness failed') from error
    except subprocess.CalledProcessError as error:
        raise SetupError(f'{args[0]} failed: {error.stderr.strip()}') from error


@dataclass
class Plan:
    project: str
    name: str
    alpha: str
    beta: str
    host: str
    ignores: list
    mode: str = 'two-way-safe'

    @property
    def beta_url(self):
        return f'{self.host}:{self.beta}' if self.host else self.beta


def plans():
    config = json.loads(CONFIG.read_text())
    if (tuple(config['projects']) != PROJECTS or config['mode'] != 'two-way-safe'
            or config['alpha_root'] != '~/Development/mapping'
            or config['beta_root'] != '/Volumes/Development/mapping'):
        raise SetupError('configuration must retain the approved three-project scope/mode')
    host = config['ssh_alias']
    if not host or host.startswith('-') or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-' for c in host):
        raise SetupError('invalid SSH alias')
    return [Plan(project, config['projects'][project]['name'],
                 str(Path(config['alpha_root']).expanduser() / project),
                 config['beta_root'] + '/' + project, host,
                 config['common_ignores'] + config['projects'][project]['ignores'])
            for project in PROJECTS]


def sessions():
    return json.loads(run(['mutagen', 'sync', 'list', '--template', '{{json .}}']))


def endpoint(path, host=''):
    return {'protocol': 'ssh' if host else 'local', 'path': path, 'host': host}


def same_endpoint(actual, expected):
    return all(actual.get(key, '') == value for key, value in expected.items()) and not (
        actual.get('user') or actual.get('port') or actual.get('environment') or actual.get('parameters'))


def overlap(a, b):
    return a == b or a.startswith(b.rstrip('/') + '/') or b.startswith(a.rstrip('/') + '/')


def ssh_identity(host):
    values = dict(line.split(' ', 1) for line in run(['ssh', '-G', host]).splitlines() if ' ' in line)
    return tuple(values.get(key) for key in ('hostname', 'user', 'port'))


def transport_matches(actual, expected):
    if actual.get('protocol') != expected['protocol']:
        return False
    if expected['protocol'] == 'local':
        return True
    if actual.get('host') == expected['host']:
        return True
    return ssh_identity(actual['host']) == ssh_identity(expected['host'])


def find_session(plan, existing):
    """Any session touching either root must be checked, not just named ones."""
    expected = [endpoint(plan.alpha), endpoint(plan.beta, plan.host)]
    candidates = []
    for session in existing:
        touches = any(transport_matches(actual, target) and overlap(actual['path'], target['path'])
                      for actual in (session['alpha'], session['beta']) for target in expected)
        if session.get('name') == plan.name or touches or session.get('labels', {}).get('mapping-project') == plan.project:
            candidates.append(session)
    if len(candidates) > 1:
        raise SetupError(f'{plan.project}: duplicate/overlapping sessions; preserve and reconcile manually')
    if not candidates:
        return None
    session = candidates[0]
    mismatch = []
    if session.get('name') != plan.name or session.get('labels', {}).get('mapping-project') != plan.project:
        mismatch.append('project identity')
    for side, target in zip(('alpha', 'beta'), expected):
        if not same_endpoint(session[side], target):
            mismatch.append(side + ' effective root/transport')
        # The public API includes endpoint-specific configuration separately.
        if (session[side].get('ignore', {}).get('paths')
                or session[side].get('ignore', {}).get('syntax')
                or session[side].get('mode')):
            mismatch.append(side + ' configuration override')
    if session.get('mode') != plan.mode:
        mismatch.append('mode')
    ignores = session.get('ignore', {})
    # Exact ordered comparison also prevents extra negations undoing required ignores.
    if ignores.get('paths') != plan.ignores or ignores.get('syntax') != 'mutagen' or ignores.get('vcs') is not False:
        mismatch.append(f'required exclusions/syntax (syntax={ignores.get("syntax")}, vcs={ignores.get("vcs")})')
    if mismatch:
        raise SetupError(f'{plan.project}: configuration drift: {", ".join(mismatch)}; session retained')
    return session


def preflight(plan, require_mirror=True):
    root = Path(plan.alpha)
    if not root.is_dir() or root.is_symlink() or str(root.resolve()) != plan.alpha or not (root / 'pubspec.yaml').is_file():
        raise SetupError(f'{plan.project}: invalid MacBook root')
    if plan.host:
        # realpath catches substitute/symlink roots. The mount check refuses an empty
        # /Volumes directory on the startup filesystem, even if it contains folders.
        checks = ["test -d /Volumes/Development",
                  "test \"$(stat -f %d /Volumes/Development)\" != \"$(stat -f %d /)\"",
                  f'test -f {shlex.quote(plan.beta + "/pubspec.yaml")}',
                  f'test "$(cd {shlex.quote(plan.beta)} && pwd -P)" = {shlex.quote(plan.beta)}']
        if require_mirror:
            checks.append(f'test ! -e {shlex.quote(plan.beta + "/.git")} && test ! -L {shlex.quote(plan.beta + "/.git")}')
        try:
            run(['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', plan.host,
                 ' && '.join(checks)], timeout=20)
        except SetupError as error:
            raise SetupError(f'{plan.project}: mini SSH/mounted-volume/root preflight failed for {plan.beta}; '
                             f'confirm attached Development volume, pubspec, physical path and Git-metadata backup: {error}') from error
    else:
        beta = Path(plan.beta)
        if not beta.is_dir() or beta.is_symlink() or not (beta / 'pubspec.yaml').is_file():
            raise SetupError(f'{plan.project}: invalid disposable beta root')
        if require_mirror and os.path.lexists(beta / '.git'):
            raise SetupError(f'{plan.project}: beta Git metadata must be backed up outside roots')


def create(plan, mode=None, name=None):
    args = ['mutagen', 'sync', 'create', plan.alpha, plan.beta_url,
            '--paused', '--name', name or plan.name,
            '--label', 'mapping-project=' + plan.project,
            '--no-global-configuration', '--mode', mode or plan.mode,
            '--ignore-syntax', 'mutagen', '--no-ignore-vcs']
    for pattern in plan.ignores:
        args += ['--ignore', pattern]
    run(args)
    # Creation output is not a stable identifier API; discover by unique name.
    matches = [s for s in sessions() if s.get('name') == (name or plan.name)]
    if len(matches) != 1:
        raise SetupError(f'{plan.project}: creation outcome ambiguous; inspect before retrying')
    return matches[0]['identifier']


def setup(selected):
    existing = sessions()
    # Validate every project before dispatching any creation.
    checked = [(plan, find_session(plan, existing)) for plan in selected]
    for plan, _ in checked:
        preflight(plan)
    for plan, session in checked:
        identifier = session['identifier'] if session else create(plan)
        print(f'{plan.project}: {"reuse" if session else "created paused"} {identifier}')


def manifests(plan):
    alpha = mutagen_scope.manifest(plan.alpha, plan.ignores)
    if plan.host:
        source = Path(mutagen_scope.__file__).read_text()
        beta = json.loads(run(['ssh', '-T', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8',
                               plan.host, 'python3 -c ' + shlex.quote(source)], timeout=300,
                              input=json.dumps({'root': plan.beta, 'ignores': plan.ignores})))
    else:
        beta = mutagen_scope.manifest(plan.beta, plan.ignores)
    return alpha, beta


def baseline(plan):
    alpha, beta = manifests(plan)
    differences = sorted(path for path in alpha.keys() | beta.keys() if alpha.get(path) != beta.get(path))
    if differences:
        raise SetupError(f'{plan.project}: baseline differs at {len(differences)} paths: ' + ', '.join(differences[:12]))
    print(f'{plan.project}: matching baseline ({len(alpha)} entries, SHA-256 contents/types/executable bits)')


def problems(session):
    issues = []
    if session.get('paused'):
        issues.append('paused')
    if session.get('status') != 'watching':
        issues.append('not idle: ' + session.get('status', 'unknown'))
    if not session.get('successfulCycles'):
        issues.append('no successful synchronization cycle')
    for key in ('lastError', 'conflicts', 'excludedConflicts'):
        if session.get(key):
            issues.append(key)
    for side in ('alpha', 'beta'):
        state = session[side]
        if not state.get('connected') or not state.get('scanned'):
            issues.append(side + ' disconnected/unscanned')
        for key in ('scanProblems', 'excludedScanProblems', 'transitionProblems', 'excludedTransitionProblems', 'stagingProgress'):
            if state.get(key):
                issues.append(side + ' ' + key)
    return issues


def flush_ready(selected, timeout=45):
    existing = sessions()
    checked = [(plan, find_session(plan, existing)) for plan in selected]
    failures = []
    for plan, session in checked:
        try:
            if not session or session.get('paused'):
                raise SetupError('missing/paused session')
            run(['mutagen', 'sync', 'flush', session['identifier']], timeout=timeout)
        except SetupError as error:
            failures.append(f'{plan.project}: {error}')
    # Flush may return while the next watch cycle is starting; only a clean idle
    # snapshot is accepted. Timeout is bounded and never implies success.
    deadline = time.monotonic() + timeout
    while True:
        states = sessions()
        pending = []
        for plan, _ in checked:
            state = find_session(plan, states)
            reasons = problems(state) if state else ['missing session']
            if reasons:
                pending.append(f'{plan.project}: {", ".join(reasons)}')
        if not pending or failures or time.monotonic() >= deadline:
            break
        time.sleep(0.2)
    if failures or pending:
        raise SetupError('NOT READY; keep source writers stopped\n' + '\n'.join(failures + pending))
    for plan, _ in checked:
        print(f'{plan.project}: READY (flush completed; connected, idle, no conflicts/problems)')


def activate(selected):
    existing = sessions()
    checked = [(plan, find_session(plan, existing)) for plan in selected]
    for plan, state in checked:
        if not state:
            raise SetupError(f'{plan.project}: run setup-paused first')
        preflight(plan)
        baseline(plan)
    for _, state in checked:
        if state.get('paused'):
            run(['mutagen', 'sync', 'resume', state['identifier']])
    flush_ready(selected)


def seed(plan):
    """Only after human review/backups; intentionally never reused/replayed."""
    existing = sessions()
    if find_session(plan, existing):
        raise SetupError(f'{plan.project}: seed requires deliberate retirement of existing session after preservation')
    name = plan.name + '-bootstrap'
    if any(s.get('name') == name for s in existing):
        raise SetupError(f'{plan.project}: previous bootstrap retained; inspect it before retrying')
    preflight(plan)
    identifier = create(plan, mode='one-way-replica', name=name)
    try:
        run(['mutagen', 'sync', 'resume', identifier])
        run(['mutagen', 'sync', 'flush', identifier], timeout=300)
        deadline = time.monotonic() + 45
        while True:
            state = next(s for s in sessions() if s['identifier'] == identifier)
            issues = problems(state)
            if not issues:
                break
            if time.monotonic() >= deadline:
                raise SetupError(f'{plan.project}: bootstrap problems ({", ".join(issues)}); temporary session retained: {identifier}')
            time.sleep(0.2)
        baseline(plan)
    except (SetupError, OSError, ValueError):
        # A failed replica must not keep replacing beta while it is inspected.
        run(['mutagen', 'sync', 'pause', identifier])
        raise
    run(['mutagen', 'sync', 'terminate', identifier])
    print(f'{plan.project}: seed verified; bootstrap session retired')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('inspect', 'preflight', 'setup-paused', 'baseline', 'seed', 'activate', 'ready'))
    parser.add_argument('--project', choices=PROJECTS, help='only for seed; ordinary readiness always covers all three')
    parser.add_argument('--writers-stopped', action='store_true', help='attest to documented two-Mac, three-project source-write freeze')
    parser.add_argument('--mini-work-preserved', action='store_true', help='attest to reviewed recoverable backups outside every root')
    args = parser.parse_args()
    try:
        config = json.loads(CONFIG.read_text())
        if run(['mutagen', 'version']).strip() != config['mutagen_version']:
            raise SetupError('Mutagen version differs from inspected API; reverify before setup')
        selected = plans()
        if args.project and args.command != 'seed':
            raise SetupError('--project applies only to seed')
        if args.command in ('seed', 'activate', 'ready') and not args.writers_stopped:
            raise SetupError('save edits and stop source writers on both Macs in all three projects first')
        if args.command == 'inspect':
            existing = sessions()
            for plan in selected:
                print(f'{plan.project}: {plan.alpha} <-> {plan.beta_url}; {plan.mode}')
                state = find_session(plan, existing)
                print(json.dumps(state, indent=2) if state else 'no session')
        elif args.command == 'preflight':
            for plan in selected:
                preflight(plan, require_mirror=False)
                print(f'{plan.project}: existing roots/mount/SSH checked')
        elif args.command == 'setup-paused':
            setup(selected)
        elif args.command == 'baseline':
            for plan in selected:
                preflight(plan)
                baseline(plan)
        elif args.command == 'seed':
            if not args.project or not args.mini_work_preserved:
                raise SetupError('seed needs --project and reviewed mini-work preservation')
            seed(next(plan for plan in selected if plan.project == args.project))
        elif args.command == 'activate':
            activate(selected)
        else:
            flush_ready(selected)
    except (SetupError, OSError, ValueError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
