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

/// Binds existing card actions without giving internal controls Tab stops.
class DashboardCardActions extends StatefulWidget {
  const DashboardCardActions({
    required this.actions,
    required this.child,
    this.onEntry,
    super.key,
  });

  final Map<LogicalKeyboardKey, VoidCallback?> actions;
  final VoidCallback? onEntry;
  final Widget child;

  @override
  State<DashboardCardActions> createState() => _DashboardCardActionsState();
}

class _DashboardCardActionsState extends State<DashboardCardActions> {
  DashboardCardKeyboardController? _owner;
  final Map<LogicalKeyboardKey, VoidCallback> _bindings = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = DashboardCardKeyboard.maybeOf(context);
    if (owner == _owner) return;
    _unbind();
    _owner = owner;
    owner?.focusEvents.addListener(_onFocus);
    _bind();
  }

  @override
  void didUpdateWidget(DashboardCardActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _removeActions();
    _bind();
  }

  void _bind() {
    for (final key in widget.actions.keys) {
      void action() {
        if (mounted && _owner?.isActive() == true) widget.actions[key]?.call();
      }

      _bindings[key] = action;
      _owner?.actions[key] = action;
    }
  }

  void _onFocus() {
    if (_owner?.focusEvents.value.$2 == DashboardCardFocusReason.entry &&
        _owner?.focusNode.hasPrimaryFocus == false) {
      widget.onEntry?.call();
    }
  }

  void _removeActions() {
    for (final entry in _bindings.entries) {
      if (_owner?.actions[entry.key] == entry.value) {
        _owner?.actions.remove(entry.key);
      }
    }
    _bindings.clear();
  }

  void _unbind() {
    _removeActions();
    _owner?.focusEvents.removeListener(_onFocus);
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Presentation-only ownership. Rows use measured layout rather than assumed
/// pixel heights so keyboard reveal also works with enlarged text/year headers.
class DashboardRowRevealController {
  final scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  int _revision = 0;
  GlobalKey keyFor(int id) => _keys.putIfAbsent(id, GlobalKey.new);

  void retainIds(List<int> ids) =>
      _keys.removeWhere((id, _) => !ids.contains(id));

  void reveal(int? id) {
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (revision != _revision || !scroll.hasClients) return;
      final render = _keys[id]?.currentContext?.findRenderObject();
      if (render == null || !render.attached) return;
      // Reveal only within the card; the board owns card-level scrolling.
      scroll.position.ensureVisible(
        render,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      scroll.position.ensureVisible(
        render,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  void dispose() {
    _revision++;
    scroll.dispose();
    _keys.clear();
  }
}
