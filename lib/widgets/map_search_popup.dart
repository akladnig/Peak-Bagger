import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/widgets/popup_shell.dart';
import '../models/map_search_result.dart';
import '../services/region_manifest_catalog.dart';
import '../theme.dart';
import 'map_search_results_list.dart';

const _noRegionSelection = '__map_search_no_region__';

class MapSearchPopup extends StatelessWidget {
  const MapSearchPopup({
    required this.focusNode,
    required this.searchResults,
    required this.searchQuery,
    required this.entityFilter,
    required this.selectedRegionKey,
    required this.sort,
    required this.group,
    required this.availableRegions,
    required this.onChanged,
    required this.onSelectEntityFilter,
    required this.onSelectRegionKey,
    required this.onSelectSort,
    required this.onSelectGroup,
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
  final MapSearchGroup group;
  final List<RegionManifestRegionData> availableRegions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapSearchEntityFilter> onSelectEntityFilter;
  final ValueChanged<String?> onSelectRegionKey;
  final ValueChanged<MapSearchSort> onSelectSort;
  final ValueChanged<MapSearchGroup> onSelectGroup;
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
                  labelStyle: TextStyle(fontSize: searchControlFontSize),
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: searchControlIconSize),
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
                  PopupMenuButton<String>(
                    key: const Key('map-search-filter-button'),
                    onSelected: (value) {
                      onSelectRegionKey(
                        value == _noRegionSelection ? null : value,
                      );
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        key: Key('map-search-region-none'),
                        value: _noRegionSelection,
                        child: Text('None'),
                      ),
                      ...availableRegions.map(
                        (region) => PopupMenuItem<String>(
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
                      isSelected: selectedRegionKey != null,
                      label: _regionLabel(),
                      compact: true,
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
                      isSelected: true,
                      label: sort == MapSearchSort.nameAscending
                          ? 'Sort A-Z'
                          : 'Sort Z-A',
                      compact: true,
                    ),
                  ),
                  PopupMenuButton<MapSearchGroup>(
                    key: const Key('map-search-group-button'),
                    onSelected: onSelectGroup,
                    itemBuilder: (context) => const [
                      PopupMenuItem<MapSearchGroup>(
                        key: Key('map-search-group-none'),
                        value: MapSearchGroup.none,
                        child: Text('None'),
                      ),
                      PopupMenuItem<MapSearchGroup>(
                        key: Key('map-search-group-region'),
                        value: MapSearchGroup.region,
                        child: Text('Region'),
                      ),
                      PopupMenuItem<MapSearchGroup>(
                        key: Key('map-search-group-type'),
                        value: MapSearchGroup.type,
                        child: Text('Type'),
                      ),
                    ],
                    child: _menuButton(
                      context,
                      key: const Key('map-search-group-trigger'),
                      icon: Icons.layers,
                      isSelected: group != MapSearchGroup.none,
                      label: switch (group) {
                        MapSearchGroup.none => 'Group',
                        MapSearchGroup.region => 'Group Region',
                        MapSearchGroup.type => 'Group Type',
                      },
                      compact: true,
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
                  sort: sort,
                  group: group,
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
    final searchButtonTheme = Theme.of(
      context,
    ).extension<SearchButtonThemeData>();
    return OutlinedButton.icon(
      key: key,
      style: searchButtonTheme?.styleFor(isSelected),
      onPressed: onPressed,
      icon: Icon(icon, size: searchControlIconSize),
      label: Text(
        label,
        style: const TextStyle(fontSize: searchControlFontSize),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required bool isSelected,
    required String label,
    bool compact = false,
  }) {
      return _SearchMenuButton(
        key: key,
        icon: icon,
        iconSize: compact ? searchControlIconSize : null,
        label: label,
        labelStyle: compact
          ? const TextStyle(fontSize: searchControlFontSize)
          : null,
      style: Theme.of(
        context,
      ).extension<SearchButtonThemeData>()?.styleFor(isSelected),
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

class _SearchMenuButton extends StatefulWidget {
  const _SearchMenuButton({
    required this.icon,
    required this.label,
    this.iconSize,
    this.labelStyle,
    this.style,
    super.key,
  });

  final IconData icon;
  final String label;
  final double? iconSize;
  final TextStyle? labelStyle;
  final ButtonStyle? style;

  @override
  State<_SearchMenuButton> createState() => _SearchMenuButtonState();
}

class _SearchMenuButtonState extends State<_SearchMenuButton> {
  late final WidgetStatesController _statesController;

  @override
  void initState() {
    super.initState();
    _statesController = WidgetStatesController();
  }

  @override
  void dispose() {
    _statesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _statesController.update(WidgetState.hovered, true),
      onExit: (_) => _statesController.update(WidgetState.hovered, false),
      child: IgnorePointer(
        child: OutlinedButton.icon(
          statesController: _statesController,
          style: widget.style,
          onPressed: () {},
          icon: Icon(widget.icon, size: widget.iconSize),
          label: Text(widget.label, style: widget.labelStyle),
        ),
      ),
    );
  }
}
