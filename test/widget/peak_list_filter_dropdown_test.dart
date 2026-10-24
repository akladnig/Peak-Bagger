import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/map_metadata_filter_popup.dart';

const easy = PeakDifficultyFilterOption(region: 'tasmania', difficulty: 'Easy');
const hard = PeakDifficultyFilterOption(region: 'tasmania', difficulty: 'Hard');

Finder key(String value) => find.byKey(Key(value));

void main() {
  testWidgets(
    'nullable Any, retained disabled difficulty, grouping and revalidation use real shared input',
    (tester) async {
      PeakDifficultyFilterOption? selected = easy;
      var options = [hard];
      var writes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.dark,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 360,
                    child: MapMetadataFilterPopup(
                      ratingFilter: PeakRatingFilterOption.any,
                      difficultyFilter: selected,
                      difficultyOptions: options,
                      durationFilter: PeakDurationFilterOption.any,
                      onSelectRatingFilter: (_) {},
                      onSelectDurationFilter: (_) {},
                      onSelectDifficultyFilter: (value) => update(() {
                        selected = value;
                        writes++;
                      }),
                      onClearFilters: () {},
                      onClose: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      const unavailable = 'Easy (Tasmanian) — unavailable for this list';
      expect(find.text(unavailable), findsOneWidget);
      await tester.tap(key('map-metadata-filter-difficulty-trigger'));
      await tester.pumpAndSettle();
      expect(key('map-metadata-filter-difficulty-unavailable'), findsOneWidget);
      expect(
        key('map-metadata-filter-difficulty-group-tasmania'),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(selected, easy);
      await tester.tap(key('map-metadata-filter-difficulty-trigger'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      expect(selected, easy);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(writes, 1);
      await tester.tap(key('map-metadata-filter-difficulty-trigger'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(writes, 1); // Committed Any is not an absent required selection.
      update(() {
        selected = easy;
        options = [easy, hard];
      });
      await tester.pumpAndSettle();
      expect(find.text(unavailable), findsNothing);
      await tester.tap(key('map-metadata-filter-difficulty-trigger'));
      await tester.pumpAndSettle();
      expect(
        key('map-metadata-filter-difficulty-option-tasmania-easy'),
        findsOneWidget,
      );
      expect(key('map-metadata-filter-difficulty-unavailable'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rating uses exact threshold text, semantic names and stable identities',
    (tester) async {
      final semantics = tester.ensureSemantics();
      PeakRatingFilterOption? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.dark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: MapMetadataFilterPopup(
                  ratingFilter: PeakRatingFilterOption.any,
                  difficultyFilter: null,
                  difficultyOptions: const [],
                  durationFilter: PeakDurationFilterOption.any,
                  onSelectRatingFilter: (value) => selected = value,
                  onSelectDifficultyFilter: (_) {},
                  onSelectDurationFilter: (_) {},
                  onClearFilters: () {},
                  onClose: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(key('map-metadata-filter-rating-trigger'));
      await tester.pumpAndSettle();
      for (final label in ['Any', '3.0+', '3.5+', '4.0+', '4.5+']) {
        expect(find.text(label), findsWidgets);
      }
      expect(
        find.bySemanticsLabel('Rating at least 4.5 out of 5'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star), findsNothing);
      await tester.tap(key('map-metadata-filter-rating-option-4.5'));
      await tester.pumpAndSettle();
      expect(selected, PeakRatingFilterOption.values.last);
      semantics.dispose();
    },
  );
}
