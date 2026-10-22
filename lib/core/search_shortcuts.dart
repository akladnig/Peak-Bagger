import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool isFindShortcut(KeyEvent event) =>
    event is KeyDownEvent &&
    event.logicalKey == LogicalKeyboardKey.keyF &&
    HardwareKeyboard.instance.isMetaPressed &&
    !HardwareKeyboard.instance.isControlPressed &&
    !HardwareKeyboard.instance.isAltPressed &&
    !HardwareKeyboard.instance.isShiftPressed;

/// A shared shell may own focus outside the active branch Navigator. That is
/// not an obscuring surface. Check the route hierarchy instead of comparing
/// the focused control's route with the field's route.
///
/// Inspect parent Navigators too: a root dialog can obscure a branch whose own
/// route still reports isCurrent, including dialogs that don't request focus.
bool isSearchSurfaceActive(
  BuildContext context, {
  bool allowLocalHistory = false,
}) {
  if (!context.mounted || !TickerMode.valuesOf(context).enabled) return false;
  bool permitsSearch(ModalRoute<dynamic>? route) =>
      route == null ||
      (route.isCurrent &&
          (allowLocalHistory || !route.willHandlePopInternally));
  if (!permitsSearch(ModalRoute.of(context))) return false;
  var navigator = Navigator.maybeOf(context);
  while (navigator != null) {
    final parentContext = navigator.context;
    if (!permitsSearch(ModalRoute.of(parentContext))) return false;
    navigator = parentContext.findAncestorStateOfType<NavigatorState>();
  }
  return true;
}
