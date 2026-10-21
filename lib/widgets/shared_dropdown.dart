import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_field_decoration.dart';

enum SharedDropdownTrigger { labelledField, iconOnly }

enum SharedDropdownRows { labelOnly, iconAndLabel }

/// Explicit close outcomes let card owners restore inspection or traverse cards
/// without treating an unchanged menu dismissal as a selection.
enum SharedDropdownCloseReason {
  unchanged,
  selected,
  tabForward,
  tabBackward,
  unavailable,
}

class SharedDropdownChoice<T> {
  const SharedDropdownChoice({
    required this.value,
    required this.label,
    this.key,
    this.icon,
    this.enabled = true,
    this.semanticLabel,
  });

  final T value;
  final String label;
  final Key? key;
  final IconData? icon;
  final bool enabled;
  final String? semanticLabel;
}

/// Presentation only: the caller owns the typed value, draft and persistence.
/// Use T? with a null-valued choice for Any; [hasSelection] distinguishes that
/// committed null from a required field with no value yet.
class SharedDropdown<T> extends StatefulWidget {
  const SharedDropdown({
    required this.label,
    required this.value,
    required this.choices,
    required this.onSelected,
    this.hasSelection = true,
    this.hint,
    this.errorText,
    this.enabled = true,
    this.isInteractionAllowed,
    this.trigger = SharedDropdownTrigger.labelledField,
    this.rows = SharedDropdownRows.labelOnly,
    this.icon,
    this.focusNode,
    this.controller,
    this.onOpened,
    this.onClosed,
    this.restoreFocus = true,
    this.skipTraversal = false,
    super.key,
  }) : assert(trigger != SharedDropdownTrigger.iconOnly || icon != null);

  final String label;
  final T value;
  final List<SharedDropdownChoice<T>> choices;
  final ValueChanged<T> onSelected;
  final bool hasSelection;
  final String? hint;
  final String? errorText;
  final bool enabled;

  /// Read the authoritative current lock here, including before a rebuild.
  final bool Function()? isInteractionAllowed;
  final SharedDropdownTrigger trigger;
  final SharedDropdownRows rows;
  final IconData? icon;
  final FocusNode? focusNode;
  final MenuController? controller;
  final VoidCallback? onOpened;
  final ValueChanged<SharedDropdownCloseReason>? onClosed;
  final bool restoreFocus;
  final bool skipTraversal;

  @override
  State<SharedDropdown<T>> createState() => _SharedDropdownState<T>();
}

class _SharedDropdownState<T> extends State<SharedDropdown<T>> {
  final _ownedFocus = FocusNode(debugLabel: 'Dropdown trigger');
  final _menuFocus = FocusNode(debugLabel: 'Dropdown menu');
  final _ownedController = MenuController();
  final _scroll = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  LocalHistoryEntry? _history;
  SharedDropdownCloseReason _reason = SharedDropdownCloseReason.unchanged;
  int? _target;
  bool _hovered = false;
  bool _open = false;
  bool _disposing = false;
  int _revision = 0;

  FocusNode get _focus => widget.focusNode ?? _ownedFocus;
  MenuController get _menu => widget.controller ?? _ownedController;
  bool get _allowed =>
      mounted &&
      widget.enabled &&
      (widget.isInteractionAllowed?.call() ?? true) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  bool get _selectable => _allowed && widget.choices.any((c) => c.enabled);
  int get _committed => widget.hasSelection
      ? widget.choices.indexWhere((c) => c.value == widget.value)
      : -1;

  @override
  void didUpdateWidget(covariant SharedDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_open &&
        (!widget.enabled ||
            widget.controller != oldWidget.controller ||
            widget.focusNode != oldWidget.focusNode ||
            !_sameChoices(oldWidget.choices, widget.choices))) {
      _scheduleUnavailableClose();
    }
  }

  bool _sameChoices(
    List<SharedDropdownChoice<T>> a,
    List<SharedDropdownChoice<T>> b,
  ) =>
      a.length == b.length &&
      List.generate(
        a.length,
        (i) => a[i].value == b[i].value && a[i].enabled == b[i].enabled,
      ).every((v) => v);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open && !_allowed) _scheduleUnavailableClose();
  }

  void _scheduleUnavailableClose() {
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open && revision == _revision) {
        _close(SharedDropdownCloseReason.unavailable);
      }
    });
  }

  void _openRequested(Offset? position, VoidCallback show) {
    // A choice-less field can still open to explain an unavailable selection.
    if (!_allowed) return;
    _target = null;
    _reason = SharedDropdownCloseReason.unchanged;
    widget.onOpened?.call();
    if (!_allowed) return;
    show();
    setState(() => _open = true);
    _history = LocalHistoryEntry(
      onRemove: () {
        _history = null;
        if (mounted && _open) _close();
      },
    );
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open && revision == _revision && _allowed) {
        _menuFocus.requestFocus();
        _reveal(_committed);
      }
    });
  }

  void _close([
    SharedDropdownCloseReason reason = SharedDropdownCloseReason.unchanged,
  ]) {
    if (!_open) return;
    _reason = reason;
    _menu.close();
  }

  void _closed() {
    if (_disposing || !_open) return;
    final reason = _allowed ? _reason : SharedDropdownCloseReason.unavailable;
    _open = false;
    ++_revision;
    final history = _history;
    _history = null;
    history?.remove();
    setState(() {});
    if (widget.restoreFocus &&
        reason != SharedDropdownCloseReason.unavailable &&
        _allowed &&
        _focus.canRequestFocus) {
      _focus.requestFocus();
      if (reason == SharedDropdownCloseReason.tabForward) {
        _focus.nextFocus();
      } else if (reason == SharedDropdownCloseReason.tabBackward) {
        _focus.previousFocus();
      }
    }
    widget.onClosed?.call(reason);
  }

  void _select(int index) {
    if (!_open ||
        !_allowed ||
        index >= widget.choices.length ||
        !widget.choices[index].enabled) {
      if (_open && !_allowed) _close(SharedDropdownCloseReason.unavailable);
      return;
    }
    final value = widget.choices[index].value;
    // Close before dispatch: a caller may remove this anchor synchronously.
    _close(SharedDropdownCloseReason.selected);
    if (_allowed) widget.onSelected(value);
  }

  void _move(int delta) {
    if (!_allowed) {
      _close(SharedDropdownCloseReason.unavailable);
      return;
    }
    final length = widget.choices.length;
    if (length == 0) return;
    final committed = _committed;
    var index =
        _target ??
        (committed >= 0 && widget.choices[committed].enabled
            ? committed
            : (delta > 0 ? -1 : 0));
    for (var i = 0; i < length; i++) {
      index = (index + delta) % length;
      if (!widget.choices[index].enabled) continue;
      setState(() => _target = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reveal(index);
      });
      return;
    }
  }

  void _reveal(int index) {
    if (!mounted || !_open || !_scroll.hasClients) return;
    final render = _rowKeys[index]?.currentContext?.findRenderObject();
    if (render == null || !render.attached) return;
    _scroll.position.ensureVisible(
      render,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    _scroll.position.ensureVisible(
      render,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  KeyEventResult _menuKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    final keyboard = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape ||
        (key == LogicalKeyboardKey.keyC &&
            keyboard.isControlPressed &&
            !keyboard.isMetaPressed &&
            !keyboard.isAltPressed)) {
      _close();
    } else if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      // Preserve native copy; do not let background Search/card shortcuts run.
      return key == LogicalKeyboardKey.keyC && keyboard.isMetaPressed
          ? KeyEventResult.ignored
          : KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.tab) {
      _close(
        keyboard.isShiftPressed
            ? SharedDropdownCloseReason.tabBackward
            : SharedDropdownCloseReason.tabForward,
      );
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyJ) {
      _move(1);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyK) {
      _move(-1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _target == null ? _close() : _select(_target!);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _triggerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    if ({
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.space,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowUp,
        }.contains(event.logicalKey) &&
        _selectable) {
      _menu.open();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _disposing = true;
    _open = false;
    ++_revision;
    _history?.remove();
    _ownedFocus.dispose();
    _menuFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _committed < 0 ? null : widget.choices[_committed];
    final text = selected?.label ?? widget.hint ?? '';
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      heightFactor: 1,
      child: RawMenuAnchor(
        controller: _menu,
        consumeOutsideTaps: true,
        onOpenRequested: _openRequested,
        onClose: _closed,
        overlayBuilder: (context, info) => _overlay(context, info),
        builder: (context, controller, child) {
          final canActivate = _selectable;
          final states = <WidgetState>{
            if (!widget.enabled) WidgetState.disabled,
            if (_hovered) WidgetState.hovered,
            if (_focus.hasFocus || _open) WidgetState.focused,
            if (widget.errorText != null) WidgetState.error,
          };
          final semanticValue = selected?.semanticLabel ?? text;
          void toggle() {
            if (!_allowed) return;
            _open ? _close() : (canActivate ? controller.open() : null);
          }

          if (widget.trigger == SharedDropdownTrigger.iconOnly) {
            final style = theme.iconButtonTheme.style!;
            return MergeSemantics(
              child: Semantics(
                label: widget.label,
                value: semanticValue,
                expanded: _open,
                child: ExcludeFocusTraversal(
                  excluding: widget.skipTraversal,
                  child: Tooltip(
                    message: widget.label,
                    excludeFromSemantics: true,
                    child: IconButton(
                      focusNode: _focus,
                      // The explicit action/value semantics above are authoritative.
                      tooltip: null,
                      style: style.copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.square(48),
                        ),
                        side: WidgetStateProperty.resolveWith((buttonStates) {
                          if (buttonStates.contains(WidgetState.disabled)) {
                            return BorderSide.none;
                          }
                          if (_open ||
                              buttonStates.contains(WidgetState.focused)) {
                            return BorderSide(
                              color: widget.errorText != null
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              width: 2,
                            );
                          }
                          return BorderSide.none;
                        }),
                      ),
                      onPressed: canActivate ? toggle : null,
                      icon: ExcludeSemantics(child: Icon(widget.icon)),
                    ),
                  ),
                ),
              ),
            );
          }
          final valueStyle = SharedDropdownStyle.valueText(theme).copyWith(
            color: theme.colorScheme.onSurface.withValues(
              alpha: widget.enabled ? 1 : .38,
            ),
          );
          final scaler = MediaQuery.textScalerOf(context);
          final direction = Directionality.of(context);
          double measure(String text, TextStyle style) =>
              _textWidth(text, style, scaler, direction);
          final valueWidth = [
            text,
            if (widget.hint != null) widget.hint!,
            ...widget.choices.map((c) => c.label),
          ].map((s) => measure(s, valueStyle)).fold(0.0, math.max);
          final labelWidth = measure(
            widget.label,
            theme.inputDecorationTheme.labelStyle ?? valueStyle,
          );
          final width = math.max(
            48.0,
            math.max(valueWidth + 24 + 12 + 24, labelWidth + 24),
          );
          return Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(
              width: width,
              child: Focus(
                focusNode: _focus,
                skipTraversal: widget.skipTraversal || !canActivate,
                canRequestFocus: widget.enabled,
                onFocusChange: (_) => setState(() {}),
                onKeyEvent: _triggerKey,
                child: Semantics(
                  button: true,
                  enabled: canActivate,
                  expanded: _open,
                  label: widget.label,
                  value: semanticValue,
                  onTap: canActivate ? toggle : null,
                  child: MouseRegion(
                    cursor: canActivate
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: canActivate ? toggle : null,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 48,
                          minWidth: 48,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final padding = theme
                                .inputDecorationTheme
                                .contentPadding!
                                .resolve(direction);
                            final labelStyle = theme.textTheme.titleMedium!
                                .merge(theme.inputDecorationTheme.labelStyle)
                                .copyWith(height: 1);
                            // Flutter floats outlined labels at 75% and centers
                            // them over the top border, but does not reserve their
                            // wrapped height. Keep the entire label in our target
                            // and clear of the value, using the actual scaler.
                            final label =
                                TextPainter(
                                  text: TextSpan(
                                    text: widget.label,
                                    style: labelStyle,
                                  ),
                                  textDirection: direction,
                                  textScaler: scaler,
                                )..layout(
                                  maxWidth: math.max(
                                    1,
                                    (constraints.maxWidth -
                                            padding.horizontal -
                                            8) /
                                        .75,
                                  ),
                                );
                            final labelHalfHeight = label.height * .75 / 2;
                            label.dispose();
                            return Padding(
                              padding: EdgeInsets.only(top: labelHalfHeight),
                              child: InputDecorator(
                                isFocused: states.contains(WidgetState.focused),
                                isHovering: _hovered && widget.enabled,
                                isEmpty: false,
                                decoration:
                                    sharedFieldDecoration(
                                          errorText: widget.errorText,
                                        )
                                        .copyWith(
                                          enabled: widget.enabled,
                                          // InputDecorator ellipsizes labelText. A widget label wraps.
                                          label: ExcludeSemantics(
                                            child: Text(
                                              widget.label,
                                              softWrap: true,
                                            ),
                                          ),
                                        )
                                        .applyDefaults(
                                          theme.inputDecorationTheme,
                                        ),
                                child: ExcludeSemantics(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: math.max(
                                        0,
                                        labelHalfHeight - padding.top + 4,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            text,
                                            style: valueStyle,
                                            softWrap: true,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 24,
                                          color: valueStyle.color,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _overlay(BuildContext context, RawMenuOverlayInfo info) {
    final media = MediaQuery.of(context);
    const margin = SharedDropdownStyle.viewportMargin;
    final bounds = Rect.fromLTRB(
      math.max(media.padding.left, media.viewInsets.left) + margin,
      math.max(media.padding.top, media.viewInsets.top) + margin,
      info.overlaySize.width -
          math.max(media.padding.right, media.viewInsets.right) -
          margin,
      info.overlaySize.height -
          math.max(media.padding.bottom, media.viewInsets.bottom) -
          margin,
    );
    if (!_allowed || !bounds.overlaps(info.anchorRect)) {
      _scheduleUnavailableClose();
    }
    final theme = Theme.of(context);
    final style = SharedDropdownStyle.menuText(theme);
    final withIcons = widget.rows == SharedDropdownRows.iconAndLabel;
    final contentWidth =
        widget.choices
            .map(
              (c) => _textWidth(
                c.label,
                style,
                media.textScaler,
                Directionality.of(context),
              ),
            )
            .fold(0.0, math.max) +
        24 +
        24 +
        12 +
        (withIcons ? 36 : 0);
    final width = math
        .max(info.anchorRect.width, contentWidth)
        .clamp(0.0, math.max(0.0, bounds.width))
        .toDouble();
    final below = math.max(0.0, bounds.bottom - info.anchorRect.bottom);
    final above = math.max(0.0, info.anchorRect.top - bounds.top);
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _DropdownLayout(
          anchor: info.anchorRect,
          bounds: bounds,
          width: width,
          below: below,
          above: above,
        ),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          consumeOutsideTaps: true,
          onTapOutside: (_) => _close(),
          child: Focus(
            focusNode: _menuFocus,
            onKeyEvent: _menuKey,
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              label: widget.label,
              child: Material(
                key: const ValueKey('shared-dropdown-menu'),
                color: theme.colorScheme.surfaceContainer,
                surfaceTintColor: Colors.transparent,
                elevation: SharedDropdownStyle.elevation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    SharedDropdownStyle.radius,
                  ),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Scrollbar(
                  controller: _scroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < widget.choices.length; i++)
                          KeyedSubtree(
                            key: _rowKeys.putIfAbsent(i, GlobalKey.new),
                            child: _DropdownRow(
                              key: widget.choices[i].key,
                              label: widget.choices[i].label,
                              semanticLabel: widget.choices[i].semanticLabel,
                              icon: withIcons ? widget.choices[i].icon : null,
                              withIcon: withIcons,
                              enabled:
                                  widget.enabled && widget.choices[i].enabled,
                              selected:
                                  widget.hasSelection &&
                                  widget.choices[i].value == widget.value,
                              targeted: i == _target,
                              tick: SharedDropdownStyle.tick(
                                theme,
                                error: widget.errorText != null,
                                disabled:
                                    !widget.enabled ||
                                    !widget.choices[i].enabled,
                              ),
                              onTap: () => _select(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _textWidth(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: scaler,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

class _DropdownLayout extends SingleChildLayoutDelegate {
  _DropdownLayout({
    required this.anchor,
    required this.bounds,
    required this.width,
    required this.below,
    required this.above,
  });
  final Rect anchor;
  final Rect bounds;
  final double width;
  final double below;
  final double above;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(below, above),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    anchor.left.clamp(
      bounds.left,
      math.max(bounds.left, bounds.right - childSize.width),
    ),
    childSize.height <= below
        ? anchor.bottom.clamp(bounds.top, bounds.bottom)
        : math.max(bounds.top, anchor.top - childSize.height),
  );
  @override
  bool shouldRelayout(_DropdownLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      bounds != oldDelegate.bounds ||
      width != oldDelegate.width;
}

class _DropdownRow extends StatefulWidget {
  const _DropdownRow({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.withIcon,
    required this.enabled,
    required this.selected,
    required this.targeted,
    required this.tick,
    required this.onTap,
  });
  final String label;
  final String? semanticLabel;
  final IconData? icon;
  final bool withIcon;
  final bool enabled;
  final bool selected;
  final bool targeted;
  final Color tick;
  final VoidCallback onTap;

  @override
  State<_DropdownRow> createState() => _DropdownRowState();
}

class _DropdownRowState extends State<_DropdownRow> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface.withValues(
      alpha: widget.enabled ? 1 : .38,
    );
    final active = widget.enabled && (_hover || _pressed || widget.targeted);
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticLabel ?? widget.label,
      onTap: widget.enabled ? widget.onTap : null,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: ColoredBox(
            color: active
                ? SharedDropdownStyle.rowFill(theme, pressed: _pressed)
                : theme.colorScheme.surfaceContainer,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: SharedDropdownStyle.minimumRowHeight,
              ),
              child: Padding(
                padding: SharedDropdownStyle.optionPadding,
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      if (widget.withIcon) ...[
                        SizedBox.square(
                          dimension: SharedDropdownStyle.iconSize,
                          child: widget.icon == null
                              ? null
                              : Icon(
                                  widget.icon,
                                  size: SharedDropdownStyle.iconSize,
                                  color: foreground,
                                ),
                        ),
                        const SizedBox(width: SharedDropdownStyle.gap),
                      ],
                      Expanded(
                        child: Text(
                          widget.label,
                          softWrap: true,
                          style: SharedDropdownStyle.menuText(
                            theme,
                          ).copyWith(color: foreground),
                        ),
                      ),
                      const SizedBox(width: SharedDropdownStyle.gap),
                      SizedBox.square(
                        dimension: SharedDropdownStyle.checkSize,
                        child: widget.selected
                            ? Icon(
                                Icons.check,
                                size: SharedDropdownStyle.checkSize,
                                color: widget.tick,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
