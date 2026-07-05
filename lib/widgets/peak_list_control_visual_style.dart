import 'package:flutter/material.dart';

import '../theme.dart';

class PeakListControlVisualStyle {
  const PeakListControlVisualStyle({
    required this.buttonStyle,
    required this.iconColor,
  });

  final ButtonStyle buttonStyle;
  final Color iconColor;
}

PeakListControlVisualStyle peakListControlVisualStyle(
  BuildContext context, {
  required bool isSelected,
  int? colourValue,
  bool useNeutralStyle = false,
}) {
  final theme = Theme.of(context);
  final searchButtonTheme = theme.extension<SearchButtonThemeData>();
  final baseStyle =
      searchButtonTheme?.styleFor(isSelected) ?? const ButtonStyle();
  final baseForeground =
      baseStyle.foregroundColor?.resolve(const <WidgetState>{}) ??
      theme.colorScheme.onSurface;

  if (useNeutralStyle || colourValue == null) {
    return PeakListControlVisualStyle(
      buttonStyle: baseStyle,
      iconColor: baseForeground,
    );
  }

  final accentColor = Color(colourValue);
  if (isSelected) {
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(accentColor) == Brightness.dark
        ? Colors.white
        : outlineTextColour;
    final buttonStyle = baseStyle.copyWith(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return foregroundColor.withValues(alpha: 0.38);
        }
        return foregroundColor;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return accentColor;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(color: accentColor);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return foregroundColor.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
    return PeakListControlVisualStyle(
      buttonStyle: buttonStyle,
      iconColor: foregroundColor,
    );
  }

  final buttonStyle = baseStyle.copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return accentColor.withValues(alpha: 0.38);
      }
      return accentColor;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      return BorderSide(color: accentColor);
    }),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return accentColor.withValues(alpha: 0.12);
      }
      return null;
    }),
  );
  return PeakListControlVisualStyle(
    buttonStyle: buttonStyle,
    iconColor: accentColor,
  );
}
