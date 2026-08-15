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
| the functional wheel, talent and current | `AttributeProfiles`, plus the functional axes in `TEAM_ATTRIBUTE_WHEEL.md` | what this six is, and whether it is playing to it |
| familiarity and cohesion | `starting_identity_state` | which combinations have played together |
| position familiarity | `position_familiarity` | who is out of position and how badly |
| what the opponent did last time | `MatchStatistics` computes it and `VolleyballFixture` throws it away | the only honest thing to say about them |

**The lock-in screen invents nothing** — it is a place to put what the game
already knows and never says. That is what makes it cheap relative to its
effect.

Confirming is the only route into a match. A gate you can dismiss is a loading
screen; what makes this one worth stopping at is the cards, not the button.

### It says figures, not sentences

The first draft of this screen wrote prose at the player — *"serves that break a
rally before it starts"*, *"Mila is spent"*. That is wrong twice over. It
injects flavour where none was asked for, and worse, **it hands over a
conclusion the player should reach by losing to it once**. A region's identity
is a thing to be discovered from evidence, not announced before the match that
would have taught it.

So the board is statistical:

- **Your six** is the functional wheel's axes with a letter grade each, marked
  only at the extremes — `! DEF 48.9 D`, `✓ BLK 62.4 A`, nothing at B or C. A
  balanced side draws no marks at all, which is how the panel stays quiet most
  weeks by construction rather than by tuning. Which axes, and how each one is
  computed, is `docs/design/TEAM_ATTRIBUTE_WHEEL.md`.
- **Them** is a short table of what they did — aces, blocks, kills, errors, per
  meeting — with your own row underneath it. Nine aces against your three does
  the work the sentence was doing, and it stays true when they are having a bad
  season, which a hard-coded description never does.
- **A card** is condition, form, confidence, slot familiarity and the six
  grades. No line of prose anywhere. If a card wants to say something, it is a
  figure that has not been found yet.

### The grades: superseded in part, and the measurement still stands

**The wheel this section originally described — six category means across the
starters — is superseded by `docs/design/TEAM_ATTRIBUTE_WHEEL.md`.** A plain
average puts the libero in Team Attack, which is exactly what that spec forbids.
The lock-in board shows the *functional* wheel: axes with named primary
contributors, an asymmetric bonus for exceptional secondary ability, and two
figures rather than one — squad talent beside current performance.

Two things from the measurement survive that change and are worth keeping here,
because they are constraints on any grade scale this board prints:

Measured over 4,000 generated volis and 800 random sixes:

| category | solo p10 / p50 / p90 | six-mean p10 / p50 / p90 |
|---|---|---|
| Attacking | 39 / 57 / 70 | 49.2 / 56.2 / 62.2 |
| Defensive | 39 / 54 / 68 | 47.5 / 53.7 / 59.7 |
| Setting / Control | 30 / 47 / 64 | 40.5 / 47.5 / 54.3 |
| Physical | 40 / 55 / 68 | 49.5 / 54.7 / 59.8 |
| Serving | 34 / 50 / 64 | 43.2 / 49.3 / 55.5 |
| Mental / Tactical | 27 / 45 / 62 | 37.2 / 44.2 / 51.2 |

1. **A team scale is not a player scale.** Averaging collapses the spread to
   about 40% of the individual one. Grade a team on player bands and every team
   is a C forever — the knob cannot reach its own range.
2. **One scale across categories mislabels most of them.** Median Attacking 57
   against Mental / Tactical 45 reports a property of the generator as a
   property of the squad. Bands are per category.

**What does not survive: the six-mean column itself.** It was measured for a
mean over six, and a functional axis is a mean over three or four with a bonus
term — a different and wider distribution. Those numbers must be re-measured
once functional axes exist, and they are not usable as bands in the meantime.

**And a correction.** An earlier draft of this section said no grade function
existed in the codebase. `AttributeProfiles.grade()` exists, with eight bands
from S at 96 to C− at 50. Measured over 28,000 voli-by-category readings, S, A
and B+ together account for 0.43% and 43.23% of readings fall below the lowest
named band. The scale is not missing; it is entirely above the distribution it
grades.

### One field is missing before any of it can be printed

`MatchStatistics` computes kills, blocks, aces and digs per side every match.
`VolleyballFixture` stores `home_sets` and `opponent_sets`. **No stat line
survives the match that produced it**, so the opponent panel that replaced the
descriptive one has nothing to print. Persisting that dictionary onto the
fixture is one export field and it should land before the screen does.

The honest limit beyond that: a league table of aces needs a league, and no
club plays any other club. Until club entities and fixtures for teams other than
yours exist, the opponent panel can only show meetings you were in — still
enough for the comparison row, and still strictly more than a sentence about
their region.

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

### Accommodation is the retention loop, and it is where volis live

The premise is that volleyball is the world's dominant activity, every club
competes to be the most accommodating, and therefore a voli in poor conditions
nearly always has somewhere better to go. A club is not an employer with a
training pitch attached — it is **where these people live**. It controls their
food, their room, their day, and how much of that day is theirs.

That answers a question this section previously answered badly. It used to say
that what a club offers that a richer one cannot is *fit, role, and having been
good to them for a long time*. Those are career terms, and they are the smaller
half. The real currency is domestic:

| a club can offer | and the trade-off it implies |
|---|---|
| better food, and food that suits where a voli is from | expensive per head; scales badly with squad size |
| larger rooms, fewer to a room, a room of their own | capital, not wages — slow to change, hard to reverse |
| more social time, or deliberately less of it | a voli who wants quiet and a voli who wants company are not the same voli, and no club can be both |
| how much of the week is training | trades development against everything above |
| where the food comes from, and who cooks it | `ACCOMMODATIONS_AND_CARE.md` is already 495 lines of exactly this |

**None of these are a single "facilities" number, and they must not collapse
into one.** The point of the list is that clubs differ in *shape*, not in rank —
otherwise the richest club wins every transfer and the market has no decisions
in it. A club that feeds people superbly and works them into the ground is a
real club, and it is the right club for some volis and the wrong one for others.

That is also what makes the friction real. The mobility premise says a voli can
always find somewhere better; a preference model says *better at what*. A voli
who has a room to themselves at a club that leaves them alone does not move for
a bigger wage, because the thing they are optimising is not on offer elsewhere.
The friction is not a stickiness constant — it is the fact that the axes
conflict.

### The start of a save is major region versus minor region

`new_career_screen` currently offers:

> **CLUB** — Compete now — 10 senior players · larger budget
> **ACADEMY** — Build for later — 12 young players · higher potential

That is the youth-development reading the structure above rejects, and
`career_manager.create_career` backs it with nothing but roster generation,
`reputation` 10 vs 6 and `finances` 120,000 vs 65,000. It is two clubs — an
established one and a young one — under a word that now means the regional
selection body.

**The choice becomes major region versus minor region**, which is a distinction
the data already carries: `SIXNET_PARTICIPANTS` names eight majors, `CLUB_NAMES`
already gives every major two clubs and every minor one, and `playable_names()`
already excludes the minors. What changes is that a minor region stops being
unplayable and becomes the other starting position.

| | major region | minor region |
|---|---|---|
| clubs to choose from | several, established, with existing squads and existing accommodation | one or two, small |
| your seat | take over one of them | take over the small one |
| founding your own | available, and it is the hard route — from nothing, against clubs that have everything | not the default |
| the Sixnet | your region is in it; your volis are candidates for its academy | your region is not, so being seen means leaving |

**On the open question — found a new club, or take over a small one?** Take over
a small one, and put founding in the major regions as the hard route.

A brand-new club has no squad, no accommodation, no history and no
relationships, which means every system that makes this game interesting reads
state it does not have. The first hours would be an empty roster screen and an
accommodation menu with nothing to compare against. A small existing club
arrives with an inherited problem instead: six volis you did not pick, dorms
somebody else built to somebody else's idea of what volis want, and people who
are there for reasons you have to work out. That is a starting position with
texture, and the texture is made of exactly the systems this design is building.

Founding then belongs where the resources are, as a deliberate hard mode: in a
major region you can take a berth at an established club, or start from nothing
against clubs that have everything. That should cost something to choose rather
than being what happens when you pick the smaller region.

The minor region's difficulty is a different one and does not need founding to
supply it: your region is not in the Sixnet, so your best volis are being
watched by academies that are not yours, and the thing pulling them away is the
one thing you cannot outbid.

**Note for `regions.gd`.** The comment above `playable_names()` currently reads
that minor regions "run no academy at the level this game is about... They are
places you sign players *from*, not places you manage." That is now half true
and should be rewritten with this: they still run no academy — that is the point
of them — but they become manageable, and the absent academy is the difficulty
rather than the disqualification.

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
3. **Recut the save's opening choice as major versus minor region.** The data
   already separates them; what is missing is the branch and the words.
4. **Club entities**, then **regional strength as a measured figure**, then
   **accommodations as the retention loop**, then **club fit** on top of
   mechanical fit, then **the academy**. §3 has the reasoning for that order.

Steps 1--3 are independent of everything after them.
