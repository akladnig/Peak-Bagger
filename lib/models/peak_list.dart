import 'dart:convert';

import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/peak.dart';

@Entity()
class PeakList {
  @Id(assignable: true)
  int peakListId;

  @Unique()
  String name;

  String region;

  String peakList;

  int colour;

  PeakList({
    this.peakListId = 0,
    required this.name,
    this.region = Peak.defaultRegion,
    required this.peakList,
    this.colour = 0,
  });

  PeakList copyWith({
    int? peakListId,
    String? name,
    String? region,
    String? peakList,
    int? colour,
  }) {
    return PeakList(
      peakListId: peakListId ?? this.peakListId,
      name: name ?? this.name,
      region: region ?? this.region,
      peakList: peakList ?? this.peakList,
      colour: colour ?? this.colour,
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
