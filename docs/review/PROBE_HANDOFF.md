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

Suite baseline on this branch: **1,792 checks pass.** The count is not a
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

## 6. Inherited probes, and what they are worth

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
