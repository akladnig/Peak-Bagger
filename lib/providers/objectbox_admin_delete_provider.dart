import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/objectbox_admin_save_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

/// Only incomplete non-destructive follow-up is retained, never confirmation or
/// removal. Multiple outcomes can coexist without losing an earlier Retry.
class ObjectBoxAdminDeleteRecovery {
  ObjectBoxAdminDeleteRecovery({
    required this.label,
    required this.followUp,
    required this.refresh,
  });

  final String label;
  Future<void> Function()? followUp;
  final Future<void> Function() refresh;
}

final objectboxAdminDeleteProvider =
    NotifierProvider<ObjectBoxAdminDelete, List<ObjectBoxAdminDeleteRecovery>>(
      ObjectBoxAdminDelete.new,
    );

class ObjectBoxAdminDelete
    extends Notifier<List<ObjectBoxAdminDeleteRecovery>> {
  @override
  List<ObjectBoxAdminDeleteRecovery> build() => const [];

  Future<void> run({
    required String label,
    required Future<bool> Function() confirm,
    required Future<void> Function() remove,
    required void Function() didRemove,
    required Future<void> Function() refresh,
    required Future<void> Function(Object, StackTrace) onFailure,
    Future<void> Function()? followUp,
  }) => ref.read(objectboxAdminSaveProvider.notifier).runDelete(() async {
    try {
      if (!await confirm() || !ref.mounted) return;
      await remove();
    } catch (error, stack) {
      logObjectBoxAdminError(
        error,
        stack,
        'Admin $label deletion failed before confirmed removal',
      );
      await onFailure(error, stack);
      return;
    }
    if (!ref.mounted) return;
    didRemove();
    final recovery = ObjectBoxAdminDeleteRecovery(
      label: label,
      followUp: followUp,
      refresh: refresh,
    );
    await _finish(recovery);
  });

  Future<void> retry(ObjectBoxAdminDeleteRecovery recovery) =>
      ref.read(objectboxAdminSaveProvider.notifier).runDelete(() async {
        if (!state.contains(recovery)) return;
        await _finish(recovery);
      });

  Future<void> _finish(ObjectBoxAdminDeleteRecovery recovery) async {
    try {
      await recovery.followUp?.call();
      recovery.followUp = null; // Never repeat completed synchronisation.
      await recovery.refresh();
      if (ref.mounted) state = [...state.where((item) => item != recovery)];
    } catch (error, stack) {
      logObjectBoxAdminError(
        error,
        stack,
        '${recovery.label} deleted; follow-up incomplete',
      );
      if (ref.mounted) {
        state = [...state.where((item) => item != recovery), recovery];
      }
    }
  }
}
