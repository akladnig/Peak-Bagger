import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

import 'package:peak_bagger/core/widgets/popup_shell.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'dialog_helpers.dart';

typedef GpxImportRunner = Future<dynamic> Function({
  required bool importAsRoute,
  required Map<String, String> pathToEditedNames,
});

typedef GpxTrackImportRunner = GpxImportRunner;
typedef GpxPrefilledNameResolver = Future<String> Function(String filePath);

class GpxImportDialog extends StatefulWidget {
  const GpxImportDialog({
    required this.filePicker,
    required this.onImport,
    required this.importAsRoute,
    this.prefilledNameResolver,
    super.key,
  });

  final GpxFilePicker filePicker;
  final bool importAsRoute;
  final GpxImportRunner onImport;
  final GpxPrefilledNameResolver? prefilledNameResolver;

  @override
  State<GpxImportDialog> createState() => _GpxImportDialogState();
}

typedef GpxTrackImportDialog = GpxImportDialog;

class _GpxImportDialogState extends State<GpxImportDialog> {
  static const double _panelHorizontalPadding = 16;
  static const double _dialogMaxWidth = 320;
  static const double _dialogChromeHeightEstimate = 320;
  static const double _estimatedFileRowHeight = 96;

  final List<_SelectedFile> _selectedFiles = [];
  final GlobalKey _headerMeasureKey = GlobalKey();
  final GlobalKey _bodyStaticMeasureKey = GlobalKey();
  final GlobalKey _actionsMeasureKey = GlobalKey();
  bool _isImporting = false;
  bool _isSelectingFiles = false;
  Map<String, String> _nameErrors = {};
  double? _measuredChromeHeight;

  late bool _importAsRoute;

  @override
  void initState() {
    super.initState();
    _importAsRoute = widget.importAsRoute;
  }

  @override
  void dispose() {
    for (final file in _selectedFiles) {
      file.nameController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMeasuredChromeHeight();
    });

    return Dialog(
      insetPadding: const EdgeInsets.all(_panelHorizontalPadding),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(
            _dialogMaxWidth,
            MediaQuery.sizeOf(context).width - (_panelHorizontalPadding * 2),
          ),
          maxHeight: math.max(0.0, MediaQuery.sizeOf(context).height - 32),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chromeHeight = _measuredChromeHeight ?? _dialogChromeHeightEstimate;
            final availableFileHeight = math.max(
              0.0,
              constraints.maxHeight - chromeHeight,
            );
            final estimatedFileHeight =
                _selectedFiles.length * _estimatedFileRowHeight;
            final shouldScrollFiles = estimatedFileHeight > availableFileHeight;

            Widget fileSection() {
              if (_selectedFiles.isEmpty) {
                return const SizedBox.shrink();
              }

              if (!shouldScrollFiles) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0;
                        index < _selectedFiles.length;
                        index += 1)
                      _buildFileRow(_selectedFiles[index], index),
                  ],
                );
              }

              return SizedBox(
                height: math.min(availableFileHeight, estimatedFileHeight),
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.zero,
                  itemCount: _selectedFiles.length,
                  itemBuilder: (context, index) {
                    return _buildFileRow(_selectedFiles[index], index);
                  },
                ),
              );
            }

            return SafeArea(
              child: PopupShell(
                key: const Key('gpx-import-dialog'),
                title: Text(
                  'Import GPX File(s)',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                onClose: _isImporting ? null : () => Navigator.of(context).pop(),
                closeButtonKey: const Key('gpx-import-close'),
                closeTooltip: 'Close import dialog',
                headerMeasureKey: _headerMeasureKey,
                headerPaddingKey: const Key('gpx-import-header-padding'),
                bodyPaddingKey: const Key('gpx-import-body-padding'),
                footerMeasureKey: _actionsMeasureKey,
                footerPaddingKey: const Key('gpx-import-actions-padding'),
                body: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: _bodyStaticMeasureKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FilledButton.tonal(
                            key: const Key('gpx-import-select-files'),
                            onPressed: _isImporting || _isSelectingFiles
                                ? null
                                : _selectFiles,
                            child: const Text('Select GPX Files'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            key: const Key('gpx-import-as-route'),
                            children: [
                              Expanded(
                                child: Text(
                                  'Import as Route',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              Switch(
                                value: _importAsRoute,
                                onChanged: _isImporting || _isSelectingFiles
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _importAsRoute = value;
                                          _nameErrors = {};
                                        });
                                      },
                              ),
                            ],
                          ),
                          if (_selectedFiles.isNotEmpty)
                            const SizedBox(height: 12)
                          else if (_isSelectingFiles) ...[
                            const SizedBox(height: 8),
                            const SizedBox(
                              key: Key('gpx-import-file-selection-progress'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ]
                          else ...[
                            const SizedBox(height: 8),
                            Text(
                              'No files selected',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_selectedFiles.isNotEmpty) fileSection(),
                  ],
                ),
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('gpx-import-cancel'),
                      onPressed: _isImporting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      key: const Key('gpx-import-button'),
                      onPressed: _selectedFiles.isEmpty ||
                              _isImporting ||
                              _isSelectingFiles
                          ? null
                          : _import,
                      child: _isImporting
                          ? const SizedBox(
                              key: Key('gpx-import-progress'),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Import'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _updateMeasuredChromeHeight() {
    if (!mounted) return;

    final headerHeight = _heightFor(_headerMeasureKey);
    final bodyStaticHeight = _heightFor(_bodyStaticMeasureKey);
    final actionsHeight = _heightFor(_actionsMeasureKey);
    if (headerHeight == null || bodyStaticHeight == null || actionsHeight == null) {
      return;
    }

    final measuredHeight = headerHeight + bodyStaticHeight + actionsHeight + 28;
    if (_measuredChromeHeight != null &&
        (_measuredChromeHeight! - measuredHeight).abs() < 1) {
      return;
    }

    setState(() {
      _measuredChromeHeight = measuredHeight;
    });
  }

  double? _heightFor(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.size.height;
  }

  Widget _buildFileRow(_SelectedFile file, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        key: Key('gpx-import-row-$index'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: Key('gpx-import-name-field-$index'),
              controller: file.nameController,
              enabled: !_isImporting,
              decoration: InputDecoration(
                labelText: _importAsRoute ? 'Route Name' : 'Track Name',
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
    setState(() {
      _isSelectingFiles = true;
    });

    try {
      final selected = await widget.filePicker.pickGpxFiles();
      if (!mounted || selected == null || selected.isEmpty) {
        return;
      }

      final resolvePrefilledName = widget.prefilledNameResolver ??
          _derivePrefilledName;
      final newFiles = await Future.wait(
        selected.map((path) async {
          final existingIndex = _selectedFiles.indexWhere((f) => f.path == path);
          if (existingIndex >= 0) {
            return _selectedFiles[existingIndex];
          }

          final prefilledName = await resolvePrefilledName(path);
          return _SelectedFile(
            path: path,
            nameController: TextEditingController(text: prefilledName),
          );
        }),
      );

      final newPaths = newFiles.map((file) => file.path).toSet();
      for (final file in _selectedFiles) {
        if (!newPaths.contains(file.path)) {
          file.nameController.dispose();
        }
      }

      setState(() {
        _selectedFiles.clear();
        _selectedFiles.addAll(newFiles);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSelectingFiles = false;
      });

      await _showFailureDialog(
        Navigator.of(context, rootNavigator: true).context,
        _formatPickerError(error),
      );
    } finally {
      if (mounted && _isSelectingFiles) {
        setState(() {
          _isSelectingFiles = false;
        });
      }
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
    final nameLabel = _importAsRoute ? 'route' : 'track';

    for (final file in _selectedFiles) {
      final name = file.nameController.text.trim();
      if (name.isEmpty) {
        errors[file.path] = 'A $nameLabel name is required';
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
        importAsRoute: _importAsRoute,
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
    dynamic result,
  ) {
    return showSingleActionDialog(
      context: dialogContext,
      title: 'Import Complete',
      closeKey: 'gpx-import-result-close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.addedCount} ${_importAsRoute ? 'route(s)' : 'track(s)'} added',
            key: const Key('gpx-import-summary'),
          ),
          if (result.unchangedCount > 0)
            Text('${result.unchangedCount} unchanged'),
          if (result.unsupportedCount > 0)
            Text('${result.unsupportedCount} unsupported'),
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
      closeKey: 'gpx-import-error-close',
      content: Text(error),
    );
  }
}

class _SelectedFile {
  _SelectedFile({required this.path, required this.nameController});

  final String path;
  final TextEditingController nameController;
}
