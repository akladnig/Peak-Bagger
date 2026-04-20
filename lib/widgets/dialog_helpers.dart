import 'package:flutter/material.dart';

Future<bool?> showDangerConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String cancelKey,
  required String cancelLabel,
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
