import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/peak_multi_select_results_list.dart';

void main() {
  testWidgets('renders row keys and checkbox', (tester) async {
    await tester.pumpWidget(_Harness(searchResults: [_peak(1, 'Alpha Peak')]));

    expect(find.byKey(const Key('peak-multi-select-row-1')), findsOneWidget);
    expect(
      find.byKey(const Key('peak-multi-select-checkbox-1')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a checkbox selects the row', (tester) async {
    await tester.pumpWidget(_Harness(searchResults: [_peak(1, 'Alpha Peak')]));

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-1')));
    await tester.pump();

    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('peak-multi-select-checkbox-1')),
          )
          .value,
      isTrue,
    );
    final row = find.byKey(const Key('peak-multi-select-row-1'));
    final theme = Theme.of(tester.element(row));
    final decoration =
        tester.widget<Container>(_rowDecoration(row)).decoration!
            as BoxDecoration;
    expect(
      decoration.color,
      theme.extension<DataGridTheme>()!.selectedRowColor,
    );
    expect(decoration.border, isA<Border>());
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('peak-multi-select-checkbox-1')),
          )
          .activeColor,
      Colors.green,
    );
  });

  testWidgets('read-only selected peaks stay checked and disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        searchResults: [_peak(1, 'Alpha Peak')],
        readOnlySelectedIds: {1},
      ),
    );

    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('peak-multi-select-checkbox-1')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('peak-multi-select-checkbox-1')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('unknown height renders as a long dash', (tester) async {
    await tester.pumpWidget(
      _Harness(searchResults: [_peak(1, 'Alpha Peak', elevation: null)]),
    );

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('selection limit disables new checkboxes', (tester) async {
    await tester.pumpWidget(
      _Harness(
        searchResults: [_peak(51, 'Alpha Peak')],
        initialSelectedIds: {for (var index = 1; index <= 50; index++) index},
      ),
    );

    expect(find.text('Maximum 50 peaks per save'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('peak-multi-select-checkbox-51')),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('search results lazily build beyond 100 rows', (tester) async {
    final peaks = [
      for (var index = 1; index <= 101; index++)
        _peak(index, 'Peak ${index.toString().padLeft(3, '0')}'),
    ];
    await tester.pumpWidget(_Harness(searchResults: peaks));

    expect(find.text('Showing 100 of 101 results'), findsNothing);
    expect(find.byKey(const Key('peak-multi-select-row-101')), findsNothing);

    await tester.drag(
      find.byKey(const Key('peak-multi-select-scrollable')),
      const Offset(0, -8000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-multi-select-row-101')), findsOneWidget);
  });

  testWidgets(
    'uses the data grid style at desktop text scale without changing checkbox keyboard activation',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longName =
          'A very long peak name that must ellipsize without overflowing the data grid row';
      await tester.pumpWidget(
        _Harness(
          searchResults: [
            _peak(1, longName, elevation: 1234),
            _peak(2, 'Beta Peak', elevation: 567),
          ],
          initialSelectedIds: {2},
          textScaler: TextScaler.linear(2.0),
        ),
      );

      final unselectedRow = find.byKey(const Key('peak-multi-select-row-1'));
      final selectedRow = find.byKey(const Key('peak-multi-select-row-2'));
      final theme = Theme.of(tester.element(selectedRow));
      final dataGridTheme = theme.extension<DataGridTheme>()!;
      final selectedDecoration =
          tester.widget<Container>(_rowDecoration(selectedRow)).decoration!
              as BoxDecoration;
      expect(selectedDecoration.color, dataGridTheme.selectedRowColor);
      expect(selectedDecoration.border, isA<Border>());
      expect(
        find.byKey(const Key('peak-multi-select-divider-0')),
        findsOneWidget,
      );
      expect(
        tester.widget<Text>(find.text(longName)).overflow,
        TextOverflow.ellipsis,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(selectedRow));
      await tester.pump();
      expect(
        (tester.widget<Container>(_rowDecoration(selectedRow)).decoration!
                as BoxDecoration)
            .color,
        dataGridTheme.selectedRowColor,
      );

      final press = await tester.startGesture(tester.getCenter(selectedRow));
      await tester.pump();
      expect(
        (tester.widget<Container>(_rowDecoration(selectedRow)).decoration!
                as BoxDecoration)
            .color,
        dataGridTheme.selectedRowColor,
      );
      await press.up();
      await tester.pump();

      await mouse.moveTo(tester.getCenter(unselectedRow));
      await tester.pump();
      expect(
        (tester.widget<Container>(_rowDecoration(unselectedRow)).decoration!
                as BoxDecoration)
            .color,
        dataGridTheme.hoverColor,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const Key('peak-multi-select-checkbox-1')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Finder _rowDecoration(Finder row) {
  return find.descendant(of: row, matching: find.byType(Container)).first;
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.searchResults,
    this.initialSelectedIds = const {},
    this.readOnlySelectedIds = const {},
    this.textScaler = TextScaler.noScaling,
  });

  final List<Peak> searchResults;
  final Set<int> initialSelectedIds;
  final Set<int> readOnlySelectedIds;
  final TextScaler textScaler;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Set<int> _selectedPeakIds;

  @override
  void initState() {
    super.initState();
    _selectedPeakIds = {...widget.initialSelectedIds};
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: MyTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: widget.textScaler),
        child: Scaffold(
          body: SizedBox.expand(
            child: PeakMultiSelectResultsList(
              searchResults: widget.searchResults,
              searchQuery: '',
              selectedPeakIds: _selectedPeakIds,
              readOnlySelectedPeakIds: widget.readOnlySelectedIds,
              mapNameForPeak: (peak) => 'Map ${peak.osmId}',
              onSelectionChanged: (selectedPeakIds) {
                setState(() {
                  _selectedPeakIds = selectedPeakIds;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

Peak _peak(int osmId, String name, {double? elevation}) {
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: -41.0 + osmId / 1000,
    longitude: 146.0 + osmId / 1000,
  );
}
