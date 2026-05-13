// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_peak_notifier.dart';

void main() {
  testWidgets('update tassy full cancel is a no-op', (tester) async {
    _setLargeViewport(tester);
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        )..peakListId = 1,
      ]),
    );
    final mapNotifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          peakListRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final settingsScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('update-tassy-full-peak-list-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('update-tassy-full-peak-list-tile')));
    await tester.pump();

    expect(find.text('Update Tassy Full Peak List?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-tassy-full-cancel')));
    await tester.pump();

    expect(find.text('Tassy Full Peak List Updated'), findsNothing);
    expect(repository.findByName('Tassy Full'), isNull);
    expect(mapNotifier.refreshCallCount, 0);
  });

  testWidgets('update tassy full shows success dialog', (tester) async {
    _setLargeViewport(tester);
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
            const PeakListItem(peakOsmId: 22, points: 4),
          ]),
        )..peakListId = 1,
      ]),
    );
    final mapNotifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          peakListRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final settingsScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('update-tassy-full-peak-list-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('update-tassy-full-peak-list-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('update-tassy-full-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Tassy Full Peak List Updated'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Added 2 peaks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Updated 0 peaks')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('update-tassy-full-result-close')), findsOneWidget);
    expect(
      decodePeakListItems(repository.findByName('Tassy Full')!.peakList)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 2), (22, 4)],
    );
  });

  testWidgets('update tassy full shows failure dialog', (tester) async {
    _setLargeViewport(tester);
    final repository = PeakListRepository.test(
      _FailingTassyFullStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        )..peakListId = 1,
      ]),
    );
    final mapNotifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          peakListRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final settingsScrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.byKey(const Key('update-tassy-full-peak-list-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('update-tassy-full-peak-list-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('update-tassy-full-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Tassy Full Peak List Update Failed'),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: dialog, matching: find.textContaining('boom')),
        findsOneWidget);
    expect(
      repository.findByName('Tassy Full'),
      isNull,
    );
    expect(find.byKey(const Key('update-tassy-full-error-close')), findsOneWidget);
  });
}

class _FailingTassyFullStorage extends InMemoryPeakListStorage {
  _FailingTassyFullStorage([List<PeakList> peakLists = const []])
    : super(peakLists);

  @override
  Future<PeakList> put(PeakList peakList) {
    if (peakList.name == 'Tassy Full') {
      throw StateError('boom');
    }

    return super.put(peakList);
  }

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) {
    if (peakList.name == 'Tassy Full') {
      throw StateError('boom');
    }

    return super.replaceByName(peakList, beforePutForTest: beforePutForTest);
  }
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
