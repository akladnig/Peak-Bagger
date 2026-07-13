# Peak Bagger Glossary

This glossary captures stable project-specific terms used across planning and implementation work in this repository.

## Terminology

**Starter app**:
A project-owned reusable Flutter app foundation extracted from this repository for generating new apps with shared UI and infrastructure.
_Avoid_: Flutter template, SDK template

**Track**:
An imported `GpxTrack` that represents a completed recorded walk.
_Avoid_: route when referring to historical walk data

**Route**:
A planned path saved in the app for future use, separate from a completed imported walk.
_Avoid_: track when referring to planned geometry

**Track type**:
The classification of a walked segment derived from app-owned map or trail metadata, rather than a free-text user label.
_Avoid_: user-entered category, manual label

**Hiking difficulty**:
The difficulty classification of a walked segment derived from preserved OSM tags, prioritizing tags such as `sac_scale`, `trail_visibility`, `tracktype`, and `surface`.
_Avoid_: track type when referring to difficulty-specific tagging

**Off-track**:
A moving track segment that does not match any route-graph way closely enough to inherit route-graph metadata.
_Avoid_: unknown/off-network

**Ranked peak list CSV**:
A header-detected peak-list import format produced by region ranking tools such as `tool/rank_fvg_peaks.dart`, where each row identifies an existing peak by `osmId` and can carry shared peak metadata updates plus list membership.
_Avoid_: FVG format

**Hribi source peak list**:
A CSV-only raw peak extract built from `hribi.net` range and detail pages, optionally enriched from sibling translated domains such as `monti.uno`, without matching rows to existing app peaks.
_Avoid_: ranked peak list CSV, import-ready peak list

**Slovenia ranked peak list**:
A Slovenia peak CSV produced by correlating Hribi-sourced rows to existing ObjectBox `Peak` records so the result is import-ready rather than a raw source extract.
_Avoid_: Hribi source peak list, raw Slovenia export

**Correlation review CSV**:
A read-only CSV review artifact for Slovenia rows that could not be confidently correlated to exactly one existing ObjectBox `Peak` record.
_Avoid_: repair list, canonical ranked CSV

**Repair list**:
A sidecar CSV of unresolved range or peak source pages that a later repair-only run retries instead of crawling the full upstream set again.
_Avoid_: retry cache, hidden state file

**Tassy Full**:
A Tasmania-only project-managed peak list intended to represent the full Tasmanian set rather than a cross-region super-set.
_Avoid_: all-lists super-set, non-Tasmanian aggregate

**Italy North East subregion**:
A finer stored/search region key under the broader `italy-nord-est` umbrella, such as `fvg`, `veneto`, `trentino-alto-adige`, or `emilia-romagna`.
_Avoid_: treating these as full top-level manifest regions by default

**Search popup**:
The map screen's `MapSearchPopup` multi-entity search surface, which replaces the older peak-only search experience.
_Avoid_: peak search when referring to the popup flow

**Background job**:
App-managed long-running import or export work with shared status that is not tied to the initiating screen.
_Avoid_: screen-local task, blocking import/export

**Peak ownership ring**:
The segmented ring drawn around a peak marker or peak cluster to show visible peak-list ownership in map rendering.
_Avoid_: list ring, ownership halo
