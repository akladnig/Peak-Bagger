import 'package:flutter/material.dart';

import 'dialog_helpers.dart';
import 'peak_list_name_field.dart';

typedef PeakListCreateRunner = Future<int> Function({
  required String listName,
});

class PeakListCreateDialog extends StatefulWidget {
  const PeakListCreateDialog({
    required this.onCreate,
    required this.duplicateNameChecker,
    super.key,
  });

  final PeakListCreateRunner onCreate;
  final Future<bool> Function(String name) duplicateNameChecker;

  @override
  State<PeakListCreateDialog> createState() => _PeakListCreateDialogState();
}

class _PeakListCreateDialogState extends State<PeakListCreateDialog> {
  final _nameController = TextEditingController();
  String? _nameError;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('peak-list-create-dialog'),
      title: const Text('Add New Peak List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PeakListNameField(
            fieldKey: const Key('peak-list-create-name-field'),
            controller: _nameController,
            enabled: !_isCreating,
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) {
                setState(() {
                  _nameError = null;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('peak-list-create-cancel'),
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('peak-list-create-button'),
          onPressed: _isCreating ? null : _createPeakList,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _createPeakList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'A list name is required';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _nameError = null;
    });

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    try {
      final isDuplicate = await widget.duplicateNameChecker(name);
      if (!mounted) {
        return;
      }
      if (isDuplicate) {
        setState(() {
          _isCreating = false;
          _nameError = 'This peak list already exists.';
        });
        return;
      }

      final peakListId = await widget.onCreate(listName: name);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(peakListId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCreating = false;
      });
      await showSingleActionDialog(
        context: rootNavigator.context,
        title: 'Peak List Create Failed',
        closeKey: 'peak-list-create-error-close',
        content: Text(error.toString()),
      );
      return;
    } finally {
      if (mounted && _isCreating) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
