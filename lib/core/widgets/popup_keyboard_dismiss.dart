import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PopupKeyboardDismiss extends StatelessWidget {
  const PopupKeyboardDismiss({
    required this.child,
    required this.onDismiss,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback onDismiss;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: enabled,
      onKeyEvent: enabled ? _handleKeyEvent : null,
      child: child,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isCtrlC =
        key == LogicalKeyboardKey.keyC &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed;
    if (key == LogicalKeyboardKey.escape || isCtrlC) {
      onDismiss();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
