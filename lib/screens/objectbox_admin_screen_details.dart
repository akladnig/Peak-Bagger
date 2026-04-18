import 'package:flutter/material.dart';

import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminDetailsPane extends StatelessWidget {
  const ObjectBoxAdminDetailsPane({
    required this.row,
    required this.entity,
    required this.onClose,
    super.key,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row == null
                        ? 'Details'
                        : '${entity.displayName} #${objectBoxAdminFormatValue(row!.primaryKeyValue)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  onPressed: row == null ? null : onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            if (row == null)
              const Expanded(
                child: Center(
                  child: Text('Select a row to inspect full values.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  key: const Key('objectbox-admin-details-list'),
                  itemCount: entity.fields.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final field = entity.fields[index];
                    final selectedRow = row!;
                    return ListTile(
                      dense: true,
                      title: Text(field.name),
                      subtitle: SelectableText(
                        objectBoxAdminFormatValue(
                          selectedRow.values[field.name],
                        ),
                      ),
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
