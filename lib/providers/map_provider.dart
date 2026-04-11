import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/main.dart';

const _distance = Distance();

const _latKey = 'map_position_lat';
const _lngKey = 'map_position_lng';
const _zoomKey = 'map_zoom';

const _defaultCenter = LatLng(-41.5, 146.5);
const _defaultZoom = 15.0;

enum Basemap { tracestrack, openstreetmap }

class MapState {
  final LatLng center;
  final double zoom;
  final Basemap basemap;
  final bool isFirstLaunch;
  final bool isLoading;
  final String? error;
  final String currentMgrs;
  final String? cursorMgrs;
  final String? gotoMgrs;
  final bool showGotoInput;
  final bool showPeakSearch;
  final bool showInfoPopup;
  final String? infoMapName;
  final String? infoMgrs;
  final String? infoPeakName;
  final double? infoPeakElevation;
  final LatLng? selectedLocation;
  final bool syncEnabled;
  final List<Peak> peaks;
  final bool isLoadingPeaks;
  final List<Peak> searchResults;
  final String searchQuery;
  final List<Peak> selectedPeaks;
  final Tasmap50k? selectedMap;
  final bool showMapOverlay;
  final List<Tasmap50k> mapSuggestions;
  final String mapSearchQuery;

  const MapState({
    required this.center,
    required this.zoom,
    required this.basemap,
    this.isFirstLaunch = true,
    this.isLoading = false,
    this.error,
    this.currentMgrs = '55G FN\n00000 00000',
    this.cursorMgrs,
    this.gotoMgrs,
    this.showGotoInput = false,
    this.showPeakSearch = false,
    this.showInfoPopup = false,
    this.infoMapName,
    this.infoMgrs,
    this.infoPeakName,
    this.infoPeakElevation,
    this.selectedLocation,
    this.syncEnabled = true,
    this.peaks = const [],
    this.isLoadingPeaks = false,
    this.searchResults = const [],
    this.searchQuery = '',
    this.selectedPeaks = const [],
    this.selectedMap,
    this.showMapOverlay = false,
    this.mapSuggestions = const [],
    this.mapSearchQuery = '',
  });

  MapState copyWith({
    LatLng? center,
    double? zoom,
    Basemap? basemap,
    bool? isFirstLaunch,
    bool? isLoading,
    String? error,
    String? currentMgrs,
    String? cursorMgrs,
    String? gotoMgrs,
    bool? showGotoInput,
    bool? showPeakSearch,
    bool? showInfoPopup,
    String? infoMapName,
    String? infoMgrs,
    String? infoPeakName,
    double? infoPeakElevation,
    bool clearInfoPopup = false,
    LatLng? selectedLocation,
    bool clearSelectedLocation = false,
    bool? syncEnabled,
    List<Peak>? peaks,
    bool? isLoadingPeaks,
    List<Peak>? searchResults,
    String? searchQuery,
    List<Peak>? selectedPeaks,
    Tasmap50k? selectedMap,
    bool? showMapOverlay,
    List<Tasmap50k>? mapSuggestions,
    String? mapSearchQuery,
  }) {
    return MapState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      basemap: basemap ?? this.basemap,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentMgrs: currentMgrs ?? this.currentMgrs,
      cursorMgrs: cursorMgrs,
      gotoMgrs: gotoMgrs,
      showGotoInput: showGotoInput ?? this.showGotoInput,
      showPeakSearch: showPeakSearch ?? this.showPeakSearch,
      showInfoPopup: clearInfoPopup
          ? false
          : (showInfoPopup ?? this.showInfoPopup),
      infoMapName: clearInfoPopup ? null : (infoMapName ?? this.infoMapName),
      infoMgrs: clearInfoPopup ? null : (infoMgrs ?? this.infoMgrs),
      infoPeakName: clearInfoPopup ? null : (infoPeakName ?? this.infoPeakName),
      infoPeakElevation: clearInfoPopup
          ? null
          : (infoPeakElevation ?? this.infoPeakElevation),
      selectedLocation: clearSelectedLocation
          ? null
          : (selectedLocation ?? this.selectedLocation),
      syncEnabled: syncEnabled ?? this.syncEnabled,
      peaks: peaks ?? this.peaks,
      isLoadingPeaks: isLoadingPeaks ?? this.isLoadingPeaks,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPeaks: selectedPeaks ?? this.selectedPeaks,
      selectedMap: selectedMap ?? this.selectedMap,
      showMapOverlay: showMapOverlay ?? this.showMapOverlay,
      mapSuggestions: mapSuggestions ?? this.mapSuggestions,
      mapSearchQuery: mapSearchQuery ?? this.mapSearchQuery,
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

class MapNotifier extends Notifier<MapState> {
  late final PeakRepository _peakRepository;
  late final TasmapRepository _tasmapRepository;
  final OverpassService _overpassService = OverpassService();

  @override
  MapState build() {
    _peakRepository = PeakRepository(objectboxStore);
    _tasmapRepository = ref.read(tasmapRepositoryProvider);
    _loadPosition();
    Future.microtask(() => _loadPeaks());
    return MapState(
      center: _defaultCenter,
      zoom: _defaultZoom,
      basemap: Basemap.tracestrack,
      isFirstLaunch: true,
      selectedLocation: _defaultCenter,
    );
  }

  Future<void> _loadPeaks() async {
    if (_peakRepository.isEmpty()) {
      state = state.copyWith(isLoadingPeaks: true);
      try {
        final peaks = await _overpassService.fetchTasmaniaPeaks();
        if (peaks.isNotEmpty) {
          await _peakRepository.addPeaks(peaks);
        }
        state = state.copyWith(
          peaks: _peakRepository.getAllPeaks(),
          isLoadingPeaks: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoadingPeaks: false,
          error: 'Failed to load peaks: $e',
        );
      }
    } else {
      state = state.copyWith(peaks: _peakRepository.getAllPeaks());
    }
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      final zoom = prefs.getDouble(_zoomKey);

      if (lat != null && lng != null && zoom != null) {
        final location = LatLng(lat, lng);
        state = state.copyWith(
          center: location,
          zoom: zoom,
          isFirstLaunch: false,
          currentMgrs: _convertToMgrs(location),
          selectedLocation: location,
        );
      }
    } catch (e) {
      // Keep default position on error
    }
  }

  String _convertToMgrs(LatLng location) {
    try {
      final mgrsString = mgrs.Mgrs.forward([
        location.longitude,
        location.latitude,
      ], 5);
      if (mgrsString.length >= 10) {
        final firstLine = mgrsString.substring(0, 5);
        final easting = mgrsString.substring(5, 10);
        final northing = mgrsString.substring(10);
        return '$firstLine\n$easting $northing';
      }
      return mgrsString;
    } catch (e) {
      return 'Invalid';
    }
  }

  Future<void> savePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, state.center.latitude);
      await prefs.setDouble(_lngKey, state.center.longitude);
      await prefs.setDouble(_zoomKey, state.zoom);
      state = state.copyWith(isFirstLaunch: false);
    } catch (e) {
      // Continue without saving
    }
  }

  void updatePosition(LatLng center, double zoom) {
    state = state.copyWith(
      center: center,
      zoom: zoom,
      currentMgrs: _convertToMgrs(center),
      cursorMgrs: null,
    );
    savePosition();
  }

  void setBasemap(Basemap basemap) {
    state = state.copyWith(basemap: basemap);
  }

  void centerOnLocation(LatLng location) {
    state = state.copyWith(
      center: location,
      currentMgrs: _convertToMgrs(location),
      gotoMgrs: null,
      selectedLocation: location,
      syncEnabled: true,
    );
    savePosition();
  }

  void setCursorMgrs(LatLng location) {
    state = state.copyWith(cursorMgrs: _convertToMgrs(location));
  }

  void setSelectedLocation(LatLng location) {
    state = state.copyWith(
      cursorMgrs: _convertToMgrs(location),
      selectedLocation: location,
      syncEnabled: false,
    );
  }

  void enableSync() {
    state = state.copyWith(syncEnabled: true);
  }

  void centerOnSelectedLocation() {
    final selected = state.selectedLocation;
    if (selected != null) {
      state = state.copyWith(
        center: selected,
        currentMgrs: _convertToMgrs(selected),
        syncEnabled: true,
      );
      savePosition();
    }
  }

  void clearCursorMgrs() {
    state = state.copyWith(cursorMgrs: null, clearSelectedLocation: true);
  }

  (LatLng?, String?) parseGridReference(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return (null, null);

    // Check for map name only (no digits = no coordinates)
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      final maps = _tasmapRepository.searchMaps(trimmed);
      state = state.copyWith(mapSuggestions: maps, mapSearchQuery: trimmed);

      if (maps.isEmpty) {
        return (null, "No maps found matching '$trimmed'");
      }

      final exactMatch = maps
          .where((m) => m.name.toLowerCase() == trimmed.toLowerCase())
          .toList();

      if (exactMatch.length == 1) {
        final map = exactMatch.first;
        final center = _tasmapRepository.getMapCenter(map);
        if (center != null) {
          state = state.copyWith(
            selectedMap: map,
            showMapOverlay: false,
            mapSuggestions: [],
            mapSearchQuery: '',
          );
          return (center, null);
        }
        return (null, 'Cannot calculate center for ${map.name}');
      }

      return (null, null);
    }

    // Check for map name format: "MapName easting northing" or "MapName easting" or "MapName easting northing" (space separated)
    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      // Determine if last part(s) are coordinates (digits only)
      String potentialName;
      String potentialCoords;

      // Check if last part is digits (coordinate)
      // Also check if second-to-last is digits (for "MapName easting northing")
      if (parts.length >= 3 &&
          RegExp(r'^[0-9]+$').hasMatch(parts[parts.length - 1]) &&
          RegExp(r'^[0-9]+$').hasMatch(parts[parts.length - 2])) {
        // Format: "MapName easting northing" - last two parts are coordinates
        potentialName = parts.sublist(0, parts.length - 2).join(' ');
        potentialCoords = parts[parts.length - 2] + parts[parts.length - 1];
      } else if (RegExp(r'^[0-9]+$').hasMatch(parts.last)) {
        // Format: "MapName coordinates" - last part is coordinates
        potentialName = parts.sublist(0, parts.length - 1).join(' ');
        potentialCoords = parts.last;
      } else {
        potentialName = '';
        potentialCoords = '';
      }

      // Check if we have a map name and valid-looking coordinates (digits only)
      if (potentialName.isNotEmpty &&
          RegExp(r'^[0-9]+$').hasMatch(potentialCoords)) {
        // Check if potentialName is a 2-letter MGRS100k square (skip map lookup)
        final isMgrs100k = RegExp(r'^[A-Za-z]{2}$').hasMatch(potentialName);
        if (!isMgrs100k) {
          // Look up the map by name
          final maps = _tasmapRepository.findByName(potentialName);
          if (maps.isNotEmpty) {
            final map = maps.first;
            final mgrsCodes = map.mgrs100kIdList;
            if (mgrsCodes.isEmpty) {
              return (null, 'Map not found: ${potentialName}');
            }

            final mgrsCode = mgrsCodes.first;
            final digitCount = potentialCoords.length;

            // Validate coordinate count (2=easting only, 3=easting+placeholder, 4=compact, 5=3+2, 6=full)
            if (digitCount < 2 || digitCount > 6) {
              return (null, 'Invalid format. Use: MapName easting northing');
            }

            // Handle different input formats - convert to 5-digit coordinates
            String easting5digit;
            String northing5digit;

            if (digitCount == 2) {
              // Just easting, use northing range (handle wrap-around)
              easting5digit = ((int.tryParse(potentialCoords) ?? 0) * 1000)
                  .toString()
                  .padLeft(5, '0');
              // Use middle of northing range
              final northingMid = _rangeMiddle(
                map.northingMin,
                map.northingMax,
              );
              northing5digit = northingMid.toString().padLeft(5, '0');
            } else if (digitCount == 3) {
              // 3-digit: multiply by 100 to get 5-digit
              easting5digit =
                  ((int.tryParse(potentialCoords.substring(0, 3)) ?? 0) * 100)
                      .toString()
                      .padLeft(5, '0');
              northing5digit = (map.northingMin).toString().padLeft(5, '0');
            } else if (digitCount == 4) {
              // Compact: first 2 easting (multiply by 1000), last 2 northing (multiply by 1000)
              easting5digit =
                  ((int.tryParse(potentialCoords.substring(0, 2)) ?? 0) * 1000)
                      .toString()
                      .padLeft(5, '0');
              northing5digit =
                  ((int.tryParse(potentialCoords.substring(2, 4)) ?? 0) * 1000)
                      .toString()
                      .padLeft(5, '0');
            } else if (digitCount == 5) {
              // 3 easting + 2 northing: first 3 * 100, last 2 * 1000
              easting5digit =
                  ((int.tryParse(potentialCoords.substring(0, 3)) ?? 0) * 100)
                      .toString()
                      .padLeft(5, '0');
              northing5digit =
                  ((int.tryParse(potentialCoords.substring(3, 5)) ?? 0) * 1000)
                      .toString()
                      .padLeft(5, '0');
            } else {
              // Full 6 digits: 3 easting + 3 northing (both * 100)
              easting5digit =
                  ((int.tryParse(potentialCoords.substring(0, 3)) ?? 0) * 100)
                      .toString()
                      .padLeft(5, '0');
              northing5digit =
                  ((int.tryParse(potentialCoords.substring(3, 6)) ?? 0) * 100)
                      .toString()
                      .padLeft(5, '0');
            }

            final paddedEasting = easting5digit;
            final paddedNorthing = northing5digit;

            // Validate range (handle wrap-around)
            final eastingVal = int.tryParse(paddedEasting) ?? 0;
            final northingVal = int.tryParse(paddedNorthing) ?? 0;

            bool validEasting = _inRange(
              eastingVal,
              map.eastingMin,
              map.eastingMax,
            );
            bool validNorthing = _inRange(
              northingVal,
              map.northingMin,
              map.northingMax,
            );

            if (!validEasting) {
              final displayMin = map.eastingMin;
              final displayMax = map.eastingMax;
              final rangeDisplay = map.eastingMin > map.eastingMax
                  ? '$displayMin-99999 OR 0-$displayMax'
                  : '$displayMin-$displayMax';
              return (
                null,
                'Easting $eastingVal out of range for ${map.name}. Valid range: $rangeDisplay',
              );
            }

            if (!validNorthing) {
              final displayMin = map.northingMin;
              final displayMax = map.northingMax;
              final rangeDisplay = map.northingMin > map.northingMax
                  ? '$displayMin-99999 OR 0-$displayMax'
                  : '$displayMin-$displayMax';
              return (
                null,
                'Northing $northingVal out of range for ${map.name}. Valid range: $rangeDisplay',
              );
            }

            final fullMgrs =
                '55G${mgrsCode.substring(0, 2)} $paddedEasting $paddedNorthing';

            try {
              final coords = mgrs.Mgrs.toPoint(fullMgrs);
              final location = LatLng(coords[1], coords[0]);
              final mgrsOutputRaw = mgrs.Mgrs.forward([
                coords[0],
                coords[1],
              ], 5);
              String mgrsOutput;
              if (mgrsOutputRaw.length >= 10) {
                final firstLine = mgrsOutputRaw.substring(0, 5);
                final easting = mgrsOutputRaw.substring(5, 10);
                final northing = mgrsOutputRaw.substring(10);
                mgrsOutput = '$firstLine\n$easting $northing';
              } else {
                mgrsOutput = mgrsOutputRaw;
              }
              state = state.copyWith(gotoMgrs: mgrsOutput);
              return (location, null);
            } catch (e) {
              return (null, 'Invalid grid reference');
            }
          }
        }
      }
    }

    // Check for MGRS 100k square only format: "EN 194507" or "EN194507"
    final mgrs100kMatch = RegExp(
      r'^([A-Z]{2})\s*([0-9]+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mgrs100kMatch != null) {
      final mgrsCode = mgrs100kMatch.group(1)!.toUpperCase();
      final coords = mgrs100kMatch.group(2)!;
      final maps = _tasmapRepository.findByMgrs100kId(mgrsCode);
      if (maps.isEmpty) {
        return (null, 'Unknown MGRS square: $mgrsCode');
      }

      // Handle different coordinate lengths
      final digitCount = coords.length;
      String easting5digit;
      String northing5digit;

      if (digitCount < 2) {
        return (null, null);
      } else if (digitCount == 2 || digitCount == 3) {
        easting5digit = ((int.tryParse(coords) ?? 0) * 1000).toString().padLeft(
          5,
          '0',
        );
        northing5digit = '00000';
      } else if (digitCount == 4) {
        easting5digit = ((int.tryParse(coords.substring(0, 2)) ?? 0) * 1000)
            .toString()
            .padLeft(5, '0');
        northing5digit = ((int.tryParse(coords.substring(2, 4)) ?? 0) * 1000)
            .toString()
            .padLeft(5, '0');
      } else if (digitCount == 5) {
        easting5digit = ((int.tryParse(coords.substring(0, 3)) ?? 0) * 100)
            .toString()
            .padLeft(5, '0');
        northing5digit = ((int.tryParse(coords.substring(3, 5)) ?? 0) * 1000)
            .toString()
            .padLeft(5, '0');
      } else {
        easting5digit = ((int.tryParse(coords.substring(0, 3)) ?? 0) * 100)
            .toString()
            .padLeft(5, '0');
        northing5digit = ((int.tryParse(coords.substring(3, 6)) ?? 0) * 100)
            .toString()
            .padLeft(5, '0');
      }

      final eastingVal = int.tryParse(easting5digit) ?? 0;
      final northingVal = int.tryParse(northing5digit) ?? 0;

      // Find the correct map by checking which one contains the coordinates
      Tasmap50k? correctMap;
      for (final map in maps) {
        if (_inRange(eastingVal, map.eastingMin, map.eastingMax) &&
            _inRange(northingVal, map.northingMin, map.northingMax)) {
          correctMap = map;
          break;
        }
      }

      if (correctMap == null) {
        return (null, 'Coordinates out of range for MGRS square $mgrsCode');
      }

      final fullMgrs = '55G$mgrsCode $easting5digit $northing5digit';

      try {
        final coords = mgrs.Mgrs.toPoint(fullMgrs);
        final location = LatLng(coords[1], coords[0]);
        final mgrsOutputRaw = mgrs.Mgrs.forward([coords[0], coords[1]], 5);
        String mgrsOutput;
        if (mgrsOutputRaw.length >= 10) {
          final firstLine = mgrsOutputRaw.substring(0, 5);
          final easting = mgrsOutputRaw.substring(5, 10);
          final northing = mgrsOutputRaw.substring(10);
          mgrsOutput = '$firstLine\n$easting $northing';
        } else {
          mgrsOutput = mgrsOutputRaw;
        }
        state = state.copyWith(gotoMgrs: mgrsOutput);
        return (location, null);
      } catch (e) {
        return (null, 'Invalid grid reference');
      }
    }

    // Original MGRS format parsing
    final upper = trimmed.toUpperCase();
    final cleaned = upper.replaceAll(' ', '');

    String gridZone = '55G';
    String coords;

    if (RegExp(r'^[0-9]{1,2}[A-Z]\s*[A-Z]{2}\s*[0-9]+$').hasMatch(input) ||
        RegExp(r'^[0-9]{1,2}[A-Z][A-Z][0-9]+$').hasMatch(cleaned)) {
      final parts = input.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        gridZone = parts[0];
        coords = parts.sublist(1).join();
      } else if (parts.length == 2 && parts[1].length >= 4) {
        gridZone = parts[0];
        coords = parts[1];
      } else {
        coords = input.replaceAll(
          RegExp(r'^[0-9]{1,2}[A-Z]\s*', caseSensitive: false),
          '',
        );
      }
    } else {
      coords = cleaned;
    }

    final digitCount = coords.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount != 6 && digitCount != 8) {
      return (null, 'Invalid grid reference');
    }

    final easting = digitCount == 6
        ? coords.substring(0, 3)
        : coords.substring(0, 4);
    final northing = digitCount == 6
        ? coords.substring(3)
        : coords.substring(4);

    final paddedEasting = easting.padLeft(5, '0');
    final paddedNorthing = northing.padLeft(5, '0');

    final fullMgrs = '$gridZone $paddedEasting $paddedNorthing';

    try {
      final coords = mgrs.Mgrs.toPoint(fullMgrs);
      final location = LatLng(coords[1], coords[0]);
      final mgrsOutputRaw = mgrs.Mgrs.forward([coords[0], coords[1]], 5);
      String mgrsOutput;
      if (mgrsOutputRaw.length >= 10) {
        final firstLine = mgrsOutputRaw.substring(0, 5);
        final easting = mgrsOutputRaw.substring(5, 10);
        final northing = mgrsOutputRaw.substring(10);
        mgrsOutput = '$firstLine\n$easting $northing';
      } else {
        mgrsOutput = mgrsOutputRaw;
      }
      state = state.copyWith(gotoMgrs: mgrsOutput);
      return (location, null);
    } catch (e) {
      return (null, 'Invalid grid reference');
    }
  }

  void searchMapSuggestions(String query) {
    if (query.isEmpty) {
      state = state.copyWith(mapSuggestions: [], mapSearchQuery: '');
      return;
    }
    final maps = _tasmapRepository.searchMaps(query);
    state = state.copyWith(mapSuggestions: maps, mapSearchQuery: query);
  }

  void selectMap(Tasmap50k map) {
    final center = _tasmapRepository.getMapCenter(map);
    if (center != null) {
      state = state.copyWith(
        selectedMap: map,
        showMapOverlay: false,
        mapSuggestions: [],
        mapSearchQuery: '',
      );
    }
  }

  void centerOnLocationWithZoom(LatLng location, Tasmap50k map) {
    state = state.copyWith(center: location);
    savePosition();
  }

  void toggleMapOverlay() {
    state = state.copyWith(showMapOverlay: !state.showMapOverlay);
  }

  void clearGotoMgrs() {
    state = state.copyWith(
      gotoMgrs: null,
      mapSuggestions: [],
      mapSearchQuery: '',
    );
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void toggleGotoInput() {
    state = state.copyWith(showGotoInput: !state.showGotoInput);
  }

  void toggleInfoPopup() {
    if (state.showInfoPopup) {
      state = state.copyWith(clearInfoPopup: true);
    } else {
      _showInfoPopup();
    }
  }

  void _showInfoPopup() {
    final mgrs = _convertToMgrs(state.center);
    final map = _findMapByMgrsWithCoordinates(mgrs);
    final (peakName, peakElevation) = _findNearbyPeak(state.center);
    state = state.copyWith(
      showInfoPopup: true,
      infoMapName: map?.name ?? 'Outside Tasmania 50k coverage',
      infoMgrs: mgrs,
      infoPeakName: peakName,
      infoPeakElevation: peakElevation,
    );
  }

  void closeInfoPopup() {
    if (state.showInfoPopup) {
      state = state.copyWith(clearInfoPopup: true);
    }
  }

  (String?, double?) _findNearbyPeak(LatLng location) {
    const searchRadiusMeters = 100.0;
    for (final peak in state.peaks) {
      final distance = _distance.as(
        LengthUnit.Meter,
        location,
        LatLng(peak.latitude, peak.longitude),
      );
      if (distance <= searchRadiusMeters) {
        return (peak.name, peak.elevation);
      }
    }
    return (null, null);
  }

  Tasmap50k? _findMapByMgrsWithCoordinates(String mgrsString) {
    if (mgrsString.length < 10) return null;
    return _tasmapRepository.findByMgrsCodeAndCoordinates(mgrsString);
  }

  void setGotoInputVisible(bool visible) {
    state = state.copyWith(showGotoInput: visible);
  }

  void togglePeakSearch() {
    state = state.copyWith(showPeakSearch: !state.showPeakSearch);
  }

  void setPeakSearchVisible(bool visible) {
    state = state.copyWith(showPeakSearch: visible);
  }

  void searchPeaks(String query) {
    final results = _peakRepository.searchPeaks(query).take(20).toList();
    state = state.copyWith(searchQuery: query, searchResults: results);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: []);
  }

  void selectAllSearchResults() {
    if (state.searchResults.isNotEmpty) {
      final peaks = state.searchResults;
      double minLat = peaks.first.latitude;
      double maxLat = peaks.first.latitude;
      double minLng = peaks.first.longitude;
      double maxLng = peaks.first.longitude;

      for (final peak in peaks) {
        if (peak.latitude < minLat) minLat = peak.latitude;
        if (peak.latitude > maxLat) maxLat = peak.latitude;
        if (peak.longitude < minLng) minLng = peak.longitude;
        if (peak.longitude > maxLng) maxLng = peak.longitude;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

      double zoom = 12;
      if (maxDiff > 0) {
        zoom = 10 - (maxDiff / 10).clamp(0, 3);
      }

      state = state.copyWith(
        selectedPeaks: List.from(peaks),
        showPeakSearch: false,
        searchQuery: '',
        searchResults: [],
        center: LatLng(centerLat, centerLng),
        zoom: zoom,
        currentMgrs: _convertToMgrs(LatLng(centerLat, centerLng)),
      );
    }
  }

  void clearSelectedPeaks() {
    state = state.copyWith(selectedPeaks: []);
  }

  void centerOnPeak(Peak peak) {
    state = state.copyWith(
      center: LatLng(peak.latitude, peak.longitude),
      zoom: 15.0,
      syncEnabled: true,
      selectedPeaks: [peak],
    );
  }

  Future<void> refreshPeaks() async {
    state = state.copyWith(isLoadingPeaks: true);
    try {
      await _peakRepository.clearAll();
      final peaks = await _overpassService.fetchTasmaniaPeaks();
      if (peaks.isNotEmpty) {
        await _peakRepository.addPeaks(peaks);
      }
      state = state.copyWith(
        peaks: _peakRepository.getAllPeaks(),
        isLoadingPeaks: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPeaks: false,
        error: 'Failed to refresh peaks: $e',
      );
    }
  }

  bool _inRange(int value, int min, int max) {
    if (min <= max) {
      return value >= min && value <= max;
    } else {
      return value >= min || value <= max;
    }
  }

  int _rangeMiddle(int min, int max) {
    if (min <= max) {
      return (min + max) ~/ 2;
    } else {
      // Wrap-around range: find middle of combined range
      final range1 = 99999 - min + 1;
      final range2 = max + 1;
      final totalRange = range1 + range2;
      final middle = totalRange ~/ 2;
      if (middle < range1) {
        return min + middle;
      } else {
        return middle - range1;
      }
    }
  }
}
