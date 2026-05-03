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
                    final value = selectedRow.values[field.name];
                    return ListTile(
                      dense: true,
                      title: Text(field.name),
                      subtitle: objectBoxAdminDetailsValue(
                        entityName: entity.name,
                        fieldName: field.name,
                        label: field.name,
                        value: value,
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
  late final TextEditingController _altNameController;
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
  bool _verified = false;
  bool _isEditing = false;
  bool _isSaving = false;
  PeakAdminCoordinateSource? _activeCoordinateSource;
  String? _submitError;
  PeakAdminValidationResult _validation = const PeakAdminValidationResult(
    fieldErrors: {},
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _altNameController = TextEditingController();
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
    _altNameController.dispose();
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
      _altNameController.clear();
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
      _verified = false;
      _isEditing = true;
    } else {
      _peak = peakFromAdminRow(widget.row!);
      final form = PeakAdminEditor.normalize(_peak);
      _nameController.text = form.name;
      _altNameController.text = form.altName;
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
      _verified = form.verified;
      _isEditing = false;
    }
    _isSaving = false;
    _activeCoordinateSource = null;
    _submitError = null;
    _validation = const PeakAdminValidationResult(fieldErrors: {});
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _activeCoordinateSource = null;
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
      coordinateSource: _activeCoordinateSource,
    );
    return validation.peak ?? _peak;
  }

  PeakAdminFormState _currentFormState() {
    return PeakAdminFormState(
      name: _nameController.text,
      altName: _altNameController.text,
      osmId: _osmIdController.text,
      elevation: _elevationController.text,
      latitude: _latitudeController.text,
      longitude: _longitudeController.text,
      area: _areaController.text,
      gridZoneDesignator: _gridZoneDesignatorController.text,
      mgrs100kId: _mgrs100kIdController.text,
      easting: _eastingController.text,
      northing: _northingController.text,
      verified: _verified,
      sourceOfTruth: _sourceOfTruth,
    );
  }

  void _setVerified(bool? value) {
    setState(() {
      _verified = value ?? false;
    });
    _updateValidation();
  }

  void _updateValidation() {
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
      coordinateSource: _activeCoordinateSource,
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
      coordinateSource: _activeCoordinateSource,
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

  void _handleLatLngChanged() {
    final form = _currentFormState();
    final shouldClear =
        _activeCoordinateSource != PeakAdminCoordinateSource.latLng;
    if (shouldClear) {
      _mgrs100kIdController.clear();
      _eastingController.clear();
      _northingController.clear();
    }

    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: shouldClear
          ? form.copyWith(mgrs100kId: '', easting: '', northing: '')
          : form,
      coordinateSource: PeakAdminCoordinateSource.latLng,
    );
    setState(() {
      _activeCoordinateSource = PeakAdminCoordinateSource.latLng;
      _validation = validation;
      if (_submitError != null) {
        _submitError = null;
      }
    });
  }

  void _handleMgrsChanged() {
    final form = _currentFormState();
    final shouldClear =
        _activeCoordinateSource != PeakAdminCoordinateSource.mgrs;
    if (shouldClear) {
      _latitudeController.clear();
      _longitudeController.clear();
    }

    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: shouldClear ? form.copyWith(latitude: '', longitude: '') : form,
      coordinateSource: PeakAdminCoordinateSource.mgrs,
    );
    setState(() {
      _activeCoordinateSource = PeakAdminCoordinateSource.mgrs;
      _validation = validation;
      if (_submitError != null) {
        _submitError = null;
      }
    });
  }

  void _calculateCoordinates() {
    final coordinateSource = _activeCoordinateSource;
    if (coordinateSource == null || _isSaving) {
      return;
    }

    final result = PeakAdminEditor.calculateMissingCoordinates(
      source: coordinateSource,
      form: _currentFormState(),
    );
    if (!result.isValid) {
      setState(() {
        _validation = PeakAdminValidationResult(
          fieldErrors: result.fieldErrors,
          coordinateError: result.coordinateError,
        );
        if (_submitError != null) {
          _submitError = null;
        }
      });
      return;
    }

    final form = result.form!;
    _latitudeController.text = form.latitude;
    _longitudeController.text = form.longitude;
    _mgrs100kIdController.text = form.mgrs100kId;
    _eastingController.text = form.easting;
    _northingController.text = form.northing;

    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
      coordinateSource: coordinateSource,
    );
    setState(() {
      _validation = validation;
      if (_submitError != null) {
        _submitError = null;
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
                      altNameController: _altNameController,
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
                      verified: _verified,
                      sourceOfTruth: _sourceOfTruth,
                      peakIdText: _peak.id.toString(),
                      submitError: _submitError,
                      validation: _validation,
                      onChanged: _updateValidation,
                      onLatLngChanged: _handleLatLngChanged,
                      onMgrsChanged: _handleMgrsChanged,
                      onVerifiedChanged: _setVerified,
                      onMarkAsHwc: _markAsHwc,
                      onCalculate: _calculateCoordinates,
                      canCalculate: _activeCoordinateSource != null,
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
    final detailsFields = peakAdminDetailsFields(entity);
    return ListView(
      children: [
        ...detailsFields.map((field) {
          final isSourceOfTruth = field.name == 'sourceOfTruth';
          final title = field.name == 'sourceOfTruth'
              ? 'sourceOfTruth'
              : field.name;
          return ListTile(
            dense: true,
            title: Text(title),
            subtitle: objectBoxAdminDetailsValue(
              entityName: row.values.containsKey(field.name)
                  ? entity.name
                  : null,
              fieldName: field.name,
              label: title,
              value: row.values[field.name],
            ),
            trailing: isSourceOfTruth
                ? TextButton(
                    key: const Key('objectbox-admin-peak-source-of-truth'),
                    onPressed: onMarkAsHwc,
                    child: const Text('Mark as HWC'),
                  )
                : null,
          );
        }),
      ],
    );
  }
}

Widget objectBoxAdminDetailsValue({
  String? entityName,
  String? fieldName,
  required String label,
  required Object? value,
}) {
  if (value is bool) {
    return ObjectBoxAdminDetailsValue(label: label, value: value);
  }

  if (entityName != null && fieldName != null) {
    return SelectableText(
      objectBoxAdminFormatFieldValue(
        entityName: entityName,
        fieldName: fieldName,
        value: value,
      ),
    );
  }

  return SelectableText(objectBoxAdminFormatValue(value));
}

class ObjectBoxAdminDetailsValue extends StatelessWidget {
  const ObjectBoxAdminDetailsValue({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final rawValue = value as bool;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: label,
        checked: rawValue,
        enabled: false,
        child: ExcludeSemantics(
          child: Checkbox(value: rawValue, onChanged: null),
        ),
      ),
    );
  }
}

class _PeakEditForm extends StatelessWidget {
  const _PeakEditForm({
    required this.isSaving,
    required this.nameController,
    required this.altNameController,
    required this.osmIdController,
    required this.elevationController,
    required this.latitudeController,
    required this.longitudeController,
    required this.areaController,
    required this.gridZoneDesignatorController,
    required this.mgrs100kIdController,
    required this.eastingController,
    required this.northingController,
    required this.verified,
    required this.sourceOfTruth,
    required this.peakIdText,
    required this.submitError,
    required this.validation,
    required this.onChanged,
    required this.onLatLngChanged,
    required this.onMgrsChanged,
    required this.onVerifiedChanged,
    required this.onMarkAsHwc,
    required this.onCalculate,
    required this.canCalculate,
    required this.onSubmit,
  });

  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController altNameController;
  final TextEditingController osmIdController;
  final TextEditingController elevationController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController areaController;
  final TextEditingController gridZoneDesignatorController;
  final TextEditingController mgrs100kIdController;
  final TextEditingController eastingController;
  final TextEditingController northingController;
  final bool verified;
  final String sourceOfTruth;
  final String peakIdText;
  final String? submitError;
  final PeakAdminValidationResult validation;
  final VoidCallback onChanged;
  final VoidCallback onLatLngChanged;
  final VoidCallback onMgrsChanged;
  final ValueChanged<bool?> onVerifiedChanged;
  final VoidCallback onMarkAsHwc;
  final VoidCallback onCalculate;
  final bool canCalculate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const Key('objectbox-admin-peak-edit-form'),
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
                key: const Key('objectbox-admin-peak-alt-name'),
                controller: altNameController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Alt Name',
                  border: const OutlineInputBorder(),
                  errorText: validation.fieldErrors['altName'],
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
                onChanged: (_) => onLatLngChanged(),
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
                onChanged: (_) => onLatLngChanged(),
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
                onChanged: (_) => onMgrsChanged(),
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
                onChanged: (_) => onMgrsChanged(),
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
                onChanged: (_) => onMgrsChanged(),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const Key('objectbox-admin-peak-verified'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Verified'),
                value: verified,
                onChanged: isSaving ? null : onVerifiedChanged,
                controlAffinity: ListTileControlAffinity.leading,
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
        FilledButton.tonal(
          key: const Key('objectbox-admin-peak-calculate'),
          onPressed: isSaving || !canCalculate ? null : onCalculate,
          child: const Text('Calculate'),
        ),
        const SizedBox(height: 8),
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
