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

## Measured in production data, not inferred from call sites

`tools/audit_six_player_space.gd` sorts every published leg per player and
compares each leg to the next, over 120 rallies — **1,044 consecutive leg
pairs**:

| measure | value |
|---|---:|
| **next leg begins at rest** | **1,044 of 1,044** |
| previous leg ended moving (>0.4 m/s) | 149 |
| mean position gap between legs | 0.352 m |
| worst position gap | **4.781 m** |
| pairs gapped by more than 10 cm | 268 |

**Every leg in the game begins from a standstill.** Not "most" and not "the ones
that were not given a velocity" — all 1,044. In 149 of them the previous leg
genuinely ended moving, and that momentum was dropped at the boundary. This is
the call-site census of A1 confirmed against the record the game actually
publishes.

**A quarter of leg boundaries also move the body.** Attributing the 268 gaps to
the publisher pair that produced them:

| previous → next | gaps > 10 cm |
|---|---:|
| `phase_intent` → `phase_intent` | **102** |
| `movement_path` → `phase_hold` | 77 |
| `phase_hold` → `phase_intent` | 43 |
| `movement_path` → `phase_intent` | 14 |
| others | 32 |

The discriminating result is the first row: 102 gaps are **one publisher's own
consecutive journeys** failing to join, which cannot be explained as two sources
describing different things.

**Two caveats, because not every gap is a defect.** A contact legitimately places
its actor, so `movement_path → *` transitions can move a body by design. And the
zero-correction metric does not contradict this: a "correction" is defined as *no
published path* plus a disagreement, so a next leg that publishes a path starting
somewhere else is invisible to it. These 268 are a different population from the
425 corrections P15 removed, and they were previously unmeasured.

**Re-run at 600 rallies, and every proportion holds.** 5,800 consecutive leg
pairs — 5.6× the sample — and the shape does not move:

| measure | 120 rallies | 600 rallies |
|---|---:|---:|
| next leg begins at rest | 1,044 of 1,044 | **5,800 of 5,800** |
| previous leg ended moving | 149 (14.3%) | 801 (13.8%) |
| pairs gapped by more than 10 cm | 268 (25.7%) | 1,482 (25.6%) |
| mean gap | 0.352 m | 0.340 m |
| worst gap | 4.781 m | 4.781 m |
| `phase_intent → phase_intent` share of the gaps | 102 (38.1%) | 569 (38.4%) |

The "begins at rest" row is the one that matters: it is not a small-sample
artefact and it is not a majority — it is every leg the game publishes, at both
sample sizes. The worst gap is the *same* 4.781 m, so 480 additional rallies
found nothing worse than the 120 already had.

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

## A3.1b Every movement mode, not just TRANSITION

The first version of this audit exercised TRANSITION alone, which cannot say
whether any finding generalises. All six declared modes, entry velocity zero:

| mode | 1.5 m | 3.0 m | 5.0 m | facing-180 penalty |
|---|---:|---:|---:|---:|
| IDLE | 0.8159 | 1.3759 | 2.1227 | +0.1518 |
| LATERAL | 0.7806 | 1.2727 | 1.9288 | +0.1491 |
| TRANSITION | 0.7485 | 1.0571 | 1.4398 | +0.1512 |
| APPROACH | 0.7518 | 1.1536 | 1.6893 | +0.1522 |
| BLOCK_CLOSE | 0.7717 | 1.2421 | 1.8692 | +0.1515 |
| RECOVERY | 0.7672 | 1.2254 | 1.8363 | +0.1518 |

Modes differ in speed as they should, and the facing penalty is ~0.15 s in every
one of them. The findings are properties of the model, not of one mode.

## A3.4b More than one body

| player | accel | mass | stationary | from 6 m/s toward | facing-180 penalty |
|---|---:|---:|---:|---:|---:|
| Mira | 74 | 77.0 | 1.0571 | 0.5908 | +0.1512 |
| Tala | 78 | 84.0 | 1.0461 | 0.6053 | +0.1561 |
| Boro | 80 | 98.0 | 1.0612 | 0.6679 | +0.1742 |
| Sena | 62 | 99.0 | 1.1291 | 0.6794 | +0.1725 |
| Ivo | 84 | 90.0 | 1.0237 | 0.5981 | +0.1518 |
| Nemi | 90 | 69.0 | 0.9958 | 0.5658 | +0.1402 |

Six bodies, same shape of result. The facing penalty is not a constant — it runs
0.140–0.174 s and tracks the body — which strengthens rather than weakens the
finding that it is never charged.

## A3.2b Interaction: facing × incoming velocity

| entry speed | entry angle | facing 0° | facing 180° | difference |
|---|---|---:|---:|---:|
| 0.0 | — | 1.0571 | 1.2083 | +0.1512 |
| 3.0 | 0° (toward) | 0.6754 | 0.8266 | +0.1512 |
| 3.0 | 180° (away) | 1.0571 | 1.2083 | +0.1512 |
| 6.0 | 0° (toward) | 0.5908 | 0.7420 | +0.1512 |
| 6.0 | 180° (away) | 1.0571 | 1.2083 | +0.1512 |

**No interaction.** The facing penalty is exactly +0.1512 s in every cell — a
constant additive turn cost, independent of what the body is carrying. It also
re-confirms the reversal finding with facing varied: entry 180° at 3 and 6 m/s
gives precisely the stationary time.

## A3.3b Interaction: body state × movement direction

All six body states give 0.5908 s moving toward, 1.0571 s moving away and
1.0571 s stationary. Body state is inert in interaction as well as in isolation.

## A3.1c Interaction: truncation × incoming momentum

4.0 m target, integrated for a window shorter than the leg:

| entry speed | 0.25 s | 0.50 s | 0.75 s | 1.50 s |
|---|---:|---:|---:|---:|
| 0.0 | 0.152 m | 0.654 m | 1.506 m | 4.000 m, reached |
| 3.0 | 0.925 m | 2.171 m | 3.478 m | 4.000 m, reached |
| 6.0 | 1.307 m | 2.613 m | 3.920 m | 4.000 m, reached |

**The integrator honours carried momentum properly** — a body entering at 6 m/s
covers 8.6× as much ground in the first quarter-second as one from rest. The
model is not the problem; the wiring is. `_committed_path` never gives it the
velocity to honour.

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

## A5b Personality and coordination — present in the claim, absent from the walk

The spec asks for personality effects on movement specifically, and the answer
splits cleanly, so it is worth stating both halves rather than one.

**Temperament decides who claims.** `_second_contact_claim_score` adds
`_second_contact_temperament`, which is `ego`, `leadership` and `aggression` each
centred on 50 and weighted 0.050 / 0.025 / 0.015. `attempt_judgment.gd` runs the
same currency on whether a recognised overreach is attempted at all. So
personality changes *which body is sent*, and therefore which body moves — a real
movement consequence, arriving through the claim rather than the locomotion.

**Teammate position is also read, and only for claim quality.**
`_support_term(support_count, nearest_teammate_meters)` is consumed at `:1235`
(home reception) and `:4112` (opponent reception), with a crowding floor at
1.05 m and a help peak at 2.40 m — a teammate too close makes the reception
*worse*. Defence records `nearest_teammate_meters` in metadata at `:6489`
without consuming it.

**Neither reaches locomotion.** No personality term and no teammate distance
appears in `rally_movement_system.gd`, in `_travel`, in `_committed_path` or in
`_reached_point`. The game knows where a body's teammates are and uses it to
decide who should play the ball and how well; nothing uses it to decide where a
body walks. That distinction is the precise shape of the B-series defect, and it
is why "teammate occupancy is absent" — the claim made in the first draft of the
A9 matrix — was too strong and is corrected there.

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
| 0.50 m | 529 | 21.2 s | **1** |
| 0.72 m | 1,015 | 40.6 s | **18** |
| 0.90 m | 1,750 | 70.0 s | **61** |

**The cluster column was wrong in the first version of this document and is
corrected here.** It read 129 / 0 / 0. Two bugs: adjacency was counted inside the
clearance loop, so a pair falling under all three thresholds was counted three
times, and a `break` let only the tightest clearance ever record. A wider
clearance reporting *fewer* clusters than a tighter one is impossible, and that
is how the bug announced itself. Three-body clusters are rare at 0.50 m — one
instant in 11,974 — and become common only at 0.90 m.

### Which phase produces the traffic

Pair-samples inside 0.50 m, by the flight being drawn and the side:

| flight | side | samples |
|---|---|---:|
| RECEPTION | opponent | 183 |
| DIG | opponent | 135 |
| POINT | home | 60 |
| BLOCK | home | 48 |
| SET | opponent | 38 |
| DIG | home | 29 |
| POINT | opponent | 25 |

Conflicts are not spread evenly: they concentrate where several bodies converge
on one ball — the receiving side during a reception and the defending side
during a dig. 85 samples occur during POINT, the dead ball, where no body has a
phase intention at all; that is `BACKLOG.md`'s dead-ball tail showing up as
spatial nonsense rather than as a separate problem.

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

### Confirmed at 600 rallies, with one figure corrected upward

63,564 instants, **403,710 pair observations**, 5.5× the first sweep. The rates
hold; two things change.

| measure | 120 rallies | 600 rallies |
|---|---:|---:|
| minimum separation | 0.000 m | **0.000 m** |
| p01 | 0.606 m | 0.580 m |
| p05 | 1.347 m | 1.324 m |
| p50 | 4.083 m | 4.046 m |
| pair-samples inside 0.50 m | 529 (0.72%) | 3,142 (0.78%) |
| court-seconds inside 0.50 m | 21.2 s | **125.7 s** |
| instants with 3+ bodies inside 0.50 m | 1 | **32** |
| instants with 3+ inside 0.90 m | 61 (0.51%) | 342 (0.54%) |
| slots publishing no path | 27% | 24% |

**The three-body cluster rate at 0.50 m was under-measured, and the reason is that
it was one observation.** 1 instant in 11,974 is not a rate; 32 in 63,564 is
0.050%, six times the point estimate the smaller sweep gave. Nothing changed in
the code — the first number was a single event being read as a frequency, which
is the same class of error as a threshold measured against the wrong
distribution. The 0.90 m row, which had 61 observations to begin with, moves by
6% and confirms the sweep itself is stable.

Stratification also sharpens, and one row moves rank:

| flight | side | 120 | 600 | share at 600 |
|---|---|---:|---:|---:|
| RECEPTION | opponent | 183 | 786 | 25.0% |
| DIG | opponent | 135 | 599 | 19.1% |
| **BLOCK** | home | 48 | **463** | **14.7%** |
| POINT | home | 60 | 407 | 13.0% |
| DIG | home | 29 | 278 | 8.8% |
| POINT | opponent | 25 | 184 | 5.9% |
| ATTACK | home | — | 139 | 4.4% |
| SET | opponent | 38 | 135 | 4.3% |
| ATTACK_COVERAGE | both | — | 75 | 2.4% |

BLOCK on the home side was the fourth-largest source at 120 rallies and is the
third at 600, at nearly ten times the count — a three-body wall converging on one
point is exactly the geometry that produces this, and the small sweep under-sampled
it. The reception/dig concentration is unchanged as the headline.

The causal split is unchanged: **2,856 of 3,142 (90.9%) are both bodies moving**,
245 both parked, 41 one moving. Converging traffic, at both sample sizes.

**`ATTACK_COVERAGE` is now measured rather than guessed at.** It appeared in 2 of
120 rallies, which was too thin to conclude anything; at 600 it appears in **20**
(3.3%) and contributes 75 of the 3,142 close samples (2.4%). It is genuinely
rare, and it is *not* disproportionately conflict-prone — its share of the
traffic is slightly below its share of the rallies. That closes it as a candidate
hot spot rather than leaving it open.

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

**At 600 rallies the rate holds and the tail extends, which is what a tail does.**

| measure | 120 | 600 | rate at 120 | rate at 600 |
|---|---:|---:|---:|---:|
| outside x | 34 (worst 0.32 m) | 212 (worst 0.34 m) | 0.28% | 0.33% |
| outside y | 260 (worst 1.00 m) | 1,276 (worst 1.00 m) | 2.17% | 2.01% |
| **past the net plane** | 305 (worst 0.88 m) | **1,669 (worst 0.96 m)** | 2.55% | 2.63% |

2.6% of every sampled body-instant is on the wrong side of the net, at both
sample sizes — this is not a rare seed. The worst case moves 0.88 m to 0.96 m
(seed 61575, player 102, opponent side) because five times the sample reaches
further into the same distribution; the y excursion, which is bounded by
legitimate pursuit, does not move at all. A quantity that grows with sampling and
one that does not is the distinction between a tail and a limit.

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

## A8b They also disagree about what the leg *ends* with

Same leg, both models, exit speed in m/s:

| distance | entry | closed form exit | integrated exit | reached |
|---|---:|---:|---:|---|
| 1.5 m | 0.0 | 4.194 | **0.000** | true |
| 1.5 m | 6.0 | 5.227 | **0.000** | true |
| 3.0 m | 0.0 | 5.227 | **0.000** | true |
| 3.0 m | 6.0 | 5.227 | **0.000** | true |
| 5.0 m | 0.0 | 5.227 | 5.227 | false |
| 5.0 m | 6.0 | 5.227 | 5.227 | false |

**They agree exactly when the body does not arrive, and disagree completely when
it does.** A completed leg ends at rest in the drawn path and at full speed in
the closed form.

This matters because `live_velocities` is written from the *closed form*, while
the body on screen follows the integrated path. So the stored momentum says a
body that has just reached its target is still travelling at 5.2 m/s.

### Every production consumer of the wrong number

Three writes, all from `_travel` — the closed form — and all of the reads:

| site | what it is | what receives the value |
|---|---|---|
| **w** `:2349` | home hitter's approach leg | `live_velocities[hitter.id]` |
| **w** `:5197` | opponent hitter's approach leg | `opponent_live_velocities[...]` |
| **w** `:7096` | home continuation leg | `live_velocities[hitter.id]` |
| **r** `:2229` | home attack preparation | `hitter_actor.apply_position(...)` → `ApproachMechanicsModel.prepare_for_attack` → `prepared_velocity_mps` |
| **r** `:5071` | opponent attack preparation | the same, opponent side |
| **r** `:6968` | continuation transition state | **every home player's `velocity`**, in a loop over `transition_state.home_players` |
| **r** `:11938` | `_candidate_actors` defender search | `actor.velocity` for every candidate |
| **r** `:11535` | `_commit_facing` | reads `exit_velocity` **off the leg directly**, not via the store, and sets `player_facing` from it |

**The first version of this section named two consumers. There are five, and the
widest was the one missed:** `:6968` seeds the velocity of all six home bodies in
the continuation transition, not just the hitter's. `_commit_facing` is a separate
path again — it never touches `live_velocities`, it reads the same closed-form
number straight off the leg dictionary, so fixing the store alone would leave
facing derived from a velocity the body does not have.

`:2229` carries a NOTE recording that this store was previously returning zero
for 91% of hitters. That is the same plumbing, and it means the store is not
vestigial — it was deliberately wired, and it is now carrying a number that is
wrong in the other direction whenever the body arrived.

It does not propagate into the next *drawn* leg only because `_committed_path`
ignores entry velocity entirely — one defect masking another. Fixing the
momentum wiring without fixing this would start feeding a wrong number into
every leg.

**One further divergence was isolated, by accident and then deliberately.** With a target
off the court, the closed form times the journey to it and the integrator clamps
the body at the boundary: a target at `x = 1.167` produced a landing exactly
1.500 m short — the clamp distance, in every row. The two models do not agree
about whether a body may be off court.

---

# Validation

| control | result |
|---|---|
| playback corrections | 0 of 8,733, three runs, byte-identical |
| `audit_embodied_locomotion.gd` | re-run, byte-identical |
| `audit_six_player_space.gd` | re-run, byte-identical |
| `audit_target_sources.gd` | re-run, byte-identical |
| balance probe, 700 rallies | reproduces `a41f285` exactly |
| production behaviour changed | **none** — this pass added instruments and one test, and altered no production file |

## Suite

**2 of 2,267 checks fail**, and they are the two that fail on `origin/main`
unchanged — `_test_tempo_buys_flight_time` and
`_test_playback_geometry_is_drawable`. The predecessor is 2 of 2,265, measured on
this tree and recorded in `CLAUDE.md`.

**Two checks written, two gained.** `_test_reachability_agrees_across_the_court`
emits exactly two on its passing path, and `4f67cdb` is the only commit since the
predecessor to touch `tests/`, `scripts/` or `scenes/` at all. So the delta is
fully attributable to authorship and no sampling population changed size — which
is the only count a pass that added instruments and one test is allowed to
produce.

## Resolve cost, re-measured with a named instrument

`tools/probe_resolve_cost.gd`, 200 rallies from seed 61000, 10 warm-up resolves
discarded, `resolve_active_rally` alone on the clock:

| run | median | mean | p90 |
|---|---:|---:|---:|
| 1 | 117.3 ms | 114.5 ms | 240.6 ms |
| 2 | 116.4 ms | 111.1 ms | 234.4 ms |
| 3 | **121.7 ms** | 116.0 ms | 247.7 ms |

Median across three runs spans 2.3%, so the figure is stable enough to be a
baseline. p10 is 3.7 ms and the worst rally is 503 ms — an ace and a
twenty-contact rally are two orders of magnitude apart, which is why the median
is quoted and not the mean. The mean tracks the outcome mix and will move
whenever balance moves; the median tracks the resolver.

**This is not comparable to the contract's 62.8 ms/rally, and reporting it as a
1.9× regression would be the exact error this repository keeps writing down.**
Two reasons. The instrument that produced 62.8 is not in the repo — this probe
had to be written to take the measurement, and it is not the one that produced
the recorded number. And the hardware is different: 62.8 was measured at
`8bb09ca`, this on a remote container. A figure is worth the commit *and the
instrument* it was measured on.

What can be said without either: **this pass altered no production file**, so
whatever the resolve cost is, this audit did not move it. 117 ms is published as
a new baseline with its instrument named, so the next reader has something they
can actually reproduce.

## Regression guard added

`tests/test_runner.gd::_test_reachability_agrees_across_the_court` sweeps
distances 1–6 m, entry speeds 0–6 m/s and entry angles 0/90/180° on legal
targets and asserts the closed form and the integrator land within 1 cm.

The existing `_test_authoritative_movement_path_contract` already asserts this at
*one* target and one mode. It was broadened rather than duplicated because the
audit's finding is precisely that geometry decides the answer: on-court targets
agree to 0.000 m, and the divergence that exists is about targets off the court.
The new test is deliberately silent about those.

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

## Final matrix

| factor | current status | causal in production? | physically causal? | contexts tested | interactions / confounders | defect? | severity | recommended action |
|---|---|---|---|---|---|---|---|---|
| position | supplied everywhere | yes | yes | all 6 modes, 6 profiles, 120–600 rallies | — | no | — | preserve |
| carried velocity | stored, mostly unconsumed | partly — approach timing and candidate search only | **no** for committed legs | 5 speeds × 5 angles × 6 modes; 1,044 production leg pairs | × facing (none), × truncation (integrator honours it) | **yes** | high | wire into `_committed_path` / `_reached_point` after the exit state is reconciled |
| exit velocity | two models disagree | yes — **five** production consumers, incl. all six home bodies at `:6968` | **wrong when the body arrives** | 3 distances × 3 entry speeds | reached vs not reached | **yes** | high | reconcile first; it is the number a momentum repair would propagate |
| facing | modelled, plumbed, overwritten with zero | no | no | 5 angles × 3 distances × 6 modes × 6 profiles | × velocity: additive, no interaction | **yes** | medium (0.14–0.17 s) | supply it, or delete `facing_fit` as dead weight |
| body/action state | not an input | no | no | 6 states × 3 directions | × direction: inert | no — a documentation error | low | correct the assumption; do not build a consequence |
| recovery | upstream window gate | yes, as a delay | indirectly | call-site trace | no in-model interaction to test | no | — | preserve |
| acceleration | full input | yes | yes | 3 values + 6 profiles | dominant term | no | — | preserve |
| fatigue | full input | yes | yes | 3 values | — | no | — | preserve |
| mass | full input | yes | yes, weakly | 3 values + 6 profiles | — | no | — | preserve; note 0.030 s across 58–118 kg |
| perceived ball state | reaches reachability | yes | **yes** at 4 of 18 `_reached_point` sites | call-site trace | — | no | — | preserve |
| target source priority | 4 publishers, fixed order | yes | yes | 3,802 body-events | 51% contested; 10% of those disagree, worst 4.14 m | no, but load-bearing | medium | document; any new consumer must apply the same order |
| teammate occupancy | read for claim quality, **never as a route constraint** | yes, for *who* plays the ball; no, for where a body walks | no | `_support_term` at 2 sites; 0 sites in the movement system | crowding floor 1.05 m vs help peak 2.40 m | **yes**, as a route input | high | see B; the plumbing exists and the solve does not read it |
| personality / temperament | claim input only | yes — it changes which body is sent | no | `_second_contact_temperament`, `attempt_judgment.gd` | ego/leadership/aggression, weights 0.050/0.025/0.015 | no | — | preserve; it is not a locomotion factor and should not become one |
| court bounds | integrator clamps, closed form does not | yes | yes | 60 controlled rows + 600 rallies | — | **yes** | medium | make the two agree about off-court legality |

## A. Physical locomotion defects

| # | finding | evidence | severity |
|---|---|---|---|
| A1 | **Reversal is free.** Moving away from the target at any speed costs exactly what standing still costs. | A3.1, all of 0/1.5/3/4.5/6 m/s at 90–180° identical to stationary | high — it makes momentum one-directional |
| A2 | **Carried velocity does not reach the committed solve.** 0 of 16 `_committed_path` and 0 of 18 `_reached_point` sites pass it. | A1/A2 call-site census | high |
| A3 | **Facing is modelled and never charged**, and is overwritten with a value meaning "no penalty". | A3.2; 0 of 16 sites supply it | medium — worth up to 0.151 s |
| A4 | **Body state is not a locomotion input.** | A3.3 and A3.3b, six states identical in isolation and in interaction | low as a defect, high as a documentation correction |
| A5 | **The two models disagree about a leg's exit state.** Closed form 4.2–5.2 m/s, integrated 0.000, whenever the body arrives. `live_velocities` stores the closed form; the drawn body follows the integrator. | A8b | high — it is the number a momentum repair would propagate |

## B. Six-player spatial-coherence defects

| # | finding | evidence | severity |
|---|---|---|---|
| B1 | Same-team bodies occupy the same point. Minimum separation 0.000 m; **3,142 pair-samples and 125.7 s inside 0.50 m over 600 rallies**, 0.78% of all pair observations. Three-body clusters: 32 instants at 0.50 m, 342 at 0.90 m. | A6 | high |
| B2 | **90.9%** of those are **both bodies moving** — converging traffic, not duplicated standing positions. | A6 context split, stable 120→600 | informs the fix |
| B4 | Traffic concentrates on RECEPTION (25.0%) and DIG (19.1%) on the receiving/defending side, then the **home BLOCK (14.7%)**, plus 18.8% during the dead ball where nothing has a phase intention. | A6 stratification at 600 | directs the fix |
| B3 | Bodies cross the net plane by up to **0.96 m**, **1,669 samples — 2.6% of every body-instant**, at both sample sizes. | A7 | medium |

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

- **24% of player-rally slots publish no path** and are invisible to A6. The
  conflict numbers are a lower bound and the true rate is unknown. The figure was
  27% at 120 rallies; the wider sweep does not close it, it only measures it
  better.
- **The D1 split's actual cause is not identified.** Controlled geometry agrees;
  the 46 disagreeing production legs must come from waypoints, mode, or the
  clamp, and no discriminating test was run.
- **Claim and coordination were not isolated.** A4 enumerates which *publisher*
  wins; it does not establish which upstream decision chose that publisher's
  target, nor whether claim priority or assertiveness changed who moved. A
  controlled scenario differing only in claimant would be the test.
- **Recovery × deadline has no interaction to measure inside the model.**
  `rally_movement_system.gd` mentions recovery twice, both times copying
  `recovery_time_seconds` onto an opportunity object, and never in its locomotion
  arithmetic. Recovery acts upstream by shortening the available window, so the
  interaction lives in the callers, not in the solve. Recorded as resolved rather
  than untested.
- **Attribute interactions were not crossed.** Six bodies were compared whole;
  acceleration × mass × fatigue were not varied against each other.
- **Teammate occupancy × route geometry was not tested**, because no production
  mechanism consumes teammate positions as a *route* constraint — so there is
  nothing to vary. That is an absence, not a measurement. It is not an absence of
  data: `_support_term` already reads `nearest_teammate_meters` for reception
  quality (A5b), so a repair would be wiring an existing quantity into the solve,
  not inventing one.

## Search saturation

The spec asks the audit to keep widening until the search stops producing new
kinds of finding. It has. The evidence for that claim is that the last widening
changed *numbers* and no *classes*:

| axis | how far it was taken | what the last widening added |
|---|---|---|
| production sampling | 120 → 600 rallies (5.5× pair observations) | sharper rates, one rank change (home BLOCK 4th → 3rd), one corrected estimate that had been n=1. **No new defect.** |
| leg continuity | 1,044 → 5,800 leg pairs | every proportion within 0.5 points; the worst gap is the identical 4.781 m |
| locomotion counterfactuals | 6 modes × 6 body profiles × 5 entry speeds × 5 entry angles × 3 distances, plus three explicit interaction crossings | facing × velocity additive with no interaction; body state × direction inert in interaction as in isolation; truncation × momentum honoured. **No interaction produced an effect its factors did not have alone.** |
| reachability split | 60 controlled rows across distance × entry speed × entry angle | 0.000 m agreement throughout, which *falsified* the spec's own hypothesis rather than confirming it |
| call-site census | exhaustive, not sampled — 16 `_committed_path`, 18 `_reached_point`, 33 `_movement_time`, 7 `_travel` | nothing left to widen; the population is the whole codebase |
| target-source contest | 3,802 body-events, every event | — |

Saturation is a claim about the questions asked, not about the system. Four
things remain open and they are open *by construction*, not for want of samples —
each needs an instrument this audit does not have:

1. **The D1 split's cause.** Controlled geometry agrees exactly, so the
   discriminating variable is waypoints, mode, or the clamp. A two-leg waypointed
   fixture would answer it; running more rallies will not.
2. **The 24% of slots that publish no path.** They cannot be sampled by an
   instrument that reads published paths. Closing this needs a different source,
   not a larger `rallies=`.
3. **Claim versus coordination.** A4 says which publisher wins; isolating which
   upstream decision chose it needs a scenario that differs only in claimant.
4. **Attribute cross-interactions.** Six whole bodies were compared;
   acceleration × mass × fatigue were not crossed against each other. A3.4 makes
   this low-yield — mass moves the answer by 0.030 s across a 60 kg range — but it
   is untested, and low-yield is a prediction, not a measurement.

## Minimum evidence-backed implementation sequence

0. **Reconcile the exit state first.** The closed form and the integrator
   disagree about what a completed leg ends with, and `live_velocities` stores
   the losing answer. Wiring momentum in before fixing this would propagate
   5.2 m/s into every leg that should begin at rest — a repair that makes the
   simulation worse in a way the current disconnection hides.
1. **Then pass carried velocity into `_committed_path` and `_reached_point`** —
   the plumbing and the store already exist; this is wiring, not a new model,
   and A3.1c shows the integrator already honours momentum correctly when given
   it.
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
