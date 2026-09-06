# Embodied Movement Continuity

## Status

Execution spec. Implements the minimum evidence-backed sequence from `docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md` after that audit reached DONE.

Repo truth wins over this document. Preserve the authoritative movement boundary established by `docs/specs/AUTHORITATIVE_RALLY_MOVEMENT.md`.

## Goal

Make consecutive production movement legs belong to one continuously embodied player state:

`authoritative path N -> actual exit position/velocity/facing -> brake/redirect/turn/accelerate -> authoritative path N+1`

Do not add a new locomotion model. Reconcile and wire the physical state the existing authoritative movement machinery already represents.

## Evidence this pass is responsible for

The completed audit established:

- 5,800/5,800 sampled consecutive production legs begin at rest; 801 predecessors ended moving >0.4 m/s.
- 1,482/5,800 leg boundaries differ by >10 cm; 569 are `phase_intent -> phase_intent`.
- `_committed_path`: 0/16 sites receive carried velocity; `_reached_point`: 0/18.
- The integrator honours incoming momentum when supplied.
- Reversal is free: perpendicular/away momentum is discarded rather than arrested.
- Facing cost exists (~0.14-0.17 s in controlled cases) but production supplies no meaningful entry facing.
- Closed-form and integrated movement disagree about exit velocity on completed legs; five production consumers use exit velocity.
- Six-player traffic is real but timing-sensitive: 3,142 same-team pair-samples <0.50 m over 600 rallies, 90.9% with both bodies moving.
- Net-plane traversal is independently real (~2.6% of sampled body-instants) but its cause is not yet identified.

The audit review is the evidence authority. Do not restate or reinterpret findings without measurement.

## Non-negotiables

- Preserve `simulation-owned movement -> RallyMovementPath/state -> 2D/3D/actor consumers`.
- No playback re-solve, endpoint snap, actor-derived speed truth, target drift, or facing cheat.
- Position, velocity and facing passed between legs must describe the same authoritative physical state.
- Do not wire a known-wrong exit velocity into later legs.
- Do not restore balance by hiding a physical contradiction. Measure outcome drift and diagnose the earliest responsible layer.
- Preserve determinism/seeding and perception-vs-truth semantics.
- Do not add body-state locomotion penalties: the audit found body state is not currently a locomotion input; that is a documentation result, not authorization to invent behavior.
- Do not add teammate avoidance/collision during C0-C3. Re-measure traffic after individual locomotion timing is correct.
- Do not clamp legal off-court pursuit.
- Reception preparation timing remains outside this pass.

# C0 — Reconcile authoritative exit state

Before propagating momentum, determine the single physically correct exit state of a movement leg.

1. Trace the closed-form and stepped/integrated definitions of `reached_target`, arrival, terminal velocity and truncation.
2. Explain why completed short legs can report ~4-5 m/s closed-form exit velocity while the integrated authoritative path ends at 0.
3. Define one contract for terminal velocity for reached, unreached/truncated, waypointed/two-leg and clamped/legal-off-court cases.
4. Make `RallyMovementPath.exit_velocity`, its final sample velocity, committed live velocity and every downstream consumer agree with that contract.
5. Enumerate and validate all five production exit-velocity consumers found by the audit; search for additional consumers before editing.
6. Add targeted regression coverage that fails on the predecessor and passes on the repair.

### Gate C0

Do not begin C1 while authoritative final-sample velocity, `exit_velocity` and committed live velocity disagree for the same leg.

# C1 — Carry momentum across production leg boundaries

Once C0 is sound:

1. Feed actual prior authoritative velocity into every production `_committed_path` and `_reached_point` context where physical continuity requires it.
2. Preserve legitimate discontinuities caused by contact/landing/state semantics; do not mechanically join legs whose volleyball event genuinely resets physical state.
3. Eliminate dead-stop defaults at ordinary consecutive movement boundaries.
4. Ensure path N+1 begins from path N's committed position and physically valid exit velocity, except for explicitly classified legitimate discontinuities.
5. Exercise all six movement modes and normal/truncated/emergency/chained contexts.

Measure the 600-rally continuity population again: dead-start rate, moving-predecessor count, >10 cm gaps, publisher-pair breakdown, worst gap and representative velocity joins.

### Gate C1

A decrease in dead starts is not enough. Remaining resets/gaps must be classified as physically intentional or defects with an identified upstream source.

# C2 — Charge braking and reversal

Fix the asymmetric momentum rule at its earliest responsible layer.

Requirements:

- toward momentum may help;
- perpendicular momentum cannot disappear for free;
- away momentum must require physically meaningful arrest/redirection before acceleration toward target;
- cost must vary continuously with incoming speed and angle rather than use arbitrary categorical penalties;
- use the existing locomotion model/integrator where possible; do not create a parallel reversal system.

Re-run the audit's velocity × angle × distance × mode counterfactuals, including truncation. Required ordering for otherwise matched cases is generally `toward < stationary < strongly away` for time-to-target; document any evidence-backed exception.

C1 and C2 are separate attribution checkpoints but together form one shippable momentum milestone. Do not stop with connected momentum plus free reversal as the intended final state.

# C3 — Supply meaningful facing

Production currently models facing cost but overwrites/omits the state that would charge it.

1. Trace the authoritative facing that should enter each committed leg.
2. Supply it from committed prior state where physically meaningful.
3. Keep travel heading, volleyball/body facing and rendered facing distinct if production distinguishes them.
4. Do not pre-align solely to make an endpoint/deadline work.
5. If evidence proves `facing_fit` is not a valid physical contract, remove it rather than leaving a permanently zeroed pseudo-model; otherwise make it causal.

Re-run facing × velocity, all modes/profiles and chained production cases. Verify 2D/3D still consume the authoritative result rather than inventing orientation.

# C4 — Re-measure six-player traffic; do not preselect the fix

After C0-C3 stabilize movement timing, rerun `tools/audit_six_player_space.gd` at the audit's broad sample size and compare against the recorded 600-rally baseline.

Measure at minimum:

- pair-samples and court-seconds below 0.50/0.72/0.90 m;
- 3+ clusters;
- both-moving/parked split;
- action/flight/side stratification;
- exact overlaps and worst cases;
- previously invisible no-path slots if a sound source now exists.

Only then decide whether teammate route/priority semantics are required. If they are, produce a narrow follow-up spec based on the new population. Do not implement generic collision, bounce, slide or avoidance in this pass.

# C5 — Diagnose net-plane traversal independently

Use discriminating fixtures/instrumentation to identify whether wrong-side traversal originates in tactical target, waypoint, contact/body offset, integrator/clamp behavior, coordinate transform or another source.

Fix only if the earliest responsible layer is proven and the repair is narrow. Do not clamp all paths to the court or net plane. Legal off-court pursuit must remain legal.

If diagnosis shows a distinct subsystem/semantic decision is required, document it as a follow-up rather than expanding this pass.

# Validation after every causal change

At each C0-C3 checkpoint, and again at final state:

- targeted predecessor-failing regression(s);
- full suite with attributable delta;
- deterministic repeated probes;
- P15 authoritative-path/correction invariants;
- 700-rally balance probe with drift reported, not normalized away;
- resolve-cost probe using the named current instrument and comparable environment only;
- representative seeded long rallies plus truncated/emergency cases;
- search for newly introduced fallback/re-solve/state reset.

Do not compare performance numbers produced by different instruments/hardware as regressions.

## DONE

This pass is DONE only when:

1. completed/truncated authoritative paths have one internally consistent exit-velocity contract;
2. all production exit-velocity consumers receive that same truth;
3. ordinary consecutive movement legs inherit actual prior velocity rather than universally cold-starting;
4. reversal/braking makes adverse momentum physically causal;
5. meaningful prior facing reaches committed movement or the invalid facing model has been deliberately removed;
6. position/velocity/facing continuity is measured in production and remaining discontinuities are classified;
7. P15 has no playback reconstruction/correction regression;
8. determinism, suite, balance and comparable performance are recorded at attributable commits;
9. A6 is re-measured only after C0-C3, with no teammate-routing fix chosen from the stale baseline;
10. net-plane traversal has an evidence-backed cause and either a narrow repair or an explicitly scoped follow-up;
11. no scheduler, generic navigation/collision system, body-state penalty system, perception rewrite or animation workaround was added without a gate proving it necessary.

Continue C0 -> C5 autonomously. Stop only for a genuine evidence-backed architecture choice that cannot be resolved from repo truth.