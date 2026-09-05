# P1-C4 — Following "Resolve Rally"

Status: **VERIFIED**
Keywords: call path, resolve rally, event playback, GameManager, RallySimulator, contract, determinism, seed
Primary sources: `scenes/main/main.gd`; `scripts/managers/game_manager.gd`; `scripts/simulation/rally_simulator.gd`; `scripts/models/rally_event.gd`

## Prerequisites

- [P1-C2 Godot Project and Runtime](02_godot_project_and_runtime.md) — the runtime trace method and the four layers
- [P1-C3 Repository Map](03_repository_map.md) — which directory each step lives in

## Learning goals

After this chapter you should be able to:

1. recite the resolve-rally call path and name the file for each step;
2. decide, from a bug's symptom, which side of the simulation/playback contract failed;
3. explain what a **seed** buys and what it does not;
4. read `RallySimulator.resolve`'s signature and say what the rally is a function *of*;
5. verify the whole path yourself when it changes.

## Vocabulary

| Term | Meaning |
|---|---|
| **Call path** | The ordered chain of functions from a user action to a state change. |
| **Contract** | The agreed shape of data passed between two layers. |
| **`RallyResult`** | The completed rally: a list of events plus its outcome. |
| **`RallyEvent`** | One recorded action, consumed by playback and analysis. |
| **Seed** | The integer initialising the rally's random generation. |
| **Playback** | Drawing a rally that has already been decided. |
| **Metadata** | Extra per-event data, e.g. `outgoing_trajectory`. Contract-critical. |

## 1. The call path

```text
user activates rally control
        ↓
Main._resolve_rally()                      scenes/main/main.gd:1905
        ↓
GameManager.resolve_active_rally(seed)     scripts/managers/game_manager.gd:499
        ↓
RallySimulator.resolve(...)                scripts/simulation/rally_simulator.gd:824
        ↓
RallyResult containing RallyEvent resources
        ↓
Main._play_rally(result, ...)              scenes/main/main.gd:1974
        ↓
2D tactical court playback and result recording
```

Notice the layers: **scene → manager → simulation → back to scene**. That is
P1-C2's architecture in one path, and the shape is the point. The simulation
never calls back into the scene.

## 2. What the rally is a function of

```gdscript
func resolve(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	active_play: OffensivePlay,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int,
	development_continuous_reception: bool = false,
	development_physical_platform_dig: bool = false,
	team_principles: Resource = null,
	...
)
```

Read a signature as a claim about causality. **Everything the rally depends on
is in this list.** If a rally outcome changes and none of these changed, you
have found either hidden state or unseeded randomness — both are bugs, and
[P3-C2](../part_03_workflow/02_debugging_testing_and_git.md) explains how to
hunt them.

Three observations worth making:

- **`seed_value` is a parameter, not a global.** The same inputs must produce the
  same rally.
- **The `development_*` flags are explicit.** Unfinished work is opt-in and
  visible in the signature rather than hidden behind a global switch.
- **Management decisions enter as arguments** — `active_play`, `defensive_plan`,
  `team_principles`. This is the causal chain from
  [P1-C1](01_what_you_are_building.md), made concrete.

## 3. The contract, and the bug it prevents

`RallyResult` contains events. Each `RallyEvent` carries an actor, event type,
start and end positions, success, quality, text, and metadata. Playback depends
especially on exact metadata contracts such as `outgoing_trajectory`.

> **The rule.** Changing playback to "fix" a simulation error can make the screen
> look right while analysis and results remain wrong. Changing simulation to
> "fix" a drawing transform can corrupt correct outcomes. **Always identify which
> side of the contract failed.**

### Diagnosing by symptom

| Symptom | Failed side | Where to look |
|---|---|---|
| Wrong winner, wrong score | Simulation | `RallySimulator.resolve` |
| Right outcome, ball teleports | Playback / contract | `outgoing_trajectory` continuity |
| Right outcome, player snaps to a spot | Playback | position resets in playback only |
| Missing player or plan | Manager state | `GameManager` |
| Same seed, different result | Determinism | unseeded RNG or mutable global state |
| Text says one thing, court shows another | Contract | event metadata vs drawn values |

**The two middle rows are the ones people get wrong.** A ball that teleports is
almost never a simulation bug — the simulation decided a correct destination and
the drawing did not receive or respect it.

### Worked example

*The ball jumps at the moment of a set.*

1. **Which side?** The rally's outcome is right, so the physics decided
   something coherent. This is a playback or contract symptom.
2. **Which contract?** Ball movement between events is carried by
   `outgoing_trajectory`.
3. **What to check:** does the set event's `outgoing_trajectory` *end* where the
   attack event's flight *begins*? A jump is a discontinuity between two events
   that each look correct alone.
4. **What not to do:** interpolate over the gap in the playback layer. That hides
   a broken contract and the analysis stays wrong.

## 4. Determinism, and what a seed buys

A seed buys **reproducibility**: the same inputs give the same rally, so a bug
can be re-run and a change can be compared against a known baseline.

It does **not** buy stability across code changes. A change to how a contact is
resolved will produce a different rally from the same seed, and that is correct
behaviour — it is how the balance probes detect that something moved.

> **Practical consequence.** "Same seed, different result" is a bug **only if
> nothing in the resolver changed.** Before hunting for hidden state, confirm
> your tree is actually unchanged.

## 5. Verifying this chapter yourself

This path is load-bearing and the book must not drift from it.

```bash
rg -n "func _resolve_rally" scenes
rg -n "func resolve_active_rally" scripts
rg -n "^func resolve\(" scripts/simulation/rally_simulator.gd
rg -n "func _play_rally" scenes
```

Write down the file and line of each result. If the chain differs from §1,
**update this chapter and the evidence ledger** — see
[EVIDENCE.md](../EVIDENCE.md). A textbook that is confidently wrong about a call
path is worse than one that is silent about it.

## 6. Common mistakes

**Fixing the drawing because the drawing is what you can see.** Diagnose the side
first.

**Assuming a plausible function is the live one.** This codebase contains
superseded paths that still parse. Trace.

**Treating a seed as a guarantee across versions.** It is a guarantee across
runs.

**Adding a global to avoid threading a parameter.** It breaks the determinism
property the signature exists to give you.

## 7. Check yourself

1. Score is right, ball flies through the net during playback. Which side? *(Playback or contract — the outcome was decided correctly.)*
2. Why is `seed_value` a parameter rather than read from a global? *(So the rally is a pure function of its inputs and can be reproduced.)*
3. What does the presence of `development_*` flags in the signature tell you? *(Unfinished work is opt-in and visible, not hidden behind a global.)*
4. Same inputs, same seed, different rally, and you just edited the resolver. Bug? *(No — that is the expected consequence of changing the resolver.)*
5. Which layer does `_play_rally` belong to, and what must it never do? *(Scene; it must not decide outcomes.)*

## Where this leads

- [P4-C1 Current Rally Pipeline](../part_04_match_engine/01_current_rally_pipeline.md) — what happens inside `resolve`
- [P3-C2 Debugging, Testing and Git](../part_03_workflow/02_debugging_testing_and_git.md) — determinism failures in practice
- [P2-C2 Resources, Nodes and Signals](../part_02_gdscript/02_resources_nodes_and_signals.md) — why `RallyEvent` is a `Resource`
