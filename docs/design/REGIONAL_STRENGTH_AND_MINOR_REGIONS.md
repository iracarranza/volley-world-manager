# Regional strength, minor regions, and the Sixnet standing model

Design handoff. Nothing here is implemented yet.

**Status of the tree this was written against.** The container this was drafted
in sits at `0bd0809` and does *not* contain the merged Codex work
(`team_principles.gd`, `work_rate`, satisfaction/confidence/cohesion, the
regional identity revisions, the world-generation redistribution, or the attack
calibration fixes). Every line number and constant below was read from
`0bd0809`. The **architecture** should survive that merge; the **specific
constants and identity data almost certainly moved**, since Codex revised
`regions.gd`, `player_generator.gd` and `world_population.gd` — the same three
files this design touches. Re-read those before implementing.

---

## 1. The problem this solves

`career.region_power` currently means two incompatible things.

`SixnetLeague.bootstrap_rating()` returns the mean `current_ability_score()` of
a generated **Academy** roster — an absolute measure on the ability scale,
comparable between any two regions whether or not they ever play each other.
`ensure_bootstrapped()` seeds `region_power` with it.

`apply_power_update()` then overwrites that same field with

```gdscript
var target := lerpf(30.0, 90.0, win_rate)
career.region_power[region_name] = clampf(lerpf(current, target, POWER_SEASON_PULL), ...)
```

— a relative measure derived purely from results inside a closed pool of eight.
Within a few seasons the absolute information is gone.

Three consequences:

1. **Minor regions cannot be compared to Sixnet regions at all**, because they
   have no results in that pool. There is no shared axis.
2. **The Sixnet is a closed loop.** Total wins always equal total losses, so the
   mean win rate is always 0.5 and the mean of `region_power` drifts toward
   `lerp(30, 90, 0.5)` = 60 forever. If the world's talent rose or fell, this
   number could not show it.
3. **Influence drift reads the wrong quantity.** It decides whose *training
   tradition* spreads from bracket results rather than from whether the region
   actually develops better players.

---

## 2. Four quantities

```gdscript
## Absolute. Academy production quality. Every region in DEFINITIONS.
## Blend of prime and depth -- see §5. Never touched by results.
@export var region_strength: Dictionary = {}          # region -> float

## Relative. Competitive standing inside the Sixnet pool only.
## Today's region_power renamed; the win-rate lerp is unchanged.
@export var sixnet_form: Dictionary = {}              # region -> float

## Accumulated Sixnet pedigree. Decays each season. Added to standing,
## never folded into strength or form.
@export var sixnet_prestige: Dictionary = {}          # region -> float

## Rolling snapshots of each region's best seven -- see §6.
@export var region_prime_history: Dictionary = {}     # region -> Array[Dictionary]
```

**Standing is derived, not stored**, so it cannot drift out of sync:

```gdscript
static func region_standing(career: Resource, region_name: String) -> float:
    var base := challenge_standing(career, region_name)
    return clampf(base + float(career.sixnet_prestige.get(region_name, 0.0)), 0.0, 100.0)


## Standing with the prestige term removed. Used for relegation challenges
## (§7) -- outsiders have no prestige, so stripping it removes only the
## incumbent's advantage, which is exactly the intent.
static func challenge_standing(career: Resource, region_name: String) -> float:
    return lerpf(
        _normalised_strength(career, region_name),
        _normalised_form(career, region_name),      # 50.0 when outside the Sixnet
        STANDING_FORM_WEIGHT,
    )
```

```gdscript
const STANDING_FORM_WEIGHT: float = 0.40
const PRESTIGE_DECAY: float = 0.75              # applied at each season boundary
const PRESTIGE_CHAMPION: float = 12.0
const PRESTIGE_CHAMPIONSHIP_PLACE: float = 4.0
const PRESTIGE_QUALIFIER_WIN: float = 3.0
const PRESTIGE_RELEGATION: float = -5.0
```

**Normalisation is load-bearing and must be calibrated, not assumed.**
`region_strength` lives on the ability scale; `sixnet_form` lives on an
arbitrary 30–90 band clamped to 10–95. Measure the real spread of
`region_strength` across all regions on the target tree before fixing
`_normalised_strength()`'s endpoints.

**Form decays for non-participants.** A region outside the Sixnet should have
`sixnet_form` decay toward neutral (50) each season rather than freeze, so a
region absent for a decade is judged on its academies rather than on a result
from ten years ago.

---

## 3. Minor regions

A fourth tier: regions that exist and produce players but contest neither the
Sixnet nor (by default) the top of the standings table.

`SixnetLeague` iterates explicit lists (`SIXNET_PARTICIPANTS`, `CORE_REGIONS`)
rather than `DEFINITIONS`, so minor regions are excluded from bracket logic with
**no changes to the league engine**.

```gdscript
const MINOR_REGIONS: Array[String] = ["Tu'ul ys Feynt", ...]

## Drift scope becomes core + minor. Ispayk and A'ace stay out: per the
## existing comment in regions.gd they have no development tradition to
## spread or absorb -- their identity is history and money, not geography.
const DEVELOPMENT_REGIONS: Array[String] = CORE_REGIONS + MINOR_REGIONS
```

Naming convention for this tier: **the name encodes the specialty**
("Tu'ul ys Feynt" → feinting). Worked example:

```gdscript
"Tu'ul ys Feynt": {
    "tagline": "Village halls where the ball is won by the shot the blocker
                didn't believe -- wrists over power, patience over height.",
    "physical": 1, "technical": 3, "mental": 1,     # sum 5 vs the core 6-8
    "names": [...],
}
# REGION_SPECIALTY:        ["feinting", "tooling", "finesse"]   # 3, not 6
# REGION_HEIGHT_BIAS:      -3.0      MASS: -4.0     WINGSPAN: -2.0
# REGION_BIRTH_WEIGHTS:     0.25
# REGION_PULL:              0.55     # loses its best to bigger programs
```

`home_region` and `club_region` are already separate fields and both are
surfaced on the roster bio panel, so the talent-drain story is visible in the UI
for free: you scout a Tu'ul-raised specialist playing in Landavol.

The intended outcome is a player who grades ~C by `current_ability_score()` —
because `POSITION_WEIGHTS` scores an outside hitter on power and accuracy, and
feinting is tertiary for them — while sitting near S on three attributes. A
hidden gem, not merely a worse player.

### Tradition resistance

`REGION_ADJACENCY` drives influence drift, and the rule is: if the strongest
neighbour's gap exceeds `DOMINANCE_THRESHOLD` (15) the region **blends** toward
them, otherwise if its own power is below `ISOLATION_THRESHOLD` (40) it
**intensifies** its own specialty.

A minor region is by design far weaker than any major neighbour, so the gap
essentially always exceeds 15. Left alone, minor regions would **always blend
and never intensify** — culturally absorbed within a few seasons, losing exactly
the specialisation that justifies the tier. The isolation branch, which is the
one that actually describes a small stubborn tradition, would never fire.

Fix, decided:

```gdscript
const REGION_TRADITION_RESISTANCE := {
    "Tu'ul ys Feynt": 1.0,      # needs double the usual gap to be absorbed
}   # majors absent -> 0.0 -> behaviour unchanged

var threshold := DOMINANCE_THRESHOLD * (1.0 + resistance)
var gap := strength_of(neighbour) - strength_of(region)     # strength, not form
if gap > threshold:                               blend
elif strength_of(region) < ISOLATION_THRESHOLD:   intensify
```

Absorption stays possible — a small tradition *can* die, which is a good story —
but it becomes a slow risk rather than a certainty.

**`ISOLATION_THRESHOLD` must be re-derived.** It is currently `40.0` calibrated
against the power scale. Moving the check onto strength will otherwise make the
intensify branch fire for everyone or for no one.

### Anti-inflation: specialty budget

Influence drift is currently a one-way ratchet. Blending adds an attribute to
`specialty_add` (more attributes receive the `+8`); intensifying raises
`specialty_bonus_delta` (`+8` toward `+14`). **Both branches only ever add.** If
`region_strength` is recomputed from generation each season, every region's
academies get monotonically stronger forever — destroying the one property the
absolute axis exists to provide.

Decided fix: make the specialty bonus a **fixed budget per region** rather than a
per-attribute constant.

- Intensifying concentrates the same budget onto fewer attributes → sharper spike
- Blending spreads it across more → flatter, broader profile
- Nothing is created

This removes the inflation *and* makes minor regions fall out of the same rule
rather than needing special-casing: Tu'ul gets a small budget concentrated on
three attributes (weak overall, extreme spike); Landavol spreads a normal budget
across many and spikes nowhere. "Specialised vs broad" becomes one dial.

---

## 4. Per-region tier share

Today every region draws talent from the same region-blind uniform:

```gdscript
static func _talent_level(rng: RandomNumberGenerator, academy: bool) -> int:
    return rng.randi_range(62, 92) if academy else rng.randi_range(48, 90)
```

So **no region can be star-heavy or depth-heavy** — the archetypes this whole
design discriminates between are not currently generatable.

Meanwhile `WorldPopulation.TALENT_TIERS` already models scarcity properly:
8 generational players alive worldwide (deliberately not scaling with population
size), 24 elite, 62 standout, with solid/squad/fringe splitting the remainder by
weight.

`REGION_BIRTH_WEIGHTS` decides **how many** players a region produces. Add a
companion deciding **what they look like**:

```gdscript
## Per-tier multipliers on a region's birth share. Above 1.0 means the region
## is over-represented in that tier relative to how many players it produces.
##
## The world totals are INVARIANT. There are still exactly 8 generational
## players. This redistributes which regions they come from; it never creates
## more. That invariant is the entire point of the scarcity model -- finding a
## generational player must stay an event.
const REGION_TIER_AFFINITY := {
    "Pāwa Hitō":    {"generational": 1.9, "elite": 1.6, "standout": 1.3,
                     "solid": 0.9, "squad": 0.8, "fringe": 1.1},
    "Bloc du Larg": {"generational": 0.5, "elite": 0.8, "standout": 1.1,
                     "solid": 1.4, "squad": 1.3, "fringe": 0.7},
    "Tu'ul ys Feynt": {"generational": 0.3, "elite": 0.6, "standout": 1.0,
                     "solid": 1.2, "squad": 1.2, "fringe": 1.1},
}   # regions absent default to 1.0 across the board -- unchanged behaviour
```

**Implementation.** Tier is chosen before region (scarce tiers are apportioned
across birth cohorts first, in `generate()`). So the region picker — the
cumulative-weight loop around `world_population.gd:328` — needs the tier key
passed in, and its weight becomes:

```gdscript
REGION_BIRTH_WEIGHTS.get(r, 1.0) * _tier_affinity(r, tier_key)
```

Keep affinity values within roughly `[0.3, 2.0]`. The existing guarantee that
every region gets a scoutable prospect in the two youngest bands must still
hold — check it against low-affinity minor regions specifically.

This validates against fiction that is **already written**:

- Pāwa Hitō — *"showcase academies favor explosive approaches and attacking
  ambition"* → star-producing, high variance, thin depth
- Bloc du Larg — *"methodical halls teach net control, court reading and patient
  structure"* → depth-producing, low variance

The taglines describe these archetypes; generation just doesn't implement them.

---

## 5. Strength aggregation

The question this answers: *should a region with 3 superstars and a mediocre
rest rank above or below a region with 12 uniformly good players?*

Today it cannot be answered — `bootstrap_rating()` takes a **plain mean** of a
synthetic roster drawn from a region-blind uniform. Both archetypes collapse.

### Measure the real population, not a synthetic roster

`region_strength` should read the actual world population filtered by
**`home_region`** — production, not acquisition. This makes tier scarcity flow
through automatically (a region that produced 2 of the world's 8 generational
players *shows* it) and deletes a synthetic sampling path that can disagree with
the real world.

It also makes A'ace's identity mechanically real: high `club_region`
concentration through `REGION_PULL`, weak `home_region` production.

> **Ordering blocker.** `ensure_bootstrapped()` runs at `career_manager.gd:79`,
> *before* `world_population` is generated at line 85. That order has to swap, or
> bootstrapping must go lazy.

### Prime and depth

Volleyball fields six who all rotate through the back row, and at least three
receive serve. The libero hides exactly one weak passer — not four. So the
aggregate needs a genuine weak-link term, and it must be **positional**: three
superstars at one position are worth far less than three across different ones.

```gdscript
## A regional "best XI" equivalent -- the seven a region would field.
const REGIONAL_BEST_SEVEN := {
    "Setter": 1, "Outside Hitter": 2, "Middle Blocker": 2,
    "Opposite": 1, "Libero": 1,
}
```

```gdscript
## Prime: the best seven this region could put on court, by position.
## Shape mirrors AttributeProfiles.category_score() -- average-dominant with a
## standout bonus and a weak-spot penalty -- which is already this codebase's
## idiom for that aggregation. The weights differ because the situations do:
## for a player's skill profile the weak axis is always exposed, whereas for a
## region the weak *members* simply are not selected. Hence pooling to the
## seven first, then weighting the weak link heavily inside it -- the seventh
## starter still rotates and still passes.
prime = mean(seven) * 0.70 + best(seven) * 0.15 + min(seven) * 0.15

## Depth: the next seven, matching roster_limit 14. About having replacements,
## not about spikes, so a plain mean is right.
depth = mean(players ranked 8..14)

region_strength = prime * PRIME_WEIGHT + depth * (1.0 - PRIME_WEIGHT)
const PRIME_WEIGHT: float = 0.65
```

Positional selection does the discriminating work for free: a region with three
stars all at outside hitter counts only its best two, and its `min(seven)` is
dragged down by whatever it has at setter and libero.

Worked example on the raw seven (before positional constraints):

| | seven | mean | best | min | **prime** |
|---|---|---|---|---|---|
| 3 stars + mediocre | 95, 93, 92, 60, 58, 57, 56 | 73.0 | 95 | 56 | **73.7** |
| 12 good | 78, 77, 76, 76, 75, 74, 74 | 75.7 | 78 | 74 | **75.8** |

Depth edges it — enough to rank higher, not enough to make stars worthless. The
star region still owns a 95 that decides individual matches and transfer value,
and if its three stars sat at three *different* positions it would win.

---

## 6. Tracking the best seven through a season

```gdscript
## region -> Array of {"week": int, "prime": float, "seven": Array[int]}
@export var region_prime_history: Dictionary = {}
```

Snapshot at each season boundary (and optionally mid-season). **Cap the array**
— last ~20 entries — or saves grow without bound; the career file is rewritten
every week.

This gives two distinct readings:

- **current prime** — form-sensitive, what the region can field right now
- **peak prime** — the ceiling it has ever reached, i.e. its golden era

Feeds the news panel ("a Tu'ul ys Feynt generation peaks"), a world-rankings
screen, and scouting. `region_strength` itself uses current prime; peak is
narrative and UI.

---

## 7. Relegation by prestige-stripped challenge

Bottom Sixnet teams are **not** auto-relegated. Instead their prestige is
removed for the comparison, and an outsider who still outranks them takes the
slot. Prestige is the incumbent's benefit of the doubt; you must be beaten on
merit alone to lose it.

At the season boundary, after the qualifier resolves:

- **Eligible to be challenged:** participants who failed to reach the
  championship. With `QUALIFIER_ADVANCE_COUNT = 2` of 4, that is the two
  lower-bracket teams that lost the qualifier.
- **Challenger:** the highest `challenge_standing()` among non-participants.
- **Swap if** `challenger > incumbent + CHALLENGE_MARGIN`.

`CHALLENGE_MARGIN` provides hysteresis — without it a region that ties by 0.01
ping-pongs in and out every season. Rarity then comes from the right place:
Sixnet regions genuinely have stronger academies, so an outsider needs both a
real strength edge *and* a bad incumbent season for form to drag them under.

A relegated region keeps decaying prestige, so it fades over several seasons
rather than falling off a cliff, and can climb back.

> **Refactor blocker.** `SIXNET_PARTICIPANTS` is a `const Array` and
> `apply_power_update()` iterates it directly. Once membership can change,
> participation must be read from `career.sixnet_slots.values()`; the const
> demotes to "founding members at world creation". Every loop over that const
> needs auditing — the failure mode is a relegated region quietly still
> accruing form.

---

## 8. Squad shape (context for tuning)

`Team.roster_limit` is already `14` (range 6–18), which is the right range and
should stay. Volleyball allows six substitutions per set, so depth beyond a
match squad cannot express itself; a 25-player roster would leave most players
never touching the floor, make cross-training pointless, trivialise the fatigue
decisions, and flatten the team-aggregate wheel.

Target shape: 6–7 clear starters, 2–3 genuine single-skill specialists (where
minor-region players shine), 4–5 developing.

Within the starting six, balanced-strong beats six specialists — volleyball is a
system sport and `POSITION_WEIGHTS` plus the system-fit machinery already encode
that. The rare transcendent talent comes from `golden_birth_years`, which
already exists; the tunable is **how rare**, not which philosophy.

**Caution:** a top-heavy 14 is brittle against `availability`, because
`match_roster_errors()` blocks the match outright on an incomplete lineup. Two
unavailable specialists should not make the game unplayable — either hold the
floor near 14 or make an incomplete lineup a penalty rather than a hard block.

---

## 9. Implementation order

1. **Split the fields.** `region_power` → `region_strength` + `sixnet_form`,
   with `to_dict`/`from_dict` and a back-compat read (an old save's
   `region_power` seeds both). No behaviour change yet.
2. **Swap the bootstrap ordering** so the world population exists first, and
   repoint strength at `home_region` instead of a synthetic roster.
3. **Prime/depth aggregation** (§5) plus `region_prime_history` (§6).
4. **Specialty budget** (§3) — do this *before* drift starts reading strength,
   or the first seasons inflate.
5. **Rewire drift** to dominance-by-strength with tradition resistance, and
   re-derive `ISOLATION_THRESHOLD`.
6. **Tier affinity** (§4).
7. **Minor regions** as data.
8. **Standing, prestige, and the challenge relegation** (§2, §7), including the
   `SIXNET_PARTICIPANTS` refactor.

## 10. Tests worth pinning

- **Tier conservation:** total generational players across all regions is
  exactly 8 for any affinity table. Same for elite and standout.
- **Anti-inflation:** run 20 synthetic seasons of drift; mean `region_strength`
  across all regions must not trend upward. This is the invariant most likely
  to rot silently.
- **Positional discrimination:** a region with three stars at one position
  scores lower prime than the same three spread across three positions.
- **Depth vs stars:** the §5 worked example, pinned as a regression.
- **Challenge rarity:** across N synthetic seasons, external relegation fires
  rarely rather than every year — and never leaves the bracket at other than
  8 slots.
- **Back-compat:** a save written before the split loads with both fields
  populated and no crash.

## 11. Open questions

- Should sustained Sixnet success feed back into academy strength (results →
  investment → better academies)? Deliberately excluded above to keep strength
  clean, but it is the obvious next loop.
- Should minor regions ever appear in `REGION_ADJACENCY` as neighbours *of*
  majors (donating flavour upward), or only take influence? Currently specced
  as symmetric with resistance.
- `STANDING_FORM_WEIGHT`, `PRIME_WEIGHT`, `CHALLENGE_MARGIN` and the prestige
  constants are all first guesses and need a multi-career sweep, not a single
  seed — `fixture_base_seed()` hashes the career name, so one career is one
  sample, not a result.
