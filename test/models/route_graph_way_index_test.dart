import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';

void main() {
  test('RouteGraphWayIndex carries the expected row shape', () {
    final row = RouteGraphWayIndex(
      recordKey: RouteGraphWayIndex.recordKeyFor(
        generation: 12,
        chunkKey: '3_4',
        osmWayId: 42,
      ),
      generation: 12,
      chunkKey: '3_4',
      osmWayId: 42,
      highway: 'footway',
      surface: 'gravel',
      footway: 'sidewalk',
      foot: 'yes',
      route: 'mtb',
      access: 'private',
      name: 'Main Track',
      normalizedName: 'main track',
      lengthMeters: 513,
      tagCount: 7,
      tagsJson: '{"highway":"footway"}',
    );

    expect(row.recordKey, '12|3_4|42');
    expect(row.generation, 12);
    expect(row.chunkKey, '3_4');
    expect(row.osmWayId, 42);
    expect(row.highway, 'footway');
    expect(row.surface, 'gravel');
    expect(row.footway, 'sidewalk');
    expect(row.foot, 'yes');
    expect(row.route, 'mtb');
    expect(row.access, 'private');
    expect(row.name, 'Main Track');
    expect(row.normalizedName, 'main track');
    expect(row.lengthMeters, 513);
    expect(row.tagCount, 7);
    expect(row.tagsJson, '{"highway":"footway"}');
  });
}
