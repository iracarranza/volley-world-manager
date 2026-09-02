# The architectural gate, second pass

After repairs 1-4. The question:

> Can playback now derive each 3D player journey uniquely from authoritative
> simulation facts plus the shared movement model, without inventing pace, start
> time, endpoint, or cross-window continuity?

**Yes for every journey the simulator resolves. No for 79% of the legs playback
draws -- two thirds of all drawn travel -- because the simulator never resolved
them at all.**

That is a different answer from "the contract is incomplete", and it corrects
what `MOVEMENT_CONTRACT_GATE.md` said at `4b60055`.

## The correction that matters

At `4b60055` this record stated: *"every target in the plan is resolver-published.
Playback is inventing the pace, not the place."*

**That was wrong.** `_apply_cheat_steps` hands a target to every voli not
otherwise in the plan -- a bounded step toward `responsibility.lerp(action_target,
UNCOVERED_PULL)`, with an unstacking push. The destination is computed in
`match_screen.gd` from presentation constants. The error came from reading
`_apply_base_positions`, which *is* resolver-published, and generalising from it
without checking the function two calls above it.

Measured by `tools/probe_movement_plan.gd`, reading the real `MatchScreen` over
40 rallies -- **every** drawn leg, not only the window-paced ones:

| where the destination came from | legs | metres | mean m |
|---|---:|---:|---:|
| **cheat step -- invented by playback** | **1,194** | **1,117.2** | 0.94 |
| base return -- resolver-published, no journey | 168 | 329.5 | 1.96 |
| contact actor -- the resolved contact | 90 | 189.5 | 2.11 |
| phase entry | 33 | 18.1 | 0.55 |
| staging mark | 22 | 46.4 | 2.11 |
| **total** | **1,507** | **1,700.7** | |

**79% of drawn legs and 66% of drawn travel have a destination nothing in the
simulation chose.** 817 of those legs are also window-paced; the other 377 are
drawn at the body's own top speed because the step does not fit the window.

### The first version of this table was measured against a stale court

It read 863 of 1,563, and it was the intersection of *invented* and
*window-paced* rather than the population -- but the deeper fault was the
instrument. The probe built every window's plan without ever playing one, so
`live_positions` never advanced past the opening formation and
`_apply_cheat_steps`, `_apply_base_positions` and the start re-anchoring all
measured from a body that had not moved since the serve.

Walking each plan out before building the next moved three published figures:
start mismatches 54 → **28**, overspeed legs 30 → **23**, continued legs 8 → **3**.
Metadata-derived figures -- budgets, durations, leg ids, the early-leg counts --
are unaffected, because they never read the court.

## The four criteria

**Pace.** Closed for everything the resolver names. Off-ball legs with no
duration: 700 → **0 of 3,223**. Legs drawn slower than the body moves:
1,844 → **176**. Every off-ball family now paces between 0.96 and 1.24 where the
range was 0.67 to 1.48. Not closed for the 1,194, and cannot be: a leg with an
invented destination has no authored duration to read.

**Start time.** Partly. `movement_delay_seconds` on 151 of 151 attacks;
`movement_ready_seconds` on 75 of 164 receptions. Still absent on dig, set and
block, and the dig's absence remains structural -- `_read_adjusted_arrival` is
`distance_meters`, `reach_margin_meters`, `edge_ratio`, `read_error_meters`, all
lengths. The engine models where a read leaves a defender and never when they set
off.

**Endpoint.** Closed for every resolver-named leg. `body_contact_position` and
`physical_time` at 100% on every contact family; `movement_target` at 81 of 81
digs after repair 3 closed the continuation dig's missing duration. Open for the
1,194.

**Cross-window continuity.** Now expressible, and expressed with one field.
`movement_start_time` and `movement_leg_id` are derived where `physical_time` is
stamped; `_legs_issued_early` is a `player_id -> leg_id` dictionary. 8 legs issued
early, 8 continued, **0 issued twice**. It reaches only journeys whose earlier
stretch has a drawn window -- 9 of 40 rallies offer one -- and the rest are still
drawn compressed, with `playback_leg_overspeed` counting them at 23 in 40
rallies.

## Still no `PlayerMovementTrace`

The gate said criterion eight was the one argument for a consolidated record.
It turned out to want **two derived keys and one dictionary**. Nothing in the
remaining gap is a shape problem:

- the 1,194 cheat steps need a *decision*, not a record;
- the dig's departure time needs a *model*, not a field;
- the compressed remainder needs a *window that does not exist*.

A trace would carry a null duration for the first, a null start for the second,
and the same missing window for the third.

## What the 1,194 actually are, and why they were not removed here

`_apply_cheat_steps` is the drift the big comment in `_build_movement_plan`
describes removing -- *"twelve volis edged toward every contact for the whole
rally because a 2D top-down view once needed the court to look alive"* -- and it
is still there, bounded to one `CHEAT_STEP_METERS` step per window.

Whether a voli not involved in the play should lean toward the ball is a question
`docs/design/OFF_BALL_MOVEMENT.md` governs, not one the movement contract can
answer. It is not a broken fact; it is presentation deciding something the
simulation has no opinion about. Removing it would change what the court looks
like for 55% of drawn legs, which is a design call and belongs to whoever owns
that document.

**It is not inert, and that is the part worth carrying forward.** A cheat step
moves the body, and the next resolver-timed leg is drawn from where it left them
-- which is exactly what `playback_start_mismatches` counts, 28 in 40 rallies.
So the invented movement is upstream of the legs these four repairs spent their
effort timing. It cannot change a rally outcome; it can change where an
authoritative journey is drawn from.

What this pass can say, and now does: **1,194 legs of 1,507 and two thirds of the
drawn travel, measured, and the only remaining population where playback invents
a destination.**

## Verified unchanged throughout

`run_rally_balance_probe.gd` over 700 rallies is byte-identical to the pre-repair
reading after every one of the four repairs -- six separate runs. No resolved
contact, quality, or outcome moved.
