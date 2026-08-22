# 04 — Generation, Potential, and Development

Status: **VERIFIED**

Player generation is designed around a useful principle:

> **generate the player first; derive role/value views from the player rather than generating a role-shaped score and decorating it afterward.**

That is what “attribute-first generation” means in VWM.

## Generator structure

`VolleyballPlayerGenerator` knows about:

- role/position slots;
- role-primary and secondary attributes;
- regional specialty biases;
- regional physique biases;
- individual variation;
- potential/attribute ceilings;
- world/influence overlays.

It produces `VolleyballPlayer` Resources that then move through scouting, training, rosters and rally simulation like any other player.

## One role vocabulary

The generator deliberately reads `VolleyballPlayer.POSITION_WEIGHTS` for primary role attributes instead of maintaining an independent second definition of what makes a Setter, Libero, etc.

This avoids:

```text
generator says Setter = A/B/C
ability score says Setter = A/D/E
```

Two copies of semantic configuration eventually diverge.

## Potential is a ceiling, not current ability

Players carry:

```gdscript
potential: int
attribute_ceilings: Dictionary
```

The scalar potential is a summary; the per-attribute ceilings preserve the actual developmental shape.

A player can therefore have the same broad potential as another player while having different ceilings by skill.

This is important for scouting and training: development is not required to raise every attribute uniformly.

## Current expression versus reserve

The generation architecture separates what the player **could become** from how much of it they currently express.

Age/growth reserve and role/regional shaping influence the generated current attributes under the ceiling rather than redefining the ceiling as “older = more talented.”

That supports the management fantasy that a young prospect may be valuable because of hidden/upside capacity while a veteran may be valuable because much of their capacity is already expressed.

## Regional bias is authored world design

`REGION_SPECIALTY`, `REGION_HEIGHT_BIAS`, `REGION_MASS_BIAS`, and `REGION_WINGSPAN_BIAS` are game-world abstractions.

They are **not claims about real human populations**. They encode fictional volleyball traditions and roster variety.

For example, a region may be biased toward serving skills, tactical attributes, blocking/control, sustained transition effort, or terminal attacking technique.

When reading these constants, treat the comments as design authority: many values were chosen to keep regional identities distinct rather than to model biology.

## Major versus minor traditions

The generator supports broad and narrow regional specialties. Minor-region traditions can intentionally be smaller/deeper attribute sets.

That creates different scouting stories without requiring a separate player class per region.

All regions still produce players from the same underlying model.

## World overlays

Generation can receive a regional overlay representing current Sixnet influence drift.

The overlay is additive to the region's static identity rather than replacing it.

Conceptually:

```text
base regional tradition
+ current world/competition influence
+ role
+ individual variation
→ generated player
```

An empty overlay preserves the baseline generator behavior.

## Training uses fractional progress

`VolleyballTrainingSystem` no longer treats a week as “+1 or nothing.”

Each player stores fractional `training_progress` per attribute. A training week adds progress, and whole attribute points are gained only when the accumulated fraction crosses 1.0.

This gives the model a vocabulary for slow development.

```gdscript
var carried := float(player.training_progress.get(attribute_name, 0.0)) + step
while carried >= 1.0 and current < ceiling:
    current += 1
    carried -= 1.0
```

**GDScript reminder:** the `while` loop here handles the general case where one application could cross more than one whole point, while the ceiling prevents over-development.

## Training respects individual ceilings

For a trained attribute, the system uses the player's specific attribute ceiling when present and falls back to scalar potential for older/hand-authored data.

It also never lowers the ceiling below the player's current value.

That makes save compatibility possible without pretending legacy fixtures have per-attribute ceiling data they never stored.

## Activity is not the same as focus

Training has multiple layers:

```text
activity
→ broad session type and candidate attributes

regimen/squad
→ who is training together

focus
→ how the development budget is targeted

schedule blocks
→ whether the day can afford the session
```

This is why training cannot be understood as one `training_focus` String anymore, even though that legacy field remains as a default/migration seam.

## The day is a budget

Activities consume different numbers of schedule blocks. `DailyScheduleSystem` determines what the configured day can actually support.

A regimen that the day cannot afford is reported as unaffordable rather than silently disappearing.

This connects diegetic scheduling to actual development opportunity.

## Some visible attributes are not yet simulated

`VolleyballTrainingSystem.UNSIMULATED_ATTRIBUTES` explicitly records ratings that can exist/train but are not currently read by official rally behavior.

This is an important honesty mechanism.

Do not add a meaningless 0.01 coefficient somewhere simply to make the list empty. A new attribute should get a mechanism when the simulation has a real decision/physical place for it.

## Development projects

The broader design direction treats development as:

```text
Tactical Need
+ Latent Potential
+ Opportunity
→ development project
```

rather than an instant position-switch button.

The existing data model already supports pieces of that idea through:

- per-attribute ceilings;
- position familiarity/training targets;
- training regimens;
- tactical attributes;
- opportunity/selection context.

Not every higher-level development-project UI/system described in design docs is necessarily complete. Keep current runtime behavior separate from product direction.

## Safe change: modifying generation

Generation changes have wide consequences. Before editing:

1. identify whether the change is role, region, global distribution, or world overlay;
2. keep ceiling/current-ability semantics separate;
3. ensure the same attribute isn't independently defined in multiple tables;
4. regenerate deterministic populations with fixed seeds;
5. compare distributions, not one memorable player;
6. verify affected role scores;
7. check save fixtures/hand-authored players still have sensible fallbacks.

## Reading exercise

Pick one region and one role.

Trace:

```text
regional specialty
+ role primary/secondary attributes
+ physique bias
→ generated VolleyballPlayer
→ POSITION_WEIGHTS role score
→ training ceiling/progress
```

Identify which pieces are authored world design versus emergent individual variation.

## Source trail

- `scripts/systems/player_generator.gd`
- `scripts/models/volleyball_player.gd`
- `scripts/systems/attribute_profile_system.gd`
- `scripts/systems/training_system.gd`
- `scripts/systems/training_focus_model.gd`
- `scripts/systems/daily_schedule_system.gd`
- `docs/design/ATTRIBUTE_FIRST_GENERATION.md`
- `docs/design/DEVELOPMENT_PROJECTS.md`

Next: regions and clubs—how a world-level identity reaches generation, tactics and management without becoming one giant modifier.