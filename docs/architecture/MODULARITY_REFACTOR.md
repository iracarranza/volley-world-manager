# Modularity and efficiency refactor

This pass separates two concerns: repeated runtime work, and the cost of adding new content.

## Ownership

- `AttributeRegistry`: canonical ability-attribute vocabulary and category metadata.
- `RoleProfiles`: role primary weights, approach modifiers and generation support attributes.
- `RegionProfiles`: regional generation/development biases.
- `BodyTypeGameplay`: body gameplay modifiers; `BodyTypeModels` stays presentation-only.
- `PlayerGenerator`: composition pipeline consuming those profiles. Compatibility aliases remain during migration.
- `VerticalSliceRoster`: hand-authored fixture player data, outside `GameManager`.
- `SetterDecisionMath`: first pure setter-decision extraction from `RallySimulator`, behind compatibility wrappers.

## Growth rule

Prefer **definition + registration + consumer** over adding another branch to a procedural file. New attributes should be registered once, then deliberately referenced by roles/regions/bodies/training/scouting/simulation. `tools/validate_domain_registries.gd` catches dangling attribute and body references.

## Runtime change

`CareerManager.advance_week()` resolves the team's served food once per week and reuses it for recovery, palate progression and chef familiarity instead of reconstructing the same service for every player.

## Deliberately unchanged

Rally formulas, RNG order, event schema and scoring are not redesigned. Declarative visual catalogues are not split merely for being large. Home/opponent resolver consolidation remains a behavior-level migration requiring phase-specific symmetry tests; it is not safe as a mechanical size refactor.
