import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/track_date_migration_provider.dart';
import 'package:peak_bagger/services/track_date_migration_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/track_date_migration_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/track_date_fixtures.dart';
import '../harness/track_date_migration_fixture.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);

  for (final dark in [false, true]) {
    testWidgets(
      'app-root barrier shows retry then durable counts/skips in ${dark ? 'dark' : 'light'} theme before routed writers mount',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final fixture = (await tester.runAsync(
          TrackDateMigrationFixture.create,
        ))!;
        addTearDown(fixture.dispose);
        var fail = true;
        final service = fixture.service(
          repository: ObjectBoxTrackDateMigrationRepository(
            fixture.store,
            beforeWriteForTest: (stage) {
              if (fail && stage == TrackDateMigrationWriteStage.completion) {
                throw StateError('Fixture disk failure');
              }
            },
          ),
        );
        addTearDown(service.dispose);
        final container = ProviderContainer(
          overrides: [
            trackDateMigrationServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        var mountedWriters = 0;
        final child = Builder(
          builder: (_) {
            mountedWriters++;
            expect(fixture.metadata!.completedVersion, 1);
            return const Text('Routed content');
          },
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? MyTheme.dark : MyTheme.light,
              home: TrackDateMigrationHost(child: child),
            ),
          ),
        );
        final attempt = container
            .read(trackDateMigrationProvider.notifier)
            .ensureCurrent();
        await tester.pumpAndSettle();
        expect(await attempt, isFalse);
        expect(mountedWriters, 0);
        expect(
          find.byKey(const Key('track-date-migration-failure')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('track-date-migration-continue')),
          findsNothing,
        );
        expect(fixture.metadata, isNull);
        fail = false;
        // Standard keyboard traversal/activation uses the same retry action.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          container.read(trackDateMigrationProvider).status,
          TrackDateMigrationStatus.completed,
        );
        expect(find.text('Updated: 2'), findsOneWidget);
        expect(find.text('Unchanged: 1'), findsOneWidget);
        expect(find.text('Skipped: 2'), findsOneWidget);
        expect(
          find.byKey(const Key('track-date-migration-skip-10')),
          findsOneWidget,
        );
        expect(find.textContaining('Missing time (Track 10)'), findsOneWidget);
        expect(mountedWriters, 0);
        await tester.tap(
          find.byKey(const Key('track-date-migration-continue')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Routed content'), findsOneWidget);
        expect(mountedWriters, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'real App startup gates the router; completed next launch mounts immediately without rescanning',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fixture = (await tester.runAsync(
        TrackDateMigrationFixture.create,
      ))!;
      addTearDown(fixture.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Original route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [
          trackDateMigrationRepositoryProvider.overrideWithValue(
            ObjectBoxTrackDateMigrationRepository(fixture.store),
          ),
          mappingStoreBootstrapProvider.overrideWith((ref) async {}),
          routeGraphBootstrapProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: App(router: router),
        ),
      );
      expect(find.text('Original route'), findsNothing);
      expect(
        find.byKey(const Key('track-date-migration-progress')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(fixture.metadata!.completedVersion, 1);
      await tester.tap(find.byKey(const Key('track-date-migration-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Original route'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      final service = fixture.service(
        derivation: () => throw StateError('Completed database must not scan'),
      );
      addTearDown(service.dispose);
      final next = ProviderContainer(
        overrides: [
          trackDateMigrationServiceProvider.overrideWithValue(service),
          mappingStoreBootstrapProvider.overrideWith((ref) async {}),
          routeGraphBootstrapProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(next.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: next,
          child: App(router: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Original route'), findsOneWidget);
      expect(
        find.byKey(const Key('track-date-migration-status')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'leaving status UI does not cancel app-owned preparation; scaled short view keeps controls and skipped reasons reachable',
    (tester) async {
      final fixture = (await tester.runAsync(
        TrackDateMigrationFixture.create,
      ))!;
      addTearDown(fixture.dispose);
      final release = Completer<void>();
      final service = fixture.service(yieldToUi: () => release.future);
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          trackDateMigrationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1200, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(Widget body) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: body,
          ),
        ),
      );
      await tester.pumpWidget(
        app(const TrackDateMigrationHost(child: Text('Content'))),
      );
      final attempt = container
          .read(trackDateMigrationProvider.notifier)
          .ensureCurrent();
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('track-date-migration-progress')),
        findsOneWidget,
      );
      await tester.pumpWidget(app(const Text('Another surface')));
      release.complete();
      await tester.pumpAndSettle();
      expect(await attempt, isTrue);
      expect(fixture.metadata!.completedVersion, 1);
      await tester.pumpWidget(
        app(const TrackDateMigrationHost(child: Text('Content'))),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('track-date-migration-skip-11')),
        150,
      );
      expect(find.textContaining('Unknown import (Track 11)'), findsOneWidget);
      expect(
        find.byKey(const Key('track-date-migration-continue')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('track-date-migration-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
