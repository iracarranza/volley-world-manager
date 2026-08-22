# 05 — How Management Decisions Reach Match Behavior

Status: **VERIFIED ARCHITECTURE / INDIVIDUAL MECHANISMS VARY**

A management feature earns its place in VWM when its consequence can be traced into a fact the match engine honestly consumes.

The preferred chain is:

```text
manager decision
→ persistent player/team/club state
→ match setup / tactical state
→ perception, responsibility, feasibility, choice, or execution
→ rally consequence
→ visible event/result
```

This is different from giving a management button a hidden outcome bonus.

## The same player crosses the boundary

A recruited/trained `VolleyballPlayer` Resource is not converted into a separate “match player” with unrelated ratings. Match setup references the same underlying player data through lineup/team structures and creates transient `RallyPlayerState` wrappers for physical rally state.

That distinction matters:

```text
VolleyballPlayer
→ persistent identity + attributes + career state

RallyPlayerState
→ this rally's position, velocity, facing, body/intent/recovery state
```

Long-term development belongs to the first. Temporary physical state belongs to the second.

## Training → attributes → mechanisms

A Serve Receive regimen may improve `reception`, `reception_balance`, or `reception_stability` over time.

Those attributes can then enter reception/platform/responsibility systems when the player is selected.

The causal chain is:

```text
training choice
→ fractional progress
→ permanent rating gain
→ live system reads changed rating
→ different feasible/executed contacts over many rallies
```

The training system should not itself award “better receptions next match.”

## Tactical principles → decisions

Team principles are carried into rally decision systems.

For example, overpass action choice can read team decisiveness/transition commitment when comparing a physically feasible attack with control.

The tactic affects **what the player tries**, while the physical systems still decide what is possible.

This is the model M9 eventually needs to certify with controlled A/B comparisons.

## Familiarity/cohesion are relationship state

A team may know a tactic to different degrees. Training can move tactical familiarity/cohesion without changing the tactic itself.

When those values influence match behavior, they should do so through interpretable coordination/execution pathways—not as an unexplained global win multiplier.

## Fatigue is a cross-system state

Training, schedule, recovery and match participation can change fatigue.

The rally engine can then reduce usable physical/execution capability through the existing player-state/rating mechanisms.

A previous fatigue bug demonstrated why this connection is powerful and dangerous: insufficient weekly recovery compounded until attacks collapsed. The correct diagnosis began upstream in career cadence rather than by buffing attack outcomes.

## Selection is itself a management consequence

Even before ratings change, roster/lock-in choices affect the match because different players carry different:

- bodies;
- attributes;
- positions/familiarity;
- serve styles;
- tendencies;
- fatigue/confidence.

The manager does not need a separate “selection bonus.” Choosing a different athlete changes the inputs to the simulator.

## Scouting affects decisions, not player truth

Better scouting should alter what the manager knows and therefore which players they choose/sign/develop.

It should not make a prospect play better merely because the manager has a better report.

This produces an indirect but meaningful match consequence:

```text
better information
→ better/different management decision
→ different roster
→ different volleyball
```

## Operational systems should use existing seams when possible

Suppose housing/care improves satisfaction or availability. If those states already have meaningful career/match consequences, use them.

Do not create `housing_attack_bonus` just because the housing system needs a visible payoff.

If no existing state can honestly represent the effect, then the design may need a new explicit variable/mechanism—but that should be named and traced.

## Uns simulated attributes reveal broken chains

A management screen can offer training in an attribute whose official match engine does not yet consume it. `TrainingSystem.UNSIMULATED_ATTRIBUTES` makes those gaps visible.

That list is effectively a set of incomplete causal chains:

```text
manager can develop X
→ X persists
→ ??? no official rally consumer yet
```

Closing such a gap requires a meaningful volleyball mechanism, not a token read.

## How to prove a management-to-match feature

Use a controlled A/B where possible:

```text
same seed / roster / opponent / tactic
A: baseline state
B: one management-derived difference
```

Then measure the **mechanism first**.

Example:

```text
higher reception stability
→ broader/more stable platform capability under same difficult contact
```

Only afterward inspect aggregate rally outcomes.

If the first measurable change is “team wins 4% more,” the causal explanation is too weak.

## Capability is not permission

A player having the ability to execute an action does not mean tactics/rules/state always select or permit it.

This principle appears throughout VWM:

```text
capability
→ contributes when action is available/selected

permission/choice
→ comes from role, rules, tactics, responsibility, situation
```

Do not make a high attribute automatically trigger its action family.

## Safe extension checklist

For any management feature that promises an on-court effect:

1. write the manager-visible decision;
2. identify the durable state changed;
3. identify the live match consumer;
4. verify the consumer's semantics match the promise;
5. test the mechanism under controlled circumstances;
6. ensure the UI only reports the consequence;
7. document any gap if the downstream consumer does not yet exist.

## Reading exercise

Choose one complete chain—training `reception_stability`, fatigue, position familiarity, or tactical familiarity.

Draw every owner/function from the management input to the rally consumer. Mark where the value is persisted and where it becomes temporary rally state.

## Source trail

- `scripts/models/volleyball_player.gd`
- `scripts/models/team.gd`
- `scripts/models/rally_player_state.gd`
- `scripts/systems/training_system.gd`
- `scripts/managers/career_manager.gd`
- `scripts/managers/game_manager.gd`
- `scripts/simulation/`
- `docs/design/TACTICS_AND_TRAINING.md`

Part VII turns these ideas into a repeatable maintainer workflow: tests, probes, calibration authority, certification, debugging and safe extension.