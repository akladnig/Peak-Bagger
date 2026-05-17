import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/services/my_ascents_summary_service.dart';

void main() {
  const service = MyAscentsSummaryService();

  test('groups by year and sorts descending by date', () {
    final summary = service.build(
      MyAscentsDataset(
        baggedRows: [
          _bagged(1, peakId: 10, date: DateTime.utc(2026, 5, 15)),
          _bagged(2, peakId: 20, date: DateTime.utc(2025, 5, 15)),
          _bagged(3, peakId: 10, date: DateTime.utc(2026, 5, 14)),
          _bagged(4, peakId: 30, date: null),
        ],
        peaksByOsmId: {
          10: _peak(10, 'Alpha', elevation: 1234),
          20: _peak(20, 'Beta', elevation: 987.2),
        },
      ),
      ascending: false,
    );

    expect(summary.isEmpty, isFalse);
    expect(summary.sections, hasLength(2));
    expect(summary.sections.first.year, 2026);
    expect(summary.sections.first.rows.map((row) => row.baggedId), [1, 3]);
    expect(summary.sections.first.rows.first.dateText, 'Fri, 15 May 2026');
    expect(summary.sections.first.rows.first.elevationText, '1234 m');
    expect(summary.sections.last.year, 2025);
    expect(summary.sections.last.rows.single.peakName, 'Beta');
    expect(summary.sections.last.rows.single.elevationText, '987 m');
  });

  test('sorts ascending and keeps tie breaks deterministic', () {
    final summary = service.build(
      MyAscentsDataset(
        baggedRows: [
          _bagged(3, peakId: 30, date: DateTime.utc(2026, 5, 15)),
          _bagged(1, peakId: 10, date: DateTime.utc(2026, 5, 15)),
          _bagged(2, peakId: 20, date: DateTime.utc(2026, 5, 15)),
        ],
        peaksByOsmId: {
          10: _peak(10, 'Alpha'),
          20: _peak(20, 'Beta'),
          30: _peak(30, 'Alpha'),
        },
      ),
      ascending: true,
    );

    expect(summary.sections, hasLength(1));
    expect(summary.sections.single.rows.map((row) => row.baggedId), [1, 3, 2]);
  });

  test('skips null dates and falls back for missing peaks', () {
    final summary = service.build(
      MyAscentsDataset(
        baggedRows: [
          _bagged(1, peakId: 10, date: DateTime.utc(2026, 1, 1)),
          _bagged(2, peakId: 99, date: DateTime.utc(2026, 1, 2)),
          _bagged(3, peakId: 10, date: null),
        ],
        peaksByOsmId: {
          10: _peak(10, '', elevation: null),
        },
      ),
      ascending: false,
    );

    expect(summary.sections, hasLength(1));
    expect(summary.sections.single.rows, hasLength(2));
    expect(summary.sections.single.rows.last.peakName, 'Unknown Peak');
    expect(summary.sections.single.rows.last.elevationText, 'Unknown');
  });

  test('returns empty summary when every date is null', () {
    final summary = service.build(
      MyAscentsDataset(
        baggedRows: [
          _bagged(1, peakId: 10, date: null),
          _bagged(2, peakId: 20, date: null),
        ],
        peaksByOsmId: {
          10: _peak(10, 'Alpha'),
          20: _peak(20, 'Beta'),
        },
      ),
      ascending: false,
    );

    expect(summary.isEmpty, isTrue);
  });
}

PeaksBagged _bagged(
  int baggedId, {
  required int peakId,
  required DateTime? date,
}) {
  return PeaksBagged(
    baggedId: baggedId,
    peakId: peakId,
    gpxId: 100 + baggedId,
    date: date,
  );
}

Peak _peak(
  int osmId,
  String name, {
  double? elevation,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: -41,
    longitude: 146,
  );
}
