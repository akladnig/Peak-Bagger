import 'package:objectbox/objectbox.dart';

@Entity()
class PeakRegionFingerprint {
  PeakRegionFingerprint({
    this.id = 0,
    required this.regionKey,
    required this.fingerprint,
  });

  @Id()
  int id;

  @Unique()
  String regionKey;

  String fingerprint;
}
