class RouteGraphLoadException implements Exception {
  const RouteGraphLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
