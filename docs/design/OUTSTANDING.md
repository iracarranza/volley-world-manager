# Outstanding design work

What is designed, agreed or diagnosed but not built, as of this branch. Ordered
by what unblocks what, not by size.

`docs/BACKLOG.md` is the older list and still holds; this is the live one for the
rally-timing, block, pose and measurement threads opened on
`claude/system-fit-serve-receive-von64k`.

## §1 The rally clock

Stages 1 and 2 are done: playback paces on one rate through `PlaybackPacing`,
and the terminal ball gets its whole flight. Stage 3 -- the block jump derived
from the contact stamp -- is done and verified.

**Remaining, in order:**

- **Cogniticon coalescing.** `cognition_compiler.gd:123` states the fault
  outright: *"One cue per off-ball voli per flight."* A voli whose attention
  does not change across four contacts gets four cues, so an unchanged state
  renders as four appear-and-fade cycles. The fix is a compiler pass that
  extends an existing cue's `ends_at` when the next one agrees on player, side,
  intent and attention kind, applied to **state** cues only so a recognition
  `!` stays brief. The cue model already carries `starts_at`/`ends_at`,
  `priority` and `as_held()`, and both courts sample one `CognitionTimeline`,
  so this is a compiler change and not a renderer one.
- **Semantic cue lifetimes.** Cues hold until superseded or resolved rather
  than for a fixed span. Depends on the coalescing above.
- **A pre-serve phase**, and restricting `waiting` to it. Two to four seconds
  of standing before the serve, which is also where serve routines, ball
  bouncing and quirks eventually live.
- **Per-player overlapping timelines.** The largest piece and deliberately
  unscoped: today the approach and the contact are drawn *sequentially* at
  honest lengths, when the approach should overlap the preceding flight. This
  is what makes a setter chase during the pass and a hitter start their run
  before the set is released.

  **The setter's half is done.** `_spatial_setter_choice` takes a
  `head_start_seconds` and spends it as *distance already covered* rather than
  as time added to the window -- a setter releases toward their target when the
  serve is struck, not when the platform touches the ball. The first ball
  passes the serve's own flight. Measured over 1,215 second contacts, the
  arrival margin moved from a median **-0.37 s to +0.31 s**, which is 95% of
  setters arriving late becoming most of them arriving early, and it is what
  made the jump set reachable at all.

  Still on this thread:

  - **The transition set has no head start**, because its window is the
    hardcoded 0.68 s the movement-agreement gate already names as a defect.
    Fixing the constant and the head start together is one job, not two.
  - **The hitter's approach** is the other half and is untouched.
  - **Removing the setter's precognition is blocked on short-leg timing.** The
    head start currently advances every candidate toward `set_contact`, which
    is the *resolved* pass destination -- a coordinate that does not exist when
    the setter releases. They should run at the plan's `setter_release_target`
    instead, and the one-line change is written and held in
    `_spatial_setter_choice` with the reason on it.

    Measured, passing the expected zone moves the movement-agreement gate from
    SET 0.8344 to **0.7466** and the perceptible-leg rate from 0.0579 to
    **0.1294**. That is the correct behaviour exposing a real instrument limit:
    a setter already standing in their zone has a *short* remaining leg, and a
    short leg is where the resolver's allotted duration and the stepped model
    disagree most -- the standing start and the turn delay are a large share of
    two tenths of a second and a small share of one and a half. Fix the
    short-leg timing, then this becomes one word.

  - **Playback should spend the slack rather than stretch it.** A setter who
    arrives early is drawn crossing the floor slowly enough to fill the whole
    flight, because `_pace_plan` gives a leg the window rather than the
    traversal. The movement-agreement gate reads that as SET at 0.8344 against
    an allotted duration, and the honest fix is a leg that finishes early being
    drawn finishing early with the voli standing and waiting -- which is what a
    setter actually does.

## §2 The block

Done: hang from the real leap, height from the real leap, apex from
`block_timing`, arm count derived from the close.

**Remaining:**

- **Course-change poses.** One-arm and two-arm *swing* -- a blocker moving
  their arms across to a new lane mid-air. New phase-dependent motion in
  `BlockBiomechanics`, not a parameter change, which is why it has not been
  done alongside the rest.
- **Spread arms**, and **dropping the arms to avoid being tooled.** Both
  wanted, both after the swing poses.
- **Drawing `block_intent` and `block_defense_relationship`.** Both are on the
  block event already and both are invisible. `Seal`/`Balanced`/`Funnel` and
  `Balanced`/`Defend Line`/`Defend Cross` are separate fields on
  `DefensivePlan`, so they are two orthogonal axes rather than one -- a wall
  can seal *and* defend line. Rendering work over data that exists.
- **`block_hands` is likewise undrawn.** `soft`/`kill`/`neutral`, computed per
  blocker from close fraction and contest margin.

## §2b The second contact's posture

Done: the pass is high enough to jump to, the jump set is the standard, pace
comes from both the geometry and the leap, and delivery scatter is angular.

Measured before and after, 1,200 rallies (`tools/pass_and_set_probe.tscn`):

| | before | after |
|---|---|---|
| pass apex above the floor | 2.42-3.31 m, median 2.89 | **2.94-4.05 m, median 3.51** |
| setter arrival margin | median -0.37 s, p95 -0.03 | **median +0.31 s, p95 +1.07** |
| jump sets | **1 of 914** | **580 of 914** |
| drift, short / mid / long | 0.34 / 0.26 / 0.40 m | **0.24 / 0.25 / 0.61 m** |

The old pass band topped out *below* a setter's own jump-set contact -- a
1.90 m setter meets the ball at about 2.83 m in the air and the median pass
peaked at 2.89 m -- so there was no ball in the game worth leaving the floor
for. That is why the jump set could never be the standard and why the pass read
as too low to jump to.

**Remaining:**

- **The opponent and transition sets have no posture.** 437 of 1,351 sets in the
  probe report `?`: both of those paths still release from a standing height
  unconditionally. The same one-way asymmetry this file keeps closing a path at
  a time.
- **Poses for the two postures.** A jump set and a standing set are drawn
  identically. Wanted with the dig poses in §3.
- **`_set_pace_scale` is unmeasured.** `JUMP_SET_PACE_BONUS` 0.12 and
  `STANDING_SET_ARM_SWING` 0.16 are starting values; nothing has published a
  set's flight time against posture, so there is no distribution to cut them
  from.

## §3 Poses

- **Dig poses.** An underhand set with a pointed follow-through that goes
  straight up out of the legs, and an overhead bump sending the ball backwards
  with the follow-through up and over the head. Wanted **after** the
  second-contact work in §4, because those are the contacts the poses are for.
- **Verify the cocked elbow in match playback.** `ELBOW_COCK_DEGREES` is -98
  and reads correctly in the roster once the pose is turned to three-quarter.
  The match camera moves, so it may show the fold unaided -- worth judging
  before the value is settled.

## §4 The second contact, and the shank

**Non-setter second contacts already exist.** `_spatial_setter_choice`
(`rally_simulator.gd:8634`) picks among `_home_second_contact_candidates`,
weights them by `second_contact_responsibility` -- "Primary emergency setter"
0.34, "Secondary emergency setter" 0.18 -- and sets `emergency_setter` when the
chosen body is not the designated one. None of that is missing.

**What is missing is where the ball is tested.** That function takes one
`target`, which is `reception_pass.destination`, and asks every candidate
whether they can reach *the endpoint* within the whole flight. Nobody is asked
whether the ball passes near them **en route**. So a shank that skims a metre
past a libero is invisible: that libero is only tested on whether they can
sprint to where it eventually lands.

Serve reception already does this correctly and the machinery is shared.
`RallyMovementSystem.generate_reception_opportunities` calls
`BallTrajectory.earliest_contact_time(from, 0.15, 1.40)`, which walks the arc
and returns the first moment the ball sits inside a playable height band --
literally the tight window a low shank offers. The second contact simply does
not use it.

**A first attempt was reverted.** Sampling `earliest_contact_time` for the
*first* playable moment put the second contact next to the passer on every
ordinary pass, because a pass leaves the platform already inside the 0.15-1.40
band. Three gates caught it. The right shape is an interception considered only
when the destination is unreachable -- evaluate both, take the better -- rather
than a rule that replaces the destination unconditionally.

**Confidence, proficiency and the seam are now in.** `_spatial_setter_choice`
takes its physical half from the same `CoverageModel.evaluate_arrival` the first
contact uses, judged from where the body actually is, and publishes
`reach_margin_meters`, `arrival_margin`, `claim_margin`, `seam_conflict` and
`contested_by`. The duty weighting stays local on purpose: a serve receive and a
second ball rank responsibility differently, and one shared chooser would have
to pretend otherwise.

`evaluate_arrival` gained an `origin` -- it measured reach from the *zone
centre*, which is where a voli stands in a serve-receive formation and nowhere
else. Mid-rally the passer has just played the ball and the setter has been
chasing it; judging them from a formation slot is the same confusion between a
body and its assignment that `assigned_reach` was already caught making one
field below.

**Collisions are in, and they fire.** `_navigation_waypoint` returns the corner
a voli has to turn round a body standing in their line, `_movement_time` times
the staged route through it, and both playback paths draw the bend -- the 2D
court through `unit_movement_waypoints`, the 3D court through the plan's
`waypoint`, both of which already existed for a hitter's approach. A collision
bends a run; it does not cancel one, and it is not a published reason.

Measured over 1,500 rallies / 1,520 second contacts
(`tools/obstruction_probe.tscn`):

| | |
|---|---|
| obstructed second contacts | **710, 46.71%** |
| detour off the straight line | median 0.199 m, mean 0.244 m, p95 0.638 m, max 0.722 m |

**The rate is the open question.** Half of all second contacts having somebody
in the way is a crowded court, not the design intent -- which was the setter who
ran into the passer stepping in short. The bends themselves are small, so the
time cost is minor either way; what is wrong is the frequency, and the two
candidate causes are `OBSTRUCTION_CLEARANCE_M` (0.715, the widest torso, so a
*brush* counts as an obstruction) and the fact that the obstructing bodies are
sampled once at leg start and never move out of the way. Do not tune the
clearance without deciding which.

Still to do here:

1. The interception attempt, in the shape above.
2. **The reach margin says the chosen setter cannot reach the ball.** Median
   -0.902 m, mean -1.033 m, p95 +0.694 m -- so for most second contacts the
   coverage model reports the body that took the ball as out of range. Either
   the margin is measured with the wrong instrument or the claim is fiction,
   and the evidence points at the instrument: `evaluate_arrival` charges a
   0.18-0.56 s reaction delay out of a window that is only the pass flight,
   and a setter releasing to the target does not react to the pass -- they
   started on the serve. Removing that delay alone is worth roughly 1.5 m at
   4 m/s, against a 0.9 m median shortfall. Measure before changing it.
3. `SECOND_CONTACT_SEAM_MARGIN` is 0.10 and **fired zero times in 1,520
   contacts** -- and now that it can be measured, it is a threshold outside its
   own distribution, §0's exact shape.

   Two things were hiding it. The sentinel: the no-rival case published
   `claim_margin = 1.0` while real gaps run to 1.201, so a stand-in that was
   indistinguishable from a genuine wide gap made up the *median* of the
   published figures. That is gone -- uncontested publishes no gap and a
   `claimant_count` instead. What was underneath:

   | | |
   |---|---|
   | second contacts with any rival claimant | **40 of 1,520, 2.6%** |
   | real claim gap | p05 0.142, median 0.861, mean 0.755, p95 1.143, max 1.201 |

   0.10 sits below the 5th percentile of the distribution it cuts, so no gap
   this engine produces can reach it. It is not a value that wants nudging:
   the 2.6% contest rate is item 2 wearing a different face -- with most
   candidates reported unreachable there is rarely a second claimant to have a
   seam with. Fix the reach margin, re-measure, then cut the threshold from
   whatever distribution survives.

## §5 Measurement debt

Three things are known-unreliable and should not be quoted until re-run.

- **The determinism figure is untrustworthy.** `tools/determinism_probe.tscn`
  reports 75 of 400 seeds not replaying identically, but it resolves the same
  seed three times without resetting player state, and `_note_recovery` mutates
  fatigue during a resolve. It cannot currently tell a replay bug from expected
  fatigue accumulation. Fix the probe before believing the number.
- **Attack symmetry has drifted and stayed.** 0.622 against a 0.12 shipping
  bound, inside the 0.150 tuning ceiling so it passes. Absent before the
  arm-count and decision-time commits, present in every run since, and it
  survived reverting the lane change. The decision-time wall split is the
  likely owner, since changing which shot a hitter picks moves the home-away
  attack share. Belongs with the symmetry items already on the backlog.
- **The suite's check count is not a regression signal.** It has read 1,180,
  1,187, 1,776 and 1,786 across runs on near-identical trees, because sampling
  tests emit a variable number of checks. A drop is not evidence of anything on
  its own; this was mistaken for one.

Also open: **two ball legs over four seconds** in 13,298, the longest 4.43 s.
The 31-second flight reported earlier has never reproduced and is unconfirmed
rather than fixed. Both long flights are attacks on error outcomes, and in both,
`duration`, `apex_rise_meters` and `launch_vertical_mps` contradict each other
under `ball_flight_model.gd`'s own equation -- a ball rising 0.65 m that stays
airborne 4.26 s. Observation, not diagnosis: those fields arrive from the attack
resolver rather than being derived together.

## §6 Screens

- **The housing folder's internal structure** -- lease pages, property
  photographs, the equipment catalogue. Deferred repeatedly.
- **The kitchen's meal-plan pad reframe**, per `THE_DESK_AND_THE_PHONE.md` §4.
- **The answering machine**, and the phone's calls model, which depends on the
  day and hours model.
- **Back buttons return to the journal**, not the desk, for pages opened from
  the desk.
- **Quirks** are designed and explicitly deferred.

## §7 The comment audit

`docs/review/comment_audit.docx` holds 128 flagged passages across
`rally_simulator.gd` and `player_actor_3d.gd`, awaiting marks. Citations are
mechanically verified -- 127 of 128 quoted verbatim at the exact line -- but the
**judgement is uncorroborated**: the adversarial pass was cut short, so some
flags will be wrong.

Fourteen of sixteen core files are unaudited, including the two extremes that
prompted the exercise: `rally_feature_flags.gd` at 92% comment, and
`rally_calibration_report.gd` with 2 comment lines across 841.
