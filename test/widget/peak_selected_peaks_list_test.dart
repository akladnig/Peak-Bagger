import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/widgets/peak_selected_peaks_list.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  testWidgets(
    'scaled labelled Points retain drafts and reject captured callbacks at the current lock',
    (tester) async {
      var allowed = true;
      var writes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.dark,
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SizedBox(
                    width: 676,
                    child: PeakSelectedPeaksList(
                      selectedPeaks: [_peak(1, 'Alpha Peak')],
                      selectedPeakIds: const {1},
                      pointsByPeakId: const {1: 3},
                      enabled: allowed,
                      isInteractionAllowed: () => allowed,
                      onSelectionChanged: (_) => writes++,
                      onPointsChanged: (_, _) => writes++,
                      mapNameForPeak: (_) => 'Map',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      final field = find.byKey(const Key('peak-selected-points-1'));
      await tester.enterText(field, '');
      final input = tester.widget<TextField>(field);
      expect(input.decoration!.labelText, 'Points');
      final increment = tester
          .widget<IconButton>(find.byKey(const Key('peak-selected-points-up')))
          .onPressed!;
      final changed = input.onChanged!;
      allowed = false;
      increment();
      changed('9');
      expect(writes, 0);
      update(() {});
      await tester.pump();
      expect(
        input.controller!.text,
        '',
      ); // No committed-value resync on rebuild/lock focus loss.
      expect(tester.widget<TextField>(field).enabled, false);
      expect(tester.takeException(), isNull);
      allowed = true;
      update(() {});
      await tester.pump();
      expect(input.controller!.text, '');
      await tester.tap(find.byKey(const Key('peak-selected-points-up')));
      await tester.pump();
      expect(input.controller!.text, '4');
      expect(writes, 1);
    },
  );

  testWidgets('renders row keys and default points', (tester) async {
    await tester.pumpWidget(_Harness(selectedPeaks: [_peak(1, 'Alpha Peak')]));

    expect(find.byKey(const Key('peak-selected-row-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-selected-checkbox-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-selected-points-1')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('peak-selected-points-1')))
          .controller!
          .text,
      '1',
    );
  });

  testWidgets('typing points clamps and keeps the row selected', (
    tester,
  ) async {
    await tester.pumpWidget(_Harness(selectedPeaks: [_peak(1, 'Alpha Peak')]));

    await tester.enterText(
      find.byKey(const Key('peak-selected-points-1')),
      '12',
    );
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('peak-selected-points-1')))
          .controller!
          .text,
      '10',
    );
    expect(
      tester
          .widget<Checkbox>(find.byKey(const Key('peak-selected-checkbox-1')))
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Container>(
            find
                .descendant(
                  of: find.byKey(const Key('peak-selected-row-1')),
                  matching: find.byType(Container),
                )
                .first,
          )
          .color,
      Colors.green.withValues(alpha: 0.12),
    );
  });

  testWidgets('tapping the checkbox removes the selected row', (tester) async {
    await tester.pumpWidget(_Harness(selectedPeaks: [_peak(1, 'Alpha Peak')]));

    await tester.tap(find.byKey(const Key('peak-selected-checkbox-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-selected-row-1')), findsNothing);
  });

  testWidgets('unknown height renders as a long dash', (tester) async {
    await tester.pumpWidget(
      _Harness(selectedPeaks: [_peak(1, 'Alpha Peak', elevation: null)]),
    );

    expect(find.text('—'), findsOneWidget);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.selectedPeaks});

  final List<Peak> selectedPeaks;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Set<int> _selectedPeakIds;
  late Map<int, int> _pointsByPeakId;

  @override
  void initState() {
    super.initState();
    _selectedPeakIds = {for (final peak in widget.selectedPeaks) peak.osmId};
    _pointsByPeakId = <int, int>{};
  }

  @override
  Widget build(BuildContext context) {
    final visibleSelectedPeaks = widget.selectedPeaks
        .where((peak) => _selectedPeakIds.contains(peak.osmId))
        .toList(growable: false);

    return MaterialApp(
      theme: MyTheme.dark,
      home: Scaffold(
        body: SizedBox.expand(
          child: PeakSelectedPeaksList(
            selectedPeaks: visibleSelectedPeaks,
            selectedPeakIds: _selectedPeakIds,
            pointsByPeakId: _pointsByPeakId,
            mapNameForPeak: (peak) => 'Map ${peak.osmId}',
            onSelectionChanged: (selectedPeakIds) {
              setState(() {
                _selectedPeakIds = selectedPeakIds;
              });
            },
            onPointsChanged: (peakId, points) {
              setState(() {
                _selectedPeakIds = {..._selectedPeakIds, peakId};
                _pointsByPeakId[peakId] = points;
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
