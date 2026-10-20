import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';
import 'package:peak_bagger/services/natural_feature_admin_editor.dart';
import 'package:peak_bagger/services/peak_list_admin_editor.dart';
import 'package:peak_bagger/services/route_admin_editor.dart';
import 'package:peak_bagger/services/contact_admin_editor.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';
import 'package:peak_bagger/widgets/objectbox_admin_form_field.dart';
import 'package:peak_bagger/services/objectbox_admin_field_policy.dart';
import 'package:peak_bagger/widgets/objectbox_admin_edit_footer.dart';
import 'package:peak_bagger/widgets/objectbox_admin_save_scope.dart';

// Local state also protects standalone panes and callbacks retained before a
// rebuild. The routed screen owns the app-visible Save/navigation lifetime.
mixin _AdminSaveState<W extends StatefulWidget> on State<W> {
  bool _localSavePending = false;
  bool get _isSaving =>
      _localSavePending || ObjectBoxAdminSaveScope.read(context);
  set _isSaving(bool value) => _localSavePending = value;

  Future<String?> _awaitSave(Future<String?> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      logObjectBoxAdminError(error, stackTrace, 'Admin Save failed');
      return 'Could not save. Please retry or cancel.';
    }
  }
}

class _AdminDetailsDivider extends StatelessWidget {
  const _AdminDetailsDivider({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(
          theme.colorScheme,
          theme.textTheme,
          seedColor: theme.seedColor,
        );
    return Divider(
      height: height,
      thickness: grid.dividerThickness,
      color: grid.dividerColor,
    );
  }
}

class ObjectBoxAdminDetailsPane extends StatelessWidget {
  const ObjectBoxAdminDetailsPane({
    required this.row,
    required this.entity,
    required this.peakList,
    required this.route,
    required this.naturalFeature,
    this.contact,
    required this.isCreatingPeak,
    this.isCreatingContact = false,
    required this.isNaturalFeatureMutationLocked,
    required this.onClose,
    required this.createOsmId,
    required this.onViewPeakOnMap,
    required this.onViewNaturalFeatureOnMap,
    required this.onViewGpxTrackOnMap,
    required this.onViewRouteOnMap,
    required this.onPeakSubmit,
    required this.onPeakListSubmit,
    required this.onRouteSubmit,
    required this.onNaturalFeatureSubmit,
    this.onContactSubmit,
    super.key,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final PeakList? peakList;
  final app_route.Route? route;
  final NaturalFeature? naturalFeature;
  final Contact? contact;
  final bool isCreatingPeak;
  final bool isCreatingContact;
  final bool isNaturalFeatureMutationLocked;
  final VoidCallback onClose;
  final int createOsmId;
  final void Function(Peak peak) onViewPeakOnMap;
  final void Function(NaturalFeature naturalFeature) onViewNaturalFeatureOnMap;
  final void Function(ObjectBoxAdminRow row)? onViewGpxTrackOnMap;
  final void Function(app_route.Route route)? onViewRouteOnMap;
  final Future<String?> Function(Peak peak) onPeakSubmit;
  final Future<String?> Function(PeakListAdminFormState form) onPeakListSubmit;
  final Future<String?> Function(RouteAdminFormState form) onRouteSubmit;
  final Future<String?> Function(NaturalFeature feature) onNaturalFeatureSubmit;
  final Future<String?> Function(Contact contact)? onContactSubmit;

  @override
  Widget build(BuildContext context) {
    if (row == null && !isCreatingPeak && !isCreatingContact) {
      return _ObjectBoxAdminReadOnlyDetailsPane(
        row: null,
        entity: entity,
        onClose: onClose,
      );
    }

    if (entity.name == 'Peak') {
      return _PeakAdminDetailsPane(
        key: ValueKey((
          'Peak',
          row?.primaryKeyValue,
          isCreatingPeak,
          isCreatingPeak ? createOsmId : null,
        )),
        row: row,
        entity: entity,
        createMode: isCreatingPeak,
        createOsmId: createOsmId,
        onClose: onClose,
        onViewPeakOnMap: onViewPeakOnMap,
        onPeakSubmit: onPeakSubmit,
      );
    }

    if (entity.name == 'NaturalFeature' && naturalFeature != null) {
      return _NaturalFeatureAdminDetailsPane(
        key: ValueKey(('NaturalFeature', row!.primaryKeyValue)),
        row: row!,
        entity: entity,
        naturalFeature: naturalFeature!,
        mutationLocked: isNaturalFeatureMutationLocked,
        onClose: onClose,
        onViewNaturalFeatureOnMap: onViewNaturalFeatureOnMap,
        onNaturalFeatureSubmit: onNaturalFeatureSubmit,
      );
    }

    if (entity.name == 'Contact' && (contact != null || isCreatingContact)) {
      return _ContactAdminDetailsPane(
        key: ValueKey(('Contact', contact?.id, isCreatingContact)),
        entity: entity,
        contact: contact ?? Contact(),
        createMode: isCreatingContact,
        onClose: onClose,
        onContactSubmit: onContactSubmit!,
      );
    }

    if (entity.name == 'Route' && route != null) {
      return _RouteAdminDetailsPane(
        key: ValueKey(('Route', route!.id)),
        row: row,
        entity: entity,
        route: route!,
        onClose: onClose,
        onViewRouteOnMap: onViewRouteOnMap == null
            ? null
            : () => onViewRouteOnMap!(route!),
        onRouteSubmit: onRouteSubmit,
      );
    }

    if (entity.name == 'PeakList' && peakList != null) {
      return _PeakListAdminDetailsPane(
        key: ValueKey(('PeakList', peakList!.peakListId)),
        row: row,
        entity: entity,
        peakList: peakList!,
        onClose: onClose,
        onPeakListSubmit: onPeakListSubmit,
      );
    }

    return _ObjectBoxAdminReadOnlyDetailsPane(
      row: row,
      entity: entity,
      onClose: onClose,
      onViewGpxTrackOnMap: row == null || onViewGpxTrackOnMap == null
          ? null
          : () {
              final selectedRow = row!;
              onViewGpxTrackOnMap!(selectedRow);
            },
    );
  }
}

class _ObjectBoxAdminReadOnlyDetailsPane extends StatelessWidget {
  const _ObjectBoxAdminReadOnlyDetailsPane({
    required this.row,
    required this.entity,
    required this.onClose,
    this.onViewGpxTrackOnMap,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final VoidCallback onClose;
  final VoidCallback? onViewGpxTrackOnMap;

  @override
  Widget build(BuildContext context) {
    final title = _objectBoxAdminDetailsTitle(entity, row);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey(('title', entity.name, row?.primaryKeyValue)),
                    label: entity.primaryNameField,
                    text: row == null ? 'Details' : title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (entity.name == 'GpxTrack' && onViewGpxTrackOnMap != null)
                  IconButton(
                    key: const Key('objectbox-admin-gpx-track-view-on-map'),
                    tooltip: 'View Track on Main Map',
                    onPressed: onViewGpxTrackOnMap,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: row == null ? null : onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            if (row == null)
              const Expanded(
                child: Center(
                  child: Text('Select a row to inspect full values.'),
                ),
              )
            else
              Expanded(
                child: Builder(
                  builder: (context) {
                    final detailsFields = _objectBoxAdminDetailsFields(entity);
                    return ListView.separated(
                      key: const Key('objectbox-admin-details-list'),
                      itemCount: detailsFields.length,
                      separatorBuilder: (context, index) =>
                          const _AdminDetailsDivider(height: 1),
                      itemBuilder: (context, index) {
                        final field = detailsFields[index];
                        final selectedRow = row!;
                        final value = selectedRow.values[field.name];
                        return ListTile(
                          dense: true,
                          title: Text(field.name),
                          subtitle: objectBoxAdminDetailsValue(
                            recordId: selectedRow.primaryKeyValue,
                            entityName: entity.name,
                            fieldName: field.name,
                            label: field.name,
                            value: value,
                          ),
                        );
                      },
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
    super.key,
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

class _PeakAdminDetailsPaneState extends State<_PeakAdminDetailsPane>
    with _AdminSaveState<_PeakAdminDetailsPane> {
  late Peak _peak;
  late final TextEditingController _nameController;
  late final TextEditingController _altNameController;
  late final TextEditingController _osmIdController;
  late final TextEditingController _peakbaggerPidController;
  late final TextEditingController _elevationController;
  late final TextEditingController _prominenceController;
  late final TextEditingController _countryController;
  late final TextEditingController _countyController;
  late final TextEditingController _rangeController;
  late final TextEditingController _ratingController;
  late final TextEditingController _durationController;
  late final TextEditingController _difficultyController;
  late final TextEditingController _viaFerrataController;
  late final TextEditingController _notesController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _regionController;
  late final TextEditingController _mgrs100kIdController;
  late final TextEditingController _eastingController;
  late final TextEditingController _northingController;
  late String _gridZoneDesignator;
  late String _sourceOfTruth;
  bool _verified = false;
  bool _isEditing = false;
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
    _peakbaggerPidController = TextEditingController();
    _elevationController = TextEditingController();
    _prominenceController = TextEditingController();
    _countryController = TextEditingController();
    _countyController = TextEditingController();
    _rangeController = TextEditingController();
    _ratingController = TextEditingController();
    _durationController = TextEditingController();
    _difficultyController = TextEditingController();
    _viaFerrataController = TextEditingController();
    _notesController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _regionController = TextEditingController();
    _mgrs100kIdController = TextEditingController();
    _eastingController = TextEditingController();
    _northingController = TextEditingController();
    _syncFromRow();
  }

  @override
  void didUpdateWidget(covariant _PeakAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving &&
        (oldWidget.row != widget.row ||
            oldWidget.createMode != widget.createMode ||
            oldWidget.createOsmId != widget.createOsmId)) {
      _syncFromRow();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _altNameController.dispose();
    _osmIdController.dispose();
    _peakbaggerPidController.dispose();
    _elevationController.dispose();
    _prominenceController.dispose();
    _countryController.dispose();
    _countyController.dispose();
    _rangeController.dispose();
    _ratingController.dispose();
    _durationController.dispose();
    _difficultyController.dispose();
    _viaFerrataController.dispose();
    _notesController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _regionController.dispose();
    _mgrs100kIdController.dispose();
    _eastingController.dispose();
    _northingController.dispose();
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
      _peakbaggerPidController.clear();
      _elevationController.clear();
      _prominenceController.clear();
      _countryController.clear();
      _countyController.clear();
      _rangeController.clear();
      _ratingController.clear();
      _durationController.clear();
      _difficultyController.clear();
      _viaFerrataController.clear();
      _notesController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _regionController.clear();
      _mgrs100kIdController.clear();
      _eastingController.clear();
      _northingController.clear();
      _gridZoneDesignator = PeakAdminEditor.fixedGridZoneDesignator;
      _sourceOfTruth = Peak.sourceOfTruthOsm;
      _verified = false;
      _isEditing = true;
      _activeCoordinateSource = null;
    } else {
      _peak = peakFromAdminRow(widget.row!);
      final form = PeakAdminEditor.normalize(_peak);
      _nameController.text = form.name;
      _altNameController.text = form.altName;
      _osmIdController.text = form.osmId;
      _peakbaggerPidController.text = form.peakbaggerPid;
      _elevationController.text = form.elevation;
      _prominenceController.text = form.prominence;
      _countryController.text = form.country;
      _countyController.text = form.county;
      _rangeController.text = form.range;
      _ratingController.text = form.rating;
      _durationController.text = form.durationLabel;
      _difficultyController.text = form.difficulty;
      _viaFerrataController.text = form.viaFerrata;
      _notesController.text = form.notes;
      _latitudeController.text = form.latitude;
      _longitudeController.text = form.longitude;
      _regionController.text = form.region;
      _mgrs100kIdController.text = form.mgrs100kId;
      _eastingController.text = form.easting;
      _northingController.text = form.northing;
      _gridZoneDesignator = form.gridZoneDesignator;
      _sourceOfTruth = form.sourceOfTruth;
      _verified = form.verified;
      _isEditing = false;
      _activeCoordinateSource = null;
    }
    _submitError = null;
    _validation = const PeakAdminValidationResult(fieldErrors: {});
  }

  void _startEditing() {
    if (!mounted || _isSaving) return;
    setState(() {
      _isEditing = true;
      _activeCoordinateSource = null;
      _submitError = null;
      _validation = const PeakAdminValidationResult(fieldErrors: {});
    });
  }

  void _markAsHwc() {
    if (!mounted || _isSaving) return;
    setState(() {
      _sourceOfTruth = Peak.sourceOfTruthHwc;
    });
  }

  Peak _peakForMainMap() {
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
      coordinateSource: _effectiveSubmitCoordinateSource(),
    );
    return validation.peak ?? _peak;
  }

  PeakAdminFormState _currentFormState() {
    return PeakAdminFormState(
      name: _nameController.text,
      altName: _altNameController.text,
      osmId: _osmIdController.text,
      peakbaggerPid: _peakbaggerPidController.text,
      elevation: _elevationController.text,
      prominence: _prominenceController.text,
      country: _countryController.text,
      county: _countyController.text,
      range: _rangeController.text,
      rating: _ratingController.text,
      durationLabel: _durationController.text,
      difficulty: _difficultyController.text,
      viaFerrata: _viaFerrataController.text,
      notes: _notesController.text,
      latitude: _latitudeController.text,
      longitude: _longitudeController.text,
      region: _regionController.text,
      gridZoneDesignator: _gridZoneDesignator,
      mgrs100kId: _mgrs100kIdController.text,
      easting: _eastingController.text,
      northing: _northingController.text,
      verified: _verified,
      sourceOfTruth: _sourceOfTruth,
    );
  }

  void _setVerified(bool? value) {
    if (!mounted || _isSaving) return;
    setState(() {
      _verified = value ?? false;
    });
    _updateValidation();
  }

  void _updateValidation() {
    if (!mounted || _isSaving) return;
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
    if (!mounted || _isSaving || !_isEditing) return;
    final validation = PeakAdminEditor.validateAndBuild(
      source: _peak,
      form: _currentFormState(),
      coordinateSource: _effectiveSubmitCoordinateSource(),
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

    final error = await _awaitSave(() => widget.onPeakSubmit(validation.peak!));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (error == null) {
        if (!widget.createMode) _syncFromRow();
        _isEditing = false;
        _submitError = null;
      } else {
        _submitError = error;
      }
    });
  }

  PeakAdminCoordinateSource? _effectiveSubmitCoordinateSource() {
    return _activeCoordinateSource ??
        (widget.createMode ? null : PeakAdminCoordinateSource.latLng);
  }

  void _handleLatLngChanged() {
    if (!mounted || _isSaving) return;
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
    if (!mounted || _isSaving) return;
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
    if (!mounted) return;
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

  void _close() {
    if (!mounted || _isSaving) return;
    widget.onClose();
  }

  void _cancelEditing() {
    if (!mounted || _isSaving || !_isEditing) return;
    if (widget.createMode) {
      widget.onClose();
    } else {
      setState(_syncFromRow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.createMode
        ? 'Add Peak'
        : (_peak.name.trim().isNotEmpty
              ? _peak.name.trim()
              : _objectBoxAdminDetailsTitle(widget.entity, widget.row!));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey((
                      'title',
                      widget.entity.name,
                      widget.row?.primaryKeyValue,
                    )),
                    label: widget.entity.primaryNameField,
                    text: title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!widget.createMode)
                  IconButton(
                    key: const Key('objectbox-admin-peak-view-on-map'),
                    tooltip: 'View Peak on Main Map',
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (!mounted || _isSaving) return;
                            widget.onViewPeakOnMap(_peakForMainMap());
                          },
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                if (!_isEditing && !widget.createMode)
                  IconButton(
                    key: const Key('objectbox-admin-peak-edit'),
                    tooltip: 'Edit',
                    onPressed: _isSaving ? null : _startEditing,
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            Expanded(
              child: _isEditing
                  ? _PeakEditForm(
                      entity: widget.entity,
                      recordId: _peak.id,
                      isSaving: _isSaving,
                      nameController: _nameController,
                      altNameController: _altNameController,
                      osmIdController: _osmIdController,
                      peakbaggerPidController: _peakbaggerPidController,
                      elevationController: _elevationController,
                      prominenceController: _prominenceController,
                      countryController: _countryController,
                      countyController: _countyController,
                      rangeController: _rangeController,
                      ratingController: _ratingController,
                      durationController: _durationController,
                      difficultyController: _difficultyController,
                      viaFerrataController: _viaFerrataController,
                      notesController: _notesController,
                      latitudeController: _latitudeController,
                      longitudeController: _longitudeController,
                      regionController: _regionController,
                      gridZoneDesignator: _gridZoneDesignator,
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
                      onCancel: _cancelEditing,
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
      key: const Key('objectbox-admin-details-list'),
      children: [
        ...detailsFields.map((field) {
          final isSourceOfTruth = field.name == 'sourceOfTruth';
          final title = field.name == 'sourceOfTruth'
              ? 'sourceOfTruth'
              : field.name;
          return ListTile(
            key: Key('objectbox-admin-peak-details-${field.name}'),
            dense: true,
            title: Text(title),
            subtitle: objectBoxAdminDetailsValue(
              recordId: row.primaryKeyValue,
              entityName: row.values.containsKey(field.name)
                  ? entity.name
                  : null,
              fieldName: field.name,
              label: title,
              value: row.values[field.name],
            ),
            trailing: isSourceOfTruth
                ? FilledButton(
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

List<ObjectBoxAdminFieldDescriptor> _objectBoxAdminDetailsFields(
  ObjectBoxAdminEntityDescriptor entity,
) {
  return entity.fields
      .where((field) => field.name != entity.primaryNameField)
      .toList(growable: false);
}

class _RouteAdminDetailsPane extends StatefulWidget {
  const _RouteAdminDetailsPane({
    super.key,
    required this.row,
    required this.entity,
    required this.route,
    required this.onClose,
    required this.onViewRouteOnMap,
    required this.onRouteSubmit,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final app_route.Route route;
  final VoidCallback onClose;
  final VoidCallback? onViewRouteOnMap;
  final Future<String?> Function(RouteAdminFormState form) onRouteSubmit;

  @override
  State<_RouteAdminDetailsPane> createState() => _RouteAdminDetailsPaneState();
}

class _RouteAdminDetailsPaneState extends State<_RouteAdminDetailsPane>
    with _AdminSaveState<_RouteAdminDetailsPane> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _colourController;
  late final TextEditingController _distance2dController;
  late final TextEditingController _distance3dController;
  late final TextEditingController _ascentController;
  late final TextEditingController _descentController;
  late final TextEditingController _startElevationController;
  late final TextEditingController _endElevationController;
  late final TextEditingController _lowestElevationController;
  late final TextEditingController _highestElevationController;
  bool _visible = true;
  bool _isEditing = false;
  String? _submitError;
  RouteAdminValidationResult _validation = const RouteAdminValidationResult(
    fieldErrors: {},
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _colourController = TextEditingController();
    _distance2dController = TextEditingController();
    _distance3dController = TextEditingController();
    _ascentController = TextEditingController();
    _descentController = TextEditingController();
    _startElevationController = TextEditingController();
    _endElevationController = TextEditingController();
    _lowestElevationController = TextEditingController();
    _highestElevationController = TextEditingController();
    _syncFromRoute();
  }

  @override
  void didUpdateWidget(covariant _RouteAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving &&
        (oldWidget.row != widget.row ||
            oldWidget.route.id != widget.route.id)) {
      _syncFromRoute();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _colourController.dispose();
    _distance2dController.dispose();
    _distance3dController.dispose();
    _ascentController.dispose();
    _descentController.dispose();
    _startElevationController.dispose();
    _endElevationController.dispose();
    _lowestElevationController.dispose();
    _highestElevationController.dispose();
    super.dispose();
  }

  void _syncFromRoute() {
    final form = RouteAdminEditor.normalize(widget.route);
    _nameController.text = form.name;
    _descController.text = form.desc;
    _colourController.text = form.colour;
    _distance2dController.text = form.distance2d;
    _distance3dController.text = form.distance3d;
    _ascentController.text = form.ascent;
    _descentController.text = form.descent;
    _startElevationController.text = form.startElevation;
    _endElevationController.text = form.endElevation;
    _lowestElevationController.text = form.lowestElevation;
    _highestElevationController.text = form.highestElevation;
    _visible = form.visible;
    _isEditing = false;
    _submitError = null;
    _validation = const RouteAdminValidationResult(fieldErrors: {});
  }

  void _startEditing() {
    if (!mounted || _isSaving) return;
    setState(() {
      _isEditing = true;
      _submitError = null;
    });
  }

  RouteAdminFormState _currentFormState() {
    return RouteAdminFormState(
      name: _nameController.text,
      desc: _descController.text,
      visible: _visible,
      colour: _colourController.text,
      distance2d: _distance2dController.text,
      distance3d: _distance3dController.text,
      ascent: _ascentController.text,
      descent: _descentController.text,
      startElevation: _startElevationController.text,
      endElevation: _endElevationController.text,
      lowestElevation: _lowestElevationController.text,
      highestElevation: _highestElevationController.text,
    );
  }

  void _updateValidation() {
    if (!mounted || _isSaving) return;
    final validation = RouteAdminEditor.validateAndBuild(
      source: widget.route,
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
    if (!mounted || _isSaving || !_isEditing) {
      return;
    }

    final validation = RouteAdminEditor.validateAndBuild(
      source: widget.route,
      form: _currentFormState(),
    );
    setState(() {
      _validation = validation;
      _submitError = null;
    });
    if (!validation.isValid || validation.route == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final form = _currentFormState();
    final error = await _awaitSave(() => widget.onRouteSubmit(form));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _submitError = error;
      if (error == null) {
        _syncFromRoute();
        _isEditing = false;
      }
    });
  }

  void _close() {
    if (!mounted || _isSaving) return;
    widget.onClose();
  }

  void _cancelEditing() {
    if (!mounted || _isSaving || !_isEditing) return;
    setState(_syncFromRoute);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.route.name.trim().isNotEmpty
        ? widget.route.name.trim()
        : _objectBoxAdminDetailsTitle(widget.entity, widget.row!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey((
                      'title',
                      widget.entity.name,
                      widget.row?.primaryKeyValue,
                    )),
                    label: widget.entity.primaryNameField,
                    text: title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('objectbox-admin-route-view-on-map'),
                    tooltip: 'View Route on Main Map',
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (!mounted || _isSaving) return;
                            widget.onViewRouteOnMap?.call();
                          },
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('objectbox-admin-route-edit'),
                    tooltip: 'Edit',
                    onPressed: _isSaving ? null : _startEditing,
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            Expanded(
              child: _isEditing
                  ? _RouteEditForm(
                      entity: widget.entity,
                      route: widget.route,
                      isSaving: _isSaving,
                      nameController: _nameController,
                      descController: _descController,
                      colourController: _colourController,
                      distance2dController: _distance2dController,
                      distance3dController: _distance3dController,
                      ascentController: _ascentController,
                      descentController: _descentController,
                      visible: _visible,
                      startElevationController: _startElevationController,
                      endElevationController: _endElevationController,
                      lowestElevationController: _lowestElevationController,
                      highestElevationController: _highestElevationController,
                      submitError: _submitError,
                      validation: _validation,
                      onChanged: _updateValidation,
                      onVisibleChanged: (value) {
                        if (!mounted || _isSaving) return;
                        setState(() {
                          _visible = value;
                        });
                        _updateValidation();
                      },
                      onSubmit: _submit,
                      onCancel: _cancelEditing,
                    )
                  : _RouteReadOnlyDetails(
                      row: widget.row!,
                      entity: widget.entity,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteReadOnlyDetails extends StatelessWidget {
  const _RouteReadOnlyDetails({required this.row, required this.entity});

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    final detailsFields = _objectBoxAdminDetailsFields(entity);
    return ListView.separated(
      key: const Key('objectbox-admin-details-list'),
      itemCount: detailsFields.length,
      separatorBuilder: (context, index) =>
          const _AdminDetailsDivider(height: 1),
      itemBuilder: (context, index) {
        final field = detailsFields[index];
        final value = row.values[field.name];
        return ListTile(
          dense: true,
          title: Text(field.name),
          subtitle: objectBoxAdminDetailsValue(
            recordId: row.primaryKeyValue,
            entityName: entity.name,
            fieldName: field.name,
            label: field.name,
            value: value,
          ),
        );
      },
    );
  }
}

class _PeakListAdminDetailsPane extends StatefulWidget {
  const _PeakListAdminDetailsPane({
    super.key,
    required this.row,
    required this.entity,
    required this.peakList,
    required this.onClose,
    required this.onPeakListSubmit,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final PeakList peakList;
  final VoidCallback onClose;
  final Future<String?> Function(PeakListAdminFormState form) onPeakListSubmit;

  @override
  State<_PeakListAdminDetailsPane> createState() =>
      _PeakListAdminDetailsPaneState();
}

class _PeakListAdminDetailsPaneState extends State<_PeakListAdminDetailsPane>
    with _AdminSaveState<_PeakListAdminDetailsPane> {
  late final TextEditingController _colourController;
  bool _isEditing = false;
  String? _submitError;
  PeakListAdminValidationResult _validation =
      const PeakListAdminValidationResult(fieldErrors: {});

  @override
  void initState() {
    super.initState();
    _colourController = TextEditingController();
    _syncFromPeakList();
  }

  @override
  void didUpdateWidget(covariant _PeakListAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving &&
        (oldWidget.row != widget.row ||
            oldWidget.peakList.peakListId != widget.peakList.peakListId ||
            oldWidget.peakList.colour != widget.peakList.colour)) {
      _syncFromPeakList();
    }
  }

  @override
  void dispose() {
    _colourController.dispose();
    super.dispose();
  }

  void _syncFromPeakList() {
    final form = PeakListAdminEditor.normalize(widget.peakList);
    _colourController.text = form.colour;
    _isEditing = false;
    _submitError = null;
    _validation = const PeakListAdminValidationResult(fieldErrors: {});
  }

  void _startEditing() {
    if (!mounted || _isSaving) return;
    setState(() {
      _isEditing = true;
      _submitError = null;
    });
  }

  PeakListAdminFormState _currentFormState() {
    return PeakListAdminFormState(colour: _colourController.text);
  }

  void _updateValidation() {
    if (!mounted || _isSaving) return;
    final validation = PeakListAdminEditor.validateAndBuild(
      source: widget.peakList,
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
    if (!mounted || _isSaving || !_isEditing) {
      return;
    }

    final validation = PeakListAdminEditor.validateAndBuild(
      source: widget.peakList,
      form: _currentFormState(),
    );
    setState(() {
      _validation = validation;
      _submitError = null;
    });
    if (!validation.isValid || validation.peakList == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final form = _currentFormState();
    final error = await _awaitSave(() => widget.onPeakListSubmit(form));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _submitError = error;
      if (error == null) {
        _syncFromPeakList();
        _isEditing = false;
      }
    });
  }

  void _close() {
    if (!mounted || _isSaving) return;
    widget.onClose();
  }

  void _cancelEditing() {
    if (!mounted || _isSaving || !_isEditing) return;
    setState(_syncFromPeakList);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.peakList.name.trim().isNotEmpty
        ? widget.peakList.name.trim()
        : _objectBoxAdminDetailsTitle(widget.entity, widget.row!);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey((
                      'title',
                      widget.entity.name,
                      widget.row?.primaryKeyValue,
                    )),
                    label: widget.entity.primaryNameField,
                    text: title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('objectbox-admin-peak-list-edit'),
                    tooltip: 'Edit',
                    onPressed: _isSaving ? null : _startEditing,
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            Expanded(
              child: _isEditing
                  ? _PeakListEditForm(
                      entity: widget.entity,
                      row: widget.row,
                      peakList: widget.peakList,
                      isSaving: _isSaving,
                      colourController: _colourController,
                      submitError: _submitError,
                      validation: _validation,
                      onChanged: _updateValidation,
                      onSubmit: _submit,
                      onCancel: _cancelEditing,
                    )
                  : _PeakListReadOnlyDetails(
                      row: widget.row!,
                      entity: widget.entity,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakListReadOnlyDetails extends StatelessWidget {
  const _PeakListReadOnlyDetails({required this.row, required this.entity});

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    final detailsFields = _objectBoxAdminDetailsFields(entity);
    return ListView.separated(
      key: const Key('objectbox-admin-details-list'),
      itemCount: detailsFields.length,
      separatorBuilder: (context, index) =>
          const _AdminDetailsDivider(height: 1),
      itemBuilder: (context, index) {
        final field = detailsFields[index];
        final value = row.values[field.name];
        return ListTile(
          dense: true,
          title: Text(field.name),
          subtitle: objectBoxAdminDetailsValue(
            recordId: row.primaryKeyValue,
            entityName: entity.name,
            fieldName: field.name,
            label: field.name,
            value: value,
          ),
        );
      },
    );
  }
}

class _PeakListEditForm extends StatelessWidget {
  const _PeakListEditForm({
    required this.entity,
    required this.row,
    required this.peakList,
    required this.isSaving,
    required this.colourController,
    required this.submitError,
    required this.validation,
    required this.onChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final ObjectBoxAdminRow? row;
  final PeakList peakList;
  final bool isSaving;
  final TextEditingController colourController;
  final String? submitError;
  final PeakListAdminValidationResult validation;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const Key('objectbox-admin-peak-list-edit-form'),
            children: [
              _buildReadOnlyField(
                label: 'peakListId',
                value: peakList.peakListId.toString(),
                keyName: 'objectbox-admin-peak-list-id',
              ),
              const SizedBox(height: 8),
              _buildReadOnlyField(
                label: 'Name',
                value: peakList.name,
                keyName: 'objectbox-admin-peak-list-name-read-only',
              ),
              const SizedBox(height: 8),
              _buildReadOnlyField(
                label: 'Region',
                value: peakList.region,
                keyName: 'objectbox-admin-peak-list-region-read-only',
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'colour',
                recordId: peakList.peakListId,
                key: const Key('objectbox-admin-peak-list-colour'),
                controller: colourController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Colour',
                  errorText: validation.fieldErrors['colour'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                title: const Text('Membership Items'),
                subtitle: objectBoxAdminDetailsValue(
                  recordId: row?.primaryKeyValue,
                  entityName: 'PeakList',
                  fieldName: 'membershipItems',
                  label: 'membershipItems',
                  value: row?.values['membershipItems'] ?? const [],
                ),
              ),
            ],
          ),
        ),
        if (submitError != null) ...[
          const SizedBox(height: 8),
          Text(submitError!, style: TextStyle(color: errorColor)),
        ],
        const SizedBox(height: 12),
        ObjectBoxAdminEditFooter(
          prefix: 'peak-list',
          isSaving: isSaving,
          onCancel: onCancel,
          onSave: onSubmit,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required String keyName,
  }) {
    return ObjectBoxAdminReadOnlyFormValue(
      key: Key(keyName),
      valueKey: ValueKey(('PeakList', peakList.peakListId, keyName)),
      label: label,
      text: value,
    );
  }
}

class _RouteEditForm extends StatelessWidget {
  const _RouteEditForm({
    required this.entity,
    required this.route,
    required this.isSaving,
    required this.nameController,
    required this.descController,
    required this.colourController,
    required this.distance2dController,
    required this.distance3dController,
    required this.ascentController,
    required this.descentController,
    required this.visible,
    required this.startElevationController,
    required this.endElevationController,
    required this.lowestElevationController,
    required this.highestElevationController,
    required this.submitError,
    required this.validation,
    required this.onChanged,
    required this.onVisibleChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final app_route.Route route;
  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController descController;
  final TextEditingController colourController;
  final TextEditingController distance2dController;
  final TextEditingController distance3dController;
  final TextEditingController ascentController;
  final TextEditingController descentController;
  final bool visible;
  final TextEditingController startElevationController;
  final TextEditingController endElevationController;
  final TextEditingController lowestElevationController;
  final TextEditingController highestElevationController;
  final String? submitError;
  final RouteAdminValidationResult validation;
  final VoidCallback onChanged;
  final ValueChanged<bool> onVisibleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const Key('objectbox-admin-route-edit-form'),
            children: [
              _buildReadOnlyField(
                label: 'id',
                value: route.id.toString(),
                keyName: 'objectbox-admin-route-id',
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'name',
                recordId: route.id,
                key: const Key('objectbox-admin-route-name'),
                controller: nameController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Name',
                  errorText: validation.fieldErrors['name'],
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'desc',
                recordId: route.id,
                key: const Key('objectbox-admin-route-desc'),
                controller: descController,
                enabled: !isSaving,
                decoration: const InputDecoration(labelText: 'Description'),
                multiline: true,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              if (objectBoxAdminPermitsInput(
                entity,
                'visible',
                AdminFieldInput.boolean,
              ))
                SwitchListTile(
                  key: const Key('objectbox-admin-route-visible'),
                  title: const Text('Visible'),
                  value: visible,
                  onChanged: isSaving ? null : onVisibleChanged,
                )
              else
                ListTile(
                  key: const Key('objectbox-admin-route-visible'),
                  title: const Text('Visible'),
                  subtitle: ObjectBoxAdminDetailsValue(
                    label: 'Visible',
                    value: visible,
                  ),
                ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'colour',
                recordId: route.id,
                key: const Key('objectbox-admin-route-colour'),
                controller: colourController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Colour',
                  errorText: validation.fieldErrors['colour'],
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'distance2d',
                recordId: route.id,
                key: const Key('objectbox-admin-route-distance2d'),
                controller: distance2dController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Distance 2D',
                  errorText: validation.fieldErrors['distance2d'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'distance3d',
                recordId: route.id,
                key: const Key('objectbox-admin-route-distance3d'),
                controller: distance3dController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Distance 3D',
                  errorText: validation.fieldErrors['distance3d'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'ascent',
                recordId: route.id,
                key: const Key('objectbox-admin-route-ascent'),
                controller: ascentController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Ascent',
                  errorText: validation.fieldErrors['ascent'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'descent',
                recordId: route.id,
                key: const Key('objectbox-admin-route-descent'),
                controller: descentController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Descent',
                  errorText: validation.fieldErrors['descent'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'startElevation',
                recordId: route.id,
                key: const Key('objectbox-admin-route-start-elevation'),
                controller: startElevationController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Start Elevation',
                  errorText: validation.fieldErrors['startElevation'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'endElevation',
                recordId: route.id,
                key: const Key('objectbox-admin-route-end-elevation'),
                controller: endElevationController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'End Elevation',
                  errorText: validation.fieldErrors['endElevation'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'lowestElevation',
                recordId: route.id,
                key: const Key('objectbox-admin-route-lowest-elevation'),
                controller: lowestElevationController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Lowest Elevation',
                  errorText: validation.fieldErrors['lowestElevation'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              objectBoxAdminTextFormField(
                entity: entity,
                field: 'highestElevation',
                recordId: route.id,
                key: const Key('objectbox-admin-route-highest-elevation'),
                controller: highestElevationController,
                enabled: !isSaving,
                decoration: InputDecoration(
                  labelText: 'Highest Elevation',
                  errorText: validation.fieldErrors['highestElevation'],
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                title: const Text('gpxRouteJson'),
                subtitle: objectBoxAdminDetailsValue(
                  recordId: route.id,
                  entityName: 'Route',
                  fieldName: 'gpxRouteJson',
                  label: 'gpxRouteJson',
                  value: route.gpxRouteJson,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                dense: true,
                title: const Text('displayRoutePointsByZoom'),
                subtitle: objectBoxAdminDetailsValue(
                  recordId: route.id,
                  entityName: 'Route',
                  fieldName: 'displayRoutePointsByZoom',
                  label: 'displayRoutePointsByZoom',
                  value: route.displayRoutePointsByZoom,
                ),
              ),
            ],
          ),
        ),
        if (submitError != null) ...[
          const SizedBox(height: 8),
          Text(submitError!, style: TextStyle(color: errorColor)),
        ],
        const SizedBox(height: 12),
        ObjectBoxAdminEditFooter(
          prefix: 'route',
          isSaving: isSaving,
          onCancel: onCancel,
          onSave: onSubmit,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required String keyName,
  }) {
    return ObjectBoxAdminReadOnlyFormValue(
      key: Key(keyName),
      valueKey: ValueKey(('Route', route.id, keyName)),
      label: label,
      text: value,
    );
  }
}

Widget objectBoxAdminDetailsValue({
  Object? recordId,
  String? entityName,
  String? fieldName,
  required String label,
  required Object? value,
}) {
  if (value is bool) {
    return ObjectBoxAdminDetailsValue(label: label, value: value);
  }

  final formattedValue = objectBoxAdminFormatFieldValue(
    entityName: entityName ?? '',
    fieldName: fieldName ?? '',
    value: value,
  );

  return ObjectBoxAdminReadOnlyValue(
    key: ValueKey((entityName, recordId, fieldName ?? label)),
    label: label,
    text: formattedValue,
  );
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

String _objectBoxAdminDetailsTitle(
  ObjectBoxAdminEntityDescriptor entity,
  ObjectBoxAdminRow? row,
) {
  const namedEntities = {
    'GpxTrack',
    'Peak',
    'PeakList',
    'Route',
    'Tasmap50k',
    'Waypoints',
    'NaturalFeature',
    'Contact',
  };

  if (row == null || !namedEntities.contains(entity.name)) {
    if (row == null) {
      return entity.displayName;
    }
    return '${entity.displayName} #${objectBoxAdminFormatValue(row.primaryKeyValue)}';
  }

  if (entity.name == 'NaturalFeature') {
    final name = objectBoxAdminFormatValue(row.values['name']).trim();
    if (name.isNotEmpty && name != '—') {
      return name;
    }
    return '${objectBoxAdminFormatValue(row.values['osmType'])} '
        '${objectBoxAdminFormatValue(row.values['osmId'])}';
  }

  if (entity.name == 'Contact') {
    final title = [
      objectBoxAdminFormatValue(row.values['firstName']).trim(),
      objectBoxAdminFormatValue(row.values['surname']).trim(),
    ].where((part) => part.isNotEmpty && part != '—').join(' ');
    if (title.isNotEmpty) {
      return title;
    }
    final nickname = objectBoxAdminFormatValue(row.values['nickname']).trim();
    if (nickname.isNotEmpty && nickname != '—') {
      return nickname;
    }
  }

  final value = row.values[entity.primaryNameField];
  final title = objectBoxAdminFormatValue(value).trim();
  if (title.isNotEmpty && title != '—') {
    return title;
  }

  return '${entity.displayName} #${objectBoxAdminFormatValue(row.primaryKeyValue)}';
}

class _ContactAdminDetailsPane extends StatefulWidget {
  const _ContactAdminDetailsPane({
    super.key,
    required this.entity,
    required this.contact,
    required this.createMode,
    required this.onClose,
    required this.onContactSubmit,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final Contact contact;
  final bool createMode;
  final VoidCallback onClose;
  final Future<String?> Function(Contact contact) onContactSubmit;

  @override
  State<_ContactAdminDetailsPane> createState() =>
      _ContactAdminDetailsPaneState();
}

class _ContactAdminDetailsPaneState extends State<_ContactAdminDetailsPane>
    with _AdminSaveState<_ContactAdminDetailsPane> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _nicknameController;
  var _isEditing = false;
  String? _submitError;
  ContactAdminValidationResult _validation = const ContactAdminValidationResult(
    fieldErrors: {},
  );

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _surnameController = TextEditingController();
    _nicknameController = TextEditingController();
    _syncFromContact();
  }

  @override
  void didUpdateWidget(covariant _ContactAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving &&
        (oldWidget.contact.id != widget.contact.id ||
            oldWidget.createMode != widget.createMode ||
            (!_isEditing && oldWidget.contact != widget.contact))) {
      _syncFromContact();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  ContactAdminFormState _currentForm() => ContactAdminFormState(
    firstName: _firstNameController.text,
    surname: _surnameController.text,
    nickname: _nicknameController.text,
  );

  void _syncFromContact() {
    _firstNameController.text = widget.contact.firstName;
    _surnameController.text = widget.contact.surname;
    _nicknameController.text = widget.contact.nickname;
    _isEditing = widget.createMode;
    _submitError = null;
    _validation = const ContactAdminValidationResult(fieldErrors: {});
  }

  void _validate() {
    if (!mounted || _isSaving) return;
    setState(() {
      _submitError = null;
      _validation = ContactAdminEditor.validateAndBuild(
        source: widget.contact,
        form: _currentForm(),
      );
    });
  }

  void _cancelEditing() {
    if (!mounted || _isSaving || !_isEditing) return;
    if (widget.createMode) {
      widget.onClose();
      return;
    }
    setState(_syncFromContact);
  }

  Future<void> _submit() async {
    if (!mounted || _isSaving || !_isEditing) {
      return;
    }
    final validation = ContactAdminEditor.validateAndBuild(
      source: widget.contact,
      form: _currentForm(),
    );
    setState(() => _validation = validation);
    if (!validation.isValid) {
      return;
    }

    setState(() => _isSaving = true);
    final error = await _awaitSave(
      () => widget.onContactSubmit(validation.contact!),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _submitError = error;
      if (error == null) {
        _isEditing = false;
      }
    });
  }

  void _close() {
    if (!mounted || _isSaving) return;
    widget.onClose();
  }

  String get _title {
    final validation = ContactAdminEditor.validateAndBuild(
      source: widget.contact,
      form: _currentForm(),
    );
    if (widget.createMode && !validation.isValid) {
      return 'New Contact';
    }
    final displayName = contactDisplayName(
      validation.contact ?? widget.contact,
    );
    return displayName.isEmpty ? 'New Contact' : displayName;
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
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey(('title', 'Contact', widget.contact.id)),
                    label: 'Contact',
                    text: _title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('objectbox-admin-contact-edit'),
                    tooltip: 'Edit',
                    onPressed: _isSaving
                        ? null
                        : () {
                            if (!mounted || _isSaving) return;
                            setState(() => _isEditing = true);
                          },
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            Expanded(
              child: _isEditing
                  ? _ContactEditForm(
                      entity: widget.entity,
                      contact: widget.contact,
                      createMode: widget.createMode,
                      firstNameController: _firstNameController,
                      surnameController: _surnameController,
                      nicknameController: _nicknameController,
                      validation: _validation,
                      isSaving: _isSaving,
                      submitError: _submitError,
                      onChanged: _validate,
                      onCancel: _cancelEditing,
                      onSubmit: _submit,
                    )
                  : _ContactReadOnlyDetails(contact: widget.contact),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactReadOnlyDetails extends StatelessWidget {
  const _ContactReadOnlyDetails({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final values = {
      'id': contact.id,
      'firstName': contact.firstName,
      'surname': contact.surname,
      'nickname': contact.nickname,
    };
    return ListView(
      key: const Key('objectbox-admin-details-list'),
      children: [
        for (final entry in values.entries)
          ListTile(
            dense: true,
            title: Text(entry.key),
            subtitle: objectBoxAdminDetailsValue(
              recordId: contact.id,
              entityName: 'Contact',
              fieldName: entry.key,
              label: entry.key,
              value: entry.value,
            ),
          ),
      ],
    );
  }
}

class _ContactEditForm extends StatelessWidget {
  const _ContactEditForm({
    required this.entity,
    required this.contact,
    required this.createMode,
    required this.firstNameController,
    required this.surnameController,
    required this.nicknameController,
    required this.validation,
    required this.isSaving,
    required this.submitError,
    required this.onChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final Contact contact;
  final bool createMode;
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController nicknameController;
  final ContactAdminValidationResult validation;
  final bool isSaving;
  final String? submitError;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const Key('objectbox-admin-contact-edit-form'),
            children: [
              ObjectBoxAdminReadOnlyFormValue(
                key: const Key('objectbox-admin-contact-id'),
                valueKey: ValueKey(('Contact', contact.id, 'id')),
                label: 'id',
                text:
                    createMode &&
                        contact.id == 0 &&
                        entity.fields.any(
                          (field) =>
                              field.name == 'id' &&
                              field.isPrimaryKey &&
                              field.isGenerated,
                        )
                    ? 'Not yet assigned'
                    : contact.id.toString(),
              ),
              const SizedBox(height: 8),
              _field(
                field: 'firstName',
                keyName: 'first-name',
                label: 'First name',
                controller: firstNameController,
                errorText: validation.fieldErrors['firstName'],
              ),
              const SizedBox(height: 8),
              _field(
                field: 'surname',
                keyName: 'surname',
                label: 'Surname',
                controller: surnameController,
                errorText: validation.fieldErrors['surname'],
              ),
              const SizedBox(height: 8),
              _field(
                field: 'nickname',
                keyName: 'nickname',
                label: 'Nickname',
                controller: nicknameController,
                errorText: validation.fieldErrors['nickname'],
              ),
            ],
          ),
        ),
        if (submitError != null)
          Text(
            submitError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        ObjectBoxAdminEditFooter(
          prefix: 'contact',
          isSaving: isSaving,
          onCancel: onCancel,
          onSave: onSubmit,
        ),
      ],
    );
  }

  Widget _field({
    required String field,
    required String keyName,
    required String label,
    required TextEditingController controller,
    required String? errorText,
  }) {
    return objectBoxAdminTextFormField(
      entity: entity,
      field: field,
      recordId: contact.id,
      key: Key('objectbox-admin-contact-$keyName'),
      controller: controller,
      enabled: !isSaving,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      onChanged: (_) => onChanged(),
    );
  }
}

class _NaturalFeatureAdminDetailsPane extends StatefulWidget {
  const _NaturalFeatureAdminDetailsPane({
    super.key,
    required this.row,
    required this.entity,
    required this.naturalFeature,
    required this.mutationLocked,
    required this.onClose,
    required this.onViewNaturalFeatureOnMap,
    required this.onNaturalFeatureSubmit,
  });

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminEntityDescriptor entity;
  final NaturalFeature naturalFeature;
  final bool mutationLocked;
  final VoidCallback onClose;
  final void Function(NaturalFeature naturalFeature) onViewNaturalFeatureOnMap;
  final Future<String?> Function(NaturalFeature feature) onNaturalFeatureSubmit;

  @override
  State<_NaturalFeatureAdminDetailsPane> createState() =>
      _NaturalFeatureAdminDetailsPaneState();
}

class _NaturalFeatureAdminDetailsPaneState
    extends State<_NaturalFeatureAdminDetailsPane>
    with _AdminSaveState<_NaturalFeatureAdminDetailsPane> {
  late final Map<String, TextEditingController> _controllers;
  late String _sourceOfTruth;
  var _isEditing = false;
  NaturalFeatureAdminCoordinateSource? _coordinateSource;
  String? _submitError;
  NaturalFeatureAdminValidationResult _validation =
      const NaturalFeatureAdminValidationResult(fieldErrors: {});

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in _editableFields) field: TextEditingController(),
    };
    _syncFromFeature();
  }

  @override
  void didUpdateWidget(covariant _NaturalFeatureAdminDetailsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSaving &&
        (oldWidget.naturalFeature.id != widget.naturalFeature.id ||
            (oldWidget.row != widget.row && !_isEditing))) {
      _syncFromFeature();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static const _editableFields = [
    'name',
    'altName',
    'tag',
    'country',
    'county',
    'region',
    'latitude',
    'longitude',
    'mgrs100kId',
    'easting',
    'northing',
  ];

  TextEditingController _controller(String field) => _controllers[field]!;

  void _syncFromFeature() {
    final form = NaturalFeatureAdminEditor.normalize(widget.naturalFeature);
    _controller('name').text = form.name;
    _controller('altName').text = form.altName;
    _controller('tag').text = form.tag;
    _controller('country').text = form.country;
    _controller('county').text = form.county;
    _controller('region').text = form.region;
    _controller('latitude').text = form.latitude;
    _controller('longitude').text = form.longitude;
    _controller('mgrs100kId').text = form.mgrs100kId;
    _controller('easting').text = form.easting;
    _controller('northing').text = form.northing;
    _sourceOfTruth = form.sourceOfTruth;
    _isEditing = false;
    _coordinateSource = null;
    _submitError = null;
    _validation = const NaturalFeatureAdminValidationResult(fieldErrors: {});
  }

  NaturalFeatureAdminFormState _currentForm() {
    return NaturalFeatureAdminFormState(
      name: _controller('name').text,
      altName: _controller('altName').text,
      tag: _controller('tag').text,
      country: _controller('country').text,
      county: _controller('county').text,
      region: _controller('region').text,
      latitude: _controller('latitude').text,
      longitude: _controller('longitude').text,
      gridZoneDesignator: widget.naturalFeature.gridZoneDesignator,
      mgrs100kId: _controller('mgrs100kId').text,
      easting: _controller('easting').text,
      northing: _controller('northing').text,
      sourceOfTruth: _sourceOfTruth,
    );
  }

  bool get _isLocked => _isSaving || widget.mutationLocked;

  void _validate() {
    if (!mounted || _isLocked) return;
    setState(() {
      _validation = NaturalFeatureAdminEditor.validateAndBuild(
        source: widget.naturalFeature,
        form: _currentForm(),
        coordinateSource: _coordinateSource,
      );
      _submitError = null;
    });
  }

  void _handleLatLngChanged() {
    if (!mounted || _isLocked) return;
    if (_coordinateSource != NaturalFeatureAdminCoordinateSource.latLng) {
      _controller('mgrs100kId').clear();
      _controller('easting').clear();
      _controller('northing').clear();
    }
    _coordinateSource = NaturalFeatureAdminCoordinateSource.latLng;
    _validate();
  }

  void _handleMgrsChanged() {
    if (!mounted || _isLocked) return;
    if (_coordinateSource != NaturalFeatureAdminCoordinateSource.mgrs) {
      _controller('latitude').clear();
      _controller('longitude').clear();
    }
    _coordinateSource = NaturalFeatureAdminCoordinateSource.mgrs;
    _validate();
  }

  void _calculateCoordinates() {
    if (!mounted) return;
    final source = _coordinateSource;
    if (source == null || _isLocked) {
      return;
    }
    final result = NaturalFeatureAdminEditor.calculateMissingCoordinates(
      source: widget.naturalFeature,
      coordinateSource: source,
      form: _currentForm(),
    );
    if (!result.isValid) {
      setState(() {
        _validation = NaturalFeatureAdminValidationResult(
          fieldErrors: result.fieldErrors,
          coordinateError: result.coordinateError,
        );
      });
      return;
    }
    final form = result.form!;
    _controller('latitude').text = form.latitude;
    _controller('longitude').text = form.longitude;
    _controller('mgrs100kId').text = form.mgrs100kId;
    _controller('easting').text = form.easting;
    _controller('northing').text = form.northing;
    _validate();
  }

  Future<void> _submit() async {
    if (!mounted || _isLocked || !_isEditing) {
      return;
    }
    final validation = NaturalFeatureAdminEditor.validateAndBuild(
      source: widget.naturalFeature,
      form: _currentForm(),
      coordinateSource:
          _coordinateSource ?? NaturalFeatureAdminCoordinateSource.latLng,
    );
    setState(() {
      _validation = validation;
      _submitError = null;
    });
    if (!validation.isValid) {
      return;
    }
    setState(() => _isSaving = true);
    final error = await _awaitSave(
      () => widget.onNaturalFeatureSubmit(validation.naturalFeature!),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _submitError = error;
      if (error == null) {
        _syncFromFeature();
        _isEditing = false;
      }
    });
  }

  void _close() {
    if (!mounted || _isSaving) return;
    widget.onClose();
  }

  void _cancelEditing() {
    if (!mounted || _isSaving || !_isEditing) return;
    setState(_syncFromFeature);
  }

  @override
  Widget build(BuildContext context) {
    final title = _objectBoxAdminDetailsTitle(widget.entity, widget.row);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ObjectBoxAdminReadOnlyValue(
                    key: ValueKey((
                      'title',
                      widget.entity.name,
                      widget.row.primaryKeyValue,
                    )),
                    label: widget.entity.primaryNameField,
                    text: title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('objectbox-admin-natural-feature-view-on-map'),
                  tooltip: 'View Natural Feature on Main Map',
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (!mounted || _isSaving) return;
                          widget.onViewNaturalFeatureOnMap(
                            widget.naturalFeature,
                          );
                        },
                  icon: const Icon(Icons.visibility_outlined),
                ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('objectbox-admin-natural-feature-edit'),
                    tooltip: 'Edit',
                    onPressed: _isLocked
                        ? null
                        : () {
                            if (!mounted || _isLocked) return;
                            setState(() => _isEditing = true);
                          },
                    icon: const Icon(Icons.edit),
                  ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  tooltip: 'Close',
                  onPressed: _isSaving ? null : _close,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const _AdminDetailsDivider(),
            Expanded(
              child: _isEditing
                  ? _NaturalFeatureEditForm(
                      entity: widget.entity,
                      feature: widget.naturalFeature,
                      controllers: _controllers,
                      sourceOfTruth: _sourceOfTruth,
                      validation: _validation,
                      submitError: _submitError,
                      locked: _isLocked,
                      isSaving: _isSaving,
                      canCalculate: _coordinateSource != null,
                      onChanged: _validate,
                      onLatLngChanged: _handleLatLngChanged,
                      onMgrsChanged: _handleMgrsChanged,
                      onSourceOfTruthChanged: (value) {
                        if (!mounted || _isLocked) return;
                        setState(
                          () => _sourceOfTruth = value ?? _sourceOfTruth,
                        );
                        _validate();
                      },
                      onCalculate: _calculateCoordinates,
                      onSubmit: _submit,
                      onCancel: _cancelEditing,
                    )
                  : _NaturalFeatureReadOnlyDetails(
                      row: widget.row,
                      entity: widget.entity,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NaturalFeatureReadOnlyDetails extends StatelessWidget {
  const _NaturalFeatureReadOnlyDetails({
    required this.row,
    required this.entity,
  });

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('objectbox-admin-details-list'),
      itemCount: entity.fields.length - 1,
      separatorBuilder: (context, index) =>
          const _AdminDetailsDivider(height: 1),
      itemBuilder: (context, index) {
        final field = entity.fields
            .where((field) => !field.isPrimaryName)
            .elementAt(index);
        return ListTile(
          dense: true,
          title: Text(field.name),
          subtitle: objectBoxAdminDetailsValue(
            recordId: row.primaryKeyValue,
            entityName: entity.name,
            fieldName: field.name,
            label: field.name,
            value: row.values[field.name],
          ),
        );
      },
    );
  }
}

class _NaturalFeatureEditForm extends StatelessWidget {
  const _NaturalFeatureEditForm({
    required this.entity,
    required this.feature,
    required this.controllers,
    required this.sourceOfTruth,
    required this.validation,
    required this.submitError,
    required this.locked,
    required this.canCalculate,
    required this.onChanged,
    required this.onLatLngChanged,
    required this.onMgrsChanged,
    required this.onSourceOfTruthChanged,
    required this.onCalculate,
    required this.onSubmit,
    required this.onCancel,
    required this.isSaving,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final NaturalFeature feature;
  final Map<String, TextEditingController> controllers;
  final String sourceOfTruth;
  final NaturalFeatureAdminValidationResult validation;
  final String? submitError;
  final bool locked;
  final bool canCalculate;
  final VoidCallback onChanged;
  final VoidCallback onLatLngChanged;
  final VoidCallback onMgrsChanged;
  final ValueChanged<String?> onSourceOfTruthChanged;
  final VoidCallback onCalculate;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            key: const Key('objectbox-admin-natural-feature-edit-form'),
            children: [
              _readOnly('id', feature.id.toString()),
              _readOnly('osmType', feature.osmType),
              _readOnly('osmId', feature.osmId.toString()),
              _readOnly('gridZoneDesignator', feature.gridZoneDesignator),
              _field('name', 'Name', onChanged),
              _field('altName', 'Alt Name', onChanged),
              _field('tag', 'Tag', onChanged),
              _field('country', 'Country', onChanged),
              _field('county', 'County', onChanged),
              _field('region', 'Region', onChanged),
              _field('latitude', 'Latitude', onLatLngChanged),
              _field('longitude', 'Longitude', onLatLngChanged),
              _field('mgrs100kId', 'MGRS 100km identifier', onMgrsChanged),
              _field('easting', 'Easting', onMgrsChanged),
              _field('northing', 'Northing', onMgrsChanged),
              if (objectBoxAdminPermitsInput(
                entity,
                'sourceOfTruth',
                AdminFieldInput.sourceOfTruthSelector,
              ))
                DropdownButtonFormField<String>(
                  key: const Key(
                    'objectbox-admin-natural-feature-source-of-truth',
                  ),
                  initialValue: sourceOfTruth,
                  decoration: InputDecoration(
                    labelText: 'Source of truth',
                    errorText: validation.fieldErrors['sourceOfTruth'],
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OSM', child: Text('OSM')),
                    DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                  ],
                  onChanged: locked ? null : onSourceOfTruthChanged,
                )
              else
                ObjectBoxAdminReadOnlyFormValue(
                  key: const Key(
                    'objectbox-admin-natural-feature-source-of-truth',
                  ),
                  valueKey: ValueKey((
                    'NaturalFeature',
                    feature.id,
                    'sourceOfTruth',
                  )),
                  label: 'Source of truth',
                  text: sourceOfTruth,
                ),
            ].expand((widget) => [widget, const SizedBox(height: 8)]).toList(),
          ),
        ),
        if (validation.coordinateError != null)
          Text(
            validation.coordinateError!,
            style: TextStyle(color: errorColor),
          ),
        if (submitError != null)
          Text(submitError!, style: TextStyle(color: errorColor)),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('objectbox-admin-natural-feature-calculate'),
          onPressed: locked || !canCalculate ? null : onCalculate,
          child: const Text('Calculate'),
        ),
        const SizedBox(height: 8),
        ObjectBoxAdminEditFooter(
          prefix: 'natural-feature',
          isSaving: isSaving,
          locked: locked,
          onCancel: onCancel,
          onSave: onSubmit,
        ),
      ],
    );
  }

  Widget _readOnly(String field, String value) =>
      ObjectBoxAdminReadOnlyFormValue(
        key: Key('objectbox-admin-natural-feature-$field'),
        valueKey: ValueKey(('NaturalFeature', feature.id, field)),
        label: field,
        text: value,
      );

  Widget _field(String field, String label, VoidCallback changed) =>
      objectBoxAdminTextFormField(
        entity: entity,
        field: field,
        recordId: feature.id,
        key: Key('objectbox-admin-natural-feature-${_fieldKey(field)}'),
        controller: controllers[field]!,
        enabled: !locked,
        keyboardType: switch (field) {
          'latitude' || 'longitude' => const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          'easting' || 'northing' => TextInputType.number,
          _ => TextInputType.text,
        },
        decoration: InputDecoration(
          labelText: label,
          errorText: validation.fieldErrors[field],
        ),
        onChanged: (_) => changed(),
      );

  String _fieldKey(String field) => field.replaceAllMapped(
    RegExp(r'(?<!^)([A-Z])'),
    (match) => '-${match[1]!.toLowerCase()}',
  );
}

class _PeakEditForm extends StatelessWidget {
  const _PeakEditForm({
    required this.entity,
    required this.recordId,
    required this.isSaving,
    required this.nameController,
    required this.altNameController,
    required this.osmIdController,
    required this.peakbaggerPidController,
    required this.elevationController,
    required this.prominenceController,
    required this.countryController,
    required this.countyController,
    required this.rangeController,
    required this.ratingController,
    required this.durationController,
    required this.difficultyController,
    required this.viaFerrataController,
    required this.notesController,
    required this.latitudeController,
    required this.longitudeController,
    required this.regionController,
    required this.gridZoneDesignator,
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
    required this.onCancel,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final int recordId;
  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController altNameController;
  final TextEditingController osmIdController;
  final TextEditingController peakbaggerPidController;
  final TextEditingController elevationController;
  final TextEditingController prominenceController;
  final TextEditingController countryController;
  final TextEditingController countyController;
  final TextEditingController rangeController;
  final TextEditingController ratingController;
  final TextEditingController durationController;
  final TextEditingController difficultyController;
  final TextEditingController viaFerrataController;
  final TextEditingController notesController;
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController regionController;
  final String gridZoneDesignator;
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
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('objectbox-admin-peak-edit-form'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReadOnlyField(
                  label: 'id',
                  value: peakIdText,
                  keyName: 'objectbox-admin-peak-id',
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'name',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-name'),
                  controller: nameController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: validation.fieldErrors['name'],
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'altName',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-alt-name'),
                  controller: altNameController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Alt Name',
                    errorText: validation.fieldErrors['altName'],
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'osmId',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-osm-id'),
                  controller: osmIdController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'osmId',
                    errorText: validation.fieldErrors['osmId'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'peakbaggerPid',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-peakbagger-pid'),
                  controller: peakbaggerPidController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'PeakBagger PID',
                    errorText: validation.fieldErrors['peakbaggerPid'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'elevation',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-elevation'),
                  controller: elevationController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Elevation',
                    errorText: validation.fieldErrors['elevation'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'prominence',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-prominence'),
                  controller: prominenceController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Prominence',
                    errorText: validation.fieldErrors['prominence'],
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'country',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-country'),
                  controller: countryController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Country'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'county',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-county'),
                  controller: countyController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'County'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'range',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-range'),
                  controller: rangeController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Range'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'rating',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-rating'),
                  controller: ratingController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Rating',
                    errorText: validation.fieldErrors['rating'],
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'durationLabel',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-duration'),
                  controller: durationController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Peak duration',
                    errorText: validation.fieldErrors['durationLabel'],
                  ),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'difficulty',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-difficulty'),
                  controller: difficultyController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'viaFerrata',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-via-ferrata'),
                  controller: viaFerrataController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Via ferrata'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'notes',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-notes'),
                  controller: notesController,
                  enabled: !isSaving,
                  multiline: true,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'latitude',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-latitude'),
                  controller: latitudeController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    errorText: validation.fieldErrors['latitude'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onLatLngChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'longitude',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-longitude'),
                  controller: longitudeController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    errorText: validation.fieldErrors['longitude'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onLatLngChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'region',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-region'),
                  controller: regionController,
                  enabled: !isSaving,
                  decoration: const InputDecoration(labelText: 'Region'),
                  onChanged: (_) => onChanged(),
                ),
                const SizedBox(height: 8),
                _buildReadOnlyField(
                  label: 'gridZoneDesignator',
                  value: gridZoneDesignator,
                  keyName: 'objectbox-admin-peak-grid-zone-designator',
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'mgrs100kId',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-mgrs100k-id'),
                  controller: mgrs100kIdController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'MGRS 100km identifier',
                    errorText: validation.fieldErrors['mgrs100kId'],
                  ),
                  onChanged: (_) => onMgrsChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'easting',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-easting'),
                  controller: eastingController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Easting',
                    errorText: validation.fieldErrors['easting'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onMgrsChanged(),
                ),
                const SizedBox(height: 8),
                objectBoxAdminTextFormField(
                  entity: entity,
                  field: 'northing',
                  recordId: recordId,
                  key: const Key('objectbox-admin-peak-northing'),
                  controller: northingController,
                  enabled: !isSaving,
                  decoration: InputDecoration(
                    labelText: 'Northing',
                    errorText: validation.fieldErrors['northing'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onMgrsChanged(),
                ),
                const SizedBox(height: 8),
                if (objectBoxAdminPermitsInput(
                  entity,
                  'verified',
                  AdminFieldInput.boolean,
                ))
                  CheckboxListTile(
                    key: const Key('objectbox-admin-peak-verified'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verified'),
                    value: verified,
                    onChanged: isSaving ? null : onVerifiedChanged,
                    controlAffinity: ListTileControlAffinity.leading,
                  )
                else
                  ListTile(
                    key: const Key('objectbox-admin-peak-verified'),
                    title: const Text('Verified'),
                    subtitle: ObjectBoxAdminDetailsValue(
                      label: 'Verified',
                      value: verified,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ObjectBoxAdminReadOnlyFormValue(
                        key: const Key(
                          'objectbox-admin-peak-source-of-truth-label',
                        ),
                        valueKey: ValueKey(('Peak', recordId, 'sourceOfTruth')),
                        label: 'Source of truth',
                        text: sourceOfTruth,
                      ),
                    ),
                    FilledButton(
                      key: const Key('objectbox-admin-peak-source-of-truth'),
                      onPressed: isSaving ? null : onMarkAsHwc,
                      child: const Text('Mark as HWC'),
                    ),
                  ],
                ),
              ],
            ),
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
          key: const Key('objectbox-admin-peak-calculate'),
          onPressed: isSaving || !canCalculate ? null : onCalculate,
          child: const Text('Calculate'),
        ),
        const SizedBox(height: 8),
        ObjectBoxAdminEditFooter(
          prefix: 'peak',
          saveSuffix: 'submit',
          isSaving: isSaving,
          onCancel: onCancel,
          onSave: onSubmit,
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required String keyName,
  }) {
    return ObjectBoxAdminReadOnlyFormValue(
      key: Key(keyName),
      valueKey: ValueKey(('Peak', recordId, keyName)),
      label: label,
      text: value,
    );
  }
}
