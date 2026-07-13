import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_csv_source.dart';

void main() {
  test('loads peaks from exported app csv rows', () async {
    final directory = await Directory.systemTemp.createTemp('peak-csv-source');
    addTearDown(() => directory.deleteSync(recursive: true));

    final file = File('${directory.path}/peaks.csv');
    await file.writeAsString('''
Name,Alt Name,Elevation,Latitude,Longitude,Region,Zone,mgrs100kId,Easting,Northing,Verified,osmId
Triglav,,2864,46.37832,13.83648,Slovenia,33T,VM,12345,67890,true,1001
Bad Row,,,not-a-latitude,13.1,Slovenia,33T,VM,12345,67890,false,1002
''');

    final source = await PeakCsvSource.load(file.path);
    final peaks = source.getAllPeaks();

    expect(peaks, hasLength(1));
    expect(peaks.single.name, 'Triglav');
    expect(peaks.single.osmId, 1001);
    expect(peaks.single.verified, isTrue);
    expect(peaks.single.region, 'Slovenia');
  });
}
