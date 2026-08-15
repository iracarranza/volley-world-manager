# Rally physical time

## §0 The finding, before the plan

The brief that opened this work proposed deriving rally timing from ball
trajectory legs, and then corrected itself: *do not introduce a second timing
model based on distance over constant speed; promote the durations the simulator
already produces.*

The correction is right, and it understates the case. **The authoritative
cumulative clock already exists and is already correct.** `rally_simulator.gd`
carries a `rally_clock`, advances it by each flight's own duration, and stamps
every emitted event with an `event_time` taken from it. Measured over 240
rallies and 2,116 events (`tools/playback_timing_probe.tscn`):

| | |
|---|---|
| events with no `event_time` | **0** |
| events out of chronological order | **0** |
| contacts with no `event_duration` | **0** |

There is nothing to build on the simulator side. Every acceptance criterion in
the brief's list that begins *"timestamps are monotonically ordered"* or
*"every contact has a deterministic timestamp"* already passes today.

The defect is entirely on the playback side, and it is one defect.

## §1 Playback throws the clock away and re-times everything by hand

`scenes/main/main.gd` walks `result.events` and paces each one itself:

```gdscript
var trajectory_duration := clampf(
    float(outgoing_trajectory.get("duration", 0.5)), 0.28, 2.60
) / maxf(playback_speed, 0.1)
...
var event_duration := clampf(simulated_duration, 0.55, 2.60) \
    / maxf(playback_speed, 0.1)
```

`event_time` is read only for captions and for the cognition window. It is never
what paces anything. Neither clamp was measured against the distribution it acts
on, which is the mistake `FAILURE_MODES.md` §0 exists to name. Measured:

**Ball legs** — n=1,506

| p05 | p25 | p50 | p75 | p95 | max |
|---|---|---|---|---|---|
| 0.03 | 0.40 | 1.06 | 1.21 | 1.51 | 31.00 |

The clamp `[0.28, 2.60]` rewrites **20.7%** below and 0.7% above.

**In-place contacts** — n=610

| p05 | p25 | p50 | p75 | p95 | max |
|---|---|---|---|---|---|
| 0.10 | 0.10 | 0.12 | 0.12 | 0.24 | 0.24 |

The clamp `[0.55, 2.60]` rewrites **100.0%** below. Every single one.

A contact that physically takes 0.12 s is drawn over 0.55 s. The floor sits
outside the top of its own distribution — it is not a clamp at all, it is a
constant with a `clampf` written round it. This is the §0 pattern in its purest
observed form to date: not a threshold that rarely fires, but one that always
fires and therefore replaces the model wholesale.

## §2 Why the symptoms are all the same bug

Total physical time across the sample is 1,439 s; total playback time is
1,697 s, a ratio of **1.179**. Being 18% slower than life is not the problem —
some slow-down is exactly what makes a rally watchable.

The problem is that the slow-down is **uneven**. A 0.12 s contact is stretched
4.6×; a 1.2 s flight is not stretched at all. Every ratio between two events is
destroyed, and every reported symptom follows from that:

- **Blockers hang.** The block is drawn over a window inflated 4.6× while the
  ball leg beside it runs at 1.0×, so the jump outlives the contact it was
  built around. Nothing about the jump model is wrong.
- **Contacts feel disconnected from the ball.** They are: the ball moves on
  (nearly) physical time and the bodies move on inflated time.
- **The rally ends before the ball lands.** 15 of 240 rallies, worst case
  0.08 s. Small, real, and separate — see §3.

The fix for the first two is not a per-symptom patch. It is to pace playback
on **one scale factor applied to physical time**, so relative timing is
preserved exactly and only the overall rate is a presentation choice.

## §3 The rally end is a second, smaller bug

15 of 240 rallies have a last stamped event earlier than the terminal ball's
landing. The logical outcome is known at the attack contact; the physical ball
is still in the air. The invariant the brief asks for —

```
visual_rally_end_time >= terminal_ball_contact_time
```

— is worth having as a test regardless of how small the current violation is,
because it is the same boundary that once made the ball vanish at point-end and
was patched locally rather than structurally.

## §4 Cognition: the sonar is one comment away from being visible

`cognition_compiler.gd` says what it does at line 123:

> One cue per off-ball voli per flight.

That is the flashing. A voli whose attention does not change across four
contacts gets four cues — four starts, four ends, four appearances — because the
compiler emits per flight rather than per *change*. Nothing tests whether the
attention state differs from the one already running.

The infrastructure for the fix is already there and is good: cues carry
`starts_at`/`ends_at` in simulation seconds, a priority, an `as_held()` flag,
and both courts sample the identical `CognitionTimeline`. What is missing is a
coalescing pass — if a newly compiled cue has the same subject, `attention_kind`
and intent as the one already covering that voli, extend the existing cue's
`ends_at` instead of appending a new one.

That is a compiler change, not a renderer change, which keeps the brief's rule
that neither renderer decides cognition.

## §5 Order of work

1. **One playback scale, no per-event clamps.** Pace every leg and every contact
   at `physical_duration × READABILITY_SCALE / playback_speed`. Relative timing
   becomes exact. Re-measure the ratio; it should be flat across the
   distribution rather than 4.6× at one end and 1.0× at the other.
2. **Gate the rally end on the terminal landing.** Plus the regression test.
3. **Derive the block jump from the block contact stamp** — takeoff, peak,
   landing — now that the window it sits in is physical.
4. **Coalesce unchanged cognition** in the compiler, and hold semantic cues
   until superseded rather than for a fixed span.
5. **Restrict `waiting` to a pre-serve phase**, and add that phase.

Stages 1–2 are small and unblock the rest. Stage 3 is where "blockers hang"
actually resolves. Stages 4–5 are the cogniticon half of the brief and are
independent of 1–3.

## §6 Two things found in passing, not yet acted on

- **CORRECTED.** This section first read "two ball legs out of 1,506 exceed 4 s,
  one of them 31 s", and the 31 has not survived. A wider sweep
  (`tools/long_flight_probe.tscn`, 3,000 rallies and 13,298 legs) found the
  longest flight at **4.43 s**, only two legs over 4 s, and nothing at all above
  6 s. The original figure was also exactly `31.00`, which reads more like a
  sentinel than a computed duration. A deterministic re-run on the original
  seeds was started to settle it and timed out without reporting, so the
  question is open: treat 31 s as unconfirmed, not as a known defect.

  What the two real cases do show is an internal disagreement worth chasing.
  Both are `trajectory_type = attack` on rallies ending in an attack error, and
  in both, `duration`, `apex_rise_meters` and `launch_vertical_mps` contradict
  each other under `ball_flight_model.gd`'s own equation
  `t = (v + sqrt(v^2 + 2gh))/g` at `g = 9.8`, `h = 1.0`:

  | | launch | duration vs model | apex rise vs model |
  |---|---|---|---|
  | seed 2961955578 | 18.41 m/s | 4.43 s vs 3.81 s (x1.16) | 12.04 m vs 17.30 m (x0.70) |
  | seed 49077948 | 4.46 m/s | 4.26 s vs 1.10 s (**x3.88**) | 0.65 m vs 1.02 m (x0.64) |

  A ball rising 0.65 m cannot stay up 4.26 s. But these three fields are passed
  *into* `_trajectory_payload` from the attack resolver rather than derived
  there, so they may come from different models by design. Observation, not
  diagnosis.

- The old playback ceiling of 2.60
  was hiding it from view, which is the other cost of clamping.
- The `[0.55, 2.60]` contact clamp means the current playback has never once
  shown a contact at its simulated duration. Any prior visual judgement about
  contact pacing was made against the constant, not the model.
