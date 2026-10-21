import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/services/map_search_service.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/map_search_popup.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';

const _yearError = 'Enter a year from 1 to 9999';
Finder _key(String suffix) => find.byKey(Key('map-search-$suffix'));
Finder _year(String endpoint) => find.descendant(
  of: _key('date-$endpoint-year'),
  matching: find.byType(TextField),
);
String _calendar(WidgetTester tester, String endpoint) =>
    tester.widget<Text>(_key('date-$endpoint-calendar-label')).data!;

void main() {
  for (final invalid in ['', 'abc', '0', '10000']) {
    testWidgets(
      'Year retains invalid "$invalid" without navigation or date edits',
      (tester) async {
        final selected = <TrackDateRange?>[];
        await _pumpPopup(tester, onDate: selected.add);
        await tester.tap(_key('date-trigger'));
        await tester.pumpAndSettle();
        await tester.enterText(_year('start'), invalid);
        await tester.pump();
        expect(find.text(_yearError), findsNothing);
        expect(_calendar(tester, 'start'), 'Jul 2024');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text(_yearError), findsOneWidget);
        expect(
          tester.widget<TextField>(_year('start')).controller!.text,
          invalid,
        );
        expect(_calendar(tester, 'start'), 'Jul 2024');
        expect(_calendar(tester, 'end'), 'Jul 2024');
        expect(selected, isEmpty);
        expect(
          tester.widget<FilledButton>(_key('date-apply')).onPressed,
          isNotNull,
        );
        await tester.ensureVisible(_key('date-apply'));
        await tester.tap(_key('date-apply'));
        await tester.pumpAndSettle();
        expect(selected.single!.start, const TrackCalendarDay(2024, 7, 28));
        expect(selected.single!.end, const TrackCalendarDay(2024, 7, 28));
      },
    );
  }

  testWidgets(
    'Year errors are independent, validate on blur and recover at boundaries',
    (tester) async {
      await _pumpPopup(tester);
      await tester.tap(_key('date-trigger'));
      await tester.pumpAndSettle();
      await tester.enterText(_year('start'), '0');
      await tester.tap(_year('end'));
      await tester.pumpAndSettle();
      expect(find.text(_yearError), findsOneWidget);
      await tester.enterText(_year('end'), '10000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(_yearError), findsNWidgets(2));
      await tester.enterText(_year('start'), '1');
      await tester.pump();
      expect(_calendar(tester, 'start'), 'Jul 2024');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_calendar(tester, 'start'), 'Jul 1');
      expect(_calendar(tester, 'end'), 'Jul 2024');
      expect(find.text(_yearError), findsOneWidget);
      await tester.enterText(_year('end'), '9999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_calendar(tester, 'end'), 'Jul 9999');
      expect(find.text(_yearError), findsNothing);
      await tester.enterText(_year('start'), 'bad');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(_key('date-close'));
      await tester.pumpAndSettle();
      await tester.tap(_key('date-trigger'));
      await tester.pumpAndSettle();
      expect(find.text(_yearError), findsNothing);
      expect(tester.widget<TextField>(_year('start')).controller!.text, '2024');
      expect(_calendar(tester, 'start'), 'Jul 2024');
    },
  );

  testWidgets(
    'Month menu owns Escape Ctrl+C back and immediate Enter without picker cascade',
    (tester) async {
      await _pumpPopup(tester);
      await tester.tap(_key('date-trigger'));
      await tester.pumpAndSettle();
      final month = _key('date-start-month');
      for (final close in ['enter', 'escape', 'controlC', 'back']) {
        await tester.ensureVisible(month);
        await tester.tap(month);
        await tester.pumpAndSettle();
        if (close == 'back') {
          await tester.binding.handlePopRoute();
        } else if (close == 'controlC') {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        } else {
          await tester.sendKeyEvent(
            close == 'enter'
                ? LogicalKeyboardKey.enter
                : LogicalKeyboardKey.escape,
          );
        }
        await tester.pumpAndSettle();
        expect(_calendar(tester, 'start'), 'Jul 2024');
        expect(_key('date-picker'), findsOneWidget);
        expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);
      }
      await tester.tap(month);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_calendar(tester, 'start'), 'Aug 2024');
      expect(
        tester.widget<TextField>(_key('date-start-input')).controller!.text,
        '28 Jul 2024',
      );
    },
  );

  testWidgets(
    'Month pointer selection and consumed outside click retain the picker',
    (tester) async {
      await _pumpPopup(tester);
      await tester.tap(_key('date-trigger'));
      await tester.pumpAndSettle();
      final month = _key('date-start-month');
      await tester.tap(month);
      await tester.pumpAndSettle();
      final august = find.descendant(
        of: find.byKey(const Key('shared-dropdown-menu')),
        matching: find.text('Aug'),
      );
      await tester.tap(august);
      await tester.pumpAndSettle();
      expect(_key('date-picker'), findsOneWidget);
      expect(_calendar(tester, 'start'), 'Aug 2024');
      await tester.tap(month);
      await tester.pumpAndSettle();
      await tester.tap(_key('entity-natural'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);
      expect(_key('date-picker'), findsOneWidget);
      await tester.tap(_key('entity-natural'));
      await tester.pumpAndSettle();
      expect(_key('date-picker'), findsNothing);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'scaled ${brightness.name} picker wraps errors, scrolls, retains drafts on resize/theme',
      (tester) async {
        const config = ThemeConfig(
          seedColor: Colors.teal,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          contrastLevel: 0,
        );
        final theme = brightness == Brightness.light
            ? MyTheme.lightWith(config)
            : MyTheme.darkWith(config);
        await _pumpPopup(tester, theme: theme, scale: 2);
        await tester.tap(_key('date-trigger'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(_year('start'));
        await tester.enterText(_year('start'), '10000');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        final error = tester.widget<Text>(find.text(_yearError));
        expect(error.maxLines, isNull);
        expect(error.softWrap, isTrue);
        expect(tester.getSize(find.text(_yearError)).height, greaterThan(24));
        expect(find.byTooltip('Previous start month'), findsNothing);
        await tester.binding.setSurfaceSize(const Size(1600, 1100));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_year('start')).controller!.text,
          '10000',
        );
        await tester.ensureVisible(_key('date-apply'));
        expect(_key('date-apply').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'stale selection and focus callbacks reject a current lock without replay',
    (tester) async {
      var allowed = true;
      var selections = 0;
      final key = GlobalKey<MapSearchPopupState>();
      final focus = await _pumpPopup(
        tester,
        key: key,
        allowed: () => allowed,
        onSort: (_) => selections++,
      );
      await tester.enterText(_key('input'), 'raw query');
      final input = tester.widget<TextField>(_key('input'));
      final before = input.controller!.selection;
      final stale = tester
          .widget<SharedDropdown<MapSearchSort>>(_key('sort-button'))
          .onSelected;
      allowed = false;
      stale(MapSearchSort.nameDescending);
      key.currentState!.focusSearch();
      expect(input.controller!.selection, before);
      expect(selections, 0);
      allowed = true;
      await tester.pumpAndSettle();
      expect(selections, 0);
      key.currentState!.focusSearch();
      expect(focus.hasFocus, isTrue);
      expect(
        input.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 9),
      );
      await tester.ensureVisible(_key('sort-button'));
      await tester.tap(_key('sort-button'));
      await tester.pumpAndSettle();
      key.currentState!.focusSearch();
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      key.currentState!.focusSearch();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
    },
  );
}

Future<FocusNode> _pumpPopup(
  WidgetTester tester, {
  GlobalKey<MapSearchPopupState>? key,
  ThemeData? theme,
  double scale = 1,
  bool Function()? allowed,
  ValueChanged<TrackDateRange?>? onDate,
  ValueChanged<MapSearchSort>? onSort,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final focus = FocusNode();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? MyTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: MapSearchPopup(
            key: key,
            focusNode: focus,
            searchResults: const [],
            isLoadingMore: false,
            isExhausted: true,
            searchQuery: '',
            trackDateRange: const TrackDateRange(
              start: TrackCalendarDay(2024, 7, 28),
              end: TrackCalendarDay(2024, 7, 28),
            ),
            categories: MapSearchService.defaultCategories,
            selectedRegionKey: null,
            sort: MapSearchSort.nameAscending,
            group: MapSearchGroup.none,
            availableRegions: const [],
            isInteractionAllowed: allowed,
            onChanged: (_) {},
            onToggleCategory: (_) {},
            onSelectTrackDateRange: onDate ?? (_) {},
            onSelectRegionKey: (_) {},
            onSelectSort: onSort ?? (_) {},
            onSelectGroup: (_) {},
            onLoadMore: () {},
            onClose: () {},
            onSelectResult: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return focus;
}
