import 'package:objectbox/objectbox.dart';

@Entity()
class TrackReplacementRecoveryIssue {
  TrackReplacementRecoveryIssue({
    this.id = 0,
    required this.sourcePath,
    required this.destinationPath,
    this.backupPath,
    required this.reason,
  });

  @Id()
  int id;
  String sourcePath;
  String destinationPath;
  String? backupPath;
  String reason;
}
