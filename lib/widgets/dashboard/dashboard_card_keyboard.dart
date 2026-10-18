import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transient focus ownership, separate from Riverpod's calendar/domain state.
/// Menu returns are explicit so inspection need not treat them as initial entry.
enum DashboardCardFocusReason { entry, menuReturn, menuChanged }

class DashboardCardKeyboardController {
  DashboardCardKeyboardController({
    required String title,
    required this.traverse,
  }) : focusNode = FocusNode(debugLabel: 'Dashboard card: $title');

  final FocusNode focusNode;
  final ValueChanged<bool> traverse;
  final focusEvents = ValueNotifier<(int, DashboardCardFocusReason)>((
    0,
    DashboardCardFocusReason.entry,
  ));
  final Map<LogicalKeyboardKey, VoidCallback> actions = {};
  Object? menuOwner;
  bool get menuOwnsFocus => menuOwner != null;
  bool Function() isActive = () => false;
  bool _disposed = false;

  void focus([
    DashboardCardFocusReason reason = DashboardCardFocusReason.entry,
  ]) {
    if (_disposed || !isActive()) return;
    focusNode.requestFocus();
    focusEvents.value = (focusEvents.value.$1 + 1, reason);
  }

  void dispose() {
    _disposed = true;
    actions.clear();
    focusEvents.dispose();
    focusNode.dispose();
  }
}

class DashboardCardKeyboard extends InheritedWidget {
  const DashboardCardKeyboard({
    super.key,
    required this.controller,
    required super.child,
  });

  final DashboardCardKeyboardController controller;

  static DashboardCardKeyboardController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DashboardCardKeyboard>()
          ?.controller;

  @override
  bool updateShouldNotify(DashboardCardKeyboard oldWidget) =>
      controller != oldWidget.controller;
}

bool get dashboardHasCommandModifier =>
    HardwareKeyboard.instance.isMetaPressed ||
    HardwareKeyboard.instance.isControlPressed ||
    HardwareKeyboard.instance.isAltPressed;

bool get dashboardIsEditing =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;
