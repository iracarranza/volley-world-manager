# Six-Player Embodied Movement Audit

Audit of `docs/specs/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md`, run on
`claude/system-fit-serve-receive-von64k` at `ac13cb4`.

Instruments written for this pass and kept:

- `tools/audit_embodied_locomotion.gd` — A3 counterfactuals and the A8 split,
  driven through `RallyMovementSystem` and `ShadowMovementSystem` directly.
- `tools/audit_six_player_space.gd` — A6 same-team conflict and A7 environment,
  on one shared rally clock.

Existing instruments re-run: `tools/audit_playback_corrections.gd`,
`tools/run_rally_balance_probe.gd`.

---

# A0 — Production baseline

| property | value | source |
|---|---|---|
| branch / commit | `claude/system-fit-serve-receive-von64k` @ `ac13cb4` | — |
| playback corrections | **0 of 8,733 drawn legs** | `audit_playback_corrections.gd` |
| worst spatial disagreement | **0.0000 court units** | same |
| determinism | two further repeat runs byte-identical | same, ×3 |
| balance, 700 rallies | contacts 4.630, kill 0.535, dig 0.522, stuff 0.101, ace 0.099, serve error 0.194 | `run_rally_balance_probe.gd` |

Every figure reproduces the record `a41f285` put in `CLAUDE.md` exactly. **P15
invariants hold**; the audit proceeds.

The authoritative type is `RallyMovementPath`
(`scripts/models/rally_movement_path.gd`): per sample an absolute rally-clock
`time`, `position`, `velocity` and `facing`, plus `exit_velocity` and
`reached_target` for the leg. The single solve is
`RallySimulator._committed_path()`. Consumers are the four in contract §C6, and
the four publishers are those `tactical_court._authoritative_phase_path` reads,
in its priority order: `movement_path`, `<side>_phase_intents[id].path`,
`<side>_phase_hold_paths[id]`, `staged_next_path`.

---

# A1/A2 — Causal inventory, and what the committed solve is actually told

The classification the spec asks for turns almost entirely on one question:
which of the four movement entry points a given piece of state reaches.

| factor | modelled? | reaches `_travel` | reaches `_movement_time` | reaches `_reached_point` | reaches `_committed_path` | verdict |
|---|---|---|---|---|---|---|
| position | yes | yes | yes | yes | yes | physically causal |
| carried velocity | yes | **7 of 7 sites** | **1 of 33 sites** | **0 of 18** | **0 of 16** | causal for approach timing only |
| facing | yes, via `facing_fit` | parameter exists, never supplied | no | no | **0 of 16 sites** | modelled, never charged |
| body/action state | **no** | — | — | — | — | not a locomotion input |
| recovery | yes, as a start gate | via `recovery_until` | — | — | — | gates when, not how |
| acceleration rating | yes | yes | yes | yes | yes | physically causal, dominant |
| fatigue | yes | yes | yes | yes | yes | physically causal |
| mass | yes | yes | yes | yes | yes | causal but near-inert (below) |

**Carried velocity is stored and mostly not consumed.** `live_velocities` /
`opponent_live_velocities` are written from `exit_velocity` at three sites
(`:2349`, `:5197`, `:7096`) and read at four (`:2229`, `:5071`, `:6968`, and the
defender candidate search at `:11938`). But **no `_committed_path` call site and
no `_reached_point` call site passes it**. So the function that decides where a
body ends up, and the function that draws every leg in the game, both work from
a dead stop. The hitter's approach and the defender candidate scoring are the
exceptions, not the rule.

**Facing is a modelled locomotion cost that production never charges, and it is
actively discarded rather than merely unsupplied.**
`RallyMovementSystem._movement_profile` derives `facing_fit` from
`actor.facing · direction` and feeds it into
`LocomotionModel.direction_change_seconds`, and into `arrival_balance` in
`_movement_scenario`. `RallyPlayerState.create()` sets a real side-relative ready
facing. Both `_travel` and `_committed_path` then execute
`actor.facing = entry_facing`, and every one of the 16 `_committed_path` call
sites leaves that parameter defaulted to `Vector2.ZERO` — which
`_movement_profile` reads as a *perfect* fit, because its guard is
`length_squared() > 0.001`. The code overwrites a meaningful default with a value
that means "no penalty".

`player_facing` is maintained (`_commit_facing`, from exit velocity) and is read
in two places — `_seed_carried_body_states` and the candidate search — so the
information exists and travels. It simply never reaches the committed solve.

**Body state is not a locomotion input at all.** `body_state` appears once in
`rally_movement_system.gd`, setting `REACHING` on a snapshot, and never in the
arithmetic. Measured below.

---

# A3 — Controlled locomotion counterfactuals

One player (Mira, acceleration 74, mass 77.0, fatigue 0.00), TRANSITION mode, one
start, targets along the 9 m axis, no RNG. Only the named factor varies per row.

## A3.2 Facing — worth up to 0.151 s, charged never

| facing vs travel | seconds (3.0 m) | delta |
|---|---:|---:|
| 0° | 1.0571 | — |
| 45° | 1.0793 | +0.0221 |
| 90° | 1.1327 | +0.0756 |
| 135° | 1.1862 | +0.1291 |
| 180° | 1.2083 | +0.1512 |
| **zeroed (production)** | **1.0571** | **+0.0000** |

The penalty is a constant additive turn cost — identical at 1.5 m, 3.0 m and
5.0 m — so it is proportionally largest on the short, urgent legs. Production
takes the 0° row every time.

Keeping `create()`'s own default rather than overwriting it would already cost
0.0756 s on a body facing across its travel. The zeroing is not neutral.

## A3.1 Direction and momentum — reversal is free

3.0 m target, varying entry speed and the angle between that velocity and the
target.

| entry speed | 0° | 45° | 90° | 135° | 180° |
|---|---:|---:|---:|---:|---:|
| 0.0 | 1.0571 | 1.0571 | 1.0571 | 1.0571 | 1.0571 |
| 1.5 | 0.8279 | 0.8870 | 1.0571 | 1.0571 | 1.0571 |
| 3.0 | 0.6754 | 0.7554 | 1.0571 | 1.0571 | 1.0571 |
| 4.5 | 0.5998 | 0.6621 | 1.0571 | 1.0571 | 1.0571 |
| 6.0 | 0.5908 | 0.6073 | 1.0571 | 1.0571 | 1.0571 |

**A body sprinting at 6 m/s directly away from its target reaches it in exactly
the same time as a body standing still.** Momentum toward the target is credited
(up to −0.466 s); momentum away costs nothing, because `_leg_seconds` takes
`max(velocity · direction, 0)` and the discarded component is never charged as
something that must first be arrested. Physically the away case must be *worse*
than stationary — the body has to decelerate, stop and turn.

Exit speed is 5.227 m/s in every row including entry 6.0, so the leg's exit
state is independent of what it carried in.

## A3.3 Body state — no effect, as predicted

BALANCED, MOVING, REACHING, DIVING, AIRBORNE and RECOVERING all give 1.0571 s,
delta +0.0000. This was run as a falsification test of the code reading; it did
not falsify it.

## A3.4 Attributes and morphology

| factor | value | seconds | delta |
|---|---|---:|---:|
| acceleration | 10 / 50 / 90 | 1.5187 / 1.1715 / 1.0030 | +0.462 / +0.114 / −0.054 |
| fatigue | 0.0 / 0.5 / 1.0 | 1.0571 / 1.1614 / 1.3103 | — / +0.104 / +0.253 |
| mass_kg | 58 / 82 / 118 | 1.0521 / 1.0592 / 1.0825 | −0.005 / +0.002 / +0.025 |

Acceleration dominates (0.52 s across its range). Fatigue is real. **Mass spans
0.030 s across 58–118 kg** — a 60 kg difference in body mass is worth a fifth of
what facing 90° away would cost if facing were charged. It is causal but close to
inert.

---

# A4 — Where each body's destination comes from

`tactical_court._authoritative_phase_path` reads four publishers in a fixed
priority order and takes the first that answers. That order only matters when
more than one answers, and nothing had counted how often that happens.
`tools/audit_target_sources.gd`, 120 rallies, **3,802 body-events**:

| | count |
|---|---:|
| exactly one source | 1,870 |
| **two or more sources** | **1,932 (51%)** |

| publisher | answers | wins a contest |
|---|---:|---:|
| `movement_path` | 503 | 91 |
| `phase_intent` | 2,789 | 1,841 |
| `phase_hold` | 2,427 | **0** |
| `staged_next` | 27 | 0 |

**Half of all body-events carry two competing journeys.** The contract intends
this — a stated journey beats a hold — and `phase_hold` correctly never wins a
contest, only answering when uncontested. What the contract does not say is
whether the loser was the same journey restated or a different destination:

| winner-vs-loser endpoint distance | value |
|---|---:|
| agree within 1 cm | **1,737 of 1,932 (90%)** |
| median | 0.000 m |
| p90 | 0.151 m |
| **worst** | **4.139 m** |

So one contested body-event in ten has a discarded source pointing somewhere
materially different, up to 4.14 m away. The priority order is doing real work,
not just tie-breaking. Contests are overwhelmingly `phase_intent` vs
`phase_hold` — a body simultaneously told to travel and to stand still — led by
RECEPTION (570), DIG (523) and SET (341).

This is reported as a **measured property, not a defect**: playback resolves it
deterministically and by the documented rule. It matters because any *other*
consumer that reads a hold path without applying the same priority would place
that body up to 4.14 m from where the court draws it.

---

# A5 — Perception and coordination reaching movement

**Perception is causal for defensive arrival, and this is a category-C
finding.** `_reached_point` takes a `shortfall_meters` — how far short a mover
stops because they read the ball somewhere else — and **4 of its 18 call sites
pass one**, fed by `_read_error_meters`, which builds a `BallContactSignature`
from the flight's real launch speed and spin. The setter path additionally moves
to a `perceived_body_position` rather than the true one (`:2293`).

So the naive reading — that perception is tactical decoration — is wrong: it
changes where a defender physically ends up, at the defensive sites and nowhere
else. The approach and coverage sites deliberately keep exact arrival.

What is *not* fixed remains D2: preparation timing still runs on the ball's true
flight. That is out of scope here and is not absorbed into this pass.

---

# A6 — Six-player spatial conflict

120 rallies, 40 ms steps, 11,974 instants, **73,525 same-team pair observations**.
Bodies are sampled only where one of the four publishers gave them a live leg; a
body between legs is deliberately not interpolated.

| separation | value |
|---|---:|
| minimum observed | **0.000 m** |
| p01 | 0.606 m |
| p05 | 1.347 m |
| p50 | 4.083 m |

| clearance | pair-samples below | court-seconds below | instants with 3+ crowded |
|---|---:|---:|---:|
| 0.50 m | 529 | 21.2 s | 129 |
| 0.72 m | 1,015 | 40.6 s | 0 |
| 0.90 m | 1,750 | 70.0 s | 0 |

Worst eight closest approaches: 0.000, 0.016, 0.060, 0.063, 0.067, 0.067, 0.068,
0.072 m. These are the same point, not near misses.

**The clearance figure is an assumption and is labelled as one.** The repo has no
simulation body width; the only dimension anywhere is a 0.36 m torso half-width
*rendering* fallback in `render_double_block_regression.gd`. 0.72 m is two of
those; the other two rows bracket it.

**Causal context, which decides what kind of defect this is.** Of the 529
pair-samples inside 0.50 m:

| both bodies | samples |
|---|---:|
| moving | **492** |
| parked | 32 |
| one moving | 5 |

So this is converging traffic, not two maps handing two players the same standing
coordinate. It is a coordination/route defect rather than a positioning one, and
those want different repairs.

**This is a lower bound.** 386 of 1,440 player-rally slots (27%) published no path
at all and were never sampled. Conflicts involving those bodies cannot appear in
these numbers.

---

# A7 — Court and environment

| measure | count | worst |
|---|---:|---:|
| samples outside the 0–1 x bounds | 34 | 0.32 m |
| samples outside the 0–1 y bounds | 260 | 1.00 m |
| **samples past the net plane** | **305** | **0.88 m** |

The x and y excursions are small and are consistent with legal pursuit — a body
0.32 m outside the sideline or 1.00 m behind the baseline is playing volleyball.
This closes `AUTHORITATIVE_RALLY_MOVEMENT.md` D3's open question in the
legitimate direction: the traces that cross `x = 0` and `x = 1` are pursuit, not
unclamped targets.

**The net plane is different.** 305 samples put a body on the opponents' side of
`NET_Y`, up to 0.88 m past it — worst case seed 61103, player 102, opponent side.
A body 0.88 m across the centre line has walked through the net. This is
impossible traversal rather than legal off-court movement, and it is the one A7
finding that is not explainable as pursuit.

---

# A8 — The two reachability answers

`_committed_path` asks the closed form for a duration and hands that duration to
the stepped integrator to draw, so any disagreement appears as distance still
owed at the end of a leg the resolver believes is complete.

Stressed on controlled geometry — 60 rows, distances 1.0–8.0 m, entry speeds
0.0–6.0 m/s, entry angles 0/90/180°:

**Zero rows short by more than 5 cm. Worst shortfall 0.000 m.**

On legal geometry the two models agree exactly. That falsifies distance, entry
speed and entry angle as the source of the D1 split (46 of 1,679 legs, up to
0.377 court units) and says the disagreement lives somewhere else — waypointed
two-leg traversals, mode differences, or the clamp below are the candidates, and
this pass did not discriminate between them.

**One divergence was isolated, by accident and then deliberately.** With a target
off the court, the closed form times the journey to it and the integrator clamps
the body at the boundary: a target at `x = 1.167` produced a landing exactly
1.500 m short — the clamp distance, in every row. The two models do not agree
about whether a body may be off court.

---

# Instrument errors found and corrected

Recorded because the audit's own instrument was wrong twice and both times it
announced itself by producing a physically impossible number.

1. **Reading a non-existent key.** The A8 block read `integration["position"]`;
   the integrator returns a `trail`, not a point. The default `Vector2.ZERO`
   produced shortfalls of 12–14 m — larger than the court.
2. **One unit for two axes.** `_target_at` scaled a unit bearing vector by the
   *x*-axis metres-per-unit, so a "6 m" target along y was 12 m away and the
   court clamp was reported as a 3.000 m model disagreement. Bearing 0 was right
   by accident, so the A3 blocks are unaffected — verified by re-running them
   after the fix and confirming the facing table is identical.

---

# A9 — Findings

## A. Physical locomotion defects

| # | finding | evidence | severity |
|---|---|---|---|
| A1 | **Reversal is free.** Moving away from the target at any speed costs exactly what standing still costs. | A3.1, all of 0/1.5/3/4.5/6 m/s at 90–180° identical to stationary | high — it makes momentum one-directional |
| A2 | **Carried velocity does not reach the committed solve.** 0 of 16 `_committed_path` and 0 of 18 `_reached_point` sites pass it. | A1/A2 call-site census | high |
| A3 | **Facing is modelled and never charged**, and is overwritten with a value meaning "no penalty". | A3.2; 0 of 16 sites supply it | medium — worth up to 0.151 s |
| A4 | **Body state is not a locomotion input.** | A3.3, six states identical | low as a defect, high as a documentation correction |

## B. Six-player spatial-coherence defects

| # | finding | evidence | severity |
|---|---|---|---|
| B1 | Same-team bodies occupy the same point. Minimum separation 0.000 m; 529 pair-samples and 21.2 s inside 0.50 m; 129 instants with three or more crowded. | A6 | high |
| B2 | 93% of those are **both bodies moving** — converging traffic, not duplicated standing positions. | A6 context split | informs the fix |
| B3 | Bodies cross the net plane by up to 0.88 m, 305 samples. | A7 | medium |

## C. Things that already work — preserve

Zero playback corrections across 8,733 legs, deterministic on repeat. Acceleration
and fatigue are properly causal. Off-court pursuit in x and y is legitimate and
should not be clamped. The closed form and the integrator agree exactly on legal
geometry.

## D. Outside this pass

Perceived-vs-true preparation timing (`AUTHORITATIVE_RALLY_MOVEMENT.md` D2, P4
not done) — perception machinery does reach some movement decisions
(`_read_error_meters`, `perceived_body_position` at `:2293`), but prep timing
still runs on true flight. Documented, not absorbed.

## E. Uncertain / under-exercised

- **27% of player-rally slots publish no path** and are invisible to A6. The
  conflict numbers are a lower bound and the true rate is unknown.
- **The D1 split's actual cause is not identified.** Controlled geometry agrees;
  the 46 disagreeing production legs must come from waypoints, mode, or the
  clamp, and no discriminating test was run.
- **Claim and coordination were not isolated.** A4 enumerates which *publisher*
  wins; it does not establish which upstream decision chose that publisher's
  target, nor whether claim priority or assertiveness changed who moved. A
  controlled scenario differing only in claimant would be the test.
- Interaction coverage is partial: velocity × angle and facing × distance were
  measured; facing × incoming velocity, recovery × deadline and
  attributes × turning were not.
- One player profile was used for all A3 rows. Attribute *interactions* were not
  crossed.

## Minimum evidence-backed implementation sequence

1. **Pass carried velocity into `_committed_path` and `_reached_point`** — the
   plumbing and the store already exist; this is wiring, not a new model.
2. **Charge reversal.** `_leg_seconds` must cost the component it currently
   discards, not merely decline to credit it.
3. **Supply facing** to the committed solve, or delete `facing_fit` and the turn
   model as dead weight. It should not stay in the state it is in — modelled,
   plumbed, and always zero.
4. **Then** re-measure A6. Two of the three above change arrival times, and the
   conflict population will move; fixing traffic before fixing momentum would be
   tuning against a number that is about to change.
5. The net-plane crossing wants its own diagnosis — it may be a target source
   rather than a locomotion failure.

Items 1–3 will move rally outcomes. Kill rate is already outside its 0.45–0.50
gate at 0.535, and `a41f285` records that the sampling population under it moved
for a defensible reason; these repairs will move it again and should be measured
against that entry, not against the gate.
