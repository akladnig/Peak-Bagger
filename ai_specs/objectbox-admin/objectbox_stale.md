
Found the real issue.
- GpxTrack was changed to @Id(assignable: true), but ObjectBox’s generated model was still stale.
- At runtime, reset could fail during persistence, which explains both symptoms:
  - only a few rows made it into ObjectBox
  - no success dialog appeared because resetTrackData() returned null
What I changed:
- Regenerated ObjectBox metadata:
  - lib/objectbox.g.dart
  - lib/objectbox-model.json
- Added visible reset-failure UI in Settings:
  - inline trackImportError
  - failure dialog: Track Data Reset Failed
- Kept the success dialog path for successful resets
