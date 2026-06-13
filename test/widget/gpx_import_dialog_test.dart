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

      final dialog = tester.widget<AlertDialog>(
        find.byKey(const Key('gpx-import-dialog')),
      );
      expect(
        dialog.insetPadding,
        const EdgeInsets.all(UiConstants.dialogMargin),
      );
      expect(
        dialog.titlePadding,
        const EdgeInsets.fromLTRB(
          UiConstants.dialogMargin,
          UiConstants.dialogMargin,
          UiConstants.dialogMargin,
          0,
        ),
      );
      expect(
        dialog.contentPadding,
        const EdgeInsets.fromLTRB(
          UiConstants.dialogMargin,
          0,
          UiConstants.dialogMargin,
          UiConstants.dialogMargin,
        ),
      );
      expect(
        dialog.actionsPadding,
        const EdgeInsets.fromLTRB(
          UiConstants.dialogMargin,
          0,
          UiConstants.dialogMargin,
          UiConstants.dialogMargin,
        ),
      );

      final title = dialog.title as Text;
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      expect(title.overflow, TextOverflow.ellipsis);
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
      final files = List.generate(
        8,
        (index) => File('${tempDir.path}/track-$index.gpx')
          ..writeAsStringSync(
            '<gpx><trk><name>Track $index</name></trk></gpx>',
          ),
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
                    filePicker: _FakeSelectedGpxFilePicker(
                      files.map((file) => file.path).toList(growable: false),
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

      expect(find.byKey(const Key('gpx-import-select-files')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('gpx-import-dialog')),
          matching: find.byType(SingleChildScrollView, skipOffstage: false),
        ),
        findsNothing,
      );
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

  @override
  Future<List<String>?> pickGpxFiles() async => paths;

  @override
  Future<String> resolveImportRoot() async => '/tmp';
}
