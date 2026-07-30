# P4-C2 — Persistent Rally State

Status: **PARTIALLY IMPLEMENTED**
Keywords: RallyState, RallyPlayerState, RallyBallState, RallyMoment, RallyScheduler, persistence
Primary sources: `scripts/models/rally_state.gd`; `scripts/models/rally_player_state.gd`; `scripts/models/rally_ball_state.gd`; `scripts/models/rally_moment.gd`; `scripts/simulation/rally_state_builder.gd`; `scripts/simulation/rally_scheduler.gd`

## The core feedback loop

```text
current player and ball state
            ↓
generate feasible action opportunities
            ↓
choose an action using tactics, knowledge, and skill
            ↓
resolve contact and launch a new ball trajectory
            ↓
schedule future ball and movement moments
            ↓
advance every relevant state to the next moment
            └─────────────── repeat
```

## RallyState

`RallyState` is the container for simulation time, phase, serving side, player-state dictionaries, ball state, contact count, last contact, and rally activity. `advance_to()` moves time forward and updates the ball. `register_contact()` records ownership and contact count.

It should become the only authoritative answer to “what is happening now?” Events remain an output for playback and analysis.

## RallyPlayerState

Each player state stores identity, side, court position, velocity, tactical home, intent, target, timing, and availability. `set_intent()` describes future movement. `apply_position()` updates actual state.

The crucial rule is: tactical home is not an automatic reset. A player may choose to recover toward home, but the distance and elapsed time must matter.

## RallyBallState

Ball state owns a trajectory, flight status, current position, timing, and contact ownership. Launching a ball changes what locations and times become relevant to every player.

## RallyMoment and RallyScheduler

A moment represents a future occurrence. The scheduler orders moments deterministically and can schedule ball-flight milestones. This replaces a monolithic “then do the next phase” assumption with explicit simulation time.

## RallyStateBuilder

The builder translates match inputs—players, lineups, opponent state, and defensive plan—into initial persistent state. Translation belongs here so the simulation loop does not need to know every storage detail of every manager.

## What is still missing

The live `RallySimulator.resolve()` does not yet use these objects as its main loop. Opportunity generation currently focuses on a reception foundation. Contact resolution, decision policies, rule enforcement, event conversion, and migration across all phases still need integration.
