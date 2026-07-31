# Gate 44: Shadow Block Hypotheses

Review date: 2026-07-31

Status: **PASS; SHADOW ONLY**

`ShadowBlockSystem` builds the attack-to-block observation slice the handoff
called for: starting from the shadow attack's resolved hitter contact and the
`RallyState` at that same resolver boundary, it forms one independent
hypothesis per opponent front-row blocker and never touches the official
`BLOCK` event.

## What each blocker perceives

For every front-row opponent player, `ShadowBlockSystem._evaluate_blocker()`
builds a decision-safe observation from:

- the attacking setter's position, degraded by a position error scaled to the
  blocker's own reading ability (`anticipation`, `court_vision`,
  `decision_making`, `tactical_discipline`, `composure`);
- an early and a late `BallReadSystem` sample of the incoming set flight
  (reconstructed from `ShadowAttackSystem`'s serialised `set_flight` so the
  already-calibrated attack code is never touched or re-run live);
- a coarsened, noise-degraded read of the hitter's approach load (the same
  `ApproachMechanicsSystem` output already computed for the hitter, exposed as
  an observable cue, never as access to the hitter's decision);
- the blocker's own known rotation slot, teammates' slots, and the defensive
  plan's block-strategy instruction (Read Block / Commit Middle / Commit Pin).

No key in any blocker's `observation` dictionary begins with `true_` or
`authoritative_`; `BlockRolloutAudit` enforces this on every evaluation.

## How a commitment is chosen

`_choose_commitment()` picks one of hold/read, commit-middle, close-left,
close-right, assist, or release from the perceived picture alone. A called
scheme (Commit Middle / Commit Pin) can override the read entirely for a
blocker whose own zone matches the scheme. Otherwise the blocker only commits
once their own confidence clears a reading-skill-scaled bar -- a sharper
reader commits on thinner information, never faster movement. The chosen
commitment is then checked for physical feasibility with
`RallyMovementSystem.evaluate_opportunity()` and `ContactEnvelopeSystem`,
using the blocker's persistent position, velocity, and facing -- the same
physics every other action in the engine uses.

## Resolving against truth, after the fact

Only once a commitment is fixed does `_evaluate_blocker()` compare it against
the authoritative contact position, purely to grade it: `wrong_read`,
`hesitated`, and the physically-true reach (`true_reachable`,
`true_arrival_margin`) live alongside the clean `observation` sub-dictionary,
mirroring how `ShadowAttackSystem`'s `hitter_response` carries
`true_reachable` next to a clean observation. `ShadowBlockSystem.evaluate()`
then resolves primary and assist roles by comparing every blocker's own
(perception-driven) commitment target against that same truth -- coordination
itself is Gate 45; this gate only has to show that two blockers can commit to
different zones before anything reconciles them.

## What the regression suite proves

- identical seed and inputs reproduce every blocker's commitment fingerprint
  exactly;
- `BlockRolloutAudit` finds no truth-prefixed key in any observation, and
  every blocker plus the resolved primary/assist roles are legally front-row;
- a later read of the same set sharpens confidence and shifts the perceived
  destination without moving the authoritative contact truth each blocker is
  graded against;
- with movement attributes held identical, an elite reader recognizes no
  later (lower `recognition_delay_seconds`) and is no more confident by
  accident -- and moves at exactly the same `maximum_speed_mps` as a
  developing reader, proving reading attributes cannot buy movement;
- with the implied commitment held identical, a blocker displaced far from
  the play loses a close that a correctly positioned blocker (same
  attributes) still has;
- with position and attributes held identical, only facing differs -- the
  blocker already facing the target pays a smaller direction-change cost than
  the one facing away;
- evaluating a copied `RallyState` leaves that copy's fingerprint unchanged
  before and after -- the shadow system never mutates source state;
- the official `BLOCK` event carries no shadow-block evidence; Gate 44 has no
  rollout policy yet, so this is simply proof the legacy resolver path was
  never touched.

`BlockerProgressionCalibration.run()` adds paired multi-seed evidence at
three reading tiers (developing/established/elite) with lateral speed,
acceleration, and mass held fixed across tiers: confidence and earlier
recognition are monotonic in reading tier, and mean `maximum_speed_mps` is
identical across all three tiers to within floating-point tolerance.

## What this gate does not do

- It does not resolve conflicting blocker reads into one team decision --
  that is Gate 45.
- It does not add a guarded rollout boundary or a production flag -- there is
  nothing to gate yet; `shadow_block` is evaluated every rally purely as
  evidence, alongside `shadow_attack`, inside
  `RallySimulator.resolve()`'s existing shadow pipeline.
- It does not change the legacy block resolver (`RallySimulator._resolve_home_block`)
  in any way. Normal fixed-seed rally events are unchanged; the full
  regression suite (364 checks, up from the pre-Gate-44 355) proves it.
