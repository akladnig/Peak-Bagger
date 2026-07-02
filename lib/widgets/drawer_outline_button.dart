import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../theme.dart';

double drawerWidthForLabels(
  BuildContext context,
  Iterable<String> labels, {
  bool includeIcon = true,
  double trailingWidth = 0.0,
}) {
  final textStyle =
      Theme.of(context).textTheme.labelLarge?.copyWith(
        fontSize: UiConstants.drawerControlFontSize,
      ) ??
      const TextStyle(fontSize: UiConstants.drawerControlFontSize);
  final textPainter = TextPainter(
    textDirection: Directionality.of(context),
    maxLines: 1,
  );

  var widestLabel = 0.0;
  for (final label in labels) {
    textPainter.text = TextSpan(text: label, style: textStyle);
    textPainter.layout();
    widestLabel = math.max(widestLabel, textPainter.width);
  }

  final iconWidth = includeIcon
      ? searchControlIconSize + UiConstants.drawerButtonIconGap
      : 0.0;
  final buttonWidth =
      widestLabel +
      iconWidth +
      trailingWidth +
      (UiConstants.drawerButtonHorizontalPadding * 2) +
      UiConstants.drawerWidthSlack;
  final drawerWidth = buttonWidth + (UiConstants.drawerHorizontalPadding * 2);

  return drawerWidth.clamp(
    UiConstants.drawerMinWidth,
    UiConstants.drawerMaxWidth,
  );
}

class DrawerOutlineButton extends StatelessWidget {
  const DrawerOutlineButton({
    required this.buttonKey,
    required this.label,
    required this.isSelected,
    super.key,
    this.icon,
    this.trailing,
    this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool isSelected;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final searchButtonTheme = Theme.of(
      context,
    ).extension<SearchButtonThemeData>();
    final style = searchButtonTheme
        ?.styleFor(isSelected)
        .merge(OutlinedButton.styleFrom(alignment: Alignment.centerLeft));

    final button = Semantics(
      button: true,
      selected: isSelected,
      child: icon == null
          ? OutlinedButton(
              key: buttonKey,
              style: style,
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: UiConstants.drawerControlFontSize,
                ),
              ),
            )
          : OutlinedButton.icon(
              key: buttonKey,
              style: style,
              onPressed: onPressed,
              icon: Icon(icon, size: searchControlIconSize),
              label: Text(
                label,
                style: const TextStyle(
                  fontSize: UiConstants.drawerControlFontSize,
                ),
              ),
            ),
    );

    if (trailing == null) {
      return SizedBox(width: double.infinity, child: button);
    }

    return SizedBox(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          SizedBox(
            width: double.infinity,
            child: icon == null
                ? OutlinedButton(
                    key: buttonKey,
                    style: style,
                    onPressed: onPressed,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: searchControlIconSize + 20,
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: UiConstants.drawerControlFontSize,
                        ),
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    key: buttonKey,
                    style: style,
                    onPressed: onPressed,
                    icon: Icon(icon, size: searchControlIconSize),
                    label: Padding(
                      padding: const EdgeInsets.only(
                        right: searchControlIconSize + 20,
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: UiConstants.drawerControlFontSize,
                        ),
                      ),
                    ),
                  ),
          ),
          Positioned(right: 8, child: trailing!),
        ],
      ),
    );
  }
}
