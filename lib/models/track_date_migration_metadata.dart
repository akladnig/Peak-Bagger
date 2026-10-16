import 'package:objectbox/objectbox.dart';

/// Database-owned completion record; travels with an ObjectBox backup.
@Entity()
class TrackDateMigrationMetadata {
  static const metadataId = 1;
  static const migrationKey = 'track_location_calendar_day';

  @Id(assignable: true)
  int id;
  String key;
  int completedVersion;
  @Property(type: PropertyType.dateUtc)
  DateTime? completedAt;
  String geographicDataVersion;
  String ianaDataVersion;
  int updatedCount;
  int unchangedCount;
  int skippedCount;
  String skippedRecordsJson;

  TrackDateMigrationMetadata({
    this.id = metadataId,
    this.key = migrationKey,
    this.completedVersion = 0,
    this.completedAt,
    this.geographicDataVersion = '',
    this.ianaDataVersion = '',
    this.updatedCount = 0,
    this.unchangedCount = 0,
    this.skippedCount = 0,
    this.skippedRecordsJson = '[]',
  });
}
