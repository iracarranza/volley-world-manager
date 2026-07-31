# Fresh-Agent Handoff

Status: **AUTHORITATIVE PROJECT HANDOFF**

Last reviewed: 2026-07-30

Repository: `https://github.com/iracarranza/volley-world-manager`

This document is the starting point for a developer or coding model with no
conversation history. It says what runs, what remains experimental, and what
to build next. When another textbook chapter disagrees with this document,
verify the source and update both documents before implementing anything.

## Bootstrap from nothing

1. Clone or download the whole repository. The textbook explains source files;
   the textbook directory alone is enough for orientation but not implementation.
2. Treat the repository root as the working directory. Do not depend on the
   former maintainer's absolute filesystem path.
3. Read, in order:
   - this handoff;
   - [Current Implementation Status](STATUS.md);
   - [Current Rally Pipeline](part_04_match_engine/01_current_rally_pipeline.md);
   - [Migration Plan and Visible Proof](part_04_match_engine/05_migration_and_visible_proof.md);
   - [Adjusting and Extending Live Match Systems](part_04_match_engine/06_adjusting_and_extending_live_systems.md).
4. Inspect every named source symbol before changing it.
5. Run the baseline in [VALIDATION.md](VALIDATION.md). Do not assume a historical
   check count is still current.
6. Inspect `git status --short`. Existing changes belong to the current user;
   preserve them unless the task explicitly authorizes replacing them.

## Product and architectural objective

The match engine should become a persistent, information-bounded volleyball
simulation:

```text
perceived game state
        ↓
available actions from time, movement, body state, and rules
        ↓
tactical decision
        ↓
resolved physical action and new ball flight
        ↓
new player knowledge, movement, and opportunities
        ↓
RallyEvent records for explanation and playback
```

Playback presents resolved events. It must never decide contact ownership,
movement feasibility, ball trajectory, or outcome.

The management-game fantasy that this simulation must eventually support is:

> See what an athlete could become before anyone else does.

Player development should be expressed as tactical projects built from
`Tactical Need + Latent Potential + Opportunity`, not as an instant position
switch. The current engine task is still Gate 44; do not divert into building
the full development-project feature. Preserve the product contract in
[Connecting Development to Match Options](part_05_management/02_development_to_match_options.md).

## What is authoritative today

| Area | Ordinary match | Explicit development fixture |
|---|---|---|
| Whole-rally sequencing | Phase-based `RallySimulator.resolve()` | Same hybrid resolver |
| Reception ownership/contact | Official phase resolver | Audited persistent candidate may be promoted |
| Setter ownership/contact | Official phase resolver | May be promoted only after promoted reception |
| Attack ownership/contact | Official phase resolver | May be promoted only after promoted reception and setter |
| Home attack preparation | `ApproachMechanicsSystem` affects normal attack quality, jump conversion, and available attack families | Same evidence passes through the attack audit and live candidate |
| Home floor-defense geometry | Saved plan and block relationship drive phase positions and claimant geometry | Same |
| Block decision | Legacy resolver reads resolved attack geometry | Legacy resolver; a shadow block slice (Gates 44-49) runs alongside it as evidence. One audited block contact may be promoted, but only in an explicitly requested development fixture, in a debug build, on top of a promoted attack |
| 2D display | Consumes `RallyEvent` and trajectory metadata | May additionally show explicitly requested diagnostics |
| 3D display | Paused | Paused |

The four `ENABLE_CONTINUOUS_*` production flags in
`scripts/simulation/rally_feature_flags.gd` are all `false`. The four
`ALLOW_DEVELOPMENT_*` flags are all `true`; they permit explicit debug fixtures
and are not production activation.

## Implemented migration chain

- Gates 1–30 establish ball timing, player perception, persistent reception,
  audit, guarded selection, and development-only live reception.
- Gates 31–36 establish setter observations, ownership, progression, audit,
  guarded selection, and development-only live setting.
- Gates 37–42 establish attack opportunities, setter/hitter observations,
  progression, audit, guarded selection, and development-only live attack.
- Gate 43 makes approach preparation causal in ordinary home attacks and
  defense-to-counterattack continuations. Responsibility changes release time;
  the resulting run-up changes speed, lateral control, usable jump, quality,
  and available attacks.
- Gate 44 gives every opponent front-row blocker an independent, decision-safe
  observation of the shadow attack (perceived setter cues, a progressive set
  read, a degraded hitter-approach cue, known rotation, and the called block
  strategy) and a commitment chosen from that perception alone, resolved
  against authoritative contact truth only afterward. It never touches the
  official `BLOCK` event. See
  [Gate 44](../calibration/GATE_44_SHADOW_BLOCK_HYPOTHESES.md).
- Gate 48 adds the fourth selection boundary,
  `RallyRolloutPolicy.select_block_source()`, with
  `ENABLE_CONTINUOUS_BLOCK_EVENTS` off. It records a verdict under
  `shadow_summary["block_rollout"]` and holds ordinary rallies on the official
  block. See [Gate 48](../calibration/GATE_48_BLOCK_ROLLOUT_POLICY.md).
- Gate 49 closes the slice by promoting one audited block contact and its
  deflection flight through `LiveBlockIntegrator`, only in an explicitly
  requested development fixture, in a debug build, and only on top of a
  promoted attack. A block touch consumes no contact, and a promoted block
  cannot miss. See
  [Gate 49](../calibration/GATE_49_DEVELOPMENT_LIVE_BLOCK.md).
- Gates 45 through 47 complete the shadow-only block slice: a coordination pass
  in which blockers revise commitments from teammates' visible body cues and
  roles are resolved without consulting authoritative truth
  ([Gate 45](../calibration/GATE_45_BLOCK_COORDINATION.md)); a reading-tier
  sweep over set difficulties calibrating misread, hesitation, and
  coordinated-close rates with coverage guards
  ([Gate 46](../calibration/GATE_46_BLOCKER_CALIBRATION.md)); and a promotion-
  ready candidate audit covering teammate-cue privacy, movement, contact
  envelope, and role consistency
  ([Gate 47](../calibration/GATE_47_BLOCK_CANDIDATE_AUDIT.md)).

The detailed gate records are in `docs/calibration/`. They are evidence and
history, not a license to enable production flags.

## The one current next objective

The whole block slice, **Gates 44 through 49**, is complete: observation,
coordination, calibration, candidate audit, a production-off selection boundary,
and a development-only promoted contact. **The documented gate sequence is
finished. No gate is currently in flight.**

That means the next objective is a judgement call rather than a lookup, and it
should be made deliberately. Do not start a production rollout: every
`ENABLE_CONTINUOUS_*` flag is still off, and turning one on is a separately
reviewed decision that no completed gate authorizes.

Three candidates, in the order this document recommends:

**1. Mirror Gate 43 onto the opponent attack (recommended).** The opponent
attack path never calls `ApproachMechanicsSystem`, so opponent hitters have no
causal approach. This is now the weakest link in work that was just completed:
the shadow block reads a hitter-approach cue that, on the opponent side, has
almost nothing behind it. Fixing it makes Gates 44 to 49 measure something
sharper, and it is the smallest change with the largest effect on existing
evidence.

**2. Consume `set_release_interval` and `defensive_depth`.** Both are derived
and then read by nothing. Smaller and safer than the first, and a reasonable
warm-up, but it improves less.

**3. Movement fluidity, step 4.** See
[Movement Fluidity](../design/MOVEMENT_FLUIDITY_DRAFT.md). Steps 1 to 3 are
done: playback now samples a traversal built by the engine's movement model and
contributes no timing constants of its own. Step 4 makes movement
resolver-owned and authoritative for reachability, in the audit / guarded
boundary / development promotion shape Gates 47-49 used. It is the one that
moves seeds, and it also subsumes the compromise step 3 had to make --
`RallySimulator._movement_time()` and `RallyMovementSystem.project_toward()` are
separate timing paths that disagree, so playback currently renormalises the
model's traversal onto the resolver's duration. Do not start this in the same
change as anything else.

Whatever is chosen, the invariants below still bind, and the block work must not
be reopened casually: `RallySimulator._resolve_opponent_block` remains the
official path for ordinary rallies, and `LiveBlockIntegrator` must stay behind
its development fixture.

### Historical record: the shadow block hypotheses gate (Gate 44, complete)

Gate 44 built a shadow-only system that:

1. starts from the authoritative attack flight and player state only at the
   resolver boundary; **done** -- `ShadowBlockSystem.evaluate(state, shadow_attack, seed_value)`
   is called immediately after `shadow_attack` is resolved in `RallySimulator.resolve()`;
2. constructs a separate player-specific observation for each blocker; **done** --
   one independent `_evaluate_blocker()` call per opponent front-row player;
3. exposes perceived setter position/body cues, set trajectory estimates,
   hitter approach cues, known rotation, and tactical blocking instructions;
   **done**, see the "What each blocker perceives" section of the Gate 44 record;
4. never exposes keys beginning with `true_` or `authoritative_` to the blocker
   decision function; **done and enforced** by `BlockRolloutAudit.evaluate()`
   and Gate 44 test 2;
5. produces possible commitments such as hold/read, commit middle, close left,
   close right, assist, or release from the block; **done** --
   `ShadowBlockSystem._choose_commitment()`;
6. projects movement from persistent position and velocity; **done** via
   `RallyMovementSystem.evaluate_opportunity()` and `ContactEnvelopeSystem`;
7. resolves the selected perceived commitment against authoritative contact
   truth afterward; **done** -- `wrong_read`, `true_reachable`, and
   `true_arrival_margin` are computed only after the commitment is fixed;
8. records wrong reads, hesitation, solo closes, coordinated assists, arrival
   margins, and rejection reasons; **done** -- `wrong_read`, `hesitated`,
   `solo_close`, `coordinated_assist`, and the reachability fields on every
   blocker record;
9. leaves official block events and results unchanged. **done and verified**
   -- Gate 44 test 9, and the full regression suite (364/364).

Use the existing attack architecture as a pattern for Gate 45 as well:

- `PlayerObservation` for decision-safe data;
- `RallyMovementSystem` and `ContactEnvelopeSystem` for physical feasibility;
- `ShadowAttackSystem` for repeated observations without source mutation;
- `AttackRolloutAudit` for information and continuity checks;
- `RallyRolloutPolicy` for a disabled-by-default selection boundary;
- `ApproachMechanicsSystem` output as an observable hitter cue, never as direct
  access to the hitter's private or authoritative decision.

Do not copy the attack system wholesale. Blocking has multiple cooperating
actors, commitment timing, possible conflicting reads, and net-position rules.

### Suggested gate sequence

| Gate | Deliverable | Authority | Status |
|---|---|---|---|
| 44 | Deterministic block hypotheses and repeated perceived cues | Shadow only | **Complete** -- `shadow_block_system.gd` |
| 45 | Individual and coordinated block decisions from observations | Shadow only | **Complete** -- `_coordinate_blocker`, `_resolve_roles` |
| 46 | Blocker progression fixtures and wrong-read calibration | Shadow only | **Complete** -- `block_progression_calibration.gd` |
| 47 | Candidate audit: legality, information purity, movement, contact and state immutability | Shadow only | **Complete** -- `block_rollout_audit.gd` |
| 48 | Guarded block rollout policy with production flag off | Official remains authoritative | **Complete** -- `select_block_source` |
| 49 | Explicit debug-only promoted block contact | Development fixture only | **Complete** -- `live_block_integrator.gd` |

Gate numbers are sequencing aids. Do not mark a gate complete merely because a
class exists; its stated tests and authority boundary must pass. Four habits
from this slice are worth carrying forward. First, a monotonic rate over an
all-zero column proves nothing -- Gate 46 pairs every rate with a coverage flag
asserting the sweep actually contains that outcome, after both a zero
wrong-read column and a structurally unreachable `hesitated` flag passed their
checks silently. Second, an audit that cannot fail certifies nothing -- Gate 47
corrupts one property at a time and requires each to be caught by name. Third, a
boundary that has never been pushed against has not been tested -- Gate 48
forces its flag on, and separately asserts the sweep contained an eligible
candidate at all, because "everything was held back" is vacuous when there was
nothing to hold. Fourth, a branch that ordinary play never reaches is not
verified by ordinary play -- every promoted block in the Gate 49 sweep was a
single-blocker touch, so the terminal two-blocker seal is driven directly by a
synthetic candidate rather than left as unexercised code.

Gate 48's forced-flag check is also a worked example of updating a test for the
right reason. It asserted the boundary refuses to promote *because no activation
existed*; Gate 49 built the activation and made that false on purpose, so the
check was rewritten to assert the opposite contract. Changing a test because the
contract genuinely changed is correct; changing one because it started failing
is not, and the commit message should make clear which happened.

## Gate 44 acceptance contract

Complete as of 2026-07-31; verified by `_test_gate_forty_four_shadow_block_hypotheses`
in `tests/test_runner.gd` and `docs/calibration/GATE_44_SHADOW_BLOCK_HYPOTHESES.md`.
The first block gate is complete only when all of these are true:

- equal seed and inputs produce equal observations, commitments, and evidence;
- blocker decisions contain no authoritative lane, exact future hitter contact,
  exact final attack target, or resolver-only success result;
- strong readers recognize cues earlier or more accurately rather than gaining
  unexplained movement speed;
- a wrong commit is possible and visible;
- two blockers can disagree before coordination resolves ownership;
- lateral speed, initial position, velocity, facing, and available time affect
  whether a close is physically possible;
- block reach uses `ContactEnvelopeSystem`, including takeoff time and height;
- the shadow system does not mutate source `RallyState`;
- normal fixed-seed rally events remain identical;
- evidence is sufficient for later playback without playback recomputing the
  decision.

## Tests to add with Gate 44

Added; all nine pass inside `_test_gate_forty_four_shadow_block_hypotheses`
in `tests/test_runner.gd`. Kept here as the acceptance record:

1. identical observation and seed produce an identical commitment fingerprint;
2. observation dictionaries contain no truth-prefixed fields;
3. a late setter cue changes perceived probabilities, not authoritative truth;
4. an elite reader is no slower and recognizes no later than a developing reader
   under paired inputs;
5. a displaced blocker loses a close that the correctly positioned blocker has;
6. a blocker moving the wrong direction pays the direction-change cost;
7. primary and assist roles are deterministic and legally front-row;
8. copied shadow state has the same fingerprint before and after evaluation;
9. with rollout disabled, official event identity is preserved.

After focused tests pass, add a paired multi-seed calibration report. Do not tune
from one visually convenient rally. `BlockerProgressionCalibration.run()` adds
this for reading-tier confidence and recognition timing (30 seeds per tier by
default); it does not yet cover wrong-read rate or coordinated-outcome
calibration -- that is part of Gate 46's remaining scope.

## Invariants that must survive every match-engine change

- Tactical positions are intentions or starting conditions, never teleportation.
- A player begins new movement from the last resolved position and velocity.
- Player decisions use perceived information; resolver truth audits outcomes.
- Physical ratings change capabilities, not hidden foreknowledge.
- Better attributes should preserve or expand options in controlled progression
  fixtures unless a documented tradeoff is being tested.
- Consecutive ball trajectories meet at the same contact position and time.
- A player cannot make illegal consecutive contacts.
- Events describe resolved state; visualizers and captions cannot change it.
- Production rollout flags stay off until a separately reviewed gate authorizes
  activation.
- Home and opponent orientation must be explicit; do not silently reflect one
  side's coordinates and assume equivalent decisions.

## Known warnings and non-blockers

At the review date, a headless editor scan succeeds but reports inherited-scene
recovery warnings involving `main.tscn` and `MatchScreen`. The test process may
also report Godot shutdown-only `ObjectDB` and resource-use warnings after a
passing result. Record them, but do not misdiagnose them as a new simulation
failure unless their behavior changes.

Treat parser errors, test failures, textbook validation failures, UI-binding
failures, trajectory discontinuities, nondeterminism, and source-state mutation
as blockers.

## Definition of a safe handoff

Before ending work:

1. run every command in [VALIDATION.md](VALIDATION.md);
2. update `STATUS.md`, `EVIDENCE.md`, `INDEX.md`, and `source_manifest.json`;
3. add or update the relevant `docs/calibration/GATE_*.md` record;
4. state which behavior is normal, development-only, shadow-only, or proposed;
5. report known warnings separately from failures;
6. do not commit, push, enable flags, or discard unrelated work unless the user
   explicitly requested it.

## Copyable prompt for another coding model

```text
Read docs/textbook/FRESH_AGENT_HANDOFF.md and the files it names. Verify all
claims against source before editing. The documented gate sequence (through Gate
49) is complete, so read "The one current next objective" and pick one of the
three candidates it lists before writing code; say which you picked and why.
Preserve the dirty worktree,
production-off rollout flags, player-information boundary, deterministic seeds,
source-state immutability, and RallyEvent playback contract. Run the complete
validation guide and update textbook evidence before handing off.
```
