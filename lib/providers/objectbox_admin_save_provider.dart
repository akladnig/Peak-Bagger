import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-visible lifetime of an Admin Save, including preparation and feedback.
/// It outlives the pane when a successful refresh replaces that pane.
final objectboxAdminSaveProvider = NotifierProvider<ObjectBoxAdminSave, bool>(
  ObjectBoxAdminSave.new,
);

class ObjectBoxAdminSave extends Notifier<bool> {
  @override
  bool build() => false;

  Future<String?> run(Future<String?> Function() save) async {
    if (state) return 'A Save is already in progress.';
    state = true;
    try {
      return await save();
    } finally {
      if (ref.mounted) state = false;
    }
  }
}
