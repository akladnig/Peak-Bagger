import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

final tasmapRepositoryProvider = Provider<TasmapRepository>((ref) {
  throw UnimplementedError('tasmapRepositoryProvider must be overridden');
});

class TasmapState {
  final int mapCount;
  final bool isLoading;
  final String? error;

  const TasmapState({this.mapCount = 0, this.isLoading = false, this.error});

  TasmapState copyWith({int? mapCount, bool? isLoading, String? error}) {
    return TasmapState(
      mapCount: mapCount ?? this.mapCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final tasmapStateProvider = NotifierProvider<TasmapNotifier, TasmapState>(
  TasmapNotifier.new,
);

class TasmapNotifier extends Notifier<TasmapState> {
  @override
  TasmapState build() {
    return const TasmapState();
  }

  Future<void> loadCount() async {
    try {
      final repo = ref.read(tasmapRepositoryProvider);
      state = state.copyWith(mapCount: repo.mapCount);
    } catch (_) {}
  }

  Future<void> resetAndReimport() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tasmapRepositoryProvider);
      await repo.clearAndReloadFromCsv('assets/tasmap50k.csv');
      state = state.copyWith(mapCount: repo.mapCount);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
