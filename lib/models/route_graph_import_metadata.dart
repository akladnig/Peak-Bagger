import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphImportMetadata {
  static const metadataId = 1;

  @Id(assignable: true)
  int id;

  bool multiCoverageMigrationComplete;
  int lastReservedGeneration;

  RouteGraphImportMetadata({
    this.id = metadataId,
    this.multiCoverageMigrationComplete = false,
    this.lastReservedGeneration = 0,
  });
}
