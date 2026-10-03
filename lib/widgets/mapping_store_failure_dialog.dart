import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

class MappingStoreFailureDialogHost extends ConsumerWidget {
  const MappingStoreFailureDialogHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(mappingStoreOperationRevisionProvider);
    final coordinator = ref.read(mappingStoreOperationCoordinatorProvider);
    final failure = coordinator.activeFailure;
    if (failure == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        const Positioned.fill(child: ModalBarrier(dismissible: false)),
        Center(
          child: MappingStoreFailureDialog(
            failure: failure,
            coordinator: coordinator,
          ),
        ),
      ],
    );
  }
}

class MappingStoreFailureDialog extends StatelessWidget {
  const MappingStoreFailureDialog({
    required this.failure,
    required this.coordinator,
    super.key,
  });

  final MappingStoreOperationFailure failure;
  final MappingStoreOperationCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('mapping-store-failure-dialog'),
      title: const Text('Mapping data store unavailable'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              failure.key.description,
              key: const Key('mapping-store-failure-operation'),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView(
                key: const Key('mapping-store-failure-path-list'),
                shrinkWrap: true,
                children: [for (final path in failure.paths) Text(path)],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('mapping-store-failure-dismiss'),
          onPressed: coordinator.isRetrying ? null : coordinator.dismissActive,
          child: const Text('Dismiss'),
        ),
        FilledButton(
          key: const Key('mapping-store-failure-retry'),
          onPressed: coordinator.isRetrying ? null : coordinator.retryActive,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
