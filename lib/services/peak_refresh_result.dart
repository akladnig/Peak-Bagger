class PeakRefreshResult {
  const PeakRefreshResult({
    required this.importedCount,
    required this.skippedCount,
    this.warning,
  });

  final int importedCount;
  final int skippedCount;
  final String? warning;
}
