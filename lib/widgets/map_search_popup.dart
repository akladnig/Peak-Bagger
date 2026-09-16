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
    required this.entityFilter,
    required this.selectedRegionKey,
    required this.sort,
    required this.group,
    required this.availableRegions,
    required this.onChanged,
    required this.onSelectEntityFilter,
    required this.onSelectTrackDateRange,
    required this.onSelectRegionKey,
    required this.onSelectSort,
    required this.onSelectGroup,
    required this.onLoadMore,
    required this.onClose,
    required this.onSelectResult,
    this.clock = DateTime.now,
    super.key,
  });

  final FocusNode focusNode;
  final List<MapSearchResult> searchResults;
  final bool isLoadingMore;
  final bool isExhausted;
  final String searchQuery;
  final TrackDateRange? trackDateRange;
  final MapSearchEntityFilter entityFilter;
  final String? selectedRegionKey;
  final MapSearchSort sort;
  final MapSearchGroup group;
  final List<MapSearchRegionOption> availableRegions;
  final ValueChanged<String> onChanged;
  final ValueChanged<MapSearchEntityFilter> onSelectEntityFilter;
  final ValueChanged<TrackDateRange?> onSelectTrackDateRange;
  final ValueChanged<String?> onSelectRegionKey;
  final ValueChanged<MapSearchSort> onSelectSort;
  final ValueChanged<MapSearchGroup> onSelectGroup;
  final VoidCallback onLoadMore;
  final VoidCallback onClose;
  final ValueChanged<MapSearchResult> onSelectResult;
  final DateTime Function() clock;

  @override
  State<MapSearchPopup> createState() => _MapSearchPopupState();
}

class _MapSearchPopupState extends State<MapSearchPopup> {
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
  String? _startDateError;
  String? _endDateError;
  TrackCalendarDay? _draftStart;
  TrackCalendarDay? _draftEnd;
  late DateTime _startCalendarMonth;
  late DateTime _endCalendarMonth;

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
      if (mounted && !_isPickerOpen) {
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
      if (!mounted) {
        return;
      }
      widget.onChanged(value);
    });
  }

  void _openPicker() {
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

  void _changeCalendarYear({required bool isStart, required String value}) {
    final year = int.tryParse(value);
    if (year == null || year < 1 || year > 9999) {
      return;
    }
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
    if (!(_searchDebounceTimer?.isActive ?? false)) {
      return;
    }
    _searchDebounceTimer?.cancel();
    widget.onChanged(_pendingQuery);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              TapRegion(
                groupId: _pickerTapRegionGroup,
                onTapOutside: _isPickerOpen ? (_) => _discardPicker() : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('map-search-input'),
                            controller: _queryController,
                            focusNode: widget.focusNode,
                            autofocus: _shouldAutofocusSearchInput,
                            decoration: InputDecoration(
                              labelText: 'Search',
                              error: _isDateQueryInvalid
                                  ? const Text(
                                      'Enter a valid date or date range',
                                      key: Key(
                                        'map-search-date-query-validation',
                                      ),
                                    )
                                  : null,
                              labelStyle: const TextStyle(
                                fontSize: searchControlFontSize,
                              ),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.seedColour),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: theme.seedColour),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.seedColour,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: searchControlIconSize,
                              ),
                            ),
                            onChanged: _handleQueryChanged,
                            onSubmitted: (_) => _flushPendingQuery(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildDatePicker(context),
                      ],
                    ),
                    if (_isPickerOpen) ...[
                      const SizedBox(height: PopupUIConstants.actionSpacing),
                      _buildDatePickerSurface(context),
                    ],
                  ],
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
                      key: const Key('map-search-entity-all'),
                      icon: Icons.language,
                      label: 'All',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.all,
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onSelectEntityFilter(MapSearchEntityFilter.all);
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-peaks'),
                      icon: Icons.landscape,
                      label: 'Peaks',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.peaks,
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onSelectEntityFilter(
                          MapSearchEntityFilter.peaks,
                        );
                      },
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
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onSelectEntityFilter(
                          MapSearchEntityFilter.tracksRoutes,
                        );
                      },
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
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.roads,
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onSelectEntityFilter(
                          MapSearchEntityFilter.roads,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _entityButton(
                      context,
                      key: const Key('map-search-entity-maps'),
                      icon: Icons.map,
                      label: 'Maps',
                      isSelected:
                          widget.entityFilter == MapSearchEntityFilter.maps,
                      onPressed: () {
                        _flushPendingQuery();
                        widget.onSelectEntityFilter(MapSearchEntityFilter.maps);
                      },
                    ),
                    const SizedBox(width: 8),
                    const SizedBox(height: 32, child: VerticalDivider()),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      key: const Key('map-search-filter-button'),
                      onSelected: (value) {
                        _flushPendingQuery();
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
                      onSelected: (value) {
                        _flushPendingQuery();
                        widget.onSelectSort(value);
                      },
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
                      onSelected: (value) {
                        _flushPendingQuery();
                        widget.onSelectGroup(value);
                      },
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
                  key: ValueKey((
                    widget.searchQuery,
                    widget.trackDateRange,
                    widget.entityFilter,
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
        event.logicalKey == LogicalKeyboardKey.escape) {
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
              Row(
                children: [
                  TextButton(
                    key: const Key('map-search-date-clear'),
                    onPressed: _clearPicker,
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('map-search-date-cancel'),
                    onPressed: _discardPicker,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('map-search-date-apply'),
                    onPressed: _canApplyPicker ? _applyPicker : null,
                    child: const Text('Apply'),
                  ),
                ],
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
                  errorText: error,
                  isDense: true,
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
        if (error != null)
          Text(
            error,
            key: Key('map-search-date-${isStart ? 'start' : 'end'}-validation'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
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
            tooltip: _formatEditableDate(calendarDay),
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
              tooltip: 'Previous $prefix month',
              onPressed: () =>
                  _changeCalendarMonth(isStart: isStart, delta: -1),
              icon: const Icon(Icons.chevron_left),
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
              tooltip: 'Next $prefix month',
              onPressed: () => _changeCalendarMonth(isStart: isStart, delta: 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: Key('map-search-date-$prefix-month'),
                initialValue: month.month,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(_monthNames[index]),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  _setCalendarMonth(isStart: isStart, month: value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                key: Key('map-search-date-$prefix-year'),
                initialValue: '${month.year}',
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                onFieldSubmitted: (value) =>
                    _changeCalendarYear(isStart: isStart, value: value),
              ),
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
          childAspectRatio: 1.25,
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
        return region.compactName;
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
