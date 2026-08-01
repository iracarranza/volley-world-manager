# Fresh-Agent Handoff

Status: **AUTHORITATIVE PROJECT HANDOFF**

Last reviewed: 2026-08-01

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
switch. No gate is currently in flight; do not divert into building the full
development-project feature. Preserve the product contract in
[Connecting Development to Match Options](part_05_management/02_development_to_match_options.md).

## What is authoritative today

| Area | Ordinary match | Explicit development fixture |
|---|---|---|
| Whole-rally sequencing | Phase-based `RallySimulator.resolve()` | Same hybrid resolver |
| Reception ownership/contact | Official phase resolver | Audited persistent candidate may be promoted |
| Setter ownership/contact | Official phase resolver | May be promoted only after promoted reception |
| Attack ownership/contact | Official phase resolver | May be promoted only after promoted reception and setter |
| Attack preparation, both sides | `ApproachMechanicsSystem` affects normal attack quality, jump conversion, and available attack families; the opponent path mirrors it with explicit side orientation | Same evidence passes through the attack audit and live candidate |
| Home floor-defense geometry | Saved plan and block relationship drive phase positions and claimant geometry | Same |
| Block decision | Legacy resolver reads resolved attack geometry | Legacy resolver; a shadow block slice (Gates 44-49) runs alongside it as evidence. One audited block contact may be promoted, but only in an explicitly requested development fixture, in a debug build, on top of a promoted attack |
| Serve/set/attack flight timing | Derived from real distance and a launch angle by `RallyKinematics.solve_launch_arc()`; no duration tables remain | Same |
| Ground speed | `stride x cadence x mass`, per-mode, via `LocomotionModel`; the single rating curve is retired | Same |
| Second-contact capability | `SetterCapabilitySystem` sets tempo command, pass recovery, and reach on every official set | Same |
| Player generation | Attribute-first: ceiling, then an age-driven growth reserve, then role and region tiers | Same |
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

## Work completed after the gate sequence

The documented gate sequence ends at Gate 49, and Gates 50-51 added a
shadow-only continuous-movement slice. Everything below happened after that, is
**live in ordinary matches**, and is not gated. Each entry moved seeds on
purpose.

- **Force-derived ball flight.** Serve, set and attack duration and apex are no
  longer table lookups. `RallyKinematics.solve_launch_arc()` derives both from
  real court distance and a launch angle via projectile motion; the angle
  (shot shape / tempo intent) is the only free input.
  See [Ball Launch Kinematics](../design/BALL_LAUNCH_KINEMATICS.md).
- **`set_release_interval` consumed.** Both home set paths query the setter's
  `SYSTEM_FIT_SET_RELEASE` profile through `RallySimulator._release_interval()`,
  using *both* halves of it: `ideal_value` is the setter's natural rhythm and
  `tolerance` how far off it they can work. `defensive_depth` was already
  consumed; the old "read by nothing" claim was simply wrong.
- **The continuation path gained a real timeline.** It had never advanced its
  rally clock, so every contact in a defence-to-counterattack carried the dig's
  timestamp and the transition attack began at the same instant as the set that
  fed it. Set contact, set flight, then attack now chain correctly.
- **Attribute-first generation.** Potential is a ceiling set before attributes;
  a growth reserve driven by *age alone* decides how much is expressed. Role
  tiers read `VolleyballPlayer.POSITION_WEIGHTS` rather than a second copy, and
  region specialty and physique biases give the four regions distinct identities.
  See [Attribute-First Generation](../design/ATTRIBUTE_FIRST_GENERATION.md).
- **Stride x cadence locomotion.** The single speed curve
  `lerpf(1.35, 5.25, rating)` is retired. Speed is stride x cadence x mass, both
  factors with per-mode tables, and long limbs cost turnover so archetypes
  diverge by build. This was a deliberate rebalance: lateral -24%, transition
  +43%. See [Locomotion](../design/LOCOMOTION_AND_GENERATION.md).
- **Setter capability.** `SetterCapabilitySystem` gives tempo command, pass
  recovery, and reach real consequences on every official second contact, and
  attaches its read to the SET event. Capability constrains outcomes, never
  permission -- see below.
- **Gate 43 mirrored onto the opponent attack.** Opponent hitters now have a
  causal approach feeding attack quality, the swing arc, and available attack
  families, and the opponent set stages them at their approach mark for
  playback. `approach_start_position()` and `prepare_for_attack()` take an
  explicit side: the approach depth offset is signed by side, and the home
  defensive-duty lookup is gated so it can never be consulted for an opponent.

## The one current next objective

**No gate is in flight, and the documented sequence is finished.** The next
objective is a judgement call rather than a lookup. Do not start a production
rollout: every `ENABLE_CONTINUOUS_*` flag is still off, and turning one on is a
separately reviewed decision that no completed gate authorizes.

**1. Confirm opponent spikes now read correctly in 2D playback.** The engine
side of this is done -- the opponent attack path mirrors Gate 43, and the
opponent SET event stages the hitter at their approach mark so playback can
animate the run-up rather than teleporting them into a swing. What has not been
done is *looking at it*: the original complaint was that spikes were unclear on
the 2D court, and that should now be re-checked against a real rally before
anything else is built on top of it. If it still reads poorly, the remaining
fault is in `scenes/main/main.gd` playback rather than in the resolver.

**2. Carry the capability pattern to attacking and blocking.**
`SetterCapabilitySystem` is a worked example of the contract described under
"Capability is not permission" below. Attacking and blocking have the same
shape -- an action family, a physical reach, a technical demand -- and neither
currently expresses it. Attack families are partly there already through
`ApproachMechanicsSystem`'s available actions.

**3. Academy power normalisation (design direction, partly specified).** The
intended product is an elite academy rather than a national league pyramid, with
power normalised so a gifted fifteen-year-old and a settled thirty-year-old are
both worth picking. Generation already supports this: potential no longer
declines with age, so a veteran is a *developed* player rather than a better
one. Two decisions remain open and should be taken with the project owner:
whether physical attributes decline after a peak age, and whether `potential`
becomes per-attribute rather than scalar. See the open decision recorded at the
end of [Attribute-First Generation](../design/ATTRIBUTE_FIRST_GENERATION.md).

**4. Movement fluidity, step 4.** Steps 1-3 are done and step 4 is partly done:
`_movement_time()` and `project_toward()` now share one model, and Gates 50-51
added a shadow-only continuous reachability slice. What remains is making
movement resolver-owned and authoritative, in the audit / guarded boundary /
development promotion shape Gates 47-49 used. Do not start this in the same
change as anything else.

Whatever is chosen, the invariants below still bind:
`RallySimulator._resolve_opponent_block` remains the official path for ordinary
rallies, and `LiveBlockIntegrator` must stay behind its development fixture.

## Capability is not permission

This is a design contract, stated here because it was implemented wrongly once
and the wrong version looked reasonable.

A player may attempt **any** action, for any reason -- the play called for it,
they misread their own limits, they were out of options, they gambled. What
their attributes decide is not *whether* an action is available but *how it
goes*. An earlier `SetterCapabilitySystem` removed tempos a setter could not
command from the option list, which reads as a clean "explicitly could not" and
is wrong: it makes a limit into a rule and takes the decision away from the
player.

The correct shape, which that system now implements:

- capability sets a *requirement*, and the shortfall against it is measured;
- the action stays selectable regardless of the shortfall;
- attempting past capability carries a penalty that scales with how far past;
- a separate **judgment** attribute family decides whether the player recognises
  the overreach and takes the safer option, so a disciplined player backs off
  and a reckless one does not;
- the rally record shows which happened.

Physical impossibility is not an exception to this. A ball above a player's
reach is still reached *for*; it simply does not become a usable contact.

Two consequences worth carrying to other actions. **Reach is a product of three
independent things** -- standing height, arm length, and leap -- so a short
player with a real jump out-reaches a tall one who cannot get off the floor;
`VolleyballPlayer.jumping_reach_cm()` is the single place they are combined, and
nothing may re-add them itself. **Reach is not fixed per action**, because how
much of a run-up a player could afford changes how much of their leap is
available: a setter who arrives early takes a short approach into a jump set and
buys the height a sailing pass demands, while one still scrambling takes it
flat-footed and loses the same ball.

## Lessons that cost real debugging time

Carry these forward; each was found the expensive way.

- **A duplicated formula is a defect, not a style problem.** Found three times in
  one session: `estimate_movement()` restated the whole movement profile,
  the generator kept its own copy of the role tiers that had already drifted
  from `POSITION_WEIGHTS`, and `ShadowMovementSystem` hard-coded a turn-delay
  floor that stopped being constant. Each would have silently disagreed with its
  original after the next change.
- **A test that restates the formula it checks passes whenever both copies are
  wrong together.** Call the real helper.
- **A rate over an all-zero column proves nothing.** Gate 46 pairs every rate
  with a coverage flag. The same trap reappeared with setter tempo downgrades,
  which never occur in ordinary play because the default offence only ever calls
  T3 -- so the rally-level check asserts reach variation instead, and the
  downgrade is verified directly.
- **An audit that cannot fail certifies nothing.** Gate 47 corrupts one property
  at a time. New checks should be confirmed falsifiable by breaking the thing
  they guard and watching them fail.
- **Changing a test because the contract changed is correct; changing one
  because it started failing is not.** The commit message must make clear which
  happened. Worked examples: Gate 48's forced-flag check, and the jump-set
  fixtures that asserted a real contract at a height only reachable under an
  assumption that had just been removed.
- **A derived value computed before its input is final is a bug that hides.**
  `stride_length_m` was set from the role's base height and never recomputed
  after generation perturbed the real height; `hitter_move_time` was computed
  before staging relocated the hitter. Both looked like tuning problems.

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
   -- Gate 44 test 9, and the full regression suite as it stood at that gate.

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
- Attributes constrain how an action turns out, never whether a player is
  allowed to attempt it. See "Capability is not permission".
- A quantity derived from several attributes has exactly one function that
  combines them; callers ask that function rather than re-deriving it.
- Potential is a ceiling and must actually bound current ability. Age decides
  how much of a ceiling is expressed, never how high the ceiling is.
- In-rally physical quantities are derived from real distances, masses and
  times, not chosen from tuned tables.

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
2. update `STATUS.md`, `EVIDENCE.md`, `INDEX.md`, `source_manifest.json`, and
   any `docs/design/*.md` whose status line your change invalidates;
3. add or update the relevant `docs/calibration/GATE_*.md` record;
4. state which behavior is normal, development-only, shadow-only, or proposed;
5. report known warnings separately from failures;
6. do not commit, push, enable flags, or discard unrelated work unless the user
   explicitly requested it.

## Copyable prompt for another coding model

```text
Read docs/textbook/FRESH_AGENT_HANDOFF.md and the files it names. Verify every
claim against source before editing; several textbook statements have been
stale in the past. The documented gate sequence is complete and no gate is in
flight, so read "The one current next objective", pick one candidate, and say
which you picked and why before writing code. Read "Capability is not
permission" and "Lessons that cost real debugging time" first -- both encode
mistakes already made here. Preserve the dirty worktree, production-off rollout
flags, the player-information boundary, deterministic seeds, source-state
immutability, and the RallyEvent playback contract. Run the complete validation
guide and update textbook evidence before handing off.
```
