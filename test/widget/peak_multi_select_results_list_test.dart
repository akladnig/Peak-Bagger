import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/widgets/peak_multi_select_results_list.dart';

void main() {
  testWidgets('renders row keys and checkbox', (tester) async {
    await tester.pumpWidget(
      _Harness(
        searchResults: [_peak(1, 'Alpha Peak')],
      ),
    );

    expect(find.byKey(const Key('peak-multi-select-row-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-multi-select-checkbox-1')), findsOneWidget);
  });

  testWidgets('tapping a checkbox selects the row', (tester) async {
    await tester.pumpWidget(
      _Harness(
        searchResults: [_peak(1, 'Alpha Peak')],
      ),
    );

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-1')));
    await tester.pump();

    expect(
      tester.widget<Checkbox>(find.byKey(const Key('peak-multi-select-checkbox-1'))).value,
      isTrue,
    );
  });

  testWidgets('unknown height renders as a long dash', (tester) async {
    await tester.pumpWidget(
      _Harness(
        searchResults: [_peak(1, 'Alpha Peak', elevation: null)],
      ),
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
      tester.widget<Checkbox>(find.byKey(const Key('peak-multi-select-checkbox-51'))).onChanged,
      isNull,
    );
  });

  testWidgets('search results lazily build beyond 100 rows', (tester) async {
    final peaks = [for (var index = 1; index <= 101; index++) _peak(index, 'Peak ${index.toString().padLeft(3, '0')}')];
    await tester.pumpWidget(
      _Harness(
        searchResults: peaks,
      ),
    );

    expect(find.text('Showing 100 of 101 results'), findsNothing);
    expect(find.byKey(const Key('peak-multi-select-row-101')), findsNothing);

    await tester.drag(
      find.byKey(const Key('peak-multi-select-scrollable')),
      const Offset(0, -8000),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-multi-select-row-101')), findsOneWidget);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({
    required this.searchResults,
    this.initialSelectedIds = const {},
  });

  final List<Peak> searchResults;
  final Set<int> initialSelectedIds;

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
      home: Scaffold(
        body: SizedBox.expand(
          child: PeakMultiSelectResultsList(
            searchResults: widget.searchResults,
            searchQuery: '',
            selectedPeakIds: _selectedPeakIds,
            mapNameForPeak: (peak) => 'Map ${peak.osmId}',
            onSelectionChanged: (selectedPeakIds) {
              setState(() {
                _selectedPeakIds = selectedPeakIds;
              });
            },
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
