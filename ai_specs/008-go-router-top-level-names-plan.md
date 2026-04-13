## Overview

Name the top-level `go_router` destinations so the route table is self-describing, while leaving branch switching with `navigationShell.goBranch(...)` unchanged.

**Spec**: none; this is a minimal routing refactor plan.

## Context

- Current top-level branches are `dashboard`, `map`, `peaks`, and `settings`, but they are only identified by path today.
- The app already uses shell branch switching correctly for navigation, so that behavior should stay in place.
- The goal is route clarity and future-proofing, not a navigation model rewrite.

## Plan

### Phase 1: Name the top-level routes

- Update `lib/router.dart` to assign explicit `name:` values to the four branch routes.
- Use these names:
  - `dashboard`
  - `map`
  - `peaks`
  - `settings`
- Keep the existing paths unchanged:
  - `/`
  - `/map`
  - `/peaks`
  - `/settings`

### Phase 2: Keep shell navigation as-is

- Do not replace `navigationShell.goBranch(...)` calls.
- Do not convert the side menu or recovery action to `goNamed`.
- Keep the shell route structure and indexed-stack behavior unchanged.

### Phase 3: Optional follow-up cleanup

- If desired later, add small route-name constants in `lib/router.dart` so the names are not duplicated as raw strings.
- Only add direct named navigation where there is a concrete need outside shell switching.

## Verification

- Run `flutter analyze`.
- Run `flutter test`.

## Risks

- Named routes can become dead metadata if no call sites use them yet, but that is acceptable here because the branch navigation stays intact.
