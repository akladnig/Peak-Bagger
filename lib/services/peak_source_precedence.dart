/// Approved source ownership, independent of import order or polygon priority.
/// NE also outranks Croatia through the NE > Slovenia > Croatia hierarchy.
const preferredPeakSourceRegions = <String, List<String>>{
  'italy-nord-ovest': ['italy-nord-est'],
  'slovenia': ['italy-nord-est'],
  'croatia': ['italy-nord-est', 'slovenia'],
};
