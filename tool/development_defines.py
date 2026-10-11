"""Validate local build defines or receive an absent copy over SSH stdin.

Only status is printed. This checks configuration shape, not provider access.
"""

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse


def validate(payload):
    config = json.loads(payload)
    if not isinstance(config, dict):
        raise TypeError()
    for key in ("TRACESTRACK_API_KEY", "TRACESTRACK_REFERER", "MAPY_CZ_API_KEY"):
        value = config.get(key)
        if not isinstance(value, str) or not value.strip():
            raise ValueError()
        if value.strip().lower().startswith("replace-with-"):
            raise ValueError()
    referer = urlparse(config["TRACESTRACK_REFERER"])
    if referer.scheme not in ("http", "https") or not referer.netloc:
        raise ValueError()


def check_existing(path, receive):
    try:
        if path.is_symlink():
            raise ValueError()
        validate(path.read_bytes())
    except (OSError, TypeError, ValueError):
        print("Existing configuration is invalid or unreadable; deliberate correction required.",
              file=sys.stderr)
        return 1
    print("Existing usable configuration preserved." if receive else "Local configuration is usable.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", type=Path, default=Path("dart_defines.local.json"))
    parser.add_argument("--receive", action="store_true",
                        help="Receive validated JSON from stdin only if the target is absent.")
    args = parser.parse_args()
    path = args.file
    if os.path.lexists(path):
        return check_existing(path, args.receive)
    if not args.receive:
        print("Local configuration is absent; create it from the shared example.", file=sys.stderr)
        return 1
    try:
        payload = sys.stdin.buffer.read()
        validate(payload)
    except (OSError, TypeError, ValueError):
        print("Incoming configuration is invalid; no file created.", file=sys.stderr)
        return 1
    try:
        # Publish a complete mode-0600 file without replacing a concurrent copy.
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".dart_defines.local.json.seed-") as temporary:
            temporary.write(payload)
            temporary.flush()
            os.fsync(temporary.fileno())
            try:
                os.link(temporary.name, path)
            except FileExistsError:
                return check_existing(path, True)
    except OSError:
        print("Could not seed local configuration; check directory and permissions.", file=sys.stderr)
        return 1
    print("Absent local configuration seeded with private permissions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
