# Discussed but not implemented

Shared backlog for the two-agent workflow (Claude on the container, Codex on
the local machine). Everything here was designed, agreed, or half-built in
conversation and is *not* in `main` today. Measured at `7d94cdd`.

Order within each section is rough implementation order, not priority.

---

## 1. Body types — secondary layer done, primary layer missing

Branch: `claude/body-types-wip`, rebased onto `main`, **645 checks green**.

Landed:

- `body_type` on `VolleyballPlayer` (categorical, alongside `dominant_hand`,
  deliberately *not* in `ABILITY_ATTRIBUTES`), serialized both ways.
- `BODY_TYPES` / `BODY_TYPE_METRICS` (height, mass, wingspan) /
  `BODY_TYPE_ATTRIBUTES` in `player_generator.gd`, applied to ceilings before
  storage, wired into both generation paths.
- Uniform assignment across all regions, now enforced by
  `_test_body_type_distribution_is_flat` rather than only stated in prose. It
  fails naming the region and the type — a deliberate 50% Ursi bias in
  Landavol is reported as "Ursi in Landavol, 44.1% against 16.7%".

Still missing:

- **The `SystemFitProfile` shifts.** This is the primary layer per §2 of the
  design doc — body type is supposed to move `ideal_value` / `tolerance` /
  `in_system_bonus` so a Cani setter and a Feli setter are *suited
  differently*, not ranked. Only the secondary metric/attribute/ceiling layer
  is in, which means body types are currently stat blocks: exactly what §2
  says the feature must not be.
- **Ceiling-persistence test** — assert the ceiling deltas survive a
  save/load round trip.
- **One line in `docs/world/STYLE_AND_SETTING.md`** — that doc still says
  "everyone who isn't a manager is human." Body types either sit inside that
  as morphological variation or the sentence needs a light edit. Fix the
  vocabulary before it reaches twenty strings of news copy.
- **Surfacing in UI** — `body_type` appears nowhere in `scenes/`. It should
  read as flavour on the player dossier, never as a scouting category.

The three balance checks that were failing were **not** body-type defects.
All three were assertions running below the resolution their sample size could
support; see `docs/calibration/IDENTITY_AND_BLOCK_TEST_POWER_2026_08_03.md`.

## 2. Regional strength — the unimplemented half

From `docs/design/REGIONAL_STRENGTH_AND_MINOR_REGIONS.md`. The talent-tier
affinity, positional affinity, roster capacity and the six minor regions all
landed; these did not:

- **`sixnet_prestige`** — a region's standing, so the Sixnet has a pecking
  order rather than six equals.
- **`region_prime_history`** — regions that were strong in a past era and
  aren't now, giving the world a memory.
- **Specialty-budget conservation** — regional specialties currently *add*
  ability with nothing paying for it. Without a conserved budget every future
  specialty inflates the world.
- **Challenge relegation** — the promotion path between the minor tier and
  the Sixnet.

## 3. Minor regions as playable

Explicitly deferred by the user ("doesn't need to be within scope
currently"), and the stated blocker has since been removed:
`docs/calibration/MINOR_REGION_POPULATION_2026_08_03.md` shows every minor
region already fields a starting seven and a 14-player squad at the current
4,000, so **no population bump is needed**. What remains is career-setup and
UI work only — `Regions.playable_names()` returns `SIXNET_PARTICIPANTS` and
would need to widen, plus whatever competition structure a non-Sixnet career
plays in (which is the same question as challenge relegation, above).

## 4. Career dashboard — the part of the rework that regressed out

The nav dropdown, Home news panel, Team sub-tabs and the aggregated lineup
wheel are all in. Two Roster-tab items from the agreed plan are not in the
current scene:

- **Reserved space for the 3D player visualizer.** The `RosterExtra` column
  holding `Placeholder3D` is gone from `journal_screen.tscn`; the Roster
  profile is now `IdentityPanel` + `WheelPanel` only. The user asked for the
  space to exist before the feature does.
- **Biography block.** `home_region` / `club_region` / `traits` are surfaced
  in the Player Dossier popup rather than inline on the Roster tab. This may
  be an intentional Codex improvement rather than a regression — worth
  confirming before re-adding anything.

## 5. Flavor events

The Home news panel exists and is fed by a stand-in feed built from real
completed fixtures. The actual flavor-event system — the thing the panel was
built to hold — does not exist anywhere in `scripts/`. No data model, no
trigger, no copy.

## 6. Staff

`StaffPlaceholder` is a reserved panel on the Team overview. There is no
staff system: no hiring, no coaching effects, no staff model. Confirmed as
placeholder-only scope at the time; still open.

## 6a. Title screen, rendered in full — before the training work

Explicitly sequenced ahead of the clipboard and the day loop (§0.9 of
`docs/design/TACTICS_AND_TRAINING.md`). The title screen has a written spec
already -- the "ui write up" -- and it is the one screen every session begins
on, so it sets the reading for everything after it. The clipboard draft that
exists now (Tactics / Development tabs, fit strip) is deliberately parked at
draft fidelity until this lands.

Held rather than started, so the order is a decision rather than an accident.

---

## 7. Continuous movement for all twelve players

Intended model: all twelve players move continuously during every ball flight,
each on their own timeline. "Relative to the ball" does **not** mean everyone
chases it — each reacts to the ball's *perceived* trajectory through role,
tactical assignment, teammate ownership and current phase. Passers move to
reception responsibility; the setter releases or chases the projected second
contact; hitters stage approaches and adjust to set quality; blockers read and
close; floor defenders shift behind the block; non-contacting attackers move
into coverage or transition.

Position, velocity, intent and recovery persist across contacts. Nobody resets
to a rotation slot, snaps to event coordinates, or stands still waiting for
their own event. A defender may still be recovering while the setter moves and
the ball travels on.

The simulator stays authoritative. Playback samples simulator-produced ball and
player timelines and never invents movement. If a player cannot physically
reach a contact given acceleration, speed, reaction delay, fatigue, body
measurements and available time, **the simulator resolves a late, degraded or
missed action** — the renderer must not teleport them to make an
already-decided contact look right.

### The core finding: two representations, and the resolver uses the poor one

`RallyPlayerState` already carries everything the architecture below asks for —
`position`, `velocity`, `facing`, `movement_mode`, `body_state`, `balance`,
`readiness`, `intent`, `intent_target`, `committed_until`, `last_contact_time`,
`recovery_until`. It is consumed by `RallyState`, `RallyStateBuilder`,
`ApproachMechanicsSystem`, the three live integrators and the movement
calibrations.

`RallySimulator` does not use it. It carries `live_positions` and
`opponent_live_positions`, both **position-only `Vector2` dictionaries**, across
19 write sites. Every step discards velocity, facing, intent and recovery and
keeps only where the player ended up.

That is *why* movement is event-allotted rather than integrated: there is
nothing to integrate from. Motion cannot continue across a contact when the only
thing carried across is a point. Collapsing the resolver onto `RallyPlayerState`
is therefore step one, and it is already half-built.

### Architecture

1. Authoritative per-player movement state: position, velocity, facing, intent
   target, movement mode, last update time.
2. Update every player over the same monotonic rally clock the ball uses.
3. Re-evaluate intent at perception/read moments; movement continues between
   them. **This is Gate 50's model and needs no continuous re-perception** — a
   player runs toward the destination they last judged, which is what keeps the
   Gate 31/32 information boundary intact.
4. Emit time-bounded movement segments or sampled tracks for every player.
5. Both 2D and 3D playback sample the ball and all player tracks at the same
   timestamp.
6. Carry each segment's ending state into the next phase without resetting.
7. Deterministic seeded outcomes; identical playback for identical rally data.

### Acceptance

- No player snaps between event positions.
- No player exceeds physically plausible movement limits.
- All players remain active off the ball.
- Tactical shape changes continuously as the ball develops.
- Failed arrivals finish where the player actually reached.
- Contact events and rendered positions agree.
- Playback never computes a second version of rally truth.

### Current state, verified

| claim | status |
| --- | --- |
| Ball trajectories continuous contact to contact | yes, `outgoing_trajectory` |
| Next actor and some phase groups move during a flight | partial, 10 staging sites |
| Live positions persist between phases | yes, but position only |
| Partial arrival for some failed defensive actions | yes, 7 `_reached_point()` sites |
| Blockers staged during the preceding flight | partial |
| Movement continuously integrated | no — allotted |
| Per-player timelines for all twelve | no |

Design trail: `docs/design/MOVEMENT_FLUIDITY_DRAFT.md`,
`docs/calibration/PLAYBACK_MOVEMENT_AUDIT_2026_08_03.md`, and the "Spatial rally
clock" section of `ARCHITECTURE.md`.

Note the two docs use "step 4" for different things: the draft's "Step 4, done"
is the unification of `_movement_time()` onto
`RallyMovementSystem.traversal_seconds()` (done, and it cut the traversal
discrepancy range from 0.557–1.246 to 0.969–1.043). The draft's "Remaining"
section uses step 4 for resolver-*integrated* movement, which is open and is
what this section describes.

---

## 8. Ball geometry — outcome, position and drawing must become one computation

Design source: `docs/textbook/EVENT_CALCULATION_TAXONOMY.md`, which specified
the per-phase decomposition and the pass/set trajectory observables before any
of this was built. This section records the gap against it, not a new design.

### The rule the work follows

**Contacts that cross the net need geometry. Contacts that stay on your own
side need attributes.**

Serve, attack and block have terminal geometric verdicts decided against
boundaries and obstacles. Reception, set and dig hand off to a teammate — there
is no line to be on the wrong side of. Own-side contacts still have to emit a
*position*, because the next contact's geometry reads it, but they need no
flight simulation and no boundary test.

### Landed

Own-side deliveries now resolve to a position instead of a table entry:

- `_delivered_point()` — normal scatter in metres, converted per axis, spread
  from execution quality. Values from the taxonomy: sets `lerp(0.40, 0.08)`,
  passes `lerp(0.50, 0.10)`.
- Applied to the first-ball set, the transition set, and the opponent's
  reception. The home reception already did this in `_reception_pass_result`.
- `intended_target` on SET events, so aim and result are separately readable.
- Home reception's scatter converted from uniform to normal.

Measured over 854 rallies: mean set displacement 0.397 m, p90 0.672 m, max
1.525 m. Terminal shares moved, most visibly `attack_error` 15.5% → 11.1% and
`opponent_kill` 13.5% → 16.4%, because moving the set moves the hitter's
contact point and therefore approach timing. `tools/run_delivery_audit.gd`
reproduces both figures.

**Finding that came out of it: set quality is compressed at the bottom.** 524 of
559 sets scored below 0.50 and exactly one above 0.65. The quality-dependent
spread is therefore almost always running at its worst-case end, so the
mechanism discriminates between setters far less than it looks like it does.
That is a set-quality calibration problem, not a delivery one, and it points
the opposite way from the "both teams highly capable" baseline the design wants.

### The dig asymmetry is an attack-shape defect, not a defence defect

Three passes chased the 0.20 dig gap as a claim or positioning problem — the
parallel implementation, then the staging, then the timing term. It is neither.
`tools/run_dig_terms_split.gd` now stamps and reports the claim's own inputs on
both sides of the net (the opponent side never stamped its arrival at all, which
is why this could be seen and not attributed), and they say:

| claim input | home | opponent | gap |
| --- | ---: | ---: | ---: |
| attack flight seconds | 0.739 | 0.490 | **0.249** |
| available_time | 0.419 | 0.165 | 0.254 |
| reaction_delay | 0.325 | 0.333 | 0.008 |
| physical_reach_meters | 2.505 | 1.763 | 0.742 |
| distance_meters | 1.526 | 1.863 | 0.338 |

Reaction delay is equal and raw speed is identical by construction. The reach
gap is *entirely* the time gap: `physical_reach = base + speed × available_time`,
and one side has two and a half times the clock. Home defenders are digging lobs.

**Two causes, both upstream of the defence.**

1. **The two sides choose their shot by different rules.**
   `_choose_opponent_attack` downgrades to a roll shot or tip below a set quality
   of 0.38, and opponent first-ball sets have a *median of 0.344* — so it fires on
   more than half their attacks. The opponent essentially never spikes; it rolls
   the ball over at 20–32° instead of 5–14°. The home side has no such rule and
   swings at everything.

2. **One opponent swing is solved twice with two different launch angles.** The
   drawn arc uses the hitter's shot shape; the home defender's budget is re-solved
   through `_opponent_attack_type`, a *defensive* classifier whose "Short tip"
   branch covers everything landing inside y 0.80 — most of the court. Outcome and
   picture disagree, which is this section's own headline defect showing up in a
   place nobody had looked.

**Both fixes are written and both are withheld, for the same reason.** The fix
for (2) is behind `ENABLE_UNIFIED_DIG_FLIGHT`, off. The fix for (1) — one shared
`_compromised_shot_type` — was implemented and withdrawn; the finding sits above
`_hit_type`. Either one strengthens the home floor defence before the block has
been re-tuned for it, and the two block-intent gates (a sealing block stuffs
more, a funnelling one deflects more) separate by two or three counts on a sample
of about fifty. Against an opponent that swings they stop separating, identically
at every threshold tried between 0.18 and 0.30. That is a real re-tune, not a
fixture to re-baseline.

**The samples are widened, and the verdict is now measured.** The block-intent
gates ran 300 rallies of a single six and separated by two or three counts out of
fifty; they now run 1,200 across four rosters. Against that sample:

- **Flight fix alone:** passes both block gates, and moves the attack-symmetry
  ratchet 0.656 → 0.672. It unifies on the *lobbed* arc, so it makes the
  asymmetry worse rather than better — which is why the two fixes belong together.
- **Both together:** reverses the funnelling gate by five counts out of about two
  hundred. That is a genuine reversal, not re-sequencing noise.

So the remaining work is exactly one thing and it is now a known quantity: **the
block's outcome bands in `_contest_block` need re-separating against an opponent
that swings.** `AttackResolutionModel.STUFF_DEPTH_METERS` is the named lever for
converting stuffs into touches; the same reasoning applies to the seal/funnel
bands. Both fixes sit behind `ENABLE_UNIFIED_ATTACK_SHAPE`, off, and flip together.
Do not widen a bound to close either.

Worth carrying: a change to how many random numbers a rally consumes
re-sequences every seeded outcome after it. Drawing the improvisation roll
conditionally flipped both block gates on the re-sequencing alone. Draw
unconditionally, gate afterwards.

### The missing row filter is not reachable — and the home side had no pipe

`OpponentTeam.eligible_hitters()` filters by position code and never reads the
row, which is why "a back-row player can be picked as a front-row attacker" was on
the list. Audited with `tools/run_front_row_legality.gd`, 720 rallies:

| side | attacks | back row | illegal |
| --- | ---: | ---: | ---: |
| home | 416 | 0 | 0 |
| opponent | 312 | 201 | 0 |

**No violation occurs.** The filter is only half the rule and the other half
already carries it: `_opponent_attack_contact_point` reads the lineup and pulls
back-row hitters behind the attack line, so 0 of 201 back-row attacks were struck
illegally. Gated by `_test_no_attack_is_struck_illegally()` so it stays that way —
and the gate has to install generated attributes, because on the raw vertical
slice the opponent's hitters sit in front-row slots almost always and the sample
collapses to four attacks, which is a legality check that passes because nothing
was tested.

**The finding points the opposite way from the defect it was looking for.** The
opponent takes 64% of its attacks from the back row; the home side takes *none*.
The home playbook has no pipe at all, so the block can compress on it with nothing
to lose, and nothing was measuring that. This is a bigger offensive asymmetry than
the filter would have been a fix for, and it sits on the *home* side — the
opposite of every other asymmetry in this section.

**Closed.** `_fallback_hitter` iterated front-row slots only, so of the five lanes
in `CourtConstants.LANES` the home offence could reach four and the fifth was
unreachable by any code path. Everything downstream of the decision already
existed and had for some time — `LANE_X` carries the pipe, `_hit_type` names it
"Pipe attack", `ApproachMechanicsSystem` gives that a power-attack profile,
`ShadowAttackSystem._fallback_lane` returns it for any back-row slot, and
`PlayValidator` has required back-row hitters to use it since the plays were
written. What was missing was a caller. Back-row attackers are candidates now,
behind `ENABLE_HOME_PIPE_OFFENSE`, gated on the same pass quality the quick is
and excluding the libero, the setter and a resting middle.

Fixing it exposed a second thing the absence had hidden: `lane_target` aimed the
pipe at 0.66 against an attack line at 0.6667, a centimetre the wrong side of it,
and execution spread put 2 take-offs in 28 in front of the line. A pipe is set
about a metre behind the three-metre line rather than on it, which is where the
measured take-offs already clustered — median 0.721 against the 0.722 the
constant now names. Minimum take-off moved 0.652 → 0.740, illegal take-offs 2 →
0.

The home lane mix, measured over 74 swings: Left Pin 0.338, Right Pin 0.284,
Front Quick 0.270, Pipe 0.108. `_test_no_attack_is_struck_illegally()` asserted
`home_back_row == 0` to hold the gap in place; it now asserts the opposite, with
the legality half of the same test — which always covered both sides —
keeping it honest.

### Withdrawn: the approach mark is placed from the set already

Recorded here last pass as a defect on the strength of `to mark` measuring a constant
0.847 s at every tempo. It is not one. `approach_start_position()` reads the delivered set
point — its `_lane` argument is unused — and within a single tempo the mark's x spans
−0.032 to 0.361 across 312 attacks, about three and a half metres, tracking the set over
the same range while the walk varies 0.707–0.981 s. The mean is stable across tempos
because tempo changes the arc and not the aim point.

Gated by `_test_the_approach_mark_tracks_the_set()` so that if it ever *does* become a
constant, something notices.

Worth carrying: this and the double-charged approach budget were the same mistake —
reading a stable mean as a stable quantity — and it is the same shape as the thresholds
set outside their own distributions in the recovery work. When a summary statistic is
being used to support a structural claim, check the spread first.

### The set-quality gap starts one contact earlier, in the reception formula

The histogram below measures the opponent setting worse and erroring far more. That is
real, and it is downstream. The serve reception that feeds it was written out twice with
different weights:

| | reception | ball_control | composure | serving side's risk charged |
| --- | ---: | ---: | ---: | :---: |
| home receives (opponent serves) | 0.65 | 0.20 | 0.15 | no |
| opponent receives (home serves) | 0.58 | 0.24 | — | yes |

Three attributes summing to 1.0 against two summing to 0.82, with `composure` reaching
the home side's receivers and not the opponent's. Measured across 629 receptions on
identical rosters: **home reception quality 0.606, opponent 0.378.** That is the largest
single asymmetry measured in this engine, and it is upstream of everything in the table
below — a worse pass is a worse ball for the setter, which is exactly what
`capability_penalty` 0.297 against 0.132 is reporting.

`_reception_skill()` unifies the weighting and a symmetric risk-pressure term closes the
rest; measured, the gap narrows from 0.228 to 0.102 (0.589 against 0.487). The residue is
the two formulas' remaining differences (serve pressure 0.48 against 0.44, seam conflict
on one side only) and is deliberately left alone until this lands.

**It is behind `ENABLE_UNIFIED_RECEPTION_SKILL`, off, and it does not land alone.** On its
own it moves the attack-symmetry ratchet 0.656 → 0.686 and flips the defensive-identity
gate. That is the *same direction* `ENABLE_UNIFIED_ATTACK_SHAPE` pushes it, and the
convergence is evidence rather than coincidence: better opponent passing clears the 0.38
set-quality threshold in `_choose_opponent_attack` more often, so more opponent balls
become real swings instead of safe rolls — and the block those swings meet is the system
Gate D already measures at 41.5% terminal against a 12% target. Improving reception does
not create a defect; it exercises the block defect more often.

So the two flags land together, after the block's outcome bands are re-tuned for an
opponent that swings. Do not widen the ratchet to close either.

### Set quality collapses on two of the four paths

From `tools/run_set_quality_histogram.gd`, and relevant because everything above
is downstream of it:

| path | n | p25 | median | mean | kill | error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| home first ball | 312 | 0.323 | 0.634 | 0.524 | 0.571 | 0.154 |
| home transition | 115 | 0.100 | 0.100 | 0.185 | 0.557 | 0.122 |
| opponent first ball | 277 | 0.080 | 0.344 | 0.389 | 0.350 | **0.477** |
| opponent transition | 41 | 0.080 | 0.152 | 0.290 | 0.488 | 0.366 |

Two saturated floors: 70% of home transition sets land on exactly 0.100 and over
a quarter of opponent sets on exactly 0.080. The floors are not creating the low
values, they are piling them up — the underlying execution genuinely produces
less. The transition path loses about 70% of its capability to three penalties at
once (capability_penalty 0.203, geometry_difficulty 0.160, arrival −0.073).

And the opponent errors on **47.7%** of its first-ball attacks against the home
side's 15.4%. On identical rosters. That is the largest single asymmetry in the
engine and it is not in the dig.

### Not landed — the distance still to go

**Serve in/out: the visible half is landed; the emergent half is not.**

The first of the two fixes below shipped. `_errant_serve_landing()` mirrors
`_errant_attack_target()` on both serve paths — keep the roll, relocate the ball,
into the tape on a poor contact and past whichever line the intended target sat
nearest otherwise. `_test_a_serve_that_misses_is_drawn_missing()` gates it on both
sides of the net and requires the misses not to be all one kind. The visible
defect in save `as`, seed 3801887943 is gone.

What remains is the second, larger fix:

- Derive in/out from the landing point. `_serve_landing_point` is already 90%
  of the way there — `deviation := lerpf(0.105, 0.018, accuracy)` is the right
  shape, and the final `clampf` back into the court is the single line that
  makes an errant serve impossible. Removing it converts the error *rate* from
  a calibrated constant into an emergent one, which re-rates every server in
  the world. The uniform must become normal first, or "can this serve go out"
  becomes a step function of placement rating rather than a tail.

**Attack: the causal direction is inverted.** Today `target → distance → angle`;
the proposal is `angle + velocity → trajectory → landing`. Specifically:

- The target scan (`_choose_attack_target`, 13×9 grid) scores candidates on
  distance to the nearest *floor defender* and **never reads the block**. The
  hitter picks where defenders aren't while ignoring the wall in front of them.
- `decision_making` is a coin flip between the correct answer and the hitter's
  own line, so a poor reader gets perfect information or a fixed fallback,
  never a plausibly wrong read.
- Accuracy perturbs the landing point in court space, not the launch angle.
  Launch angle comes from a per-`attack_type` table.
- `_contest_block()` is a scalar margin comparison run *after* the arc exists.
  No geometric intersection anywhere.
- In/out is `_attack_missed()`, a logistic roll, with the ball relocated
  afterwards to agree with it.
- The block is priced twice: `block_pressure` inside `_attack_execution`, and
  again as a margin in `_contest_block`. Only one should survive.
- Block deflection is a re-slice of the arc to the net, so a deflection carries
  no directional information.
- **The transition path aims by coin flip**: `Vector2(1.0 - set_target.x,
  rng.randf_range(0.12, 0.38))`, with no defender scan, no repertoire gate and
  no accuracy spread. It never calls `_choose_attack_target`.

**Three attack implementations** (home, opponent, transition) plus two serve
paths all need the same inversion, or they diverge. That is the cost driver,
not the geometry itself.

**Overpass is now detectable but not playable.** Emitting a real delivery
position means a set or pass crossing `NET_Y` is a comparison away. There is no
rally branch that plays one out, so deliveries are currently clamped to their
own side (`HOME_SET_DELIVERY_MIN_Y`, `OPPONENT_PASS_DELIVERY_MIN_Y`).

### Gates

The cheap serve patch was dropped deliberately: the re-architecture fixes the
same defect, and patching then replacing is wasted work.

- **Gate A — ballistics. Landed.** `scripts/simulation/ball_flight_model.gd`.
  Launch from a contact height with signed angles, the inverse solve, a
  height-at-distance probe for block intersection, and a minimum-speed query.
  Pure functions, no rally state, nothing wired — behaviour is unchanged.
- **Gate B — the hitter's decision. Landed, closed.**
  `attack_course_model.gd`, `attack_power_model.gd`, `attack_read_model.gd`,
  `attack_swing_model.gd`. Courses as bearings, power as a temperament-driven
  choice, a blurred read of the block and floor, and three independent
  execution channels.
- **Gate C — resolution. Landed.** `attack_resolution_model.gd`. Tape, antennae,
  block and floor, read off one flight in the order the ball meets them. No
  branch consults a random number.
- **Gate D — calibration. First pass done, blocked.**
  `attack_geometry_calibration.gd` sweeps the Gate B→C chain over a generated
  population. Targets set (below). Convergence is blocked on the reach model,
  not on the geometry.
- **Gate E — promotion. Seam built, wiring open.**
  `geometric_attack_resolver.gd` composes all five models into the single call
  the resolver will make, and `ENABLE_GEOMETRIC_ATTACK` /
  `ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK` exist and are off. What remains is
  substituting it into the three attack paths and both serve paths.

  The seam exists specifically so that substitution is *one* call per site
  rather than five. Wiring three attack paths to five models individually is
  how three copies of `_attack_execution` happened in the first place.

  Note this rollout is unlike the others. Gates 48/49 promote one *contact*;
  this replaces how an attack is decided and resolved end to end. The flag
  therefore stays off until every path is migrated -- a rally running the
  geometric attack into the legacy block contest would be measuring neither.

### Gate A notes

Two things worth carrying forward.

**A near-vertical root must be declined, not clamped.** The lofted solution for
a fast ball at short range is a near-vertical lob — 22 m/s over 4 m solves to
87.7° — and pinning that to an 85° bound returns an angle carrying 8.8 m
instead of the 4 m requested. `solve_angle_for_range` therefore flags each root
usable or not rather than clamping, because a solver that quietly answers a
different question than the one asked is the same defect as a serve that is
ruled out and drawn in. A round-trip test over the speed × range grid pins it.

**`RallyKinematics.solve_launch_arc` is not being deleted yet.** Every live call
site still uses it, and it remains the right model for own-side deliveries,
which launch and land at roughly the same height and are never struck downward.
Gate E decides which sites move.

### Gate B notes

A course is a **bearing**, measured on the floor from the net normal, positive
toward increasing x. Zones are not portable between hitters — a left-pin
hitter's cross-court and a right-pin hitter's cross-court are opposite
directions — so the bearing is the choice and the *label* is derived from where
the ball lands relative to the hitter, which `_attack_direction()` already does
correctly.

Measured legal cones, contact at y = 0.52 (`tools/run_course_probe.gd`):

| lane | legal cone | width | deepest shot |
| --- | --- | ---: | --- |
| Left Pin | −64.75° … +87.25° | 152.0° | 11.79 m at +40.25° |
| Front Quick | −83.65° … +85.90° | 169.6° | 10.39 m at +29.95° |
| Pipe | −85.00° … +85.00° | 170.0° | 9.98 m at −25.65° |
| Right Quick | −85.90° … +83.65° | 169.6° | 10.39 m at −29.95° |
| Right Pin | −87.25° … +64.75° | 152.0° | 11.79 m at −40.25° |

Two consequences for the gates after this one.

**The pins' cones are lopsided and mirrored.** A left-pin hitter can turn 87°
across the court and only 65° back toward their own sideline. `swing_range`
today is a symmetric window in *x* and offers that hitter the same reach toward
a sideline 0.065 away as toward one 0.825 away.

**The deepest legal shot from a pin is 11.79 m, not 9 m** — the sharp cross
diagonal is longer than the court is deep. So required power is a function of
the chosen course, and the sharp cross costs more of it than the line does.
That is a genuine tactical consequence falling straight out of the geometry,
and it is the first thing Gate C's power selection has to respect.

**Bearings are metric, not normalized.** The court is 9 m by 18 m, so equal
normalized offsets in x and y are a 26.6° shot, not 45°. Computing bearings in
normalized space would tilt every course in the game.

### Gate D targets

Chosen from the gameplay fantasy rather than from realism alone: high baseline
competence, points decided by named exceptional actions, rally length as a
*distribution* with a fat short mode and a real tail, and capability sitting on
the **continuation** side rather than the terminating side.

**Terminal outcome mix, share of all rallies:**

| outcome | target | now (870 rallies) |
| --- | ---: | ---: |
| kill (both sides) | **55%** | 24.6% |
| attack error (both sides) | **16%** | 12.3% |
| terminal block (stuff + counter) | **12%** | 41.5% |
| service error | **11%** | 17.6% |
| ace | **6%** | 4.0% |

**The headline gap is not the stuff rate — it is that blocks and kills are the
wrong way round.** The engine ends 41.5% of rallies on a block and 24.6% on a
kill; real volleyball is roughly the reverse, and so is the fantasy. Everything
else is a rounding error next to that.

12% terminal block is "deliberately blocky" — above the 8–10% an elite real
team manages — while staying rare enough that a roof remains a nameable moment
rather than the texture.

**Block involvement 35–45%** of attacks touched, against 12% terminated. That
is the split that gives a blocky *feel* without making the block the routine
way rallies end.

**Rally length**, as a distribution rather than a mean: ~55% decided within one
attack per side, ~33% two to three, ~12% extended. Named actions cluster in the
tail, which is what makes the long rallies the memorable ones.

**Named actions:** 40–60% of rallies contain at least one; ~1 per rally mean;
and a high share of *points* whose decisive event carries a name. Rare per
contact, dominant per point.

### Gate D first pass: the geometry is not the problem

`AttackGeometryCalibration.run()` sweeps courses → read → power → swing →
resolve over a generated population. Three defects surfaced, in order.

**1. Near-parallel courses were selectable.** The legal cone reaches past 85°,
and a course scorer picks those *because* no blocker stands 80° away — then the
ball needs twenty metres of travel to cross the net. Fixed with
`MAX_COURSE_BEARING_DEGREES = 70`: nobody hits a volleyball sideways down the
tape.

**2. Power was anchored on distance, which re-coupled the two axes the whole
model exists to separate.** `choose_power` derived its speed from the least
force that reached the target, so a hitter aiming four metres in swung at a
third of their power — and a cut shot could not be hit hard *and* soft, the
exact example the design is built around. Power is now anchored on **intent**
(`DRIVE_INTENT` 0.90, `CONTROL_INTENT` 0.66, `OFF_SPEED_INTENT` 0.36) and the
launch angle is solved to put that ball where it was aimed. Reachability became
a consequence rather than the anchor.

**3. The blocker out-reaches the hitter, and that decides everything.** The
block test is `ball_height_at_net vs blocker_reach`, so what matters is the
difference between where a hitter contacts and how high a blocker gets. Swept
at two contact heights:

| contact | in | net | stuff | touch | tool |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2.68 m (model reach) | 11.1% | 25.2% | 36.5% | 16.8% | 10.4% |
| 3.15 m (realistic) | 90.3% | 0.0% | 0.2% | 8.0% | 1.5% |

A 47 cm change in contact height moves the stuff rate from 36.5% to 0.2%. **The
block contest is a step function on contact height**, with almost no gradient
in between — which is why no threshold tuning inside Gate C can reach the
target.

### Resolved: leap, not standing reach

Contact height was raised by widening the **leap** band (`JUMP_LEAP_MIN_CM` /
`JUMP_LEAP_MAX_CM`, 12-78 cm -> 20-110 cm) rather than by correcting
`standing_reach_cm()`. That is the better fix for three reasons.

**The contest is proportional to leap.** A blocker jumps at a fraction of a
hitter's effort, so the gap that decides everything is
`leap * (1 - blocker_effort)`. Widening the leap widens the attacking advantage
directly, without touching a single reach formula.

**It moves the contest off the body and onto training.** Standing reach is
height, which a player is born with. Leap is `jump_reach` and `explosiveness`,
which they develop. The gap now runs +4.9 cm for a poor jumper, +17.3 cm for an
average one and +29.5 cm for an elite one -- a threshold a player can be
coached across.

**It puts contact where the sport puts it.** 22-87 cm above the tape across the
range, against 10-57 cm before; real contact is 60-90 cm above a 2.43 m net.

Measured effect on the geometry sweep:

| | before | after |
| --- | ---: | ---: |
| mean contact height | 2.80 m | 3.01 m |
| lands in | 32.1% | **45.5%** |
| netted | 7.0% | **0.4%** |
| stuffed | 23.8% | 22.0% |
| touched | 27.5% | 23.3% |
| tooled | 9.6% | 8.8% |

Effect on the **live** simulator was far smaller -- blocked 36.0% -> 33.9%,
kills 24.6% -> 26.8% -- and that gap is itself the finding. The geometry sweep
moved thirteen points on "in" while the live path moved two, because the legacy
block is a scalar margin comparison that barely reads reach at all. A change to
how high people jump should move a block contest a lot; that it does not is
another argument for promoting the geometric one.

`standing_reach_cm()` is still ~15 cm low across the range (see below) and is
still worth correcting, but it is no longer blocking Gate D.

### Signature moves, and Gate D converged

`signature_move_model.gd`. Two ways a spike beats a block it has physically
met, keyed to different attributes so a power build and a placement build each
have an answer:

- **Block Crush** -- struck harder than the hands can absorb; rips through and
  keeps going down. Power, ego, leadership.
- **High Hands** -- placed deliberately on the outside edge; leaves high and
  away from court. Accuracy, composure, decision making.

Tips, rolls and cut shots have no move here, and lose nothing by it: they beat
a block by not touching it.

**Charge is not a consumable.** `charge()` asks whether a player currently has
the game in them, from ability, belief and which way the match is running.
Attempting costs nothing, succeeding costs nothing, **only failing is
expensive** -- and it is expensive because it damages the belief the charge was
reading. That asymmetry is what makes it self-regulating: a hitter who goes for
it and misses drops below the line and has to earn back, one who keeps landing
them stays hot, and streaks fall out without anyone scripting streaks.

Belief is the existing `VolleyballPlayer.match_confidence`, already moved by
`flow_shift` and already decayed between sets. New consumer and new writer, no
new state. **Watch the loop gain**: quality → flow → confidence → execution →
quality was already closed with small gain (0.02-0.06); moves now read *and*
write confidence, so that gain has risen and wants measuring rather than
assuming.

Note the two move families have different owners. Attacker moves gate on the
attacker's own confidence and ego; receiver moves will gate on the team's
`floor_defense_adaptation_strength`. Failure should cost whichever thing gated
that move, not a shared pool.

**Distinguishing a placed ball from a lucky one** uses the swing's own
`bearing_error_degrees`: edge contact from a swing that went where it was aimed
is High Hands, the same contact off a wild swing is an ordinary tool. The
hitter did not put it there.

#### Gate D result

| | target | measured |
| --- | ---: | ---: |
| terminal stuff | 12% | **12.5%** |
| block involvement | 35-45% | 49.5% |
| lands in | -- | 50.2% |
| netted | -- | 0.3% |
| move attempts | 10-15% of swings | 3.8% |
| move conversion | ~50% | 37% |

Converged on the stuff rate, which was the headline gap. Involvement sits about
five points high, and moves fire somewhat rarer than the 10-15% suggested --
both acceptable for a first pass and both cheap to move later
(`BLOCKER_HALF_WIDTH_METERS` for the first, `AVAILABILITY_THRESHOLD` for the
second).

Constants that moved, and why:

- `STUFF_DEPTH_METERS` 0.15 -> 0.21. The line between the block being
  *involved* and the block *ending* the rally.
- `TOOL_EDGE_MARGIN_METERS` 0.12 -> 0.08. It is a share of the sealed lane, so
  when the lane narrowed a fixed 0.12 turned a third of every block into an
  edge contact and tools stopped being rare.
- `BLOCKER_HALF_WIDTH_METERS` 0.45 -> 0.34. The lateral window is the term that
  decides involvement.

### Remaining levers

Geometry sweep now sits at 22.0% stuffed against a 12% target, with block
involvement (stuff + touch + tool) at 54.1% against a 35-45% target.

The design intent is **antagonistic, then decisively overcome**: being blocked
or touched should be common, there should be a hard ceiling, and clearing it
should let hitting dominate. The current shape is already antagonistic; what is
wrong is that too much of the involvement *terminates*. The direct lever is
`AttackResolutionModel.STUFF_DEPTH_METERS`, which decides how far below a
blocker's reach a ball has to arrive to be pressed down rather than deflected
up -- raising it converts stuffs into touches without reducing how often the
block is involved at all.

Secondary levers: `BLOCKER_REACH_EFFORT`, blocker `half_width_m`, and how
accurately the block positions itself laterally.

Worth noting the counter-pressure already exists.
`_opponent_block_adaptation_bonus()` rewards the block when the opponent has
anticipated **both** the lane and the tempo, routed through
`OpponentTeam.block_bonus()` and `block_adaptation_strength`. So a hitter who
overcomes the block by jumping over it is answered by a block that learns their
pattern -- which is the loop that keeps the ceiling from being a solved problem.

### The remaining reach question

`VolleyballPlayer.standing_reach_cm()` is
`height_cm * 1.215 + (wingspan_cm - height_cm) * 0.32`, and it is about **15 cm
low across the whole height range**:

| height / span | model | realistic (~1.30 × height) | short by |
| --- | ---: | ---: | ---: |
| 185 / 190 | 226 cm | 240 cm | 14 cm |
| 193 / 198 | 236 cm | 251 cm | 15 cm |
| 203 / 211 | 249 cm | 264 cm | 15 cm |

The net is 243 cm. So the model puts a 193 cm player's standing reach **below
the tape**, where a real one stands comfortably above it. Every reach in the
game is compressed against a net that is proportionally too high, and the
attack-versus-block contest — which is entirely a reach difference — is the
system that suffers most.

Changing it touches blocking, contact envelopes, reachability and every
existing calibration, so it is **not** being changed as part of Gate D. It is
the next decision to make, and Gate D cannot converge before it.

Interim harness constants, chosen to restore a gradient rather than to hide the
problem: `CONTACT_BELOW_REACH_METERS` 0.22 → 0.10 and `BLOCKER_REACH_EFFORT`
0.72 → 0.62, which moves the hitter from 6 cm *below* the blocker's reach to
12 cm above and takes the stuff rate 36.5% → 23.8%.

### Gate C notes

`attack_resolution_model.gd` reads one flight in the order the ball meets
things: **tape → antennae → block → floor.** No branch consults a random
number, which is what allows an attack error to be *shown* — the ball is long
because it was struck too flat and too hard, and playback draws exactly that.

**`CourtConstants.NET_HEIGHT_METERS` did not exist.** Nothing had ever tested
whether a ball clears the tape, and nothing could have: with the landing point
chosen first and the arc back-solved to reach it, no ball could fail. The net
test only becomes possible once the ball flies. A netted ball now also drops on
the side it was struck from rather than wherever the unimpeded arc pointed.

**The block is resolved by where the ball met the hands**, not by a margin
comparison:

| condition | outcome |
| --- | --- |
| ball above `reach_height_m` | not touched — beaten over the top |
| lateral offset beyond `half_width_m` | not touched — passed wide of the hands |
| within `TOOL_EDGE_MARGIN` of the edge | **tool** — the hitter's point |
| more than `STUFF_DEPTH` below the reach | **stuff** — pressed down on |
| otherwise | **touch** — fingertips, deflected up and playable |

`STUFF_DEPTH_METERS` moved 0.25 → 0.15 when a test caught it: a ball meeting
the hands 0.23 m below a blocker's reach is mid-palm, and 0.25 m was implicitly
calling that a fingertip graze. Both thresholds are provisional and are what
Gate D tunes against the stuff-rate target.

This is also where "tool off the block" and "got tooled" stop being
undetectable — the vocabulary entries that need to know the ball actually
touched a hand.

### Perception is blurred, not coin-flipped

`attack_read_model.gd`. `_choose_attack_target()` hands the hitter the scan's
best answer or a fixed fallback down their own line, chosen by
`randf() < decision_making`. That is two behaviours with no middle: perfect play
or a stock mistake, never a plausible misread. Perception now degrades the
*inputs* — blockers and defenders are seen up to 0.55 m and 1.30 m from where
they are, scaled by how well the hitter reads — so a hitter commits confidently
to a picture that is slightly wrong.

How much lane a pair of hands seals is deliberately **not** blurred. That is a
fact about the block's shape rather than something read off it in the air, and
blurring it would double-count the position error.

The block also enters the decision at all, which it previously did not: openness
is the *lesser* of the gap past the block at the net and the gap from the
defence at the floor, because threading the block into a waiting libero is not
half a good shot.

**Finding, and Gate C depends on it: shot selection barely moves where the ball
passes the net.** From a contact 0.36 m off the net, the entire legal bearing
range crosses within about 0.7 m of the hitter's own x — a line shot crosses
0.04 m across, a sharp cross 0.37 m, an extreme cross 0.68 m. So a blocker is
beaten by *height*, by their own positioning, and by the edge of their hands —
not by aiming at a different point on the floor. A test pins the span, because
the result is unintuitive enough to be "fixed" by mistake later.

### Three execution channels

`attack_swing_model.gd`. Intent goes in as a course, a launch angle and a speed,
and comes out moved on three independent channels, each failing in a separately
nameable way:

| channel | asymmetry | reads as |
| --- | --- | --- |
| power | shortfall ≈ 3× overshoot | dropped short |
| vertical angle | symmetric | sailed long, or into the net |
| bearing | symmetric, widest | pulled wide, or into a blocker |

Bearing runs wider than vertical because the swing plane constrains how far a
hitter can miss upward but not how far they can miss sideways. Power is
asymmetric because mishitting a ball and having it dribble is common, and
catching one better than intended is not. All three widen with
`swing_cost()`'s spread multiplier, so a ball struck across the body is less
accurate in every respect rather than only slower.

`dominant_channel` reports which one moved the ball furthest from intent,
normalised by each channel's own spread. That is what turns today's single
`attack_error` into a hitter who pulled it wide, one who sailed it long, and one
who never got hold of it.

### The natural swing line is the run-up — fixed, and it was worse than shallow

**Resolved.** The run-up was not merely too square; there were **two derivations
of it that disagreed in sign**, and the live one had pins running inside-out.

`ApproachMechanicsSystem.approach_start_position()` sent `Left Pin` to
`target.x + 0.07` — *inward* of the contact — while `rally_simulator`'s private
copy sent them outward. `prepare_for_attack()` calls the former, so inside-out
is what the engine actually did: a natural bearing near −17.6°, pointing at the
hitter's own sideline. The first fix attempt edited the simulator's copy and
changed nothing at all, which is how the duplication surfaced — 854 rallies came
back byte-identical.

They are one function now, in `ApproachMechanicsSystem`, and the lateral offset
is derived from an explicit **angle** rather than a fixed distance, so changing
the run-up's depth can no longer silently change its direction. Pins run in at
30°, middles at 8–14°, scaled by how wide the contact is. Approach starts may
now sit outside the sideline, which is where an outside hitter's actually
begins; holding them on court capped the angle at exactly the pins that need it.

Measured after (`tools/run_course_probe.gd`, now calling the live derivation
rather than a copy):

| lane | natural | line | off | cross | off |
| --- | ---: | ---: | ---: | ---: | ---: |
| Left Pin | +30.00° | −2.20° | 32.2° | +41.08° | **11.1°** |
| Front Quick | +13.79° | −21.67° | 35.5° | +27.15° | **13.4°** |
| Right Pin | −30.00° | +2.20° | 32.2° | −41.08° | **11.1°** |

Cross is now the cheap swing and line the hard turn back across the body, which
is the sport. Before, the offsets were 12.5° and 30.8° — exactly inverted.

Outcome cost of the change, 870 rallies: kills 11.8% → 10.3%, attack errors
11.1% → 12.3%, blocked 34.4% → 36.0%. Attacking got harder, which is correct —
`evaluate_takeoff()` reads this direction, so a diagonal run-up blends transition
speed toward lateral speed and charges lateral control, and pins had been
getting a free square approach. It also pushes the block rate further from its
target, which was already the largest open calibration item.

### Power is a choice, and there is no attribute for the trait that drives it

`attack_power_model.gd`. The hitter asks how hard they can reasonably hit here
and answers with their temperament. Three drivers, each producing a *different*
mistake, where one quality roll produced all of them indistinguishably:

- **decision making** judges how much power the intent needs — a good reader
  hits with just enough to push the ball to the endline;
- **aggression** biases the choice upward, centred on 0.5 so the trait cuts
  both ways — a timid hitter genuinely leaves something on the ball rather than
  merely failing to over-swing;
- **composure**, against the block in front of them, biases it downward — and
  only a formed block intimidates, and only a hitter short of composure.

Power required is priced at a driven reference angle (−15°), so reaching the
endline costs more than dropping it short, and a hitter whose ceiling cannot
carry that far is told `reachable = false` rather than quietly reaching. The
ceiling itself is spent by approach quality and by `swing_cost()`'s power
fraction, so the same player hits softer off a bad run-up or across their body.

**`bias` is reported on every swing** — `over-swung`, `held back`, `measured`,
`short of the range`. That is the action vocabulary's attacking entries arriving
for free: over-hitting and under-hitting become separately nameable.

**`ego` added, and deliberately kept off the ability wheel.**
`VolleyballPlayer.ego`, 1–100, outside `ABILITY_ATTRIBUTES`.

The wheel was the obvious home and is the wrong one. Its axes feed
`AttributeProfiles.category_score()`, which is `0.70·mean + 0.20·max +
0.10·min` over them — so any axis added to Mental & Tactical raises that
category, and Overall with it. Ego is not a capability: a hitter with ego 90 is
not mentally stronger than one with 50, they attempt different shots and fail
differently. On the wheel it would read as a strength and inflate a rating.

`body_type` is the existing precedent, held out of `ABILITY_ATTRIBUTES` with a
comment saying exactly this. Ego follows it, and is displayed in the biography
alongside `Adaptability` and `Hand` — the things that are *true* of a player
rather than *good* about them.

Consequences of being outside `ABILITY_ATTRIBUTES`: no ceiling, no training, no
category, and no contribution to current ability or potential. That is intended.

Generated with regional and positional leans — Ispayk 64.9 down to Taktikã
36.8, Opposite 59.6 down to Libero 42.8, on a deliberately wide σ = 16 because
the extremes are the interesting players rather than the broken ones.

**Drawn from its own RNG stream**, which matters more than it looks. Taking a
number from the shared generation rng advances it for every attribute drawn
afterwards, so the first version silently rerolled the entire world and failed
two balance fixtures on a change that touches no simulation code. A test now
asserts `assign_ego` consumes nothing from the shared stream.

`AttackPowerModel.aggression_from(ego, team_decisiveness, tactical_discipline)`
folds the instruction in: a disciplined hitter converges on what the bench
asked for, an undisciplined one plays their own game — which is what makes a
low-discipline star both a weapon and a liability rather than simply worse.

### Superseded: the original finding

Courses are centred on the line the hitter ran in on rather than on the net
normal, read straight off `_approach_start_position()`, which already offsets a
pin's start toward their own sideline. `swing_cost()` then charges power and
aim for turning off that line, so the same shot is cheap for a hitter who ran
at it and dear for one turning back across themselves.

The mechanism works and the signs are right — pins lean across the court,
mirrored, and middles run straight. **The magnitudes are wrong, and the result
currently inverts the sport.** Measured with `tools/run_course_probe.gd`:

| lane | natural | line | off | cross | off |
| --- | ---: | ---: | ---: | ---: | ---: |
| Left Pin | +10.31° | −2.20° | 12.5° | +41.08° | 30.8° |
| Front Quick | 0.00° | −21.67° | 21.7° | +27.15° | 27.1° |
| Right Pin | −10.31° | +2.20° | 12.5° | −41.08° | 30.8° |

An outside hitter running in diagonally should find **cross** natural and
**line** the hard turn back across the body. Here line is 12.5° off the approach
and cross is 30.8°, so the cheap shot and the dear one are swapped.

The cause is not in this module. `_approach_start_position()` offsets a pin by
0.055 in x against 0.135 in y — 0.5 m of lateral run over 2.4 m of forward run,
about 10°. A real outside approach covers something closer to 1.5–2 m laterally
over 3 m forward, nearer 30°. The run-up is roughly a third as angled as the
sport's.

Fixing it means changing approach *mechanics*, which moves run-up distance,
travel time and `approach_execution_fit` — a calibration-bearing change that
belongs in its own step rather than smuggled into this gate. Until then the
approach lean is present but too weak to express the asymmetry it exists for.
Deliberately not papered over with a fudge factor on the bearing.

### Resolved: velocity is real, and it is `attack_power`

Decided 2026-08-03. Power is carried in both calculation and playback. It is a
*choice made independently of the course* — an attacker may hit a cut shot hard
or soft, and those are the same course at two velocities. Execution then decides
how faithfully the intent is realised, for the power and the angle alike; a poor
swing drops power, but choosing a shot does not.

**This conflicts with how attack shape is currently expressed.**
`_attack_launch_angle_degrees` maps `attack_type` to an angle band — "Power
swing" 6–10°, "Roll shot" 20–30°, "Tip" 22–32°. Those names bundle power and
angle into one axis. Under the decision above they are points in a 2D
(course × power) space, and "a cut shot with high power" is a thing the current
table cannot express, because power is not a variable anywhere.

**`solve_launch_arc` must be replaced, not inverted.** It is the level-ground
projectile solution — `duration = sqrt(2d·tan θ / g)`, `speed = sqrt(d·g /
sin 2θ)` — which assumes launch and landing at the same height, and
`MIN_LAUNCH_ANGLE_DEGREES = 2.0` clamps every launch upward. A spike contacts
near 3.2 m and launches *downward*; a negative angle puts a negative under that
square root. The engine currently models every spike as a ball lobbed upward
from the floor to the floor, and gets away with it only because the target is
chosen first and the arc back-solved to reach it.

The launch-from-height form handles it, negative angles included:

```
t_land = (v·sin θ + sqrt(v²·sin²θ + 2·g·h)) / g
range  = v·cos θ · t_land
```

There is always a solution for h > 0 — the ball always comes down — so
insufficient power lands short rather than failing to solve. Worked at
h = 3.2 m, against a 9 m far court:

| v (m/s) | θ | range | flight | reads as |
| ---: | ---: | ---: | ---: | --- |
| 25 | 0° | 20.20 m | 0.81 s | eleven metres past the endline |
| 25 | −12° | 10.67 m | 0.44 s | long, just out |
| 25 | −20° | 7.44 m | 0.32 s | a spike |
| 30 | −25° | 6.30 m | 0.23 s | a heavy spike, deep-ish |
| 18 | −8° | 10.55 m | 0.59 s | slower, still sails |
| 12 | +25° | 16.06 m | 1.48 s | a lob well past the court |
| 8 | +35° | 9.19 m | 1.40 s | a roll shot to the endline |

Two things to take from it. **Downward launch angles are the normal case for
attacks, not an edge case** — and they do most of the work an aerodynamic drag
term would otherwise have to, which is what makes a drag-free model viable at
all. Float and topspin serves stay a known simplification.

And the usable region is narrower than intuition suggests: a 12 m/s roll shot at
25° already carries sixteen metres. Off-speed shots have to be genuinely soft or
genuinely steep, so the power axis needs real range at the bottom, not just at
the top.

**Contact height becomes a required input.** It is already computed —
`contact_envelope_system.gd` and the `contact_height_meters` metadata — so this
is plumbing rather than new modelling.

**Three error channels replace one roll.** "Execution determines the resulting
action" separates cleanly into:

- delivered power, multiplicative and biased downward (you rarely hit it harder
  than intended) — mishit, drops short
- vertical angle — sails long, or into the net
- horizontal angle — pulled wide, or off the intended course

Each is a *different, nameable* failure, where `_attack_missed()` today is one
logistic roll that produces all of them indistinguishably. This is where the
action vocabulary gets its attacking entries for free.

**Attributes get distinct physical jobs:** `attack_power` sets the peak velocity
ceiling in m/s, `attack_accuracy` sets angular spread, and a consistency
attribute sets power-delivery variance. Today `attack_power` is a weight in a
quality composite.

**Playback payoff:** ball speed becomes visibly different between a driven ball
and a roll shot. Duration is currently back-solved from distance, so speed is
implied and barely varies.


## Playback legibility: quality belongs in the picture, not in the text

Eighteen announcer strings in `rally_simulator.gd` hand the player a raw
percentage: `"%d%% pressure toward the receiver"`, `"%d%% reception quality"`,
`"T%d set for %s · %d%% accuracy"`, `"%d%% close speed"`, `"%d%% recycle
control"`. These are model internals wearing a sentence, and they are the wrong
answer to a real question.

The question is genuine and gets harder as the simulation gets more granular:
with block jump timing, contact depth, arm state and set tightness all now
deciding outcomes, a viewer cannot tell *how the rally is going* from the player
models alone. A good pass and a shanked one look nearly identical in flight.

The fix is a visual channel rather than a numeric one, on the ball and its trail
rather than on the body:

- **pass / reception quality** — trail colour and solidity. A clean pass keeps a
  solid trail; a poor one degrades toward a muted, broken trail.
- **set quality** — an overlay on the ball as it leaves the setter, warning
  toward red as delivery error grows. This is the one that needs it most,
  because set quality drives tempo, approach and everything after it.
- **contact severity** — a distinct marker for the outcomes that already have
  names in the resolver but no picture: a lift, a tool, a block that got hands
  on it but did not stop it.

Every quantity needed is already stamped on the events -- `quality` on each
`RallyEvent`, plus `attack_effectiveness`, `contact_recovery`, `block_miss_reason`
and the trajectory dictionaries. Nothing new needs measuring; this is a
presentation layer over data the resolver already produces.

Two constraints worth stating now, before it is built. The percentages should
come *out* of the announcer text when the visual channel goes in, not sit
alongside it -- otherwise the number remains the thing people read. And the
channel has to survive a colourblind viewer, so solidity, breakage and shape
have to carry the signal alongside hue rather than hue carrying it alone.


## Captions name the outcome and never the cause

The other half of the entry above, and not a duplicate of it. That one asks
*how is the rally going* and answers it with a picture. This one asks **why did
this voli succeed or fail**, and a coloured trail cannot answer it.

Sampled verbatim from playback:

```
[Defense] Nemi defends
    63% defensive contact against a 23% attack. Perimeter defense met the seam
    attack responsibility behind the read block. Arrived with 1.85 m to spare;
    1 nearby teammate supported the zone.
[Block] Boro · Stuff
    Primary close 100%; block quality 59%. Sena assisted at 100% close.
```

Outcome, geometry and system are all there. **No attribute is named anywhere.**
The reader cannot tell whether Nemi dug that because she reads early, because
the plan put her in the right place, or because the swing was weak -- and those
three have completely different consequences for who to sign, who to drill and
what to declare.

This is the player-facing instance of the defect FAILURE_MODES §15 arrived at
from the engine side: *when a model publishes a single verdict assembled from
several independent judgements, publish the judgements too.* There it sent
investigations to the wrong file. Here it stops the player learning the system
at all.

**The rule the copy should follow: name the term that decided it, not the
total.** One or two contributors, chosen by which term moved the result furthest
from its baseline -- derived, not authored, so it cannot drift from the model
the way a hand-written string would. `_defense_terms` already itemises exactly
this and throws the itemisation away.

### The handedness case, and the correction it needs

Raised as the motivating example: handedness affects reception of spikes and the
player has no way of knowing. The first half is true, the assumed mechanism is
not, and the difference matters for what the caption should say.

Handedness does **not** go through spin, rebound or any physics. It goes through
`Familiarity.read_modifier` via a `hand:left` / `hand:right` read tag, which is
about the *defender's accumulated experience*, not the ball. Measured, 13.2% of
generated volis are left-handed (53 of 400), so the `hand:left` tag accumulates
roughly seven times slower than `hand:right` and stays chronically unfamiliar.
A caption explaining this as spin would be a lie about the model. The true
sentence is closer to *"Mira has seen few left-handed swings"*.

And before any of that gets written, one thing has to be fixed: **the vertical
slice contains zero left-handers, 0 of 14.** `Familiarity.initialize_player`
only rolls a hand when it is handed an rng, and `game_manager.gd:380` -- the
slice's own call site -- does not pass one, so every player keeps the `"Right"`
export default. Every measurement ever taken on the slice, the whole 941-check
suite included, has run with this channel pinned off. Writing player-facing copy
for a mechanic the test data never exercises is the §6 failure mode with a
caption on it.

While measuring that: `Ambidextrous` appeared **0 times in 400** generated
volis. Not unreachable -- 8 of 400 clear its `improvisation >= 82 and
hand_control >= 75` gate, and 16% of those is an expected 1.3 -- but that is one
voli in roughly 312, which is rare enough that its behaviour has never been
observed and probably never validated. Worth deciding whether that is the
intended rate.

## Trace the voli silhouette from the rig instead of drawing stick figures

Spiked and measured, not guessed. The worksheet draws blockers and defenders as
a circle and a few lines, which is the one thing on the clipboard that is a
symbol rather than a likeness -- and the game already owns a posed 3D body with
the right height, wingspan, body type and handedness in it.

**It works.** Render the posed `PlayerActor3D` into a `SubViewport` with a
transparent background, threshold the alpha, trace the boundary, and simplify:

| | block | attack | dig |
|---|---|---|---|
| raw boundary points | 652 | 606 | 446 |
| after Douglas-Peucker at 1.6 px | 55 | 54 | **42** |
| render + trace | 8.2 ms | 9.1 ms | 9.9 ms |

Forty-two points is nothing to draw, and the output is a *closed polyline*, which
means it goes straight into `_marker_stroke` -- so the outline comes out in
pencil with the tooth and the pressure drift on it rather than as a hard vector
edge. That is the whole reason to trace rather than to model: the drawing stays a
drawing.

**Nine milliseconds is a bake, not a frame.** At 60 fps that is most of the
budget for one figure, so the contour is cached per (pose x body type x view) and
recomputed only when one of those changes. Nothing about it is per-frame.

**The payoff over stick figures is not fidelity, it is identity.** The trace runs
against the real physical profile, so a 201 cm Vegi middle and a 172 cm Cani
libero come out as visibly different people on the same sheet -- for free, from
data that already exists. A stick figure cannot carry that at all.

**Known gap.** A pose where a limb separates from the torso in screen space --
a blocker with both arms up -- traces as several islands rather than one, and the
spike's border-follow handles the body cleanly and the detached limbs poorly. A
production version wants proper marching squares over the alpha rather than a
neighbour walk. Bounded, known work; it does not change any of the numbers above.

Also worth noting for whoever builds it: `PlayerActor3D.set_pose` returns early
unless `is_contact_actor` is true, and all the pose-specific limb work is behind
that gate. Posed with `false` the rig silently stays neutral, which is what made
the first three traces come out identical.

## A character for the manager

Two halves, and they should be judged separately because one is nearly free and
the other is premature.

**The clipboard flip is good and cheap.** A left-handed manager holds the
clipboard with the clip on the right, so the rail and detail columns mirror.
It costs a layout reversal, it is instantly legible, and it pays off the desk
metaphor the whole interface is built on -- an object that responds to who is
holding it is exactly what "a desk with things on it" is promising. Nothing in
the simulation has to move for it to be worth having.

**"Coaches left-handed hitters slightly more effectively" is the wrong shape.**
It is a hidden multiplier on a population of 13.2%, which is about 1.6 volis in
a twelve-player squad -- below the noise floor of a season, and unobservable
even in principle. That is a knob that cannot reach its own stated range, which
is the failure this repository keeps re-finding.

The mechanism that *is* available is better and already designed: §0.9 gives the
game an assistant coach who runs every session the manager skips. A manager with
real parameters makes that assistant meaningful -- **what you are good at is
what you do not have to attend.** That is a resource decision the player makes
every day and can watch resolve, rather than a number they never see.

**The avatar is premature until something shows it.** Body type, proportion and
colour all have a renderer already: generation assigns `body_type`, and
`PlayerActor3D` reads height, wingspan and stride to build a body. Reusing it
for a manager is cheap. But the manager never stands on court, and the desk, the
sponsorship obligations and the journal photo that would display them do not
exist yet. Build the surface first, or the creator produces something seen once
and never again.

Suggested order: clipboard flip now; manager parameters when the assistant coach
exists to express them; avatar when there is a page with a face on it.


## The floor defence: two asymmetries and a threshold between them

Measured over 200 rallies on identically-seeded squads.

The floor defence is not weak and the rally cap is not the cause. Defenders are
claimed and attempt on 126 of 212 attacks, and every successful dig leads to an
attack -- 34 home plus 18 opponent successes against exactly 52 attacks
following a defence. The transition works. `MAX_EXCHANGES` binds in 1.0%.

What is wrong is that the two sides' dig contests sit in different places:

  side       attack quality   dig quality   dig success
  home             0.400          0.524          62%
  opponent         0.325          0.354          25%

`_dig_contest` asks `dig_quality + noise > attack_quality + DIG_ATTACKER_ADVANTAGE`,
with the advantage a fixed 0.20. So:

  home digger      0.524 against 0.325 + 0.20 = 0.525   -- exactly on the line
  opponent digger  0.354 against 0.400 + 0.20 = 0.600   -- 0.246 below it

One contest is decided by execution noise; the other is decided before the noise
is drawn. That is the same defect this repository keeps finding -- a threshold
that lands inside one distribution and outside another -- and it is why the
identity gates saturate, why home swings kill 83-91%, and why the median rally
contains one swing.

**Both models are already shared.** Selection goes through
`CoverageModel.choose_claimant` on both sides, and both call `_dig_contest`. The
home path is if anything stricter, since it also requires `defender_arrived`. So
this is not another simplified parallel implementation to unify; the inputs
differ, not the code.

Two gaps feed it and they compound:

- **dig quality, 0.524 against 0.354.** The larger of the two. Where it comes
  from has not been decomposed -- `_dig_terms` builds it from reception,
  anticipation, dig_control and lateral_speed against posture, support count and
  arrival margin, and which of those diverge is the next measurement, not a
  guess.
- **attack quality, 0.400 against 0.325.** Smaller, and already tracked by the
  attack-symmetry ratchet.

### Decomposed

`tools/run_dig_terms_probe.gd`, 150 rallies x 2 serving sides, identically
seeded squads:

  term                    home   opponent    gap
  quality                0.374     0.346   +0.028
  capability             0.644     0.695   -0.051
  timing                 0.880     0.590   +0.290
  posture                0.017     0.047   -0.030
  support                0.013     0.009   +0.005
  opportunity            0.914     0.693   +0.221
  recovery               1.000     1.000   +0.000
  reach_margin_meters    1.058     0.242   +0.816
  contested_against      0.326     0.446   -0.120

**Capability is better for the opponent**, not worse -- 0.695 against 0.644 --
so this is not an attribute gap and no amount of buffing dig ratings addresses
it. Posture, support and recovery are all near-identical or favour the opponent.

The whole gap is `reach_margin_meters`, 1.058 m against 0.242 m, flowing through
`timing` into `opportunity` into `quality`. The opponent defender arrives with a
quarter of a metre to spare where the home defender has a full metre.

Both claimant calls are structurally identical -- same function, same zone
construction, same recovery penalties -- and both sides are staged into their
defensive shape before the claim. So the margin gap is not in how the defence is
resolved. It is `contested_against`: the opponent digs a 0.446 attack where the
home side digs a 0.326 one, and a harder, faster ball arrives sooner and leaves
less margin.

**That "which means the attack asymmetry" was asserted, not measured, and it is
wrong.** `reach_margin` has two inputs -- time available and distance to cover --
and both were assumed to follow from the ball being harder. Measured separately:

  side       flight time given   distance to ball   dig success
  home             0.526 s            1.506 m           56.4%
  opponent         0.339 s            1.828 m           23.6%

The opponent defender gets 36% less time *and* 21% more distance. Two
independent defects, stacked, and neither is "the home attack is stronger".

**Time.** The home defence's budget is re-solved through `_opponent_attack_type`,
whose "Short tip" branch covers everything landing inside y 0.80, so most
opponent swings are *lobbed* for timing purposes while being hit flat for drawing
purposes. The home defence is timing a lob. Confirmed by test rather than
inference: opening `ENABLE_UNIFIED_ATTACK_SHAPE` moves home flight 0.526 to 0.621
and leaves the opponent's at 0.338, widening the gap -- which is precisely what
that flag already records ("the arc it unifies on is the lobbed one"). So the
mechanism is identified and the existing flag does not fix it alone.

**Distance -- decomposed, and the gap does not survive it.**

Ball placement was ruled out first, and in the opposite direction to the guess.
The home defence digs balls landing 2.64 m off centre; the opponent defence digs
balls landing 1.60 m off centre. Placement *favours* the opponent defence, which
covers more central balls and still reports travelling further.

Then the two available measurements of "distance to the ball" turned out to
disagree, and to disagree in opposite directions:

  source                                    home      opponent
  arrival.distance_meters (the claim used)  1.51 m      1.83 m
  movement_start -> ball (playback draws)   2.26 m      1.77 m

On the opponent side they agree within 0.06 m. On the home side they differ by
0.75 m. The cause is two anchors for one defender: the claimant scores zones
anchored at `floor_phase_positions`, the staged defensive shape for this attack,
while `defender_start` reads `live_positions` -- so the claim is computed from
one position and the journey is drawn from another.

**So the direction of the distance gap is not established.** By the claim's own
figures the opponent travels further; by the stamped movement the home defender
does. One of the two is describing a defender who is not there.

**Attempted and reverted: the anchor is not the cause.** The obvious reading is
that `evaluate_arrival` measures from `zone.center` while `defender_start` reads
`live_positions`, so having the arrival report its anchor and both callers use it
should collapse the two figures onto one. Implemented on both sides and it
changed *nothing* -- byte-identical rallies, the claim still 1.506 m and the drawn
journey still 2.257 m. The `anchor` key never arrives, so every call takes the
fallback and reproduces the old behaviour exactly. Reverted rather than shipped,
because a comment asserting it reconciles a 0.75 m disagreement while provably
changing nothing is a false claim left in the source.

**And the disagreement was never real.** Dumping the `arrival` dict rather than
reasoning about it showed that most are *empty* -- only claimed digs carry one.
So "claim distance" was averaged over 44 home rows and "drawn distance" over 78.
A denominator mismatch in the probe, not a defect in the engine.

On matched rows -- the same subset on both sides -- the two agree exactly:

  side       rows with arrival   claim dist   drawn dist   reach margin
  home            44 of 78         1.506 m      1.506 m       1.339 m
  opponent        69 of 106        1.828 m      1.828 m       0.242 m

So the resolver and playback never disagreed, and no anchor needed reconciling.

**What survives is real.** The opponent defender is 0.32 m further from the ball
and has 1.1 m less reach margin, measured on matched rows, while digging balls
that land *more centrally* than the ones the home defence covers.

### Claimant choice, decomposed -- and ruled out

The opponent DEFENSE event now stamps `opponent_phase_targets`, mirroring the
`home_phase_targets` the home dig has always carried. Without it the opponent's
*best available* defender was unmeasurable and "their shape is worse" could only
be asserted. With it:

  side       chosen   best available   penalty   closer teammates
  home       1.613 m       1.495 m     0.118 m         0.20
  opponent   1.828 m       1.794 m     0.034 m         0.07

The opponent's claimant is **better** than the home one -- it concedes 0.034 m
against 0.118 m, and passes over 0.07 closer teammates against 0.20. Both sides
run the same `choose_claimant`, and neither is picking badly.

**The entire gap is `best_available`: 1.495 m against 1.794 m.** Even the
opponent's *closest* defender is 0.30 m further from the ball than the home
side's closest. There is no defender to choose who is any nearer.

So: not the rally cap, not dig ratings (the opponent's capability is *higher*),
not the dig contest, not ball placement (which favours them), not the anchors,
not the measurement, and not the claim. **The opponent's staged defensive shape
is positioned 0.30 m worse for the balls it actually faces**, and that is the one
thing left standing.

### Shading, checked -- neither side does it

`tools/run_defensive_shading_probe.gd` measures how far each shape's centroid
moves per metre the attack lane moves:

  side       n    lane sd   centroid sd   slope
  home      50      0.250        0.014    0.019
  opponent  69      0.025        0.009    0.085

**Neither shape shades.** Centroid movement is 0.014 and 0.009 in normalised x --
0.13 m and 0.08 m across the whole sample -- so both are effectively static and
shading is ruled out as the differentiator. The opponent's 0.085 slope is fitting
noise; with a centroid spread of 0.009 against a lane spread of 0.025 there is
nothing there to regress.

That both sides stage a fixed shape is worth knowing on its own. A defence that
does not move with the attack is a defence that cannot be out-positioned *or*
well-positioned, and the 0.30 m best-available gap therefore comes from where the
two fixed shapes sit relative to where balls arrive, not from one reacting better
than the other.

### The unlooked-for finding: home attacks come from one place

`lane sd` is 0.025 for the attacks the opponent defends and 0.250 for the attacks
the home side defends -- a factor of ten. The home hitter contacts at an almost
fixed x, about 0.22 m of spread, while opponent contacts range over 2.25 m.

The home offence is not using the width of the court. That is upstream of the dig
question and probably upstream of several others: a fixed contact lane means the
crossing point, the block's staging and the defence's shape are all being asked
to cover a distribution that barely exists on one side and is wide on the other.
It also sits directly beside the reported playback behaviour of an outside hitter
running parallel to the net rather than into it, which would be the same defect
seen from the approach end.

Measure the contact-x distribution per side and per lane assignment before
touching the defensive shape; a 0.30 m shape gap is small next to an offence that
attacks from one spot.

**Observed independently in debug playback, and it matches term for term.** Out
of solid serve receive the home offence overwhelmingly plays: a T2 set, a
controlled roll against a *single* blocker, into short court, landing where the
nearest defender has to cover 1.3-2.2 m and cannot.

Every one of those has a number beside it already:

- *one place* -- contact-x spread of 0.025 against the opponent's 0.250
- *single blocker* -- 190 one-blocker walls against 126 doubles
- *controlled roll* -- the shot-type downgrade `ENABLE_UNIFIED_ATTACK_SHAPE`
  documents, where a set quality below 0.38 drops the swing to a roll
- *1.3-2.2 m and cannot* -- opponent dig distance of 1.828 m at a 25% success rate

So this is not a defensive hole being exploited by a varied offence. It is **one
shot, repeated**, because the decision layer has found a dominant option and has
no reason to leave it. The defence being 0.30 m out of position is the least
interesting thing in that sentence.

That reframes the order of work. Shot selection comes before defensive shape:
a defence tuned against an offence that plays one ball from one place will be
mistuned the moment the offence stops doing that.

Both want their own fix. Neither is the attack-symmetry ratchet, and treating
them as one thing is what produced the wrong answer above.

One genuine defect was found and fixed on the way: the opponent's *continuation*
dig passed its raw flight time while the other two dig sites both add 0.24 s for
a block touch and 0.06 s for a funnel. Three sites, one rule -- but it changed
the measured terms not at all, because that branch never fires in this sample.
Recorded as fixed and immaterial rather than as a win.

And `DIG_ATTACKER_ADVANTAGE = 0.20` should be re-derived once they are
comparable, against the dig-success rate the sport actually shows -- roughly
35-45% against a live swing, which sits between the 62% and 25% measured here.
Neither current figure is right, so this is not a case of raising the weaker one
to match the stronger.


### Depth split by outcome: the opponent defence only wins deep balls

`tools/run_defensive_depth_probe.gd`, metres from the net:

  side       dug     n   ball depth   stood at   travel
  home       yes    44        3.67       3.75      2.80
  home       no     34        4.22       3.68      1.56
  opponent   yes    25        6.26       6.60      1.42
  opponent   no     81        3.76       3.29      1.88

The opponent's 25 successes are deep-court diggers standing at 6.60 m taking
balls at 6.26 m. Its 81 failures are balls at 3.76 m with the defender standing
at 3.29 m -- **roughly the right depth**, 0.47 m adrift, and still 1.88 m from the
ball. That leaves a lateral component of about 1.82 m.

**"Beside the ball rather than behind it" was wrong, and wrong by construction.**
That read compared mean stood-at depth (3.29 m) against mean ball depth (3.76 m)
and called the 0.47 m remainder the depth component. A difference of means is not
the mean of the differences, and here the two disagree badly.

Decomposing the *nearest* defender's offset per row instead:

  side       nearest lateral   nearest depth   ball x   shape width
  home              0.69 m          1.20 m      0.422        5.18 m
  opponent          0.97 m          1.38 m      0.498        6.05 m

Depth dominates on both sides, not lateral. Both axes are worse for the
opponent, by 0.28 m laterally and 0.18 m in depth.

**The standout is the last column.** The opponent's shape spans 6.05 m of a 9 m
court against the home side's 5.18 m, while the balls it concedes arrive at
x = 0.498 -- dead centre. A wider shape taking balls in the middle is a gap
*between* defenders rather than a shape standing in the wrong place, and it
explains why the nearest defender is a metre away on both axes at once while the
claimant is picking near-optimally out of what it has.

### Straddle measured -- there is no hole, and no lateral story at all

`tools/run_straddle_probe.gd`:

  side       dug     n   straddle gap   to nearer edge   outside
  home       yes    16         1.94 m           0.58 m         1
  home       no     34         1.56 m           0.35 m        17
  opponent   yes    11         2.14 m           0.75 m         0
  opponent   no     58         1.99 m           0.50 m         9

Gaps run 1.56-2.14 m across all four rows and failures do not have wider ones --
home failures have the *narrowest* gap of the four. So the wider opponent shape
is evenly wide, not holed.

`to nearer edge` then runs backwards: balls that are **not** dug sit laterally
*closer* to a straddling defender (0.35 m and 0.50 m) than balls that are
(0.58 m and 0.75 m). Lateral proximity does not predict success, and on this
evidence mildly anti-predicts it.

**Positioning is ruled out.** Across the whole decomposition the defence has
better capability (0.695 against 0.644), a better claimant (0.034 m of concession
against 0.118 m), easier ball placement (1.60 m off centre against 2.64 m), no
hole in its shape, and no lateral disadvantage where it fails. It still digs
23.6% against 56.4%.

**What has never been ruled out is time.** Flight time given to the defender is
0.526 s home against 0.339 s opponent -- 36% less -- and that traces to
`_opponent_attack_type`, whose "Short tip" branch covers everything landing
inside y 0.80, so the home defence is timing a *lob* while the opponent defence
times a spike. It is the one term that has survived every measurement, and it is
already documented behind `ENABLE_UNIFIED_ATTACK_SHAPE`, which does not fix it
alone because the arc it unifies onto is the lobbed one.

One separate observation, small and worth a look on its own: 17 of 51 home
failures had **nobody on one flank of the ball at all**, against 1 of 17
successes. That is a different defect from a gap -- it is the ball going outside
the shape entirely -- and it is specific to the home side.

Sample sizes on the success rows are small (16 and 11); treat the success columns
as indicative and the failure columns as solid.

Worth noting the home rows do not follow the same pattern -- home successes
travel *further* than home failures, 2.80 m against 1.56 m. A side that succeeds
on the long journeys and fails on the short ones is not a positioning story, and
the home path additionally gates on `defender_arrived`. Do not assume the two
sides fail for the same reason.

### The debug path only ever shows one service side

`scenes/main/main.gd:487` sets `serving_home = false` unconditionally before
running a shadow-debug rally and restores it afterwards. Every debug rally
therefore has the opponent serving, and no seed exists that starts with a home
serve.

That is why observation from debug reports "the vast majority of home attacks out
of solid serve receive" -- serve receive is the only phase the tool can show. Half
the engine has never been watched, including the entire home-serving branch whose
opponent-side transition attack and continuation dig are two of the three dig
sites measured above. Make the service side selectable in the fixture before
drawing further conclusions from what debug displays.


## The opponent never spikes, and it is not the threshold

`tools/run_shot_downgrade_probe.gd`, 150 rallies x 2 serving sides:

  attack types produced
    home      High-ball swing=169  Tempo swing=11   Controlled roll=5
    opponent  Roll shot=103        Emergency tip=14  Power swing=3

96% of home attacks are swings. 97% of opponent attacks are rolls or tips --
three power swings in a hundred and twenty.

The obvious suspect is the downgrade threshold sitting above the distribution it
cuts, which is the most common defect in this repository. It is not that:

  set quality      n     p10     p25     p50     p75     p90   below compromise
  home           185   0.100   0.326   0.682   0.722   0.762     46 (25%)
  opponent       120   0.259   0.627   0.755   0.798   0.861     13 (11%)

**The opponent's sets are better than the home side's** -- median 0.755 against
0.682 -- and only 11% fall below the 0.30 compromise threshold. The legacy branch
downgrades below 0.38 or on a 12-20% improvisation roll, and neither can turn an
11% tail into 97% of attacks.

So the `set_quality` that shot selection reads is not the `set_quality` stamped on
the SET event. `ENABLE_UNIFIED_ATTACK_SHAPE` quotes a median of 0.344 for the same
quantity the event reports at 0.755. One name, two numbers, and the one shot
selection reads is roughly half the one the setter actually delivered.

**This is the root of the entire dig chain.** An opponent that rolls 97% of the
time hands the home defence a slow lofted ball -- which is the 0.526 s of flight
against the opponent's 0.339 s, which is the reach margin, which is the 56.4%
against 23.6% dig rate, which is the saturated identity gates and the symmetry
ratchet. Every measurement in this section is downstream of it.

It also explains the shape of what debug playback shows. The tool only ever runs
the opponent serving, so what is watched is the home side attacking out of serve
receive against a side that answers with rolls.

### The second `set_quality`, found -- and a third one implied

`opponent_set_quality` is computed twice in the same function, and the code says
so: line 2376 computes it from `set_geometry.difficulty`, whose target is the
placeholder `(0.50, 0.48)`, and hands it to `_choose_opponent_attack`; line 2469
recomputes it from `resolved_set_geometry.difficulty` once the contact is final,
and *that* is what the SET event stamps.

So shot selection decides roll-against-swing on a set that was never delivered.
`ENABLE_DELIVERED_SET_SHOT_CHOICE` re-applies the gate against the resolved
value, carrying the improvisation draw forward rather than redrawing it.

**It changes almost nothing: 3 power swings become 4 out of 120.** At a delivered
quality of 0.755 the gate would leave roughly four swings in five intact, so the
resolved value this reads must also be low.

Which means there are three numbers, not two: the estimate, the resolved value,
and whatever the SET event's 0.755 median is -- because it is demonstrably not the
resolved value the code assigns immediately before stamping it. **Re-attribute
the 0.755 first.** It is the only figure suggesting the opponent's sets are good,
and the conclusion that the downgrade thresholds are correctly placed rests
entirely on it. If that number is something else, the thresholds are back in
question.

### Resolved: the 0.755 was real, and the set-quality gate was never the cause

The 0.755 stands. It is the resolved `opponent_set_quality`, stamped where the
code says it is; there is no third number. Re-applying the shot gate against it
barely moved the mix for a much simpler reason -- **the gate is not what turns
opponent swings into rolls.**

There are two independent rewrites of a shot type, and only the second one's
output was ever published. `tools/run_downgrade_attribution_probe.gd` separates
them, and both `intended_type` and `chosen_type` are now stamped on every ATTACK
event so the split is legible without a probe:

| opponent swings | asked for a power family | after the set-quality gate | after `backs_off` |
|---|---|---|---|
| 119 | 119 | 88 | **3** |

The set-quality gate costs 31 swings. `AttemptJudgment.backs_off`, reading the
approach, costs 85. Two earlier investigations went after the gate.

`tools/run_backoff_terms_probe.gd` then itemises the approach deficit, which
`attack_family_deficit_terms()` now returns rather than summing away:

| side | rating | lateral | runup | **arrival margin** | power access | total |
|---|---|---|---|---|---|---|
| home | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 |
| opponent | 0.000 | 0.000 | 0.000 | **0.662** | 0.296 | 0.958 |

The arrival margin reads -0.461 s for the opponent against +0.288 s for the home
side -- and it is **stale**. See `ENABLE_CLAMPED_ARRIVAL_MARGIN` and
`FAILURE_MODES.md` §15: `_reachable_contact` moves the contact back to whatever
the hitter reaches as the ball arrives, so the clamp makes them punctual by
construction, and all three swings kept billing the pre-clamp figure.

With the flag on: opponent power swings 3/119 -> 27/110, back-off rate 71% ->
49%, and the arrival term disappears (0.004 mean, fires on 0% of swings).

**Left off, because it is large rather than doubtful.** Every downstream band was
calibrated against a side that rolled nearly every ball. It lands with the block
outcome-band re-tune, alongside `ENABLE_UNIFIED_ATTACK_SHAPE` and
`ENABLE_UNIFIED_RECEPTION_SKILL`.

**Next, and it is the last term standing:** the opponent's remaining deficit is
entirely `power_access` -- run-up quality 0.337 against a 0.52 floor, where the
home side reads 0.687. Two sides, identical code, half the run-up. Note also that
`approach_in_system` reads **0% on both sides**, which no swing in the game has
ever satisfied; that is a §2 candidate in its own right.

The machinery added is sound regardless: the improvisation draw is now taken
unconditionally and gated afterwards, because `set_quality < 0.38 or rng.randf()`
short-circuited and made draw counts depend on the branch. That is the rule in
FAILURE_MODES.md section 8, and correcting it re-sequences one rally in three
hundred with the flag off.

---

## The stale-derivation audit

`tools/audit_stale_derivations.py` sweeps every `.gd` file for the shape behind
the arrival-margin defect: a local derived from `X`, `X` then reassigned, and the
derived value read afterwards without being refreshed. It is deliberately noisy
-- 57 candidates across `scripts/`, most of them benign -- and reports candidates
for a human read, not verdicts.

```
python3 tools/audit_stale_derivations.py scripts
```

Triage of the 57:

**Confirmed defects, both from the same clamp, both now flagged off.**

| what | where | binds on |
|---|---|---|
| `hitter_arrival_margin` derived pre-clamp | all three swings | 74% of opponent swings |
| `opponent_lane` derived pre-clamp | opponent transition | 36% of opponent swings |

The lane one is `ENABLE_CLAMPED_CONTACT_LANE`. `opponent_lane` is read off the
contact the set aimed at, three hundred lines before `_reachable_contact` moves
that contact; the wall is then restaged against the new contact but the old lane,
familiarity accrues to a lane nobody swung from, and `_geometric_swing` resolves
the ball along the old lane's natural course -- which is precisely the failure the
lane fix was written to stop. 40 of the 43 drifted swings are one migration,
Right Quick to Right Pin: a middle who cannot reach the quick is dragged back
down their own approach, which runs outward, and arrives at the pin still
labelled a quick. `tools/run_lane_drift_probe.gd`; the flag takes it to 0%.

**Confirmed, but latent behind a flag that is off.** On the home path,
`_compromised_shot_type` rewrites `hit_type` *after* `swing_deficit` has been
charged against the power swing and already spent against `attack_quality`, so a
hitter who backs down to a roll pays the overreach penalty for the swing they
declined. The `using_live_attack` rollout branch has the same ordering. The
opponent path re-reads the shot before its deficit, so the asymmetry is
one-sided. Recorded on `ENABLE_UNIFIED_ATTACK_SHAPE`, which must not land until
the ordering is fixed. Nothing exercises this today; the sweep found it, not a
rally.

**Deliberate, and each already says so in the code.** Worth listing, because they
are the same shape and a future sweep will surface them again:

- `set_arc` / `continuation_set_arc` are not re-solved after the clamp.
  `_retarget_set_event` explains it: a setter delivering short lofts the ball
  rather than releasing earlier, so the hang time stays and only the landing
  point moves -- and re-solving would be circular, since a shorter ball flies for
  less time, which shortens the runway that caused the clamp.
- `opponent_capability` is read after `opponent_tempo_call` is downgraded. The
  setter is billed for what they attempted and delivers what they can; that is
  the model.
- `home_block_formation` is staged against the pre-clamp contact on purpose --
  blockers commit during the set's flight. The adjustment they make once the
  hitter commits is `_wall_stage_x`, which *is* recomputed.
- `intended_attack_target` is kept precisely because `attack_target` moves.

**Unresolved, and not claimed either way.** `home_block_pressure` is derived from
the staged formation's `primary_close`/`assist_close` and feeds the swing's
quality. Whether it should reflect the post-commitment adjustment is a design
question about when pressure is felt, not a stale read. Left alone.

---

## Withdrawn: the opponent's shot mix is not upstream of the dig asymmetry

Recorded because it was asserted twice, in a commit message and in this file, and
it is wrong.

The claim was that a side rolling nearly every ball hands the other side a slow
lofted one to read, and that this was "upstream of most of the dig asymmetry".
`ENABLE_CLAMPED_ARRIVAL_MARGIN` takes the opponent from 3 power swings in 119 to
27 in 110 -- a change of shot mix from 3% to 25% -- which is the largest lever
anyone has found on that mix. The dig terms barely notice:

| term | flags off | arrival margin on | both clamp flags on |
|---|---|---|---|
| timing gap | +0.290 | +0.285 | +0.285 |
| reach margin gap | +0.816 m | +0.790 m | +0.790 m |
| home dig quality | 0.374 | 0.365 | 0.365 |

The opponent's own defensive rows are byte-identical across all three, which is
correct and worth stating: they defend *home* attacks, and the home swing never
clamps, so nothing about it moved.

**So the defensive asymmetry survives an eightfold change in the attack it
defends.** Both clamp fixes are still right -- they are stale reads and the
correctness argument does not depend on what they buy -- but neither is the
defensive fix, and the mix is not the cause.

### The gap is one number, not two

`_defense_terms` computes `timing` as
`(reach_margin + DIG_REACH_MARGIN_METERS) / DIG_REACH_MARGIN_METERS`. It is a
pure function of the reach margin. The probe prints them as separate rows, and
reading a "timing gap" beside a "reach margin gap" as two pieces of evidence
double-counts one fact -- which is how the timing term came to be guessed at as a
cause on its own.

There is no time in the dig model at all. Ball speed reaches it only through
whatever sets `reach_margin_meters`, which is why a 3%-to-25% swing in the shot
mix moved the home defence's margin by 0.025 m.

**Next: `reach_margin_meters`, 1.058 m home against 0.242 m opponent.** It is the
sole input to `timing`, it carries the whole of the dig gap, and it has now
survived every change made this session. Start by asking what it is measured
against on each side, per FAILURE_MODES.md 14 -- print what arrives before
touching what produces it.

---

## The reach margin, decomposed -- and it is an offensive defect

`reach_margin_meters` is the sole input to the dig's `timing` factor and carries
the whole dig asymmetry. `CoverageCalculator.evaluate_arrival` now returns the
six terms it was summing away, and `tools/run_reach_margin_probe.gd` reads them
off the DEFENSE events rather than recomputing any of them.

| term | home | opponent | gap |
|---|---|---|---|
| ball_time_seconds | 0.824 | 0.520 | **+0.304** |
| reaction_delay | 0.348 | 0.319 | +0.029 |
| movement_speed_mps | 3.751 | 3.779 | -0.028 |
| acceleration_factor | 0.873 | 0.863 | +0.010 |
| base_reach_meters | 1.240 | 1.268 | -0.027 |
| travel_distance_meters | 1.604 | 0.803 | **+0.801** |
| distance_meters | 1.506 | 1.828 | **-0.323** |
| reach_margin_meters | 1.339 | 0.242 | +1.097 |

Four of the six are symmetric to within 3%, which rules out locomotion, reach and
reaction outright. The margin is **time (73%) and distance (27%)**, nothing else.

### The two defences never face the same shot

Splitting by the swing that caused each dig ends the argument:

| side | attack defended | n | ball_time | reach_margin |
|---|---|---|---|---|
| home | Roll shot | 37 | 0.826 | 1.268 |
| home | Emergency tip | 6 | 0.853 | 1.610 |
| opponent | High-ball swing | 69 | 0.520 | 0.242 |

**No overlap at all.** Ball time is a property of the shot -- a roll is lofted
and hangs 0.83 s, a high ball arrives in 0.52 s -- so the home defence gets a
third of a second more on every ball it ever sees, and the "defensive gap" is
two sides being fed completely different diets.

Both diets are degenerate, in opposite directions:

```
home      Controlled roll=5   High-ball swing=169  Tempo swing=11
opponent  Emergency tip=14    Power swing=3        Roll shot=103
home tempo    T2=16 (9%)   T3=169 (91%)   -- never T0, never T1
```

The home side high-balls 92% of its swings and **never once runs a quick**. The
opponent rolls 97% of theirs. Neither side plays volleyball.

### Correcting the earlier withdrawal

This file previously recorded "the opponent's shot mix is not upstream of the dig
asymmetry", on the evidence that `ENABLE_CLAMPED_ARRIVAL_MARGIN` moved the mix
without moving the gap. **That reasoning was wrong**, and the error is worth
keeping because it is a general one: the flag changed only the *opponent's* mix,
and only from 97% rolls to 75% rolls. It never touched the home side's 92%
high-ball diet, which is the entire diet the opponent's defence faces -- the half
of the comparison that reads 0.242 m. A lever that moves one quarter of one side
of a two-sided comparison is not a test of the mechanism.

The mix is the mechanism. The lever was too small and pointed at one side.

**Next: why the home offence never calls a quick.** `_hit_type` returns
"High-ball swing" for any tempo 3 assignment, and 91% of home assignments are
tempo 3 with none below 2. `_tempo_call` starts from a requested tempo and only
quickens on a good pass, so either the request is a constant or its thresholds
sit outside the pass-quality distribution it cuts -- the section 2 shape, and the
two want different fixes. Measure the requested tempo before changing either.

---

## The home offence was two hitters and a high ball

`_fallback_hitter` runs on **every ball the calibration fixture plays**, because
no play is ever called. It looked only for Outside Hitters, and
`_fallback_assignment` chose a lane from which half of the court the hitter
happened to stand in -- which can only ever produce a pin.

```
home lanes    Left Pin=34    Right Pin=151    (no quick, no pipe, ever)
home tempo    T2=16 (9%)     T3=169 (91%)     (never T0, never T1)
```

The middle never attacked. And `_hit_type` reads "Quick attack" off the **lane**,
never off the tempo, so no amount of tempo variation could have produced one.

### Two independent thresholds outside their distributions

Home pass quality measures p10 0.291, p25 0.350, **p50 0.419**, p75 0.494, **p90
0.567** (`tools/run_shot_downgrade_probe.gd`).

- `OPPONENT_QUICK_CALL_PASS = 0.68` is **above the p90**. The quicken branch of
  `_tempo_call` fires essentially never.
- `OPPONENT_SLOW_CALL_PASS = 0.38` sits between p25 and the median, so it fires
  on roughly a third of balls.

The tempo call is therefore a **one-way ratchet toward the slowest set in the
game**. Not fixed here: the constant is shared with the opponent's path, whose
pass distribution is a different shape (p50 0.276 against 0.419), and one
constant cut against two distributions wants its own measurement rather than a
value tuned until one side looks right.

`_apply_identity_tempo` is the same shape a third time. Its thresholds are 0.66
and 0.34 against a preset table clustered on 0.50, so for **Balanced -- the
default and the calibration fixture's identity -- the entire function is inert**:

| identity | commitment | shift | tempo_variation | varies? |
|---|---|---|---|---|
| Balanced | 0.500 | 0 | 0.50 | **no** |
| Technical | 0.425 | 0 | 0.42 | **no** |
| Physical | 0.815 | -1 | 0.38 | no |
| Defensive | 0.225 | +1 | 0.24 | no |
| Fast Tempo | 0.843 | -1 | 0.88 | yes |
| Development | 0.510 | 0 | 0.72 | yes |

### `ENABLE_HOME_MIDDLE_OFFENSE`, and what it costs

With the flag on, the middle attacks on the best quarter of passes
(`OFFENSE_QUICK_PASS_FLOOR = 0.494`, solved as the measured p75):

```
home lanes    Front Quick=74   Right Pin=106
home tempo    T1=74 (41%)      T3=106 (59%)
```

**The dig asymmetry mostly disappears with it**, which is the confirmation that
it was never a defensive defect:

| | flag off | flag on |
|---|---|---|
| reach margin gap | +1.097 m | **+0.271 m** |
| ball_time gap | +0.304 s | +0.149 s |
| distance gap | -0.323 m | -0.168 m |

**Left off, and not because it is doubtful.** The attack-symmetry ratchet goes
0.654 to **0.340** -- the same distance off centre, in the opposite direction --
and the block-intent gates fail again. A home side that runs a first-tempo ball
41% of the time is being blocked by a wall calibrated against a side that only
ever hit pins, and the wall now loses. That is the same blocker
`ENABLE_UNIFIED_ATTACK_SHAPE` and `ENABLE_UNIFIED_RECEPTION_SKILL` are waiting
behind: **re-separate the block's outcome bands against sides that actually
attack**, then land all three together and re-measure. Do not widen the bound.

The ratchet flipping sign rather than merely moving is itself the useful reading:
0.654 and 0.340 bracket the answer, so the three held flags are unlikely to
compound in the same direction.

**One defect this introduced and the counts caught.** The first version produced
74 quick *lanes* against 35 first-tempo balls, because the continuation path
overwrites `assignment.tempo` from `TRANSITION_TEMPO_BASE` a line after
`_fallback_assignment` sets it -- a middle running a quick approach under a high
ball. A quick is a first-tempo ball by definition, so the tempo is no longer the
transition setter's to call once the lane is chosen. Section 7, found by counting
lanes against tempos rather than by reading the diff.

---

## The block bands are not the defect, and cannot be tuned as specified

`STUFF_DEPTH_METERS` and `TOOL_EDGE_MARGIN_METERS` are the live bands under
`ENABLE_GEOMETRIC_ATTACK`; the `BLOCK_*_MARGIN` constants are legacy. Neither
geometric band had ever been checked against its own distribution, because both
quantities were computed inside `_block_contact` and consumed there. They are now
published on every ATTACK event and `tools/run_block_geometry_bands.gd` reads
them.

**Where the bands sit, on the side that has a sample:**

```
attacked   swings  contacted   stuff  touch   tool
home          185         57      12     31     14
opponent      120          6       2      0      4
```

Against the opponent's wall, `depth_below` runs p10 0.049, p50 0.130, p75 0.183,
p90 0.262 and the 0.21 band cuts 21% of it -- **inside the spread, near the top,
which is what a stuff band should be.** Partial outcomes outnumber terminal
stuffs 45 to 12. The bands are doing their job wherever they can be observed.

**Why it cannot be tuned:** the other side of the comparison is *six balls*. The
home wall contacts 5% of opponent swings against the opponent wall's 31%, and its
six contacts all sit above the stuff band (p10 0.299 against a 0.21 band), so a
touch by the home wall is arithmetically impossible. That is not a band that
needs moving -- it is a sample that cannot support a decision, and moving a band
to make six balls come out differently is fitting a constant to noise.

**Why the wall is not there:**

```
why the wall was missed (opponent swings, 120)
  (none)=39   around=30   no wall=31   over=14   contacted=6
```

**The home wall does not form at all on 31 of 120 opponent swings**, and is beaten
around on 30 more. The equivalent row for the opponent's wall carries no "no
wall" at all. That is the defect, and it sits upstream of every band.

**So the dependency in the flag comments is backwards.** Three flags
(`ENABLE_UNIFIED_ATTACK_SHAPE`, `ENABLE_UNIFIED_RECEPTION_SKILL`,
`ENABLE_HOME_MIDDLE_OFFENSE`) are each held waiting for "the block outcome bands
to be re-separated". The bands cannot be separated while one wall barely
participates, and turning the offence flags on does not fix it -- measured with
`ENABLE_HOME_MIDDLE_OFFENSE` and `ENABLE_CLAMPED_ARRIVAL_MARGIN` both on, the home
wall still contacted exactly 6 balls with an identical depth distribution.

**Next, and it is a different question from the one this section was opened to
answer: why does the home wall fail to form on a quarter of opponent swings?**
`_form_home_block` is the producer. Ask what it returns on those 31 rows before
changing anything in it.

### One defect this instrumentation introduced

Stamping the two quantities as `NAN` when no contact happened broke the
shadow-trace determinism check and the 2D court's trace acceptance immediately:
**NaN is not equal to itself**, so a metadata dictionary carrying one can never
compare equal to a byte-identical copy. Absent is the right encoding for "no
contact" anyway. Worth adding to the determinism entry in `FAILURE_MODES.md`:
a sentinel that fails its own equality test is not a sentinel.

### Found: the home wall is absent on 45% of opponent swings

`wall_size` is now forwarded to the ATTACK event -- it was in
`_geometric_swing_record` and `_geometric_promotion` did not pass it on, the same
dropped-key shape that hid `block_miss_reason` for as long.

```
how many blockers were in the wall at all
  home attacks      1=145 (78%)   2=40 (22%)                 <- never zero
  opponent attacks  0=54 (45%)    1=51 (42%)   2=15 (12%)
```

**The opponent's wall is never absent. The home wall is absent on nearly half of
opponent swings.** That is the whole reason the home wall contacts 5% of balls
against the opponent wall's 31%, and it is upstream of every band -- a threshold
cannot be tuned on a wall that is not there.

`GeometricAttackPromotion.block_wall` drops any blocker whose close fraction is
under `WALL_JOIN_CLOSE = 0.34`, and that is the only gate that can produce a
`wall_size` of zero from a formation that named a primary. So the home blockers
are failing to close on 45% of swings while the opponent's blockers always close.

Two producers, as usual: `_form_home_block` and `_form_opponent_block`. The home
one is handed a constant `DEFAULT_SET_RELEASE_SECONDS + DEFAULT_SECOND_CONTACT_SECONDS`
(1.10 s) as its pass-to-release window; the opponent's is handed
`second_contact_window + cont_release_interval`, computed live. **Note the
direction before assuming: the home wall gets the larger, constant window and
still fails to close.** So the window is unlikely to be the term -- start by
printing `primary_close` and `assist_close` per side against the 0.34 gate, and
find which input to the close differs. Do not change `WALL_JOIN_CLOSE` first;
a gate that is correct against one distribution and wrong against another is the
symptom, not the cause.

### The close is binary, so the gate is not the question

`tools/run_block_close_probe.gd` -- and nothing needed adding, both closes have
been on the BLOCK event all along.

```
primary close       n      p10      p25      p50      p75      p90  below gate
home               56    0.000    0.000    1.000    1.000    1.000         38%
opponent          160    1.000    1.000    1.000    1.000    1.000          0%
```

**It is not a fraction.** Every percentile is either 0.000 or 1.000: the primary
blocker is either fully closed or not there at all, and nothing in between is
ever produced. `WALL_JOIN_CLOSE = 0.34` is therefore not cutting a distribution
-- any value strictly between 0 and 1 gives the identical answer, and moving it
would have changed nothing while looking like a fix.

So this is not the section 2 shape after all. It is a producer emitting a
**boolean through a float-shaped channel**, and the two producers disagree about
whether zero is reachable: `_form_opponent_block`'s primary is closed on every
one of 160 blocks, `_form_home_block`'s fails to close on 38% of 56.

The assist is worse and symmetric, which is the useful control: it reads 0.000
through the p75 on *both* sides and is present on 12% of home blocks against 21%
of the opponent's. A double block is close to nonexistent in this engine on
either side of the net, and that is a separate finding from the primary's.

**Next, and it is now a narrow question:** what makes `_form_home_block` return a
`primary_close` of exactly zero, and why can `_form_opponent_block` never return
one? Two producers, one of which has a failure state the other does not. Print
the inputs to the close on the 38% before changing either -- and do not touch
`WALL_JOIN_CLOSE`, which this measurement has now ruled out.

### Located: the close formula is continuous, so the input must be bimodal

`_blocker_close_fraction` ends:

```gdscript
clampf(1.0 - maxf(required_seconds - usable_time, 0.0)
       / BLOCK_CLOSE_FAILURE_SECONDS, 0.0, 1.0)
```

with `BLOCK_CLOSE_FAILURE_SECONDS = 0.45`. **That is a wide ramp, not a narrow
one** -- any deficit between 0 and 0.45 s returns an intermediate close. The
formula is not what makes the output binary.

So the deficit `required_seconds - usable_time` must itself be bimodal: at or
below zero, or beyond 0.45 s, with 56 samples and nothing in between.

**Hypothesis, not yet measured.** The primary is chosen as the blocker *nearest*
the attack, and a front row has three slots. So the nearest blocker is either
already standing in the lane -- deficit strongly negative, close 1.0 -- or a whole
slot away, which at block-close speed from a standstill is far more than 0.45 s
of deficit. There is no intermediate distance for a three-slot row to produce,
which would make the binary a consequence of the *court*, not of any constant.

If that holds, the fix is not a constant at all. It is that a real block closes
by a blocker who starts moving on the read rather than one who starts from a
standstill when the ball is already up -- and `BLOCK_PLANT_SECONDS` plus the
preset window are where that would have to come from.

**The discriminating measurement:** print `required_seconds`, `usable_time` and
their difference for every close, per side. If the difference is bimodal the
hypothesis holds and the constants are innocent; if it is spread across 0 to
0.45 s and the *output* is still binary, something downstream is rounding it and
that is a different defect entirely. Measure before touching either constant.

### The discriminator ran, and it refutes the hypothesis

```
deficit_seconds, bucketed
side              n       <= 0   0 to 0.225   0.225 to .45     > 0.45
home             56         31            4              2         19
opponent        160        158            2              0          0
```

**The middle buckets are not empty.** Six of 56 home closes land between the
extremes. The deficit is strongly bimodal, not binary, and the three-slot-row
explanation is wrong.

**And the "binary close" reading was a percentile artifact.** Six intermediate
values out of 56 is 11% -- enough that no decile lands on one, so p10 through p90
all read 0.000 or 1.000 while the distribution underneath was never two-valued.
That is section 3 in its plainest form: the percentiles were correct and the
sentence drawn from them ("nothing in between is ever produced") was not. The
bucket counts were four lines of work and would have said so immediately.

### What the term actually is

```
                    home    opponent
available_time     0.967      1.586
usable_time        0.431      1.029
required_seconds   0.345      0.272
footwork_meters    0.365      0.153
deficit_seconds   -0.087     -0.757
```

**`available_time` -- and the previous entry predicted the opposite.** It reasoned
that the home wall is handed a constant 1.10 s pass-to-release window against the
opponent's live one, so the window could not be the term. Measured, the home wall
has 0.967 s of closing time against the opponent wall's 1.586 s: **less than
two-thirds of it, and less than half once the plant comes off.** Required time and
footwork are near-identical between the sides. The window is the whole story.

The reason closes the loop on the last four sections. `close_time` is built on
`set_flight_time`, and each wall closes during the *other* side's set. The home
side sets tempo 3 on 91% of balls, so the opponent's wall gets ~0.9 s to close and
always makes it. The opponent sets fast, so the home wall gets ~0.5 s and misses
45% of the time.

**So the home wall's absence, the block's 5%-vs-31% contact gap, the untunable
outcome bands, and the dig asymmetry are all one defect: the home offence never
varies tempo.** It is also why `ENABLE_HOME_MIDDLE_OFFENSE` flipped the symmetry
ratchet to 0.340 rather than merely moving it -- adding quicks takes closing time
away from the opponent's wall, which had been getting all it wanted.

**Next: land the tempo work rather than anything in the block.** No constant in
the block model is implicated -- `WALL_JOIN_CLOSE`, `BLOCK_CLOSE_FAILURE_SECONDS`
and the preset window are each now measured and cleared. The block bands are fine
where they can be observed. What the wall needs is an opponent whose sets are not
uniformly slow and a home side whose sets are not uniformly high, and both of
those are the offence.

---

## The ratchet passes when the fixes land together, and that changes the plan

Nothing in this thread had shipped. Four measured, correct simulation fixes were
built and every one switched off, because each individually moved the
attack-symmetry ratchet -- a *do not drift further* gate that any change to the
balance fails, **including a correct one**. Respecting it one fix at a time
guarantees that nothing ever lands, and that is what happened.

Turned on together -- `ENABLE_CLAMPED_ARRIVAL_MARGIN`,
`ENABLE_CLAMPED_CONTACT_LANE`, `ENABLE_HOME_MIDDLE_OFFENSE` -- **the ratchet
clears.** It is not in the failure list at all. Individually the same three read
0.654 and 0.340, which bracket centre; together they land inside the bound.

Five failures remain, and they are a bounded list rather than another chain:

| failure | read |
|---|---|
| Gate 44 block event identity with no rollout policy | probably sequence sensitivity, needs confirming |
| Gate 49 ordinary resolution of the same seed | same family as above |
| a funnelling block deflects more than a sealing one (25 vs 31) | the known intent gate |
| neither block intent is strictly better than the other | the known intent gate |
| extreme hitter displacement reduces arrival and attack quality | new, unexamined |

**So the block work is real after all, but it is these two intent gates against a
wall that now has closing time to lose -- not the outcome bands, which stayed
measured and fine throughout.**

Left off in this commit because shipping five failures is worse than shipping
none. But the sequencing is now settled: land the three together, work the five,
and stop building single fixes against a gate that no single fix can pass.

---

## What the rally simulator work is for, and what is actually blocking it

Written after a long thread that diagnosed a great deal and shipped no simulation
behaviour, because the diagnosis kept going one layer deeper instead of naming
the shape of the problem.

**The goal:** outcomes should fall out of geometry and attributes rather than out
of a quality scalar compared against a threshold. The geometric attack, the
locomotion model, the shadow systems and the kinematics solver are all that same
move, and most of it is built.

**Five recurring defects, in the order they cost the most:**

1. **Values computed and then dropped before anything can use them.** Curator
   functions copy a dictionary field by field and silently lose whatever was
   added upstream -- `block_miss_reason`, `wall_size`, the approach deficit's
   terms, the block close's inputs, the shot type before it was downgraded. The
   cost is not the missing feature; it is that no question can be answered
   without first re-plumbing the answer.
2. **A value computed, the thing it described moved, and nobody re-read it.**
   `_reachable_contact` pulls a hitter's contact back and the arrival margin, the
   lane and the wall all keep describing the old one.
3. **Thresholds outside the range they cut, so branches never fire.**
   `OPPONENT_QUICK_CALL_PASS` is 0.68 against a pass distribution whose p90 is
   0.567; `_apply_identity_tempo` tests 0.66/0.34 against presets clustered on
   0.50. **This is the direct enemy of the goal** -- an attribute that only
   matters inside a branch that never runs cannot produce depth.
4. **Constants where a decision belongs.** `_fallback_hitter` only ever considers
   Outside Hitters, so the middle never attacks; `_fallback_assignment` always
   says tempo 3.
5. **Two implementations of one fact**, most of all the two sides of the net.

**The limiter, named:** *the model plays one rally over and over.* Home is 92%
high-ball swings, 82% to a single pin, with no quick and no pipe ever. The
opponent is 97% rolls. Attributes cannot create depth in a system that only runs
one play -- and worse, every constant in the engine was fitted against that one
play, which is why the wall collapses the moment a quick appears.

**The structural half:** the calibration gates enforce the degeneracy. The
attack-symmetry ratchet fails any change that moves the balance, so the only
changes that pass are the ones that do not matter. That is how a shelf of
correct, measured, disabled fixes accumulates, and this thread added four more to
it before noticing.

**What unblocks it:** fix the degeneracy before tuning anything else. Land the
offence variety, accept that every downstream constant is then mis-calibrated,
and re-fit them against a fixture that plays a real match. That is a bigger and
noisier change than this thread has been making, and the small safe changes
provably cannot land -- measured: three of them together clear the ratchet that
each of them fails alone.

---

## Tempo is now live, and the model prices it backwards

With the four offence flags on, the one remaining suite failure is the
Defensive-identity gate, and it is a real finding rather than a fixture problem.
Measured across six career seeds at 48 samples:

| identity | tempo shift | home attack error | home kill rate |
|---|---|---|---|
| Physical | -1 (quicker) | 0.1398 | **0.3239** |
| Fast Tempo | -1 (quicker) | 0.1478 | 0.3335 |
| Balanced | 0 | 0.1350 | 0.3443 |
| Defensive | +1 (slower) | 0.1406 | **0.3774** |

**Monotone in tempo shift.** Running quick costs the offence five points of kill
rate, so no bench would ever call one -- the opposite of the sport, and the
opposite of what the tempo work was for.

### The cause is an asymmetry nobody had noticed

The blocker's closing clock is `set_flight_time + preset_window * preset_share`
-- 26% to 72% of the pass-to-release window, scaled by how well they read it. The
hitter's clock is `set_flight_time` **alone**.

Both are reading the same pass and only one of them is paid for it. So shortening
the set squeezes the attacker and leaves the wall's head start untouched, and
tempo comes out priced the wrong way round. If anything the hitter should get the
*larger* share: they know the play and leave on the pass, while a blocker is
guessing until the set is up.

### And the fix for it is inert, which is the same defect again

`ENABLE_HITTER_PRESET_WINDOW` reads `preparation_time_seconds` -- a value the
approach model already computes and publishes -- and credits the hitter with it.
It changes nothing: the identity calibration returns byte-identical figures with
it on or off across roughly two thousand rallies.

`preparation_time_seconds` is produced in exactly one place,
`ApproachMechanics.prepare_approach`, and the dictionary the home first-ball path
reads from does not carry it. So the attempted fix for "a published value reaches
no consumer" is itself a published value reaching no consumer.

**Next, and it is one probe:** print the credit at the swing and find which
dictionary actually carries `preparation_time_seconds` on the home first-ball
path. Do not turn the flag on until it arrives non-zero.

### Still degenerate: the home side has two lanes

Home lanes read Front Quick 84, Right Pin 110, **Left Pin zero**. `_fallback_hitter`
picks the front-row Outside Hitter nearest a pin and gets the same one every
rally, so the second outside and the opposite never swing. Four tempos and two
lanes is not a finished offence, and this is the next degeneracy after the tempo
pricing.

### Correction, and a better reading of the tempo asymmetry

The previous entry said `ENABLE_HITTER_PRESET_WINDOW` was inert because the
home first-ball path's dictionary does not carry `preparation_time_seconds`.
**That was wrong.** The edit adding the call had not applied -- one level of
indentation off in the anchor -- so the function was defined and never called.
The identical figures were explained with a data story rather than one `grep`
for the call site, which would have answered it in a single command.

Wired properly the credit does arrive, and it makes the pricing **worse**:
Defensive moves 0.3774 to 0.3795 on kill rate while the other three identities
do not move at all.

That negative result is the useful part. `preparation_time_seconds` is
`set_contact_time - release_time`, so it is **not** a fixed pass-to-release
period the two sides share -- it grows with slower sets and collapses to zero on
quick ones, which is exactly why only the slow-setting identity responded.
Crediting the hitter with it widens the high ball's advantage instead of
narrowing it.

**So the asymmetry is not "the blocker is paid and the hitter is not".** It is
that the blocker's window arrives as a *constant* (`DEFAULT_SET_RELEASE_SECONDS +
DEFAULT_SECOND_CONTACT_SECONDS`, 1.10 s) while the hitter's shrinks to nothing
precisely when tempo is doing work. Fixing that means giving the hitter a release
that does not depend on the set's own flight -- they leave on the pass, and the
pass is the same pass whatever the setter then does with it. Different fix,
still open.

### Set distribution: partial, and the remaining gap is named

`_fallback_hitter` picked "the front-row outside hitter, nearest a pin", which is
deterministic in the rotation -- the same voli every rally, so the opposite never
swung and the offence had two lanes.

It now scores every front-row attacker on the swing they would take, plus a
deterministic per-rally spread (`SET_SPREAD_STEP`) so the ball does not always go
to the same best hitter.

| | before | after |
|---|---|---|
| home lanes | Front Quick 84, Right Pin 110, **Left Pin 0** | Front Quick 86, Left Pin 88 |
| home T1 share | 30% | 33% |

**Honest reading: this fixed the balance, not the variety.** The ball is now
shared between attackers instead of fed to one, which is real -- but the lane
count is still two, because scoring alone just moved the offence from one pin to
the other before the spread evened it out.

Two things are still missing and neither is a constant:

- **The lane is derived from where the hitter stands**, not chosen.
  `_fallback_assignment` reads `start_position.x <= 0.5`, so whichever attackers
  the scoring picks decide the lane as a side effect. A right-side attack has to
  be a *call*, not a consequence of a slot.
- **The spread is a placeholder and says so in the code.** The real term is a
  setter deciding against what the opponent anticipates.
  `OpponentTeam.anticipated_lane()` and `Familiarity` already track exactly that
  and are write-only against the home side -- half a scouting system that has
  never been read. Wiring it is the next step and it replaces the placeholder
  rather than tuning it.

---

## Tempo pricing: the channel is found, and one constant cannot fix it

The channel is **not** the arrival margin. `ENABLE_CLAMPED_ARRIVAL_MARGIN` already
floors that at zero, so crediting it changes almost nothing. It is the **contact
clamp**: `_reachable_contact`'s budget is `set_flight_time` alone, so a quicker
set clamps harder, the contact ends further off the net, and
`CLAMPED_CONTACT_SEVERITY` bills the swing for it. Quick sets were being charged
for being quick.

Crediting the release window into that budget confirms the diagnosis and
overshoots badly:

| `HITTER_PRESET_SHARE` | Physical (quick) | Defensive (slow) | ordering | mean kill |
|---|---|---|---|---|
| 0 (off) | 0.3239 | 0.3774 | **wrong** | 0.344 |
| 0.18 | 0.5409 | 0.5894 | **wrong** | 0.560 |
| 0.82 | 0.7731 | 0.7260 | **correct** | 0.746 |

**No value of this constant does both jobs.** The correct ordering only appears
once the credit is large enough to relieve the clamp almost everywhere, and by
then home kill rate has gone from 0.344 to 0.746. At a share small enough to keep
the aggregate anywhere near its calibrated value, the ordering is still inverted.

### What that actually tells us

The contact clamp is doing enormous work in the current model. A home kill rate
of 0.344 is substantially produced by hitters being dragged off the net rather
than by anything about the swing, the block or the defence -- which is worth
knowing independently of tempo.

And the fix is not a bigger budget for everyone. **A quick hitter is not
travelling during the set at all**: they leave on the pass and are standing at
the net when the setter touches it, which is precisely why a first-tempo ball
beats a block. Modelling that as "more time to travel" relieves every hitter's
clamp uniformly and inflates the whole offence; modelling it as "a first-tempo
hitter starts at their contact point" costs the aggregate nothing and prices
tempo correctly by construction.

**Next: make the approach start tempo-dependent**, so a T0/T1 hitter's
`hitter_move_time` is near zero because they are already there, and a T3 hitter
still has to run. That is a change to `_approach_start_position` and the
preparation staging, not to any constant, and it should leave slow-ball kill
rates where they are.

`ENABLE_HITTER_PRESET_WINDOW` is left off with both call sites wired, so the next
attempt starts from a measured baseline rather than re-deriving the channel.

### The run-up now points at the net

Reported from playback rather than found in a probe: a tempo-2 outside ran
*parallel* to the tape and arrived sideways.

`approach_start_position` computes a lane angle -- 8 degrees at the middle, 30 at
the pin -- and then blends the start toward wherever the hitter is standing, so a
voli out of position gets a mark barely ahead of the contact and mostly beside
it. **The angle it solved for was discarded.** The runway had the right distance
and the wrong direction, and nothing checked the result.

`ENABLE_PERPENDICULAR_APPROACH` checks it. The lateral leg is not negotiable --
they do have to reach the pin -- so the depth gives instead: the runway lengthens
until the run is inside `MAX_APPROACH_ANGLE_DEGREES` (42, past which an approach
stops being an approach and becomes a shuffle along the tape). Destination and
shape both survive, and it costs the hitter time, which is the honest price of
being out of position.

Suite unchanged at 870 checks / 1 failing with it on. **Not visually confirmed** --
the geometry is checked and the regression suite is clean, but nobody has watched
a tempo-2 outside since. Worth one playback pass.

## The bodies are the weakest thing on the tactic sheet

The sheet is now good enough that the figures on it are the problem. What is
there is the match rig -- `PlayerActor3D` -- posed, rendered unshaded, traced
into a silhouette, quantised to a printed palette, and drawn with a die-cut
border and a separate crease round the arms.

That buys a lot for free: real height and wingspan, body type, handedness, the
club's kit colour, and a pose that comes from the same biomechanics the match
plays. It also inherits what the rig is: capsules and spheres, built to read at
court distance in three dimensions. At a hundred pixels on paper it reads as a
toy.

**What the sticker pipeline should keep**, because it is the part that works:

- Size and ground offset measured off the bake in metres, so nothing downstream
  picks a size.
- The bake camera driven by the view's own angles, and the body's heading applied
  *after* `set_pose` -- the rig turns to face the ball, which is right on a court
  and wrong in a drawing.
- Flat unshaded colour, saturation capped, quantised. Lit and posterised was mud.
- Silhouette trace plus a separate arm trace, so a pose survives the arms
  crossing the torso.

**What has to change** is the rig's own geometry for this use, and the honest
options are three:

1. **A second, drawn rig** for stickers only -- shapes authored to read small,
   sharing the skeleton and the pose solver so the biomechanics stay one thing.
2. **Better meshes on the one rig**, which improves the match view too and is the
   larger job.
3. **Give up on tracing** and draw the figures as 2D from the pose data -- keeps
   handedness and proportion, loses the free 3D consistency.

Not chosen. See `docs/design/TACTICS_AND_TRAINING.md` §0.13 for the rest of the
sheet's known weaknesses, and the receive-posture occlusion problem in particular
-- a passer's platform is invisible from behind, and every camera stands behind
them.

## Scouting produces coordinates, and the planner now has a door for them

`place_voli_at(slot, metres, who)` exists and the drag is a wrapper over it.
Nothing produces the coordinates yet. What should:

- Where the block got beaten, as points on the tape with the lane past each.
- The worst seams on the floor, as a gap between coverage zones.
- Where attacks were stuffed against where they were touched -- two distributions
  over one net, and the difference between them is most of what "adjust the
  swing" means.

Design in `docs/design/TACTICS_AND_TRAINING.md` §0.12.

## A jumping sticker's height is a constant, and it should be that voli's jump

`UIWorksheet` bakes airborne poses at `BLOCK_ELEVATION = 0.85` and
`ATTACK_ELEVATION = 1.00`. Both are constants, and they are applied to every
voli on the sheet -- so a 201 cm middle with a 3.42 m jumping reach and a 178 cm
libero with 3.10 m leave the floor by exactly the same amount, and the drawing
says they jump the same.

That is this repository's recurring defect in its plainest form: a quantity the
model already owns, restated as a number in the drawing. Every profile the sheet
holds carries `standing_reach_meters` and `jumping_reach_meters`, and the
difference between them **is** the jump. The elevation should be derived from
that pair, and where the pose needs a ceiling -- a block is not a maximal jump,
it is a controlled one off two feet from a standing start -- the ceiling should
be a share of that voli's own capacity rather than a flat metre.

Two things fall out and both are wanted:

- A tall middle is drawn reaching over the tape and a short libero is not, in a
  picture whose entire premise is that a metre means a metre.
- The block page stops being a picture of two identical jumps. Who can get over
  the net from a standing block is a real tactical fact and the sheet currently
  hides it.

Deliberately **not built yet**: it changes what every sticker looks like, and the
body models are being overhauled first. Recorded so it is not re-derived.

## Does a voli fall over? Centre of mass, and balance as the thing that resists

Raised while fixing the passing platform, and worth a real answer rather than a
constant.

A passer extending their arms further forward has to put their hips further back
and bend their knees more, or they fall. That is not a drawing rule -- it is
where the centre of mass is relative to the base of support, and it is the same
quantity that decides whether a defender who lunges recovers or ends up on the
floor. The rig already has every input: segment positions from the pose solver,
segment masses implied by the body type, and foot positions from the gait.

The design question is whether it is worth **computing** rather than asserting:

- **For the drawing**, a centre-of-mass check would stop poses being authored
  that no body could hold -- which is exactly the mistake the platform had, arms
  out in front of an almost upright trunk.
- **For the model**, "did they keep their feet" is already a thing the rally
  cares about: a defender who goes down cannot play the next ball, and recovery
  time after a reaching dig is a real cost the simulator approximates today with
  posture bands rather than physics.
- **For the attributes**, balance is the obvious resistor -- a higher balance
  voli tolerates a centre of mass further outside their base before it becomes a
  fall, and that is a claim the suite could actually test.

Against: it is a physical model in a game that has deliberately kept its physics
to ball flight and locomotion, and "posture bands the resolver already decides"
may be the right grain. Not decided. If it is built, it belongs next to
`LocomotionModel` rather than in the actor, because the actor draws conclusions
and does not reach them.

## A reaching dig is a lunge, and the rig can only make both legs do one thing

The four dig postures are drawn from one leg model: a thigh angle, twice that at
the knee, and a hip roll, applied to both legs identically apart from a fore-aft
stride offset. That is enough for planted, moving and off-axis. It is not enough
for **reaching**, which in this sport means a lunge -- one leg folded under the
body, the other nearly straight and thrown out to the side, the whole base
asymmetric and the weight over the folded one.

The constraint is measurable rather than aesthetic. A folded leg cannot splay
far, because only the part of the shank still pointing downward travels sideways
when the hip rolls out. At the 0.34 m crouch a reaching dig now takes, the hip
abduction limit caps the base at about 0.78 m -- and that is the *widest of the
four*, so it reads as a deep squat rather than as a player at the edge of their
range. Asking for more silently gets less, which is why the number in the code is
0.78 and not the 0.92 the pose wants.

What it needs is per-leg parameters: a `crouch_metres` and a `stance_metres` for
each side rather than one pair for both, with the grounding solve run against the
lower foot as it already is. That is a contained change to `_pose_dig_legs` and
its two solvers. It is held because the whole body model is being overhauled
first, and a lunge is exactly the pose whose legibility depends on the knee and
hip geometry that overhaul will replace.

Adjacent and cheaper: the platform still finishes **0.30 m above the hip joint**
at contact, rising to 0.45 through the drive. A real passing platform is at or
below the waist with the hands nearer the knees. The forearm pitch is a single
`lead` angle authored in degrees, and it should be solved from a target platform
height in metres the same way the stance and the crouch now are -- the same fix,
one joint further up.

## The roster page does not fit 720, and minimums cannot be capped

Measured with `tools/preview/layout_probe.tscn`, the journal's Roster tab needed
**812 px of minimum height in a 720 px window**. A `MarginContainer` that cannot
fit is not clipped and does not warn -- it is placed at a negative offset, so the
page grew out through the top *and* bottom edges at once and took the ribbon off
the screen with it. Nothing is logged. Nothing inside the tree looks wrong.

Two controls were most of it and are trimmed: the roster visualizer's viewport
(214 to 140) and the attribute wheel (186 to 152). That is 758, and it still
does not fit.

The remaining 38 px cannot be tuned away honestly:

| | px | can it give? |
|---|---|---|
| chrome: ribbon, nav strip, card margins, tab bar | 243 | not looked at yet |
| attribute table | 251 | no -- eight rows is the longest category, so fewer hides attributes |
| profile row: visualizer, wheel, identity | 228 | only by making both too small to read |

**A minimum size is a floor and there is no ceiling**, which is the whole problem:
no container above can recover the space, so every fix is either "make the
content smaller" or "let it scroll". Tuning the content to fit exactly one window
size is this repository's named defect wearing a layout hat -- it works at
1280x720 and breaks the moment anything is added or the window is smaller.

The structural fix is a scroll guarantee: the Roster tab's `RosterPlayer` goes
inside a `ScrollContainer`, whose vertical minimum is not its child's, so the
page can never exceed the window and the overflow scrolls inside the card. Held
because it is scene surgery -- the subtree has dozens of node paths to re-point,
and `%` unique names make it safe but not quick. The chrome is worth measuring
first: 243 px of fixed furniture around a 515 px page is a lot, and taking it
back costs no content at all.

## The cold start styles every screen in the game before the title screen answers

Measured in `Application._ready()`:

| | ms |
|---|---|
| building every screen | 25 |
| `_load_theme` -> `UIStyleSystem.apply` over the whole app | **1073** |
| total | 1219 |

`application.tscn` holds every screen, and the style pass walks the entire tree
once at boot -- every control of the journal, the match centre, the clipboard,
the folders and the planner, each getting its overrides stripped, a variation
assigned, an ink outline or printed rule added as a child and a halftone material
built. All of it synchronous, all of it before the first frame the player can
click, and all but the title screen's share of it for screens nobody has opened.

On a machine where the renderer is also compiling pipelines for the first time
this lands on top of that, which is how a second of styling reads as a game that
has hung.

The fix is to style a screen the first time it is shown rather than all of them
at boot: `_swap_to` already runs on every screen change and already calls
`UIStyleSystem.reveal`, so it is the natural place to call `apply` on a screen
carrying no "styled" mark yet. `_apply_theme` still has to walk everything,
because a theme switch changes screens the player is not looking at -- but that
is a deliberate act with a visible cause, not a cold start.

Held because it moves *when* styling happens, and the pass is not idempotent in
an obvious way -- it adds child nodes and strips overrides, and `_printed_rule`
already has a "did I add this already" branch that suggests the others may not.
Worth an afternoon and a careful read, not a quick change.

## Removing finesse and shot variety collapses role specialisation

Attempted and reverted. The change itself is small -- `finesse` becomes the mean
of composure and improvisation, `shot_variety` becomes `decision_making`, both as
derived read-only properties so the dozen resolver call sites that read them by
name keep working -- and it takes Attacking from eight attributes to six, which
is the row that makes the roster page too tall.

What it also does, measured on five seeded Landavol rosters:

| | before | after | test wants |
|---|---|---|---|
| setter `set_accuracy` minus libero's | **32.8** | **7.7** | > 10 |
| libero `reception` minus libero `set_accuracy` | **28.2** | **9.8** | > 10 |
| libero `set_accuracy` | 50.6 | **65.0** | -- |
| setter `set_accuracy` | 83.4 | 72.7 | -- |

Roles are still assigned in the right proportions -- Setter 10, Outside Hitter
15, Middle Blocker 15, Opposite 5, Libero 5, unchanged. What collapses is
*specialisation*: everyone converges toward the middle, and a libero gains
fourteen points of setting accuracy they have no business having. This is not
seed drift. Two near-miss thresholds looked like drift, and measuring the
baseline is the only reason that reading did not survive.

The mechanism is not yet found. Generation scores each attribute in three tiers
-- `POSITION_WEIGHTS` primary, `ROLE_SECONDARY` secondary, everything else in
`ABILITY_ATTRIBUTES` tertiary at -8 -- and `set_accuracy` is tertiary for a
libero both before and after. Neither of the two obvious candidates explains it:
deleting the pair from two role lists, and substituting the replacements into
them, both produce the same collapse.

Worth suspecting next: that the tertiary tier is derived from `ABILITY_ATTRIBUTES`
by subtraction, so shortening that list changes the size of the tertiary set and
therefore whatever is normalised across it. Start by printing the three tiers for
a libero before and after, which is one probe and settles it.

Held rather than shipped. The roster page can find its 38 px elsewhere -- the
243 px of chrome above it is the better target and costs no content at all.

## Next, in the manager's own words

Written down because it was said in passing and passing is where plans go to be
forgotten. Not a design, a direction -- each of these wants its own reading of
what exists before anything is built.

1. **The rally simulator.** The thread that was running before the tactic sheet
   and the body models pulled attention sideways. Tasks #62 to #64 and #66 to #68
   are all pieces of it and are still open.
2. **The 2D match centre.** Playback today is the 3D court; what the match centre
   shows around it has not been looked at since the screens were renamed.
3. **The tactical planner.** The clipboard's worksheet took a projection refactor
   and a set of selectable zones this pass, but the *planner* -- the daily
   schedule at `scenes/screens/schedule_screen.gd` -- has not moved, and #69
   ("build the day: hours, the training appointment, and the live drill session")
   is the shape of what it needs.

Held from this pass and still true: the body-model overhaul is first on the
tactic sheet's own list, and nothing on the sheet is persisted.

## Body models: rods are gone, the shoulder join is not

First pass of the overhaul, against the complaint that a voli reads as "a pumpkin
with four vertical rods".

The rods were literal. `PlayerActor3D._build_body` set `arm_spec["shape"] =
"cylinder"` and the same for legs, overwriting whatever the body type authored --
and a `CylinderMesh` ends in a flat disc. Limbs are now a lathed shape,
`BodyTypeModels._limb_mesh`: tapered along its length with a hemisphere at each
end, built by hand because Godot has no tapered capsule (`CapsuleMesh` has one
radius, `CylinderMesh` has two radii and no caps). Joint balls sized from the
body type's own limb radii close the wedge a bent elbow or knee opens.

**Still assembled at the shoulder.** The arms hang outside the torso silhouette
with daylight between the shoulder ball and the body, which is now the loudest
remaining tell. `shoulder_offset.x` is authored per body type against the old
cylinder arms; a Vegi is a sphere and its arms want to start *inside* that sphere,
while Cani and Ursi have shoulders to hang from. Fixing it well means deriving
the offset from the torso profile at shoulder height -- `_torso_radius_at` already
exists and already does this for the collar.

Also unaddressed, in rough order of how much they cost:

- The torso is one capsule or sphere. A chest that narrows to a waist would do
  more for the silhouette than anything below the shoulder.
- Hands and feet are a shoe box and nothing. A hand at the end of a passing
  platform is the whole shape of a pass.
- The neck is a cylinder between two spheres.

Judge these on `bodies3d`-style renders -- the rig lit and large -- not on sticker
bakes. The bake posterises to twelve steps at about a hundred pixels, which is
precisely where the difference between a rod and a limb disappears.

## Drawn, not modelled: the inverted hull, and what it makes redundant

Drafted and rendered, not chosen. `tools/preview/outline_drafts.tscn` puts four
of them side by side.

Every mesh gets a twin, grown outward a fixed distance, painted flat and rendered
inside-out so only its far side shows. What is left is a band around the
silhouette of *that part*, so the line follows each limb and an arm crossing the
torso keeps its own edge instead of dissolving into it -- which is exactly what
the sticker trace does in 2D, obtained in 3D for nothing. `grow_amount` is in
metres, so the line is constant in world space: a voli at the back of the court
carries the same weight of line as one at the net.

The drafts: 0.008 m reads as a drawn figure that is still a body; 0.018 m is the
sticker look in three dimensions, and the joints stop being beads and start being
articulation; lighting under a hard line brings back the posterised mud that flat
shading was introduced to kill, one layer up.

**What it costs:** about forty lines and no shader. **What it makes redundant:**
most of the geometry work queued above. A torso that narrows to a waist, better
hands, a real neck -- all of it is detail *under* a heavy line, and a heavy line
is what carries legibility. The shoulder join still matters, because a line
around a floating arm is still a line around a floating arm.

Found by drafting it: the lathed limb was wound **inside-out**. Flat unshaded fill
hid it completely and the outline did not -- the ink twin showed its near face and
filled each limb solid black instead of drawing a rim. Normals face out now, which
lighting wanted anyway and nothing had checked. A rendering technique that fails
loudly on bad geometry is worth something on its own.

## The hip block is a ledge, and the type dial may not reach its own range

Drafted in `tools/preview/body_type_drafts.tscn`: Feli, Avi and Cani in the
receive pose, top row as built and bottom row with the hip hidden and
`type_expression` at 0.92 instead of 0.45.

**The hip is worth fixing and is small.** It is a box wider than the torso sitting
at the waist, and under a heavy line it earns an outline of its own -- which is
what turns shorts into a shelf. All three read better without it. Either size it
inside the torso profile at that height (`_torso_radius_at` already does this for
the collar) or drop the mesh and let the kit colour carry it.

**Corrected: the first version of this draft changed two things at once.** It hid
the shorts *and* turned the dial up, so the legs meeting the body differently and
an Avi's arms sitting differently were read as effects of the hip when they were
effects of `type_expression` -- which moves `hip_x`, `hip_y`, `shoulder_x`,
`shoulder_y` and both limb lengths. The tool now changes one thing a row.

Three separate things live at the waist and the first draft ran them together:
the **shorts**, a box wider than the torso; the **hip joint balls**, spheres at
each leg root; and the leg **angles**, which come from the pose and from `hip_x`
and are not a mesh at all. Keeping the angles while losing the shelf needs no new
work -- it is what hiding the shorts already does.

The joint balls are worth keeping. Without them the thighs read as hanging from
the body rather than springing off it, and the hip is the only joint that would
be missing one while the knee, elbow and shoulder all have theirs.

**Ears, crests and beaks were never missing an outline** -- the ink walks every
mesh. What they lacked was emphasis, and they now carry a heavier line than the
body: 0.030 m against 0.018. A crown is the smallest thing on a figure and carries
the whole identity of its type, which makes it the one place a thicker line buys
legibility rather than weight.

**The exaggeration is a real mechanism and an unproven one.** Every body type is
authored as a complete skeleton and then pulled toward `UNIVERSAL_RATIOS` by
`type_expression`, whose own comment says 1.0 is the type exactly as authored and
0.0 is three identical figures. So turning it up invents nothing.

But 0.45 to 0.92 is more than double the type's share and the bottom row barely
moves -- a couple of centimetres of torso and nothing anyone would name. That is
the shape of a knob that cannot reach its stated range: if the authored skeletons
already sit near the universal ratios, there is nothing for the dial to travel.

**Measure before turning it.** Print each type's authored proportions against
`UNIVERSAL_RATIOS` and see how far apart they actually are. If they are close, the
fix is bolder authoring and not a bigger multiplier -- and raising the dial would
be a change that looks like it did something and did not, which is this
repository's oldest defect and one it has hit twice in this session already.

## The ink is on, and now two outlines are drawn over each other

The rig carries its own line: an inverted hull on every mesh, 0.018 m for the
body and 0.030 m for ears, crests and beaks. In metres rather than pixels, so a
voli at the endline carries the same pen as one at the net. It runs everywhere the
rig does -- the match court, the roster view and the sticker bake -- so the sheet
and the live view finally agree about what a voli looks like.

The shorts are the torso's own bottom section now, sized from its profile at the
height they sit at and covering 34 percent of its height, rather than a box wider
than the body. That was the shelf.

**What is left, and it is a real question rather than a polish item.** At about a
hundred pixels the drawn line arrives dark, slightly broken and dithered rather
than as a clean stroke. Two things are fighting for those pixels:

1. `_shade` quantises to twelve colour steps, so a thin dark band lands between
   steps and speckles.
2. The sticker already draws a **die-cut border** of its own, plus a lighter arm
   crease. That was invented precisely because the geometry had no line. It now
   has one, and drawing both means two outlines over each other at slightly
   different offsets -- which is most of what the noise is.

The likely answer is to drop the die cut and let the geometry carry the edge, at
which point the arm crease also becomes redundant because each arm's hull already
separates it from the torso. Cheaper alternative: keep the die cut and thicken the
ink for the bake only, which is one constant. Render both before choosing --
guessing between two plausible causes is what this session has repeatedly had to
undo.

## Die cut versus thicker ink: settled, the cut stays and gains a keyline

**Decided: the die cut, plus a thinner dark line around it.** What follows is the
comparison it was decided from; the sheet now draws the cut as stock with a
keyline and keeps the rig's ink at 0.018.

Two things changed with the decision, and neither is the border's width:

1. **The cut is the stock, not the ink.** It was drawn in `_ink()`, which flips
   with the theme -- pale on Mikasa, graphite on Molten -- so the same border read
   as a die cut on one sheet and as a heavy outline on the other. Vinyl does not
   change colour when you put it on a darker page. It is one warm off-white in
   both now, which is what leaves the shape reading as an object lying on the
   sheet.
2. **The cut goes under the body, not over it.** A polyline is centred on its
   path, so a border drawn on the contour put half its width *inside* the
   silhouette and ate the art -- worse the thicker the sticker. Laid down before
   the texture and painted over, only the outer half survives, which is where a
   margin belongs.

The keyline is the third stroke and the one that was asked for: drawn in the same
place as the cut but wider, so what survives after the stock goes on is a thin
dark ring outside the margin. It is also what makes a white margin work on a cream
page, where it has nothing to push against -- rendered in both themes before
committing, which is the check the first pass of this comparison did not have.

## The comparison it was decided from

Both candidates are switchable -- `Worksheet.draw_die_cut` and
`PlayerActor3D.ink_metres` / `crown_ink_metres` are static vars rather than
constants -- so this is a toggle rather than an edit.

Rendered as a strip: `tools/preview/sheet_strip.gd -- diecut` stands the
worksheet up on its own, draws it three ways in **both themes**, and writes the
full sheets (`diecut_<theme>_strip.png`) and the blockers cropped and four times
up (`diecut_<theme>_zoom.png`). Roughly a minute per theme, against five for one
frame through the training screen -- which was the point.

What the three show, on the dark theme:

- **Cut on, ink 0.018** -- the current sheet. The white cut border separates a
  voli from the court hardest of the three, and where two volis overlap it also
  cuts one out of the other, which is exactly what a sticker does. It is also
  the only one where the arms merge into the silhouette: the cut traces the
  outside of the shape, so an arm crossing a torso disappears into it and gets
  the lighter crease line back to compensate.
- **Cut off, ink 0.034** -- softest. The parts separate, the two blockers read as
  two people, but at sheet size the line is thin enough that the bodies go a
  little blobby.
- **Cut off, ink 0.048** -- the most legible of the three at the size the sheet
  actually draws. Every part carries its own edge, the crown reads, and no
  compensating crease is needed.

The dark ground flatters the cut, and that turned out to be the deciding
observation rather than a caveat: the white margin is a legibility win against a
dark court that no ink line can match, and it is the one treatment that survives
the theme switch once it stops being drawn in ink.

Two things learned in the earlier attempt, both still true:

- **The ink doubles the mesh count in every bake.** Each sticker's viewport now
  draws the body twice, and the tactic sheet bakes a sticker per voli per phase
  per view. That is the real cost of the technique and it lands on the slowest
  path in the game.
- **`Invalid polygon data, triangulation failed` appears in *both* candidates** --
  six times in A. It is the sticker shadow polygon meeting a degenerate contour
  and it predates the ink, so it is not evidence against the thicker line. Worth
  chasing separately: a contour that cannot be triangulated is a sticker whose
  shadow silently does not draw.

## Blockers faced the wrong way: fixed, and one yaw still serves every phase

**Fixed.** `_bake_angles` turned every baked body by `facing - theta`, which is
the right relative angle measured against the wrong zero. The bake camera stands
on +z and looks along -z, and the rig's own forward at yaw 0 is also -z -- so yaw
0 is already a back and yaw 180 is already a face. Reading it the other way put
every voli on the sheet chest-on to a reader standing behind them: 142 degrees at
three quarter, which is a blocker facing their own setter.

It is `facing - theta + 180` now, and the half turn has a name
(`CAMERA_LOOKS_BACK`) rather than being folded into the arithmetic.

Measured, not argued, because two plausible causes were on the table -- the sign,
or `set_pose`'s own `_turn_toward` -- and this repository's recurring defect is
picking between them by reasoning. `tools/preview/sheet_strip.gd -- turntable`
bakes one blocker the whole way round in 45 degree steps in two poses. The
passing platform, which can only be in front of a body, appears at yaw 180 and is
hidden at yaw 0. That settles which end is which in one image, and it also
cleared `_turn_toward`: the baker overwrites the pose's own rotation afterwards,
so it never reached the sheet.

Held by a test rather than by the render. `_test_worksheet_facing` ties the bake
to `_project` -- the function that draws the court -- by projecting a heading
vector and checking the bake's yaw against where that heading points on the page,
in both the screen-right and the toward-the-reader component, for every view and
five headings. Set `CAMERA_LOOKS_BACK` back to zero and 26 of its 30 checks fail;
the four that survive are the headings where one component is zero in that view,
which is why it takes both.

**Still open, and it is the other half of the heading:** every call site takes the
default facing, so attack, block and floor are all baked at 180 degrees, "looking
over the net". Correct for a blocker and a passer. An attacker on the sheet is
drawn at the cock of a swing and is still square to the net, when a hitter
arriving on an outside approach is angled across it. That wants the facing to come
off the drill's own geometry rather than a constant -- the parameter is already
there and has never been passed.

## The startup stall: the clipboard was built before the title screen

**Fixed.** Opening the game was unresponsive for tens of seconds and then came
right on its own, with every click made during the freeze arriving at once when
it ended. That last detail is the diagnosis: a renderer that cannot keep up drops
frames, it does not queue your clicks and hand them back later. The main thread
was blocked.

`application.gd` built all three code-made screens in `_ready` -- the clipboard,
the folders and the planner -- before the title screen had drawn a frame. The
clipboard is the expensive one: it stands up a worksheet, and the worksheet asks
for every figure it can draw. Seven volis, a headshot each plus three phases in
two views: forty-nine stickers, each one a posed 3D render, two texture readbacks
and a contour trace.

That is a real cost and it is the right cost for a page of drawn bodies. It is
just not a cost the *title screen* should pay, and it was paying all of it.

The three are built on first navigation now. Two things had to move with them:
the wipe has to be pushed back to last child after each add, since later siblings
draw over earlier ones and a screen added after the wipe would cover the sheet
meant to cover it; and the style pass is a tree walk that happens once, so a
screen built after it has to be given the same pass on the way in or it arrives
with no backdrop -- invisible in the dark theme.

**Measured on both sides**, with `tools/preview/startup_probe.gd`, which traces
frame times off a cold boot and names anything over four frames' worth. It runs
the real main scene rather than a stand-in, because the stall is in what the
application builds.

| | before | after |
|---|---|---|
| longest frame | 232 s | 1.8 s |
| time to settle | 243 s | 2.9 s |
| frames in the first 30 s | 137 | 869 |

Those are llvmpipe numbers under `xvfb` and are perhaps an order of magnitude
worse than real hardware, which is why the table is a ratio to read rather than a
duration to quote. The shape is the finding: one frame carrying a boot's entire
sticker bake.

Worth knowing that the probe also reports headless. Headless has always settled
in under three seconds -- the stall never appeared without a renderer attached,
which is what pointed at the bake in the first place.

**What is left on this path**, in order of what is left to gain:

- Roughly a second to load `application.tscn` and 1.8 s in the first frame, which
  is the whole scene entering the tree and drawing once. Not investigated.
- The clipboard's own first open still pays the forty-nine bakes. Moving the
  freeze off the title screen is worth doing on its own, but the bake wants
  either spreading over frames with the page usable in the meantime, or caching
  to disk.
- The journal's roster visualizer viewport reads **2x140** for the whole trace.
  It may simply be a container that has never been laid out, since the journal is
  not the visible screen during the probe -- but a 3D view two pixels wide is
  worth a look with the journal actually up.

## The clipboard ran off the bottom, and what is holding it there now

**Fixed, with 10 px to spare, which is not much.**

Measured with `layout_probe -- clipboard`, which now weighs the training screen
as well as the journal's roster. The tactics page needed **610 px where 560 px
was going** -- fifty over, and that is the clipping.

Three changes, in order of what they were worth:

| | saved |
|---|---|
| the fit strip row deleted, its one live line moved onto the tab strip | ~40 px |
| the two receipts (what the sheet says, what was declared) put on one row | 30 px |
| the page's one instruction moved onto the tab strip too | 30 px |

The tab strip is the trick in two of those. A `TabContainer` draws its own strip
and has no slot to put anything beside it, and a plain child of one *becomes a
tab* -- so the strip cannot simply be given a second occupant. Hosting the tabs
in a plain `Control` and anchoring a row to its top right puts text in the empty
part of the strip the two titles never reach, at no height at all.

Two placeholders died on the way. The rotation selector filtered a strip whose
figures were invented, and "4 asks, 1 unfamiliar" was the figure it filtered. A
control that cannot change anything is worse than no control, because it reads as
working.

**The floor is now the tools column and nothing else**: sticky note 203, the
coordinate entry 42, roster tray 210, plus separations -- 471 px of the page's
501. All three are `custom_minimum_size` floors stated inside their components,
not heights derived from what they hold, so nothing gives when the window is
short. At 720 px that leaves 10 px of headroom, which a different font or a
higher DPI would eat.

Worth doing properly rather than trimming again: the tray lays its slots out from
its own width already (`MIN_SLOT`, a grid solved from `size.x`), so it is the one
of the three that could take a height instead of demanding one. The other two
want looking at with a manager actually using them.

## Two long-standing suite failures, measured

Both predate this work and neither is a regression. Recorded here because "two
expected failures" has been carried in `CLAUDE.md` for a long time without
saying what they *are*.

**1. `Allotted duration and the movement model agree for every phase type`.**
The simulator allots each contact a duration; the movement model derives one from
stride and cadence. The test wants their ratio inside a band, per phase. Measured
over the same 120-seed sweep the test runs:

| phase | mean ratio | band | |
|---|---|---|---|
| RECEPTION | 0.9987 | 0.95 – 1.06 | ok |
| SET | 0.9927 | 0.92 – 1.06 | ok |
| ATTACK | **0.9129** | 0.95 – 1.12 | out |
| DEFENSE | 0.9983 | 0.95 – 1.06 | ok |

ATTACK is the only phase that enters its traversal already carrying speed, and it
is the only one out. The interesting part is the *direction*: the band is
asymmetric because the residual used to sit at **1.09** -- the stepped integrator
reporting a traversal 9% longer than the closed form solved for. It now sits at
0.91, the same 9% on the other side. Something flipped the sign of that residual
and the band, drawn around where it used to be, no longer contains it. The
overall `perceptible_rate` fails with it at 0.0603 against a 0.04 ceiling, which
is the same finding counted differently.

**2. `defensive attack lowers both error risk and terminal pressure across six
career seeds`.** Two claims, and only one holds. Measured at 48 samples:

| identity | attack error | kill rate |
|---|---|---|
| Physical | 0.1470 | 0.6251 |
| Defensive | **0.1243** | **0.6638** |

A defensive identity does lower the error risk, by a lot. It does not give up
terminal pressure for it -- it *gains* kills. So the trade the design claims is
not being paid: defensive attacking is currently strictly better at both ends,
which is a balance finding rather than a test that needs its band widened.

## Five roster and marking fixes, and what each one actually was

**The page resized when you paged the attributes.** `_fill_attribute_column`
hid the rows a group had no attribute for, and the six groups are not the same
length -- so a five-attribute page stood three rows shorter than an
eight-attribute one and everything under the table moved. The arrows are at the
top of the block, so the page jumped under the pointer that had just moved it.
Rows are blanked to zero alpha now instead of hidden: eight rows on every page,
because every column always has eight rows.

**The highlighter un-drew itself.** One `move_toward` ran the tip back to its
start, so leaving a control played the stroke backwards. Symmetrical, which is
why it read as reasonable in the code and wrong on the screen -- nobody
un-highlights. The tip stays where it stopped and the ink goes instead, over
0.09 s, which is quicker than the sweep that laid it down: putting a mark on the
page is a gesture with a hand's pace in it and taking it away is not a gesture at
all. The 30% chance of a right-to-left stroke went with it, for the same reason
the underline never had one.

**The expand button had a line through it**, and it is not a rendering fault:
`⤢` is two arrowheads *joined by a diagonal*, which is what the glyph is. `↗↙`
is the same idea without the join, and both halves are basic arrows that no font
here has to substitute for.

**The rating marker was set in body ink**, which made the largest thing on the
page the one that told you least -- an S and a D are the same mark until you have
read them. It takes its band's own colour now, from the table every other grade
in the interface already uses: gold, green, blue, white, red. Painted from
`grade_tier` rather than `grade`, because the table has five bands and the letter
has nine: B+ and B- are both the colour of B, which is what a tier is for.

**The name lists are wide-ruled paper.** New `UIRuledPaper`, applied to the
transfer list and the scouting list. Wide ruled and not college ruled -- 34 px
against 28 -- because the wider pitch is what reads as a pad rather than a dense
table. The rules are printed, not drawn: they barely wander, and the wander they
do have belongs to the sheet rather than to a hand, which is what leaves the
writing reading as added afterwards.

Two Godot details worth keeping. `ItemList.fixed_item_height` no longer exists in
4.7; row pitch is bought with content margins on the item styleboxes. And the
paper attaches as a *child* of the list with `show_behind_parent`, the way
`UIInkOutline` already attaches to a control -- the first cut made it a sibling
and put a third child inside an `HSplitContainer`, which takes exactly two.

**Still open on this page:** the scouting screen's rows are pitched to the paper
but the sheet does not scroll with them, which is right for a pad and wrong the
moment the list is longer than the panel -- the rules stay put while the names
move past them. Fine at the lengths it currently holds; wants the paper inside
the scrolled content once there are more prospects than fit.

## The pepper cage, the coat, and the id that made every voli the same voli

**Pepper.** The lobes were built on the Stalk's rib mechanism -- thin vertical
capsules laid on the surface of a sphere, in the *crown* colour. Five green rods
standing off a red ball is not a pepper with ridges; it is a ball in a cage, and
it read as one from every angle.

A pepper's lobes are not ridges on a shape, they are the shape. Four fat bulges
packed round the axis, skin-coloured, set close enough that adjacent ones overlap
-- centres 0.219 apart with radii of 0.225 -- so the union is continuous and the
grooves are where two bulges meet. From above that is a clover, which is what a
pepper's cross-section is. The core sphere shrank from 0.335 to 0.275 because it
is no longer the shape: it is what the kit, the shorts and the arms are measured
off, and the lobes are what anybody sees.

Took two passes, and the first one is worth keeping written down. At height 0.76
with a 1.12 radial stretch the lobes were tall ellipsoids whose bottoms converged
below the core, so the silhouette came to a point and read as a **bat**. The cage
was gone and something else had taken its place. A pepper is widest at the
shoulder and blunt underneath: wider across, shorter, no radial stretch at all.

**Coats.** New `MARKINGS`, seeded from its own hash string like `produce_for` and
`palette_for` have theirs -- so shape, colour and coat do not correlate. Six
kinds: `tabby`, `spots`, `blaze`, `patch`, `speckle`, `scar`, each on a weighted
list per body type with `none` the commonest entry everywhere. A marking every
voli has is a species trait; the unmarked ones are what make a marked one worth
noticing.

Every mark is a flattened sphere turned to face outward and squashed along the
radius so it hugs the body, placed by `_mark_on_torso` from the torso's own
profile rather than at a fixed radius. That is the pepper cage's mistake and it
was not worth making twice.

**And the reason none of it would have shown.** `voli_sticker._bake` called
`_actor.configure(1, ...)` -- the literal id 1. Everything that makes one voli
look unlike another of the same species is seeded from the player id, so every
sticker resolved the same produce, the same colourway and the same coat. **A
tactic sheet of seven volis was seven copies of one voli at different heights.**
The differentiators were already there and none of them could reach the page. The
id comes off the profile now, and the callers put it there.

## What the body sheet showed that was not asked about

`sheet_strip -- bodies` bakes every produce, every animal and one voli per coat
as the stickers the game actually draws. Two things it made obvious:

- **Marks on a clothed body land on the singlet.** The animals wear a full kit
  over the torso, so a tabby's bars and a spot pattern are drawn on the shirt.
  Reads as printed sportswear rather than as a coat. The produce are fine --
  their torso is skin. The fix is to put an animal's marks where its skin
  actually is: head, arms, legs. Marks would then need an arm or leg `parent`
  and would move with the pose, which is correct but is not a one-line change.
- **The arms read as detached slabs.** In a neutral standing pose every animal's
  arms hang clear of the torso with a visible gap, and flat unshaded colour gives
  the eye nothing to bridge it with. It is worst on the wide-shouldered types.
  Not caused by any of this work -- it is the shoulder join, already on this list
  -- but the body sheet is the first render that shows it plainly.

## The band nobody could name, and coats that moved to skin

**The produce wear no band.** It was a belt, then a collar, and both were the
same mistake at different heights: a produce's torso is its *skin*, and skin is
the whole of what says which produce this is. Any ring across it cuts the one
shape carrying the identity in two, and at a glance it read as neither clothing
nor body -- a green band somebody could not name, which is what it was called
when it was finally looked at. The animals keep their singlet, because an
animal's torso is genuinely clothed.

**Coats moved off the torso onto the face and the arms.** They started on the
torso, which put every stripe and spot on the *shirt* -- a tabby's bars came out
as printed sportswear. A coat is on skin, and the skin a dressed voli shows is
the head and the limbs. Marks parented to `BodyPivot/LeftArm` also now swing with
the arm, which is correct and is why this could not be done by nudging positions:
it needed a different parent.

**And they are now much harder to see, which is the honest result.** A face mark
is sized in head radii and an arm mark in arm radii, both an order of magnitude
smaller than the torso they left. At sticker size -- sixty to a hundred pixels
for a whole body -- a brow bar is about one pixel. Correct and nearly invisible
is a real trade, not a win, and the next pass has to buy the legibility back
somewhere: fewer and bigger marks, or marks that read at the size they are
actually drawn rather than at the size they are modelled.

## Still open from this round

- **The clipboard leaves the game lagging even after you navigate away.**
  Reported and not yet investigated. Building it lazily moved the stall off the
  title screen but something it leaves behind is still costing frames, which is a
  different bug from the one that was fixed and wants its own measurement --
  `startup_probe -- clipboard` already opens the page, so it needs a mode that
  closes it again and keeps watching.
- **The sticker bake in the roster's 3D view**, as the test of whether a baked
  sticker still reads when it moves. Not started.
- **The arms read as detached slabs** in a neutral standing pose on every animal:
  they hang clear of the torso and flat colour gives the eye nothing to bridge
  the gap with. The shoulder join is already on this list; the body sheet is just
  the first render that shows it plainly.

## The clipboard lag: not a leak, and the work was never bounded

Reported as the game staying slow after the clipboard was opened, all the way
back to the title screen. Measured with `startup_probe -- clipboard`, which now
opens the page, navigates away from it, and keeps watching -- three phases, with
frame times **averaged per phase** rather than reported per frame. That second
instrument was necessary: a background tax is a small cost on every frame, and
the slow-frame threshold that found the boot stall is blind to it by design.

**There is no leak, and that is a measured result rather than a hope.**

| | frames | ms each |
|---|---|---|
| before opening | 32 | 89.2 |
| clipboard open | 125 | 209.3 |
| after navigating away | 559 | 80.3 |

After the page closes the game is *faster* than before it opened, and a census of
the whole tree reports **0 nodes processing** and no `SubViewport` left on
`UPDATE_ALWAYS`. Nothing the clipboard builds keeps running.

**What was actually happening** is that the bake had not finished. It carries on
draining its queue while you navigate, and it blocks the main thread while it
does -- so the lag genuinely followed you to the title screen, without anything
being left behind to cause it. Two fixes, both about the work rather than about
cleanup:

1. **The sheet asked for every pose up front.** Seven volis by three phases by
   two views plus a headshot each is **49 bakes**, each two posed 3D renders, two
   full-image readbacks and two contour traces. The comment defending it argued
   from a per-sticker figure -- "a bake is roughly ten milliseconds, so the whole
   set is a blink" -- which is the wrong cost to reason about a set with, and the
   ten was optimistic besides. It asks for the headshots plus the current phase in
   the current view now: **14**. A phase or view switch costs 7, and with the disk
   cache each is paid once ever rather than once per open.
2. **Several bakes could share one main-loop iteration.** `_bake` awaits frames
   internally, but those awaits are for the renderer and nothing stopped the pump
   starting the next job in the same iteration. One render per frame is guaranteed
   now, which turns a freeze into a stutter. Cache hits do not spend a frame --
   spending one on a file read would make a warm open slower than a cold one by
   exactly the mechanism meant to speed it up.

**Still true, and not fixed:** a single bake can still take a very long time in
this environment -- the worst frame in the cold trace is 27 s of one sticker under
software rasterisation, which no amount of queue discipline touches. Some of that
is llvmpipe and some is likely first-use pipeline compilation for the coats' new
meshes, and this environment cannot separate the two. The right next measurement
is on real hardware, where the question is simply whether a cold clipboard still
hitches now that it does a third of the work one frame at a time.

## Mesh count: the coats are not the problem, the ink is

Measured, because "the coats' mesh count is my first suspect" was a guess and it
was wrong. Counted off built actors, body meshes against their `Ink` twins:

| body | coat | body | ink | total |
|---|---|---|---|---|
| Feli | none | 37 | 35 | 72 |
| Feli | patch | 38 | 36 | 74 |
| Feli | scar | 39 | 37 | 76 |
| Feli | tabby | 44 | 42 | 86 |
| Avi | none | 31 | 29 | 60 |
| Avi | speckle | 36 | 34 | 70 |

A coat is not one part. It is a set of small spheres flattened by a non-uniform
scale, parented to `BodyPivot` for face marks and to `BodyPivot/LeftArm` or
`RightArm` for limb marks so they swing with the arm. Each also takes an `Ink`
twin, so a mark costs two meshes: tabby and spots are seven marks (14 meshes),
speckle five (10), scar two (4), patch and blaze one (2).

**So the worst coat is +19% on a body that is already 72 meshes, and most are
+3%.** Trimming them is optimising the wrong thing. The `Ink` twin is **35 of
those 72** -- the outline hull doubles every mesh on every voli, marked or not,
and it is the only lever on this scale.

Which is the argument for doing the roster sticker test next rather than a mesh
diet: a sticker needs no ink hull at all, because its border is drawn in 2D by
the worksheet around the baked contour. Moving the roster view to stickers is a
~49% cut where a coat diet could never reach 19%.

**Before that test can run:** the roster's `VisualizerViewport` reports **2x140
px** in every trace. A two-pixel-wide viewport cannot show anything, so whatever
is starving it needs fixing first, whichever way the test then goes.

**And the one thing the test has to answer, not the easy half:** a sticker is
baked per view angle. A voli that turns or moves needs either a bake per angle or
a small set of angles it snaps between. "Does it look right" is the easy question;
"how many bakes does a rally need" is the one that decides whether playback can
use them at all.

## Tactical training: three items, one done

**Done: the tray's names could not be read.** They were drawn in `press` -- the
muted ink the *empty*-slot outlines use -- laid straight over a headshot. Mid-grey
on mid-tone is the one pairing that cannot be read, and because a voli's body can
be any colour it comes in, it failed differently for every slot and so never
failed consistently enough to look like a bug.

The slot number two lines above already had the answer and it had not been applied
here: it takes a backing plate as soon as the card is filled. The name gets the
same, along the foot, with the type at full ink rather than `press` -- once the
plate is providing the contrast, a muted ink on an opaque ground is just quiet
for no reason. Centred rather than right-aligned, because right-aligned was the
right call while the type was floating over a headshot and had to keep clear of
the face; on its own ground it has no reason to hug an edge.

**Open: sticker placement.** Dropping a voli on the sheet places them, and what
is missing is everything around that -- what a legal position is, whether two
volis can occupy one, whether a placement survives a phase change or a view
change, and what the sheet does when a rotation makes a placement illegal. The
drop currently stores metres and redraws; nothing validates it.

**Open: action assignment.** A voli on the sheet is a body in a pose, not a voli
*doing* something the drill will run. The phase says what the whole sheet is
about (Block, Attack, Floor) and the individual has no assignment inside it --
no "this one takes the line, that one covers the tip". `PHASE_POSE` is keyed by
phase precisely because there was nothing per-voli to key on. That is the gap
worth closing before the drill session in #69 can mean anything, because a
session needs per-voli asks to score against learned comfort.

## The shadow is the handle

Stickers are adjustable and removable now, and the grip is the **shadow**.

That is the right handle rather than a convenient one. A sticker is a flat body
standing up out of the floor, and the one part of it genuinely *on* the floor is
its shadow -- so it is the part that answers "where does this voli stand" rather
than "where is this picture". It is also the only part that stays put in the plan
view, where the body is a pair of shoulders seen from above and there is nothing
else to take hold of.

Handles are **recorded from the draw**, not recomputed: `_draw_sticker` appends
the shadow polygon it just drew, tagged with the slot it was drawing for. A
handle therefore cannot be somewhere the shadow is not. Only placed volis get
one -- what the phase draws (the blockers, the hitter, the floor marks) is not
something anybody put there, so it is not something anybody may pick up.

Checked before the zones are, because a voli always stands *on* a zone and the
two are always under the cursor together. Of the two, the one a hand is reaching
for is the body it can see.

The drag offset is kept in **court metres**, like everything else on this sheet:
without it a voli lurches so their feet land under the cursor the moment you
touch them, and with it in pixels the drag would break on a view change.

**Removal is leaving the court.** No bin to aim at and no second control -- you
take a voli off the sheet by taking them off the sheet. The bound is the same one
`place_voli_at` refuses on, deliberately: two different margins leaves a band
where a drop is neither placed nor removed and the voli springs back, which reads
as the drag having failed rather than as the sheet having a rule.

**Refusals are notes on the page, not dialogs.** A page whose whole argument is
that the drawing is the interface cannot answer a click with a modal window --
that is the one thing on it you would operate from outside the drawing, which is
the reasoning that kept the zoom out too. Three of them:

- a block page refuses the floor: *"No blockers on the floor — a block is made
  at the net."*
- a floor page refuses the net: *"No receivers at the net — this phase is played
  off it."*
- either page refuses a spot inside `PLACEMENT_CLEARANCE_M` of another voli.

The attack page takes the whole court and that is not an omission: a hitter
starts on the floor and finishes at the net, so both are legal. It is the case
most likely to be broken by somebody tightening the other two, which is why it
has a test of its own.

Nine checks, including the two easiest ways for the clearance rule to be wrong --
a voli crowding *themselves* when moved a short way, and taking a voli off twice.

**Still open on placement:** rotation legality. Nothing checks a placement against
the rotation the lineup is actually in, so a sheet can show an overlap that would
be a fault. That wants `RotationLegality`, which already exists for the simulator,
pointed at the sheet's own placements -- and a refusal that names the overlap
rather than saying "illegal".

## Telling a voli what to do

The sheet had no per-voli instruction at all. `PHASE_POSE` is keyed by phase
because there was nothing else to key on, so a page could say "this is a block"
and could not say which blocker closes the line -- which is the entire content of
a tactical instruction.

**The rail is an instruction now, not a chart.** It held four priority bars: a
frequency reading of where attacks go, which is a fact about the *opponent* on a
page about what your own volis should do. Interesting once and never actionable
-- nothing you could do to the sheet changed it, so it was the one thing on the
page you could only read. It shows who you are holding, where they are standing
in a coach's words, and what they are being told.

**Holding a voli is selecting them**, because there is nothing else "select"
could mean on a sheet you operate by dragging, and a separate click would be a
second gesture for what the first already said. Their card in the tray lights
green while you hold them, which is the answer to "which voli is who": seven
stickers on a court are seven bodies, the names live in the tray, and nothing
joined the two. Green rather than the marker red on purpose -- red here is the
pen that carries emphasis and refusal, and a voli being moved is neither.

**The vocabularies are per phase**, and so are the assignments: the same voli
closes the line when blocking and digs cross when the ball comes down, so a
single value per voli would make the second overwrite the first.

| phase | options |
|---|---|
| Attack | spike line, spike cross, tool, roll, feint |
| Block | close line, close cross, soft block, kill block |
| Floor | dig line, dig cross, cover the tip, chase — **provisional** |

Floor is marked provisional because nobody has said it. The attack and block sets
were named; these are the standard terms for the same distinctions on defence and
are a proposal, not a decision.

**Every behaviour is a dashed arrow, and the shape is the meaning.** A dashed
line is what somebody draws for a thing that has not happened -- the solid marks
on this sheet are where bodies are, and an intention is not a body.

- **line** runs straight over the net on the voli's own axis, so zone 4 and zone
  2 get different lines on the page from the same instruction.
- **cross** cuts to the opposite far corner, its direction taken from the
  hitter's own x. The one shot whose drawing genuinely depends on where they
  stand, which is why it cannot be a fixed angle -- and a middle correctly gets
  the shorter of the two, because a middle has less angle than a pin.
- **tool** is short, flat and level, with no rise at all. Struck *off* the block
  rather than over it, and a flat mark is the only one of these that says the
  ball never went up.
- **feint** is a low short arc landing just past the net; **roll** is the same
  arc longer and higher, landing deep.

Nine checks, including the two an instruction system most easily gets wrong:
telling a voli what they are already doing takes the instruction *off* (or it can
be changed and never removed), and a block instruction on an attack page is
refused rather than stored (or it would draw an arrow the phase has no meaning
for).

**Open on this:** nothing consumes an instruction yet. A behaviour is drawn and
stored and the drill session in #69 does not read it, which is the next join --
per-voli asks scored against learned comfort is exactly what these are for.

---

## The ball flew flat and then fell out of the sky

Reported from playback: "the ball takes a flat moving trajectory until it reaches
the x/z coordinate of the floor or voli it reaches, then teleports down to
continue the play."

That is a claim about the *middle* of a flight, and every instrument this repo
had checked the ends. `run_contact_continuity_probe` asks whether the ball
finishes where the next contact begins; a ball that flies flat and then drops
passes it, because both of its ends are right. So the first thing built was an
instrument that could see the defect at all -- `tools/run_ball_flight_probe.gd`.

### The measure, and why the obvious one was useless

The first attempt measured "what share of the descent happens in the last quarter
of the flight". It reported the retired curve at 86% for Attack -> Block against
a physical 31%, which looked like the finding -- and then reported the *new*
curve at 84%, which looked like a failure. Both readings were meaningless: the
denominator was the flight's own minimum height, which for a rising flight is its
start, so the metric was apportioning a descent against a point the ball never
returned to.

The retired hump is also a parabola in the flight fraction, which is what makes
"where does it drop" a dead end:

    h(t) = lerp(h0, h1, t) + 4A*t*(1-t),   A = apex - midpoint

Its t-squared term is -4A and a real flight's is -g*T^2/2, so **the two differ by
exactly one coefficient**, and the honest measure is what gravity the drawn ball
appeared to fall under. Over 1090 drawn flights:

    contact pair              n   was, x g   worst x g   off by m   worst m
    Set -> Attack           227       3.92       43.60       0.89      1.48
    Reception -> Set        175       2.64        4.45       2.41      3.55
    Defense -> Set           52      47.91      438.74       2.96      3.43
    Serve -> Reception      204       2.11        2.38       1.25      1.31
    Attack -> Block         181       1.71       19.49       0.26      0.97

A ball under forty-eight times gravity, thrown forty-eight times too hard upward,
holds its height and then plummets. The drawn ball sat up to **3.55 m** away from
where a real one would have been, entirely in the middle of the flight, where
nothing was looking.

### What the apex was, and why it could not draw a spike

The apex was an *input*, computed in `match_screen.gd` from a table of per-action
`rise_scale` and `minimum_lift` constants, with floors that lifted a serve to at
least net + 0.48 and a set to net + 1.05 whatever their flight time was. Two
consequences, both invisible:

1. **Net clearance was a property of the drawing.** A serve whose flight could not
   physically carry it over the tape was drawn over the tape anyway. With the
   floors gone and the flight solved honestly, 17 of 204 serve receptions and 8 of
   30 serves to the floor were drawn *through the net* -- real defects that had
   been papered over rather than fixed.
2. **A downward-struck ball could not be expressed at all.** The floor put the
   apex above the contact, and a symmetric hump with an apex above both ends has
   to rise first. A spike is struck downward -- `DRIVEN_REFERENCE_ANGLE_DEGREES`
   has been minus fifteen since `AttackPowerModel` was written -- so the one shape
   the curve could not draw was the commonest shot in the sport.

### The fix: three knowns determine a parabola

Both contact heights are facts about the rally and so is the flight time, and a
parabola has three degrees of freedom. Nothing is left to choose.
`BallFlightModel.height_between` solves it; `BallTrajectory.height_at_progress`
and `MatchCourt3D.trajectory_world_position` -- which were two hand-kept copies of
one curve -- both call it. `apex_height_meters` is now *reported* rather than
supplied, which is what lets a probe ask whether a flight cleared the net.

`BallPresentation` is new and holds the drawn flight on its own, for the reason
`terminate_trajectory` was made static before it: a defect you can only see by
watching a rally at playback speed is a defect nobody finds twice.

### The contact heights were also two implementations of one fact

Five expressions in `match_screen.gd` and five more in
`GeometricAttackPromotion`, with five pairs of constants that agreed by
inspection and by nothing else -- the resolver timed a serve leaving one height
and the court drew it leaving another. The promotion module now owns all of them
in both forms, one taking a `VolleyballPlayer` and one taking the two reach
figures a physical profile carries, and presentation calls it.

### A spike is struck, not lobbed

`GeometricAttackResolver` resolves every attack in the game: it picks a course,
chooses a power from `AttackPowerModel`, solves the driven root off the hitter's
real contact height, and checks the ball clears the tape. It hands back
`speed_mps`, `vertical_angle_degrees` and `contact_height_meters` -- and all
three were dropped, with the drawn attack rebuilt from `solve_launch_arc` as a
ball lobbed *upward* from ground level to ground level. Failure mode #1, exactly.

`_swing_arc` carries the speed and **re-solves the angle**. The first version
carried the angle too and it drew nonsense: a lofted 70-degree roll re-aimed at
the legacy target solved to a two-second flight with the ball nine metres up.
Speed is a property of the swing and travels; angle is a property of the swing
*plus its target* and does not. `minimum_speed_to_reach` was added because
`minimum_speed_for_range` returns the speed floor rather than an error when no
speed reaches at a fixed angle -- taken literally, a sixteen-metre attack came out
with a 124-second flight.

### Bump height is now what buys the setter time

The pass's flight time was `0.38 + distance / lerp(5.2, 8.4, execution)`, a
horizontal speed dressed as a duration in which **a good pass reached the setter
faster than a bad one**. That is backwards: height is the whole currency of a
second contact, because it is the only thing that buys the setter time to arrive
and square up and the hitters time to find their run-ups.

The apex band was already there as `lerpf(1.1, 2.8, execution)`, passed to the
trajectory, thrown away by the drawing and read by nothing. It is now an absolute
apex and the hang time falls out of gravity:

    reception quality     n     apex m     hang s
    0.0-0.2              81       1.47       0.63
    0.2-0.4              89       2.67       0.94
    0.4-0.6              80       2.75       0.83
    0.6-0.8              57       3.39       1.11
    0.8-1.0              12       3.55       1.25

**The underhand set is reachable now, and was not before.** The setter takes the
ball as high as they can reach *and as high as it got*, so a pass that never rises
to hand height has to be bumped -- a new `platform` reach state in
`SetterCapabilitySystem`, which cannot run a quick and costs more than a jump set
because a jump set is a choice and this is not. It could not previously happen:
`pass_contact_height_meters` drew the height from a table against a random sail
value whose floor sat above every setter's forehead, which is the §0 defect in its
purest form -- a state with a threshold outside its own distribution.

### The trail: one meaning per channel

Colour is contact quality on the five grade tiers every rating in the game already
uses; length and weight are how hard the ball was struck. Asked to carry both, one
channel makes red mean "hammered" and "shanked" at once, and those are the two
readings a viewer most needs to tell apart.

**The tier bands are measured, not inherited.**
`VolleyballAttributeProfileSystem` grades a 0-100 attribute at 96 / 89 / 66 / 50.
Reusing those on a contact quality would have been the mistake this file keeps
recording: over 1131 contacts, quality runs p10 0.17, p50 0.50, p90 0.72, so those
cuts put nine contacts in ten in the bottom two tiers and gold would never once
have appeared. The bands sit on the quartiles of the distribution they cut.

Power is read off the *launch* speed rather than the ground speed, because a dig
goes almost straight up and covers 1.6 m of floor in most of a second -- which
would read as the softest touch in the game when it is a defender getting a hand
on a spike.

### Two changes were correct, measured, and turned off

Both are the same shape and both belong with tasks #62 to #64.

**The defender's flight budget.** `attack_time` is solved through a *defensive*
classifier while the ball is drawn from the hitter's own swing -- one fact,
computed twice, and the file already says so at length. Pointing it at the drawn
flight is right and, now that the drawn flight is a struck ball rather than a
0.74 s lob, produced over 700 rallies:

    opponent swings   681 -> 8
    home kill rate   0.85 -> 1.000

Nothing is dug, so no rally reaches a second exchange, so the opponent stops
attacking. The floor defence turns out to be *entirely* calibrated against attacks
being modelled as lobs, which nothing had measured because the two numbers had
never been made to disagree this much.

**`ENABLE_SET_HEIGHT_TIMING`.** A set is described by its height, so `_set_arc`
solves the hang time from an apex. The launch-angle table it replaces cannot
express a set at all: at the six to ten degrees it calls a quick, the only ball
that climbs the metre from a setter's hands to a hitter's over four metres is one
struck at 26 m/s. The new times are right -- 0.65 s for a quick to 1.47 s for a
high ball against 0.23 s to 0.69 s -- and that is the problem, because the run-up
is paid for out of the set's flight time:

    home attack quality >= 0.25    0.794 -> 1.000
    opponent swings                   97 -> 8

Every approach constant in the engine was fitted against set flights a third as
long as a set really is.

With both off, the drawing is still honest: the ball on screen is a real parabola
between the two contact heights over whatever duration the resolver reports. What
has not happened is the re-fit, and it is the same re-fit this file has been
naming as the limiter since "What the rally simulator work is for".

### One gate moved, and the move is a finding

`Gate 4 exposes both player-development and formation effects` read
`formation_reachability_spread`. Solving the serve from the server's own contact
height makes a serve about a third longer -- which is what a real serve takes --
and every formation now reaches everything: 1.000, 1.000, 1.000, spread exactly
zero. A metric pinned at its ceiling separates nothing.

The formations have not stopped differing; reachability has stopped being where
they differ. Mean destination error still moves with the formation (0.892 m
standard, 0.937 m compressed middle, 0.906 m split deep), so the calibration now
reports both spreads and the gate reads the one still inside its own range.

### Still open from this round

- **The re-fit.** Both flags above, and the floor defence they depend on.
- **Four attacks in 23 and one dig in 96 are still drawn through the net.** Real
  errors or drawing defects, not yet separated -- an attack into the net is a
  thing that happens, and the probe cannot currently tell one from the other.
- **`_ball_trajectory` still publishes `height_contract: "relative_rise"`** while
  the drawn flight publishes `gravity_true`. Two contracts, correctly, because
  they describe different objects -- but the naming invites a reader to think one
  supersedes the other.

---

## The floor defence, re-fitted -- and the five-to-one it was hiding

The re-fit the previous entry left open, and the answer turned out to be one
number rather than a tuning pass.

### The instrument first

`tools/run_rally_balance_probe.gd`. Every previous attempt at this was measured
with a different private probe, so no two attempts were comparable, and the
figures this file quotes across ten entries are not on one scale. This is one
reading with every number the sport has a real value for -- kill rate, dig rate,
stuff rate, ace rate, swing balance, contacts per rally -- printed together
because they are one fact, and run on **both serving sides**, because half this
engine's history is one side of the net being modelled and the other not.

The baseline was healthier than this file had been claiming. Not 0.85-0.91 kill:

    contacts per rally   5.44   above 6.0
    kill rate            0.542  0.45 - 0.50
    dig rate             0.341  0.35 - 0.55
    stuff rate           0.065  0.08 - 0.14
    ace rate             0.083  0.05 - 0.09
    serve error rate     0.154  0.12 - 0.20

Serving is **in range on both of its own axes** and needs no buff.

### The defect: one side of the net was timing a different ball

Splitting the dig rate by side found it immediately:

    home dig rate       0.929
    opponent dig rate   0.180

Five to one, on identical code, with identical attributes. The home defence
timed the incoming swing through `_attack_launch_angle_degrees` -- a *defensive*
classifier that lobs the ball at 22-32 degrees -- while the opponent defence
timed it off the swing that was actually drawn. This file found that split once
before and fixed it behind `ENABLE_UNIFIED_ATTACK_SHAPE`, and the flag stayed
shut because opening it collapsed the rally.

It collapsed the rally because the dig was calibrated against the lob. That was
never an argument that the two solves should disagree.

### What landed, and what each part was worth

Three changes that cannot land separately, measured over 700 rallies:

1. **`ENABLE_SET_HEIGHT_TIMING` on.** Real hang times, 0.65 s to 1.47 s.
2. **The home defence times the ball off the swing**, unconditionally.
3. **`DIG_SOLO_SHARE` 0.62 -> 0.90 and `DIG_ATTACKER_ADVANTAGE` 0.20 -> 0.07.**

                        before    after   target
    kill rate            0.542    0.481   0.45 - 0.50
    dig rate             0.341    0.478   0.35 - 0.55
    stuff rate           0.065    0.112   0.08 - 0.14
    home kill rate       0.724    0.531
    opponent kill rate   0.276    0.415
    swing balance        0.681    0.767   near 1.00
    contacts per rally   5.44     5.57    above 6.0

The three headline rates are inside their bands for the first time. The
side-to-side kill gap goes from 0.448 to 0.116.

### Four attributes that decided nothing, and now decide something

- **`arm_speed` was inert.** Generated, trained, scouted, drawn on the profile
  wheel, read by no simulation code -- it was in the inert-attribute audit and
  stayed there. Two consumers now. It shortens what a blocker can read off the
  swing (`ARM_SPEED_READ_COST`), and it pays off part of the tempo demand
  (`ARM_SPEED_TEMPO_RELIEF`), which is what makes it a middle's attribute: a
  quick was priced entirely on the *setter's* `tempo_control` and the person
  swinging at it had no say in whether they could get the arm through.
- **`court_vision` decided nothing on the floor.** It was read by the attack's
  own resolver and by the blocker's read and by nothing a defender does, so a
  libero's vision was worth nothing to a dig. It is now contested directly
  against the hitter's `arm_speed` in `_dig_read_bonus`: seeing the shot early
  is worth exactly as much as the arm is slow, and the term is *signed*, so a
  poor reader against a fast arm is behind the ball rather than merely not ahead
  of it.
- **A funnelling block told the diggers nothing.** Which is the entire point of
  funnelling. Choosing the intent moved the wall's own position and bought the
  six people behind it nothing at all. `FUNNEL_READ_BONUS`, with a smaller
  `SEAL_READ_BONUS` -- holding the line still removes an option, it just
  concedes the angle rather than narrowing it -- and a larger
  `TOUCHED_BALL_READ_BONUS`, because the engine already pays a defender the
  extra flight time off a touch and this is the read that goes with the time.

### Already built, and worth recording so it is not built again

**Balance and pace resistance are done.** `CoverageModel.reception_body_penalty`
already prices exactly this: `edge_ratio` is how far out on their own reach
envelope a defender is -- a defender who is set has a low one and a defender
stretching has a high one -- and `reception_balance` counteracts it, while
`reception_stability` counteracts a pace exposure taken from the ball's real
speed. There is no separate `pace_resistance` attribute to add; it is
`reception_stability`, and it has been consuming a real ball speed since the
drawn flight became physical.

### Still open

- **The remaining asymmetry is an offence difference, not a defence one.** Home
  swings come out at 0.484 quality and opponent swings at 0.332, and that gap is
  now most of what is left of the kill split. Tasks #62 to #64.
- **Contacts per rally is 5.57 against a target above 6.** One full exchange and
  most of a second. Bounded by the same offence gap: a weaker opponent swing ends
  more rallies than it should by being dug into a free ball.
- **A blocker reads the arm but not the course.** `_blocker_read_quality` now
  costs the read against `arm_speed`, which says *how much* a blocker sees. What
  they see is still the play -- pass, setter's body, tempo -- and not the
  shoulder. `wall_stage_x` already takes a `read_quality` and would consume a
  course read directly, so the foundation exists and only the cue does not.
- **Serve placement precision is not measured at all.** The two serve rates the
  probe reports are outcome rates and both are in range; how *close to its aim
  point* a serve lands, and whether a seam is worth attacking, are different
  questions with no instrument.
- **No blocker touch attribute exists.** A deflection's pace is currently
  uncontested. `block_timing` decides *when* the hands are there and
  `hand_control` is the setter's; nothing says how well a blocker's hands absorb
  a ball once it hits them.


---

## Withdrawn: the run-up window is not why displacement stopped costing

Recorded because the reasoning was published before it was checked, and it was
wrong in a way worth keeping.

Three gates went red together when sets started being timed by how high they
were put up -- extreme hitter displacement stopped costing contact position,
stopped costing swing quality, and transition speed stopped changing when a
hitter arrived. One cause was proposed for all three: `evaluate_takeoff` set
`run_time` to the whole available time, so tripling a set's hang time tripled
the run-up and `runway_completion` saturated for everybody.

**The mechanism is real and the cap is right on its own merits.** A hitter given
a 1.5 s high ball does not run for 1.5 s; they take three or four steps and wait
out the rest, so hang time should not convert into speed. `APPROACH_RUNUP_SECONDS`
caps it and the balance figures hold across the change:

    kill 0.483   dig 0.474   stuff 0.112   swing balance 0.766

**But it is not why those gates went red.** With the cap in, the displacement
gate reports *bit-identical* numbers -- margin 0.712 -> 0.589, quality 0.449 ->
0.423, contact_y 0.513 -> 0.510. A fix that changes nothing about the quantity
under test did not fix it, whatever its own merits.

A second attempt put the same cap on `_approach_budget`, whose `available_seconds`
is the run-up's clock. That changed nothing at all, and the reason is written
above the call site: *"Published, not spent."* It is a diagnostic on the event's
metadata and no consumer reads it. The cap stays -- a published figure that
disagrees with the model it describes is worse than one that agrees -- but it is
bookkeeping, not behaviour.

**So the three gates are still open and undiagnosed.** What is now known is what
it is *not*: not the run-up window, on either path. The next thing to measure is
what `_reachable_contact` does with a displaced hitter when the set hangs
honestly -- the gate's own first clause is that the contact should be dragged
back off the net, and it is moving 0.003 the wrong way, which is a claim about
the clamp rather than about the runway.

---

## The spike was still lobbing over the block, and the launch was the missing fact

Reported again after the gravity-true rewrite: the flat-then-drop symptom was
still visible in 3D playback. It was, and the rewrite could not have caught it,
because both ends of every drawn segment were still right.

### What it was

Dumping the drawn height of real attacks at deciles, which no probe had done --
the earlier instruments reported aggregates:

    seed 7002  T=0.88s  dist=6.7m  next=Block
       h:  3.30 3.60 3.83 3.99 4.07 4.07 3.99 3.84 3.61 3.31 2.93
    seed 7006  T=0.49s  dist=9.2m  next=floor
       h:  3.28 3.07 2.84 2.58 2.30 1.99 1.66 1.31 0.94 0.54 0.12

An untouched spike descends exactly as it should. **A spike met by a block is
drawn lobbing upward over it.**

A parabola is determined by two endpoints and a duration only when both
endpoints are *landings*. A blocked spike's far end is an interception, and the
height taken there was the **blocker's reach** -- around 2.9 m, within a few
centimetres of the hitter's own contact. A curve forced to arrive level after
most of a second has to be launched upward to spend the time. Attack-to-block is
181 of 1090 flights and it is the one a viewer watches most closely.

### The fix: carry the launch instead of re-inferring it

Four changes, each unlocking the next:

1. **`struck_arc_from_speed` publishes the launch**, and `_ball_trajectory`
   carries it, so a truncated segment need not reconstruct a launch it cannot
   see.
2. **Presentation derives a blocked spike's far end from that launch** rather
   than from the blocker's reach.
3. **`_truncated_arc` keeps the parent swing's launch and its proportional
   share of duration** instead of re-solving against the distance to the net.
4. **`_swing_arc` carries the resolver's own angle** when the ball is going
   where the resolver sent it.

Attack-to-block flights crossing below net height: **111 -> 50 -> 47 -> 50**
across the four attempts below, ending with blocked spikes descending rather
than lobbing, and the suite green at 1013.

### Two targets that were never two

The prerequisite named in the previous version of this entry -- *reconcile the
resolver's landing point with the legacy `attack_target`* -- **did not exist.**
Every attack site assigns `attack_target = geometric.target` *before* solving
the arc, at all three sites, so distance and landing have never disagreed. That
was inferred from a symptom rather than read off the assignment order, which is
the same mistake in method as the run-up cap two entries above.

The nine-metre flights came from somewhere far narrower: the full shot's angle
applied to the **to-block leg**, whose distance is the short hop to the net
rather than the shot's own range. One line of geometry, three passes of wrong
theory about it.

### Three wrong turns, kept because each looked right

1. **Reading the far end off the aimed flight at the truncation fraction.**
   Correct in principle, wrong here: `attack_to_block` trajectories are *already*
   truncated by the resolver, so the aimed flight is the short leg and the ball
   was drawn hitting the floor at the net.
2. **Re-solving the driven angle against the distance to the net.** That asks
   "what shot lands at the tape", so the leg aimed at the block rather than
   through it and dived -- 111 of 181.
3. **Carrying the resolver's angle unconditionally.** Its net-clearance search
   falls back to a *lofted* root when no driven one gets over, and a lofted angle
   is achieved by going a very long way up. Measured: the mean height of an
   untouched attack at the tape moved 2.69 m to **5.19 m**. The carry is now
   bounded to downward-struck balls, which is the only case the flat-spike report
   was ever about; a lofted shot re-solves as before and the mean returns to
   2.69 m.

### The gate that had to move with it

`a block happens during the swing, not after it lands` measured the block's stamp
against the attack's `outgoing_trajectory` -- which, for a blocked swing, is the
leg re-sliced to the tape. Once that leg is timed as its true share of the swing
it ends exactly when the ball reaches the net, so the fraction is 1.0 by
construction and the gate would flag every block in the game. It reads
`swing_duration_seconds`, the parent flight's own time, carried for this reader.

Distinct from the funnel gate, which asserted the inverse of the truth: this one
asserted the right property against a denominator that changed underneath it.

### Still open

**50 of 181 attack-to-block flights cross below net height.** Before any of this
they cleared by lobbing, which is clearing the net by being wrong, so the figure
is newly *visible* rather than newly caused. What remains is the case where the
resolver itself found no clearing angle and the swing is drawn honestly failing
to get over -- which may be correct, and wants separating from the case where the
drawing is still losing the resolver's answer. `run_ball_flight_probe` reports
the count; nothing yet reports which of the two it is.

---

## The offence gap is the second contact, and only one of four paths raises the ball

The last structural asymmetry. `run_rally_balance_probe` reports home swings at
0.484 and opponent swings at 0.332 and cannot say why, because attack quality is
a product of six terms and a product that only reports itself cannot be asked
which factor moved. `tools/run_offence_split_probe.gd` decomposes it.

### The first reading was a false lead, and the control is the point

Split by side alone, the answer looked obvious: set quality 0.570 against 0.231,
a gap of 0.338 driving an attack gap of 0.133. But the home side plays most of
its offence off a serve-receive pass and the opponent plays most of its off a
dig, and those are different contacts in the sport. A side-only average was
comparing two different questions.

Split by **what fed the set**:

    term                  home/pass   home/dig   opp/pass   opp/dig
    pass quality              0.630      0.720      0.396     0.700
    set quality               0.722      0.271      0.265     0.121
    attack quality            0.525      0.384      0.354     0.315
    swings                      290        148        265        82

### The finding

**Home off a pass is the only one of the four paths where the set is better than
the ball that fed it.** Everywhere else the second contact comes out far below
its own first contact -- a 0.720 dig becomes a 0.271 set, a 0.396 pass becomes a
0.265 set.

That is not phase and not roster. `_set_terms` computes
`usable = pass + (1 - pass) * capability * 0.40`, so a setter with any command at
all should raise the ball rather than lower it, and on one path it does.

### Two candidates ruled out, before either was claimed

- **`effective_pass_quality` is not dropped on the opponent path.** It reads
  `opponent_capability.get("effective_pass_quality", incoming_quality)`, the same
  recovery term the home side gets. This was asserted as the defect and was
  wrong.
- **The third argument differing is not it either.** Home passes `tempo_demand`
  and the opponent passes `transition_penalty`, which are genuinely different
  quantities occupying one parameter -- worth fixing on its own -- but
  `transition_penalty` is `(exchange - 1) * 0.035` and therefore *zero* on the
  first exchange, so it cannot explain a set that comes out below its pass.

### Where to look next, stated as a hypothesis

`_set_geometry`'s `release_distance` term. The opponent's setter contact is
`dig_position` -- wherever the ball was dug -- while `difficulty` charges
`release_distance * 0.020` against the setter's *release target*. A second
contact taken far from where the setter wanted to release is charged for the
distance, and on three of the four paths the contact is not at the release
target. That would explain why the one path whose setter is standing where they
meant to be is also the one path whose set improves on its pass.

Not verified. Recorded as the next measurement rather than a fix, because two
confident readings of this same gap have already been wrong in one sitting: print
`release_distance_meters` and `difficulty` per path before changing anything.

### Also found, and it is a reporting gap rather than a defect

`reached_approach_mark` reads exactly 0.000 for every opponent swing.
`_add_event` publishes it on the home attack and the home continuation and not on
the opponent's, so the figure is absent rather than false. Worth closing so the
probe can tell "did not reach the mark" from "was never asked".

---

## The 50 flights below the tape, separated -- and 53 of 55 are one cause

The open item from the spike-launch entry. The count could not be acted on
because two opposite defects look identical in a total: a swing the resolver
itself could not get over the net is *correctly* drawn hitting the tape, and a
swing the resolver cleared and the drawing then put into the net is a defect in
the drawing.

`GeometricAttackResolver._feasible_launch` already answers this. It searches
angles, then speeds, then a shortened aim, and returns `cleared` plus a
`launch_mode` naming the branch that answered -- `driven`, `lofted`,
`shortened`, `scraped`, `forced`, `unsolved`, of which the last two are a hitter
with no shot.

    === why a flight is drawn below the tape ===
      no geometric record                              2
      resolver cleared (driven), drawing lost it      33
      resolver cleared (lofted), drawing lost it      13
      resolver cleared (shortened), drawing lost it    7

**Not one case of the hitter having no shot.** `launch_cleared` is true on every
flight in the sample, so the design question this was waiting on -- should a
swing with no clearing angle be drawn honestly into the net, or nudged over --
does not arise. There are no such swings to decide about.

### It took three layers to ask

`launch_cleared` and `launch_mode` were computed on every swing and dropped three
times over: `_geometric_swing_record` did not forward them out of the resolver's
answer, `_geometric_promotion` did not forward them out of the record, and the
attack event did not publish them. The same failure mode as the spike launch two
entries above, and the reason the count sat unactionable for a pass.

### What the split says

- **33 driven.** The resolver found a *driven* angle that clears and the drawn
  ball still ended up in the net. These are the flights the carried angle is
  supposed to cover, so the carry is not reaching them -- that is the thread to
  pull.
- **13 lofted.** Excluded by design: the carry is bounded to angles at or below
  zero, because carrying a lofted root unconditionally moved the mean height of
  an untouched attack at the tape from 2.69 m to 5.19 m. Expected, and now named
  rather than anonymous.
- **7 shortened.** Swings the resolver had to pull the aim in on to clear at all.

### The signature in the worst cases

    Attack -> Block   0.56 m at the tape, 0.22 s, 3.40 m -> 0.12 m
    Attack -> Block   0.66 m at the tape, 0.19 s, 2.88 m -> 0.12 m

Every one ends at 0.12 m, which is the floor clamp in `display_trajectory`. The
carried launch drives the ball into the ground before it reaches the block, so
the leg's duration and its launch disagree -- the duration is too long for a ball
descending that steeply over a metre of court. That is a concrete next
measurement rather than an open question: print the leg's horizontal speed
against the parent swing's and see which one the duration belongs to.

---

## A deflection is a collision, and it now carries the pace it was struck with

`BLOCK_DEFLECTION_LAUNCH_ANGLE_DEGREES` is thirty degrees and the speed was
derived from the distance to wherever the ball was going to land -- so a 25 m/s
spike and a 12 m/s roll came off the wall at the same pace, and the blocker had
nothing to do with it. Pace is the one thing a deflection is *made of*: it is
not a shot anybody chose, it is a collision.

The speed is now the incoming swing's, less what the hands take out of it, and
the flight time is distance over that speed like every other struck ball here.

### Two things fell out without being written

- **`reception_stability` finally has something to resist.** The pace-resistance
  half of the defence was already built -- `CoverageModel.reception_body_penalty`
  spends it against `_incoming_ball_force`, which reads the drawn arc's real
  speed. It was resisting a constant. It now resists the swing.
- **A hard-driven ball reaches the defender sooner**, because the duration is
  derived rather than floored.

### The constant that made the first attempt inert

Landing the drawn speed alone moved the dig rate **0.491 to 0.490** -- nothing.
The reason is that a touched ball bought the defence a flat `+= 0.24` seconds,
at all three defence sites, whatever hit the block and whoever blocked it. The
ball on screen was right and the number the defence actually spends was still
the constant: a value computed and dropped before anything could use it, one more
time, and the fourth instance of that pattern in this file today.

With the budget reading the deflection's own flight:

    dig rate            0.490 -> 0.500
    contacts per rally  5.719 -> 5.763
    stuff rate          0.136 -> 0.134

Small, and in the right direction on every axis. The point is not the size, it is
that the blocker's hands and the hitter's power now reach the defender's decision
at all.

### `block_timing` is a stand-in and should be replaced

What belongs in the absorption term is how well a blocker's hands take pace off a
ball, and **no such attribute exists**. `ball_control` is displayed as "Touch
Control" but it is the *receiver's* hands and is read by reception quality.
`block_timing` is the nearest true thing -- a blocker meeting the ball at full
extension presents a firm angled surface and one already falling gives with it --
and that is a real part of the effect rather than the whole of it.

`BLOCK_ABSORB_SOFT` and `BLOCK_ABSORB_FIRM` are bounded well short of both ends
on purpose: a block absorbing nothing returns the spike at the spike's own speed,
which is a mirror rather than a deflection, and one absorbing nearly all of it
makes every touched ball a free ball and removes the reason a hitter fears the
wall.

---

## The block's hands are a decision, and the two things that would let it fire

Proposed by the manager, and correct: `block_intent` -- Seal or Funnel -- is a
*lateral* choice about where the wall stands, and the sport has a second axis it
has never had. Two blockers at the same height with the same timing produce
different balls depending on whether they pressed over the tape to end the rally
or angled back to keep it alive. Not an attribute; a decision.

It is also the missing consumer for something already built: the clipboard
offers **"soft block"** and **"kill block"** as two of its four per-voli block
instructions, `TacticSheet` stores them, and nothing has ever read one.

### Built, and measured inert

`_block_hands_intent` returns `kill`, `soft` or `neutral` from three sources in
the order a real decision has them -- the manager's instruction, then
`AttemptJudgment.backs_off`, then pressing. It moves the stuff margin and the
deflection absorption in opposite directions, because a kill block that comes off
ends the rally and one that is beaten hands the hitter a tool at full pace, while
a soft block gives up stuffs to convert the swing into a playable ball.

`AttemptJudgment` is the right module rather than a new one: it already models
this exact decision for the second contact (a setter backing off a quick) and the
third (a hitter rolling instead of swinging), and its own header says so. The
block is the fourth contact that needs it and the only one that never asked.

**Every block in the sample comes out pressing: 224 of 224.** Two measurements
say why, and both are the §0 defect.

    primary_close   p10 1.00  p25 1.00  p50 1.00  p75 1.00  p90 1.00  min 1.00
    blocker judgment    p10 0.55   p50 0.67   p90 0.73

1. **`primary_close` is saturated at 1.00**, at every percentile including the
   minimum, on every block that reaches an event. So "how much of the travel did
   this blocker complete" carries no information, and a deficit built on it is
   always zero. It also means the stuff gate's own `primary_close >= 0.78` is a
   threshold that cannot fail -- a pre-existing instance of the same defect,
   found by looking for something else.
2. **`AttemptJudgment`'s curve is calibrated for deficits the block cannot
   produce.** Its thresholds run from 0.85 at a vanishing deficit to 0.25 at
   0.40, which is "hopeless". A median blocker judgment of 0.67 needs a deficit
   of about 0.12 before backing off is even possible, and the block's natural
   deficits are around 0.05. The shared model needs a scale adapter at this
   contact, or the block needs a deficit that spans the range the curve expects.

### Deliberately shipped inert rather than tuned into life

Two attempts were made and neither is in the tree as a live effect: the contest
margin as the deficit -- which is the *outcome* of the contest, decided after the
fact, and which a blocker in the air cannot feel -- and the close fraction, which
is the measurement above. Picking a third mapping without knowing the
distribution it acts on is precisely what §0 forbids, and it has already been
done twice in this one feature.

**What unblocks it, in order:** find out why `primary_close` saturates -- if
blockers who fail to close simply never emit a block event, then the deficit has
to come from the swing they are facing rather than from their own travel. Then
either scale the block's deficit onto `AttemptJudgment`'s range or give that
module a per-contact scale, which is the cleaner of the two because three
contacts already share it and a fourth arriving with a different natural range is
evidence about the module rather than about the block.

The instruction path is live and correct the moment anything sets it: nothing
carries the clipboard's per-voli block behaviour into the resolver yet, which is
the same join `TacticSheet` has been waiting on since it was written.

---

## The release distance was not it, and 85% of one squad was never written down

The measurement the last entry asked for, taken before anything was changed.
`tools/run_set_split_probe.gd` decomposes `_set_terms` the way the offence probe
decomposed the swing, split the same four ways.

    term                    home/pass   home/dig   opp/pass   opp/dig
    quality                     0.723      0.239      0.232     0.087
    capability                  0.855      0.713      0.595     0.593
    usable                      0.851      0.837      0.643     0.823
    capability_penalty          0.000      0.087      0.302     0.189
    geometry_difficulty         0.046      0.154      0.077     0.157
    arrival                     0.014     -0.088      0.011    -0.142
    release_distance_meters     0.501      3.593      0.853     4.339
    sets                          290        147        265        82

### The hypothesis was wrong, and wrong in an instructive way

`release_distance` is real and large -- 3.5 to 4.3 m on both dig paths against
0.5 to 0.9 m on both pass paths -- and it is **not the asymmetry**, because both
sides pay it equally. `geometry_difficulty` comes out 0.154 against 0.157. What
the release distance separates is a *pass from a dig*, which is a distinction the
sport agrees with: a setter who has to run down a dug ball is setting from
somewhere they did not choose. Left alone.

Three confident readings of this gap have now been wrong. The instrument found
it each time and the reasoning found it none of the times.

### The defect the measurement did find

`capability_penalty` was 0.302 on opponent/pass and 0.000 on home/pass, and the
decomposition says why: 37.7% of opponent first-ball sets were classified
`beyond_reach` and another 44.5% `jump`, against 100% `standing` at home.

The height that classification reads is the one thing the two paths sourced
differently. `_reception_pass_result` has computed a real contact height from the
pass's own apex under gravity since the bump-height work; the home first ball
reads it; the opponent path recomputed it from the retired table against
`rng.randf()` -- **eleven lines below the call that already had the real one.**
Failure mode #1, one-sided, and the value was not merely unused but overwritten
with a dice roll.

It is worse than an omission, because the table's shape is backwards for this
question: a worse pass arrives *higher* in it, and higher is what triggers
`beyond_reach`. A high pass is the forgiving one. The reach ladder only ever
fired where the retired table still fed it.

Threading `opponent_pass.set_contact_height_meters` through
`_resolve_opponent_transition`:

    opponent/pass          before    after
    contact height (m)      2.532    2.225
    reach: standing         0.177    1.000
    reach: beyond_reach     0.377    0.000
    capability_penalty      0.302    0.000
    set quality             0.232    0.395

The two dig paths keep the table, deliberately: a dug ball has no apex model yet,
so there is no real height to read. That is the remaining half and it is
symmetric -- 11.5% and 6.0% `beyond_reach`, both sides, both from the table.

### And then the reading that makes every previous side-versus-side number suspect

`command()` came out at **exactly 0.500** for the opponent on both of its paths
across 347 sets. An exactly constant number is never a model; it is a value
nobody set.

    home:      14 of 328 ability attributes never specified   (4%)
    opponent: 245 of 287 ability attributes never specified  (85%)

Port Azure VC is a sketch. Ari has five attributes, Oren has two, Vale has three;
everything else on that side -- `tempo_control`, `hand_control`, `composure`,
`arm_speed`, `court_vision`, `work_rate`, all of it -- is `VolleyballPlayer`'s
class default of 50. Every attribute this engine has learned to read since the
fixture was written reads 50 for one of the two teams.

So the residual `capability` gap, 0.855 against 0.595, is not the engine
modelling one side better. It is one squad written down and the other not. The
same applies to the first-contact gap feeding it (`pass` 0.773 against 0.532),
and to every kill, dig and stuff rate this repository has ever compared by side.

This is not a defect to fix quietly -- deciding how good Port Azure VC is, is a
design act, not a repair. What is done here instead: the probe prints the
specification count above every reading it takes, so no future measurement can be
made without seeing which of the two arms was ever real. The §0 failure in its
other direction -- not a threshold outside its distribution, but a comparison
whose two sides were never comparable.

### Still open

- The dug ball has no apex, so the second contact off a dig is still classified
  by the retired table on both sides. Same work as the pass apex, one contact
  later.
- `approach_quality` at the second contact is 0.07 and 0.03 on the dig paths
  against 0.47 on the pass paths, so a setter taking a dug ball effectively never
  gets to jump. That may be right and has not been measured against anything.
- `SetterCapabilitySystem.command()` reads raw attributes rather than `_rating`,
  so fatigue, form and match confidence move every other term at the second
  contact and not this one.

### The gate, and proof it can fail

`the height a first-ball setter is read against is the height their own pass
delivered, on both sides` compares the SET event's
`setter_capability.contact_height_meters` against the RECEPTION event's
published `set_contact_height_meters`, as an equality rather than a rate -- so
it cannot be satisfied by moving a coefficient. Both reception paths now publish
the pass apex and the contact height they produced.

Checked against a reverted tree rather than assumed: with the thread removed the
same comparison reports **52 matched, 53 mismatched**; with it in place, 105
matched and 0 mismatched. A gate nobody has watched fail is a gate nobody knows
works, and this file records two written in the same sitting that turned out to
be unfailable.

### What it did to the rates

`tools/run_rally_balance_probe.gd`, 700 rallies, both serving sides, after the
thread:

    contacts per rally     5.693   (target above 6.0)
    kill rate              0.433   (0.45 - 0.50)   home 0.471  opponent 0.387
    swing balance          0.814   (near 1.00)     429 against 349
    dig rate               0.482   (0.35 - 0.55)
    stuff rate             0.141   (0.08 - 0.14)
    ace rate               0.059   (0.05 - 0.09)
    serve error rate       0.149   (0.12 - 0.20)
    opponent swing quality 0.371   (0.332 before)

The opponent's offence moved up, which is the intended direction and the reason
the number is recorded rather than assumed. Swing balance 0.766 -> 0.814 and
opponent swing quality 0.332 -> 0.371; nothing left its band that was in one.
Stuff sits 0.001 over the top of its band and kill 0.017 under the bottom of
its; both were already there before this change and neither is chased here,
because the 85% figure above says a side-versus-side rate is not yet a
measurement of the simulation.

---

## The primary blocker is chosen for being near, and the set is no longer fast

Two explanations were on the table for `primary_close` sitting at 1.00 at every
percentile including the minimum: a selection effect where unclosed blocks never
emit an event, or a travel model that is simply too generous.

**Both were wrong, and the answer was one line above where either was looking.**

`tools/run_block_close_probe.gd`, 800 rallies, both serving sides, split by tempo:

    term                     tempo 0   tempo 1   tempo 2   tempo 3
    primary_close              1.000     0.999     1.000     1.000
    assist_close               0.937     0.781     0.978     0.999
    primary_lane_delta_m       1.036     0.625     0.852     0.497
    assist_lane_delta_m        1.844     2.946     2.342     3.353
    primary_required_s         0.617     0.290     0.389     0.217
    assist_required_s          0.939     1.299     1.053     1.521
    usable_s (both)            0.963     1.264     1.556     1.753
    set_flight_s               0.714     0.987     1.214     1.471
    preset_credited_s          0.717     0.655     0.704     0.730
    assist_closed_fully        0.647     0.651     0.926     0.988
    swings                        17       195       366       173

    attacks 843, of which 751 carried a block formation (89.1%)

### 1. The saturation is a tautology, not a defect

`_form_home_block` selects its primary as *the front-row blocker whose slot is
nearest the attack lane*. That blocker has a mean lane delta of 0.5-1.0 m and
needs 0.22-0.62 s to cover it. Asking whether the nearest blocker got there is
asking a question with one answer.

The blocker who actually travels is the **assist**, at 1.8-3.4 m. So the stuff
gate's `primary_close >= 0.78` is not a threshold outside its distribution in the
§0 sense -- it is a threshold pointed at the wrong blocker. Neither of the two
recorded hypotheses was right, and 89.1% of attacks do carry a formation, so
there is no selection effect to speak of either.

### 2. The dynamic exists; nothing reads it

`assist_closed_fully` runs 0.647 at tempos 0 and 1 against 0.926 and 0.988 at 2
and 3. The middle genuinely fails to seal on a fast ball -- the payoff the whole
set-height and tempo line of work was for. It is recorded in a field the stuff
gate does not consult.

### 3. The set did get slower, and it was this work that did it

Three readings of the same quantity exist in this repository:

    tempo    2026-08-05    in-code note    now
    0                --           0.204   0.714
    1             0.376           0.392   0.987
    2             0.554           0.426   1.214
    3             0.806           1.006   1.471

`_set_arc` used to solve a level-ground launch from an angle table. Since the
set-height work it solves `BallFlightModel.duration_for_apex(release, contact,
apex)` with `apex = hitter contact + SET_CLEARANCE_BY_TEMPO`, so the flight is
now two gravity legs. Measured for Mira setting Tala -- release 2.19 m, hitter
contact 2.86 m, a rise of 0.67 m:

    tempo   clearance   rise_s   fall_s   total_s
    0            0.15    0.408    0.175     0.583
    1            0.60    0.508    0.350     0.859
    2            1.30    0.633    0.515     1.149
    3            2.20    0.765    0.670     1.435

**The honest reading is not that the set was nerfed. It is that the old numbers
were physically impossible and nobody noticed.** A ball cannot rise 0.67 m in
0.204 s under gravity; it needs 0.37 s. The old table never had to lift the ball
at all, so it could report any duration it liked, and the block was calibrated
against those durations. When the set became gravity-true, nothing re-fitted the
block.

### 4. And two thirds of a second is credited before the ball exists

`preset_credited_s` is 0.655-0.730 s at **every** tempo. Whatever tempo does to
the flight, it cannot touch this half of the budget, and this half is roughly as
large as a first-tempo set's entire flight.

### What this makes the next work

Not a coefficient. Three separable things, in the order they should be taken:

1. **Gate the stuff on the blocker who travelled.** `primary_close` answers a
   question about the blocker chosen for being near. Whatever the wall's timing
   gate reads, it should be the assist's close or the pair, not the primary's.
2. **A quick set is not struck on the way down.** `duration_for_apex` charges a
   full fall leg -- 0.175 s at tempo 0, 0.670 s at tempo 3 -- for a ball the
   hitter should be able to meet at or before the apex. The clearance is what a
   *high* ball needs; a quick does not need to be cleared at all.
3. **Re-fit the pre-set window against the gravity-true set.** It was set when a
   first-tempo ball nominally arrived in 0.204 s and has not moved since one
   arrives in 0.714 s.

Recorded rather than done, because all three change the block's rates together
and fixing one alone would be measured against the other two.

---

## The cognition layer, and two names that could never fire

All nine steps of the cognition handoff. Four unwired foundations become a layer
the rally carries, and the build found four defects the way this repository
usually finds them -- by printing a distribution rather than by reasoning about
one.

### `misread` is a magnitude, not a flag

`_setter_option_terms` returns `misread` as `stable_noise * (1 - judgment) *
0.22` -- a signed size. The compiler's first version read it as a boolean, and
`bool()` of any non-zero float is true, so **182 of 182 options across 120
rallies came out misread** and every setter would have been drawn equally unsure
of everything. Read as a magnitude it has a real range: judgment sits at 0.855
for the slice's setter, so |misread| tops out at 0.032 and separates two options
by about a tenth of certainty.

### The option list lives in two different places

The home side publishes `option_evaluation` on its `SET_DECISION` event; the
opponent publishes it on the `SET` event. Read in the compiler so neither
renderer learns the two sides disagree. The asymmetry itself is still open.

### `Dime` and `Telegraphed` both asked `primary_close`

The action vocabulary's two set names ask the same question -- did the wall get
there? -- and both asked it of the field that cannot answer. Measured over 800
rallies before the correction:

    Dime           0 occurrences
    Telegraphed  240 occurrences, 20.5% of every name in the game

`Dime` is the draft's own most important entry: "the one name that credits a
player for a point they did not score, which is the whole reason setters are
interesting." It was unreachable, and its opposite was the most common thing
that happened, both because the primary blocker is *selected* as the front-row
player nearest the lane and therefore always arrives.

Pointed at `assist_close_attempted` -- the travelling blocker, before the 0.34
cut that zeroes it -- `Beaten by tempo` becomes reachable and `Telegraphed`
falls to 19.0%. **`Dime` is still zero**, and that is now a true statement about
the simulation rather than about the field: the assist seals 93% of walls, so a
set almost never isolates a hitter. Same finding as the block-close probe, from
a second instrument. Not chased with a threshold.

### The budget's third target was measuring the wrong noun

The draft asks for "the share of *points* whose decisive **event** carries a
name". The probe measured whether `decisive_actor_id` was named -- but the actor
credited with a point and the actor of its last contact are different players on
a stuffed swing, on opposite sides of the net. Corrected to the final contact,
the figure moves 34.6% -> 52.5% with no change to the budget at all.

### Where the vocabulary sits against its own targets

    rallies with at least one named action    88.6%   target 40-60%
    named actions per rally                    1.44   target ~1
    points whose decisive contact is named    52.5%   target high
    names offered before the budget            1839
    names kept                                 1155

Two of three are out of band and the threshold was **not** moved to fix them.
The draft says why: "playback thresholds cannot be finalised until the block
rate is calibrated and the vocabulary is in." `Telegraphed`, `Got tooled`,
`Roof` and `Swung into the block` together are 55% of all names, and every one
of them is a block outcome. The block's rates are the input, not the labels.

### What the layer is, in one paragraph

A cue is semantics and never a picture. `CognitionCompiler` is the only thing
allowed to read `option_evaluation`, `primary_close_terms` or any `shadow_*`
dictionary; `CognitionBadge` holds every meaning; the tactical board rasterises
it into arcs and the 3D billboard picks a glyph, and neither has a rule of its
own. A blocker's believed lane is where they actually travelled, never the lane
the attack used -- a blocker who read it wrong points at the wrong place, which
is the behaviour worth showing. Cues sample the rally's physical clock rather
than the animation's progress, so 0.5x and 2x show the same thought at the same
point of the rally. Reactions write nothing: `match_confidence` remains the
post-point system.

### Two gates that failed usefully before they passed

The determinism check failed against a re-used manager -- the same seed later in
a match is a different rally by design -- which is the gate catching the test.
The stagger check failed until it was scoped to home walls: every Port Azure
player sits on the default anticipation of 50, so two opponent blockers derive
the same reaction delay and genuinely recognise together. Including them would
have made the gate a measurement of the fixture.

Home walls stagger by **0.018 s**, which is real but invisible. Both home
middles carry nearly the same anticipation, so the gate asserts the mechanism --
distinct per-blocker delays reaching the cue -- rather than a visible spread.

### Still open

- `Dime` needs the block budget re-fitted before it can fire. Same three repairs
  the block-close probe already named.
- The vocabulary's naming threshold is unchanged and out of band, deliberately,
  until the block rate is calibrated.
- `SET_DECISION` versus `SET` for the option list is read around, not fixed.

---

## The cognition clock was one leg behind, and the badge needed a legend

Three defects in the 2D cognition layer, all reported from watching it rather
than from measuring it, and the third is the one that mattered.

### The badge was drawn at the size of a voli

Radius 11 px against a player marker drawn at radius 20 -- over half the thing
it annotates. A note in the margin has to be smaller than what it is a note
about. Now 6.5, hanging 26 px up rather than 34, with punctuation at 11 pt
rather than 15.

### A shape vocabulary is a legend, and a board that needs one has failed

Reported plainly: "it is unclear what each one means". The eye, the outline and
the colour together say *how* a voli is thinking and never say *what about* --
a yellow diamond is a committed passer, and there was no way to know that from
the mark. Every state now carries its own word: `READ`, `SEES`, `CHOOSING`,
`CALL`, `COMMITTED`, `BLIND`, `REACTS`. Volleyball words where the sport has
one. Ball-tracking is filtered before anything is drawn, so only a few badges
are ever live at once and this stays a label rather than clutter.

### The clock was one leg behind on every ball flight

**"Sometimes the blockers start moving BEFORE the red icon appears."** They did,
and it is a real bug rather than a reading difficulty.

Playback has two kinds of leg. A contact drawn in place resolves *at* its own
stamp. A ball flight draws the ball travelling from this contact to the **next**
one, so the physical window it depicts is `[this event, next contact]`. The
first version advanced one clock per event, at the top of the loop, from the
previous event's stamp to this one's -- correct for the first kind and one whole
leg behind for the second.

Most legs are the second kind. So the blockers were animated closing during the
set's flight while the badges were still showing the reception, and the
recognition cue arrived a leg late, after the movement it explains. The clock
now advances inside each branch with that branch's own window.

Worth stating as a general shape: the layer sampled physical time correctly and
mapped it onto the wrong window. Both halves have to be right, and only one of
them was checked.

---

## The blocker sticker could walk onto the other court, and two of them could not be picked up

Three defects on the training clipboard, reported from using it.

### A blocker's depth was a free coordinate, and the axis runs through the net

The worksheet's y axis is metres from the net, **negative across it** --
`PHASE_DEPTH["Block"]` starts at -1.4 precisely so a blocker's hands over the
tape are visible. In the three-quarter view "up" the screen is toward the net
and past it, so dragging a blocker the way any reader would read as *higher*
carried them through y = 0 and onto the opponent's side.

The visible symptom was the second-order one: the behaviour arrow draws from the
body, so a blocker standing on the far court drew their soft-block or kill-block
instruction back toward home. That reads as a defect in the trajectory and was a
defect in the coordinate.

Depth is not a decision the Block phase asks about -- a block is a lateral
choice, which lane and sealed or funnelled -- so a blocker's y is now **pinned**
to 0.35 m rather than bounded. Every blocker on the sheet stands on one line and
a wall reads as a wall. This is the only place on the worksheet that clamps
instead of refusing, and it earns it: refusing a depth nobody meant to choose
would just make the drag feel broken.

### Two volis nobody placed and nobody could remove

`_draw_blockers` drew a fixed pair from the squad's first two entries as part of
the Block phase's *printed* diagram, not as placements. The shadow handle only
finds entries in `placements`, so those two were unreachable by every gesture
the sheet has -- there was no way to move them, no way to take them off, and no
indication they were different in kind from a voli you had dropped yourself.

Gone. The net, its zones and the drill marks are the printed part; every body on
the sheet is now one somebody put there.

### The remove gesture was a secret

Taking a voli off is done by dragging them off the sheet, and nothing said so. A
gesture whose only documentation is that somebody tried it is not a gesture. The
worse reading is the likely one: a voli that will not go where you want reads as
the sheet being broken.

The edge now lights while a voli is in hand -- faint over the court, burning
past the same bound the drop checks, so the page answers before the hand
commits. Two states rather than one, because "you can let go here" and "letting
go here removes them" are different sentences. Said once on the crossing rather
than from the draw pass, since `_say` queues a redraw and saying it while
drawing would redraw every frame for as long as a voli was held.

### Still open: the sticker gestures need a pass of their own

Reported as "sticker behaviour in general seems buggy", and not chased here
because the three above were specific and this is not yet. What is known:

- `_crowded` refuses a drop within `PLACEMENT_CLEARANCE_M` of another voli and
  says so, but the held voli springs back to where it started, which reads the
  same as a drag that failed.
- A drop is refused rather than clamped when it lands off the court by less than
  the removal bound, so there is a band where a drag neither places nor removes.
  The comment on `place_voli_at` argues for this deliberately; the edge glow now
  covers half of it, and the other half -- a near-miss inside the court -- still
  has no feedback.
- Grabbing selects, which is right, but there is no way to *deselect* without
  placing something, so the behaviour rail keeps acting on the last voli touched.
- Nothing is measured. There is no probe over placement, so every statement here
  is from use rather than from a distribution -- which is exactly the shape this
  file warns about, and the first thing the pass should fix.

---

## Three asks, and what the code already says about each

Recorded for later rather than built. Each one was checked against the tree, so
the entry states what exists rather than assuming nothing does.

### Fatigue is one linear multiplier, three times over

**Asked:** fatigue should not be a linear loss of attributes that leads straight
to big mistakes. At least three stages -- *tiredness*, then *forced errors*,
then *unforced errors* -- reading as (1) a small reduction across broad
attributes, (2) a loss in work rate and effective range (explosiveness, jump
capacity), and only then (3) major mistakes. The attribute loss should be
slightly logarithmic, mental as well as physical. And it should be visible for
home volis somewhere.

**What exists.** Three separate linear applications and nothing else:

    rally_simulator.gd:11137   raw_rating * (1.0 - fatigue * 0.18)
    volleyball_player.gd:388   lerpf(1.0, 0.78, fatigue)      -- in-system band
    volleyball_player.gd:586   leap * (1.0 - fatigue * 0.35)  -- jump reach

So the shape asked for is genuinely absent. There is no staging, no curve, and
no separation of the physical from the mental -- `_rating` applies the same flat
0.18 to `composure` as to `explosiveness`. The two extra terms happen to sit in
roughly the right *place* for stage two (reach and the in-system band), but they
fire at the same time as everything else rather than after it, so a tired voli
loses a bit of everything at once, which is exactly the reading the ask is
trying to get away from.

Worth stating before anyone builds it: at maximum fatigue the total attribute
cost is 18%, and a stage that arrives at 70% fatigue therefore has about five
points of rating left to spend. **The stages need the ceiling raised or they
will be three thresholds cutting a range too narrow to hold them** -- the §0
failure, in advance for once. Measure the live fatigue distribution first: if a
match never drives a voli past 0.4, stage three is unreachable whatever it is
set to.

Visibility: fatigue is on the journal's voli page and the clipboard's squad
sidebar, both as a percentage. It is nowhere in Match Centre and nowhere on the
court, which is where it would actually be read.

### A tired animation, and actions that fail because of it

**Asked:** a tired animation or a set of them; volis track how far and how fast
they must move for an action, and at some fatigue level the action -- closing a
block, running an approach, chasing a feint -- fails outright.

**What exists.** The travel half is already there and is not being used for
this: `RallyMovementSystem.traversal_seconds` answers "how long does this voli
need" for every phase, and the block close, the approach and the floor defence
all already compare it against a budget. What is missing is that fatigue does
not enter that comparison at all -- it moves ratings and reach, never the
traversal. So a tired voli currently covers ground exactly as fast as a fresh
one and simply plays the ball slightly worse when they get there.

Wiring fatigue into the traversal is the whole of the ask's second half, and it
would make actions fail on their own -- a close that no longer fits its window
is already handled everywhere as a close that did not happen. No new failure
path is needed.

No tired animation exists. `player_actor_3d.gd` has no idle variation of any
kind, which is the same gap `Sleeping poses` names from the other end.

### Body facing is not driven during playback at all

**Asked:** it is hard to tell whether head and body facing is even happening.

**It is not, and this is a straightforward finding rather than a design
question.** `has_facing` and `facing_yaw` are set in exactly three places:
`_turn_toward` inside the actor, and the two offline tools
(`run_voli_portfolio.gd`, `run_animation_frames.gd`). Neither
`match_court_3d.gd` nor `match_screen.gd` sets them, so during a rally an actor
only ever turns when something calls `_turn_toward` -- which the contact poses
do, at the moment of contact, and nothing does between contacts.

So a voli holds whatever heading their last contact left them with for the whole
rally, and a voli who has not touched the ball yet has no heading at all. The
machinery is complete and correct -- `FACING_TURN_RATE`, the 62-degree neck
limit, `look_toward` for the head independently of the body -- and nothing is
driving it.

The cheapest honest fix is the one the cognition layer already half did: it
turns the head toward a cue's attention target through `look_toward`. The body
wants the same treatment from the movement it is already doing -- a voli
travelling has a heading, which is their velocity, and that is a fact playback
holds every frame and currently discards.

---

## The VFX pass, nine steps

Every item came from a frame strip or from a measured distribution rather than
from reading the code, which is why several of them were not what they looked
like.

**1. The ball decides the platform.** `platform_yaw` was a constant per posture
and `contact_direction` reached only the recovery, so every square pass had
identical forearms. `PlatformAim` bisects the incoming and outgoing flights --
where the normal of a rebounding surface is -- and both are already on the event.
Pitch off the same normal. Derived in playback rather than in the resolver: the
resolver owns where the ball goes, it simply never said where the arms were.

**2. The geometry votes on posture.** `reaching` fires on 0.0% of receptions and
`off-axis` on 2.5% of digs, both thresholds outside their distribution. A body
that gave up more than a degree of platform was not square whatever the
alignment term said, so the residual is a second opinion taken when it is more
specific.

**3. The recovery has its own clock.** It ran on the approach's phase, so a voli
started going to the floor while still travelling to the ball.

**4. The roll was there all along.** Correcting my own earlier claim: the
112-degree roll always reached `body_pivot.rotation.z`. What made it read as a
tumble is that the legs folded in the first third, so the body balled up before
it rotated.

**5. The chin tucks**, which is both the fix for the head passing through the
torso and the correct technique.

**Then the roll was rebuilt from the technique** rather than patched: arms lead,
platform breaks, load on the lateral line -- hip, glute, back, shoulder -- with
elbows and knees kept clear, core stable until after impact, trailing leg and
shoulder turning together, legs and core returning upright. Seven overlapping
bands and a full 360, because the roll ends on the feet.

**6-7. The surge was anchored at the pelvis and cut rather than faded.** A crush
and a monster block are defined by the hands; both were drawn as a sphere at the
hips with a ring at the shoes. The burst now sits at the contact -- derived from
the rig's reach and the jump the body is already carrying -- rings and streams
travel to it, and the fade runs to the end of the pose instead of reaching zero
at 0.78 while two frames of swing remained.

**8. The block does jump**, and always did. The strip was posing every frame at
elevation 1.0, so eight identical heights read as a blocker who never left the
floor. Elevation now comes from `BlockBiomechanics.elevation_at` the way
playback drives it.

**9. Facing was never driven during playback.** `has_facing` and `facing_yaw`
were set in three places: the actor's own `_turn_toward`, and the two offline
tools. A voli turned only at a contact and then held that heading for the rest
of the rally. A moving body's heading is its velocity, which
`set_player_position` already held every frame and discarded.

### Two defects in the instrument, both found because the strips stopped making sense

The recovery strips passed `posture = "diving"`, which matches no branch, so the
body never entered a dig -- eight frames of a standing figure collapsing were
read as the animation being wrong. And `fall` is two motions: planted and
off-axis roll sideways, moving and reaching slide forward. Only the first is the
dive roll. They are rendered separately now, and every strip starts at phase
-0.34 so a row reads approach -> contact -> recovery.

### Honest residuals

- At the top of the turn the body reads as briefly airborne: the 360 rotates
  about a pivot the floor solve does not track through a full turn. A stylised
  roll rather than a solved one.
- The platform aim is drawn, not simulated. A pass still lands where the
  resolver said; the arms merely stop contradicting it. If the two ever need to
  agree the other way, that is a resolver change and a much larger one.
- `PlatformAim.posture_for` overrides the recorded posture for *drawing* only.
  The simulator's two dead branches are still dead where they are scored, and
  the reach-margin finding -- receivers arriving with 3.1 m to 4.8 m of spare
  reach -- remains untouched.

---

## Receivers arrive exactly on the ball, and that is why nobody ever reaches

Three candidate causes were on the table for `reaching` firing on 0.0% of
receptions -- a global range nerf, a platform-specific nerf, or receivers
micro-positioning too well. It is the third, and it is a single line.

    func _reached_point(mover, start, target, available_time, mode) -> Vector2:
        ...
        if _movement_time(mover, start, target, mode) <= available_time:
            return target

**A receiver with any spare time at all arrives dead on the landing point.** Not
near it -- on it. And the measured reach margin says 90% of receptions have at
least 1.7 m of spare travel, so this branch is what almost every reception takes.

The consequences follow from that one return:

- The platform is never off-centre, so there is nothing to reach for.
- `reach_margin` measures spare *travel capacity* and never spare *accuracy*,
  which is why closing the acceleration defect moved it 3.72 m to 2.59 m and
  still left `reaching` at zero.
- `PlatformAim`'s residual -- the part of the platform a body cannot square up
  to -- is structurally near zero on a reception, because the body is standing
  exactly where the ball is going.

### The case for the change, in the sport's terms

A passer entering a seam or stepping into the ball's path is reacting to where
the ball is *heading*, not to where it will land, and they commit before they
know. Add the ball's own variance, and add that a server can partly see the
receiving formation and aim between people. The ball is not going to be exactly
where the passer wanted it.

So the honest model is that a receiver arrives at a point *near* the landing
point, with the error growing from time pressure -- and the residual offset is
what forces a reach. That is also the term the drawing already wants: an arrival
error feeds `PlatformAim` directly and would make the off-axis and reaching
postures geometric facts rather than dead thresholds.

### Why this is recorded and not built

The branch is already red on one gate from the acceleration fix, and this change
would move every reception rate in the game on top of that. Two large
simulation changes stacked before either is measured is the specific mistake
this file logs most.

The order it wants: close the red gate, take a fresh balance baseline, then add
the arrival error as its own change with its own measurement.

### What to measure first, before choosing any coefficient

The distribution of *spare time* at the reception -- `available_time` minus
`_movement_time` to the landing point. The arrival error should scale with how
little of that there is, and that distribution decides the scale. Picking a
constant offset first would be a threshold chosen before its distribution, which
is §0 and is what produced the two dead posture branches in the first place.

---

## The red gate: a defensive identity has no way to lower its attack error

`defensive attack lowers both error risk and terminal pressure across six career
seeds` went red after the reach-acceleration fix. Diagnosed rather than adjusted.

### It is a real inversion, not noise

    48 samples   attack error   defensive 0.0843  physical 0.0806   INVERTED
                 kill rate      defensive 0.5796  physical 0.6086   ok
    96 samples   attack error   defensive 0.0828  physical 0.0791   INVERTED
                 kill rate      defensive 0.5808  physical 0.5948   ok

The gap is -0.0037 and -0.0036 across a doubled sample. The kill-rate half still
holds; the error half is stably wrong.

### The mechanism that should produce it never fires

`decisiveness` reaches the attack twice and only one of them touches error:

- `_attack_effectiveness` scales quality by 0.85-1.15, but `attack_missed` reads
  `result.attack_quality`, the *unmultiplied* figure. That is deliberate and its
  comment says so -- decisiveness prices what a ball does after it lands in, not
  whether it lands in.
- `_identity_hit_type` substitutes a controlled roll or a tip when
  `decisiveness <= 0.30 and (set_quality < 0.48 or arrival_margin < 0.05)`. A
  safe shot misses less, so **this is the only path to error.**

Measured with `tools/run_identity_shot_probe.gd`, 200 rallies per identity, with
the resolver confirmed to be reading `decisiveness = 0.18`:

    Defensive   _identity_hit_type returned:
                High-ball swing 129, Pipe attack 27, Quick attack 29
    Physical    Power swing 43, Tempo swing 48, Pipe 27, Quick 29, High-ball 38

    safe shots (roll/tip):  Defensive 0.0%   Physical 0.0%

**Zero.** The identity is applied, the upper branch fires -- Physical converts 43
tempo swings into power swings -- and the lower branch never does. So a Defensive
side hits exactly the same shots as anyone else and there is no mechanism by
which its error rate could be lower. The gate asserts a property the engine
cannot produce.

### Why now

The trigger needs a bad ball: set quality under 0.48 or a hitter arriving inside
0.05 s. Home first-ball set quality now sits at 0.708 after the roster mirror and
the pass-height work. The condition was not written for a side that passes and
sets this well, and it has quietly gone out of reach -- the same shape as the
other five dead branches in this file, arrived at by improvement rather than by
a bad constant.

### The choice, which is a design call rather than a repair

1. **Widen the trigger** so a cautious side plays safe more often. Cheap, but it
   is choosing a threshold, and the distribution of `result.set_quality` and
   `hitter_arrival_margin` *at that call site* has to be printed first or it is
   §0 again.
2. **Give decisiveness a continuous effect on error** rather than a discrete
   substitution -- let it move the error threshold directly, the way it already
   moves effectiveness. More robust, and it stops the property depending on how
   often a bad ball happens.

Recorded rather than chosen. Option 2 is the better design and the larger
change; option 1 is honest only after the measurement it needs.

---

## Option 2, attempted and inert: the geometric resolver owns the error

Commitment now shifts the attack's error threshold continuously -- a side that
swings at everything asks more of each swing than one that picks its moments --
which is the design that stops the property depending on how often a bad ball
happens.

**It does not fix the gate, and the measurement says so plainly.** The identity
calibration came back byte identical: 0.0843 against 0.0806, the same four
decimals as before the change.

The reason is three lines below the call site:

    var attack_missed := _attack_missed(quality, decisiveness)
    if not geometric.is_empty():
        attack_missed = bool(geometric.attack_missed)

A geometric swing is struck along a course at a speed and lands where it lands,
so the resolver decides the error and the threshold applied afterwards is
discarded. That is the ordinary path for almost every attack in the game.

**Failure mode #1 -- a value computed and dropped -- walked into while fixing a
dead branch, in the same session that found four others.** The parameter is kept
because it is correct on the fallback path, and it is commented with what
overrides it rather than left to look effective.

### Where the repair actually goes

A geometric swing lands in or out from its own course and speed. Commitment has
to move something `GeometricAttackResolver` reads -- the aim tolerance it is
allowed, or the speed it is struck at -- so that a committed side genuinely hits
harder at tighter targets and misses more. That is a change inside the resolver
rather than a wrapper around it, and it wants the distribution of the resolver's
own margin printed first.

Until then the gate stays red and should stay red: it is asserting a real design
property that the engine cannot currently produce, and silencing it would hide
exactly the thing worth knowing.

---

## Two design asks, recorded

### Collisions, and being in the way

Floor defence currently resolves each defender against the ball independently:
`choose_claimant` scores every candidate and the best one plays it. Nobody is
ever obstructed by a team-mate, nobody has to avoid one, and two volis can
occupy the same ground without consequence.

Wanted: bodies that get in each other's way. A defender's path crossing another's
should cost time or the ball; a passer standing between the server and the
intended receiver should matter. The seam-conflict penalty that exists today is
the nearest thing and it is a scoring adjustment rather than a physical fact --
two players *claiming* the same ball, not two players *colliding*.

This interacts with the arrival-error work above: once a receiver arrives near
rather than exactly on the ball, two of them arriving near the same ball is the
case where collision starts to mean something.

### The libero may not attack over the net

Real rule, and currently unenforced: a libero cannot complete an attack hit if
the ball is entirely above the height of the net. `_fallback_hitter`,
`_choose_assignment` and the opponent's hitter selection all pick from the
front-row and eligible lists without checking the role, and `RotationLineup`
already prevents a front-row libero -- but a back-row libero can still be
selected for a Pipe swing.

Worth doing as a rule rather than as a weighting: it is a legality constraint,
so it belongs beside the existing rotation validation rather than as a
discouraging term in the selection score.

---

## The spike goes through the net -- and the block leg was innocent

Reported from playback: "spike goes through the net and blocker".
`tools/run_ball_flight_probe.gd` found it, and `tools/run_block_leg_probe.gd`
was written to say which of three candidate mechanisms it was. Fixed; kept
because the wrong diagnosis is more instructive than the right one.

    height at the tape, metres (net is 2.43)
    leg                 n     mean     min    below tape
    Attack -> Block   205     2.59    0.74        43        <- before
    Attack -> Block   250     3.14    2.36         6        <- after

### The diagnosis that was wrong

The first reading, from the summary alone, was that the to-block leg was drawn
from the hitter's contact down to the floor instead of ending in the blocker's
hands -- every one of the worst five ended at 0.12 m, which is the floor
constant. Plausible, and wrong. Splitting the same 205 legs by whether the block
actually touched the ball settles it in one table:

    re-sliced at the block (it touched)    91 legs,  2 under the tape
    left whole (the block missed)         114 legs, 41 under the tape

`_truncated_arc` was doing its job. The legs that end in a blocker's hands were
already fine; the ones going under the tape are the swing's *own* flight, drawn
whole because a block that misses does not shorten anything. The 0.12 m endings
were the floor target those swings were correctly aimed at.

A total cannot tell two populations apart. This one hid a 2-in-91 defect inside
a 41-in-114 one and pointed the fix at the wrong file.

### The three defects that were actually there

**1. The drawing threw away the resolver's certified launch angle whenever it
pointed up.** `_swing_arc` carried `vertical_angle_degrees` only when it was
`<= 0.0`. `_feasible_launch` reaches for a lofted root *only* when no driven one
clears the tape, so the guard excluded exactly the branch that needed it: all 26
lofted swings were certified over the net, all 26 were drawn at a mean of -18.4
degrees, and 23 of the 26 were drawn through it. The bound had been added to hold
down an unrelated number (untouched attacks at the tape, 2.69 m -> 5.19 m), which
is §0 twice -- a limit placed on the drawing to correct something the resolver
had decided.

**2. The loft itself was a punt.** With the drawing no longer flattening them,
the lofted swings could be measured for the first time: **mean apex 9.34 m**,
mean height at the tape 7.82 m, on 15% of all attacks. For a fixed range there
are only two angles that carry the ball, and the lofted root is the high one --
the faster the swing, the closer to vertical. The search took the first loft it
met and the sweep starts at full pace, so it always took the steepest one
available. `_flattest_clearing_loft` now takes pace off within that decision
until the arc stops clearing: apex 9.34 m -> 3.96 m.

Deferring the whole loft to the end of the relief sweep was tried first and is
worse -- a slower driven root is a *higher* one, so it swallowed every roll shot
in the game and the lofted branch went to 0 of 232. One dead branch for another.

And a serve must not be softened at all: pace is the tactical instruction there,
and flattening made risk 0.0 / 0.5 / 1.0 come back at 11.68 / 11.18 / 11.39 m/s
-- not compressed, non-monotone. `may_soften_the_loft` is false for serves.

**3. The opponent lost its record entirely.** `_swing_arc` was handed
`_trace_summary()["geometric_attack_opponent"]` -- the same dictionary stored
four lines earlier, except the store is conditional on `shadow_reception_trace`
and that is null on any path with no trace. Split by side, the tell is
unmistakable:

    home/lofted        16 swings, angle carried on 15,  0 under the tape
    opponent/lofted    19 swings, angle carried on  1, 14 under the tape

Both records were in hand as locals at the call sites. Failure mode #1 again:
computed correctly, dropped before anything could use it, re-derived worse.

### What it moved

    Attack -> Block below the tape   43 of 205  ->   6 of 250
    worst crossing                      0.74 m  ->  2.36 m  (tape is 2.43)
    Attack -> floor below the tape    2 of  24  ->   0 of  22

The six that remain are all within 7 cm of the tape, which is a different order
of problem from a ball 1.7 m under it.

### The balance cost, which is real and not yet paid

    contacts per rally    5.874 -> 6.657   (into band, was failing)
    kill rate             0.486 -> 0.374   (out of band, was passing)
    dig rate              0.400 -> 0.593   (out of band, was passing)
    home / opponent kill  0.433 / 0.542 -> 0.368 / 0.381

The asymmetry closing from 0.109 to 0.013 is defect 3 being fixed, and is the
result worth having. The rest follows from 15% of attacks now flying as the
resolver always said they did: a roll shot is slow and high, so it is dug, and
rallies are longer.

**The bands were calibrated against a game that mis-flew those swings**, so they
are the next thing to check rather than the evidence that this is wrong. Do not
tune the kill rate back up by changing the launch model -- re-measure what the
band should be, then look at whether 15% of attacks *should* be roll shots.

### Left over, unrelated, noticed in passing

`resolve_serve`'s certified launch comes back at 74-81 degrees -- a ball hit
nearly straight up -- and the serve's in/out is resolved on that flight. It
predates all of this and the drawn serve is unaffected (`Serve -> Reception`
sits at 3.33 m at the tape, byte-identical before and after), so the two
descriptions of a serve disagree somewhere. Worth a probe of its own.

---

## The red identity gate: commitment bought speed and never paid for it

`_test_team_identity_directional_outcomes` asserts that a Defensive attack makes
fewer errors *and* fewer kills than a Physical one. The kill half held; the error
half was inverted -- 0.0642 for Physical against 0.0868 for Defensive, so the
game said swinging harder was **safer**. Fixed.

### Why the two earlier attempts did nothing

`ATTACK_COMMITMENT_ERROR_SHIFT` moved a threshold inside `_attack_missed`, three
lines before `attack_missed = bool(geometric.attack_missed)` overwrote it. The
calibration came back byte-identical, which is how it was caught.

The reason no threshold there can work: a geometric swing lands in or out from
its own course and speed. Decisiveness reaches that swing through exactly one
channel -- `aggression_from` biases `chosen_fraction`, which becomes the ball's
speed -- and speed only ever *helps* a ball stay in. A faster swing is flatter,
clears the tape more easily, and reaches its target without needing to be
lofted. Nothing anywhere charged a hitter for swinging near their own limit, so
the design's central claim about commitment had no mechanism behind it at all.

### The distribution first

`chosen_fraction` was published by `choose_power` and read only for a label, so
`tools/run_commitment_probe.gd` had to put it on the event before it could be
measured. Over 657 live home swings:

    identity      p10     p50     p90     mean
    Physical    0.466   0.860   1.000    0.800
    Balanced    0.365   0.764   0.929    0.715
    Defensive   0.299   0.676   0.843    0.637

A gap of 0.164 in the mean, across a range that genuinely spans 0.30 to 1.00 --
so a cost anchored inside it can reach, which is the question §0 says to ask
before writing the bound rather than after.

### The bound, and the version of it that was wrong

`AttackPowerModel.commitment_spread_multiplier` widens the swing's execution
spread from 1.0 at the median swing (0.72) to 1.60 at a swing with nothing left
over. It multiplies `AttackCourseModel`'s across-body strain rather than
replacing it: being turned back across yourself and swinging at your ceiling are
two independent ways to lose a ball.

The first version also gave a *held-back* swing an accuracy bonus, sliding to
0.78 at the tenth percentile. It looks symmetric and is not -- it handed the
Defensive identity both halves of the claim at once and overshot into the mirror
failure, Defensive kill 0.5383 against Physical 0.5321. Dropping the bonus is
also the better model: swinging softer does not make a hitter a better aimer
than their own attack accuracy, it only stops spending accuracy they have.

    identity     attack error    kill
    Physical           0.0979  0.5305
    Defensive          0.0931  0.5266

Both halves directional. **The margins are thin** -- 0.0048 and 0.0039, and the
kill one is 0.7% relative where the test's own note says 1.4% was the smallest
effect it could resolve at 48 samples. It passes, and it is not a comfortable
pass. If it goes red again from an unrelated RNG shift, the answer is more
samples or a stronger channel, not a nudged ceiling.

### Balance, for the record

    contacts per rally    6.657 -> 6.553
    kill rate             0.374 -> 0.352
    dig rate              0.593 -> 0.608
    stuff rate            0.121 -> 0.125

Wider swings are dug more, so this deepens the same gap the launch fix opened.
Kill 0.352 against a 0.45-0.50 band is now the largest single thing out of
place, and it wants the band re-derived and the dig contest looked at together
rather than either one tuned alone.

---

## Attack quality is compressed and defence quality is not

Asked: is the important mechanism not *who wins a contest* but **how easily each
side can raise its quality at all?** Measured, and the answer is yes, with a
clear asymmetry.

`tools/run_attack_scaling_probe.gd`, re-run after the pace and dig work:

    quality      n   error   stuff  tch>dug tch>kill  cln>dug cln>kill anytouch
    0.20-0.30    24   0.083   0.208   0.000    0.167    0.333    0.208    0.375
    0.30-0.40    92   0.130   0.098   0.065    0.098    0.250    0.359    0.261
    0.40-0.50   174   0.057   0.052   0.109    0.115    0.270    0.397    0.276
    0.50-0.60   155   0.084   0.052   0.103    0.090    0.135    0.535    0.245
    0.60-0.70    20   0.100   0.050   0.050    0.100    0.200    0.500    0.200

Kill rate climbs 0.375 -> 0.625 across the range, so good attacks *are* rewarded
and the cliff the old table showed is gone. But look at the `n` column rather
than the rates: **465 swings, and 20 of them clear 0.60.** The distribution is
a hump centred on 0.45-0.55 with almost nothing above it.

Against that, from `tools/run_dig_contest_probe.gd`:

    attack effectiveness   p10 0.369  p50 0.490  p90 0.774
    defence quality        p10 0.127  p50 0.691  p90 0.952

The defender's own range is **0.83 wide** between the tenth and ninetieth
percentile; the attacker's is **0.41**. Twice as wide, and the defence reaches
both ends -- a defender genuinely can be nearly helpless or nearly certain,
while an attacker is almost always somewhere in the middle.

### Why, and it is not a tuning constant

An attack's quality is the product of a chain the hitter mostly does not own:
the pass, then the set, then the tempo the setter could actually run, then the
approach that pass left time for, then the wall in front of them. Each is a
fraction under 1, and a product of five fractions cannot reach its own ceiling
-- the same compounding that made a 30 m/s ceiling produce a 12.6 m/s spike.
A defender's quality is capability times *one* opportunity term.

So the ceiling an A-tier attacker can reach is not set by how good they are. It
is set by how rarely all five gates open together, which is what "the A tier
attacker might never have that clear shot" describes exactly.

### What to do about it

Not to widen the attack's range by scaling it up -- that rewards every swing
equally and is the flat buff this branch has been avoiding. The claim to
implement is **conditional**: when the chain *does* align, the hitter's own
rating should carry further than it currently can. Concretely, the term to look
at is how `attack_quality` composes its factors: a product punishes a single
weak link multiplicatively, so an outstanding hitter off a merely-decent set is
capped by the set. A hitter's own excellence should be able to partially
*rescue* a link, which is what "he made something out of nothing" means and is
the single most recognisable thing a great attacker does.

Measure first: the distribution of each factor in the chain, and which one is
the binding constraint on the swings that land in 0.50-0.60. Widening the wrong
link does nothing, and does nothing silently.

---

## The ball has no life after the last contact

Reported: defenders play their dig *after* the ball has already hit the floor;
the ball changes direction as though it were touched when nobody touched it;
and a ball wiped out of bounds hovers instead of leaving the court. Three
symptoms, and the hypothesis is that they are one absence.

**Every drawn leg is contact-to-contact.** `BallPresentation.display_trajectory`
takes an event and the *next contact*, and the last leg of a rally ends at the
aimed landing point and stops. There is no leg after the final contact, so:

  * a wiped ball stops at the landing point the resolver computed, which is
    where the ball *lands*, not where it ends up -- so it hangs in the air at
    the edge of the court instead of carrying on into the seats;
  * a ball reaching the floor does not bounce, because nothing draws anything
    after the floor;
  * and the "bounce off nobody" is most likely the **DEFENSE-to-SET seam**
    already on this list. The home dig publishes no `outgoing_trajectory` at
    all, so there is no leg from the defender to the setter -- the ball
    finishes the attack's arc at the floor and the next drawn leg starts
    wherever the set begins. A teleport between two legs reads exactly like a
    bounce.

The timing half is separate and also real: `terminate_at_next_contact` returns
early for a contact whose `success` is false, so the *ball* correctly ignores a
defender who never reached it -- while the *actor* is still walked to that
event's `start_position` and posed at its `event_time`. The ball and the body
are then on different clocks, and the body plays a dig at a ball that is
already down. If that is meant to read as "could not react in time" it needs to
look like a failed reach rather than a completed dig.

The fix is one concept, not three: **a ball needs a life after the last
contact** -- a final leg that continues past the landing point, bounces off the
floor with a fraction of its speed, and carries out of the court when it was
going out. Everything above falls out of that.

---

## Jump sets, and sets that visibly go somewhere

Missing, and both are visible rather than mechanical.

A **jump set** is a setter leaving the floor to deliver, which buys tempo -- the
ball is set from higher and travels less far down, so a quick is quicker and the
block has less time to read it. `setter_capability.reach_state` already carries
`jump` and `beyond_reach` as states and `BallPresentation.contact_height`
already reads them for the contact height, so the *decision* exists and the
*height* exists. What does not exist is the pose: a setter never leaves the
floor on screen.

A **directional set** is the other half. A set is currently drawn as a flight
from the setter to the hitter with the setter facing wherever `_turn_toward`
put them, so a back set and a front set look identical apart from where the ball
goes. Real setters are read by opponents precisely on this -- shoulders, hips,
and whether the ball comes off the front or the back of the hands -- and a
blocker's whole job is to see it. The game has a block that reads the set
(`read_quality`) and no visual for the thing being read.

Both belong with `SETTER_DECISION.md`, and both are pose work rather than
simulation work: the numbers are already there.

---

## The world tab: an encyclopedia for things the game never explains

A voli has a body type, a home region, a club region and traits, and the game
explains none of them anywhere. Body types are five produce shapes and six
species; regions carry generation biases; traits are unsurfaced entirely. A
player is expected to read a roster and make decisions from vocabulary the
game has never defined.

Wanted: a **world** tab, sitting beside the journal on the desk, holding an
encyclopedia -- body types and what they are, the regions and what they are
known for, traits, positions, and the terms the rest of the interface uses. It
is a reference object rather than a screen with state, which makes it the
cheapest possible way to make the setting legible.

**Correction, recorded because the wrong version was stated first.** Body type
is *not* cosmetic. `PlayerGenerator.BODY_TYPE_METRICS` shifts height, mass and
wingspan, and `BODY_TYPE_ATTRIBUTES` shifts attribute **ceilings** -- not
starting values, deliberately, so training cannot converge everyone and quietly
evaporate the morphology over a few seasons. Every type sums to zero, which the
comment there says was load-bearing: an earlier pass had every type net positive
and it inflated the generated population against the hand-authored roster.

The confusion was mine and it is worth naming, because the encyclopedia has to
get it right: there are **two** body vocabularies. `PRODUCE_BODIES` in
`body_type_models.gd` -- Tomato, Aubergine, Pear, Stalk, Pepper -- is pure
geometry, a silhouette with a colourway. `BODY_TYPES` in `player_generator.gd`
-- Vegi, Avi, Cani, Feli, Ursi, Simi -- is the mechanical one. Reading the first
and reporting on the second is exactly the mistake an encyclopedia exists to
stop a player making.

    type   height  mass  wingspan   attribute trades
    Vegi      0     0       0       none -- the no-lean body
    Avi      -4    -7      +6       jump_reach, block_timing / reception_stability
    Cani      0    +2       0       stamina, transition_speed, attack_power /
                                    jump_reach, hand_control
    Feli     -3    -4       0       explosiveness, lateral_speed, dig_control,
                                    set_disguise / stamina, tactical_discipline
    Ursi     +1   +11      +1       reception_stability, attack_power, composure /
                                    acceleration, lateral_speed, jump_reach
    Simi     -6    -5      +2       hand_control, ball_control, finesse, tooling /
                                    attack_power, jump_reach

---

## A spike is placed by the body's centre, not by the hand

Reported: the ball should meet the *hand at the apex of the swing*, and
positioning appears to be driven by the model's centre instead.

Consistent with how the rig works. `set_tactical_position` places the actor's
root, `GeometricAttackPromotion.contact_height_meters` answers how high the
contact is, and the two are combined as "this voli, at this spot, contacting at
this height" -- a point on the vertical axis through the body's centre. The
striking hand at contact is nowhere near that axis: `SpikeBiomechanics` carries
the shoulder to -204 degrees with an abduction that takes the elbow *out* as
well as back, so at the contact instant the hand is up, forward, and off to the
striking side by most of an arm's length.

So the ball is drawn arriving at a column above the hitter's navel while the
hand swings through a point half a metre away, and the contact reads as a miss
even when the resolver is entirely right about the outcome.

The fix is a hand *anchor* rather than a height: the actor already computes
every joint of the swing, so it can report where the striking hand is at a given
phase, and playback should place the ball there at the contact instant instead
of at the body's centre at a contact height. `_signature_anchor_height` is the
existing precedent for asking the rig where something is rather than telling it.

Worth checking the same question for the block, the serve and the set, all of
which contact well off the centre line -- a set is played above the forehead and
a block above and in front of the shoulders.

---

## `reaching` cannot be fixed from `_reached_point`, and the serve has a ceiling

Two attempts recorded, one reverted, because both found the same shape of thing
and the shape is worth more than either fix.

### The receiver's arrival error went in the wrong file

`_reached_point` returns `target` exactly whenever the mover has time, so every
defender who can reach a ball reaches its precise centre -- which is why the
`reaching` posture fires on **0.0%** of receptions. Giving it a spare-time-scaled
lateral error is the obvious fix and it does not work, measured: `reaching`
stayed at 0.0%.

The reason is that **`reaching` is classified off `CoverageCalculator`'s
`edge_ratio`, not off where `_reached_point` put the body.** Two descriptions of
the same arrival, and the classifier reads the one the fix did not touch. The
error belongs in the coverage arrival, where the ratio is computed.

It also broke `successful attacks land in while declared misses visibly leave
the intended court`, because `_reached_point` places hitters' approach contacts
too -- moving a hitter sideways moves where their swing starts, and the RNG draw
shifts every downstream stream as well. Reverted rather than shipped: a change
that breaks a gate to achieve nothing is worse than no change.

### The serve's remaining gap is a shape problem, not a constant

Serve pace went 14.7 -> 16.1 m/s across three fixes -- the launch now solves
under the spin gravity it will be flown at, and jump servers now contact at the
height their style implies rather than everyone taking half a leap. Both were
real disconnects. Neither got serves near the 25 m/s a real jump serve reaches.

The physics says why, and it is not a number to raise. Topspin here is a
*constant* addition to gravity, so it pulls the ball down as hard at the start of
its flight as at the end. A serve is struck from about 3 m and has to still be
above 2.43 m eleven metres later; a constant extra 16 m/s squared has taken it
under the tape long before then. Real aerodynamics do the opposite -- drag and
Magnus both scale with velocity, so the ball is barely bent early and dives late,
which is exactly the shape that lets a hard serve clear the net and still land in.

So the honest options are: accept ~16 m/s as this model's serve ceiling and say
so, or make the aerodynamic term velocity-dependent rather than constant. The
second is a real physics addition, but it stays inside the stated philosophy --
it is still *spin*, still chosen by the server, still visible as a dive, and
still attributable to serve technique. What it is not is a hidden global drag
constant, which remains the thing to avoid.

