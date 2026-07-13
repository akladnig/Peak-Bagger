import 'dart:convert';

import 'package:objectbox/objectbox.dart';

@Entity()
class RouteGraphChunk {
  @Id(assignable: true)
  int id;

  @Unique()
  String recordKey;

  String chunkKey;
  int generation;
  double minLat;
  double minLon;
  double maxLat;
  double maxLon;
  int elementCount;
  String payloadJson;

  RouteGraphChunk({
    this.id = 0,
    required this.recordKey,
    required this.chunkKey,
    required this.generation,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
    required this.elementCount,
    required this.payloadJson,
  });

  Map<String, dynamic> decodePayload() {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Route graph chunk payload must be JSON object.',
      );
    }
    return decoded;
  }

  RouteGraphChunk copyWith({
    int? id,
    String? recordKey,
    String? chunkKey,
    int? generation,
    double? minLat,
    double? minLon,
    double? maxLat,
    double? maxLon,
    int? elementCount,
    String? payloadJson,
  }) {
    return RouteGraphChunk(
      id: id ?? this.id,
      recordKey: recordKey ?? this.recordKey,
      chunkKey: chunkKey ?? this.chunkKey,
      generation: generation ?? this.generation,
      minLat: minLat ?? this.minLat,
      minLon: minLon ?? this.minLon,
      maxLat: maxLat ?? this.maxLat,
      maxLon: maxLon ?? this.maxLon,
      elementCount: elementCount ?? this.elementCount,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }
}
