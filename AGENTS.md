## ACT Workflow

ACT workflow storage for new Specs is configured in `.act/config.yaml`.

ACT workflow semantics, Workflow Storage selection, artifact vocabulary, and domain-doc guidance are defined in `.act/workflow.md`.

## App Development Standard

Before relevant Flutter ACT planning or implementation, read these **required project-local documents** in order:

1. [App Development Standard](ai_specs/coding-rules.md), including its revision and applicable shared rules.
2. [Peak Bagger app profile](ai_specs/app-profile.md), including Desktop wide obligations, app/domain contracts, and named `Pending` decisions.
3. The affected Spec, Interview Ledger, and Work Item, plus [GLOSSARY.md](GLOSSARY.md) and relevant project docs. Preserve the ACT workflow instructions above.

Peak Bagger selects **Desktop wide only**: macOS-only wide desktop layouts, maximised on launch. Compact/narrow navigation and iOS/touch-layout support are not required. Native macOS full-screen mode is a separate choice. The profile distinguishes documented targets from observed implementation; inspect actual code before claiming runtime compliance.

### Stage-specific instructions

- **`act-interview-flutter`:** read the standard and profile before relevant questions; identify applicable Desktop wide/domain obligations and pending minimum/window/feature decisions. Ask about decisions affecting the proposed work.
- **`act-create-spec-flutter`:** capture adopted revision ADS-1.0, selected profile, and exact applicable constraints and feature contracts, including labels, routes, failures, and verification. Carry named pending decisions forward; do not invent dimensions or dimension-dependent acceptance criteria.
- **`act-refine-spec-flutter`:** check conflicts among the standard, profile, Spec, historical docs, and actual implementation, proposed deviations, and unresolved decisions. Existing code is evidence, not approval. Gate only work dependent on an unresolved choice.
- **`act-create-issues-flutter`:** include project-root-relative `ai_specs/coding-rules.md` and `ai_specs/app-profile.md` in each relevant Work Item's `## Required context`, alongside its parent Spec. Carry applicable exact contracts into observable acceptance criteria and unresolved dependencies into blocking decisions.
- **`act-implement-flutter`:** read both documents, apply the shared rules and Desktop wide/app contracts, and verify affected behaviour using the Work Item/Spec's verification surface. Stop affected layout work until dependent pending values are resolved; unrelated work may proceed. Documentation publication uses documentation checks.

Report conflicts and record proposed exceptions with their rule, reason, scope, affected features, and approval status. The full L10 exception-governance proposal remains provisional/non-blocking; do not presume an approved exception process or silently replace mandatory ObjectBox, Riverpod, or GoRouter foundations. Missing compliance is an alignment gap, not an approved exception.

Source paths such as `lib/theme.dart`, popup/dialog helpers, providers/services, and tests are implementation evidence or examples, not required adoption documents. Use actual local equivalents for affected work; copying the standard creates no external source read dependency. Retain the single authoritative local copy at `ai_specs/coding-rules.md`.

The profile's [ACT matrix and paper walkthrough](ai_specs/app-profile.md#act-documentation-matrix) explain local adoption and pending-value gating through all five stages. Platform/layout choices belong in the profile; `.act/config.yaml` remains workflow storage configuration. `ai_specs/` is an ordinary directory in the Peak Bagger Git repository. Commit its documentation with the app; do not create or use a nested Git repository there.
