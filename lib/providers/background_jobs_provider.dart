import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _interruptedBackgroundJobKey = 'background_jobs_interrupted_job_v1';

final bootstrappedBackgroundJobsPreferencesProvider =
    Provider<SharedPreferences?>((ref) => null);

final backgroundJobsPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

final backgroundJobsProvider =
    NotifierProvider<BackgroundJobsNotifier, BackgroundJobsState>(
      BackgroundJobsNotifier.new,
    );

enum BackgroundJobKind {
  importGpxFiles,
  importPeakList,
  exportPeakData,
  exportPeakLists,
}

enum BackgroundJobStatus { running, completed, failed, cancelled }

@immutable
class BackgroundJobProgress {
  const BackgroundJobProgress({
    required this.label,
    required this.statusText,
    this.secondaryStatusText,
    this.currentFileName,
    this.percent,
  }) : assert(percent == null || (percent >= 0 && percent <= 1));

  final String label;
  final String statusText;
  final String? secondaryStatusText;
  final String? currentFileName;
  final double? percent;

  BackgroundJobProgress copyWith({
    String? label,
    String? statusText,
    String? secondaryStatusText,
    bool clearSecondaryStatusText = false,
    String? currentFileName,
    bool clearCurrentFileName = false,
    double? percent,
    bool clearPercent = false,
  }) {
    return BackgroundJobProgress(
      label: label ?? this.label,
      statusText: statusText ?? this.statusText,
      secondaryStatusText: clearSecondaryStatusText
          ? null
          : (secondaryStatusText ?? this.secondaryStatusText),
      currentFileName: clearCurrentFileName
          ? null
          : (currentFileName ?? this.currentFileName),
      percent: clearPercent ? null : (percent ?? this.percent),
    );
  }
}

@immutable
class BackgroundJob {
  BackgroundJob({
    required this.id,
    required this.kind,
    required this.label,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.progress,
    this.summary,
    List<String> detailLines = const <String>[],
    this.hasWarnings = false,
    this.isExpanded = false,
  }) : detailLines = List<String>.unmodifiable(detailLines);

  final String id;
  final BackgroundJobKind kind;
  final String label;
  final BackgroundJobStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final BackgroundJobProgress? progress;
  final String? summary;
  final List<String> detailLines;
  final bool hasWarnings;
  final bool isExpanded;

  bool get isFinished => status != BackgroundJobStatus.running;

  String get statusLabel {
    return switch (status) {
      BackgroundJobStatus.running => 'Running',
      BackgroundJobStatus.completed => 'Completed',
      BackgroundJobStatus.failed => 'Failed',
      BackgroundJobStatus.cancelled => 'Cancelled',
    };
  }

  BackgroundJob copyWith({
    String? id,
    BackgroundJobKind? kind,
    String? label,
    BackgroundJobStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    BackgroundJobProgress? progress,
    bool clearProgress = false,
    String? summary,
    bool clearSummary = false,
    List<String>? detailLines,
    bool? hasWarnings,
    bool? isExpanded,
  }) {
    return BackgroundJob(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
      progress: clearProgress ? null : (progress ?? this.progress),
      summary: clearSummary ? null : (summary ?? this.summary),
      detailLines: detailLines ?? this.detailLines,
      hasWarnings: hasWarnings ?? this.hasWarnings,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

@immutable
class BackgroundJobsState {
  const BackgroundJobsState({
    this.runningJob,
    this.finishedJobs = const <BackgroundJob>[],
    this.isPanelOpen = false,
  });

  final BackgroundJob? runningJob;
  final List<BackgroundJob> finishedJobs;
  final bool isPanelOpen;

  bool get hasJobs => runningJob != null || finishedJobs.isNotEmpty;

  List<BackgroundJob> get visibleJobs => <BackgroundJob>[
    ...?switch (runningJob) {
      null => null,
      final runningJob => <BackgroundJob>[runningJob],
    },
    ...finishedJobs,
  ];

  BackgroundJobsState copyWith({
    BackgroundJob? runningJob,
    bool clearRunningJob = false,
    List<BackgroundJob>? finishedJobs,
    bool? isPanelOpen,
  }) {
    return BackgroundJobsState(
      runningJob: clearRunningJob ? null : (runningJob ?? this.runningJob),
      finishedJobs: finishedJobs ?? this.finishedJobs,
      isPanelOpen: isPanelOpen ?? this.isPanelOpen,
    );
  }
}

@immutable
class BackgroundJobsSnackBarEvent {
  const BackgroundJobsSnackBarEvent({
    required this.message,
    this.actions = const <BackgroundJobsSnackBarAction>[],
  });

  final String message;
  final List<BackgroundJobsSnackBarAction> actions;
}

@immutable
class BackgroundJobsSnackBarAction {
  const BackgroundJobsSnackBarAction({
    required this.label,
    required this.onPressed,
    this.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Key? key;
}

@immutable
class BackgroundJobStartResult {
  const BackgroundJobStartResult._({this.job, this.blockedMessage});

  const BackgroundJobStartResult.started(BackgroundJob job) : this._(job: job);

  const BackgroundJobStartResult.blocked(String blockedMessage)
    : this._(blockedMessage: blockedMessage);

  final BackgroundJob? job;
  final String? blockedMessage;

  bool get isStarted => job != null;
}

class BackgroundJobsNotifier extends Notifier<BackgroundJobsState> {
  var _nextJobId = 0;
  var _recoveryHydrated = false;
  Future<void> _prefsWriteChain = Future<void>.value();
  BackgroundJobsSnackBarEvent? _pendingSnackBarEvent;

  @override
  BackgroundJobsState build() {
    final bootstrappedPrefs = ref.watch(
      bootstrappedBackgroundJobsPreferencesProvider,
    );
    if (bootstrappedPrefs != null) {
      _recoveryHydrated = true;
      final recoveredJob = _restoreInterruptedJob(bootstrappedPrefs);
      return BackgroundJobsState(
        finishedJobs: recoveredJob == null
            ? const <BackgroundJob>[]
            : <BackgroundJob>[recoveredJob],
      );
    }

    if (!_recoveryHydrated) {
      _recoveryHydrated = true;
      unawaited(_hydrateRecoveryState());
    }

    return const BackgroundJobsState();
  }

  BackgroundJobStartResult startJob({
    required BackgroundJobKind kind,
    required String label,
    BackgroundJobProgress? progress,
    String? summary,
    List<String> detailLines = const <String>[],
    bool hasWarnings = false,
  }) {
    final runningJob = state.runningJob;
    if (runningJob != null) {
      final blockedMessage = '${runningJob.label} is already running.';
      _pendingSnackBarEvent = BackgroundJobsSnackBarEvent(
        message: blockedMessage,
        actions: [
          BackgroundJobsSnackBarAction(
            key: const Key('background-jobs-snackbar-open-jobs'),
            label: 'Open Jobs',
            onPressed: openPanel,
          ),
        ],
      );
      return BackgroundJobStartResult.blocked(blockedMessage);
    }

    final job = BackgroundJob(
      id: 'background-job-${++_nextJobId}',
      kind: kind,
      label: label,
      status: BackgroundJobStatus.running,
      startedAt: DateTime.now(),
      progress: progress,
      summary: summary,
      detailLines: detailLines,
      hasWarnings: hasWarnings,
    );
    state = state.copyWith(runningJob: job);
    _queuePrefsWrite((prefs) async {
      await prefs.setString(
        _interruptedBackgroundJobKey,
        jsonEncode({
          'kind': job.kind.name,
          'label': job.label,
          'startedAt': job.startedAt.toIso8601String(),
        }),
      );
    });
    return BackgroundJobStartResult.started(job);
  }

  void updateRunningJob({
    required String jobId,
    BackgroundJobProgress? progress,
    String? summary,
    List<String>? detailLines,
    bool? hasWarnings,
  }) {
    final runningJob = state.runningJob;
    if (runningJob == null || runningJob.id != jobId) {
      return;
    }

    state = state.copyWith(
      runningJob: runningJob.copyWith(
        progress: progress ?? runningJob.progress,
        summary: summary ?? runningJob.summary,
        detailLines: detailLines ?? runningJob.detailLines,
        hasWarnings: hasWarnings ?? runningJob.hasWarnings,
      ),
    );
  }

  void completeRunningJob({
    required String jobId,
    String? summary,
    List<String> detailLines = const <String>[],
    bool hasWarnings = false,
  }) {
    _finishRunningJob(
      jobId: jobId,
      status: BackgroundJobStatus.completed,
      summary: summary,
      detailLines: detailLines,
      hasWarnings: hasWarnings,
    );
  }

  void failRunningJob({
    required String jobId,
    required String summary,
    List<String> detailLines = const <String>[],
  }) {
    _finishRunningJob(
      jobId: jobId,
      status: BackgroundJobStatus.failed,
      summary: summary,
      detailLines: detailLines,
    );
  }

  void dismissJob(String jobId) {
    final nextFinishedJobs = state.finishedJobs
        .where((job) => job.id != jobId)
        .toList(growable: false);
    if (nextFinishedJobs.length == state.finishedJobs.length) {
      return;
    }

    state = _withPanelVisibility(
      state.copyWith(finishedJobs: nextFinishedJobs),
    );
  }

  void clearFinishedJobs() {
    if (state.finishedJobs.isEmpty) {
      return;
    }

    state = _withPanelVisibility(state.copyWith(finishedJobs: const []));
  }

  void toggleJobExpanded(String jobId) {
    state = state.copyWith(
      finishedJobs: [
        for (final job in state.finishedJobs)
          if (job.id == jobId)
            job.copyWith(isExpanded: !job.isExpanded)
          else
            job,
      ],
      runningJob: state.runningJob?.id == jobId
          ? state.runningJob?.copyWith(
              isExpanded: !state.runningJob!.isExpanded,
            )
          : state.runningJob,
    );
  }

  void openPanel() {
    if (!state.hasJobs || state.isPanelOpen) {
      return;
    }
    state = state.copyWith(isPanelOpen: true);
  }

  void closePanel() {
    if (!state.isPanelOpen) {
      return;
    }
    state = state.copyWith(isPanelOpen: false);
  }

  void togglePanel() {
    if (state.isPanelOpen) {
      closePanel();
      return;
    }
    openPanel();
  }

  BackgroundJobsSnackBarEvent? consumeSnackBarEvent() {
    final event = _pendingSnackBarEvent;
    _pendingSnackBarEvent = null;
    return event;
  }

  void queueSnackBar({
    required String message,
    List<BackgroundJobsSnackBarAction> actions =
        const <BackgroundJobsSnackBarAction>[],
  }) {
    _pendingSnackBarEvent = BackgroundJobsSnackBarEvent(
      message: message,
      actions: actions,
    );
  }

  void _finishRunningJob({
    required String jobId,
    required BackgroundJobStatus status,
    String? summary,
    List<String> detailLines = const <String>[],
    bool hasWarnings = false,
  }) {
    final runningJob = state.runningJob;
    if (runningJob == null || runningJob.id != jobId) {
      return;
    }

    final finishedJob = runningJob.copyWith(
      status: status,
      summary: summary ?? runningJob.summary,
      detailLines: detailLines,
      hasWarnings: hasWarnings,
      finishedAt: DateTime.now(),
    );
    state = _withPanelVisibility(
      state.copyWith(
        clearRunningJob: true,
        finishedJobs: <BackgroundJob>[finishedJob, ...state.finishedJobs],
      ),
    );
    _queuePrefsWrite((prefs) => prefs.remove(_interruptedBackgroundJobKey));
  }

  BackgroundJobsState _withPanelVisibility(BackgroundJobsState nextState) {
    if (nextState.hasJobs) {
      return nextState;
    }
    return nextState.copyWith(isPanelOpen: false);
  }

  Future<void> _hydrateRecoveryState() async {
    try {
      final prefs = await _loadPreferences();
      final recoveredJob = _restoreInterruptedJob(prefs);
      if (!ref.mounted || recoveredJob == null) {
        return;
      }
      state = state.copyWith(
        finishedJobs: <BackgroundJob>[recoveredJob, ...state.finishedJobs],
      );
    } catch (_) {
      // Continue with empty in-memory state on read failure.
    }
  }

  BackgroundJob? _restoreInterruptedJob(SharedPreferences prefs) {
    final payload = prefs.getString(_interruptedBackgroundJobKey);
    if (payload == null) {
      return null;
    }

    final recovered = _decodeInterruptedJob(payload);
    unawaited(prefs.remove(_interruptedBackgroundJobKey));
    if (recovered == null) {
      return null;
    }

    _pendingSnackBarEvent = BackgroundJobsSnackBarEvent(
      message: _recoveredSnackbarMessage(recovered.kind),
      actions: [
        BackgroundJobsSnackBarAction(
          key: const Key('background-jobs-snackbar-open-jobs'),
          label: 'Open Jobs',
          onPressed: openPanel,
        ),
      ],
    );

    return BackgroundJob(
      id: 'background-job-recovered-${++_nextJobId}',
      kind: recovered.kind,
      label: recovered.label,
      status: BackgroundJobStatus.cancelled,
      startedAt: recovered.startedAt,
      finishedAt: DateTime.now(),
      summary: 'Cancelled when app was closed',
    );
  }

  ({BackgroundJobKind kind, String label, DateTime startedAt})?
  _decodeInterruptedJob(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final kindName = decoded['kind'];
      final label = decoded['label'];
      final startedAtText = decoded['startedAt'];
      if (kindName is! String || label is! String || startedAtText is! String) {
        return null;
      }

      final kind = BackgroundJobKind.values.firstWhere(
        (value) => value.name == kindName,
      );
      final startedAt = DateTime.tryParse(startedAtText);
      if (startedAt == null) {
        return null;
      }

      return (kind: kind, label: label, startedAt: startedAt);
    } catch (_) {
      return null;
    }
  }

  String _recoveredSnackbarMessage(BackgroundJobKind kind) {
    return switch (kind) {
      BackgroundJobKind.importGpxFiles || BackgroundJobKind.importPeakList =>
        'Import cancelled when app was closed',
      BackgroundJobKind.exportPeakData || BackgroundJobKind.exportPeakLists =>
        'Export cancelled when app was closed',
    };
  }

  Future<SharedPreferences> _loadPreferences() async {
    final bootstrappedPrefs = ref.read(
      bootstrappedBackgroundJobsPreferencesProvider,
    );
    if (bootstrappedPrefs != null) {
      return bootstrappedPrefs;
    }

    return ref.read(backgroundJobsPreferencesLoaderProvider)();
  }

  void _queuePrefsWrite(Future<void> Function(SharedPreferences prefs) write) {
    _prefsWriteChain = _prefsWriteChain.then((_) async {
      try {
        final prefs = await _loadPreferences();
        await write(prefs);
      } catch (_) {
        // Continue with in-memory state on persistence failure.
      }
    });
  }
}
