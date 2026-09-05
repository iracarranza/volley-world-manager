# P4-C2 — Persistent Rally State

Status: **PARTIALLY IMPLEMENTED**
Keywords: RallyState, RallyPlayerState, RallyBallState, RallyMoment, RallyScheduler, builder, feedback loop, migration
Primary sources: `scripts/models/rally_state.gd`; `scripts/models/rally_player_state.gd`; `scripts/models/rally_ball_state.gd`; `scripts/models/rally_moment.gd`; `scripts/simulation/rally_state_builder.gd`; `scripts/simulation/rally_scheduler.gd`

## Prerequisites

- [P4-C1 Current Rally Pipeline](01_current_rally_pipeline.md) — the model this replaces, and why
- [P2-C2 Resources, Nodes and Signals](../part_02_gdscript/02_resources_nodes_and_signals.md) — these are all Resources, deliberately

## Learning goals

After this chapter you should be able to:

1. draw the feedback loop from memory and explain why it is a loop;
2. name each persistent model and the one question it answers;
3. explain why **tactical home is an intention, not a reset**;
4. read the integration boundary and say what is live today;
5. say why this migration proceeds one contact at a time.

## Vocabulary

| Term | Meaning |
|---|---|
| **Persistent state** | State that survives between moments, rather than being recomputed per phase. |
| **Moment** | A scheduled future occurrence in simulation time. |
| **Intent** | What a player is trying to do next; describes future movement. |
| **Tactical home** | The position a player's role wants them at. |
| **Shadow decision** | A persistent decision computed but not used for outcomes. |
| **Promotion** | Allowing a shadow decision to become authoritative. |
| **Rollout flag** | A switch gating promotion; production flags are off. |

---

## 1. The core feedback loop

### 1.1 The loop

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

### 1.2 Why it must be a loop

Every arrow feeds the next, and the last feeds the first. A phase model breaks
the cycle by knowing the next stage in advance; here **nothing knows what comes
next** — it falls out of what is reachable.

Compare the two failure surfaces. In a phase model a bug produces a *wrong
choice*. In a loop, a bug produces a rally that goes somewhere nobody designed,
which is harder to debug and much more likely to be correct when it works.

---

## 2. The models

### 2.1 `RallyState` — what is happening now

The container for simulation time, phase, serving side, player-state
dictionaries, ball state, contact count, last contact, and rally activity.

- `advance_to()` moves time forward and updates the ball;
- `register_contact()` records ownership and contact count.

> It should become the **only** authoritative answer to "what is happening now?"
> Events remain an output for playback and analysis.

### 2.2 `RallyPlayerState` — where one player is, and what they are doing

Stores identity, side, court position, velocity, tactical home, intent, target,
timing and availability.

- `set_intent()` describes future movement;
- `apply_position()` updates actual state.

It also carries `body_state`, one of `BALANCED`, `MOVING`, `REACHING`,
`DIVING`, `AIRBORNE`, `RECOVERING` — five of those six describe a body that is
compromised, which is what makes a contact from one of them different.

### 2.3 `RallyBallState` — where the ball is and whose it is

Owns a trajectory, flight status, current position, timing and contact
ownership. **Launching a ball changes what locations and times become relevant
to every player** — that is the arrow from "resolve contact" back to "generate
opportunities".

### 2.4 `RallyMoment` and `RallyScheduler` — when things happen

A moment represents a future occurrence. The scheduler orders moments
deterministically and can schedule ball-flight milestones.

This replaces a monolithic "then do the next phase" assumption with **explicit
simulation time**. Determinism matters here: the ordering must be reproducible
or the whole seed discipline in [P3-C2](../part_03_workflow/02_debugging_testing_and_git.md)
collapses.

### 2.5 `RallyStateBuilder` — translation, in one place

Translates match inputs — players, lineups, opponent state, defensive plan —
into initial persistent state.

> Translation belongs here so the simulation loop does not need to know every
> storage detail of every manager.

**This is the boundary that keeps the loop testable.** A test can construct a
state directly and never touch `CareerManager`.

---

## 3. Tactical home is an intention, not a reset

### 3.1 The rule

> A player may choose to recover toward home, but the **distance and elapsed
> time must matter**.

### 3.2 Why this single rule carries so much

If tactical home is a reset, a player teleports between phases. Everything
downstream inherits the lie:

- movement costs nothing, so a slow player is as good as a fast one;
- a defender who committed to a dig is instantly available again;
- training that improves movement changes nothing observable — which breaks the
  legibility requirement from
  [P1-C1 §3](../part_01_project/01_what_you_are_building.md).

So this is not a detail of the movement system. **It is the mechanism by which
management decisions reach the court**, and it is the last row of P4-C1's
comparison table for that reason.

---

## 4. The integration boundary

### 4.1 What is true today

The live `RallySimulator.resolve()` does **not** yet use these objects as one
authoritative scheduler-driven loop. Integration proceeds one contact at a time:

- reception, setter and attack each have persistent shadow decisions, candidate
  audits, guarded rollout policies and explicit development-only promotion;
- **their production flags remain disabled**, so ordinary contact ownership
  still comes from the phase resolver;
- home attack preparation now consumes persistent-style position, velocity,
  responsibility, approach and contact-envelope evidence in ordinary rallies;
- floor-defence phase positions affect normal claimant geometry;
- attack-to-block perception has not migrated yet.

### 4.2 What remains incomplete

Rule enforcement, coordinated blocker observations, opponent-side persistent
decisions, and one scheduler-driven loop.

### 4.3 Reading this section as a contributor

**New persistent code that does not change a live rally is not broken** — it is
almost certainly not wired into `resolve`, and that may be deliberate. Check the
flag before debugging. This is a documented symptom in
[INDEX.md](../INDEX.md)'s error table.

See the [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md) for the single current
next slice and its acceptance contract.

---

## 5. Why one contact at a time

### 5.1 The alternative, and why it was rejected

A rewrite would replace a working, tuned resolver with an untested one and
compare the results — with every difference ambiguous between "the new model is
better" and "the new model is broken."

### 5.2 What the slice strategy buys

Each slice can be:

1. computed in **shadow**, changing nothing;
2. compared against the live decision on real rallies;
3. audited for information purity — did it read something a player could not
   know?;
4. promoted behind a **development-only** flag;
5. measured with the balance probe before production rollout.

That is five opportunities to find a defect while the game still works. See
[P4-C5](05_migration_and_visible_proof.md).

---

## 6. Common mistakes

| Mistake | Consequence |
|---|---|
| Treating tactical home as a reset | Movement becomes free; training stops being legible |
| Putting manager-storage knowledge in the loop | The loop cannot be tested standalone |
| Debugging persistent code that "does nothing" | It is flag-gated, by design |
| Making `RallyEvent` hold state | Two diverging copies of the truth |
| Non-deterministic moment ordering | Every seeded test becomes unreliable |

---

## 7. Check yourself

1. What is `RallyState` the authoritative answer to? *("What is happening now?")*
2. Why is `RallyStateBuilder` separate from the loop? *(So the loop needs no knowledge of manager storage, and stays testable.)*
3. Give two consequences of treating tactical home as a reset. *(Movement costs nothing; committed defenders become instantly available.)*
4. Your new persistent code changes no rally. First check? *(Whether it is wired into `resolve` and whether its flag is on.)*
5. Why shadow a decision before promoting it? *(It can be compared against the live one on real rallies while the game still works.)*

---

## Where this leads

- [P4-C3 Ball, Time, Movement and Actions](03_ball_time_movement_and_actions.md) — how opportunities are generated
- [P4-C4 Tactics, Information and Progression](04_tactics_information_and_progression.md) — how a choice is made
- [P4-C5 Migration and Visible Proof](05_migration_and_visible_proof.md) — the shadow-and-promote machinery
