import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('recovery state shows banner and disables track controls', (
    tester,
  ) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
      hasTrackRecoveryIssue: true,
      tracks: [
        GpxTrack(contentHash: '', trackName: 'Broken Track', trackDate: null),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapProvider.overrideWith(() => TestMapNotifier(state))],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Some tracks need to be rebuilt.'), findsWidgets);

    final showTracksFab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('show-tracks-fab')),
    );
    final importFab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('import-tracks-fab')),
    );

    expect(showTracksFab.onPressed, isNull);
    expect(importFab.onPressed, isNull);
  });
}
