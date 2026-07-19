// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_peak_notifier.dart';

void main() {
  testWidgets('update tassy full shows updated copy and cancel is a no-op', (
    tester,
  ) async {
    _setLargeViewport(tester);
    final repository = _buildRepository(
      peakLists: [
        PeakList(name: 'Abels')..peakListId = 1,
      ],
      peaks: [_peak(11)],
      memberships: const [(peakListId: 1, peakOsmId: 11, points: 2)],
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

    expect(
      find.text(
        'Updates the Tassy Full Peak List using Tasmanian peaks from other peak lists',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('update-tassy-full-peak-list-tile')));
    await tester.pump();

    expect(find.text('Update Tassy Full Peak List?'), findsOneWidget);
    expect(
      find.text(
        'This will update Tassy Full using Tasmanian peaks from other peak lists and remove non-Tasmanian peaks. Do you wish to proceed?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('update-tassy-full-cancel')));
    await tester.pump();

    expect(find.text('Tassy Full Peak List Updated'), findsNothing);
    expect(repository.findByName('Tassy Full'), isNull);
    expect(mapNotifier.refreshCallCount, 0);
  });

  testWidgets('update tassy full shows success dialog', (tester) async {
    _setLargeViewport(tester);
    final peakIds = List<int>.generate(1234, (index) => index + 1);
    final repository = _buildRepository(
      peakLists: [
        PeakList(name: 'Abels')..peakListId = 1,
        PeakList(name: 'Tassy Full')..peakListId = 2,
      ],
      peaks: [
        for (final peakId in peakIds) _peak(peakId),
        _peak(2000, region: 'new-south-wales'),
      ],
      memberships: [
        for (final peakId in peakIds) (peakListId: 1, peakOsmId: peakId, points: 1),
        (peakListId: 2, peakOsmId: 2000, points: 9),
      ],
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
      find.descendant(of: dialog, matching: find.text('Added 1,234 peaks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Updated 0 peaks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Removed 0 peaks')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('update-tassy-full-result-close')),
      findsOneWidget,
    );
    expect(
      repository
          .getPeakListItemsForList(repository.findByName('Tassy Full')!.peakListId)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [for (final peakId in peakIds) (peakId, 1), (2000, 9)],
    );
  });

  testWidgets('update tassy full shows failure dialog', (tester) async {
    _setLargeViewport(tester);
    final abels = PeakList(name: 'Abels')..peakListId = 1;
    final repository = _buildRepository(
      storage: _FailingTassyFullStorage([abels]),
      peakLists: [abels],
      peaks: [_peak(11)],
      memberships: const [(peakListId: 1, peakOsmId: 11, points: 2)],
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
    expect(
      find.descendant(of: dialog, matching: find.textContaining('boom')),
      findsOneWidget,
    );
    expect(repository.findByName('Tassy Full'), isNull);
    expect(
      find.byKey(const Key('update-tassy-full-error-close')),
      findsOneWidget,
    );
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

PeakListRepository _buildRepository({
  PeakListStorage? storage,
  required List<PeakList> peakLists,
  required List<Peak> peaks,
  List<({int peakListId, int peakOsmId, int points})> memberships = const [],
}) {
  final peakRepository = PeakRepository.test(InMemoryPeakStorage(peaks));
  final peakListsById = {for (final peakList in peakLists) peakList.peakListId: peakList};
  return PeakListRepository.test(
    storage ?? InMemoryPeakListStorage(peakLists),
    peakRepository: peakRepository,
    itemStorage: InMemoryPeakListItemEntityStorage([
      for (var index = 0; index < memberships.length; index++)
        PeakListItemEntity(id: index + 1, points: memberships[index].points)
          ..peakList.target = peakListsById[memberships[index].peakListId]!
          ..peak.target = peakRepository.findByOsmId(memberships[index].peakOsmId),
    ]),
  );
}

Peak _peak(int osmId, {String region = Peak.defaultRegion}) {
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    latitude: -41.5,
    longitude: 146.5,
    region: region,
  );
}
