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

## 3. The inversion: volis play for a region, clubs select them

This is the ask that changes the game, and it needs one question answered before
anything is built on it.

### What is being proposed

Rather than the real-world arrangement — a voli plays for a club, and the best
are selected for their nation — the proposal inverts it. Every voli belongs to
their region. Regional strength is therefore the primary measure, which is
consistent with the Sixnet already being the competition the world revolves
around. Clubs then **select from the regional pool**, each with a budget and a
loose identity, and transfers are driven as much by what a voli *wants* —
accommodations, care, the life around the sport — as by money or tactical fit.

### Why it is a good inversion

It makes the Sixnet mean something structurally rather than by assertion. It
gives `home_region` primacy over `club_region`, which matches every regional
system now built: specialty attributes, physique, ego, `fatigue_resistance` and
`read_rate` are all read from where a voli was *raised*. And it makes
accommodations load-bearing rather than flavour, which is the strongest argument
for it — a 495-line design document currently attached to nothing becomes the
reason volis choose you.

### The question that has to be answered first

**What do clubs compete in, and does a voli play for both?**

Three coherent answers, and they are different games:

**(a) Clubs are employers, not competitors.** The only competition is regional.
A club signs, houses, trains and cares for volis, and is measured by how many of
them make their region's Sixnet squad and how those squads do. The manager's
seat is a club; success is other people's trophies. This is unusual, it makes
accommodations and development the entire loop, and it is the reading most
consistent with "regional strength is the primary measure". It also has an
obvious failure mode: the player never plays a match they own.

**(b) Clubs compete, regions compete, volis do both.** The real-world split with
the allegiances swapped. Rich, and it doubles the calendar, the fatigue
bookkeeping and the roster-lock ritual — a voli tired from a club match arrives
at the Sixnet spent, which is a genuinely good tension and a lot of machinery.

**(c) Clubs compete; regional strength is an emergent measure rather than a
competition.** Volis are *from* regions and their regional traditions decide
what they are, but the matches are club matches. "Regional strength" is then a
league table of where the good volis come from, not a tournament. Cheapest by
far, keeps the match loop the player already has, and loses the Sixnet as an
event.

I would not guess between these. (a) is the most distinctive and the most
faithful to what has already been built; (c) is the least disruptive to
everything that currently works; (b) is the most expensive and the most
conventional.

### What is already in place either way

- `home_region` and `club_region` exist on every voli and are already
  distinguished correctly.
- `world_population.assign_club_region` already moves volis between regions by
  pull, capacity and age, and `_recruitment_appetite` already lets a region shop
  for a particular kind of voli — A'ace does. That machinery becomes club
  recruitment almost unchanged if clubs become entities.
- `REGION_PULL` and `REGION_BIRTH_WEIGHTS` are the beginnings of an economy.
- What does not exist at all: a club **entity**. `CLUB_NAMES` are strings. There
  is no budget, no identity, no roster, no fixtures.

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
3. **Settle the clubs-versus-regions question** above. Everything in §3 and §4
   depends on which of (a), (b) or (c) is the game.
4. **Club entities**, then **accommodations as recruitment**, then **club fit**
   on top of mechanical fit.

Steps 1 and 2 are independent of step 3 and can proceed while it is undecided.
