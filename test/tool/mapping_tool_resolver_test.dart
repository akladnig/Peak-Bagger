import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_store_contract_verifier.dart';
import 'package:peak_bagger/services/mapping_store_resolver.dart';
import 'package:peak_bagger/services/mapping_tool_manifest.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

void main() {
  late Directory root;
  late Map<String, dynamic> contract;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('mapping-tool-test-');
    root = Directory(await root.resolveSymbolicLinks());
    contract = _contract();
    await _write(root, 'Peaks/input.json', 'source');
  });
  tearDown(() async => root.delete(recursive: true));

  Future<MappingToolResolver> resolver({
    MappingToolProcessRunner? runner,
    MappingToolFileCommit? commit,
  }) async {
    await _write(root, 'tool_manifest.json', jsonEncode({'example': contract}));
    final processRunner =
        runner ??
        (
          String executable,
          List<String> arguments,
          String cwd,
          Map<String, String> environment,
        ) => Process.run(
          executable,
          arguments,
          workingDirectory: cwd,
          environment: environment,
          includeParentEnvironment: false,
          runInShell: false,
        );
    if (commit != null) {
      return MappingToolResolver.namedTool(
        toolId: 'example',
        repositoryRoot: Directory.current.path,
        rootPath: root.path,
        runner: processRunner,
        commitFile: commit,
      );
    }
    return MappingToolResolver.namedTool(
      toolId: 'example',
      repositoryRoot: Directory.current.path,
      rootPath: root.path,
      runner: processRunner,
    );
  }

  test(
    'v1 tool fixture declares inventory tools with parsed policies',
    () async {
      final parsed = MappingToolManifest.parse(
        await _fixture('tool_manifest.json'),
      );
      expect(parsed.tools, hasLength(12));
      expect(
        parsed
            .requireTool('update-region-peak-fingerprints')
            .outputs['updated-manifest']!
            .atomic,
        isTrue,
      );
      expect(
        parsed.requireTool('route-graph-peak-list').permittedWrites,
        isEmpty,
      );
      expect(
        parsed.requireTool('elvis-dem-topo').outputs['topo-dem']!.kind,
        MappingToolPathKind.directory,
      );
    },
  );

  test(
    'maintainer command runs in standalone Dart without opening the mounted store for invalid arguments',
    () async {
      final result = await Process.run(
        'dart',
        ['run', 'tool/mapping_store.dart', 'invalid-command'],
        workingDirectory: Directory.current.path,
        runInShell: false,
      );
      expect(result.exitCode, 1);
      expect(
        result.stderr,
        contains('Usage: dart run tool/mapping_store.dart'),
      );
      expect(result.stderr, isNot(contains('dart:ui')));
    },
  );

  final invalidContracts = <String, void Function(Map<String, dynamic>)>{
    'empty executable': (c) => (c['command'] as Map)['executable'] = '',
    'string arguments': (c) => (c['command'] as Map)['arguments'] = 'hello',
    'non-string argument': (c) => (c['command'] as Map)['arguments'] = [1],
    'unknown working directory': (c) => c['workingDirectory'] = '/',
    'unknown environment': (c) => (c['command'] as Map)['environment'] = {},
    'missing declarations': (c) => c.remove('inputs'),
    'duplicate input': (c) =>
        (c['inputs'] as List).add((c['inputs'] as List).first),
    'duplicate output': (c) =>
        (c['outputs'] as List).add((c['outputs'] as List).first),
    'empty ID': (c) => ((c['inputs'] as List).first as Map)['id'] = '',
    'glob output': (c) =>
        ((c['outputs'] as List).first as Map)['kind'] = 'glob',
    'wrong required type': (c) =>
        ((c['inputs'] as List).first as Map)['required'] = 'true',
    'missing atomic policy': (c) =>
        ((c['outputs'] as List).first as Map).remove('atomic'),
    'undeclared write': (c) => c['permittedWrites'] = ['other'],
    'unauthorized output placeholder': (c) => c['permittedWrites'] = [],
    'undeclared input placeholder': (c) =>
        (c['command'] as Map)['arguments'] = ['{input:other}'],
    'partial placeholder': (c) =>
        (c['command'] as Map)['arguments'] = ['--file={input:source}'],
    'malformed placeholder': (c) =>
        (c['command'] as Map)['arguments'] = ['{source}'],
    'literal Mapping path': (c) =>
        (c['command'] as Map)['arguments'] = ['Peaks/input.json'],
    'literal mounted path': (c) => (c['command'] as Map)['arguments'] = [
      '$mappingStoreRootPath/Peaks/input.json',
    ],
    'literal absolute input': (c) =>
        (c['command'] as Map)['arguments'] = ['/some/input.json'],
    'undeclared relative dataset literal': (c) =>
        (c['command'] as Map)['arguments'] = ['Unlisted/data.json'],
    'literal dataset basename': (c) =>
        (c['command'] as Map)['arguments'] = ['data.csv'],
    'override wrong target': (c) => c['overrides'] = [
      {'flag': '--source', 'inputId': 'other'},
    ],
    'override both targets': (c) => c['overrides'] = [
      {'flag': '--source', 'inputId': 'source', 'outputId': 'result'},
    ],
    'overlapping outputs': (c) => (c['outputs'] as List).add({
      'id': 'nested',
      'path': 'Reports/result.json/child',
      'kind': 'file',
      'required': false,
      'replace': true,
      'atomic': true,
    }),
  };
  for (final entry in invalidContracts.entries) {
    test('parser rejects ${entry.key}', () {
      entry.value(contract);
      expect(
        () => MappingToolManifest.parse(jsonEncode({'example': contract})),
        throwsFormatException,
      );
    });
  }
  for (final unsafe in [
    '',
    '/outside',
    '../file',
    'Peaks/../file',
    'Peaks/./file',
    r'Peaks\file',
    'Peaks//file',
    'C:/file',
    'file\u0000',
  ]) {
    test('rejects unsafe declaration $unsafe', () {
      ((contract['inputs'] as List).first as Map)['path'] = unsafe;
      expect(
        () => MappingToolManifest.parse(jsonEncode({'example': contract})),
        throwsFormatException,
      );
    });
  }

  test(
    'named mode cannot load another tool or undeclared reads/writes',
    () async {
      final tool = await resolver();
      expect(await tool.readInputText('source'), 'source');
      await expectLater(tool.readInputText('other'), throwsStateError);
      await expectLater(
        tool.openInput('result', opener: (_) async => Object()),
        throwsStateError,
      );
      await expectLater(
        tool.writeOutputs((outputs) => outputs.writeText('other', 'invalid')),
        throwsStateError,
      );
      await expectLater(
        MappingToolResolver.namedTool(
          toolId: 'another',
          repositoryRoot: Directory.current.path,
          rootPath: root.path,
        ),
        throwsStateError,
      );
      expect(await File('${root.path}/Reports/result.json').exists(), isFalse);
    },
  );

  test(
    'direct argv preserves metacharacters, fixed cwd/env and staged output',
    () async {
      final literal = 'name with spaces; \$(touch impossible)';
      (contract['command'] as Map)['arguments'] = [
        '{input:source}',
        literal,
        '{output:result}',
      ];
      final tool = await resolver(
        runner: (executable, arguments, cwd, environment) async {
          expect(executable, 'example');
          expect(cwd, Directory.current.path);
          expect(environment, Platform.environment);
          expect(() => environment['INJECTED'] = 'x', throwsUnsupportedError);
          expect(arguments[0], '${root.path}/Peaks/input.json');
          expect(arguments[1], literal);
          expect(p.dirname(arguments[2]), '${root.path}/Reports');
          expect(arguments[2], isNot('${root.path}/Reports/result.json'));
          expect(
            await File('${root.path}/Reports/result.json').exists(),
            isFalse,
          );
          await File(arguments[2]).writeAsString('new');
          return ProcessResult(1, 0, '', '');
        },
      );
      await tool.execute();
      expect(
        await File('${root.path}/Reports/result.json').readAsString(),
        'new',
      );
      expect(Directory('${root.path}/Reports').listSync(), hasLength(1));
    },
  );

  test('actual process receives literal argv without a shell', () async {
    (contract['command'] as Map)['executable'] = '/bin/echo';
    (contract['command'] as Map)['arguments'] = [r'hello; $HOME $(false)'];
    contract['inputs'] = [];
    contract['outputs'] = [];
    contract['permittedWrites'] = [];
    contract['overrides'] = [];
    await _write(root, 'tool_manifest.json', jsonEncode({'example': contract}));
    final actual = await MappingToolResolver.namedTool(
      toolId: 'example',
      repositoryRoot: Directory.current.path,
      rootPath: root.path,
    );
    final result = await actual.execute();
    expect(result.stdout, '${r'hello; $HOME $(false)'}\n');
  });

  test(
    'overrides replace only declared placeholders and keep output policy',
    () async {
      await _write(root, 'Peaks/alternative.json', 'alternative');
      final tool = await resolver(
        runner: (_, args, _, _) async {
          expect(args.first, '${root.path}/Peaks/alternative.json');
          expect(p.dirname(args.last), '${root.path}/Other');
          await File(args.last).writeAsString('overridden');
          return ProcessResult(1, 0, '', '');
        },
      );
      await expectLater(
        tool.execute(overrides: {'--undeclared': 'Peaks/alternative.json'}),
        throwsArgumentError,
      );
      await expectLater(
        tool.execute(overrides: {'--source': '../escape'}),
        throwsFormatException,
      );
      await tool.execute(
        overrides: {
          '--source': 'Peaks/alternative.json',
          '--result': 'Other/result.json',
        },
      );
      expect(
        await File('${root.path}/Other/result.json').readAsString(),
        'overridden',
      );
      expect(await File('${root.path}/Reports/result.json').exists(), isFalse);
    },
  );

  test(
    'glob **, * and ? expand in lexical order with zero optional argv',
    () async {
      contract['inputs'] = [
        {
          'id': 'source',
          'path': 'Peaks/**/*.jso?',
          'kind': 'glob',
          'required': true,
        },
        {
          'id': 'optional',
          'path': 'Missing/*.json',
          'kind': 'glob',
          'required': false,
        },
      ];
      contract['overrides'] = [];
      (contract['command'] as Map)['arguments'] = [
        '{input:source}',
        '{input:optional}',
        '{output:result}',
      ];
      await _write(root, 'Peaks/z.json', 'z');
      await _write(root, 'Peaks/a/nested.json', 'nested');
      await _write(root, 'Peaks/skip.txt', 'skip');
      final tool = await resolver(
        runner: (_, args, _, _) async {
          expect(args.take(3).toList(), [
            '${root.path}/Peaks/a/nested.json',
            '${root.path}/Peaks/input.json',
            '${root.path}/Peaks/z.json',
          ]);
          expect(args, hasLength(4));
          await File(args.last).writeAsString('glob');
          return ProcessResult(1, 0, '', '');
        },
      );
      expect(await tool.readGlobTexts('source'), ['nested', 'source', 'z']);
      await tool.execute();
      ((contract['inputs'] as List).last as Map)['required'] = true;
      final missing = await resolver(
        runner: (_, _, _, _) async => throw StateError('must not execute'),
      );
      await expectLater(missing.execute(), throwsA(isA<FileSystemException>()));
    },
  );

  test(
    'wrong input kind and missing required input fail before execution',
    () async {
      await File('${root.path}/Peaks/input.json').delete();
      var calls = 0;
      final tool = await resolver(
        runner: (_, _, _, _) async {
          calls++;
          return ProcessResult(1, 0, '', '');
        },
      );
      await expectLater(tool.execute(), throwsA(isA<FileSystemException>()));
      await Directory('${root.path}/Peaks/input.json').create();
      await expectLater(tool.execute(), throwsA(isA<FileSystemException>()));
      expect(calls, 0);
    },
  );

  test(
    'inside-root input symlinks work; retargeted escaping input fails',
    () async {
      final outside = await Directory.systemTemp.createTemp('mapping-outside-');
      addTearDown(() => outside.delete(recursive: true));
      await _write(root, 'Peaks/real.json', 'safe');
      await File('${root.path}/Peaks/input.json').delete();
      final link = Link('${root.path}/Peaks/input.json');
      await link.create('${root.path}/Peaks/real.json');
      final tool = await resolver();
      expect(await tool.readInputText('source'), 'safe');
      await File('${outside.path}/source.json').writeAsString('outside');
      await link.update('${outside.path}/source.json');
      var opened = false;
      await expectLater(
        tool.openInput(
          'source',
          opener: (_) async {
            opened = true;
            return Object();
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(opened, isFalse);
    },
  );

  test('opaque binary opener returns only the resource', () async {
    final resource = Object();
    final tool = await resolver();
    final result = await tool.openInput(
      'source',
      opener: (path) async {
        expect(path, '${root.path}/Peaks/input.json');
        return resource;
      },
    );
    expect(result, same(resource));
  });

  test(
    'file no-replacement fails before staging or process; replacement is atomic',
    () async {
      await _write(root, 'Reports/result.json', 'old');
      ((contract['outputs'] as List).first as Map)['replace'] = false;
      var calls = 0;
      final tool = await resolver(
        runner: (_, _, _, _) async {
          calls++;
          return ProcessResult(1, 0, '', '');
        },
      );
      await expectLater(tool.execute(), throwsA(isA<FileSystemException>()));
      expect(calls, 0);
      expect(Directory('${root.path}/Reports').listSync(), hasLength(1));
      ((contract['outputs'] as List).first as Map)['replace'] = true;
      final replacing = await resolver();
      await replacing.writeOutputs((outputs) async {
        await outputs.writeText('result', 'new');
        expect(
          await File('${root.path}/Reports/result.json').readAsString(),
          'old',
        );
      });
      expect(
        await File('${root.path}/Reports/result.json').readAsString(),
        'new',
      );
    },
  );

  test(
    'exclusive publication prevents a target created during execution from being overwritten',
    () async {
      ((contract['outputs'] as List).first as Map)['replace'] = false;
      final tool = await resolver();
      await expectLater(
        tool.writeOutputs((outputs) async {
          await outputs.writeText('result', 'staged');
          await _write(root, 'Reports/result.json', 'racer');
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File('${root.path}/Reports/result.json').readAsString(),
        'racer',
      );
    },
  );

  test(
    'overridden outputs retain no-replacement rules and writers expire after commit',
    () async {
      ((contract['outputs'] as List).first as Map)['replace'] = false;
      await _write(root, 'Alternative/existing.json', 'existing');
      final tool = await resolver();
      await expectLater(
        tool.writeOutputs(
          (_) async => fail('must not run'),
          overrides: {'--result': 'Alternative/existing.json'},
        ),
        throwsA(isA<FileSystemException>()),
      );
      late MappingToolOutputs retained;
      await tool.writeOutputs((outputs) async {
        retained = outputs;
        await outputs.writeText('result', 'complete');
      });
      await expectLater(retained.writeText('result', 'late'), throwsStateError);
      expect(
        await File('${root.path}/Alternative/existing.json').readAsString(),
        'existing',
      );
    },
  );

  test(
    'failed command or missing required output preserves final and cleans staging',
    () async {
      await _write(root, 'Reports/result.json', 'old');
      final failed = await resolver(
        runner: (_, args, _, _) async {
          await File(args.last).writeAsString('partial');
          return ProcessResult(1, 2, '', 'failed');
        },
      );
      await expectLater(failed.execute(), throwsA(isA<ProcessException>()));
      final missing = await resolver(
        runner: (_, _, _, _) async => ProcessResult(1, 0, '', ''),
      );
      await expectLater(missing.execute(), throwsA(isA<FileSystemException>()));
      expect(
        await File('${root.path}/Reports/result.json').readAsString(),
        'old',
      );
      expect(Directory('${root.path}/Reports').listSync(), hasLength(1));
    },
  );

  test(
    'directory snapshots stage siblings, replace files and remove stale entries last',
    () async {
      _directoryOutput(contract);
      await _write(root, 'Reports/snapshot/stale/sub.txt', 'stale');
      await _write(root, 'Reports/snapshot/a.txt', 'old');
      final tool = await resolver(
        runner: (_, args, _, _) async {
          expect(p.dirname(args.last), '${root.path}/Reports');
          expect(args.last, isNot('${root.path}/Reports/snapshot'));
          await File('${args.last}/a.txt').writeAsString('new');
          await Directory('${args.last}/nested').create();
          await File('${args.last}/nested/b.txt').writeAsString('b');
          expect(
            await File('${root.path}/Reports/snapshot/stale/sub.txt').exists(),
            isTrue,
          );
          return ProcessResult(1, 0, '', '');
        },
      );
      await tool.execute();
      expect(
        await File('${root.path}/Reports/snapshot/a.txt').readAsString(),
        'new',
      );
      expect(
        await File('${root.path}/Reports/snapshot/nested/b.txt').readAsString(),
        'b',
      );
      expect(
        await Directory('${root.path}/Reports/snapshot/stale').exists(),
        isFalse,
      );
    },
  );

  test(
    'directory failure preserves stale files without claiming directory atomicity',
    () async {
      _directoryOutput(contract);
      await _write(root, 'Reports/snapshot/stale.txt', 'stale');
      await _write(root, 'Reports/snapshot/a.txt', 'old-a');
      await _write(root, 'Reports/snapshot/b.txt', 'old-b');
      final tool = await resolver(
        commit: (staged, target, _) async {
          if (p.basename(target) == 'b.txt') {
            throw const FileSystemException('commit failed');
          }
          await File(staged).rename(target);
        },
      );
      await expectLater(
        tool.writeOutputs((outputs) async {
          await outputs.writeText('result', 'new-a', child: 'a.txt');
          await outputs.writeText('result', 'new-b', child: 'b.txt');
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        await File('${root.path}/Reports/snapshot/a.txt').readAsString(),
        'new-a',
      );
      expect(
        await File('${root.path}/Reports/snapshot/b.txt').readAsString(),
        'old-b',
      );
      expect(
        await File('${root.path}/Reports/snapshot/stale.txt').readAsString(),
        'stale',
      );
    },
  );

  test(
    'directory no-replacement and symlink policies fail before a final write',
    () async {
      _directoryOutput(contract);
      await _write(root, 'Reports/snapshot/old.txt', 'old');
      ((contract['outputs'] as List).first as Map)['replace'] = false;
      await expectLater(
        (await resolver()).writeOutputs((_) async => fail('must not execute')),
        throwsA(isA<FileSystemException>()),
      );
      ((contract['outputs'] as List).first as Map)['replace'] = true;
      final symlink = await resolver(
        runner: (_, args, _, _) async {
          await Link(
            '${args.last}/unsafe',
          ).create('${root.path}/Peaks/input.json');
          return ProcessResult(1, 0, '', '');
        },
      );
      await expectLater(symlink.execute(), throwsA(isA<FileSystemException>()));
      expect(
        await File('${root.path}/Reports/snapshot/old.txt').readAsString(),
        'old',
      );
      await expectLater(
        (await resolver()).writeOutputs(
          (outputs) =>
              outputs.writeText('result', 'escaped', child: '../escape'),
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects output parent symlinks, including inside-root links', () async {
    await Directory('${root.path}/Actual').create();
    await Link('${root.path}/Reports').create('${root.path}/Actual');
    await expectLater(
      (await resolver()).writeOutputs((_) async => fail('must not execute')),
      throwsA(isA<FileSystemException>()),
    );
    expect(Directory('${root.path}/Actual').listSync(), isEmpty);
  });

  test(
    'directory inputs constrain child reads and glob escape links are rejected',
    () async {
      contract['inputs'] = [
        {
          'id': 'source',
          'path': 'Peaks',
          'kind': 'directory',
          'required': true,
        },
      ];
      final tool = await resolver();
      expect(await tool.readInputText('source', child: 'input.json'), 'source');
      await expectLater(
        tool.readInputText('source', child: '../tool_manifest.json'),
        throwsFormatException,
      );
      await expectLater(tool.readInputText('source'), throwsArgumentError);
      ((contract['inputs'] as List).first as Map)['kind'] = 'glob';
      ((contract['inputs'] as List).first as Map)['path'] = 'Peaks/**';
      final outside = await Directory.systemTemp.createTemp(
        'mapping-glob-outside-',
      );
      addTearDown(() => outside.delete(recursive: true));
      await Link('${root.path}/Peaks/escape').create(outside.path);
      await expectLater(
        (await resolver()).readGlobTexts('source'),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'runtime reads only validated pair/references and never tool manifest',
    () async {
      await _runtimeStore(root);
      await _write(root, 'tool_manifest.json', '{invalid tool manifest');
      final preflight = await MappingDataStoreCore(
        rootPath: root.path,
      ).preflight();
      final runtime = MappingStoreReadResolver.runtime(preflight: preflight);
      expect(await runtime.readText('Peaks/tasmania-peaks.json'), 'fixture');
      await expectLater(
        runtime.readText('tool_manifest.json'),
        throwsA(isA<MappingStoreFailure>()),
      );
      await _write(root, 'Peaks/undeclared.json', 'hidden');
      await expectLater(
        runtime.readText('Peaks/undeclared.json'),
        throwsA(isA<MappingStoreFailure>()),
      );
      final opaque = Object();
      expect(
        await runtime.open(
          relativePath: 'DEM/Elvis/elvis_runtime_10m.tif',
          opener: (_) async => opaque,
        ),
        same(opaque),
      );
      await File('${root.path}/DEM/Elvis/elvis_runtime_10m.tif').delete();
      final demLink = Link('${root.path}/DEM/Elvis/elvis_runtime_10m.tif');
      await demLink.create('${root.path}/tool_manifest.json');
      await expectLater(
        runtime.open(
          relativePath: 'DEM/Elvis/elvis_runtime_10m.tif',
          opener: (_) async =>
              fail('must not open the tool manifest via an alias'),
        ),
        throwsA(isA<MappingStoreFailure>()),
      );
      await expectLater(
        MappingDataStoreCore(rootPath: root.path).preflight(),
        throwsA(isA<MappingStoreFailure>()),
      );
      await demLink.delete();
      final outside = await Directory.systemTemp.createTemp(
        'mapping-runtime-outside-',
      );
      addTearDown(() => outside.delete(recursive: true));
      await File('${outside.path}/dem.tif').writeAsString('outside');
      await Link(
        '${root.path}/DEM/Elvis/elvis_runtime_10m.tif',
      ).create('${outside.path}/dem.tif');
      await expectLater(
        runtime.open(
          relativePath: 'DEM/Elvis/elvis_runtime_10m.tif',
          opener: (_) async => fail('must not open'),
        ),
        throwsA(isA<MappingStoreFailure>()),
      );
    },
  );

  test(
    'bootstrap installs only the fixture, verifies equal JSON, never overwrites conflicts',
    () async {
      final fixture = await _fixture('tool_manifest.json');
      final bootstrap = const MappingToolManifestBootstrap();
      expect(
        await bootstrap.install(fixtureText: fixture, rootPath: root.path),
        isTrue,
      );
      final mounted = File('${root.path}/tool_manifest.json');
      expect(await mounted.readAsString(), fixture);
      final stat = await mounted.stat();
      expect(
        await bootstrap.install(fixtureText: fixture, rootPath: root.path),
        isFalse,
      );
      expect((await mounted.stat()).modified, stat.modified);
      await mounted.writeAsString('{}');
      await expectLater(
        bootstrap.install(fixtureText: fixture, rootPath: root.path),
        throwsStateError,
      );
      expect(await mounted.readAsString(), '{}');
    },
  );

  test(
    'bootstrap rejects symlink and concurrent no-overwrite publication',
    () async {
      final fixture = await _fixture('tool_manifest.json');
      final outcomes = await Future.wait(
        List.generate(2, (_) async {
          try {
            return await const MappingToolManifestBootstrap().install(
              fixtureText: fixture,
              rootPath: root.path,
            );
          } on FileSystemException {
            return false;
          }
        }),
      );
      expect(outcomes.where((installed) => installed), hasLength(1));
      expect(
        await File('${root.path}/tool_manifest.json').readAsString(),
        fixture,
      );
      await File('${root.path}/tool_manifest.json').delete();
      await _write(root, 'elsewhere.json', fixture);
      await Link(
        '${root.path}/tool_manifest.json',
      ).create('${root.path}/elsewhere.json');
      await expectLater(
        const MappingToolManifestBootstrap().install(
          fixtureText: fixture,
          rootPath: root.path,
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'runtime manifest cannot authorize the tool-only manifest as a source',
    () async {
      final region =
          jsonDecode(await _fixture('region_manifest.json'))
              as Map<String, dynamic>;
      (region['tasmania'] as Map)['peaks'] = ['tool_manifest.json'];
      expect(
        () => validateMappingManifestPair(
          region,
          jsonDecode(
            File(
              'test/fixtures/mapping_store/v1/Polygons/manifest.json',
            ).readAsStringSync(),
          ),
        ),
        throwsA(isA<MappingStoreFailure>()),
      );
    },
  );

  test(
    'provision verification uses shared schema and reports only named fingerprints',
    () async {
      final region = await _fixture('region_manifest.json');
      final polygons = await _fixture('Polygons/manifest.json');
      final tools = await _fixture('tool_manifest.json');
      final actual = jsonDecode(region) as Map<String, dynamic>;
      (actual['tasmania'] as Map)['fingerprint'] = 'new-fingerprint';
      (actual['slovenia'] as Map)['fingerprint'] = 'another-fingerprint';
      List<MappingStoreAllowedDifference> verify() =>
          verifyMappingStoreContract(
            fixtureRegion: region,
            fixturePolygons: polygons,
            fixtureTools: tools,
            mountedRegion: jsonEncode(actual),
            mountedPolygons: polygons,
            mountedTools: tools,
          );
      expect(verify().map((difference) => difference.path), [
        'region_manifest.json#/slovenia/fingerprint',
        'region_manifest.json#/tasmania/fingerprint',
      ]);
      (actual['tasmania'] as Map)['mapSet'] = [];
      expect(verify, throwsA(isA<MappingStoreFailure>()));
      actual['tasmap'] = {'catalog': '../outside'};
      expect(verify, throwsA(isA<MappingStoreFailure>()));
      expect(
        () => verifyMappingStoreContract(
          fixtureRegion: region,
          fixturePolygons: polygons,
          fixtureTools: tools,
          mountedRegion: region,
          mountedPolygons: polygons,
          mountedTools: '{}',
        ),
        throwsA(isA<MappingStoreFailure>()),
      );
    },
  );
}

Map<String, dynamic> _contract() => {
  'command': {
    'executable': 'example',
    'arguments': ['{input:source}', '{output:result}'],
  },
  'inputs': [
    {
      'id': 'source',
      'path': 'Peaks/input.json',
      'kind': 'file',
      'required': true,
    },
  ],
  'outputs': [
    {
      'id': 'result',
      'path': 'Reports/result.json',
      'kind': 'file',
      'required': true,
      'replace': true,
      'atomic': true,
    },
  ],
  'permittedWrites': ['result'],
  'overrides': [
    {'flag': '--source', 'inputId': 'source'},
    {'flag': '--result', 'outputId': 'result'},
  ],
};

void _directoryOutput(Map<String, dynamic> contract) {
  ((contract['outputs'] as List).first as Map)['kind'] = 'directory';
  ((contract['outputs'] as List).first as Map)['path'] = 'Reports/snapshot';
}

Future<void> _write(Directory root, String relative, String contents) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
}

Future<String> _fixture(String relative) =>
    File('test/fixtures/mapping_store/v1/$relative').readAsString();

Future<void> _runtimeStore(Directory root) async {
  final region = await _fixture('region_manifest.json');
  final polygons = await _fixture('Polygons/manifest.json');
  final paths = <String>{};
  void collect(Object? value) {
    if (value is Map) {
      for (final child in value.values) {
        collect(child);
      }
    } else if (value is List) {
      for (final child in value) {
        collect(child);
      }
    } else if (value is String &&
        RegExp(
          r'^(Peaks|Highways|Polygons|Maps|Features|DEM)/',
        ).hasMatch(value)) {
      paths.add(value);
    }
  }

  collect(jsonDecode(region));
  collect(jsonDecode(polygons));
  for (final path in paths) {
    await _write(root, path, 'fixture');
  }
  await _write(root, 'region_manifest.json', region);
  await _write(root, 'Polygons/manifest.json', polygons);
}
