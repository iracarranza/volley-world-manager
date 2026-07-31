# Attribute-First Generation

Review date: 2026-07-31

Status: **SPECIFICATION; NOT IMPLEMENTED**

This is the definition for phase 2 of the change order in
[Locomotion and Generation](LOCOMOTION_AND_GENERATION.md). It is written down
before implementation because it moves every seeded fixture in the project and
because several of its semantics are not the obvious ones.

Prior art is `iracarranza/record-label-sim`, whose generator solves the same
problem for musicians. Where this specification departs from it, the departure
is noted and justified.

## Why the current generator forces role-first

```gdscript
var base := rng.randi_range(42, 62) if academy else rng.randi_range(52, 72)
for property_name in [~40 attributes]:
    var modifier := region.physical | region.mental | region.technical
    player.set(property_name, clampi(base + modifier + rng.randi_range(-8, 8), 20, 92))
```

Every attribute is one shared `base` plus a broad regional modifier plus eight
points of noise. There is **no budget, no conservation, and no specialization**.
A player is a flat line with a wobble.

That is the actual reason `apply_role_physical_defaults()` has to write the
body: with skills this uniform, physique is the only thing distinguishing one
player from another, so role has to supply it. Fix the skill distribution and
role can step back to a lean on its own.

## 1. Talent as a scattered budget

Adopted from record-label-sim, whose `_assign_stats(ca, pa)` scatters a total
budget across seventeen stats rather than rolling each independently. Shape is
emergent from allocation; total talent is a separate axis from the shape of it.

For volleyball the same idea applies to **skills only**. Physique is handled
separately -- see section 2.

- Roll a lifetime skill total for the player.
- Scatter the currently-developed portion across skill attributes, subject to
  per-attribute floors and ceilings.
- Specialization emerges because random allocation produces peaks and troughs,
  not because a role was chosen.

## 2. Physique is a second, separate stream

**This is the main departure from record-label-sim.** There, all seventeen stats
are skills drawn from one talent budget. Volleyball has height, mass, wingspan,
and stride, and a tall player did not spend points to be tall.

So generation runs two streams:

| Stream | Source | Budgeted? | Role input? |
|---|---|---|---|
| Physique | population distribution, region-aware | no | **never** |
| Skill | lifetime budget, scattered | yes | lean only |

Internal correlation inside the physique stream stays, because it is physically
real: height drives mass, wingspan, and stride. The rule for whether a
dependency is legitimate: **it must hold for someone who never played
volleyball.** Height to stride passes. Role to `reception_stability` fails --
that is a trained outcome, not a birth condition.

Deriving stride from real height here also dissolves the ordering bug recorded
in the locomotion document, where 75% of generated players carry a stride
computed from their role's base height rather than their own.

## 3. Role becomes a lean, not an author

record-label-sim's `_apply_role_and_genre_preferences` shifts **one point per
role attribute, two per genre attribute**, and `_shift_stat_points` takes those
points from the current highest donor so the total is conserved. Against a
budget of 85-300 that is under 2%.

Two properties are worth copying exactly:

1. **Budget-preserving.** Role redistributes, never adds. Role can never make a
   player better, only differently shaped.
2. **Small.** The player remains who the scatter made them, with a lean.

Roster legality needs no new mechanism. `POSITIONS` with
`index % POSITIONS.size()` already plays the part of
`BandArchetypes.get_lineup_template()`: it guarantees a fieldable rotation by
generating one player per slot. What changes is only that the slot supplies a
lean instead of a body.

Free-agent and transfer-market generation should pass no role at all, exactly as
record-label-sim generates unattached musicians -- those are the players whose
natural position is genuinely undiscovered.

## 4. Potential is a consumable growth reserve

**This is the second significant departure, and it is not the usual meaning.**

In record-label-sim, PA is a ceiling and CA is a fraction of it. Here potential
means *how many points remain available for growth*:

- Development **spends** potential and moves it into attributes.
- A veteran has largely consumed theirs; current ability is what it became.
- A young player may show a large current-to-potential gap simply because their
  skills are **undeveloped** -- this does not imply an exceptional ceiling. Gap
  measures undevelopment, not talent.

So roughly `lifetime_total ≈ current_total + remaining_potential`, with the
split shifting across a career rather than the ceiling being fixed and
approached.

Two constraints on spending:

- **Per-attribute ceilings.** Each attribute has its own cap; a player cannot
  pour a career into one number.
- **Diminishing returns on concentration.** Pushing a single attribute high
  costs progressively more, or costs heavily elsewhere. A young player with a
  large reserve cannot min-max without severe loss of breadth.

**Open decision, needed before implementation.** `potential` today is a scalar,
`rng.randi_range(74, 94)`, and `CareerManager.transfer_cost()` reads it as a
rating. The new semantics need *points*. Either:

- (a) keep the 0-100 scalar as a descriptor and derive a point reserve from it,
  preserving saves and transfer pricing unchanged; or
- (b) store remaining points directly and migrate saves plus `transfer_cost`.

(a) is cheaper and keeps `transfer_cost` meaningful without change. (b) is
honest about what the number now is. This choice is not made here.

## 5. Regions bias clusters, not three broad buckets

Regions already carry `physical`, `technical`, and `mental` weights applied as a
flat modifier. That is too coarse for the intended regional characters, and it
does not touch physique at all.

| Region | Intended character | Needs |
|---|---|---|
| Pāwa Hitō | players are generally **larger** | physique bias -- not currently possible |
| Spëddigh | faster lateral movement, balance, floor defense | a defensive-movement cluster |
| Bloc du Larg | strong at-net attributes | a net cluster (block, jump, attack at the net) |
| Landavol | all-round, strong mental and technical | broad small positive, mental/technical stronger |

So the region schema grows from three scalars to:

- a **physique bias** (height, mass, wingspan offsets), and
- **named attribute-cluster weights** rather than three category buckets.

The same discipline as role applies: a regional bias is a **lean, not a
determinant**. A Pāwa Hitō libero and a small Bloc du Larg middle must both
remain possible, or region becomes the new role -- an essence that writes a
body, which is the exact problem this whole change exists to remove.

## 6. What this does not include

Natural, assigned, and desired position are **phase 2b**, deliberately separate:

- `natural_position` derived from `POSITION_KEY_ATTRIBUTES`, which already
  exists as an archetype definition;
- `preferred_position` blended with personality, mirroring
  `SpecialtySystem.determine_preferred_specialty()`;
- a `preference_distance()` analogue for the friction between what a player
  wants and where they are played.

That work is mostly additive and probably does not move seeds. This document's
scope moves every seed on its own and should not carry more.

## 7. Expected blast radius

Generation feeds every fixture. Implementing this requires:

- re-selecting the Gate 42 and Gate 49 development-fixture seeds;
- re-baselining every calibration record in `docs/calibration/`;
- re-checking the reachability rates recorded across the gate history, which
  were measured against uniformly-generated players and will move once players
  genuinely specialize.

None of that is a regression. All of it must be expected rather than
discovered.
