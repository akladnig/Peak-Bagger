import 'dart:developer' as developer;

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

/// The route gate also rejects direct Navigator.pop, not just maybePop/back.
/// Child confirmations have their own route and remain independently dismissible.
Future<bool?> showPeakListImportDialog({
  required BuildContext context,
  required PeakListFilePicker filePicker,
  required PeakListImportStarter onImport,
  required PeakListDuplicateNameChecker duplicateNameChecker,
}) => Navigator.of(context, rootNavigator: true).push<bool>(
  _PeakListImportRoute(
    context: context,
    builder: (_) => PeakListImportDialog(
      filePicker: filePicker,
      onImport: onImport,
      duplicateNameChecker: duplicateNameChecker,
    ),
  ),
);

class _PeakListImportRoute extends DialogRoute<bool> {
  _PeakListImportRoute({required super.context, required super.builder});
  bool _locked = false;
  set locked(bool value) {
    if (_locked == value) return;
    _locked = value;
    changedExternalState();
  }

  @override
  bool get barrierDismissible => !_locked;
  @override
  RoutePopDisposition get popDisposition =>
      _locked ? RoutePopDisposition.doNotPop : super.popDisposition;
  @override
  bool didPop(bool? result) => !_locked && super.didPop(result);
}

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

/// Present with [showPeakListImportDialog] so all parent dismissal paths share
/// the synchronous attempt gate, while duplicate-confirmation routes stay usable.
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
  bool _isSelectingFile = false;
  String? _failure;

  void _setImporting(bool value) {
    final route = ModalRoute.of(context);
    if (route is _PeakListImportRoute) route.locked = value;
    setState(() => _isImporting = value);
  }

  void _dismiss() {
    if (_isImporting || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupKeyboardDismiss(
      enabled: !_isImporting,
      onDismiss: _dismiss,
      child: AlertDialog(
        key: const Key('peak-list-import-dialog'),
        title: const Text('Import Peak List'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              key: const Key('peak-list-select-file'),
              onPressed: _isImporting || _isSelectingFile ? null : _selectFile,
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
                if (_isImporting) return;
                if (_nameError != null) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
            ),
            if (_failure case final failure?) ...[
              const SizedBox(height: 12),
              Text(
                failure,
                key: const Key('peak-list-import-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            key: const Key('peak-list-import-cancel'),
            onPressed: _isImporting ? null : _dismiss,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('peak-list-import-button'),
            onPressed:
                _selectedFilePath == null || _isImporting || _isSelectingFile
                ? null
                : _import,
            child: _isImporting
                ? SizedBox(
                    key: const Key('peak-list-import-progress'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: (ModalRoute.of(context)?.isCurrent ?? true)
                          ? null
                          : 0,
                    ),
                  )
                : const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFile() async {
    if (_isImporting || _isSelectingFile) return;
    setState(() => _isSelectingFile = true);
    try {
      final selected = await widget.filePicker.pickCsvFile();
      if (!mounted || _isImporting || selected == null) {
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
    } finally {
      if (mounted) setState(() => _isSelectingFile = false);
    }
  }

  String _formatPickerError(Object error) {
    if (error case PlatformException(:final message, :final code)) {
      return message == null || message.isEmpty ? code : message;
    }

    return error.toString();
  }

  Future<void> _import() async {
    if (_isImporting ||
        _isSelectingFile ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
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

    _setImporting(true);
    setState(() => _failure = null);
    try {
      final duplicateName = await widget.duplicateNameChecker(name);
      if (!mounted) return;
      if (duplicateName) {
        final confirmed = await _confirmUpdate();
        if (!mounted || confirmed != true) return;
      }
      final accepted = await widget.onImport(listName: name, csvPath: csvPath);
      if (!mounted) {
        return;
      }
      if (accepted) {
        _setImporting(false);
        Navigator.of(context).pop(true);
      } else {
        setState(
          () => _failure =
              'The import could not be started. Your file and list name have been kept. Check Background Jobs for running work, then try Import again.',
        );
      }
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      // Do not log file paths, list names or exception payloads.
      developer.log(
        'Peak List import could not be started (${error.runtimeType})',
        name: 'peak_list_import',
        stackTrace: stackTrace,
      );
      setState(
        () => _failure =
            'The import could not be started. Your file and list name have been kept. Try Import again, or Cancel to discard them.',
      );
    } finally {
      if (mounted && _isImporting) {
        _setImporting(false);
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The CSV file could not be selected. Try Select Peak Lists again.',
          ),
          const SizedBox(height: 12),
          Text(error),
        ],
      ),
    );
  }
}
