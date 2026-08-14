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

## §2c Responsibility, not reachability

Step 0 and step 1 of the structural handoff are done and measured; step 2 is
landed but **dormant**, for a reason worth reading before anything is tuned.

`tools/responsibility_probe.tscn`, 1,200 rallies:

| RECEPTION | before the lock | after |
|---|---|---|
| ball already inside somebody's reach | -- | **844 of 1,059 (79.7%)** |
| nearest voli did *not* take it | 194 (32.9% of contested) | **71 (12.0%)** |
| how much further the winner was | median 0.70 m, max 1.14 | **median 0.38 m, max 0.87** |

**The overtake was always small.** The handoff's libero-crosses-the-court case
does not appear: the furthest any claimant ever reached past a nearer teammate
was 1.14 m in 1,200 rallies. What existed was a tie-break between adjacent
bodies, and the lock is still right to remove it -- ownership should not be
purchasable -- but it was never a six-metre steal.

**The spacing term is inert at serve receive, and that turns out to be
correct.** Crowding is the distance from the claimant to the nearest other
reachable teammate, and over 590 contested receptions it reads **2.99 m at p05,
median, mean, p95 and max** -- one value, 590 times.

Two wrong explanations were tried and measured away before the right one. It is
not that `choose_claimant` was handed formation zone centres instead of bodies:
passing real origins changed nothing, because `_initial_home_positions` places a
receiving side *on* its zone centres, so the bodies and the diagram are the same
points. It is not that the probe held one rotation either: cycling all six left
reception spacing at 2.99 m across 454 samples.

The actual reason is in `serve_receive_formation`. The seams come from a fixed
preset and `_best_seam_assignment` maps passers onto those same points, so a
rotation changes *who* stands on each seam and never *where the seams are*. A
serve-receive shape is supposed to be invariant -- that is what makes it a
formation -- and a formation is spaced on purpose. There is nothing to fix.

So crowding is a **mid-rally** phenomenon, not a reception one, and the measured
DEFENSE spacing says the same thing from the other side: 0.86 m to 2.24 m with
real variance, and the p05 sits *below* the 1.05 m crowding threshold. The floor
can fire; it fires where bodies actually converge.

**`DEFENSE` conflates block coverage with floor defence**, and the conflation
had already produced one wrong conclusion. `rally_simulator.gd:2978` emits a
DEFENSE event for a voli covering their *own* blocked hitter -- a response to
the opponent's block, not to their attack -- under the same event type as a dig.
Counting DEFENSE therefore reported more digs than there were swings to dig in
five rotations of six, and the "dig claims treble across rotations" reading was
mostly coverage moving, not defence.

Split, over 1,200 rallies at 200 per rotation:

| | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|
| opponent swings | 13 | **1** | 16 | **58** | 26 | 35 |
| floor digs | 9 | 1 | 15 | 45 | 21 | 28 |
| digs per swing | 0.69 | 1.00 | 0.94 | 0.78 | 0.81 | 0.80 |
| block coverage | 39 | 21 | 60 | 18 | 16 | 57 |

**Floor defence is not weak per opportunity.** It answers 0.69 to 1.00 swings
per swing, which is what it should do. The anomaly is the row above it: the
opponent gets to swing **once** in 200 rallies from one home rotation and
**fifty-eight** times from another, against the same opponent, differing only in
which six volis the home side has where.

The coverage row says where those rallies went instead: R2 and R3 and R6, the
low-swing rotations, are the high-coverage ones. Rallies are ending on the *home*
attack being blocked, at a rate that swings 58-fold with rotation, so the
opponent's offence -- and therefore the home floor defence, and therefore rally
length -- barely runs at all in half the rotation cycle.

That is the short-rally symptom's actual shape, and it is not a defensive
problem. Do not buff digging.

**And it is not the block either.** Terminal outcomes per rotation, same 1,200
rallies, taken from `result.terminal_outcome` rather than from any event count:

| | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|
| **ace** | 70 | **131** | 3 | **0** | 76 | 1 |
| kill | 73 | 34 | 132 | 40 | 25 | 70 |
| blocked | 20 | 2 | 4 | 12 | 41 | 37 |
| attack_error | 10 | 8 | 26 | 71 | 13 | 36 |
| serve_error | 15 | 24 | 20 | 29 | 25 | 28 |

**Aces run from 0 to 131 out of 200.** In R2 two rallies in three end on the
serve, so nothing downstream of the first contact happens at all -- no home
attack, no opponent swing, no floor defence. The 58-fold opponent-swing spread
is a consequence of this, not a cause, and the block is a consequence too:
`blocked` runs 2 to 41 and moves the same way.

The home serve-receive fails catastrophically in some rotations and never in
others, against the same opponent with the same seeds. That is the thing
upstream of every other symptom in this section, and it is where the next work
belongs.

**One thing is unexplained and must not be built on.** Two independent counters
-- by `actor_id` and by the resolver's own `side` metadata -- both report *zero*
home ATTACK events in every rotation, in the same runs that record 132 kills.
The home attack does carry `"side": "home"` (`rally_simulator.gd:2484`), so the
metadata is there. Either the probe has a fault I have not found or the kill
path terminates without emitting the swing, and the second would mean every
measurement anyone has made of the home offence by counting events is wrong.
Resolve this before trusting any event-count statistic about the home attack.

**Next, in order:** the previous contacter yielding and clearing (then
re-measure the 46.7% obstruction, do not tune the clearance first); ready stance
as a directional state; short-ball ownership.

**And the number to chase next:** even at 119, dig claims are a ninth of the
receptions in the same 1,200 rallies. The home floor defence is barely being
asked who owns the ball, which is a different failure from being asked and
answering wrong, and it is the responsibility-side view of the short-rally
symptom.

## §3 Poses

- ~~**Dig poses.**~~ Both landed. `SetBiomechanics.POSTURE_UNDERHAND` is the
  pointed follow-through out of the legs, and setting backwards is an overlay
  (`_arch`) rather than a fourth posture, because a jumping back set and a
  standing back set differ exactly as their front counterparts do. Its selection
  signal is `back_set` on the SET event, from `_set_geometry`: which side of the
  setter's own body the ball left on, measured against the pin they square up
  to. **387 of 1,366 second contacts (28.3%) go behind the setter**, and the
  0.50 m threshold sits well inside the distribution it cuts -- p05 -5.48,
  median -2.43, p95 +4.53, range -7.70 to +7.02.

  One thing found while building it and worth repeating: the arch was first
  opened on `GATHER_END..EXTEND_END`, which put it at **0.20 of itself on the
  frame the ball leaves the hands**. A setter arches to get under a ball they
  mean to send behind them, so the shape is finished before the contact rather
  than built out of it. `tools/run_set_posture_shot.gd` now prints the joints at
  contact for all three postures both ways, which is what caught it.

### The stance foot skates, and the plant cannot close it alone

`tools/foot_plant_probe.tscn` measures what the drawn shoe does while it is on
the floor, summed over each stance phase and divided by the body travel over the
same frames -- 0 is a planted foot, 1 is a foot moving with the hips.

| speed | plant off | plant on | stance phases |
|---|---|---|---|
| 1.1 m/s | 0.343 | **0.203** | 20 |
| 2.8 m/s | 0.943 | **0.460** | 25 |
| 5.2 m/s | 2.464 | **1.974** | 45 |

Planting helps everywhere and closes nothing. The reason is upstream of it and
is arithmetic: `stride_cycle` advances by `travelled / stride_length_m` with
`stride_length_m` at 0.55-1.15 m for a **whole cycle**, which is two steps -- so
the model is told the body covers about 0.4 m per step. The legs disagree. At a
run the hip swings 39 degrees either side of vertical over a leg span near 0.9 m,
which sweeps the foot roughly 1.1 m per stance. The foot therefore travels about
2.7x further than the ground it is supposed to be pushing against, and that
ratio is what the table above is measuring.

A 14-degree correction cannot absorb a 2.7x error and should not be widened
until it can -- that would hide the cause in the symptom, which is §0 of
`FAILURE_MODES.md` in its usual form. The fix is to decide what `stride_length_m`
means and make one place own it: it is currently both the cadence divisor here
and a factor of `maximum_speed` in `RallyMovementSystem.movement_profile`, where
`speed = stride x cadence x mass`. Either the divisor is a *step* and wants
doubling, or the gait's hip amplitude is what should be derived from the
attribute rather than the cadence. **Both change every drawn gait in the game**,
which is why this is written down instead of done.
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
