# VWM Authoritative Movement — Compact Execution Spec

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

Define minimum authoritative movement type from existing sim capability.

Required semantics:
`time + position + velocity + facing`
only add state/contact fields if needed.

Properties:
deterministic; rally-clock aligned; momentum-preserving; exact start/end/contact; reusable; renderer-agnostic.

Movement used to decide reachability MUST be same movement rendered.

Add contract tests.

## P2 — RECEIVE SLICE

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

Only now reassess:
`off-ball transition / rebase / approach prep / block close / recovery / continuation`

Question: can current hybrid/event architecture express these convincingly using authoritative paths?

YES → add minimal paths; keep architecture.
NO → identify exact impossible behavior + minimum scheduler requirement.

`RallyScheduler` migration requires demonstrated need, not architectural preference.

## P7 — VALIDATE/CLEAN

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

Production:
`ONE movement solve → ONE authoritative stream → render consumers`

Required:
- no migrated playback re-solve
- no competing actor movement truth
- momentum verified
- receive moves+preps pre-contact
- state/recovery continuity where supported
- no endpoint cheats
- deterministic suite passes
- no unjustified scheduler/AAA expansion

Work continuously P0→P7 unless a gate fails.
Commit logical passes; push; clean tree.

FINAL ≤6 lines:
`commits | passes | tests | renders | measured delta | real blockers`
