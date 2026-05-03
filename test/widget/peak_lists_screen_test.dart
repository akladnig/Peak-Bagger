import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../harness/test_peak_list_file_picker.dart';
import '../harness/test_map_notifier.dart';

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
    expect(find.byKey(const Key('peak-lists-add-list-fab')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-import-fab')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
    expect(
      find.text('No peak lists exist. Import a CSV to get started.'),
      findsNWidgets(2),
    );
    expect(find.text('Peak Name'), findsOneWidget);
    expect(find.text('Height'), findsOneWidget);
    expect(find.text('Ascent\nDate'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
  });

  testWidgets('tapping a peak row opens and closes the detail dialog', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [200, 300, 100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
          _buildPeak(200, 'Beta Peak', -42.1, 146.1, elevation: 1100),
          _buildPeak(300, 'Gamma Peak', -42.2, 146.2, elevation: 1000),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    tester
        .widget<InkWell>(find.byKey(const Key('peak-lists-details-row-200')))
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsOneWidget);
    expect(find.text('Beta Peak'), findsWidgets);

    await tester.tap(find.byKey(const Key('peak-list-peak-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
  });

  testWidgets('add dialog selects the first saved alphabetical peak', (
    tester,
  ) async {
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(300, 'Zulu Peak', -41.0, 146.0),
        _buildPeak(100, 'Alpha Peak', -41.1, 146.1),
        _buildPeak(200, 'Mike Peak', -41.2, 146.2),
      ]),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-lists-add-peak')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-300')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-100')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-200')));
    await tester.pump();

    expect(find.byKey(const Key('peak-selected-row-100')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('peak-selected-points-300')),
      '7',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-100')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-200')),
      '5',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    final selectedRowFinder = find.byKey(
      const Key('peak-lists-details-row-100'),
    );
    expect(selectedRowFinder, findsOneWidget);
    final selectedRowContainer = tester.widget<Container>(
      find
          .descendant(of: selectedRowFinder, matching: find.byType(Container))
          .first,
    );
    expect(selectedRowContainer.color, isNotNull);
    expect(
      decodePeakListItems(
        peakListRepository.getAllPeakLists().single.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(100, 3), (200, 5), (300, 7)],
    );
  });

  testWidgets('add dialog cancel keeps the current selection', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -41.1, 146.1),
          _buildPeak(200, 'Mike Peak', -41.2, 146.2),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    final selectedTitleBefore = tester
        .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
        .data;

    await tester.tap(find.byKey(const Key('peak-lists-add-peak')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-peak-cancel')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      selectedTitleBefore,
    );
    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
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
          _buildPeakList(
            1,
            'Tas Peaks',
            [200, 300, 100, 100],
            pointsByPeakId: const {200: 7, 300: 3, 100: 5},
          ),
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
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-200')),
        matching: find.text('7'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-100')),
        matching: find.text('5'),
      ),
      findsOneWidget,
    );
    final summaryText = tester
        .widget<Text>(find.byKey(const Key('peak-lists-summary-sentence')))
        .data;
    expect(summaryText, contains('Tas Peaks contains 3 peaks.'));
    expect(
      summaryText,
      contains(
        'Alpha Peak and Beta Peak are your most recent ascent, climbed on 2 Mar 2024.',
      ),
    );
    expect(
      summaryText,
      contains(
        'Climbed 2 of 3 peaks (67%) and earned a total 12 points out of 15.',
      ),
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
    expect(
      find.byKey(const Key('peak-lists-details-ascents-200')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-200')))
          .data,
      '1',
    );
    expect(
      find.byKey(const Key('peak-lists-details-ascents-100')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-100')))
          .data,
      '2',
    );
    expect(
      find.byKey(const Key('peak-lists-details-ascents-300')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-details-ascents-300')))
          .data,
      '',
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
      final unsupportedMessage = find.byKey(
        const Key('peak-lists-unsupported-message'),
      );
      expect(unsupportedMessage, findsOneWidget);
      expect(
        tester.widget<Text>(unsupportedMessage).data,
        contains('Delete it and re-import the CSV'),
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
        isNot(Icons.unfold_more),
      );
      expect(
        tester
            .widget<Icon>(find.byKey(const Key('peak-lists-sort-icon-name')))
            .icon,
        Icons.unfold_more,
      );

      await tester.ensureVisible(
        find.byKey(const Key('peak-lists-sort-totalPeaks')),
      );
      await tester.tap(find.byKey(const Key('peak-lists-sort-totalPeaks')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-sort-icon-totalPeaks')),
            )
            .icon,
        isNot(Icons.unfold_more),
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

  testWidgets('long peak names wrap in the details table', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Wrap Me', [100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'kunanyi / Mount Wellington', -42.0, 146.0),
        ]),
      ),
    );

    final nameText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('peak-lists-details-row-100')),
        matching: find.text('kunanyi / Mount Wellington'),
      ),
    );

    expect(nameText.maxLines, 2);
    expect(nameText.softWrap, isTrue);
  });

  testWidgets('tapping a detail row draws a peak circle', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Circle Me', [101, 102]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(101, 'Alpha Peak', -42.0, 146.0),
          _buildPeak(102, 'Bravo Peak', -42.1, 146.1),
        ]),
      ),
    );

    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsNothing,
    );

    tester
        .widget<InkWell>(find.byKey(const Key('peak-lists-details-row-102')))
        .onTap!();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-lists-selected-peak-circle-layer')),
      findsOneWidget,
    );
  });

  testWidgets('selected peak circle layers above markers in mini map', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Tas Peaks', [100]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(100, 'Alpha Peak', -42.0, 146.0, elevation: 1200),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 1, peakId: 100, gpxId: 10),
        ]),
      ),
    );

    tester
        .widget<InkWell>(find.byKey(const Key('peak-lists-details-row-100')))
        .onTap!();
    await tester.pumpAndSettle();

    final miniMap = tester.widget<FlutterMap>(
      find.descendant(
        of: find.byKey(const Key('peak-lists-mini-map')),
        matching: find.byType(FlutterMap),
      ),
    );

    expect(
      miniMap.children.indexWhere((child) => child is CircleLayer),
      greaterThan(miniMap.children.indexWhere((child) => child is MarkerLayer)),
    );
  });

  testWidgets('details table sorts rows by tapped headers', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage([
          _buildPeakList(1, 'Sort Me', [30, 10, 20]),
        ]),
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(30, 'Zulu Peak', -42.0, 146.0, elevation: 900),
          _buildPeak(10, 'Alpha Peak', -42.1, 146.1, elevation: 700),
          _buildPeak(20, 'Bravo Peak', -42.2, 146.2, elevation: 700),
        ]),
      ),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 10,
            gpxId: 10,
            date: DateTime.utc(2024, 1, 11),
          ),
          PeaksBagged(
            baggedId: 2,
            peakId: 20,
            gpxId: 11,
            date: DateTime.utc(2024, 1, 12),
          ),
        ]),
      ),
    );

    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-name')),
          )
          .icon,
      Icons.unfold_more,
    );

    final elevationHeaderSize = tester.getSize(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    final elevationHeaderStyle = Theme.of(
      tester.element(
        find.byKey(const Key('peak-lists-details-sort-elevation')),
      ),
    ).textTheme.labelLarge;
    final elevationTextPainter = TextPainter(
      text: TextSpan(text: 'Height', style: elevationHeaderStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    expect(
      elevationHeaderSize.width,
      greaterThanOrEqualTo(elevationTextPainter.width + 30),
    );

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-name')),
    );
    await tester.tap(find.byKey(const Key('peak-lists-details-sort-name')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-name')),
          )
          .icon,
      Icons.arrow_upward,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const Key('peak-lists-details-sort-icon-elevation')),
          )
          .icon,
      Icons.unfold_more,
    );

    final alphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final bravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final zuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(alphaTop, lessThan(bravoTop));
    expect(bravoTop, lessThan(zuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-elevation')),
    );
    await tester.pumpAndSettle();

    final lowAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final lowBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final highZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(lowAlphaTop, lessThan(lowBravoTop));
    expect(lowBravoTop, lessThan(highZuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.pumpAndSettle();

    final datedAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final datedBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final blankZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(datedAlphaTop, lessThan(datedBravoTop));
    expect(datedBravoTop, lessThan(blankZuluTop));

    await tester.ensureVisible(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.tap(
      find.byKey(const Key('peak-lists-details-sort-ascentDate')),
    );
    await tester.pumpAndSettle();

    final descendingBravoTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
        .dy;
    final descendingAlphaTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
        .dy;
    final descendingBlankZuluTop = tester
        .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
        .dy;
    expect(descendingBravoTop, lessThan(descendingAlphaTop));
    expect(descendingAlphaTop, lessThan(descendingBlankZuluTop));
  });

  testWidgets(
    'selecting a peak list defaults details to ascent date descending',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: PeakListRepository.test(
          InMemoryPeakListStorage([
            _buildPeakList(1, 'Sort Me', [30, 10, 20]),
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            _buildPeak(30, 'Zulu Peak', -42.0, 146.0, elevation: 900),
            _buildPeak(10, 'Alpha Peak', -42.1, 146.1, elevation: 700),
            _buildPeak(20, 'Bravo Peak', -42.2, 146.2, elevation: 700),
          ]),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(
              baggedId: 1,
              peakId: 10,
              gpxId: 10,
              date: DateTime.utc(2024, 1, 11),
            ),
            PeaksBagged(
              baggedId: 2,
              peakId: 20,
              gpxId: 11,
              date: DateTime.utc(2024, 1, 12),
            ),
          ]),
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('peak-lists-row-1')));
      await tester.tap(
        find.byKey(const Key('peak-lists-row-1')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Icon>(
              find.byKey(const Key('peak-lists-details-sort-icon-ascentDate')),
            )
            .icon,
        Icons.arrow_downward,
      );

      final bravoTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-20')))
          .dy;
      final alphaTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-10')))
          .dy;
      final zuluTop = tester
          .getTopLeft(find.byKey(const Key('peak-lists-details-row-30')))
          .dy;

      expect(bravoTop, lessThan(alphaTop));
      expect(alphaTop, lessThan(zuluTop));
    },
  );

  testWidgets('supported floor render stays desktop-only and wraps rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        _buildPeakList(
          1,
          'This is a very long peak list name that should wrap on the summary pane',
          [101],
        ),
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          101,
          'This is a very long peak name that should wrap on the details pane',
          -42.0,
          146.0,
        ),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(
          baggedId: 1,
          peakId: 101,
          gpxId: 10,
          date: DateTime.utc(2024, 1, 12),
        ),
      ]),
    );

    await _pumpPeakListsScreen(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );

    expect(find.byKey(const Key('peak-lists-summary-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-details-pane')), findsOneWidget);
    expect(find.byKey(const Key('peak-lists-mini-map')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'This is a very long peak list name that should wrap on the summary pane',
    );
    expect(
      tester.getSize(find.byKey(const Key('peak-lists-row-1'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('peak-lists-details-row-101')))
          .height,
      greaterThan(48),
    );
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

  testWidgets(
    'delete cancel keeps row and confirmed non-selected delete preserves selection',
    (tester) async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(_buildLists(['Abels', 'Connoisseurs'])),
      );

      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(),
        repository: repository,
      );

      tester
          .widget<IconButton>(find.byKey(const Key('peak-lists-delete-2')))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Delete Peak List?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-row-2')), findsOneWidget);

      tester
          .widget<IconButton>(find.byKey(const Key('peak-lists-delete-2')))
          .onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
            .data,
        'Abels',
      );
    },
  );

  testWidgets('deleting selected rows moves next, previous, then empty', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(_buildLists(['Abels', 'Bravo', 'Charlie'])),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(find.byKey(const Key('peak-lists-delete-2')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Charlie',
    );

    tester
        .widget<IconButton>(find.byKey(const Key('peak-lists-delete-3')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Abels',
    );

    tester
        .widget<IconButton>(find.byKey(const Key('peak-lists-delete-1')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-empty-message')), findsOneWidget);
  });

  testWidgets('deleting active list bumps revision and reconciles map selection', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(_buildLists(['Abels', 'Bravo'])),
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListId: 2,
      ),
    );

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
      mapNotifier: mapNotifier,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(find.byKey(const Key('peak-lists-delete-2')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(container.read(peakListRevisionProvider), 1);
    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(container.read(mapProvider).selectedPeakListId, isNull);
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

  testWidgets('create fab opens dialog and cancel closes it', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(InMemoryPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-add-list-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-create-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-create-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-create-dialog')), findsNothing);
  });

  testWidgets('create dialog validates required and duplicate names', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(
        InMemoryPeakListStorage(_buildLists(['Abels'])),
      ),
      duplicateNameChecker: (name) async => name == 'Abels',
    );

    await tester.tap(find.byKey(const Key('peak-lists-add-list-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('A list name is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('peak-list-create-name-field')),
      'Abels',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('This peak list already exists.'), findsOneWidget);
  });

  testWidgets('create dialog saves and opens the peak selector', (
    tester,
  ) async {
    final repository = PeakListRepository.test(InMemoryPeakListStorage());

    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: repository,
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([_buildPeak(100, 'Alpha Peak', -41.0, 146.0)]),
      ),
    );

    await tester.tap(find.byKey(const Key('peak-lists-add-list-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-create-name-field')),
      '  Fresh List  ',
    );
    await tester.tap(find.byKey(const Key('peak-list-create-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-create-dialog')), findsNothing);
    expect(find.byKey(const Key('peak-list-peak-dialog')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('peak-lists-selected-title')))
          .data,
      'Fresh List',
    );

    final saved = repository.getAllPeakLists().single;
    expect(saved.name, 'Fresh List');
    expect(saved.peakList, '[]');

    await tester.tap(find.byKey(const Key('peak-list-peak-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
  });

  testWidgets('create dialog failure shows modal and keeps dialog open', (
    tester,
  ) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(),
      repository: PeakListRepository.test(_ThrowingPeakListStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-lists-add-list-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-create-name-field')),
      'Broken List',
    );
    await tester.tap(find.byKey(const Key('peak-list-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Peak List Create Failed'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.byKey(const Key('peak-list-create-error-close')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('peak-list-create-error-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-create-dialog')), findsOneWidget);
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
  TestMapNotifier? mapNotifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              mapNotifier ??
              TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 15,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
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

Future<void> _pumpPeakListsScreen(
  WidgetTester tester, {
  required PeakListFilePicker filePicker,
  required PeakListRepository repository,
  PeakRepository? peakRepository,
  PeaksBaggedRepository? peaksBaggedRepository,
  PeakListImportRunner? importRunner,
  PeakListDuplicateNameChecker? duplicateNameChecker,
  TestMapNotifier? mapNotifier,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              mapNotifier ??
              TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 15,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
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
      child: const MaterialApp(home: PeakListsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

List<PeakList> _buildLists(List<String> names) {
  return [
    for (var index = 0; index < names.length; index++)
      PeakList(name: names[index], peakList: '[]')..peakListId = index + 1,
  ];
}

class _ThrowingPeakListStorage implements PeakListStorage {
  @override
  int get count => 0;

  @override
  List<PeakList> getAll() => const <PeakList>[];

  @override
  PeakList? getById(int peakListId) => null;

  @override
  PeakList? getByName(String name) => null;

  @override
  Future<void> delete(int peakListId) async {}

  @override
  Future<PeakList> put(PeakList peakList) async {
    throw StateError('boom');
  }

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    throw StateError('boom');
  }
}

PeakList _buildPeakList(
  int id,
  String name,
  List<int> peakIds, {
  Map<int, int> pointsByPeakId = const {},
}) {
  return PeakList(
    name: name,
    peakList: encodePeakListItems([
      for (final peakId in peakIds)
        PeakListItem(peakOsmId: peakId, points: pointsByPeakId[peakId] ?? 0),
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
