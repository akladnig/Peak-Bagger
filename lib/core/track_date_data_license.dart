import 'package:flutter/foundation.dart';

/// Flutter collects the packages' MIT/BSD code licenses automatically. Their
/// separately licensed embedded geographic database also needs this notice.
void registerTrackDateDataLicense() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['timezone_finder boundary data (Timezone Boundary Builder 2026e)'],
      'Time zone boundary data © OpenStreetMap contributors, available under '
      'the Open Database License (ODbL). Boundaries built by Timezone Boundary '
      'Builder (https://github.com/evansiroky/timezone-boundary-builder).\n\n'
      'Open Database License v1.0: '
      'https://opendatacommons.org/licenses/odbl/1-0/\n'
      'OpenStreetMap: https://www.openstreetmap.org/copyright\n'
      'The embedded derivative database is distributed by timezone_finder '
      '1.0.0 under ODbL v1.0: https://pub.dev/packages/timezone_finder/versions/1.0.0\n'
      'Publicly distributed adaptations must also be offered under ODbL. '
      'No technological restrictions may limit use of the database.',
    );
  });
}
