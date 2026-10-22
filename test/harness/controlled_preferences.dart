import 'package:shared_preferences/shared_preferences.dart';

/// Models the legacy plugin's optimistic cache separately from confirmed storage.
/// Failed writes intentionally leave the cache changed until reload is called.
class ControlledPreferences implements SharedPreferences {
  ControlledPreferences([Map<String, Object> initial = const {}])
    : stored = Map.of(initial),
      _cache = Map.of(initial);

  final Map<String, Object> stored;
  final Map<String, Object> _cache;
  final writes = <({String key, Object? value})>[];
  Future<bool> Function(String key, Object? value)? onWrite;
  Future<void> Function()? onReload;

  @override
  String? getString(String key) => _cache[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _cache[key] = value;
    return _write(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    _cache.remove(key);
    return _write(key, null);
  }

  Future<bool> _write(String key, Object? value) async {
    writes.add((key: key, value: value));
    final accepted = await (onWrite?.call(key, value) ?? Future.value(true));
    if (accepted) {
      if (value == null) {
        stored.remove(key);
      } else {
        stored[key] = value;
      }
    }
    return accepted;
  }

  @override
  Future<void> reload() async {
    await onReload?.call();
    _cache
      ..clear()
      ..addAll(stored);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
