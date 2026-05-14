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
  Finder dragHandle(String id) => find.byKey(Key('dashboard-card-$id-drag-handle'));

  Future<void> pumpApp({required ProviderContainer container}) async {
    this.container = container;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const App(),
      ),
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
