import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/peak_list.dart';
import '../providers/peak_provider.dart';
import '../services/peak_list_file_picker.dart';
import '../services/peak_list_import_service.dart';
import '../services/peak_list_repository.dart';
import '../widgets/peak_list_import_dialog.dart';

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  throw UnimplementedError('peakListRepositoryProvider must be overridden');
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

  @override
  Widget build(BuildContext context) {
    final filePicker = ref.watch(peakListFilePickerProvider);
    final importRunner = ref.watch(peakListImportRunnerProvider);
    final duplicateNameChecker = ref.watch(
      peakListDuplicateNameCheckerProvider,
    );
    final repository = ref.watch(peakListRepositoryProvider);
    final peakLists = repository.getAllPeakLists();
    final selectedPeakList = _resolveSelectedPeakList(peakLists, repository);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final summaryPane = _SummaryPane(
            peakLists: peakLists,
            selectedPeakListId: selectedPeakList?.peakListId,
            onSelected: (peakListId) {
              setState(() {
                _selectedPeakListId = peakListId;
              });
            },
          );
          final detailsPane = _DetailsPane(selectedPeakList: selectedPeakList);

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
          final clampedFraction = _summaryFraction.clamp(minFraction, maxFraction);
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
              : repository.findById(result.peakListId!);
          final selected = imported ??
              (result.listName == null
                  ? null
                  : repository.findByName(result.listName!));
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

  PeakList? _resolveSelectedPeakList(
    List<PeakList> peakLists,
    PeakListRepository repository,
  ) {
    if (peakLists.isEmpty) {
      return null;
    }

    final selected = _selectedPeakListId == null
        ? null
        : repository.findById(_selectedPeakListId!);
    if (selected != null) {
      return selected;
    }

    return peakLists.first;
  }
}

class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.peakLists,
    required this.selectedPeakListId,
    required this.onSelected,
  });

  final List<PeakList> peakLists;
  final int? selectedPeakListId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Peak Lists', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _SummaryHeader(),
          if (peakLists.isEmpty) ...[
            const SizedBox(height: 24),
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
                itemCount: peakLists.length,
                itemBuilder: (context, index) {
                  final peakList = peakLists[index];
                  return Card(
                    child: ListTile(
                      key: Key('peak-lists-row-${peakList.peakListId}'),
                      selected: peakList.peakListId == selectedPeakListId,
                      title: Text(peakList.name),
                      onTap: () => onSelected(peakList.peakListId),
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
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      children: [
        Expanded(child: Text('List', style: style)),
        Expanded(child: Text('Total Peaks', style: style)),
        Expanded(child: Text('Climbed', style: style)),
        Expanded(child: Text('Percentage', style: style)),
        Expanded(child: Text('Unclimbed', style: style)),
        SizedBox(width: 48, child: Text('Actions', style: style)),
      ],
    );
  }
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.selectedPeakList});

  final PeakList? selectedPeakList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectedPeakList?.name ?? 'Peak List Details',
            key: const Key('peak-lists-selected-title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (selectedPeakList == null)
            const Expanded(
              child: Card(
                child: Center(
                  child: Text('No peak lists exist. Import a CSV to get started.'),
                ),
              ),
            )
          else
            const Expanded(
              child: Card(
                child: Center(child: Text('Select a peak list to inspect.')),
              ),
            ),
        ],
      ),
    );
  }
}
