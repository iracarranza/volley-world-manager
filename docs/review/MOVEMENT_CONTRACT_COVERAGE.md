# Changes 3-5: what the movement contract actually says

`docs/implementation/SIMULATION_PLAYBACK_AUTHORITY_HANDOFF.md` changes 3, 4 and
5, measured by `tools/run_movement_contract_coverage.gd` (200 rallies) and
`tools/run_offball_timing_baseline.gd` (300 rallies, seeds 61000-61149).

## Change 3 was already done, under a different name

The handoff asks for `movement_target` on `SET` and `ATTACK`, "if still missing at
current HEAD". It is missing -- and it does not matter, because
`_add_event:12840` fills **`body_contact_position`** for every contact that does
not set one, from `live_positions[actor_id]`, and `_build_movement_plan:1487`
already reads it in preference to the ball. The endpoint is resolver-authoritative
and playback is not inferring it.

The audit is the point rather than the assertion:

| family | n | move_start | move_target | duration | budget | ready | delay | entry_v | body_pos | leg_start | phys_time |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| ATTACK | 151 | 151 | 0 | 151 | 0 | 0 | **151** | 151 | 151 | 151 | 151 |
| BLOCK | 116 | **0** | **0** | **0** | 0 | 0 | 0 | 0 | 116 | 116 | 116 |
| DIG | 81 | 81 | 81 | 81 | 81 | 0 | 0 | 0 | 81 | 81 | 81 |
| RECEPTION | 164 | 162 | 162 | 162 | 162 | 75 | 0 | 0 | 164 | 164 | 164 |
| SET | 151 | 151 | 0 | 151 | 0 | 0 | 0 | 151 | 151 | 151 | 151 |
| ATTACK_COVERAGE | 3 | 3 | 3 | 3 | 3 | 0 | 0 | 0 | 3 | 3 | 3 |
| SERVE | 200 | 200 | 200 | 0 | 0 | 0 | 0 | 0 | 200 | **0** | 200 |

`body_contact_position` and `physical_time` are at **100% on every family**, and
`actor_leg_start` at 100% everywhere except the serve, where its absence is
deliberate: a rally's first contact has no previous leg, and filling it would
report every server as having travelled nowhere.

**One real hole was found and closed.** `DIG` read 69 of 81 on `movement_duration`
before this pass: the continuation transition dig published a start and an end and
no time between them, so twelve digs per hundred rallies fell back to the whole
window. The figure was not missing, only unpublished -- `cont_defense.travel_time`
is what the body velocity two blocks above has always been built from. `DIG` now
reads 81 of 81 on all four leg keys.

**One hole remains and is not closeable by publishing.** `BLOCK` has no movement
keys at all. Its start and end exist -- `actor_leg_start` and
`body_contact_position`, both at 116 of 116 -- but nothing anywhere times the
close. See the gate below.

## Change 4: the instruments are now consumed

- `playback_start_mismatches` -- already collected, reported by
  `playback_geometry_report()`.
- `playback_leg_overspeed` -- collected.
- **`playback_late_departures`** -- new in change 2, reported through
  `playback_geometry_report().late_departures`.
- `resolver_event_time` -- preserved by `_finalize_rally_timeline`, still read by
  nothing. Left alone: `physical_time` is the clock playback uses and it is at
  100%, so the resolver's superseded stamp is a historical record rather than a
  live fact.
- `receiver_arrived` -- still unread by playback. Its content is now carried more
  precisely by `movement_target` versus `body_contact_position`.

`tests/test_runner.gd` gains **four checks** that hold the contract closed, so the
next regression is a red suite rather than a re-measurement: every platform
contact publishing an endpoint also publishes its budget and its duration; every
contact publishes where the body was and when the contact happened; every contact
but an actor's first publishes where its leg began.

## Change 5: the off-ball clock that was already being computed

`_travel_intent` publishes `traversal_seconds` and `window_seconds` per off-ball
player. `_apply_explicit_targets` passed only the *targets* map to
`_set_plan_target`, which writes no `seconds`, so `_pace_plan` fell back to
`active_window` and stretched every off-ball journey across the ball's flight
however far it was. It now carries the intents map too.

Against the Gate 0 baseline, same seeds, same probe:

| family | n | timed | pace before | pace after |
|---|---:|---:|---:|---:|
| covering | 1238 | 1238 | 1.48 | **1.03** |
| defending | 1288 | 1288 | 0.82 | **0.94** |
| receiving | 43 | 43 | 0.87 | **1.00** |
| preparing_attack | 355 | 128 | 1.45 | 1.22 |
| unnamed | 336 | **0** | 0.73 | 0.73 |
| blocking | 137 | **0** | 0.67 | 0.67 |

**Legs drawn slower than the body moves: 1,844 → 781, of 3,397.** The 781 that
remain are almost exactly the 700 untimed legs -- 137 blocking, 336 with a target
and no intent entry at all, 227 of `preparing_attack`.

`completable`, `early` and `cannot_complete` are **unchanged**, which is the
condition Gate 0 set: those are properties of the movement model and the window,
and a presentation change that moved them would have moved the simulation.

Outcomes are unchanged through all five changes: `run_rally_balance_probe.gd` over
700 rallies is byte-identical to the pre-change reading.

## Carried to the architectural gate

Three facts do not exist anywhere in the record, and no further key can publish
what nothing computes:

1. **The block close is untimed.** 116 of 116 BLOCK contacts and 137 of 137
   `blocking` off-ball legs. Start and end are both published; the duration is not
   computed by anything.
2. **The dig has no departure time**, and `_read_adjusted_arrival` is entirely
   lengths, so the arrival record cannot supply one.
3. **231 off-ball targets carry no intent entry at all**, so not even a family
   name, let alone a duration.

And one fact exists twice and disagrees with itself:

4. **30 of 99 receptions cannot honour both their departure time and their
   traversal** (change 2), and **97 of 109 digs have a budget longer than the
   window they are drawn in** (change 1).
