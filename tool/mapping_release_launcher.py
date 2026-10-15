"""Stable, stdlib-only dispatcher; installed once outside all source roots.

Pins the selected manager itself before importing it. Subsequent selection cannot
mix manager/stage versions; unfinished launcher leases are reconciled explicitly.
"""
import fcntl
import hashlib
import json
import os
import runpy
import sys
import time
import uuid
from pathlib import Path


def main():
    base = Path(__file__).resolve().parent
    with (base/'installation.lock').open('a+b') as installation:
        deadline = time.monotonic() + 5
        while True:
            try:
                fcntl.flock(installation, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise RuntimeError('installed dispatcher busy; retry inspection')
                time.sleep(.05)
        # Installer recovery is performed before deploying the launcher or by
        # explicit installed-manager recovery. Never guess around pending intent.
        transaction = base/'selection-transaction.json'
        if transaction.exists():
            journal = json.loads(transaction.read_text())
            if journal.get('state') != 'committed':
                raise RuntimeError('release selection recovery required; run retained manager inspect')
        selected = json.loads((base/'selected.json').read_text())
        identity = selected['releaseId']
        if str(uuid.UUID(identity)) != identity:
            raise RuntimeError('invalid selected installed release identity')
        path = base/'releases'/identity
        if path.is_symlink() or not path.is_dir():
            raise RuntimeError('selected installed release missing/linked')
        raw = (path/'release.json').read_bytes()
        if hashlib.sha256(raw).hexdigest() != selected['manifestSha256']:
            raise RuntimeError('selected release manifest drift')
        manifest = json.loads(raw)
        for item in manifest['artifacts']:
            target = path/item['path']
            if not target.resolve().is_relative_to(path) or target.is_symlink() or hashlib.sha256(target.read_bytes()).hexdigest() != item['sha256']:
                raise RuntimeError(f'installed dispatcher artifact drift: {target}')
        uses = base/'launcher-uses'
        uses.mkdir(exist_ok=True)
        token = str(uuid.uuid4())
        lease = (uses/f'{token}.lock').open('a+b')
        fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with (uses/f'{token}.json').open('x') as stream:
            json.dump(dict(releaseId=identity), stream)
            stream.flush()
            os.fsync(stream.fileno())
    try:
        sys.path[:] = [str(path/'tool'), *[entry for entry in sys.path if entry and entry != str(base)]]
        os.environ.pop('PYTHONPATH', None)
        os.environ['PYTHONDONTWRITEBYTECODE'] = '1'
        sys.argv = [str(path/'tool/mapping_releases.py'), '--base', str(base), *sys.argv[1:]]
        runpy.run_path(sys.argv[0], run_name='__main__')
    finally:
        lease.close()


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'installed release dispatcher failed: {error}', file=sys.stderr)
        sys.exit(1)
