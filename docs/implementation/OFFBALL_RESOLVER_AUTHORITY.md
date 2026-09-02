# Off-ball resolver authority

## What this is

`docs/design/OFF_BALL_MOVEMENT.md` is the design authority and already states the
rule: *"the rule 'playback draws what the resolver decided' is right and must not
be relaxed — so the resolver has to decide more."* This is the implementation
spec for doing that, in two phases with a gate between them.

It is written against `6ae238e`, after the four movement-contract repairs, and it
assumes their result: **every leg the resolver names now carries its own clock**
-- 3,223 of 3,223 off-ball legs publish `traversal_seconds` and `window_seconds`,
and legs drawn slower than the body moves fell from 1,844 to 176. The contract is
no longer the problem. **Coverage is.**

## The measured starting point

`tools/run_offball_coverage_probe.gd`, 400 rallies, seeds 61000-61199, **1,760
drawn flights**. Named = in a phase map, the contact actor, or a staged next
actor.

**The resolver has an opinion about 6.89 of the twelve on court.** Twelve minus
that is exactly the population `match_screen._apply_cheat_steps` invents a
destination for: 1,194 legs of 1,507 and two thirds of all drawn travel.

| flight | flights | named /12 | home /6 | opponent /6 |
|---|---:|---:|---:|---:|
| `SERVE→RECEPTION` | 324 | **12.00** | 6.00 | 6.00 |
| `SET→ATTACK` | 311 | 9.98 | 5.02 | 4.97 |
| `ATTACK→BLOCK` | 217 | 8.31 | 5.11 | **3.20** |
| `RECEPTION→SET` | 128 | 8.02 | **3.02** | 5.00 |
| `DIG→SET` | 60 | 6.10 | 4.40 | **1.70** |
| `BLOCK→DIG` | 175 | **5.31** | 3.12 | 2.19 |
| `SET_DECISION→SET` | 114 | 5.04 | 5.04 | **0.00** |
| `RECEPTION→SET_DECISION` | 114 | **1.00** | 1.00 | 0.00 |
| every `→POINT` | 296 | ~0.7 | | |

**`SERVE→RECEPTION` is already total.** That is the proof the pattern works and
the template for the rest: two receive shapes, both published, both timed. The
work below is applying it, not inventing it.

### Which role is missing, which is the actionable form

| flight | unnamed per flight, by position |
|---|---|
| `BLOCK→DIG` | **Outside 2.22**, Middle 1.14, Opposite 1.12, Libero 1.11, Setter 1.10 |
| `DIG→SET` | **Outside 2.00**, Libero 1.32, Setter 1.25, Middle 0.67, Opposite 0.67 |
| `RECEPTION→SET` | **Outside 1.68**, Libero 1.28, Setter 1.00 |
| `ATTACK→BLOCK` | **Outside 1.42**, Opposite 0.81, Libero 0.57, Setter 0.51, Middle 0.38 |
| `SET→ATTACK` | Outside 0.63, all others ≤ 0.37 |

**The outside hitter is the worst-covered role in every flight family**, and that
is not a coincidence: an outside does the most off-ball work in the sport --
transition out, approach, cover, and dig in the back-row rotations. Two per side
means about half of them are unresolved at any instant.

`RECEPTION→SET` is worth reading closely because it names the shape of the whole
problem: Middle and Opposite do not appear at all, so `_transition_phase_map`
covers them; it excludes the receiver, the setter and the hitter by name at
`:15746`, and the libero and outsides fall through with them.

## Phase one: publish, change nothing

**Every step in phase one must leave `run_rally_balance_probe.gd` byte-identical
over 700 rallies.** That has held through eight consecutive commits and it is
what makes each step attributable. A step that moves an outcome has left phase
one and belongs in phase two.

### The contract each entry must carry

Nothing new. Repairs 1-4 built it, and `_travel_intent` already emits it:

```text
intent              which of the vocabulary below
progress            fraction of the asked journey covered
traversal_seconds   the leg's own time, clamped to the window
window_seconds      the budget it was clamped against
```

An entry is added to `<side>_phase_targets` and its companion
`<side>_phase_intents`. **Never a target without an intent** -- that was the
231-entry hole repair 3 closed, and it should not reopen.

### One intention vocabulary

`OFF_BALL_MOVEMENT.md` proposes `cover / approach / chase / base / release`; the
code emits `covering / defending / blocking / preparing_attack / receiving /
setting`. The code's list wins, because `COGNITICONS.md` already reads it and
`run_intent_progress_probe.gd` already measures its distribution. Two additions
are needed and both name things the sport has words for:

- **`chasing`** -- a voli going after a ball they probably will not reach. The
  design doc's headline case, and distinguishable from `defending` precisely
  because arrival is not expected.
- **`recovering`** -- a voli getting back from the floor or from a landing.
  `_note_recovery` and `recovery_until` already model this; nothing publishes it
  as an intent.

`base` and `release` from the doc's list are **not** added: a base return is
already `_apply_base_positions` reading resolver-published ground, and *release
for transition* is a `covering` branch that `_cover_phase_map` already takes.

### The six holes, in order

Ordered by flights × unnamed, which is drawn legs recovered per unit of work.

1. **`BLOCK→DIG`, both sides (175 flights, 6.7 unnamed).** The defensive
   scramble and the attacking side after their swing. The largest single hole and
   the one the design doc cares most about -- this is where a deflected ball is
   either contested or conceded. `_deflection_adjust_map` exists for the home
   defence; the attacking side has nothing.
2. **`ATTACK→BLOCK`, attacking side (217 flights, 2.80 unnamed).** Cover, while
   their own spike is in the air. `_cover_phase_map` exists and reads
   `attack_coverage_responsibility`; it is reaching about three of six.
3. **`RECEPTION→SET`, receiving side (128 flights, 2.98 unnamed).** The
   transition. `_transition_phase_map` excludes receiver, setter and hitter by
   name; the libero and the outsides fall through. The receiver in particular
   should be `recovering`, not absent.
4. **`DIG→SET`, opposing side (60 flights, 4.30 unnamed).** The side that has
   just been dug on, re-forming.
5. **`SET_DECISION→SET`, opposing side (114 flights, 6.00 unnamed).** Nobody on
   the far side has any opinion during the setter's decision. Check first whether
   this window is long enough to matter -- if it is consistently under about a
   tenth of a second, "nobody moves" is the right answer and the entry is
   `watching` rather than a target.
6. **`RECEPTION→SET_DECISION` (114 flights, 11 unnamed).** Same question, more
   sharply.

**Holes 5 and 6 may resolve to "publish an intent and no movement".** That is a
legitimate outcome and it is still an improvement: it replaces an invented cheat
step with an authoritative "this voli is watching."

### Gates for each step

- `run_rally_balance_probe.gd`: byte-identical, 700 rallies.
- `run_offball_coverage_probe.gd`: `mean_named_of_12` rises, and the role table
  shows the intended role moving.
- `run_offball_timing_baseline.gd`: `untimed` stays **0**, and `completable` and
  `cannot_complete` may move -- they are population statistics and the population
  is being added to, which repair 1 already recorded as the correct reading.
- The suite, with a check per hole asserting the flight family's coverage.

## The cheat-step retirement condition

`_apply_cheat_steps` is not deleted until live-ball flights are near-total,
because deleting it today turns 5.1 volis per flight into statues -- which is the
complaint that produced `OFF_BALL_MOVEMENT.md` in the first place.

**The condition: every live-ball flight family names ≥ 11 of 12, and the
`→POINT` families are excluded by the dead-ball work rather than by this rule.**

When it is met, deletion is its own commit with its own before/after on
`playback_start_mismatches` -- which should *fall*, because a cheat step moves the
body and the next authoritative leg is drawn from where it left them. That
number is 28 in 40 rallies today and it is the cleanest single measure of the
harm the invented movement does.

## Phase two: let the positions be claimed

**Behind a flag, in `rally_feature_flags.gd`, closed until a calibration gate
opens it** -- the convention every other rollout in that file follows.

Phase one publishes where the other five are. Phase two lets
`CoverageModel.choose_claimant` and the floor-defence search consider them, which
is what makes a shanked pass playable rather than structurally conceded. **This
moves rally outcomes and that is the point**, so it needs the treatment a
calibration change gets:

- a named flag, defaulting closed;
- a paired census on the same seeds with the flag open and shut;
- the gated bands in `run_rally_balance_probe.gd` re-read: **dig rate 0.35-0.55,
  stuff 0.08-0.14, serve error 0.12-0.20** are the governed ones; kill rate,
  contacts per rally and swing balance are advisory and will move most.

**The expected direction, stated before measuring so it can be wrong:** contacts
per rally rises (currently 4.636, target above 6.0), dig rate rises, rally length
rises, and kill rate falls toward its 0.45-0.50 band from 0.526. If contacts per
rally does *not* rise, the phase-one positions are not close enough to matter and
that is the finding.

**Do not tune anything in phase two's first pass.** Publish the census, read it,
and decide separately. Fitting a rate in the same change that creates the
mechanism is the mistake `docs/FAILURE_MODES.md` §0 exists to name.

## Not in scope

- **The dead ball.** 296 of 1,760 flights end in a POINT and name about one voli
  of twelve. That is `docs/BACKLOG.md`'s dead-ball tail, not off-ball tactics:
  nobody has a phase intention after the point, and standing still is closer to
  correct than any target would be. Deferred deliberately.
- **2D.** `tactical_court._integrate_phase_path` still normalises its own time
  axis away. It benefits from better inputs and is sequenced after the 3D work,
  as the authority handoff already says.
- **Pose.** Untouched. A residual snap after this work is the separate diagnosis.
- **Collisions between converging defenders**, which `OFF_BALL_MOVEMENT.md`
  already lists as a separate entry.

## Instruments

| probe | answers |
|---|---|
| `run_offball_coverage_probe.gd` | how many of twelve are named, by flight and by position |
| `run_offball_timing_baseline.gd` | whether their legs carry a clock, and the pace that results |
| `probe_movement_plan.gd` | what the real `MatchScreen` draws, including which source each destination came from |
| `run_rally_balance_probe.gd` | whether any of it moved an outcome |
| `run_intent_progress_probe.gd` | whether the intent vocabulary carries a real distribution |

The first three did not exist before this pass. They are the reason the spec can
name six holes and a role rather than a direction.
