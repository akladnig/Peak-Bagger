import 'dart:io';

import 'package:csv/csv.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_source.dart';

class PeakCsvSource implements PeakSource {
  PeakCsvSource(this._peaks);

  final List<Peak> _peaks;

  static Future<PeakCsvSource> load(String csvPath) async {
    final contents = await File(csvPath).readAsString();
    final rows = const CsvDecoder().convert(contents);
    if (rows.isEmpty) {
      return PeakCsvSource(const []);
    }

    final header = rows.first.map((cell) => '$cell'.trim()).toList(growable: false);
    final columnIndex = <String, int>{
      for (var index = 0; index < header.length; index++) header[index]: index,
    };

    String cellAt(List<dynamic> row, String columnName) {
      final index = columnIndex[columnName];
      if (index == null || index >= row.length) {
        return '';
      }
      return '${row[index]}'.trim();
    }

    final peaks = <Peak>[];
    for (final row in rows.skip(1)) {
      final name = cellAt(row, 'Name');
      final latitude = double.tryParse(cellAt(row, 'Latitude'));
      final longitude = double.tryParse(cellAt(row, 'Longitude'));
      if (name.isEmpty || latitude == null || longitude == null) {
        continue;
      }

      peaks.add(
        Peak(
          osmId: int.tryParse(cellAt(row, 'osmId')) ?? 0,
          name: name,
          altName: cellAt(row, 'Alt Name'),
          elevation: double.tryParse(cellAt(row, 'Elevation')),
          latitude: latitude,
          longitude: longitude,
          region: cellAt(row, 'Region'),
          gridZoneDesignator: cellAt(row, 'Zone'),
          mgrs100kId: cellAt(row, 'mgrs100kId'),
          easting: cellAt(row, 'Easting'),
          northing: cellAt(row, 'Northing'),
          verified: cellAt(row, 'Verified').toLowerCase() == 'true',
        ),
      );
    }

    return PeakCsvSource(List<Peak>.unmodifiable(peaks));
  }

  @override
  List<Peak> getAllPeaks() => _peaks;
}
