import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/widgets/popup_shell.dart';
import '../models/map_search_result.dart';
import '../services/region_manifest_catalog.dart';
import '../theme.dart';
import 'map_search_results_list.dart';

const _noRegionSelection = '__map_search_no_region__';
const _minimumPopupWidth = 320.0;

class MapSearchPopup extends StatefulWidget {
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
  State<MapSearchPopup> createState() => _MapSearchPopupState();
}

class _MapSearchPopupState extends State<MapSearchPopup> {
  final _controlsKey = GlobalKey();
  double? _popupWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePopupWidth());
  }

  @override
  void didUpdateWidget(covariant MapSearchPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePopupWidth());
  }

  void _updatePopupWidth() {
    if (!mounted) {
      return;
    }
    final controlsContext = _controlsKey.currentContext;
    if (controlsContext == null) {
      return;
    }
    final renderBox = controlsContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    final measuredControlsWidth = renderBox.size.width;
    final maxWidth = math.max(
      _minimumPopupWidth,
      MediaQuery.sizeOf(context).width - 32,
    );
    final nextWidth =
        (measuredControlsWidth + (PopupUIConstants.surfacePadding * 2)).clamp(
          _minimumPopupWidth,
          maxWidth,
        );
    if (_popupWidth == nextWidth) {
      return;
    }
    setState(() {
      _popupWidth = nextWidth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.max(
      _minimumPopupWidth,
      MediaQuery.sizeOf(context).width - 32,
    );
    final initialWidth = math.min(maxWidth, 1000.0);

    return SizedBox(
      width: _popupWidth ?? initialWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: PopupShell(
          key: const Key('map-search-popup'),
          title: const Text('Search'),
          onClose: widget.onClose,
          closeButtonKey: const Key('map-search-close'),
          bodyFlexible: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('map-search-input'),
                focusNode: widget.focusNode,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  labelStyle: TextStyle(fontSize: searchControlFontSize),
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search, size: searchControlIconSize),
                ),
                onChanged: widget.onChanged,
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              thinDivider,
              const SizedBox(height: PopupUIConstants.actionSpacing),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  key: _controlsKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-all'),
                      icon: Icons.language,
                      label: 'All',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.all,
                      onPressed: () => widget.onSelectEntityFilter(
                        MapSearchEntityFilter.all,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-peaks'),
                      icon: Icons.landscape,
                      label: 'Peaks',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.peaks,
                      onPressed: () => widget.onSelectEntityFilter(
                        MapSearchEntityFilter.peaks,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-tracks-routes'),
                      icon: Icons.hiking,
                      label: 'Tracks/Routes',
                      isSelected:
                          widget.entityFilter ==
                          MapSearchEntityFilter.tracksRoutes,
                      onPressed: () => widget.onSelectEntityFilter(
                        MapSearchEntityFilter.tracksRoutes,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-natural'),
                      icon: Icons.forest,
                      label: 'Natural',
                      isSelected: false,
                      onPressed: null,
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-roads'),
                      icon: Icons.directions_car,
                      label: 'Roads',
                      isSelected: false,
                      onPressed: null,
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-maps'),
                      icon: Icons.map,
                      label: 'Maps',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.maps,
                      onPressed: () => widget.onSelectEntityFilter(
                        MapSearchEntityFilter.maps,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(height: 32, child: VerticalDivider()),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      key: const Key('map-search-filter-button'),
                      onSelected: (value) {
                        widget.onSelectRegionKey(
                          value == _noRegionSelection ? null : value,
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem<String>(
                          key: Key('map-search-region-none'),
                          value: _noRegionSelection,
                          child: Text('None'),
                        ),
                        ...widget.availableRegions.map(
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
                        isSelected: widget.selectedRegionKey != null,
                        label: _regionLabel(),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<MapSearchSort>(
                      key: const Key('map-search-sort-button'),
                      onSelected: widget.onSelectSort,
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
                        label: widget.sort == MapSearchSort.nameAscending
                            ? 'Sort A-Z'
                            : 'Sort Z-A',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<MapSearchGroup>(
                      key: const Key('map-search-group-button'),
                      onSelected: widget.onSelectGroup,
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
                        isSelected: widget.group != MapSearchGroup.none,
                        label: switch (widget.group) {
                          MapSearchGroup.none => 'Group',
                          MapSearchGroup.region => 'Group Region',
                          MapSearchGroup.type => 'Group Type',
                        },
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              Text('Results', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: PopupUIConstants.headerSpacing),
              Expanded(
                child: MapSearchResultsList(
                  searchResults: widget.searchResults,
                  searchQuery: widget.searchQuery,
                  sort: widget.sort,
                  group: widget.group,
                  onSelectResult: widget.onSelectResult,
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
    if (widget.selectedRegionKey == null) {
      return 'Filter';
    }
    for (final region in widget.availableRegions) {
      if (region.key == widget.selectedRegionKey) {
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
