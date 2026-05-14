import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_layout_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(dashboardLayoutProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(dashboardLayoutProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _resolveColumnCount(constraints.maxWidth);
              return GridView.builder(
                key: const Key('dashboard-board'),
                itemCount: order.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: dashboardCardAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final definition = dashboardCards.firstWhere(
                    (card) => card.id == order[index],
                  );
                  return _DashboardCard(
                    definition: definition,
                    onMove: (draggedId, targetId) {
                      unawaited(
                        ref
                            .read(dashboardLayoutProvider.notifier)
                            .moveCard(draggedId, targetId),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  int _resolveColumnCount(double width) {
    if (width >= dashboardDesktopWideBreakpoint) {
      return 3;
    }
    if (width >= dashboardDesktopMediumBreakpoint) {
      return 2;
    }
    return 1;
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.definition, required this.onMove});

  final DashboardCardDefinition definition;
  final void Function(String draggedId, String targetId) onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<String>(
      key: Key('dashboard-card-${definition.id}'),
      onWillAcceptWithDetails: (details) => details.data != definition.id,
      onAcceptWithDetails: (details) {
        onMove(details.data, definition.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Card(
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isHovered
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isHovered ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DashboardCardHeader(definition: definition),
              const Expanded(child: _DashboardCardBody()),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardCardHeader extends StatelessWidget {
  const _DashboardCardHeader({required this.definition});

  final DashboardCardDefinition definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        data: definition.id,
        feedback: _DashboardCardDragFeedback(definition: definition),
        childWhenDragging: const Opacity(
          opacity: 0.35,
          child: _DashboardCardHeaderBodyPlaceholder(),
        ),
        child: Container(
          key: Key('dashboard-card-${definition.id}-drag-handle'),
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  definition.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.drag_indicator),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCardBody extends StatelessWidget {
  const _DashboardCardBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Placeholder'),
    );
  }
}

class _DashboardCardDragFeedback extends StatelessWidget {
  const _DashboardCardDragFeedback({required this.definition});

  final DashboardCardDefinition definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 280,
        child: Card(
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: theme.colorScheme.primary, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        definition.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.drag_indicator),
                  ],
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCardHeaderBodyPlaceholder extends StatelessWidget {
  const _DashboardCardHeaderBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
