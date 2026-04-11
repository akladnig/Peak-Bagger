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
  String tl;
  String tr;
  String bl;
  String br;

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
    this.tl = '',
    this.tr = '',
    this.bl = '',
    this.br = '',
  });

  List<String> get mgrs100kIdList =>
      mgrs100kIds.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}
