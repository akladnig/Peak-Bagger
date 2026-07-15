import 'package:flutter/material.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

import '../core/widgets/popup_shell.dart';

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
    final theme = Theme.of(context);
    final visibleRegions = difficultyOptions
        .map((option) => option.region)
        .toSet()
        .length;
    final selectedDifficultyIsStale =
        difficultyFilter != null &&
        !difficultyOptions.contains(difficultyFilter);
    final difficultyMenuEntries = <PopupMenuEntry<PeakDifficultyFilterOption?>>[
      const PopupMenuItem<PeakDifficultyFilterOption?>(
        value: null,
        child: Text('Any'),
      ),
    ];

    String? currentRegion;
    for (final option in difficultyOptions) {
      if (option.region != currentRegion) {
        currentRegion = option.region;
        difficultyMenuEntries.add(
          PopupMenuItem<PeakDifficultyFilterOption?>(
            key: Key('map-metadata-filter-difficulty-group-${option.region}'),
            enabled: false,
            child: Text(
              formatRegionDisplayName(option.region),
              style: theme.textTheme.labelMedium,
            ),
          ),
        );
      }
      difficultyMenuEntries.add(
        PopupMenuItem<PeakDifficultyFilterOption?>(
          key: Key(
            'map-metadata-filter-difficulty-option-${_difficultyOptionKeySuffix(option)}',
          ),
          value: option,
          child: Text(
            _difficultyOptionLabel(
              option,
              showRegionContext: visibleRegions > 1,
            ),
          ),
        ),
      );
    }

    return PopupShell(
      key: const Key('map-metadata-filter-popup'),
      title: const Text('Filter'),
      onClose: onClose,
      closeButtonKey: const Key('map-metadata-filter-close'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          _FilterRowContainer(
            key: const Key('map-metadata-filter-row-rating'),
            label: 'Rating',
            control: PopupMenuButton<PeakRatingFilterOption>(
              key: const Key('map-metadata-filter-rating-trigger'),
              tooltip: 'Select rating filter',
              initialValue: ratingFilter,
              onSelected: onSelectRatingFilter,
              itemBuilder: (context) => [
                for (final option in PeakRatingFilterOption.values)
                  PopupMenuItem<PeakRatingFilterOption>(
                    key: Key(
                      'map-metadata-filter-rating-option-${option.label}',
                    ),
                    value: option,
                    child: option == PeakRatingFilterOption.any
                        ? const Text('Any')
                        : _RatingOptionLabel(label: option.label),
                  ),
              ],
              child: _DropdownTrigger(
                label: ratingFilter == PeakRatingFilterOption.any
                    ? const Text('Any')
                    : _RatingOptionLabel(label: ratingFilter.label),
              ),
            ),
          ),
          _FilterRowContainer(
            key: const Key('map-metadata-filter-row-difficulty'),
            label: 'Difficulty',
            control: PopupMenuButton<PeakDifficultyFilterOption?>(
              key: const Key('map-metadata-filter-difficulty-trigger'),
              tooltip: 'Select difficulty filter',
              initialValue: difficultyOptions.contains(difficultyFilter)
                  ? difficultyFilter
                  : null,
              onSelected: onSelectDifficultyFilter,
              itemBuilder: (context) => difficultyMenuEntries,
              child: _DropdownTrigger(
                label: Text(
                  difficultyFilter == null
                      ? 'Any'
                      : _difficultyOptionLabel(
                          difficultyFilter!,
                          showRegionContext:
                              visibleRegions > 1 || selectedDifficultyIsStale,
                        ),
                ),
              ),
            ),
          ),
          _FilterRowContainer(
            key: const Key('map-metadata-filter-row-duration'),
            label: 'Duration',
            control: PopupMenuButton<PeakDurationFilterOption>(
              key: const Key('map-metadata-filter-duration-trigger'),
              tooltip: 'Select duration filter',
              initialValue: durationFilter,
              onSelected: onSelectDurationFilter,
              itemBuilder: (context) => [
                for (final option in PeakDurationFilterOption.values)
                  PopupMenuItem<PeakDurationFilterOption>(
                    key: Key(
                      'map-metadata-filter-duration-option-${option.label}',
                    ),
                    value: option,
                    child: Text(option.label),
                  ),
              ],
              child: _DropdownTrigger(label: Text(durationFilter.label)),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('map-metadata-filter-clear'),
              onPressed: onClearFilters,
              child: const Text('Clear filters'),
            ),
          ),
        ],
      ),
    );
  }
}

String _difficultyOptionKeySuffix(PeakDifficultyFilterOption option) {
  final normalizedDifficulty = option.difficulty.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  return '${option.region}-$normalizedDifficulty';
}

class _FilterRowContainer extends StatelessWidget {
  const _FilterRowContainer({
    required this.label,
    required this.control,
    super.key,
  });

  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          const SizedBox(width: 12),
          Flexible(child: control),
        ],
      ),
    );
  }
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({required this.label});

  final Widget label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

class _RatingOptionLabel extends StatelessWidget {
  const _RatingOptionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final roundedRating = double.parse(label);
    final fullStarCount = roundedRating.floor();
    final hasHalfStar = roundedRating - fullStarCount >= 0.5;
    final filledStarColor = Colors.amber;
    final emptyStarColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      label: '$label out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (var index = 0; index < 5; index++)
              Icon(
                index < fullStarCount
                    ? Icons.star
                    : index == fullStarCount && hasHalfStar
                    ? Icons.star_half
                    : Icons.star_border,
                size: 14,
                color:
                    index < fullStarCount ||
                        (index == fullStarCount && hasHalfStar)
                    ? filledStarColor
                    : emptyStarColor,
              ),
          ],
        ),
      ),
    );
  }
}

String _difficultyOptionLabel(
  PeakDifficultyFilterOption option, {
  required bool showRegionContext,
}) {
  if (!showRegionContext) {
    return option.difficulty;
  }

  return '${option.difficulty} (${formatRegionDisplayName(option.region)})';
}
