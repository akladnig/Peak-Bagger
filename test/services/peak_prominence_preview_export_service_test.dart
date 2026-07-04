import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_prominence_preview_export_service.dart';
import 'package:peak_bagger/services/peak_source.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peak-prominence-preview');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'exports all peaks sorted by id with projected prominence values',
    () async {
      final service = PeakProminencePreviewExportService(
        peakSource: InMemoryPeakSource([
          Peak(
            id: 7,
            osmId: 700,
            name: 'Later Peak',
            latitude: -41,
            longitude: 146,
            prominence: null,
            region: 'B',
          ),
          Peak(
            id: 3,
            osmId: 300,
            name: 'Earlier Peak',
            latitude: -42,
            longitude: 147,
            prominence: 123.4,
            region: 'A',
          ),
        ]),
        outputDirectory: tempDir,
      );

      final result = await service.exportPreview(
        prominenceByPeakId: {7: 561.0},
      );
      final csvText = await File(result.path).readAsString();
      final rows = const CsvDecoder().convert(csvText);

      expect(
        result.path,
        '${tempDir.path}/peak-prominence-objectbox-preview.csv',
      );
      expect(result.exportedCount, 2);
      expect(rows.first.cast<String>(), [
        'id',
        'region',
        'name',
        'latitude',
        'longitude',
        'elevation',
        'prominence',
      ]);
      expect(rows[1][0].toString(), '3');
      expect(rows[1][6].toString(), '123.4');
      expect(rows[2][0].toString(), '7');
      expect(rows[2][6].toString(), '561.0');
    },
  );
}
