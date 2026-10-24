import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visible label plus the same complete selectable viewport used by details.
class ObjectBoxAdminReadOnlyFormValue extends StatelessWidget {
  const ObjectBoxAdminReadOnlyFormValue({
    required this.label,
    required this.text,
    required this.valueKey,
    super.key,
  });

  final String label;
  final String text;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      ObjectBoxAdminReadOnlyValue(key: valueKey, label: label, text: text),
    ],
  );
}

/// Selectable, non-editable value content to place beside/below its visible label.
///
/// The semantic label travels with the value. Give this widget a record/field key
/// so selection and scrolling cannot migrate to another record in a reused list.
class ObjectBoxAdminReadOnlyValue extends StatefulWidget {
  const ObjectBoxAdminReadOnlyValue({
    required this.label,
    required this.text,
    this.style,
    super.key,
  });

  final String label;
  final String text;
  final TextStyle? style;

  @override
  State<ObjectBoxAdminReadOnlyValue> createState() =>
      _ObjectBoxAdminReadOnlyValueState();
}

class _ObjectBoxAdminReadOnlyValueState
    extends State<ObjectBoxAdminReadOnlyValue> {
  // Never inherit the outer details panel's primary controller or PageStorage
  // position. This value alone owns these resources; SelectionArea owns selection.
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _focusNode = FocusNode(debugLabel: 'Admin read-only value');

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        widget.style ??
        theme.textTheme.bodyMedium!.copyWith(
          color: theme.colorScheme.onSurface,
        );
    final defaults = DefaultTextStyle.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    return Semantics(
      container: true,
      label: widget.label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            textHeightBehavior: defaults.textHeightBehavior,
          )..layout(maxWidth: constraints.maxWidth);
          final lines = painter.computeLineMetrics();
          final cap = lines.isEmpty
              ? painter.height
              : lines.take(5).fold(0.0, (sum, line) => sum + line.height);
          final height = math.min(painter.height, cap);
          final scrolls = lines.length > 5;
          painter.dispose();

          return ListenableBuilder(
            listenable: _focusNode,
            builder: (context, child) => DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: _focusNode.hasFocus
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: child,
            ),
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: SizedBox(
                height: height,
                child: SelectionArea(
                  focusNode: _focusNode,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: scrolls,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      primary: false,
                      child: Text(
                        widget.text,
                        style: style,
                        textScaler: scaler,
                        textDirection: direction,
                        locale: locale,
                        textHeightBehavior: defaults.textHeightBehavior,
                        softWrap: true,
                        maxLines: null,
                        overflow: TextOverflow.clip,
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
}
