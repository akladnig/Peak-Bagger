import 'dart:convert';
import 'dart:io';

class PeakBaggerCommandResult {
  const PeakBaggerCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

typedef PeakBaggerCommandRunner =
    Future<PeakBaggerCommandResult> Function(List<String> command);

class PeakBaggerCommandException implements Exception {
  const PeakBaggerCommandException(this.message);

  final String message;

  @override
  String toString() => 'PeakBaggerCommandException: $message';
}

class PeakBaggerPeakDetails {
  const PeakBaggerPeakDetails({
    required this.peakbaggerPid,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.altName = '',
    this.elevation,
    this.prominence,
    this.country = '',
    this.county = '',
    this.range = '',
    this.osmId,
  });

  final int peakbaggerPid;
  final String name;
  final String altName;
  final double? latitude;
  final double? longitude;
  final double? elevation;
  final double? prominence;
  final String country;
  final String county;
  final String range;
  final int? osmId;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory PeakBaggerPeakDetails.fromJson(Map<String, dynamic> json) {
    final payload = _unwrapPeakJson(json);
    final location = _nestedMap(payload, 'location');
    final elevation = _nestedMap(payload, 'elevation');
    final prominence = _nestedMap(payload, 'prominence');
    final peakbaggerPid = _readInt(payload, const [
      'peakbaggerPid',
      'pid',
      'PeakBagger PID',
      'PeakID',
    ]);
    if (peakbaggerPid == null) {
      throw const FormatException('PeakBagger response is missing a pid.');
    }

    final latitude = _readDouble(location ?? payload, const [
      'latitude',
      'lat',
      'Latitude',
    ]);
    final longitude = _readDouble(location ?? payload, const [
      'longitude',
      'lon',
      'lng',
      'Longitude',
    ]);
    return PeakBaggerPeakDetails(
      peakbaggerPid: peakbaggerPid,
      name: _readString(payload, const ['name', 'Peak', 'peak']) ?? 'Unknown',
      altName:
          _readString(payload, const ['altName', 'AltName', 'alternateName']) ??
          '',
      latitude: latitude,
      longitude: longitude,
      elevation:
          _readDouble(elevation ?? payload, const ['meters']) ??
          _readDouble(payload, const ['elevation', 'ele', 'Elev-M', 'elev_m']),
      prominence:
          _readDouble(prominence ?? payload, const ['meters']) ??
          _readDouble(payload, const [
            'prominence',
            'prom',
            'Prom-M',
            'prom_m',
          ]),
      country:
          _readString(location ?? payload, const ['country', 'Country']) ??
          _readString(payload, const ['country', 'Country']) ??
          '',
      county:
          _readString(location ?? payload, const ['county', 'County']) ??
          _readString(payload, const ['county', 'County']) ??
          '',
      range: _readString(payload, const ['range', 'Range']) ?? '',
      osmId: _readInt(payload, const ['osmId', 'osm_id', 'osmid', 'OSM ID']),
    );
  }

  static Map<String, dynamic>? _nestedMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    return null;
  }

  static Map<String, dynamic> _unwrapPeakJson(Map<String, dynamic> json) {
    final nested = json['peak'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return json;
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value != null) {
        final parsed = int.tryParse(value.toString().trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value != null) {
        final parsed = double.tryParse(value.toString().trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}

abstract class PeakBaggerScraper {
  Future<void> verifyAvailable();
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid);
}

class ProcessPeakBaggerScraper implements PeakBaggerScraper {
  ProcessPeakBaggerScraper({
    PeakBaggerCommandRunner? commandRunner,
    List<String> Function()? availabilityCommandBuilder,
    List<String> Function(int peakbaggerPid)? showCommandBuilder,
  }) : _commandRunner = commandRunner ?? _runProcess,
       _availabilityCommandBuilder =
           availabilityCommandBuilder ?? _defaultAvailabilityCommand,
       _showCommandBuilder = showCommandBuilder ?? _defaultShowCommand;

  final PeakBaggerCommandRunner _commandRunner;
  final List<String> Function() _availabilityCommandBuilder;
  final List<String> Function(int peakbaggerPid) _showCommandBuilder;

  @override
  Future<void> verifyAvailable() async {
    final result = await _commandRunner(_availabilityCommandBuilder());
    if (result.exitCode != 0) {
      throw PeakBaggerCommandException(
        result.stderr.isNotEmpty
            ? result.stderr
            : 'uvx peakbagger is required to sync PeakBagger CSV data.',
      );
    }
  }

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    final result = await _commandRunner(_showCommandBuilder(peakbaggerPid));
    if (result.exitCode != 0) {
      throw PeakBaggerCommandException(
        result.stderr.isNotEmpty
            ? result.stderr
            : 'PeakBagger fetch failed for pid $peakbaggerPid.',
      );
    }

    final decoded = jsonDecode(result.stdout);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('PeakBagger response must be a JSON object.');
    }

    return PeakBaggerPeakDetails.fromJson(decoded);
  }

  static Future<PeakBaggerCommandResult> _runProcess(
    List<String> command,
  ) async {
    final result = await Process.run(
      command.first,
      command.skip(1).toList(growable: false),
    );
    return PeakBaggerCommandResult(
      exitCode: result.exitCode,
      stdout: '${result.stdout}',
      stderr: '${result.stderr}',
    );
  }

  static List<String> _defaultAvailabilityCommand() {
    return const ['uvx', 'peakbagger', '--help'];
  }

  static List<String> _defaultShowCommand(int peakbaggerPid) {
    return [
      'uvx',
      'peakbagger',
      'peak',
      'show',
      '$peakbaggerPid',
      '--format',
      'json',
    ];
  }
}
