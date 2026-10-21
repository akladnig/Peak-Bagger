import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-visible exclusive Admin mutation lifetime (Save, Delete and recovery),
/// including preparation, child confirmation, reconciliation and feedback.
/// The established name is retained for existing form/router consumers.
/// It outlives the pane when a successful refresh replaces that pane.
final objectboxAdminSaveProvider = NotifierProvider<ObjectBoxAdminSave, bool>(
  ObjectBoxAdminSave.new,
);

class ObjectBoxAdminSave extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> run(Future<String?> Function() save) async {
    if (state) return 'An Admin operation is already in progress.';
    state = true;
    try {
      return await save();
    } finally {
      if (ref.mounted) state = false;
    }
  }

  Future<void> runDelete(Future<void> Function() action) async {
    if (state) return;
    state = true;
    try {
      await action();
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
