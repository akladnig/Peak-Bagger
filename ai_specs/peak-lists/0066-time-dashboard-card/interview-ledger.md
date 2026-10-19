---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What new dashboard content is requested?

Answer: Add Time alongside Distance, Elevation, and Peaks Bagged, displaying two series named `Total Time` and `Moving Time`. Total Time uses the existing primary chart colour derived from the theme; Moving Time uses the existing green secondary colour.

Decision: Add a Time card to the existing Dashboard, with two time series and the established chart palette.

Source: Initial request, interpreted in the existing Dashboard-card context throughout the interview.

### L2

Status: current

Question: Should Total Time and Moving Time have exactly the same meanings as the existing Track details?

Recommended Answer:
- Total Time is recorded time within Track segments, including resting time but excluding gaps between recording segments (`Paused Time`).
- Moving Time is Total Time minus resting time.
- A walk with four hours moving, one hour resting, and a thirty-minute recording gap contributes five hours Total Time and four hours Moving Time.

Answer: yes

Decision: Reuse the existing stored Track durations and their meanings. Record the durable definitions in root `GLOSSARY.md`.

### L3

Status: current

Question: How should the new card compare with the existing charts, and which chart types should it offer?

Answer: "So there is an issue with consistency between the existing charts, so use distance as the reference and yes, add a third chart type using two side-by-side columns and add that choice to the chart selection, so 'Stacked column view' (replaces 'Switch to column view') use icons.stacked-bar-chart, 'Line view', 'Clustered column view' (for two side-by-side) use the current column icon. For now apply this only to the new chart. Others will need to be updated later"

Decision: Distance is the reference. Offer `Stacked column view` with `Icons.stacked_bar_chart`, `Line view` with the existing line icon (`Icons.show_chart`), and `Clustered column view` with the existing column icon (`Icons.bar_chart`). Apply the new selection/types only to Time.

Answer History:
- The interviewer initially recommended side-by-side columns for the column mode.
- The user expanded this to three selectable types and explicitly chose Distance as the consistency reference, superseding the initial general comparison with Peaks Bagged.

Negative Requirements:
- Do not update other cards' chart-type selection, defaults, presentation, or persistence in this feature.

Refinement clarification: L11 and L13–L15 explicitly expand Dashboard focus traversal and keyboard access, including visible focus/row selection, temporary shell navigation, Retry, and reordering through the existing card-order mechanism. L16 narrows the shell-access commitment, and L17 adds recovery for saves through that shared order mechanism. They do not change this record's exclusion of other cards' chart-type menus, defaults, chart/header presentation, or chart-preference migration.

### L4

Status: current

Question: Should stacked columns show green from zero to Moving Time, then the theme colour up to Total Time?

Recommended Answer:
- Yes. Four hours moving within five hours total renders four hours green plus one hour theme colour, with a full height of five hours.
- Tooltip values remain `Total Time` = five hours and `Moving Time` = four hours; do not add the two durations together.

Answer: yes

Decision: Stack the moving portion and the remaining portion, with Total Time as the full column height. Keep the displayed series meanings unchanged.

### L5

Status: current

Question: Should the chart-type button open a menu containing all three choices, and what should its startup default be?

Recommended Answer:
- Menu order is `Stacked column view`, `Line view`, `Clustered column view`, each with its specified icon and a current-choice indication.
- The button uses the current chart type's icon and tooltip `Chart type`.
- Selecting a choice closes the menu and preserves the selected period and date page.
- Initially use Stacked column view, matching Distance's default.

Answer: "yes. However, on app startup the previous choice of chart type should become the default chart type."

Decision: Use the recommended menu interaction, and persist Time's last selected chart type across app restarts. Stacked column view is the initial fallback when no saved choice exists.

### L6

Status: current

Question: How should durations be formatted in tooltips, header totals/averages, and Y-axis labels?

Answer: "Since the totals are most likely going to be measured in days, use xd yh zm for Tooltips and header totals/averages for y-axis use 0d, 2.5d, 5d"

Decision: Use day/hour/minute values such as `2d 5h 7m` in tooltips and header totals/averages, and compact decimal-day Y-axis labels such as `0d`, `2.5d`, and `5d`. A duration day is twenty-four hours.

Answer History:
- The interviewer proposed Track-details-style hours/minutes and an hours-based axis.
- The user replaced that proposal with day/hour/minute values and a days-based axis. The new card does not change Track details formatting.

### L7

Status: current

Question: Should the header total and average summarise Total Time only, matching Distance's primary-series summary?

Recommended Answer:
- Yes. Retain `Total:` and the period-specific `Daily Avg:`, `Weekly Avg:`, `Monthly Avg:`, or `Annual Avg:` labels, calculated from Total Time.
- Tooltips show both `Total Time` and `Moving Time`.

Answer: yes

Decision: Header summaries use the primary Total Time series, while tooltips expose both series.

### L8

Status: current

Question: How should the Time card handle Tracks with missing or inconsistent duration data?

Recommended Answer:
- Include a Track only when both durations are present and `0 ≤ Moving Time ≤ Total Time`.
- Valid zero durations remain included.
- Skip other Tracks for this card without changing stored data.
- If no eligible Tracks remain, show `No time data yet`.

Answer: agreed

Decision: Both time series use the same eligible Track set, with the stated non-negative/subset validation and exact wholly-empty message.

### L9

Status: current

Question: If remembering the chart type fails, should the chart remain usable with a visible warning?

Recommended Answer:
- Startup read failure: use Stacked column view and show `Couldn’t load Time chart preference.` with `Retry`.
- Save failure: keep the newly selected chart type visible and show `Couldn’t save Time chart preference.` with `Retry`. The previous successfully saved choice remains the startup default until a save succeeds.
- Log the technical error for diagnosis.

Answer: agreed

Decision: Preference failures are visible and retryable without preventing use of the chart. A save failure does not roll back the visible chart type or claim that the preference was saved.

### L10

Status: current

Question: Should Time's header summaries wrap or scroll when full day/hour/minute values do not fit at the user's selected text scale?

Answer: "wrapping."

Decision: Time's summary header wraps, preserving full labels/values at the active text scale rather than shrinking or truncating them. The period/navigation/chart-type toolbar stays on one row. Other cards retain their header presentation. Resolve any actual dependent Pending window/layout value before affected implementation; no dimensions or threshold were selected.

Source: One-by-one refinement discussion of finding 1; included in the final summary approved for Spec/Ledger update.

### L11

Status: current

Question: How should keyboard users traverse Dashboard cards, inspect Time's buckets/pages, and open/select its dropdown choices?

Answer History:
- The user added Shift+Tab for reverse traversal and requested h/l at bucket boundaries browse as the Previous/Next buttons.
- The user agreed to landing on the last bucket of the previous page or first bucket of the next page, with Left/Right behaving like h/l.
- The user stated "Focusable control should be restricted to the dashboard cards only" and selected interpretation `1`: one Tab stop per card, skipping internal controls and surrounding app navigation.
- After clarification that a combined card-actions menu would be a new surface, the user chose "P and C. j/k and up/down for menu selection in drop-down menus. W for next, B for prev".
- The user confirmed W/B mean next/previous calendar page, matching the toolbar buttons.
- The approved final summary retained accessible inspected values, visible focus, Enter application, Escape dismissal/focus restoration, and the Dashboard-wide focus-traversal scope expansion.

Decision:
- Tab moves to the next Dashboard card and Shift+Tab to the previous card, with one focus stop per card in displayed order. Internal controls/buckets and surrounding app navigation are not Tab stops in Dashboard traversal. Apply this card focus traversal across Dashboard, with visible, meaningfully named card focus.
- On first Time keyboard inspection, inspect the latest bucket containing eligible Tracks on the selected page, or the first bucket on an empty page. Valid zero-duration Tracks count as activity. Left/h and Right/l inspect previous/next buckets, exposing the date, Total Time, and Moving Time to assistive technology.
- At bucket boundaries, Left/h and Right/l use the same previous/next calendar pages and limits as the toolbar, landing on the previous page's last bucket or next page's first bucket. Keep focus on the card; remain at the boundary when no page is available.
- W/B invoke Time's Next/Previous page actions. P opens its existing Period dropdown; C opens its Chart type dropdown. Scope these shortcuts to the focused card, preserving normal text editing/copy shortcuts and preventing chart navigation while a dropdown owns keys.
- Dashboard dropdowns use Down/j for next choice and Up/k for previous choice, Enter to apply, and Escape to dismiss without changing the choice. Return focus to the owning card on selection/dismissal. Tab/Shift+Tab dismiss a dropdown and move to the next/previous card, maintaining card-only traversal.
- Escape outside a dropdown clears Time inspection while retaining card focus. Preserve pointer hover/click inspection and pointer access to internal controls.
- The traversal/dropdown-key changes expand the original Time-only interaction scope. Other cards retain their chart controls, data, presentation, defaults, and persistence. Do not add the proposed combined actions menu or migrate existing binary-mode cards to new chart-type menus.

Source: One-by-one refinement discussion of finding 2 and the user's explicit corrections/confirmations; final summary approved for Spec/Ledger update.

Refinement clarification: L13 supplies replacement keyboard access to existing Dashboard actions while retaining one Tab stop per card. L14 resolves off-screen traversal and wrapping at the first/last card. L15 resolves when Time inspection starts and how it resumes after Escape, page changes, and menu return. L16 later narrows access to other shell actions, and L17 adds shared card-order save recovery; L18 defers shortcut discovery. These records refine this initial contract without adding chart-type menus to existing binary-mode cards or changing their chart preferences.

### L12

Status: current

Question: Should preference warnings be retained while Dashboard is inactive and presented once when it becomes active again?

Recommended Answer:
- Keep the failure in app-owned state, independent of the Time card lifecycle.
- Show the exact L9 SnackBar immediately on an active Dashboard; otherwise show it once on the next active Dashboard, even if Time is off-screen.
- Do not replay an already-presented warning on rebuild or navigation.
- Clear a queued warning if a later successful operation resolves that failure before presentation.
- Save Retry writes the latest selected chart type. Retain the visible selection after failed saves and keep the chart usable.

Answer: "yes"

Decision: Adopt the recommended warning-delivery and latest-selection Retry policy. Never publish feedback to an inactive/disposed surface or lose an unpresented failure merely because the card was disposed. Preserve L9's exact warning text and persistence outcomes.

Source: One-by-one refinement discussion of finding 3; final summary approved for Spec/Ledger update.

### L13

Status: current

Question: How should existing Dashboard actions remain keyboard-accessible after their internal controls and surrounding navigation are removed from normal card Tab traversal?

Answer History:
- The user selected `Yes (Recommended)` to keeping every existing Dashboard action keyboard-accessible while preserving one Tab stop per card.
- In separate questions, the user approved W/B/P/C on Distance/Elevation/Peaks Bagged; Home/End on all four timeline cards; Latest Walk B/W/Enter; My Year to Date B/W; My Lists/My Ascents row navigation and S sorting; F6 temporary shell navigation; R for a visible Time preference warning; and Cmd+Shift+Left/Right for keyboard reordering.
- The user selected `Update Spec and ledger` after reviewing the combined decision summary.

Decision:
- On focused Distance, Elevation, or Peaks Bagged, W/B invoke existing Next/Previous calendar-page actions, P opens Period, and C directly activates the existing binary line/column toggle. Do not introduce a chart-type menu on those cards.
- On any of the four timeline cards, including Time, Home/End invoke First/Last using the toolbar's exact destinations, eligibility, limits, and enabled states.
- On Latest Walk, B/W invoke Previous track/Next track using existing enabled states, keeping card focus while browsing; Enter opens the displayed Track through its existing map action.
- On the separate My Year to Date card, B/W invoke Previous year/Next year with that card's existing bounds.
- On initial focus of populated My Lists/My Ascents, select the first row. Down/j and Up/k move selection without wrapping and scroll the selected row into view. Enter invokes the selected row's existing list/Track map action. Empty cards have no selected row to open. S toggles My Ascents' existing date sort, retaining the selected row when possible. Rows remain outside Tab traversal; selection and keyboard focus are visibly distinct from hover.
- F6 from a Dashboard card temporarily focuses the selected shell destination. Up/Down or k/j highlight destinations; Enter activates through existing shell navigation. Escape/F6 returns to the previous Dashboard card without navigating. Tab/Shift+Tab returns to that card and resumes next/previous-card traversal. Shell destinations are not normal Dashboard Tab stops.
- While a Time preference warning SnackBar is visible, R from any focused Dashboard card invokes that displayed warning's existing Retry, even with Time off-screen, retaining current card focus and deduplicating pending retries. Keep L9/L12's read/save/latest-choice policies. R does nothing without a visible Time preference warning and does not intercept typing or modified shortcuts.
- Cmd+Shift+Left/Right moves the focused card one position earlier/later in stored order. At an endpoint, the unavailable move does nothing without wrapping. Retain focus on the moved card, reveal it, and save through the existing card-order mechanism.
- Scope card shortcuts to the active Dashboard and focused card; temporary dropdown/shell focus must not double-dispatch card actions. Preserve normal text editing/Cmd+C, existing pointer actions, chart defaults/presentation, and persistence contracts. Keyboard reordering uses existing order persistence rather than introducing new navigation/selection preferences.

Source: Current one-by-one refinement discussion of finding 1; each proposed mapping was approved individually, followed by approval to update the Spec and ledger.

Refinement clarification: L16 supersedes the blanket “every existing Dashboard action” commitment for other shell actions: F6 stays destination-only, with no keyboard entry path to Background Jobs, its panel controls, or other shell notification actions. L17 adds visible card-order save failure/Retry recovery through the existing mechanism; it does not change the chart preferences of other cards or extend R beyond Time preference warnings. The enumerated card/destination mappings above remain current.

### L14

Status: current

Question: How should card-only Tab traversal handle off-screen/lazily constructed cards and the first/last cards?

Answer: `Wrap (Recommended)` — Tab from last focuses first; Shift+Tab from first focuses last, revealing off-screen targets. The full-order/reveal behavior was also included in the approved final update summary.

Decision: Traverse the entire displayed/stored card order, not only mounted focus nodes. Bring an off-screen target into view and focus it after lazy construction. Tab from the last card wraps to the first; Shift+Tab from the first wraps to the last. Preserve one focus stop per card and reordering-aware traversal. F6 supplies the separate shell-navigation access path under L13. Verify traversal through the full set in both directions under short existing regression viewports, without treating those fixture dimensions as approved window minima.

Source: Current one-by-one refinement discussion of finding 2; wrap was explicitly selected, followed by approval to update the Spec and ledger.

### L15

Status: current

Question: When should Time's keyboard inspection start, and what should happen after Escape, page navigation, or menu return?

Answer History:
- The user selected `On focus (Recommended)`: show the initial bucket immediately; the first directional key moves from it.
- The user selected `Yes (Recommended)` to the proposed Escape, W/B, page-boundary, and menu-return rules.
- The user approved recording the combined decisions in the Spec and ledger.

Decision:
- When Time receives keyboard focus, immediately inspect the selected page's latest bucket containing eligible Tracks, including zero-duration Tracks, or the first bucket if the page has no eligible Tracks. The first Left/Right/h/l moves from that already-inspected bucket, including L11's cross-page boundary behavior.
- Escape clears inspection while retaining card focus. The next Left/Right/h/l initializes the initial bucket without also stepping.
- After W/B changes page, inspect the destination page's latest eligible bucket, or its first bucket if empty.
- An arrow/h/l page crossing retains L11's last-bucket-of-previous/first-bucket-of-next landing; it does not use the W/B initialization policy.
- Closing a menu preserves a still-valid inspection. Changing the period or chart type clears the old inspection, and the next directional key initializes it without also stepping. Focus return from a menu must not unconditionally restart inspection.
- Preserve the existing refresh/rollover rule clearing obsolete inspection and keep keyboard-inspected dates/values accessible without stale callbacks restoring superseded state.

Source: Current one-by-one refinement discussion of finding 3; focus entry and subsequent transitions were approved separately, followed by approval to update the Spec and ledger.

### L16

Status: current

Question: Should the temporary F6 scope include existing shell actions such as Background Jobs, panel controls, and shell notification actions so they remain keyboard-reachable from card-only traversal?

Answer: "keep it as is with no keyboard entry path"

Decision: Keep F6 destination-only and add no keyboard entry path for the other shell actions while retaining their pointer operation. Narrow L13's earlier “every existing action” commitment accordingly. This limitation also applies to the card-order Retry action introduced by L17; R remains limited to a visible Time preference warning. Record the intentional ADS-1.0/Desktop wide accessibility gap, its reason, affected scope, and approval status in the Spec. The product scope decision is confirmed; it does not establish a standard exception approval process or claim full keyboard compliance.

Source: Latest one-by-one refinement discussion of finding 1; the user then approved the combined decision summary and Spec/Ledger update.

### L17

Status: current

Question: What should happen when saving a changed Dashboard card order fails?

Answer: `Keep order + Retry (Recommended)` — keep the visible order, show a save-failure SnackBar with Retry, and have Retry save the latest order.

Decision: Retain the changed visible order on save failure and provide a SnackBar with `Retry` that saves the latest order rather than an obsolete captured order. Apply recovery through the existing shared order-save mechanism, including pointer and keyboard reordering. Preserve the existing stored order until a later save succeeds. Treat unsuccessful write results as failures alongside exceptions, and log technical failures. As supporting implementation defaults, serialize/coalesce writes and deduplicate pending retries; these defaults do not select additional UI behavior. Under L16, Retry remains pointer-operable without a new keyboard entry path or Dashboard Tab stop; R remains Time-preference-only. Other cards' chart preferences are unchanged.

Source: Latest one-by-one refinement discussion of finding 2; the user selected the stated recovery policy and then approved the combined decision summary and Spec/Ledger update.

### L18

Status: deferred

Question: How should users discover the replacement Dashboard keyboard shortcuts?

Answer History:
- The user asked how contextual hints would be shown; a focused-card/shared-shortcut footer was proposed.
- The user asked about accessible-only hints; these were explained as screen-reader descriptions without visible hints.
- The user decided: "Defer this. Later on I will want to add the ablility to edit shortcuts and also add a help screen."

Decision: Defer shortcut discovery. Add no contextual hint footer, shortcut-help surface, or accessible-only shortcut explanation in this feature. Carry editable keyboard shortcuts and a Help screen as future work, without selecting their design, routes, entry shortcuts, persistence, or implementation sequence. Existing required accessible names, focus feedback, and inspected values remain required.

Source: Latest one-by-one refinement discussion of finding 3; the user deferred the work and then approved recording the combined decisions in the Spec and ledger.

### L19

Status: current

Question: During Work Item 01 implementation, what minimum usable macOS content width/height, supported resize range and Time wide-layout thresholds should be recorded after the enlarged-text header regression exposed insufficient chart height? The existing `1600 × 1000` / `1.5×` fixture was explicitly identified as test evidence only.

Answer: **`Leave layout gated`** — finish and verify independent Time work; keep header-height reachability incomplete until supported dimensions are decided.

Decision: Retain the named Pending profile values and the conditional gate. Pause dependent height/layout changes and keep the long-header light/dark regression checks explicitly gated. This does not approve the fixture dimensions, authorise text downscaling, relax the wrapping/reachability contract, or declare Work Item 01 complete. Independent data/calendar/formatter/chart/integration verification may proceed.

Source: Work Item 01 implementation clarification, 2026-10-18.

### L20

Status: current

Question: May independent Work Item 02 chart/menu implementation proceed while Work Item 01 remains incomplete under the L19 layout gate?

Answer: "Authorize independent Work Item 02 work"

Decision: Proceed with Work Item 02's chart-type state, pointer menu, renderers and independent verification using the implemented Work Item 01 foundation. Carry forward the wrapping-header height/reachability gate and its dependent verification. Do not resolve Pending dimensions, change window/card geometry, or declare Work Item 01 complete.

Source: Work Item 02 implementation authorisation, 2026-10-18.

### L21

Status: current

Question: May independent Work Item 03 preference/recovery implementation proceed using Work Item 02's verified chart/menu foundation while its inherited layout criterion remains incomplete?

Answer: `Authorize independent 03`.

Decision: Proceed with app-owned preference persistence/recovery, Dashboard feedback and readiness integration, and independent verification. Carry forward L19's layout gate and incomplete dependent checks; do not resolve Pending dimensions or declare Work Items 01–02 complete.

Source: Work Item 03 implementation authorisation, 2026-10-18.

### L22

Status: current

Question: May independent Work Item 04 traversal and timeline/menu keyboard work proceed using Work Item 02's verified foundation while its inherited layout checks remain incomplete?

Answer: `Authorize independent 04`.

Decision: Proceed with full-order traversal, scoped timeline/dropdown actions, focus coordination and independent verification. Retain L19's wrapping-header height/reachability gate and incomplete dependent checks. Do not resolve Pending dimensions or declare Work Items 01–02 complete.

Source: Work Item 04 implementation authorisation, 2026-10-19.
