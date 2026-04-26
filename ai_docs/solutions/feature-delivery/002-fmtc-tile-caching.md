---
title: FMTC Tile Caching Integration for flutter_map
date: 2026-04-26
work_type: investigation
tags: [flutter, flutter_map, tile-caching, offline, objectbox, dependency-conflict]
confidence: medium
references: [lib/services/tile_downloader.dart, lib/screens/settings_screen.dart]
---

## Summary

Investigated integrating flutter_map_tile_caching for persistent tile caching. Abandoned due to objectbox version conflict. Reverted to existing TileDownloader solution.

## Dependency Resolution

**Tested combinations:**
- FMTC ^10.1.1 + objectbox ^4.1.0 = INCOMPATIBLE with existing app (objectbox.g.dart generated with 5.x)
- FMTC ^11.0.0-dev.2 + objectbox ^4.1.0 = INCOMPATIBLE with existing app
- FMTC git main (unreleased) = hangs, not usable

**Core conflict:** FMTC requires objectbox ^4.x due to flat_buffers version mismatch with objectbox ^5.3.1. The app's objectbox.g.dart was generated with objectbox 5.x, so regenerating with 4.x fails.

**Future:** FMTC v10.1.2 (PR #195) promises objectbox ^5 compatibility but hasn't been released yet.

## Existing Solution

The app already has `TileDownloader` in `lib/services/tile_downloader.dart` which handles offline tile downloads. The Settings screen "Download Offline Tiles" uses this.

## Key Files

- `lib/services/tile_downloader.dart` - existing manual tile downloader
- `lib/services/tile_cache_service.dart` - was created but deleted (FMTC attempt)
- `lib/screens/settings_screen.dart` - uses TileDownloader (unchanged)