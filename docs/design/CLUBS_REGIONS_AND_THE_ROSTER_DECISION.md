# Clubs, regions, and making the roster a decision

Three connected asks, recorded before any of them is built, because the third
one changes what the game is and should be settled first.

## 1. The problem, stated as it was observed

> "gameplay testing consists mostly of clicking around in the training menu and
> watching a rally. there's no real incentive to study your roster."

That is the correct diagnosis and it is worth being precise about *why*, because
the obvious fix — add more roster screens — is not it. A roster becomes worth
studying when three things are true at once, and currently none of them are:

1. **The roster can be wrong.** If every lineup plays about as well, inspection
   has no payoff. Regional identity now gives volis genuinely different shapes,
   which is the first of the three arriving.
2. **You can find out it is wrong before it costs you.** Fatigue, form and
   opponent identity all exist and none of them are legible before a match.
3. **Committing is an act.** Right now the lineup is a state that drifts; there
   is no moment where you say *this is the team* and it becomes true.

## 2. Locking in the roster

The Football Manager ritual the ask names is not a screen, it is a **gate with
information behind it**. You cannot advance to the match until you confirm a
side, and immediately before confirming you are shown the things that should
change your mind. The effect is not that the interface asks a question; it is
that the *information arrives at the moment it is actionable*.

What already exists and is not surfaced at that moment:

| known | where it lives now | why it matters at lock-in |
|---|---|---|
| per-voli fatigue and stage | `player.fatigue`, `FatigueModel.stage_name` | the whole reason to rotate |
| match confidence and form | `match_confidence`, `current_form` | who is playing above or below themselves |
| opponent region and identity | `OpponentTeam.region`, principles | which of your strengths is relevant |
| familiarity and cohesion | `starting_identity_state` | which combinations have played together |
| position familiarity | `position_familiarity` | who is out of position and how badly |

Every one of those is already computed. **The lock-in screen invents nothing —
it is a place to put things the game already knows and currently never says out
loud.** That is what makes it cheap relative to its effect, and it is the reason
this should come before any new roster mechanics.

Sketch, deliberately small:

- Advancing to a match routes through a confirm step rather than straight to
  playback.
- The six starters and the bench, each with condition, form, and position
  familiarity shown as a state rather than a number where a state reads better.
- One line about the opponent: region, what that region is good at, and — once
  scouting means anything — what they have shown so far.
- A single flagged concern where one exists: *"Mila is spent"*, *"You have no
  one who can pass a Xérvyan serve"*. Derived, never authored.
- Confirming writes the lineup and is the thing that starts the match.

The design risk to avoid: this must not become a checklist that always says the
same thing. A flag that appears every match is wallpaper. It should be quiet
most weeks and loud when something is genuinely wrong.

## 3. Settled: clubs employ, the academy selects, the region is measured

The question this section used to hold open — *what do clubs compete in, and
does a voli play for both?* — has been answered, and the answer is none of the
three options that were offered. It is closest to (b), but the shape is
specific enough that writing it down properly is most of the work.

### The structure

**A voli is always from a region.** They are a prospective representative of it.
That never changes and it is not a contract.

**A club employs and houses them.** The club controls training, food, lodging,
care — the whole life around the sport, not just the sessions. Clubs compete in
a club competition, week to week, and that is the match loop the player already
has.

**The academy selects.** It is government-funded, one per region, and it is
*not* a youth setup. It collects the region's premier players and prepares them
— teaches them to represent the region in its strongest form — in time for the
Sixnet. Its output is a squad, and the squad is what plays the Sixnet.

**Regional strength is a measure, not a team's rating.** It is assembled from
three things, in descending weight:

| contributes | what it actually measures | already computable? |
|---|---|---|
| the clubs in the region | how the region's *tactic* performs against other regions' | yes — clubs carry a region and `principles()` is regional |
| the academy squad | how good the twelve who will actually be sent are | no — no academy entity, no selection |
| the whole regional pool | breadth: many strong-ish volis beat one standout | yes — `world_population` holds every voli and their `home_region` |

### The two consequences worth stating as design, not flavour

**Breadth beats a standout, and that has to be a real curve.** "A region with
numerous strong-ish volis rates higher than a region with just one standout" is
a specific mathematical claim, and the obvious implementation — mean ability, or
top-N mean — gets it backwards or flat. What produces the stated behaviour is a
*saturating* per-voli contribution: each voli adds something that rises with
ability and flattens near the top, summed over the pool. One 95 then contributes
less than four 70s, which is the sentence. This is exactly the kind of number
that must be measured against the distribution it acts on before the curve
constant is chosen — see `docs/FAILURE_MODES.md` §0.

**A club match is evidence about a tactic, not just a result.** "Does that
region's tactic outperform other regions" means a club fixture is a sample in a
league table of *principles*, and every club match already carries both sides'
regional principles into the resolver. So this measure is available the moment
clubs exist as entities and results are recorded against their regions. Nothing
new has to be simulated for it.

### Accommodation is the retention loop, and its risk is churn

The premise is that volleyball is the world's dominant activity, every club
competes to be the most accommodating, and therefore *a voli in poor conditions
will nearly always have somewhere better to go*. That makes accommodations
load-bearing — it is the reason
`docs/design/ACCOMMODATIONS_AND_CARE.md` stops being a 495-line document
attached to nothing.

It also names the failure mode precisely. If every voli always has a better
option, and nothing resists, every roster empties every season and the market is
noise. The mobility premise needs friction that is *also* modelled, not asserted:
tenure, relationships with team-mates, `position_familiarity` and cohesion that a
move throws away, the pull of a voli's own home region, and how much of a squad
a club can absorb at once. The interesting design question is not "will a voli
leave for better conditions" — the premise says yes — it is **what a club can
offer that a richer club cannot**, and the honest answers are fit, role, and
having been good to them for a long time. All three are things this codebase can
already compute or nearly can.

### The club/academy dichotomy at the start of a save is wrong, and it is cheap
### to fix

`new_career_screen` currently offers exactly this choice:

> **CLUB** — Compete now — 10 senior players · larger budget
> **ACADEMY** — Build for later — 12 young players · higher potential

That is the youth-development reading the structure above rejects. What it
actually describes is two *clubs* — an established one and a young one — and
`career_manager.create_career` treats it that way: the only differences are
roster generation, `reputation` (10 vs 6) and `finances` (120,000 vs 65,000).
Nothing about it selects for a region or prepares anyone for the Sixnet.

Two fixes, and they are different sizes:

1. **Now, and small: stop calling it an academy.** The second option is a young
   club with a smaller budget and higher-potential volis. Naming it that costs a
   string and a generation branch, and it stops the save's first screen teaching
   the player a word that means something else.
2. **Later, and real: make the academy the other seat.** Managing a regional
   academy is a genuinely different game — no employment, no housing, no
   transfers; you *select* from what the region's clubs developed and prepare
   them for one tournament. It needs club entities and a Sixnet calendar, both
   of which are unbuilt. It should not be offered as a starting choice until it
   is that.

### What is already in place

- `home_region` and `club_region` exist on every voli and are already
  distinguished correctly. Every regional system built so far — specialty
  attributes, physique, ego, `fatigue_resistance`, `read_rate` — reads
  `home_region`, which is the field the structure above makes primary.
- `world_population.assign_club_region` already moves volis between regions by
  pull, capacity and age, and `_recruitment_appetite` already lets a region shop
  for a particular kind of voli — A'ace does. That is club recruitment almost
  unchanged, once clubs are entities.
- `OpponentTeam.region` and `VolleyballRegions.club_name` already give every
  opponent a region and a club name, so a fixture already knows whose tactic it
  is testing.
- What does not exist at all: a club **entity** (budget, identity, roster,
  fixtures — `CLUB_NAMES` are strings), an **academy** entity, a **selection**
  step, and any **regional strength** figure.

### Build order this implies

1. Rename the save's second option away from "Academy". Small, and it is
   currently teaching the wrong word.
2. Club entities: budget, identity, roster, region. The recruitment machinery
   already exists to fill them.
3. Regional strength as a measured figure — tactic performance from club
   results, plus the saturating pool term. Buildable as soon as (2) records
   results.
4. Accommodations as the retention loop, with the friction terms named above
   built at the same time as the pull terms. Not after.
5. The academy: selection from the regional pool, preparation, the Sixnet squad.
   Last, because it consumes all of the above.

## 4. Accommodations, care, and two different things called "fit"

The ask names both as needing to be created. One is designed and unbuilt; the
other partly exists and the name is doing double duty.

**Accommodations and care** — `docs/design/ACCOMMODATIONS_AND_CARE.md`, 495
lines, food blocks, flavouring pastes, lodging, who cooks and where the food
comes from. It ends with a section called *Deliberately unresolved*. In code it
reaches exactly one place: a `PasteRow` and an `AccommodationsSummary` label on
the journal's Club section. So it is a fully-formed design with a display and no
mechanism.

Under the inversion this stops being flavour and becomes the transfer economy's
other half: if volis choose clubs partly on how they are housed and fed, then
accommodations *are* the recruitment system.

**System fit** is two different concepts sharing a name, and the distinction
matters:

- **Mechanical system fit already exists and is live.** `SystemFitProfile` gives
  every voli four axes — approach distance, set release interval, block
  engagement distance, defensive depth — and the resolver reads them at five
  sites. This is a voli's fit to a *style of play*, and it works.
- **Club fit does not exist.** Whether a voli suits this club, wants to be here,
  and would thrive — the thing a transfer decision needs — has no model at all.

So the ask is best read as: *club* fit needs creating, and it should be built on
the mechanical fit that already works rather than beside it. A voli whose
approach distance suits a fast-tempo side has a real, already-computed reason to
prefer one club over another, and that is a far better foundation than a new
opaque compatibility number.

## 5. Order

1. **Off-ball movement**, ahead of all of this. Not because it is related but
   because a rally that does not look like volleyball undermines everything
   built on top of it, and the ask is explicit that it is the most pressing.
2. **Roster lock-in.** Cheapest thing here with the largest effect on whether
   the roster feels like a decision, and it invents nothing.
3. **Rename the save's "Academy" option.** One string and one branch, and it is
   currently the first thing a new save teaches.
4. **Club entities**, then **regional strength as a measured figure**, then
   **accommodations as the retention loop**, then **club fit** on top of
   mechanical fit, then **the academy**. §3 has the reasoning for that order.

Steps 1--3 are independent of everything after them.
