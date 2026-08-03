# Playback movement audit

Date: 2026-08-03
Measured at: `ae06074` (before) and this commit (after)
Tool: `tools/run_playback_audit.gd`

## The report

Four observations from watching 3D playback, all from one session:

1. Defensive actions read as several actions rather than one.
2. Opponent attacks look impossible — "their opposite slides all the way from
   one pin to another as the set goes up with tempo."
3. A suggestion: resolve each player against their own timeline and the ball,
   rather than putting everyone on one shared continuous timeline.
4. A question: are home and opponent reversed in playback?

## Method

`tools/run_playback_audit.gd` replays `match_screen.gd`'s own bookkeeping
headlessly — the same live-position dictionary, the same `_build_movement_plan`
targets, the same per-flight durations — over a full match, and reports the
ground each player is asked to cover in the time the ball is in the air. It
also checks every event's declared side against roster membership, and flags
any player who contacts the ball twice in a row.

## 4. Home and opponent are not reversed

**0 of 71 rallies** contained an event whose declared side disagreed with the
roster. Geometry checks out too: `CourtConstants.ROTATION_SLOT_POSITIONS` puts
home at y 0.56–0.87, `mirror_to_opponent` puts the opponent at 0.13–0.44,
`tactical_to_world` maps y to +z, and the broadcast camera sits at z = +10.8.
Home is the near side and always was.

What almost certainly produced the impression is finding 2 below: an opponent
hitter sliding across the whole width of the net mid-set does not look like a
player on their own half.

## 2. The impossible attacks were real, and measurable

| transition | n | over 6.5 m/s | worst |
| --- | ---: | ---: | ---: |
| Serve → Reception | 57 | 0 | 3.2 m/s |
| Reception → Set | 57 | 0 | 4.2 m/s |
| **Set → Attack** | **70** | **37** | **25.5 m/s** |
| Attack → Block | 67 | 6 | 14.2 m/s |
| Block → Defense | 16 | 15 | 19.9 m/s |
| Defense → Set | 13 | 2 | 8.6 m/s |

The worst case is exactly the one reported: opponent 104, the opposite, drawn
from (0.18, 0.16) to (0.82, 0.48) — 8.15 m — in the 0.32 s a quick set is in
the air. **25.5 m/s**, about two and a half times the peak speed of the 100 m
world record.

Three separate causes, all in `_choose_opponent_attack`:

- **The contact point was a fixed pin per position code.** An OP was always
  given (0.82, 0.48) and an OH always (0.18, 0.48), regardless of where the
  rotation had actually placed them — including when they were in the back row,
  where taking off at the net is a violation as well as a sprint.
- **Arrival was priced at almost nothing.** `lateness` cost at most 0.12 of the
  option score against 0.42 for attack power and ±0.12 of random noise. The
  biggest arm won the swing from anywhere on the court.
- **Ranking cannot fix a scramble.** Raising the lateness penalty was tried
  first and made things worse elsewhere: when every candidate is late the
  penalty saturates for all of them, the comparison collapses back onto the arm,
  and the offence collapses onto the middles — who start at the net and are
  never late. That broke three tests (hitter variety, non-middle blocks,
  non-blocker floor defense) because the opponent stopped attacking anywhere but
  the middle.

So the geometry gives instead of the ranking. `_reachable_attack_contact()`
bisects the segment from the hitter to their ideal contact point and returns
the furthest point they can actually reach in the set's flight. A scrambling
team hits from where it can get to, which is what a scrambling team does, and
the existing approach machinery degrades that swing without a special case.

`_opponent_attack_contact()` additionally reads the rotation, so a back-row
hitter contacts behind their attack line (y = 0.30) rather than at the tape.

## 1. Defensive actions reading as several actions

**8 occurrences in 71 rallies, all of them "Block then Defense" by the same
player.** This is legal — a block touch is not one of the team's three contacts,
so a blocker may play the ball immediately after blocking it. The problem was
entirely in how it was drawn, in two ways:

- **The pose.** `_apply_contact_poses` posed the outgoing event and then the
  incoming one. For one player that meant the incoming pose overwrote the
  outgoing one at every progress value, with an elevation of zero until
  progress 0.48 — so the block collapsed to a standing dig the instant the
  deflection started travelling. Now whichever pose currently carries more
  weight is the one drawn, and the block holds until the dig genuinely takes
  over.
- **The teleport.** Deflection flights were three hardcoded constants between
  0.18 s and 0.30 s regardless of distance, and a defender chasing one was
  drawn covering up to 4.8 m inside 0.24 s. They now solve the same launch arc
  every other flight in the file solves, at a 30° squirt-off-the-hands angle: a
  four-metre deflection hangs for about 0.7 s. A stuff keeps its constant,
  because the rally ends on it and nobody chases.

Playback also now starts each actor's drawn journey at the simulator's own
`movement_start` rather than wherever the previous leg left them, so the two
stop disagreeing about where a contact began.

## Result

| metric | before | after |
| --- | ---: | ---: |
| movements above 6.5 m/s | 21.4% | 5.7% |
| worst Set → Attack | 25.5 m/s | 8.7 m/s |
| Block → Defense over-speed | 15 of 16 | 4 of 24 |
| median implied speed | 3.09 m/s | 2.06 m/s |

Two regression tests now hold the line
(`_test_playback_movement_is_humanly_possible`). The attacker-speed bound fails
at 13.1 m/s against the pre-fix simulator and passes after.

## Balance consequence, and what paid for it

Hitters swinging from where they can reach moved the mean opponent contact from
y 0.480 (at the tape) to y 0.416 — about 1.5 m off the net. The block model had
no term for contact depth: it read lane alignment and timing only, so a ball
struck three metres back was contested exactly like one struck at the tape. The
home stuff-block rate rose from **0.134 to 0.227**, through its 0.22 ceiling.

`BLOCK_DEPTH_RELIEF_WEIGHT` adds the missing term — full relief at the attack
line, because a back-row swing crosses higher and later while the blockers are
pressed to the net. Stuff rate lands at **0.128** against a pre-change baseline
of **0.134**. That is a physically motivated term restoring a measured
baseline, not a threshold moved to make a change pass.

## Two tests were passing on noise

Both surfaced because this work shifted the rally RNG stream. Neither is a
regression in the simulation.

**"changing only team identity produces a visibly different first-match
scoreline."** Measured across twelve fixture-seed bases, two identities land on
the *same* final scoreline **6 times out of 12**. A fifteen-point set has few
enough end states that different rally sequences converge often. The assertion
was a coin flip. It now requires at least one differing scoreline across six
bases — same meaning, false-failure rate under 2%.

**"defensive attack lowers both error risk and terminal pressure."** Two claims
in one assertion, with very different strength:

| samples | Physical attack error | Defensive attack error | Physical kill | Defensive kill |
| ---: | ---: | ---: | ---: | ---: |
| 12 | 0.1362 | 0.1501 ✗ | 0.4716 | 0.3902 ✓ |
| 24 | 0.1627 | 0.1609 ✓ | 0.4790 | 0.3957 ✓ |
| 36 | 0.1680 | 0.1672 ✓ | 0.4809 | 0.4128 ✓ |
| 48 | 0.1782 | 0.1721 ✓ | 0.4755 | 0.4026 ✓ |

Terminal pressure is robust: correctly signed at every count, 15% relative at
48 samples. The error-rate claim is about 3% relative and its **sign flips at
the 12 samples the suite actually runs**. It was passing on noise. The
assertion now covers the half that can be resolved; the error-rate figures live
here rather than in a gate.

This is the same failure mode flagged earlier on `claude/body-types-wip`
("physical serving creates more pressure, aces, and errors across six career
seeds"), and the same diagnosis applies: that test family runs below the
resolution its sample count can support.

## Follow-up: beaten defenders are now drawn short of the ball

The next step named at the bottom of this document has since been implemented.
`_reached_point()` bisects the run from a player's start to the contact against
`_movement_time`, and returns the furthest point they could actually reach in
the flight they had. It is bisected rather than scaled by the time fraction
because locomotion has an acceleration phase: a player who has spent 60% of the
time has covered less than 60% of the ground, and the gap is largest at the
start of the run, which is the part most visible.

It is emitted as `movement_target` from six sites — both receptions, both floor
defences, the block-touch coverer, and the transition dig, which previously
carried no spatial metadata at all. Both playback views already read
`movement_target` (`match_screen.gd` via `_build_movement_plan`,
`tactical_court.gd` via `_movement_action_target`), so neither needed changing.
The live-position bookkeeping was updated with it too: a defender who was beaten
to the ball starts the *next* phase short of it, which is what the rest of the
rally should reason from.

Reception already did a binary version of this — target the ball if the passer
arrived, otherwise don't move them at all. That is now partial as well, so a
passer who nearly got there is drawn nearly getting there.

Making live positions honest exposed a second problem it had been masking.
Opponent blockers were only walked to the wall during the *attack-to-block*
segment, which can be 0.14 s, so a blocker caught deep in transition covered
seven metres inside it — 51.8 m/s, worse than anything in the original report.
It had been hidden because live positions were previously overwritten onto the
ball, which happened to leave players nearer the net. The home side already
forms its wall during the preceding flight via `home_phase_targets`; both
opponent block paths now do the same through `opponent_phase_targets`, which is
why only opponent blockers ever appeared in this table.

| transition | over 6.5 m/s | worst |
| --- | ---: | ---: |
| Serve → Reception | 0 of 65 | 1.6 m/s |
| Reception → Set | 0 of 65 | 4.3 m/s |
| Set → Attack | 4 of 356 | 12.9 m/s |
| Attack → Block | 0 of 44 | 1.0 m/s |
| Block → Defense | 0 of 59 | 6.1 m/s |
| Defense → Set | 3 of 25 | 12.2 m/s |

Overall: **1.1% of movements above 6.5 m/s, worst 12.9 m/s** — from 21.4% and
25.5 m/s in the original report, and 5.7% / 17.9 m/s after the first pass.
`Block → Defense`, which was 15 of 16 over-speed at the start, is now zero.

## 3. Per-player timelines — not done, and worth doing

The suggestion was to resolve each player against their own timeline and the
ball, so a defender can still be mid-dive while the ball travels and the setter
is already moving. That is right, and it is what the remaining residue is made
of. Two cases survive everything above, and they share a shape: **the contact
happens, so the player cannot be drawn short of it.**

- `Defense → Set` at 12.2 m/s — a setter chasing a dug ball 7 m across a 0.58 s
  flight. The setter does touch it; `setter_capability.reach_state` records
  `beyond_reach` and the set is degraded accordingly. Drawing them short would
  mean the ball sets itself.
- `Set → Attack` at 12.9 m/s — a home hitter's final 2 m of run-up inside a
  0.16 s quick set. Same thing: the swing happens, late and degraded.

Both are cases where the run genuinely overlaps the previous action rather than
starting when the ball is struck — the setter is already moving as the dig goes
up, the hitter is already approaching before the set is released. A per-player
timeline models that directly; a plan-per-flight cannot express it at all.

The engine already has most of the parts: `RallyPlayerState` carries position
and velocity, `ApproachMechanicsModel` reasons about arrival margins,
`RallyMovementSystem` has a closed-form traversal time. What is missing is that
playback consumes a *plan per flight* rather than a *timeline per player*. That
is a real piece of work — a new contract between the simulator and
`match_screen.gd` — and it should be its own change rather than a rider on this
one.

The smaller step that came first — drawing a beaten defender where they got to
— is done, and it took the residue from 5.7% of movements to 1.1%. What is left
needs the timeline.
