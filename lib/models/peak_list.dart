import 'dart:convert';

import 'package:objectbox/objectbox.dart';

@Entity()
class PeakList {
  @Id(assignable: true)
  int peakListId;

  @Unique()
  String name;

  String peakList;

  PeakList({this.peakListId = 0, required this.name, required this.peakList});

  PeakList copyWith({int? peakListId, String? name, String? peakList}) {
    return PeakList(
      peakListId: peakListId ?? this.peakListId,
      name: name ?? this.name,
      peakList: peakList ?? this.peakList,
    );
  }
}

class PeakListItem {
  const PeakListItem({required this.peakOsmId, required this.points});

  final int peakOsmId;
  final String points;

  Map<String, Object> toJson() {
    return {'peakOsmId': peakOsmId, 'points': points};
  }

  factory PeakListItem.fromJson(Map<String, dynamic> json) {
    return PeakListItem(
      peakOsmId: json['peakOsmId'] as int,
      points: json['points'] as String,
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
