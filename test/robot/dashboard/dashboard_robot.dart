import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';

class DashboardRobot {
  DashboardRobot(this.tester);

  final WidgetTester tester;
  late ProviderContainer container;

  Finder get homeButton => find.byKey(const Key('app-bar-home'));
  Finder get board => find.byKey(const Key('dashboard-board'));
  Finder card(String id) => find.byKey(Key('dashboard-card-$id'));
  Finder dragHandle(String id) =>
      find.byKey(Key('dashboard-card-$id-drag-handle'));
  Finder summaryControl(String id, String key) =>
      find.descendant(of: card(id), matching: find.byKey(Key(key)));
  Finder get yearToDateCard =>
      find.byKey(const Key('dashboard-card-year-to-date'));
  Finder get yearToDateLoadingState =>
      find.byKey(const Key('year-to-date-loading-state'));
  Finder get yearToDateTitle => find.byKey(const Key('year-to-date-title'));
  Finder yearToDateControl(String key) =>
      find.descendant(of: yearToDateCard, matching: find.byKey(Key(key)));
  Finder get latestWalkCard => find.byKey(const Key('latest-walk-card'));
  Finder get latestWalkEmptyState =>
      find.byKey(const Key('latest-walk-empty-state'));
  Finder get latestWalkPrevTrack =>
      find.byKey(const Key('latest-walk-prev-track'));
  Finder get latestWalkNextTrack =>
      find.byKey(const Key('latest-walk-next-track'));
  Finder get latestWalkTitle =>
      find.byKey(const Key('latest-walk-track-title'));
  Finder get myListsCard => find.byKey(const Key('dashboard-card-my-lists'));
  Finder get myListsEmptyState => find.byKey(const Key('my-lists-empty-state'));
  Finder get myListsTable => find.byKey(const Key('my-lists-table'));
  Finder myListsRow(int peakListId) => find.byKey(Key('my-lists-row-$peakListId'));
  Finder myListsControl(String key) =>
      find.descendant(of: myListsCard, matching: find.byKey(Key(key)));

  Future<void> pumpApp({required ProviderContainer container}) async {
    this.container = container;
    await tester.binding.setSurfaceSize(const Size(2200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDashboard() async {
    await tester.tap(homeButton);
    await tester.pumpAndSettle();
  }

  Future<void> dragCard(String draggedId, String targetId) async {
    final start = tester.getCenter(dragHandle(draggedId));
    final end = tester.getCenter(card(targetId));
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> tapLatestWalkPrev() async {
    await tester.tap(latestWalkPrevTrack);
    await tester.pumpAndSettle();
  }

  Future<void> tapLatestWalkNext() async {
    await tester.tap(latestWalkNextTrack);
    await tester.pumpAndSettle();
  }

  void expectOrder(List<String> expected) {
    expect(container.read(dashboardLayoutProvider), expected);
  }

  Future<void> expectOrderEventually(List<String> expected) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (listEquals(container.read(dashboardLayoutProvider), expected)) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(container.read(dashboardLayoutProvider), expected);
  }
}
