import 'package:flutter/material.dart';

import '../constants.dart';
import 'popup_keyboard_dismiss.dart';

class PopupShell extends StatelessWidget {
  const PopupShell({
    required this.title,
    required this.body,
    required this.onClose,
    this.leading,
    this.footer,
    this.closeTooltip = 'Close',
    this.closeButtonKey,
    super.key,
  });

  final Widget title;
  final Widget body;
  final VoidCallback onClose;
  final Widget? leading;
  final Widget? footer;
  final String closeTooltip;
  final Key? closeButtonKey;

  @override
  Widget build(BuildContext context) {
    final shell = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PopupUIConstants.surfaceRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            key: const Key('popup-shell-header-padding'),
            padding: const EdgeInsets.all(PopupUIConstants.surfacePadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: PopupUIConstants.headerSpacing),
                ],
                Flexible(child: title),
                const SizedBox(width: PopupUIConstants.headerSpacing),
                IconButton(
                  key: closeButtonKey ?? const Key('popup-shell-close'),
                  onPressed: onClose,
                  tooltip: closeTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close,
                    size: PopupUIConstants.closeIconSize,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            key: const Key('popup-shell-body-padding'),
            padding: const EdgeInsets.fromLTRB(
              PopupUIConstants.surfacePadding,
              0,
              PopupUIConstants.surfacePadding,
              PopupUIConstants.surfacePadding,
            ),
            child: body,
          ),
          if (footer != null)
            Padding(
              key: const Key('popup-shell-footer-padding'),
              padding: const EdgeInsets.fromLTRB(
                PopupUIConstants.surfacePadding,
                0,
                PopupUIConstants.surfacePadding,
                PopupUIConstants.surfacePadding,
              ),
              child: footer,
            ),
        ],
      ),
    );

    return PopupKeyboardDismiss(onDismiss: onClose, child: shell);
  }
}
