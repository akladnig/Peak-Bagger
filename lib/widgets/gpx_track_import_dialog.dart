import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'dialog_helpers.dart';

typedef GpxTrackImportRunner =
    Future<GpxTrackImportResult> Function({
      required Map<String, String> pathToEditedNames,
    });

class GpxTrackImportDialog extends StatefulWidget {
  const GpxTrackImportDialog({
    required this.filePicker,
    required this.onImport,
    super.key,
  });

  final GpxFilePicker filePicker;
  final GpxTrackImportRunner onImport;

  @override
  State<GpxTrackImportDialog> createState() => _GpxTrackImportDialogState();
}

class _GpxTrackImportDialogState extends State<GpxTrackImportDialog> {
  final List<_SelectedFile> _selectedFiles = [];
  bool _isImporting = false;
  Map<String, String> _nameErrors = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('gpx-track-import-dialog'),
      title: const Text('Import GPX Track(s)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.tonal(
              key: const Key('gpx-track-select-files'),
              onPressed: _isImporting ? null : _selectFiles,
              child: const Text('Select GPX Files'),
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _selectedFiles[index];
                    return _buildFileRow(file, index);
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'No files selected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('gpx-track-import-cancel'),
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('gpx-track-import-button'),
          onPressed: _selectedFiles.isEmpty || _isImporting ? null : _import,
          child: _isImporting
              ? const SizedBox(
                  key: Key('gpx-track-import-progress'),
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }

  Widget _buildFileRow(_SelectedFile file, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        key: Key('gpx-track-row-$index'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: Key('gpx-track-name-field-$index'),
              controller: file.nameController,
              enabled: !_isImporting,
              decoration: InputDecoration(
                labelText: 'Track Name',
                errorText: _nameErrors[file.path],
                helperText: _basename(file.path),
                helperMaxLines: 1,
                helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onChanged: (_) {
                if (_nameErrors.containsKey(file.path)) {
                  setState(() {
                    _nameErrors = Map.from(_nameErrors)..remove(file.path);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFiles() async {
    try {
      final selected = await widget.filePicker.pickGpxFiles();
      if (!mounted || selected == null || selected.isEmpty) {
        return;
      }

      final newFiles = <_SelectedFile>[];
      for (final path in selected) {
        final existingIndex = _selectedFiles.indexWhere((f) => f.path == path);
        if (existingIndex >= 0) {
          newFiles.add(_selectedFiles[existingIndex]);
        } else {
          final prefilledName = await _derivePrefilledName(path);
          newFiles.add(
            _SelectedFile(
              path: path,
              nameController: TextEditingController(text: prefilledName),
            ),
          );
        }
      }

      setState(() {
        _selectedFiles.clear();
        _selectedFiles.addAll(newFiles);
      });
    } catch (error) {
      if (!mounted) return;

      await _showFailureDialog(
        Navigator.of(context, rootNavigator: true).context,
        _formatPickerError(error),
      );
    }
  }

  Future<String> _derivePrefilledName(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      final doc = XmlDocument.parse(content);
      final nameElement = doc.findAllElements('name').firstOrNull;
      if (nameElement != null) {
        final text = nameElement.innerText.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    } catch (_) {}
    return _basenameWithoutExtension(filePath);
  }

  String _basenameWithoutExtension(String filePath) {
    final filename = filePath.split(Platform.pathSeparator).last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) return filename;
    return filename.substring(0, dotIndex);
  }

  String _basename(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }

  String _formatPickerError(Object error) {
    if (error case PlatformException(:final message, :final code)) {
      return message == null || message.isEmpty ? code : message;
    }
    return error.toString();
  }

  Future<void> _import() async {
    // Validate all names
    final errors = <String, String>{};
    final pathToEditedNames = <String, String>{};

    for (final file in _selectedFiles) {
      final name = file.nameController.text.trim();
      if (name.isEmpty) {
        errors[file.path] = 'A track name is required';
      } else {
        pathToEditedNames[file.path] = name;
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _nameErrors = errors;
      });
      return;
    }

    setState(() {
      _isImporting = true;
    });

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    try {
      final result = await widget.onImport(
        pathToEditedNames: pathToEditedNames,
      );
      if (!mounted) return;

      setState(() {
        _isImporting = false;
      });

      await _showResultDialog(rootNavigator.context, result);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isImporting = false;
      });

      rootNavigator.pop();
      await _showFailureDialog(rootNavigator.context, error.toString());
    }
  }

  Future<void> _showResultDialog(
    BuildContext dialogContext,
    GpxTrackImportResult result,
  ) {
    return showSingleActionDialog(
      context: dialogContext,
      title: 'Import Complete',
      closeKey: 'gpx-track-import-result-close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.addedCount} track(s) added',
            key: const Key('gpx-track-import-summary'),
          ),
          if (result.unchangedCount > 0)
            Text('${result.unchangedCount} unchanged'),
          if (result.nonTasmanianCount > 0)
            Text('${result.nonTasmanianCount} non-Tasmanian'),
          if (result.errorCount > 0) Text('${result.errorCount} error(s)'),
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
      title: 'Import Failed',
      closeKey: 'gpx-track-import-error-close',
      content: Text(error),
    );
  }
}

class _SelectedFile {
  _SelectedFile({required this.path, required this.nameController});

  final String path;
  final TextEditingController nameController;
}
