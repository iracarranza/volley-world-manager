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

## 7. Ball geometry — outcome, position and drawing must become one computation

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

### Not landed — the distance still to go

**Serve in/out is a coin flip disconnected from the drawn ball.** Both serve
paths compute `serve_error := rng.randf() < error_chance` and then draw the ball
to `_serve_landing_point()`, which clamps into the court and is structurally
incapable of returning an out-of-bounds point. The opponent path writes "The
serve does not enter the court" while handing the renderer an in-court landing.
This is the visible bug in save `as`, seed 3801887943.

Two fixes, and they are not the same size:

- Mirror `_errant_attack_target()` — keep the roll, relocate the ball. ~30
  lines, no calibration impact, kills the visible defect.
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
- **Gate D — calibration.** Tune spreads and the power range until the emergent
  rates hit the targets. Needs those targets settled first: stuff rate, block
  involvement, rally-length distribution. They are design decisions that
  survive any implementation; the constants that currently hit them are not, so
  do not spend effort tuning today's margins toward them.
- **Gate E — promotion** behind a rollout flag, across all three attack paths
  and both serve paths, the way Gates 44–49 did for the block.

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
