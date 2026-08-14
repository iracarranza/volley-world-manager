# Regional differentiation: every channel, and what state each one is in

This is the sheet for locking in the eight identities. It lists **every way a
region can differ from another region**, what each channel is wired to, and
which of them work today. Nothing here is aspirational unless it is marked so.

Status vocabulary, used strictly:

| mark | meaning |
|---|---|
| **LIVE** | wired end to end, and the effect has been measured |
| **HALF** | wired, but reaches only one side of the net or one phase |
| **INERT** | the values exist and nothing reads them |
| **UNBUILT** | the channel does not exist yet |

---

## Part 1 — The eight channels

### C1. Team principles · seven axes · `regions.gd REGIONAL_PRINCIPLES`

What a side *does* with a given ball. The only channel that acts during a rally
without going through a player's attributes.

| axis | reaches | status | notes |
|---|---|---|---|
| `decisiveness` | attack power commitment, swing spread, roll-shot fallback under 0.30 | **LIVE** both sides | 9 home reads, 1 opponent |
| `serve_aggression` | serve risk ×0.70, serve quality ×0.14, reception pressure ×0.10 | **LIVE** both sides | best-wired axis in the game |
| `pin_focus` | hitter-lane weighting `lerpf(0.35, 1.65, x)` | **HALF** — home only | opponent picks its lane from `tendencies.preferred_lane`, a string, so there is nothing to weight |
| `block_commitment` | blocker closing window `(x−0.5)×0.18` | **LIVE** both sides | |
| `tempo_variation` | chance of rotating tempo, and reach of the rotation | **LIVE** both sides | was a threshold; now a rate |
| `transition_commitment` | blended with decisiveness, chance of pulling tempo faster | **LIVE** both sides | was a threshold; now a magnitude |
| `emotional_expression` | `confidence_volatility = 1 + (x−0.5)×0.6` | **HALF** — home only | the opponent has no confidence track to be volatile |

### C2. Generated attributes · `player_generator.gd REGION_SPECIALTY`

**+8 to each named attribute**, applied at generation. The deepest regional
system in the game and the one most likely to decide matches once academies
exist.

| region | specialty attributes |
|---|---|
| Landavol | *(none — deliberate)* |
| Spëddigh | work_rate, acceleration, lateral_speed, tempo_control, reception_balance |
| Pāwa Hitō | stamina, transition_speed, explosiveness, approach_timing, attack_accuracy |
| Blôc du Larg | block_timing, jump_reach, court_vision, tactical_discipline |
| Xérvu | serve_power, serve_technique, serve_placement, serve_consistency, serve_aggression, serve_variation |
| Taktikã | decision_making, composure, tactical_discipline, adaptability, unpredictability |
| Ĭspayk | attack_power, arm_speed, jump_reach, block_timing, shot_variety |
| A'ace | attack_power, serve_power, block_timing *(three, spanning three categories — bought stars, not a tradition)* |

**LIVE**, but see the Ĭspayk/A'ace warning in Part 3.

### C3. Physique bias · `REGION_HEIGHT/MASS/WINGSPAN_BIAS`

Centimetres and kilograms added before individual variation. **LIVE.**

| region | height | mass | wingspan |
|---|---|---|---|
| Ĭspayk | +4 | +5 | +3 |
| Blôc du Larg | +1 | +1 | +2 |
| Xérvu | +1 | 0 | +2 |
| A'ace | +1 | +1 | +1 |
| Landavol | 0 | 0 | 0 |
| Pāwa Hitō | 0 | −1 | 0 |
| Taktikã | −1 | −1 | 0 |
| Spëddigh | −2 | −3 | −2 |

### C4. Ego bias · `REGION_EGO_BIAS`

**LIVE.** Ĭspayk +14, Xérvu +9, A'ace +6, Pāwa +5, Spëddigh +2, Landavol 0,
Blôc du Larg −6, **Taktikã −15**. Ego feeds the attack-power commitment
alongside `decisiveness`, so this is a second, per-player route into the same
decision — and it is currently Taktikã's largest single mechanical footprint.

### C5. Naming, clubs, demonyms · `regions.gd`

**LIVE.** Given names, `CLUB_NAMES`, `DEMONYMS`. Cosmetic by design, and the
first thing a player perceives.

### C6. In-match adaptation · `OpponentTeam.*_adaptation_strength`

Three phase-specific strengths that grow with `rallies_observed` and re-aim the
block, floor defence and serve receive at repeated patterns.

**HALF — opponent-only, and not regional.** `adaptation_rate` is a single
balancing slider, identical for every region. This is the machinery Bloc du
Larg's and Taktikã's identities are supposed to be made of, and neither region
touches it.

### C7. Sixnet influence drift · `SixnetLeague`, `REGION_TRADITION_RESISTANCE`

**LIVE**, season-scale. Regions absorb neighbours' traditions via
`region_overlay`, which adds attributes and physique deltas to C2/C3. Zaitgaist
mirrors whoever last won. Does not act inside a match.

### C8. Region ratings · `DEFINITIONS` `physical` / `technical` / `mental`

**LIVE as of Part 5** — was INERT. Eight regions carried three numbers each and
nothing in the codebase read any of them: twenty-four values, zero consumers,
and the most visible statement of what a region is. They now set a broad,
small ceiling bias per attribute band (2 is neutral, each point is worth 2.6),
sitting underneath `REGION_SPECIALTY` rather than competing with it.

### C9. Regional curves · `regions.gd REGIONAL_CURVES`

**LIVE as of Part 5.** `fatigue_resistance` and `read_rate`, both read from
`home_region`. The first channel in the game that makes a region play
differently in the fourth set than in the first.

### C10. Ceiling penalties · `player_generator.gd REGION_CEILING_PENALTY`

**LIVE as of Part 5.** The first table that takes something away, so a tradition
can have a hole in it rather than only a peak. A'ace only.

### C11. Selective recruitment · `world_population._recruitment_appetite`

**LIVE as of Part 5.** What a region *shops for*, distinct from how attractive it
is. A'ace only; every other region returns 1.0 and the ordinary migration model
is untouched.

---

## Part 2 — Channels that do not exist yet

Each is named in a tagline and has no implementation.

| channel | would carry | substrate today | status |
|---|---|---|---|
| `fatigue_resistance` | Pāwa Hitō's flat curve | — | **BUILT**, see Part 5 |
| `read_rate` | Taktikã finding your pattern | — | **BUILT**, see Part 5 |
| `home_adaptation` | Blôc du Larg re-aiming the block | opponent-only equivalents exist | **UNBUILT** — substrate half |
| `composure_decay` | who cracks in set five | `match_confidence`, `flow` | **UNBUILT** |
| regional body-type bias | who a region *looks* like | `assign_body_type` is `rng.randi_range` over all types, region-blind | **UNBUILT** |
| regional serve-style bias | Xérvu's float tradition | `primary_serve_style` is derived from attributes, never from region | **UNBUILT** |
| regional handedness | left-handed traditions | uniform | **UNBUILT** |
| off-ball phase intentions | any identity about *shape* | see `OFF_BALL_MOVEMENT.md` | **UNBUILT** |

---

## Part 3 — The eight identities, and which will not survive

Measured separation (`run_regional_identity_probe.gd`, nearest neighbour in
units of league spread): Xérvu 1.768, Spëddigh 0.897, Ĭspayk 0.834, Blôc du Larg
0.766, A'ace 0.664, Pāwa Hitō 0.664, Taktikã 0.567, Landavol 0.567.

### ✅ Xérvu — sound

Owns `serve_aggression` outright, and it is the best-wired axis in the game.
Six specialty attributes all serving. Nothing else in the league competes for
this space. **Lock as is.**

### ✅ Blôc du Larg — sound in disposition, thin in identity

`block_commitment` 0.72 is live on both sides; low everything else produces the
slowest tempo and longest rallies in the league, which reads correctly. But its
tagline — "methodical court reading… complete control" — is a claim about
**adaptation**, and C6 is opponent-only and not regional. What is legible today
is *conservatism*, not *reading*. **Lock the disposition; the identity needs
`home_adaptation` to be what the tagline says.**

### ✅ Spëddigh — sound as of this pass

Highest tempo spread in the league (0.993) and a fast mean. Before
`tempo_variation` became a rate, it was Landavol with a coin flip. **Lock as is.**

### ✅ Pāwa Hitō — resolved in Part 5 (was INEFFECTIVE)

`transition_commitment` 0.94 now produces the fastest mean tempo (1.86), which
is real but is *the same currency Ĭspayk and Spëddigh trade in*. Its actual
brief — "quality never declines, effectiveness surges as others burn out" — is a
**time claim**, and no time-scale channel is attached to it. Its specialty list
already leads with `stamina`, so the substrate is one multiplier away.

**Cannot be locked until `fatigue_resistance` exists.** Everything else about
Pāwa is a weaker Ĭspayk.

### ⚠️ Taktikã — INEFFECTIVE in its current state

The most exposed identity in the game. Six of its seven axes are within 0.10 of
Landavol; the seventh, `emotional_expression` 0.12, has **one** read in the
simulator and is home-only. Its five specialty attributes are
`decision_making`, `composure`, `tactical_discipline`, `adaptability`,
`unpredictability` — and *adaptability* has no consumer that varies by region,
while `unpredictability` and `tactical_discipline` are thin.

Its largest real footprint today is **ego −15**, which is a side effect rather
than an identity.

**Cannot be locked until `read_rate` exists**, and probably needs two new
principle axes of its own (`read_discipline`, `risk_aversion`) since it owns
none of the existing seven.

### ✅ A'ace — resolved in Part 5 (was INEFFECTIVE)

All seven axes above neutral, no axis below. Physique positive on all three.
Three specialty attributes, all glamour. Nothing is *traded*. Its nearest
neighbour is Pāwa Hitō at 0.664 largely because both are "generically strong".

An identity with no cost is a difficulty setting. The fiction supports a cost
easily — bought squads with no shared tradition — and the natural home is
**cohesion, familiarity growth and identity alignment**, all of which exist:
`starting_identity_state` already computes `familiarity` and `cohesion` from
alignment distance. **Lock only once A'ace pays for its breadth somewhere.**

### ✅ Ĭspayk — re-cut in Part 5; the overlap it caused is resolved

`decisiveness` 0.90 and `pin_focus` 0.88 are the two best-wired axes after
serve, `+14` ego, and the largest frame in the league. It is the strongest
identity in the game by some distance, and its specialty list overlaps A'ace on
`attack_power` and `block_timing` and Blôc du Larg on `block_timing` and
`jump_reach`. **Lock the identity, but its overlap is the reason A'ace and Pāwa
read as dilute versions of it.**

### ✅ Landavol — now sound, and about to become load-bearing

Zero on every physique bias, no specialty, 0.50 on all seven axes, ego 0. It is
the arithmetic identity of every regional system at once, which is exactly what
makes it the correct **symmetry fixture** — and per the standing decision, a
Landavolan side is what the calibration instruments should be pinned to once
regional academies exist.

Its player-facing identity should be stated as *breadth*: no ceiling anywhere,
no floor anywhere, cheapest retraining, smallest familiarity penalty when a
manager changes system. **Lock as the reference, and give it breadth mechanics
rather than an extreme.**

---

## Part 4 — What has to be true before all eight can be locked

1. **Build `fatigue_resistance`.** Unblocks Pāwa Hitō. Cheapest of the four
   curves; substrate is live and measurable immediately.
2. **Build `read_rate`.** Unblocks Taktikã, partially.
3. **Give Taktikã axes it owns** — `read_discipline`, `risk_aversion`. Without
   these it is Landavol with a quiet bench.
4. **Give A'ace a cost** in cohesion/familiarity.
5. **Build `home_adaptation`.** Completes Blôc du Larg's stated identity.
6. **Mirror `pin_focus` and `emotional_expression` to the opponent.** Needs the
   opponent a weighted lane choice and a confidence track.
7. **Decide what `physical`/`technical`/`mental` are for** — wire them to
   something (development speed? scouting display? academy quality?) or delete
   them. Twenty-four numbers with no reader is the exact shape of a value
   nobody set.
8. **Resolve the Ĭspayk overlap** before academies land, since C2 is where
   regional talent will actually be felt and three regions currently share
   `attack_power`/`block_timing`.

Only after 1–4 can Pāwa Hitō, Taktikã and A'ace be locked. Xérvu, Spëddigh,
Ĭspayk and Landavol can be locked now. Blôc du Larg can be locked in
disposition, with its adaptation identity pending 5.

---

## Part 5 — Built since this spec was written

### Fatigue is now three stages, and it is earned by work

`scripts/simulation/fatigue_model.gd`. The model it replaces was one line —
`raw * (1.0 - fatigue * 0.18)` — which is linear, so the first percent of
tiredness cost what the last percent cost, and single-channel, so a tired setter
and a tired middle degraded identically.

| stage | onset | what it takes |
|---|---|---|
| **working** | 0.00 | every attribute, a little (max 7%), saturating by 0.55 |
| **laboured** | 0.34 | work rate, explosiveness, jump, speed, arm speed (a further 22%) |
| **spent** | 0.68 | forced errors (+0.14), then unforced (+0.09, squared into the tail) |

Each channel is logarithmic — most of what a stage takes, it takes early — and
the escalation a player feels comes from the *stages arriving in sequence*, not
from any one accelerating. Reads as tiredness, then forced errors, then unforced
ones, which is the brief.

Mental and physical now diverge, which the single multiplier could not express:
at full fatigue a mental attribute is at ×0.930 and a physical one at ×0.725,
where the old model put both at ×0.820. At zero fatigue the new model is exactly
1.0, so every calibration fixture is untouched.

**And fatigue is now charged for what a voli did**, not for being on the court.
Two chokepoints catch everything: `_reached_point` for every metre travelled
(with a sprint multiplier for anything that is not a lateral shuffle) and
`_add_event` for every jump in the game — attack, block, assisting block, jump
set, jump serve, both sides, all variants. Charging at the jump *sites* would
have meant finding all of them and missing one silently.

Measured over a five-set match (`tools/run_fatigue_stage_probe.gd`):

```
after         p10      p50      p90   stage at the median
set 1       0.000    0.103    0.147   working
set 3       0.000    0.271    0.470   working
set 4       0.000    0.389    0.600   laboured
set 5       0.000    0.522    0.743   laboured   (p90 is spent, +0.058 error)

who actually tired, by role
  Opposite         0.650      Outside Hitter  0.572
  Setter           0.522      Middle Blocker  0.372
  Libero           0.274
```

A 2.4× spread between the libero and the opposite, which the flat per-rally
figure could not produce at all. The middle sits lower than the pins because the
libero replaces them in the back row — emergent, and correct.

Both cost constants were re-anchored *against that measurement*: at the first
values tried, the most-worked starter finished a five-setter at 0.531 and the
`spent` stage — and therefore the whole error channel — was unreachable. The
ratio between jump and travel cost is the design and was not touched; only the
scale was wrong.

### `fatigue_resistance` and `read_rate`

`REGIONAL_CURVES` in `regions.gd`, the second layer this document argued for.
Both read from `home_region` rather than `club_region`: these are habits formed
growing up, so signing a Pāwan buys their curve and a club's endurance becomes
the aggregate of who it raised and who it bought — which is the shape regional
academies will need on the day they arrive.

Worth, on the match measured above: a Pāwa Hitō median voli sits at **0.287 and
is still `working`** where a Landavol one is at 0.522 and `laboured`. That is
the identity, and it is the first thing in the game that makes a long match
different from a short one.

### The three re-cuts

**Blôc du Larg** — from analysis to reach. `court_vision` and
`tactical_discipline` out, `lateral_speed`, `explosiveness` and
`reception_stability` in. The wall is not a side that out-thinks you; it is long
enough and quick enough off the floor to touch the shot it guessed *wrong*
about. Whatever adaptation the region shows is then a consequence of touching
more balls rather than a separate talent for reading them.

**Ĭspayk** — from a broad attacking region to one polished terminal swing.
`shot_variety` removed *as the point of the change*: a side that can hit six
different shots is not predictable, and predictability is what Ĭspayk is
supposed to cost. `approach_timing` and `attack_accuracy` are the polish;
`block_timing` dropped because it sat in three regions at once.

**A'ace** — the first region in the game with a real cost.
`REGION_CEILING_PENALTY` takes 12, 12 and 9 off `tactical_discipline`,
`decision_making` and `court_vision` for anybody A'ace *raises*; a voli it signs
from Taktikã keeps Taktikã's ceilings, which is the mechanism of the region
rather than a debuff on the individual. `_recruitment_appetite` makes its
migration pull selective — terminal ability, ego and leadership, ranging 0.45 to
2.35 so it genuinely sorts. Its low birth weight (0.35) and high pull (3.40)
already existed and needed nothing.

### `physical` / `technical` / `mental` now do something

Twenty-four values that nothing in the codebase read. They are a region's
*breadth of emphasis*, so they act broad and small, underneath
`REGION_SPECIALTY`'s sharp +16 rather than competing with it: 2 is the world
average and does nothing, and each point away is worth 2.6 on every attribute in
that band. Landavol is 0.0 on all three bands, as the symmetry fixture requires.

A'ace's mental rating of 1 costs it 2.6 on decision-making on top of the 12 from
its academy gap — **−14.6 total** — so "poor tactical decision making" is stated
twice by two systems that agree.

### Still unbuilt

`home_adaptation`, `composure_decay`, opponent-side `pin_focus` and
`emotional_expression`, regional body-type and serve-style bias, and Taktikã's
own axes (`read_discipline`, `risk_aversion`). Taktikã now has `read_rate` at
1.55 — the largest curve in the league — which is its first real mechanism, but
it still owns none of the seven dispositions.


---

## Part 6 — The locked table

Overlap policy, decided: **exclusive systems, exclusive peaks, shared
foundations.** Zero attribute overlap is arithmetically forced into absurdity —
seven non-Landavol regions times five specialties is thirty-five of about forty
attributes, so you end up assigning attributes to regions to satisfy a
constraint rather than because the region is about them. Shared foundations are
also what make matchups instead of rock-paper-scissors: two regions strong at
the net means that match is decided by what *else* they bring, rather than by
whose axis came up. What must never be shared is the peak, and what must never
be shared at all is a system.

Attribute overlap went 7 → 2 in this pass. Both survivors are A'ace holding
another region's peak, which is the one overlap the fiction actively requires:
A'ace does not develop, it buys, and what it buys is whatever ends points.

| region | peak attribute | system it owns alone | weakness | frame |
|---|---|---|---|---|
| **Landavol** | *none* | *none — 1.00/1.00* | *none* | 0/0/0 |
| **Spëddigh** | `work_rate` | `tempo_variation` 0.90 | `attack_power` −10, `block_timing` −8 | −2/−3/−2 |
| **Pāwa Hitō** | `stamina` | **`fatigue_resistance` 0.55** | `feinting` −11, `set_disguise` −9 | +3/+4/+2 |
| **Blôc du Larg** | `block_timing` | `block_commitment` 0.72 | `improvisation` −11, `serve_power` −9 | +3/+2/+4 |
| **Xérvu** | `serve_technique` | `serve_aggression` 0.92 | `reception` −11, `dig_control` −9 | +1/0/+2 |
| **Taktikã** | `decision_making` | **`read_rate` 1.55** | `explosiveness` −12, `jump_reach` −10 | −1/−1/0 |
| **Ĭspayk** | `attack_power` | `decisiveness` 0.90 | `shot_variety` −12, `adaptability` −10 | +4/+5/+3 |
| **A'ace** | `leadership` | recruitment (pull 3.40, selective) | `tactical_discipline`/`decision_making` −12, `court_vision` −9 | +1/+1/+1 |

### The three clarifications this pass implemented

**Pāwa Hitō is a battery, not a swing.** Its specialty list now carries *no
attacking attribute at all* — the damage is a consequence of a large frame
(raised from 0/−1/0, which contradicted the fiction) arriving at a defence that
`fatigue_resistance` 0.55 has outlasted. They beat down tired defenders; they do
not out-hit fresh ones.

**Ĭspayk is one perfected swing.** `attack_power`, `arm_speed`, `jump_reach`,
`approach_timing`, `attack_accuracy` — going toe-to-toe in the air, and owning
air presence outright now that Bloc's size moved to the frame instead.
`shot_variety` is not merely absent but *penalised*, because predictability is
the price of the perfect swing.

**The three-way tie at the net is resolved by channel, not by deletion.** Bloc
and Ĭspayk are both tall, and they say so differently: Ĭspayk through
`jump_reach` (an attribute, contested in the air), Bloc through wingspan +4 (a
frame, occupying space). A'ace holds both peaks and pays for them in decisions.

### The web of counters

Weaknesses were chosen so no two regions share one, and so each is the inverse
of that region's own strength:

- **Ĭspayk cannot adapt; Taktikã is built on adapting.** The clearest matchup in
  the league, and it is the one the fiction names.
- **Xérvu cannot pass; Blôc du Larg exists to make you pass.**
- **Bloc cannot improvise; Spëddigh is nothing but improvisation of tempo.**
- **Taktikã cannot win a physical contest; Pāwa Hitō and Ĭspayk are the
  physical contest.**
- **Spëddigh cannot hurt you at the net; A'ace is bought terminal ability.**
- **A'ace cannot make decisions; Taktikã sells nothing else.**

Landavol has neither a peak nor a weakness, which is the same statement twice
and is what qualifies it as the symmetry fixture.
