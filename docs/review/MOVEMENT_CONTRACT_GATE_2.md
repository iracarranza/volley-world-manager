# The architectural gate, second pass

After repairs 1-4. The question:

> Can playback now derive each 3D player journey uniquely from authoritative
> simulation facts plus the shared movement model, without inventing pace, start
> time, endpoint, or cross-window continuity?

**Yes for every journey the simulator resolves. No for 55% of the legs playback
draws, because the simulator never resolved them at all.**

That is a different answer from "the contract is incomplete", and it corrects
what `MOVEMENT_CONTRACT_GATE.md` said at `4b60055`.

## The correction that matters

At `4b60055` this record stated: *"every target in the plan is resolver-published.
Playback is inventing the pace, not the place."*

**That was wrong.** `_apply_cheat_steps` hands a target to every voli not
otherwise in the plan -- a bounded step toward `responsibility.lerp(action_target,
UNCOVERED_PULL)`, with an unstacking push. The destination is computed in
`match_screen.gd` from presentation constants. Measured by
`tools/probe_movement_plan.gd`, reading the real `MatchScreen` over 40 rallies:

| source of a leg whose duration is still the ball's flight | legs |
|---|---:|
| **cheat step -- destination invented by playback** | **863** |
| base return -- destination resolver-published, no journey | 57 |
| phase entry whose intent carries no traversal | 29 |
| contact actor whose own event published no duration | 16 |
| staging mark the resolver named | 2 |
| **total window-paced** | **967 of 1,563** |

863 of 1,563 drawn legs -- 55% -- have a destination nothing in the simulation
chose. The error was mine and it came from reading `_apply_base_positions`, which
*is* resolver-published, and generalising from it without checking the function
two calls above it.

## The four criteria

**Pace.** Closed for everything the resolver names. Off-ball legs with no
duration: 700 → **0 of 3,223**. Legs drawn slower than the body moves:
1,844 → **176**. Every off-ball family now paces between 0.96 and 1.24 where the
range was 0.67 to 1.48. Not closed for the 863, and cannot be: a leg with an
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
863.

**Cross-window continuity.** Now expressible, and expressed with one field.
`movement_start_time` and `movement_leg_id` are derived where `physical_time` is
stamped; `_legs_issued_early` is a `player_id -> leg_id` dictionary. 8 legs issued
early, 8 continued, **0 issued twice**. It reaches only journeys whose earlier
stretch has a drawn window -- 9 of 40 rallies offer one -- and the rest are still
drawn compressed, with `playback_leg_overspeed` counting them at 30 in 40
rallies.

## Still no `PlayerMovementTrace`

The gate said criterion eight was the one argument for a consolidated record.
It turned out to want **two derived keys and one dictionary**. Nothing in the
remaining gap is a shape problem:

- the 863 cheat steps need a *decision*, not a record;
- the dig's departure time needs a *model*, not a field;
- the compressed remainder needs a *window that does not exist*.

A trace would carry a null duration for the first, a null start for the second,
and the same missing window for the third.

## What the 863 actually are, and why they were not removed here

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

What this pass can say, and now does: **it is 863 of 1,563, it is measured, and
it is the only remaining population where playback invents a destination.**

## Verified unchanged throughout

`run_rally_balance_probe.gd` over 700 rallies is byte-identical to the pre-repair
reading after every one of the four repairs -- six separate runs. No resolved
contact, quality, or outcome moved.
