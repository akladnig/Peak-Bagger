class ManifestPriority implements Comparable<ManifestPriority> {
  const ManifestPriority(this.segments);

  factory ManifestPriority.parse(String rawValue, {String? regionKey}) {
    final value = rawValue.trim();
    final errorContext = regionKey == null
        ? 'Manifest priority "$rawValue"'
        : 'Region $regionKey has invalid priority "$rawValue"';
    if (value.isEmpty) {
      throw FormatException('$errorContext.');
    }

    final parts = value.split('.');
    if (parts.isEmpty || parts.length > 3) {
      throw FormatException('$errorContext.');
    }

    final segments = <int>[];
    for (final part in parts) {
      if (part.isEmpty) {
        throw FormatException('$errorContext.');
      }

      final parsed = int.tryParse(part);
      if (parsed == null || parsed < 0) {
        throw FormatException('$errorContext.');
      }
      segments.add(parsed);
    }

    return ManifestPriority(List<int>.unmodifiable(segments));
  }

  final List<int> segments;

  @override
  int compareTo(ManifestPriority other) {
    final sharedLength = segments.length < other.segments.length
        ? segments.length
        : other.segments.length;
    for (var index = 0; index < sharedLength; index++) {
      final left = segments[index];
      final right = other.segments[index];
      if (left != right) {
        return left.compareTo(right);
      }
    }

    return segments.length.compareTo(other.segments.length);
  }

  @override
  String toString() {
    return segments.join('.');
  }
}
