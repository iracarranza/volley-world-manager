# Style and Setting

Status: **Product direction; captures decisions made in conversation so they
survive past this session.** Nothing here is a mechanic spec -- see
`docs/design/` for those. This is the creative bible: premise, tone, and the
visual/narrative rules future features should be checked against.

## Core premise

Volleyball is this world's dominant global cultural medium -- bigger than any
single real-world sport is to us. A dense web of regional orgs and community
clubs forms development pipelines into a small number of massive elite
academies, one surfacing on every continent, which regularly compete against
each other at the top level.

The player is the manager of an up-and-coming academy: arguably alien. What
that means is deliberately never pinned down. This isn't unique to the
player -- it's true of academy managers generally, everywhere, always has
been. It's not a mystery to be solved or a joke to be explained; it's just an
accepted fact of the role, unremarked on by the human cast (players, staff,
rivals -- everyone who isn't a manager is human) and never confirmed or
denied on the page.

## Why volleyball, and the Charter

Volleyball's dominance isn't an ancient accident -- it's a founding choice.
Generations back, the academy system was formalized by an agreement between
the continents' governing sporting bodies, remembered now simply as **the
Charter**. Volleyball was the sport chosen to anchor it, deliberately, because
it was the sport that could actually meet the brief: a net, a ball, six
players, and any reasonably flat surface -- no equipment barrier, no single
nation's origin story to gatekeep it, playable competitively by very different
bodies and climates. The Charter chartered six flagship academy slots, one
per continent, as a neutral, elite proving ground, and the sport grew into the
role because it was built to fit it.

Academy managers being "arguably alien" predates and outlasts any single
academy -- as far as anyone remembers, it's simply always been true of the
role, since the Charter era. Nobody treats it as news.

The Charter era's tournament is **the Sixnet Championship** (usually just
"the Sixnet") -- the annual competition between the six flagship academies,
the closest thing this world has to a World Cup. Winning it is the single
biggest thing that can happen to a program; an up-and-coming academy's whole
arc is measured by how far it is from Sixnet contention.

**The six flagship slots aren't permanent.** They're contested, not owned --
a legendary program can fall out of them, and a well-resourced newcomer can
buy or work its way in. This is deliberate, established texture (see Ispayk
and A'ace below), not an incidental detail: it means "region" and "current
Sixnet flagship" are two different things, and the roster of eight playable
regions doesn't need to shrink or grow in lockstep with who currently holds
the six slots.

This is now a real background mechanic, not only lore (`scripts/systems/
sixnet_league.gd`): the Sixnet runs as an 8-slot competition, a 4-team upper
bracket and a 4-team lower bracket, filled from the 6 core regions (Ispayk
and A'ace stay outside this pool entirely -- they compete *for* a slot, not
within it). Since 6 regions fill 8 slots, a dominant region can hold two at
once. Each core region carries a power level that genuinely evolves from a
simulated background season every year -- the six flagship academies (plus
whichever core regions hold a second slot) play a real, if abstracted,
schedule the player never sees in match detail, and results promote/relegate
occupants between the two brackets. A region's power, combined with which
regions are geographically "near" it (invented world-map adjacency, not tied
to any region's real-world naming tradition), also drives a slow influence
drift: a dominant region's development traits partially spread to a weaker
neighbor, while an isolated region with no dominant neighbor nearby instead
intensifies its own specialty rather than being absorbed.

### Regional sporting culture

Rivalries between academies are sporting and stylistic, not political --
playful, longstanding, the kind of thing broadcasters replay highlight reels
over, not anything modeled on real-world conflict:

- **Pāwa Hitō vs. Bloc du Larg**: the marquee rivalry, power-and-pace against
  patient structure -- the sport's version of a shootout offense against a
  lockdown defense.
- **Spëddigh** plays the disruptor: smaller budgets, faster systems, a
  reputation for upsetting bigger programs on tempo alone.
- **Xérvu** is high-risk, high-reward -- aggressive serving cultures that
  either blow a match open early or implode trying.
- **Taktikã** is the circuit's "chess players": unglamorous, deeply annoying
  to prepare for, rarely the highlight reel but often the eventual winner.
- **Landavol**, with no specialty, is chronically underestimated by scouts --
  and is where the circuit's most complete late bloomers tend to come from,
  since nobody trains them into one narrow box early.
- **Ispayk vs. A'ace**: the circuit's other marquee rivalry, and its most
  pointed -- old glory against new money. Ispayk invented the set-and-spike
  and once held a flagship slot; it's since fallen out of Sixnet contention
  and now competes on reputation, craft, and a threadbare budget, with a
  crushing signature spike (a **bomba**, and the hitter who lands one a
  **bomberino**) as the one thing that still travels. A'ace has existed for a
  fraction of the time and already threatens to buy its way into the slot
  Ispayk lost -- imported star talent across a few glamour positions,
  essentially no homegrown tradition yet. Neither side is played as the
  villain; it's a genuine, ongoing "does history or money deserve the last
  flagship spot" argument the broadcasters never get tired of.

## What the manager actually does

Beyond roster and on-court performance, the job is absorbing the texture of
running a program: weather delaying travel, jetlag before a continental
fixture, a player sulking because the academy is out of their favorite
supplement flavor. Dozens of small events like this exist to make the academy
feel lived-in, not to be simulated in depth. See "Flavor events" below for the
design rule this implies.

## Visual style

Reference points: **PEAK** and **R.E.P.O.** (simple, rounded, toy-like,
physically a little goofy character models over a minimal, friendly, flat-color
UI); a third reference the user named, **Mecha Chameleon**, is not one this
doc's author (Claude) could verify firsthand -- treat the two confirmed
references as the throughline until someone checks that one.

The gameplay underneath is inspired by **Football Manager**: dense management
systems, real progression, real consequences. The intended tension is
deliberate -- a spreadsheet-deep simulation wrapped in a disarming, cozy
presentation. Neither side should apologize for the other: the systems should
stay honest and consequential even though the cast looks like plush toys.

### Does stylized art conflict with realistic biometric attributes?

Raised directly in conversation: the player model already tracks real-feeling
human measurements (`height_cm`, `mass_kg`, `wingspan_cm`, derived reach and
stride formulas) and weighted physical attributes. Does a PEAK/R.E.P.O.-style
simplified character model undercut that?

**No fundamental conflict, and it's arguably the point.** The numbers are the
simulation-credibility layer (this is answering "what happens," not "what does
it look like"); the character model is the presentation layer. Football
Manager itself keeps the same split -- realistic-feeling stats driving an
abstract match engine, not photorealistic players.

**The one real risk**: stylization can flatten physical variety if every
character reads as a similarly-sized round shape regardless of their actual
measurements. That would quietly waste the scouting value the numbers already
provide -- a lanky middle blocker should still visually read as the tall one
across the net. **Design rule: a player's stylized silhouette should still
visibly track their measurements** -- taller/heavier/longer-armed players get
exaggerated-but-readable proportions, not smoothed-away ones. Cute and
statistically legible are not in tension if the character generation actually
uses the numbers; they're only in tension if it ignores them.

## Flavor events

The "dozens of events" (weather, jetlag, a missing supplement flavor, and
whatever else gets invented later) are light-touch by design:

- Mostly narrative/UI texture -- a news-feed entry, a dialogue line, a mood
  change -- not a new simulated subsystem.
- Where they do touch numbers, prefer small, legible nudges (morale, fatigue,
  a single attribute's short-term form) over new formulas or hidden systems.
- The bar for "does this need real simulation" is high. Most of these should
  be closer to a slice-of-life detail than a mechanic. If an event idea starts
  requiring its own weighted formula, it has probably drifted out of this
  category and into a real system that deserves its own design doc.

## Naming conventions already established

Regions (`scripts/data/regions.gd`) follow a specific pattern, already applied
to eight regions (Pāwa Hitō, Spëddigh, Bloc du Larg, Landavol, Xérvu, Taktikã,
Ispayk, A'ace):

- The **region name** is an English volleyball-related pun (Power Hitter,
  Speed Dig, Block [the] Large, Land of Volleyball, Serve, Tactic[a], Spike,
  Ace) respelled with foreign-looking diacritics or letters. It should look
  like a different written language at a glance without borrowing real
  grammar, prefixes, or suffixes from any actual language -- light cosmetic
  reskinning of English, not a translation. Ispayk is the one case that
  borrows a real spelling *feature* rather than pure decoration -- the
  epenthetic-i that Filipino English speakers themselves use affectionately
  (iskul, istrart) -- but it's still a spelling quirk, not borrowed grammar.
- The **people** from a region draw on a real, specific naming tradition
  matched to the region's flavor (Japanese for Pāwa Hitō, Nordic/Icelandic for
  Spëddigh, French for Bloc du Larg, a generic Northern/Central European blend
  for Landavol, West/Southern/East African for Xérvu, Quechua/Aymara/Mapuche
  for Taktikã, Filipino for Ispayk, Gulf Arab for A'ace) -- real, respectful,
  attested given names, not invented gibberish. This is where genuine cultural
  representation actually shows up to the player, more than the place-name
  pun does.
- Landavol is the deliberate no-lean region: flat ratings, no specialty bonus,
  zero physique bias. It exists so "generic/well-rounded" has a home instead
  of every region needing an identity.

The diacritic-pun trick itself is specifically a **region**-naming device --
it doesn't need to be forced onto everything else. Other flavor (the Sixnet
Championship is the first example) can use its own invented-but-plainly-named
style, the way real sports mix straightforward league names with regional
club identities. Extend the region convention specifically when something is
genuinely region-flavored; invent normally otherwise. No batch effort needed
-- name things as a feature actually introduces them.

## Tone

Earnest and warm, not grimdark or cynical. Comedic where it's light (a
supplement-flavor tantrum), sincere where it's not (a young player's
development arc). Closer to a cozy management sim with real stakes than a
satire of one.

## Open questions

Deliberately unresolved -- surface these before building a feature that
depends on an answer, don't guess:

- Below the flagship academies, how does the regional-org-to-academy pipeline
  actually work as a player-facing mechanic (is it visible at all right now,
  or purely lore until recruitment/scouting needs it)?
- The Sixnet, standings, and region power now exist as real background state
  (`career.sixnet_slots`/`region_power`/`region_overlay`), but the player has
  no screen to see any of it yet -- worth a minimal standings/bracket view,
  and if so, does it live in `career_dashboard.gd` or its own screen?
- Now that flagship slots are established as contested rather than fixed
  (see Ispayk/A'ace), does the player's own academy ever get a shot at
  Sixnet contention as a mechanic, or does that stay aspirational flavor?
- Spëddigh and Landavol don't have a named signature rival yet (Pāwa
  Hitō/Bloc du Larg and Ispayk/A'ace do) -- worth inventing one each, or is
  an uneven spread fine?
