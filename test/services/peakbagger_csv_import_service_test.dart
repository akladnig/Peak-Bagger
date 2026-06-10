import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peakbagger_csv_import_service.dart';

void main() {
  test('parses pid from url and adds sync columns', () {
    final service = PeakBaggerCsvImportService();
    final document = service.parse('''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''');

    expect(service.peakbaggerPidForRow(document, 0), 74023);
    expect(document.headerIndexOf('PeakBagger PID'), isNotNull);
    expect(document.headerIndexOf('Latitude'), isNotNull);
    expect(document.headerIndexOf('Longitude'), isNotNull);
    expect(document.headerIndexOf('note'), isNotNull);
    expect(document.headerIndexOf('osmId'), isNotNull);

    service.setSyncColumns(
      document,
      0,
      peakbaggerPid: 74023,
      latitude: -41.5,
      longitude: 146.5,
      osmId: -1,
      note: 'matched via strong-name fallback',
    );

    final csv = service.write(document);
    expect(csv, contains('74023'));
    expect(csv, contains('-41.5'));
    expect(csv, contains('146.5'));
    expect(csv, contains('matched via strong-name fallback'));

    service.setSyncColumns(document, 0, note: '');
    expect(service.write(document), isNot(contains('matched via strong-name fallback')));
  });

  test('falls back to State/Prov when region header differs', () {
    final service = PeakBaggerCsvImportService();
    final document = service.parse('''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''');

    expect(service.regionKeyForRow(document, 0), 'Tasmania');
  });

  test('inserts sync columns before CRLF row endings', () {
    final service = PeakBaggerCsvImportService();
    final document = service.parse(
      'Peak,Elev-M,Prom-M,Country,Region,County,Range,Url\r\n'
      'Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023\r\n',
    );

    service.setSyncColumns(
      document,
      0,
      peakbaggerPid: 74023,
      latitude: -41.5,
      longitude: 146.5,
      osmId: -1,
      note: 'ok',
    );

    final csv = service.write(document);
    final lines = csv.trimRight().split('\n');

    expect(lines, hasLength(2));
    expect(lines.first, contains('Url,PeakBagger PID,Latitude,Longitude,note,osmId'));
    expect(lines.last, contains('peak.aspx?pid=74023,74023,-41.5,146.5,ok,-1'));
  });
}
