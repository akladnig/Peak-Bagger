import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;

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
  final LatLng? selectedLocation;
  final bool syncEnabled;

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
    this.selectedLocation,
    this.syncEnabled = true,
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
    LatLng? selectedLocation,
    bool clearSelectedLocation = false,
    bool? syncEnabled,
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
      selectedLocation: clearSelectedLocation
          ? null
          : (selectedLocation ?? this.selectedLocation),
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() {
    _loadPosition();
    return MapState(
      center: _defaultCenter,
      zoom: _defaultZoom,
      basemap: Basemap.tracestrack,
      isFirstLaunch: true,
      selectedLocation: _defaultCenter,
    );
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
    final cleaned = input.trim().toUpperCase().replaceAll(' ', '');

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

  void clearGotoMgrs() {
    state = state.copyWith(gotoMgrs: null);
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

  void setGotoInputVisible(bool visible) {
    state = state.copyWith(showGotoInput: visible);
  }
}
