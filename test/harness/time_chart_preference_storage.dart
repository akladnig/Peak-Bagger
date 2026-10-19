import 'package:peak_bagger/providers/time_chart_type_provider.dart';

/// Controllable durable storage: failed writes never change the restart value.
class TestTimeChartPreferenceStorage implements TimeChartPreferenceStorage {
  TestTimeChartPreferenceStorage([this.stored]);

  String? stored;
  int reads = 0;
  int activeWrites = 0;
  int maxActiveWrites = 0;
  final writes = <String>[];
  final readSteps = <Future<String?> Function()>[];
  final writeSteps = <Future<bool> Function()>[];

  @override
  Future<String?> read() {
    reads++;
    return readSteps.isEmpty ? Future.value(stored) : readSteps.removeAt(0)();
  }

  @override
  Future<bool> write(String value) async {
    writes.add(value);
    activeWrites++;
    if (activeWrites > maxActiveWrites) maxActiveWrites = activeWrites;
    try {
      final success = writeSteps.isEmpty
          ? true
          : await writeSteps.removeAt(0)();
      if (success) stored = value;
      return success;
    } finally {
      activeWrites--;
    }
  }
}
