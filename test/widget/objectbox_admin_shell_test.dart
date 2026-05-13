import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';

void main() {
  testWidgets('admin shell opens from side menu', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('shared-app-bar')), findsOneWidget);
    expect(find.byKey(const Key('app-bar-title')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Map'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nav-objectbox-admin')), findsOneWidget);
    expect(find.byKey(const Key('side-menu-objectbox-admin')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('objectbox-admin-entity-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('objectbox-admin-schema-data-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('objectbox-admin-export-gpx')), findsNothing);
    expect(find.byKey(const Key('objectbox-admin-table')), findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('PeaksBagged').last, findsOneWidget);
  });

  testWidgets('admin shell reloads rows when re-entered', (tester) async {
    final repository = TestObjectBoxAdminRepository();

    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final initialEntityCalls = repository.getEntitiesCallCount;
    final initialLoadRowsCalls = repository.loadRowsCallCount;

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.getEntitiesCallCount, greaterThan(initialEntityCalls));
    expect(repository.loadRowsCallCount, greaterThan(initialLoadRowsCalls));
  });

  testWidgets('side navigation remains available in the current shell layout', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(1280, 900));

    expect(find.byKey(const Key('nav-dashboard')), findsOneWidget);
    expect(find.byKey(const Key('nav-objectbox-admin')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('home action returns to dashboard and is a no-op there', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-bar-home')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-bar-home')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wide destinations render in shared order', (tester) async {
    await _pumpApp(tester);

    final dashboard = tester.getTopLeft(find.byKey(const Key('nav-dashboard')));
    final map = tester.getTopLeft(find.byKey(const Key('nav-map')));
    final peakLists = tester.getTopLeft(
      find.byKey(const Key('nav-peak-lists')),
    );
    final admin = tester.getTopLeft(
      find.byKey(const Key('nav-objectbox-admin')),
    );
    final settings = tester.getTopLeft(find.byKey(const Key('nav-settings')));

    expect(dashboard.dy, lessThan(map.dy));
    expect(map.dy, lessThan(peakLists.dy));
    expect(peakLists.dy, lessThan(admin.dy));
    expect(admin.dy, lessThan(settings.dy));
  });

  testWidgets(
    'wide home icon aligns with nav icons and title is left-aligned',
    (tester) async {
      await _pumpApp(tester);

      final homeCenter = tester.getCenter(
        find.byKey(const Key('app-bar-home')),
      );
      final dashboardCenter = tester.getCenter(
        find.byKey(const Key('nav-dashboard')),
      );
      final titleTopLeft = tester.getTopLeft(
        find.byKey(const Key('app-bar-title')),
      );

      expect(homeCenter.dx, greaterThan(dashboardCenter.dx));
      expect(
        titleTopLeft.dx,
        closeTo(RouterConstants.wideNavigationWidth, 0.001),
      );
    },
  );

  testWidgets('Peak edit mode validates and refreshes the selected row', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur', area: 'Far East'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-name')),
      '',
    );
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(find.text('A peak name is required'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-name')),
      'Mt Ossa',
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-alt-name')),
      ' mt ossa ',
    );
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Alt Name must be different from Name'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-alt-name')),
      'Ossa',
    );
    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-area')),
      'New Area',
    );
    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-verified')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('Mt Ossa updated.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('objectbox-admin-peak-update-success-close')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final mapState = container.read(mapProvider);
    expect(mapState.peaks, hasLength(2));
    expect(mapState.peaks.singleWhere((peak) => peak.id == 1).area, 'New Area');
    expect(mapState.peaks.singleWhere((peak) => peak.id == 1).altName, 'Ossa');
    expect(mapState.peaks.singleWhere((peak) => peak.id == 1).verified, isTrue);
    expect(find.text('New Area'), findsWidgets);
  });

  testWidgets('Peak edit calculates MGRS from changed latitude', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-latitude')),
      '-41.600000',
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-mgrs100k-id')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-easting')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-northing')),
          )
          .controller!
          .text,
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-calculate')));
    await tester.pumpAndSettle();

    final expectedComponents = PeakMgrsConverter.fromLatLng(
      const LatLng(-41.6, 146.5),
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-mgrs100k-id')),
          )
          .controller!
          .text,
      expectedComponents.mgrs100kId,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-easting')),
          )
          .controller!
          .text,
      expectedComponents.easting,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-northing')),
          )
          .controller!
          .text,
      expectedComponents.northing,
    );

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-latitude'),
      '-41.600000',
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-longitude'),
      '146.500000',
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(repository.findById(1)?.latitude, -41.6);
    expect(repository.findById(1)?.longitude, 146.5);
    expect(repository.findById(1)?.mgrs100kId, expectedComponents.mgrs100kId);
    expect(repository.findById(1)?.easting, expectedComponents.easting);
    expect(repository.findById(1)?.northing, expectedComponents.northing);
  });

  testWidgets('Peak edit calculates latitude and longitude from changed MGRS', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);
    final expectedComponents = PeakMgrsConverter.fromLatLng(
      const LatLng(-41.6, 146.6),
    );
    final expectedForward =
        '${PeakAdminEditor.fixedGridZoneDesignator}'
        '${expectedComponents.mgrs100kId}'
        '${expectedComponents.easting}'
        '${expectedComponents.northing}';
    final expectedLatLng = mgrs.Mgrs.toPoint(expectedForward);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-mgrs100k-id')),
      expectedComponents.mgrs100kId,
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-easting')),
      expectedComponents.easting,
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-northing')),
      expectedComponents.northing,
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-latitude'),
      isEmpty,
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-longitude'),
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-calculate')));
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-latitude'),
      expectedLatLng[1].toStringAsFixed(6),
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-longitude'),
      expectedLatLng[0].toStringAsFixed(6),
    );

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    final saved = repository.findById(1)!;
    expect(saved.mgrs100kId, expectedComponents.mgrs100kId);
    expect(saved.easting, expectedComponents.easting);
    expect(saved.northing, expectedComponents.northing);
    expect(saved.latitude, closeTo(expectedLatLng[1], 0.000001));
    expect(saved.longitude, closeTo(expectedLatLng[0], 0.000001));
  });

  testWidgets(
    'Peak edit shows paired-coordinate error for incomplete lat/lng',
    (tester) async {
      final peaks = [
        _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
      ];
      final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
        'Peak': peaks.map(_peakRow).toList(),
        'PeakList': const [],
        'Tasmap50k': const [],
        'GpxTrack': const [],
        'PeaksBagged': const [],
      };

      await _pumpApp(
        tester,
        repository: TestObjectBoxAdminRepository(
          entities: [_peakEntity()],
          rowsByEntity: rowsByEntity,
        ),
        peakRepository: _MutablePeakRepository(peaks, rowsByEntity),
        peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
      );

      await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Mt Ossa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('objectbox-admin-peak-latitude')),
        '-41.600000',
      );
      await tester.enterText(
        find.byKey(const Key('objectbox-admin-peak-longitude')),
        '',
      );
      await tester.drag(
        find.byKey(const Key('objectbox-admin-peak-edit-form')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-mgrs100k-id'),
        isEmpty,
      );
      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-easting'),
        isEmpty,
      );
      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-northing'),
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('objectbox-admin-peak-calculate')));
      await tester.pumpAndSettle();

      expect(find.text('Enter both latitude and longitude.'), findsOneWidget);
      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-mgrs100k-id'),
        isEmpty,
      );
      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-easting'),
        isEmpty,
      );
      expect(
        _textFormFieldText(tester, 'objectbox-admin-peak-northing'),
        isEmpty,
      );
    },
  );

  testWidgets('Peak admin renders coordinates with six decimals', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: _MutablePeakRepository(peaks, rowsByEntity),
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('-41.500000'), findsOneWidget);
    expect(find.text('146.500000'), findsOneWidget);

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

    expect(find.text('-41.500000'), findsWidgets);
    expect(find.text('146.500000'), findsWidgets);

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-latitude'),
      '-41.500000',
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-longitude'),
      '146.500000',
    );
  });

  testWidgets('Peak edit ignores focus-only and non-coordinate edits', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final expectedComponents = PeakMgrsConverter.fromLatLng(
      const LatLng(-41.5, 146.5),
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: _MutablePeakRepository(peaks, rowsByEntity),
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-latitude')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-mgrs100k-id'),
      expectedComponents.mgrs100kId,
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-easting'),
      expectedComponents.easting,
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-northing'),
      expectedComponents.northing,
    );

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-name')),
      'Mt Ossa Peak',
    );
    await tester.pumpAndSettle();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );

    await tester.drag(
      find.byKey(const Key('objectbox-admin-peak-edit-form')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-mgrs100k-id'),
      expectedComponents.mgrs100kId,
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-easting'),
      expectedComponents.easting,
    );
    expect(
      _textFormFieldText(tester, 'objectbox-admin-peak-northing'),
      expectedComponents.northing,
    );
  });

  testWidgets('Peak calculate is disabled before edit and while saving', (
    tester,
  ) async {
    final saveGate = Completer<void>();
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: _MutablePeakRepository(
        peaks,
        rowsByEntity,
        saveGate: saveGate,
      ),
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-latitude')),
      '-41.600000',
    );
    await tester.pumpAndSettle();
    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pump();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );
    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-submit'),
      isFalse,
    );

    saveGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Peak row switch and create mode reset calculate state', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur', area: 'Far East'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: _MutablePeakRepository(peaks, rowsByEntity),
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-latitude')),
      '-41.600000',
    );
    await tester.pumpAndSettle();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isTrue,
    );

    await tester.tap(find.text('Ossa Spur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();

    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-add')));
    await tester.pumpAndSettle();

    expect(find.text('Add Peak').last, findsOneWidget);
    expect(
      _isFilledButtonEnabled(tester, 'objectbox-admin-peak-calculate'),
      isFalse,
    );
  });

  testWidgets('Peak admin table and details use required field ordering', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(entities: [_peakEntity()]),
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final header = find.byKey(const Key('objectbox-admin-header-row'));
    expect(
      tester
          .getTopLeft(find.descendant(of: header, matching: find.text('name')))
          .dx,
      lessThan(
        tester
            .getTopLeft(
              find.descendant(of: header, matching: find.text('altName')),
            )
            .dx,
      ),
    );
    expect(
      tester
          .getTopLeft(
            find.descendant(of: header, matching: find.text('altName')),
          )
          .dx,
      lessThan(
        tester
            .getTopLeft(find.descendant(of: header, matching: find.text('id')))
            .dx,
      ),
    );
    expect(
      find.descendant(of: header, matching: find.text('Delete')),
      findsOneWidget,
    );

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

    final details = find.byKey(const Key('objectbox-admin-details-close'));
    expect(
      tester.getTopLeft(find.text('id').last).dy,
      lessThan(tester.getTopLeft(find.text('name').last).dy),
    );
    expect(
      tester.getTopLeft(find.text('name').last).dy,
      lessThan(tester.getTopLeft(find.text('altName').last).dy),
    );
    expect(details, findsOneWidget);
  });

  testWidgets('details value renders booleans as disabled checkboxes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ObjectBoxAdminDetailsValue(label: 'verified', value: true),
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(checkbox.onChanged, isNull);
    expect(find.text('true'), findsNothing);
  });

  testWidgets('View Peak on Main Map opens the map at the Peak location', (
    tester,
  ) async {
    final peak = _buildPeak(
      id: 1,
      osmId: 101,
      name: 'Mt Ossa',
      area: 'Old Area',
    );
    final peaks = [peak];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('objectbox-admin-peak-view-on-map')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-view-on-map')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Map'),
      ),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final mapState = container.read(mapProvider);
    expect(mapState.center.latitude, closeTo(peak.latitude, 0.001));
    expect(mapState.center.longitude, closeTo(peak.longitude, 0.001));
    expect(mapState.zoom, MapConstants.defaultZoom);
    expect(mapState.selectedLocation, isNotNull);
  });

  testWidgets('Add Peak opens a create form and saves a new peak', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur', area: 'Far East'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('objectbox-admin-peak-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('objectbox-admin-peak-add')), findsOneWidget);
    expect(find.text('Add Peak').last, findsOneWidget);
    expect(find.byKey(const Key('objectbox-admin-peak-name')), findsOneWidget);
    expect(find.byKey(const Key('objectbox-admin-peak-edit')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('objectbox-admin-peak-osm-id')),
          )
          .controller!
          .text,
      '-1',
    );

    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-name')),
      'New Peak',
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-osm-id')),
      '303',
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-latitude')),
      '-41.5',
    );
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-longitude')),
      '146.5',
    );
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(find.text('New Peak updated.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('objectbox-admin-peak-update-success-close')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final mapState = container.read(mapProvider);
    expect(mapState.peaks, hasLength(3));
    expect(
      mapState.peaks.singleWhere((peak) => peak.osmId == 303).name,
      'New Peak',
    );
    expect(
      container.read(objectboxAdminProvider).selectedRow?.primaryKeyValue,
      3,
    );
    expect(repository.findByOsmId(303)?.name, 'New Peak');
    expect(find.text('Peak #3'), findsOneWidget);
  });

  testWidgets('Peak save success surfaces PeakList warnings', (tester) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa', area: 'Old Area'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(
      peaks,
      rowsByEntity,
      saveResultBuilder: (peak) {
        return PeakSaveResult(
          peak: peak,
          peakListRewriteResult: const PeakListRewriteResult(
            rewrittenCount: 0,
            skippedMalformedCount: 1,
          ),
        );
      },
    );

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('objectbox-admin-peak-area')),
      'New Area',
    );
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Update Successful'), findsOneWidget);
    expect(
      find.text("1 PeakList has been skipped as it's malformed."),
      findsOneWidget,
    );
  });

  testWidgets('Peak delete is blocked by dependent PeakList', (tester) async {
    final peaks = [_buildPeak(id: 1, osmId: 101, name: 'Mt Ossa')];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(
        entities: [_peakEntity()],
        rowsByEntity: rowsByEntity,
      ),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(
        _PeakListBlockerSource(
          peakLists: [
            PeakList(
              name: 'Abels',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 101, points: 3),
              ]),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete Blocked'), findsOneWidget);
    expect(find.textContaining('PeakList Abels'), findsOneWidget);
    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-1')),
      findsOneWidget,
    );
  });

  testWidgets('Peak delete confirmation clears the selected row when deleted', (
    tester,
  ) async {
    final peaks = [
      _buildPeak(id: 1, osmId: 101, name: 'Mt Ossa'),
      _buildPeak(id: 2, osmId: 202, name: 'Ossa Spur'),
    ];
    final rowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': peaks.map(_peakRow).toList(),
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
      'PeaksBagged': const [],
    };
    final repository = _MutablePeakRepository(peaks, rowsByEntity);

    await _pumpApp(
      tester,
      repository: TestObjectBoxAdminRepository(rowsByEntity: rowsByEntity),
      peakRepository: repository,
      peakDeleteGuard: PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
    );

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('objectbox-admin-peak-delete-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete Peak?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Select a row to inspect full values.'), findsOneWidget);
    expect(
      find.byKey(const Key('objectbox-admin-peak-delete-1')),
      findsNothing,
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  List<ObjectBoxAdminEntityDescriptor>? entities,
  TestObjectBoxAdminRepository? repository,
  PeakRepository? peakRepository,
  PeakDeleteGuard? peakDeleteGuard,
  Size size = const Size(1280, 900),
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
        peakRepositoryProvider.overrideWithValue(
          peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
        ),
        peakDeleteGuardProvider.overrideWithValue(
          peakDeleteGuard ?? PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
        ),
      ],
      child: const App(),
    ),
  );

  await tester.pump();
}

Peak _buildPeak({
  required int id,
  required int osmId,
  required String name,
  String altName = '',
  double? elevation,
  String? area,
  bool verified = false,
}) {
  final location = const LatLng(-41.5, 146.5);
  final components = PeakMgrsConverter.fromLatLng(location);
  return Peak(
    id: id,
    osmId: osmId,
    name: name,
    altName: altName,
    elevation: elevation,
    latitude: location.latitude,
    longitude: location.longitude,
    area: area,
    gridZoneDesignator: components.gridZoneDesignator,
    mgrs100kId: components.mgrs100kId,
    easting: components.easting,
    northing: components.northing,
    verified: verified,
  );
}

ObjectBoxAdminEntityDescriptor _peakEntity() {
  return const ObjectBoxAdminEntityDescriptor(
    name: 'Peak',
    displayName: 'Peak',
    primaryKeyField: 'id',
    primaryNameField: 'name',
    fields: [
      ObjectBoxAdminFieldDescriptor(
        name: 'id',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: true,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'name',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: true,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'altName',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'osmId',
        typeLabel: 'int',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'elevation',
        typeLabel: 'double',
        nullable: true,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'latitude',
        typeLabel: 'double',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'longitude',
        typeLabel: 'double',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'area',
        typeLabel: 'String',
        nullable: true,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'gridZoneDesignator',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'mgrs100kId',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'easting',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'northing',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'verified',
        typeLabel: 'bool',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
      ObjectBoxAdminFieldDescriptor(
        name: 'sourceOfTruth',
        typeLabel: 'String',
        nullable: false,
        isPrimaryKey: false,
        isPrimaryName: false,
      ),
    ],
  );
}

ObjectBoxAdminRow _peakRow(Peak peak) {
  return peakToAdminRow(peak);
}

String _textFormFieldText(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;
}

bool _isFilledButtonEnabled(WidgetTester tester, String key) {
  return tester.widget<FilledButton>(find.byKey(Key(key))).onPressed != null;
}

class _MutablePeakRepository extends PeakRepository {
  _MutablePeakRepository(
    this._peaks,
    this._rowsByEntity, {
    this.saveResultBuilder,
    this.saveGate,
  }) : super.test(InMemoryPeakStorage(_peaks));

  final List<Peak> _peaks;
  final Map<String, List<ObjectBoxAdminRow>> _rowsByEntity;
  final PeakSaveResult Function(Peak peak)? saveResultBuilder;
  final Completer<void>? saveGate;

  @override
  List<Peak> getAllPeaks() => List<Peak>.unmodifiable(_peaks);

  @override
  Peak? findByOsmId(int osmId) {
    for (final peak in _peaks) {
      if (peak.osmId == osmId) {
        return peak;
      }
    }
    return null;
  }

  @override
  Peak? findById(int peakId) {
    for (final peak in _peaks) {
      if (peak.id == peakId) {
        return peak;
      }
    }
    return null;
  }

  @override
  Future<PeakSaveResult> saveDetailed(Peak peak) async {
    await saveGate?.future;

    final index = _peaks.indexWhere((entry) => entry.id == peak.id);
    final saved = peak.copyWith();
    if (index == -1) {
      saved.id = peak.id == 0 ? _peaks.length + 1 : peak.id;
      _peaks.add(saved);
    } else {
      saved.id = peak.id;
      _peaks[index] = saved;
    }

    _syncRows();
    return saveResultBuilder?.call(saved) ?? PeakSaveResult(peak: saved);
  }

  @override
  Future<void> delete(int peakId) async {
    _peaks.removeWhere((peak) => peak.id == peakId);
    _syncRows();
  }

  void _syncRows() {
    _rowsByEntity['Peak'] = _peaks.map(_peakRow).toList(growable: false);
  }
}

class _PeakListBlockerSource implements PeakDeleteGuardSource {
  _PeakListBlockerSource({required this.peakLists});

  final List<PeakList> peakLists;

  @override
  List<GpxTrack> loadGpxTracks() => const [];

  @override
  List<PeakList> loadPeakLists() => peakLists;

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}

class _NoopPeakDeleteGuardSource implements PeakDeleteGuardSource {
  @override
  List<GpxTrack> loadGpxTracks() => const [];

  @override
  List<PeakList> loadPeakLists() => const [];

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}
