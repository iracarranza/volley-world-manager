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
that means is deliberately never pinned down. The manager's nature is not a
mystery to be solved or a joke to be explained -- it's just true, unremarked
on by the human cast, and never confirmed or denied on the page. Every other
character -- players, staff, rivals -- is human.

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
to six regions (Pāwa Hitō, Spëddigh, Bloc du Larg, Landavol, Xérvu, Taktikã):

- The **region name** is an English volleyball-related pun (Power Hitter,
  Speed Dig, Block [the] Large, Land of Volleyball, Serve, Tactic[a])
  respelled with foreign-looking diacritics or letters. It should look like a
  different written language at a glance without borrowing real grammar,
  prefixes, or suffixes from any actual language -- light cosmetic reskinning
  of English, not a translation.
- The **people** from a region draw on a real, specific naming tradition
  matched to the region's flavor (Japanese for Pāwa Hitō, Nordic/Icelandic for
  Spëddigh, French for Bloc du Larg, a generic Northern/Central European blend
  for Landavol, West/Southern/East African for Xérvu, Quechua/Aymara/Mapuche
  for Taktikã) -- real, respectful, attested given names, not invented
  gibberish. This is where genuine cultural representation actually shows up
  to the player, more than the place-name pun does.
- Landavol is the deliberate no-lean region: flat ratings, no specialty bonus,
  zero physique bias. It exists so "generic/well-rounded" has a home instead
  of every region needing an identity.

This pattern should extend to anything else that needs a fictionalized
real-world flavor (leagues, competitions, sponsors, equipment brands) rather
than each new one inventing its own convention.

## Tone

Earnest and warm, not grimdark or cynical. Comedic where it's light (a
supplement-flavor tantrum), sincere where it's not (a young player's
development arc). Closer to a cozy management sim with real stakes than a
satire of one.

## Open questions

Deliberately unresolved -- surface these before building a feature that
depends on an answer, don't guess:

- Do rival academies' managers share the manager's unspecified nature, or is
  the player's ambiguity unique to them?
- Is there an in-universe name for the sport, the academy circuit, or the top
  competition, or do we keep using "volleyball" plainly?
- How much of the wider world (politics between regions, academy rivalries'
  history, why volleyball specifically became this dominant) needs inventing
  before it's needed by a feature, versus staying implicit?
- Does the naming-convention pattern above extend to non-region flavor (kit
  sponsors, broadcast partners, award names), and if so, on what cadence?
