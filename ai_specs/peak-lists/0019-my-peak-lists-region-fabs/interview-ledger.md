---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the new permanent `My Peak Lists` controls be treated as countries, or as the existing manifest regions?

Recommended Answer:
- Use `region FABs` as the canonical term.
- Show one permanent control per manifest region.
- Use the manifest regions `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia`.
- Do not collapse `Italy North East` and `Italy North West` into one `Italy` control.

Answer: agreed

Decision: The feature uses permanent `region FABs` backed by the manifest regions, not country controls.

### L2

Status: current

Question: Where should the `region FABs` sit in the `My Peak Lists` shared app bar layout?

Answer: align the FABs to left so that the first sits next to the My Peak Lists title

Decision: On `My Peak Lists`, the `region FABs` must be left-aligned in the shared app bar lane, with the first control immediately beside the `My Peak Lists` title when the one-line layout fits.

### L3

Status: current

Question: Should the `region FABs` be exclusive, or can multiple regions stay selected at once?

Answer: region FABs are not exclusive, so that if Italy Nord Est and slovenia are selected all lists applicble to those two countries are shown

Decision: The `region FABs` are independent multi-select filters. `My Peak Lists` must show all applicable lists for the union of the selected manifest regions.

### L4

Status: current

Question: What should the default `region FAB` selection be when `My Peak Lists` opens?

Recommended Answer:
- Default to all manifest regions selected when `My Peak Lists` opens.
- Each region FAB toggles independently on or off.

Answer: The default should be the previous selected state or all on first launch

Decision: `My Peak Lists` restores the previously saved region selection when one exists. On first launch with no saved state, all manifest regions start selected.

Answer History:
- Initial recommendation: default to all selected every time the screen opens.
- Final answer: restore the previous saved selection, or use all selected only on first launch.

### L5

Status: current

Question: How should `mixed-region peak lists` behave in the `My Peak Lists` region filter?

Recommended Answer:
- Show a mixed-region peak list when it applies to at least one selected region.
- Hide it only when none of its applicable regions are selected.

Answer: agreed

Decision: A `mixed-region peak list` remains visible whenever at least one of its applicable regions is selected.

### L6

Status: current

Question: If the active region filter hides the currently selected peak list on `My Peak Lists`, what should the screen do next?

Recommended Answer:
- Automatically select the first remaining visible peak list in the current filtered order.
- If no peak lists remain, clear the current selection.
- Update the mini-map, summary, and detail pane immediately.

Answer: agreed

Decision: When filtering hides the current selection, `My Peak Lists` must move selection to the first remaining visible list in the current filtered order, or clear selection if none remain.

### L7

Status: current

Question: After removing the `Add New Peak List` FAB, should `My Peak Lists` still offer any on-screen way to create a new peak list?

Recommended Answer:
- Remove the create action from `My Peak Lists` entirely in this slice.
- Keep `Import Peak List` unchanged.
- Do not add a replacement create button, menu item, or app-bar action elsewhere on this screen.

Answer: agreed

Decision: This slice removes the `Add New Peak List` action from `My Peak Lists`, keeps `Import Peak List`, and does not add a replacement create control on that screen.

### L8

Status: current

Question: Should the manifest become the source of truth for both full region names and new app-bar short labels, and which short labels should `My Peak Lists` use?

Recommended Answer:
- Add a manifest-backed short label for each region FAB.
- Keep the existing full manifest names unchanged for other uses.
- Use these exact short labels in the `My Peak Lists` app bar: `Tas`, `NSW`, `Italy NE`, `Italy NW`, `Slovenia`, `Croatia`.

Answer: agreed

Decision: The manifest must provide full names plus app-bar short labels. `My Peak Lists` uses `Tas`, `NSW`, `Italy NE`, `Italy NW`, `Slovenia`, and `Croatia` as the visible region FAB labels.

### L9

Status: current

Question: How should `My Peak Lists` treat peak lists whose stored `region` is not one of the manifest regions and is not `mixed`?

Recommended Answer:
- Only manifest-region lists and `mixed-region peak lists` participate in the new region FAB filter.
- Peak lists with unsupported legacy or non-manifest region keys stay hidden on `My Peak Lists` in this slice.
- Do not add an `Other` or `Unknown` region FAB.

Answer: agreed

Decision: Only manifest-region and mixed-region peak lists participate in the filter. Unsupported legacy or non-manifest region keys remain hidden, with no `Other` or `Unknown` control.

### L10

Status: current

Question: Should the `My Peak Lists` region FAB selection persist across app restarts, or only while the app stays open?

Recommended Answer:
- Persist the `My Peak Lists` region FAB selection locally across app restarts.
- Restore that saved selection whenever the user returns to `My Peak Lists`.
- Use all regions selected only when there is no previously saved state yet.

Answer: agreed

Decision: The `My Peak Lists` region filter persists locally across app restarts and restores on later visits.

### L11

Status: current

Question: If the user turns every `region FAB` off on `My Peak Lists`, should the screen show no lists, or should it automatically restore all regions?

Recommended Answer:
- Show no peak lists when all region FABs are off.
- Keep the empty state visible until the user re-enables one or more regions.
- Do not silently restore all regions.

Answer: agreed

Decision: All-off is a valid filter state. `My Peak Lists` shows no lists and does not auto-restore all regions.

### L12

Status: current

Question: What color rule should the permanent `region FABs` use?

Recommended Answer:
- Assign colors by manifest order using the existing map-screen peak-list palette.
- Use a fixed mapping so the same region always has the same accent color.
- Map `Tas`, `NSW`, `Italy NE`, `Italy NW`, `Slovenia`, and `Croatia` to palette colors 1 through 6 in manifest order.

Answer: use the same colour palette that is used for the peak list FABs in the map screen

Decision: The `region FABs` reuse the same palette as the Map screen peak-list controls, with a fixed manifest-order mapping to the first six palette entries.

Answer History:
- Initial recommendation: give each region a fixed app-owned accent color.
- Final answer: reuse the existing map-screen peak-list palette instead of introducing a second palette.

### L13

Status: current

Question: After using short labels, what should happen if the region FAB row still cannot fit beside `My Peak Lists` on narrower widths or larger text scales?

Recommended Answer:
- Keep the title and region FABs on a single line.
- When they do not fit, keep the title left-aligned and allow horizontal scrolling of the region FAB row on that same line.
- Do not wrap the region FABs onto a second line.
- Keep all region FABs reachable and tappable through the horizontal scroller.

Answer: keep the app bar single line and allow horizontal scrolling when needed

Decision: The app bar keeps a single-line layout. When width or text scale is constrained, it keeps the title on the left and allows horizontal scrolling of the region FAB row on the same line rather than wrapping.

Answer History:
- Initial recommendation: keep the title and region FABs on one line when they fit and wrap to a second line when they do not.
- Updated answer: keep the app bar on a single line and allow horizontal scrolling of the region FAB row when needed.

### L14

Status: current

Question: With shortened visible labels such as `Tas`, `NSW`, and `Italy NE`, should the app still expose the full region names in tooltip and accessibility text?

Recommended Answer:
- Keep the visible FAB text short.
- Use the full manifest name for tooltip and semantics: `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia`.

Answer: Agreed.

Decision: The app bar keeps short visible labels but exposes the full manifest region names in tooltip and accessibility text.
