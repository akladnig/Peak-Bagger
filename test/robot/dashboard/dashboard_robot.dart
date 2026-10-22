import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';

class DashboardRobot {
  DashboardRobot(this.tester);

  final WidgetTester tester;
  late ProviderContainer container;

  Finder get dashboardButton => find.byKey(const Key('nav-dashboard'));
  Finder get mapButton => find.byKey(const Key('nav-map'));
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
  Finder myListsRow(int peakListId) =>
      find.byKey(Key('my-lists-row-$peakListId'));
  Finder get peakListsSelectedTitle =>
      find.byKey(const Key('peak-lists-selected-title'));
  Finder myListsControl(String key) =>
      find.descendant(of: myListsCard, matching: find.byKey(Key(key)));
  Finder get myAscentsCard =>
      find.byKey(const Key('dashboard-card-my-ascents'));
  Finder get myAscentsEmptyState =>
      find.byKey(const Key('my-ascents-empty-state'));
  Finder get myAscentsTable => find.byKey(const Key('my-ascents-table'));
  Finder myAscentsRow(int baggedId) =>
      find.byKey(Key('my-ascents-row-$baggedId'));
  Finder myAscentsYearHeader(int year) =>
      find.byKey(Key('my-ascents-year-$year'));
  Finder get myAscentsSortToggle =>
      find.byKey(const Key('my-ascents-sort-toggle'));

  Future<void> pumpApp({required ProviderContainer container}) async {
    // End the previous scope before replacing its container, allowing
    // auto-disposed per-card state to release its scheduler/listeners.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    this.container = container;
    await tester.binding.setSurfaceSize(const Size(2200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDashboard() async {
    await tester.tap(dashboardButton);
    await tester.pumpAndSettle();
  }

  Future<void> openMap() async {
    await tester.tap(mapButton);
    await tester.pumpAndSettle();
  }

  Future<void> navigateSummary(String cardId, String action) async {
    await tester.tap(summaryControl(cardId, 'summary-$action-window'));
    await tester.pumpAndSettle();
  }

  Future<void> selectSummaryPeriod(String cardId, String label) async {
    await tester.tap(summaryControl(cardId, 'summary-period-dropdown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> selectTimeChartType(TimeChartType type) async {
    await revealCard('time');
    await tester.tap(summaryControl('time', 'time-chart-type-button'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('time-chart-type-${type.name}')));
    await tester.pumpAndSettle();
  }

  Future<void> closeTimeMenuUnchanged() async {
    await tester.tap(summaryControl('time', 'time-chart-type-button'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);
  }

  Future<void> scrollSummary(String cardId, double delta) async {
    final browser = summaryControl(cardId, '$cardId-page-browser');
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(browser),
        scrollDelta: Offset(delta, 0),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
  }

  void expectSummary(
    String cardId, {
    required String range,
    required String total,
    required String average,
  }) {
    expect(
      tester.widget<Text>(summaryControl(cardId, '$cardId-period-range')).data,
      range,
    );
    final header = dragHandle(cardId);
    final chart = tester.widget<SummaryChart>(
      find.descendant(of: card(cardId), matching: find.byType(SummaryChart)),
    );
    for (final field in [
      ('total', 'Total: $total'),
      ('average', '${chart.period.averageLabel} $average'),
    ]) {
      final value = find.descendant(
        of: header,
        matching: find.byKey(Key('dashboard-card-summary-${field.$1}-value')),
      );
      expect(tester.widget<Text>(value).data, field.$2);
    }
  }

  Future<void> openSettings() async {
    await tester.tap(find.byKey(const Key('nav-settings')));
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

  Future<void> tapMyAscentsSortToggle() async {
    await tester.tap(myAscentsSortToggle);
    await tester.pumpAndSettle();
  }

  Future<void> tapMyListsRow(int peakListId) async {
    await revealCard('my-lists');
    await tester.tap(myListsRow(peakListId));
    await tester.pumpAndSettle();
  }

  Future<void> revealCard(String id) async {
    await tester.scrollUntilVisible(
      card(id),
      200,
      scrollable: find
          .descendant(of: board, matching: find.byType(Scrollable))
          .first,
    );
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
