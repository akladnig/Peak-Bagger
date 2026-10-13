import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/widgets/mapping_store_failure_dialog.dart';

class MappingStoreFailureRobot {
  MappingStoreFailureRobot(this.tester);
  final WidgetTester tester;

  Future<void> pumpStartup(Widget shell) async {
    await tester.pumpWidget(shell);
    await tester.pump();
  }

  void expectReplicaStartupUnavailable(String root) {
    expect(find.text('Mapping runtime replica unavailable'), findsOneWidget);
    expect(find.text(root), findsWidgets);
    expect(
      find.byKey(const Key('mapping-store-unavailable-retry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mapping-store-unavailable-quit')),
      findsOneWidget,
    );
  }

  Future<void> retryStartup() async {
    await tester.tap(find.byKey(const Key('mapping-store-unavailable-retry')));
    await tester.pump();
  }

  void expectStartupChecking() {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('dashboard-card-elevation')), findsNothing);
  }

  void expectReadySurface() =>
      expect(find.byKey(const Key('dashboard-card-elevation')), findsOneWidget);

  Future<void> pumpSurface(ProviderContainer container, Widget surface) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: MappingStoreFailureDialogHost(child: surface)),
        ),
      ),
    );
    await tester.pump();
  }

  void expectFailure(String path) {
    expect(
      find.byKey(const Key('mapping-store-failure-dialog')),
      findsOneWidget,
    );
    expect(find.text(path), findsOneWidget);
  }

  Future<void> dismiss() async {
    await tester.tap(find.byKey(const Key('mapping-store-failure-dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('mapping-store-failure-dialog')), findsNothing);
  }

  void expectUnavailable(String feature) =>
      expect(find.byKey(Key('$feature-mapping-unavailable')), findsOneWidget);

  Future<void> retryFeature(String feature) async {
    await tester.tap(find.byKey(Key('$feature-mapping-unavailable-retry')));
    await tester.pump();
    await tester.pump();
  }

  void expectAvailable(String feature) =>
      expect(find.byKey(Key('$feature-mapping-unavailable')), findsNothing);
}
