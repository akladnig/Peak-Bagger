import 'package:flutter/material.dart';
import 'shared_field_decoration.dart';

class PeakListNameField extends StatelessWidget {
  const PeakListNameField({
    required this.controller,
    required this.enabled,
    this.fieldKey,
    this.errorText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final Key? fieldKey;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      decoration: sharedFieldDecoration(
        labelText: 'List Name',
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}
