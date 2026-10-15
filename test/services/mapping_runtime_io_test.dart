import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_runtime_io.dart';

void main() {
  test(
    'Dart session locks interoperate with Python and are released by process death',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mapping-process-pin-',
      );
      addTearDown(() => base.delete(recursive: true));
      final path = p.join(base.path, 'session.lock');
      final child = await Process.start('dart', [
        'run',
        'test/fixtures/mapping_runtime_lock_owner.dart',
        path,
      ]);
      addTearDown(() {
        child.kill(ProcessSignal.sigkill);
      });
      final errors = child.stderr.transform(utf8.decoder).join();
      expect(
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 30)),
        'owned',
      );
      final observed = await Process.run('python3', [
        '-c',
        'import fcntl,sys; stream=open(sys.argv[1],"a+b"); '
            'fcntl.flock(stream,fcntl.LOCK_EX|fcntl.LOCK_NB)',
        path,
      ]);
      expect(observed.exitCode, isNot(0));
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
      expect(await errors, isEmpty);
      (await MappingRuntimeIo().lock(path, wait: Duration.zero)).close();
    },
  );
  test(
    'Darwin lifetime locks exclude independent owners and release on close',
    () async {
      final base = await Directory.systemTemp.createTemp('mapping-lock-');
      addTearDown(() => base.delete(recursive: true));
      final io = MappingRuntimeIo();
      final path = p.join(base.path, 'selection.lock');
      final held = await io.lock(path);
      await expectLater(
        io.lock(path, wait: Duration.zero),
        throwsA(isA<FileSystemException>()),
      );
      held.close();
      final next = await io.lock(path, wait: Duration.zero);
      next.close();
      expect(await io.isLocal(base.path), isTrue);
    },
  );
  test(
    'atomic state publication exposes complete JSON and confines metadata writes',
    () async {
      final base = await Directory.systemTemp.createTemp('mapping-atomic-');
      addTearDown(() => base.delete(recursive: true));
      final io = MappingRuntimeIo();
      await io.publishState(base.path, 'selection.json', {'revision': 1});
      await io.publishState(base.path, 'selection.json', {'revision': 2});
      expect(
        (await io.readMetadata(p.join(base.path, 'selection.json'))).value,
        {'revision': 2},
      );
      await expectLater(
        io.publishState(base.path, 'generations/payload/file.json', {}),
        throwsA(isA<ArgumentError>()),
      );
    },
  );
}
