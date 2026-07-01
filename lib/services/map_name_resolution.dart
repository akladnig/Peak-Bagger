import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

enum MapNameOrigin { sheet, region, unknown }

class ResolvedMapName {
  const ResolvedMapName({required this.displayName, required this.origin});

  const ResolvedMapName.unknown()
    : displayName = 'Unknown',
      origin = MapNameOrigin.unknown;

  final String displayName;
  final MapNameOrigin origin;
}

const _regionDisplayNameAliases = <String, String>{'tasmania': 'Tasmanian'};

String formatRegionDisplayName(String regionKey) {
  final alias = _regionDisplayNameAliases[regionKey];
  if (alias != null) {
    return alias;
  }

  return regionKey
      .split('-')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

ResolvedMapName resolveMapNameForPoint({
  required TasmapRepository tasmapRepository,
  required LatLng point,
}) {
  try {
    final map = tasmapRepository.findByPoint(point);
    if (map != null) {
      return ResolvedMapName(
        displayName: map.name,
        origin: MapNameOrigin.sheet,
      );
    }
  } catch (_) {
    // Fall through to region fallback.
  }

  final region = regionManifestCatalog.regionForPoint(point);
  if (region != null) {
    return ResolvedMapName(
      displayName: formatRegionDisplayName(region.key),
      origin: MapNameOrigin.region,
    );
  }

  return const ResolvedMapName.unknown();
}

String? resolveSheetMapNameForPoint({
  required TasmapRepository tasmapRepository,
  required LatLng point,
}) {
  try {
    return tasmapRepository.findByPoint(point)?.name;
  } catch (_) {
    return null;
  }
}

ResolvedMapName resolveMapNameForMgrs({
  required TasmapRepository tasmapRepository,
  required String mgrsText,
}) {
  final normalizedMgrs = mgrsText.replaceAll(RegExp(r'\s+'), ' ').trim();

  try {
    final map = tasmapRepository.findByMgrsCodeAndCoordinates(normalizedMgrs);
    if (map != null) {
      return ResolvedMapName(
        displayName: map.name,
        origin: MapNameOrigin.sheet,
      );
    }
  } catch (_) {
    // Fall through to region fallback.
  }

  try {
    final coords = mgrs.Mgrs.toPoint(normalizedMgrs);
    return resolveMapNameForPoint(
      tasmapRepository: tasmapRepository,
      point: LatLng(coords[1], coords[0]),
    );
  } catch (_) {
    return const ResolvedMapName.unknown();
  }
}
