/// Stable persisted codes; never reorder or reuse a value.
abstract final class TrackDateStatus {
  static const legacy = 0;
  static const resolved = 1;
  static const legacySkipped = 2;
  static const unresolvedImport = 3;
}
