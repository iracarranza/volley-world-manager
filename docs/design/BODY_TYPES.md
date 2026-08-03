# Body types

Design doc. **The secondary layer is implemented; the primary one is not.**

Landed: `body_type` on `VolleyballPlayer` (serialized both ways), uniform
assignment across every region, `BODY_TYPE_METRICS` for height/mass/wingspan,
`BODY_TYPE_ATTRIBUTES` applied to `attribute_ceilings` before storage, and
both generation paths wired. The flat-distribution rule in §1 is enforced by
`_test_body_type_distribution_is_flat`, which fails naming the region and the
type if anyone weights it.

Not landed: **the `SystemFitProfile` shifts of §2**, which is the layer that
makes a type a tactical answer rather than a power level. Until those exist,
body types are stat blocks — precisely what §2 says the feature must not be.
A Cani setter and a Feli setter currently differ in numbers, not in which
system suits them.

Also outstanding: surfacing body type in the UI (it appears nowhere in
`scenes/`), and a ceiling-persistence test across save/load.

---

## 1. What this is

Every player has a **body type** — a morphological variation that shapes both
what they are physically capable of and what kind of system suits them.

It is handled exactly the way academy managers being "arguably alien" is handled
in `docs/world/STYLE_AND_SETTING.md`: **deliberately never pinned down**. Body
types are not a mystery to be solved or a joke to be explained. They have always
existed, everybody has one, and no character in the world remarks on it. The
text never confirms or denies what they are.

### They are a universal constant

**Every region produces every body type in equal proportion.** This is not a
tuning value to be balanced later — it is a fixed property of the world, and the
one rule in this document that must never be softened.

The reason is design intent, not neutrality-by-default. The regional systems
already carry difference: `REGION_SPECIALTY`, the body biases, the talent tier
and positional skews in
`docs/design/REGIONAL_STRENGTH_AND_MINOR_REGIONS.md`. Regions are *supposed* to
feel distinct. If body type were also regionally weighted, it would immediately
read as a proxy for ethnicity — "people from here are built like that" — which
is the one reading this feature must never support. A flat distribution makes
body type orthogonal to origin: a Tu'ul ys Feynt Ursi and a Pāwa Hitō Ursi are
the same body in different traditions, and the *tradition* is what differs.

It is also culturally invisible in-world. No scouting text, news copy, region
tagline, or dialogue treats body type as a category of person, an advantage, or
a divider. It is never a subject. Players are described by what they *do*.

The Charter section of the setting doc already leans this way — volleyball was
chosen partly because it is "playable competitively by very different bodies."
Body types make that line literal.

> **One line to settle in `STYLE_AND_SETTING.md`.** That doc currently says
> "everyone who isn't a manager is human." Body types either sit inside that as
> human morphological variation, or that sentence gets a light edit. This
> document deliberately does not decide it — but the vocabulary should be fixed
> before it reaches twenty strings of news copy.

---

## 2. The mechanism: fit, not stat blocks

The obvious implementation — each type grants attribute bonuses and penalties —
produces types that are simply **better or worse**. What is wanted is types that
are **suited or unsuited**, so that a Cani setter and a Feli setter offer
genuinely different things rather than one being an upgrade.

`scripts/models/system_fit_profile.gd` already models exactly this. Every
profile answers three questions for one player and one tactical quantity:

| field | question |
| --- | --- |
| `ideal_value` | what value does this player naturally want? |
| `tolerance` | how much deviation can they absorb before it hurts? |
| `in_system_bonus` | how much do they gain from landing on the mark? |

Existing axes carry real units — approach distance in metres, set release in
seconds, defensive depth in metres, block engagement distance in metres — and
profiles are cached per player because they derive from career attributes.

**Body type shifts these three fields.** Attribute and body-metric deltas
(§4) are the secondary layer; the fit signature is the primary one, because it
is what makes a type a tactical answer rather than a power level.

### Fit signatures

| type | `ideal_value` | `tolerance` | `in_system_bonus` | reads as |
| --- | --- | --- | --- | --- |
| **Homi** | median | median | median | dependable, unremarkable |
| **Avi** | standard | **narrow** | **high** | precision instrument — lethal on plan, lost off it |
| **Cani** | standard | **wide** | **low** | works anywhere, gains little from perfection |
| **Feli** | **shifted early/fast** | narrow | high | does not want a better plan, wants a *different* one |
| **Ursi** | standard | wide on contact, **narrow on movement** | median | immovable, but only where it already stands |
| **Simi** | standard | narrow | **very high on touch axes** | flawless when set up, absent when not |

Avi and Cani are deliberately the same total value expressed in opposite
directions. That symmetry is what stops either being strictly better, and it is
the template every future type should follow.

**The tolerance/bonus trade must be zero-sum.** A wide-tolerance type that also
gained normally from being in system would simply be better. Cani buy their
range by gaining almost nothing from perfect conditions; Avi buy their ceiling
by collapsing outside a narrow band.

---

## 3. The six types

**Homi** — the baseline. No modifiers. The majority of any population, the
default for saves written before this feature, and genuinely the right pick for
a manager who changes system often.

**Avi** — reach and vertical, light frame. Gets above the net faster and higher
than anything else and hits softer for it.

**Cani** — stride, endurance, ground-generated power. The anti-Avi: covers
ground nobody else reaches, never leaves the floor.

**Feli** — burst and twitch. Explosive over two metres, fading over five sets.

**Ursi** — mass and anchorage. Eats pace, immovable at the net, cannot cover
ground.

**Simi** — hands and dexterity. The finest touch in the game and no physical
presence at all.

---

## 4. Deltas

First-pass magnitudes. These need a multi-career sweep before they are trusted —
one career is one sample (`fixture_base_seed()` hashes the career name).

### Body metrics

| type | `height_cm` | `mass_kg` | `wingspan_cm` | `stride_length_m` |
| --- | ---: | ---: | ---: | ---: |
| Homi | 0 | 0 | 0 | 0 |
| Avi | −4 | −7 | +6 | 0 |
| Cani | 0 | +2 | 0 | **+0.09** |
| Feli | −3 | −4 | 0 | −0.03 |
| Ursi | +1 | **+11** | +1 | −0.05 |
| Simi | −6 | −5 | +2 | −0.02 |

### Attributes

| type | up | down |
| --- | --- | --- |
| Avi | `jump_reach`, `block_timing` | `reception_stability`, `attack_power`¹ |
| Cani | `stamina`, `transition_speed`, `attack_power` | `jump_reach`, `hand_control` |
| Feli | `explosiveness`, `lateral_speed`, `dig_control`, `set_disguise` | `stamina`, `tactical_discipline` |
| Ursi | `reception_stability`, `attack_power`, `composure` | `acceleration`, `lateral_speed`, `jump_reach` |
| Simi | `hand_control`, `ball_control`, `finesse`, `tooling` | `attack_power`, `jump_reach` |

¹ Avi's attack power falls out of the mass delta automatically —
`usable_attack_power()` is mass-derived — so it should **not** also be applied
as an attribute penalty or it is counted twice.

### Two deltas that are load-bearing rather than cosmetic

**Feli `stamina`.** `GameManager.stamina_fatigue_scale()` reads `stamina`
directly to scale per-rally fatigue accrual, so a low-stamina Feli measurably
tires faster *within a single match*. They are first-set terrors and fifth-set
liabilities, with no new mechanism required — it emerges from the fatigue system
already in place.

**Cani `stride_length_m`.** The locomotion model consumes stride directly, so
Cani coverage is real movement rather than a rating. Their wide `tolerance` and
their stride are the same trait seen from two directions.

### Free propagation

Body-metric deltas flow automatically through everything already derived from
them: `reach_rating()`, `usable_attack_power()`, `baseline_defensive_range()`,
`standing_reach_cm()`, `jumping_reach_cm()`, and the locomotion model. No new
wiring. This is the main argument for expressing body type through metrics
wherever possible rather than through bespoke attribute bonuses.

---

## 5. Ceilings, not just starting values

**Body type must shift `attribute_ceilings`, not only generated values.** This
is the single decision that determines whether the feature survives a career.

If an Avi starts with more `jump_reach` but carries the same ceiling as
everyone, training converges them and body type quietly evaporates over a few
seasons — leaving a character-creation flavour rather than a permanent identity.
The ceiling shift should be the larger of the two effects; the starting-value
shift only decides how quickly the difference becomes visible.

---

## 6. Worked example: six setters

Against the identities in `scripts/models/team_principles.gd` (Balanced,
Defensive, Fast Tempo, Physical, Technical, Development):

| setter | thrives in | why | fails in |
| --- | --- | --- | --- |
| **Avi** | Fast Tempo | high jump-set release, quick overhead hands, tight in-system band | Physical — cannot block, gets served at |
| **Cani** | Defensive / attrition | wide tolerance converts broken plays nobody else reaches | Fast Tempo — worst of the six on a perfect pass |
| **Feli** | Technical | elite disguise; opponents cannot read the distribution | Balanced — low discipline means own hitters sometimes cannot either |
| **Ursi** | Physical | unshakeable under pressure, blocks at the net | anything requiring movement to the ball |
| **Simi** | Technical / Development | finest pure hands when the pass is good | Physical — no net presence |
| **Homi** | Balanced | fine everywhere | nowhere in particular |

Same position, six different **jobs**. No ranking exists without naming a system
first. That property is the point of the whole design, and it is the test any
new type must pass before being added.

---

## 7. Generation

`body_type` is a **categorical trait**, not an ability attribute. Follow the
`dominant_hand` pattern exactly:

```gdscript
@export_enum("Homi", "Avi", "Cani", "Feli", "Ursi", "Simi")
var body_type: String = "Homi"
```

with `to_dict()`/`from_dict()` carrying a `"Homi"` default so saves written
before this feature load unchanged.

**It must not be added to `ABILITY_ATTRIBUTES` or `CATEGORY_ATTRIBUTES`.** A
regression check sums those in both directions and will fail loudly if a
non-ability lands in them — which is exactly what caught `work_rate`.

Assignment happens in `player_generator.gd`, drawn **uniformly, with no regional
weighting whatsoever** (§1). Order of application: region bias first, then body
type, both additive on the same body metrics. Body type is applied second so a
Landavol Ursi and a Pāwa Hitō Ursi differ by their region's bias and by nothing
else.

---

## 8. Perception

This is what makes player portraits worth building. The current
`PlayerActor3D` rig cannot distinguish two players — `Color("d6a06c")` is
hardcoded three times for head, arms and legs, with no hair or facial variation
and no cosmetic data on the model at all.

Body type fixes that at the **silhouette** level rather than the detail level,
which is what actually reads at portrait size: a light long-limbed Avi and a
broad heavy Ursi are distinguishable as thumbnails, where two humans with
different faces are not. The rig already scales limb length and body height from
`height_cm`, `wingspan_cm` and `stride_length_m`, so the metric deltas in §4
drive the visual difference with no separate art pipeline.

It also gives the manager a **prior**: body type is the at-a-glance read that
the attribute wheel then confirms or subverts. A Cani middle blocker is
immediately interesting precisely because the type argues against it.

---

## 9. Balance risks

**Ursi is the most likely to come out accidentally dominant.** Mass feeds
`usable_attack_power()` *and* `reception_stability`, so it buys two of the most
valuable things in the game. Its movement penalty is only a real cost if the
defensive systems punish immobility hard enough — verify that before trusting
the numbers.

**Avi's mass penalty must not be double-counted** (see §4 note 1).

**Watch for positional collapse.** If any type turns out strictly best at a
position across *all* six identities, the fit signature is not doing its job and
the type needs re-shaping rather than a numeric nerf.

**Feli fatigue interacts with a system that was only just fixed.** Weekly
recovery and stamina scaling landed recently; a type built on low stamina should
be swept specifically for whether it is merely weak rather than differently
strong.

---

## 10. Verification

- Full suite before and after. Body type should add checks, not move existing
  ones; a moved count means generation changed for players who should be
  unaffected.
- **Distribution flatness, as a regression check.** Generate a full world and
  assert each body type's share is within tolerance of `1/6` **in every
  region**. This is the rule most likely to be broken silently by a later
  well-meaning change, and the one with the worst consequences if it is.
- **Back-compat**: a save written before this feature loads with every player as
  `Homi` and no crash.
- **Ceiling persistence**: simulate several seasons of training and assert two
  types have not converged on their signature attributes.
- **Fit symmetry**: assert no type has both wider tolerance and higher
  in-system bonus than another on the same axis — the zero-sum rule from §2.
- Sweep across at least six career names for any balance figure.
