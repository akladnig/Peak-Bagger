# App Development Standard

**Standard revision:** ADS-1.0 — 2026-10-13

**Current amendment:** 2026-10-19, user-requested adoption of shared text-field
styling, neutral idle outlines, Data-matched hover, scoped tooltip exclusion and
draft-preserving live Search with contextual Command+F, following the
2026-10-17 navigation, theme Settings, Admin and button refinements. Retain the ADS-1.0
identifier; copied apps must record this amendment date as well as the revision.

**Dropdown delivery supplement — 2026-10-20:** Spec 0007's approved shared field/menu
and dismissal rules, including the final human-reviewed L4 corrections, are adopted
in §§4/5/9/13 below. Retain ADS-1.0 and the preceding 2026-10-19 amendment provenance.
The final dropdown rules supersede the initial full-width boxes, primary-role
checkmarks, outlined menu-row focus and 48px macOS menu-row minimum.
The current rules below supersede conflicting original-publication wording. See
[the amendment history](#12-amendment-history--2026-10-19) for provenance and scope.

**Local dropdown presentation supplement — 2026-10-21:** Peak Bagger's approved
Spec 0069 refinement adds caller-configured labelled-field or icon-only triggers
and label-only or icon-plus-label menu rows to §§5/9. This locally extends the
2026-10-20 contract; it does not claim an upstream starter change or runtime Pass.
Retain ADS-1.0 and the preceding amendment/supplement provenance; see §14.

**Local verification scope amendment — 2026-10-21:** Peak Bagger theme testing uses
only **My Seed Colour (`#7E47EB`) in dark mode**, as explicitly requested by the
user. The [app profile](app-profile.md#theme-testing-scope--approved-2026-10-21)
defines the single configuration and supersedes broader testing matrices below
and in existing Specs/Work Items. Runtime light/dark/custom-seed support and shared
styling rules are unchanged; this is a local verification amendment, not an
upstream starter change or runtime acceptance claim. Retain ADS-1.0 provenance.

**Provenance:** Published by the My Flutter Template starter app project from its Reusable App Development Standard and ACT Integration Spec and Interview Ledger (0002). The agreed foundation and visual/interaction decisions were checked against Peak Bagger's current theme, popup/dialog callers, ObjectBox Admin Route flow, providers, services, formatters, and tests. This is a deliberate reusable written contract, not a claim that either app already complies at runtime.

## 1. Authority, portability, and adoption

The **App Development Standard** is the written contract. A **Starter app** is the reusable Flutter code foundation. Publishing or copying this document does not implement that foundation.

Apply three distinct kinds of contract:

1. **Required shared rules:** mandatory foundations and shared visual/interaction requirements in this document.
2. **Selected-profile obligations:** the platform, layout, input, and window requirements of Desktop wide or Apple adaptive.
3. **App-specific decisions:** domain rules, selected values, permitted customisations such as seed colour, and feature behaviour recorded locally in `ai_specs/app-profile.md` and affected feature Specs.

Supporting architecture/testing guidance is labelled as defaults where it is not an explicitly resolved product choice. Existing code and screenshots are evidence to audit, not implicit permission to diverge from a required rule. Report conflicts between the standard, profile, feature Spec, historical docs, and implementation, identifying both sources and the affected behaviour. Do not silently override or replace ObjectBox, Riverpod, or GoRouter.

**Proposed non-blocking governance default — not a confirmed approval policy:** explicitly record an intended exception's rule, reason, scope, affected features, and approval status in the profile or feature Spec; report intentional conflicts during refinement. The full approval/exception policy remains an **open question** from deferred ledger decision L10. No approval authority or exception process is presumed settled. A profile entry alone does not authorise replacement of a mandatory foundation.

### Required local documents

- The local copy of this standard, normally root `coding-rules.md`.
- `ai_specs/app-profile.md`, declaring the selected profile and app decisions.
- Root `AGENTS.md`, referring project-locally to both documents before relevant ACT planning or implementation.
- The affected Spec and Work Item; read the nearest relevant `GLOSSARY.md` and project docs when present. Preserve `.act/workflow.md` semantics and `.act/config.yaml` workflow-storage selection.

These are documentation adoption requirements. Source files such as `lib/theme.dart`, `lib/core/constants.dart`, popup helpers, providers, and tests are **optional example-code locations**, not prerequisites that every copied app already contains. Use the app's actual local equivalents when available. A missing planned helper is an implementation gap, not a reason to read another repository at runtime or during planning.

### Copy and revision procedure

1. Copy the standard into a new app's root as `coding-rules.md`, retaining revision and provenance. Keep the reusable rules together; put app choices in `ai_specs/app-profile.md`.
2. Add project-relative standard/profile references to `AGENTS.md` and select a profile. A copied app must be able to follow the entire contract using its own documents, without access to the original absolute master path.
3. Record the adopted revision and amendment date, adoption status, unresolved values, observed runtime configuration, and alignment follow-ups in the profile. Separate documented targets from implemented/verified behaviour.
4. When a later revision is available, review its changes against the local profile, feature Specs, and implementation. Deliberately replace the local standard, update the adopted revision, and record any resulting implementation work. A revision update is not automatic proof of compliance.

On adoption, Peak Bagger retains its existing local standard location, `ai_specs/coding-rules.md`, with `AGENTS.md` pointing there. Keep one authoritative standard copy per app. Peak Bagger's required adoption profile is Desktop wide only; the starter's planned profile is Apple adaptive. Adoption wiring and profiles are separate from publication of this canonical document.

This procedure defines no synchronisation tooling, shared package, setup-script behaviour, custom ACT configuration schema, or global skill changes.

### ACT use of the local contract

| Stage | Required use |
| --- | --- |
| `act-interview-flutter` | Read local standard/profile before relevant questions; identify selected-profile obligations and pending decisions. |
| `act-create-spec-flutter` | Capture the selected profile and exact applicable constraints; settle feature-specific behaviour rather than infer it from samples. |
| `act-refine-spec-flutter` | Check conflicting sources, proposed deviations, implementation gaps, and decisions that block affected work. |
| `act-create-issues-flutter` | Carry local references into Required Context and observable relevant acceptance criteria. |
| `act-implement-flutter` | Apply the agreed rules, resolve blockers, and verify affected behaviour against the selected profile. |

**Pending-value walkthrough:** an Apple adaptive profile may publish “Compact/wide navigation breakpoint: `Pending`”. Documenting components or implementing unrelated formatter logic may proceed. A Work Item implementing breakpoint-dependent navigation, or an acceptance criterion requiring a particular compact width, needs that breakpoint resolved first. An observed current width is not an approved target. Do not guess a breakpoint to unblock the layout work.

## 2. Mandatory foundations and responsibility boundaries

| Mandatory foundation | Role |
| --- | --- |
| **ObjectBox** | The app database for persistent domain records. It is required, not an optional persistence recommendation. |
| **Riverpod** (`flutter_riverpod` for Flutter) | Application state management and dependency injection. |
| **GoRouter** (`go_router`) | Routing and navigation; the app owns its destination and back-navigation contracts. |

ObjectBox runtime/native libraries, `objectbox_generator`, and build tooling support its entity generation and platform integration. `shared_preferences` is the established default for small app preferences; it does not replace ObjectBox for domain records.

Choose mutually compatible Flutter/Dart, package, generator/native library, and Apple deployment requirements. Review breaking changes and regeneration/platform implications deliberately, preserve reproducible application dependency resolution, and verify upgrades on the app's supported targets. This standard does not permanently pin extracted package versions. The separately scoped starter implementation Spec owns its particular dependency and deployment-target values; those are not universal version requirements.

### Actionable ownership defaults

- **Widgets** render state, collect input, and dispatch intents. They may present UI feedback but should not hide database writes or business/external operations inside rendering.
- **Riverpod providers/notifiers** own application and screen state, coordinate actions, expose pending/success/error outcomes, and supply dependencies. Derive views from the authoritative state instead of maintaining competing mutable copies.
- **Services** own business/external operations, including API calls and operation-specific validation or transformations.
- **Data-access boundaries** (the project's existing repositories/storage adapters or equivalent) own ObjectBox reads, writes, queries, relationships, and required transactions. Do not spread `Store`/`Box` operations across widgets.

Prefer established project conventions. A trivial pure helper does not need speculative service/repository layers. Keep a boundary when it clarifies ownership or allows meaningful verification.

| State kind | Single authoritative owner |
| --- | --- |
| Persistent domain records | ObjectBox through the data-access boundary; provider state is an observable projection/cache with explicit refresh or invalidation. |
| Small preferences | Preference storage plus its provider/notifier; widgets do not independently persist a second version. |
| Application/screen state | Riverpod provider/notifier, including selection, coordinated loading, filters, and application-level operations. |
| Temporary edit state | One explicit draft owner for the operation; commit through the action boundary, discard on permitted Cancel, and keep separate from persisted records. |
| Transient widget presentation | Small widget-local text/focus/scroll controllers, hover/animation state, or a self-contained form draft may be local; this is not a replacement for Riverpod application state. |

Provide dependencies through providers or explicit construction; prefer Riverpod overrides in tests over globals or silent fallback storage. Make side effects explicit at startup/action boundaries, not repeated on widget rebuild. Give stores, clients, subscriptions, timers, controllers, and router listeners clear lifecycle owners. Use provider disposal hooks or widget disposal as appropriate; close a shared resource only from its owner. Handle async completion after disposal and stale responses deliberately.

Replace database, network, platform/file access, preference storage, and clock dependencies where meaningful verification depends on their behaviour. Keep ownership visible when work outlives the initiating screen. Do not automatically cancel app-owned background work just because its initiating widget disappears.

### ObjectBox discipline

- Edit entity source and regenerate bindings. **Never hand-edit `objectbox.g.dart`.** Review generated output with the source change using the project's documented generator command.
- Preserve schema/model identity, UIDs, and model history, including `objectbox-model.json`. Do not reset the model or recreate entity/property identities to disguise a migration. Follow supported schema-change tooling and verify existing-data compatibility.
- Initialise the app-owned store once at the startup boundary, before dependent operations. Inject data-access dependencies; make startup failure visible and avoid silently substituting an in-memory database in production.
- Use a transaction when multiple writes/relationship changes form one atomic operation or consistency requires a coherent read/write snapshot. Keep required transaction work inside the data-access boundary, and keep unrelated network/platform awaits outside the transaction.
- Close queries/subscriptions and the store at their owned lifecycle boundary, after dependents stop using them. Clean up a partially initialised store on startup failure. Tests close stores before deleting temporary directories.
- Keep generated/model artifacts according to the project's reproducible-build policy and document native test-library prerequisites. Do not copy Peak Bagger entities or database data as the universal foundation.
- An **ObjectBox Admin** screen is required when ObjectBox is implemented; see section 8 before defining that implementation work.

### Preferences and the starter Settings contract

Use shared preferences for small settings, separate from ObjectBox domain records. Make preference loading/saving dependencies replaceable and errors observable.

The starter's separately specified theme-mode Settings behaviour is exact:

- Supported values: `system`, `light`, `dark`; default: `system`.
- Startup loading failure leaves system mode and shows a visible in-app **SnackBar**.
- Saving failure restores the prior mode and shows a visible in-app **SnackBar**.
- Persistence works across restarts without a network/external-service dependency.

A binary toggle and silently retained failed save do not fulfil this contract.
The starter now also implements **Theme / Theme Colours / Seeded Scheme Variant /
Seeded Contrast Level**, in that order. Its exact swatches, presentation order,
labels and storage keys belong in [the app profile](ai_specs/app-profile.md#theme-preference)
and [Spec 0004](ai_specs/0004-peak-bagger-ui-parity/spec.md#theme-settings).

When theme customisation is provided, derive both schemes from the effective seed,
variant and contrast. Apply seed/variant choices immediately and persist
automatically; preview contrast live and persist once on completed pointer,
keyboard or accessibility adjustment. Cancel an unfinished preview to the last
committed value. Keep preferences independently committed: missing keys use defaults,
malformed/failed loads use the affected default with a visible SnackBar, and failed
saves restore only the affected saved value with retry guidance. Acquire the save
lock before awaited preparation, prevent overlapping/conflicting changes, show
progress and retain session-owned results/error feedback across route changes.
Do not load or save on rebuild. This does not require every app to expose pickers.

## 3. Platform and layout profiles

Select one profile explicitly. Platform scope, layout scope, and native window mode are separate concepts.

### Desktop wide

- **Supported platforms:** macOS only.
- **Layout scope:** wide desktop interfaces with compact rows/toolbars and keyboard/pointer affordances. Compact/narrow navigation is not required.
- **Window behaviour:** maximised on launch, with a declared minimum usable window width and height.
- **Native window mode:** a separate declared choice; maximised does not mean native macOS full-screen mode.
- Keep essential content/actions usable within the declared supported window range and at supported text scales, wrapping or scrolling as needed. Do not add iOS/touch-layout obligations to a Desktop wide app.

### Apple adaptive

- **Supported platforms:** macOS and iOS.
- **Layout scope:** wide and compact/narrow layouts selected from available constraints, not device-name assumptions. Include touch support and appropriate keyboard/pointer behaviour when available.
- Adapt navigation while preserving destination identity, selection, and back behaviour. Choose the app's wide/compact shells in its profile/Spec; the starter's exact Drawer flow is a local contract.
- Keep content and actions accessible on small screens/windows, including short available heights, safe areas, text scaling, and keyboard-visible forms. Constrain and scroll form bodies, retain access to validation and submission controls, and bring focused fields into view.
- Declare macOS launch/window behaviour and native window mode separately from layout breakpoints. Do not inherit Desktop wide maximisation automatically.

### Required project-profile declarations

Use plain Markdown in `ai_specs/app-profile.md` to declare:

| Field | Declaration |
| --- | --- |
| Adopted standard | Revision and documentation/runtime adoption status. |
| Selected profile | Desktop wide or Apple adaptive. |
| Supported platforms | Explicit supported targets. |
| Layout scope | Wide only or wide plus compact/narrow, including navigation choices. |
| Window behaviour | Launch maximisation/initial behaviour and resizing policy where applicable. |
| Native window mode | Native full-screen choice independently of maximisation. |
| Minimum usable dimensions | Named macOS width and height, or explicitly named `Pending` values. |
| Breakpoints | Applicable constraint thresholds, or explicitly named `Pending` values; mark inapplicable thresholds as such. |
| App customisations/domain rules | Seed override, domain styling/formatting, routes, and feature-local decisions. |
| Observed runtime configuration | Evidence recorded separately from approved targets and follow-ups. |

Named `Pending` values pass this documentation release. Resolve them before affected layout implementation or dimension-dependent acceptance criteria; unrelated work may proceed. There are no universal approved window dimensions or breakpoints. Peak Bagger's observed native minimum width `1024`, height `0`, and launch zoom are evidence, not an approved minimum usable width/height contract.

## 4. Shared theme, typography, sizing, and accessibility

### Theme and state styling

Use seed-generated Material light/dark themes with this shared baseline:

| Setting | Value |
| --- | --- |
| Seed | `#7E47EB` |
| Scheme variant | `DynamicSchemeVariant.vibrant` |
| Contrast level | `0.0` |

This supersedes historical Catppuccin descriptions. Match semantic component roles across runtime light/dark themes; verify readable foreground/background pairs using the app profile's testing scope (Peak Bagger: My Seed Colour, dark only). Use theme-derived surfaces, outlines, foregrounds, and error colours; an incidental widget-local override or historical dark-mode quirk is not authoritative.

Centrally theme controls and their selected, hovered, focused, pressed, and disabled states. Keep selection distinct from hover and make keyboard focus visible even on selected rows. Disabled controls must look unavailable. Use the theme's semantic foreground for its actual surface, including `onSurface`, `onPrimaryContainer`, and `error` as appropriate; do not copy a blanket icon colour onto incompatible backgrounds.

An app may declare a different seed colour in its profile while keeping typography, spacing, component styling, and interactions shared. Mapping colours and domain chart-series palettes are domain styling. Every app need not expose seed/scheme/contrast pickers.

Hide Flutter's **DEBUG** ribbon in every application root, including startup
loading/failure screens, with `debugShowCheckedModeBanner: false`.

### Typography and token ownership

Use Material text roles and platform-default fonts. Define consistent heading weights and component text styles centrally instead of screen-local arbitrary font sizes. Theme/style tokens are separate from domain constants; an app may colocate them initially if their responsibilities remain clear.

Use this named **4-logical-pixel spacing scale** (token names below are the shared descriptive names):

| Token | Logical pixels |
| --- | ---: |
| `space4` | `4` |
| `space8` | `8` |
| `space12` | `12` |
| `space16` | `16` |
| `space24` | `24` |
| `space32` | `32` |

Shared **card/popup surface radius is `12` logical pixels**. Button shapes belong in central component themes. Ratios such as a 1.25-based sizing system and scattered ad-hoc gaps are not equally authoritative alternatives to this scale. Domain geometry, column widths, and thin dividers are not a competing spacing scale; define justified component metrics centrally.

The named DataGrid metrics in section 8 (including **6** vertical row padding)
are adopted component-specific metrics, not additions to the general spacing scale.
The starter's wide navigation similarly adopts a centrally defined **10-pixel regular**
Material-role/platform-font label at scale 1 and a **70-pixel** coloured rail with
**8-pixel** outer margins. Honour actual scaling, full labels through wrapping/
vertical scrolling, touch targets and focus. Exact destination labels, compact
Drawer presentation and the **800** breakpoint remain app-profile contracts.

### Density, sizing, and accessibility

- Desktop rows/toolbars are compact while retaining clear hover, keyboard focus, selection, and pointer affordances.
- In profiles including touch layouts, interaction targets are at least **`48 × 48` logical pixels**, even if glyphs are smaller. The explicitly approved dropdown-menu-row exception is **40px minimum height on macOS desktop only**, as specified in §5; iOS menu rows, closed dropdowns and other controls retain their 48px minima. Do not impose new iOS/touch support on Desktop wide.
- Respect text scaling, semantics, accessible labels, and logical focus traversal. Do not reduce text scale merely to make a layout fit.
- Essential labels, values, and actions wrap or scroll rather than clip. Account for available height and the on-screen keyboard as well as width; a wide but short viewport can still need scrolling.
- Size surfaces against their actual constraints. Keep primary and dismissal controls reachable at supported sizes; a hard-coded source popup size is not a universal dimension.

## 5. Components and actions

The footer, cursor, labelled-field/validation/input-retention, FAB, icon/text, and popup/dialog focus/dismissal requirements below are the **L17-approved component baseline**, together with L8/L9/L15 visual/action decisions. The additionally labelled recommendations are author-selected supporting defaults, not further interview-approved product decisions. Feature Specs must settle save/cancel/retry, persistence, validation timing, invalid-submission behaviour, outside-click dismissal, unsaved-change handling, and operation locking.

### Buttons and action order

- Popup/dialog **labelled footer primary actions and Cancel/Close use `FilledButton`**. Shared FilledButtons use `colorScheme.primaryContainer` backgrounds and `colorScheme.onPrimaryContainer` foregrounds in **both light and dark themes**, with centrally themed, theme-derived interaction states and shapes.
- **Cancel** abandons an editable operation; **Close** dismisses read-only content. Cancellation/secondary actions precede the primary action; the primary action is last. Align footers right where space permits and wrap/reflow actions so they remain accessible in supported layouts.
- Accessible header Close `IconButton`s are permitted. Do not reinstate the superseded TextButton-cancel proposal. Unrelated links, toolbar controls, and selection toggles need not become FilledButtons.
- **All new icon-only action buttons** inherit the central **circular** shape and
  interaction background, including Edit, Close, row trash, Search, menu and future
  toolbar/panel actions. Use a `CircleBorder`, transparent idle and focus-only
  backgrounds, `onSurface` hover overlay at **0.08** and pressed overlay at **0.12**.
  Keyboard focus uses a visible **2-pixel primary-colour circular outline**, not a
  filled focus disk; disabled controls dim, suppress interaction overlays and use a
  basic cursor. Do not replace the shared shape with local rectangular styles.
  Keep at least **48 × 48** targets for touch profiles. Labelled buttons retain
  their centrally themed **12-pixel rounded rectangle** and footer colour pairing;
  navigation destinations and selection/mode controls retain their own composition.
- Give actions meaningful labels and implement their enabled/disabled/pending semantics. Feature-specific persistence and confirmation are decided in the feature Spec, not guessed from button appearance.

### Popups and modal dialogs

**Transient popup:** a contextual surface attached to content/selection, with explicit header, body, and optional footer. It need not behave as a modal route or trap background focus. Provide deliberate focus entry and a clear dismissal affordance; return focus to the invoking control/context when appropriate.

**Modal dialog:** an operation or information surface that temporarily contains keyboard focus and blocks interaction with the underlying route. Keep focus traversal within the dialog and restore focus appropriately on dismissal. Use the app's established dialog/navigation mechanism rather than inventing competing route state.

Both types use shared spacing tokens and the 12-logical-pixel surface radius, coherent header/body/footer spacing, a clear title, labelled/icon dismissal affordances, and viewport-aware body scrolling. Header and footer must remain reachable; allow footer wrapping when width is insufficient. Use shared shell/dialog helpers when present, adapting them to the supported profile rather than assuming their current implementation is complete.

Route header close, footer Cancel/Close, Escape, Ctrl+C, back, and any permitted outside-click dismissal through the same feature-approved cancellation/close policy. The feature Spec decides outside-click dismissal, unsaved-change handling, and whether work locks dismissal or can be cancelled. Disabling only the Cancel button is insufficient if another dismissal path bypasses the lock.

**Representative examples, described without requiring external code:**

- **Import Peak List** is the modal-form reference: a labelled name input with beside-field validation, file selection, a FilledButton **Cancel / Import** footer, and pending-operation feedback. Its live Peak Lists header action opens a dialog; accepted imports are handed to app-owned background jobs. The domain import/update actions and job policy are not universal requirements.
- **Peak Info** is the popup-shell reference: header icon actions including Close/Edit, a scrollable body, read/edit states, and a wrapping FilledButton **Cancel / Save** edit footer. The main-map caller supplies edit/save operations; the Peak Lists mini-map caller uses the card with different capabilities. Peak/mapping actions, pinning, and fixed source dimensions remain domain behaviour.
- `PeakListCreateDialog` has no runtime callers in the audited source; it is not evidence of a live screen flow.

These references demonstrate reusable composition, not uniform compliance. In particular, the audited Import caller's barrier dismissal and failure handling need review against any required operation lock/input-retention policy.

**Additional author-selected composition default:** start with `space12` surface padding, `space8` header-item gaps, and `space12` footer-action gaps; use shared tokens to adjust consistently for content and constraints. This recommendation extracts source composition without making every incidental source metric mandatory.

### Cursors

Use platform-appropriate cursors: enabled clickable actions use a click/pointer affordance, editable text uses a text cursor, draggable content uses grab/grabbing or move feedback, and resizable edges use the appropriate directional resize cursor. Disabled controls must not advertise a click/drag action that cannot run. Cursor feedback supplements accessible labels and keyboard operation.

### Text fields and validation

Field labels remain visible independently of placeholders; placeholder-only identification is insufficient. Put field-specific validation beside the field and preserve input after recoverable failures. Use appropriate input types and make errors/focus reachable when the keyboard is visible. The feature Spec determines validation timing, invalid-submission handling, transformations, and save/cancel/retry semantics.

**Required shared field theme — amended 2026-10-19:** own decoration centrally in
the app's `InputDecorationThemeData` for all TextFields and theme-inheriting text-form
fields, rather than repeating border/text styles in each screen. Define central
`searchControlFontSize = 14.0` and `searchControlIconSize = 24.0` tokens. The label
size applies to ordinary fields as well as Search. Retain platform fonts and actual
text scaling; these are logical-pixel sizes at text scale 1.

| Decoration property | Required value |
| --- | --- |
| `labelStyle` | `TextStyle(fontSize: searchControlFontSize, color: colorScheme.onSurface)` |
| `isDense` | `true` |
| `border` | `OutlineInputBorder(borderSide: BorderSide(color: colorScheme.onPrimary))` |
| Enabled/unfocused outline | `colorScheme.outline`, width `1`; hovered: effective configured seed, width `1` |
| `focusedBorder` | `OutlineInputBorder(borderSide: BorderSide(color: effectiveSeedColour, width: 2))` |

Use the supplied constructors' defaults for unspecified border metrics, including
the outline radius; the 12-pixel card/popup radius does not prescribe field borders.
Resolve colours when constructing the theme: `effectiveSeedColour` is the currently
effective configured seed, not the generated `primary` role or a hard-coded seed
that ignores preference changes. Apply the rule in both light/dark themes, including
custom seeds and preference rollback. A runtime theme colour cannot be part of a
Dart `const TextStyle`. Keep visible labels (ordinary fields always float; Search
may use the app's persistent inline/floating label), central content padding,
inline error wrapping, disabled/error styling and input retention. Dense layout must
not clip labels, errors or editable content.

Enabled fields under the pointer, including focused fields, use the hovered
selected-Data fill:
`Color.alphaBlend(primary.withValues(alpha: .08), Color.alphaBlend(primary.withValues(alpha: .12), surface))`,
using current `ColorScheme` roles. Share selection/hover layer definitions centrally
with mode buttons; do not apply the hover overlay twice. Restore the prior fill on
exit, suppress disabled hover, and retain focus/error border priority. No idle
selected tint or focus-only fill is added. Labelled-field selection-only dropdowns
share these field states as specified below; icon-only triggers use the central
icon-action states instead. Unrelated controls do not become editable fields.

**Hover-outline correction — 2026-10-19:** enabled/unfocused hover uses
`BorderSide(color: effectiveSeedColour, width: 1)`, restoring semantic outline on
exit. Focus/error/disabled borders retain priority. With filled outlined fields,
centrally resolve `activeIndicatorBorder` and leave `enabledBorder` unset so Flutter
can apply the hover state; retain the default onPrimary border shape. Search's
empty/unfocused inline shortcut label uses the theme's disabled foreground colour;
its floating label keeps the normal onSurface label colour. This dims the inline
cue without disabling Search or dimming entered text and ordinary labels.

**No tooltips on text fields or their associated controls.** Preserve meaningful
accessible names; other controls retain the tooltip requirements below. Only a
Search field receives a leading `Icons.search`, size `searchControlIconSize`, supplied
at that field rather than as an unconditional global prefix. It is decorative,
with no tap action, button semantics, independent focus stop or pointer-action
affordance. Ordinary edit fields have no leading magnifying glass. Text fields have
no individual submit button; editable operations retain their feature-approved
Save/Cancel boundary. Search has no trailing submit button; its live/Enter behavior
is defined in section 8.

### Shared selection-only dropdowns

Use one centrally styled, reusable presentation for all current and future
selection-only single-value dropdowns. Keep closed-field typography separate from
the smaller opened-menu typography; do not copy styles into individual screens.

**Caller-configured variants — local supplement 2026-10-21:** independently choose
a **labelled-field** or **icon-only** trigger, and **label-only** or **icon-plus-label**
menu rows. These are reusable presentation options selected by the feature caller,
not a new user preference, selector capability or separate menu style. Feature
Specs declare the chosen variants; do not silently replace required form labels
with icons. Both trigger variants share the opened-menu and interaction rules below.

#### Labelled-field closed boxes

Inherit the central TextField decoration and selected-value typography: dense layout,
**12px content padding**, **14px onSurface label style** at text scale 1, platform
fonts, actual text scaling, **onPrimary** fallback outline and constructor-default
field radius. The opened menu's 12px radius does not replace the field radius.

**Size each box only as wide as needed**, bounded by available width. Account for
the longest option/value or current hint, the complete floating label, indicator,
padding and framework input gaps using the actual text styles and text scaler.
Keep width stable across selections when options are unchanged. Do not stretch
dropdowns across a toolbar, form or Settings section merely because space exists.
At constrained widths, wrap complete values and retain access to the label/error
without ellipsis or reduced text scaling.

Connect decoration to the real interaction state:

| Closed-box state | Outline |
| --- | --- |
| Enabled, unfocused, idle | `colorScheme.outline`, **1px** |
| Enabled, unfocused, hovered | Effective configured seed, **1px** |
| Enabled, focused | Effective configured seed, **2px** |
| Enabled, expanded/open | Effective configured seed, **2px**, even while actual focus belongs to the menu |
| Error / focused error / disabled | Preserve the corresponding shared TextField role and priority |

Enabled hover applies the shared selected-Data composite **once**, including focused
fields: primary **8% over 12% over surface**, as defined in the text-field rules.
Pointer exit restores the prior fill; there is no idle selected/focus-only tint.
Disabled fields suppress hover and action cursors. Colours follow live effective
seed/variant/contrast/brightness changes and failed-preference rollback.

Always float the meaningful field label independently of value/hint, wrap complete
closed values, retain beside-field validation and a decorative dropdown indicator.
Keep one **48 × 48** minimum field target, no independent indicator focus stop,
associated tooltip, Search icon or individual submit action. These controls select
existing typed values; they do not accept arbitrary text, search/autocomplete or
multiple selections. A choice-less required field may retain programmatic validation
focus without enabling selection; a mutation-disabled field cannot regain focus.

#### Icon-only triggers

Use the central circular icon-action styling from **Buttons and action order**, not
a miniature TextField box: transparent idle/focus-only background, `onSurface`
hover/press overlays at **0.08 / 0.12**, disabled dim/basic cursor and no double
overlays. Keep a single **48 × 48 minimum** trigger target and one activation/focus
owner; add no separate indicator focus stop. Show the central **2px primary circular
outline** for keyboard focus and while expanded, including when focus is in the
menu; error/disabled state retains priority. Use live theme roles and rollback.

Give the trigger a meaningful accessible action name, expose its expanded state
and current selected value, and provide a desktop tooltip. It is a standalone menu
action, not a text-field-associated control: the labelled-field tooltip prohibition,
floating label, value-box measurement and Data-matched field fill do not apply.
The feature Spec identifies its icon (which may reflect the current value). Do not
hide an ordinary required input label or validation problem behind an icon/tooltip.

#### Opened menus

Use a centrally owned **12px rounded**, subtly outlined/shadowed, theme-derived
surface with left-aligned labels. Menu labels are **12px at text scale 1**, retaining
platform fonts and actual scaling. Rows have minimum height **40px on macOS desktop /
48px on iOS touch**, growing whenever wrapped/scaled text needs more space.

Exactly the committed value has one trailing checkmark and accessible selected
state. **The tick matches the active closed-box border colour**: effective seed in
normal operation, the error role when applicable, and dimmed when disabled. Do not
substitute generated `colorScheme.primary` for the effective seed. Icon-only
triggers retain this same effective-seed/error/disabled menu-tick policy, not the
button's primary focus-ring colour. Reserve equal checkmark space so
selected/unselected labels align. Selection adds no idle row fill.

Choose **label-only** or **icon-plus-label** consistently per menu. Label-only
rows have no leading option-icon slot. Icon-plus-label rows retain complete text
and add a decorative leading icon using centrally owned sizing/spacing and semantic
foregrounds, dimmed when disabled. Keep labels aligned using a consistent leading
slot, include it in content-width measurement and keep it inside the full-width
interactive background. Icons add no independent focus stop or duplicate accessible
name and never replace the trailing selected checkmark. Trigger and menu-row
variants are independent; neither changes selection, keyboard or dismissal rules.

**No menu-row outlines in any state**, including selected and keyboard-focused
rows. Opening alone adds no automatic row highlight. After keyboard navigation,
show focus using the same background as pointer hover, independently of the
committed checkmark. Derive hover/focus and pressed backgrounds centrally from
`onSurface` at **0.08 / 0.12**, respectively, over the menu surface. Disabled options
dim and suppress these backgrounds. Do not borrow DataGrid selection colours.

Hover/press/focus backgrounds fill the **entire row width through the menu's clipped
rounded edges**. Keep no untinted outer-list gutter: the current shared defaults
are **zero outer menu padding**, **12px horizontal / 8px vertical option padding**,
**24px checkmark space** and a **12px label/checkmark gap**. Padding stays inside
the row's interactive background. Surface/outline/shadow use semantic theme roles;
the starter's current `surfaceContainer`, `outlineVariant` and elevation `3` are
central implementation defaults, not screenshot-measured product dimensions.

Prefer below-trigger opening when possible. Start with trigger-width minimum and allow
content-driven growth within safe/keyboard-aware viewport bounds; narrower available
bounds override the minimum. Adapt at edges, wrap remaining long labels without
ellipsis or reduced scaling, constrain height and scroll to every option.

**Scoped desktop target exception:** the **40px macOS menu-row** minimum is explicitly
user-approved over §4's usual 48px touch-profile target. Scope: desktop dropdown
rows only; iOS rows, closed fields and other controls retain 48px. Reason: requested
compact menu presentation. Approval: [ledger L4](ai_specs/0007-shared-dropdown-styling/interview-ledger.md#l4);
visual re-review **passed**, User 2026-10-20. This does not settle general L10 governance.

#### Interaction and ownership

Focus movement alone does not commit; activation selects/closes. **Outside click/
tap is consumed**: its first gesture only dismisses, and another gesture is needed
to activate a control underneath. **Ctrl+C behaves exactly as Escape**, using the
same dismissal path, eligible invoker focus return and current operation guards.
Escape/Ctrl+C/back close only the open dropdown, with no same-event cascade into
editor cancellation, details closure or navigation. Preserve ordinary editing/Cmd+C
and exclude background Search shortcuts while the menu owns focus. Unrelated
panel shortcuts keep their existing scope.

Keep record IDs/enums, authoritative values, sole drafts, validation, persistence
timing and operation locks at their feature owners. Disable affected fields and
reject captured callbacks immediately when a current lock begins, including before
rebuild; never replay stale selections on unlock. Presentation owns/disposes only
its focus/scroll/listener/overlay resources. Resize/theme rebuilds preserve values/
drafts; invalid/removed anchors close without commit, forced focus to removed
controls or orphan overlays. The starter's exact callers/options remain in its
[profile](ai_specs/app-profile.md#shared-dropdowns); the
[usage guide](docs/shared-dropdown-verification.md) documents the actual shared API.

### FABs and icon/text actions

Reserve FABs for a prominent primary action in the current context. Provide an accessible label, and place the FAB so content and other controls remain reachable. An unfamiliar or ambiguous action uses icon-plus-text. Icon-only actions have accessible labels and desktop tooltips, except text-field-associated controls, which retain accessible names without tooltips. Do not infer domain-only Route/Trail controls or unbundled SVG dependencies from source UI.

### Common icons

| Action | Icon |
| --- | --- |
| Add | `Icons.add` |
| Close | `Icons.close` |
| Delete | `Icons.delete_forever` |
| Edit | `Icons.edit` |
| Filter | `Icons.filter_list` |
| Home | `Icons.home` |
| Info | `Icons.info` |
| Search | `Icons.search` |
| Settings | `Icons.settings` |
| Undo / Redo | `Icons.undo` / `Icons.redo` |
| Refresh | `Icons.refresh` |

Use semantic foreground colours for the actual surface and theme error colours for
destructive actions, except the explicitly adopted Admin table-trash role in
section 8. Supply accessible labels and tooltips where permitted by the text-field
exclusion above. Additional domain icons/assets belong
to the app and must be bundled or otherwise declared there.

## 6. Formatting and keyboard interaction

### Shared number/date formatting

Shared formatter helpers own number/date **display** formatting. Reuse consistent rules for grouping, precision, units, null/non-finite values, and date ranges instead of scattering `toStringAsFixed` or date patterns across widgets. Keep display formatting separate from storage/export precision and field-input parsing. Declare locale/timezone/precision choices when a feature needs them.

Examples extracted from the audited helpers: grouped counts; consistently formatted percentages/file sizes; same-year date ranges that omit the first repeated year, such as “Sat, 9 May - Fri, 15 May 2026”, and cross-year ranges that include both years. These illustrate central ownership, not mandatory English locale or date text for every app.

Distinguish a **date-only value** (calendar year/month/day) from a **timestamp** (an instant). Do not convert a date-only value to local time and accidentally change its calendar day. Convert timestamps only according to the declared display-timezone rule. The source's compact-date helper calls `toLocal()`, whereas Track-date helpers preserve supplied calendar components; select/rework helpers deliberately. Mapping units, Track wording such as “Unknown”, and GPX coordinate precision remain domain/profile rules.

### macOS shortcuts and contextual navigation

Preserve Cmd-based standard actions on macOS:

| Context/action | Shortcut |
| --- | --- |
| Search | **Cmd+F** |
| Undo | **Cmd+z** |
| Redo | **Cmd+shift+z** |
| Permitted cancellation/close | **Escape** and intentionally specified **Ctrl+C** |
| Contextual left/right/up/down | Arrow keys and **h/l/k/j**, respectively |

Use contextual Vim-style navigation where applicable. Scope navigation shortcuts to the active surface so typed text is not intercepted; preserve normal editing/copy shortcuts, including Cmd+C. Escape/Ctrl+C follow the same permitted cancellation/close path as visible controls and honour operation locking. Previous/next actions operate only on the feature's defined navigation/history state. Map-only zoom keys are not universal app requirements. The source keyboard-dismiss helper demonstrates Escape/Ctrl+C handling; its existence does not verify every focus or locking path.

## 7. Async operations, feedback, services, and configuration

Shared async behaviour requires visible pending progress, prevention of duplicate submissions, retained input on recoverable failure, actionable user errors, diagnostic logging, and deliberate cleanup/cancellation. Start pending/duplicate protection before awaited validation or preparation that could otherwise allow another submission. Do not present success before the feature's defined persistence/completion boundary.

The feature Spec decides whether running work can be cancelled or dismissal is temporarily locked, including back/outside-click/keyboard paths and background-job hand-off. Specify what Cancel means, whether partial writes can occur, and what remains available after failure. A disposed widget must not publish stale UI updates or leave screen-owned resources running without an owner.

**Author-selected feedback default:** show field problems inline, use a SnackBar for non-blocking operation outcomes with a useful next action where relevant, and use a dialog when an explicit decision or acknowledgement is needed. Avoid raw exception strings as the only guidance. Explain what failed and what the user can do; log technical error/stack/context separately without secrets. The exact starter theme-failure SnackBar behaviour in section 2 is an agreed contract, not merely this default. Feature Specs settle retry/success/cancel/persistence behaviour.

Supporting service/configuration defaults:

- Keep API protocol, transport errors, parsing, and external operations behind service boundaries; expose domain outcomes to providers and UI. External integrations are feature-specific.
- Inject configuration/dependencies through established project mechanisms, document required values and failure behaviour, and do not introduce undocumented developer-machine paths or dependencies.
- Do not embed **server-only secrets** in Flutter clients. Client-accessible configuration is not secret storage; choose an appropriate feature-specific credential boundary.
- Commit no credentials with the starter. Keep diagnostics free of credentials/private payloads.
- Ordinary automated tests require no real external services, credentials, live API keys, or production data. Use controlled fakes/fixtures/overrides.

## 8. ObjectBox Admin implementation contract

An **ObjectBox Admin** screen must be added when ObjectBox is implemented. The Route admin flow is a visual/interaction reference, not a domain schema, route name, coverage decision, or mapping-feature requirement.

**Before admin implementation**, the affected implementation Spec must enumerate the covered entities and explicitly declare **all-persisted-entity coverage** or **selected-subset coverage**. Do not infer this from the Route reference. For the declared entity set:

- Browse records in rows with **Delete at the trailing end of each row**. Keep it reachable when other fields scroll.
- Centrally theme row/header typography, padding, column gaps, dividers, and
  **hovered, pressed, selected, and keyboard-focused** states using a dedicated
  **DataGridTheme**, separate from generic selectable cards and navigation.
- Adopt Material **labelLarge** headers / **bodyMedium** rows with **onSurface**
  row text; header padding **4 vertical**, row padding **12 horizontal / 6 vertical**,
  column gaps **12**, and primary/value/action base widths **144 / 160 / 72**.
  Scale/reflow against actual constraints and retain independently reachable Delete
  while header/data horizontal scrolling stays aligned. These are base component
  metrics, not inflexible pane widths or permission to clip full detail values.
- Selected-row fill subtracts **0.30** from both HSL saturation and lightness,
  clamped to **0…1**, using the effective chosen **seed in dark mode** and
  **primaryContainer in light mode**. Selected horizontal borders use the same base
  with **0.08** subtractions. **Hover is the selected fill blended with 10% opaque
  white** (`Color.lerp(selectedRowColor, Colors.white, 0.10)`), in both themes and
  for custom seeds. This replaces the former half-alpha primaryContainer hover.
  Selection takes precedence over hover/press; disabled rows do not gain hover/press
  feedback. Unselected press uses **primary at 0.12 alpha over surface**. Keyboard
  focus retains an independent **2-pixel primary outline**, also when selected.
- Admin table/details dividers use a local **onPrimary** colour role at **1 pixel**,
  matching the adopted reference; do not remap the global scheme's outlineVariant.
  Table-row trash uses exact **Colors.red / #F44336** in both themes, transparent
  idle backing even when its row is selected, and the same circular hover/press/
  focus styling as Edit/Close from section 5. Disabled trash still dims and locks.
  This is an explicit adopted Admin visual role; confirmation Delete and other
  destructive actions retain semantic error colours.
- Selecting a row opens its details panel, with **Edit and Close** actions and labelled field values. Header icon actions are permitted if accessible; labelled popup/dialog footers obey section 5.
- Long field values remain **fully accessible and selectable** in **independently scrollable regions capped at five rendered text lines**. Short values use only their required height. Measure the cap using active text style, available wrapping width, and text scale; do not use an unscaled fixed pixel height. The viewport cap must not truncate either stored or displayed values. Users must be able to scroll/select content beyond the fifth line without scrolling only the overall details panel.
- The reference currently uses `SelectableText(maxLines: 5)` for certain Route long fields. That alone **does not prove a scrollable five-line viewport**, full-value access, or scaled-height correctness; explicitly implement and verify the target behaviour.
- Edit forms follow shared validation, **Save/Cancel**, pending, duplicate-prevention, input-retention, and recoverable-error rules.

The affected implementation Spec must settle entity-specific editable/read-only fields, relationship-aware deletion, confirmation/cancellation behaviour, navigation entry, and supported-profile layouts. Even subset coverage retains the required row/details controls for that declared set. Do not copy Route entities, map actions or fixed details-panel widths as universal requirements; use only the explicitly adopted shared visual roles above. Publishing this document does not build the screen.

### Browser and embedded-pane interaction baseline

The adopted starter composition provides an **Entity** selector, **Schema / Data**
modes, a read-only actual-schema view (including empty entities), Data-only live
**Search**, and primary-name/title sorting. Every accepted text edit immediately
filters results, without a debounce or submission requirement; **Enter also performs
the search action** using the current query, including the keyboard search action.
Clearing Search or entering only whitespace immediately restores all rows. Search's
leading magnifying glass is decorative and there is no field-level submit button
or tooltip. Preserve raw field input while applying a trimmed query; any retained
draft/applied search split must apply each accepted edit, not defer it until Enter.
Match a trimmed case-insensitive substring against each
full display value, not a truncated preview or missing-value placeholder; use stable
record identity and deterministic ID sort ties. Entity changes clear search/selection
and reset ascending order; mode changes retain entity/search/sort but clear details.
Render rows lazily and distinguish loading, empty, no matches and retryable errors;
obsolete async reads must not replace newer results. Each app enumerates its own
entities, searchable fields, schema and editable fields in its feature Spec.

Typing, clearing Search and pressing Enter preserve the selected record, open
details/editor and the single unsaved draft, even when the selected record is no
longer in the filtered rows. Search reads committed records, not unsaved editor
contents, and never saves, cancels, closes details, retargets selection or navigates.
Keep query and record identity independent of result membership. Pending Save/Delete
disables Search and guards typing/clearing/Enter at the authoritative operation
boundary, including callbacks retained before a rebuild. Filtering is local and
requires no network; preserve query/draft context and existing Retry/error recovery.

Search focus/select-all shortcuts must preserve the same query, identity and draft
boundaries. Scope bindings to the routed feature, honor current mutation locks
before focus/scroll, and respect modal/Drawer focus boundaries. Do not queue an
unavailable action for later. Exact visible shortcut labels, platform bindings and
compact-details eligibility are app-local contracts in the profile/affected Spec.

For Apple adaptive, use side-by-side table/details on wide layouts and in-route
table→details→editor transitions on compact layouts at the profile's breakpoint.
Save/Cancel returns to read-only details; Close clears wide selection or returns to
the compact table. Keep one draft across resizing. Successful Save retains details
for the same record even when it leaves the applied search; recompute rows/sort
independently and restore/clamp table position. Enter panel focus deliberately
without automatically highlighting Edit or trapping focus; Save/Cancel restores Edit.

The starter's approved idle actions discard edits on row/entity/mode/destination
changes or Close; Sort also discards the draft and clears details. Search typing,
clearing and Enter preserve selection/details/drafts as specified above. Back
unwinds editor→details→compact table before route navigation.
Escape/Ctrl+C is panel-focus-scoped, with dropdown/Drawer dismissal taking precedence
and normal editing/Cmd+C preserved. Pending Save/Delete locks input, duplicate
submission, row/entity/mode/search/sort, dismissal and shell/programmatic navigation
before awaits. Wide table-row Delete confirmations retain the editor/draft through
Cancel/failure/deletion of another record; deleting the edited record clears it.
Compact Delete starts from the table after leaving editing/details. Record each
app's mutation/relationship rules explicitly rather than importing sample entities.

## 9. Forward-looking verification

This section guides implementation work; documentation publication itself needs documentation review, not TDD, unit/widget tests, robot journeys, database setup, package upgrades, or platform builds.

**Peak Bagger verification scope:** all theme-related automated, native and visual
checks use **My Seed Colour (`#7E47EB`) in dark mode only**, normally `MyTheme.dark`.
Do not add light-mode, alternate-seed or custom-theme permutations. Keep behavioural,
failure, scale and layout coverage without repeating it for other themes. Preference
tests use the same seed and dark-mode values; no rendering matrix is needed for
scheme/contrast preference logic. Runtime capabilities and domain palettes are
unchanged. This user-approved local scope overrides any broader verification wording
in copied guidance or historical feature artifacts; retain dated evidence as history.

- **Unit tests:** verify state/services/formatters through public behaviour, including meaningful failures and persistence boundaries.
- **Focused widget tests:** verify shared components and supported-layout states, including themes, focus/semantics, text scaling, constrained sizes, pending/error states, and dismissal policies where affected.
- **Robot journeys:** add them when a feature Spec requires journey coverage. Stable selectors and deterministic Test Seams are required when selected. There is no universal robot or TDD mandate; follow a feature's agreed TDD requirement when present.
- Prefer Riverpod overrides, preference fakes/mock initial values, temporary ObjectBox stores, and controlled database/network/platform/clock dependencies. Dispose containers/controllers/subscriptions; close stores and remove temporary data. Keep production services and user databases out of tests.
- Verify the exact planned starter Settings load/save failure contract with deterministic preference failures, not just a successful binary toggle.
- **ObjectBox Admin widget coverage:** deterministically verify row selection opening details; Edit/Save/Cancel outcomes and retention; delete outcomes specified for the declared entities, including relationships and confirmation/cancellation; and scrolling to/selecting content beyond the fifth line at supported text scales/layouts. Use temporary stores or repository/provider fakes and assert that the full long value remains available and short fields do not occupy five lines unnecessarily.
- Verify actual row hover/exit, selected precedence, the 10%-white hover relation and
   circular icon-action hover/press/focus/disabled styling in My Seed Colour/dark. Cover
  live typing/clearing and Enter Search, sort/schema, Save outside filtered results, resize-preserved
  drafts, scoped keyboard dismissal and pending navigation/mutation locks.
- Verify the central dense field decoration and 14/24 tokens in My Seed Colour/dark;
  visible/scaled labels, inline errors and disabled states;
  the Search-only decorative icon, no field-level submit buttons or field-associated
  tooltips, and retained accessible names. Search journeys must preserve record
  identity/details/drafts through live filtering, Enter, clearing and focus/select-all
  shortcuts, including exclusion from results, and enforce pending Save/Delete guards.
  Compare actual hovered field rendering with selected Data, verify pointer exit,
  focused hover, disabled/error priority and draft-preserving rebuilds. Exercise
  persistent inline/floating Search labels and contextual shortcut exclusions.
- When visual parity is requested, retain local pinned reference and paired rendered
  evidence at matching viewport/theme/scale settings, plus attributed human Pass/Fail
  per surface/theme and material-difference dispositions. Unresolved differences or
  pending human review block visual-parity completion; tests/screenshots alone are
  not human acceptance. Do not require automated pixel identity or similarity scores.
- For shared dropdowns, verify actual box state propagation beside TextFields,
  content-sized stable widths, complete labels/values and one hover composite.
  Check the **2px expanded border while focus is in the menu**, matching-border
  tick colour and error/disabled priority in My Seed Colour/dark. Verify
  **12px menu typography**, **40px macOS / 48px iOS** row minima with scaled/wrapped
  growth, no row outlines or initial selected fill, background-only keyboard focus,
  full-width hover through rounded edges and scrolling to the last option.
  Exercise real callers' stable IDs, draft/save/validation/lock boundaries, consumed
  outside gestures and matched Escape/Ctrl+C/back without cancellation cascades.
  Cover supported Apple constraints/scales/safe areas/keyboard insets and overlay
  cleanup on resize/route removal. Distinguish widget configurations, native renders,
  native input and attributed human visual acceptance.
- For the local dropdown variants, verify labelled-field and icon-only triggers
  with both label-only and icon-plus-label menus. Check circular icon-action states,
  expanded outline while focus is in the menu, accessible action/value/expanded
  semantics, desktop tooltip and one 48 × 48 target without extra focus stops.
  Keep labelled-field tooltip exclusions intact. Check decorative leading-icon
  alignment/width/disabled roles without losing complete labels, the trailing check
  or shared menu metrics, hover/press/focus, navigation and dismissal behaviour.

Use the app's documented verification commands, static analysis, focused tests during work, and the required full suite before completing implementation. Add supported-profile/platform verification when the affected Spec calls for it; this standard does not add iOS builds to Desktop wide.

## 10. Audited evidence and alignment follow-ups

The 2026-10-13 publication audit reviewed the starter scaffold/earlier starter Spec and Peak Bagger's glossary, ACT docs, old coding rules, theme including `DataGridTheme`, size/constants systems, actual popup/dialog callers, keyboard helper, Admin Route table/details flow, provider/service ownership, formatters, and relevant unit/widget/robot tests. The rules above are self-contained. Source filenames below are historical **optional authoring evidence**, not required local files or external read dependencies in copied apps.

| Evidence | Finding and follow-up |
| --- | --- |
| Starter `lib/main.dart`, `pubspec.yaml`, and planned starter Spec 0001 | Counter scaffold lacks mandatory ObjectBox/Riverpod/GoRouter foundation, planned Settings/navigation, shared components/formatters, and ObjectBox Admin. Implement and verify separately, preserving the earlier Spec's exact starter contracts. Its package/deployment values and Home/Settings shell are local, not universal pins/routes. |
| Peak Bagger old `ai_specs/coding-rules.md` | Incorrect iOS/compact scope, absolute source read dependency, empty component sections, blanket constants ownership, and hard-coded red guidance conflict with this revision. Adopt the local standard/profile separately; Peak Bagger remains Desktop wide only. |
| `lib/theme.dart`, `lib/core/constants.dart`, `lib/core/app_sizes.dart` | Seed/vibrant/0.0 and FilledButton pairing are confirmed in both themes. Popup radius/padding are shared, but ratio sizing, scattered metrics, fixed hover colours, and dark/light icon differences need deliberate alignment. Historical Catppuccin descriptions are superseded; domain map/chart colours stay local. |
| `lib/widgets/peak_list_import_dialog.dart`, `lib/widgets/dialog_helpers.dart`, and Peak Lists caller | Live modal input/validation/FilledButton footer/pending example. Other helper footers mix TextButton/OutlinedButton. Import duplicate-name checking precedes pending protection; caller leaves default barrier dismissal enabled; its catch path dismisses the form before showing an error. Audit locking, duplicate prevention, diagnostics, and recoverable input retention rather than copy them as compliant defaults. |
| `lib/core/widgets/popup_shell.dart`, `lib/screens/map_screen_panels.dart`, main-map and mini-map callers | Peak Info is live with scrollable body, edit/read states and wrapping Cancel/Save footer; local controllers are disposed. Main-map caller supplies save; mini-map has different capabilities. Fixed dimensions/local typography and dismissal while editing need feature/profile review. Modal focus containment/restoration is a target to verify, not proven by a popup shell. |
| `lib/core/widgets/popup_keyboard_dismiss.dart` and popup tests | Escape and Ctrl+C are implemented and tested in the shell. The helper itself does not encode unsaved-change or editable-text policy; verify all permitted dismissal/operation-lock paths in affected flows. |
| `lib/screens/objectbox_admin_screen.dart`, table/details files, `DataGridTheme` | Route rows have trailing Delete; selection opens labelled details with Edit/Close. Row styling is central but keyboard focus is explicitly transparent, Delete is hard-coded red, Route editor has Save without the target Cancel footer, and long fields use `SelectableText(maxLines: 5)`. Align these gaps and verify the five-line scrolling target; do not infer universal entity coverage. |
| Startup, providers, repositories/services | Startup opens a store and injects several repositories; notifiers own observable screen state; repositories demonstrate transaction boundaries and testable storage. Globals/direct UI database access and a repository provider's silent in-memory fallback remain gaps to review. Startup failure closes its partial store, but normal lifecycle ownership/disposal needs explicit alignment. |
| `lib/providers/theme_provider.dart` and preference tests | Preference loader/bootstrap overrides are useful seams. Current mode load errors are silent and save errors retain the new in-memory mode; Settings uses a binary toggle. These do not satisfy the starter's planned three-value, SnackBar, and rollback contract. |
| Date/number helpers and tests | Shared formatting, date-range and null/precision behaviour are evidenced. Audit calendar-only versus local timestamp handling; keep units, Track text, and GPX precision in domain rules. |
| Admin repository/provider/widget/robot tests | Fakes, in-memory storage, provider overrides, and temporary-store patterns are evidenced. Existing tests/examples are not proof of new Cancel, keyboard-focus, or five-line-scroll acceptance; add affected deterministic coverage when implementing. |

Record app-specific follow-ups and observed values in each local profile during adoption. There are no universal dimensions/breakpoints; the starter's approved values are now resolved in its profile. Full exception governance remains open. The audit table above is historical evidence from 2026-10-13, not a statement of current starter implementation.

## 11. Amendment history — 2026-10-17

The user requested updating ADS-1.0 with today's committed refinements and the
subsequent row/button/banner corrections. This amendment adopts the shared rules
above; exact starter content remains in the profile and Spec 0004. It supersedes
the original publication's conflicting Admin semantic-trash/density wording and
the earlier local exception classification for these now-adopted roles. It does
not settle deferred L10 governance or change the mandatory foundations.

| Source | Adopted change / current contract |
| --- | --- |
| `1472dc9` — theme customisation | Four Settings sections; effective/committed seed, variant and contrast; automatic persistence, contrast completion boundary, independent fallback/rollback and session feedback (§2). Exact 12 colours, nine visible variant choices, −1…+1 / 0.1 steps and keys are profile/Spec contracts. |
| `30b803a` — searchable entity browser | Entity/Schema/Data, actual schema, explicit full-display-value Search, deterministic sorting, lazy rows, aligned scrolling and reachable trailing Delete (§8). |
| `2eefb87` — embedded details and guards | Adaptive in-route panes, single draft, post-Save identity, panel-scoped shortcuts, Delete draft/target rules, pending guards and short-height reachable feedback (§§3/7/8). |
| `582b629` — navigation and integrated review | Starter 70-pixel rail / 10-pixel regular labels / 8-pixel margins, no top-app-bar back buttons, compact Drawer and preserved real back behaviour (profile/Spec); central mode tint and independent human visual gate (§§4/9). Schema/Data selected tint is primary at 0.12 with primary foreground; mode controls retain their own shape. |
| `6e679c1` — grid/details styling | Central grid metrics, onSurface text, local onPrimary dividers, red unbacked table trash, transparent header actions and deliberate panel focus (§§5/8). |
| Subsequent user corrections, 2026-10-17 | Dark selection shades the chosen seed; hover blends selected fill with 10% white; Delete/Edit/Close and future icon actions share circular interaction backgrounds; hide DEBUG ribbons in all app-root states (§§4/5/8). |

Historical interview ledgers, publication criteria and dated test counts are
provenance, not rewritten decisions or proof of present runtime compliance.
The starter records amendment adoption in [its profile](ai_specs/app-profile.md).
Existing rendered captures predate the latest corrections; human visual re-review
remains pending in [the acceptance record](ai_specs/0004-peak-bagger-ui-parity/visual-acceptance.md).

## 12. Amendment history — 2026-10-19

The user requested adding the final text-field and Search interview decisions to
these reusable coding rules. [Spec 0005](ai_specs/0005-text-field-theme-and-live-search/spec.md)
and its [Interview Ledger](ai_specs/0005-text-field-theme-and-live-search/interview-ledger.md)
record the exact contracts and this publication request. Retain ADS-1.0 and record
**2026-10-19** as the current amendment date. This amendment supersedes §5's former
optional field-theming default and blanket desktop-tooltip wording only within the
field scope, and §8/§9's explicit-submit/search-discards-details rules.

- Central dense outlined decoration: 14-pixel onSurface labels, onPrimary default
  border and effective-seed enabled/focused borders, with 2-pixel focused width.
- No text-field-associated tooltips or individual submit buttons. Only Search has
  a decorative leading magnifying glass, using the central 24-pixel icon token.
- Immediate local filtering on typing/clearing and Enter search; preserve selected
  record/details/draft even outside results, and guard every search path during
  pending Save/Delete. Entity/mode/sort and other operation policies remain distinct.

These are adopted shared rules, not app-local exceptions. Deferred L10 governance,
mandatory foundations and platform/layout declarations are unaffected. Publication
does not implement or verify runtime compliance; the starter tracks that work in
Spec 0005 and its profile, while earlier dated runtime evidence remains historical.

### Field hover and Search shortcut delivery — 2026-10-19

[Spec 0006](ai_specs/0006-text-field-hover-and-search-shortcut/spec.md), ledger
[L1–L4](ai_specs/0006-text-field-hover-and-search-shortcut/interview-ledger.md),
deliberately revises the preceding amendment's seed-coloured enabled/unfocused
outline and always-floating Search target. **Reason:** user-requested neutral idle
appearance, selected-Data-matched hover and persistent shortcut discoverability.
**Scope:** all shared text fields' idle outline/hover; only Search's label/shortcut.
**Product approval:** explicit L1/L2/L4 styling/label agreements and L3 shortcut
agreement. This publication aligns the current §5/§8/§9 clauses above; exact
**Search ⌘F**, Apple hardware-keyboard binding and compact-pane exclusion remain in
the app profile. Default/focus/error borders, ordinary labels and live filtering/
draft policies are preserved. Earlier Specs, ledgers and dated captures retain
their historical scope. This is no general exception-process approval; L10 remains
provisional. Runtime verification is recorded separately in the
[delivery evidence](docs/field-hover-search-shortcut-verification.md).

## 13. Dropdown delivery supplement — 2026-10-20

[Spec 0007](ai_specs/0007-shared-dropdown-styling/spec.md), current ledger **L1–L4**
and its **two approved refinement resolutions** extend the preceding decoration-only
dropdown applicability to shared TextField-matched boxes and separately styled
adaptive menus. **Reason/scope:** the user's shared appearance request for all
current/future dropdowns. **Approval:** L1's box agreement, L2's menu agreement, L3's
width/wrapping agreement, plus approved consumed-outside-gesture and exact
Escape/Ctrl+C equivalence. This is shared-contract adoption, not an exception or
an amendment to unrelated panel shortcut behavior. Preserve ADS-1.0 and the
2026-10-19 amendment history, mandatory foundations and provisional L10 governance.

The subsequent human **Fail** and L4 explicitly revise content-sized boxes,
expanded seed borders/matching ticks, 12px text, no row outlines and full-width
hover; its **40px macOS menu-row** minimum is the narrowly approved target
exception recorded in §5. Revised dropdown re-review **passed**, User 2026-10-20;
this grants no general exception authority or unrelated input-policy change.

The accepted rules are consolidated directly in §5, with the target exception
cross-referenced from §4 and observable checks in §9. The user explicitly passed
the Entity, Collection and Seeded Scheme Variant **boxes and menus in light and
dark**, including revised custom-theme/compact examples. The
[12 attributed human Pass rows](ai_specs/0007-shared-dropdown-styling/rendered-evidence/revised/README.md#human-visual-acceptance-inventory)
and original rejected evidence remain local. This acceptance is scoped to Spec 0007;
Spec 0004's human review and Spec 0006's native keyboard limitation remain separate.

The [integrated delivery record](docs/shared-dropdown-verification.md#integrated-verification--spec-0007-item-04)
separates implemented/automated/native-rendered evidence from human acceptance.
Publication alone proves no visual Pass; the original user image and current
per-box/menu review are retained locally with provenance.

## 14. Local dropdown presentation supplement — 2026-10-21

During refinement of [Peak Bagger Spec 0069](peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md#refinement-decisions--2026-10-21),
the user requested icon-only dropdown triggers while retaining shared menu styling,
with a choice of icon-plus-label or label-only rows, and confirmed these are
**caller-selected configurations**, not user-facing Settings preferences.

**Reason:** retain compact icon-based selectors such as Time's Chart type while
sharing the same reusable menu. **Scope:** trigger variants, optional leading menu
icons, their accessibility/state/tooltip rules and verification in §§5/9. This
supersedes mandatory labelled boxes for every selector and the blanket no-leading-
option-icons rule only for the explicitly configured variants. Labelled fields
retain their visible labels, TextField styling and tooltip exclusions; menu metrics,
selection feedback, input/ownership and dismissal rules remain shared.

**Approval status:** the product change and local Spec/coding-rules publication were
confirmed by the user in the one-by-one refinement discussion, 2026-10-21. This is
an explicit local contract extension, not an assertion of upstream publication,
starter acceptance or general exception authority. ADS-1.0, amendment 2026-10-19,
the 2026-10-20 delivery provenance, mandatory foundations and provisional L10
governance remain unchanged. Peak Bagger caller choices and the inherited Time
layout gate remain in Spec 0069; publication implements/verifies no runtime work.
