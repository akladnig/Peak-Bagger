# App Development Standard

**Standard revision:** ADS-1.0 — 2026-10-13

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
3. Record the adopted revision, adoption status, unresolved values, observed runtime configuration, and alignment follow-ups in the profile. Separate documented targets from implemented/verified behaviour.
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

### Preferences and the planned starter Settings contract

Use shared preferences for small settings, separate from ObjectBox domain records. Make preference loading/saving dependencies replaceable and errors observable.

The starter's **planned**, separately specified theme-mode Settings behaviour is exact:

- Supported values: `system`, `light`, `dark`; default: `system`.
- Startup loading failure leaves system mode and shows a visible in-app **SnackBar**.
- Saving failure restores the prior mode and shows a visible in-app **SnackBar**.
- Persistence works across restarts without a network/external-service dependency.

The existing scaffold does not implement this contract. A binary toggle and silently retained failed save in source examples do not fulfil it. Starter Home/Settings routes, labels, menu/back behaviour, and compact iOS Drawer details belong in its local profile and implementation Spec, not in every app's navigation.

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

This supersedes historical Catppuccin descriptions. Match semantic component roles across light/dark themes and verify readable foreground/background pairs in both. Use theme-derived surfaces, outlines, foregrounds, and error colours; an incidental widget-local override or historical dark-mode quirk is not authoritative.

Centrally theme controls and their selected, hovered, focused, pressed, and disabled states. Keep selection distinct from hover and make keyboard focus visible even on selected rows. Disabled controls must look unavailable. Use the theme's semantic foreground for its actual surface, including `onSurface`, `onPrimaryContainer`, and `error` as appropriate; do not copy a blanket icon colour onto incompatible backgrounds.

An app may declare a different seed colour in its profile while keeping typography, spacing, component styling, and interactions shared. Mapping colours and domain chart-series palettes are domain styling. Every app need not expose seed/scheme/contrast pickers.

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

### Density, sizing, and accessibility

- Desktop rows/toolbars are compact while retaining clear hover, keyboard focus, selection, and pointer affordances.
- In profiles including touch layouts, interaction targets are at least **`48 × 48` logical pixels**, even if glyphs are smaller. Do not impose this as new iOS/touch support for Desktop wide.
- Respect text scaling, semantics, accessible labels, and logical focus traversal. Do not reduce text scale merely to make a layout fit.
- Essential labels, values, and actions wrap or scroll rather than clip. Account for available height and the on-screen keyboard as well as width; a wide but short viewport can still need scrolling.
- Size surfaces against their actual constraints. Keep primary and dismissal controls reachable at supported sizes; a hard-coded source popup size is not a universal dimension.

## 5. Components and actions

The footer, cursor, labelled-field/validation/input-retention, FAB, icon/text, and popup/dialog focus/dismissal requirements below are the **L17-approved component baseline**, together with L8/L9/L15 visual/action decisions. The additionally labelled recommendations are author-selected supporting defaults, not further interview-approved product decisions. Feature Specs must settle save/cancel/retry, persistence, validation timing, invalid-submission behaviour, outside-click dismissal, unsaved-change handling, and operation locking.

### Buttons and action order

- Popup/dialog **labelled footer primary actions and Cancel/Close use `FilledButton`**. Shared FilledButtons use `colorScheme.primaryContainer` backgrounds and `colorScheme.onPrimaryContainer` foregrounds in **both light and dark themes**, with centrally themed, theme-derived interaction states and shapes.
- **Cancel** abandons an editable operation; **Close** dismisses read-only content. Cancellation/secondary actions precede the primary action; the primary action is last. Align footers right where space permits and wrap/reflow actions so they remain accessible in supported layouts.
- Accessible header Close `IconButton`s are permitted. Do not reinstate the superseded TextButton-cancel proposal. Unrelated links, toolbar controls, and selection toggles need not become FilledButtons.
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

**Additional author-selected default:** use theme-owned input decoration and sensible focus/error placement rather than repeating border/text styling in every screen. This does not prescribe when a particular feature validates or persists.

### FABs and icon/text actions

Reserve FABs for a prominent primary action in the current context. Provide an accessible label, and place the FAB so content and other controls remain reachable. An unfamiliar or ambiguous action uses icon-plus-text. Icon-only actions have accessible labels and desktop tooltips. Do not infer domain-only Route/Trail controls or unbundled SVG dependencies from source UI.

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

Use semantic foreground colours for the actual surface and theme error colours for destructive actions, not hard-coded red. Supply accessible tooltips/labels. Additional domain icons/assets belong to the app and must be bundled or otherwise declared there.

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
- Centrally theme row/header typography, padding, column gaps, dividers, and **hovered, pressed, selected, and keyboard-focused** states. Selection and keyboard focus remain visibly distinguishable. Use shared tokens and semantic theme error colours for Delete.
- Selecting a row opens its details panel, with **Edit and Close** actions and labelled field values. Header icon actions are permitted if accessible; labelled popup/dialog footers obey section 5.
- Long field values remain **fully accessible and selectable** in **independently scrollable regions capped at five rendered text lines**. Short values use only their required height. Measure the cap using active text style, available wrapping width, and text scale; do not use an unscaled fixed pixel height. The viewport cap must not truncate either stored or displayed values. Users must be able to scroll/select content beyond the fifth line without scrolling only the overall details panel.
- The reference currently uses `SelectableText(maxLines: 5)` for certain Route long fields. That alone **does not prove a scrollable five-line viewport**, full-value access, or scaled-height correctness; explicitly implement and verify the target behaviour.
- Edit forms follow shared validation, **Save/Cancel**, pending, duplicate-prevention, input-retention, and recoverable-error rules.

The affected implementation Spec must settle entity-specific editable/read-only fields, relationship-aware deletion, confirmation/cancellation behaviour, navigation entry, and supported-profile layouts. Even subset coverage retains the required row/details controls for that declared set. Do not copy Route entities, map actions, source hard-coded red, or source fixed details-panel widths as universal requirements. Publishing this document does not build the screen.

## 9. Forward-looking verification

This section guides implementation work; documentation publication itself needs documentation review, not TDD, unit/widget tests, robot journeys, database setup, package upgrades, or platform builds.

- **Unit tests:** verify state/services/formatters through public behaviour, including meaningful failures and persistence boundaries.
- **Focused widget tests:** verify shared components and supported-layout states, including themes, focus/semantics, text scaling, constrained sizes, pending/error states, and dismissal policies where affected.
- **Robot journeys:** add them when a feature Spec requires journey coverage. Stable selectors and deterministic Test Seams are required when selected. There is no universal robot or TDD mandate; follow a feature's agreed TDD requirement when present.
- Prefer Riverpod overrides, preference fakes/mock initial values, temporary ObjectBox stores, and controlled database/network/platform/clock dependencies. Dispose containers/controllers/subscriptions; close stores and remove temporary data. Keep production services and user databases out of tests.
- Verify the exact planned starter Settings load/save failure contract with deterministic preference failures, not just a successful binary toggle.
- **ObjectBox Admin widget coverage:** deterministically verify row selection opening details; Edit/Save/Cancel outcomes and retention; delete outcomes specified for the declared entities, including relationships and confirmation/cancellation; and scrolling to/selecting content beyond the fifth line at supported text scales/layouts. Use temporary stores or repository/provider fakes and assert that the full long value remains available and short fields do not occupy five lines unnecessarily.

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

Record app-specific follow-ups and observed values in each local profile during adoption. Exact dimensions/breakpoints and full exception governance remain open as described above; this documentation release neither resolves them by guesswork nor claims runtime compliance.
