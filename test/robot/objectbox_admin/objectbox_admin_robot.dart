import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_objectbox_admin_repository.dart';

class ObjectBoxAdminRobot {
  ObjectBoxAdminRobot(this.tester);

  final WidgetTester tester;

  Finder get adminMenuItem => find.byKey(const Key('nav-objectbox-admin'));
  Finder get appBarTitle => find.byKey(const Key('app-bar-title'));
  Finder get homeAction => find.byKey(const Key('app-bar-home'));
  Finder get entityDropdown =>
      find.byKey(const Key('objectbox-admin-entity-dropdown'));
  Finder get schemaDataToggle =>
      find.byKey(const Key('objectbox-admin-schema-data-toggle'));
  Finder get exportButton =>
      find.byKey(const Key('objectbox-admin-export-gpx'));
  Finder get exportError =>
      find.byKey(const Key('objectbox-admin-export-error'));
  Finder get table => find.byKey(const Key('objectbox-admin-table'));
  Finder get addPeakButton => find.byKey(const Key('objectbox-admin-peak-add'));
  Finder get peakEditButton =>
      find.byKey(const Key('objectbox-admin-peak-edit'));
  Finder get peakViewOnMapButton =>
      find.byKey(const Key('objectbox-admin-peak-view-on-map'));
  Finder get peakSubmitButton =>
      find.byKey(const Key('objectbox-admin-peak-submit'));
  Finder get peakDeleteBlockedClose =>
      find.byKey(const Key('objectbox-admin-peak-delete-blocked-close'));
  Finder get peakUpdateSuccessClose =>
      find.byKey(const Key('objectbox-admin-peak-update-success-close'));
  Finder peakDeleteButton(int peakId) =>
      find.byKey(Key('objectbox-admin-peak-delete-$peakId'));
  Finder peakField(String fieldName) =>
      find.byKey(Key('objectbox-admin-peak-${_fieldKey(fieldName)}'));

  String _fieldKey(String fieldName) {
    return fieldName.replaceAllMapped(
      RegExp(r'(?<!^)([A-Z])'),
      (match) => '-${match[1]!.toLowerCase()}',
    );
  }

  Future<void> pumpApp({
    TestObjectBoxAdminRepository? repository,
    List<ObjectBoxAdminEntityDescriptor>? entities,
    PeakRepository? peakRepository,
    PeakDeleteGuard? peakDeleteGuard,
    Size size = const Size(1000, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
              peakRepository:
                  peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
            ),
          ),
          objectboxAdminRepositoryProvider.overrideWithValue(
            repository ?? TestObjectBoxAdminRepository(entities: entities),
          ),
          if (peakRepository != null)
            peakRepositoryProvider.overrideWithValue(peakRepository),
          if (peakDeleteGuard != null)
            peakDeleteGuardProvider.overrideWithValue(peakDeleteGuard),
          if (peakRepository == null)
            peakRepositoryProvider.overrideWithValue(
              PeakRepository.test(InMemoryPeakStorage()),
            ),
          if (peakDeleteGuard == null)
            peakDeleteGuardProvider.overrideWithValue(
              PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
            ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
  }

  Future<void> openAdminFromMenu() async {
    await tester.tap(adminMenuItem);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> selectRow(String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> startEditingPeak() async {
    await tester.tap(peakEditButton);
    await tester.pumpAndSettle();
  }

  Future<void> viewPeakOnMainMap() async {
    await tester.tap(peakViewOnMapButton);
    await tester.pumpAndSettle();
  }

  Future<void> startCreatingPeak() async {
    await tester.tap(addPeakButton);
    await tester.pumpAndSettle();
  }

  Future<void> enterPeakField(String fieldName, String value) async {
    final finder = peakField(fieldName);
    await tester.tap(finder);
    await tester.pump();
    tester.testTextInput.enterText(value);
    await tester.pumpAndSettle();
  }

  Future<void> submitPeakEdit() async {
    await tester.tap(peakSubmitButton);
    await tester.pumpAndSettle();
  }

  Future<void> deletePeak(int peakId) async {
    await tester.tap(peakDeleteButton(peakId));
    await tester.pumpAndSettle();
  }

  Future<void> closePeakSuccessDialog() async {
    await tester.tap(peakUpdateSuccessClose);
    await tester.pumpAndSettle();
  }

  void expectAdminShellVisible() {
    expect(appBarTitle, findsOneWidget);
    expect(
      find.descendant(of: appBarTitle, matching: find.text('ObjectBox Admin')),
      findsOneWidget,
    );
    expect(entityDropdown, findsOneWidget);
    expect(schemaDataToggle, findsOneWidget);
    expect(table, findsOneWidget);
  }
}

class _NoopPeakDeleteGuardSource implements PeakDeleteGuardSource {
  @override
  List<GpxTrack> loadGpxTracks() => const [];

  @override
  List<PeakList> loadPeakLists() => const [];

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}
