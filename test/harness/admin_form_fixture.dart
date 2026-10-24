import 'package:flutter/material.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/services/objectbox_admin_field_policy.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

/// Committed records and controlled saves; never opens a Store or app services.
class AdminFormFixture {
  AdminFormFixture(
    this.name, {
    this.id = 7,
    this.createMode = false,
    String text = 'Committed value',
    Map<String, Map<String, AdminFieldMetadata>>? metadata,
  }) {
    entity = ObjectBoxAdminRepositoryImpl(
      appMetadata: metadata ?? objectBoxAdminAppMetadata,
    ).getEntities().singleWhere((entity) => entity.name == name);
    peak = Peak(
      id: id,
      osmId: 123,
      name: 'Fixture',
      notes: text,
      latitude: -41.5,
      longitude: 146.5,
    );
    feature = NaturalFeature(
      id: id,
      osmType: 'way',
      osmId: 123,
      name: 'Fixture',
      tag: 'water',
      latitude: -41.5,
      longitude: 146.5,
      gridZoneDesignator: '55G',
    );
    contact = Contact(id: id, firstName: 'Fixture');
    route = app_route.Route(id: id, name: 'Fixture', desc: text);
    peakList = PeakList(peakListId: id, name: text, region: text);
    row = switch (name) {
      'Peak' => peakToAdminRow(peak),
      'NaturalFeature' => naturalFeatureToAdminRow(feature),
      'Contact' => contactToAdminRow(contact),
      'Route' => routeToAdminRow(route),
      'PeakList' => peakListToAdminRow(peakList),
      _ => throw ArgumentError.value(name),
    };
  }

  static const names = [
    'Peak',
    'NaturalFeature',
    'Contact',
    'Route',
    'PeakList',
  ];
  final String name;
  final int id;
  final bool createMode;
  late final ObjectBoxAdminEntityDescriptor entity;
  late final ObjectBoxAdminRow row;
  late final Peak peak;
  late final NaturalFeature feature;
  late final Contact contact;
  late final app_route.Route route;
  late final PeakList peakList;
  final submitted = <Object>[];
  int closes = 0;
  Future<String?> Function()? save;

  String get prefix => switch (name) {
    'NaturalFeature' => 'natural-feature',
    'PeakList' => 'peak-list',
    _ => name.toLowerCase(),
  };
  String get formKey => 'objectbox-admin-$prefix-edit-form';
  String get editKey => 'objectbox-admin-$prefix-edit';
  String get saveKey =>
      'objectbox-admin-$prefix-${name == 'Peak' ? 'submit' : 'save'}';

  Future<String?> _submit(Object value) async {
    submitted.add(value);
    return await save?.call();
  }

  Widget pane() => ObjectBoxAdminDetailsPane(
    row: row,
    entity: entity,
    peakList: name == 'PeakList' ? peakList : null,
    route: name == 'Route' ? route : null,
    naturalFeature: name == 'NaturalFeature' ? feature : null,
    contact: name == 'Contact' ? contact : null,
    isCreatingPeak: createMode && name == 'Peak',
    isCreatingContact: createMode && name == 'Contact',
    isNaturalFeatureMutationLocked: false,
    createOsmId: 123,
    onClose: () => closes++,
    onViewPeakOnMap: (_) {},
    onViewNaturalFeatureOnMap: (_) {},
    onViewGpxTrackOnMap: null,
    onViewRouteOnMap: null,
    onPeakSubmit: _submit,
    onPeakListSubmit: _submit,
    onRouteSubmit: _submit,
    onNaturalFeatureSubmit: _submit,
    onContactSubmit: _submit,
  );
}
