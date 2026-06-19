import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  testWidgets('OutlinedText builds stroke and fill layers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: OutlinedText(text: 'Peak')),
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(OutlinedText),
            matching: find.byType(Text),
          ),
        )
        .toList(growable: false);
    final fill = texts.singleWhere((text) => text.style?.foreground == null);
    final outline = texts.singleWhere((text) => text.style?.foreground != null);

    expect(texts, hasLength(2));
    expect(fill.data, 'Peak');
    expect(outline.data, 'Peak');
  });

  testWidgets('OutlinedText accepts an explicit fill colour', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: OutlinedText(
              text: 'Favourite',
              textColor: favouriteMarkerColour,
            ),
          ),
        ),
      ),
    );

    final widget = tester.widget<OutlinedText>(find.byType(OutlinedText));
    expect(widget.textColor, favouriteMarkerColour);
  });
}
