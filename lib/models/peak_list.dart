import 'dart:convert';

import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/peak.dart';

const _peakListCopyWithUnset = Object();

@Entity()
class PeakList {
  static const mixedRegion = 'mixed';

  @Id(assignable: true)
  int peakListId;

  @Unique()
  String name;

  String region;

  String peakList;

  int colour;

  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;

  PeakList({
    this.peakListId = 0,
    required this.name,
    this.region = Peak.defaultRegion,
    required this.peakList,
    this.colour = 0,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
  });

  PeakList copyWith({
    int? peakListId,
    String? name,
    String? region,
    String? peakList,
    int? colour,
    Object? minLat = _peakListCopyWithUnset,
    Object? maxLat = _peakListCopyWithUnset,
    Object? minLng = _peakListCopyWithUnset,
    Object? maxLng = _peakListCopyWithUnset,
  }) {
    return PeakList(
      peakListId: peakListId ?? this.peakListId,
      name: name ?? this.name,
      region: region ?? this.region,
      peakList: peakList ?? this.peakList,
      colour: colour ?? this.colour,
      minLat: identical(minLat, _peakListCopyWithUnset)
          ? this.minLat
          : minLat as double?,
      maxLat: identical(maxLat, _peakListCopyWithUnset)
          ? this.maxLat
          : maxLat as double?,
      minLng: identical(minLng, _peakListCopyWithUnset)
          ? this.minLng
          : minLng as double?,
      maxLng: identical(maxLng, _peakListCopyWithUnset)
          ? this.maxLng
          : maxLng as double?,
    );
  }
}

class PeakListItem {
  const PeakListItem({required this.peakOsmId, required this.points});

  final int peakOsmId;
  final int points;

  Map<String, Object> toJson() {
    return {'peakOsmId': peakOsmId, 'points': points};
  }

  factory PeakListItem.fromJson(Map<String, dynamic> json) {
    return PeakListItem(
      peakOsmId: json['peakOsmId'] as int,
      points: json['points'] as int,
    );
  }
}

String encodePeakListItems(List<PeakListItem> items) {
  return json.encode(
    items.map((item) => item.toJson()).toList(growable: false),
  );
}

List<PeakListItem> decodePeakListItems(String payload) {
  final decoded = json.decode(payload);
  if (decoded is! List) {
    throw const FormatException(
      'Peak list payload must decode to a JSON array.',
    );
  }

  return decoded
      .map((entry) => PeakListItem.fromJson(entry as Map<String, dynamic>))
      .toList(growable: false);
}
