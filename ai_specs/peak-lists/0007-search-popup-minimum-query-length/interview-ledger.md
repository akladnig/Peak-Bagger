---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this spec target only the AppBar/Search popup flow, or should the new minimum-character behavior also change peak-only searches elsewhere?

Recommended Answer:
- Limit this slice to the AppBar `MapSearchPopup` flow only.
- Use `MapSearchPopup` / `Search popup` as the canonical term for this multi-entity feature.
- Leave peak-only search behavior unchanged in other UIs.

Answer: agreed

Decision: Scope this slice to the map screen `Search popup` (`MapSearchPopup`) flow only, use `Search popup` as the canonical term, and leave unrelated peak-only search behavior unchanged.

Reason: This targets the slow search path without unintentionally changing other peak-picking flows.

### L2

Status: current

Question: Should this spec remove the old peak-only path entirely rather than keep both behaviors in parallel?

Recommended Answer:
- Yes, remove the old peak-only search path from the map flow.
- Keep one canonical search surface: the `Search popup` (`MapSearchPopup`).
- Any remaining map-screen search entry point should open the popup instead of using separate peak-only state or UI.
- Do not keep a hidden fallback or duplicate peak-search logic unless another current screen still depends on it directly.

Answer: agreed

Decision: Remove the separate peak-only map search path and keep one canonical `Search popup` surface for map-screen search entry points.

Negative Requirements:
- Do not keep a hidden fallback or duplicate peak-search logic in the map flow.

### L3

Status: current

Question: When the `Search popup` query is 0 or 1 character after trimming, what should the results area show, and should the app treat that state as "not searched yet" or as "searched but no matches"?

Recommended Answer:
- For 0 characters: keep the current blank results area.
- For 1 character: do not run a real search; show a helper message in the results area: `Type at least 2 characters`.
- If the user deletes from 2+ characters back to 1, clear any previous results immediately and show that helper message.
- Keep filter/sort controls usable while under the threshold.
- Do not show `No results found` until a real 2+ character search has actually run and returned nothing.

Answer: agreed

Decision: Treat under-threshold popup input as a distinct helper state: blank at 0 characters, helper text for non-empty under-threshold queries, immediate clearing of stale results when dropping back under threshold, and `No results found` only after a real threshold-meeting search returns nothing.

### L4

Status: current

Question: Should the minimum-length rule be fixed in the product contract at `2` characters now, or should the spec explicitly treat it as a single app-owned threshold that starts at `2` and may be raised to `3` later without changing the surrounding UX?

Recommended Answer:
- Define one app-owned minimum query length constant for the `Search popup`.
- Set its initial value to `2`.
- Keep all under-threshold behavior the same if that value later changes to `3`.
- Do not expose this as a user setting in this slice.

Answer: agreed. Put this constant in constants.dart

Decision: Define a single app-owned `Search popup` minimum query length constant in `constants.dart`, set its initial value to `2`, keep the surrounding UX stable if the threshold later changes to `3`, and do not expose it as a user setting in this slice.

Reason: Two-character mountain and map prefixes are common enough that `2` is a safer usability default than `3`, while a shared constant preserves the option to tighten the threshold later if profiling still shows performance issues.

### L5

Status: current

Question: When the `Search popup` is under the minimum query length, should the helper text be generated from the shared constant so it automatically changes with the threshold, or should the UI keep a fixed literal message?

Recommended Answer:
- Generate the helper copy from the shared constant in `constants.dart`.
- Use the exact format `Type at least N characters`, where `N` is the current minimum query length.
- Keep that message visible for any non-empty under-threshold query.

Answer: agreed

Decision: Generate the under-threshold helper text from the shared `constants.dart` threshold using the exact visible format `Type at least N characters`.

### L6

Status: current

Question: If the query is still under the minimum length, should changing entity filter, region filter, sort, or group ever trigger a real search anyway, or should the threshold block all search execution until the query reaches the shared minimum?

Recommended Answer:
- The shared minimum-length guard should block all real `Search popup` searches until the trimmed query reaches the threshold.
- While under threshold, entity/filter/sort/group controls may still update their visible selected state.
- Under-threshold control changes should not repopulate stale prior results.
- Once the query reaches the threshold, the current control selections should apply to the first real search immediately.

Answer: agreed

Decision: The shared minimum-length guard blocks all real popup searches until the trimmed query reaches the threshold; under-threshold control changes may update visible state but must not run search or restore stale results, and the first threshold-meeting search must use the current selections.

### L7

Status: current

Question: For this slice, what automated coverage should be required for the new minimum-query behavior in the `Search popup`?

Recommended Answer:
- Require service tests for the minimum-length guard and result clearing behavior.
- Require widget tests for the visible helper message, the transition to `No results found`, and the shared `Search popup` behavior from existing entry points.
- Do not require new robot coverage unless an existing journey already needs a small update because of the new helper text.
- Keep dependencies fake/local; no real storage or external services in tests.

Answer: agreed

Decision: Require service coverage for the threshold guard and result clearing, widget coverage for helper and no-results transitions plus shared popup entry behavior, and no new robot coverage unless an existing journey needs a small helper-text update.

Negative Requirements:
- Do not require real storage, network access, or external services in automated tests.
