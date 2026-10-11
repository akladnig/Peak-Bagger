"""Read-only source manifests using the workspace's Mutagen ignore subset.

Patterns support *, ?, ** path components, root anchors and ordered negation.
Like Mutagen syntax, ignored directories are not traversed. No Git ignore input.
Run this reviewed module on each endpoint; never follow symlink directories.
"""

import fnmatch
import hashlib
import json
import os
import sys
from pathlib import Path


def path_match(pattern, path):
    """Segment matching keeps '*' from crossing '/', unlike fnmatch(path)."""
    patterns, parts = pattern.split('/'), path.split('/')

    def match(i, j):
        if i == len(patterns):
            return j == len(parts)
        if patterns[i] == '**':
            return match(i + 1, j) or (j < len(parts) and match(i, j + 1))
        return (j < len(parts) and fnmatch.fnmatchcase(parts[j], patterns[i])
                and match(i + 1, j + 1))

    return match(0, 0)


def ignored(path, directory, patterns):
    result = False
    for raw in patterns:
        negate = raw.startswith('!')
        pattern = raw[1:] if negate else raw
        anchored = pattern.startswith('/')
        dir_only = pattern.endswith('/')
        pattern = pattern.strip('/')
        if dir_only and not directory:
            continue
        if path_match(pattern, path) or (
                not anchored and '/' not in pattern
                and fnmatch.fnmatchcase(path.rsplit('/', 1)[-1], pattern)):
            result = not negate
    return result


def manifest(root, patterns):
    root = Path(root)
    if not root.is_dir() or root.is_symlink():
        raise ValueError('missing or symlink endpoint root')
    result = {}
    device = root.stat().st_dev

    def visit(directory):
        for entry in sorted(os.scandir(directory), key=lambda item: item.name):
            path = Path(entry.path)
            relative = path.relative_to(root).as_posix()
            is_dir = entry.is_dir(follow_symlinks=False)
            if ignored(relative, is_dir, patterns):
                continue
            if entry.is_symlink():
                result[relative] = ['symlink', os.readlink(path)]
            elif is_dir:
                if path.stat().st_dev != device:
                    raise ValueError('in-scope filesystem boundary: ' + relative)
                result[relative] = ['directory']
                visit(path)
            elif entry.is_file(follow_symlinks=False):
                digest = hashlib.sha256()
                with path.open('rb') as stream:
                    for block in iter(lambda: stream.read(1024 * 1024), b''):
                        digest.update(block)
                result[relative] = ['file', digest.hexdigest(), bool(path.stat().st_mode & 0o111)]
            else:
                raise ValueError('unsupported in-scope file: ' + relative)

    visit(root)
    return result


if __name__ == '__main__':
    request = json.load(sys.stdin)
    print(json.dumps(manifest(request['root'], request['ignores']), sort_keys=True))
