import 'package:peak_bagger/models/peak_list.dart';

const defaultFABPalette = <int>[
  0xFF4C8BF5,
  0xFF12B886,
  0xFF6347EA,
  0xFFE67E22,
  0xFFD6336C,
  0xFF0EA5E9,
  0xFFA16207,
  0xFF7C4DFF,
];

int defaultPeakListColourForId(int peakListId) {
  final paletteLength = defaultFABPalette.length;
  final index = (peakListId - 1).remainder(paletteLength);
  return defaultFABPalette[index < 0 ? index + paletteLength : index];
}

int resolvePeakListColour(PeakList peakList) {
  return peakList.colour != 0
      ? peakList.colour
      : defaultPeakListColourForId(peakList.peakListId);
}
