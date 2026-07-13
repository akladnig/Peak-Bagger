import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'retains finished jobs and supports dismiss and clear finished',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(backgroundJobsProvider.notifier);
      final started = notifier.startJob(
        kind: BackgroundJobKind.importPeakList,
        label: 'Import Peak List',
      );

      expect(started.isStarted, isTrue);
      expect(
        container.read(backgroundJobsProvider).runningJob?.label,
        'Import Peak List',
      );

      notifier.completeRunningJob(
        jobId: started.job!.id,
        summary: 'Imported 12 rows',
      );

      final completedState = container.read(backgroundJobsProvider);
      expect(completedState.runningJob, isNull);
      expect(completedState.finishedJobs, hasLength(1));
      expect(
        completedState.finishedJobs.single.status,
        BackgroundJobStatus.completed,
      );

      notifier.dismissJob(completedState.finishedJobs.single.id);
      expect(container.read(backgroundJobsProvider).hasJobs, isFalse);

      final secondStarted = notifier.startJob(
        kind: BackgroundJobKind.exportPeakData,
        label: 'Export Peak Data',
      );
      notifier.failRunningJob(
        jobId: secondStarted.job!.id,
        summary: 'Export failed',
      );
      notifier.startJob(
        kind: BackgroundJobKind.exportPeakLists,
        label: 'Export Peak Lists',
      );
      notifier.completeRunningJob(
        jobId: container.read(backgroundJobsProvider).runningJob!.id,
        summary: 'Exported 4 lists',
      );

      expect(container.read(backgroundJobsProvider).finishedJobs, hasLength(2));

      notifier.clearFinishedJobs();
      expect(container.read(backgroundJobsProvider).hasJobs, isFalse);
    },
  );

  test('blocks a second running job and exposes a snackbar event', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(backgroundJobsProvider.notifier);
    notifier.startJob(
      kind: BackgroundJobKind.importGpxFiles,
      label: 'Import GPX File(s)',
    );

    final blocked = notifier.startJob(
      kind: BackgroundJobKind.exportPeakData,
      label: 'Export Peak Data',
    );

    expect(blocked.isStarted, isFalse);
    expect(blocked.blockedMessage, 'Import GPX File(s) is already running.');

    final event = notifier.consumeSnackBarEvent();
    expect(event?.message, 'Import GPX File(s) is already running.');
    expect(notifier.consumeSnackBarEvent(), isNull);
  });

  test('restores one cancelled job and clears recovery metadata', () async {
    SharedPreferences.setMockInitialValues({
      'background_jobs_interrupted_job_v1':
          '{"kind":"importPeakList","label":"Import Peak List","startedAt":"2026-07-12T08:30:00.000"}',
    });
    final prefs = await SharedPreferences.getInstance();

    final firstContainer = ProviderContainer(
      overrides: [
        bootstrappedBackgroundJobsPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(firstContainer.dispose);

    final firstState = firstContainer.read(backgroundJobsProvider);
    expect(firstState.runningJob, isNull);
    expect(firstState.finishedJobs, hasLength(1));
    expect(
      firstState.finishedJobs.single.status,
      BackgroundJobStatus.cancelled,
    );
    expect(
      firstContainer
          .read(backgroundJobsProvider.notifier)
          .consumeSnackBarEvent()
          ?.message,
      'Import cancelled when app was closed',
    );

    await _drainAsync();
    expect(prefs.getString('background_jobs_interrupted_job_v1'), isNull);

    final secondContainer = ProviderContainer(
      overrides: [
        bootstrappedBackgroundJobsPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(secondContainer.dispose);

    expect(secondContainer.read(backgroundJobsProvider).hasJobs, isFalse);
    expect(
      secondContainer
          .read(backgroundJobsProvider.notifier)
          .consumeSnackBarEvent(),
      isNull,
    );
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
