import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/widgets/gpx_import_dialog.dart';

Future<GpxTrackImportResult> fakeImportRunner({
  required bool importAsRoute,
  required Map<String, String> pathToEditedNames,
}) async {
  return const GpxTrackImportResult(
    items: [],
    addedCount: 0,
    unchangedCount: 0,
    unsupportedCount: 0,
    errorCount: 0,
  );
}

Future<String> fastPrefilledNameResolver(String filePath) async {
  return filePath.split(Platform.pathSeparator).last;
}

void main() {
  group('GpxImportDialog', () {
    testWidgets('uses dialog margin spacing and single-line title', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final headerPadding = tester.widget<Padding>(
        find.byKey(const Key('gpx-import-header-padding')),
      );
      expect(
        headerPadding.padding,
        const EdgeInsets.all(PopupUIConstants.surfacePadding),
      );

      final bodyPadding = tester.widget<Padding>(
        find.byKey(const Key('gpx-import-body-padding')),
      );
      expect(
        bodyPadding.padding,
        const EdgeInsets.fromLTRB(
          PopupUIConstants.surfacePadding,
          0,
          PopupUIConstants.surfacePadding,
          PopupUIConstants.surfacePadding,
        ),
      );

      final actionsPadding = tester.widget<Padding>(
        find.byKey(const Key('gpx-import-actions-padding')),
      );
      expect(
        actionsPadding.padding,
        const EdgeInsets.fromLTRB(
          PopupUIConstants.surfacePadding,
          0,
          PopupUIConstants.surfacePadding,
          PopupUIConstants.surfacePadding,
        ),
      );

      final title = tester.widget<Text>(
        find.text('Import GPX File(s)'),
      );
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.byKey(const Key('gpx-import-close')), findsOneWidget);
    });

    testWidgets('dismisses on escape and ctrl+c', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gpx-import-dialog')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gpx-import-dialog')), findsNothing);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('gpx-import-dialog')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gpx-import-dialog')), findsNothing);
    });

    testWidgets('shows "No files selected" when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('No files selected'), findsOneWidget);
    });

    testWidgets('shows loading indicator while selected files are resolving', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync('gpx-import-dialog');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final file = File('${tempDir.path}/track-1.gpx')
        ..writeAsStringSync('<gpx><trk><name>Track 1</name></trk></gpx>');
      final completer = Completer<String>();

      Future<String> slowPrefilledNameResolver(String filePath) {
        return completer.future;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeSelectedGpxFilePicker([file.path]),
                    importAsRoute: false,
                    prefilledNameResolver: slowPrefilledNameResolver,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gpx-import-select-files')));
      await tester.pump();

      expect(
        find.byKey(const Key('gpx-import-file-selection-progress')),
        findsOneWidget,
      );
      expect(find.text('No files selected'), findsNothing);

      completer.complete('Track 1');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('gpx-import-file-selection-progress')),
        findsNothing,
      );
      expect(find.byKey(const Key('gpx-import-row-0')), findsOneWidget);
    });

    testWidgets('shows dialog title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Import GPX File(s)'), findsOneWidget);
    });

    testWidgets('picker failure uses failure modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(
                      pickError: PlatformException(
                        code: 'PICK_FAILED',
                        message: 'Could not open picker.',
                      ),
                    ),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gpx-import-select-files')));
      await tester.pumpAndSettle();

      expect(find.text('Import Failed'), findsOneWidget);
      expect(find.text('Could not open picker.'), findsOneWidget);
      expect(find.byKey(const Key('gpx-import-error-close')), findsOneWidget);
    });

    testWidgets('route mode shows route copy and toggle', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('gpx-import-dialog');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final file = File('${tempDir.path}/route-test.gpx')
        ..writeAsStringSync('<gpx><trk><name>Route Test</name></trk></gpx>');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeSelectedGpxFilePicker([file.path]),
                    importAsRoute: true,
                    prefilledNameResolver: fastPrefilledNameResolver,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gpx-import-select-files')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      final routeSwitch = find.descendant(
        of: find.byKey(const Key('gpx-import-as-route')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(routeSwitch).value, isTrue);

      await tester.tap(routeSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(routeSwitch).value, isFalse);

      await tester.tap(routeSwitch);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(routeSwitch).value, isTrue);

    });

    testWidgets('Import button disabled when no files selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('gpx-import-button')),
      );
      expect(importButton.onPressed, isNull);
    });

    testWidgets('file list uses its own scrollable area', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('gpx-import-dialog');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final filePicker = _FakeSelectedGpxFilePicker(
        List.generate(
          8,
          (index) => File('${tempDir.path}/track-$index.gpx')
            ..writeAsStringSync(
              '<gpx><trk><name>Track $index</name></trk></gpx>',
            ),
        ).map((file) => file.path).toList(growable: false),
      );

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 520));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: filePicker,
                    importAsRoute: false,
                    prefilledNameResolver: fastPrefilledNameResolver,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('gpx-import-select-files')));
      expect(filePicker.pickCallCount, 1);
      final firstRow = find.byKey(
        const Key('gpx-import-row-0'),
        skipOffstage: false,
      );
      for (var attempt = 0; attempt < 50; attempt += 1) {
        if (firstRow.evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gpx-import-select-files')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('gpx-import-dialog')),
          matching: find.byKey(const Key('gpx-import-row-0')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('dialog grows as more files are selected', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('gpx-import-dialog');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      Future<double> openWithPaths(List<String> paths) async {
        var opened = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  if (!opened) {
                    opened = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      showDialog(
                        context: context,
                        builder: (_) => GpxImportDialog(
                          filePicker: _FakeSelectedGpxFilePicker(paths),
                          importAsRoute: false,
                          prefilledNameResolver: fastPrefilledNameResolver,
                          onImport: fakeImportRunner,
                        ),
                      );
                    });
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gpx-import-select-files')));
        final firstRow = find.byKey(
          const Key('gpx-import-row-0'),
          skipOffstage: false,
        );
        for (var attempt = 0; attempt < 50; attempt += 1) {
          if (firstRow.evaluate().isNotEmpty) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
        final height = tester
            .getSize(find.byKey(const Key('gpx-import-dialog')).last)
            .height;
        await tester.tap(find.byKey(const Key('gpx-import-cancel')).last);
        await tester.pumpAndSettle();
        return height;
      }

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 900));

      final oneFilePath = '${tempDir.path}/track-1.gpx';
      File(oneFilePath).writeAsStringSync(
        '<gpx><trk><name>Track 1</name></trk></gpx>',
      );
      for (var i = 0; i < 6; i += 1) {
        File('${tempDir.path}/track-$i.gpx').writeAsStringSync(
          '<gpx><trk><name>Track $i</name></trk></gpx>',
        );
      }

      final oneFileHeight = await openWithPaths([oneFilePath]);
      final manyFileHeight = await openWithPaths([
        for (var i = 0; i < 6; i += 1) '${tempDir.path}/track-$i.gpx',
      ]);

      expect(manyFileHeight, greaterThan(oneFileHeight));
    });

    testWidgets('shows select files button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gpx-import-select-files')), findsOneWidget);
      expect(find.text('Select GPX Files'), findsOneWidget);
    });

    testWidgets('cancel button closes dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('gpx-import-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Import GPX File(s)'), findsNothing);
    });

    testWidgets('shows file picker button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxImportDialog(
                    filePicker: _FakeGpxFilePicker(),
                    importAsRoute: false,
                    onImport: fakeImportRunner,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gpx-import-select-files')), findsOneWidget);
    });
  });
}

class _FakeGpxFilePicker implements GpxFilePicker {
  _FakeGpxFilePicker({this.pickError});

  final Object? pickError;

  @override
  Future<List<String>?> pickGpxFiles() async {
    if (pickError != null) {
      throw pickError!;
    }
    return null;
  }

  @override
  Future<String> resolveImportRoot() async => '/tmp';
}

class _FakeSelectedGpxFilePicker implements GpxFilePicker {
  _FakeSelectedGpxFilePicker(this.paths);

  final List<String> paths;
  int pickCallCount = 0;

  @override
  Future<List<String>?> pickGpxFiles() async {
    pickCallCount += 1;
    return paths;
  }

  @override
  Future<String> resolveImportRoot() async => '/tmp';
}
