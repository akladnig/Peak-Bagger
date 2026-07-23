import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart'
    show
        PointerPanZoomEndEvent,
        PointerPanZoomStartEvent,
        PointerPanZoomUpdateEvent,
        PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/number_formatters.dart';
import '../models/geo_areas.dart';
import '../models/peak.dart';
import '../models/peak_list.dart';
import '../models/peaks_bagged.dart';
import '../providers/background_jobs_provider.dart';
import '../providers/peak_list_provider.dart';
import '../providers/peak_list_region_filter_provider.dart';
import '../providers/peak_list_selection_provider.dart';
import '../providers/map_provider.dart';
import '../providers/peak_list_mini_map_cluster_display_settings_provider.dart';
import '../providers/peak_marker_info_settings_provider.dart';
import '../providers/peak_provider.dart';
import '../providers/tasmap_provider.dart';
import 'map_screen_panels.dart';
import '../services/peak_list_file_picker.dart';
import '../services/peak_cluster_engine.dart';
import '../services/peak_hover_detector.dart';
import '../services/peak_hit_test.dart';
import '../services/peak_list_visibility.dart';
import '../services/peak_metadata_rules.dart';
import '../services/peak_list_repository.dart';
import '../services/peak_repository.dart';
import '../services/peak_projection_cache.dart';
import '../services/map_trackpad_gesture_classifier.dart';
import '../services/gpx_track_repository.dart';
import '../services/peaks_bagged_repository.dart';
import '../services/tile_cache_service.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/left_tooltip_fab.dart';
import '../widgets/peak_list_import_dialog.dart';
import '../widgets/peak_list_peak_dialog.dart';
import '../theme.dart';
import '../router.dart';
import 'map_screen_layers.dart';
import 'map_screen_peak_layer.dart';

typedef PeakListsSummaryRefreshScheduler =
    Future<void> Function(FutureOr<void> Function() task);

final peakListsSummaryRefreshSchedulerProvider =
    Provider<PeakListsSummaryRefreshScheduler>((ref) {
      return (task) async {
        await task();
      };
    });

class PeakListsScreen extends ConsumerStatefulWidget {
  const PeakListsScreen({super.key, this.initialPeakListId});

  final int? initialPeakListId;

  @override
  ConsumerState<PeakListsScreen> createState() => _PeakListsScreenState();
}

class _PeakListsScreenState extends ConsumerState<PeakListsScreen> {
  GlobalKey<_MiniPeakMapState> _miniPeakMapKey = GlobalKey<_MiniPeakMapState>();
  final _screenFocusNode = FocusNode(debugLabel: 'peak-lists-screen');
  int? _selectedPeakListId;
  int? _selectedPeakId;
  _PeakListSortColumn _sortColumn = _PeakListSortColumn.percentage;
  bool _sortAscending = false;
  bool _selectionSyncQueued = false;
  _PeakListsDerivedSnapshot? _derivedSnapshot;
  _PeakListsDerivedRefreshKey? _settledDerivedRefreshKey;
  _PeakListsDerivedRefreshKey? _pendingDerivedRefreshKey;
  int _derivedRefreshSerial = 0;

  @override
  void initState() {
    super.initState();
    _setSelectedPeakListId(widget.initialPeakListId);
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PeakListsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPeakListId == widget.initialPeakListId) {
      return;
    }

    _setSelectedPeakListId(widget.initialPeakListId);
    _selectedPeakId = null;
  }

  void _setSelectedPeakListId(int? peakListId) {
    if (_selectedPeakListId == peakListId) {
      _selectedPeakListId = peakListId;
      return;
    }
    _selectedPeakListId = peakListId;
    _miniPeakMapKey = GlobalKey<_MiniPeakMapState>();
  }

  @override
  Widget build(BuildContext context) {
    final filePicker = ref.watch(peakListFilePickerProvider);
    final PeakListImportBackgroundRunner importRunner = ref.watch(
      peakListImportBackgroundRunnerProvider,
    );
    final duplicateNameChecker = ref.watch(
      peakListDuplicateNameCheckerProvider,
    );
    final peaksBaggedRevision = ref.watch(peaksBaggedRevisionProvider);
    final peakRevision = ref.watch(peakRevisionProvider);
    final peakListRevision = ref.watch(peakListRevisionProvider);
    final peakListRepository = ref.watch(peakListRepositoryProvider);
    final peakRepository = ref.watch(peakRepositoryProvider);
    final peaksByOsmId = ref.watch(peaksByOsmIdProvider);
    final peaksBaggedRepository = ref.watch(peaksBaggedRepositoryProvider);
    final selectedRegionKeys = ref.watch(peakListRegionFilterProvider);
    final peakLists = ref.watch(peakListsProvider);
    final derivedRefreshKey = _PeakListsDerivedRefreshKey(
      peakRevision: peakRevision,
      peakListRevision: peakListRevision,
      peaksBaggedRevision: peaksBaggedRevision,
      selectedRegionKeys: selectedRegionKeys,
    );
    final summaryRows = _resolveDerivedSummaryRows(
      derivedRefreshKey: derivedRefreshKey,
      preferredSelectedPeakListId: _selectedPeakListId,
      selectedRegionKeys: selectedRegionKeys,
      peakLists: peakLists,
      peakListRepository: peakListRepository,
      peakRepository: peakRepository,
      peaksByOsmId: peaksByOsmId,
      peaksBaggedRepository: peaksBaggedRepository,
    );
    final sortedSummaryRows = _sortSummaryRows(summaryRows);
    final selectedSummaryRow = _resolveSelectedSummaryRow(sortedSummaryRows);
    final resolvedSelectedSummaryRow = _derivedSnapshot?.resolveRowDetails(
      selectedSummaryRow,
    );
    _queueSelectionSync(sortedSummaryRows, selectedSummaryRow);
    final selectedMapPeak = _resolveSelectedMapPeak(resolvedSelectedSummaryRow);
    final route = ModalRoute.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if ((route != null && !route.isCurrent) || _isEditableTextFocused()) {
        _miniPeakMapKey.currentState?.cancelKeyboardScroll();
        return;
      }
      if (_screenFocusNode.hasFocus) {
        return;
      }
      _screenFocusNode.requestFocus();
    });

    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if ((route != null && !route.isCurrent) || _isEditableTextFocused()) {
          _miniPeakMapKey.currentState?.cancelKeyboardScroll();
          return KeyEventResult.ignored;
        }
        final miniMapState = _miniPeakMapKey.currentState;
        if (miniMapState == null) {
          return KeyEventResult.ignored;
        }
        return miniMapState.handleScreenKeyEvent(event);
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final panes = _resolvePaneWidths(constraints.maxWidth);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  key: const Key('peak-lists-summary-pane'),
                  width: panes.leftWidth,
                  child: _SummaryPane(
                    rows: sortedSummaryRows,
                    selectedPeakListId: selectedSummaryRow?.peakList.peakListId,
                    selectedSummaryRow: resolvedSelectedSummaryRow,
                    sortColumn: _sortColumn,
                    sortAscending: _sortAscending,
                    miniPeakMapKey: _miniPeakMapKey,
                    onSelected: (peakListId) {
                      setState(() {
                        _setSelectedPeakListId(peakListId);
                      });
                    },
                    onSortSelected: _handleSortSelected,
                    onDeleteRequested: (peakListId) {
                      _deletePeakList(peakListId, sortedSummaryRows);
                    },
                    filePicker: filePicker,
                    importRunner: importRunner,
                    duplicateNameChecker: duplicateNameChecker,
                    peakListRepository: peakListRepository,
                    selectedMapPeak: selectedMapPeak,
                    onPeakSelected: (peakId) {
                      setState(() {
                        _selectedPeakId = peakId;
                      });
                    },
                  ),
                ),
                const VerticalDivider(width: UiConstants.dividerWidth),
                SizedBox(
                  key: const Key('peak-lists-details-pane'),
                  width: panes.rightWidth,
                  child: _DetailsPane(
                    selectedSummaryRow: resolvedSelectedSummaryRow,
                    selectedPeakId: _selectedPeakId,
                    onSummaryPeakSelected: (peakId) {
                      setState(() {
                        _selectedPeakId = peakId;
                      });
                      _miniPeakMapKey.currentState?.showPopupForPeak(peakId);
                    },
                    onPeakSelected: (peakId) async {
                      setState(() {
                        _selectedPeakId = peakId;
                      });
                      final result = await _openPeakDialog(
                        resolvedSelectedSummaryRow,
                        peakId,
                      );
                      if (!mounted || result == null) {
                        return;
                      }
                      setState(() {
                        _selectedPeakId = result.selectedPeakId;
                      });
                    },
                    onAddPeakRequested: () async {
                      final result = await _openAddPeakDialog(
                        resolvedSelectedSummaryRow,
                      );
                      if (!mounted || result == null) {
                        return;
                      }
                      final selectedPeakIds = result.selectedPeakIds;
                      if (selectedPeakIds.isEmpty) {
                        return;
                      }
                      await _refreshPeakListSelectionDependencies();
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _selectedPeakId = selectedPeakIds.first;
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_PeakListSummaryRow> _resolveDerivedSummaryRows({
    required _PeakListsDerivedRefreshKey derivedRefreshKey,
    required int? preferredSelectedPeakListId,
    required Set<String> selectedRegionKeys,
    required List<PeakList> peakLists,
    required PeakListRepository peakListRepository,
    required PeakRepository peakRepository,
    required Map<int, Peak> peaksByOsmId,
    required PeaksBaggedRepository peaksBaggedRepository,
  }) {
    final settledSnapshot = _derivedSnapshot;
    if (settledSnapshot == null) {
      final initialSnapshot = _buildPeakListsDerivedSnapshot(
        state: this,
        preferredSelectedPeakListId: preferredSelectedPeakListId,
        selectedRegionKeys: selectedRegionKeys,
        peakLists: peakLists,
        peakListRepository: peakListRepository,
        peakRepository: peakRepository,
        peaksByOsmId: peaksByOsmId,
        peaksBaggedRepository: peaksBaggedRepository,
      );
      _derivedSnapshot = initialSnapshot;
      _settledDerivedRefreshKey = derivedRefreshKey;
      return initialSnapshot.summaryRows;
    }

    final settledKey = _settledDerivedRefreshKey;
    final pendingKey = _pendingDerivedRefreshKey;
    if (pendingKey != null &&
        !pendingKey.matches(derivedRefreshKey) &&
        settledKey != null &&
        settledKey.matches(derivedRefreshKey)) {
      _derivedRefreshSerial += 1;
      _pendingDerivedRefreshKey = null;
    }
    if ((settledKey == null || !settledKey.matches(derivedRefreshKey)) &&
        (pendingKey == null || !pendingKey.matches(derivedRefreshKey))) {
      _scheduleDerivedSummaryRefresh(
        derivedRefreshKey: derivedRefreshKey,
        preferredSelectedPeakListId: preferredSelectedPeakListId,
        selectedRegionKeys: selectedRegionKeys,
        peakLists: peakLists,
        peakListRepository: peakListRepository,
        peakRepository: peakRepository,
        peaksByOsmId: peaksByOsmId,
        peaksBaggedRepository: peaksBaggedRepository,
      );
    }

    return settledSnapshot.summaryRows;
  }

  void _scheduleDerivedSummaryRefresh({
    required _PeakListsDerivedRefreshKey derivedRefreshKey,
    required int? preferredSelectedPeakListId,
    required Set<String> selectedRegionKeys,
    required List<PeakList> peakLists,
    required PeakListRepository peakListRepository,
    required PeakRepository peakRepository,
    required Map<int, Peak> peaksByOsmId,
    required PeaksBaggedRepository peaksBaggedRepository,
  }) {
    _pendingDerivedRefreshKey = derivedRefreshKey;
    final refreshSerial = ++_derivedRefreshSerial;
    final selectedRegionKeysSnapshot = Set<String>.unmodifiable(
      selectedRegionKeys,
    );
    final peakListsSnapshot = List<PeakList>.unmodifiable(peakLists);
    final scheduleRefresh = ref.read(peakListsSummaryRefreshSchedulerProvider);

    unawaited(
      scheduleRefresh(() {
        try {
          final nextSnapshot = _buildPeakListsDerivedSnapshot(
            state: this,
            preferredSelectedPeakListId: preferredSelectedPeakListId,
            selectedRegionKeys: selectedRegionKeysSnapshot,
            peakLists: peakListsSnapshot,
            peakListRepository: peakListRepository,
            peakRepository: peakRepository,
            peaksByOsmId: peaksByOsmId,
            peaksBaggedRepository: peaksBaggedRepository,
          );
          if (!mounted || refreshSerial != _derivedRefreshSerial) {
            return;
          }
          setState(() {
            _derivedSnapshot = nextSnapshot;
            _settledDerivedRefreshKey = derivedRefreshKey;
            _pendingDerivedRefreshKey = null;
          });
        } catch (error, stackTrace) {
          developer.log(
            'Failed to refresh My Peak Lists derived summary rows.',
            error: error,
            stackTrace: stackTrace,
            name: 'peak_lists_screen',
          );
          if (!mounted || refreshSerial != _derivedRefreshSerial) {
            return;
          }
          setState(() {
            _pendingDerivedRefreshKey = null;
          });
        }
      }),
    );
  }

  ({double leftWidth, double rightWidth}) _resolvePaneWidths(double bodyWidth) {
    final usableWidth = math.max(0.0, bodyWidth - UiConstants.dividerWidth);
    final preferredLeft = usableWidth * 0.55;
    final rightSoftTarget = UiConstants.preferredRightWidth;
    final maxLeftAtPreferredRight = math.max(
      0.0,
      usableWidth - rightSoftTarget,
    );
    final minLeftForMiniMap = UiConstants.minimumMiniMapAspectWidth;
    final leftWidth =
        usableWidth >=
            (UiConstants.preferredLeftWidth +
                UiConstants.preferredRightWidth +
                UiConstants.dividerWidth)
        ? preferredLeft
              .clamp(UiConstants.preferredLeftWidth, maxLeftAtPreferredRight)
              .toDouble()
        : math.max(
            minLeftForMiniMap,
            math.min(UiConstants.preferredLeftWidth, maxLeftAtPreferredRight),
          );
    return (
      leftWidth: leftWidth,
      rightWidth: math.max(0.0, usableWidth - leftWidth),
    );
  }

  void _handleSortSelected(_PeakListSortColumn column) {
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
        return;
      }
      _sortAscending = !_sortAscending;
    });
  }

  Future<void> _deletePeakList(
    int peakListId,
    List<_PeakListSummaryRow> visibleRows,
  ) async {
    final row = visibleRows.firstWhere(
      (candidate) => candidate.peakList.peakListId == peakListId,
    );
    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: 'Delete Peak List?',
      message:
          'This will permanently delete the ${row.peakList.name}. Do you want to proceed',
      cancelKey: 'cancel-delete',
      cancelLabel: 'Cancel',
      confirmKey: 'confirm-delete',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    int? nextSelectedPeakListId = _selectedPeakListId;
    if (_selectedPeakListId == peakListId) {
      final index = visibleRows.indexWhere(
        (candidate) => candidate.peakList.peakListId == peakListId,
      );
      if (visibleRows.length == 1) {
        nextSelectedPeakListId = null;
      } else if (index < visibleRows.length - 1) {
        nextSelectedPeakListId = visibleRows[index + 1].peakList.peakListId;
      } else {
        nextSelectedPeakListId = visibleRows[index - 1].peakList.peakListId;
      }
    }

    await ref.read(peakListMutationRepositoryProvider).delete(peakListId);
    await _refreshPeakListSelectionDependencies();
    if (!mounted) {
      return;
    }
    setState(() {
      _setSelectedPeakListId(nextSelectedPeakListId);
      if (_selectedPeakListId != peakListId) {
        _selectedPeakId = null;
      }
    });
  }

  Future<PeakListPeakDialogOutcome?> _openPeakDialog(
    _PeakListSummaryRow? selectedSummaryRow,
    int peakId,
  ) async {
    if (selectedSummaryRow == null) {
      return null;
    }

    final peakRows = selectedSummaryRow.peakRows
        .where((row) => row.peakId == peakId)
        .toList(growable: false);
    if (peakRows.isEmpty) {
      return null;
    }

    final peak = ref.read(peakRepositoryProvider).findByOsmId(peakId);
    if (peak == null) {
      return null;
    }

    final ascentRows = ref
        .read(peaksBaggedRepositoryProvider)
        .ascentsForPeakId(peakId);

    return showGeneralDialog<PeakListPeakDialogOutcome>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PeakListPeakDialog(
          mode: PeakListPeakDialogMode.view,
          peakList: selectedSummaryRow.peakList,
          peakListRepository: ref.read(peakListMutationRepositoryProvider),
          peakItems: [
            for (final row in selectedSummaryRow.peakRows)
              PeakListItem(peakOsmId: row.peakId, points: row.points),
          ],
          ascentRows: ascentRows,
          peak: peak,
          points: peakRows.first.points,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(opacity: fadeAnimation, child: child);
      },
    );
  }

  Future<PeakListPeakDialogOutcome?> _openAddPeakDialog(
    _PeakListSummaryRow? selectedSummaryRow,
  ) async {
    if (selectedSummaryRow == null) {
      return null;
    }

    final ascentRows = const <PeaksBagged>[];

    return showGeneralDialog<PeakListPeakDialogOutcome>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return PeakListPeakDialog(
          mode: PeakListPeakDialogMode.add,
          peakList: selectedSummaryRow.peakList,
          peakListRepository: ref.read(peakListMutationRepositoryProvider),
          peakItems: [
            for (final row in selectedSummaryRow.peakRows)
              PeakListItem(peakOsmId: row.peakId, points: row.points),
          ],
          ascentRows: ascentRows,
          refreshPeakListSelectionOnAddSuccess: false,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        return FadeTransition(opacity: fadeAnimation, child: child);
      },
    );
  }

  Future<void> _refreshPeakListSelectionDependencies() async {
    ref.read(peakListMembershipRefreshRunnerProvider)();
    if (!mounted) {
      return;
    }
    setState(() {
      _derivedSnapshot = null;
      _settledDerivedRefreshKey = null;
      _pendingDerivedRefreshKey = null;
      _derivedRefreshSerial += 1;
    });
  }

  List<_PeakListSummaryRow> _sortSummaryRows(List<_PeakListSummaryRow> rows) {
    final sorted = List<_PeakListSummaryRow>.from(rows);
    sorted.sort((left, right) {
      if (_sortColumn == _PeakListSortColumn.ascents) {
        final leftBlank = left.ascentCount == 0;
        final rightBlank = right.ascentCount == 0;
        if (leftBlank != rightBlank) {
          return leftBlank ? 1 : -1;
        }
        if (!leftBlank) {
          final direction = _sortAscending ? 1 : -1;
          final countComparison = left.ascentCount.compareTo(right.ascentCount);
          if (countComparison != 0) {
            return countComparison * direction;
          }
        }
        final nameComparison = left.peakList.name.toLowerCase().compareTo(
          right.peakList.name.toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return left.peakList.peakListId.compareTo(right.peakList.peakListId);
      }

      final direction = _sortAscending ? 1 : -1;
      final primaryComparison = switch (_sortColumn) {
        _PeakListSortColumn.name => left.peakList.name.toLowerCase().compareTo(
          right.peakList.name.toLowerCase(),
        ),
        _PeakListSortColumn.totalPeaks => left.totalPeaks!.compareTo(
          right.totalPeaks!,
        ),
        _PeakListSortColumn.climbed => left.climbed!.compareTo(right.climbed!),
        _PeakListSortColumn.percentage => left.percentageValue.compareTo(
          right.percentageValue,
        ),
        _PeakListSortColumn.unclimbed => left.unclimbed!.compareTo(
          right.unclimbed!,
        ),
        _PeakListSortColumn.ascents => left.ascentCount.compareTo(
          right.ascentCount,
        ),
      };
      if (primaryComparison != 0) {
        return primaryComparison * direction;
      }
      return left.peakList.name.toLowerCase().compareTo(
        right.peakList.name.toLowerCase(),
      );
    });
    return sorted;
  }

  _PeakListSummaryRow? _resolveSelectedSummaryRow(
    List<_PeakListSummaryRow> rows,
  ) {
    if (rows.isEmpty) {
      return null;
    }

    if (_selectedPeakListId != null) {
      for (final row in rows) {
        if (row.peakList.peakListId == _selectedPeakListId) {
          return row;
        }
      }
    }

    return rows.first;
  }

  void _queueSelectionSync(
    List<_PeakListSummaryRow> visibleRows,
    _PeakListSummaryRow? selectedSummaryRow,
  ) {
    final nextSelectedPeakListId = selectedSummaryRow?.peakList.peakListId;
    final shouldClearPeakSelection =
        nextSelectedPeakListId != _selectedPeakListId || visibleRows.isEmpty;
    if (_selectedPeakListId == nextSelectedPeakListId &&
        (!shouldClearPeakSelection || _selectedPeakId == null)) {
      return;
    }
    if (_selectionSyncQueued) {
      return;
    }

    _selectionSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionSyncQueued = false;
      if (!mounted) {
        return;
      }
      setState(() {
        _setSelectedPeakListId(nextSelectedPeakListId);
        if (shouldClearPeakSelection) {
          _selectedPeakId = null;
        }
      });
    });
  }

  _MapPeak? _resolveSelectedMapPeak(_PeakListSummaryRow? selectedSummaryRow) {
    final selectedPeakId = _selectedPeakId;
    if (selectedPeakId == null) {
      return null;
    }

    for (final peak in selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[]) {
      if (peak.peak.osmId == selectedPeakId) {
        return peak;
      }
    }

    return null;
  }
}

bool _isEditableTextFocused() {
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null) {
    return false;
  }

  return focusedContext.widget is EditableText ||
      focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
}

enum _PeakListSortColumn {
  name,
  totalPeaks,
  climbed,
  percentage,
  unclimbed,
  ascents,
}

enum _PeakDetailSortColumn {
  rating,
  name,
  elevation,
  ascentDate,
  ascents,
  difficulty,
  duration,
}

typedef _SummaryTableWidths = ({
  double list,
  double totalPeaks,
  double climbed,
  double percentage,
  double unclimbed,
  double ascents,
  double actions,
  double totalWidth,
});

typedef _PeakTableWidths = ({
  double rating,
  double peakName,
  double elevation,
  double ascentDate,
  double ascents,
  double difficulty,
  double duration,
  double totalWidth,
});

double _measureTextWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
}

_SummaryTableWidths _resolveSummaryTableWidths(
  BuildContext context,
  List<_PeakListSummaryRow> rows,
) {
  final theme = Theme.of(context);
  final headerStyle = theme.textTheme.labelLarge;
  final cellStyle = theme.textTheme.bodyMedium;
  final selectedStyle = cellStyle?.copyWith(fontWeight: FontWeight.w600);
  const horizontalPadding = UiConstants.columnCellHorizontalPadding * 2;
  const headerLabelGap = UiConstants.headerLabelGap;

  double list =
      _measureTextWidth(context, 'List', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double totalPeaks =
      _measureTextWidth(context, 'Total Peaks', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double climbed =
      _measureTextWidth(context, 'Climbed', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double percentage =
      _measureTextWidth(context, 'Percentage', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double unclimbed =
      _measureTextWidth(context, 'Unclimbed', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double ascents =
      _measureTextWidth(context, 'Ascents', headerStyle) +
      horizontalPadding +
      headerLabelGap;
  double actions = math.max(
    _measureTextWidth(context, 'Actions', headerStyle) + horizontalPadding,
    48.0,
  );

  for (final row in rows) {
    list = math.max(
      list,
      _measureTextWidth(context, row.peakList.name, selectedStyle) +
          horizontalPadding,
    );
    totalPeaks = math.max(
      totalPeaks,
      _measureTextWidth(context, row.totalPeaksLabel, cellStyle) +
          horizontalPadding,
    );
    climbed = math.max(
      climbed,
      _measureTextWidth(context, row.climbedLabel, cellStyle) +
          horizontalPadding,
    );
    percentage = math.max(
      percentage,
      _measureTextWidth(context, row.percentageLabel, cellStyle) +
          horizontalPadding,
    );
    unclimbed = math.max(
      unclimbed,
      _measureTextWidth(context, row.unclimbedLabel, cellStyle) +
          horizontalPadding,
    );
    ascents = math.max(
      ascents,
      _measureTextWidth(context, row.ascentCountLabel, cellStyle) +
          horizontalPadding,
    );
  }

  const rowHorizontalPadding = UiConstants.rowHorizontalPadding;
  final totalWidth =
      list +
      totalPeaks +
      climbed +
      percentage +
      unclimbed +
      ascents +
      actions +
      rowHorizontalPadding;
  return (
    list: list,
    totalPeaks: totalPeaks,
    climbed: climbed,
    percentage: percentage,
    unclimbed: unclimbed,
    ascents: ascents,
    actions: actions,
    totalWidth: totalWidth,
  );
}

_PeakTableWidths _resolvePeakTableWidths(
  BuildContext context,
  _PeakListSummaryRow? selectedSummaryRow,
) {
  final theme = Theme.of(context);
  final headerStyle = theme.textTheme.labelLarge;
  final cellStyle = theme.textTheme.bodyMedium;
  const horizontalPadding = UiConstants.columnCellHorizontalPadding * 2;
  const columnGap = UiConstants.columnGap;
  const headerIconWidth = UiConstants.headerIconWidth;
  const headerLabelGap = UiConstants.headerLabelGap;
  const headerControlWidth = headerIconWidth + headerLabelGap;
  final rows = selectedSummaryRow?.peakRows ?? const <_PeakDetailRow>[];
  const ratingStarCount = 5;
  const ratingStarSize = 14.0;
  const ratingStarGap = 2.0;

  double rating =
      math.max(
        _measureTextWidth(context, 'Rating', headerStyle) + headerControlWidth,
        (ratingStarCount * ratingStarSize) +
            ((ratingStarCount - 1) * ratingStarGap),
      ) +
      horizontalPadding;
  double peakName =
      math.max(
        _measureTextWidth(context, 'Peak Name', headerStyle) +
            headerControlWidth,
        0,
      ) +
      horizontalPadding;
  double elevation =
      math.max(
        _measureTextWidth(context, 'Height', headerStyle) + headerControlWidth,
        0,
      ) +
      horizontalPadding;
  double ascentDate =
      math.max(
        _measureTextWidth(context, 'Ascent\nDate', headerStyle) +
            headerControlWidth,
        0,
      ) +
      horizontalPadding;
  double ascents =
      math.max(
        _measureTextWidth(context, 'Ascents', headerStyle) + headerControlWidth,
        0,
      ) +
      horizontalPadding;
  double difficulty =
      math.max(
        _measureTextWidth(context, 'Difficulty', headerStyle) +
            headerControlWidth,
        0,
      ) +
      horizontalPadding;
  double duration =
      math.max(
        _measureTextWidth(context, 'Duration', headerStyle) +
            headerControlWidth,
        0,
      ) +
      horizontalPadding;

  for (final row in rows) {
    rating = math.max(
      rating,
      row.hasRating
          ? (ratingStarCount * ratingStarSize) +
                ((ratingStarCount - 1) * ratingStarGap) +
                horizontalPadding
          : horizontalPadding,
    );
    peakName = math.max(
      peakName,
      _measureTextWidth(context, row.name, cellStyle) + horizontalPadding,
    );
    elevation = math.max(
      elevation,
      _measureTextWidth(context, row.elevationLabel, cellStyle) +
          horizontalPadding,
    );
    ascentDate = math.max(
      ascentDate,
      _measureTextWidth(context, row.ascentDateLabel, cellStyle) +
          horizontalPadding,
    );
    ascents = math.max(
      ascents,
      _measureTextWidth(context, row.ascentCountLabel, cellStyle) +
          horizontalPadding,
    );
    difficulty = math.max(
      difficulty,
      _measureTextWidth(context, row.difficultyLabel, cellStyle) +
          horizontalPadding,
    );
    duration = math.max(
      duration,
      _measureTextWidth(context, row.durationDisplayLabel, cellStyle) +
          horizontalPadding,
    );
  }

  peakName = math.min(peakName, 180.0);
  ascentDate = math.min(ascentDate, 88.0);
  difficulty = math.min(difficulty, 110.0);
  duration = math.min(duration, 96.0);

  return (
    rating: rating,
    peakName: peakName,
    elevation: elevation,
    ascentDate: ascentDate,
    ascents: ascents,
    difficulty: difficulty,
    duration: duration,
    totalWidth:
        rating +
        peakName +
        elevation +
        ascentDate +
        ascents +
        difficulty +
        duration +
        (columnGap * 6),
  );
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.rows,
    required this.selectedPeakListId,
    required this.selectedSummaryRow,
    required this.selectedMapPeak,
    required this.miniPeakMapKey,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSelected,
    required this.onSortSelected,
    required this.onDeleteRequested,
    required this.filePicker,
    required this.importRunner,
    required this.duplicateNameChecker,
    required this.peakListRepository,
    required this.onPeakSelected,
  });

  final List<_PeakListSummaryRow> rows;
  final int? selectedPeakListId;
  final _PeakListSummaryRow? selectedSummaryRow;
  final _MapPeak? selectedMapPeak;
  final GlobalKey<_MiniPeakMapState> miniPeakMapKey;
  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<int> onSelected;
  final ValueChanged<_PeakListSortColumn> onSortSelected;
  final ValueChanged<int> onDeleteRequested;
  final PeakListFilePicker filePicker;
  final PeakListImportBackgroundRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final PeakListRepository peakListRepository;
  final ValueChanged<int> onPeakSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _SummaryListCard(
              rows: rows,
              selectedPeakListId: selectedPeakListId,
              sortColumn: sortColumn,
              sortAscending: sortAscending,
              onSelected: onSelected,
              onSortSelected: onSortSelected,
              onDeleteRequested: onDeleteRequested,
              filePicker: filePicker,
              importRunner: importRunner,
              duplicateNameChecker: duplicateNameChecker,
              peakListRepository: peakListRepository,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 7,
            child: _MiniPeakMapContainer(
              selectedSummaryRow: selectedSummaryRow,
              selectedMapPeak: selectedMapPeak,
              miniPeakMapKey: miniPeakMapKey,
              onPeakSelected: onPeakSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryListCard extends StatefulWidget {
  const _SummaryListCard({
    required this.rows,
    required this.selectedPeakListId,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSelected,
    required this.onSortSelected,
    required this.onDeleteRequested,
    required this.filePicker,
    required this.importRunner,
    required this.duplicateNameChecker,
    required this.peakListRepository,
  });

  final List<_PeakListSummaryRow> rows;
  final int? selectedPeakListId;
  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<int> onSelected;
  final ValueChanged<_PeakListSortColumn> onSortSelected;
  final ValueChanged<int> onDeleteRequested;
  final PeakListFilePicker filePicker;
  final PeakListImportBackgroundRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final PeakListRepository peakListRepository;

  @override
  State<_SummaryListCard> createState() => _SummaryListCardState();
}

class _SummaryListCardState extends State<_SummaryListCard> {
  int? _hoveredPeakListId;

  @override
  Widget build(BuildContext context) {
    final widths = _resolveSummaryTableWidths(context, widget.rows);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const headerActionsWidth = 128.0;
                  const headerActionsClearance = 24.0;
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: widths.totalWidth + headerActionsWidth,
                          height: constraints.maxHeight,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: headerActionsWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SummaryHeader(
                                  sortColumn: widget.sortColumn,
                                  sortAscending: widget.sortAscending,
                                  onSortSelected: widget.onSortSelected,
                                  widths: widths,
                                ),
                                const SizedBox(height: headerActionsClearance),
                                Expanded(
                                  child: widget.rows.isEmpty
                                      ? const Center(
                                          child: Card(
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text(
                                                'No peak lists exist. Import a CSV to get started.',
                                                key: Key(
                                                  'peak-lists-empty-message',
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          key: const Key(
                                            'peak-lists-summary-table-scroll',
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final row in widget.rows)
                                                _SummaryRowCard(
                                                  row: row,
                                                  selectedPeakListId:
                                                      widget.selectedPeakListId,
                                                  widths: widths,
                                                  isHovered:
                                                      _hoveredPeakListId ==
                                                      row.peakList.peakListId,
                                                  onHoverChanged: (value) {
                                                    final peakListId =
                                                        row.peakList.peakListId;
                                                    if (!value &&
                                                        _hoveredPeakListId !=
                                                            peakListId) {
                                                      return;
                                                    }
                                                    final nextHoveredPeakListId =
                                                        value
                                                        ? peakListId
                                                        : null;
                                                    if (_hoveredPeakListId ==
                                                        nextHoveredPeakListId) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      _hoveredPeakListId =
                                                          nextHoveredPeakListId;
                                                    });
                                                  },
                                                  onSelected: widget.onSelected,
                                                  onDeleteRequested:
                                                      widget.onDeleteRequested,
                                                ),
                                            ],
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _SummaryHeaderActions(
                          filePicker: widget.filePicker,
                          importRunner: widget.importRunner,
                          duplicateNameChecker: widget.duplicateNameChecker,
                          peakListRepository: widget.peakListRepository,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryHeaderActions extends ConsumerWidget {
  const _SummaryHeaderActions({
    required this.filePicker,
    required this.importRunner,
    required this.duplicateNameChecker,
    required this.peakListRepository,
  });

  final PeakListFilePicker filePicker;
  final PeakListImportBackgroundRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final PeakListRepository peakListRepository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fabForeground = _fabForegroundColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LeftTooltipFab(
          message: 'Import Peak List',
          child: FloatingActionButton.small(
            key: const Key('peak-lists-import-fab'),
            heroTag: 'peak-list-import',
            backgroundColor: Colors.transparent,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            disabledElevation: 0,
            mouseCursor: SystemMouseCursors.click,
            onPressed: () async {
              await showDialog<bool>(
                context: context,
                builder: (context) {
                  return PeakListImportDialog(
                    filePicker: filePicker,
                    onImport:
                        ({required String listName, required String csvPath}) {
                          return _startBackgroundImport(
                            ref,
                            listName: listName,
                            csvPath: csvPath,
                          );
                        },
                    duplicateNameChecker: duplicateNameChecker,
                  );
                },
              );
            },
            child: Icon(Icons.upload_file, color: fabForeground),
          ),
        ),
      ],
    );
  }

  Future<bool> _startBackgroundImport(
    WidgetRef ref, {
    required String listName,
    required String csvPath,
  }) async {
    final jobsNotifier = ref.read(backgroundJobsProvider.notifier);
    final startResult = jobsNotifier.startJob(
      kind: BackgroundJobKind.importPeakList,
      label: 'Import Peak List',
      progress: BackgroundJobProgress(
        label: 'Rows processed',
        statusText: '0 / 0 rows',
        currentFileName: p.basename(csvPath),
      ),
    );
    if (!startResult.isStarted) {
      return false;
    }

    final openJobsAction = BackgroundJobsSnackBarAction(
      key: const Key('background-jobs-snackbar-open-jobs'),
      label: 'Open Jobs',
      onPressed: jobsNotifier.openPanel,
    );
    jobsNotifier.queueSnackBar(
      message: 'Import started',
      actions: [openJobsAction],
    );

    unawaited(
      _runBackgroundImport(
        ref,
        jobId: startResult.job!.id,
        listName: listName,
        csvPath: csvPath,
        openJobsAction: openJobsAction,
      ),
    );
    return true;
  }

  Future<void> _runBackgroundImport(
    WidgetRef ref, {
    required String jobId,
    required String listName,
    required String csvPath,
    required BackgroundJobsSnackBarAction openJobsAction,
  }) async {
    final jobsNotifier = ref.read(backgroundJobsProvider.notifier);

    try {
      final result = await importRunner(
        listName: listName,
        csvPath: csvPath,
        onProgress: (progress) {
          jobsNotifier.updateRunningJob(
            jobId: jobId,
            progress: BackgroundJobProgress(
              label: 'Rows processed',
              statusText:
                  '${progress.processedRows} / ${progress.totalRows} rows',
              currentFileName: progress.currentFileName,
              percent: progress.percent,
            ),
          );
        },
      );

      final resolvedPeakListId = _resolvePeakListId(result);
      final openListAction = resolvedPeakListId == null
          ? null
          : BackgroundJobsSnackBarAction(
              key: const Key('background-jobs-snackbar-open-list'),
              label: 'Open List',
              onPressed: () => _openImportedList(ref, resolvedPeakListId),
            );

      if (resolvedPeakListId != null && _isPeakListsScreenVisible()) {
        _openImportedList(ref, resolvedPeakListId);
      }

      jobsNotifier.completeRunningJob(
        jobId: jobId,
        summary: _importSummary(result),
        detailLines: _importDetailLines(result),
        hasWarnings:
            result.warningCount > 0 ||
            result.ambiguousCount > 0 ||
            result.importLogNote != null,
      );
      jobsNotifier.queueSnackBar(
        message: 'Import complete: ${_importSummary(result)}',
        actions: [
          openJobsAction,
          ...?switch (openListAction) {
            null => null,
            final openListAction => <BackgroundJobsSnackBarAction>[
              openListAction,
            ],
          },
        ],
      );
    } catch (error) {
      final message = _formatImportError(error);
      jobsNotifier.failRunningJob(jobId: jobId, summary: message);
      jobsNotifier.queueSnackBar(
        message: 'Import failed: $message',
        actions: [openJobsAction],
      );
    }
  }

  int? _resolvePeakListId(PeakListImportPresentationResult result) {
    final peakListId = result.peakListId;
    if (peakListId != null) {
      return peakListId;
    }
    final listName = result.listName;
    if (listName == null) {
      return null;
    }
    return peakListRepository.findByName(listName)?.peakListId;
  }

  bool _isPeakListsScreenVisible() {
    return router.routerDelegate.currentConfiguration.uri.path == '/peaks';
  }

  void _openImportedList(WidgetRef ref, int peakListId) {
    ref
        .read(mapProvider.notifier)
        .selectPeakList(
          PeakListSelectionMode.specificList,
          peakListId: peakListId,
        );
    router.go('/peaks?selectedPeakListId=$peakListId');
  }

  String _importSummary(PeakListImportPresentationResult result) {
    final parts = <String>['${formatCount(result.importedCount)} imported'];
    if (result.skippedCount > 0) {
      parts.add('${formatCount(result.skippedCount)} skipped');
    }
    if (result.ambiguousCount > 0) {
      parts.add('${formatCount(result.ambiguousCount)} ambiguous');
    }
    return parts.join(', ');
  }

  List<String> _importDetailLines(PeakListImportPresentationResult result) {
    return <String>[
      'Imported: ${result.importedCount}',
      'Skipped: ${result.skippedCount}',
      'Ambiguous: ${result.ambiguousCount}',
      'Warnings: ${result.warningCount}',
      ...?switch (result.importLogNote) {
        null => null,
        final note => <String>[note],
      },
    ];
  }

  String _formatImportError(Object error) {
    if (error case FormatException(:final message)) {
      return message;
    }
    return error.toString();
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortSelected,
    required this.widths,
  });

  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_PeakListSortColumn> onSortSelected;
  final _SummaryTableWidths widths;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      key: const Key('peak-lists-summary-header'),
      children: [
        SizedBox(
          width: widths.list,
          child: _SortHeaderCell(
            label: 'List',
            column: _PeakListSortColumn.name,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.totalPeaks,
          child: _SortHeaderCell(
            label: 'Total Peaks',
            column: _PeakListSortColumn.totalPeaks,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.climbed,
          child: _SortHeaderCell(
            label: 'Climbed',
            column: _PeakListSortColumn.climbed,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.percentage,
          child: _SortHeaderCell(
            label: 'Percentage',
            column: _PeakListSortColumn.percentage,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.unclimbed,
          child: _SortHeaderCell(
            label: 'Unclimbed',
            column: _PeakListSortColumn.unclimbed,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.ascents,
          child: _SortHeaderCell(
            label: 'Ascents',
            column: _PeakListSortColumn.ascents,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(
          width: widths.actions,
          child: Text('Actions', style: style),
        ),
      ],
    );
  }
}

class _SortHeaderCell extends StatelessWidget {
  const _SortHeaderCell({
    required this.label,
    required this.column,
    required this.sortColumn,
    required this.sortAscending,
    required this.onTap,
    required this.textStyle,
  });

  final String label;
  final _PeakListSortColumn column;
  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_PeakListSortColumn> onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final isActive = column == sortColumn;
    final icon = isActive
        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.unfold_more;

    return InkWell(
      key: Key('peak-lists-sort-${column.name}'),
      onTap: () => onTap(column),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            ),
            Icon(
              icon,
              key: Key('peak-lists-sort-icon-${column.name}'),
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _SummaryRowCard extends StatelessWidget {
  const _SummaryRowCard({
    required this.row,
    required this.selectedPeakListId,
    required this.widths,
    required this.isHovered,
    required this.onHoverChanged,
    required this.onSelected,
    required this.onDeleteRequested,
  });

  final _PeakListSummaryRow row;
  final int? selectedPeakListId;
  final _SummaryTableWidths widths;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final peakListId = row.peakList.peakListId;
    final isSelected = peakListId == selectedPeakListId;
    final isHovered = this.isHovered && !isSelected;
    final decoration = isSelected
        ? _selectedRowDecoration(context)
        : isHovered
        ? BoxDecoration(color: rowTheme.hoverColor)
        : null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        key: Key('peak-lists-row-decoration-$peakListId'),
        decoration: decoration,
        child: InkWell(
          key: Key('peak-lists-row-$peakListId'),
          onTap: () => onSelected(peakListId),
          onHover: onHoverChanged,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: widths.list,
                  child: Text(
                    row.peakList.name,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.totalPeaks,
                  child: Text(
                    row.totalPeaksLabel,
                    key: Key('peak-lists-total-$peakListId'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.climbed,
                  child: Text(
                    row.climbedLabel,
                    key: Key('peak-lists-climbed-$peakListId'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.percentage,
                  child: Text(
                    row.percentageLabel,
                    key: Key('peak-lists-percentage-$peakListId'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.unclimbed,
                  child: Text(
                    row.unclimbedLabel,
                    key: Key('peak-lists-unclimbed-$peakListId'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.ascents,
                  child: Text(
                    row.ascentCountLabel,
                    key: Key('peak-lists-ascents-$peakListId'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: isHovered ? rowTheme.hoveredTextColor : null,
                    ),
                  ),
                ),
                SizedBox(
                  width: widths.actions,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: 'Delete ${row.peakList.name}',
                      child: InkResponse(
                        key: Key('peak-lists-delete-$peakListId'),
                        onTap: () => onDeleteRequested(peakListId),
                        radius: 16,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_forever,
                            size: 18,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _selectedRowDecoration(BuildContext context) {
  var rowColour = Theme.of(context).colorScheme.primaryContainer;
  return BoxDecoration(
    color: darken(rowColour, 0.30),
    border: Border(
      top: BorderSide(color: darken(rowColour, 0.08)),
      bottom: BorderSide(color: darken(rowColour, 0.08)),
    ),
  );
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({
    required this.selectedSummaryRow,
    required this.selectedPeakId,
    required this.onSummaryPeakSelected,
    required this.onPeakSelected,
    required this.onAddPeakRequested,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final int? selectedPeakId;
  final ValueChanged<int> onSummaryPeakSelected;
  final Future<void> Function(int) onPeakSelected;
  final Future<void> Function() onAddPeakRequested;

  @override
  Widget build(BuildContext context) {
    final fabBackground = _fabBackgroundColor(context);
    final fabForeground = _fabForegroundColor(context);

    final summaryRow = selectedSummaryRow;
    final title = summaryRow?.peakList.name ?? 'Peak List Details';
    final summaryText = summaryRow?.buildSummarySentence();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: const Key('peak-lists-selected-title'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (selectedSummaryRow != null)
                LeftTooltipFab(
                  message: 'Add New Peak',
                  child: FloatingActionButton.small(
                    key: const Key('peak-lists-add-peak'),
                    heroTag: 'peak-list-add',
                    backgroundColor: fabBackground,
                    onPressed: onAddPeakRequested,
                    child: Icon(Icons.add_circle_outline, color: fabForeground),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (summaryText != null) ...[
            _PeakListSummarySentence(
              summaryRow: summaryRow!,
              onPeakSelected: onSummaryPeakSelected,
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            key: const Key('peak-lists-right-column-content-scroll'),
            child: _PeakDetailsTableCard(
              selectedSummaryRow: selectedSummaryRow,
              selectedPeakId: selectedPeakId,
              onPeakSelected: onPeakSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakDetailsTableCard extends StatefulWidget {
  const _PeakDetailsTableCard({
    required this.selectedSummaryRow,
    required this.selectedPeakId,
    required this.onPeakSelected,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final int? selectedPeakId;
  final Future<void> Function(int) onPeakSelected;

  @override
  State<_PeakDetailsTableCard> createState() => _PeakDetailsTableCardState();
}

class _PeakDetailsTableCardState extends State<_PeakDetailsTableCard> {
  _PeakDetailSortColumn? _sortColumn = _PeakDetailSortColumn.ascentDate;
  bool _sortAscending = false;
  int? _hoveredPeakId;
  final _tableScrollKey = GlobalKey();
  final Map<int, GlobalKey> _rowKeys = {};

  @override
  void didUpdateWidget(covariant _PeakDetailsTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeakListId = oldWidget.selectedSummaryRow?.peakList.peakListId;
    final newPeakListId = widget.selectedSummaryRow?.peakList.peakListId;
    if (oldWidget.selectedPeakId != widget.selectedPeakId) {
      _centerSelectedRowIfNeeded();
    }
    if (oldPeakListId != newPeakListId) {
      _sortColumn = _PeakDetailSortColumn.ascentDate;
      _sortAscending = false;
      _hoveredPeakId = null;
      _rowKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.selectedSummaryRow?.peakRows ?? const <_PeakDetailRow>[];
    final sortedRows = _sortRows(rows);
    final widths = _resolvePeakTableWidths(context, widget.selectedSummaryRow);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              key: _tableScrollKey,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: widths.totalWidth,
                height: constraints.maxHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PeakDetailsHeaderRow(
                      textStyle: Theme.of(context).textTheme.labelLarge,
                      widths: widths,
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onSortSelected: _handleSortSelected,
                    ),
                    const Divider(height: 16),
                    if (widget.selectedSummaryRow == null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'No peak lists exist. Import a CSV to get started.',
                        ),
                      ),
                    Expanded(
                      child: rows.isEmpty
                          ? const SizedBox.shrink()
                          : SingleChildScrollView(
                              key: const Key('peak-lists-peak-table-scroll'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final row in sortedRows)
                                    KeyedSubtree(
                                      key: Key(
                                        'peak-lists-details-row-${row.peakId}',
                                      ),
                                      child: _PeakDetailsTableRow(
                                        key: _rowKeyFor(row.peakId),
                                        row: row,
                                        widths: widths,
                                        selectedPeakId: widget.selectedPeakId,
                                        isHovered: _hoveredPeakId == row.peakId,
                                        onHoverChanged: (value) {
                                          if (!value &&
                                              _hoveredPeakId != row.peakId) {
                                            return;
                                          }
                                          final nextHoveredPeakId = value
                                              ? row.peakId
                                              : null;
                                          if (_hoveredPeakId ==
                                              nextHoveredPeakId) {
                                            return;
                                          }
                                          setState(() {
                                            _hoveredPeakId = nextHoveredPeakId;
                                          });
                                        },
                                        onPeakSelected: widget.onPeakSelected,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  GlobalKey _rowKeyFor(int peakId) {
    return _rowKeys.putIfAbsent(peakId, () => GlobalKey());
  }

  void _centerSelectedRowIfNeeded() {
    final selectedPeakId = widget.selectedPeakId;
    if (selectedPeakId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedPeakId != selectedPeakId) {
        return;
      }

      final rowContext = _rowKeys[selectedPeakId]?.currentContext;
      final tableContext = _tableScrollKey.currentContext;
      if (rowContext == null || tableContext == null) {
        return;
      }

      final rowBox = rowContext.findRenderObject() as RenderBox?;
      final tableBox = tableContext.findRenderObject() as RenderBox?;
      if (rowBox == null || tableBox == null) {
        return;
      }

      final rowTopLeft = rowBox.localToGlobal(Offset.zero);
      final rowRect = rowTopLeft & rowBox.size;
      final tableTopLeft = tableBox.localToGlobal(Offset.zero);
      final tableRect = tableTopLeft & tableBox.size;

      final isVisible =
          rowRect.top >= tableRect.top && rowRect.bottom <= tableRect.bottom;
      if (isVisible) {
        return;
      }

      Scrollable.ensureVisible(
        rowContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleSortSelected(_PeakDetailSortColumn column) {
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
        return;
      }
      _sortAscending = !_sortAscending;
    });
  }

  List<_PeakDetailRow> _sortRows(List<_PeakDetailRow> rows) {
    if (_sortColumn == null) {
      return rows;
    }

    if (_sortColumn == _PeakDetailSortColumn.ascentDate) {
      final validRows = rows.where((row) => row.ascentDate != null).toList();
      final blankRows = rows.where((row) => row.ascentDate == null).toList();
      validRows.sort((left, right) {
        final comparison = _compareNullableDates(
          left.ascentDate,
          right.ascentDate,
        );
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        return left.peakId.compareTo(right.peakId);
      });
      blankRows.sort((left, right) => left.peakId.compareTo(right.peakId));
      return [...validRows, ...blankRows];
    }

    if (_sortColumn == _PeakDetailSortColumn.ascents) {
      final sorted = List<_PeakDetailRow>.from(rows);
      sorted.sort((left, right) {
        final leftBlank = left.ascentCount == 0;
        final rightBlank = right.ascentCount == 0;
        if (leftBlank != rightBlank) {
          return leftBlank ? 1 : -1;
        }

        if (!leftBlank) {
          final comparison = left.ascentCount.compareTo(right.ascentCount);
          if (comparison != 0) {
            return _sortAscending ? comparison : -comparison;
          }
        }

        final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return left.peakId.compareTo(right.peakId);
      });
      return sorted;
    }

    if (_sortColumn == _PeakDetailSortColumn.rating) {
      final ratedRows = rows.where((row) => row.rating != null).toList();
      final blankRows = rows.where((row) => row.rating == null).toList();
      ratedRows.sort((left, right) {
        final comparison = left.rating!.compareTo(right.rating!);
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        return left.peakId.compareTo(right.peakId);
      });
      blankRows.sort((left, right) => left.peakId.compareTo(right.peakId));
      return [...ratedRows, ...blankRows];
    }

    if (_sortColumn == _PeakDetailSortColumn.duration) {
      final durationRows = rows
          .where((row) => row.durationMinutes != null)
          .toList();
      final blankRows = rows
          .where((row) => row.durationMinutes == null)
          .toList();
      durationRows.sort((left, right) {
        final comparison = left.durationMinutes!.compareTo(
          right.durationMinutes!,
        );
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        return left.peakId.compareTo(right.peakId);
      });
      blankRows.sort((left, right) => left.peakId.compareTo(right.peakId));
      return [...durationRows, ...blankRows];
    }

    if (_sortColumn == _PeakDetailSortColumn.difficulty) {
      final difficultyRows = rows.where((row) => row.hasDifficulty).toList();
      final blankRows = rows.where((row) => !row.hasDifficulty).toList();
      difficultyRows.sort((left, right) {
        final comparison = comparePeaksByDifficulty(left.peak!, right.peak!);
        if (comparison != 0) {
          return _sortAscending ? comparison : -comparison;
        }
        return left.peakId.compareTo(right.peakId);
      });
      blankRows.sort((left, right) => left.peakId.compareTo(right.peakId));
      return [...difficultyRows, ...blankRows];
    }

    final sorted = List<_PeakDetailRow>.from(rows);
    sorted.sort((left, right) {
      final direction = _sortAscending ? 1 : -1;
      final comparison = switch (_sortColumn!) {
        _PeakDetailSortColumn.rating => left.rating!.compareTo(right.rating!),
        _PeakDetailSortColumn.name => left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        ),
        _PeakDetailSortColumn.elevation => _compareNullableNumbers(
          left.elevation,
          right.elevation,
        ),
        _PeakDetailSortColumn.ascentDate => _compareNullableDates(
          left.ascentDate,
          right.ascentDate,
        ),
        _PeakDetailSortColumn.ascents => left.ascentCount.compareTo(
          right.ascentCount,
        ),
        _PeakDetailSortColumn.difficulty => comparePeaksByDifficulty(
          left.peak!,
          right.peak!,
        ),
        _PeakDetailSortColumn.duration => left.durationMinutes!.compareTo(
          right.durationMinutes!,
        ),
      };
      if (comparison != 0) {
        return comparison * direction;
      }
      return left.peakId.compareTo(right.peakId);
    });
    return sorted;
  }
}

int _compareNullableNumbers(num? left, num? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

int _compareNullableDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

class _PeakDetailsTableRow extends StatelessWidget {
  const _PeakDetailsTableRow({
    super.key,
    required this.row,
    required this.widths,
    required this.selectedPeakId,
    required this.isHovered,
    required this.onHoverChanged,
    required this.onPeakSelected,
  });

  final _PeakDetailRow row;
  final _PeakTableWidths widths;
  final int? selectedPeakId;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final Future<void> Function(int) onPeakSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final isSelected = row.peakId == selectedPeakId;
    final isHovered = this.isHovered && !isSelected;
    final decoration = isSelected
        ? _selectedRowDecoration(context)
        : isHovered
        ? BoxDecoration(color: rowTheme.hoverColor)
        : null;
    final textStyle = isHovered
        ? theme.textTheme.bodyMedium?.copyWith(color: rowTheme.hoveredTextColor)
        : null;

    return Container(
      decoration: decoration,
      child: InkWell(
        onTap: () async {
          await onPeakSelected(row.peakId);
        },
        onHover: onHoverChanged,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: widths.rating,
                child: _PeakRatingCell(
                  peakId: row.peakId,
                  rating: row.rating,
                  textStyle: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.peakName,
                child: Text(
                  row.name,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.elevation,
                child: Text(
                  row.elevationLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.ascentDate,
                child: Text(
                  row.ascentDateLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.ascents,
                child: Text(
                  row.ascentCountLabel,
                  key: Key('peak-lists-details-ascents-${row.peakId}'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.difficulty,
                child: Text(
                  row.difficultyLabel,
                  key: Key('peak-lists-details-difficulty-${row.peakId}'),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widths.duration,
                child: Text(
                  row.durationDisplayLabel,
                  key: Key('peak-lists-details-duration-${row.peakId}'),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeakDetailsHeaderRow extends StatelessWidget {
  const _PeakDetailsHeaderRow({
    required this.textStyle,
    required this.widths,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortSelected,
  });

  final TextStyle? textStyle;
  final _PeakTableWidths widths;
  final _PeakDetailSortColumn? sortColumn;
  final bool sortAscending;
  final ValueChanged<_PeakDetailSortColumn> onSortSelected;

  @override
  Widget build(BuildContext context) {
    const columnGap = SizedBox(width: UiConstants.columnGap);
    return Row(
      children: [
        SizedBox(
          width: widths.rating,
          child: _DetailSortHeaderCell(
            label: 'Rating',
            column: _PeakDetailSortColumn.rating,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.peakName,
          child: _DetailSortHeaderCell(
            label: 'Peak Name',
            column: _PeakDetailSortColumn.name,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.elevation,
          child: _DetailSortHeaderCell(
            label: 'Height',
            column: _PeakDetailSortColumn.elevation,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
            textAlign: TextAlign.right,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.ascentDate,
          child: _DetailSortHeaderCell(
            label: 'Ascent\nDate',
            column: _PeakDetailSortColumn.ascentDate,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
            textAlign: TextAlign.right,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.ascents,
          child: _DetailSortHeaderCell(
            label: 'Ascents',
            column: _PeakDetailSortColumn.ascents,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
            textAlign: TextAlign.right,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.difficulty,
          child: _DetailSortHeaderCell(
            label: 'Difficulty',
            column: _PeakDetailSortColumn.difficulty,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
          ),
        ),
        columnGap,
        SizedBox(
          width: widths.duration,
          child: _DetailSortHeaderCell(
            label: 'Duration',
            column: _PeakDetailSortColumn.duration,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: textStyle,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _PeakRatingCell extends StatelessWidget {
  const _PeakRatingCell({
    required this.peakId,
    required this.rating,
    required this.textStyle,
  });

  static const _starSize = 14.0;
  static const _starSpacing = 2.0;

  final int peakId;
  final double? rating;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final roundedRating = roundPeakRatingForDisplay(rating);
    if (roundedRating == null) {
      return Text(
        '',
        key: Key('peak-lists-details-rating-$peakId'),
        style: textStyle,
      );
    }

    const fullStar = Icons.star;
    const halfStar = Icons.star_half;
    const emptyStar = Icons.star_border;
    final fullStarCount = roundedRating.floor();
    final hasHalfStar = roundedRating - fullStarCount >= 0.5;
    final filledStarColor = Colors.amber;
    final emptyStarColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.38);

    return Row(
      key: Key('peak-lists-details-rating-$peakId'),
      spacing: _starSpacing,
      children: [
        for (var index = 0; index < 5; index++)
          Icon(
            index < fullStarCount
                ? fullStar
                : index == fullStarCount && hasHalfStar
                ? halfStar
                : emptyStar,
            key: Key('peak-lists-details-rating-$peakId-star-$index'),
            size: _starSize,
            color:
                index < fullStarCount || (index == fullStarCount && hasHalfStar)
                ? filledStarColor
                : emptyStarColor,
          ),
      ],
    );
  }
}

class _DetailSortHeaderCell extends StatelessWidget {
  const _DetailSortHeaderCell({
    required this.label,
    required this.column,
    required this.sortColumn,
    required this.sortAscending,
    required this.onTap,
    required this.textStyle,
    this.textAlign = TextAlign.left,
  });

  final String label;
  final _PeakDetailSortColumn column;
  final _PeakDetailSortColumn? sortColumn;
  final bool sortAscending;
  final ValueChanged<_PeakDetailSortColumn> onTap;
  final TextStyle? textStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final isActive = column == sortColumn;
    final icon = isActive
        ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
        : Icons.unfold_more;

    return InkWell(
      key: Key('peak-lists-details-sort-${column.name}'),
      onTap: () => onTap(column),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textStyle,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                textAlign: textAlign,
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              key: Key('peak-lists-details-sort-icon-${column.name}'),
              size: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

Color _fabBackgroundColor(BuildContext context) {
  return Theme.of(context).appBarTheme.backgroundColor ??
      Theme.of(context).colorScheme.surface;
}

Color _fabForegroundColor(BuildContext context) {
  return Theme.of(context).appBarTheme.foregroundColor ??
      Theme.of(context).colorScheme.onSurface;
}

class _MiniPeakMapContainer extends StatelessWidget {
  const _MiniPeakMapContainer({
    required this.selectedSummaryRow,
    required this.selectedMapPeak,
    required this.miniPeakMapKey,
    required this.onPeakSelected,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final _MapPeak? selectedMapPeak;
  final GlobalKey<_MiniPeakMapState> miniPeakMapKey;
  final ValueChanged<int> onPeakSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _MiniPeakMap(
                    key: miniPeakMapKey,
                    selectedSummaryRow: selectedSummaryRow,
                    selectedMapPeak: selectedMapPeak,
                    onPeakSelected: onPeakSelected,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniPeakMap extends ConsumerStatefulWidget {
  const _MiniPeakMap({
    required this.selectedSummaryRow,
    required this.selectedMapPeak,
    required this.onPeakSelected,
    super.key,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final _MapPeak? selectedMapPeak;
  final ValueChanged<int> onPeakSelected;

  @override
  ConsumerState<_MiniPeakMap> createState() => _MiniPeakMapState();
}

class _MiniPeakMapState extends ConsumerState<_MiniPeakMap> {
  final _mapController = MapController();
  final _peakProjectionCache = PeakProjectionCache();
  PeakInfoContent? _popupContent;
  int? _hoveredPeakId;
  bool _hoveringCluster = false;
  Timer? _scrollTimer;
  double _scrollDx = 0;
  double _scrollDy = 0;
  bool _historyResetPending = true;
  PeakListMiniMapDebugState? _debugState;
  List<_MiniPeakMapCameraState> _cameraHistory = const [];
  int _cameraHistoryIndex = -1;
  int _cameraFitRequestToken = 0;
  Timer? _wheelCommitTimer;
  Offset? _pointerDownPosition;
  Offset? _lastDragPosition;
  bool _isPointerDown = false;
  bool _pointerMovedBeyondClickThreshold = false;
  LatLng? _trackpadGestureCenter;
  double? _trackpadGestureZoom;
  static const _tapThreshold = 24.0;
  static const _clickDragThreshold = 5.0;
  static const _wheelPixelsPerZoomLevel = 200.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitCameraToSelectedSummaryRow();
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _wheelCommitTimer?.cancel();
    super.dispose();
  }

  KeyEventResult handleScreenKeyEvent(KeyEvent event) {
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.comma ||
        key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.less ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.greater) {
      if (event is KeyDownEvent) {
        final currentZoom = _mapController.camera.zoom;
        final newZoom =
            (key == LogicalKeyboardKey.equal ||
                key == LogicalKeyboardKey.period ||
                key == LogicalKeyboardKey.greater ||
                key == LogicalKeyboardKey.add)
            ? currentZoom + 1
            : currentZoom - 1;
        _moveCamera(
          center: _mapController.camera.center,
          zoom: newZoom,
          resetHistory: false,
        );
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent) {
        _startScrolling(0, -1);
      } else if (event is KeyUpEvent) {
        _stopScrolling();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.arrowDown) {
      if (event is KeyDownEvent) {
        _startScrolling(0, 1);
      } else if (event is KeyUpEvent) {
        _stopScrolling();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyH || key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyDownEvent) {
        _startScrolling(-1, 0);
      } else if (event is KeyUpEvent) {
        _stopScrolling();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.keyL ||
        key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyDownEvent) {
        _startScrolling(1, 0);
      } else if (event is KeyUpEvent) {
        _stopScrolling();
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isMetaPressed &&
        key == LogicalKeyboardKey.bracketLeft) {
      _navigateCameraHistory(-1);
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isMetaPressed &&
        key == LogicalKeyboardKey.bracketRight) {
      _navigateCameraHistory(1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void cancelKeyboardScroll() {
    if (_scrollTimer == null) {
      return;
    }
    _stopScrolling();
  }

  void _handlePointerDown(Offset localPosition) {
    _isPointerDown = true;
    _pointerMovedBeyondClickThreshold = false;
    _pointerDownPosition = localPosition;
    _lastDragPosition = localPosition;
    setState(() {});
  }

  void _handlePointerMove(Offset localPosition) {
    if (!_isPointerDown) {
      return;
    }

    final pointerDownPosition = _pointerDownPosition;
    final lastDragPosition = _lastDragPosition;
    if (pointerDownPosition == null || lastDragPosition == null) {
      return;
    }

    if (!_pointerMovedBeyondClickThreshold &&
        (localPosition - pointerDownPosition).distance > _clickDragThreshold) {
      _pointerMovedBeyondClickThreshold = true;
    }
    if (!_pointerMovedBeyondClickThreshold) {
      return;
    }

    _panCameraByDelta(localPosition - lastDragPosition);
    _lastDragPosition = localPosition;
  }

  void _handlePointerUp(Offset localPosition) {
    final treatAsDrag = _pointerMovedBeyondClickThreshold;
    _resetPointerInteraction();
    if (treatAsDrag) {
      _commitCameraFromController(resetHistory: false);
      return;
    }
    _handleMapTap(localPosition);
  }

  void _handlePointerCancel() {
    final treatAsDrag = _pointerMovedBeyondClickThreshold;
    _resetPointerInteraction();
    if (treatAsDrag) {
      _commitCameraFromController(resetHistory: false);
    }
  }

  void _resetPointerInteraction() {
    _isPointerDown = false;
    _pointerMovedBeyondClickThreshold = false;
    _pointerDownPosition = null;
    _lastDragPosition = null;
    setState(() {});
  }

  void _panCameraByDelta(Offset delta) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    final centerScreenOffset = Offset(
      camera.nonRotatedSize.width / 2,
      camera.nonRotatedSize.height / 2,
    );
    final targetCenter = camera.screenOffsetToLatLng(
      centerScreenOffset - delta,
    );
    _mapController.move(targetCenter, camera.zoom);
    setState(() {});
  }

  void _handleTrackpadPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadGestureCenter = _mapController.camera.center;
    _trackpadGestureZoom = _mapController.camera.zoom;
  }

  void _handleTrackpadPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final gestureCenter = _trackpadGestureCenter;
    final gestureZoom = _trackpadGestureZoom;
    if (gestureCenter == null || gestureZoom == null) {
      return;
    }

    final intent = classifyMapTrackpadGesture(
      pan: event.pan,
      scale: event.scale,
    );
    if (intent.type == MapTrackpadGestureType.none) {
      _mapController.move(gestureCenter, gestureZoom);
      setState(() {});
      return;
    }

    final targetZoom = (gestureZoom + intent.zoomDelta).clamp(
      1.0,
      MapConstants.peakMaxZoom.toDouble(),
    );
    _mapController.move(gestureCenter, targetZoom);
    setState(() {});
  }

  void _handleTrackpadPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadGestureCenter = null;
    _trackpadGestureZoom = null;
    _commitCameraFromController(resetHistory: false);
  }

  void _handlePointerSignal(PointerScrollEvent event) {
    if (event.kind != PointerDeviceKind.mouse) {
      return;
    }

    final zoomDelta = -event.scrollDelta.dy / _wheelPixelsPerZoomLevel;
    if (zoomDelta == 0) {
      return;
    }

    final currentZoom = _mapController.camera.zoom;
    final targetZoom = (currentZoom + zoomDelta).clamp(
      1.0,
      MapConstants.peakMaxZoom.toDouble(),
    );
    if ((targetZoom - currentZoom).abs() <= MapConstants.cameraEpsilon) {
      return;
    }

    _mapController.move(_mapController.camera.center, targetZoom);
    _wheelCommitTimer?.cancel();
    _wheelCommitTimer = Timer(MapConstants.cameraSaveDebounce, () {
      if (mounted) {
        _commitCameraFromController(resetHistory: false);
      }
    });
    setState(() {});
  }

  void showPopupForPeak(int peakId) {
    final tappedPeak = _peakForId(peakId);
    if (tappedPeak == null) {
      _clearPopup();
      return;
    }

    final content = resolvePeakInfoContent(
      peak: tappedPeak,
      peakListRepository: ref.read(peakListRepositoryProvider),
      tasmapRepository: ref.read(tasmapRepositoryProvider),
      peaksBaggedRepository: _readPeaksBaggedRepository(),
      gpxTrackRepository: _readGpxTrackRepository(),
    );
    setState(() {
      _popupContent = content;
    });
  }

  void _goToMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/map');
    });
  }

  void _openPeakOnMap(Peak peak) {
    ref
        .read(mapProvider.notifier)
        .requestCameraMove(
          center: LatLng(peak.latitude, peak.longitude),
          zoom: MapConstants.defaultZoom,
        );
    _goToMap();
  }

  void _openAscentTrackOnMap(PeakInfoAscentRow row) {
    if (!_isTrackOpenable(row.gpxId)) {
      return;
    }

    ref.read(mapProvider.notifier).showTrack(row.gpxId);
    _goToMap();
  }

  @override
  void didUpdateWidget(covariant _MiniPeakMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeakId = oldWidget.selectedMapPeak?.peak.osmId;
    final newPeakId = widget.selectedMapPeak?.peak.osmId;
    final oldListId = oldWidget.selectedSummaryRow?.peakList.peakListId;
    final newListId = widget.selectedSummaryRow?.peakList.peakListId;
    final popupPeakId = _popupContent?.peak.osmId;
    if ((oldPeakId != newPeakId || oldListId != newListId) &&
        popupPeakId != newPeakId) {
      _popupContent = null;
    }
    if (oldListId != newListId) {
      _cameraFitRequestToken += 1;
      _historyResetPending = true;
      _cameraHistory = const [];
      _cameraHistoryIndex = -1;
      final requestToken = _cameraFitRequestToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitCameraToSelectedSummaryRow(requestToken: requestToken);
        }
      });
    }
  }

  void _fitCameraToSelectedSummaryRow({int attempt = 0, int? requestToken}) {
    final token = requestToken ?? _cameraFitRequestToken;
    if (token != _cameraFitRequestToken) {
      return;
    }
    final summaryRow = widget.selectedSummaryRow;
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _fitCameraToSelectedSummaryRow(
              attempt: attempt + 1,
              requestToken: token,
            );
          }
        });
      }
      return;
    }

    _mapController.fitCamera(_resolveInitialCameraFit(summaryRow));
    _commitCameraFromController(
      resetHistory: _historyResetPending,
      appendToHistory: false,
    );
  }

  void _clearPopup() {
    if (_popupContent == null) {
      return;
    }
    setState(() {
      _popupContent = null;
    });
  }

  void _handleHover(Offset localPosition) {
    final summaryRow = widget.selectedSummaryRow;
    if (summaryRow == null || summaryRow.mapPeaks.isEmpty) {
      if (_hoveredPeakId != null) {
        setState(() {
          _hoveredPeakId = null;
        });
      }
      return;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    final viewportData = _buildPeakViewportData(
      summaryRow.mapPeaks,
      clusteringEnabled: ref.read(
        peakListMiniMapClusterDisplaySettingsProvider,
      ),
    );
    final cluster = hitTestPeakCluster(
      pointerPosition: localPosition,
      data: viewportData,
    );
    final peak = hitTestPeakFromViewportData(
      pointerPosition: localPosition,
      data: viewportData,
    );

    if (peak?.osmId == _hoveredPeakId &&
        (cluster != null) == _hoveringCluster) {
      return;
    }

    setState(() {
      _hoveredPeakId = peak?.osmId;
      _hoveringCluster = cluster != null;
    });
  }

  void _clearHover() {
    if (_hoveredPeakId == null && !_hoveringCluster) {
      return;
    }
    setState(() {
      _hoveredPeakId = null;
      _hoveringCluster = false;
    });
  }

  void _handleMapTap(Offset localPosition) {
    final summaryRow = widget.selectedSummaryRow;
    if (summaryRow == null || summaryRow.mapPeaks.isEmpty) {
      return;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    final viewportData = _buildPeakViewportData(
      summaryRow.mapPeaks,
      clusteringEnabled: ref.read(
        peakListMiniMapClusterDisplaySettingsProvider,
      ),
    );
    final tappedCluster = hitTestPeakCluster(
      pointerPosition: localPosition,
      data: viewportData,
    );
    if (tappedCluster != null) {
      _clearHover();
      _clearPopup();
      _expandPeakCluster(tappedCluster);
      return;
    }

    final hitPeak = hitTestPeakFromViewportData(
      pointerPosition: localPosition,
      data: viewportData,
    );
    final peakId =
        hitPeak?.osmId ??
        _findNearestPeakId(
          pointerPosition: localPosition,
          candidates: buildPeakHoverCandidatesFromViewportData(viewportData),
        );
    if (peakId == null) {
      _clearPopup();
      return;
    }

    widget.onPeakSelected(peakId);
    showPopupForPeak(peakId);
  }

  PeaksBaggedRepository _readPeaksBaggedRepository() {
    try {
      return ref.read(peaksBaggedRepositoryProvider);
    } catch (_) {
      return PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage());
    }
  }

  GpxTrackRepository _readGpxTrackRepository() {
    try {
      return ref.read(gpxTrackRepositoryProvider);
    } catch (_) {
      return GpxTrackRepository.test(InMemoryGpxTrackStorage());
    }
  }

  Peak? _peakForId(int peakId) {
    final summaryRow = widget.selectedSummaryRow;
    if (summaryRow == null) {
      return null;
    }

    for (final peak in summaryRow.mapPeaks) {
      if (peak.peak.osmId == peakId) {
        return peak.peak;
      }
    }

    return null;
  }

  bool _isTrackOpenable(int gpxId) {
    if (gpxId <= 0) {
      return false;
    }
    return _readGpxTrackRepository().findById(gpxId) != null;
  }

  int? _findNearestPeakId({
    required Offset pointerPosition,
    required List<PeakHoverCandidate> candidates,
  }) {
    int? nearestPeakId;
    double? nearestDistance;
    for (final candidate in candidates) {
      final distance = (pointerPosition - candidate.screenPosition).distance;
      if (distance > _tapThreshold) {
        continue;
      }
      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestPeakId = candidate.peakId;
      }
    }
    return nearestPeakId;
  }

  PeakClusterViewportData _buildPeakViewportData(
    List<_MapPeak> peaks, {
    required bool clusteringEnabled,
  }) {
    MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      return const PeakClusterViewportData(
        individualCandidates: [],
        clusters: [],
      );
    }

    return _peakProjectionCache.getOrBuild(
      peaks: [for (final peak in peaks) peak.peak],
      camera: camera,
      correlatedPeakIds: {
        for (final peak in peaks.where((peak) => peak.isClimbed))
          peak.peak.osmId,
      },
      untickedPeakColours: const <int, int>{},
      clusteringEnabled: clusteringEnabled,
    );
  }

  void _expandPeakCluster(PeakCluster cluster) {
    final points = cluster.points;
    if (points.isEmpty) {
      return;
    }

    final camera = _mapController.camera;
    if (peakClusterNeedsZoomFallback(points)) {
      _moveCamera(
        center: points.first,
        zoom: (camera.zoom + 2).clamp(
          MapConstants.peakMinZoom.toDouble(),
          MapConstants.peakMaxZoom.toDouble(),
        ),
        resetHistory: false,
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(MapConstants.peakClusterExpandPadding),
      ),
    );
    _commitCameraFromController(resetHistory: false);
  }

  void _startScrolling(double dx, double dy) {
    _scrollDx = dx * UiConstants.scrollSpeed;
    _scrollDy = dy * UiConstants.scrollSpeed;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(UiConstants.scrollInterval, (_) {
      if (_scrollDx != 0 || _scrollDy != 0) {
        _panCamera(_scrollDx, _scrollDy);
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollDx = 0;
    _scrollDy = 0;
    _commitCameraFromController(resetHistory: false);
  }

  void _panCamera(double dx, double dy) {
    final center = _mapController.camera.center;
    final newCenter = LatLng(center.latitude + dy, center.longitude + dx);
    _mapController.move(newCenter, _mapController.camera.zoom);
    if (mounted) {
      setState(() {});
    }
  }

  void _moveCamera({
    required LatLng center,
    required double zoom,
    required bool resetHistory,
  }) {
    _mapController.move(center, zoom);
    _commitCameraFromController(resetHistory: resetHistory);
  }

  void _navigateCameraHistory(int direction) {
    final nextIndex = _cameraHistoryIndex + direction;
    if (nextIndex < 0 || nextIndex >= _cameraHistory.length) {
      return;
    }

    final nextCamera = _cameraHistory[nextIndex];
    _mapController.move(nextCamera.center, nextCamera.zoom);
    setState(() {
      _cameraHistoryIndex = nextIndex;
      _debugState = PeakListMiniMapDebugState(
        center: nextCamera.center,
        zoom: nextCamera.zoom,
        canGoPrevious: nextIndex > 0,
        canGoNext: nextIndex < _cameraHistory.length - 1,
      );
    });
  }

  void _commitCameraFromController({
    required bool resetHistory,
    bool appendToHistory = true,
  }) {
    final cameraState = _cameraStateFromController();
    if (cameraState == null) {
      return;
    }
    if (resetHistory && !_cameraMatchesSelectedSummaryRow(cameraState)) {
      setState(() {
        _debugState = PeakListMiniMapDebugState(
          center: cameraState.center,
          zoom: cameraState.zoom,
          canGoPrevious: false,
          canGoNext: false,
        );
      });
      return;
    }

    final nextHistory = switch ((resetHistory, _cameraHistory.isEmpty)) {
      (true, _) || (_, true) => <_MiniPeakMapCameraState>[cameraState],
      _
          when _cameraStateEquals(
            _cameraHistory[_cameraHistoryIndex],
            cameraState,
          ) =>
        [
          for (var index = 0; index < _cameraHistory.length; index++)
            index == _cameraHistoryIndex ? cameraState : _cameraHistory[index],
        ],
      _ when !appendToHistory => [
        for (var index = 0; index < _cameraHistory.length; index++)
          index == _cameraHistoryIndex ? cameraState : _cameraHistory[index],
      ],
      _ => <_MiniPeakMapCameraState>[
        ..._cameraHistory.take(_cameraHistoryIndex + 1),
        cameraState,
      ],
    };
    final nextIndex = resetHistory || _cameraHistory.isEmpty
        ? 0
        : _cameraStateEquals(
                _cameraHistory[_cameraHistoryIndex],
                cameraState,
              ) ||
              !appendToHistory
        ? _cameraHistoryIndex
        : nextHistory.length - 1;

    setState(() {
      _historyResetPending = false;
      _cameraHistory = List<_MiniPeakMapCameraState>.unmodifiable(nextHistory);
      _cameraHistoryIndex = nextIndex;
      _debugState = PeakListMiniMapDebugState(
        center: cameraState.center,
        zoom: cameraState.zoom,
        canGoPrevious: nextIndex > 0,
        canGoNext: nextIndex < nextHistory.length - 1,
      );
    });
  }

  _MiniPeakMapCameraState? _cameraStateFromController() {
    try {
      final camera = _mapController.camera;
      return _MiniPeakMapCameraState(center: camera.center, zoom: camera.zoom);
    } catch (_) {
      return null;
    }
  }

  bool _cameraMatchesSelectedSummaryRow(_MiniPeakMapCameraState cameraState) {
    final peakListBounds = _peakListMiniMapBoundsOrNull(
      widget.selectedSummaryRow?.peakList,
    );
    if (peakListBounds != null) {
      return peakListBounds.contains(cameraState.center);
    }

    final peaks = widget.selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[];
    if (peaks.isEmpty) {
      return true;
    }

    return LatLngBounds.fromPoints([
      for (final peak in peaks) LatLng(peak.peak.latitude, peak.peak.longitude),
    ]).contains(cameraState.center);
  }

  Offset _screenOffsetForPeak(Peak peak) {
    return _mapController.camera.latLngToScreenOffset(
      LatLng(peak.latitude, peak.longitude),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markerPeaks =
        widget.selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[];
    ref.watch(peakMarkerInfoSettingsProvider);
    final showPeakListMiniMapClusters = ref.watch(
      peakListMiniMapClusterDisplaySettingsProvider,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            double effectiveZoom;
            try {
              effectiveZoom = _mapController.camera.zoom;
            } catch (_) {
              effectiveZoom = 0;
            }
            final viewportData = _buildPeakViewportData(
              markerPeaks,
              clusteringEnabled: showPeakListMiniMapClusters,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                KeyedSubtree(
                  key: const Key('peak-lists-mini-map'),
                  child: FlutterMap(
                    key: ValueKey(
                      widget.selectedSummaryRow?.peakList.peakListId,
                    ),
                    mapController: _mapController,
                    options: MapOptions(
                      initialCameraFit: _resolveInitialCameraFit(
                        widget.selectedSummaryRow,
                      ),
                      onMapReady: () {
                        if (mounted) {
                          _fitCameraToSelectedSummaryRow();
                        }
                      },
                      onPositionChanged: (camera, hasGesture) {
                        if (!mounted) {
                          return;
                        }
                        if (_historyResetPending) {
                          _commitCameraFromController(resetHistory: true);
                          return;
                        }
                        setState(() {});
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: mapTileUrl(Basemap.openstreetmap),
                        userAgentPackageName: 'com.peak_bagger.app',
                        tileProvider: buildPeakListMiniMapTileProvider(
                          cacheAvailable:
                              TileCacheService.getStoreForBasemap(
                                Basemap.openstreetmap,
                              ) !=
                              null,
                        ),
                      ),
                      if (markerPeaks.isNotEmpty)
                        MapScreenPeakLayer(
                          zoom: effectiveZoom,
                          showPeakInfo: false,
                          hoveredPeakId: _hoveredPeakId,
                          popupPeakId: _popupContent?.peak.osmId,
                          viewportData: viewportData,
                          clusterRingStyle:
                              PeakClusterRingStyle.proportionalTickedUnticked,
                        ),
                      if (markerPeaks.isNotEmpty)
                        _MiniPeakMapAffordanceLayer(viewportData: viewportData),
                      if (widget.selectedMapPeak != null)
                        CircleLayer(
                          key: const Key(
                            'peak-lists-selected-peak-circle-layer',
                          ),
                          circles: [
                            CircleMarker(
                              point: LatLng(
                                widget.selectedMapPeak!.peak.latitude,
                                widget.selectedMapPeak!.peak.longitude,
                              ),
                              radius: 15,
                              color: Colors.blue.withValues(alpha: 0.3),
                              borderColor: Colors.blue,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: MouseRegion(
                    key: const Key('peak-lists-mini-map-interaction-region'),
                    cursor: _hoveredPeakId != null || _hoveringCluster
                        ? (_isPointerDown
                              ? SystemMouseCursors.grabbing
                              : SystemMouseCursors.click)
                        : (_isPointerDown
                              ? SystemMouseCursors.grabbing
                              : SystemMouseCursors.grab),
                    onHover: (event) {
                      _handleHover(event.localPosition);
                    },
                    onExit: (_) {
                      _clearHover();
                    },
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (event) {
                        _handlePointerDown(event.localPosition);
                      },
                      onPointerMove: (event) {
                        _handlePointerMove(event.localPosition);
                      },
                      onPointerCancel: (event) {
                        _handlePointerCancel();
                      },
                      onPointerPanZoomStart: _handleTrackpadPanZoomStart,
                      onPointerPanZoomUpdate: _handleTrackpadPanZoomUpdate,
                      onPointerPanZoomEnd: _handleTrackpadPanZoomEnd,
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          _handlePointerSignal(event);
                        }
                      },
                      onPointerUp: (event) {
                        _handlePointerUp(event.localPosition);
                      },
                    ),
                  ),
                ),
                if (_popupContent != null)
                  Builder(
                    builder: (context) {
                      final effectivePopupSize = Size(
                        math.min(
                          UiConstants.peakInfoPopupSize.width,
                          math.max(1.0, viewportSize.width - 16),
                        ),
                        math.min(
                          UiConstants.peakInfoPopupSize.height,
                          math.max(1.0, viewportSize.height - 16),
                        ),
                      );
                      final placement = resolvePeakInfoPopupPlacement(
                        anchorScreenOffset: _screenOffsetForPeak(
                          _popupContent!.peak,
                        ),
                        viewportSize: viewportSize,
                        popupSize: effectivePopupSize,
                      );
                      if (!placement.isAnchorable) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _clearPopup();
                          }
                        });
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        left: placement.topLeft.dx,
                        top: placement.topLeft.dy,
                        child: SizedBox(
                          width: effectivePopupSize.width,
                          child: PeakInfoPopupCard(
                            key: const Key('peak-lists-mini-map-popup'),
                            content: _popupContent!,
                            onPeakTitleTap: () {
                              _openPeakOnMap(_popupContent!.peak);
                            },
                            onAscentTap: _openAscentTrackOnMap,
                            interactiveAscentTrackIds: {
                              for (final ascent in _popupContent!.ascentRows)
                                if (_isTrackOpenable(ascent.gpxId))
                                  ascent.gpxId,
                            },
                            onClose: _clearPopup,
                          ),
                        ),
                      );
                    },
                  ),
                PeakListMiniMapDebugProbe(
                  key: const Key('peak-lists-mini-map-debug-probe'),
                  state:
                      _debugState ??
                      const PeakListMiniMapDebugState(
                        center: LatLng(0, 0),
                        zoom: 0,
                        canGoPrevious: false,
                        canGoNext: false,
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PeakListMiniMapDebugProbe extends StatelessWidget {
  const PeakListMiniMapDebugProbe({required this.state, super.key});

  final PeakListMiniMapDebugState state;

  @override
  Widget build(BuildContext context) {
    return const Offstage(child: SizedBox.shrink());
  }
}

class PeakListMiniMapDebugState {
  const PeakListMiniMapDebugState({
    required this.center,
    required this.zoom,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  final LatLng center;
  final double zoom;
  final bool canGoPrevious;
  final bool canGoNext;
}

class _MiniPeakMapCameraState {
  const _MiniPeakMapCameraState({required this.center, required this.zoom});

  final LatLng center;
  final double zoom;
}

bool _cameraStateEquals(
  _MiniPeakMapCameraState left,
  _MiniPeakMapCameraState right,
) {
  return (left.center.latitude - right.center.latitude).abs() <=
          MapConstants.cameraEpsilon &&
      (left.center.longitude - right.center.longitude).abs() <=
          MapConstants.cameraEpsilon &&
      (left.zoom - right.zoom).abs() <= MapConstants.cameraEpsilon;
}

TileProvider buildPeakListMiniMapTileProvider({required bool cacheAvailable}) {
  const basemap = Basemap.openstreetmap;
  final headers = mapTileHeaders(basemap);
  if (!cacheAvailable) {
    return NetworkTileProvider(headers: headers);
  }

  return FMTCTileProvider(
    stores: {basemap.name: BrowseStoreStrategy.readUpdateCreate},
    loadingStrategy: BrowseLoadingStrategy.cacheFirst,
    recordHitsAndMisses: false,
    headers: headers,
    urlTransformer: (url) => TileCacheService.transformBrowseUrl(basemap, url),
  );
}

class _MiniPeakMapAffordanceLayer extends StatelessWidget {
  const _MiniPeakMapAffordanceLayer({required this.viewportData});

  final PeakClusterViewportData viewportData;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = camera.nonRotatedSize;
    if (size == MapCamera.kImpossibleSize) {
      return const SizedBox.shrink();
    }

    return MobileLayerTransformer(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          key: const Key('peak-lists-mini-map-peak-marker-layer'),
          clipBehavior: Clip.none,
          children: [
            for (final candidate in viewportData.individualCandidates)
              Positioned(
                left: candidate.screenPosition.dx - 16,
                top: candidate.screenPosition.dy - 16,
                width: 32,
                height: 32,
                child: SizedBox(
                  key: Key(
                    'peak-lists-mini-map-marker-${candidate.peak.osmId}-${candidate.isTicked ? 'ticked' : 'unticked'}',
                  ),
                ),
              ),
            for (var i = 0; i < viewportData.clusters.length; i++)
              Positioned(
                left:
                    viewportData.clusters[i].screenPosition.dx -
                    peakClusterVisualRadius(viewportData.clusters[i]),
                top:
                    viewportData.clusters[i].screenPosition.dy -
                    peakClusterVisualRadius(viewportData.clusters[i]),
                width: peakClusterVisualRadius(viewportData.clusters[i]) * 2,
                height: peakClusterVisualRadius(viewportData.clusters[i]) * 2,
                child: SizedBox(key: Key('peak-lists-mini-map-cluster-$i')),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeakListsDerivedRefreshKey {
  const _PeakListsDerivedRefreshKey({
    required this.peakRevision,
    required this.peakListRevision,
    required this.peaksBaggedRevision,
    required this.selectedRegionKeys,
  });

  final int peakRevision;
  final int peakListRevision;
  final int peaksBaggedRevision;
  final Set<String> selectedRegionKeys;

  bool matches(_PeakListsDerivedRefreshKey other) {
    return peakRevision == other.peakRevision &&
        peakListRevision == other.peakListRevision &&
        peaksBaggedRevision == other.peaksBaggedRevision &&
        _sameRegionKeySet(selectedRegionKeys, other.selectedRegionKeys);
  }
}

class _PeakListsDerivedBaseDataKey {
  const _PeakListsDerivedBaseDataKey({
    required this.peakListRepository,
    required this.peakRepository,
    required this.peaksBaggedRepository,
    required this.peakRevision,
    required this.peakListRevision,
    required this.peaksBaggedRevision,
  });

  final PeakListRepository peakListRepository;
  final PeakRepository peakRepository;
  final PeaksBaggedRepository peaksBaggedRepository;
  final int peakRevision;
  final int peakListRevision;
  final int peaksBaggedRevision;

  bool matches(_PeakListsDerivedBaseDataKey other) {
    return identical(peakListRepository, other.peakListRepository) &&
        identical(peakRepository, other.peakRepository) &&
        identical(peaksBaggedRepository, other.peaksBaggedRepository) &&
        peakRevision == other.peakRevision &&
        peakListRevision == other.peakListRevision &&
        peaksBaggedRevision == other.peaksBaggedRevision;
  }
}

class _PeakListsDerivedBaseData {
  const _PeakListsDerivedBaseData({
    required this.peaksById,
    required this.ascentCountsByPeakId,
    required this.latestAscentDatesByPeakId,
    required this.itemsByPeakListId,
    required this.peakRegionKeysByOsmId,
  });

  final Map<int, Peak> peaksById;
  final Map<int, int> ascentCountsByPeakId;
  final Map<int, DateTime?> latestAscentDatesByPeakId;
  final Map<int, List<PeakListItem>> itemsByPeakListId;
  final Map<int, String?> peakRegionKeysByOsmId;
}

_PeakListsDerivedBaseDataKey? _cachedPeakListsDerivedBaseDataKey;
_PeakListsDerivedBaseData? _cachedPeakListsDerivedBaseData;

class _PeakListsDerivedSnapshot {
  const _PeakListsDerivedSnapshot({
    required this.summaryRows,
    required this.itemsByPeakListId,
    required this.peaksById,
    required this.ascentCountsByPeakId,
    required this.latestAscentDatesByPeakId,
  });

  final List<_PeakListSummaryRow> summaryRows;
  final Map<int, List<PeakListItem>> itemsByPeakListId;
  final Map<int, Peak> peaksById;
  final Map<int, int> ascentCountsByPeakId;
  final Map<int, DateTime?> latestAscentDatesByPeakId;

  _PeakListSummaryRow? resolveRowDetails(_PeakListSummaryRow? row) {
    if (row == null || row.detailsResolved) {
      return row;
    }

    return row.resolveDetails(
      items: itemsByPeakListId[row.peakList.peakListId] ??
          const <PeakListItem>[],
      peaksById: peaksById,
      ascentCountsByPeakId: ascentCountsByPeakId,
      latestAscentDatesByPeakId: latestAscentDatesByPeakId,
    );
  }
}

_PeakListsDerivedBaseData _resolvePeakListsDerivedBaseData({
  required _PeakListsDerivedBaseDataKey baseDataKey,
  required List<PeakList> peakLists,
  required PeakListRepository peakListRepository,
  required Map<int, Peak> peaksByOsmId,
  required PeaksBaggedRepository peaksBaggedRepository,
}) {
  final cachedKey = _cachedPeakListsDerivedBaseDataKey;
  final cachedData = _cachedPeakListsDerivedBaseData;
  if (cachedKey != null &&
      cachedData != null &&
      cachedKey.matches(baseDataKey)) {
    return cachedData;
  }

  final peaksById = peaksByOsmId;
  final ascentCountsByPeakId = peaksBaggedRepository.ascentCountsByPeakId();
  final latestAscentDatesByPeakId = peaksBaggedRepository
      .latestAscentDatesByPeakId();
  final itemsByPeakListId = peakListRepository.getPeakListItemsByPeakListId();
  final mixedPeakListIds = {
    for (final peakList in peakLists)
      if (peakList.region == PeakList.mixedRegion) peakList.peakListId,
  };
  final peakRegionKeysByOsmId = <int, String?>{};
  for (final peakListId in mixedPeakListIds) {
    for (final item in itemsByPeakListId[peakListId] ?? const <PeakListItem>[]) {
      peakRegionKeysByOsmId.putIfAbsent(item.peakOsmId, () {
        final peak = peaksById[item.peakOsmId];
        return peak == null ? null : canonicalPeakRegionKey(peak);
      });
    }
  }

  final baseData = _PeakListsDerivedBaseData(
    peaksById: peaksById,
    ascentCountsByPeakId: ascentCountsByPeakId,
    latestAscentDatesByPeakId: latestAscentDatesByPeakId,
    itemsByPeakListId: itemsByPeakListId,
    peakRegionKeysByOsmId: peakRegionKeysByOsmId,
  );
  _cachedPeakListsDerivedBaseData = baseData;
  _cachedPeakListsDerivedBaseDataKey = baseDataKey;
  return baseData;
}

_PeakListsDerivedSnapshot _buildPeakListsDerivedSnapshot({
  required _PeakListsScreenState state,
  required int? preferredSelectedPeakListId,
  required Set<String> selectedRegionKeys,
  required List<PeakList> peakLists,
  required PeakListRepository peakListRepository,
  required PeakRepository peakRepository,
  required Map<int, Peak> peaksByOsmId,
  required PeaksBaggedRepository peaksBaggedRepository,
}) {
  final baseData = _resolvePeakListsDerivedBaseData(
    baseDataKey: _PeakListsDerivedBaseDataKey(
      peakListRepository: peakListRepository,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
      peakRevision: state.ref.read(peakRevisionProvider),
      peakListRevision: state.ref.read(peakListRevisionProvider),
      peaksBaggedRevision: state.ref.read(peaksBaggedRevisionProvider),
    ),
    peakLists: peakLists,
    peakListRepository: peakListRepository,
    peaksByOsmId: peaksByOsmId,
    peaksBaggedRepository: peaksBaggedRepository,
  );
  final filteredPeakLists = <PeakList>[];
  for (final peakList in peakLists) {
    final applies = peakListAppliesToVisibleRegions(
      peakList,
      selectedRegionKeys,
      peaks: baseData.peaksById.values,
      peakRegionKeysByOsmId: baseData.peakRegionKeysByOsmId,
      itemsLoader: (peakList) =>
          baseData.itemsByPeakListId[peakList.peakListId] ??
          const <PeakListItem>[],
    );
    if (applies) {
      filteredPeakLists.add(peakList);
    }
  }
  final detailedPeakListId = filteredPeakLists.any(
    (peakList) => peakList.peakListId == preferredSelectedPeakListId,
  )
      ? preferredSelectedPeakListId
      : (filteredPeakLists.isEmpty ? null : filteredPeakLists.first.peakListId);

  return _PeakListsDerivedSnapshot(
    summaryRows: filteredPeakLists
        .map(
          (peakList) => _PeakListSummaryRow.fromPeakList(
            peakList,
            items: baseData.itemsByPeakListId[peakList.peakListId] ??
                const <PeakListItem>[],
            peaksById: baseData.peaksById,
            ascentCountsByPeakId: baseData.ascentCountsByPeakId,
            latestAscentDatesByPeakId: baseData.latestAscentDatesByPeakId,
            includeDetailData: peakList.peakListId == detailedPeakListId,
          ),
        )
        .toList(growable: false),
    itemsByPeakListId: baseData.itemsByPeakListId,
    peaksById: baseData.peaksById,
    ascentCountsByPeakId: baseData.ascentCountsByPeakId,
    latestAscentDatesByPeakId: baseData.latestAscentDatesByPeakId,
  );
}

bool _sameRegionKeySet(Set<String> left, Set<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final regionKey in left) {
    if (!right.contains(regionKey)) {
      return false;
    }
  }
  return true;
}

CameraFit _resolveInitialCameraFit(_PeakListSummaryRow? summaryRow) {
  final peakListBounds = _peakListMiniMapBoundsOrNull(summaryRow?.peakList);
  if (peakListBounds != null) {
    if (_boundsCollapseToSinglePoint(peakListBounds)) {
      return CameraFit.coordinates(
        coordinates: [peakListBounds.southWest],
        padding: const EdgeInsets.all(24),
        maxZoom: 11,
      );
    }
    return CameraFit.bounds(
      bounds: peakListBounds,
      padding: const EdgeInsets.all(24),
    );
  }

  final markerPeaks = summaryRow?.mapPeaks ?? const <_MapPeak>[];
  if (markerPeaks.isEmpty) {
    return CameraFit.bounds(
      bounds: GeoAreas.tasmaniaBounds,
      padding: const EdgeInsets.all(24),
    );
  }

  final coordinates = markerPeaks
      .map((peak) => LatLng(peak.peak.latitude, peak.peak.longitude))
      .toList(growable: false);

  if (coordinates.length == 1) {
    return CameraFit.coordinates(
      coordinates: coordinates,
      padding: const EdgeInsets.all(24),
      maxZoom: 11,
    );
  }

  return CameraFit.bounds(
    bounds: LatLngBounds.fromPoints(coordinates),
    padding: const EdgeInsets.all(24),
  );
}

LatLngBounds? _peakListMiniMapBoundsOrNull(PeakList? peakList) {
  if (peakList == null) {
    return null;
  }

  final minLat = peakList.minLat;
  final maxLat = peakList.maxLat;
  final minLng = peakList.minLng;
  final maxLng = peakList.maxLng;
  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return null;
  }
  if (!minLat.isFinite ||
      !maxLat.isFinite ||
      !minLng.isFinite ||
      !maxLng.isFinite ||
      minLat > maxLat ||
      minLng > maxLng) {
    return null;
  }

  return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

bool _boundsCollapseToSinglePoint(LatLngBounds bounds) {
  return (bounds.northEast.latitude - bounds.southWest.latitude).abs() <=
          MapConstants.cameraEpsilon &&
      (bounds.northEast.longitude - bounds.southWest.longitude).abs() <=
          MapConstants.cameraEpsilon;
}

class _PeakListSummaryRow {
  const _PeakListSummaryRow._({
    required this.peakList,
    required this.totalPeaks,
    required this.climbed,
    required this.unclimbed,
    required this.ascentCount,
    required this.totalPoints,
    required this.earnedPoints,
    required this.percentageValue,
    required this.peakRows,
    required this.mapPeaks,
    required this.latestAscentDate,
    required this.latestAscentPeaks,
    required this.detailsResolved,
  });

  factory _PeakListSummaryRow.fromPeakList(
    PeakList peakList, {
    required List<PeakListItem> items,
    required Map<int, Peak> peaksById,
    required Map<int, int> ascentCountsByPeakId,
    required Map<int, DateTime?> latestAscentDatesByPeakId,
    bool includeDetailData = true,
  }) {
    final uniqueItems = <PeakListItem>[];
    final seenPeakIds = <int>{};
    for (final item in items) {
      if (seenPeakIds.add(item.peakOsmId)) {
        uniqueItems.add(item);
      }
    }

    final ascentCount = uniqueItems.fold<int>(
      0,
      (sum, item) => sum + (ascentCountsByPeakId[item.peakOsmId] ?? 0),
    );

    final details = includeDetailData
        ? _buildPeakListResolvedDetails(
            uniqueItems: uniqueItems,
            peaksById: peaksById,
            ascentCountsByPeakId: ascentCountsByPeakId,
            latestAscentDatesByPeakId: latestAscentDatesByPeakId,
          )
        : null;

    final totalPeaks = uniqueItems.length;
    final climbed = uniqueItems
        .where((item) => latestAscentDatesByPeakId.containsKey(item.peakOsmId))
        .length;
    final unclimbed = totalPeaks - climbed;
    final totalPoints = uniqueItems.fold<int>(
      0,
      (sum, item) => sum + item.points,
    );
    final earnedPoints = uniqueItems
        .where((item) => latestAscentDatesByPeakId.containsKey(item.peakOsmId))
        .fold<int>(0, (sum, item) => sum + item.points);
    final percentageValue = totalPeaks == 0
        ? 0.0
        : climbed / totalPeaks.toDouble();

    return _PeakListSummaryRow._(
      peakList: peakList,
      totalPeaks: totalPeaks,
      climbed: climbed,
      unclimbed: unclimbed,
      ascentCount: ascentCount,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      percentageValue: percentageValue,
      peakRows: details?.peakRows ?? const <_PeakDetailRow>[],
      mapPeaks: details?.mapPeaks ?? const <_MapPeak>[],
      latestAscentDate: details?.latestAscentDate,
      latestAscentPeaks:
          details?.latestAscentPeaks ?? const <_LatestAscentPeak>[],
      detailsResolved: includeDetailData,
    );
  }

  _PeakListSummaryRow resolveDetails({
    required List<PeakListItem> items,
    required Map<int, Peak> peaksById,
    required Map<int, int> ascentCountsByPeakId,
    required Map<int, DateTime?> latestAscentDatesByPeakId,
  }) {
    if (detailsResolved) {
      return this;
    }

    final uniqueItems = <PeakListItem>[];
    final seenPeakIds = <int>{};
    for (final item in items) {
      if (seenPeakIds.add(item.peakOsmId)) {
        uniqueItems.add(item);
      }
    }
    final details = _buildPeakListResolvedDetails(
      uniqueItems: uniqueItems,
      peaksById: peaksById,
      ascentCountsByPeakId: ascentCountsByPeakId,
      latestAscentDatesByPeakId: latestAscentDatesByPeakId,
    );

    return _PeakListSummaryRow._(
      peakList: peakList,
      totalPeaks: totalPeaks,
      climbed: climbed,
      unclimbed: unclimbed,
      ascentCount: ascentCount,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
      percentageValue: percentageValue,
      peakRows: details.peakRows,
      mapPeaks: details.mapPeaks,
      latestAscentDate: details.latestAscentDate,
      latestAscentPeaks: details.latestAscentPeaks,
      detailsResolved: true,
    );
  }

  final PeakList peakList;
  final int? totalPeaks;
  final int? climbed;
  final int? unclimbed;
  final int ascentCount;
  final int? totalPoints;
  final int? earnedPoints;
  final double percentageValue;
  final List<_PeakDetailRow> peakRows;
  final List<_MapPeak> mapPeaks;
  final DateTime? latestAscentDate;
  final List<_LatestAscentPeak> latestAscentPeaks;
  final bool detailsResolved;

  String get totalPeaksLabel => _formattedCountOrDash(totalPeaks);
  String get climbedLabel => _formattedCountOrDash(climbed);
  String get unclimbedLabel => _formattedCountOrDash(unclimbed);
  String get ascentCountLabel =>
      ascentCount == 0 ? '' : formatCount(ascentCount);
  String get percentageLabel =>
      formatPercentage(percentageValue * 100, decimalPlaces: 0);

  String? buildSummarySentence() {
    if (totalPeaks == null ||
        climbed == null ||
        earnedPoints == null ||
        totalPoints == null) {
      return null;
    }

    final infoSentence =
        '${peakList.name} contains ${formatCount(totalPeaks!)} peaks.';

    final metricsSentence =
        'Climbed ${formatCount(climbed!)} of ${formatCount(totalPeaks!)} peaks (${formatPercentage(percentageValue * 100, decimalPlaces: 0)}) and earned a total ${formatCount(earnedPoints!)} points out of ${formatCount(totalPoints!)}.';
    if (latestAscentDate == null || latestAscentPeaks.isEmpty) {
      return '$infoSentence\n\n$metricsSentence';
    }

    final joinedPeakNames = _joinPeakNames([
      for (final peak in latestAscentPeaks) peak.name,
    ]);
    final verb = latestAscentPeaks.length == 1 ? 'is' : 'are';
    return '$infoSentence\n\n$joinedPeakNames $verb your most recent ascent, climbed on ${_formatDate(latestAscentDate!)}.\n$metricsSentence';
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _formattedCountOrDash(int? value) {
    return value == null ? '-' : formatCount(value);
  }
}

_PeakListResolvedDetails _buildPeakListResolvedDetails({
  required List<PeakListItem> uniqueItems,
  required Map<int, Peak> peaksById,
  required Map<int, int> ascentCountsByPeakId,
  required Map<int, DateTime?> latestAscentDatesByPeakId,
}) {
  final peakRows = uniqueItems
      .map((item) {
        final peak = peaksById[item.peakOsmId];
        return _PeakDetailRow(
          peakId: item.peakOsmId,
          peak: peak,
          name: peak?.name ?? 'Unknown',
          elevation: peak?.elevation,
          rating: peak?.rating,
          ascentDate: latestAscentDatesByPeakId[item.peakOsmId],
          ascentCount: ascentCountsByPeakId[item.peakOsmId] ?? 0,
          difficulty: peak?.difficulty ?? '',
          durationMinutes: peak?.durationMinutes,
          durationLabel: peak?.durationLabel ?? '',
          points: item.points,
        );
      })
      .toList(growable: false);
  final mapPeaks = uniqueItems
      .map((item) {
        final peak = peaksById[item.peakOsmId];
        if (peak == null) {
          return null;
        }
        return _MapPeak(
          peak: peak,
          isClimbed: latestAscentDatesByPeakId.containsKey(item.peakOsmId),
        );
      })
      .whereType<_MapPeak>()
      .toList(growable: false);

  DateTime? latestAscentDate;
  for (final row in peakRows) {
    if (row.ascentDate == null) {
      continue;
    }
    final ascentDay = _PeakListSummaryRow._dateOnly(row.ascentDate!);
    if (latestAscentDate == null || ascentDay.isAfter(latestAscentDate)) {
      latestAscentDate = ascentDay;
    }
  }

  final latestAscentPeakRows = latestAscentDate == null
      ? <_PeakDetailRow>[]
      : (peakRows
            .where(
              (row) =>
                  row.ascentDate != null &&
                  _PeakListSummaryRow._dateOnly(row.ascentDate!) ==
                      latestAscentDate,
            )
            .toList(growable: false)
          ..sort((left, right) => left.peakId.compareTo(right.peakId)));

  return _PeakListResolvedDetails(
    peakRows: peakRows,
    mapPeaks: mapPeaks,
    latestAscentDate: latestAscentDate,
    latestAscentPeaks: [
      for (final row in latestAscentPeakRows)
        _LatestAscentPeak(peakId: row.peakId, name: row.name),
    ],
  );
}

class _PeakListResolvedDetails {
  const _PeakListResolvedDetails({
    required this.peakRows,
    required this.mapPeaks,
    required this.latestAscentDate,
    required this.latestAscentPeaks,
  });

  final List<_PeakDetailRow> peakRows;
  final List<_MapPeak> mapPeaks;
  final DateTime? latestAscentDate;
  final List<_LatestAscentPeak> latestAscentPeaks;
}

class _PeakDetailRow {
  const _PeakDetailRow({
    required this.peakId,
    required this.peak,
    required this.name,
    required this.elevation,
    required this.rating,
    required this.ascentDate,
    required this.ascentCount,
    required this.difficulty,
    required this.durationMinutes,
    required this.durationLabel,
    required this.points,
  });

  final int peakId;
  final Peak? peak;
  final String name;
  final double? elevation;
  final double? rating;
  final DateTime? ascentDate;
  final int ascentCount;
  final String difficulty;
  final int? durationMinutes;
  final String durationLabel;
  final int points;

  bool get hasRating => rating != null;

  bool get hasDifficulty => peak != null && difficultyLabel.isNotEmpty;

  String get difficultyLabel => difficulty.trim();

  String get durationDisplayLabel {
    final peakValue = peak;
    if (peakValue != null) {
      return peakDurationDisplayLabel(peakValue);
    }

    final trimmedLabel = durationLabel.trim();
    if (trimmedLabel.isNotEmpty) {
      return trimmedLabel;
    }
    return formatPeakDurationMinutes(durationMinutes);
  }

  String get elevationLabel {
    if (elevation == null) {
      return '';
    }
    return formatElevation(elevation!.round());
  }

  String get ascentDateLabel {
    if (ascentDate == null) {
      return '';
    }
    return _formatDate(ascentDate!);
  }

  String get ascentCountLabel => ascentCount == 0 ? '' : ascentCount.toString();
}

class _LatestAscentPeak {
  const _LatestAscentPeak({required this.peakId, required this.name});

  final int peakId;
  final String name;
}

class _MapPeak {
  const _MapPeak({required this.peak, required this.isClimbed});

  final Peak peak;
  final bool isClimbed;
}

class _PeakListSummarySentence extends StatelessWidget {
  const _PeakListSummarySentence({
    required this.summaryRow,
    required this.onPeakSelected,
  });

  final _PeakListSummaryRow summaryRow;
  final ValueChanged<int> onPeakSelected;

  @override
  Widget build(BuildContext context) {
    final summaryText = summaryRow.buildSummarySentence();
    final latestAscentDate = summaryRow.latestAscentDate;
    if (summaryText == null) {
      return const SizedBox.shrink();
    }
    if (latestAscentDate == null ||
        summaryRow.latestAscentPeaks.isEmpty ||
        summaryRow.totalPeaks == null ||
        summaryRow.climbed == null ||
        summaryRow.totalPoints == null ||
        summaryRow.earnedPoints == null) {
      return Text(
        summaryText,
        key: const Key('peak-lists-summary-sentence'),
        softWrap: true,
      );
    }

    final defaultStyle = DefaultTextStyle.of(context).style;
    final theme = Theme.of(context);
    final linkStyle = defaultStyle.copyWith(color: theme.seedColour);
    final infoSentence =
        '${summaryRow.peakList.name} contains ${formatCount(summaryRow.totalPeaks!)} peaks.';
    final metricsSentence =
        'Climbed ${formatCount(summaryRow.climbed!)} of ${formatCount(summaryRow.totalPeaks!)} peaks (${formatPercentage(summaryRow.percentageValue * 100, decimalPlaces: 0)}) and earned a total ${formatCount(summaryRow.earnedPoints!)} points out of ${formatCount(summaryRow.totalPoints!)}.';
    final verb = summaryRow.latestAscentPeaks.length == 1 ? 'is' : 'are';

    return Text.rich(
      TextSpan(
        style: defaultStyle,
        children: [
          TextSpan(text: '$infoSentence\n\n'),
          ..._buildLatestAscentSpans(
            peaks: summaryRow.latestAscentPeaks,
            linkStyle: linkStyle,
          ),
          TextSpan(
            text:
                ' $verb your most recent ascent, climbed on ${_formatDate(latestAscentDate)}.\n$metricsSentence',
          ),
        ],
      ),
      key: const Key('peak-lists-summary-sentence'),
      softWrap: true,
    );
  }

  List<InlineSpan> _buildLatestAscentSpans({
    required List<_LatestAscentPeak> peaks,
    required TextStyle linkStyle,
  }) {
    final spans = <InlineSpan>[];
    for (var index = 0; index < peaks.length; index++) {
      if (index > 0) {
        spans.add(TextSpan(text: index == peaks.length - 1 ? ' and ' : ', '));
      }
      final peak = peaks[index];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _PeakListSummaryLink(
            peakId: peak.peakId,
            name: peak.name,
            style: linkStyle,
            onTap: onPeakSelected,
          ),
        ),
      );
    }
    return spans;
  }
}

class _PeakListSummaryLink extends StatelessWidget {
  const _PeakListSummaryLink({
    required this.peakId,
    required this.name,
    required this.style,
    required this.onTap,
  });

  final int peakId;
  final String name;
  final TextStyle style;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: Key('peak-lists-summary-link-$peakId'),
      mouseCursor: SystemMouseCursors.click,
      hoverColor: lighten(theme.colorScheme.surfaceContainer, 0.08),
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        onTap(peakId);
      },
      child: Text(name, style: style),
    );
  }
}

String _joinPeakNames(List<String> names) {
  if (names.isEmpty) {
    return '';
  }
  if (names.length == 1) {
    return names.first;
  }
  if (names.length == 2) {
    return '${names[0]} and ${names[1]}';
  }
  return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

String _formatDate(DateTime date) {
  const monthNames = <String>[
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
  final local = date.toLocal();
  return '${local.day} ${monthNames[local.month - 1]} ${local.year}';
}
