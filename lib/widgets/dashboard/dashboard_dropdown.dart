import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared_dropdown.dart';
import 'dashboard_card_keyboard.dart';

/// Shared presentation with temporary, card-owned keyboard/focus coordination.
class DashboardDropdown<T> extends StatefulWidget {
  const DashboardDropdown({
    super.key,
    required this.label,
    required this.selected,
    required this.choices,
    required this.shortcut,
    required this.onOpen,
    required this.onSelected,
    this.trigger = SharedDropdownTrigger.labelledField,
    this.rows = SharedDropdownRows.labelOnly,
    this.icon,
  });

  final String label;
  final T selected;
  final List<SharedDropdownChoice<T>> choices;
  final LogicalKeyboardKey shortcut;
  final VoidCallback onOpen;
  final ValueChanged<T> onSelected;
  final SharedDropdownTrigger trigger;
  final SharedDropdownRows rows;
  final IconData? icon;

  @override
  State<DashboardDropdown<T>> createState() => _DashboardDropdownState<T>();
}

class _DashboardDropdownState<T> extends State<DashboardDropdown<T>> {
  final _menu = MenuController();
  final _buttonFocus = FocusNode();
  DashboardCardKeyboardController? _card;
  bool _changed = false;
  bool _keyboardOpened = false;
  int _revision = 0;

  bool get _allowed => mounted && (_card?.isActive() ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final card = DashboardCardKeyboard.maybeOf(context);
    if (_card != card) {
      _unregister();
      _menu.close();
      _releaseMenu();
      ++_revision;
      _card = card;
      _card?.actions[widget.shortcut] = _openForKeyboard;
    }
  }

  @override
  void didUpdateWidget(covariant DashboardDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shortcut != widget.shortcut) {
      if (_card?.actions[oldWidget.shortcut] == _openForKeyboard) {
        _card?.actions.remove(oldWidget.shortcut);
      }
      _card?.actions[widget.shortcut] = _openForKeyboard;
    }
  }

  void _unregister() {
    if (_card?.actions[widget.shortcut] == _openForKeyboard) {
      _card?.actions.remove(widget.shortcut);
    }
  }

  void _openForKeyboard() {
    if (!_allowed || _menu.isOpen) return;
    _keyboardOpened = true;
    _menu.open();
    if (!_menu.isOpen) _keyboardOpened = false;
  }

  void _opened() {
    ++_revision;
    _changed = false;
    _card?.menuOwner = this;
    widget.onOpen();
  }

  void _releaseMenu() {
    if (_card?.menuOwner == this) _card?.menuOwner = null;
  }

  void _closed(SharedDropdownCloseReason reason) {
    final revision = ++_revision;
    final card = _card;
    final keyboardOpened = _keyboardOpened;
    _keyboardOpened = false;
    // Shared presentation closes before dispatching selection. Wait for that
    // dispatch to distinguish selecting the current value from a real change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _revision) return;
      if (card != null && card.menuOwner != this) return;
      _releaseMenu();
      if (card == null ||
          !card.isActive() ||
          reason == SharedDropdownCloseReason.unavailable) {
        return;
      }
      if (reason == SharedDropdownCloseReason.tabForward ||
          reason == SharedDropdownCloseReason.tabBackward) {
        card.traverse(reason == SharedDropdownCloseReason.tabForward);
      } else if (keyboardOpened) {
        card.focus(
          _changed
              ? DashboardCardFocusReason.menuChanged
              : DashboardCardFocusReason.menuReturn,
        );
      }
    });
  }

  @override
  void dispose() {
    ++_revision;
    _unregister();
    _releaseMenu();
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SharedDropdown<T>(
    label: widget.label,
    value: widget.selected,
    choices: widget.choices,
    trigger: widget.trigger,
    rows: widget.rows,
    icon: widget.icon,
    focusNode: _buttonFocus,
    controller: _menu,
    isInteractionAllowed: () => _allowed,
    restoreFocus: _card == null,
    skipTraversal: _card != null,
    onOpened: _opened,
    onClosed: _closed,
    onSelected: (value) {
      if (!_allowed) return;
      _changed = value != widget.selected;
      if (_changed) widget.onSelected(value);
    },
  );
}
