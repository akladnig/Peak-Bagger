import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_layout_provider.dart';

enum TimeChartType {
  stackedColumn('stacked-column'),
  line('line'),
  clusteredColumn('clustered-column');

  const TimeChartType(this.storageId);
  final String storageId;

  static TimeChartType restore(String? value) => values.firstWhere(
    (type) => type.storageId == value,
    orElse: () => stackedColumn,
  );
}

const timeChartTypeStorageKey = 'dashboard_time_chart_type';

abstract interface class TimeChartPreferenceStorage {
  Future<String?> read();
  Future<bool> write(String value);
}

class _SharedTimeChartPreferenceStorage implements TimeChartPreferenceStorage {
  _SharedTimeChartPreferenceStorage(this.ref);
  final Ref ref;

  @override
  Future<String?> read() async {
    final prefs = await ref.read(dashboardPreferencesLoaderProvider)();
    return prefs.getString(timeChartTypeStorageKey);
  }

  @override
  Future<bool> write(String value) async {
    final prefs = await ref.read(dashboardPreferencesLoaderProvider)();
    return prefs.setString(timeChartTypeStorageKey, value);
  }
}

final timeChartPreferenceStorageProvider = Provider<TimeChartPreferenceStorage>(
  _SharedTimeChartPreferenceStorage.new,
);

typedef TimeChartPreferenceDiagnostics =
    void Function(String operation, Object error, StackTrace stackTrace);

final timeChartPreferenceDiagnosticsProvider =
    Provider<TimeChartPreferenceDiagnostics>((ref) {
      return (operation, error, stackTrace) => developer.log(
        'Time chart preference $operation ($timeChartTypeStorageKey)',
        name: 'TimeChartPreference',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
    });

enum TimeChartPreferenceOperation { read, save }

class TimeChartPreferenceWarning {
  const TimeChartPreferenceWarning({
    required this.id,
    required this.operation,
    this.presented = false,
  });

  final int id;
  final TimeChartPreferenceOperation operation;
  final bool presented;

  String get message => operation == TimeChartPreferenceOperation.read
      ? 'Couldn’t load Time chart preference.'
      : 'Couldn’t save Time chart preference.';
}

class TimeChartPreferenceState {
  const TimeChartPreferenceState({
    this.selected = TimeChartType.stackedColumn,
    this.readOutcome = const AsyncLoading(),
    this.saveOutcome,
    this.isHydrating = true,
    this.warning,
    this.visibleWarningId,
  });

  final TimeChartType selected;
  final AsyncValue<void> readOutcome;
  final AsyncValue<void>? saveOutcome;
  final bool isHydrating;
  final TimeChartPreferenceWarning? warning;
  final int? visibleWarningId;

  TimeChartPreferenceState copyWith({
    TimeChartType? selected,
    AsyncValue<void>? readOutcome,
    AsyncValue<void>? saveOutcome,
    bool? isHydrating,
    TimeChartPreferenceWarning? warning,
    bool clearWarning = false,
    int? visibleWarningId,
    bool clearVisibleWarning = false,
  }) => TimeChartPreferenceState(
    selected: selected ?? this.selected,
    readOutcome: readOutcome ?? this.readOutcome,
    saveOutcome: saveOutcome ?? this.saveOutcome,
    isHydrating: isHydrating ?? this.isHydrating,
    warning: clearWarning ? null : warning ?? this.warning,
    visibleWarningId: clearVisibleWarning
        ? null
        : visibleWarningId ?? this.visibleWarningId,
  );
}

/// App-owned preference work survives lazy-card and Dashboard disposal.
final timeChartTypeProvider =
    NotifierProvider<TimeChartTypeController, TimeChartPreferenceState>(
      TimeChartTypeController.new,
    );

class TimeChartTypeController extends Notifier<TimeChartPreferenceState> {
  Future<void>? _readFuture;
  Future<void>? _saveFuture;
  int _selectionRevision = 0;
  int _warningSequence = 0;

  @override
  TimeChartPreferenceState build() {
    _readFuture = Future.microtask(_read);
    return const TimeChartPreferenceState();
  }

  Future<void> load() => _readFuture ?? Future.value();

  Future<void> _read() async {
    if (!ref.mounted) return;
    final storage = ref.read(timeChartPreferenceStorageProvider);
    final diagnostics = ref.read(timeChartPreferenceDiagnosticsProvider);
    try {
      final value = await storage.read();
      if (!ref.mounted) return;
      state = state.copyWith(
        selected: _selectionRevision == 0 ? TimeChartType.restore(value) : null,
        readOutcome: const AsyncData(null),
        isHydrating: false,
        clearWarning:
            state.warning?.operation == TimeChartPreferenceOperation.read,
      );
    } catch (error, stackTrace) {
      diagnostics('read', error, stackTrace);
      if (!ref.mounted) return;
      state = state.copyWith(
        readOutcome: AsyncError(error, stackTrace),
        isHydrating: false,
        warning: _selectionRevision == 0
            ? _warning(TimeChartPreferenceOperation.read)
            : null,
      );
    }
  }

  Future<void> select(TimeChartType type) {
    if (type == state.selected) return Future.value();
    _selectionRevision++;
    state = state.copyWith(
      selected: type,
      isHydrating: false,
      clearWarning: true,
    );
    return _save();
  }

  Future<void> retryWarning(int id) {
    final warning = state.warning;
    if (warning == null || warning.id != id) return Future.value();
    if (warning.operation == TimeChartPreferenceOperation.save) return _save();
    if (state.readOutcome.isLoading) return _readFuture!;
    final completion = Completer<void>();
    _readFuture = completion.future;
    state = state.copyWith(readOutcome: const AsyncLoading());
    unawaited(_read().whenComplete(completion.complete));
    return completion.future;
  }

  /// Shared by the visible pointer action and Work Item 06's card shortcut.
  Future<void> retryVisibleWarning() {
    final id = state.visibleWarningId;
    return id == null ? Future.value() : retryWarning(id);
  }

  void markWarningPresented(int id) {
    final warning = state.warning;
    if (warning == null || warning.id != id) return;
    state = state.copyWith(
      warning: TimeChartPreferenceWarning(
        id: id,
        operation: warning.operation,
        presented: true,
      ),
      visibleWarningId: id,
    );
  }

  void dismissWarning(int id) {
    if (!ref.mounted) return;
    if (state.visibleWarningId == id) {
      state = state.copyWith(clearVisibleWarning: true);
    }
  }

  TimeChartPreferenceWarning _warning(TimeChartPreferenceOperation operation) =>
      TimeChartPreferenceWarning(id: ++_warningSequence, operation: operation);

  Future<void> _save() {
    if (_saveFuture != null) return _saveFuture!;
    final completion = Completer<void>();
    _saveFuture = completion.future;
    // Install the shared future before synchronous listeners can request Retry.
    state = state.copyWith(saveOutcome: const AsyncLoading());
    unawaited(
      _drainSaves().whenComplete(() {
        completion.complete();
      }),
    );
    return completion.future;
  }

  Future<void> _drainSaves() async {
    final storage = ref.read(timeChartPreferenceStorageProvider);
    final diagnostics = ref.read(timeChartPreferenceDiagnosticsProvider);
    while (ref.mounted) {
      final revision = _selectionRevision;
      final type = state.selected;
      Object? failure;
      StackTrace? failureStack;
      try {
        if (!await storage.write(type.storageId)) {
          throw StateError('Preference write reported false');
        }
      } catch (error, stackTrace) {
        failure = error;
        failureStack = stackTrace;
        diagnostics(
          'save ${type.storageId} revision $revision',
          error,
          stackTrace,
        );
      }
      if (!ref.mounted) return;
      // Finish the older physical write before dispatching the latest choice.
      // Neither its failure nor its success is the latest persistence outcome.
      if (revision != _selectionRevision) continue;
      _saveFuture = null;
      state = state.copyWith(
        saveOutcome: failure == null
            ? const AsyncData(null)
            : AsyncError(failure, failureStack!),
        warning: failure == null
            ? null
            : _warning(TimeChartPreferenceOperation.save),
        clearWarning: failure == null,
      );
      return;
    }
    _saveFuture = null;
  }
}
