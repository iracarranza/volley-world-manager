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
  holding `Placeholder3D` is gone from `career_dashboard.tscn`; the Roster
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

### The missing row filter is not reachable — and the home side has no pipe

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
