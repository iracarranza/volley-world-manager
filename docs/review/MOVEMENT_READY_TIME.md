# Change 2: when a voli could first have known where the ball was going

`docs/implementation/SIMULATION_PLAYBACK_AUTHORITY_HANDOFF.md` change 2, measured
and implemented at `e4a62f3`.

## The requirement, and what the repository could actually supply

The handoff asks that `movement_delay_seconds` be generalised to reception,
dig/floor defence, set chase/release, hitter approach and block close, using
existing perception timing.

**It exists for one of those five.**

| family | departure time available today |
|---|---|
| hitter approach | **yes** -- `tempo_coordination.approach_start_delay_seconds`, published on 510 of 510 attacks |
| home reception | **derivable at no cost** -- see below |
| opponent reception | no. `ShadowReceptionSystem` is built for the receiving *home* side only |
| dig / floor defence | **no** |
| set chase / release | no departure time; `_travel_intent` publishes a duration, not a start |
| block close | no |

The dig is the important absence and it is not an oversight. The floor-defence
arrival record is `_read_adjusted_arrival`, and every field in it is a **length**
-- `distance_meters`, `reach_margin_meters`, `edge_ratio`, `read_error_meters`.
The engine models where a defender's read leaves them, never when they set off.
So for the dig there is no fact to publish, and inventing one is what the
handoff's non-goals forbid.

## What was published, and why it cost nothing

`BallReadSystem` derives `recognition_time` with **no random draw at all**:

```text
recognition_delay = clamp(
    lerp(0.34, 0.07, reading) + novelty * 0.18 - observation_progress * 0.05,
    MIN_RECOGNITION_DELAY, MAX_RECOGNITION_DELAY)
```

The `RandomNumberGenerator` in that function is used only for the destination,
timing and height *errors*, all after this line. And `ShadowReceptionSystem.evaluate`
already runs on **every** rally at `rally_simulator.gd:1094`, regardless of
`ENABLE_CONTINUOUS_RECEPTION_EVENTS` -- only its *promotion* is gated. So the
number is computed today and thrown away today.

`_read_ready_delay` reads it off the trace for the official receiver and the
reception publishes it as `movement_ready_seconds`.

## Published, applied only where it fits, counted where it does not

This is the decision in the change and it is not a safety rail.

The resolver times a reception from the instant the serve is struck and grants it
the **whole** flight. The read model says the body could not have known where the
ball was going for the first 0.07-0.34 s of it. Where both are asserted, the drawn
receiver sets off late and misses a ball the record has them passing -- playback
contradicting the resolver, which is precisely the class of defect this work
exists to remove.

So `match_screen` applies the delay only where `ready + min(duration, budget) <=
budget`, and records the rest in `playback_late_departures`, surfaced through
`playback_geometry_report().late_departures`.

## Measured

`tools/run_contact_leg_pacing.gd`, 300 rallies, seeds 61000-61149:

| family | legs | with a ready time | mean ready s | fits | mean overrun s |
|---|---:|---:|---:|---:|---:|
| SERVE→RECEPTION | 209 | 99 | 0.163 | **69** | 0.137 |
| SERVE→RECEPTION (failed) | 32 | 18 | 0.164 | **15** | 0.153 |
| BLOCK→DIG | 109 | 0 | -- | -- | -- |
| BLOCK→ATTACK_COVERAGE | 5 | 0 | -- | -- | -- |

**A receiver's legitimate departure is 0.163 s after the serve, and in 30 of 99
cases the journey the resolver timed no longer fits behind it, by 0.137 s.**

That is not a rounding error on a 1.18 s flight: it is 12% of the window, on 30%
of the receptions that have the fact at all. It is the first hard number on the
handoff's own question -- whether the existing keys compose into exactly one
physical interpretation -- and the answer for those 30 legs is no. Two
authoritative facts about one journey disagree, and no key added to either side
reconciles them.

Outcomes are unchanged: the balance probe over 700 rallies is byte-identical to
the change-1 reading, which was itself byte-identical to the pre-change tree.

## Carried to the architectural gate

1. **The dig has no departure time and the arrival record cannot supply one.**
   Adding one is a simulation change, not a contract change.
2. **30% of receptions cannot honour both their departure time and their
   traversal.** Whichever is wrong, publishing more keys will not tell us which.
3. **The opponent side has no read model at all**, so any rule built on
   `movement_ready_seconds` is half-court by construction -- the same `&"home"`
   boundary the verification pass found in the continuous stack.
