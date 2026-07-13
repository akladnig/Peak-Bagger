import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/core/widgets/popup_keyboard_dismiss.dart';

import '../services/peak_list_file_picker.dart';
import 'dialog_helpers.dart';
import 'peak_list_name_field.dart';

typedef PeakListDuplicateNameChecker = Future<bool> Function(String name);

typedef PeakListImportRunner =
    Future<PeakListImportPresentationResult> Function({
      required String listName,
      required String csvPath,
    });

typedef PeakListImportStarter =
    Future<bool> Function({required String listName, required String csvPath});

class PeakListImportPresentationResult {
  const PeakListImportPresentationResult({
    required this.updated,
    required this.importedCount,
    required this.skippedCount,
    this.matchedCount = 0,
    this.ambiguousCount = 0,
    this.warningCount = 0,
    this.warningMessage,
    this.logEntryCount = 0,
    this.importLogNote,
    this.peakListId,
    this.listName,
  });

  final bool updated;
  final int importedCount;
  final int skippedCount;
  final int matchedCount;
  final int ambiguousCount;
  final int warningCount;
  final String? warningMessage;
  final int logEntryCount;
  final String? importLogNote;
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
  final PeakListImportStarter onImport;
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
    return PopupKeyboardDismiss(
      enabled: !_isImporting,
      onDismiss: () => Navigator.of(context).pop(),
      child: AlertDialog(
        key: const Key('peak-list-import-dialog'),
        title: const Text('Import Peak List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
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
            PeakListNameField(
              fieldKey: const Key('peak-list-name-field'),
              controller: _nameController,
              enabled: !_isImporting,
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
          FilledButton(
            key: const Key('peak-list-import-cancel'),
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('peak-list-import-button'),
            onPressed: _selectedFilePath == null || _isImporting
                ? null
                : _import,
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
      ),
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

  String _formatImportError(Object error) {
    if (error case FormatException(:final message)) {
      return message.toString();
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
      final accepted = await widget.onImport(listName: name, csvPath: csvPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _isImporting = false;
      });
      if (accepted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      rootNavigator.pop();
      await _showFailureDialog(
        rootNavigator.context,
        _formatImportError(error),
      );
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

  Future<void> _showFailureDialog(BuildContext dialogContext, String error) {
    return showSingleActionDialog(
      context: dialogContext,
      title: 'Peak List Import Failed',
      closeKey: 'peak-list-import-error-close',
      content: Text(error),
    );
  }
}
