import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/widgets/map_search_popup.dart';

/// In-memory source/commit seam; journeys render the production popup and dialog.
class NaturalFeatureMappingHarness {
  NaturalFeatureMappingHarness({bool populated = false}) {
    repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage([if (populated) _feature(id: 1)]),
    );
    container = ProviderContainer(
      overrides: [
        naturalFeatureBootstrapEnabledProvider.overrideWithValue(true),
        naturalFeatureRepositoryProvider.overrideWithValue(repository),
        mappingStoreOperationCoordinatorProvider.overrideWithValue(operations),
      ],
    );
  }
  final operations = MappingStoreOperationCoordinator();
  final focus = FocusNode();
  late final NaturalFeatureRepository repository;
  late final ProviderContainer container;
  Completer<void>? pending;
  bool repaired = false;
  int reads = 0;

  Future<void> start(MappingStoreOperationKey key) async {
    try {
      await operations.run<void>(
        key: key,
        writerTables: const ['NaturalFeature'],
        action: () async {
          reads++;
          if (pending case final wait?) await wait.future;
          if (!repaired) {
            throw MappingStoreOperationException(
              paths: ['Features/features.json'],
              cause: const FormatException('Invalid source'),
            );
          }
          repository.save(
            _feature(
              id:
                  repository.findByOsmIdentity(osmType: 'node', osmId: 1)?.id ??
                  0,
            ),
          );
        },
      );
    } on MappingStoreOperationException {
      // The production coordinator retains the failure and original action.
    }
  }

  Widget get surface => Consumer(
    builder: (context, ref, _) {
      final availability = ref.watch(naturalFeatureAvailabilityProvider);
      return MapSearchPopup(
        focusNode: focus,
        searchResults: const [],
        isLoadingMore: false,
        isExhausted: true,
        searchQuery: '',
        trackDateRange: null,
        categories: const {MapSearchCategory.natural},
        selectedRegionKey: null,
        sort: MapSearchSort.nameAscending,
        group: MapSearchGroup.none,
        availableRegions: const [],
        onChanged: (_) {},
        onToggleCategory: (_) {},
        onSelectTrackDateRange: (_) {},
        onSelectRegionKey: (_) {},
        onSelectSort: (_) {},
        onSelectGroup: (_) {},
        onLoadMore: () {},
        onClose: () {},
        onSelectResult: (_) {},
        naturalFeaturesUnavailableReason: availability.reason,
        onRetryNaturalFeatures: availability.retryKey == null
            ? null
            : () => operations.retry(availability.retryKey!),
      );
    },
  );

  void dispose() {
    container.dispose();
    operations.dispose();
    focus.dispose();
  }
}

NaturalFeature _feature({int id = 0}) => NaturalFeature(
  id: id,
  name: 'Stored lake',
  tag: 'lake',
  latitude: -42,
  longitude: 146,
  osmType: 'node',
  osmId: 1,
);
