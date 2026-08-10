# Regional identity: a pattern over a match, not a setting on a rally

An identity is something you notice in the fourth set. Taktikã spend two sets
finding your pattern and then defend the place you are about to hit. Pāwa Hitō
look ordinary at 8–8 and are still hitting at full weight when everyone else's
legs have gone. That is what a regional identity *is* — a shape that emerges from
accumulated state — and the current model has no way to express it, because every
principle is read fresh at each rally from a table that never changes.

This document records what that costs, measured, and what the model would need.

## What the current model produces

`tools/run_regional_identity_probe.gd` runs 640 rallies per region with identical
seeds, rosters and opponent, so the only thing varying is the seven principle
numbers.

```
region          kill    dig    ace  svErr  stuff cont/r   tempo  quick
Landavol       0.466  0.595  0.072  0.081  0.147   5.14    2.21  0.316
Spëddigh       0.448  0.594  0.072  0.081  0.143   5.15    1.88  0.379
Pāwa Hitō      0.484  0.598  0.072  0.081  0.143   5.11    1.86  0.359
Bloc du Larg   0.475  0.605  0.072  0.078  0.148   5.27    2.35  0.262
Xérvu          0.452  0.578  0.103  0.097  0.156   4.98    1.91  0.357
Taktikã        0.472  0.609  0.072  0.081  0.150   5.18    2.18  0.329
Ispayk         0.474  0.600  0.075  0.087  0.133   5.05    1.86  0.360
A'ace          0.465  0.604  0.072  0.084  0.136   5.08    1.86  0.389
```

Nearest-neighbour distance, each column scaled by its own spread: Ispayk/A'ace
0.431, Landavol/Taktikã 0.541, Pāwa/Ispayk 0.648, Spëddigh/A'ace 0.716, Bloc
0.735, **Xérvu 1.632**.

Xérvu is four times more separated than anyone else, and the reason is
structural rather than a matter of tuning.

### Three of the seven axes are thresholds, not magnitudes

| axis | reads | shape | owned by |
|---|---|---|---|
| `decisiveness` | 9 home, 1 opp | magnitude + one threshold | Ispayk .90 |
| `serve_aggression` | 4 home | magnitude ×0.70, ×0.14, ×0.10 | Xérvu .92 |
| `pin_focus` | 4 home | magnitude `lerpf(0.35, 1.65, …)` | Ispayk .88 |
| `block_commitment` | 2 home, 1 opp | magnitude `(x−0.5)×0.18` | Bloc .72 |
| `emotional_expression` | 1 home | magnitude, confidence volatility only | Taktikã .12 |
| `tempo_variation` | 2 home | **threshold** `≥ 0.48` → seeded ±1 | Spëddigh .90 |
| `transition_commitment` | 1 home | **threshold**, blended at 0.45 | Pāwa .94 |

Spëddigh at 0.90 and Landavol at 0.50 both clear the tempo floor and receive the
identical coin flip. Pāwa at 0.94 and Xérvu at 0.60 both clear the commitment
gate and receive the identical −1 shift. `regions.gd` asserts that "the sim
already renders that difference"; its own game says otherwise.

Two further findings from the same pass:

- **22 of 24 principle reads are `home_principles`.** An opponent Xérvu serves
  exactly like an opponent Bloc du Larg. Regional identity is a property of the
  player's team only.
- **The ace rate is 0.072 for six of eight regions**, identical to three
  decimals. Serve identity is a Xérvu feature, not a system.

## The deeper problem: identity has no time axis

Even with every axis given honest magnitude, the model would still describe a
team that plays the same way on the first rally and the last. Every principle is
a constant read per rally. Nothing about a region can *develop* within a match.

That is the wrong shape for the fiction. The taglines describe trajectories:
Taktikã "strip the game down to its roots" — a process; Pāwa Hitō are
"nightmarish deep into a rally" — a time claim; Bloc du Larg "keep complete
control" — a claim about what happens when control is tested repeatedly.

## What already exists to build on

Three accumulating quantities are live, and none of them are connected to a
region.

**Fatigue** accumulates per rally in `GameManager._apply_rally_dynamics`:
`RALLY_FATIGUE_BASE = 0.0035` for everyone on court, plus each player's floor
recovery cost, plus `RALLY_FATIGUE_DECISIVE = 0.006` for whoever ended it. It is
scaled per player by `stamina_fatigue_scale`, which maps stamina 0–100 onto a
1.4–0.6 multiplier, and it reaches the rally through `_rating`'s
`(1 − fatigue × 0.18)`. Over a long match that is a rating difference of roughly
eight to eighteen percent between a low- and high-stamina roster. **The Pāwa
Hitō story is already half-built and nobody has attached it to Pāwa Hitō.**

**Familiarity** updates live: `Familiarity.record_exposure` is called at four
sites inside the resolver, so defenders genuinely learn a hitter's spin and read
tags as a match goes on. Nothing regional modulates how fast.

**Adaptation** exists on the opponent as `block_adaptation_strength`,
`floor_defense_adaptation_strength` and `serve_receive_adaptation_strength`,
surfaced through `_adaptation_bonus` and already stamped on block events. It is
opponent-only and has no home-side counterpart.

So the substrate is there. What is missing is that a region cannot say anything
about its own *rate* on any of these.

## The model change

Regional identity should be expressed in two layers rather than one.

### Layer 1 — dispositions (what they do on any given ball)

The existing seven axes, with the three threshold axes given real magnitude.
This is the tuning-shaped work and it is a prerequisite: an identity cannot form
over a match on top of an axis that does nothing per rally.

### Layer 2 — curves (how they change across a match)

A small set of per-region *rates*, applied to state that already accumulates:

- **`fatigue_resistance`** — a multiplier on the region's contribution to
  `stamina_fatigue_scale`. Pāwa Hitō's identity is that their curve is flat.
  This is the cheapest of the four and the most legible: a team that is as good
  in set five as in set one is something a player feels without being told.
- **`read_rate`** — a multiplier on `Familiarity.record_exposure` amounts, and on
  how quickly the setter's option evaluation stops misreading. Taktikã's whole
  brief. It also gives Taktikã the thing it currently lacks entirely: a reason to
  be feared that is not a rating.
- **`adaptation_rate`** — the home-side counterpart of the opponent's existing
  adaptation strengths, governing how fast a side re-aims its block and floor
  defence at the pattern it has been shown. Bloc du Larg's "methodical court
  reading" is this, and it is currently spelled as one block constant.
- **`composure_decay`** — how much the accumulated confidence and flow state
  swings under pressure. Already half-present as `emotional_expression`'s
  volatility multiplier; the change is to make it act on a *running* quantity
  rather than a per-rally one.

Landavol sits at 1.0 on every curve, exactly as it sits at 0.50 on every
disposition — and that is finally a meaningful position rather than an absence,
because a curve of 1.0 is a team whose fourth set looks like its first. That is a
real identity in a league where everyone else bends one way or the other, and it
matches the tagline's actual claim, which is about breadth rather than about
having no character.

### Presentation

A curve nobody can see is a curve that does not exist. The two candidates:

- The match centre already has a caption layer and a cognition layer. A regional
  curve turning is a legible beat — "Taktikã have seen this set three times now"
  — and it is the first thing in the game that would explain *why* the fourth set
  went differently.
- The journal is where a season's worth of these should aggregate: not "Pāwa
  Hitō, physical 4", but the shape of their sets.

## Sequence

1. Give `tempo_variation` and `transition_commitment` magnitude, and re-run the
   probe. Spëddigh and Pāwa must separate from each other and from Landavol
   before anything else is built on them.
2. Read opponent principles wherever home principles are read. Mostly
   mechanical, and it doubles the reach of everything above.
3. Add `fatigue_resistance` first of the four curves — the state it rides on is
   already accumulating at a magnitude that matters, so it is the one that can be
   verified fastest.
4. Then `read_rate` and `adaptation_rate`, which need their substrate extended
   (home-side adaptation does not exist yet).
5. Give A'ace a tradeoff. Seven axes above neutral with no cost is not an
   identity.

Each step is measured with the same probe, before and after. Three of these are
exactly the failure `docs/FAILURE_MODES.md` §0 describes — a threshold placed
outside the distribution it acts on — and two of them are already that today.

## Implementation status

Landed (this pass), in the sequence argued above:

**R1 — magnitude for the two dead axes.** Tempo is an integer 0–3, so a
continuous input cannot become a fractional shift; it becomes the *probability*
of the shift. `COMMITMENT_FULL_PULL` is the largest deviation from neutral the
regional table actually contains (blended commitment runs 0.30 to 0.84 around
0.50), so the extremes act on every eligible set and Landavol on none.
`tempo_variation` is read as what it is — a rate — so it needs no constant at
all, and reaches a second step only in proportion to how far past neutral it
sits. Draws are hashed rather than taken from `rng`, because adding to the
random stream would move every seeded fixture for reasons unrelated to identity.

Measured, nearest-neighbour separation before → after: minimum across the league
0.431 → **0.567**, Spëddigh 0.716 → **0.897**, Ispayk 0.431 → 0.834. The probe
also gained a `tempo_sd` column, because the first version reported only the
mean — and the mean of a distribution whose *width* is the whole identity is the
§0 error committed with the instrument instead of the model. Spëddigh now holds
the widest spread (0.993) and Pāwa Hitō the fastest mean with a narrow one
(1.86 / 0.901): unpredictable against relentless, which is the distinction the
table always claimed and never produced.

**R2 — the opponent reads its own principles.** `_identity_tempo_shift` is now
one function for both sides, and the opponent's serve risk takes the same
`(serve_aggression − 0.5) × 0.70` the home side has always taken. It previously
read only `_rating(opponent_server, "serve_aggression")` — a roster attribute,
and the vertical slice's roster is mirrored, so **the opponent's serve-error rate
was provably identical for every region**. It now runs 0.093 (Bloc du Larg, 0.30)
to 0.133 (Xérvu, 0.92).

Still home-only: `pin_focus` on lane choice and `emotional_expression` on
confidence volatility. Neither has an opponent-side counterpart to mirror into —
the opponent picks its lane from `tendencies.preferred_lane` rather than from a
weighted candidate list — so those are new mechanism rather than a wiring fix.

**R3 — an opponent is from somewhere.** `OpponentTeam.region`, with
`principles()` preferring it over the preset. Safe because
`REGIONAL_PRINCIPLES.Landavol` and `PRESETS.Balanced` are the same seven 0.50s —
asserted in the suite, so the day either table is edited the mirror control fails
loudly rather than silently.

**R4 — clubs.** `CLUB_NAMES`, two per major region, built on the same device as
the region names. `set_opponent_region` swaps region, club and given names **but
keeps every mirrored attribute**, which is deliberate: a Xérvyan roster with
Xérvyan talent would confound identity with ability on the first rally and no
later measurement could separate them. Any difference across the net is
currently the region and nothing else.

**R5 — the player can see it and change it.** A region picker beside the
opponent panel, and the scouting label now carries region, demonym and tagline.

### Remaining, in order

1. `pin_focus` and `emotional_expression` for the opponent — needs the opponent a
   weighted lane choice and a confidence track of its own.
2. The curves layer: `fatigue_resistance` first, for the reason given above.
3. Taktikã's missing axes (`read_discipline`, `risk_aversion`).
4. A'ace's tradeoff.
5. Regional academies with their own rosters — and note that this is the act that
   *spends* the mirror control, so the symmetry instruments need their own
   fixture pinned to a mirrored opponent before it lands.
