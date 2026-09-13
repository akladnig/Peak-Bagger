import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/local_topo_overlay_outage_provider.dart';
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';

void main() {
  test('publishes a deduplicated overlay outage message', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final messages = <String>[];
    final subscription = container
        .read(localTopoOverlayOutageReporterProvider)
        .messages
        .listen(messages.add);
    addTearDown(subscription.cancel);

    final reporter = container.read(localTopoOverlayOutageReporterProvider);
    reporter.report(terrainReliefShadingOverlayKey);
    reporter.report(terrainReliefShadingOverlayKey);
    await Future<void>.delayed(Duration.zero);

    expect(messages, [
      'Terrain relief shading is unavailable from the local tile server',
    ]);
  });
}
