import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';

import '../core/constants.dart';
import '../core/widgets/popup_shell.dart';
import '../models/map_search_result.dart';
import '../theme.dart';
import 'map_search_results_list.dart';
import 'shared_dropdown.dart';
import 'shared_field_decoration.dart';

const _noRegionSelection = '__map_search_no_region__';
const _minimumPopupWidth = 320.0;

class MapSearchPopup extends StatefulWidget {
  const MapSearchPopup({
    required this.focusNode,
    required this.searchResults,
    required this.isLoadingMore,
    required this.isExhausted,
    required this.searchQuery,
    required this.trackDateRange,
    required this.categories,
    required this.selectedRegionKey,
    required this.sort,
    required this.group,
    required this.availableRegions,
    required this.onChanged,
    required this.onToggleCategory,
    required this.onSelectTrackDateRange,
    required this.onSelectRegionKey,
    required this.onSelectSort,
    required this.onSelectGroup,
    required this.onLoadMore,
    required this.onClose,
    required this.onSelectResult,
    this.mappingUnavailableReason,
    this.onRetryMapping,
    this.naturalFeaturesUnavailableReason,
    this.onRetryNaturalFeatures,
    this.clock = DateTime.now,
    this.isInteractionAllowed,
    this.enabled = true,
    super.key,
  });

  final FocusNode focusNode;
  final List<MapSearchResult> searchResults;
  final bool isLoadingMore;
  final bool isExhausted;
  final String searchQuery;
  final TrackDateRange? trackDateRange;
  final Set<MapSearchCategory> categories;
  final String? selectedRegionKey;
  final MapSearchSort sort;
  final MapSearchGroup group;
  final List<MapSearchRegionOption> availableRegions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapSearchCategory> onToggleCategory;
  final ValueChanged<TrackDateRange?> onSelectTrackDateRange;
  final ValueChanged<String?> onSelectRegionKey;
  final ValueChanged<MapSearchSort> onSelectSort;
  final ValueChanged<MapSearchGroup> onSelectGroup;
  final VoidCallback onLoadMore;
  final VoidCallback onClose;
  final ValueChanged<MapSearchResult> onSelectResult;
  final String? mappingUnavailableReason;
  final VoidCallback? onRetryMapping;
  final String? naturalFeaturesUnavailableReason;
  final VoidCallback? onRetryNaturalFeatures;
  final DateTime Function() clock;
  final bool Function()? isInteractionAllowed;
  final bool enabled;

  @override
  State<MapSearchPopup> createState() => MapSearchPopupState();
}

class MapSearchPopupState extends State<MapSearchPopup> {
  static const _searchDebounceDuration = Duration(milliseconds: 180);
  static final _pickerTapRegionGroup = Object();

  final _controlsKey = GlobalKey();
  final _queryController = TextEditingController();
  final _dateTriggerFocusNode = FocusNode();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _startDateFocusNode = FocusNode();
  Timer? _searchDebounceTimer;
  double? _popupWidth;
  String _pendingQuery = '';
  bool _hasTypedTrackDateRange = false;
  bool _isDateQueryInvalid = false;
  bool _isPickerOpen = false;
  bool _shouldAutofocusSearchInput = true;
  final _regionMenu = MenuController();
  final _sortMenu = MenuController();
  final _groupMenu = MenuController();
  final _startMonthMenu = MenuController();
  final _endMonthMenu = MenuController();
  bool _menuDismissedThisTurn = false;

  bool get _hasOpenMenu => [
    _regionMenu,
    _sortMenu,
    _groupMenu,
    _startMonthMenu,
    _endMonthMenu,
  ].any((menu) => menu.isOpen);
  String? _startDateError;
  String? _endDateError;
  TrackCalendarDay? _draftStart;
  TrackCalendarDay? _draftEnd;
  late DateTime _startCalendarMonth;
  late DateTime _endCalendarMonth;

  bool get _allowed =>
      mounted &&
      widget.enabled &&
      (widget.isInteractionAllowed?.call() ?? true) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  /// Select the raw query, never the parsed/debounced provider projection.
  void focusSearch() {
    if (!_allowed ||
        _isPickerOpen ||
        _hasOpenMenu ||
        !widget.focusNode.canRequestFocus) {
      return;
    }
    widget.focusNode.requestFocus();
    _queryController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _queryController.text.length,
    );
  }

  void _menuClosed(SharedDropdownCloseReason _) {
    // TapRegion callbacks can run after the menu's consumed outside gesture
    // already closed it. Keep that same event from dismissing the picker too.
    _menuDismissedThisTurn = true;
    scheduleMicrotask(() => _menuDismissedThisTurn = false);
  }

  @override
  void initState() {
    super.initState();
    _pendingQuery = widget.searchQuery;
    _queryController.text = widget.searchQuery;
    final fallbackMonth = _monthFor(null, fallback: widget.clock);
    _startCalendarMonth = fallbackMonth;
    _endCalendarMonth = fallbackMonth;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePopupWidth();
      if (_allowed && !_isPickerOpen) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MapSearchPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery.isEmpty) {
      _pendingQuery = widget.searchQuery;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePopupWidth());
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _queryController.dispose();
    _dateTriggerFocusNode.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startDateFocusNode.dispose();
    super.dispose();
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

  void _handleQueryChanged(String value) {
    if (!_allowed) return;
    _pendingQuery = value;
    _searchDebounceTimer?.cancel();
    final dateQuery = const TrackDateQueryParser().parseQuery(value);
    switch (dateQuery.kind) {
      case TrackDateQueryKind.valid:
        setState(() {
          _hasTypedTrackDateRange = true;
          _isDateQueryInvalid = false;
        });
        widget.onSelectTrackDateRange(dateQuery.range);
        widget.onChanged('');
        return;
      case TrackDateQueryKind.invalidDateLike:
        _clearTypedTrackDateRange();
        setState(() => _isDateQueryInvalid = true);
        widget.onChanged('');
        return;
      case TrackDateQueryKind.nonDateLike:
        _clearTypedTrackDateRange();
        setState(() => _isDateQueryInvalid = false);
    }
    final trimmedQuery = value.trim();
    if (trimmedQuery.isEmpty ||
        trimmedQuery.length < MapConstants.searchPopupMinimumQueryLength) {
      widget.onChanged(value);
      return;
    }
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!_allowed) {
        return;
      }
      widget.onChanged(value);
    });
  }

  void _openPicker() {
    if (!_allowed) return;
    _searchDebounceTimer?.cancel();
    final activeRange = widget.trackDateRange;
    setState(() {
      _shouldAutofocusSearchInput = false;
      _isPickerOpen = true;
      _draftStart = activeRange?.start;
      _draftEnd = activeRange?.end;
      _startDateError = null;
      _endDateError = null;
      _startDateController.text = _formatEditableDate(_draftStart);
      _endDateController.text = _formatEditableDate(_draftEnd);
      _startCalendarMonth = _monthFor(_draftStart, fallback: widget.clock);
      _endCalendarMonth = _monthFor(_draftEnd, fallback: widget.clock);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isPickerOpen) {
        FocusScope.of(context).requestFocus(_startDateFocusNode);
      }
    });
  }

  void _discardPicker() {
    if (!_isPickerOpen) {
      return;
    }
    setState(() {
      _isPickerOpen = false;
      _draftStart = null;
      _draftEnd = null;
      _startDateError = null;
      _endDateError = null;
    });
    _restoreDateTriggerFocus();
  }

  void _restoreDateTriggerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _dateTriggerFocusNode.requestFocus();
      }
    });
  }

  void _applyPicker() {
    if (!_allowed) return;
    final start = _draftStart;
    final end = _draftEnd ?? start;
    if (start == null || end == null || start.compareTo(end) > 0) {
      return;
    }
    final hadTypedRange = _hasTypedTrackDateRange;
    _hasTypedTrackDateRange = false;
    if (hadTypedRange) {
      _queryController.clear();
      _pendingQuery = '';
      widget.onChanged('');
    }
    widget.onSelectTrackDateRange(TrackDateRange(start: start, end: end));
    _discardPicker();
  }

  void _clearPicker() {
    if (!_allowed) return;
    final hadTypedRange = _hasTypedTrackDateRange;
    setState(() {
      _hasTypedTrackDateRange = false;
      _draftStart = null;
      _draftEnd = null;
      _startDateError = null;
      _endDateError = null;
      _startDateController.clear();
      _endDateController.clear();
      if (hadTypedRange) {
        _queryController.clear();
        _pendingQuery = '';
      }
    });
    if (hadTypedRange) {
      widget.onChanged('');
    }
    widget.onSelectTrackDateRange(null);
  }

  void _updateDraftFromText({required bool isStart, required String value}) {
    if (!_allowed) return;
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      setState(() {
        if (isStart) {
          _draftStart = null;
          _startDateError = null;
        } else {
          _draftEnd = null;
          _endDateError = null;
        }
      });
      return;
    }
    final result = const TrackDateQueryParser().parseEndpoint(value);
    if (result.kind != TrackDateQueryKind.valid) {
      setState(() {
        if (isStart) {
          _startDateError = 'Enter a valid date';
        } else {
          _endDateError = 'Enter a valid date';
        }
      });
      return;
    }
    _setDraftDate(isStart: isStart, date: result.range!.start);
  }

  void _setDraftDate({required bool isStart, required TrackCalendarDay date}) {
    if (!_allowed) return;
    setState(() {
      if (isStart) {
        _draftStart = date;
        _startDateError = null;
        _startDateController.text = _formatEditableDate(date);
      } else {
        _draftEnd = date;
        _endDateError = null;
        _endDateController.text = _formatEditableDate(date);
        if (_draftStart == null) {
          _draftStart = date;
          _startDateError = null;
          _startDateController.text = _formatEditableDate(date);
        }
      }
    });
  }

  void _setDraftEndToToday() {
    final now = widget.clock();
    _setDraftDate(
      isStart: false,
      date: TrackCalendarDay(now.year, now.month, now.day),
    );
  }

  void _changeCalendarMonth({required bool isStart, required int delta}) {
    if (!_allowed) return;
    final currentMonth = isStart ? _startCalendarMonth : _endCalendarMonth;
    final nextMonth = _offsetMonth(currentMonth, delta);
    if (nextMonth == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startCalendarMonth = nextMonth;
      } else {
        _endCalendarMonth = nextMonth;
      }
    });
  }

  void _changeCalendarYear({required bool isStart, required int year}) {
    if (!_allowed || !_isPickerOpen) return;
    final currentMonth = isStart ? _startCalendarMonth : _endCalendarMonth;
    setState(() {
      final nextMonth = DateTime(year, currentMonth.month);
      if (isStart) {
        _startCalendarMonth = nextMonth;
      } else {
        _endCalendarMonth = nextMonth;
      }
    });
  }

  void _clearTypedTrackDateRange() {
    if (!_hasTypedTrackDateRange) {
      return;
    }
    setState(() => _hasTypedTrackDateRange = false);
    widget.onSelectTrackDateRange(null);
  }

  void _flushPendingQuery() {
    if (!_allowed) return;
    if (!(_searchDebounceTimer?.isActive ?? false)) {
      return;
    }
    _searchDebounceTimer?.cancel();
    widget.onChanged(_pendingQuery);
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
        constraints: const BoxConstraints(maxHeight: 840),
        child: PopupShell(
          key: const Key('map-search-popup'),
          title: const Text('Search'),
          onClose: widget.onClose,
          closeButtonKey: const Key('map-search-close'),
          bodyFlexible: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: _isPickerOpen ? 20 : 0,
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: TapRegion(
                    groupId: _pickerTapRegionGroup,
                    onTapOutside: _isPickerOpen
                        ? (_) {
                            // A menu lives in the overlay, outside this region.
                            // It owns both row clicks and its first outside gesture.
                            if (!_hasOpenMenu && !_menuDismissedThisTurn) {
                              _discardPicker();
                            }
                          }
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Semantics(
                                label: 'Main Map Search',
                                child: TextField(
                                  key: const Key('map-search-input'),
                                  controller: _queryController,
                                  enabled: widget.enabled,
                                  focusNode: widget.focusNode,
                                  autofocus: _shouldAutofocusSearchInput,
                                  decoration: InputDecoration(
                                    labelText: 'Search ⌘F',
                                    hintText: 'Search Peaks',
                                    error: _isDateQueryInvalid
                                        ? const SharedFieldError(
                                            'Enter a valid date or date range',
                                            key: Key(
                                              'map-search-date-query-validation',
                                            ),
                                          )
                                        : null,
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: searchControlIconSize,
                                    ),
                                  ),
                                  onChanged: _handleQueryChanged,
                                  onSubmitted: (_) => _flushPendingQuery(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildDatePicker(context),
                          ],
                        ),
                        if (_isPickerOpen) ...[
                          const SizedBox(
                            height: PopupUIConstants.actionSpacing,
                          ),
                          _buildDatePickerSurface(context),
                        ],
                      ],
                    ),
                  ),
                ),
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
                      key: const Key('map-search-entity-peaks'),
                      icon: Icons.landscape,
                      label: 'Peaks',
                      isSelected: widget.categories.contains(
                        MapSearchCategory.peaks,
                      ),
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onToggleCategory(MapSearchCategory.peaks);
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-tracks-routes'),
                      icon: Icons.hiking,
                      label: 'Tracks/Routes',
                      isSelected: widget.categories.contains(
                        MapSearchCategory.tracksRoutes,
                      ),
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onToggleCategory(MapSearchCategory.tracksRoutes);
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-natural'),
                      icon: Icons.forest,
                      label: 'Natural',
                      isSelected: widget.categories.contains(
                        MapSearchCategory.natural,
                      ),
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onToggleCategory(MapSearchCategory.natural);
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-roads'),
                      icon: Icons.directions_car,
                      label: 'Roads',
                      isSelected: widget.categories.contains(
                        MapSearchCategory.roads,
                      ),
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onToggleCategory(MapSearchCategory.roads);
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-maps'),
                      icon: Icons.map,
                      label: 'Maps',
                      isSelected: widget.categories.contains(
                        MapSearchCategory.maps,
                      ),
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onToggleCategory(MapSearchCategory.maps);
                      },
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(height: 32, child: VerticalDivider()),
                    const SizedBox(width: 8),
                    SharedDropdown<String>(
                      key: const Key('map-search-filter-button'),
                      controller: _regionMenu,
                      onClosed: _menuClosed,
                      label: 'Region',
                      value: widget.selectedRegionKey ?? _noRegionSelection,
                      enabled: widget.enabled,
                      isInteractionAllowed: () => _allowed,
                      onSelected: (value) {
                        if (!_allowed) return;
                        _flushPendingQuery();
                        widget.onSelectRegionKey(
                          value == _noRegionSelection ? null : value,
                        );
                      },
                      choices: [
                        const SharedDropdownChoice<String>(
                          key: Key('map-search-region-none'),
                          value: _noRegionSelection,
                          label: 'None',
                        ),
                        ...widget.availableRegions.map(
                          (region) => SharedDropdownChoice<String>(
                            key: Key('map-search-region-${region.key}'),
                            value: region.key,
                            label: region.name,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    SharedDropdown<MapSearchSort>(
                      key: const Key('map-search-sort-button'),
                      controller: _sortMenu,
                      onClosed: _menuClosed,
                      label: 'Sort',
                      value: widget.sort,
                      enabled: widget.enabled,
                      isInteractionAllowed: () => _allowed,
                      onSelected: (value) {
                        if (!_allowed) return;
                        _flushPendingQuery();
                        widget.onSelectSort(value);
                      },
                      choices: const [
                        SharedDropdownChoice<MapSearchSort>(
                          key: Key('map-search-sort-name-ascending'),
                          value: MapSearchSort.nameAscending,
                          label: 'Name ascending',
                        ),
                        SharedDropdownChoice<MapSearchSort>(
                          key: Key('map-search-sort-name-descending'),
                          value: MapSearchSort.nameDescending,
                          label: 'Name descending',
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    SharedDropdown<MapSearchGroup>(
                      key: const Key('map-search-group-button'),
                      controller: _groupMenu,
                      onClosed: _menuClosed,
                      label: 'Group',
                      value: widget.group,
                      enabled: widget.enabled,
                      isInteractionAllowed: () => _allowed,
                      onSelected: (value) {
                        if (!_allowed) return;
                        _flushPendingQuery();
                        widget.onSelectGroup(value);
                      },
                      choices: const [
                        SharedDropdownChoice<MapSearchGroup>(
                          key: Key('map-search-group-none'),
                          value: MapSearchGroup.none,
                          label: 'None',
                        ),
                        SharedDropdownChoice<MapSearchGroup>(
                          key: Key('map-search-group-region'),
                          value: MapSearchGroup.region,
                          label: 'Region',
                        ),
                        SharedDropdownChoice<MapSearchGroup>(
                          key: Key('map-search-group-type'),
                          value: MapSearchGroup.type,
                          label: 'Type',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PopupUIConstants.actionSpacing),
              Text('Results', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: PopupUIConstants.headerSpacing),
              Expanded(
                child: widget.mappingUnavailableReason != null
                    ? _MappingUnavailableState(
                        reason: widget.mappingUnavailableReason!,
                        onRetry: widget.onRetryMapping,
                      )
                    : widget.naturalFeaturesUnavailableReason != null
                    ? _NaturalFeaturesMappingUnavailableState(
                        reason: widget.naturalFeaturesUnavailableReason!,
                        onRetry: widget.onRetryNaturalFeatures,
                      )
                    : MapSearchResultsList(
                        key: ValueKey((
                          widget.searchQuery,
                          widget.trackDateRange,
                          widget.categories,
                          widget.selectedRegionKey,
                          widget.sort,
                          widget.group,
                        )),
                        searchResults: widget.searchResults,
                        isLoadingMore: widget.isLoadingMore,
                        isExhausted: widget.isExhausted,
                        searchQuery: widget.searchQuery,
                        isTrackDateRangeActive: widget.trackDateRange != null,
                        sort: widget.sort,
                        group: widget.group,
                        onLoadMore: widget.onLoadMore,
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
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: OutlinedButton.icon(
        key: key,
        style: searchButtonTheme?.styleFor(isSelected),
        onPressed: onPressed,
        icon: Icon(icon, size: searchControlIconSize),
        label: Text(
          label,
          style: const TextStyle(fontSize: searchControlFontSize),
        ),
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Focus(
      onKeyEvent: _isPickerOpen ? _handlePickerKeyEvent : null,
      child: OutlinedButton.icon(
        key: const Key('map-search-date-trigger'),
        focusNode: _dateTriggerFocusNode,
        onPressed: _isPickerOpen ? _discardPicker : _openPicker,
        icon: const Icon(Icons.calendar_month, size: searchControlIconSize),
        label: Text(
          _formatDateRange(widget.trackDateRange),
          style: const TextStyle(fontSize: searchControlFontSize),
        ),
      ),
    );
  }

  KeyEventResult _handlePickerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            (event.logicalKey == LogicalKeyboardKey.keyC &&
                HardwareKeyboard.instance.isControlPressed &&
                !HardwareKeyboard.instance.isMetaPressed))) {
      _discardPicker();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildDatePickerSurface(BuildContext context) {
    return Focus(
      onKeyEvent: _handlePickerKeyEvent,
      child: Card(
        key: const Key('map-search-date-picker'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Track date',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    key: const Key('map-search-date-close'),
                    onPressed: _discardPicker,
                    tooltip: 'Close date picker',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildEndpoint(context, isStart: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildEndpoint(context, isStart: false)),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('map-search-date-clear'),
                      onPressed: _clearPicker,
                      child: const Text('Clear'),
                    ),
                    FilledButton(
                      key: const Key('map-search-date-cancel'),
                      onPressed: _discardPicker,
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('map-search-date-apply'),
                      onPressed: _canApplyPicker ? _applyPicker : null,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndpoint(BuildContext context, {required bool isStart}) {
    final prefix = isStart ? 'Start' : 'End';
    final controller = isStart ? _startDateController : _endDateController;
    final error = isStart ? _startDateError : _endDateError;
    final calendarMonth = isStart ? _startCalendarMonth : _endCalendarMonth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('map-search-date-${isStart ? 'start' : 'end'}-input'),
                controller: controller,
                focusNode: isStart ? _startDateFocusNode : null,
                decoration: InputDecoration(
                  labelText: '$prefix date',
                  hintText: 'd MMM yyyy',
                  error: error == null
                      ? null
                      : SharedFieldError(
                          error,
                          key: Key(
                            'map-search-date-${isStart ? 'start' : 'end'}-validation',
                          ),
                        ),
                ),
                onChanged: (value) =>
                    _updateDraftFromText(isStart: isStart, value: value),
                onSubmitted: (value) =>
                    _updateDraftFromText(isStart: isStart, value: value),
              ),
            ),
            if (!isStart) ...[
              const SizedBox(width: 8),
              TextButton(
                key: const Key('map-search-date-end-today'),
                onPressed: _setDraftEndToToday,
                child: const Text('Today'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _buildCalendar(context, isStart: isStart, month: calendarMonth),
      ],
    );
  }

  Widget _buildCalendar(
    BuildContext context, {
    required bool isStart,
    required DateTime month,
  }) {
    final prefix = isStart ? 'start' : 'end';
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month).weekday % 7;
    final cells = <Widget>[];
    for (var index = 0; index < firstWeekday + daysInMonth; index++) {
      if (index < firstWeekday) {
        cells.add(const SizedBox.shrink());
        continue;
      }
      final day = index - firstWeekday + 1;
      final calendarDay = TrackCalendarDay(month.year, month.month, day);
      final selected = calendarDay == (isStart ? _draftStart : _draftEnd);
      cells.add(
        Semantics(
          label:
              '${isStart ? 'Start' : 'End'} ${_formatEditableDate(calendarDay)}',
          button: true,
          selected: selected,
          child: IconButton(
            key: Key('map-search-date-$prefix-day-$day'),
            style: IconButton.styleFrom(
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
            onPressed: () => _setDraftDate(isStart: isStart, date: calendarDay),
            icon: Text('$day'),
          ),
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: Key('map-search-date-$prefix-previous-month'),
              onPressed: () =>
                  _changeCalendarMonth(isStart: isStart, delta: -1),
              icon: Icon(
                Icons.chevron_left,
                semanticLabel: 'Previous $prefix month',
              ),
            ),
            Expanded(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                key: Key('map-search-date-$prefix-calendar-label'),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              key: Key('map-search-date-$prefix-next-month'),
              onPressed: () => _changeCalendarMonth(isStart: isStart, delta: 1),
              icon: Icon(
                Icons.chevron_right,
                semanticLabel: 'Next $prefix month',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            SharedDropdown<int>(
              key: Key('map-search-date-$prefix-month'),
              controller: isStart ? _startMonthMenu : _endMonthMenu,
              onClosed: _menuClosed,
              label: 'Month',
              value: month.month,
              isInteractionAllowed: () => _allowed && _isPickerOpen,
              choices: List.generate(
                12,
                (index) => SharedDropdownChoice(
                  key: Key('map-search-date-$prefix-month-${index + 1}'),
                  value: index + 1,
                  label: _monthNames[index],
                ),
              ),
              onSelected: (value) {
                if (!_allowed || !_isPickerOpen) return;
                _setCalendarMonth(isStart: isStart, month: value);
              },
            ),
            _CalendarYearField(
              key: Key('map-search-date-$prefix-year'),
              year: month.year,
              semanticLabel: '${isStart ? 'Start' : 'End'} calendar year',
              onSubmitted: (year) =>
                  _changeCalendarYear(isStart: isStart, year: year),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Row(
          children: [
            Expanded(child: Center(child: Text('S'))),
            Expanded(child: Center(child: Text('M'))),
            Expanded(child: Center(child: Text('T'))),
            Expanded(child: Center(child: Text('W'))),
            Expanded(child: Center(child: Text('T'))),
            Expanded(child: Center(child: Text('F'))),
            Expanded(child: Center(child: Text('S'))),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisExtent: math.max(
            40,
            MediaQuery.textScalerOf(context).scale(20) + 16,
          ),
          children: cells,
        ),
      ],
    );
  }

  void _setCalendarMonth({required bool isStart, required int month}) {
    final currentMonth = isStart ? _startCalendarMonth : _endCalendarMonth;
    setState(() {
      final nextMonth = DateTime(currentMonth.year, month);
      if (isStart) {
        _startCalendarMonth = nextMonth;
      } else {
        _endCalendarMonth = nextMonth;
      }
    });
  }

  bool get _canApplyPicker {
    final start = _draftStart;
    final end = _draftEnd;
    return start != null &&
        _startDateError == null &&
        _endDateError == null &&
        (end == null || start.compareTo(end) <= 0);
  }

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  DateTime _monthFor(TrackCalendarDay? day, {DateTime Function()? fallback}) {
    final source = day == null ? (fallback ?? widget.clock)() : null;
    return DateTime(day?.year ?? source!.year, day?.month ?? source!.month);
  }

  DateTime? _offsetMonth(DateTime month, int delta) {
    final target = month.year * 12 + month.month - 1 + delta;
    final year = target ~/ 12;
    final monthNumber = target % 12 + 1;
    if (year < 1 || year > 9999) {
      return null;
    }
    return DateTime(year, monthNumber);
  }

  String _formatDateRange(TrackDateRange? range) {
    if (range == null) {
      return 'Any date';
    }
    final start = _formatEditableDate(range.start);
    final end = _formatEditableDate(range.end);
    return range.start == range.end ? start : '$start - $end';
  }

  String _formatEditableDate(TrackCalendarDay? day) {
    if (day == null) {
      return '';
    }
    return '${day.day} ${_monthNames[day.month - 1]} ${day.year}';
  }
}

class _MappingUnavailableState extends StatelessWidget {
  const _MappingUnavailableState({required this.reason, required this.onRetry});

  final String reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PopupUIConstants.actionSpacing),
        child: Column(
          key: const Key('peak-search-mapping-unavailable'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Peak data is unavailable.'),
            const SizedBox(height: 8),
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: PopupUIConstants.actionSpacing),
            FilledButton(
              key: const Key('peak-search-mapping-unavailable-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NaturalFeaturesMappingUnavailableState extends StatelessWidget {
  const _NaturalFeaturesMappingUnavailableState({
    required this.reason,
    required this.onRetry,
  });

  final String reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PopupUIConstants.actionSpacing),
        child: Column(
          key: const Key('natural-features-mapping-unavailable'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Natural Features are unavailable.'),
            const SizedBox(height: 8),
            Text(reason, textAlign: TextAlign.center),
            const SizedBox(height: PopupUIConstants.actionSpacing),
            FilledButton(
              key: const Key('natural-features-mapping-unavailable-retry'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarYearField extends StatefulWidget {
  const _CalendarYearField({
    required this.year,
    required this.semanticLabel,
    required this.onSubmitted,
    super.key,
  });

  final int year;
  final String semanticLabel;
  final ValueChanged<int> onSubmitted;

  @override
  State<_CalendarYearField> createState() => _CalendarYearFieldState();
}

class _CalendarYearFieldState extends State<_CalendarYearField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.year}');
    _focus = FocusNode()..addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant _CalendarYearField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != oldWidget.year && !_focus.hasFocus) {
      _controller.text = '${widget.year}';
      _error = null;
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _submit();
  }

  void _submit() {
    final year = int.tryParse(_controller.text.trim());
    if (year == null || year < 1 || year > 9999) {
      setState(() => _error = 'Enter a year from 1 to 9999');
      return;
    }
    setState(() => _error = null);
    widget.onSubmitted(year);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.textScalerOf(context).scale(100) + 24,
      child: Semantics(
        label: widget.semanticLabel,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          decoration: sharedFieldDecoration(
            labelText: 'Year',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}
