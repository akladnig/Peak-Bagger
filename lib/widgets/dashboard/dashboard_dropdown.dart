import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dashboard_card_keyboard.dart';

class DashboardDropdownChoice<T> {
  const DashboardDropdownChoice({
    required this.value,
    required this.label,
    required this.key,
    this.icon,
  });

  final T value;
  final String label;
  final Key key;
  final IconData? icon;
}

/// Existing Material menus with temporary, card-scoped keyboard ownership.
class DashboardDropdown<T> extends StatefulWidget {
  const DashboardDropdown({
    super.key,
    required this.selected,
    required this.choices,
    required this.shortcut,
    required this.onOpen,
    required this.onSelected,
    required this.buttonBuilder,
    this.alignment = AlignmentDirectional.bottomStart,
    this.minimumWidth = 0,
  });

  final T selected;
  final List<DashboardDropdownChoice<T>> choices;
  final LogicalKeyboardKey shortcut;
  final VoidCallback onOpen;
  final ValueChanged<T> onSelected;
  final Widget Function(FocusNode focusNode, VoidCallback toggle) buttonBuilder;
  final AlignmentGeometry alignment;
  final double minimumWidth;

  @override
  State<DashboardDropdown<T>> createState() => _DashboardDropdownState<T>();
}

class _DashboardDropdownState<T> extends State<DashboardDropdown<T>> {
  final _menu = MenuController();
  final _buttonFocus = FocusNode();
  late final List<FocusNode> _items = [
    for (final choice in widget.choices) FocusNode(debugLabel: choice.label),
  ];
  DashboardCardKeyboardController? _card;
  bool _changed = false;
  bool _keyboardOpened = false;
  bool? _continueForward;
  int _revision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final card = DashboardCardKeyboard.maybeOf(context);
    if (_card != card) {
      _unregister();
      _card = card;
      _card?.actions[widget.shortcut] = _openForKeyboard;
    }
  }

  void _unregister() {
    if (_card?.actions[widget.shortcut] == _openForKeyboard) {
      _card?.actions.remove(widget.shortcut);
    }
  }

  void _openForKeyboard() => _open(keyboard: true);

  void _releaseMenu() {
    if (_card?.menuOwner == this) _card?.menuOwner = null;
  }

  void _open({bool keyboard = false}) {
    if (!mounted || _menu.isOpen || _card?.isActive() == false) return;
    widget.onOpen();
    _changed = false;
    _keyboardOpened = keyboard;
    _continueForward = null;
    _card?.menuOwner = this;
    _menu.open();
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision || !_menu.isOpen) return;
      final selected = widget.choices.indexWhere(
        (c) => c.value == widget.selected,
      );
      _items[selected < 0 ? 0 : selected].requestFocus();
    });
  }

  void _closed() {
    final revision = ++_revision;
    final card = _card;
    final forward = _continueForward;
    final changed = _changed;
    final keyboardOpened = _keyboardOpened;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      if (card != null && card.menuOwner != this) return;
      _releaseMenu();
      if (card == null || !card.isActive()) return;
      if (forward != null) {
        card.traverse(forward);
      } else if (keyboardOpened) {
        card.focus(
          changed
              ? DashboardCardFocusReason.menuChanged
              : DashboardCardFocusReason.menuReturn,
        );
      }
    });
  }

  void _select(int index) {
    if (!mounted || !_menu.isOpen) return;
    final value = widget.choices[index].value;
    _changed = value != widget.selected;
    widget.onSelected(value);
    _menu.close();
  }

  KeyEventResult _menuKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (dashboardHasCommandModifier || dashboardIsEditing) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      _continueForward = !HardwareKeyboard.instance.isShiftPressed;
      _menu.close();
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyJ) {
      _items[(index + 1) % _items.length].requestFocus();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyK) {
      _items[(index - 1) % _items.length].requestFocus();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _select(index);
    } else if (key == LogicalKeyboardKey.escape) {
      _menu.close();
    } else {
      // Do not bubble card/page letters from the temporary menu scope.
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _revision++;
    _unregister();
    _releaseMenu();
    _buttonFocus.dispose();
    for (final node in _items) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    controller: _menu,
    childFocusNode: _buttonFocus,
    onClose: _closed,
    style: MenuStyle(
      alignment: widget.alignment,
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),
    menuChildren: [
      for (var i = 0; i < widget.choices.length; i++)
        Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) => _menuKey(i, event),
          child: MenuItemButton(
            key: widget.choices[i].key,
            focusNode: _items[i],
            autofocus: widget.choices[i].value == widget.selected,
            closeOnActivate: false,
            leadingIcon: widget.choices[i].icon == null
                ? null
                : Icon(widget.choices[i].icon),
            trailingIcon: widget.choices[i].value == widget.selected
                ? const Icon(Icons.check)
                : null,
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(
                Size(widget.minimumWidth, 36),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
              mouseCursor: const WidgetStatePropertyAll(
                SystemMouseCursors.click,
              ),
            ),
            onPressed: () => _select(i),
            child: Semantics(
              selected: widget.choices[i].value == widget.selected,
              child: Text(widget.choices[i].label),
            ),
          ),
        ),
    ],
    builder: (context, controller, child) => widget.buttonBuilder(
      _buttonFocus,
      () => controller.isOpen ? controller.close() : _open(),
    ),
  );
}
