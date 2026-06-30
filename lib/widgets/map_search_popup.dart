import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/widgets/popup_shell.dart';
import '../models/map_search_result.dart';
import '../services/region_manifest_catalog.dart';
import '../theme.dart';
import 'map_search_results_list.dart';

class MapSearchPopup extends StatelessWidget {
  const MapSearchPopup({
    required this.focusNode,
    required this.searchResults,
    required this.searchQuery,
    required this.entityFilter,
    required this.selectedRegionKey,
    required this.sort,
    required this.availableRegions,
    required this.onChanged,
    required this.onSelectEntityFilter,
    required this.onSelectRegionKey,
    required this.onSelectSort,
    required this.onClose,
    required this.onSelectResult,
    super.key,
  });

  final FocusNode focusNode;
  final List<MapSearchResult> searchResults;
  final String searchQuery;
  final MapSearchEntityFilter entityFilter;
  final String? selectedRegionKey;
  final MapSearchSort sort;
  final List<RegionManifestRegionData> availableRegions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapSearchEntityFilter> onSelectEntityFilter;
  final ValueChanged<String?> onSelectRegionKey;
  final ValueChanged<MapSearchSort> onSelectSort;
  final VoidCallback onClose;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 680,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: PopupShell(
          key: const Key('map-search-popup'),
          title: const Text('Search'),
          onClose: onClose,
          closeButtonKey: const Key('map-search-close'),
          bodyFlexible: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('map-search-input'),
                focusNode: focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: onChanged,
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              thinDivider,
              const SizedBox(height: PopupUIConstants.actionSpacing),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-all'),
                    icon: Icons.language,
                    label: 'All',
                    isSelected: entityFilter == MapSearchEntityFilter.all,
                    onPressed: () =>
                        onSelectEntityFilter(MapSearchEntityFilter.all),
                  ),
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-peaks'),
                    icon: Icons.landscape,
                    label: 'Peaks',
                    isSelected: entityFilter == MapSearchEntityFilter.peaks,
                    onPressed: () =>
                        onSelectEntityFilter(MapSearchEntityFilter.peaks),
                  ),
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-tracks-routes'),
                    icon: Icons.hiking,
                    label: 'Tracks/Routes',
                    isSelected:
                        entityFilter == MapSearchEntityFilter.tracksRoutes,
                    onPressed: () => onSelectEntityFilter(
                      MapSearchEntityFilter.tracksRoutes,
                    ),
                  ),
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-natural'),
                    icon: Icons.forest,
                    label: 'Natural',
                    isSelected: false,
                    onPressed: null,
                  ),
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-roads'),
                    icon: Icons.directions_car,
                    label: 'Roads',
                    isSelected: false,
                    onPressed: null,
                  ),
                  _entityButton(
                    context,
                    key: const Key('map-search-entity-maps'),
                    icon: Icons.map,
                    label: 'Maps',
                    isSelected: entityFilter == MapSearchEntityFilter.maps,
                    onPressed: () =>
                        onSelectEntityFilter(MapSearchEntityFilter.maps),
                  ),
                  const SizedBox(height: 32, child: VerticalDivider()),
                  PopupMenuButton<String?>(
                    key: const Key('map-search-filter-button'),
                    onSelected: onSelectRegionKey,
                    itemBuilder: (context) => [
                      const PopupMenuItem<String?>(
                        key: Key('map-search-region-none'),
                        value: null,
                        child: Text('None'),
                      ),
                      ...availableRegions.map(
                        (region) => PopupMenuItem<String?>(
                          key: Key('map-search-region-${region.key}'),
                          value: region.key,
                          child: Text(region.name),
                        ),
                      ),
                    ],
                    child: _menuButton(
                      context,
                      key: const Key('map-search-filter-trigger'),
                      icon: Icons.filter_list,
                      label: _regionLabel(),
                    ),
                  ),
                  PopupMenuButton<MapSearchSort>(
                    key: const Key('map-search-sort-button'),
                    onSelected: onSelectSort,
                    itemBuilder: (context) => const [
                      PopupMenuItem<MapSearchSort>(
                        key: Key('map-search-sort-name-ascending'),
                        value: MapSearchSort.nameAscending,
                        child: Text('Name ascending'),
                      ),
                      PopupMenuItem<MapSearchSort>(
                        key: Key('map-search-sort-name-descending'),
                        value: MapSearchSort.nameDescending,
                        child: Text('Name descending'),
                      ),
                    ],
                    child: _menuButton(
                      context,
                      key: const Key('map-search-sort-trigger'),
                      icon: Icons.sort,
                      label: sort == MapSearchSort.nameAscending
                          ? 'Sort A-Z'
                          : 'Sort Z-A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              Text('Results', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: PopupUIConstants.headerSpacing),
              Expanded(
                child: MapSearchResultsList(
                  searchResults: searchResults,
                  searchQuery: searchQuery,
                  onSelectResult: onSelectResult,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entityButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback? onPressed,
  }) {
    final selectedStyle = Theme.of(
      context,
    ).extension<SelectedButtonThemeData>()?.style;
    return OutlinedButton.icon(
      key: key,
      style: isSelected ? selectedStyle : null,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
  }) {
    final style = Theme.of(context).extension<SelectedButtonThemeData>()?.style;
    return IgnorePointer(
      child: OutlinedButton.icon(
        key: key,
        style: style,
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  String _regionLabel() {
    if (selectedRegionKey == null) {
      return 'Filter';
    }
    for (final region in availableRegions) {
      if (region.key == selectedRegionKey) {
        return region.name;
      }
    }
    return 'Filter';
  }
}
