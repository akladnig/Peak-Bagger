import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/gpx_track.dart';
import '../models/peak.dart';
import '../models/peak_list.dart';
import '../models/peaks_bagged.dart';
import '../models/tasmap50k.dart';
import '../providers/map_provider.dart';
import '../providers/peak_provider.dart';
import '../providers/tasmap_provider.dart';
import '../router.dart';
import '../services/peak_list_repository.dart';
import 'dialog_helpers.dart';
import 'peak_search_results_list.dart';

enum PeakListPeakDialogMode { view, add, edit }

class PeakListPeakDialogOutcome {
  const PeakListPeakDialogOutcome._({
    required this.selectedPeakId,
    required this.deleted,
  });

  const PeakListPeakDialogOutcome.selected(int selectedPeakId)
    : this._(selectedPeakId: selectedPeakId, deleted: false);

  const PeakListPeakDialogOutcome.deleted([int? selectedPeakId])
    : this._(selectedPeakId: selectedPeakId, deleted: true);

  final int? selectedPeakId;
  final bool deleted;
}

class PeakListPeakDialog extends ConsumerStatefulWidget {
  const PeakListPeakDialog({
    required this.mode,
    required this.peakList,
    required this.peakListRepository,
    required this.peakItems,
    required this.ascentRows,
    this.peak,
    this.points,
    super.key,
  });

  final PeakListPeakDialogMode mode;
  final PeakList peakList;
  final PeakListRepository peakListRepository;
  final List<PeakListItem> peakItems;
  final List<PeaksBagged> ascentRows;
  final Peak? peak;
  final int? points;

  @override
  ConsumerState<PeakListPeakDialog> createState() => _PeakListPeakDialogState();
}

class _PeakListPeakDialogState extends ConsumerState<PeakListPeakDialog> {
  static const _dialogMargin = 24.0;
  final _searchController = TextEditingController();
  final _pointValues = List<int>.generate(11, (index) => index);

  late PeakListPeakDialogMode _mode;
  Peak? _selectedPeak;
  int _selectedPoints = 0;
  String _searchQuery = '';
  bool _saving = false;
  Offset _dialogOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _selectedPeak = widget.peak;
    _selectedPoints = widget.points ?? 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width - (_dialogMargin * 2))
        .clamp(320.0, 700.0)
        .toDouble();
    final maxLeftShift = size.width - dialogWidth - (_dialogMargin * 2);
    final clampedOffset = Offset(
      _dialogOffset.dx.clamp(-maxLeftShift, 0).toDouble(),
      _dialogOffset.dy.clamp(-(size.height * 0.5), 0).toDouble(),
    );

    return SafeArea(
      child: SizedBox.expand(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(_dialogMargin),
            child: Transform.translate(
              offset: clampedOffset,
              child: Material(
                key: const Key('peak-list-peak-dialog'),
                color:
                    Theme.of(context).dialogTheme.backgroundColor ??
                    Theme.of(context).colorScheme.surface,
                elevation: 6,
                shadowColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: size.height - (_dialogMargin * 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        key: const Key('peak-list-peak-dialog-drag-handle'),
                        onPanUpdate: (details) {
                          setState(() {
                            _dialogOffset += details.delta;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: _mode == PeakListPeakDialogMode.view
                                    ? GestureDetector(
                                        key: const Key('peak-list-peak-name'),
                                        onTap: _navigateToPeakOnMap,
                                        child: Text(
                                          _titleLabel,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      )
                                    : Text(_titleLabel),
                              ),
                              if (_mode == PeakListPeakDialogMode.view) ...[
                                IconButton(
                                  key: const Key('peak-list-peak-edit'),
                                  onPressed: _saving ? null : _enterEditMode,
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  key: const Key('peak-list-peak-delete'),
                                  onPressed: _saving
                                      ? null
                                      : _deleteSelectedPeak,
                                  icon: const Icon(Icons.delete_forever),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: SizedBox(
                            width: dialogWidth - 48,
                            child: switch (_mode) {
                              PeakListPeakDialogMode.view => _buildViewContent(
                                context,
                              ),
                              PeakListPeakDialogMode.add => _buildAddContent(
                                context,
                              ),
                              PeakListPeakDialogMode.edit => _buildEditContent(
                                context,
                              ),
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              key: Key(
                                _mode == PeakListPeakDialogMode.view
                                    ? 'peak-list-peak-close'
                                    : 'peak-list-peak-cancel',
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Text(
                                _mode == PeakListPeakDialogMode.view
                                    ? 'Close'
                                    : 'Cancel',
                              ),
                            ),
                            if (_mode != PeakListPeakDialogMode.view) ...[
                              const SizedBox(width: 12),
                              FilledButton(
                                key: const Key('peak-list-peak-save'),
                                onPressed: _saving ? null : _saveCurrentMode,
                                child: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewContent(BuildContext context) {
    final peak = widget.peak;
    if (peak == null) {
      return const Text('No peak selected');
    }

    final theme = Theme.of(context);
    final elevationLabel = peak.elevation == null
        ? ''
        : peak.elevation == peak.elevation!.roundToDouble()
        ? '${peak.elevation!.round()}m'
        : '${peak.elevation!.toStringAsFixed(1)}m';
    final resolvedMap = _resolveMap(peak);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailLine(label: 'List', value: Text(widget.peakList.name)),
        _DetailLine(label: 'Height', value: Text(elevationLabel)),
        _DetailLine(
          label: 'Points',
          value: Text(_pointsForPeak(peak.osmId).toString()),
        ),
        _DetailLine(label: 'MGRS', value: Text(_displayMgrs(peak))),
        _DetailLine(
          label: 'Map',
          value: resolvedMap == null
              ? const Text('Unknown')
              : TextButton(
                  key: const Key('peak-list-peak-map-link'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () => _openMap(resolvedMap),
                  child: Text(resolvedMap.name),
                ),
        ),
        const SizedBox(height: 16),
        Text('Ascent History', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PeakHistoryHeader(textStyle: theme.textTheme.labelLarge),
                const Divider(height: 16),
                Expanded(
                  child: widget.ascentRows.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          itemCount: widget.ascentRows.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _HistoryRow(
                              row: widget.ascentRows[index],
                              onTrackSelected: _openTrack,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddContent(BuildContext context) {
    final searchResults = _filteredSearchResults();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('peak-list-peak-search-input'),
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search peaks',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 12),
        if (searchResults.isNotEmpty || _searchQuery.isNotEmpty)
          SizedBox(
            height: 180,
            child: PeakSearchResultsList(
              searchResults: searchResults,
              searchQuery: _searchQuery,
              selectedPeakId: _selectedPeak?.osmId,
              mapNameForPeak: _mapNameForPeak,
              itemKeyBuilder: (peak) =>
                  Key('peak-list-peak-result-${peak.osmId}'),
              onSelectPeak: (peak) {
                setState(() {
                  _selectedPeak = peak;
                  _selectedPoints = 0;
                });
              },
            ),
          ),
        const SizedBox(height: 12),
        if (_selectedPeak != null) ...[
          Text('Selected: ${_selectedPeak!.name}'),
          const SizedBox(height: 8),
          _PointsSelector(
            value: _selectedPoints,
            values: _pointValues,
            onChanged: (value) {
              setState(() {
                _selectedPoints = value;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEditContent(BuildContext context) {
    final peak = widget.peak;
    if (peak == null) {
      return const Text('No peak selected');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _DetailLine(label: 'Peak', value: Text(peak.name)),
        const SizedBox(height: 12),
        _PointsSelector(
          value: _selectedPoints,
          values: _pointValues,
          onChanged: (value) {
            setState(() {
              _selectedPoints = value;
            });
          },
        ),
      ],
    );
  }

  String get _titleLabel {
    return switch (_mode) {
      PeakListPeakDialogMode.view => widget.peak?.name ?? 'Peak Details',
      PeakListPeakDialogMode.add => 'Add New Peak',
      PeakListPeakDialogMode.edit => 'Edit Peak',
    };
  }

  List<Peak> _filteredSearchResults() {
    final repository = ref.read(peakRepositoryProvider);
    final peaks = repository.searchPeaks(_searchQuery);
    final existingIds = widget.peakItems.map((item) => item.peakOsmId).toSet();
    return peaks.where((peak) => !existingIds.contains(peak.osmId)).toList();
  }

  int _pointsForPeak(int peakOsmId) {
    for (final item in widget.peakItems) {
      if (item.peakOsmId == peakOsmId) {
        return item.points;
      }
    }
    return widget.points ?? 0;
  }

  String _mgrsLookupValue(Peak peak) {
    return '${peak.gridZoneDesignator}${peak.mgrs100kId}${peak.easting}${peak.northing}';
  }

  String _displayMgrs(Peak peak) {
    final mgrsValue = [
      peak.gridZoneDesignator,
      peak.mgrs100kId,
      peak.easting,
      peak.northing,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    return '$mgrsValue (${peak.latitude.toStringAsFixed(5)}, ${peak.longitude.toStringAsFixed(5)})';
  }

  Tasmap50k? _resolveMap(Peak peak) {
    try {
      final mgrsRepository = ref.read(tasmapRepositoryProvider);
      return mgrsRepository.findByMgrsCodeAndCoordinates(
        _mgrsLookupValue(peak),
      );
    } catch (_) {
      return null;
    }
  }

  String _mapNameForPeak(Peak peak) {
    return _resolveMap(peak)?.name ?? 'Unknown';
  }

  void _openMap(Tasmap50k map) {
    ref.read(mapProvider.notifier).selectMap(map);
    _closeDialogAndGoMap();
  }

  void _navigateToPeakOnMap() {
    final peak = widget.peak;
    if (peak == null) return;
    ref
        .read(mapProvider.notifier)
        .updatePosition(LatLng(peak.latitude, peak.longitude), 15.0);
    _closeDialogAndGoMap();
  }

  Future<void> _enterEditMode() async {
    setState(() {
      _mode = PeakListPeakDialogMode.edit;
      _selectedPoints = _pointsForPeak(widget.peak?.osmId ?? 0);
    });
  }

  Future<void> _saveCurrentMode() async {
    if (_mode == PeakListPeakDialogMode.add) {
      await _saveAdd();
      return;
    }

    if (_mode == PeakListPeakDialogMode.edit) {
      await _saveEdit();
    }
  }

  Future<void> _saveAdd() async {
    final selectedPeak = _selectedPeak;
    if (selectedPeak == null) {
      await _showFailure('Select a peak first');
      return;
    }

    if (widget.peakItems.any((item) => item.peakOsmId == selectedPeak.osmId)) {
      await _showFailure('Peak already exists in list');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.peakListRepository.addPeakItem(
        peakListId: widget.peakList.peakListId,
        item: PeakListItem(
          peakOsmId: selectedPeak.osmId,
          points: _selectedPoints,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(PeakListPeakDialogOutcome.selected(selectedPeak.osmId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showFailure(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveEdit() async {
    final peak = widget.peak;
    if (peak == null) {
      await _showFailure('No peak selected');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.peakListRepository.updatePeakItemPoints(
        peakListId: widget.peakList.peakListId,
        peakOsmId: peak.osmId,
        points: _selectedPoints,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(PeakListPeakDialogOutcome.selected(peak.osmId));
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showFailure(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedPeak() async {
    final peak = widget.peak;
    if (peak == null) {
      return;
    }

    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: 'Delete Peak?',
      message: 'Remove ${peak.name} from ${widget.peakList.name}?',
      cancelKey: 'peak-list-peak-delete-cancel',
      cancelLabel: 'Cancel',
      confirmKey: 'peak-list-peak-delete-confirm',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await widget.peakListRepository.removePeakItem(
        peakListId: widget.peakList.peakListId,
        peakOsmId: peak.osmId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop(PeakListPeakDialogOutcome.deleted(_nextSelectedPeakId(peak.osmId)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      await _showFailure(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  int? _nextSelectedPeakId(int deletedPeakId) {
    final peakIds = widget.peakItems.map((item) => item.peakOsmId).toList();
    final index = peakIds.indexOf(deletedPeakId);
    if (index == -1) {
      return peakIds.isEmpty ? null : peakIds.first;
    }
    if (peakIds.length == 1) {
      return null;
    }
    if (index < peakIds.length - 1) {
      return peakIds[index + 1];
    }
    return peakIds[index - 1];
  }

  Future<void> _openTrack(PeaksBagged row) async {
    if (row.gpxId <= 0) {
      return;
    }

    final trackRepository = ref.read(gpxTrackRepositoryProvider);
    final track = trackRepository.findById(row.gpxId);
    if (!mounted) {
      return;
    }
    if (track == null) {
      await _showFailure('Track #${row.gpxId} could not be found');
      return;
    }

    final mapNotifier = ref.read(mapProvider.notifier);
    mapNotifier.enableSync();
    mapNotifier.showTrack(
      track.gpxTrackId,
      selectedLocation: widget.peak == null
          ? null
          : LatLng(widget.peak!.latitude, widget.peak!.longitude),
    );
    _closeDialogAndGoMap();
  }

  void _closeDialogAndGoMap() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.go('/map');
    });
  }

  Future<void> _showFailure(String message) {
    return showSingleActionDialog(
      context: context,
      title: 'Peak List Update Failed',
      closeKey: 'peak-list-peak-failure-close',
      content: Text(message),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  static const double _labelColumnWidth = 72;

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: _labelColumnWidth,
            child: Text('$label:', textAlign: TextAlign.end),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                child: value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsSelector extends StatelessWidget {
  const _PointsSelector({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final int value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: const Key('peak-list-peak-points'),
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Points',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final entry in values)
          DropdownMenuItem<int>(value: entry, child: Text(entry.toString())),
      ],
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }
}

class _PeakHistoryHeader extends StatelessWidget {
  const _PeakHistoryHeader({required this.textStyle});

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text('Date', style: textStyle)),
          const SizedBox(width: 12),
          Expanded(child: Text('GPX', style: textStyle)),
        ],
      ),
    );
  }
}

String _formatHistoryDate(DateTime date) {
  const weekdays = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };
  const months = <int, String>{
    1: 'Jan',
    2: 'Feb',
    3: 'Mar',
    4: 'Apr',
    5: 'May',
    6: 'Jun',
    7: 'Jul',
    8: 'Aug',
    9: 'Sep',
    10: 'Oct',
    11: 'Nov',
    12: 'Dec',
  };

  final localDate = date.toLocal();
  return '${weekdays[localDate.weekday]}, ${months[localDate.month]} ${localDate.day} ${localDate.year}';
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({required this.row, required this.onTrackSelected});

  final PeaksBagged row;
  final ValueChanged<PeaksBagged> onTrackSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    GpxTrack? track;
    try {
      final trackRepository = ref.read(gpxTrackRepositoryProvider);
      track = row.gpxId <= 0 ? null : trackRepository.findById(row.gpxId);
    } catch (_) {
      track = null;
    }
    final dateLabel = row.date == null ? '' : _formatHistoryDate(row.date!);
    final label = track == null
        ? (row.gpxId <= 0 ? '' : 'Track #${row.gpxId}')
        : track.trackName.trim().isEmpty
        ? 'Track #${track.gpxTrackId}'
        : track.trackName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(dateLabel)),
          const SizedBox(width: 12),
          Expanded(
            child: row.gpxId <= 0
                ? const SizedBox.shrink()
                : TextButton(
                    key: Key('peak-list-peak-track-${row.gpxId}'),
                    onPressed: () => onTrackSelected(row),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
