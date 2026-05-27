import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/widgets/route_marker.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('circle renders white fill and colored stroke', (tester) async {
    await tester.pumpWidget(
      host(const RouteMarker(kind: RouteMarkerKind.circle, color: Colors.red)),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('route-marker-circle')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, Colors.white);
    expect(decoration.shape, BoxShape.circle);
    final border = decoration.border! as Border;
    expect(border.top.color, Colors.red);
    expect(border.top.width, RouteUI.strokeWidth);
  });

  testWidgets('target renders ring and center dot', (tester) async {
    await tester.pumpWidget(
      host(const RouteMarker(kind: RouteMarkerKind.target, color: Colors.blue)),
    );

    final ring = tester.widget<Container>(
      find.byKey(const Key('route-marker-target-ring')),
    );
    final ringDecoration = ring.decoration! as BoxDecoration;
    expect(ringDecoration.color, Colors.white);
    final ringBorder = ringDecoration.border! as Border;
    expect(ringBorder.top.color, Colors.blue);

    final dot = tester.widget<Container>(
      find.byKey(const Key('route-marker-target-dot')),
    );
    final dotDecoration = dot.decoration! as BoxDecoration;
    expect(dotDecoration.color, Colors.blue);
    expect(dotDecoration.shape, BoxShape.circle);
  });

  testWidgets('numbered clamps and darkens stroke', (tester) async {
    await tester.pumpWidget(
      host(
        const RouteMarker(
          kind: RouteMarkerKind.numbered,
          color: Colors.green,
          number: 120,
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const Key('route-marker-numbered-fill')),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, Colors.green);
    final border = decoration.border! as Border;
    expect(border.top.width, RouteUI.strokeWidth);
    expect(border.top.color, isNot(Colors.green));
    expect(border.top.color, Color.lerp(Colors.green, Colors.black, RouteUI.strokeDarkenAlpha));

    final label = tester.widget<Text>(
      find.byKey(const Key('route-marker-numbered-label')),
    );
    expect(label.data, '99');
    expect(label.style?.fontSize, RouteUI.markerFontSize);
    expect(label.style?.color, Colors.white);
  });

  testWidgets('size clamps to minimum', (tester) async {
    await tester.pumpWidget(
      host(
        const RouteMarker(
          kind: RouteMarkerKind.circle,
          color: Colors.purple,
          size: 12,
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(sizedBox.width, RouteUI.markerMinSize);
    expect(sizedBox.height, RouteUI.markerMinSize);
  });
}
