import 'package:flutter/material.dart';

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
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
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
  var isNewVersionHovered = false;
  final action = await showDialog<ExportConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final newVersionButton = isNewVersionHovered
              ? FilledButton(
                  key: Key(newVersionKey),
                  onPressed: () => Navigator.of(dialogContext).pop(
                    ExportConflictAction.newVersion,
                  ),
                  child: const Text('New Version'),
                )
              : OutlinedButton(
                  key: Key(newVersionKey),
                  onPressed: () => Navigator.of(dialogContext).pop(
                    ExportConflictAction.newVersion,
                  ),
                  child: const Text('New Version'),
                );
          final overwriteButton = isNewVersionHovered
              ? OutlinedButton(
                  key: Key(overwriteKey),
                  onPressed: () => Navigator.of(dialogContext).pop(
                    ExportConflictAction.overwrite,
                  ),
                  child: const Text('Overwrite'),
                )
              : FilledButton(
                  key: Key(overwriteKey),
                  onPressed: () => Navigator.of(dialogContext).pop(
                    ExportConflictAction.overwrite,
                  ),
                  child: const Text('Overwrite'),
                );

          return AlertDialog(
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
              MouseRegion(
                onEnter: (_) => setState(() {
                  isNewVersionHovered = true;
                }),
                onExit: (_) => setState(() {
                  isNewVersionHovered = false;
                }),
                child: newVersionButton,
              ),
              overwriteButton,
            ],
          );
        },
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
      return AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          FilledButton(
            key: Key(closeKey),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
