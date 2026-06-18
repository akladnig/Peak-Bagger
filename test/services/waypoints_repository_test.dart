import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';

void main() {
  group('WaypointsRepository', () {
    test('saveMarker replaces previous marker row', () async {
      final repository = WaypointsRepository.test(InMemoryWaypointsStorage());

      final first = await repository.saveMarker(
        location: const LatLng(-42.0, 146.0),
        name: 'First Marker',
      );
      final second = await repository.saveMarker(
        location: const LatLng(-43.0, 147.0),
        name: 'Second Marker',
      );

      expect(first.id, isNonZero);
      expect(second.id, isNonZero);
      expect(repository.getAll().where((row) => row.type == Waypoints.typeMarker), hasLength(1));
      expect(repository.getCurrentMarker()!.name, 'Second Marker');
      expect(repository.getCurrentMarker()!.latitude, closeTo(-43.0, 1e-9));
      expect(repository.getCurrentMarker()!.longitude, closeTo(147.0, 1e-9));
    });

    test('getCurrentMarker prefers highest id marker row', () {
      final repository = WaypointsRepository.test(
        InMemoryWaypointsStorage([
          Waypoints(
            id: 3,
            name: 'Older Marker',
            type: Waypoints.typeMarker,
            latitude: -42.0,
            longitude: 146.0,
            mgrs: '55G EN 10000 10000',
          ),
          Waypoints(
            id: 4,
            name: 'Newer Marker',
            type: Waypoints.typeMarker,
            latitude: -43.0,
            longitude: 147.0,
            mgrs: '55G EN 20000 20000',
          ),
        ]),
      );

      expect(repository.getCurrentMarker()!.name, 'Newer Marker');
    });
  });
}
