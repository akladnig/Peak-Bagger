import 'package:flutter/material.dart';

import '../constants.dart';
import 'popup_keyboard_dismiss.dart';

class PopupShell extends StatelessWidget {
  const PopupShell({
    required this.title,
    required this.body,
    this.onClose,
    this.leading,
    this.headerActions = const [],
    this.footer,
    this.closeTooltip = 'Close',
    this.closeButtonKey,
    this.headerPadding = const EdgeInsets.all(PopupUIConstants.surfacePadding),
    this.bodyPadding = const EdgeInsets.fromLTRB(
      PopupUIConstants.surfacePadding,
      0,
      PopupUIConstants.surfacePadding,
      PopupUIConstants.surfacePadding,
    ),
    this.footerPadding = const EdgeInsets.fromLTRB(
      PopupUIConstants.surfacePadding,
      0,
      PopupUIConstants.surfacePadding,
      PopupUIConstants.surfacePadding,
    ),
    this.headerMeasureKey,
    this.headerPaddingKey,
    this.bodyPaddingKey,
    this.footerMeasureKey,
    this.footerPaddingKey,
    this.bodyFlexible = false,
    super.key,
  });

  final Widget title;
  final Widget body;
  final VoidCallback? onClose;
  final Widget? leading;
  final List<Widget> headerActions;
  final Widget? footer;
  final String closeTooltip;
  final Key? closeButtonKey;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry footerPadding;
  final Key? headerMeasureKey;
  final Key? headerPaddingKey;
  final Key? bodyPaddingKey;
  final Key? footerMeasureKey;
  final Key? footerPaddingKey;
  final bool bodyFlexible;

  @override
  Widget build(BuildContext context) {
    final bodySection = Padding(
      key: bodyPaddingKey ?? const Key('popup-shell-body-padding'),
      padding: bodyPadding,
      child: body,
    );
    final trailingActions = Row(
      key: const Key('popup-shell-trailing-actions'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in headerActions) ...[
          action,
          const SizedBox(width: PopupUIConstants.headerSpacing),
        ],
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
    );
    final headerSection = Padding(
      key: headerPaddingKey ?? const Key('popup-shell-header-padding'),
      padding: headerPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth.isFinite) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: PopupUIConstants.headerSpacing),
                ],
                Expanded(child: title),
                const SizedBox(width: PopupUIConstants.headerSpacing),
                trailingActions,
              ],
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: PopupUIConstants.headerSpacing),
              ],
              Flexible(child: title),
              const SizedBox(width: PopupUIConstants.headerSpacing),
              trailingActions,
            ],
          );
        },
      ),
    );

    final footerSection = footer == null
        ? null
        : Padding(
            key: footerPaddingKey ?? const Key('popup-shell-footer-padding'),
            padding: footerPadding,
            child: footer,
          );

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
          if (headerMeasureKey != null)
            KeyedSubtree(key: headerMeasureKey, child: headerSection)
          else
            headerSection,
          if (bodyFlexible)
            Flexible(fit: FlexFit.loose, child: bodySection)
          else
            bodySection,
          if (footerSection != null)
            if (footerMeasureKey != null)
              KeyedSubtree(key: footerMeasureKey, child: footerSection)
            else
              footerSection,
        ],
      ),
    );

    if (onClose == null) {
      return shell;
    }
    return PopupKeyboardDismiss(onDismiss: onClose!, child: shell);
  }
}
