import 'package:flutter/material.dart';

/// One wrapping, theme-inheriting Cancel / Save boundary for Admin drafts.
class ObjectBoxAdminEditFooter extends StatelessWidget {
  const ObjectBoxAdminEditFooter({
    required this.prefix,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
    this.locked = false,
    this.saveSuffix = 'save',
    super.key,
  });

  final String prefix;
  final bool isSaving;
  final bool locked;
  final String saveSuffix;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: 12,
    runSpacing: 8,
    children: [
      FilledButton(
        key: Key('objectbox-admin-$prefix-cancel'),
        onPressed: isSaving ? null : onCancel,
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: Key('objectbox-admin-$prefix-$saveSuffix'),
        onPressed: isSaving || locked ? null : onSave,
        child: Text(isSaving ? 'Saving...' : 'Save'),
      ),
    ],
  );
}
