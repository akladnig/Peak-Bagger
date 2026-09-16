import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/track_name_normalisation.dart';

void main() {
  test('removes a terminal hyphenated calendar-date suffix', () {
    expect(normaliseTrackName('MtAnne10-03-2025'), 'MtAnne');
  });

  test('removes a parenthesised terminal calendar-date suffix and whitespace', () {
    expect(normaliseTrackName('Mt Anne (10-03-2025)   '), 'Mt Anne');
  });

  test('removes every supported terminal suffix form', () {
    expect(normaliseTrackName('Mt Anne10/03/2025'), 'Mt Anne');
    expect(normaliseTrackName('Mt Anne (10/03/2025)'), 'Mt Anne');
    expect(normaliseTrackName('Mt Anne ---__ 10-03-2025'), 'Mt Anne');
    expect(normaliseTrackName('Mt Anne\t_\n10/03/2025   '), 'Mt Anne');
  });

  test('validates leap years and calendar dates', () {
    expect(normaliseTrackName('Leap 29-02-2024'), 'Leap');
    expect(normaliseTrackName('Leap 29-02-2025'), 'Leap 29-02-2025');
    expect(normaliseTrackName('Mt Anne 31-02-2025'), 'Mt Anne 31-02-2025');
    expect(normaliseTrackName('Mt Anne 00-03-2025'), 'Mt Anne 00-03-2025');
  });

  test('leaves unsupported and non-terminal dates unchanged', () {
    expect(normaliseTrackName('Mt Anne'), 'Mt Anne');
    expect(normaliseTrackName('Mt Anne 10-03-2025 circuit'), 'Mt Anne 10-03-2025 circuit');
    expect(normaliseTrackName('Mt Anne 2025'), 'Mt Anne 2025');
    expect(normaliseTrackName('10-03-2025'), '10-03-2025');
    expect(normaliseTrackName('Mt Anne 1-03-2025'), 'Mt Anne 1-03-2025');
    expect(normaliseTrackName('Mt Anne 10.03.2025'), 'Mt Anne 10.03.2025');
  });

  test('does not depend on or modify a track date', () {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Mt Anne 10-03-2025',
      trackDate: DateTime.utc(2024, 1, 1),
    );

    expect(normaliseTrackName(track.trackName), 'Mt Anne');
    expect(track.trackDate, DateTime.utc(2024, 1, 1));
  });
}
