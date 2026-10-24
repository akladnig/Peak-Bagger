import 'package:flutter/material.dart';

import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';

class ObjectBoxAdminLoadingState extends StatelessWidget {
  const ObjectBoxAdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class ObjectBoxAdminErrorState extends StatelessWidget {
  const ObjectBoxAdminErrorState({
    required this.message,
    this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
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

class ObjectBoxAdminSchemaView extends StatefulWidget {
  const ObjectBoxAdminSchemaView({required this.entity, super.key});

  final ObjectBoxAdminEntityDescriptor entity;

  @override
  State<ObjectBoxAdminSchemaView> createState() =>
      _ObjectBoxAdminSchemaViewState();
}

class _ObjectBoxAdminSchemaViewState extends State<ObjectBoxAdminSchemaView> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(ObjectBoxAdminSchemaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity.name != widget.entity.name &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = theme.extension<DataGridTheme>()!;
    return Column(
      key: const Key('objectbox-admin-schema-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectBoxAdminSchemaHeader(entity: widget.entity),
        const _SchemaRow(values: ['Field', 'Type', 'Attributes'], header: true),
        Divider(
          height: grid.dividerThickness,
          thickness: grid.dividerThickness,
          color: grid.dividerColor,
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _scrollController,
              itemCount: widget.entity.fields.length,
              separatorBuilder: (context, index) => Divider(
                height: grid.dividerThickness,
                thickness: grid.dividerThickness,
                color: grid.dividerColor,
              ),
              itemBuilder: (context, index) {
                final field = widget.entity.fields[index];
                return _SchemaRow(
                  key: ValueKey(
                    'objectbox-admin-schema-${widget.entity.name}-${field.name}',
                  ),
                  values: [
                    field.name,
                    field.typeLabel,
                    field.attributes.join(' · '),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SchemaRow extends StatelessWidget {
  const _SchemaRow({required this.values, this.header = false, super.key});

  final List<String> values;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = theme.extension<DataGridTheme>()!;
    final rowPadding = grid.rowPadding.resolve(Directionality.of(context));
    final headerPadding = grid.headerPadding.resolve(
      Directionality.of(context),
    );
    final style = (header ? grid.headerTextStyle : grid.rowTextStyle).copyWith(
      color: theme.colorScheme.onSurface,
    );
    return Padding(
      padding: header
          ? EdgeInsets.fromLTRB(
              rowPadding.left,
              headerPadding.top,
              rowPadding.right,
              headerPadding.bottom,
            )
          : rowPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: grid.columnGap,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              flex: const [3, 2, 5][index],
              child: header
                  ? Semantics(
                      header: true,
                      child: Text(values[index], style: style),
                    )
                  : SelectableText(values[index], style: style),
            ),
        ],
      ),
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
