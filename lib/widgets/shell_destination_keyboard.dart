import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dashboard/dashboard_card_keyboard.dart';

/// Temporary destination-only focus. The caller retains card identity/reveal
/// ownership; activation delegates to the very same action as pointer input.
class ShellDestinationKeyboard extends StatefulWidget {
  const ShellDestinationKeyboard({
    required this.labels,
    required this.selectedIndex,
    required this.onActivate,
    required this.child,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onActivate;
  final Widget child;

  static ShellDestinationKeyboardState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShellKeyboardScope>()?.owner;

  @override
  State<ShellDestinationKeyboard> createState() =>
      ShellDestinationKeyboardState();
}

class ShellDestinationKeyboardState extends State<ShellDestinationKeyboard> {
  late final nodes = [
    for (final label in widget.labels)
      FocusNode(debugLabel: 'Shell destination: $label', skipTraversal: true),
  ];
  void Function(bool? forward)? _returnToCard;
  int? highlightedIndex;
  bool get temporary => _returnToCard != null;

  @override
  void initState() {
    super.initState();
    for (final node in nodes) {
      node.addListener(_focusChanged);
    }
  }

  void enter(void Function(bool? forward) returnToCard) {
    setState(() {
      _returnToCard = returnToCard;
      highlightedIndex = widget.selectedIndex;
    });
    nodes[widget.selectedIndex].requestFocus();
    final target = nodes[widget.selectedIndex].context;
    if (target != null) unawaited(Scrollable.ensureVisible(target));
  }

  void _focusChanged() {
    scheduleMicrotask(() {
      if (mounted && temporary && !nodes.any((n) => n.hasFocus)) {
        setState(_clear);
      }
    });
  }

  void _clear() {
    _returnToCard = null;
    highlightedIndex = null;
  }

  @override
  void didUpdateWidget(ShellDestinationKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _clear();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!temporary ||
        !nodes.any((n) => n.hasPrimaryFocus) ||
        dashboardHasCommandModifier ||
        dashboardIsEditing ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    if (key == LogicalKeyboardKey.tab ||
        (!shift &&
            (key == LogicalKeyboardKey.escape ||
                key == LogicalKeyboardKey.f6))) {
      final callback = _returnToCard!;
      setState(_clear);
      callback(key == LogicalKeyboardKey.tab ? !shift : null);
      return KeyEventResult.handled;
    }
    if (shift) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.enter) {
      final index = highlightedIndex!;
      final callback = _returnToCard!;
      setState(_clear);
      widget.onActivate(index);
      if (index == widget.selectedIndex) callback(null);
      return KeyEventResult.handled;
    }
    final direction =
        key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ
        ? 1
        : key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK
        ? -1
        : 0;
    if (direction != 0) {
      final index = (highlightedIndex! + direction).clamp(0, nodes.length - 1);
      setState(() => highlightedIndex = index);
      nodes[index].requestFocus();
      final target = nodes[index].context;
      if (target != null) unawaited(Scrollable.ensureVisible(target));
      return KeyEventResult.handled;
    }
    // Own interaction until the temporary scope is dismissed; card actions are
    // outside this focus subtree and must not receive the same event.
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    for (final node in nodes) {
      node.removeListener(_focusChanged);
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ShellKeyboardScope(
    owner: this,
    highlightedIndex: highlightedIndex,
    child: Focus(skipTraversal: true, onKeyEvent: _key, child: widget.child),
  );
}

class _ShellKeyboardScope extends InheritedWidget {
  const _ShellKeyboardScope({
    required this.owner,
    required this.highlightedIndex,
    required super.child,
  });
  final ShellDestinationKeyboardState owner;
  final int? highlightedIndex;
  @override
  bool updateShouldNotify(_ShellKeyboardScope oldWidget) =>
      highlightedIndex != oldWidget.highlightedIndex;
}
