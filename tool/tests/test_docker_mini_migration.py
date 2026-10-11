"""macOS migration checks; no production Docker writes or service shutdowns.

Run: python3 -m unittest discover -s tool/tests -p 'test_docker_mini_migration.py'
"""

import os
import platform
import shlex
import socket
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "migrate_docker_to_mini.sh"


@unittest.skipUnless(
    platform.system() == "Darwin" and platform.machine() == "arm64",
    "The migration is specific to Apple Silicon macOS",
)
class MigrationChecks(unittest.TestCase):
    def run_script(self, *arguments, script=SCRIPT):
        return subprocess.run(
            ["/bin/bash", str(script), *arguments],
            text=True,
            capture_output=True,
            timeout=30,
            check=False,
        )

    def current_hostname(self):
        return subprocess.check_output(
            ["/usr/sbin/scutil", "--get", "LocalHostName"], text=True
        ).strip()

    def require_stopped_docker(self):
        backend = subprocess.run(
            ["/usr/bin/pgrep", "-f", r"(^|/)com\.docker\.backend([[:space:]]|$)"],
            capture_output=True,
            check=False,
        )
        if backend.returncode == 0:
            self.skipTest("Run this copy test on a Mac with Docker Desktop stopped")

    def create_copy_fixture(self, root):
        disk = root / "source.raw"
        disk.write_bytes(b"fixture VM disk")
        topo = root / "source topo"
        topo.mkdir()
        (topo / "docker-compose.yml").write_text("services: {}\n")
        (topo / ".env").write_text("MIGRATION_FIXTURE=yes\n")
        mapping = root / "source mapping"
        mapping.mkdir()
        (mapping / "docker-compose.yml").write_text("services: {}\n")
        data = mapping / "overpass-data" / "tasmania" / "db"
        data.mkdir(parents=True)
        (data / "ways.bin").write_bytes(b"fixture Overpass ways")
        destination = root / "internal bundle"
        arguments = (
            "copy", "--execute", "--destination", str(destination),
            "--source-disk", str(disk), "--source-topo", str(topo),
            "--source-mapping", str(mapping), "--with-overpass",
            "--target-hostname", self.current_hostname(),
        )
        return destination, arguments

    def test_write_commands_default_to_plan_and_create_no_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "uncreated bundle"
            for command in ("stop-source", "copy", "restore", "start"):
                with self.subTest(command=command):
                    result = self.run_script(
                        command, "--destination", str(destination)
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn("PLAN ONLY", result.stdout)
                    self.assertFalse(destination.exists())
                    self.assertFalse(Path(f"{destination}.partial").exists())

    def test_restore_without_a_completed_bundle_fails_before_writing(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "absent"
            result = self.run_script(
                "restore", "--execute", "--destination", str(destination)
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No completed migration bundle", result.stderr)
            self.assertFalse(destination.exists())

    def test_start_without_a_completed_bundle_fails_before_starting_docker(self):
        with tempfile.TemporaryDirectory() as temporary:
            result = self.run_script(
                "start", "--execute", "--destination", f"{temporary}/absent"
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No completed migration bundle", result.stderr)

    def test_invalid_arguments_fail(self):
        for arguments in (
            ("copy", "--destination"),
            ("copy", "--destination", "relative-path"),
            ("copy", "--unknown"),
            ("erase",),
        ):
            with self.subTest(arguments=arguments):
                result = self.run_script(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("ERROR:", result.stderr)

    def test_copy_on_the_wrong_host_fails_before_creating_any_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "uncreated"
            result = self.run_script(
                "copy", "--execute", "--destination", str(destination),
                "--target-hostname", "not-this-mac-migration-fixture",
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Run copy on the Mini", result.stderr)
            self.assertFalse(destination.exists())
            self.assertFalse(Path(f"{destination}.partial").exists())

    def test_space_check_budgets_logical_size_of_a_sparse_disk(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            disk = root / "too-large.raw"
            topo = root / "topo"
            destination = root / "uncreated"
            topo.mkdir()
            (topo / "docker-compose.yml").write_text("services: {}\n")
            with disk.open("wb") as handle:
                handle.write(b"sparse disk fixture")
                handle.truncate(2 * 1024 ** 4)
            result = self.run_script(
                "copy", "--execute", "--destination", str(destination),
                "--source-disk", str(disk), "--source-topo", str(topo),
                "--target-hostname", self.current_hostname(),
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Insufficient free space", result.stderr)
            self.assertFalse(Path(f"{destination}.partial").exists())
            self.assertLess(disk.stat().st_blocks * 512, 1024 * 1024)

    def test_copy_preserves_a_fixture_bundle_and_refuses_to_overwrite_it(self):
        self.require_stopped_docker()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            disk = root / "source.raw"
            topo = root / "source topo"
            destination = root / "internal bundle"
            topo.mkdir()
            (topo / "docker-compose.yml").write_text("services: {}\n")
            (topo / ".env").write_text("MIGRATION_FIXTURE=yes\n")
            (topo / "output").mkdir()
            (topo / "output" / "sample.mbtiles").write_bytes(b"fixture tiles")
            with disk.open("wb") as handle:
                handle.write(b"fixture VM disk")
                handle.truncate(64 * 1024 * 1024)
            arguments = (
                "copy", "--execute", "--destination", str(destination),
                "--source-disk", str(disk), "--source-topo", str(topo),
                "--target-hostname", self.current_hostname(),
            )
            result = self.run_script(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            copied_disk = destination / "docker" / "Docker.raw"
            self.assertEqual(copied_disk.stat().st_size, disk.stat().st_size)
            self.assertLess(copied_disk.stat().st_blocks * 512, 1024 * 1024)
            self.assertEqual(
                (destination / "topo" / "tasmania" / ".env").read_text(),
                "MIGRATION_FIXTURE=yes\n",
            )
            self.assertEqual(
                (destination / "topo" / "tasmania" / "output" / "sample.mbtiles").read_bytes(),
                b"fixture tiles",
            )
            self.assertTrue((destination / "migration-version.txt").exists())
            self.assertFalse(Path(f"{destination}.partial").exists())
            self.assertTrue(disk.exists())
            repeated = self.run_script(*arguments)
            self.assertNotEqual(repeated.returncode, 0)
            self.assertIn("Destination already exists", repeated.stderr)

    def test_copy_retries_empty_and_legacy_partial_bundles_in_place(self):
        self.require_stopped_docker()
        for populated in (False, True):
            with self.subTest(populated=populated), tempfile.TemporaryDirectory() as temporary:
                destination, arguments = self.create_copy_fixture(Path(temporary))
                partial = Path(f"{destination}.partial")
                partial.mkdir()
                if populated:
                    (partial / "docker").mkdir()
                    (partial / "docker" / "Docker.raw").write_bytes(b"unfinished")
                    (partial / "topo" / "tasmania").mkdir(parents=True)
                    (partial / "topo" / "tasmania" / ".env").write_text("old\n")
                result = self.run_script(*arguments)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Retrying existing partial bundle", result.stdout)
                self.assertEqual(
                    (destination / "docker" / "Docker.raw").read_bytes(),
                    b"fixture VM disk",
                )
                self.assertEqual(
                    (destination / "topo" / "tasmania" / ".env").read_text(),
                    "MIGRATION_FIXTURE=yes\n",
                )
                self.assertEqual(
                    (destination / "overpass" / "overpass-data" / "tasmania" / "db" / "ways.bin").read_bytes(),
                    b"fixture Overpass ways",
                )
                self.assertTrue((destination / "migration-version.txt").exists())
                self.assertFalse(partial.exists())

    def test_failed_overpass_copy_keeps_files_and_retries_same_destination(self):
        self.require_stopped_docker()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination, arguments = self.create_copy_fixture(root)
            # Inject an rsync failure only in a fixture copy of the script.
            # Transfer the files first, mirroring a failure after the progress tail.
            wrapper = root / "failing rsync.sh"
            wrapper.write_text(
                '#!/bin/bash\n'
                '/usr/bin/rsync "$@" || exit "$?"\n'
                'for argument in "$@"; do\n'
                '  if [[ "$argument" == */overpass/overpass-data/ ]]; then exit 23; fi\n'
                'done\n'
            )
            wrapper.chmod(0o700)
            failing_script = root / "migration fixture.sh"
            failing_script.write_text(
                SCRIPT.read_text().replace("/usr/bin/rsync", shlex.quote(str(wrapper)))
            )
            failed = self.run_script(*arguments, script=failing_script)
            self.assertEqual(failed.returncode, 23, failed.stderr)
            self.assertIn("Overpass data copy (exit 23)", failed.stderr)
            self.assertIn("no new path is needed", failed.stderr)
            partial = Path(f"{destination}.partial")
            copied_disk = partial / "docker" / "Docker.raw"
            disk_inode = copied_disk.stat().st_ino
            self.assertFalse(destination.exists())
            self.assertFalse((partial / "migration-version.txt").exists())
            self.assertEqual(copied_disk.read_bytes(), b"fixture VM disk")
            ways = partial / "overpass" / "overpass-data" / "tasmania" / "db" / "ways.bin"
            self.assertTrue(ways.exists())
            ways.write_bytes(b"interrupted")
            retried = self.run_script(*arguments)
            self.assertEqual(retried.returncode, 0, retried.stderr)
            self.assertEqual((destination / "docker" / "Docker.raw").stat().st_ino, disk_inode)
            self.assertEqual(
                (destination / "overpass" / "overpass-data" / "tasmania" / "db" / "ways.bin").read_bytes(),
                b"fixture Overpass ways",
            )
            self.assertFalse(partial.exists())

    def test_copy_rejects_invalid_partial_paths_without_changing_them(self):
        for kind in ("file", "symlink", "nested symlink", "marker symlink"):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                destination, arguments = self.create_copy_fixture(root)
                partial = Path(f"{destination}.partial")
                retained = root / "retained"
                retained.mkdir()
                sentinel = retained / "sentinel"
                sentinel.write_text("unchanged\n")
                if kind == "file":
                    partial.write_text("not a bundle\n")
                elif kind == "symlink":
                    partial.symlink_to(retained, target_is_directory=True)
                else:
                    partial.mkdir()
                    if kind == "nested symlink":
                        (partial / "docker").symlink_to(retained, target_is_directory=True)
                    else:
                        (partial / "migration-version.txt").symlink_to(sentinel)
                result = self.run_script(*arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Partial bundle", result.stderr)
                self.assertFalse(destination.exists())
                self.assertEqual(sentinel.read_text(), "unchanged\n")
                if kind == "file":
                    self.assertEqual(partial.read_text(), "not a bundle\n")

    def test_overpass_copy_skips_runtime_sockets_and_preserves_database_files(self):
        self.require_stopped_docker()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            destination, arguments = self.create_copy_fixture(root)
            source_data = root / "source mapping" / "overpass-data"
            for region in ("tasmania", "slovenia"):
                db = source_data / region / "db"
                db.mkdir(parents=True, exist_ok=True)
                (db / "nodes.bin").write_bytes(b"fixture Overpass nodes")
                (db / "nodes.bin").chmod(0o640)
                (db / "nodes.link").symlink_to("nodes.bin")
                os.mkfifo(db / "runtime.fifo")
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as runtime:
                    # Bind relatively to avoid macOS's Unix socket path limit in
                    # long temporary directories; the socket file remains on close.
                    previous_directory = os.getcwd()
                    try:
                        os.chdir(db)
                        runtime.bind("osm3s_osm_base")
                    finally:
                        os.chdir(previous_directory)
            # A regular file with the same name must not be excluded by name.
            regular_db = source_data / "regular fixture" / "db"
            regular_db.mkdir(parents=True)
            (regular_db / "osm3s_osm_base").write_bytes(b"ordinary file")
            Path(f"{destination}.partial").mkdir()
            result = self.run_script(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("mkstempsock", result.stderr)
            self.assertIn("skipping runtime sockets", result.stdout)
            copied_data = destination / "overpass" / "overpass-data"
            for region in ("tasmania", "slovenia"):
                copied_db = copied_data / region / "db"
                self.assertFalse((copied_db / "osm3s_osm_base").exists())
                self.assertFalse((copied_db / "runtime.fifo").exists())
                self.assertEqual((copied_db / "nodes.bin").read_bytes(), b"fixture Overpass nodes")
                self.assertEqual((copied_db / "nodes.bin").stat().st_mode & 0o777, 0o640)
                self.assertEqual(os.readlink(copied_db / "nodes.link"), "nodes.bin")
                self.assertTrue((source_data / region / "db" / "osm3s_osm_base").exists())
            self.assertEqual(
                (copied_data / "regular fixture" / "db" / "osm3s_osm_base").read_bytes(),
                b"ordinary file",
            )
            self.assertTrue((destination / "migration-version.txt").exists())
            self.assertFalse(Path(f"{destination}.partial").exists())

    def test_sparse_rsync_preserves_data_and_does_not_expand_holes(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source.raw"
            target = Path(temporary) / "target.raw"
            size = 64 * 1024 * 1024
            with source.open("wb") as handle:
                handle.write(b"migration-fixture-start")
                handle.seek(size - 32)
                handle.write(b"migration-fixture-end")
                handle.truncate(size)
            subprocess.run(
                ["/usr/bin/rsync", "-aS", str(source), str(target)],
                check=True,
                capture_output=True,
                timeout=30,
            )
            self.assertEqual(target.stat().st_size, size)
            self.assertLess(target.stat().st_blocks * 512, size // 10)
            with target.open("rb") as handle:
                self.assertEqual(handle.read(23), b"migration-fixture-start")
                handle.seek(size // 2)
                self.assertEqual(handle.read(128), bytes(128))
                handle.seek(size - 32)
                self.assertEqual(handle.read(21), b"migration-fixture-end")
            self.assertTrue(source.exists())
            self.assertEqual(os.stat(source).st_size, size)


if __name__ == "__main__":
    unittest.main()
