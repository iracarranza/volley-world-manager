# Regional differentiation: live implementation and locked identities

This document describes the regional systems that are **actually live on `main`**.
It is a reference sheet, not an implementation wishlist. Historical notes belong
below the live tables; a value in this document should never outrank the code that
owns it.

Authoritative sources:

- tactical dispositions and match curves: `scripts/data/regions.gd`
- generation shape, physique, specialties, temperament and ceiling weaknesses:
  `scripts/domain/region_profiles.gd`
- application of those generation tables: `scripts/systems/player_generator.gd`
- selective migration/recruitment: `world_population.gd`

Status vocabulary:

| mark | meaning |
|---|---|
| **LIVE** | wired into generation or simulation now |
| **HALF** | wired, but only for one side or one phase |
| **UNBUILT** | designed substrate or extension does not yet exist |
| **INTENTIONAL** | absence is itself a design rule; do not "complete" it |

---

## Part 1 — Live differentiation channels

### C1. Team principles · `regions.gd REGIONAL_PRINCIPLES`

These describe what a side tends to do with a given ball. They are tactical
preferences, not player attributes.

| axis | status | important extremes |
|---|---|---|
| `decisiveness` | **LIVE** both sides | Ĭspayk 0.90; Blôc du Larg 0.26 |
| `serve_aggression` | **LIVE** both sides | Xérvu 0.92; Blôc du Larg 0.30 |
| `pin_focus` | **HALF** — home weighted-lane path is deeper | Ĭspayk 0.88 |
| `block_commitment` | **LIVE** both sides | Blôc du Larg 0.72; Ĭspayk 0.78 |
| `tempo_variation` | **LIVE** both sides | Spëddigh 0.90; Ĭspayk 0.28 |
| `transition_commitment` | **LIVE** both sides | Pāwa Hitō 0.94 |
| `emotional_expression` | **HALF** — home confidence path is deeper | Taktikã 0.12 |

The important distinction is **choice versus capability**. For example, Blôc du
Larg's `serve_aggression = 0.30` means its sides usually choose conservative
serves. That is separate from any generated player's `serve_power` ceiling.

### C2. Generated specialties · `region_profiles.gd REGION_SPECIALTY`

**LIVE.** A region distributes a fixed `SPECIALTY_BUDGET` of **80 ceiling
points** across its specialty list. This replaced the old fixed per-attribute
bonus: adding or removing a specialty now changes the *shape* of a tradition,
not the total amount of regional advantage.

| region | specialty attributes |
|---|---|
| Landavol | *(none — deliberate)* |
| Spëddigh | `work_rate`, `acceleration`, `lateral_speed`, `tempo_control`, `reception_balance` |
| Pāwa Hitō | `stamina`, `transition_speed`, `explosiveness` |
| Blôc du Larg | `block_timing`, `reception_stability`, `dig_control`, `ball_control` |
| Xérvu | `serve_power`, `serve_technique`, `serve_placement`, `serve_consistency`, `serve_aggression`, `serve_variation` |
| Taktikã | `decision_making`, `composure`, `tactical_discipline`, `adaptability`, `unpredictability` |
| Ĭspayk | `attack_power`, `arm_speed`, `jump_reach`, `approach_timing`, `attack_accuracy` |
| A'ace | `attack_power`, `block_timing`, `leadership` |

With no influence overlay, that means 80/5 = 16 each for the common five-item
lists, 80/6 ≈ 13.3 each for Xérvu, 80/4 = 20 each for Blôc du Larg, and
80/3 ≈ 26.7 each for Pāwa Hitō and A'ace before penalty compensation and other
shaping terms.

### C3. Physique bias · `region_profiles.gd`

**LIVE.** Added before individual variation and morphology.

| region | height cm | mass kg | wingspan cm |
|---|---:|---:|---:|
| Pāwa Hitō | +3 | +4 | +2 |
| Spëddigh | −2 | −3 | −2 |
| Blôc du Larg | +3 | +2 | +4 |
| Landavol | 0 | 0 | 0 |
| Xérvu | +1 | 0 | +2 |
| Taktikã | −1 | −1 | 0 |
| Ĭspayk | +4 | +5 | +3 |
| A'ace | +1 | +1 | +1 |

Pāwa Hitō and Blôc du Larg were deliberately enlarged after their specialties
were re-cut. Pāwa's threat is a large body whose output survives long rallies;
Blôc's wall is carried partly by frame rather than by borrowing Ĭspayk's
`jump_reach` specialty.

### C4. Temperament biases · `region_profiles.gd`

**LIVE.** Ego and aggression are separate generated temperament channels.

| region | ego | aggression |
|---|---:|---:|
| Landavol | 0 | 0 |
| Spëddigh | +2 | +3 |
| Pāwa Hitō | +5 | +7 |
| Blôc du Larg | −6 | −4 |
| Xérvu | +9 | +11 |
| Taktikã | −15 | −9 |
| Ĭspayk | +14 | +15 |
| A'ace | +6 | +4 |

These are biases around individual distributions, not fixed personality labels.

### C5. Naming, clubs and demonyms · `regions.gd`

**LIVE.** Cosmetic and world-building by design. Demonyms are civic, retain the
region's own orthographic gesture, and are independent of player ancestry.

### C6. In-match adaptation machinery

Opponent-side phase adaptation exists and grows from observed patterns, but the
old version of this spec incorrectly treated **Blôc du Larg's identity as
unfinished until it owned adaptation**.

That is no longer the design. Blôc was re-cut away from `court_vision` and
`tactical_discipline`: its wall is coverage, size, block timing and the floor
behind it, not a Taktikã-style ability to solve the opponent.

`home_adaptation` remains a possible future system, but it is **not required to
complete Blôc du Larg**.

### C7. Sixnet influence drift · `SixnetLeague`, `REGION_TRADITION_RESISTANCE`

**LIVE**, season-scale. `region_overlay` can add specialty emphasis and physique
deltas as traditions influence their neighbours. It does not replace a region's
own philosophy.

Ĭspayk and A'ace are deliberately outside this development-tradition system:
their identities come from history and money rather than a local tradition that
spreads through geography.

### C8. Physical / technical / mental ratings

**LIVE.** The old spec described a flat per-attribute bonus around global neutral
2.0. That is obsolete.

The live generator treats these ratings as **relative emphasis within the
region itself**. It subtracts the region's own three-rating mean, normalizes the
result by the size of each attribute band, and uses `RATING_BAND_STEP = 18.0`.
The net regional contribution is therefore zero: the ratings reshape talent but
do not make one region produce more talent than another.

### C9. Match curves · `regions.gd REGIONAL_CURVES`

**LIVE.** These are trajectory modifiers rather than single-ball choices.

| region | fatigue resistance | read rate |
|---|---:|---:|
| Landavol | 1.00 | 1.00 |
| Spëddigh | 1.18 | 1.05 |
| Pāwa Hitō | **0.55** | 0.90 |
| Blôc du Larg | 0.88 | 1.15 |
| Xérvu | 1.10 | 0.95 |
| Taktikã | 1.12 | **1.55** |
| Ĭspayk | 1.05 | 0.80 |
| A'ace | 0.95 | 0.72 |

Below 1.0 fatigue resistance means slower fatigue accumulation. Above 1.0 read
rate means faster learning of hitter tendencies during the match.

### C10. Regional ceiling weaknesses · `region_profiles.gd REGION_CEILING_PENALTY`

**LIVE for every major region except Landavol.** The previous statement that this
was "A'ace only" is obsolete.

| region | ceiling weakness |
|---|---|
| Landavol | *(none — deliberate)* |
| Spëddigh | `attack_power` −10, `block_timing` −8 |
| Pāwa Hitō | `feinting` −11, `set_disguise` −9 |
| Blôc du Larg | `improvisation` −11, `transition_speed` −9 |
| Xérvu | `reception` −11, `dig_control` −9 |
| Taktikã | `explosiveness` −12, `jump_reach` −10 |
| Ĭspayk | `shot_variety` −12, `adaptability` −10 |
| A'ace | `tactical_discipline` −12, `decision_making` −12, `court_vision` −9 |

The generator compensates each region's negative ceiling budget back across its
specialty list. A weakness therefore changes *what kind of elite player* the
region produces instead of reducing the world's talent supply.

**Blôc du Larg note:** conservative serving is now carried by
`serve_aggression = 0.30`, not by a `serve_power` ceiling penalty. This preserves
the possibility of an exceptional Largôis server whose pressure compounds with
the region's blocking system. The second ceiling weakness is instead
`transition_speed −9`: the same structure that makes Blôc hard to break also
makes it slower to turn a defensive contact into immediate offense.

### C11. A'ace selective recruitment

**LIVE.** A'ace is the only region with a distinct recruitment appetite. Its
high migration pull is filtered toward terminal current ability, ego and
leadership; its identity is assembled talent rather than a local development
system.

This is distinct from A'ace's homegrown tactical ceiling weaknesses. Imported
players retain the ceilings of the region that raised them.

### C12. Morphology / body type

**INTENTIONAL: region-blind.** Every region draws every body type in equal
proportion. `assign_body_type()` is a flat draw and this is a fixed world rule,
not an unfinished regional-differentiation channel.

Regional physique bias and body morphology compose additively, but morphology is
orthogonal to origin. Do not add a regional body-type distribution as a routine
"completion" of this spec.

---

## Part 2 — Current identity table

| region | main win condition / identity | peak channel | principal cost |
|---|---|---|---|
| **Landavol** | breadth; build the system you want | no imposed peak | no imposed weakness |
| **Spëddigh** | keep broken rallies moving through speed and tempo variation | `tempo_variation 0.90`, work-rate/mobility specialties | power and blocking ceilings; fatigue 1.18 |
| **Pāwa Hitō** | make time itself the advantage; retain output while the rally/match drains everyone else | `fatigue_resistance 0.55`, transition 0.94, large frame | little deception |
| **Blôc du Larg** | deny clean endings with a large organized wall and the floor behind it | block commitment, block timing, control, +4 wingspan | improvisation and slow transition |
| **Xérvu** | take control from the service line through power, variation and risk | serve aggression 0.92 + six serve specialties | reception / floor defence |
| **Taktikã** | learn the opponent and optimize as the match develops | `read_rate 1.55`, decision/composure/tactical specialties | physical contest |
| **Ĭspayk** | feed one perfected terminal swing as early and often as possible | decisiveness 0.90, pin focus 0.88, attack package, largest frame | shot variety and adaptability |
| **A'ace** | assemble already-good point-ending talent rather than grow a shared tradition | selective recruitment + terminal specialties | homegrown tactical understanding; read rate 0.72 |

This table is descriptive, not a tier list. Regional shaping is budget-neutral by
design: a tradition is supposed to change *shape*, not grade.

---

## Part 3 — Locked distinctions

### Landavol — breadth, not mediocrity

Landavol is zero/neutral across regional shaping systems because it is the
reference region. That means no prescribed win condition, not an instruction to
be average forever. Its player-facing promise is freedom to specialize through
the manager's coaching and recruitment choices.

### Spëddigh — motion out of disorder

Spëddigh owns tempo variation and develops work rate, acceleration, lateral
speed, tempo control and reception balance. The identity is not simply "fast
Pāwa": it spends more legs to manufacture playable volleyball from difficult
positions and keeps changing the rhythm.

### Pāwa Hitō — a battery, not a swing

The specialty list intentionally contains no attacking craft attribute. Pāwa's
threat comes from stamina, transition speed, explosiveness, a large frame and the
flattest fatigue curve in the world. Strong attackers can absolutely exist
there; raw attack skill is simply not the regional monopoly.

### Blôc du Larg — the wall and the floor

The old analysis/read identity has been removed. `court_vision` and
`tactical_discipline` are no longer specialties, and `jump_reach` was moved out
of the specialty claim. Blôc is now expressed through +3/+2/+4 physique,
`block_timing`, `reception_stability`, `dig_control`, `ball_control`, conservative
tactical principles and strong block commitment.

Its ceiling weakness is now `improvisation −11, transition_speed −9`. The two
costs describe the same failure mode at different levels: when Blôc can establish
its shape it is oppressive, but when the rally breaks that shape it is slower to
invent and slower to turn defence into attack. Serving remains conservative by
choice rather than capped capability, so a strong server can create an unusually
dangerous serve-to-block rotation.

### Xérvu — serving owns the region

Six specialty attributes, the league's highest serve-aggression principle and a
wingspan lean keep Xérvu's identity unusually clean. The cost is deliberately on
the first-contact/floor side of the game.

### Taktikã — learning is the win condition

`read_rate 1.55` is now live and is the defining trajectory mechanic that the
older spec said was missing. Taktikã also develops decision-making, composure,
tactical discipline, adaptability and unpredictability while giving up
explosiveness and jump reach.

It does **not** need to own Blôc's wall or physical coverage identity. Its game
is to make the opponent's repeated choices less valuable as information
accumulates.

### Ĭspayk — one perfected swing

The current list is `attack_power`, `arm_speed`, `jump_reach`,
`approach_timing`, `attack_accuracy`. `shot_variety` is deliberately penalized,
not merely absent. Predictability is the price of the bomba; if the opponent
survives and reads it, Ĭspayk is supposed to become easier to solve.

### A'ace — bought talent, no inherited game

A'ace's three specialties are `attack_power`, `block_timing`, `leadership`, and
its recruitment model selectively pursues high-end current talent. Homegrown
players pay −12 tactical discipline, −12 decision-making and −9 court vision;
A'ace also owns the lowest read rate, 0.72.

There is currently **no separate A'ace-only raw cohesion/familiarity penalty** in
`starting_identity_state`. Do not describe one as implemented unless code is
added for it.

---

## Part 4 — Remaining gaps and deliberate non-gaps

1. **Opponent parity remains incomplete** for `pin_focus` and
   `emotional_expression`; those paths are still deeper on the home side.
2. **`home_adaptation` is optional future machinery**, not a prerequisite for
   Blôc's current identity. If built, its ownership and overlap with Taktikã must
   be specified first.
3. **`composure_decay` remains unbuilt** if a future regional identity needs a
   distinct late-match emotional trajectory beyond current confidence/fatigue.
4. **Regional serve-style bias remains unbuilt.** Xérvu's serve tradition is
   currently expressed through attributes and `serve_aggression`, while primary
   serve style is derived from the player.
5. **Regional handedness remains unbuilt** and has no current identity requiring
   it.
6. **Off-ball regional shape remains dependent on the off-ball movement system.**
7. **Do not add regional body-type bias.** Equal morphology distribution across
   origins is deliberate.

---

## Part 5 — Counter web

The current major-region weakness table is built so no two non-Landavol regions
share the same principal weakness and each weakness follows from the region's
own training emphasis.

- **Ĭspayk cannot adapt; Taktikã is built on learning.**
- **Xérvu gives up first-contact/floor strength; Blôc du Larg makes clean endings difficult.**
- **Blôc du Larg cannot improvise or transition quickly; Spëddigh lives on changing the shape of a broken rally.**
- **Taktikã cannot win the physical contest; Pāwa Hitō and Ĭspayk can force one.**
- **Spëddigh gives up terminal power/blocking; other regions can punish that at the net.**
- **A'ace cannot grow shared tactical understanding; Taktikã's whole product is decision quality.**

Landavol has neither a regional peak nor a regional weakness. That is the same
statement twice, and it is what makes Landavol the symmetry fixture.