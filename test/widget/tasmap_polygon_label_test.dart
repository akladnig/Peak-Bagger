import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

void main() {
  test('formats Tasmap label and handles blanks', () {
    final map = Tasmap50k(
      series: 'TS07',
      name: 'Adamsons',
      parentSeries: '8211',
      mgrs100kIds: 'DM DN',
      eastingMin: 60000,
      eastingMax: 99999,
      northingMin: 80000,
      northingMax: 9999,
      mgrsMid: 'DM',
      eastingMid: 80000,
      northingMid: 95000,
      p1: 'DN6000009999',
      p2: 'DN9999909999',
      p3: 'DM6000080000',
      p4: 'DM9999980000',
    );

    expect(formatTasmapPolygonLabel(map), 'Adamsons\nTS07');
    expect(
      formatTasmapPolygonLabel(
        Tasmap50k(
          series: 'TS07',
          name: '',
          parentSeries: '8211',
          mgrs100kIds: 'DM DN',
          eastingMin: 60000,
          eastingMax: 99999,
          northingMin: 80000,
          northingMax: 9999,
          mgrsMid: 'DM',
          eastingMid: 80000,
          northingMid: 95000,
          p1: 'DN6000009999',
          p2: 'DN9999909999',
          p3: 'DM6000080000',
          p4: 'DM9999980000',
        ),
      ),
      'TS07',
    );
    expect(
      formatTasmapPolygonLabel(
        Tasmap50k(
          series: '',
          name: 'Adamsons',
          parentSeries: '8211',
          mgrs100kIds: 'DM DN',
          eastingMin: 60000,
          eastingMax: 99999,
          northingMin: 80000,
          northingMax: 9999,
          mgrsMid: 'DM',
          eastingMid: 80000,
          northingMid: 95000,
          p1: 'DN6000009999',
          p2: 'DN9999909999',
          p3: 'DM6000080000',
          p4: 'DM9999980000',
        ),
      ),
      'Adamsons',
    );
    expect(
      formatTasmapPolygonLabel(
        Tasmap50k(
          series: '',
          name: '',
          parentSeries: '8211',
          mgrs100kIds: 'DM DN',
          eastingMin: 60000,
          eastingMax: 99999,
          northingMin: 80000,
          northingMax: 9999,
          mgrsMid: 'DM',
          eastingMid: 80000,
          northingMid: 95000,
          p1: 'DN6000009999',
          p2: 'DN9999909999',
          p3: 'DM6000080000',
          p4: 'DM9999980000',
        ),
      ),
      isNull,
    );
  });

  test(
    'calculates a lower-right label offset with configurable x/y insets',
    () {
      final points = [
        const LatLng(-41.0, 146.0),
        const LatLng(-41.0, 147.0),
        const LatLng(-42.0, 146.0),
        const LatLng(-42.0, 147.0),
      ];
      final camera = MapCamera(
        crs: const Epsg3857(),
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        rotation: 0,
        nonRotatedSize: const Size(800, 600),
      );

      final offset = tasmapPolygonLabelScreenOffset(
        points,
        camera: camera,
        insetX: 24,
        insetY: 16,
      );

      final corner = camera.latLngToScreenOffset(const LatLng(-42.0, 147.0));

      expect(offset, isNotNull);
      expect(offset!.dx, closeTo(corner.dx - 24, 0.01));
      expect(offset.dy, closeTo(corner.dy - 16, 0.01));
    },
  );

  testWidgets('builds Tasmap label widget with left aligned text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: tasmapPolygonLabelWidget(
            label: 'Adamsons\nTS07',
            color: Colors.blue,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));

    expect(text.textAlign, TextAlign.left);
  });

  test('builds Tasmap label style with 12px font', () {
    final style = tasmapPolygonLabelStyle(Colors.blue);

    expect(style.fontSize, 12);
    expect(style.color, Colors.blue);
  });
}
