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

Fix, smallest first, in §5's order:

1. Sample the pass trajectory for a playable moment and test candidates against
   *that point at that time*, keeping the endpoint as the fallback so a good
   pass behaves exactly as it does now.
2. Widen the candidate pool only if step 1 proves insufficient.

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
