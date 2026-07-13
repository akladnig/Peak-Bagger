import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import '../services/peak_list_repository.dart';
import '../services/peak_projection_cache.dart';
import '../services/gpx_track_repository.dart';
import '../services/peaks_bagged_repository.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/left_tooltip_fab.dart';
import '../widgets/peak_list_create_dialog.dart';
import '../widgets/peak_list_import_dialog.dart';
import '../widgets/peak_list_peak_dialog.dart';
import '../theme.dart';
import '../router.dart';
import 'map_screen_layers.dart';
import 'map_screen_peak_layer.dart';

class PeakListsScreen extends ConsumerStatefulWidget {
  const PeakListsScreen({super.key, this.initialPeakListId});

  final int? initialPeakListId;

  @override
  ConsumerState<PeakListsScreen> createState() => _PeakListsScreenState();
}

class _PeakListsScreenState extends ConsumerState<PeakListsScreen> {
  final _miniPeakMapKey = GlobalKey<_MiniPeakMapState>();
  int? _selectedPeakListId;
  int? _selectedPeakId;
  _PeakListSortColumn _sortColumn = _PeakListSortColumn.percentage;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _selectedPeakListId = widget.initialPeakListId;
  }

  @override
  void didUpdateWidget(covariant PeakListsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPeakListId == widget.initialPeakListId) {
      return;
    }

    _selectedPeakListId = widget.initialPeakListId;
    _selectedPeakId = null;
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
    ref.watch(peaksBaggedRevisionProvider);
    ref.watch(peakRevisionProvider);
    final peakListRepository = ref.watch(peakListRepositoryProvider);
    final peakRepository = ref.watch(peakRepositoryProvider);
    final peaksBaggedRepository = ref.watch(peaksBaggedRepositoryProvider);
    final peaksById = <int, Peak>{
      for (final peak in peakRepository.getAllPeaks()) peak.osmId: peak,
    };
    final ascentCountsByPeakId = peaksBaggedRepository.ascentCountsByPeakId();
    final latestAscentDatesByPeakId = peaksBaggedRepository
        .latestAscentDatesByPeakId();
    final peakLists = ref.watch(peakListsProvider);
    final summaryRows = peakLists
        .map(
          (peakList) => _PeakListSummaryRow.fromPeakList(
            peakList,
            peaksById: peaksById,
            ascentCountsByPeakId: ascentCountsByPeakId,
            latestAscentDatesByPeakId: latestAscentDatesByPeakId,
          ),
        )
        .toList(growable: false);
    final sortedSummaryRows = _sortSummaryRows(summaryRows);
    final selectedSummaryRow = _resolveSelectedSummaryRow(sortedSummaryRows);
    final selectedMapPeak = _resolveSelectedMapPeak(selectedSummaryRow);

    return Scaffold(
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
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  miniPeakMapKey: _miniPeakMapKey,
                  onSelected: (peakListId) {
                    setState(() {
                      _selectedPeakListId = peakListId;
                    });
                  },
                  onSortSelected: _handleSortSelected,
                  onDeleteRequested: (peakListId) {
                    _deletePeakList(peakListId, sortedSummaryRows);
                  },
                  filePicker: filePicker,
                  importRunner: importRunner,
                  duplicateNameChecker: duplicateNameChecker,
                  onCreateRequested: _handleCreatePeakList,
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
                  selectedSummaryRow: selectedSummaryRow,
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
                      selectedSummaryRow,
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
                    final result = await _openAddPeakDialog(selectedSummaryRow);
                    if (!mounted || result == null) {
                      return;
                    }
                    final selectedPeakIds = result.selectedPeakIds;
                    if (selectedPeakIds.isEmpty) {
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
    _refreshPeakListSelectionDependencies();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedPeakListId = nextSelectedPeakListId;
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

  Future<void> _handleCreatePeakList() async {
    final createdPeakListId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PeakListCreateDialog(
          duplicateNameChecker: ref.read(peakListDuplicateNameCheckerProvider),
          onCreate: ({required String listName}) async {
            final saved = await ref
                .read(peakListMutationRepositoryProvider)
                .save(
                  PeakList(
                    name: listName,
                    peakList: encodePeakListItems(const <PeakListItem>[]),
                  ),
                );
            _refreshPeakListSelectionDependencies();
            return saved.peakListId;
          },
        );
      },
    );

    if (!mounted || createdPeakListId == null) {
      return;
    }

    final createdSummaryRow = _buildSummaryRowForPeakList(createdPeakListId);
    if (createdSummaryRow == null) {
      return;
    }

    setState(() {
      _selectedPeakListId = createdPeakListId;
      _selectedPeakId = null;
    });

    final result = await _openAddPeakDialog(createdSummaryRow);
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _selectedPeakId = result.selectedPeakId;
    });
  }

  _PeakListSummaryRow? _buildSummaryRowForPeakList(int peakListId) {
    final peakList = ref.read(peakListRepositoryProvider).findById(peakListId);
    if (peakList == null) {
      return null;
    }

    final peakRepository = ref.read(peakRepositoryProvider);
    final peaksBaggedRepository = ref.read(peaksBaggedRepositoryProvider);
    return _PeakListSummaryRow.fromPeakList(
      peakList,
      peaksById: {
        for (final peak in peakRepository.getAllPeaks()) peak.osmId: peak,
      },
      ascentCountsByPeakId: peaksBaggedRepository.ascentCountsByPeakId(),
      latestAscentDatesByPeakId: peaksBaggedRepository
          .latestAscentDatesByPeakId(),
    );
  }

  void _refreshPeakListSelectionDependencies() {
    ref.read(peakListRevisionProvider.notifier).increment();
    ref.read(mapProvider.notifier).reconcileSelectedPeakList();
  }

  List<_PeakListSummaryRow> _sortSummaryRows(List<_PeakListSummaryRow> rows) {
    final sorted = List<_PeakListSummaryRow>.from(rows);
    sorted.sort((left, right) {
      final unsupportedComparison = _sortColumn == _PeakListSortColumn.name
          ? 0
          : _compareSupportedFirst(left, right);
      if (unsupportedComparison != 0) {
        return unsupportedComparison;
      }

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

  int _compareSupportedFirst(
    _PeakListSummaryRow left,
    _PeakListSummaryRow right,
  ) {
    if (left.isSupported == right.isSupported) {
      return 0;
    }
    return left.isSupported ? -1 : 1;
  }
}

enum _PeakListSortColumn {
  name,
  totalPeaks,
  climbed,
  percentage,
  unclimbed,
  ascents,
}

enum _PeakDetailSortColumn { name, elevation, ascentDate, ascents }

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
  double peakName,
  double elevation,
  double ascentDate,
  double ascents,
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

  for (final row in rows) {
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
  }

  peakName = math.min(peakName, 180.0);
  ascentDate = math.min(ascentDate, 88.0);

  return (
    peakName: peakName,
    elevation: elevation,
    ascentDate: ascentDate,
    ascents: ascents,
    totalWidth: peakName + elevation + ascentDate + ascents + (columnGap * 3),
  );
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.rows,
    required this.selectedPeakListId,
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
    required this.onCreateRequested,
    required this.peakListRepository,
    required this.onPeakSelected,
  });

  final List<_PeakListSummaryRow> rows;
  final int? selectedPeakListId;
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
  final VoidCallback onCreateRequested;
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
              onCreateRequested: onCreateRequested,
              peakListRepository: peakListRepository,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 7,
            child: _MiniPeakMapContainer(
              selectedSummaryRow: rows.isEmpty
                  ? null
                  : rows.firstWhere(
                      (row) =>
                          row.peakList.peakListId ==
                          (selectedPeakListId ??
                              rows.first.peakList.peakListId),
                      orElse: () => rows.first,
                    ),
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

class _SummaryListCard extends StatelessWidget {
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
    required this.onCreateRequested,
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
  final VoidCallback onCreateRequested;
  final PeakListRepository peakListRepository;

  @override
  Widget build(BuildContext context) {
    final widths = _resolveSummaryTableWidths(context, rows);
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
                                  sortColumn: sortColumn,
                                  sortAscending: sortAscending,
                                  onSortSelected: onSortSelected,
                                  widths: widths,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: rows.isEmpty
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
                                              for (final row in rows)
                                                _SummaryRowCard(
                                                  row: row,
                                                  selectedPeakListId:
                                                      selectedPeakListId,
                                                  widths: widths,
                                                  onSelected: onSelected,
                                                  onDeleteRequested:
                                                      onDeleteRequested,
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
                        child: Transform.translate(
                          offset: const Offset(20, -6),
                          child: _SummaryHeaderActions(
                            filePicker: filePicker,
                            importRunner: importRunner,
                            duplicateNameChecker: duplicateNameChecker,
                            onCreateRequested: onCreateRequested,
                            peakListRepository: peakListRepository,
                          ),
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
    required this.onCreateRequested,
    required this.peakListRepository,
  });

  final PeakListFilePicker filePicker;
  final PeakListImportBackgroundRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final VoidCallback onCreateRequested;
  final PeakListRepository peakListRepository;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fabBackground = _fabBackgroundColor(context);
    final fabForeground = _fabForegroundColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LeftTooltipFab(
          message: 'Add New Peak List',
          child: FloatingActionButton.small(
            key: const Key('peak-lists-add-list-fab'),
            heroTag: 'peak-list-create',
            backgroundColor: fabBackground,
            onPressed: onCreateRequested,
            child: Icon(Icons.add_circle_outline, color: fabForeground),
          ),
        ),
        const SizedBox(width: 12),
        LeftTooltipFab(
          message: 'Import Peak List',
          child: FloatingActionButton.small(
            key: const Key('peak-lists-import-fab'),
            heroTag: 'peak-list-import',
            backgroundColor: fabBackground,
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

class _SummaryRowCard extends StatefulWidget {
  const _SummaryRowCard({
    required this.row,
    required this.selectedPeakListId,
    required this.widths,
    required this.onSelected,
    required this.onDeleteRequested,
  });

  final _PeakListSummaryRow row;
  final int? selectedPeakListId;
  final _SummaryTableWidths widths;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onDeleteRequested;

  @override
  State<_SummaryRowCard> createState() => _SummaryRowCardState();
}

class _SummaryRowCardState extends State<_SummaryRowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final peakListId = widget.row.peakList.peakListId;
    final isSelected = peakListId == widget.selectedPeakListId;
    final isHovered = _isHovered && !isSelected;
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
          onTap: () => widget.onSelected(peakListId),
          onHover: (value) {
            if (_isHovered == value) {
              return;
            }
            setState(() => _isHovered = value);
          },
          mouseCursor: SystemMouseCursors.click,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: widget.widths.list,
                  child: Text(
                    widget.row.peakList.name,
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
                  width: widget.widths.totalPeaks,
                  child: Text(
                    widget.row.totalPeaksLabel,
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
                  width: widget.widths.climbed,
                  child: Text(
                    widget.row.climbedLabel,
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
                  width: widget.widths.percentage,
                  child: Text(
                    widget.row.percentageLabel,
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
                  width: widget.widths.unclimbed,
                  child: Text(
                    widget.row.unclimbedLabel,
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
                  width: widget.widths.ascents,
                  child: Text(
                    widget.row.ascentCountLabel,
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
                  width: widget.widths.actions,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: 'Delete ${widget.row.peakList.name}',
                      child: InkResponse(
                        key: Key('peak-lists-delete-$peakListId'),
                        onTap: () => widget.onDeleteRequested(peakListId),
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
      _rowKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.selectedSummaryRow?.peakRows ?? const <_PeakDetailRow>[];
    final unsupportedMessage = widget.selectedSummaryRow?.unsupportedMessage;
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
                    if (unsupportedMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          unsupportedMessage,
                          key: const Key('peak-lists-unsupported-message'),
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

    final sorted = List<_PeakDetailRow>.from(rows);
    sorted.sort((left, right) {
      final direction = _sortAscending ? 1 : -1;
      final comparison = switch (_sortColumn!) {
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

class _PeakDetailsTableRow extends StatefulWidget {
  const _PeakDetailsTableRow({
    super.key,
    required this.row,
    required this.widths,
    required this.selectedPeakId,
    required this.onPeakSelected,
  });

  final _PeakDetailRow row;
  final _PeakTableWidths widths;
  final int? selectedPeakId;
  final Future<void> Function(int) onPeakSelected;

  @override
  State<_PeakDetailsTableRow> createState() => _PeakDetailsTableRowState();
}

class _PeakDetailsTableRowState extends State<_PeakDetailsTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final isSelected = widget.row.peakId == widget.selectedPeakId;
    final isHovered = _isHovered && !isSelected;
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
          await widget.onPeakSelected(widget.row.peakId);
        },
        onHover: (value) {
          if (_isHovered == value) {
            return;
          }
          setState(() => _isHovered = value);
        },
        mouseCursor: SystemMouseCursors.click,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: widget.widths.peakName,
                child: Text(
                  widget.row.name,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widget.widths.elevation,
                child: Text(
                  widget.row.elevationLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widget.widths.ascentDate,
                child: Text(
                  widget.row.ascentDateLabel,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  textAlign: TextAlign.right,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: widget.widths.ascents,
                child: Text(
                  widget.row.ascentCountLabel,
                  key: Key('peak-lists-details-ascents-${widget.row.peakId}'),
                  maxLines: 1,
                  softWrap: false,
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
  static const _tapThreshold = 24.0;

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
    final peak = hitTestPeakFromViewportData(
      pointerPosition: localPosition,
      data: viewportData,
    );

    if (peak?.osmId == _hoveredPeakId) {
      return;
    }

    setState(() {
      _hoveredPeakId = peak?.osmId;
    });
  }

  void _clearHover() {
    if (_hoveredPeakId == null) {
      return;
    }
    setState(() {
      _hoveredPeakId = null;
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
      _mapController.move(
        points.first,
        (camera.zoom + 2).clamp(
          MapConstants.peakMinZoom.toDouble(),
          MapConstants.peakMaxZoom.toDouble(),
        ),
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(MapConstants.peakClusterExpandPadding),
      ),
    );
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
                      initialCameraFit: _resolveInitialCameraFit(markerPeaks),
                      onMapReady: () {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      onPositionChanged: (camera, hasGesture) {
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: mapTileUrl(Basemap.openstreetmap),
                        userAgentPackageName: 'com.peak_bagger.app',
                        tileProvider: NetworkTileProvider(),
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
                    cursor: _hoveredPeakId != null
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    onHover: (event) {
                      _handleHover(event.localPosition);
                    },
                    onExit: (_) {
                      _clearHover();
                    },
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerUp: (event) {
                        _handleMapTap(event.localPosition);
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
              ],
            );
          },
        ),
      ),
    );
  }
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

CameraFit _resolveInitialCameraFit(List<_MapPeak> markerPeaks) {
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

class _PeakListSummaryRow {
  const _PeakListSummaryRow._({
    required this.peakList,
    required this.isSupported,
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
    this.unsupportedMessage,
  });

  factory _PeakListSummaryRow.fromPeakList(
    PeakList peakList, {
    required Map<int, Peak> peaksById,
    required Map<int, int> ascentCountsByPeakId,
    required Map<int, DateTime?> latestAscentDatesByPeakId,
  }) {
    try {
      final items = decodePeakListItems(peakList.peakList);
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

      final peakRows = uniqueItems
          .map((item) {
            final peak = peaksById[item.peakOsmId];
            return _PeakDetailRow(
              peakId: item.peakOsmId,
              name: peak?.name ?? 'Unknown',
              elevation: peak?.elevation,
              ascentDate: latestAscentDatesByPeakId[item.peakOsmId],
              ascentCount: ascentCountsByPeakId[item.peakOsmId] ?? 0,
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
      final climbed = uniqueItems
          .where(
            (item) => latestAscentDatesByPeakId.containsKey(item.peakOsmId),
          )
          .length;
      final totalPeaks = uniqueItems.length;
      final unclimbed = totalPeaks - climbed;
      final totalPoints = uniqueItems.fold<int>(
        0,
        (sum, item) => sum + item.points,
      );
      final earnedPoints = uniqueItems
          .where(
            (item) => latestAscentDatesByPeakId.containsKey(item.peakOsmId),
          )
          .fold<int>(0, (sum, item) => sum + item.points);
      final percentageValue = totalPeaks == 0
          ? 0.0
          : climbed / totalPeaks.toDouble();

      DateTime? latestAscentDate;
      for (final row in peakRows) {
        if (row.ascentDate == null) {
          continue;
        }
        final ascentDay = _dateOnly(row.ascentDate!);
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
                      _dateOnly(row.ascentDate!) == latestAscentDate,
                )
                .toList(growable: false)
              ..sort((left, right) => left.peakId.compareTo(right.peakId)));

      return _PeakListSummaryRow._(
        peakList: peakList,
        isSupported: true,
        totalPeaks: totalPeaks,
        climbed: climbed,
        unclimbed: unclimbed,
        ascentCount: ascentCount,
        totalPoints: totalPoints,
        earnedPoints: earnedPoints,
        percentageValue: percentageValue,
        peakRows: peakRows,
        mapPeaks: mapPeaks,
        latestAscentDate: latestAscentDate,
        latestAscentPeaks: [
          for (final row in latestAscentPeakRows)
            _LatestAscentPeak(peakId: row.peakId, name: row.name),
        ],
      );
    } catch (_) {
      return _PeakListSummaryRow._(
        peakList: peakList,
        isSupported: false,
        totalPeaks: null,
        climbed: null,
        unclimbed: null,
        ascentCount: 0,
        totalPoints: null,
        earnedPoints: null,
        percentageValue: -1,
        peakRows: const [],
        mapPeaks: const [],
        latestAscentDate: null,
        latestAscentPeaks: const [],
        unsupportedMessage:
            'This peak list uses an unsupported legacy format. Delete it and re-import the CSV to inspect its peaks and metrics.',
      );
    }
  }

  final PeakList peakList;
  final bool isSupported;
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
  final String? unsupportedMessage;

  String get totalPeaksLabel => _formattedCountOrDash(totalPeaks);
  String get climbedLabel => _formattedCountOrDash(climbed);
  String get unclimbedLabel => _formattedCountOrDash(unclimbed);
  String get ascentCountLabel =>
      ascentCount == 0 ? '' : formatCount(ascentCount);
  String get percentageLabel {
    if (!isSupported) {
      return '-';
    }
    return formatPercentage(percentageValue * 100, decimalPlaces: 0);
  }

  String? buildSummarySentence() {
    if (!isSupported ||
        totalPeaks == null ||
        climbed == null ||
        earnedPoints == null ||
        totalPoints == null) {
      return unsupportedMessage;
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

class _PeakDetailRow {
  const _PeakDetailRow({
    required this.peakId,
    required this.name,
    required this.elevation,
    required this.ascentDate,
    required this.ascentCount,
    required this.points,
  });

  final int peakId;
  final String name;
  final double? elevation;
  final DateTime? ascentDate;
  final int ascentCount;
  final int points;

  String get elevationLabel {
    if (elevation == null) {
      return '';
    }
    return formatCompactElevation(elevation!);
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
    if (!summaryRow.isSupported ||
        latestAscentDate == null ||
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
