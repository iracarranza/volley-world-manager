# Body types

Design doc. **The secondary layer is implemented; the primary one is not.**

Landed: `body_type` on `VolleyballPlayer` (serialized both ways), uniform
assignment across every region, `BODY_TYPE_METRICS` for height/mass/wingspan,
`BODY_TYPE_ATTRIBUTES` applied to `attribute_ceilings` before storage, and
both generation paths wired. The flat-distribution rule in §1 is enforced by
`_test_body_type_distribution_is_flat`, which fails naming the region and the
type if anyone weights it.

Re-checked 2026-08-06 at `1ee4c96`: §2 has not moved — `body_type` still
appears in `player_generator.gd` and `volleyball_player.gd` and in no
system-fit code path. **The "still accurate" that stood here was wrong about
the rest of the doc**, and stayed wrong until 2026-08-30; see the note below.

> **Homi was retired and replaced by Vegi.** Every "Homi" in this file was a
> stale name until 2026-08-30. The live list is
> `["Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi"]`
> (`scripts/domain/body_type_gameplay.gd:7`), and `from_dict()` migrates the
> old string (`scripts/models/volleyball_player.gd:530`).
>
> It was a **replacement, not a rename.** Homi was a plain human, and a human
> default made the other five read as costumes worn over the normal one; Vegi
> is produce, so no type is the baseline everything else departs from. The
> mechanical slot is unchanged — Vegi still carries no modifiers — but "the
> normal body" is not what that slot means any more. Recorded in
> `body_type_models.gd:19` and `body_type_gameplay.gd:13`; the Simi note at
> `body_type_models.gd:2563` is the same decision defended a second time.

Not landed: **the body-type coupling to `SystemFitProfile`** — the layer that
makes a type a tactical answer rather than a power level. Note that
`SystemFitProfile` itself *does* ship (`scripts/models/system_fit_profile.gd`,
read by `rally_simulator.gd`, `approach_mechanics_system.gd` and
`training_projection.gd`); what is missing is body type reaching it. Today
`body_type` enters the simulation at exactly one place,
`rally_simulator.gd:8944`, as a telemetry field. Until the coupling exists,
body types are stat blocks — precisely what §2 says the feature must not be.
A Cani setter and a Feli setter currently differ in numbers, not in which
system suits them.

**And the stat blocks themselves are the wrong shape.** §3 is the reframe:
one physical affordance per type, no technique or mental modifiers, with the
Ursi-setter audit as the worked evidence for why the current table does not
generate anything. §4 and §5 describe what ships; §3 describes what it should
become.

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
body type orthogonal to origin: a Tãul ys Feynt Ursi and a Pāwa Hitō Ursi are
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
(§5) are the secondary layer; the fit signature is the primary one, because it
is what makes a type a tactical answer rather than a power level.

### Fit signatures

| type | `ideal_value` | `tolerance` | `in_system_bonus` | reads as |
| --- | --- | --- | --- | --- |
| **Vegi** | median | median | median | dependable, unremarkable |
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

## 3. The affordance layer

**Status: designed here, not built.** §4 and §5 below still describe the
shipped behaviour. This section is the reframe they should be rewritten
against, and it exists because the question "what does an Ursi setter actually
accomplish?" has a measurable answer today, and the answer is *less than
nothing*.

### The Ursi setter audit

An Ursi's three bonuses are `reception_stability +4`, `attack_power +3`,
`composure +2`. Traced through the second contact:

- **`reception_stability` is switched off for a set by an `if`.**
  `contact_envelope_system.gd:154` folds it into `action_balance`, and `:156`
  overwrites that with `set_balance`/`set_stability` when
  `action_type == &"set"`. `_horizontal_reach()` does the same substitution at
  `:204`–`:206`. The bonus is discarded on both paths a setter uses.
- **`attack_power` never reaches the second contact at all.**
- **`composure` reaches it, at `setter_capability_system.gd:103`, weighted
  0.25 of a /100 term.** A +2 ceiling is therefore worth **+0.005** on a
  `command` value that runs 0–1.

The three penalties do land. `jump_reach −2.5` shrinks `accessible_jump` and so
the setter's own `maximum_contact_height_meters`; `acceleration −3.5` and
`lateral_speed −3.0` slow them to the ball.

So an Ursi setter is a setter with a **smaller contact envelope, slower arrival,
and five thousandths of extra command**. That is not a different tactical
answer. It is the same setter, worse.

### Why: the body layer is not made of body

Classified against `attribute_registry.gd`'s own three lists, the 26 modifiers
in `BODY_TYPE_ATTRIBUTES` are:

| category | count | examples |
| --- | ---: | --- |
| `PHYSICAL_ATTRIBUTES` | 13 | `jump_reach`, `lateral_speed`, `stamina` |
| technique (ability, not physical) | 11 | `set_disguise`, `hand_control`, `tooling`, `reception_stability` |
| `MENTAL_ATTRIBUTES` | 2 | Ursi `composure +2`, Feli `tactical_discipline −5.5` |

Fewer than half of the body layer is body. **Simi is the extreme case**: four of
its six modifiers are technique and only its two penalties are physical, which
makes "Simi" a synonym for *is good at volleyball with their hands* — so a Simi
with poor `hand_control` is handed the ceiling to become a good setter for
reasons the fiction never earned. **Ursi and Feli are the categorical error**:
a morphology is reaching into the mind. Nothing about being heavy is composure.

### The six affordances

One physical rule per type; the volleyball attributes decide whether the player
can exploit it.

| type | affordance | it changes |
| --- | --- | --- |
| **Avi** | **Reach** | the spatial envelope of contact, especially vertically |
| **Cani** | **Sustain** | how much work the body repeats before it decays |
| **Feli** | **Switch** | how fast the body changes state or direction |
| **Ursi** | **Anchor** | how much disruption the body tolerates *during* contact |
| **Simi** | **Manipulate** | how finely contact with the ball can be controlled |
| **Vegi** | none | no dominant affordance |

Anchor is the load-bearing rename. "Big and slow" is a static advantage and
generates nothing; "how compromised may this body be and still deliver" is a
question every position can answer differently:

| Ursi at | the same rule produces |
| --- | --- |
| setter | delivers a clean ball from ugly body states — landing, off-balance, straight out of a defensive contact |
| hitter | keeps force through awkward contacts; hard to knock out of attack posture |
| blocker | stable press, resists being washed off or displaced |
| receiver | absorbs driven pace without the body destabilising |
| defender | poor coverage radius, near-certain if the ball enters the space they hold |
| server | strong momentum transfer, poor recovery after it |

### The setter benchmark

Six bodies, six different solution spaces, same position:

| | the sentence the setter can say |
| --- | --- |
| Vegi | conventional envelope |
| Avi | "I can take that above you." |
| Cani | "I can get to that." |
| Feli | "I can get set before you expect." |
| Ursi | "I can still deliver this with my body wrecked." |
| Simi | "I can make the ball do something the others cannot." |

### The two tests that replace "six different jobs"

1. **Same body, six positions, six emergent uses** — the affordance is portable.
2. **Same position, six bodies, six solution spaces** — the affordance is
   distinguishing.

The old §2 test ("same position, six different jobs") passes for a set of
disguised classes. These two do not.

Neither is greppable, so they need a mechanical companion. The cheapest one that
would have caught the two real defects above:

> **No body type may modify an attribute in `MENTAL_ATTRIBUTES`, and no body
> type may modify a technique attribute** — only `PHYSICAL_ATTRIBUTES` and the
> affordance parameters. One loop over `attribute_registry.gd`; fails naming the
> type and the attribute.

That check fails today on Ursi/`composure`, Feli/`tactical_discipline`, and
eleven technique modifiers.

### Where each affordance attaches

The reframe is cheaper than it looks, because the seams exist and are live:

| affordance | existing seam |
| --- | --- |
| Reach | `ContactEnvelopeSystem` — `maximum_contact_height_meters`, `_horizontal_reach()` |
| Sustain | `GameManager.stamina_fatigue_scale()` and per-rally fatigue accrual — **not** `stride_length_m`, which is spoken for (§5) |
| Switch | `acceleration`; `recovery_time_seconds` in the contact envelope |
| **Anchor** | `ContactEnvelopeSystem.balance_factor` and its `posture_factor`, keyed on `RallyPlayerState.BodyState`; and `SystemFitProfile.tolerance_scale` |
| Manipulate | the per-action quality readers |

`BodyState` is already `{BALANCED, MOVING, REACHING, DIVING, AIRBORNE,
RECOVERING}` — **five of the six are compromised states**, already passed into
`ContactEnvelopeSystem.evaluate()`, already degrading `balance_factor`. Anchor
is a coefficient on a degradation the simulation performs every contact.
`SystemFitProfile` is likewise no longer hypothetical: it ships, it is read by
`rally_simulator.gd`, `approach_mechanics_system.gd` and
`training_projection.gd`, and its header already reserves `tolerance_scale` for
"transient state (fatigue, balance) applied by the caller". That is the Anchor
hook, named in advance by someone solving a different problem.

### Where this design was argued with, and how it landed

- **The ceiling/skill split already exists.** `player_generator.gd:917` applies
  body type to `attribute_ceilings`, not to rolled values, and scores
  `potential` on the untouched roll first. "Morphology raises what is possible,
  skill decides execution" is therefore shipped behaviour. The defect is not the
  mechanism — it is *which* ceilings are moved. Stripping the 13 non-physical
  modifiers is most of the work.

### Vegi: all-rounder at the type level, specific at the player level

The question this answers: can Vegi keep reading as the all-rounder while
individual Vegi carry narrow, niche differentiators?

**Yes — but the differentiator must not be attached to the produce, and it is
not new machinery.** Three findings decide this.

**1. The variants already exist and are already deliberately unnamed.**
`body_type_models.gd:60` defines five produce — Tomato, Aubergine, Pear, Stalk,
Pepper — assigned deterministically per player (`produce_for()`, seeded from the
id so a Vegi is the same aubergine for their whole career). The header at `:38`
is an explicit standing decision:

> "A Vegi is not 'a Tomato' and is never labelled as one anywhere a player can
> read… Surfacing the name turns a body into a species and invites a taxonomy
> nobody asked for."

A mechanical differentiator keyed to produce cannot stay internal — an invisible
per-produce bonus is an undisclosed dice roll, and disclosing it makes produce a
species. So **produce is the wrong hook**, and it is the wrong hook for a reason
already written down.

**2. There is already a rule for what a Vegi variant may not do**, discovered
once for silhouettes and worth promoting to the mechanical layer.
`body_type_models.gd:52` cut Pumpkin and Turnip because both read as "a heavy
round mass", which Ursi "owns outright and owns better":

> "a Vegi competing with a body type for the same read is a Vegi doing nothing."

Generalised: **a Vegi differentiator must never be a weak version of another
type's affordance.** A slightly-reachy Vegi is a bad Avi. Whatever a Vegi has
must be off the six-verb grid entirely.

**3. `TRAITS.md` already owns this exact slot.** A **Physical trait** is
"unusual morphology or a persistent physical characteristic — changes what the
body can do, and is a *label on the body*, not a second copy of it", with a
rarity budget, a prominence rule, and the direction rule that generation owns
the centimetres and the trait labels an outlier of a distribution that already
exists. Narrow, niche, two-sided, surfaced through the journal: that is the
described behaviour of traits, not of a body-type sub-table.

### So what Vegi actually is

Vegi keeps **no affordance and no bonus** — including adaptability, which stays
refused. A developmental or system-adaptability bonus would make Vegi correct
for any manager who changes system, and would restore precisely what Homi's
retirement removed: one sane default and five departures from it.

What changes is only the reading:

> The other five types are legible **before** you read the player — the body
> tells you the affordance. A Vegi is legible only **after**. It is the type
> whose identity comes entirely from its traits, because it has no affordance
> to overshadow them.

That is a real difference in how a manager relates to the player, and it costs
nothing in balance, because **Vegi gets no extra trait budget.** This is the
line to hold. If every Vegi were *guaranteed* a niche differentiator while the
other five were not, Vegi would have an affordance after all — call it Variance
— and it would be a free one. The distinction is perceptual, not mechanical:
same budget, nothing competing with it.

The trade a manager takes on a Vegi is therefore **higher scouting cost and
higher variance for the same expected value** — which is a genuine decision, and
one the journal is already built to hold.

**Open, and not decided here:** whether produce should nonetheless *bias* which
physical traits a Vegi can draw (a Stalk being likelier to roll a
long-limbed outlier), keeping the produce name internal while letting the
silhouette and the trait agree. That preserves finding 1 — the manager reads the
trait and the body, never the species — but it needs the trait budget to exist
first, and it edges toward the taxonomy `body_type_models.gd:38` refused. Worth
revisiting only once traits ship.

### Sustain and Switch: the seam that was nearly a duplicate

Cani and Feli were first drafted as **Traverse** and **Burst** — ground-per-cycle
versus speed-of-reversal. Both are distance over time, which is a much narrower
gap than Reach/Anchor/Manipulate, and it collapses in play into "fast in a line"
versus "fast to turn". Resolved by moving both off that axis:

- **Cani = Sustain.** The affordance is *low decay*, not speed. Ground coverage
  stops being the rule and becomes a consequence of it — a Cani's advantage
  therefore **grows across a rally and across a match** rather than being a flat
  movement stat. "I can still get to that in the fifth set" is a different
  sentence from "I can get to that", and only the second one was available under
  Traverse.
- **Feli = Switch.** The affordance is *state change* — initiate, arrest,
  reverse, re-initiate — priced in decay. Not top speed, and not distance.

They remain mirror images, which is the §2 zero-sum requirement, but they are
now mirrored on **cost of repetition** rather than on locomotion. Stamina is the
currency both spend and the direction differs, which is exactly what a zero-sum
pair should look like.

### What this costs

Removing 11 technique and 2 mental modifiers changes generation for every
player, so ceilings move, training projections move, and sampling gates will
draw a different number of checks. Per `CLAUDE.md`: measure the suite and the
balance probe **before** the change on the same tree, or the delta afterwards
means nothing.

---

## 4. The six types

**Vegi** — no modifiers, and the load default for saves written before body
types. Not "the baseline": it is one sixth of any population like every other
type (§1), and it exists so that *unremarkable* has a home of its own rather
than being the ground the other five are read against. Genuinely the right pick
for a manager who changes system often.

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

## 5. Deltas

First-pass magnitudes. These need a multi-career sweep before they are trusted —
one career is one sample (`fixture_base_seed()` hashes the career name).

### Body metrics

`BODY_TYPE_METRICS` carries three keys. **There is no stride key, and there
must not be one** — see the note below the table.

| type | `height_cm` | `mass_kg` | `wingspan_cm` | *implied* `stride_length_m` |
| --- | ---: | ---: | ---: | ---: |
| Vegi | 0 | 0 | 0 | 0 |
| Avi | −4 | −7 | +6 | −0.017 |
| Cani | 0 | +2 | 0 | **0.000** |
| Feli | −3 | −4 | 0 | −0.013 |
| Ursi | +1 | **+11** | +1 | **+0.004** |
| Simi | −6 | −5 | +2 | **−0.026** |

**The stride column is derived, not authored.**
`VolleyballPlayer.default_stride_length_m()` is
`clampf(height_cm / 100.0 * 0.43, 0.55, 1.15)`, and `player_generator.gd:130`
and `:222` assign it *after* body variation, so every stride figure above is
just the height delta times 0.0043. Authoring a per-type stride offset is not
merely unimplemented — it is **forbidden by a live gate**:
`locomotion_granularity_calibration.gd:53` flags any player whose stride differs
from the derived value by more than 0.005 as stale, and
`test_runner.gd:8408` fails the suite above a 5% stale rate. A per-type offset
would put one type in six out of band and take the rate to ~17%.

An earlier version of this table authored the column directly, and every figure
in it was wrong in a different way. Kept here because the shape of the error is
the lesson:

| type | column *said* | actually | |
| --- | ---: | ---: | --- |
| Cani | +0.09 | 0.000 | the type whose whole identity is ground coverage has **exactly Vegi's stride**, because its height delta is 0 |
| Ursi | −0.05 | +0.004 | **wrong sign** |
| Avi | 0 | −0.017 | a delta where none was intended |
| Simi | −0.02 | −0.026 | right sign, and the largest real stride delta in the game — which nobody designed |
| Feli | −0.03 | −0.013 | right sign, off by 2× |

This is `FAILURE_MODES.md` §0 exactly: a number acting on a distribution it was
never measured against. Ground coverage belongs to §3's **Sustain** affordance,
and Sustain has to reach locomotion through something other than a stride
offset — repeat cost, recovery between movement cycles, or decay rate — because
the stride field itself is derived and gated. This is part of why Sustain is
framed as *low decay* rather than *more ground*: the "more ground" version has
nowhere legal to attach.

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

### One delta that is load-bearing, and one that was fiction

**Feli `stamina`.** `GameManager.stamina_fatigue_scale()` reads `stamina`
directly to scale per-rally fatigue accrual, so a low-stamina Feli measurably
tires faster *within a single match*. They are first-set terrors and fifth-set
liabilities, with no new mechanism required — it emerges from the fatigue system
already in place.

**~~Cani `stride_length_m`~~ — withdrawn, and it was backwards.** The claim was
that "the locomotion model consumes stride directly, so Cani coverage is real
movement rather than a rating". Locomotion does consume stride; Cani has no
stride advantage to consume. Stride is height-derived and Cani's height delta is
zero, so a Cani covers ground at precisely a Vegi's rate. The one delta this
document called load-bearing was the one that does not exist.

### Free propagation

Body-metric deltas flow automatically through everything already derived from
them: `reach_rating()`, `usable_attack_power()`, `baseline_defensive_range()`,
`standing_reach_cm()`, `jumping_reach_cm()`, and the locomotion model. No new
wiring. This is the main argument for expressing body type through metrics
wherever possible rather than through bespoke attribute bonuses.

---

## 6. Ceilings, not just starting values

**Body type must shift `attribute_ceilings`, not only generated values.** This
is the single decision that determines whether the feature survives a career.

If an Avi starts with more `jump_reach` but carries the same ceiling as
everyone, training converges them and body type quietly evaporates over a few
seasons — leaving a character-creation flavour rather than a permanent identity.
The ceiling shift should be the larger of the two effects; the starting-value
shift only decides how quickly the difference becomes visible.

---

## 7. Worked example: six setters

Against the identities in `scripts/models/team_principles.gd` (Balanced,
Defensive, Fast Tempo, Physical, Technical, Development):

| setter | thrives in | why | fails in |
| --- | --- | --- | --- |
| **Avi** | Fast Tempo | high jump-set release, quick overhead hands, tight in-system band | Physical — cannot block, gets served at |
| **Cani** | Defensive / attrition | wide tolerance converts broken plays nobody else reaches | Fast Tempo — worst of the six on a perfect pass |
| **Feli** | Technical | elite disguise; opponents cannot read the distribution | Balanced — low discipline means own hitters sometimes cannot either |
| **Ursi** | Physical | unshakeable under pressure, blocks at the net | anything requiring movement to the ball |
| **Simi** | Technical / Development | finest pure hands when the pass is good | Physical — no net presence |
| **Vegi** | Balanced | fine everywhere | nowhere in particular |

Same position, six different **jobs**. No ranking exists without naming a system
first.

**This test is too weak and this table is aspirational.** "Six different jobs"
is satisfied by six disguised classes, and the Ursi row is the proof — traced
through the code in §3, an Ursi setter has no positive effect at all. §3
replaces both the test and the Ursi entry.

---

## 8. Generation

`body_type` is a **categorical trait**, not an ability attribute. Follow the
`dominant_hand` pattern exactly:

```gdscript
@export_enum("Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi")
var body_type: String = "Vegi"
```

with `to_dict()`/`from_dict()` carrying a `"Vegi"` default so saves written
before this feature load unchanged, plus a `"Homi"` → `"Vegi"` rewrite on load
so pre-rename careers do not end up with a body type nothing can draw.

**It must not be added to `ABILITY_ATTRIBUTES` or `CATEGORY_ATTRIBUTES`.** A
regression check sums those in both directions and will fail loudly if a
non-ability lands in them — which is exactly what caught `work_rate`.

Assignment happens in `player_generator.gd`, drawn **uniformly, with no regional
weighting whatsoever** (§1). Order of application: region bias first, then body
type, both additive on the same body metrics. Body type is applied second so a
Landavol Ursi and a Pāwa Hitō Ursi differ by their region's bias and by nothing
else.

---

## 9. Perception

This is what makes player portraits worth building. The current
`PlayerActor3D` rig cannot distinguish two players — `Color("d6a06c")` is
hardcoded three times for head, arms and legs, with no hair or facial variation
and no cosmetic data on the model at all.

Body type fixes that at the **silhouette** level rather than the detail level,
which is what actually reads at portrait size: a light long-limbed Avi and a
broad heavy Ursi are distinguishable as thumbnails, where two humans with
different faces are not. The rig already scales limb length and body height from
`height_cm`, `wingspan_cm` and `stride_length_m`, so the metric deltas in §5
drive the visual difference with no separate art pipeline.

It also gives the manager a **prior**: body type is the at-a-glance read that
the attribute wheel then confirms or subverts. A Cani middle blocker is
immediately interesting precisely because the type argues against it.

---

## 10. Balance risks

**Ursi is the most likely to come out accidentally dominant.** Mass feeds
`usable_attack_power()` *and* `reception_stability`, so it buys two of the most
valuable things in the game. Its movement penalty is only a real cost if the
defensive systems punish immobility hard enough — verify that before trusting
the numbers.

**Avi's mass penalty must not be double-counted** (see §5 note 1).

**Watch for positional collapse.** If any type turns out strictly best at a
position across *all* six identities, the fit signature is not doing its job and
the type needs re-shaping rather than a numeric nerf.

**Feli fatigue interacts with a system that was only just fixed.** Weekly
recovery and stamina scaling landed recently; a type built on low stamina should
be swept specifically for whether it is merely weak rather than differently
strong.

---

## 11. Verification

- Full suite before and after. Body type should add checks, not move existing
  ones; a moved count means generation changed for players who should be
  unaffected.
- **Distribution flatness, as a regression check.** Generate a full world and
  assert each body type's share is within tolerance of `1/6` **in every
  region**. This is the rule most likely to be broken silently by a later
  well-meaning change, and the one with the worst consequences if it is.
- **Back-compat**: a save written before this feature loads with every player as
  `Vegi` and no crash, and a save written *after* body types but *before* the
  rename loads its `Homi` players as `Vegi`.
- **Ceiling persistence**: simulate several seasons of training and assert two
  types have not converged on their signature attributes.
- **Fit symmetry**: assert no type has both wider tolerance and higher
  in-system bonus than another on the same axis — the zero-sum rule from §2.
- Sweep across at least six career names for any balance figure.
