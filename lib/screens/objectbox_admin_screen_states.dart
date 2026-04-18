import 'package:flutter/material.dart';

import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminLoadingState extends StatelessWidget {
  const ObjectBoxAdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class ObjectBoxAdminErrorState extends StatelessWidget {
  const ObjectBoxAdminErrorState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
      ),
    );
  }
}

class ObjectBoxAdminEmptyState extends StatelessWidget {
  const ObjectBoxAdminEmptyState({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}

class ObjectBoxAdminSchemaView extends StatelessWidget {
  const ObjectBoxAdminSchemaView({required this.entity, super.key});

  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entity.fields.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ObjectBoxAdminSchemaHeader(entity: entity);
        }

        final field = entity.fields[index - 1];
        return ListTile(
          dense: true,
          title: Text(field.name),
          subtitle: Text(field.typeLabel),
          trailing: Text(
            [
              if (field.isPrimaryKey) 'PK',
              if (field.isPrimaryName) 'Name',
              if (field.nullable) 'Nullable',
            ].join(' · '),
          ),
        );
      },
    );
  }
}

class ObjectBoxAdminSchemaHeader extends StatelessWidget {
  const ObjectBoxAdminSchemaHeader({required this.entity, super.key});

  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${entity.displayName} schema',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
