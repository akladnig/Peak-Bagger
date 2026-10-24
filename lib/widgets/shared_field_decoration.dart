import 'package:flutter/material.dart';

/// InputDecorator's string error defaults to ellipsis. A widget error wraps to
/// its actual height, with no line limit, outside the editable content viewport.
InputDecoration sharedFieldDecoration({String? labelText, String? errorText}) =>
    InputDecoration(
      labelText: labelText,
      error: errorText == null ? null : SharedFieldError(errorText),
    );

class SharedFieldError extends StatelessWidget {
  const SharedFieldError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, softWrap: true, overflow: TextOverflow.visible);
}
