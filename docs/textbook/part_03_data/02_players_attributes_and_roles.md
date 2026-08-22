# 02 — Players, Attributes, and Roles

Status: **VERIFIED**

`VolleyballPlayer` is one of the central data models in VWM. It stores who the player is, what their body can do, what skills they have, how they tend to decide, and their current career/match state.

The most important rule is:

> **Not every player number is “ability.”**

The model deliberately separates capability from temperament, external standing, temporary state, and physical measurements.

## Ability attributes

`VolleyballPlayer.ABILITY_ATTRIBUTES` is the explicit list of ratings treated as capability inputs.

It includes physical, technical, and mental/tactical skills such as:

- acceleration / lateral / transition speed;
- jump capacity and explosiveness;
- reception, setting, attacking and blocking skills;
- court vision, anticipation, decision making and composure.

Systems such as `AttributeProfileSystem` can build category/overall summaries from this list without accidentally treating every field as “better when higher.”

## Temperament is not ability

Fields such as `ego` and `aggression` are deliberately *outside* `ABILITY_ATTRIBUTES`.

That matters semantically.

High aggression does not mean “better volleyball player.” It means the player is more inclined toward terminal/risky action. High ego is about how strongly a decision is held, not how much skill the player possesses.

So a future decision might conceptually use:

```text
ability
→ can/how well

temperament
→ which option / willingness / persistence
```

If temperament were included in an overall ability score, a more extreme preference would incorrectly look like more skill.

## Leadership is relational

`leadership` is also excluded from the ability list because its important effects are on the *team around the player*, not on the player's own contact quality.

This is a useful modeling pattern:

> place a variable in the score it actually represents, not the score where it is convenient to display.

## State is temporary

Fields such as:

- `fatigue`;
- `current_form`;
- `match_confidence`;
- `availability`;
- `satisfaction`;

are not permanent skill ceilings.

They answer “what condition is this player in now?”

That lets the same underlying player perform differently without rewriting their learned attributes.

## Reputation is external standing

`reputation` is explicitly not ability. It represents how the world values/talks about a player.

This distinction is crucial in a management game because scouting, market value and selection pressure can depend on reputation even when physical/technical capability does not.

## Physical measurements are facts about the body

`height_cm`, `mass_kg`, `wingspan_cm` and `stride_length_m` are measurements/traits, not 1–100 skill ratings.

Derived geometry can then combine them with skill/capacity attributes.

For example, jump touch/reach should be derived from body dimensions plus jumping capacity rather than stored as a second unrelated “reach” number.

## Roles are weighted interpretations

`POSITION_WEIGHTS` defines which ability attributes matter most for each volleyball role.

Examples:

```text
Setter
→ setting skills + vision/decision

Libero
→ reception/dig/anticipation/movement

Middle
→ block/jump/lateral/attack timing
```

A role score is therefore a **view over the same player**, not a separate character class.

That permits a player to have one underlying attribute set while being more or less suited to multiple roles.

## Position familiarity is separate again

The model also stores:

- `primary_position`;
- `natural_positions`;
- `position_familiarity`;
- `position_training_target`.

This lets the game distinguish:

```text
raw capability for a role
≠ familiarity with actually performing that role
```

A technically gifted player may project well somewhere they have not yet learned to play consistently.

## Serve style is capability + learned profile

The player carries a `primary_serve_style` and style proficiencies. This is another example of not collapsing everything into one serve number.

Different attributes can support different serve outcomes/styles, while the style field describes the action family the player tends to use.

## `get()` and `set()` for generic attribute systems

Training/generation systems often operate on attribute names stored as Strings:

```gdscript
var current := int(player.get(attribute_name))
player.set(attribute_name, current + 1)
```

This is dynamic property access.

It is useful when the same algorithm needs to work across many ratings, but it means a bad attribute name becomes a runtime problem rather than a compile-time one.

That is why VWM keeps centralized lists and guards the value type before training it.

## Scouting knowledge versus underlying truth

The player Resource stores actual ratings/ceilings. A scouting system may expose estimates/ranges based on `weeks_observed`, scout quality and other information.

Do not “hide” potential by changing the true stored ceiling. Hide it in the **information layer** presented to the manager.

This distinction is analogous to rally perception:

```text
world truth exists
→ observer gets imperfect knowledge
```

rather than changing truth to match what the observer knows.

## Ability consumers should be traceable

When asking “does attribute X matter?”, search the actual simulation systems.

The training system even publishes an `UNSIMULATED_ATTRIBUTES` list for ratings that can currently improve but do not yet affect official rally behavior. This is preferable to pretending every visible rating already has a live effect.

## Safe extension: adding a new rating

Adding `new_skill` is not finished when you add:

```gdscript
@export_range(1, 100) var new_skill: int = 50
```

You must decide:

1. Is it ability, temperament, state, reputation, or measurement?
2. Does it belong in `ABILITY_ATTRIBUTES`?
3. Which profile/category owns it?
4. How is it generated?
5. Can training change it?
6. What live system consumes it?
7. How is it saved/loaded?
8. How is it scouted/displayed?
9. What test proves its consequence?

Otherwise you have created a number, not a mechanic.

## Reading exercise

Choose `ego`, `aggression`, `leadership`, and `reception_stability`.

For each:

- classify it;
- search all consumers;
- explain why it is or is not in `ABILITY_ATTRIBUTES`;
- identify one UI/report that should display it differently from a raw ability score.

## Source trail

- `scripts/models/volleyball_player.gd`
- `scripts/systems/attribute_profile_system.gd`
- `scripts/systems/familiarity_system.gd`
- `scripts/systems/training_system.gd`
- `docs/textbook/PLAYER_ATTRIBUTES_LEDGER.md`
- `docs/textbook/GRANULAR_ATTRIBUTE_BREAKDOWN.md`

Next: body types and the geometric measurements that turn those player facts into physical reach/movement.