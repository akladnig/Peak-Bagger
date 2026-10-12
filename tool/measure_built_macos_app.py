#!/usr/bin/env python3
"""Launch an already-built app with a monotonic pre-exec anchor; no build tools.

Only measurement JSON is forwarded. Personal databases/settings/GPX stay local.
Quit the existing app first. A process-cold run does not imply cold OS/SMB caches.
"""

import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import threading
import time
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    parser.add_argument("--condition", choices=["process-cold", "repeated-launch"], required=True)
    parser.add_argument("--repetition", type=int, required=True)
    parser.add_argument("--seconds", type=int, default=90, help="Gracefully quit after this many seconds; 0 means manual Quit")
    parser.add_argument("--output", type=Path, help="New local JSONL log (exclusive creation; no overwrite)")
    parser.add_argument("--detach", action="store_true", help="Leave app running for manual route clicks; requires --output and --seconds 0. Raw app log remains local.")
    args = parser.parse_args()
    if args.repetition < 1 or args.seconds < 0:
        parser.error("repetition must be positive and seconds nonnegative")
    if args.detach and (not args.output or args.seconds != 0):
        parser.error("--detach requires --output and --seconds 0")
    app = args.app.resolve(strict=True)
    with (app / "Contents/Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
    executable = app / "Contents/MacOS" / info["CFBundleExecutable"]
    if subprocess.run(["pgrep", "-x", info["CFBundleExecutable"]], capture_output=True).returncode == 0:
        parser.error("Peak Bagger is already running; quit it normally before a fresh-launch measurement")
    env = dict(os.environ)
    env.update({
        "PEAK_BAGGER_MEASUREMENT_RUN": str(uuid.uuid4()),
        "PEAK_BAGGER_MEASUREMENT_CONDITION": args.condition,
        "PEAK_BAGGER_MEASUREMENT_REPETITION": str(args.repetition),
    })
    output = args.output.open("x") if args.output else None

    def emit(record):
        line = json.dumps(record)
        if output:
            output.write(line + "\n")
            output.flush()
        else:
            print(line, flush=True)

    def quit_app():
        try:
            subprocess.run(["osascript", "-e", f'tell application id "{info["CFBundleIdentifier"]}" to quit'],
                           check=True, timeout=10, capture_output=True)
        except (subprocess.SubprocessError, OSError) as error:
            emit({"event": "launcher.quit-request-error", "error_type": type(error).__name__})

    # Python on macOS uses mach_absolute_time for time.monotonic_ns. This is a
    # conservative pre-process-creation anchor, not a wall-clock approximation.
    before_us = time.monotonic_ns() // 1000
    env["PEAK_BAGGER_LAUNCH_BEFORE_EXEC_US"] = str(before_us)
    if args.detach:
        # LaunchServices performs the ordinary foreground application launch.
        # The pre-dispatch anchor conservatively includes its small overhead.
        output.close()
        stderr_path = args.output.with_name(args.output.name + ".stderr")
        with stderr_path.open("x"):
            pass
        command = ["open", "-n", "-a", str(app), "--stdout", str(args.output.resolve()),
                   "--stderr", str(stderr_path.resolve())]
        env["PEAK_BAGGER_MEASUREMENT_LAUNCH_METHOD"] = "LaunchServices pre-dispatch upper-bound"
        for key, value in env.items():
            if key.startswith("PEAK_BAGGER_"):
                command.extend(["--env", f"{key}={value}"])
        subprocess.run(command, check=True, timeout=15)
        print(json.dumps({"event": "launcher.detached", "launch_before_exec_us": before_us,
                          "method": "LaunchServices pre-dispatch upper-bound"}), flush=True)
        return 0
    process = subprocess.Popen([str(executable)], env=env,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1,
                               start_new_session=False)
    emit({"event": "launcher.spawn", "pid": process.pid,
                      "launch_before_exec_us": before_us,
                      "spawn_return_us": time.monotonic_ns() // 1000,
                      "condition": args.condition, "repetition": args.repetition})
    timer = threading.Timer(args.seconds, quit_app) if args.seconds else None
    if timer:
        timer.start()
    try:
        for line in process.stdout:
            if line.startswith("[measurement] "):
                emit(json.loads(line.removeprefix("[measurement] ")))
        return process.wait()
    except KeyboardInterrupt:
        quit_app()
        return process.wait(timeout=15)
    finally:
        if timer:
            timer.cancel()
            timer.join(timeout=11)
        if output:
            output.close()


if __name__ == "__main__":
    raise SystemExit(main())
