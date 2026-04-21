import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../models/peak.dart';
import '../models/peak_list.dart';
import '../main.dart';
import '../providers/map_provider.dart';
import '../providers/peak_provider.dart';
import '../services/peak_list_file_picker.dart';
import '../services/peak_list_import_service.dart';
import '../services/peak_list_repository.dart';
import '../services/peaks_bagged_repository.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/peak_list_import_dialog.dart';
import 'map_screen_layers.dart';

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  throw UnimplementedError('peakListRepositoryProvider must be overridden');
});

final peaksBaggedRepositoryProvider = Provider<PeaksBaggedRepository>((ref) {
  return PeaksBaggedRepository(objectboxStore);
});

final peakListImportServiceProvider = Provider<PeakListImportService>((ref) {
  return PeakListImportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListRepositoryProvider),
  );
});

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  final service = ref.watch(peakListImportServiceProvider);
  return ({required String listName, required String csvPath}) async {
    final result = await service.importPeakList(
      listName: listName,
      csvPath: csvPath,
    );
    return PeakListImportPresentationResult(
      updated: result.updated,
      importedCount: result.importedCount,
      skippedCount: result.skippedCount,
      warningCount: result.warningEntries.length,
      warningMessage: result.warningMessage,
      peakListId: result.peakListId,
      listName: listName.trim(),
    );
  };
});

final peakListDuplicateNameCheckerProvider =
    Provider<PeakListDuplicateNameChecker>((ref) {
      final repository = ref.watch(peakListRepositoryProvider);
      return (name) async => repository.findByName(name.trim()) != null;
    });

class PeakListsScreen extends ConsumerStatefulWidget {
  const PeakListsScreen({super.key});

  @override
  ConsumerState<PeakListsScreen> createState() => _PeakListsScreenState();
}

class _PeakListsScreenState extends ConsumerState<PeakListsScreen> {
  static const _wideBreakpoint = 900.0;
  static const _dividerWidth = 12.0;
  static const _minPaneWidth = 280.0;
  double _summaryFraction = 0.4;
  int? _selectedPeakListId;
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
    final latestAscentDatesByPeakId = peaksBaggedRepository
        .latestAscentDatesByPeakId();
    final peakLists = peakListRepository.getAllPeakLists();
    final summaryRows = peakLists
        .map(
          (peakList) => _PeakListSummaryRow.fromPeakList(
            peakList,
            peaksById: peaksById,
            latestAscentDatesByPeakId: latestAscentDatesByPeakId,
          ),
        )
        .toList(growable: false);
    final sortedSummaryRows = _sortSummaryRows(summaryRows);
    final selectedSummaryRow = _resolveSelectedSummaryRow(sortedSummaryRows);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final summaryPane = _SummaryPane(
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
          );
          final detailsPane = _DetailsPane(
            selectedSummaryRow: selectedSummaryRow,
          );

          if (!isWide) {
            return Column(
              children: [
                Expanded(
                  child: SizedBox(
                    key: const Key('peak-lists-summary-pane'),
                    width: double.infinity,
                    child: summaryPane,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SizedBox(
                    key: const Key('peak-lists-details-pane'),
                    width: double.infinity,
                    child: detailsPane,
                  ),
                ),
              ],
            );
          }

          final availableWidth = constraints.maxWidth - _dividerWidth;
          final minFraction = (_minPaneWidth / availableWidth).clamp(0.0, 0.5);
          final maxFraction = 1 - minFraction;
          final clampedFraction = _summaryFraction.clamp(
            minFraction,
            maxFraction,
          );
          final summaryWidth = availableWidth * clampedFraction;
          final detailsWidth = availableWidth - summaryWidth;

          return Row(
            children: [
              SizedBox(
                key: const Key('peak-lists-summary-pane'),
                width: summaryWidth,
                child: summaryPane,
              ),
              MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  key: const Key('peak-lists-divider'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    final nextFraction =
                        (summaryWidth + details.delta.dx) / availableWidth;
                    setState(() {
                      _summaryFraction = nextFraction.clamp(
                        minFraction,
                        maxFraction,
                      );
                    });
                  },
                  child: const SizedBox(
                    width: _dividerWidth,
                    child: VerticalDivider(width: _dividerWidth),
                  ),
                ),
              ),
              SizedBox(
                key: const Key('peak-lists-details-pane'),
                width: detailsWidth,
                child: detailsPane,
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('peak-lists-import-fab'),
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

          if (!mounted || result == null) {
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
          setState(() {
            _selectedPeakListId = selected.peakListId;
          });
        },
        label: const Text('Import Peak List'),
        icon: const Icon(Icons.upload_file),
      ),
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

    await ref.read(peakListRepositoryProvider).delete(peakListId);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedPeakListId = nextSelectedPeakListId;
    });
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

enum _PeakListSortColumn { name, totalPeaks, climbed, percentage, unclimbed }

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Peak Lists', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SummaryHeader(
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onSortSelected: onSortSelected,
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No peak lists exist. Import a CSV to get started.',
                  key: Key('peak-lists-empty-message'),
                ),
              ),
            ),
          ] else
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final peakListId = row.peakList.peakListId;
                  return Card(
                    child: InkWell(
                      key: Key('peak-lists-row-$peakListId'),
                      onTap: () => onSelected(peakListId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                row.peakList.name,
                                style: peakListId == selectedPeakListId
                                    ? const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      )
                                    : null,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.totalPeaksLabel,
                                key: Key('peak-lists-total-$peakListId'),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.climbedLabel,
                                key: Key('peak-lists-climbed-$peakListId'),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.percentageLabel,
                                key: Key('peak-lists-percentage-$peakListId'),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                row.unclimbedLabel,
                                key: Key('peak-lists-unclimbed-$peakListId'),
                              ),
                            ),
                            SizedBox(
                              width: 48,
                              child: IconButton(
                                 key: Key('peak-lists-delete-$peakListId'),
                                 icon: const Icon(Icons.delete_forever),
                                 tooltip: 'Delete ${row.peakList.name}',
                                 onPressed: () => onDeleteRequested(peakListId),
                               ),
                             ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSortSelected,
  });

  final _PeakListSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_PeakListSortColumn> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _SortHeaderCell(
            label: 'List',
            column: _PeakListSortColumn.name,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        Expanded(
          child: _SortHeaderCell(
            label: 'Total Peaks',
            column: _PeakListSortColumn.totalPeaks,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        Expanded(
          child: _SortHeaderCell(
            label: 'Climbed',
            column: _PeakListSortColumn.climbed,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        Expanded(
          child: _SortHeaderCell(
            label: 'Percentage',
            column: _PeakListSortColumn.percentage,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        Expanded(
          child: _SortHeaderCell(
            label: 'Unclimbed',
            column: _PeakListSortColumn.unclimbed,
            sortColumn: sortColumn,
            sortAscending: sortAscending,
            onTap: onSortSelected,
            textStyle: style,
          ),
        ),
        SizedBox(width: 48, child: Text('Actions', style: style)),
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
            Expanded(child: Text(label, style: textStyle)),
            Icon(
              icon,
              key: Key('peak-lists-sort-icon-${column.name}'),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.selectedSummaryRow});

  final _PeakListSummaryRow? selectedSummaryRow;

  @override
  Widget build(BuildContext context) {
    final title = selectedSummaryRow?.peakList.name ?? 'Peak List Details';
    final summaryText = selectedSummaryRow?.buildSummarySentence();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            key: const Key('peak-lists-selected-title'),
            style: Theme.of(context).textTheme.titleLarge,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackDetails = constraints.maxWidth < 720;
                final peakTable = _PeakDetailsTable(
                  selectedSummaryRow: selectedSummaryRow,
                );
                final miniMap = _MiniPeakMap(
                  selectedSummaryRow: selectedSummaryRow,
                );

                if (stackDetails) {
                  return Column(
                    children: [
                      Expanded(child: peakTable),
                      const Divider(height: 1),
                      Expanded(child: miniMap),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(flex: 3, child: peakTable),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 7, child: miniMap),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakDetailsTable extends StatelessWidget {
  const _PeakDetailsTable({required this.selectedSummaryRow});

  final _PeakListSummaryRow? selectedSummaryRow;

  @override
  Widget build(BuildContext context) {
    final rows = selectedSummaryRow?.peakRows ?? const <_PeakDetailRow>[];
    final unsupportedMessage = selectedSummaryRow?.unsupportedMessage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            _PeakDetailsHeaderRow(
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            const Divider(height: 16),
            if (selectedSummaryRow == null)
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
            for (final row in rows)
              Padding(
                key: Key('peak-lists-details-row-${row.peakId}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(row.name)),
                    Expanded(child: Text(row.elevationLabel)),
                    Expanded(child: Text(row.ascentDateLabel)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeakDetailsHeaderRow extends StatelessWidget {
  const _PeakDetailsHeaderRow({required this.textStyle});

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: Text('Peak Name', style: textStyle)),
        Expanded(child: Text('Elevation', style: textStyle)),
        Expanded(child: Text('Ascent Date', style: textStyle)),
      ],
    );
  }
}

class _MiniPeakMap extends StatefulWidget {
  const _MiniPeakMap({required this.selectedSummaryRow});

  final _PeakListSummaryRow? selectedSummaryRow;

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
  static final _tasmaniaBounds = LatLngBounds(
    const LatLng(-43.643, 143.833),
    const LatLng(-39.579, 148.482),
  );
  static const _tasmaniaCenter = LatLng(-41.611, 146.1575);

  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  @override
  void didUpdateWidget(covariant _MiniPeakMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  @override
  Widget build(BuildContext context) {
    final markerPeaks =
        widget.selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FlutterMap(
          key: const Key('peak-lists-mini-map'),
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _tasmaniaCenter,
            initialZoom: 6,
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
          ],
        ),
      ),
    );
  }

  void _fitBounds() {
    if (!mounted) {
      return;
    }

    final markerPeaks =
        widget.selectedSummaryRow?.mapPeaks ?? const <_MapPeak>[];
    if (markerPeaks.isEmpty) {
      _fitTasmaniaBounds();
      return;
    }

    if (markerPeaks.length == 1) {
      _mapController.move(
        LatLng(
          markerPeaks.first.peak.latitude,
          markerPeaks.first.peak.longitude,
        ),
        11,
      );
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      markerPeaks
          .map((peak) => LatLng(peak.peak.latitude, peak.peak.longitude))
          .toList(growable: false),
    );
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
      );
    } catch (_) {
      _fitTasmaniaBounds();
    }
  }

  void _fitTasmaniaBounds() {
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _tasmaniaBounds,
          padding: const EdgeInsets.all(24),
        ),
      );
    } catch (_) {
      _mapController.move(_tasmaniaCenter, 6);
    }
  }
}

class _PeakListSummaryRow {
  const _PeakListSummaryRow._({
    required this.peakList,
    required this.isSupported,
    required this.totalPeaks,
    required this.climbed,
    required this.unclimbed,
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
    required Map<int, DateTime?> latestAscentDatesByPeakId,
  }) {
    try {
      final items = decodePeakListItems(peakList.peakList);
      final uniquePeakIds = <int>[];
      final seenPeakIds = <int>{};
      for (final item in items) {
        if (seenPeakIds.add(item.peakOsmId)) {
          uniquePeakIds.add(item.peakOsmId);
        }
      }

      final peakRows = uniquePeakIds
          .map((peakId) {
            final peak = peaksById[peakId];
            return _PeakDetailRow(
              peakId: peakId,
              name: peak?.name ?? 'Unknown',
              elevation: peak?.elevation,
              ascentDate: latestAscentDatesByPeakId[peakId],
            );
          })
          .toList(growable: false);
      final mapPeaks = uniquePeakIds
          .map((peakId) {
            final peak = peaksById[peakId];
            if (peak == null) {
              return null;
            }
            return _MapPeak(
              peak: peak,
              isClimbed: latestAscentDatesByPeakId.containsKey(peakId),
            );
          })
          .whereType<_MapPeak>()
          .toList(growable: false);
      final climbed = uniquePeakIds
          .where((peakId) => latestAscentDatesByPeakId.containsKey(peakId))
          .length;
      final totalPeaks = uniquePeakIds.length;
      final unclimbed = totalPeaks - climbed;
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
  final double percentageValue;
  final List<_PeakDetailRow> peakRows;
  final List<_MapPeak> mapPeaks;
  final DateTime? latestAscentDate;
  final List<String> latestAscentPeakNames;
  final String? unsupportedMessage;

  String get totalPeaksLabel => totalPeaks?.toString() ?? '-';
  String get climbedLabel => climbed?.toString() ?? '-';
  String get unclimbedLabel => unclimbed?.toString() ?? '-';
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

    final metricsSentence =
        '${peakList.name} contains $totalPeaks peaks. Climbed $climbed of $totalPeaks (${(percentageValue * 100).round()}%).';
    if (latestAscentDate == null || latestAscentPeakNames.isEmpty) {
      return metricsSentence;
    }

    final joinedPeakNames = _joinPeakNames(latestAscentPeakNames);
    final verb = latestAscentPeakNames.length == 1 ? 'is' : 'are';
    return '$joinedPeakNames $verb your most recent, climbed on ${_formatDate(latestAscentDate!)}. $metricsSentence';
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
  });

  final int peakId;
  final String name;
  final double? elevation;
  final DateTime? ascentDate;

  String get elevationLabel {
    if (elevation == null) {
      return '';
    }
    if (elevation == elevation!.roundToDouble()) {
      return elevation!.round().toString();
    }
    return elevation!.toStringAsFixed(1);
  }

  String get ascentDateLabel {
    if (ascentDate == null) {
      return '';
    }
    return _formatDate(ascentDate!);
  }
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
