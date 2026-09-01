# Verifying the rally movement timeline spec

A read-only audit of `docs/RALLY_MOVEMENT_TIMELINE_SPEC.md` (written against
`f625ff3`, committed on `origin/main` at `ad82c37`). No production code was
changed.

## Which tree, which instrument

Every structural claim below was read on `origin/main` at **`ad82c37`** in a
detached worktree. Every *rate* was measured there too, over **600 rallies** --
seeds 52000-52299, both serving sides -- by a throwaway `SceneTree` probe that
read published event metadata only and recomputed nothing. The probe was deleted
afterwards; the numbers are quoted with the commit that produced them, per §
"Run the tests".

The seven files the findings rest on were then diffed against this branch's
`0245f84`. `rally_opportunity_system.gd` and `live_reception_integrator.gd` are
byte-identical; the other five differ substantially, but every load-bearing
line -- `metadata["event_time"] = timeline`, the ten `movement_target`
publishers, the three `movement_delay_seconds` publishers, `_pace_plan`'s
`authored_seconds`, and `tactical_court`'s time-axis normalisation -- is present
and unchanged on both. **The structure generalises across both trees; the rates
are `ad82c37`'s alone.**

### The instrument was wrong once, and it mattered

The first run computed each window as the difference between two events'
`event_time`. On that reading `BLOCK -> DIG` had a **zero-or-negative window in
210 of 236 cases**, which would have been the headline finding: "the record says
the dig happens at the same instant as the block."

It is an artefact. `match_screen._gap_to_next` reads **`physical_time`**, not
`event_time`, and `physical_time` is a different field stamped by a different
function. Re-measured on the clock playback actually uses, **no window is
non-positive** and the minimum is 0.087 s. The real finding was still there
underneath, and it is worse, but the first number was measuring a field nothing
draws from. Recorded because it is the §0 failure mode exactly: a value measured
with the wrong instrument, read plausibly.

## The census that reframes the whole document

| adjacent event pair | count in 600 rallies |
|---|---:|
| `ATTACK -> BLOCK` | 408 |
| `BLOCK -> DIG` | 273 |
| `SERVE -> RECEPTION` | 473 |
| `SET -> ATTACK` | 510 |
| **`ATTACK -> DIG`** | **0** |

The spec's headline fixture, the deterministic `ATTACK -> DIG` it asks Codex to
trace numerically, **does not occur**. A dug attack is published as
`ATTACK -> BLOCK -> DIG` in every one of 600 rallies, because
`rally_simulator.gd:3261` emits a `BLOCK` event for an untouched block too --
stamped at the swing's net crossing, which `_stamp_physical_times:12466-12475`
derives specifically for that case. Nothing about the spec's reasoning collapses,
but every fixture, invariant and instruction naming `ATTACK -> DIG` addresses a
pair that is not in the stream, and `attack_time < receiver movement interval <=
dig_time` cannot be asserted on two adjacent events.

## Claim-by-claim

| # | Spec claim | Verdict | Evidence |
|---|---|---|---|
| 1 | `TacticalCourt.animate_spatial_transition` moves the next contact's actor during the preceding flight | **confirmed** | `tactical_court.gd:317-363` |
| 2 | "No anticipatory receiver movement exists" is false | **confirmed** | same |
| 3 | Off-ball movement exists substantially | **confirmed** | `home_phase_targets` / `opponent_phase_targets`, `match_screen.gd:1519-1521` |
| 4 | Players are driven by one shared `playback_progress` over the containing phase | **incorrect for 3D, confirmed for 2D** | `tactical_court._set_playback_progress:626` is shared; `match_court_3d._plan_fraction:356` gives each leg its own `seconds` clock and lets it run past the flight |
| 5 | `RallyScheduler` orders `RallyMoment`s by absolute time; kinds include `MOVEMENT_UPDATE` | **confirmed** | `rally_opportunity_system.gd:36-66` |
| 6 | `MOVEMENT_UPDATE` is not a global authoritative movement timeline | **confirmed** | it runs on `source_state.snapshot()`; `source_state_unchanged` is asserted in the return, `rally_opportunity_system.gd:250-256` |
| 7 | `evaluate_reception_timeline` schedules PERCEPTION + MOVEMENT_UPDATE across inter-read gaps and integrates the real model on perceived information | **confirmed** | `rally_opportunity_system.gd:36-66, 148-205`; the loop never reads ball truth, only `intent_target` and `perceived_arrival_time` |
| 8 | `LiveReceptionIntegrator` promotes arrival state/velocity and advances to contact time | **confirmed, and worse than stated** | `live_reception_integrator.gd:38-50` promotes `repeated.projected_position`, which is the position at the **final read**, not at contact; `state.advance_to` (`rally_state.gd:43-45`) moves the clock and the ball and **no player** |
| 9 | The traversal that established feasibility is not preserved as the canonical replay path | **confirmed** | the integrator reads no trail; `continuous_trail` reaches only the debug overlay |
| 10 | Continuous movement is "largely collapsed at the promotion/result boundary" | **partly confirmed** | it is collapsed there, but that is one of **three** discards and not the one that produces the visible defect -- see Q2 |
| 11 | `arrived_via_transition` may cause duplicate/suppressed movement | **unproven** | the identifier exists only in `scenes/main/main.gd`; nothing in `match_screen.gd` or `match_court_3d.gd` references it, so it cannot be the 3D defect |
| 12 | Presentation must not use resolver future knowledge before cognition permits | **confirmed as a principle, and currently violated** | only `SET -> ATTACK` publishes `movement_delay_seconds` (510/510). Every other family -- reception, dig, coverage, set -- publishes no start time at all, so its leg begins at the previous contact, before any read |
| 13 | "One Tween per player" is not required; a shared rally-clock sampler is cleaner | **confirmed** | `_plan_fraction` is already that sampler in 3D |
| 14 | Do not turn locomotor actions into `RallyEvent`s | **confirmed** | uncontested; the record already carries movement as metadata |
| 15 | `PlayerMovementTrace` should be introduced | **incorrect as scoped** | see Q4/Q6 |

## Q1 -- what actually causes the visible reception behaviour

Not one of A-E, and the dominant cause is **not in the list**.

**The finding: `movement_duration` and `movement_target` describe two different
journeys, and playback pairs them.**

`rally_simulator.gd:6043` computes `defender_move_time =
_movement_time(defender, defender_start, home_target, "lateral")` -- how long the
trip to the *ball* takes, unconstrained. `:6046` then computes `defender_reach =
_reached_point(..., available_time = attack_time, ...)`, which **truncates** the
arrival to what fits the flight. The event publishes the truncated endpoint as
`movement_target` and the untruncated time as `movement_duration`. The reception
does exactly the same at `:1279` and `:1296`.

`match_screen._build_movement_plan:1624-1627` then assigns `movement_duration` to
the plan's `seconds`, and `_pace_plan:1868-1872` keeps it as a floor. The drawn
leg therefore covers the *short* distance in the *long* time.

Measured, 600 rallies at `ad82c37`, implied speed = distance / `movement_duration`:

| pair | n | mean move s | mean window s | move > window | mean gap target→ball | to target | to ball |
|---|---:|---:|---:|---:|---:|---:|---:|
| `BLOCK -> DIG` (failed) | 132 | 0.978 | 0.385 | **129** | **1.49 m** | **0.59 m/s** | 2.05 m/s |
| `BLOCK -> DIG` (success) | 104 | 0.750 | 0.641 | 66 | 0.45 m | 1.17 m/s | 1.84 m/s |
| `SERVE -> RECEPTION` (success) | 439 | 0.855 | 1.178 | 81 | 0.54 m | 1.58 m/s | 2.00 m/s |
| `SERVE -> RECEPTION` (ace) | 34 | 0.868 | 1.186 | 8 | 0.57 m | 1.56 m/s | 1.96 m/s |
| `BLOCK -> ATTACK_COVERAGE` | 16 | 0.560 | 0.720 | 3 | 0.45 m | 1.85 m/s | 1.53 m/s |

**`v_to_ball` is coherent across every truncating family at 1.8-2.1 m/s** -- a
lateral shuffle. `v_to_target` is not; it is whatever fraction of the trip
survived truncation. That is the proof: the duration was timed on the full
journey.

The consequence compounds. On a failed dig the body is asked to cross 0.59 m in
0.978 s -- **0.60 m/s, a third of walking pace** -- inside a 0.385 s window. It
completes 39% of that, so roughly 0.23 m of drawn travel, and the dig contact
lands with the body about 1.85 m from the ball. `move > window` on **195 of 236
digs (83%)** and **89 of 473 receptions (19%)**, so the leg is *guaranteed*
unfinished at the contact in those cases -- not by accident, but because
`_plan_fraction:356-378` correctly honours a duration that is wrong.

Against the spec's list:

- **A -- lost simulator movement timing.** *Partly.* Timing is not lost; it is
  published (`movement_duration`) and read. What is lost is the *deadline*: no
  family except the hitter's approach publishes when the journey starts, so a
  duration is all playback has, and a duration cannot say "arrive by T".
- **B -- shared presentation phase timing.** *Confirmed for 2D, not the cause in
  3D.* `tactical_court._set_playback_progress:626` does drive every path off one
  `playback_progress`; `match_court_3d` does not. The user's screenshots are 3D.
- **C -- wrong endpoint semantics.** *Confirmed, and the dominant cause* -- but
  not as the spec frames it. The endpoints are individually right. The defect is
  a start/target pair from the truncated journey combined with a duration from
  the full one.
- **D -- duplicate/suppressed ownership.** *Present but secondary, and already
  instrumented.* `match_screen.gd:1600-1613` re-anchors the drawn leg to
  `live_positions` rather than the resolver's `movement_start`, and records the
  disagreement in `playback_start_mismatches`. Nothing reads that array. It is
  the right instrument, already built, never consulted.
- **E -- pose/root transition.** *Unproven.* Not measurable without a rendered
  run; separable in principle and should stay separate, as the spec says.

**A sixth cause, not in the list and worth its own line:** an ace publishes a
`RECEPTION` event carrying an `outgoing_trajectory` (`rally_simulator.gd:1495`)
before `_finish(result, "ace", ...)` at `:1517`. The pass the receiver never made
is on the record. That is a candidate for the reported "ball goes up from where
it was when the receive happened", and it is a one-key question about the record,
not an architecture question.

## Q2 -- what continuous movement information exists, and where it is discarded

Three separate discards, at three layers, and the spec names only the first.

**1. The promotion boundary (simulation).** `rally_opportunity_system.gd:192-197`
builds `continuous_samples` as `{time, position, reachable, arrival_margin}` at
`ShadowMovementSystem.DEFAULT_STEP_SECONDS` across every inter-read gap. It
computes `sample_velocity` at `:171-176` and **does not store it** -- a one-line
omission, and the only field the spec's trace contract asks for that does not
already exist. `shadow_reception_system.gd:743` decimates the array to a
24-point `continuous_trail`, its own comment (`:771-776`) calling it "a bounded
drawable trail ... something only a debug overlay reads." The full array survives
inside `opportunity_timeline`. `LiveReceptionIntegrator` reads neither: it takes
`projected_position`, `projected_velocity_mps`, balance and margin, and nothing
else. **The trail is not discarded -- it is carried, all the way, and never
consulted.**

**2. The published record (the seam).** `_finalize_rally_timeline:12566-12605`
**overwrites every event's `event_time`** with an accumulator that advances only
by ball-flight duration:

```
timeline = maxf(timeline, requested_time)
metadata["event_time"] = timeline
timeline += maxf(flight_duration, trajectory_duration)   # flight only for SERVE
```

The resolver's own figure is preserved as `resolver_event_time`, which **nothing
in the repository reads**. `event_duration` folds `movement_duration` into a
`max` and is never used to advance the clock. So the published inter-contact
interval is the ball's flight and nothing else -- the "movement path normalized
to allotted phase rather than natural traversal time" the spec lists as a
presentation concern is, at root, here.

**3. Presentation (2D).** `tactical_court._integrate_phase_path:670-730` already
integrates the real model through `ShadowMovementSystem.integrate` for every
moving player -- and then normalises the time axis away at `:725`
(`normalized.append(times[index] / span)`, last forced to 1.0). Its own comment
at `:645-653` states the problem exactly: *"the resolver allots a duration from
`RallySimulator._movement_time()`, which is a different code path from
`RallyMovementSystem.project_toward()`, so the two disagree on how long a
traversal naturally takes ... Reconciling the two timing paths is step 4's job."*
**The shape is the model's and the timing is thrown away, deliberately, with the
reconciliation already named as future work.**

## Q3 -- can the selected shadow traversal legitimately become authoritative?

**Not as it stands, for four independent reasons.**

1. **It is switched off.** `ENABLE_CONTINUOUS_RECEPTION_EVENTS = false`
   (`rally_feature_flags.gd`). `using_live_reception` (`rally_simulator.gd:1155`)
   additionally requires `OS.is_debug_build()`. Every rally the user sees runs the
   *other* path. Promoting the traversal is a calibration decision behind a gate,
   not a playback change, and the gate's own convention is "keep closed until a
   calibration gate opens one."
2. **It is home-side only.** `&"home"` is hard-coded 8 times in
   `rally_opportunity_system.gd` and 3 times in `live_reception_integrator.gd`.
   Half the court cannot use it.
3. **It is reception-only.** The equivalent machinery does not exist for dig,
   coverage, set, attack or block -- which is where 83% of the measured defect
   lives.
4. **It does not reach the contact.** The promoted `projected_position` is the
   receiver's position at the final read (`shadow_reception_system.gd:597-611`
   projects only between reads); the continuous timeline integrates one leg
   further, clamped to `perceived_deadline`. The two endpoints disagree by
   construction, so "the trace corresponds to the evidence that made the action
   feasible" is not currently true even within reception.

What *is* true, and is the spec's best structural insight: the continuous
timeline is **re-seeded to the discrete positions at every read**
(`rally_opportunity_system.gd:100-101` applies `sample.projected_position` at each
PERCEPTION). So it is anchored to the promoted arrival rather than competing with
it. If the gate were opened, promoting it would be outcome-neutral by
construction. That is a real property and worth keeping.

## Q4 -- should an existing structure carry timed movement?

**Yes. `PlayerMovementTrace` should not be introduced.**

The event metadata quartet already *is* a movement trace, and it is already
plumbed end-to-end into both presentations:

| trace field the spec asks for | what exists today |
|---|---|
| `start_position` | `movement_start` (10 publishers) |
| `end_position` | `movement_target` (10 publishers) |
| `end_time - start_time` | `movement_duration` (18 publishers) |
| `cognition_not_before` / `start_time` | `movement_delay_seconds` (**3** publishers) |
| waypoints | `approach_start_position`, `navigation_waypoint` |
| `movement_mode` / `intent` | `platform_intent`, `contact_posture`, `body_alignment` |
| contact time anchor | `physical_time` (100% coverage) |
| off-ball destinations | `home_phase_targets`, `opponent_phase_targets` |
| timed samples | `continuous_samples` (reception only, no velocity) |
| `reached_target` | `receiver_arrived` (published, **unread**) |

The gaps are three, and each is small: `movement_target` is missing on `SET` and
`ATTACK` (they publish a start and a duration with no end); `movement_delay_seconds`
is missing everywhere but the approach; and `movement_duration` currently means
the wrong journey. A new record would not close any of those -- it would need
exactly the same three facts, from exactly the same call sites.

## Q5 -- is one rally-clock sampler compatible with the current architecture?

**Yes, and most of it is already built.**

- **The clock exists.** `physical_time` is stamped on every event by
  `_stamp_physical_times:12455-12493`, derived from the ball's own trajectories,
  monotone by construction, with a block-specific net-crossing derivation for
  untouched blocks. `match_screen._gap_to_next:353-368` already computes the
  playback window from it.
- **The sampler exists in 3D.** `match_court_3d._plan_fraction:356-378` samples
  each leg on its own seconds clock, honours a per-leg delay, and lets an
  unfinished leg continue into the next window.
- **The integrator exists in 2D.** `tactical_court._integrate_phase_path` already
  runs the real movement model per player; only its time axis is normalised away.
- **Cognition already uses physical time.** `_window_physical_time:1149-1153` is
  built on `_event_physical_time`, which prefers `physical_time`.
- **The ball already uses it.** Trajectories carry absolute `start_time` /
  `end_time`; `RallyState.advance_to` samples the ball at a clock and moves no
  players, so nothing in simulation competes for player position.
- **Recovery already uses it.** `recovery_until` / `committed_until` are absolute
  simulation times.

What is missing is not a sampler. It is that the legs handed to the sampler carry
a duration measured against a journey they do not draw, and no start time.

## Q6 -- would any proposal duplicate an existing mechanism?

Yes, five times over. `PlayerMovementTrace` as specified would duplicate:
`continuous_trail` / `continuous_samples`; the
`movement_start`/`movement_target`/`movement_duration`/`movement_delay_seconds`
quartet; `home_phase_targets` / `opponent_phase_targets`; `physical_time`; and the
3D plan dictionary itself, whose keys (`start`, `target`, `waypoint`,
`delay_seconds`, `seconds`, `speed_mps`) are already the trace shape the spec
describes.

The spec's own prohibition -- *"never let legacy and trace systems move the same
player over the same interval"* -- is the argument against its own proposal. Two
of the three discards above are already two systems disagreeing about one
journey; adding a third record adds a third opinion.

## Corrections to the spec

1. **`ATTACK -> DIG` does not exist.** Every fixture, invariant and instruction
   naming it must be rewritten as `ATTACK -> BLOCK -> DIG`, and
   `attack_time < receiver movement interval <= dig_time` must span three events.
2. **"Continuous movement is largely collapsed at the promotion boundary"** is
   true and is not the cause. It is carried intact to a debug overlay; the
   defect is elsewhere, in a duration/endpoint mismatch on the ordinary path.
3. **"Players are driven by one shared `playback_progress`"** is true of 2D only.
   3D has had per-leg physical timing since `_plan_fraction` gained `seconds`.
4. **The reception is the wrong first slice.** The continuous reception path is
   gated off, home-only, and reception-only; the measured defect is worst on the
   dig (83% of digs vs 19% of receptions). The first slice should be the fix that
   serves every family, not the one subsystem that already has a shadow.
5. **`arrived_via_transition` is not implicated in 3D.** It exists only in
   `scenes/main/main.gd`. Steps 6 and 15 should be scoped to 2D or dropped.
6. **The 15-step sequence inverts the order.** Steps 1-6 build and promote a new
   record before step 7 validates the case; the case is cheap to measure and
   invalidates the record's necessity.

## The smallest architecture I recommend

Four changes, none of them a new data structure, in this order. Each is
independently measurable.

**1. Fix what `movement_duration` means.** Publish the time to the endpoint that
is actually published. `_reached_point` already knows both the asked-for target
and the reached one; the duration should be timed on `movement_start ->
movement_target`, not `movement_start -> home_target`. Predicted effect:
`v_to_target` rises to meet `v_to_ball` (~2 m/s) across every truncating family;
the `move > window` count falls from 195/236 digs toward zero. This one change is
most of the visible defect, and it costs one argument at each of the ten
`_reached_point` call sites that publish a target.

**2. Publish a start time, not only a duration.** Generalise
`movement_delay_seconds` from the approach to every family that publishes a
journey. Reception and dig already compute a read/recognition moment
(`defense_arrival`, `arrival`, `BallReadSystem.estimate_sequence`); the earliest
legitimate departure is derivable there. `_plan_fraction` already honours the key,
so presentation needs no change at all. This is what enforces the spec's
"cognition before movement" rule, and it is one key on an existing contract.

**3. Publish `movement_target` on `SET` and `ATTACK`.** Those two families
publish a start and a duration and no end (`grep '"movement_target"'` returns ten
publishers, none of them the setter or the hitter), which is why playback has to
guess the endpoint from `start_position` / `body_contact_position`. Closing this
lets one rule cover all families instead of two.

**4. Read the instruments that already exist.** `playback_start_mismatches` and
`playback_leg_overspeed` are recorded in `match_screen` and consulted by nothing;
`resolver_event_time` is preserved by `_finalize_rally_timeline` and read by
nothing; `receiver_arrived` is published and read by nothing. Gate 1 above against
`playback_start_mismatches` and the ATTACK->BLOCK->DIG interval against
`resolver_event_time` vs `physical_time`, and the fix becomes falsifiable without
a new probe.

**What I would not do yet.** Do not promote the shadow traversal, do not add
`PlayerMovementTrace`, and do not retire `playback_progress` in 2D. Those are all
downstream of whether 1-3 close the gap, and 1-3 are cheap enough to measure
first. If a residual snap survives them, it is the pose/root defect the spec
correctly insists on diagnosing separately -- and by then it will be the only
thing left, which is the whole point of doing them in this order.

## What was not measured

- **Cause E.** Pose/root onset needs a rendered run; nothing here bears on it.
- **The 2D path end to end.** `playback_progress` was read, not exercised.
- **The ace's outgoing trajectory.** The key is published on a failed reception;
  whether playback draws it was not confirmed.
- **The `RECEPTION -> RECEPTION` pair** (3 in 600). Noted, not investigated.
- **Whether fix 1 is outcome-neutral.** It changes only a published number, not a
  resolved one, but that must be measured rather than assumed.
