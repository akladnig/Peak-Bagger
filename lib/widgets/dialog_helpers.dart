import 'package:flutter/material.dart';
import 'package:peak_bagger/core/widgets/popup_keyboard_dismiss.dart';

enum ExportConflictAction { cancel, overwrite, newVersion }

Future<bool?> showDangerConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelKey,
  String cancelLabel = "Cancel",
  required String confirmKey,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopupKeyboardDismiss(
        onDismiss: () => Navigator.of(dialogContext).pop(false),
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            FilledButton(
              key: Key(cancelKey),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              key: Key(confirmKey),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    },
  );
}

Future<ExportConflictAction> showExportConflictDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelKey,
  required String overwriteKey,
  required String newVersionKey,
}) async {
  final action = await showDialog<ExportConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopupKeyboardDismiss(
        onDismiss: () => Navigator.of(dialogContext).pop(
          ExportConflictAction.cancel,
        ),
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              key: Key(cancelKey),
              onPressed: () => Navigator.of(dialogContext).pop(
                ExportConflictAction.cancel,
              ),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              key: Key(newVersionKey),
              onPressed: () => Navigator.of(dialogContext).pop(
                ExportConflictAction.newVersion,
              ),
              child: const Text('New Version'),
            ),
            FilledButton(
              key: Key(overwriteKey),
              onPressed: () => Navigator.of(dialogContext).pop(
                ExportConflictAction.overwrite,
              ),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
    },
  );
  return action ?? ExportConflictAction.cancel;
}

Future<void> showSingleActionDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  required String closeKey,
}) {
  return showDialog<void>(
    useRootNavigator: true,
    context: context,
    builder: (dialogContext) {
      return PopupKeyboardDismiss(
        onDismiss: () => Navigator.of(dialogContext).pop(),
        child: AlertDialog(
          title: Text(title),
          content: content,
          actions: [
            FilledButton(
              key: Key(closeKey),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}
