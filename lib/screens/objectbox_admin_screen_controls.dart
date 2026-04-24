import 'package:flutter/material.dart';

import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminControls extends StatelessWidget {
  const ObjectBoxAdminControls({
    required this.state,
    required this.searchController,
    required this.onEntityChanged,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchPressed,
    required this.onAddPeakPressed,
    required this.onSortPressed,
    required this.onExportPressed,
    super.key,
  });

  final ObjectBoxAdminState state;
  final TextEditingController searchController;
  final ValueChanged<ObjectBoxAdminEntityDescriptor?> onEntityChanged;
  final ValueChanged<ObjectBoxAdminViewMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchPressed;
  final VoidCallback onAddPeakPressed;
  final VoidCallback onSortPressed;
  final Future<void> Function()? onExportPressed;

  @override
  Widget build(BuildContext context) {
    final entity = state.selectedEntity;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<ObjectBoxAdminEntityDescriptor>(
            key: const Key('objectbox-admin-entity-dropdown'),
            initialValue: entity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Entity',
              border: OutlineInputBorder(),
            ),
            items: state.entities
                .map(
                  (descriptor) => DropdownMenuItem(
                    value: descriptor,
                    child: Text(descriptor.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: onEntityChanged,
          ),
        ),
        ToggleButtons(
          key: const Key('objectbox-admin-schema-data-toggle'),
          isSelected: [
            state.mode == ObjectBoxAdminViewMode.schema,
            state.mode == ObjectBoxAdminViewMode.data,
          ],
          onPressed: (index) {
            onModeChanged(
              index == 0
                  ? ObjectBoxAdminViewMode.schema
                  : ObjectBoxAdminViewMode.data,
            );
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Schema'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Data'),
            ),
          ],
        ),
        if (state.mode == ObjectBoxAdminViewMode.data)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: onSearchPressed,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onChanged: onSearchChanged,
                  onSubmitted: (_) => onSearchSubmitted(),
                ),
              ),
              if (entity?.name == 'Peak')
                FilledButton.icon(
                  key: const Key('objectbox-admin-peak-add'),
                  onPressed: onAddPeakPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Peak'),
                ),
              if (entity?.name == 'GpxTrack')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      key: const Key('objectbox-admin-export-gpx'),
                      onPressed: onExportPressed == null
                          ? null
                          : () => onExportPressed!(),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Export GPX'),
                    ),
                    if (state.selectedRow == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Text(
                          'No gpxFile selected',
                          key: const Key('objectbox-admin-export-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
