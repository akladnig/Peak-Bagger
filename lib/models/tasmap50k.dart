import 'package:objectbox/objectbox.dart';

@Entity()
class Tasmap50k {
  @Id()
  int id = 0;

  String series;
  String name;
  String parentSeries;
  String mgrs100kIds;
  int eastingMin;
  int eastingMax;
  int northingMin;
  int northingMax;
  String mgrsMid;
  int eastingMid;
  int northingMid;
  String p1;
  String p2;
  String p3;
  String p4;
  String p5;
  String p6;
  String p7;
  String p8;

  Tasmap50k({
    this.id = 0,
    required this.series,
    required this.name,
    required this.parentSeries,
    this.mgrs100kIds = '',
    this.eastingMin = 0,
    this.eastingMax = 0,
    this.northingMin = 0,
    this.northingMax = 0,
    this.mgrsMid = '',
    this.eastingMid = 0,
    this.northingMid = 0,
    this.p1 = '',
    this.p2 = '',
    this.p3 = '',
    this.p4 = '',
    this.p5 = '',
    this.p6 = '',
    this.p7 = '',
    this.p8 = '',
  });

  List<String> get mgrs100kIdList =>
      mgrs100kIds.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

  List<String> get polygonPoints => [
    p1,
    p2,
    p3,
    p4,
    p5,
    p6,
    p7,
    p8,
  ].where((point) => point.isNotEmpty).toList(growable: false);

  bool get hasValidPolygonPointCount =>
      const {4, 6, 8}.contains(polygonPoints.length);
}
