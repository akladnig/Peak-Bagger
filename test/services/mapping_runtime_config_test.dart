import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_runtime_config.dart';

void main() {
  test(
    'absent machine configuration selects a local support replica',
    () async {
      final support = await Directory.systemTemp.createTemp('mapping-config-');
      addTearDown(() => support.delete(recursive: true));
      final config = await MappingRuntimeConfiguration.load(support.path);
      expect(config.mode, MappingRuntimeMode.replica);
      expect(config.rootPath, p.join(support.path, 'MappingRuntimeReplica'));
      expect(
        config.configurationPath,
        p.join(support.path, 'mapping-runtime.json'),
      );
    },
  );
  test(
    'invalid configuration reports its path rather than a canonical fallback',
    () async {
      final support = await Directory.systemTemp.createTemp('mapping-config-');
      addTearDown(() => support.delete(recursive: true));
      final path = p.join(support.path, 'mapping-runtime.json');
      await File(path).writeAsString('{"mode":"unknown"}');
      await expectLater(
        MappingRuntimeConfiguration.load(support.path),
        throwsA(
          isA<MappingRuntimeConfigurationFailure>().having(
            (failure) => failure.path,
            'path',
            path,
          ),
        ),
      );
    },
  );
  test(
    'explicit canonical config uses only the attached canonical root',
    () async {
      final support = await Directory.systemTemp.createTemp('mapping-config-');
      addTearDown(() => support.delete(recursive: true));
      await File(p.join(support.path, 'mapping-runtime.json')).writeAsString(
        '{"schemaVersion":1,"mode":"canonical","canonicalRoot":"/Volumes/Services/Mapping"}',
      );
      final config = await MappingRuntimeConfiguration.load(support.path);
      expect(config.mode, MappingRuntimeMode.canonical);
      expect(config.rootPath, '/Volumes/Services/Mapping');
    },
  );
  test(
    'rejects SMB and source-synchronized runtime configuration paths',
    () async {
      final support = await Directory.systemTemp.createTemp('mapping-config-');
      addTearDown(() => support.delete(recursive: true));
      final path = p.join(support.path, 'mapping-runtime.json');
      await File(path).writeAsString(
        '{"schemaVersion":1,"mode":"replica","replicaBase":"/remote/replica"}',
      );
      await expectLater(
        MappingRuntimeConfiguration.load(
          support.path,
          isLocal: (_) async => false,
        ),
        throwsA(isA<MappingRuntimeConfigurationFailure>()),
      );
      await File(path).writeAsString(
        '{"schemaVersion":1,"mode":"replica","replicaBase":"${p.current}/replica"}',
      );
      await expectLater(
        MappingRuntimeConfiguration.load(support.path),
        throwsA(isA<MappingRuntimeConfigurationFailure>()),
      );
    },
  );
  test(
    'configuration rejects duplicate fields, aliases and unknown versions',
    () async {
      final support = await Directory.systemTemp.createTemp('mapping-config-');
      addTearDown(() => support.delete(recursive: true));
      final path = p.join(support.path, 'mapping-runtime.json');
      for (final text in [
        '{"schemaVersion":2,"schemaVersion":1,"mode":"replica","replicaBase":"${support.path}/replica"}',
        '{"schemaVersion":1.0,"mode":"replica","replicaBase":"${support.path}/replica"}',
      ]) {
        await File(path).writeAsString(text);
        await expectLater(
          MappingRuntimeConfiguration.load(support.path),
          throwsA(isA<MappingRuntimeConfigurationFailure>()),
        );
      }
      await Directory(p.join(support.path, 'target')).create();
      await Link(
        p.join(support.path, 'alias'),
      ).create(p.join(support.path, 'target'));
      await File(path).writeAsString(
        '{"schemaVersion":1,"mode":"replica","replicaBase":"${support.path}/alias"}',
      );
      await expectLater(
        MappingRuntimeConfiguration.load(support.path),
        throwsA(isA<MappingRuntimeConfigurationFailure>()),
      );
    },
  );
}
