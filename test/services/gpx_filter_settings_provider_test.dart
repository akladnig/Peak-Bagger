import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('round-trips disabled and enabled GPX filter selections', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final config = GpxFilterConfig.defaults.copyWith(
      outlierFilter: GpxTrackOutlierFilter.none,
      elevationSmoother: GpxTrackElevationSmoother.none,
      positionSmoother: GpxTrackPositionSmoother.none,
    );

    await config.save(prefs);

    final restored = GpxFilterConfig.fromPreferences(prefs);

    expect(restored.outlierFilter, GpxTrackOutlierFilter.none);
    expect(restored.elevationSmoother, GpxTrackElevationSmoother.none);
    expect(restored.positionSmoother, GpxTrackPositionSmoother.none);
    expect(restored.hampelWindow, GpxFilterConfig.defaults.hampelWindow);
    expect(
      restored.elevationWindow,
      GpxFilterConfig.defaults.elevationWindow,
    );
    expect(restored.positionWindow, GpxFilterConfig.defaults.positionWindow);
  });
}
