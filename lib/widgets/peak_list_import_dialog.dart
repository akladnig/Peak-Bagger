import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/peak_list_file_picker.dart';
import 'dialog_helpers.dart';

typedef PeakListDuplicateNameChecker = Future<bool> Function(String name);

typedef PeakListImportRunner =
    Future<PeakListImportPresentationResult> Function({
      required String listName,
      required String csvPath,
    });

class PeakListImportPresentationResult {
  const PeakListImportPresentationResult({
    required this.updated,
    required this.importedCount,
    required this.skippedCount,
    this.warningCount = 0,
    this.warningMessage,
    this.peakListId,
    this.listName,
  });

  final bool updated;
  final int importedCount;
  final int skippedCount;
  final int warningCount;
  final String? warningMessage;
  final int? peakListId;
  final String? listName;

  String get title => updated ? 'Peak List Updated' : 'Peak List Created';
}

class PeakListImportDialog extends StatefulWidget {
  const PeakListImportDialog({
    required this.filePicker,
    required this.onImport,
    required this.duplicateNameChecker,
    super.key,
  });

  final PeakListFilePicker filePicker;
  final PeakListImportRunner onImport;
  final PeakListDuplicateNameChecker duplicateNameChecker;

  @override
  State<PeakListImportDialog> createState() => _PeakListImportDialogState();
}

class _PeakListImportDialogState extends State<PeakListImportDialog> {
  final _nameController = TextEditingController();
  String? _selectedFilePath;
  String? _nameError;
  bool _isImporting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('peak-list-import-dialog'),
      title: const Text('Import Peak List'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.tonal(
            key: const Key('peak-list-select-file'),
            onPressed: _isImporting ? null : _selectFile,
            child: const Text('Select Peak Lists'),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedFilePath ?? 'No file selected',
            key: const Key('peak-list-selected-file'),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('peak-list-name-field'),
            controller: _nameController,
            enabled: !_isImporting,
            decoration: InputDecoration(
              labelText: 'List Name',
              errorText: _nameError,
            ),
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
          key: const Key('peak-list-import-cancel'),
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('peak-list-import-button'),
          onPressed: _selectedFilePath == null || _isImporting ? null : _import,
          child: _isImporting
              ? const SizedBox(
                  key: Key('peak-list-import-progress'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }

  Future<void> _selectFile() async {
    try {
      final selected = await widget.filePicker.pickCsvFile();
      if (!mounted || selected == null) {
        return;
      }

      setState(() {
        _selectedFilePath = selected;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      await _showFailureDialog(
        Navigator.of(context, rootNavigator: true).context,
        _formatPickerError(error),
      );
    }
  }

  String _formatPickerError(Object error) {
    if (error case PlatformException(:final message, :final code)) {
      return message == null || message.isEmpty ? code : message;
    }

    return error.toString();
  }

  Future<void> _import() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'A list name is required';
      });
      return;
    }

    final csvPath = _selectedFilePath;
    if (csvPath == null) {
      return;
    }

    final duplicateName = await widget.duplicateNameChecker(name);
    if (!mounted) {
      return;
    }
    if (duplicateName) {
      final confirmed = await _confirmUpdate();
      if (!mounted || confirmed != true) {
        return;
      }
    }

    setState(() {
      _isImporting = true;
    });

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    try {
      final result = await widget.onImport(listName: name, csvPath: csvPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _isImporting = false;
      });
      await _showResultDialog(rootNavigator.context, result);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      rootNavigator.pop();
      await _showFailureDialog(rootNavigator.context, error.toString());
    } finally {
      if (mounted && _isImporting) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<bool?> _confirmUpdate() {
    return showDangerConfirmDialog(
      context: context,
      title: 'Update Existing Peak List?',
      message:
          'This list already exists - do you want to update the existing list?',
      cancelKey: 'peak-list-update-cancel',
      cancelLabel: 'Cancel',
      confirmKey: 'peak-list-update-confirm',
      confirmLabel: 'Update',
    );
  }

  Future<void> _showResultDialog(
    BuildContext dialogContext,
    PeakListImportPresentationResult result,
  ) {
    return showSingleActionDialog(
      context: dialogContext,
      title: result.title,
      closeKey: 'peak-list-import-result-close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.importedCount} Peaks imported'),
          Text('${result.skippedCount} peaks skipped'),
          if (result.warningCount > 0) ...[
            const SizedBox(height: 12),
            Text(
              '${result.warningCount} warnings. See import.log for details.',
            ),
          ],
          if (result.warningMessage != null) ...[
            const SizedBox(height: 12),
            Text(result.warningMessage!),
          ],
        ],
      ),
    );
  }

  Future<void> _showFailureDialog(BuildContext dialogContext, String error) {
    return showSingleActionDialog(
      context: dialogContext,
      title: 'Peak List Import Failed',
      closeKey: 'peak-list-import-error-close',
      content: Text(error),
    );
  }
}
