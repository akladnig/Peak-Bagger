import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';

/// Remains on the selection surface even after the shared dialog is dismissed.
class MapSelectionMappingUnavailable extends ConsumerWidget {
  const MapSelectionMappingUnavailable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final polygons = ref.watch(polygonDisplayStateProvider);
    final mapReason = ref.watch(
      mapProvider.select((state) => state.mapSelectionMappingUnavailableReason),
    );
    final reasons = [
      ?mapReason,
      if (polygons.unavailableReason != null) polygons.unavailableReason!,
    ];
    if (reasons.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('map-selection-mapping-unavailable'),
      child: SizedBox(
        width: 320,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(child: Text(reasons.join('\n'))),
              ),
              TextButton(
                key: const Key('map-selection-mapping-unavailable-retry'),
                onPressed: polygons.pending.isNotEmpty
                    ? null
                    : () async {
                        if (mapReason != null) {
                          await ref
                              .read(mapProvider.notifier)
                              .retryMapSelectionMapping();
                        }
                        if (context.mounted) {
                          await ref
                              .read(polygonDisplayStateProvider.notifier)
                              .retryUnavailable();
                        }
                      },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
