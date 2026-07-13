---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: How should peak selection and marker behavior work on the Peak Lists mini-map when a peak is opened from the details summary?

Recommended Answer:
- Do not show the separate blue selected-peak circle on the peak-lists mini-map.
- When a peak name in the details summary sentence is tapped, open the existing anchored mini-map peak info popup for that peak on the same screen.
- Do not open the peak edit/view dialog and do not navigate to another screen.

Answer: Keep the blue selected-peak circle but do not display the amber marker. When a peak name in the details summary sentence is tapped also show the blue selected-peak circle.

Decision: The Peak Lists mini-map must keep the blue selected-peak circle for the selected peak, including when a peak is opened from the details summary, and must not show the amber selected-location marker on that screen.

Answer History:
- Initial recommendation: remove the blue selected-peak circle and rely on the popup alone.
- Final answer: keep the blue selected-peak circle and also show it for summary-link selections.

Negative Requirements:
- Do not show the amber selected-location marker on the Peak Lists screen.

### L2

Status: current

Question: When the summary sentence names multiple peaks for the same most recent ascent date, how should the link behave?

Recommended Answer:
- Make each peak name individually tappable.
- Commas and `and` stay plain text.
- Tapping a specific peak name opens that peak's existing mini-map popup and shows the blue selected-peak circle for that same peak.
- The peak-lists mini-map should not render the amber selected-location marker on this screen, including after popup actions.

Answer: agreed

Decision: Each peak name in the recent-ascent summary sentence must be individually tappable, while punctuation remains plain text. Tapping a name opens that peak's existing mini-map popup and selects the same peak for the blue selected-peak circle.

### L3

Status: current

Question: The mini-map popup on this screen currently has a `Drop Marker` action that creates the amber marker elsewhere in the app. With the new "no amber marker on Peak Lists" rule, should that action still appear here?

Recommended Answer:
- Hide the `Drop Marker` action from the peak-lists mini-map popup.
- Tapping a peak name in the summary should only open that peak's popup and set the blue selected-peak circle on this screen.
- Do not create or persist an amber selected-location marker from Peak Lists.

Answer: agreed

Decision: The Peak Lists mini-map popup must hide the `Drop Marker` action and must not create or persist an amber selected-location marker from that screen.

Reason: The screen should not offer an action whose visible result is intentionally suppressed there.

### L4

Status: current

Question: In the popup, the current track section is labeled `My Ascents:` and each row is a climbed track for that peak. Should this request treat those existing `My Ascents` rows as the "available tracks" links to the map screen?

Recommended Answer:
- Yes. Keep the visible section label as `My Ascents:`.
- Make the popup peak title tappable to navigate to the map screen for that peak.
- Make each valid, resolvable `My Ascents` row tappable to navigate to the map screen with that ascent's track selected.
- Keep unresolved ascent rows visible as plain non-interactive text with no pointing-finger cursor and no navigation.
- Do not introduce a new visible `Available Tracks` label on this popup.

Answer: agreed

Decision: Reuse the existing `My Ascents:` section as the popup's track-link surface. Keep the `My Ascents:` label, make the popup peak title tappable, make each valid and resolvable `My Ascents` row tappable, keep unresolved ascent rows visible as plain non-interactive text without a pointing-finger cursor, and do not introduce a new `Available Tracks` label.

### L5

Status: current

Question: When a user clicks a link from the peak-lists popup to open the main map, what should be visible after navigation?

Recommended Answer:
- Clicking the popup peak title navigates to `/map` and centers on that peak.
- Clicking a `My Ascents` row navigates to `/map`, shows that track on the map, and opens the normal track info panel for that track.
- Apply the pointing-finger cursor to every tappable text/link and sort header touched by this change, including the peak-lists summary links, popup title, popup ascent rows, peak-list edit/details popup links, and peak-list row sort headers.

Answer: agreed

Decision: Peak-title navigation from the Peak Lists popup must navigate to `/map` with that peak centered, without requiring the main map peak info popup to auto-open. `My Ascents` row navigation must open the main map with the selected track shown and its normal track info panel visible.

### L6

Status: current

Question: Should tappable links and sort headers involved in this flow show a pointing-finger cursor?

Answer: Yes. Ensure the cursor changes to a pointing finger for all tappable links including any links in the edit/details popup and peak list row sort headers.

Decision: Every enabled tappable link and relevant sort header in this flow must show a pointing-finger cursor, including the Peak Lists summary links, popup title, popup `My Ascents` rows, links in the peak-list edit/details popup, and peak-list sort headers.

Negative Requirements:
- Do not show a pointing-finger cursor for disabled or non-interactive text.

### L7

Status: current

Question: Should the Peak Lists `Add New Peak List` and `Import Peak List` FABs also show the pointing-finger cursor?

Answer: Yes.

Decision: The Peak Lists `Add New Peak List` FAB and `Import Peak List` FAB must also show the pointing-finger cursor when enabled.

Reason: These FABs are clickable controls on the same screen and should advertise interactivity consistently with the rest of the feature's pointer affordances.
