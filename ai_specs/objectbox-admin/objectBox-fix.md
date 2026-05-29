# Fix ObjectBox Issues

Issue identified:

Medium: PeakList.peakList stores cross-entity references as a JSON blob of peakOsmIds rather than ObjectBox relations. lib/models/peak_list.dart:13-15, lib/models/peak_list.dart:44-60, lib/services/peak_repository.dart:83-115, lib/objectbox.g.dart:473-478. That means no referential integrity, no efficient querying, and malformed payloads get skipped during rewrite instead of being repaired. 

Fix it by normalizing the list membership into ObjectBox entities.
Use a join entity instead of JSON:
@Entity()
class PeakList {
  @Id(assignable: true)
  int peakListId = 0;
  @Unique()
  String name;
  PeakList({this.peakListId = 0, required this.name});
}
@Entity()
class PeakListItem {
  @Id(assignable: true)
  int id = 0;
  final peakList = ToOne<PeakList>();
  final peak = ToOne<Peak>();
  int points;
  PeakListItem({
    this.id = 0,
    required this.points,
  });
}
Then:
- Remove PeakList.peakList JSON storage.
- Create PeakListItem rows for each membership.
- Load/export by querying PeakListItem instead of decoding JSON.
- Rewrite PeakListRepository.findPeakListNamesForPeak() to query items, not parse strings.
- Update addPeakItem, updatePeakItemPoints, removePeakItem to edit PeakListItem rows.
- Make peak_repository.rewriteOsmIdReferences() stop touching peak list membership once it is keyed to Peak.id via relation.
- Regenerate lib/objectbox.g.dart and lib/objectbox-model.json.
Migration path:
- Keep the old JSON field temporarily.
- On startup, read each old payload once, create PeakListItem rows, then stop using the JSON field.
- After migration is verified, delete the JSON field and the decode/encode helpers.
