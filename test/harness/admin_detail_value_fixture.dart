import 'package:flutter/material.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

/// Stable committed objects across rebuilds, with no Store, services or startup.
class AdminDetailValueFixture {
  AdminDetailValueFixture(this.entityName, this.text, {int id = 1}) {
    entity = ObjectBoxAdminRepositoryImpl().getEntities().singleWhere(
      (entity) => entity.name == entityName,
    );
    peak = Peak(
      id: id,
      name: 'Fixture',
      altName: text,
      latitude: 46,
      longitude: 13,
    );
    route = app_route.Route(id: id, name: 'Fixture', desc: text);
    peakList = PeakList(peakListId: id, name: 'Fixture', region: text);
    feature = NaturalFeature(
      id: id,
      name: 'Fixture',
      altName: text,
      tag: 'water',
      latitude: 46,
      longitude: 13,
      osmId: 123,
      osmType: 'way',
    );
    contact = Contact(id: id, firstName: 'Fixture', surname: text);
    row = switch (entityName) {
      'Peak' => peakToAdminRow(peak),
      'Route' => routeToAdminRow(route),
      'PeakList' => peakListToAdminRow(peakList),
      'NaturalFeature' => naturalFeatureToAdminRow(feature),
      'Contact' => contactToAdminRow(contact),
      _ => ObjectBoxAdminRow(
        primaryKeyValue: id,
        values: {
          'id': id,
          'name': 'Fixture',
          'type': text,
          'latitude': 46.0,
          'longitude': 13.0,
          'mgrs': text,
        },
      ),
    };
  }

  static const entities = [
    'Waypoints',
    'Peak',
    'Route',
    'PeakList',
    'NaturalFeature',
    'Contact',
  ];
  final String entityName;
  final String text;
  late final ObjectBoxAdminEntityDescriptor entity;
  late final ObjectBoxAdminRow row;
  late final Peak peak;
  late final app_route.Route route;
  late final PeakList peakList;
  late final NaturalFeature feature;
  late final Contact contact;
  int writes = 0;
  int closes = 0;

  String get longField => switch (entityName) {
    'Peak' || 'NaturalFeature' => 'altName',
    'Route' => 'desc',
    'PeakList' => 'region',
    'Contact' => 'surname',
    _ => 'type',
  };

  Future<String?> _unexpectedWrite() async {
    writes++;
    return 'Fixture does not save';
  }

  Widget pane() => ObjectBoxAdminDetailsPane(
    row: row,
    entity: entity,
    peakList: entityName == 'PeakList' ? peakList : null,
    route: entityName == 'Route' ? route : null,
    naturalFeature: entityName == 'NaturalFeature' ? feature : null,
    contact: entityName == 'Contact' ? contact : null,
    isCreatingPeak: false,
    isNaturalFeatureMutationLocked: false,
    createOsmId: 0,
    onClose: () => closes++,
    onViewPeakOnMap: (_) {},
    onViewNaturalFeatureOnMap: (_) {},
    onViewGpxTrackOnMap: null,
    onViewRouteOnMap: null,
    onPeakSubmit: (_) => _unexpectedWrite(),
    onPeakListSubmit: (_) => _unexpectedWrite(),
    onRouteSubmit: (_) => _unexpectedWrite(),
    onNaturalFeatureSubmit: (_) => _unexpectedWrite(),
    onContactSubmit: (_) => _unexpectedWrite(),
  );
}
