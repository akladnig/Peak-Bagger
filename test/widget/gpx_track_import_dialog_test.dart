import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/widgets/gpx_track_import_dialog.dart';

Future<GpxTrackImportResult> fakeImportRunner({
  required Map<String, String> pathToEditedNames,
}) async {
  return const GpxTrackImportResult(
    items: [],
    addedCount: 0,
    unchangedCount: 0,
    nonTasmanianCount: 0,
    errorCount: 0,
  );
}

void main() {
  group('GpxTrackImportDialog', () {
    testWidgets('shows "No files selected" when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                child: const Text('Open'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => GpxTrackImportDialog(
                    filePicker: _FakeGpxFilePicker(),
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
                  builder: (_) => GpxTrackImportDialog(
                    filePicker: _FakeGpxFilePicker(),
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

      expect(find.text('Import GPX Track(s)'), findsOneWidget);
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
                  builder: (_) => GpxTrackImportDialog(
                    filePicker: _FakeGpxFilePicker(),
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
        find.byKey(const Key('gpx-track-import-button')),
      );
      expect(importButton.onPressed, isNull);
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
                  builder: (_) => GpxTrackImportDialog(
                    filePicker: _FakeGpxFilePicker(),
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

      expect(find.byKey(const Key('gpx-track-select-files')), findsOneWidget);
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
                  builder: (_) => GpxTrackImportDialog(
                    filePicker: _FakeGpxFilePicker(),
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

      await tester.tap(find.byKey(const Key('gpx-track-import-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Import GPX Track(s)'), findsNothing);
    });
  });
}

class _FakeGpxFilePicker implements GpxFilePicker {
  @override
  Future<List<String>?> pickGpxFiles() async => null;

  @override
  Future<String> resolveImportRoot() async => '/tmp';
}
