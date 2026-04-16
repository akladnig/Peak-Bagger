import 'package:flutter/material.dart';
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

  test('calculates a lower-right label anchor', () {
    final points = [
      const LatLng(-41.0, 146.0),
      const LatLng(-41.0, 147.0),
      const LatLng(-42.0, 146.0),
      const LatLng(-42.0, 147.0),
    ];

    final anchor = tasmapPolygonLabelAnchor(points);

    expect(anchor, isNotNull);
    expect(anchor!.latitude, greaterThan(-42.0));
    expect(anchor.longitude, lessThan(147.0));
  });

  test('builds Tasmap label style with shadow and 12px font', () {
    final style = tasmapPolygonLabelStyle(Colors.blue);

    expect(style.fontSize, 12);
    expect(style.color, Colors.blue);
    expect(style.shadows, isNotEmpty);
  });
}
