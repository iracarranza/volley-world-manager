# 05 — Regions, Clubs, and Tactical Identity

Status: **VERIFIED AT SYSTEM BOUNDARY**

VWM's regions are not simple faction bonuses. They operate through several distinct channels:

```text
region/world data
→ player-generation tendencies
→ club starting resources/context
→ team principles / tactical identity
→ competition/world evolution
→ manager-facing information
```

Keeping those channels separate is important because “this region is strong” should not mean one hidden number multiplies every system.

## Region data is shared world vocabulary

`VolleyballRegions`/regional data modules provide canonical region names and facts used by career creation, generation, encyclopedia/UI and competition systems.

When a name is persisted, load paths should canonicalize it so spelling/name migrations do not fork the world into near-duplicate keys.

This is a common data-design problem: Strings that function as IDs need one canonical vocabulary.

## Generation identity

The player generator expresses regional development traditions through authored specialty and physique-bias tables.

These affect what kinds of players are *more likely* to emerge, not what every player must become.

That lets individual variation remain meaningful.

## Tactical identity belongs to teams

A club/team also carries principles/identity. At career creation, `CareerManager` constructs a `Team`, applies an identity or custom principles, and derives starting familiarity/cohesion/alignment from the region and principles.

So:

```text
region
≠ tactical plan
```

A club in a region can interpret or diverge from its local tradition while still existing in that world context.

This becomes especially important for manager agency.

## Familiarity is learned relationship to the plan

Team tactical familiarity and cohesion are stateful values that can move through training and career events.

They are not the same as the underlying tactic/principles.

```text
principle
→ what the team is trying to do

familiarity
→ how accustomed the team is to doing it
```

Changing a tactic can therefore create a short-term execution/coordination consequence without changing every player's permanent skill.

## Major/minor region context

Career creation distinguishes resource context such as major/minor regions and established/founded clubs.

Those differences can affect starting finances/reputation, facilities/housing context and world pressure without modifying the basic rules of volleyball.

This is a management-layer distinction, not a different simulation engine.

## Sixnet separates production strength from competitive form

`CareerState` stores fields such as:

- `region_strength`;
- `sixnet_form`;
- slots/standings/stages;
- champion;
- `region_overlay`.

The comments explicitly distinguish current population quality/production from competitive form.

That prevents a recent tournament result from rewriting the underlying talent pool as if those were the same thing.

## Influence drift feeds future generation

The Sixnet/world layer can create additive regional overlays that the generator consumes later.

This is a slow feedback loop:

```text
world competition / influence
→ region overlay
→ future generated cohorts
→ future clubs/players
```

The overlay is not required for ordinary baseline generation; empty means the static regional identity still works.

## Regional identity should be visible through mechanisms

A strong regional identity is more interesting when it appears through:

- roster composition;
- player attribute distributions;
- team principles;
- tactical decisions;
- development traditions;
- economic/world context;

rather than a direct hidden `REGION_WIN_BONUS`.

This matches the broader VWM architecture: manager-visible causes should generate the result.

## Club identity versus region identity

A club can have its own principles within a region.

The design docs on fixed regional philosophies and club tactical variance are useful here: the world needs recognizable traditions without making every team from a region identical.

When adding a new club-level modifier, ask whether it belongs to:

- region tradition;
- club principle;
- player attribute;
- current familiarity/cohesion;
- staff/management;
- temporary form.

Do not stack five copies of the same concept at different levels.

## UI responsibility

The encyclopedia/scouting/club screens should **explain** regional facts that already exist in data/system modules.

A screen should not carry a second handwritten description of a region's tactical specialty if the canonical region module already owns it.

That is why `Application` comments describe the encyclopedia as cheap to construct: it authors little and displays existing regional data.

## Safe extension: a new regional tradition

Before adding an attribute bonus:

1. state the fictional volleyball claim in words;
2. identify which existing attributes/mechanisms already express it;
3. check overlap with other regions;
4. avoid attributing a tactical tradition to body morphology unless that is explicitly the intended fictional design;
5. test generated distributions with fixed seeds;
6. verify the identity appears in manager-visible behavior/data, not only hidden numbers.

## Reading exercise

Pick one region from `VolleyballPlayerGenerator.REGION_SPECIALTY`.

Trace its identity through:

- generated attributes;
- physique bias if any;
- starting team/career context;
- encyclopedia/design text;
- any Sixnet overlay behavior.

Then write down which parts are static identity and which can evolve during a career.

## Source trail

- `scripts/data/regions.gd`
- `scripts/systems/player_generator.gd`
- `scripts/models/team.gd`
- `scripts/models/career_state.gd`
- `scripts/systems/sixnet_league.gd`
- `scripts/managers/career_manager.gd`
- `docs/design/REGIONAL_DIFFERENTIATION_SPEC.md`
- `docs/design/FIXED_REGIONAL_PHILOSOPHIES_AND_CLUB_TACTICAL_VARIANCE.md`
- `docs/design/REGIONAL_IDENTITY_OVER_A_MATCH.md`
- `docs/design/REGIONAL_STRENGTH_AND_MINOR_REGIONS.md`

Next: the CareerState/CareerManager boundary and how Godot data becomes a durable save.