# The architectural gate: does the contract compose into one interpretation?

`docs/implementation/SIMULATION_PLAYBACK_AUTHORITY_HANDOFF.md` requires this
question to be answered explicitly after changes 1-5, before any new
movement-trace abstraction is considered:

> Does the existing metadata + shared movement model now define every physical
> player journey unambiguously enough that playback only renders it, or does
> playback still have to infer physical history?

**Answer: no, and the shortfall is now a short, measured list rather than an
argument.** Three facts do not exist anywhere in the record; one fact exists
twice and disagrees with itself; and 61% of drawn legs still take their pace from
the ball rather than from anything that timed them.

Below, each of the handoff's nine gate criteria against measured evidence.

## The nine criteria

| must playback still infer... | verdict | evidence |
|---|---|---|
| movement start time | **yes, for four of five families** | `movement_delay_seconds` on ATTACK only (151/151); `movement_ready_seconds` on 75 of 164 receptions; nothing on DIG, SET, BLOCK |
| movement endpoint | **no** | `body_contact_position` 100% on every family, filled by `_add_event` from `live_positions`; `_build_movement_plan` reads it in preference to the ball |
| available / deadline time | **no, for contacts; yes, for off-ball** | `movement_available_seconds` on 100% of platform contacts after change 1; off-ball has `window_seconds` only where `_travel_intent` built the entry |
| carried start velocity | **yes, for three of five** | `movement_entry_velocity` on ATTACK and SET only |
| movement mode | **partly** | intent names exist (`covering`, `defending`, `blocking`, `preparing_attack`, `receiving`); 231 off-ball targets carry no intent entry at all |
| waypoint / target changes | **no** | `approach_start_position`, `navigation_waypoint` published and read |
| whether a movement completed | **no** | `movement_target` vs `body_contact_position` says it; `progress` on off-ball intents says it |
| whether a movement continues across an intermediate contact | **yes** | `_plan_fraction` carries an unfinished leg forward only if the next window re-issues the same target. Nothing published says "this is the same journey" |
| which position is authoritative when representations disagree | **yes** | `movement_start` vs `live_positions` vs `actor_leg_start` -- `_build_movement_plan` re-anchors to the visible position and records the gap in `playback_start_mismatches`, 20 in 12 rallies |

## The three facts that do not exist

Publishing more keys cannot reach these. Nothing computes them.

1. **The block close is untimed.** 116 of 116 BLOCK contacts publish no
   `movement_start`, `movement_target` or `movement_duration`; 137 of 137
   `blocking` off-ball legs publish no `traversal_seconds`. Start and end both
   exist (`actor_leg_start` and `body_contact_position`, 116/116) -- only the
   duration is missing, and no block timing model produces one with
   `ENABLE_BLOCK_JUMP_TIMING` closed.
2. **The dig has no departure time.** `_read_adjusted_arrival` is entirely
   lengths -- `distance_meters`, `reach_margin_meters`, `edge_ratio`,
   `read_error_meters`. The engine models where a defender's read leaves them and
   never when they set off.
3. **231 off-ball targets carry no intent entry at all**, so not even a family
   name.

## The fact that exists twice and disagrees

4. **30 of 99 receptions cannot honour both their departure time and their
   traversal**, by a mean 0.137 s on a 1.18 s window (change 2). **97 of 109 digs
   have a budget longer than the window they are drawn in** (change 1), because
   `attack_time` is floored at `BLOCK_DEFLECTION_MIN_SECONDS` while
   `physical_time` places the dig at the end of the deflection flight.

Both are two authoritative statements about one journey. A third record would
have to pick a winner, and picking is a simulation decision, not a contract one.

## What playback still infers, measured in the screen itself

`tools/probe_movement_plan.gd` instantiates the real `MatchScreen` and calls the
real `_build_movement_plan` / `_pace_plan`. Over 12 rallies, **568 legs**:

| | legs |
|---|---:|
| paced | 568 |
| duration taken from the ball's flight because nothing timed the leg | **346 (61%)** |
| a legitimate departure time applied | 15 |
| a departure time published but refused because the journey no longer fit | 3 |
| drawn start disagreeing with the timed start | 20 |
| drawn faster than a body moves | 13 |

The 61% is higher than Gate 0's 21%-untimed because Gate 0 counted only the
resolver's phase maps, and playback draws legs from three further sources: base
returns, staged next positions, and the contact actor.

**But the destinations are not invented.** `_apply_base_positions` reads
`active_result.home_base_positions`; `_apply_explicit_targets` reads the phase
maps; the contact actor goes to `body_contact_position`. Every target in the plan
is resolver-published. **Playback is inventing the pace, not the place** -- which
is a materially smaller and differently-shaped problem than the handoff's
historical list suggests.

## Recommendation: still no `PlayerMovementTrace`

The handoff's own test is "whether they compose into exactly one physical
interpretation." They do not. But every one of the four shortfalls above is a
**missing or contradictory simulation fact**, and a new record would carry the
same hole or the same contradiction under a new name:

- a trace for a block close would have a null duration;
- a trace for a dig would have a null start time;
- a trace for those 30 receptions would have a `start_time` and an `end_time` that
  cannot both be satisfied by the `end_position` beside them;
- a trace for the 231 unnamed targets would have no mode.

The one thing a consolidated record *would* buy that keys cannot is criterion
eight -- **journey identity across an intermediate contact**. Nothing today says
"the leg in this window is the continuation of the leg in the last one", and
`_plan_fraction`'s carry-over works only by coincidence of target. That is a real
argument for a trace, and it is one argument, not nine.

**Recommended before reconsidering the abstraction, in order:**

1. **Time the block close.** It is the largest single untimed population, its
   start and end are already published, and `ShadowMovementSystem` can time the
   journey between two known points with no new model. This is the cheapest
   remaining pace improvement and it needs no new record.
2. **Decide the dig's two budgets.** Either `attack_time` should not be floored
   for the purpose of drawing, or `physical_time` places the dig too early. One
   of them is wrong and the answer is a measurement, not a key.
3. **Give the 231 unnamed off-ball targets an intent**, which makes them
   `_travel_intent` entries and times them for free.
4. **Then** ask whether journey identity across contacts justifies a record. If it
   does, it justifies a *leg id*, which is one field, not a parallel structure.

## What was not done, and is not blocked on the gate

- **2D still normalises its time axis away** (`tactical_court:725`). Changes 1-5
  improve the numbers it receives; it discards them. The handoff sequences this
  after the 3D work, correctly.
- **The pose track is untouched.** A residual snap at DIG or RECEPTION after these
  changes is expected and is the separate diagnosis the handoff insists on.
- **The ace's phantom `outgoing_trajectory`** (`rally_simulator.gd:1495-1517`) --
  the handoff calls it a small independent authority bug and it still is.
- **No rally was rendered.** The repository's only playback renderer draws the
  ball (`tools/render_rally_frames.gd`); nothing films the players. The plan probe
  above is the closest available evidence and it reads the real planner rather
  than a reproduction of it, but it is numbers, not frames.
