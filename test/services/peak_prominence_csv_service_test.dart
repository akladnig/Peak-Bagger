import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_prominence_csv_service.dart';

void main() {
  const service = PeakProminenceCsvService();

  test('parses the six-column headerless contract', () {
    final document = service.parse('''
27.9892,86.9256,8737.79,0,0,8737.79
-32.6533,-70.0117,6915.52,0,0,6915.52
''');

    expect(document.rows, hasLength(2));
    expect(document.rows.first.latitude, 27.9892);
    expect(document.rows.first.longitude, 86.9256);
    expect(document.rows.first.elevation, 8737.79);
    expect(document.rows.first.keySaddleLatitude, 0);
    expect(document.rows.first.keySaddleLongitude, 0);
    expect(document.rows.first.prominence, 8737.79);
  });

  test('marks a zero-zero key saddle as the land-mass sentinel', () {
    final document = service.parse('''
27.9892,86.9256,8737.79,0,0,8737.79
''');

    expect(document.rows.single.keySaddleIsLandMassHighPoint, isTrue);
  });

  test('rejects malformed rows and non-numeric values', () {
    expect(
      () => service.parse('''
27.9892,86.9256,8737.79,0,0
'''),
      throwsA(isA<PeakProminenceCsvFormatException>()),
    );

    expect(
      () => service.parse('''
27.9892,86.9256,not-a-number,0,0,8737.79
'''),
      throwsA(isA<PeakProminenceCsvFormatException>()),
    );
  });

  test('rejects out-of-order prominence rows', () {
    expect(
      () => service.parse('''
27.9892,86.9256,8737.79,0,0,8737.79
-32.6533,-70.0117,6915.52,0,0,9000
'''),
      throwsA(isA<PeakProminenceCsvFormatException>()),
    );
  });
}
