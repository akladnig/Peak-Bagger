import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';
import 'package:peak_bagger/widgets/objectbox_admin_save_scope.dart';

import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminControls extends StatelessWidget {
  const ObjectBoxAdminControls({
    required this.state,
    required this.searchController,
    this.searchFocusNode,
    required this.onEntityChanged,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onAddPeakPressed,
    required this.onAddContactPressed,
    required this.onSortPressed,
    required this.onExportPressed,
    this.locked = false,
    super.key,
  });

  final ObjectBoxAdminState state;
  final bool locked;
  final TextEditingController searchController;
  final FocusNode? searchFocusNode;
  final ValueChanged<ObjectBoxAdminEntityDescriptor?> onEntityChanged;
  final ValueChanged<ObjectBoxAdminViewMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onAddPeakPressed;
  final VoidCallback onAddContactPressed;
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
        SharedDropdown<ObjectBoxAdminEntityDescriptor?>(
          key: const Key('objectbox-admin-entity-dropdown'),
          value: entity,
          hasSelection: entity != null,
          label: 'Entity',
          enabled: !locked,
          isInteractionAllowed: () => !ObjectBoxAdminSaveScope.read(context),
          choices: state.entities
              .map(
                (descriptor) =>
                    SharedDropdownChoice<ObjectBoxAdminEntityDescriptor?>(
                      value: descriptor,
                      label: descriptor.displayName,
                    ),
              )
              .toList(growable: false),
          onSelected: onEntityChanged,
        ),
        ToggleButtons(
          key: const Key('objectbox-admin-schema-data-toggle'),
          isSelected: [
            state.mode == ObjectBoxAdminViewMode.schema,
            state.mode == ObjectBoxAdminViewMode.data,
          ],
          onPressed: locked
              ? null
              : (index) {
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
                child: Semantics(
                  label: 'Search ObjectBox Admin records',
                  child: TextField(
                    key: const Key('objectbox-admin-search-field'),
                    controller: searchController,
                    focusNode: searchFocusNode,
                    enabled:
                        !locked && state.schemaError == null && entity != null,
                    decoration: const InputDecoration(
                      labelText: 'Search ⌘F',
                      prefixIcon: ExcludeSemantics(
                        child: Icon(Icons.search, size: searchControlIconSize),
                      ),
                    ),
                    onChanged: onSearchChanged,
                    onSubmitted: (_) => onSearchSubmitted(),
                  ),
                ),
              ),
              if (entity?.name == 'Peak')
                FilledButton.icon(
                  key: const Key('objectbox-admin-peak-add'),
                  onPressed: locked ? null : onAddPeakPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Peak'),
                ),
              if (entity?.name == 'Contact')
                FilledButton.icon(
                  key: const Key('objectbox-admin-contact-add'),
                  onPressed: locked ? null : onAddContactPressed,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
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
