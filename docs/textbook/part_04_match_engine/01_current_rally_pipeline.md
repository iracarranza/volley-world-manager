# P4-C1 — Current Rally Pipeline

Status: **VERIFIED**
Keywords: RallySimulator, RallyEvent, RallyResult, event pipeline, live_positions, playback, phase model
Primary sources: `scripts/simulation/rally_simulator.gd`; `scripts/models/rally_event.gd`; `scripts/models/rally_result.gd`; `scenes/main/main.gd`

## Prerequisites

- [P1-C4 Following a User Action](../part_01_project/04_following_a_user_action.md) — how control reaches `resolve`
- [P2-C2 Resources, Nodes and Signals](../part_02_gdscript/02_resources_nodes_and_signals.md) — why events are Resources

## Learning goals

After this chapter you should be able to:

1. describe what `resolve()` does, in order;
2. explain why this is a **phase** model and what that costs;
3. say what an event **is** and what it is not;
4. respect the playback boundary, and explain the bug that breaks it;
5. compare the current resolver against the proposed one, term by term.

## Vocabulary

| Term | Meaning |
|---|---|
| **Phase** | One stage of a rally: serve, reception, set, attack, block, defence, continuation. |
| **Phase model** | A resolver that knows which phase comes next. |
| **`live_positions`** | Working positions the resolver maintains during a rally. |
| **Event** | A record of an action, for playback and analysis. Not state. |
| **Claimant** | The player selected to play a ball. |
| **Continuation** | The branch handling play after a dig or a block touch. |
| **Fallback** | A simplified value used when the real one is unavailable. |

---

## 1. What runs today

### 1.1 The order of operations

`RallySimulator.resolve()` initialises a seeded random generator, a rally clock,
and home `live_positions`. It then follows branches for serve, reception,
setting, attack, block, defence and continuation. Each resolved action is
recorded with `_add_event()`. `_finish()` adds the point outcome and final
analysis.

### 1.2 It is not a random table

The simulator performs meaningful spatial work:

- court positions are normalised;
- coverage selects claimants;
- movement time depends on distance and player ratings;
- passes produce destinations and trajectories;
- setters and hitters have arrival margins;
- blocking uses read, close, reach and coverage;
- tactics and familiarity modify some decisions.

> **Why this matters for how you read the file.** A common mistake is to assume
> that because the control flow is phase-ordered, the *content* is shallow. It is
> not. The limitation in §2 is structural, not a lack of modelling.

---

## 2. The structural limitation

### 2.1 The resolver knows what comes next

The function still knows the next volleyball phase in advance. It explicitly
calls reception logic after serve, set logic after reception, and so on.

`live_positions` is updated for some actors, but there is no single
authoritative loop asking, at each future moment: **"what actions are now
possible from the complete state?"**

### 2.2 What that costs

Continuity becomes fragile. A continuation branch can choose simplified
locations or fallbacks that do not fully arise from the preceding ball state.

The deeper cost is a question the model cannot express. In a phase model, "who
receives this serve?" is answered by a function whose job is to pick someone.
In a state model, nobody picks — the receiver is whoever can physically arrive,
and the answer may be **nobody**, which the rally must then handle.

> A phase model cannot easily represent a ball that simply lands.

---

## 3. Events are records, not state

### 3.1 The distinction

`RallyEvent` records what playback needs. Its positions and metadata describe an
action, but the list does **not** automatically answer where every non-acting
player is at an arbitrary time.

`RallyResult` summarises the completed rally.

### 3.2 The rule

> Neither model should be forced to become the authoritative physical simulation
> state.

This is the temptation the persistent work exists to resist. Each time someone
needs to know where a player was, adding a field to `RallyEvent` is the small
convenient move — and it makes the playback record into a second, partial,
diverging copy of the simulation.

**If you need state, you need [P4-C2](02_persistent_rally_state.md), not a
bigger event.**

---

## 4. The playback boundary

### 4.1 What playback may do

`Main._play_rally()` consumes the event list for the 2D court. Playback should
**interpolate** the resolved positions and trajectories.

### 4.2 What playback must not do

It must not reset players in a way that changes what the simulator believes
happened. Playback draws a decided rally; it does not decide.

> **The bug this prevents.** A player who "snaps" to a position during playback
> is a drawing artefact. Fixing it by writing a position back into the record
> makes the screen agree with itself and the analysis wrong — see the symptom
> table in [P1-C4 §3.1](../part_01_project/04_following_a_user_action.md).

### 4.3 The 3D view

3D match code may still be invoked elsewhere; it consumes the same rally
snapshots and trajectory evidence. **Simulation and tactical editing remain
authoritative elsewhere** — the 3D replay is presentation only. See
[Part 7](../part_07_art_and_assets/README.md).

---

## 5. Current versus proposed, term by term

| Current live resolver | Proposed persistent resolver |
|---|---|
| phase function chooses next phase | scheduler chooses next moment |
| selected actors update positions | all relevant actors carry state |
| events are created during branching | state resolution emits events afterward |
| availability is checked inside phase logic | opportunities are explicit values |
| tactical home may become a fallback position | tactical home is a movement intention |

### 5.1 Reading the table as a direction

Each row moves one decision from being **implicit in control flow** to being
**an explicit value**. That is the whole migration in one sentence, and it is
why the work proceeds one contact at a time rather than as a rewrite.

The last row is the one with the most visible consequences: a tactical home used
as a fallback teleports a player; a tactical home used as an intention makes
them walk, and the walking takes time that changes what they can reach.

---

## 6. Common mistakes

| Mistake | Consequence |
|---|---|
| Adding a field to `RallyEvent` to answer a state question | A second, diverging copy of the simulation |
| Fixing a playback artefact in the record | Screen agrees with itself; analysis is wrong |
| Assuming phase-ordered means shallow | You re-derive modelling that already exists |
| Treating the 3D view as authoritative | It is presentation only |

---

## 7. Check yourself

1. What does `_add_event()` produce, and what does it *not* capture? *(A record of an action; not the state of non-acting players at arbitrary times.)*
2. Why can't a phase model easily represent a ball that lands untouched? *(Its reception step's job is to select a receiver, so "nobody" is not naturally in the answer set.)*
3. A player snaps position during playback. Where is the fix? *(Playback — do not write it back into the record.)*
4. You need to know where a libero was at `t=1.8`. Which model? *(Persistent state — not an enlarged event.)*
5. In the comparison table, what do all five rows have in common? *(Each makes an implicit control-flow decision into an explicit value.)*

---

## Where this leads

- [P4-C2 Persistent Rally State](02_persistent_rally_state.md) — the models replacing the implicit decisions
- [P4-C3 Ball, Time, Movement and Actions](03_ball_time_movement_and_actions.md) — how an opportunity becomes explicit
- [P4-C5 Migration and Visible Proof](05_migration_and_visible_proof.md) — how the swap is being done safely
