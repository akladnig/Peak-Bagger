import 'dart:io';
import 'package:csv/csv.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

class CsvImporter {
  static Future<List<Tasmap50k>> importFromCsv(String csvPath) async {
    final file = File(csvPath);
    final contents = await file.readAsString();

    final rows = const CsvToListConverter().convert(contents);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final maps = <Tasmap50k>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final map = _parseRow(headers, row);
      if (map != null) {
        maps.add(map);
      }
    }

    return maps;
  }

  static Tasmap50k? _parseRow(List<String> headers, List<dynamic> row) {
    if (row.length < headers.length) return null;

    final data = <String, dynamic>{};
    for (var i = 0; i < headers.length; i++) {
      data[headers[i]] = i < row.length ? row[i] : '';
    }

    final series = data['Series']?.toString().trim() ?? '';
    final name = data['Name']?.toString().trim() ?? '';
    if (series.isEmpty || name.isEmpty) return null;

    return Tasmap50k(
      series: series,
      name: name,
      parentSeries: data['Parent']?.toString().trim() ?? '',
      mgrs100kIds: data['MGRS']?.toString().trim() ?? '',
      eastingMin: int.tryParse(data['Xmin']?.toString().trim() ?? '') ?? 0,
      eastingMax: int.tryParse(data['Xmax']?.toString().trim() ?? '') ?? 0,
      northingMin: int.tryParse(data['Ymin']?.toString().trim() ?? '') ?? 0,
      northingMax: int.tryParse(data['Ymax']?.toString().trim() ?? '') ?? 0,
    );
  }
}
