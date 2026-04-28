import 'package:flutter/material.dart';

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
      decoration: InputDecoration(
        labelText: 'List Name',
        errorText: errorText,
      ),
      onChanged: onChanged,
    );
  }
}
