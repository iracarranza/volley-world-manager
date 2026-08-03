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

### Sequencing

1. **Fix the serve visually first** — the cheap patch. The visible defect
   should not stay live for however long the re-architecture takes.
2. **Settle the target rates** — stuff rate, block involvement, rally-length
   distribution. These are design decisions that survive any implementation;
   the constants that currently hit them do not. Do not spend effort tuning
   today's margins toward them.
3. **Build the geometry as a shadow system**, the way Gates 44–49 did for the
   block, and calibrate its spreads until the emergent rates land on step 2.
   Editing three paths in place leaves the sim unmeasurable meanwhile.

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
