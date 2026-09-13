---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What should applying the 2 m DEM mean in the app?

Recommended Answer:
- Add a reusable Terrain relief shading overlay above Tasmania basemaps.
- Keep it independent of the existing Local Topo basemap.
- Preserve its state when the user changes basemaps.

Answer: Agreed.

Decision: The ELVIS topo DEM must provide a reusable Terrain relief shading overlay for Tasmania basemaps, including TasMap 25K; it is not a replacement for Local Topo.

### L2

Status: current

Question: Should the overlay require the configured Local tile server?

Recommended Answer:
- Require a live-validated Local Topo tile source that advertises the overlay for Tasmania.
- Hide unavailable overlay controls without affecting the selected basemap.

Answer: Agreed.

Decision: Overlay availability depends on a validated Local tile server capability advertisement for Tasmania.

### L3

Status: current

Question: Where should the controls live, and should they persist?

Recommended Answer:
- Place an Overlays section below Basemaps in the existing drawer.
- Start both overlays off, change the map immediately, retain the drawer, and persist global preferences.

Answer: Agreed.

Decision: The Basemaps drawer owns the overlay controls; selections default off, take effect immediately, and persist across app restarts.

### L4

Status: current

Question: Should contours be a second independently controlled overlay?

Recommended Answer:
- Use the label Contour lines.
- Allow users to enable Terrain relief shading, Contour lines, or both.

Answer: Agreed.

Decision: Contour lines is an independent reusable DEM-derived overlay, distinct from the Local Topo Contour cartography style treatment.

### L5

Status: current

Question: How should overlay opacity work?

Recommended Answer:
- Give each overlay a persisted opacity value.
- Use a 0% to 100% slider in 5% increments and an editable integer percentage field.
- Default Terrain relief shading to 35% and Contour lines to 70%.
- Revert invalid input to the prior valid value when focus leaves the field.

Answer: Agreed.

Decision: Both overlays have independently persisted, directly editable opacity controls with the stated defaults and validation.

### L6

Status: current

Question: Which contour spacing should Contour lines use?

Recommended Answer:
- Use the current Local Topo build's contour tiles with no in-app interval selector.
- Prefer 10 m contours and use the existing 25 m fallback when required by the selected DEM.

Answer: Agreed.

Decision: The standalone contour overlay uses the active Local Topo build interval and has no client-side spacing selection.

### L7

Status: current

Question: What should happen when Local Topo is selected?

Recommended Answer:
- Preserve overlay preferences.
- Disable both switches and show Included in Local Topo.
- Do not add duplicate layers; restore the saved toggle states after another Tasmania basemap is selected.

Answer: Agreed.

Decision: Local Topo never renders duplicate overlay layers and communicates that both treatments are included.

### L8

Status: current

Question: How should a running server's overlay failure be shown?

Recommended Answer:
- Keep the selected basemap and settings unchanged.
- Leave unavailable tiles absent and show one non-blocking overlay-specific message.
- Do not repeatedly notify or disable the switch; retry through Settings validation.

Answer: Agreed.

Decision: An overlay tile-source failure is non-destructive, produces one named non-blocking message, and recovers through revalidation.

### L9

Status: current

Question: How should the updated capability contract interact with existing v1 Local Topo servers?

Recommended Answer:
- Extend the capability contract to advertise overlays.
- Keep v1 servers valid for Local Topo and hide the Overlays section for them.

Answer: Agreed.

Decision: Capability v2 adds overlay advertisement while the client continues accepting v1 snapshots without overlays.

### L10

Status: current

Question: Which map context controls overlay availability?

Recommended Answer:
- Follow the existing drawer rule: cursor location, or map centre, must be in Tasmania and visible bounds must intersect a server-advertised Tasmania region.
- Hide the section when context leaves Tasmania while retaining preferences.

Answer: Agreed.

Decision: Overlay availability follows the existing point-and-visible-bounds regional basemap rule.

### L11

Status: current

Question: Should overlays participate in offline tile caching?

Recommended Answer:
- Fetch overlay tiles only from the Local tile server.
- Exclude them from offline downloads to prevent stale post-rebuild terrain data.

Answer: Agreed.

Decision: Terrain relief shading and Contour lines are not offline-cacheable app tile sources.

### L12

Status: current

Question: What is the layer order when both overlays are enabled?

Recommended Answer:
- Render Terrain relief shading above the basemap.
- Render Contour lines above relief.
- Keep app map content above both.

Answer: Agreed.

Decision: The layer stack is basemap, terrain relief shading, contour lines, then app-owned map content.

### L13

Status: current

Question: At what zoom levels should contour lines be visible?

Recommended Answer:
- Show no contours below zoom 12.
- Show 50 m and 100 m tiers at zoom 12.
- Add minor contour lines at zoom 13 and above.
- Do not render contour labels.

Answer: Agreed.

Decision: The standalone Contour lines overlay uses the stated zoom hierarchy and has no labels.
