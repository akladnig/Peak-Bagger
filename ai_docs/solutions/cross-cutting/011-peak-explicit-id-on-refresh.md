---
title: Peak Explicit Sequential ID Assignment on Refresh
date: 2026-04-19
work_type: feature
tags: [objectbox, peak-refresh, id-assignment]
confidence: high
references: [lib/services/peak_refresh_service.dart, lib/services/peak_repository.dart, lib/models/peak.dart]
---

## Summary

When refreshing peaks from Overpass, we needed explicit sequential ID assignment instead of relying on ObjectBox auto-assignment. Setting `id = 0` does NOT restart numbering—ObjectBox continues from its internal sequence. To get IDs starting from 1, we must assign explicit IDs ourselves.

This matters because peak bagging requires stable, predictable peak IDs that users can reference.

## Reusable Insights

- ObjectBox `@Id` with auto-assignment continues from the last used ID, not from 1. Setting `id = 0` before insert does NOT reset the sequence.
- To get predictable sequential IDs (e.g., 1, 2, 3...), explicitly assign them before calling `box.putMany()`.
- The pattern used here: compute max existing ID, then assign `maxId + 1`, `maxId + 2`, etc. for new peaks.
- For refresh with protection (HWC peaks first), assign HWC peaks IDs starting from 1, then OSM peaks from `hwcCount + 1`.

## The Code Pattern

```dart
// In peak_repository.dart
Future<void> replaceAll(List<Peak> peaks) async {
  final box = store.box<Peak>();
  
  // Compute explicit IDs
  final existingIds = box.getAll().map((p) => p.id).toList()..sort();
  final maxId = existingIds.isEmpty ? 0 : existingIds.last;
  
  // Assign sequential IDs starting from maxId + 1
  for (var i = 0; i < peaks.length; i++) {
    peaks[i] = peaks[i].copyWith(id: maxId + 1 + i);
  }
  
  box.removeAll();
  box.putMany(peaks);
}
```

## Validation

- `flutter analyze`
- `flutter test`
- Verify peak IDs are sequential and start from 1 after fresh import/refresh