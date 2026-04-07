## Overview

Phase 1 already implemented. Verify all requirements met, run tests, ensure builds.

**Spec**: `ai_specs/001-prompt-spec.md`

## Context

- **Structure**: Layer-first (screens, widgets, providers)
- **State management**: Riverpod 3.x Notifier pattern
- **Reference implementations**: Existing code already follows spec
- **Assumptions**: Implementation complete, just needs verification

## Plan

### Phase 1: Verification

- **Goal**: Verify all spec requirements implemented

- [ ] Run `flutter analyze` - no errors
- [ ] Run `flutter test` - all pass
- [ ] Verify full-screen mode on macOS (manual)
- [ ] Verify window title "Peak Bagger" (manual)
- [ ] Verify 4 menu items in side menu (manual)
- [ ] Verify app icon at top of side menu (manual)
- [ ] Verify floating theme toggle in top-right (manual)
- [ ] Verify navigation between all 4 screens (manual)
- [ ] Verify theme toggle changes theme (manual)
- [ ] Verify theme persists across app restart (manual)

## Risks / Out of scope

- **Risks**: None - implementation complete
- **Out of scope**: iOS support, GPX import, map display (future phases)