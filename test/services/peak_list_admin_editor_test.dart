import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_admin_editor.dart';

void main() {
  test('validateAndBuild preserves non-editable PeakList fields', () {
    final source = PeakList(
      peakListId: 7,
      name: 'Abels',
      region: 'tasmania',
      colour: 1,
      minLat: 0,
      maxLat: 1,
      minLng: 2,
      maxLng: 3,
    );

    final result = PeakListAdminEditor.validateAndBuild(
      source: source,
      form: const PeakListAdminFormState(colour: '0x00000002'),
    );

    expect(result.isValid, isTrue);
    expect(result.peakList, isNotNull);
    expect(result.peakList!.peakListId, 7);
    expect(result.peakList!.name, 'Abels');
    expect(result.peakList!.region, 'tasmania');
    expect(result.peakList!.colour, 2);
    expect(result.peakList!.minLat, 0);
    expect(result.peakList!.maxLat, 1);
    expect(result.peakList!.minLng, 2);
    expect(result.peakList!.maxLng, 3);
    expect(source.colour, 1);
    expect(PeakListAdminEditor.normalize(source).colour, '0x00000001');
  });
}
