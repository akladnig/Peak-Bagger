import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_areas.dart';
import '../models/peak.dart';
import '../models/peak_list.dart';
import '../models/peaks_bagged.dart';
import '../providers/peak_list_provider.dart';
import '../providers/peak_list_selection_provider.dart';
import '../providers/map_provider.dart';
import '../providers/peak_provider.dart';
import '../services/peak_list_file_picker.dart';
import '../services/peak_list_repository.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/left_tooltip_fab.dart';
import '../widgets/peak_list_create_dialog.dart';
import '../widgets/peak_list_import_dialog.dart';
import '../widgets/peak_list_peak_dialog.dart';
import 'map_screen_layers.dart';

class PeakListsScreen extends ConsumerStatefulWidget {
  const PeakListsScreen({super.key});

  @override
  ConsumerState<PeakListsScreen> createState() => _PeakListsScreenState();
}

class _PeakListsScreenState extends ConsumerState<PeakListsScreen> {
  static const _dividerWidth = 1.0;
  static const _preferredLeftWidth = 320.0;
  static const _preferredRightWidth = 360.0;
  static const _minimumMiniMapAspectWidth = 294.0;
  static const _columnCellHorizontalPadding = 12.0;
  int? _selectedPeakListId;
  int? _selectedPeakId;
  _PeakListSortColumn _sortColumn = _PeakListSortColumn.percentage;
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final filePicker = ref.watch(peakListFilePickerProvider);
    final importRunner = ref.watch(peakListImportRunnerProvider);
    final duplicateNameChecker = ref.watch(
      peakListDuplicateNameCheckerProvider,
    );
    final peakListRepository = ref.watch(peakListRepositoryProvider);
    final peakRepository = ref.watch(peakRepositoryProvider);
    final peaksBaggedRepository = ref.watch(peaksBaggedRepositoryProvider);
    final peaksById = <int, Peak>{
      for (final peak in peakRepository.getAllPeaks()) peak.osmId: peak,
    };
    final ascentCountsByPeakId = peaksBaggedRepository.ascentCountsByPeakId();
    final latestAscentDatesByPeakId = peaksBaggedRepository
        .latestAscentDatesByPeakId();
    final peakLists = peakListRepository.getAllPeakLists();
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
                ),
              ),
              const VerticalDivider(width: _dividerWidth),
              SizedBox(
                key: const Key('peak-lists-details-pane'),
                width: panes.rightWidth,
                child: _DetailsPane(
                  selectedSummaryRow: selectedSummaryRow,
                  selectedPeakId: _selectedPeakId,
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
    final usableWidth = math.max(0.0, bodyWidth - _dividerWidth);
    final preferredLeft = usableWidth * 0.55;
    final rightSoftTarget = _preferredRightWidth;
    final maxLeftAtPreferredRight = math.max(
      0.0,
      usableWidth - rightSoftTarget,
    );
    final minLeftForMiniMap = _minimumMiniMapAspectWidth;
    final leftWidth =
        usableWidth >=
            (_preferredLeftWidth + _preferredRightWidth + _dividerWidth)
        ? preferredLeft
              .clamp(_preferredLeftWidth, maxLeftAtPreferredRight)
              .toDouble()
        : math.max(
            minLeftForMiniMap,
            math.min(_preferredLeftWidth, maxLeftAtPreferredRight),
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

  void _selectPeakList(int peakListId) {
    setState(() {
      _selectedPeakListId = peakListId;
      _selectedPeakId = null;
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

    await ref.read(peakListRepositoryProvider).delete(peakListId);
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
          peakListRepository: ref.read(peakListRepositoryProvider),
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
          peakListRepository: ref.read(peakListRepositoryProvider),
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
                .read(peakListRepositoryProvider)
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

enum _PeakDetailSortColumn { name, elevation, ascentDate, ascents, points }

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
  double points,
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
  const horizontalPadding =
      _PeakListsScreenState._columnCellHorizontalPadding * 2;
  const headerLabelGap = 12.0;

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

  const rowHorizontalPadding = 40.0;
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
  const horizontalPadding =
      _PeakListsScreenState._columnCellHorizontalPadding * 2;
  const columnGap = 12.0;
  const headerIconWidth = 18.0;
  const headerLabelGap = 12.0;
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
  double points =
      math.max(
        _measureTextWidth(context, 'Points', headerStyle) + headerControlWidth,
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
    points = math.max(
      points,
      _measureTextWidth(context, row.pointsLabel, cellStyle) +
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
    points: points,
    totalWidth:
        peakName + elevation + ascentDate + ascents + points + (columnGap * 4),
  );
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.rows,
    required this.selectedPeakListId,
    required this.selectedMapPeak,
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
  final _MapPeak? selectedMapPeak;
  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<int> onSelected;
  final ValueChanged<_PeakListSortColumn> onSortSelected;
  final ValueChanged<int> onDeleteRequested;
  final PeakListFilePicker filePicker;
  final PeakListImportRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final VoidCallback onCreateRequested;
  final PeakListRepository peakListRepository;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeakListsToolbar(
            filePicker: filePicker,
            importRunner: importRunner,
            duplicateNameChecker: duplicateNameChecker,
            onCreateRequested: onCreateRequested,
            peakListRepository: peakListRepository,
          ),
          const SizedBox(height: 12),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakListsToolbar extends StatelessWidget {
  const _PeakListsToolbar({
    required this.filePicker,
    required this.importRunner,
    required this.duplicateNameChecker,
    required this.onCreateRequested,
    required this.peakListRepository,
  });

  final PeakListFilePicker filePicker;
  final PeakListImportRunner importRunner;
  final PeakListDuplicateNameChecker duplicateNameChecker;
  final VoidCallback onCreateRequested;
  final PeakListRepository peakListRepository;

  @override
  Widget build(BuildContext context) {
    final fabBackground = _fabBackgroundColor(context);
    final fabForeground = _fabForegroundColor(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'My Peak Lists',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
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
              final result = await showDialog<PeakListImportPresentationResult>(
                context: context,
                builder: (context) {
                  return PeakListImportDialog(
                    filePicker: filePicker,
                    onImport: importRunner,
                    duplicateNameChecker: duplicateNameChecker,
                  );
                },
              );

              if (!context.mounted || result == null) {
                return;
              }

              final imported = result.peakListId == null
                  ? null
                  : peakListRepository.findById(result.peakListId!);
              final selected =
                  imported ??
                  (result.listName == null
                      ? null
                      : peakListRepository.findByName(result.listName!));
              if (selected == null) {
                return;
              }
              final state = context
                  .findAncestorStateOfType<_PeakListsScreenState>();
              if (state == null) {
                return;
              }
              state._selectPeakList(selected.peakListId);
            },
            child: Icon(Icons.upload_file, color: fabForeground),
          ),
        ),
      ],
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
  });

  final List<_PeakListSummaryRow> rows;
  final int? selectedPeakListId;
  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<int> onSelected;
  final ValueChanged<_PeakListSortColumn> onSortSelected;
  final ValueChanged<int> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final widths = _resolveSummaryTableWidths(context, rows);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: widths.totalWidth,
                height: constraints.maxHeight,
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
                                    key: Key('peak-lists-empty-message'),
                                  ),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              key: const Key('peak-lists-summary-table-scroll'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final row in rows)
                                    _SummaryRowCard(
                                      row: row,
                                      selectedPeakListId: selectedPeakListId,
                                      widths: widths,
                                      onSelected: onSelected,
                                      onDeleteRequested: onDeleteRequested,
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
    required this.onSelected,
    required this.onDeleteRequested,
  });

  final _PeakListSummaryRow row;
  final int? selectedPeakListId;
  final _SummaryTableWidths widths;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final peakListId = row.peakList.peakListId;
    return Card(
      child: InkWell(
        key: Key('peak-lists-row-$peakListId'),
        onTap: () => onSelected(peakListId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: widths.list,
                child: Text(
                  row.peakList.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: peakListId == selectedPeakListId
                      ? const TextStyle(fontWeight: FontWeight.w600)
                      : null,
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
                ),
              ),
              SizedBox(
                width: widths.actions,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    key: Key('peak-lists-delete-$peakListId'),
                    icon: const Icon(Icons.delete_forever),
                    tooltip: 'Delete ${row.peakList.name}',
                    onPressed: () => onDeleteRequested(peakListId),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({
    required this.selectedSummaryRow,
    required this.selectedPeakId,
    required this.onPeakSelected,
    required this.onAddPeakRequested,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final int? selectedPeakId;
  final Future<void> Function(int) onPeakSelected;
  final Future<void> Function() onAddPeakRequested;

  @override
  Widget build(BuildContext context) {
    final fabBackground = _fabBackgroundColor(context);
    final fabForeground = _fabForegroundColor(context);

    final title = selectedSummaryRow?.peakList.name ?? 'Peak List Details';
    final summaryText = selectedSummaryRow?.buildSummarySentence();

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
            Text(
              summaryText,
              key: const Key('peak-lists-summary-sentence'),
              softWrap: true,
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

  @override
  void didUpdateWidget(covariant _PeakDetailsTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPeakListId = oldWidget.selectedSummaryRow?.peakList.peakListId;
    final newPeakListId = widget.selectedSummaryRow?.peakList.peakListId;
    if (oldPeakListId != newPeakListId) {
      _sortColumn = _PeakDetailSortColumn.ascentDate;
      _sortAscending = false;
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
                                    InkWell(
                                      key: Key(
                                        'peak-lists-details-row-${row.peakId}',
                                      ),
                                      onTap: () async {
                                        await widget.onPeakSelected(row.peakId);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        color:
                                            row.peakId == widget.selectedPeakId
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.08)
                                            : null,
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: widths.peakName,
                                              child: Text(
                                                row.name,
                                                maxLines: 2,
                                                softWrap: true,
                                                overflow: TextOverflow.clip,
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
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: widths.ascents,
                                              child: Text(
                                                row.ascentCountLabel,
                                                key: Key(
                                                  'peak-lists-details-ascents-${row.peakId}',
                                                ),
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.clip,
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: widths.points,
                                              child: Text(
                                                row.pointsLabel,
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.clip,
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ],
                                        ),
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
        _PeakDetailSortColumn.points => left.points.compareTo(right.points),
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
    const columnGap = SizedBox(width: 12);
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
        columnGap,
        SizedBox(
          width: widths.points,
          child: _DetailSortHeaderCell(
            label: 'Points',
            column: _PeakDetailSortColumn.points,
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
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final _MapPeak? selectedMapPeak;

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
                    selectedSummaryRow: selectedSummaryRow,
                    selectedMapPeak: selectedMapPeak,
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

class _MiniPeakMap extends StatefulWidget {
  const _MiniPeakMap({
    required this.selectedSummaryRow,
    required this.selectedMapPeak,
  });

  final _PeakListSummaryRow? selectedSummaryRow;
  final _MapPeak? selectedMapPeak;

  @override
  State<_MiniPeakMap> createState() => _MiniPeakMapState();
}

class _MiniPeakMapState extends State<_MiniPeakMap> {
  static final _tickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker_ticked.svg',
  );
  static final _untickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker.svg',
    colorFilter: const ColorFilter.mode(Color(0xFFD66A6D), BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final markerPeaks =
        widget.selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: KeyedSubtree(
          key: const Key('peak-lists-mini-map'),
          child: FlutterMap(
            key: ValueKey(widget.selectedSummaryRow?.peakList.peakListId),
            options: MapOptions(
              initialCameraFit: _resolveInitialCameraFit(markerPeaks),
            ),
            children: [
              TileLayer(
                urlTemplate: mapTileUrl(Basemap.openstreetmap),
                userAgentPackageName: 'com.peak_bagger.app',
                tileProvider: NetworkTileProvider(),
              ),
              MarkerLayer(
                markers:
                    buildPeakMarkers(
                          peaks: [for (final peak in markerPeaks) peak.peak],
                          zoom: 0,
                          correlatedPeakIds: {
                            for (final peak in markerPeaks.where(
                              (peak) => peak.isClimbed,
                            ))
                              peak.peak.osmId,
                          },
                          tickedPeakMarker: _tickedPeakMarker,
                          untickedPeakMarker: _untickedPeakMarker,
                          suppressBelowZoom: false,
                        )
                        .asMap()
                        .entries
                        .map((entry) {
                          final marker = entry.value;
                          final peak = markerPeaks[entry.key];
                          return Marker(
                            point: marker.point,
                            width: marker.width,
                            height: marker.height,
                            child: SizedBox(
                              key: Key(
                                'peak-lists-mini-map-marker-${peak.peak.osmId}-${peak.isClimbed ? 'ticked' : 'unticked'}',
                              ),
                              child: marker.child,
                            ),
                          );
                        })
                        .toList(growable: false),
              ),
              if (widget.selectedMapPeak != null)
                CircleLayer(
                  key: const Key('peak-lists-selected-peak-circle-layer'),
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
    required this.latestAscentPeakNames,
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
        latestAscentPeakNames: [
          for (final row in latestAscentPeakRows) row.name,
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
        latestAscentPeakNames: const [],
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
  final List<String> latestAscentPeakNames;
  final String? unsupportedMessage;

  String get totalPeaksLabel => totalPeaks?.toString() ?? '-';
  String get climbedLabel => climbed?.toString() ?? '-';
  String get unclimbedLabel => unclimbed?.toString() ?? '-';
  String get ascentCountLabel => ascentCount == 0 ? '' : ascentCount.toString();
  String get percentageLabel {
    if (!isSupported) {
      return '-';
    }
    return '${(percentageValue * 100).round()}%';
  }

  String? buildSummarySentence() {
    if (!isSupported || totalPeaks == null || climbed == null) {
      return unsupportedMessage;
    }

    final infoSentence = '${peakList.name} contains $totalPeaks peaks.';

    final metricsSentence =
        'Climbed $climbed of $totalPeaks peaks (${(percentageValue * 100).round()}%) and earned a total $earnedPoints points out of $totalPoints.';
    if (latestAscentDate == null || latestAscentPeakNames.isEmpty) {
      return '$infoSentence\n\n$metricsSentence';
    }

    final joinedPeakNames = _joinPeakNames(latestAscentPeakNames);
    final verb = latestAscentPeakNames.length == 1 ? 'is' : 'are';
    return '$infoSentence\n\n$joinedPeakNames $verb your most recent ascent, climbed on ${_formatDate(latestAscentDate!)}.\n$metricsSentence';
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
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
    if (elevation == elevation!.roundToDouble()) {
      return '${elevation!.round()}m';
    }
    return '${elevation!.toStringAsFixed(1)}m';
  }

  String get ascentDateLabel {
    if (ascentDate == null) {
      return '';
    }
    return _formatDate(ascentDate!);
  }

  String get ascentCountLabel => ascentCount == 0 ? '' : ascentCount.toString();

  String get pointsLabel => points.toString();
}

class _MapPeak {
  const _MapPeak({required this.peak, required this.isClimbed});

  final Peak peak;
  final bool isClimbed;
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
