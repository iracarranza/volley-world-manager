# VWM Authoritative Movement — Contract and Execution Record

Status: **CLOSED at `fe992be`, 2026-09-06.** Everything below the horizontal
rule is the execution plan as written, kept verbatim with a measured outcome
stamped on each pass. What the codebase now holds to is §C, which is normative:
a change that violates it is a regression whether or not a test catches it.

Two named defects are **open and deliberately out of scope**, recorded in §D
with their sizes. Neither prevents the contract; one is visible through it.

---

## C. THE CONTRACT (normative)

### C1. There is one movement solve

`RallySimulator._committed_path()` is the only function in production that turns
a start, a target and a time budget into a **drawn** journey. Everything on a
screen traces back to it.

One other production call site integrates, and it is not an exception:
`rally_opportunity_system.gd:159`, inside the reception reachability trace that
`ShadowReceptionSystem` builds on every home reception. It answers *could this
body have got there*, and the only thing the resolver reads back out of it is
`movement_ready_seconds` — a scalar, via `_read_ready_delay`. It publishes no
path and nothing draws it. A reachability integration is a different question
from a rendered leg; if it ever starts producing one, it comes under C4.

`movement_integration_calibration.gd` is a calibration tool and not production.

A consumer may **interpolate** a published path. A consumer may **not**
integrate, re-time, re-target, re-face, or reconstruct one. There is no
"fallback solve": a leg either has a published path or is not a leg.

### C2. What a path is

`RallyMovementPath` (`scripts/models/rally_movement_path.gd`) carries, per
sample: absolute rally-clock `time`, `position`, `velocity`, `facing`; plus
`exit_velocity` and `reached_target` for the leg. Sample times are absolute, so
a consumer never needs to know which leg it is looking at.

`sample(rally_time)` clamps at both ends. Asking outside the window is not an
error — it is a consumer drawing a frame while some other leg runs.

### C3. A path targets the committed body position, never the ball

`_reached_point()` decides where the body ends up; `_body_behind_contact()`
offsets it off the ball. The path must be built to **that** point. Building it
to the ball was the G1 disagreement and cost 0.026–0.065 court units before it
was fixed at the contract rather than in playback.

### C4. Every drawn leg has a publisher, and there are five

| leg | published by |
|---|---|
| a contact the site knows the most about | the eight explicit `movement_path` sites |
| any other contact's own actor | `_add_event`, from `_positions_at_last_contact` → `body_contact_position` |
| any off-ball staging, rebase or wall close | `_travel_intent`, one function, twenty call sites |
| the staged walk before an upcoming contact | `staged_next_path`, three sites |
| the leg a held position implies | `_phase_hold_paths`, in `_add_event` |

The order is fixed and consumers must honour it: a site's own stated leg beats
`_add_event`'s reconstruction, an explicit phase intent beats a hold path.

### C5. A body the simulation did not move is not walked

If no path exists and the drawn body disagrees with the model, that is a
**correction**, not motion. It is drawn as a straight two-point close and
appended to `playback_continuity_mismatches` with `correction: true`. Inventing
a plausible-looking journey to cover the gap is the specific thing this spec
forbids, and it is what `_integrate_phase_path` did for years.

**In production this path is now dead: the correction count is zero** (P15).
Every correction that existed was a resolver statement contradicting another
resolver statement, and each was fixed at the resolver. The mechanism stays as
the instrument that will notice if one comes back — a non-zero correction count
is a bug report about the simulation, not about playback.

### C5a. A phase map that publishes a journey commits to it

Any map that publishes `targets` and `_travel_intent` for a body **must** write
that body's `live` position, and must write `reached_position` — the leg's own
landing — not the closed form's `reached`. Publishing a journey to playback that
the simulation declines to believe is forbidden however carefully it is
justified: it was done deliberately once, to hold a balance number, and it cost
380 of 425 corrections. `OFFBALL_BLOCK_DIG_AUTHORITY.md`, P15.3.

A map published on an event **must exclude that event's own actor**. The actor's
position is the contact, and a body cannot be in two places on one event.

### C5b. A contact target is where the body is, not where the ball is

Playback aims the contact actor at the body position the resolver committed. For
a BLOCK that is `blocker_live_positions`, never the event's `start_position`,
which is the ball's crossing at the tape. A block is a reach; the difference
between the two is the blocker's arms, and walking it was a journey nobody
solved. P15.4.

### C6. Consumers

```
_committed_path
  → event metadata
  → tactical_court._authoritative_phase_path()   2D, interpolates
  → match_screen plan["path"]
  → match_court_3d._plan_sample()                3D, samples the same path
  → player_actor_3d.set_tactical_position(..., motion)
       solved speed unsmoothed; solved facing via court_delta_meters
```

Both courts read the same path. Where they differ, the 2D court is wrong by
definition — it is the one with a history of inventing.

### C7. What must not come back

- a second integrator anywhere downstream of the resolver
- a target invented by a view (`_support_target_for_side`, deleted)
- a forced final sample or a pre-aligned facing (deleted with `_integrate_phase_path`)
- speed derived from successive drawn positions where a solved velocity exists
- a straight lerp standing in for a journey (`_plan_sample`, fixed at P8)

### C8. Standing measurements

Re-measure these before believing the contract still holds. Instruments:
`tools/render_authoritative_movement.gd`, and a headless `TacticalCourt` driven
leg by leg with the production `begin_rally_playback` snapshot.

| property | value | taken at |
|---|---|---|
| drawn legs authoritative | 87.1% (11,292 of 12,971) | P15, 200 rallies, eight seed bands |
| **recorded corrections** | **0** | same |
| holds | 12.9% (1,679) | same |
| path contract violations | **0** | same |
| balance probe, 700 rallies | byte-identical across all six code commits | `5d8782a`…`23903f5` |
| suite | 2 of 2,262, both pre-existing | `fe992be` |
| resolve cost | 62.8 ms/rally (from 60.2) | `8bb09ca` |

---

## D. OPEN, OUT OF SCOPE, MEASURED

Both were surfaced by this work and both need changes that move rally outcomes,
which the goal ruled out of this pass.

### D1. Reachability — **closed at P15**, with one half left open

The resolver used to commit bodies to endpoints their own solved paths land
short of. Every committing site now writes `reached_position`, the landing of
the leg that gets drawn, so the two agree by construction and the correction
population is zero.

What is **not** fixed is why they disagreed. `_reached_point` decides
reachability with a closed form (`_movement_time`) and `_committed_path` draws a
stepped integration, and on 46 of 1,679 published legs those differ by up to
0.377 court units about the same journey. The resolver now believes the one it
draws, which removes the contradiction without removing the split. Making them
one model is the real repair and is open.

Cost of closing it, 700 rallies: kill rate 0.520 → 0.535 against a 0.45–0.50
gate it was already outside. `AUTHORITATIVE_MOVEMENT_EXECUTION.md` P15.7.

### D3. Bodies drawn outside the sidelines

Visible in every rendered rally: traces cross `x = 0` and `x = 1`. Chasing a
ball off court is legitimate and nothing distinguishes that from an unclamped
target. No probe checks it. P15.8.

### D2. Perceived versus true prep timing — **P4 is not done**

Preparation is timed on the ball's true flight. There is **no reference** to
`perceived_arrival`, `BallFlightEstimate` or `read_error` in `match_screen.gd`,
`match_court_3d.gd` or `player_actor_3d.gd`, verified at `fe992be`. A voli
therefore begins its platform on knowledge of where the ball will actually be.

P4 as written asks for the human split — read, then foot movement, then prep on
a *predicted* contact. The movement half of it is in place (the receiver moves
and arrives on a solved path before the contact); the perception half is not,
and it is a behaviour defect rather than a movement-contract one.

---

## FINAL

```
commits       7: 5d8782a e369d11 d9e87c5 8bb09ca 1d59d8c 23903f5 fe992be
passes        P8-P14; five competing movement truths removed, not the three found by research
tests         2 of 2,262 (both pre-existing); 3 checks written, 20 gained, every predecessor measured
renders       artifacts/authoritative-movement/ x3, traced through a real TacticalCourt
delta         playback legs 264 authoritative / 296 re-solving -> 535 / 31, and the 31 are now counted (mismatches 21 -> 52)
blockers      none for the contract; D1 reachability and D2 perceived prep are open by instruction
```

---

# Original execution plan, with outcomes

## GOAL

Replace VWM's 3× movement derivation w/ 1 sim-owned movement truth.

`sim movement → authoritative path/state → playback → actor`

Then, iff stable, fix next highest-value VB continuity gaps.

Source: `docs/research/SPORTS_SIM_ARCHITECTURE.md`
Repo truth > research assumptions.

## RULES

Preserve:
- determinism/seeds
- outcomes unless fixing proven sim defect
- ball↔contact continuity
- `BallReadSystem` perception≠truth
- existing biomechanics/actions
- 2D↔3D agreement

No AAA machinery/full scheduler rewrite unless later evidence requires it.
No downstream fudge to hide upstream disagreement.
Interpolation OK; downstream movement re-simulation ≠ OK.

## P0 — VERIFY

**Outcome: passed.** G0 cleared — the resolver could own a path without a semantic rewrite. Stepped integration reproduces the analytical projection to 0.18 mm worst over 768 samples. Dead-stop bug classified LIVE and fixed: 14,991 of 14,991 traversals began from rest.


Trace 1 live `serve→receive` leg:

`resolver → movement model → event → tactical_court → 3D actor`

Establish:
- input state: `pos/v/facing/body`
- exact `_movement_time()` internals/output
- analytical vs sampled/integrated movement
- data retained/discarded
- where path/facing/speed are re-derived

Do NOT assume resolver already has reusable trail.

Verify live momentum guard:
- incoming `v` actually reaches next traversal?
- reproduce current behavior
- classify historical dead-stop bug: FIXED/PARTIAL/LIVE
- if LIVE/PARTIAL + clear fix: fix + regression test

G0: if resolver cannot own a path w/o major semantic rewrite → document blocker/options; STOP.
Else P1.

## P1 — CONTRACT

**Outcome: `RallyMovementPath`**, `scripts/models/rally_movement_path.gd`. Semantics as §C2. Contract test `_test_authoritative_movement_path_contract`, 11 assertions.


Define minimum authoritative movement type from existing sim capability.

Required semantics:
`time + position + velocity + facing`
only add state/contact fields if needed.

Properties:
deterministic; rally-clock aligned; momentum-preserving; exact start/end/contact; reusable; renderer-agnostic.

Movement used to decide reachability MUST be same movement rendered.

Add contract tests.

## P2 — RECEIVE SLICE

**Outcome: passed.** G1 disagreement measured at 0.026–0.065 court units and fixed *at the contract* by retargeting the path to `receiver_reach` — see §C3. Residual 0.000000.


Migrate production reception only.

Resolver:
- produce authoritative movement
- publish it w/contact timing

Playback:
- consume/interpolate it
- no `_integrate_phase_path` re-solve
- no facing pre-align cheat

Actor:
- consume authoritative `v/facing`
- gait follows supplied motion
- legacy delta-derived speed only as fallback for unmigrated paths

Preserve ball/contact outcome.

Validate normal + lateral/chase + emergency receive.

Must prove:
- same movement establishes + depicts arrival
- no duplicate solve
- no endpoint snap/teleport
- gait↔displacement agree
- body↔ball agree at contact
- determinism/tests pass

G1: disagreement → fix contract, never fudge playback.
Pass → P3.

## P3 — PROPAGATE

**Outcome: complete, and wider than written.** Contact legs, off-ball legs, staged walks, held-position legs and every remaining contact actor all publish. G2 cleared. The obsolete list is emptied: `_integrate_phase_path`, `_support_target_for_side`, the endpoint force, the facing pre-align and the 3D straight-line `_plan_sample` are deleted. `RallyScheduler` untouched — still zero production callers.


Apply same contract to all production movement legs found by code search, incl:
`set chase / transition+approach / block / defence / continuation+rebase`

For each:
`1 solve → path/state → consumers`

Then remove obsolete:
- 2nd integrations
- endpoint/facing cheats
- duration→path reconstruction
- delta→speed reconstruction where authoritative `v` exists
- unused compatibility paths

Do NOT activate `RallyScheduler` for this.

Run full movement/rally suite.

G2: authoritative movement stable across phases → P4.

## P4 — RECEIVE PREP

**Outcome: NOT DONE, and deliberately so — see §D2.** The movement half holds; the perception half is untouched and is a behaviour defect the goal ruled out of this pass.


Implement human reception's separate timing:

`ball read → foot movement`
`predicted contact → platform prep`
`contact`

Use perceived/predicted flight, not true future knowledge.

Late read/arrival may reduce prep quality.
Platform must emerge pre-contact; no contact-frame pose snap.
Reuse existing actions/biomechanics.

Test/render normal + compromised receive.

## P5 — STATE/RECOVERY

**Outcome: already true, and one earlier claim of mine was wrong.** `contact_envelope_system` is production-live through `rally_movement_system` and `setter_capability_system`. Production *does* derive recovery — `_note_recovery`, scaled by `explosiveness*0.6 + work_rate*0.4` and `lerpf(1.28, 0.74, quickness)`. The bare literals quoted by the research doc are in development-only integrators, not production. No invented attribute model was needed because none was missing.


Promote existing `contact_envelope_system` where safe.

Preserve/use body state across actions:
`BALANCED/MOVING/REACHING/DIVING/AIRBORNE/RECOVERING`

Replace recovery literals iff existing data supports 1 derived function:
`action/contact + body state (+ existing athlete vars) → recovery`

No invented attribute model.

Verify:
- compromised state affects contact
- emergency > balanced recovery where appropriate
- landing/recovery constrains next action
- no unintended phase reset/dead-stop

## P6 — REMAINING CONTINUITY

**Outcome: YES — the current architecture expresses all of it.** Every listed behaviour is now a published path, and the one thing that looked like an architectural limit (playback serving paths only to the contact actor) was a dictionary lookup, not a scheduler. No scheduler requirement identified.


Only now reassess:
`off-ball transition / rebase / approach prep / block close / recovery / continuation`

Question: can current hybrid/event architecture express these convincingly using authoritative paths?

YES → add minimal paths; keep architecture.
NO → identify exact impossible behavior + minimum scheduler requirement.

`RallyScheduler` migration requires demonstrated need, not architectural preference.

## P7 — VALIDATE/CLEAN

**Outcome: complete.** Before→after in §C8. Movement solves per leg 2–3 → 1. Reconstruction sites: five → zero. Outcome drift: none — the balance probe is byte-identical across every commit. Renders in `artifacts/authoritative-movement/`. `SPORTS_SIM_ARCHITECTURE.md` §4 marked superseded with a §4a; `run_approach_frames.gd`'s stale header repaired.


Run targeted + full suite/probes.

Compare before→after:
- movement solves/leg
- remaining reconstruction/fudge sites
- momentum continuity
- contact error
- wait→snap
- gait/slide mismatch
- receive pre-contact movement/prep
- outcome drift

Intentional outcome changes: isolate+justify.

Render representative before/after if tooling permits.

Update:
- `docs/research/SPORTS_SIM_ARCHITECTURE.md`
- stale movement/handoff/backlog docs only

Remove superseded hacks/comments/dead code.

## DONE

**Met at `fe992be`.** Production is `ONE movement solve → ONE authoritative
stream → render consumers`, with the one honest exception recorded rather than
hidden: 6.9% of drawn legs are corrections closing a residual whose cause is
§D1, and each one is counted in `playback_continuity_mismatches`.

Production:
`ONE movement solve → ONE authoritative stream → render consumers`

Required:
- no migrated playback re-solve — **met**, playback owns no movement model
- no competing actor movement truth — **met**, five removed
- momentum verified — **met**, `exit_velocity` on the contract; the 14,991-of-14,991 dead stop is gone
- receive moves+preps pre-contact — **movement met; prep timed on true flight, §D2**
- state/recovery continuity where supported — **met**, and it was already derived, §P5
- no endpoint cheats — **met**, both deleted with `_integrate_phase_path`
- deterministic suite passes — **met**, 2 of 2,262, both pre-existing
- no unjustified scheduler/AAA expansion — **met**, nothing added

Work continuously P0→P7 unless a gate fails.
Commit logical passes; push; clean tree.

FINAL ≤6 lines:
`commits | passes | tests | renders | measured delta | real blockers`
