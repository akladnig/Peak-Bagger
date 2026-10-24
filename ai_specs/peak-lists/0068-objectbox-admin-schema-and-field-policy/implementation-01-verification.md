# Work Item 01 verification

Date: 2026-10-20. Scope: [Work Item 01](work-items/01-shared-field-and-data-grid-styling.md), ADS-1.0 amendment 2026-10-19, Desktop wide.

## Implementation and consumer audit

| Shared owner / consumer | Change and regression coverage |
| --- | --- |
| `lib/theme.dart` fields | Central 14/24 tokens, dense always-visible ordinary labels, default outline shape, semantic idle / effective-seed hover and focus borders, validation/disabled priority. Filled-field hover resolves its complete selected-Data-matched colour once, with transparent extra hover layer. `test/theme_test.dart` and `test/widget/shared_field_grid_theme_test.dart` verify exact roles and actual painted pixels in light/dark with default/custom seeds. |
| `DataGridTheme` | Existing metrics retained, local onPrimary dividers, effective-seed dark selection, HSL shading, 10%-white hover, composited press colour and independent primary focus border. The global scheme now retains its generated outlineVariant; it is no longer repurposed for Admin dividers. |
| Admin controls / five editor forms | Removed local border overrides, retained controllers, validation, input, actions and submission callbacks. Admin detail dividers consume the local grid role; Edit/Close have accessible desktop tooltips. Browser, shell, Natural Feature, service/editor and existing robot tests cover retained behaviour. A scaled Peak source-of-truth action row now wraps instead of overflowing; its action is unchanged. |
| Admin grid | Selection > press > hover, disabled-row feedback suppression, independent foreground focus border without changing row geometry, and red trailing trash with proper disabled foreground. Existing Waypoints grid coverage retains sorting, keyboard activation, row/delete semantics and scrolling; new theme widget coverage exercises states across both themes/seeds. |
| Peak List summary/details | Consume the amended grid extension without changing their data, widths, sort, selection, domain formatting or deletion. `test/widget/peak_lists_screen_test.dart` covers their existing interactions and styling. No unrelated row/layout rewrite. |
| Peak multi-select | Consumes new grid roles; disabled/selection-limit rows no longer gain hover/press feedback. Checked-green domain indicator, selection limits and keyboard activation retained. `test/widget/peak_multi_select_results_list_test.dart`. |
| Map Search | Result rows inherit grid roles; input inherits central decoration rather than overriding it. Its 24-pixel leading Search icon remains decorative. Existing debounce, Enter, filtering, grouping, date picker, selection and navigation are unchanged. `map_screen_peak_search_test.dart`, `map_screen_appbar_search_test.dart` and existing appbar Search robot regression cover these consumers. The appbar test harness now uses approved 1280 × 960 content, not its implicit unsupported 800 × 600 surface. |
| Search/mode style and 14/24 consumers | Shared selected-mode layer reused by fields, mode buttons and Admin Schema/Data toggle. Consumers include drawer outline buttons, peak-list controls/summary, map peak-list drawer and elevation-profile controls. Existing drawer/chart/Peak List/Map tests and full-suite regressions cover their actions; no filter, submission or Settings redesign. |
| Icon / labelled button themes | Circular state backing paints once, transparent idle/focus-only backing, onSurface hover/press, independent primary focus outline, disabled dim/basic cursor. Labelled FilledButtons retain primaryContainer/onPrimaryContainer and central 12-pixel shape. Actual rendered icon hover/press/focus/disabled and selected-mode fill are checked, not only theme inheritance. |

GPU overlay assertions allow one 8-bit channel step for alpha quantisation; unit assertions check the exact floating-point colour formulas. Precomposited field and mode fills are checked as exact rendered 8-bit colours.

## Layout and native checks

- Widget checks: 1280 × 960, 1600 × 960 and 1920 × 1200, including 2× text, visible labels/errors, accessible Save/Close, live light/custom-dark/light rollback and an unsaved draft through resizing. The real routed Admin browser retains its Peak draft; the isolated field check samples the updated hovered fill after live theme changes.
- Native command: `flutter run -d macos -t test/harness/verify_shared_admin_theme.dart`.
- Native macOS/Metal smoke: **24 configurations passed** — 1280 × 960 → 1600 × 1000 → 1280 × 960; light/dark, default/teal expressive seed, 1×/2× text. Actual Admin controls, grid and Route editor retain the same controller/draft and reachable Entity/Name/Save controls with no framework errors. No production startup, Store, Mapping volume, credentials or external service is used; this is an isolated component-composition check, not whole-app visual acceptance.
- The smoke tool temporarily resizes only its own native window using Accessibility/osascript, then restores its original frame. It needs enough display area for 1600 × 1000 content and existing macOS Accessibility permission. It changes no native window source, app minimum, launch-maximisation policy, breakpoint or full-screen decision. The first attempt correctly rejected a restored 832-point-high native viewport; the explicit test-window resize allowed the supported-size checks. Flutter printed `Resize timed out` during final fixture teardown/frame restoration after all 24 checks passed.
- Upstream build warnings: ObjectBox SwiftPM fallback and geolocator CoreLocation deprecations, as already documented in `README.md`. Native tooling regenerated `macos/Podfile.lock`; its pre-existing user changes were recovered exactly from the pre-build snapshot and are excluded from this work.

## Commands and outcomes

- `flutter test test/theme_test.dart` and focused rendered theme tests: pass (27 tests together).
- Initial affected consumer/Admin/drawer/chart/robot regression run: pass (206 tests).
- Final focused theme/browser/appbar regression run: pass (47 tests).
- `flutter analyze`: pass, no issues.
- `git diff --check`: pass.
- Full suite: **PASS — 2694 tests, 7 skips**, using `TZ=Australia/Hobart flutter test --reporter expanded` (12:27). The first attempt hit the execution timeout and exposed the repository's explicit `TZ=Australia/Hobart` or `TZ=UTC` test prerequisite. The subsequent complete run had 2692 passes, 7 skips and two inventory-guard failures because the new UI smoke runner was under `tool/`; it was moved to the existing `test/harness/` surface rather than adding a Mapping-tool exception. Its 13 inventory-guard tests and analysis then passed, followed by the green full rerun. The added scaled Admin and affected Search harness findings above were fixed before rerunning.

## Scope boundaries / remaining feature work

Work Item 01 adds no database/model/generated edits, migration, preference, write boundary, schema table, policy-driven form generator, new create flow, Cancel policy or five-line viewport implementation. Those remain the dependent Work Items.

Admin's pre-existing trailing explicit Search action is retained (now centrally sized and accessibly named) because this item explicitly preserves submission/filter/shortcut semantics. This is a visible standard-alignment gap, not an approved exception to the decorative-leading-icon/no-submit/live-Search baseline. No new field action or tooltip was added. Broader Search behaviour and other separable whole-app baseline gaps are not silently declared compliant by completing this bounded prerequisite.
