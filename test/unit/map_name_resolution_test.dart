import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('formats region display names with alias and humanized keys', () {
    expect(formatRegionDisplayName('tasmania'), 'Tasmanian');
    expect(formatRegionDisplayName('italy-nord-est'), 'Italy Nord Est');
  });

  test('resolves sheet name for matching point', () async {
    final repository = await TestTasmapRepository.create();
    final point = repository.getMapCenter(repository.getAllMaps().first)!;

    final resolved = resolveMapNameForPoint(
      tasmapRepository: repository,
      point: point,
    );

    expect(resolved.displayName, 'Adamsons');
    expect(resolved.origin, MapNameOrigin.sheet);
  });

  test('falls back to region for known point without sheet coverage', () async {
    final repository = await TestTasmapRepository.create(maps: []);

    final resolved = resolveMapNameForPoint(
      tasmapRepository: repository,
      point: const LatLng(-43.0, 147.0),
    );

    expect(resolved.displayName, 'Tasmanian');
    expect(resolved.origin, MapNameOrigin.region);
  });

  test('falls back to region for known MGRS without sheet coverage', () async {
    final repository = await TestTasmapRepository.create(maps: []);

    final resolved = resolveMapNameForMgrs(
      tasmapRepository: repository,
      mgrsText: '55G DM 80000 95000',
    );

    expect(resolved.displayName, 'Tasmanian');
    expect(resolved.origin, MapNameOrigin.region);
  });

  test('returns unknown outside supported regions', () async {
    final repository = await TestTasmapRepository.create(maps: []);

    final resolved = resolveMapNameForPoint(
      tasmapRepository: repository,
      point: const LatLng(0, 0),
    );

    expect(resolved.displayName, 'Unknown');
    expect(resolved.origin, MapNameOrigin.unknown);
  });
}
