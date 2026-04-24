import 'package:flutter/material.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';

class ObjectBoxAdminDetailsPane extends StatelessWidget {
  const ObjectBoxAdminDetailsPane({
    required this.row,
    required this.entity,
    required this.isCreatingPeak,
    required this.onClose,
    required this.createOsmId,
    required this.onViewPeakOnMap,
    required this.onPeakSubmit,
    super.key,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final bool isCreatingPeak;
  final VoidCallback onClose;
  final int createOsmId;
  final void Function(Peak peak) onViewPeakOnMap;
  final Future<String?> Function(Peak peak) onPeakSubmit;

  @override
  Widget build(BuildContext context) {
    if (row == null && !isCreatingPeak) {
      return _ObjectBoxAdminReadOnlyDetailsPane(
        row: null,
        entity: entity,
        onClose: onClose,
      );
    }

    if (entity.name == 'Peak') {
      return _PeakAdminDetailsPane(
        row: row,
        entity: entity,
        createMode: isCreatingPeak,
        createOsmId: createOsmId,
        onClose: onClose,
        onViewPeakOnMap: onViewPeakOnMap,
        onPeakSubmit: onPeakSubmit,
      );
    }

    return _ObjectBoxAdminReadOnlyDetailsPane(
      row: row,
      entity: entity,
      onClose: onClose,
    );
  }
}

class _ObjectBoxAdminReadOnlyDetailsPane extends StatelessWidget {
  const _ObjectBoxAdminReadOnlyDetailsPane({
    required this.row,
    required this.entity,
    required this.onClose,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row == null
                        ? 'Details'
                        : '${entity.displayName} #${objectBoxAdminFormatValue(row!.primaryKeyValue)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  onPressed: row == null ? null : onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            if (row == null)
              const Expanded(
                child: Center(
                  child: Text('Select a row to inspect full values.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  key: const Key('objectbox-admin-details-list'),
                  itemCount: entity.fields.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final field = entity.fields[index];
                    final selectedRow = row!;
                    return ListTile(
                      dense: true,
                      title: Text(field.name),
                      subtitle: SelectableText(
                        objectBoxAdminFormatValue(
                          selectedRow.values[field.name],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PeakAdminDetailsPane extends StatefulWidget {
  const _PeakAdminDetailsPane({
    required this.row,
    required this.entity,
    required this.createMode,
    required this.createOsmId,
    required this.onClose,
    required this.onViewPeakOnMap,
    required this.onPeakSubmit,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final bool createMode;
  final int createOsmId;
  final VoidCallback onClose;
  final void Function(Peak peak) onViewPeakOnMap;
  final Future<String?> Function(Peak peak) onPeakSubmit;

  @override
  State<_PeakAdminDetailsPane> createState() => _PeakAdminDetailsPaneState();
}

class _PeakAdminDetailsPaneState extends State<_PeakAdminDetailsPane> {
  late Peak _peak;
  late final TextEditingController _nameController;
  late final TextEditingController _osmIdController;
  late final TextEditingController _elevationController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _areaController;
  late final TextEditingController _mgrs100kIdController;
  late final TextEditingController _eastingController;
  late final TextEditingController _northingController;
  late final TextEditingController _gridZoneDesignatorController;
  late String _sourceOfTruth;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _submitError;
  PeakAdminValidationResult _validation = const PeakAdminValidationResult(
    fieldErrors: {},
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _osmIdController = TextEditingController();
    _elevationController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _areaController = TextEditingController();
    _mgrs100kIdController = TextEditingController();
    _eastingController = TextEditingController();
    _northingController = TextEditingController();
    _gridZoneDesignatorController = TextEditingController();
    _syncFromRow();
  }

  @override
  void didUpdateWidget(covariant _PeakAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row ||
        oldWidget.createMode != widget.createMode ||
        oldWidget.createOsmId != widget.createOsmId) {
      _syncFromRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _osmIdController.dispose();
    _elevationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _areaController.dispose();
    _mgrs100kIdController.dispose();
    _eastingController.dispose();
    _northingController.dispose();
    _gridZoneDesignatorController.dispose();
    super.dispose();
  }

  void _syncFromRow() {
    if (widget.createMode) {
      _peak = Peak(
        name: '',
        latitude: 0,
        longitude: 0,
        gridZoneDesignator: PeakAdminEditor.fixedGridZoneDesignator,
      );
      _nameController.clear();
      _osmIdController.text = widget.createOsmId.toString();
      _elevationController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _areaController.clear();
      _mgrs100kIdController.clear();
      _eastingController.clear();
      _northingController.clear();
      _gridZoneDesignatorController.text =
          PeakAdminEditor.fixedGridZoneDesignator;
      _sourceOfTruth = Peak.sourceOfTruthOsm;
      _isEditing = true;
    } else {
      _peak = _peakFromRow(widget.row!);
      final form = PeakAdminEditor.normalize(_peak);
      _nameController.text = form.name;
      _osmIdController.text = form.osmId;
      _elevationController.text = form.elevation;
      _latitudeController.text = form.latitude;
      _longitudeController.text = form.longitude;
      _areaController.text = form.area;
      _mgrs100kIdController.text = form.mgrs100kId;
      _eastingController.text = form.easting;
      _northingController.text = form.northing;
      _gridZoneDesignatorController.text = form.gridZoneDesignator;
      _sourceOfTruth = form.sourceOfTruth;
      _isEditing = false;
    }
    _isSaving = false;
    _submitError = null;
    _validation = const PeakAdminValidationResult(fieldErrors: {});
  }

  Peak _peakFromRow(ObjectBoxAdminRow row) {
    final values = row.values;
    return Peak(
      id: (values['id'] as int?) ?? (row.primaryKeyValue as int? ?? 0),
      osmId: (values['osmId'] as int?) ?? 0,
      name: '${values['name'] ?? ''}',
      elevation: _doubleValue(values['elevation']),
      latitude: _doubleValue(values['latitude']) ?? 0,
      longitude: _doubleValue(values['longitude']) ?? 0,
      area: values['area']?.toString(),
      gridZoneDesignator:
          '${values['gridZoneDesignator'] ?? PeakAdminEditor.fixedGridZoneDesignator}',
      mgrs100kId: '${values['mgrs100kId'] ?? ''}',
      easting: '${values['easting'] ?? ''}',
      northing: '${values['northing'] ?? ''}',
      sourceOfTruth: '${values['sourceOfTruth'] ?? Peak.sourceOfTruthOsm}',
    );
  }

  double? _doubleValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _submitError = null;
      _validation = const PeakAdminValidationResult(fieldErrors: {});
    });
  }

  void _markAsHwc() {
    setState(() {
      _sourceOfTruth = Peak.sourceOfTruthHwc;
    });
  }

  Peak _peakForMainMap() {
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
    );
    return validation.peak ?? _peak;
  }

  PeakAdminFormState _currentFormState() {
    return PeakAdminFormState(
      name: _nameController.text,
      osmId: _osmIdController.text,
      elevation: _elevationController.text,
      latitude: _latitudeController.text,
      longitude: _longitudeController.text,
      area: _areaController.text,
      gridZoneDesignator: _gridZoneDesignatorController.text,
      mgrs100kId: _mgrs100kIdController.text,
      easting: _eastingController.text,
      northing: _northingController.text,
      sourceOfTruth: _sourceOfTruth,
    );
  }

  void _updateValidation() {
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
    );
    setState(() {
      _validation = validation;
      if (_submitError != null) {
        _submitError = null;
      }
    });
  }

  Future<void> _submit() async {
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
    );

    setState(() {
      _validation = validation;
      _submitError = null;
    });

    if (!validation.isValid) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final error = await widget.onPeakSubmit(validation.peak!);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (error == null) {
        _isEditing = false;
        _submitError = null;
      } else {
        _submitError = error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.createMode
                        ? 'Add Peak'
                        : 'Peak #${objectBoxAdminFormatValue(widget.row!.primaryKeyValue)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!widget.createMode)
                  IconButton(
                    key: const Key('objectbox-admin-peak-view-on-map'),
                    tooltip: 'View Peak on Main Map',
                    onPressed: _isSaving
                        ? null
                        : () => widget.onViewPeakOnMap(_peakForMainMap()),
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                if (!_isEditing && !widget.createMode)
                  IconButton(
                    key: const Key('objectbox-admin-peak-edit'),
                    onPressed: _isSaving ? null : _startEditing,
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  onPressed: _isSaving ? null : widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _isEditing
                  ? _PeakEditForm(
                      isSaving: _isSaving,
                      nameController: _nameController,
                      osmIdController: _osmIdController,
                      elevationController: _elevationController,
                      latitudeController: _latitudeController,
                      longitudeController: _longitudeController,
                      areaController: _areaController,
                      gridZoneDesignatorController:
                          _gridZoneDesignatorController,
                      mgrs100kIdController: _mgrs100kIdController,
                      eastingController: _eastingController,
                      northingController: _northingController,
                      sourceOfTruth: _sourceOfTruth,
                      peakIdText: _peak.id.toString(),
                      submitError: _submitError,
                      validation: _validation,
                      onChanged: _updateValidation,
                      onMarkAsHwc: _markAsHwc,
                      onSubmit: _submit,
                    )
                  : _PeakReadOnlyDetails(
                      row: widget.row!,
                      entity: widget.entity,
                      sourceOfTruth: _sourceOfTruth,
                      onMarkAsHwc: _markAsHwc,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakReadOnlyDetails extends StatelessWidget {
  const _PeakReadOnlyDetails({
    required this.row,
    required this.entity,
    required this.sourceOfTruth,
    required this.onMarkAsHwc,
  });

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminEntityDescriptor entity;
  final String sourceOfTruth;
  final VoidCallback onMarkAsHwc;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ...entity.fields.map((field) {
          final value = objectBoxAdminFormatValue(row.values[field.name]);
          final isEditable =
              !field.isPrimaryKey && field.name != 'gridZoneDesignator';
          final isSourceOfTruth = field.name == 'sourceOfTruth';
          final title = field.name == 'sourceOfTruth'
              ? 'sourceOfTruth'
              : field.name;
          return ListTile(
            dense: true,
            title: Text(title),
            subtitle: SelectableText(value),
            trailing: isSourceOfTruth
                ? TextButton(
                    key: const Key('objectbox-admin-peak-source-of-truth'),
                    onPressed: onMarkAsHwc,
                    child: const Text('Mark as HWC'),
                  )
                : isEditable
                ? null
                : Text(value),
          );
        }),
      ],
    );
  }
}

class _PeakEditForm extends StatelessWidget {
  const _PeakEditForm({
    required this.isSaving,
    required this.nameController,
    required this.osmIdController,
    required this.elevationController,
    required this.latitudeController,
    required this.longitudeController,
    required this.areaController,
    required this.gridZoneDesignatorController,
    required this.mgrs100kIdController,
    required this.eastingController,
    required this.northingController,
    required this.sourceOfTruth,
    required this.peakIdText,
    required this.submitError,
    required this.validation,
    required this.onChanged,
    required this.onMarkAsHwc,
    required this.onSubmit,
  });

  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController osmIdController;
  final TextEditingController elevationController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController areaController;
  final TextEditingController gridZoneDesignatorController;
  final TextEditingController mgrs100kIdController;
  final TextEditingController eastingController;
  final TextEditingController northingController;
  final String sourceOfTruth;
  final String peakIdText;
  final String? submitError;
  final PeakAdminValidationResult validation;
  final VoidCallback onChanged;
  final VoidCallback onMarkAsHwc;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              _buildReadOnlyField(
                context,
                label: 'id',
                value: peakIdText,
                keyName: 'objectbox-admin-peak-id',
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-name'),
                controller: nameController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['name'],
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-osm-id'),
                controller: osmIdController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'osmId',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['osmId'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-elevation'),
                controller: elevationController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Elevation',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['elevation'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-latitude'),
                controller: latitudeController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['latitude'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-longitude'),
                controller: longitudeController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['longitude'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-area'),
                controller: areaController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Area',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              _buildReadOnlyField(
                context,
                label: 'gridZoneDesignator',
                value: gridZoneDesignatorController.text,
                keyName: 'objectbox-admin-peak-grid-zone-designator',
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-mgrs100k-id'),
                controller: mgrs100kIdController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'MGRS 100km identifier',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['mgrs100kId'],
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-easting'),
                controller: eastingController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Easting',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['easting'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('objectbox-admin-peak-northing'),
                controller: northingController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Northing',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['northing'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Source of truth: $sourceOfTruth',
                      key: const Key(
                        'objectbox-admin-peak-source-of-truth-label',
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('objectbox-admin-peak-source-of-truth'),
                    onPressed: isSaving ? null : onMarkAsHwc,
                    child: const Text('Mark as HWC'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (validation.coordinateError != null) ...[
          const SizedBox(height: 8),
          Text(
            validation.coordinateError!,
            style: TextStyle(color: errorColor),
          ),
        ],
        if (submitError != null) ...[
          const SizedBox(height: 8),
          Text(submitError!, style: TextStyle(color: errorColor)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('objectbox-admin-peak-submit'),
          onPressed: isSaving ? null : onSubmit,
          child: Text(isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(
    BuildContext context, {
    required String label,
    required String value,
    required String keyName,
  }) {
    return TextFormField(
      key: Key(keyName),
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
