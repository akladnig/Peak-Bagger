import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'test_tasmap_repository.dart';

class TestTasmapMapNotifier extends MapNotifier {
  TestTasmapMapNotifier(this.initialState, this.repository);

  final MapState initialState;
  final TestTasmapRepository repository;

  @override
  MapState build() => initialState;

  @override
  (LatLng?, String?) parseGridReference(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(mapSuggestions: [], mapSearchQuery: '');
      return (null, null);
    }

    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      final maps = repository.searchMaps(trimmed);
      state = state.copyWith(mapSuggestions: maps, mapSearchQuery: trimmed);
      if (maps.isEmpty) {
        return (null, "No maps found matching '$trimmed'");
      }
      return (null, null);
    }

    state = state.copyWith(mapSuggestions: [], mapSearchQuery: trimmed);
    return (null, 'Invalid grid reference');
  }

  @override
  void selectMap(Tasmap50k map) {
    state = state.copyWith(
      selectedMap: map,
      tasmapDisplayMode: TasmapDisplayMode.selectedMap,
      selectedMapFocusSerial: state.selectedMapFocusSerial + 1,
      mapSuggestions: [],
      mapSearchQuery: '',
    );
  }

  @override
  void setGotoInputVisible(bool visible) {
    state = state.copyWith(showGotoInput: visible);
  }

  @override
  void toggleGotoInput() {
    state = state.copyWith(showGotoInput: !state.showGotoInput);
  }
}
