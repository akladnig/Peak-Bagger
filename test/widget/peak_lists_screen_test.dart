import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../harness/test_peak_list_file_picker.dart';

void main() {
  testWidgets('empty state renders copy and shell panes', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    expect(find.byKey(const Key('peak-lists-summary-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-details-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-mini-map')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
    expect(
      find.text('No peak lists exist. Import a CSV to get started.'),
      findsNWidgets(2),
    );
    expect(find.text('Peak Name'), findsOneWidget);
    expect(find.text('Elevation'), findsOneWidget);
    expect(find.text('Ascent Date'), findsOneWidget);
  });

  testWidgets('summary metrics use unique peak ids and latest ascent dates', (
    tester,
  ) async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
        _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
        _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
      ]),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100, 100]),
        ]),
      ),
      peakRepository: peakRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 100,
            gpxId: 10,
            date: DateTime.utc(2024, 1, 12),
          ),
          PeaksBagged(
            baggedId: 2,
            peakId: 100,
            gpxId: 11,
            date: DateTime.utc(2024, 3, 2),
          ),
          PeaksBagged(
            baggedId: 3,
            peakId: 200,
            gpxId: 12,
            date: DateTime.utc(2024, 3, 2),
          ),
        ]),
      ),
    );

    expect(find.byKey(const Key('peak-lists-total-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-total-1'))).data,
      '3',
    );
    expect(find.byKey(const Key('peak-lists-climbed-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '2',
    );
    expect(find.byKey(const Key('peak-lists-percentage-1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-percentage-1')))
          .data,
      '67%',
    );
    expect(find.byKey(const Key('peak-lists-unclimbed-1')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-unclimbed-1'))).data,
      '1',
    );
    expect(
      find.text(
        'Alpha Peak and Beta Peak are your most recent, climbed on 2 Mar 2024. Tas Peaks contains 3 peaks. Climbed 2 of 3 (67%).',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-100-ticked')),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-200-ticked')),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('peak-lists-mini-map-marker-300-unticked')),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-300')),
        matching: find.text('2 Mar 2024'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'unsupported legacy rows stay visible with dash metrics and details message',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              name: 'Legacy List',
              peakList: '[{"peakOsmId":100,"points":"3"}]',
            )..peakListId = 1,
          ]),
        ),
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
      );

      expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
      expect(find.text('Legacy List'), findsNWidgets(2));
      expect(find.byKey(const Key('peak-lists-delete-1')), findsOneWidget);
      expect(find.byKey(const Key('peak-lists-total-1')), findsOneWidget);
      expect(find.text('-'), findsNWidgets(4));
      expect(find.textContaining('unsupported legacy format'), findsWidgets);
      expect(
        find.textContaining('Delete it and re-import the CSV'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'derived metric sorts keep unsupported rows after supported rows and indicators stay deterministic',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Bravo', [100]),
            PeakList(
              name: 'Legacy List',
              peakList: '[{"peakOsmId":200,"points":"4"}]',
            )..peakListId = 2,
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([_buildPeak(100, 'Alpha Peak', -42.0, 146.0)]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
          ]),
        ),
      );

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-percentage')),
            )
            .icon,
        Icons.arrow_downward,
      );
      expect(
        tester
            .widget<Icon>(find.byKey(const Key('peak-lists-sort-icon-name')))
            .icon,
        Icons.unfold_more,
      );

      await tester.tap(find.byKey(const Key('peak-lists-sort-totalPeaks')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-totalPeaks')),
            )
            .icon,
        Icons.arrow_upward,
      );
      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-percentage')),
            )
            .icon,
        Icons.unfold_more,
      );

      final bravoTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-row-1')))
          .dy;
      final legacyTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-row-2')))
          .dy;
      expect(bravoTop, lessThan(legacyTop));
    },
  );

  testWidgets('first list auto-selects and row tap updates details title', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(_buildLists(['Abels', 'Connoisseurs'])),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Connoisseurs',
    );
  });

  testWidgets('narrow layout stacks panes vertically', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    final summaryTopLeft = tester.getTopLeft(
      find.byKey(const Key('peak-lists-summary-pane')),
    );
    final detailsTopLeft = tester.getTopLeft(
      find.byKey(const Key('peak-lists-details-pane')),
    );
    expect(detailsTopLeft.dy, greaterThan(summaryTopLeft.dy));
  });

  testWidgets('import completion selects returned list identity', (
    tester,
  ) async {
    final repository = PeakListRepository.test(InMemoryPeakListStorage());

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: repository,
      importRunner:
          ({required String listName, required String csvPath}) async {
            final saved = await repository.save(
              PeakList(name: listName, peakList: '[]'),
            );
            return PeakListImportPresentationResult(
              updated: false,
              importedCount: 1,
              skippedCount: 0,
              peakListId: saved.peakListId,
              listName: saved.name,
            );
          },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-import-result-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-row-1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );
  });

  testWidgets('import fab opens dialog and cancel closes it', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-import-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
  });

  testWidgets('import stays disabled until a file is selected', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    var importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);
  });

  testWidgets(
    'selecting a file enables import and empty name shows validation',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
        repository: PeakListRepository.test(InMemoryPeakListStorage()),
      );

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-list-select-file')));
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('peak-list-import-button')),
      );
      expect(importButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('peak-list-import-button')));
      await tester.pumpAndSettle();

      expect(find.text('A list name is required'), findsOneWidget);
    },
  );

  testWidgets('file picker cancel is a no-op', (tester) async {
    final filePicker = TestPeakListFilePicker(selectedFilePath: null);
    await _pumpPeakListsApp(
      tester,
      filePicker: filePicker,
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    expect(filePicker.pickCallCount, 1);
    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('file picker failure uses modal pattern', (tester) async {
    final filePicker = TestPeakListFilePicker(
      pickError: PlatformException(
        code: 'ENTITLEMENT_NOT_FOUND',
        message: 'Read-Only or Read-Write entitlement is required.',
      ),
    );
    await _pumpPeakListsApp(
      tester,
      filePicker: filePicker,
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    expect(find.text('Peak List Import Failed'), findsOneWidget);
    expect(
      find.text('Read-Only or Read-Write entitlement is required.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('peak-list-import-error-close')),
      findsOneWidget,
    );
  });

  testWidgets('duplicate name confirm path updates and shows result dialog', (
    tester,
  ) async {
    var importCallCount = 0;
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      duplicateNameChecker: (name) async => true,
      importRunner:
          ({required String listName, required String csvPath}) async {
            importCallCount += 1;
            return const PeakListImportPresentationResult(
              updated: true,
              importedCount: 3,
              skippedCount: 1,
            );
          },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This list already exists - do you want to update the existing list?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('peak-list-update-confirm')));
    await tester.pumpAndSettle();

    expect(importCallCount, 1);
    expect(find.text('Peak List Updated'), findsOneWidget);
    expect(find.text('3 Peaks imported'), findsOneWidget);
    expect(find.text('1 peaks skipped'), findsOneWidget);
  });

  testWidgets('loading state disables import and failure uses modal pattern', (
    tester,
  ) async {
    final completer = Completer<PeakListImportPresentationResult>();
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
      importRunner: ({required String listName, required String csvPath}) {
        return completer.future;
      },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pump();

    final importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);
    expect(find.byKey(const Key('peak-list-import-progress')), findsOneWidget);

    completer.completeError(StateError('boom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Peak List Import Failed'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.byKey(const Key('peak-list-import-error-close')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPeakListsApp(
  WidgetTester tester, {
  required PeakListFilePicker filePicker,
  required PeakListRepository repository,
  PeakRepository? peakRepository,
  PeaksBaggedRepository? peaksBaggedRepository,
  PeakListImportRunner? importRunner,
  PeakListDuplicateNameChecker? duplicateNameChecker,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        peakListRepositoryProvider.overrideWithValue(repository),
        peakRepositoryProvider.overrideWithValue(
          peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          peaksBaggedRepository ??
              PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        peakListFilePickerProvider.overrideWithValue(filePicker),
        peakListImportRunnerProvider.overrideWithValue(
          importRunner ??
              ({required String listName, required String csvPath}) async {
                return const PeakListImportPresentationResult(
                  updated: false,
                  importedCount: 1,
                  skippedCount: 0,
                );
              },
        ),
        peakListDuplicateNameCheckerProvider.overrideWithValue(
          duplicateNameChecker ?? ((name) async => false),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();

  router.go('/peaks');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

List<PeakList> _buildLists(List<String> names) {
  return [
    for (var index = 0; index < names.length; index++)
      PeakList(name: names[index], peakList: '[]')..peakListId = index + 1,
  ];
}

PeakList _buildPeakList(int id, String name, List<int> peakIds) {
  return PeakList(
    name: name,
    peakList: encodePeakListItems([
      for (final peakId in peakIds) PeakListItem(peakOsmId: peakId, points: 0),
    ]),
  )..peakListId = id;
}

Peak _buildPeak(
  int osmId,
  String name,
  double latitude,
  double longitude, {
  double? elevation,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: latitude,
    longitude: longitude,
    elevation: elevation,
  );
}
