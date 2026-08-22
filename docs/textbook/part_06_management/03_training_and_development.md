# 03 — Training and Development

Status: **VERIFIED CURRENT SYSTEM + PROPOSED HIGHER-LEVEL PROJECTS**

Training is the clearest existing bridge between a manager decision and a long-term change in player/team capability.

## Activity, regimen, focus, schedule

These are different concepts:

```text
Activity
→ what kind of work is being done

Regimen
→ which squad/player IDs do it

Focus
→ which attributes receive the development budget/how intensely

Daily schedule
→ whether enough training blocks exist to run it
```

Collapsing these into one dropdown would remove meaningful decisions the underlying systems already represent.

## Activities are data

`VolleyballTrainingSystem.ACTIVITIES` defines activities such as:

- Team Practice;
- Serving;
- Serve Receive;
- Attack & Transition;
- Blocking & Defense;
- Strength & Jump;
- Film Review;
- Team Meeting;
- Recovery.

Each entry describes block cost, candidate attributes, fatigue/satisfaction and team familiarity/cohesion effects.

A screen should read this vocabulary rather than maintain a second activity table.

## Training is limited by the day

Activities consume different numbers of schedule blocks. `DailyScheduleSystem` evaluates how much usable training time the configured day supplies.

`apply_week()` tracks remaining blocks and reports regimens that are unaffordable instead of silently running impossible sessions.

This makes the schedule mechanically meaningful.

## One player trains once per week

`apply_week()` tracks trained player IDs. Listing the same player on multiple squads does not create duplicate development.

This is a good example of a manager-data validation rule enforced in the system rather than trusted to the UI.

## Fractional progress

Development uses `player.training_progress` per attribute.

A week adds a fraction based on focus/receptiveness and selected attributes. Whole rating points are only gained once the fraction crosses 1.

That gives training a smooth internal clock while keeping displayed attributes as integers.

## Ceilings make development player-specific

A trained attribute stops at its per-attribute ceiling when available.

Legacy/fixture players without ceiling maps fall back to scalar potential.

This means training cannot turn every player into the same 100-rated template merely by repeating sessions.

## Training has costs and team effects

A regimen can change more than ratings:

- fatigue;
- satisfaction;
- team tactical familiarity;
- cohesion;
- position familiarity.

The same session can therefore be useful for different reasons.

A Recovery activity can restore physical state while slightly trading other gains; a Team Meeting can affect the room more than the legs.

## Recovery between weeks

`CareerManager` owns weekly fatigue recovery before/around training application. Its comments document a prior bug where recovery was too small even to overcome ordinary training cost, causing fatigue to compound and distort match attacks.

The fix was calibrated against the actual fixture/training cadence rather than chosen to restore an attack percentage directly.

That is management ↔ match debugging done correctly.

## Training cannot sell nonexistent match effects

`UNSIMULATED_ATTRIBUTES` identifies trainable/visible ratings that official rally simulation does not currently consume.

The UI should surface that honestly.

The desired fix is eventually a meaningful mechanism, not hiding the attribute or adding a token coefficient just so search finds its name.

## Position development

`position_training_target` and familiarity systems allow players to learn roles over time.

The design direction is not an instant “convert to Setter” operation. Raw capability, familiarity, training time and opportunity should all matter.

## Development projects — product direction

The larger design concept is:

```text
Tactical Need
+ Latent Potential
+ Opportunity
→ Development Project
```

Example:

> This outside has secondary setting ceilings, the team needs emergency distribution, and the manager gives them reps/training.

That higher-level project layer may be partially designed rather than fully live. It should orchestrate existing truths (ceilings, familiarity, training, selection), not invent a second development model.

## Safe extension: new training activity

A new activity requires more than a label:

1. add it to the canonical activity data;
2. choose block cost from the schedule model deliberately;
3. choose candidate attributes/team effects;
4. verify all attributes are numeric trainable properties;
5. confirm each claimed attribute has/doesn't have match consequence;
6. update UI descriptions/order where appropriate;
7. test fractional progress, ceiling and fatigue behavior;
8. ensure save data references stable activity names or has migration.

## Reading exercise

Follow `Serve Receive` training for one player:

```text
screen/regimen
→ TrainingSystem.ACTIVITIES
→ selected attributes
→ progress_per_attribute
→ player.training_progress
→ integer rating gain
→ later rally consumer
```

Pick one attribute with a live rally consumer and one listed as unsimulated. Explain the difference in downstream effect.

## Source trail

- `scripts/systems/training_system.gd`
- `scripts/systems/training_focus_model.gd`
- `scripts/systems/daily_schedule_system.gd`
- `scripts/systems/familiarity_system.gd`
- `scripts/managers/career_manager.gd`
- `scripts/models/training_regimen.gd`
- `docs/design/DEVELOPMENT_PROJECTS.md`

Next: the broader club-life systems that make the desk more than a menu for matches and training.