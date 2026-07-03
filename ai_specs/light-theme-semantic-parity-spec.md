<goal>
Make `./lib/theme.dart` update the light theme so it mirrors the dark theme semantically, not by copying dark colors.

Users who switch between light and dark mode should see the same component roles, extension availability, and intended contrast structure in both modes. The implementation must replace current light-theme fallback dependence for the targeted roles with explicit light-theme assignments in `./lib/theme.dart`.
</goal>

<background>
This is a Flutter app using `MaterialApp.router` with `CatppuccinColors.light` and `CatppuccinColors.dark` from `./lib/theme.dart`.

Relevant files to examine:
- `./lib/theme.dart`
- `./lib/app.dart`
- `./test/theme_test.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/dashboard_screen.dart`
- `./lib/widgets/side_menu.dart`
- `./lib/widgets/dashboard_chart_chrome.dart`
- `./lib/widgets/elevation_profile_chart.dart`
- `./lib/widgets/dashboard/summary_chart.dart`
- `./lib/widgets/drawer_outline_button.dart`
- `./lib/widgets/peak_list_selection_summary.dart`
- `./lib/widgets/map_search_popup.dart`
- `./test/widget/map_track_info_panel_test.dart`
- `./test/widget/map_route_info_panel_test.dart`
- `./test/widget/elevation_profile_chart_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`

Current state:
- Dark theme defines an explicit semantic role set and includes `RowHoverTheme` and `SearchButtonThemeData`; it also still carries an unused `SelectedButtonThemeData` extension with no current runtime consumer.
- Light theme defines fewer explicit `ColorScheme` roles than dark mode and does not carry the unused `SelectedButtonThemeData` extension.
- Several widgets consume semantic roles such as `secondary`, `primaryContainer`, `surfaceContainer`, `outline`, `outlineVariant`, and `tertiary`, so light mode currently depends partly on values that are not explicitly assigned in `CatppuccinColors.light`.
- `MapTrackInfoPanel` uses `colorScheme.secondary` for its panel surface but still mixes direct `onSurface` icon usage with global text-theme styles, so semantic parity is incomplete unless the panel gets a local foreground override contract based on `onSecondary`.
- `SideMenu` relies on the `primaryContainer` and `iconTheme.color` pairing, so `iconTheme.color` must intentionally mirror `onPrimaryContainer` in both themes.

Scope is limited to theme configuration, the smallest direct consumer updates needed to align foreground semantics, and direct theme validation. Do not broaden this into unrelated UI polish.
</background>

<user_flows>
Primary flow:
1. A user runs the app in light mode.
2. Shared UI surfaces, headers, controls, and chart highlights resolve colors from explicit light-theme semantics rather than fallback defaults.
3. The user switches to dark mode and sees the same semantic structure expressed with dark values.
4. Both modes preserve expected contrast and role intent for the same components.

Alternative flows:
- Theme toggle path: A user changes the app theme from settings and existing screens continue to render correctly because both theme variants expose the same required roles and extensions.
- Direct light-mode launch: A user starts the app in light mode without ever visiting dark mode and still receives the intended palette rather than default Material substitutions.

Error flows:
- Missing theme role: If a required semantic role or extension is absent, automated theme tests fail before UI regressions ship.
- Over-broad parity change: If implementation changes dark theme semantics or expands into screen-level restyling, review should reject the change as out of scope.
</user_flows>

<requirements>
**Functional:**
1. Update `./lib/theme.dart` so `CatppuccinColors.light` defines the same intentional semantic theme shape as `CatppuccinColors.dark` for the roles dark mode already sets explicitly and the app actively relies on.
2. Treat parity as semantic parity: preserve light-appropriate values while matching dark theme structure, role availability, and live extension availability.
3. Keep `CatppuccinColors.dark` visual behavior unchanged unless a strictly necessary refactor is required to express shared structure without changing live consumer output values. Removing unused `SelectedButtonThemeData` from dark mode is allowed if the type has no remaining real consumer.
4. Define the explicit light values for the in-scope mirrored roles using this semantic map:

| Role | Explicit light value | Intent |
| --- | --- | --- |
| `secondary` | `Color(0xFFDCE0E8)` | Neutral panel/card surface, matching dark mode's `secondary` job |
| `onSecondary` | `Color(0xFF4C4F69)` | Foreground for content rendered directly on `secondary` |
| `tertiary` | `Color(0xFFBCC0CC)` | Selected or contrasted neutral highlight used by chart selection states |
| `onTertiary` | `Color(0xFF4C4F69)` | Foreground paired with `tertiary` |
| `primaryContainer` | `Color(0xFFCCD0DA)` | Header and side-menu container surface |
| `onPrimaryContainer` | `Color(0xFF4C4F69)` | Foreground paired with `primaryContainer`; this must intentionally match `iconTheme.color` |
| `surfaceContainer` | `Color(0xFFDCE0E8)` | General elevated card/container surface |
| `outline` | `Color(0xFF9CA0B0)` | Neutral border and divider emphasis |
| `outlineVariant` | `Color(0xFF1E66F5)` | Accent border/hover emphasis |

5. Update light `AppBarTheme` so every in-scope field mirrors dark mode structurally with light values: `backgroundColor` must equal `scaffoldBackgroundColor`, `foregroundColor` must remain `Color(0xFF4C4F69)`, `elevation` must stay `2`, `surfaceTintColor` must stay `Colors.transparent`, and `shadowColor` must stay `Color(0x33000000)`.
6. Ensure the chosen light `secondary` value reflects the same semantic job dark mode uses it for: a neutral panel/card surface rather than an unrelated accent color.
7. Preserve existing light theme brightness, primary color family, and overall Catppuccin Latte intent while correcting semantic mismatches.
8. Update `MapTrackInfoPanel` with a panel-scoped semantic override so content rendered on the `secondary` panel surface resolves foreground text and icon semantics from `colorScheme.onSecondary` without requiring a global `textTheme` rewrite.
9. The `MapTrackInfoPanel` override must be observable in widget tests: under `CatppuccinColors.light`, the close/edit icons, route timing info/recalculate icons, the panel title, section titles, row labels, row values, and the visibility-row label rendered directly on the `secondary` card must resolve to `colorScheme.onSecondary` unless a child is intentionally rendered on a different surface.
10. The visibility `Switch` in `MapTrackInfoPanel` is a direct panel control but not a text/icon foreground descendant. It must keep default `Switch` semantics with no widget-local thumb, track, or overlay color overrides.
11. The export control in `MapTrackInfoPanel` is a separate button surface, not a direct `secondary`-card foreground descendant. It should use `FilledButton.icon` without a manual icon-color override or button-local foreground override, and widget tests must verify that it does not inherit the panel-scoped `onSecondary` override.
12. Keep `iconTheme.color` intentionally aligned with `colorScheme.onPrimaryContainer` so theme-level icon defaults stay centralized in `./lib/theme.dart`.
13. If `SelectedButtonThemeData` has no real consumer after discovery, remove it from the theme contract rather than adding it to light mode for symmetry only.

**Error Handling:**
14. If a role is consumed by the app but not intentionally defined in either theme, document that decision in code review and keep it inherited in both themes unless there is a strong reason to expand scope.
15. If implementing shared constants or helpers inside `./lib/theme.dart`, keep them minimal and avoid introducing abstraction that obscures the final role values.

**Edge Cases:**
16. Do not introduce backward-compatibility branches or dual theme paths; replace current fallback dependence with a single explicit light-theme definition.
17. Do not change widget code beyond the minimum needed to make foreground semantics match the theme contract in direct consumers such as `MapTrackInfoPanel`; do not broaden this into screen-specific restyling.
18. Maintain current behavior for existing dark-only tests and any widget expectations that compare colors against theme roles.

**Validation:**
19. Expand `./test/theme_test.dart` or add focused adjacent theme tests so they verify semantic parity, not only brightness and one-off color smoke checks.
20. Tests must assert live extension presence parity for both themes, including `SearchButtonThemeData` and `RowHoverTheme`. If `SelectedButtonThemeData` is removed, do not reintroduce it through symmetry-only assertions.
21. Tests must assert that the in-scope light-theme roles resolve to the agreed explicit light values for the mirrored semantic map.
22. Tests must assert that `iconTheme.color == colorScheme.onPrimaryContainer` in both themes.
23. All theme-consumer widget assertions in the named panel and consumer test files must pump `CatppuccinColors.light`; any dark-regression assertions must pump `CatppuccinColors.dark`.
24. Widget tests must verify that a light-themed `MapTrackInfoPanel` resolves its panel surface from `secondary` and applies a panel-scoped semantic foreground override based on `onSecondary`.
25. Widget tests must assert concrete observable descendants under `CatppuccinColors.light`: the close/edit icons, route timing info/recalculate icons, the panel title, section titles, row labels, row values, and visibility-row label rendered directly on the `secondary` card must resolve to `onSecondary` unless a child is intentionally rendered on another surface.
26. Widget tests must assert that the visibility `Switch` keeps default `Switch` semantics with no widget-local thumb, track, or overlay color overrides.
27. Widget tests must assert that the export control remains a separate button surface using `FilledButton.icon` without a manual icon-color override or button-local foreground override, and does not accidentally inherit the panel-scoped `onSecondary` override.
28. Direct panel tests are the primary verification target for this contract: use `./test/widget/map_track_info_panel_test.dart` for the track branch and `./test/widget/map_route_info_panel_test.dart` for the route branch.
29. Widget tests or small helper tests must verify a real `primaryContainer` consumer and a real `surfaceContainer` consumer using lightweight targets rather than a full-screen integration harness. For `primaryContainer`, add concrete `SideMenu` selected/unselected color inversion assertions to `./test/widget/objectbox_admin_shell_test.dart`; only add a dedicated `./test/widget/side_menu_test.dart` if the shell test proves too indirect. For `surfaceContainer`, extend `./test/widget/elevation_profile_chart_test.dart` to assert that the disabled time toggle resolves its disabled background from `theme.colorScheme.surfaceContainer` under `CatppuccinColors.light`.
30. Treat the `iconTheme.color == onPrimaryContainer` invariant and the `SideMenu` selected/unselected inversion behavior as separate checks: theme tests guard the former, consumer tests guard the latter.
31. Code review must verify that the targeted light-theme roles are explicitly assigned inside `CatppuccinColors._createLightTheme()` rather than left to constructor defaults.
</requirements>

<boundaries>
Edge cases:
- Roles only used through Material-derived defaults such as `surfaceContainerHighest` or `onSurfaceVariant`: leave them alone unless the code audit shows the parity goal cannot be met without explicitly defining them.
- Shared helper extraction inside `./lib/theme.dart`: acceptable only if it keeps dark outputs unchanged and makes parity easier to verify.
- Older repo specs that still mention `SelectedButtonThemeData` as a live button contract may become stale if this work removes the type; updating those specs is a separate follow-up unless explicitly added to scope.

Error scenarios:
- A new light role choice breaks contrast or makes a control read like an accent instead of a surface: adjust the light value, not the semantic role assignment.
- A parity fix requires broad screen-specific compensation beyond the approved local `MapTrackInfoPanel` override: stop and reassess, because this spec does not authorize broader UI redesign.

Limits:
- Output changes are limited to `./lib/theme.dart`, the smallest direct consumer updates needed for semantic foreground pairing such as `./lib/screens/map_screen_panels.dart`, and the focused widget tests named in this spec such as `./test/theme_test.dart`, `./test/widget/map_track_info_panel_test.dart`, `./test/widget/map_route_info_panel_test.dart`, `./test/widget/elevation_profile_chart_test.dart`, and either `./test/widget/objectbox_admin_shell_test.dart` with `SideMenu` assertions or a new `./test/widget/side_menu_test.dart`.
- Do not modify settings flow, routing, providers, or unrelated widget styling as part of this work.
- Do not add new packages or alter app architecture.
</boundaries>

<discovery>
Before editing, inspect where the app currently consumes theme semantics so the parity target is grounded in real usage rather than aesthetic guesswork.

Confirm at minimum:
- which widgets use `colorScheme.secondary` as a surface role
- which widgets use `primaryContainer`, `surfaceContainer`, `outline`, `outlineVariant`, and `tertiary`
- whether any current tests assume the old light `secondary` accent value directly, with `./test/theme_test.dart` treated as an expected update target
- whether `./test/widget/map_track_info_panel_test.dart` and `./test/widget/map_route_info_panel_test.dart` already provide the cleanest assertion seam before adding broader screen-level regressions
- what the smallest clean panel-scoped theme/text/icon override is for `MapTrackInfoPanel` so panel content on `secondary` reads semantically from `onSecondary`
- what explicit button-surface contract the export control should retain so it does not get conflated with direct `secondary`-card foreground content
- which other direct panel controls, such as route timing action icons and the visibility row, must be covered by the same foreground contract or an explicit exception
- whether `iconTheme.color` already matches the intended `onPrimaryContainer` contract in both themes
- whether `SelectedButtonThemeData` has any real consumer; if not, remove it rather than preserving it for symmetry only
- whether `./test/widget/objectbox_admin_shell_test.dart` can express the required `SideMenu` color inversion assertions cleanly before introducing `./test/widget/side_menu_test.dart`

Use this discovery only to confirm scope and test expectations, not to expand into unrelated UI cleanup.
</discovery>

<implementation>
Modify:
- `./lib/theme.dart`
- `./lib/screens/map_screen_panels.dart`
- `./test/theme_test.dart` or a new adjacent theme-focused test file under `./test/`
- `./test/widget/map_track_info_panel_test.dart`
- `./test/widget/map_route_info_panel_test.dart`
- `./test/widget/elevation_profile_chart_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart` with concrete `SideMenu` assertions, or `./test/widget/side_menu_test.dart` only if the shell test proves too indirect

Implementation expectations:
- Keep the change set small and mostly centered in `CatppuccinColors._createLightTheme()`, with only the minimum direct consumer updates needed for the approved panel-scoped `MapTrackInfoPanel` semantic override.
- Prefer explicit light role definitions over current unassigned `ColorScheme.light()` values for the in-scope mirrored roles.
- If useful, align dark and light theme construction order so corresponding sections are easier to compare during maintenance.
- Keep extension definitions colocated with existing theme extensions in `./lib/theme.dart`.
- Prefer a local panel-scoped theme/text/icon override in `MapTrackInfoPanel` over scattered one-off color assignments or a global text-theme rewrite.

Avoid:
- screen-specific hardcoded compensation colors
- broad refactors outside the theme file
- abstract theme builders that hide the actual role values or make tests harder to read
</implementation>

<stages>
Stage 1: Audit theme role usage and current tests.
Completion check: A short implementation note or code review summary can name the app-consumed roles that must be mirrored explicitly in light mode.

Stage 2: Update `CatppuccinColors.light` to expose the required semantic roles and align the live theme-extension contract.
Completion check: Light theme structure matches dark theme for the targeted explicit roles and live extensions, while dark live consumer output remains unchanged apart from any approved removal of unused `SelectedButtonThemeData`.

Stage 3: Add or update focused theme tests.
Completion check: Automated tests verify the parity contract, required explicit role values, live extension presence in both themes, the panel-scoped `MapTrackInfoPanel` plus export-button semantics primarily through the direct track and route panel test files, and the required `SideMenu` / `ElevationProfileChart` consumer checks.
</stages>

<validation>
Run automated coverage for the theme contract and any impacted widget assertions.

Required baseline coverage outcomes:
- Logic/configuration: tests verify both theme factories expose the required semantic roles and live extensions.
- UI behavior: tests verify concrete light-theme consumers can resolve updated semantics correctly, with direct `MapTrackInfoPanel` widget tests as the required `colorScheme.secondary` plus panel-scoped `onSecondary` consumer coverage, `SideMenu` as the required `primaryContainer` consumer, and `ElevationProfileChart` as the required `surfaceContainer` consumer.
- Critical journeys: no robot-driven journey test is required for this change because it does not add a new cross-screen user journey; focused widget and theme tests are the expected coverage split.

TDD expectations:
- Follow vertical-slice TDD with one failing test at a time.
- Start with the smallest public contract failure, such as incorrect light `secondary` semantics, mismatched light app bar structure, or the missing panel-scoped `MapTrackInfoPanel` semantic override.
- After each failing test, implement only the minimum code change needed to pass. Early slices may stay inside `./lib/theme.dart`; later slices may also require `./lib/screens/map_screen_panels.dart` for the approved panel-scoped override.
- Refactor only once the current test is green.

Suggested test slices:
1. Failing test: light theme no longer uses the old accent-like `secondary` value and instead matches `Color(0xFFDCE0E8)`.
2. Failing test: light `AppBarTheme` mirrors the agreed scaffold/app bar relationship across all in-scope fields.
3. Failing test: `iconTheme.color` intentionally matches `onPrimaryContainer`.
4. Failing test: `./test/widget/map_track_info_panel_test.dart` proves the light `MapTrackInfoPanel` applies the approved panel-scoped semantic foreground override on its `secondary` surface, with explicit assertions for icons, labels, and text descendants that must resolve to `onSecondary`.
5. Failing tests: light theme provides the required mirrored role values.
6. Regression tests: dark theme retains its current live values and extension set, minus any approved removal of unused `SelectedButtonThemeData`.
7. Regression tests: `./test/widget/map_route_info_panel_test.dart` proves the route variant of `MapTrackInfoPanel` still renders correctly under the panel-scoped override.
8. Failing or regression test: `./test/widget/map_track_info_panel_test.dart` and/or `./test/widget/map_route_info_panel_test.dart` proves the visibility `Switch` keeps default `Switch` semantics with no widget-local thumb, track, or overlay color overrides.
9. Failing or regression test: `./test/widget/map_route_info_panel_test.dart` proves route timing action icons follow the direct panel foreground contract.
10. Failing or regression test: `./test/widget/map_track_info_panel_test.dart` and/or `./test/widget/map_route_info_panel_test.dart` proves the export control uses `FilledButton.icon` without manual color/style overrides and does not inherit the panel-scoped `onSecondary` override.
11. Failing or regression test: `./test/widget/elevation_profile_chart_test.dart` proves the disabled time toggle resolves its disabled background from `theme.colorScheme.surfaceContainer` under `CatppuccinColors.light`.

Testability seams:
- Exercise `CatppuccinColors.light` and `CatppuccinColors.dark` directly as public outputs.
- Prefer direct theme assertions over mocking.
- Use widget tests only when validating that a real consumer resolves the updated role through `Theme.of(context)`.
- Prefer existing or adjacent tests that can exercise `MapTrackInfoPanel`, `SideMenu`, `dashboardChartSurfaceColor()`, or `ElevationProfileChart` under `CatppuccinColors.light` rather than inventing new artificial test hosts.
- Treat `./test/theme_test.dart`, `./test/widget/map_track_info_panel_test.dart`, `./test/widget/map_route_info_panel_test.dart`, `./test/widget/elevation_profile_chart_test.dart`, and `./test/widget/objectbox_admin_shell_test.dart` with new `SideMenu` assertions as the primary update targets before introducing `./test/widget/side_menu_test.dart`.

Recommended commands:
- `flutter test test/theme_test.dart`
- `flutter test`
</validation>

<done_when>
1. `./lib/theme.dart` gives light mode the same intended semantic theme structure as dark mode for the explicit roles in scope.
2. The live theme-extension contract is intentional and symmetric: `SearchButtonThemeData` and `RowHoverTheme` exist where used, and unused `SelectedButtonThemeData` is removed unless a real consumer is introduced.
3. Light `AppBarTheme` mirrors the agreed scaffold/app bar relationship used in dark mode across all in-scope fields.
4. Light `secondary` is reassigned to a surface/panel semantic consistent with dark theme usage.
5. `MapTrackInfoPanel` applies a panel-scoped semantic override so its content on the secondary surface reads from `onSecondary` without a global text-theme rewrite.
6. `iconTheme.color` intentionally matches `onPrimaryContainer` in both themes.
7. Theme tests and direct consumer tests verify semantic parity and guard against regression in both modes, including both direct track and route panel branches, a separate export-button surface contract, a concrete `SideMenu` `primaryContainer` assertion path, and a concrete `ElevationProfileChart` `surfaceContainer` assertion path.
8. Dark live consumer behavior remains unchanged apart from any approved removal of unused `SelectedButtonThemeData`.
9. No unrelated screen-level styling work is included.
</done_when>
