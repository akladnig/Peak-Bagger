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

  int colour;

  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;

  PeakList({
    this.peakListId = 0,
    required this.name,
    this.region = Peak.defaultRegion,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeakListItem &&
          other.peakOsmId == peakOsmId &&
          other.points == points;

  @override
  int get hashCode => Object.hash(peakOsmId, points);

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

@Entity()
class PeakListItemEntity {
  PeakListItemEntity({this.id = 0, required this.points});

  @Id()
  int id;

  final peakList = ToOne<PeakList>();
  final peak = ToOne<Peak>();

  int points;
}
