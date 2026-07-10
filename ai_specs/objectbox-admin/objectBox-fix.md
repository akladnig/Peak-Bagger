# Normalize Peak List Membership Storage

Issue identified:

Medium: current code stores PeakList membership as a JSON blob in `PeakList.peakList` (`lib/models/peak_list.dart`, `lib/services/peak_list_repository.dart`, `lib/services/peak_repository.dart`), so every membership change must decode and rewrite the full payload. That means no referential integrity, no direct querying, and malformed payloads can only be handled by JSON parsing logic.

Fix it by normalizing list membership into ObjectBox entities.
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
  int position;
  int points;
  PeakListItem({
    this.id = 0,
    required this.position,
    required this.points,
  });
}
Then:
- Update every peak-list membership call site to use the relational schema.
- No new code should read or write membership JSON after the migration path is complete.
- Remove `PeakList.peakList` JSON storage after migration.
- Create `PeakListItem` rows for each membership in stored order.
- Preserve membership order with `PeakListItem.position`.
- Load/export by querying `PeakListItem` and following the `Peak` relation.
- Rewrite `PeakListRepository.findPeakListNamesForPeak()` to query items, not parse strings.
- Update `addPeakItem`, `updatePeakItemPoints`, `removePeakItem` to edit `PeakListItem` rows.
- Make `peak_repository.rewriteOsmIdReferences()` stop touching peak list membership once it is keyed to `Peak` via relation.
- Regenerate lib/objectbox.g.dart and lib/objectbox-model.json.
Migration path:
- Keep the old JSON field temporarily.
- On startup, read each legacy payload once, create `PeakListItem` rows in payload order, then stop using the JSON field.
- After migration is verified, delete the JSON field and the decode/encode helpers.
- Treat malformed legacy payloads as migration failures that need visibility instead of silent drops.
