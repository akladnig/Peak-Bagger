import 'package:objectbox/objectbox.dart';

@Entity()
class PeaksBagged {
  @Id(assignable: true)
  int baggedId = 0;

  int peakId;
  int gpxId;

  @Property(type: PropertyType.dateUtc)
  DateTime? date;

  PeaksBagged({
    this.baggedId = 0,
    required this.peakId,
    required this.gpxId,
    this.date,
  });
}
