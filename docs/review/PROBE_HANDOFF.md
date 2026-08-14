# Probe handoff

Every measurement instrument built or exercised on
`claude/system-fit-serve-receive-von64k`, what it currently reports, what the
number is trustworthy for, and what it cannot answer.

Written because this branch's most expensive mistakes were not wrong code. They
were **numbers believed without checking what produced them** -- a threshold
outside its own distribution, a knob whose input had no variance, a counter that
disagreed with itself. Each entry below therefore states its known limits next
to its results, and an entry with no stated limit has not been examined hard
enough.

Everything runs from the repository root with the cached binary:

```bash
xvfb-run -a godot --path . res://tools/<name>.tscn
```

Suite baseline on this branch: **1,829 checks pass.** The count is not a
regression signal -- sampling tests emit a variable number of checks and it has
read 1,180 through 1,792 across near-identical trees. Read the FAIL line.

---

## 1. `responsibility_probe` -- who owns the ball

**Asks:** does reachability *create* responsibility or only decide whether it
succeeds, and how crowded is the voli who takes the ball?

**Reports, 1,200 rallies, all six rotations:**

| RECEPTION | before the immediate-control lock | after |
|---|---|---|
| ball already inside somebody's reach | -- | 844 of 1,059 (79.7%) |
| nearest voli did *not* take it | 194 (32.9% of contested) | **71 (12.0%)** |
| how much further the winner was | median 0.70 m, max 1.14 | median 0.38 m, max 0.87 |

Per rotation, 200 rallies each:

| | R1 | R2 | R3 | R4 | R5 | R6 |
|---|---|---|---|---|---|---|
| ace | 70 | **131** | 3 | **0** | 76 | 1 |
| kill | 73 | 34 | 132 | 40 | 25 | 70 |
| blocked | 20 | 2 | 4 | 12 | 41 | 37 |
| attack_error | 10 | 8 | 26 | 71 | 13 | 36 |
| serve_error | 15 | 24 | 20 | 29 | 25 | 28 |
| opponent swings | 13 | 1 | 16 | 58 | 26 | 35 |
| floor digs | 9 | 1 | 15 | 45 | 21 | 28 |
| digs per swing | 0.69 | 1.00 | 0.94 | 0.78 | 0.81 | 0.80 |
| block coverage | 39 | 21 | 60 | 18 | 16 | 57 |

**What is trustworthy:** the outcome rows. They come from
`result.terminal_outcome`, which the resolver authors directly and which no
counter in the probe touches.

**What is not:** anything split by side. See §Open question 1 -- the side split
reports zero home ATTACK events in runs recording 132 kills, and both the
`actor_id >= 100` heuristic and the resolver's own `side` metadata agree on that
zero. Until that is explained, treat every home/opponent event count from this
probe as unverified. The `home swings` and `home lanes` lines print for that
reason and should be read as evidence of the discrepancy rather than as data.

**Known limits:**

- Splitting sides by `actor_id >= 100` is the *vertical slice's* convention.
  `create_career` generates volis with different ids, so the heuristic is
  unsound against a generated roster and this probe uses one.
- `DEFENSE` is two different events. `rally_simulator.gd:2978` emits it for a
  voli covering their own blocked hitter, which is a response to the opponent's
  *block*. The probe separates them on caption text, which is fragile.
- Reception spacing reads 2.99 m at every percentile. That is correct, not a
  fault -- see §Answered 2.

---

## 2. `pass_and_set_probe` -- the second contact

**Asks:** how high is a pass, how long does the setter get, which posture do
they release from, and how far does a set miss?

**Reports, 1,200 rallies:**

| | before this branch | now |
|---|---|---|
| pass apex above the floor | 2.42-3.31 m, median 2.89 | **2.94-4.05 m, median 3.51** |
| setter arrival margin | median -0.37 s, p95 -0.03 | **median +0.31 s, p95 +1.07** |
| jump sets | **1 of 914** | 517 of 1,342 |
| drift short / mid / long | 0.34 / 0.26 / 0.40 m | **0.26 / 0.31 / 0.62 m** |
| serve rise, ball in | -- | median 0.52 m, max 1.15 |
| serve rise, ball out | -- | **median 0.62 m, p95 6.05, max 6.65** |
| attack rise | -- | median 0.00 m, p95 0.68 |

Posture split: jump 517, no time to load 614, under the hands 136, arriving too
fast to plant 75.

**What is trustworthy:** all of it. Every figure is read off event metadata the
resolver writes, and the before/after pairs were taken on the same seeds.

**Known limits:**

- `_set_pace_scale`'s constants are unmeasured. Nothing publishes a set's flight
  time against posture, so `JUMP_SET_PACE_BONUS` and `STANDING_SET_ARM_SWING`
  have no distribution under them.
- `JUMP_SET_STABLE_APPROACH_MPS` is a stated stride speed, not a measured one.
  It now fires 75 times in 1,342; the first version fired **once**, because it
  measured average speed over the final leg after the head start had shrunk that
  leg to nothing.

---

## 3. `obstruction_probe` -- does anybody get in the way

**Asks:** how often is a second contact's route bent round a teammate, and by
how much?

**Reports, 1,500 rallies / 1,520 second contacts:**

- obstructed second contacts: **710, 46.71%**
- detour off the straight line: median 0.199 m, mean 0.244, p95 0.638, max 0.722
- second contacts with a rival claimant: **40 of 1,520 (2.6%)**
- real claim gap: p05 0.142, median 0.861, max 1.201
- chosen setter's reach margin: **median -0.902 m**

**What this found:** `SECOND_CONTACT_SEAM_MARGIN` at 0.10 sits *below the fifth
percentile* of the distribution it cuts and fired zero times in 1,520 contacts.
Before that was visible, the no-rival case published `claim_margin = 1.0` while
real gaps reach 1.201 -- a sentinel indistinguishable from a genuine wide gap,
and it was the median of the published figures.

**Known limits:** the 46.71% rate has never been judged against an intent. Half
of all second contacts having somebody in the way is a crowded court, not the
setter who ran into the passer. Do not tune `OBSTRUCTION_CLEARANCE_M` before
deciding which of those the model is for.

---

## 4. `net_encroachment_probe` -- is the swing inside the net

**Reports, 1,332 attacks over 1,200 rallies:**

- struck from the wrong side of the net: **0**
- closer to the net than half a torso (0.22 m): **272, 20.42%**
- distance off the net: min 0.180, median 0.442, p95 1.019
- Left Pin and Right Pin both: **min 0.180, p05 0.180**

**What this found:** min equal to p05 on both pins is a clamp doing the work of
a distribution. `HOME_SET_DELIVERY_MIN_Y` is 0.51, which is 0.18 m off the net,
and a fifth of all swings pile onto it.

**Unfixed.** The drawn defect is one layer above the clamp: an attack's
`start_position` is where the *ball* is struck and playback stands the rig on
it, so the feet are placed where the hand should be. Body centre and contact
point want separating before this constant is touched.

---

## 5. `obstruction_shot` -- what a bent run looks like

Renders four frames of a real obstructed leg through `MatchCourt3D`, using the
same `waypoint` key `match_screen.gd` fills in, so it exercises playback rather
than a reimplementation of it.

**Reports, one leg:** the straight line from the setter to the ball passes
**0.18 m** from a teammate; the drawn route ends **0.62 m** from them.

**What it also showed:** in that leg the obstruction sits at the *destination*
rather than in the path, so the corner lands 0.03 m from the target and the bend
is a last-instant sidestep. Somebody standing where you are going is a different
problem from somebody standing in your way, and the model does not tell them
apart.

---

## 6. `foot_plant_probe` -- does the stance foot stay put

**Asks:** while a foot is on the floor, how much of the body's travel does it
copy? Summed over each contiguous stance phase and divided by the body travel
over the same frames. 0 is planted, 1 is a foot moving with the hips.

Runs the same actor twice per speed with `foot_plant_enabled` off and on, so the
improvement is measured rather than claimed.

| direction | speed | plant off | plant on | stance phases |
|---|---:|---:|---:|---:|
| forward | 1.1 | 0.180 | **0.018** | 23 |
| forward | 2.8 | 0.317 | **0.030** | 27 |
| forward | 5.2 | 0.434 | **0.038** | 27 |
| lateral | 1.1 | 1.164 | **0.154** | 37 |
| lateral | 2.8 | 1.946 | **0.219** | 94 |
| lateral | 5.2 | 2.113 | **0.236** | 89 |
| backpedal | 1.1 | 0.319 | **0.032** | 37 |
| backpedal | 2.8 | 0.536 | **0.056** | 43 |
| backpedal | 5.2 | 3.187 | **0.265** | 178 |

**What this found:** `stride_length_m` is metres per step while the pose curve
is a right-left two-step cycle. Playback had advanced one full cycle per stored
step and used the same step at every speed and direction. The corrected clock is
derived from rendered leg span, speed and heading; the ready stance releases
through upright standing before locomotion; and the actual rig supplies a local
pitch/roll Jacobian for the bounded plant correction.

The slow-backpedal failure was separate and refresh-rate dependent. Direction
was ignored until one *frame* travelled 1 cm, so 1.1 m/s had a heading at 60 Hz
and no heading at high refresh rates. Accumulating that centimetre across frames
dropped the planted median from 1.118 to 0.032.

**Known limits:**

- The first version divided per-frame foot displacement by per-frame body
  displacement and reported a max of 150 off a walk. Headless, the denominator
  is whatever the loop took, and two small numbers divided is not a measurement.
  The aggregate replaced it for that reason.
- The frame count had to go up before the walk row meant anything. At 180
  frames a walk gave four stance phases and a median that moved from 0.82 to
  2.33 between runs -- a slower gait covers less ground per frame, so it needs
  *more* frames for the same number of steps. 900 gives twenty and a stable
  figure.
- The correction is capped at 26 degrees. At 5.2 m/s, lateral/backpedal p95 is
  still 0.522 / 0.444; widening the cap would visibly contort the hip.
- Use `--direction=`, `--speed=` and `--frames=` after the scene path to isolate
  one row without replacing this rendered-process measurement with a micro-test.

---

## 7. `character_creation_shot` -- did the choice reach the body

**Asks:** when the career builder is told to make a particular voli, does the
rig draw that voli?

Chooses four bodies that differ on every axis at once, reads the silhouette back
out of `PlayerActor3D` after each, and compares it against what was asked for --
body type, expression, skin, height recovered from the scale the rig chose, and
the coat counted against the same body wearing none. Then creates the career and
reads the manager back off `CareerState`.

**Reports:** 4 of 4 drawn, 0 identical bodies, major 8 regions / minor 6, and
the body stored on the career. The rendered sheet also verifies that the model
faces the camera and that alignment/familiarity/cohesion appears on Origin as a
`CONFIRM <REGION>` prompt rather than on Philosophy.

**What this found:** the first version counted coat marks by filtering `extras`
on `color_key == "literal"`, which is not a key on those parts, and reported
every working coat as NOT REACHED. A count is only a measurement next to the
count it is being compared with -- so it now subtracts the same body wearing
nothing.

**Known limits:** it drives the screen's own methods rather than clicking, so it
proves the model and the wiring and says nothing about whether a button is
reachable with a mouse. PNG capture requires a rendered Godot window; the dummy
headless renderer still checks data flow but returns a null viewport texture.

---

## 8. `rally_resolution_probe` -- does the verdict match the visible rally

**Asks:** are roll-shot arcs plausible, does a block touch that lands out award
the correct side, does a playable touch route to defence, and does a committed
wall still publish its jump when the attack misses?

**Reports, 1,200 rallies / 1,453 attacks:**

- roll shots: 130; displayed apex max **3.65 m**, maximum rise **0.74 m**
- out after block contact: **226; 0 wrong winners**
- playable touches behind the block: **155; 0 routing/event failures**
- missed attacks into a wall: **241; 0 missing jump-timing maps**
- first-to-second contacts: **1,453; 0 consecutive-actor failures**
- block-to-defence pairs: 155; **0 implausible movement** (max 7.39 m/s)
- tempo metadata/relationship failures: **0**
- hitter set-path metadata/trajectory failures: **0**

**What this found:** collision geometry and an attempted jump are not the same
set of bodies. `block_wall` must continue to exclude hands that never arrived,
but playback timing now comes from the formation's primary and attempted assist
before that filter. A wall therefore commits during the set even if the attack
later lands out or misses entirely.

**Known limits:** the roll-shot figures include the hitter's contact height; a
3.65 m apex is only 0.74 m above the hand. Judge rise and launch mode before
judging the absolute floor height.

---

## 9. `second_contact_preview` and `transition_preview` -- the poses, looked at

Two sheets rather than two probes: they render rows of the rig through a phase
or a clock and prove nothing numerically. They are here because half the defects
on this branch were only visible as pictures.

`second_contact_preview` covers the three set postures, the backwards arch, and
the three floor recoveries through the phase. `transition_preview` covers the
stance changes and the getting-up, and **forces both clocks** the way
`gait_preview` forces a landing -- they run in seconds, and a still sheet has no
seconds in it.

**What they found:** the half-kneel never rose; being blown away had nothing
after the impact; the kneel put the shank 22 degrees above horizontal, which
reads as picking a foot up rather than as a knee taking weight; and the
backwards-set arch stood at a fifth of itself on the frame the ball left the
hands.

**Known limits:** a sheet is an argument you can disagree with, not a
measurement. The numeric counterparts are `run_set_posture_shot` for the
postures and the suite's stance-transition checks for the clocks. One mistake
already made here: stepping the floor overlay from 0 re-runs the fall from the
beginning and reads as a body going *down* -- the overlay resumes at whatever
clock the window ended on, so the sheet has to start there too.

---

## 10. Inherited probes, and what they are worth

- **`block_rate_probe`** -- stuff / involvement / touch. Baseline 2.56% /
  79.59% / 38.66%. The career is unseeded, so the roster differs between runs
  and small deltas are not signal.
- **`determinism_probe`** -- reports 75 of 400 seeds not replaying identically
  and **should not be quoted**. It resolves the same seed three times without
  resetting player state, and `_note_recovery` mutates fatigue during a resolve,
  so it cannot tell a replay bug from expected fatigue accumulation.
- **`playback_timing_probe`**, **`long_flight_probe`**, **`long_world_probe`**,
  **`leap_probe`** -- built earlier on this branch, still valid.
- **`measure_offball_travel.gd`** -- drives the *real* `MatchScreen` with a
  viewport. This is the only instrument that caught the 3D viewer crash, which
  the headless plan-builder passed straight through. Run it before pushing
  anything that touches playback.
- **`movement_timing_ratio_calibration.run(120)`** -- has no scene; drive it
  from a throwaway `SceneTree` script. Currently SET 0.8344, ATTACK 1.1108,
  overall 0.9977, perceptible 0.0579.

---

## Open questions

**1. Zero home ATTACK events against 132 kills.** Two independent counters --
`actor_id` and the resolver's `side` metadata -- both report no home swings in
any rotation, in runs whose terminal outcomes record 132 kills. The home attack
does carry `"side": "home"` at `rally_simulator.gd:2484`. Either the probe has a
fault nobody has found or the kill path terminates without emitting the swing.

The second would invalidate every event-count statistic taken about the home
offence, including several quoted on this branch. **Resolve before trusting any
of them.** Cheapest test: dump the raw event-type sequence of a single R3 rally
that ended in a kill.

**2. Why aces run 0 to 131 by rotation.** The largest unexplained number on the
branch. Same opponent, same seeds, only the home rotation differs; in R2 two
rallies in three end on the serve. Everything downstream -- opponent swings,
floor defence, rally length, the block -- moves with it. This is upstream of the
handoff's short-rally symptom and of every remaining responsibility step.

Blocked on question 1 for anything measured by counting events, though the
`terminal_outcome` rows are sound on their own.

**3. Does the immediate-control lock matter?** It cut overtaking from 32.9% to
12.0% of contested receptions, which is real. But the overtake was never large:
the furthest any claimant reached past a nearer teammate was **1.14 m in 1,200
rallies**. The handoff's libero-crossing-the-court case does not appear in the
data at all. Worth knowing before more is built on the same premise.

**4. Attack rise tails, unsplit.** Attack rise is a median 0.00 m -- struck
downward, correct -- with a p95 of 0.68 and a max of 5.24. The serve tail was
split by in/out and turned out to be **entirely failed serves**, drawn as lobs
by `_serve_arc`'s minimum-force fallback. The attack tail has not had the same
treatment. Split it by kill / dug / blocked / error / tip.

**5. Is height penalised twice?** A high set can take a set-quality penalty from
height difficulty *and* extra delivery scatter from
`DELIVERY_HEIGHT_PENALTY_PER_METER`. That may be right. It has not been measured
together, and neither coefficient should move until it is.

---

## Continuations, in dependency order

1. **Answer open question 1.** Everything event-counted is blocked on it.
2. **Answer open question 2** -- the ace spread. Upstream of the short-rally
   symptom, the block, and the rest of the responsibility list.
3. **Separate body centre from ball contact point.** Unblocks the net
   encroachment finding and matters for blocking, setting, wingspan and body
   types.
4. **The remaining responsibility steps** -- previous contacter yields and
   clears, then ready stance as a directional state, then short-ball ownership.
   All three sit inside a rally phase that half the rotation cycle barely
   reaches, so they are worth less than their position on the list suggests
   until question 2 is answered.
5. **Give a dug ball a real trajectory.** Removes the transition set's fallback
   window, its missing head start and its missing jump-set apex in one change.
6. **Split `DEFENSE` into a dig and a coverage event type.** The conflation has
   already produced one wrong conclusion on this branch and will produce more.
