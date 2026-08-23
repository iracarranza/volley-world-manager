# C0 — action-window census, and what C5/C6 did about it

The packet's C0 is done "when the implementation agent can state, for each
canonical leg, why every on-court player is or is not moving". Twelve volis per
contact, so the honest way to answer it is to count how many of them the
resolver said anything about at all.

`tools/run_action_window_census.gd` runs 300 rallies and sorts every voli-leg
into three states:

- **published** — the resolver put them in `home_phase_targets` or
  `opponent_phase_targets`. Simulation decided where they went.
- **contacting** — they are the actor. Their movement *is* the event.
- **silent** — nothing published, and they did not touch the ball.

A silent voli is not standing still. `tactical_court._support_target_for_side`
invents a target for them out of their base position and the action point, which
is presentation authoring movement the resolver never decided — the thing
`01_TARGET_AUTHORITY_STATE` §9 forbids in as many words.

## Before

| leg | events | published | contacting | silent | w/ timing |
|---|---:|---:|---:|---:|---:|
| SERVE | 300 | 0 | 300 | 3300 | 0 |
| RECEPTION | 242 | 2904 | 242 | 0 | 0 |
| SET | 273 | 1517 | 273 | 1486 | 0 |
| ATTACK | 273 | 1350 | 273 | 1653 | 0 |
| BLOCK | 225 | 1707 | 225 | 768 | 0 |
| DIG | 134 | 647 | 134 | 827 | 0 |
| ATTACK_COVERAGE | 10 | 0 | 10 | 110 | 0 |

- resolver placed **54.1%** of voli-legs
- presentation invented **45.9%**
- **0 of 8,125** placed volis carried a duration

**Two of those three numbers were wrong, and this instrument is why.** See
"The serve leg was never silent" at the foot of this file. The duration row was
correct.

That last row is the C6 defect stated as a missing field rather than as a
drawing complaint. Every phase map published a destination and a fraction of the
journey covered, and nothing about time — so a voli who crossed two metres in
0.31 s of a 1.14 s window and then stood waiting was indistinguishable, in
everything downstream, from one who spent the whole window walking. Playback,
given a start, an end and a window, draws the second.

## C6 — every journey now says when it ended

`_travel_intent` replaces the `{intent, progress}` literal at all six phase-map
sites and adds `traversal_seconds`, `window_seconds` and `arrival_progress`.

The resolver has always known the answer. `_reached_point` computes
`_movement_time` to decide whether the target is reachable, then throws the
number away and returns a position. Asking the same authority for the time to
where the voli *actually got* costs one more call and invents nothing — no new
speed, no new relation, no window-filling.

A journey that was cut short comes back with `traversal == window` by
construction, because `_reached_point` bisects to exactly the point the window
buys. That is correct and not a special case: a voli who ran out of time did not
arrive early.

## C5 — the floor defence walks into its shape instead of appearing in it

`_floor_phase_positions` computes the shape the defensive plan asks for — zones,
depth, seam, the wall's two shoulders — and all **three** of its callers wrote
that shape straight into the live position map. The defence arrived in the
diagram the instant the attacker swung, from wherever the previous phase had
left them, across any distance, for free.

This was gameplay, not drawing. The shape is handed to
`CoverageModel.choose_claimant` as the defenders' real positions for the dig
reach check, so a defender who had no time to reach their zone was still
reaching from inside it.

`_establish_shape` walks them instead, through the same `_reached_point` every
other off-ball leg in the engine uses, with the set flight as the window.
Partial establishment stays partial — a defender who cannot cover the distance
stops where the time ran out.

Applied at all three sites in one helper, deliberately. The B4 defect this same
pass repaired was one of two symmetric paths drifting from its twin; three
copies of a walk would be the same mistake with an extra copy.

## After

| leg | events | published | contacting | silent | w/ timing |
|---|---:|---:|---:|---:|---:|
| SERVE | 300 | 0 | 300 | 3300 | 0 |
| RECEPTION | 242 | 2904 | 242 | 0 | 1452 |
| SET | 270 | 1502 | 270 | 1468 | 818 |
| ATTACK | 270 | 1326 | 270 | 1644 | **1169** |
| BLOCK | 221 | 1680 | 221 | 839 | **1680** |
| DIG | 133 | 647 | 133 | 868 | 335 |
| ATTACK_COVERAGE | 10 | 0 | 10 | 110 | 0 |

**5,454 of 8,059** placed volis now carry a duration, from 0. `ATTACK` went from
0 to 1,169 and `BLOCK` to all 1,680.

### What it cost

Measured over 700 rallies on `tools/run_rally_balance_probe.gd`, before → after:

| | before | after |
|---|---:|---:|
| contacts per rally | 4.771 | 4.796 |
| kill rate | 0.661 | 0.659 |
| swing balance | 0.934 | 0.931 |
| dig rate | 0.387 | 0.393 |
| home dig rate | 0.432 | 0.445 |
| opponent dig rate | 0.348 | 0.350 |
| stuff rate | 0.114 | 0.115 |
| ace / serve error / reception quality | unchanged | unchanged |

No band moved out. Nothing was tuned to make that true, and the direction is
worth stating because it is the opposite of the naive expectation: making
defenders travel raised the dig rate slightly rather than lowering it. The
teleport was not a *buff*, it was a **relocation** — it pulled every defender to
the plan's nominal zone whether or not they were already better placed for the
ball that was actually coming. Walking them from where they really stood leaves
a well-positioned defender where they were.

This is an F5 observation. It is recorded, not fitted.

## What is still silent

Measured after the receive-geometry unification, and after the correction below:

| leg | silent voli-legs |
|---|---:|
| ATTACK | 1,714 |
| SET | 1,516 |
| DIG | 901 |
| BLOCK | 851 |
| ATTACK_COVERAGE | 143 |

Not one leg but five, and the shape is consistent: each of these events publishes
the *defending* side's map and not the acting side's. An attack event names the
six who are defending it; the six attacking are described on the SET event before
it or not at all. So the remaining gap is one repair applied five times — publish
the acting side's off-ball map through `_establish_shape` and the existing phase
maps — and it is `FIRST_DRAFT_DEBT.md`'s FD-002 and FD-003 as a single family
rather than two entries.

They are grouped on purpose. Each of those maps calls `_reached_point`, so each
one *moves volis*; closing them one at a time would mean five overlapping
distribution measurements of one change.

**Two claims that used to live in this section are gone.** The serve leg is not
silent — see below. And the receive formation is no longer a placement: it seeds
`live_positions` at rally initialization, so it is the spawn position, the
reception claim's origin and the start of every later traversal at once, measured
at 0 of 2,110 bystander displacement.

## The serve leg was never silent

The 45.9% above, and the 46.4% after C5, both counted the serve's other eleven
volis as invented by presentation. They are not.

**A rally's first contact has no preceding interval.** Playback draws a leg as
`event -> next_contact` and reads its targets off `next_contact`, so nothing
precedes the serve and there is no interval in which anybody could have moved.
Both sides' serve-flight movement is published on the RECEPTION event — the
receiving side's shape and the serving side's transition, all twelve — because
that is the only event where it can be drawn.

The resolver has said so the whole time. `_receive_formation_map`'s own note
records measuring 400 serves of 400 with no preceding flight, and gives that as
the reason the map is published where it is.

So this census was scoring a leg that does not exist: a threshold measured
against the wrong distribution, committed by the instrument written to find
those. It now carries a `no leg` column and excludes it.

| | claimed | measured |
|---|---:|---:|
| resolver placed | 54.1% | **65.2%** |
| presentation invented | 45.9% | **34.8%** |

FD-001 is withdrawn on that evidence rather than repaired — there was nothing to
repair. What was real inside it, the receive formation being a placement at
coordinates gameplay did not use, is FD-004, and that is closed and certified.

At 34.8%, presentation still invents a third of the off-ball drawing, across the
SET, ATTACK, BLOCK, DIG and coverage legs. That is the honest headline of the
remaining work, and §10 of `01_TARGET_AUTHORITY_STATE.md` names it as permitted
in a complete first draft: "presentation lag behind newly authoritative state".
