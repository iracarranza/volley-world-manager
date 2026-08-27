# Modularity and efficiency refactor

This pass targets both repeated runtime work and the cost of adding new content.

## New ownership boundaries

- `AttributeRegistry` owns the canonical ability/trait vocabulary and metadata.
- `RoleProfiles` owns role scoring/development profile data.
- `RegionProfiles` owns regional player-generation/development profile data.
- `BodyTypeGameplay` owns body gameplay modifiers; `BodyTypeModels` remains presentation-only.
- `PlayerGenerator` composes those definitions rather than authoring them.
- `VerticalSliceRoster` owns hand-authored fixture player data outside `GameManager`.
- `SetterDecisionMath` is the first pure setter-decision extraction from `RallySimulator`.

## Growth rule

Prefer **definition + registration + consumer** over adding another branch to an unrelated procedural file. A new attribute should be registered once, then deliberately referenced by role/region/body/training/scouting/simulation consumers. `tools/validate_domain_registries.gd` catches dangling trait and body references.

Roles describe weighting and development, not blanket permissions. Situation-specific ability remains in capability systems (`SetterCapabilitySystem`, attack eligibility, etc.), so unusual players can participate without acquiring the wrong roster label.

## Runtime change

`CareerManager.advance_week()` resolves the club's served food once and reuses that immutable team/week result for recovery, palate progression and chef familiarity instead of reconstructing the same service for every player.

## Deliberately incremental

Rally formulas, RNG order, event schema and scoring are unchanged. Declarative visual catalogues are not split merely for being large. Full home/opponent resolver unification is a behavior migration, not a mechanical file-size change; it should proceed phase-by-phase behind symmetry tests rather than risking the authoritative rally model in this refactor.
