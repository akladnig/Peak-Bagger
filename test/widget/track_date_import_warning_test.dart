import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/widgets/background_jobs_panel.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';

import '../harness/track_date_fixtures.dart';
import '../harness/track_date_import_harness.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);
  for (final brightness in Brightness.values) {
    testWidgets(
      'unknown-date import warning is visible in $brightness job details',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final harness = await tester.runAsync(TrackDateImportHarness.create);
        addTearDown(harness!.close);
        final file = harness.file(
          'unknown-date',
          datedGpx(
            time: null,
            extraPoints:
                '<trkpt lat="-42.8821" lon="147.3272"><ele>100</ele></trkpt>',
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: ProviderScope(
              overrides: [
                gpxFilePickerProvider.overrideWithValue(_Picker(file)),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: Scaffold(
                  body: Stack(
                    fit: StackFit.expand,
                    children: [
                      const MapActionRail(),
                      Consumer(
                        builder: (context, ref, _) {
                          final jobs = ref.watch(backgroundJobsProvider);
                          final notifier = ref.read(
                            backgroundJobsProvider.notifier,
                          );
                          if (jobs.visibleJobs.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            left: 16,
                            top: 16,
                            bottom: 16,
                            child: BackgroundJobsPanel(
                              jobs: jobs.visibleJobs,
                              onClose: () {},
                              onToggleExpanded: notifier.toggleJobExpanded,
                              onDismissJob: notifier.dismissJob,
                              onClearFinishedJobs: notifier.clearFinishedJobs,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('import-tracks-fab')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('gpx-import-select-files')));
        for (
          var i = 0;
          i < 100 &&
              find
                  .byKey(const Key('gpx-import-name-field-0'))
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(
          find.byKey(const Key('gpx-import-name-field-0')),
          findsOneWidget,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('gpx-import-button')));
          for (
            var i = 0;
            i < 100 &&
                harness.container
                    .read(backgroundJobsProvider)
                    .visibleJobs
                    .any((job) => !job.isFinished);
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        });
        await tester.pumpAndSettle();
        final job = harness.container
            .read(backgroundJobsProvider)
            .visibleJobs
            .single;
        expect(job.isFinished, isTrue);
        expect(job.detailLines.join(' '), contains('unknown walk date'));
        expect(
          harness.container.read(mapProvider).hasTrackRecoveryIssue,
          isFalse,
        );
        expect(harness.tracks.getAllTracks().single.trackDate, isNull);
        // Open the actual job details using its stable UI selector.
        if (!job.isExpanded) {
          await tester.tap(find.byKey(Key('background-jobs-expand-${job.id}')));
          await tester.pumpAndSettle();
        }
        expect(find.textContaining('unknown walk date'), findsOneWidget);
        expect(
          find.textContaining('first recorded point has no timestamp'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

class _Picker implements GpxFilePicker {
  _Picker(this.file);
  final File file;
  @override
  Future<List<String>?> pickGpxFiles() async => [file.path];
  @override
  Future<String> resolveImportRoot() async => file.parent.path;
}
