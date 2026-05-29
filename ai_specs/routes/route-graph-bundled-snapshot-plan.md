## Overview

Bundled `assets/highway.json` route graph with startup-ready route drafting and Settings validation.

**Spec**: `ai_specs/routes/route-graph-bundled-snapshot-spec.md`

## Status

- [x] Bundled snapshot is the default route-graph source
- [x] Route creation is enabled at startup
- [x] Route planning keeps the draft editable on load failure
- [x] Settings validates the bundled route graph snapshot
- [x] No route-graph code references configurable endpoints or localhost services
- [x] Route and settings journeys are covered by widget and robot tests

## Notes

- The old local-overpass framing has been removed from the implementation.
- Public Overpass references remain only in peak refresh code, not route graph code.
