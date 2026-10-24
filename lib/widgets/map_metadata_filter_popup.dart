import 'package:flutter/material.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

import '../core/widgets/popup_shell.dart';
import 'shared_dropdown.dart';

class MapMetadataFilterPopup extends StatelessWidget {
  const MapMetadataFilterPopup({
    required this.ratingFilter,
    required this.difficultyFilter,
    required this.durationFilter,
    required this.difficultyOptions,
    required this.onSelectRatingFilter,
    required this.onSelectDifficultyFilter,
    required this.onSelectDurationFilter,
    required this.onClearFilters,
    required this.onClose,
    super.key,
  });

  final PeakRatingFilterOption ratingFilter;
  final PeakDifficultyFilterOption? difficultyFilter;
  final PeakDurationFilterOption durationFilter;
  final List<PeakDifficultyFilterOption> difficultyOptions;
  final ValueChanged<PeakRatingFilterOption> onSelectRatingFilter;
  final ValueChanged<PeakDifficultyFilterOption?> onSelectDifficultyFilter;
  final ValueChanged<PeakDurationFilterOption> onSelectDurationFilter;
  final VoidCallback onClearFilters;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final visibleRegions = difficultyOptions
        .map((option) => option.region)
        .toSet()
        .length;
    final retained = difficultyFilter;
    final stale = retained != null && !difficultyOptions.contains(retained);
    String? currentRegion;
    final difficulties = <SharedDropdownChoice<PeakDifficultyFilterOption?>>[
      const SharedDropdownChoice(value: null, label: 'Any'),
      if (stale)
        SharedDropdownChoice(
          key: const Key('map-metadata-filter-difficulty-unavailable'),
          value: retained,
          label:
              '${_difficultyOptionLabel(retained, showRegionContext: true)} — unavailable for this list',
          enabled: false,
        ),
    ];
    for (final option in difficultyOptions) {
      final startsGroup = currentRegion != option.region;
      currentRegion = option.region;
      difficulties.add(
        SharedDropdownChoice(
          key: Key(
            'map-metadata-filter-difficulty-option-${_difficultyOptionKeySuffix(option)}',
          ),
          value: option,
          label: _difficultyOptionLabel(
            option,
            showRegionContext: visibleRegions > 1,
          ),
          groupLabel: startsGroup
              ? formatRegionDisplayName(option.region)
              : null,
          groupKey: startsGroup
              ? Key('map-metadata-filter-difficulty-group-${option.region}')
              : null,
        ),
      );
    }
    return PopupShell(
      key: const Key('map-metadata-filter-popup'),
      title: const Text('Filter'),
      onClose: onClose,
      closeButtonKey: const Key('map-metadata-filter-close'),
      bodyFlexible: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            KeyedSubtree(
              key: const Key('map-metadata-filter-row-rating'),
              child: SharedDropdown<PeakRatingFilterOption>(
                key: const Key('map-metadata-filter-rating-trigger'),
                label: 'Rating',
                value: ratingFilter,
                choices: [
                  for (final option in PeakRatingFilterOption.values)
                    SharedDropdownChoice(
                      key: Key(
                        'map-metadata-filter-rating-option-${option.label}',
                      ),
                      value: option,
                      label: option == PeakRatingFilterOption.any
                          ? 'Any'
                          : '${option.label}+',
                      semanticLabel: option == PeakRatingFilterOption.any
                          ? 'Any rating'
                          : 'Rating at least ${option.label} out of 5',
                    ),
                ],
                onSelected: onSelectRatingFilter,
              ),
            ),
            KeyedSubtree(
              key: const Key('map-metadata-filter-row-difficulty'),
              child: SharedDropdown<PeakDifficultyFilterOption?>(
                key: const Key('map-metadata-filter-difficulty-trigger'),
                label: 'Difficulty',
                value: difficultyFilter,
                choices: difficulties,
                onSelected: onSelectDifficultyFilter,
              ),
            ),
            KeyedSubtree(
              key: const Key('map-metadata-filter-row-duration'),
              child: SharedDropdown<PeakDurationFilterOption>(
                key: const Key('map-metadata-filter-duration-trigger'),
                label: 'Duration',
                value: durationFilter,
                choices: [
                  for (final option in PeakDurationFilterOption.values)
                    SharedDropdownChoice(
                      key: Key(
                        'map-metadata-filter-duration-option-${option.label}',
                      ),
                      value: option,
                      label: option.label,
                    ),
                ],
                onSelected: onSelectDurationFilter,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('map-metadata-filter-clear'),
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _difficultyOptionKeySuffix(PeakDifficultyFilterOption option) {
  final normalized = option.difficulty.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  return '${option.region}-$normalized';
}

String _difficultyOptionLabel(
  PeakDifficultyFilterOption option, {
  required bool showRegionContext,
}) => showRegionContext
    ? '${option.difficulty} (${formatRegionDisplayName(option.region)})'
    : option.difficulty;
