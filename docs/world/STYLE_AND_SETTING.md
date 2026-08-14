# Style and Setting

Status: **Product direction; captures decisions made in conversation so they
survive past this session.** Nothing here is a mechanic spec -- see
`docs/design/` for those. This is the creative bible: premise, tone, and the
visual/narrative rules future features should be checked against.

**Start at `THE_WORLD.md`** if you want to know what is true rather than why it
was decided. It is the canonical reference, organised as the world; this document
is the reasoning behind it, and `GEOGRAPHY.md` is the land.

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
buy or work its way in. This is deliberate, established texture (see Ĭspayk
and A'ace below), not an incidental detail: it means "region" and "current
Sixnet flagship" are two different things, and the roster of eight playable
regions doesn't need to shrink or grow in lockstep with who currently holds
the six slots.

This is now a real background mechanic, not only lore (`scripts/systems/
sixnet_league.gd`), and it runs in two stages:

- **The qualifier.** The four lower-bracket regions play a round robin for
  two open places.
- **The championship.** The four seeded regions plus the two who came
  through -- **six teams**, which is what makes the name honest. Eight
  regions compete for the Sixnet; six contest it.

A'ace and Ĭspayk each take a *fixed starting* slot, both at the **bottom**
of their bracket: A'ace is the least established team at a top table it
bought its way onto, and Ĭspayk is rock bottom of everything, where a fallen
flagship begins its climb back. Neither is pinned there -- from their first
season on they promote and relegate like anybody else, and each stage judges
its own teams (last in the championship goes down, the qualifier winner comes
up).

Every region carries a power level that genuinely evolves from a simulated
background season each year -- the eight academies play a real, if
abstracted, schedule the player never sees in match detail, and the results
move occupants between the two brackets. Regional power, combined with
which regions are geographically "near" each other (invented world-map
adjacency, not tied to any region's real-world naming tradition), also
drives a slow influence drift: a dominant region's development traditions
partially spread into a weaker neighbor, while an isolated region with no
dominant neighbor nearby instead intensifies its own specialty rather than
being absorbed. That drift covers the six core regions only -- Ĭspayk and
A'ace compete in the bracket but sit outside the geography, since their
identities come from history and money rather than from a local
development tradition that could spread.

## The world's players

The world is a fixed population rather than a stream of players invented
whenever something needs them (`scripts/systems/world_population.gd`). Four
thousand players exist at career creation and are stored with the save -- about
five hundred per region, enough for a club scene with a pipeline beneath it
rather than a single squad. The transfer market is a slice taken out of that
population, not a separate roll.

The reason is scarcity. Talent is an **allotted budget**, not a per-player
dice roll: a small fixed headcount of generational and elite players exists
*for the entire world*. Only eight genuinely generational players are alive
at any time, and that number deliberately does **not** grow with the
population -- a bigger world holds more journeymen, not more once-in-a-
generation players, or "generational" would just mean "rare in a small
world". A world where every age from fifteen to thirty is stocked with
wonderkids has no wonderkids in it -- finding one has to be an event.

Three rules follow from that, and between them they are what make the world
feel like it has a past:

- **Current ability is never allotted.** It falls out of age through the
  same development curve every player uses. One potential number plus an age
  produces either a raw prospect or a finished star, which is exactly what
  makes a "wonderkid" a coherent idea rather than a label.
- **Golden generations.** The scarce budget is apportioned across single
  birth years rather than spread evenly, with enforced spacing, so most years
  produce nobody special and once in a while one produces a real cluster. A
  golden year *concentrates* the fixed budget; it never adds to it. Where the
  golden years fall differs per world, so a career can't learn to predict
  them, but they arrive reliably enough that every save has a few.
- **Where a player is raised is not where they play.** Nowhere breeds
  champions -- birth carries no talent or age bias at all, only how prolific
  a region is. Talent then *accumulates* wherever the money is. A'ace fields
  far more scoutable talent than the world average while raising no more than
  anyone else; Ĭspayk raises plenty and cannot hold on to it. Ageing players
  filter the other way, down to the programs still glad to have them, which
  is why Ĭspayk fills with veterans and A'ace fields players at their peak.
  Nobody wrote those stories into the data; they fall out of the weighting.

Every region is guaranteed prospects worth scouting, so no save produces a
dead corner of the world.

### The world ages

The population turns over once a season (`scripts/systems/world_aging.gd`):
everyone gets a year older and redevelops accordingly, the players the game
has no room for drop out, and a new intake of fifteen-year-olds arrives.

Attrition is **derived from the age pyramid rather than invented alongside
it**. The population already states how many players of each age should
exist, so the survival rate from one age to the next is just the ratio
between consecutive cohorts. The pyramid therefore cannot drift over a long
career, and there is no second set of retirement numbers to keep in step
with the first. *Who* survives is decided by ability plus noise -- being good
is a strong advantage, not a guarantee.

Development is the same statement re-evaluated: a player's ability was always
"their ceiling, minus how far their age leaves them from it", so aging them
is that formula at a new age. Growth and decline both fall out of one curve
instead of a second model that could disagree with the first. Players peak
around thirty and decline after -- setters least, because reading holds up
long after the legs go, which is exactly why an old setter stays useful.

New golden generations keep arriving rather than the world filling a quota
and stopping. The intake looks at how far the living world has fallen below
its talent budget and fills toward it: golden years clear the shortfall in
one go, ordinary years trickle. Scarce talent therefore ebbs between golden
generations and refills when one lands, which is the wave that makes a
golden generation feel like an event rather than a statistic.

### Regional sporting culture

Rivalries between academies are sporting and stylistic, not political --
playful, longstanding, the kind of thing broadcasters replay highlight reels
over, not anything modeled on real-world conflict:

- **Pāwa Hitō vs. Blôc du Larg**: the marquee rivalry, power-and-pace against
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
- **Ĭspayk vs. A'ace**: the circuit's other marquee rivalry, and its most
  pointed -- old glory against new money. Ĭspayk invented the set-and-spike
  and once held a flagship slot; it's since fallen out of Sixnet contention
  and now competes on reputation, craft, and a threadbare budget, with a
  crushing signature spike (a **bomba**, and the hitter who lands one a
  **bomberino**) as the one thing that still travels. A'ace has existed for a
  fraction of the time and already threatens to buy its way into the slot
  Ĭspayk lost -- imported star talent across a few glamour positions,
  essentially no homegrown tradition yet. Neither side is played as the
  villain; it's a genuine, ongoing "does history or money deserve the last
  flagship spot" argument the broadcasters never get tired of.

### The caricature has to have a cause

The section above already narrativizes clubs into characters — the disruptor,
the chess players, the underestimated. That is the register this world wants,
and it needs one rule to keep it from becoming decoration.

> **A nickname must describe something the simulation actually does.**

The world is allowed to exaggerate the story. The simulation still has to
produce a plausible volleyball mechanism underneath it.

| what is true in the rally | what the world calls it |
|---|---|
| disciplined block-and-defence organisation | *the wall that walks* |
| fast multi-option offence | *the six-headed attack* |
| exceptional continuation play | *the team that won't die* |

The exaggeration is the framing, never the substance. A club nicknamed *the
wall that walks* whose blocking is ordinary is lore stapled to a team; one whose
blockers genuinely read and close early has earned the phrase, and a
volleyball-literate viewer would arrive at something like it unprompted. That is
the same standard `docs/design/VOLLEYBALL_FIDELITY.md` applies to the rally and
`TEAM_IDENTITY_AND_PHILOSOPHY.md` §6 applies to identity: **if it is only
legible from the label, it is not simulation yet.**

This is also the bridge the setting needs between four things that could easily
pull apart — realistic-ish sport, a creature world, caricatured regional
culture, and sports-anime narrative readability. The caricature is how the world
*talks* about a mechanism that is really there.

### Identity outside the match

A club's sporting idea should leave the court and become material: chants,
supporter language, uniforms, architecture, training rituals, food traditions,
sayings, rival mockery, club legends, inherited tactical diagrams, recruiting
stereotypes, media nicknames.

**None of it free-floating.** Each should be downstream of something —

- the **region**, and its larder, its housing structure, its gesture;
- the club's **history**, including what it used to be and is not any more;
- its **actual behaviour**, per the rule above;
- **specific people** who have been there.

Ĭspayk is the worked example already in this document: the *bomba* and the
*bomberino* are a vocabulary, and they exist because that club really did invent
the set-and-spike and really does still have that one thing that travels. The
words are downstream of a history and a mechanism. A supporter chant invented
because a club needed one would not be.

## What the manager actually does

Beyond roster and on-court performance, the job is absorbing the texture of
running a program: weather delaying travel, jetlag before a continental
fixture, a player sulking because the academy is out of their favorite
supplement flavor. Dozens of small events like this exist to make the academy
feel lived-in, not to be simulated in depth. See "Flavor events" below for the
design rule this implies.

## Visual style

Reference points: **PEAK** and **R.E.P.O.** (simple, rounded, toy-like,
physically a little goofy character models); a third reference the user named,
**Mecha Chameleon**, is not one this doc's author (Claude) could verify
firsthand -- treat the two confirmed references as the throughline until someone
checks that one.

> **The "minimal, friendly, flat-color UI" half of that is superseded**, and the
> interface has moved somewhere more specific: it is a manager's working
> journal, and every element on the page is a physical thing. Cards are cut-out
> patches sewn on, controls are written with a broad nib and marked with a
> highlighter when you point at them, the section menu is a tape measure that
> rolls out of its case, scrolling regions are slips of paper threaded under the
> page, and tab rows are index tabs cut into a divider.
>
> This does not fight the character direction -- it sharpens the same tension.
> The plush-toy cast is what the *simulation* looks like; the journal is what
> the *manager's desk* looks like. Both sit against a spreadsheet-deep model,
> and neither apologises for it.
>
> See [docs/design/UI_VISUAL_SYSTEM.md](../design/UI_VISUAL_SYSTEM.md) for the
> object classes and the rules that follow from them.

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
to eight regions (Pāwa Hitō, Spëddigh, Blôc du Larg, Landavol, Xérvu, Taktikã,
Ĭspayk, A'ace):

- The **region name** is an English volleyball-related pun (Power Hitter,
  Speed Dig, Block [the] Large, Land of Volleyball, Serve, Tactic[a], Spike,
  Ace) respelled with foreign-looking diacritics or letters. It should look
  like a different written language at a glance without borrowing real
  grammar, prefixes, or suffixes from any actual language -- light cosmetic
  reskinning of English, not a translation. Ĭspayk is the one case that
  borrows a real spelling *feature* rather than pure decoration -- the
  epenthetic-i that Filipino English speakers themselves use affectionately
  (iskul, istrart) -- but it's still a spelling quirk, not borrowed grammar.
- The **people** from a region draw on a real, specific naming tradition
  matched to the region's flavor (Japanese for Pāwa Hitō, Nordic/Icelandic for
  Spëddigh, French for Blôc du Larg, a generic Northern/Central European blend
  for Landavol, West/Southern/East African for Xérvu, Quechua/Aymara/Mapuche
  for Taktikã, Filipino for Ĭspayk, Gulf Arab for A'ace) -- real, respectful,
  attested given names, not invented gibberish. This is where genuine cultural
  representation actually shows up to the player, more than the place-name
  pun does.
- Landavol is the deliberate no-lean region: flat ratings, no specialty bonus,
  zero physique bias. It exists so "generic/well-rounded" has a home instead
  of every region needing an identity.

### Demonyms

`VolleyballRegions.DEMONYMS` holds the word for a person or a thing *from* a
region -- Xérvyan, Spëddish, Zaitgaister. Three rules:

- **It is built from the place, never from the people's naming tradition.**
  This is the Filipino/Tagalog distinction: Filipino is everyone from the
  Philippines, Tagalog is one people and one language, and treating the second
  as the first turns a country into an ethnicity. Xérvu's people are named from
  West/Southern/East African traditions, but the demonym is *Xérvyan* and comes
  from the map.
- **Diacritics are preserved.** Xérvu → Xérvyan, Taktikã → Taktikãn, Spëddigh →
  Spëddish. A demonym is the same word in the same written language as the
  place. An earlier version of this rule dropped marks that "would not survive
  being said aloud", which is our world's habit of flattening other people's
  spelling into whichever alphabet is convenient, and it is wrong here: the mark
  is the region's signature and the only thing making the name look like a
  written language at all.
- **Two-word regions contract to the half that gets spoken.** Nobody says "Bloc
  du Larg" in a sentence about a person; they say Larg. Hence Largen, Feyntish,
  Tempaoli.

This is not only politeness. `home_region` is where a voli was raised and
`club_region` is where they play now, and the manager moves them between the
two constantly -- so the game needs a word meaning *from there* that says
nothing about ancestry, or every transfer quietly implies one.

| region | demonym | | region | demonym |
| --- | --- | --- | --- | --- |
| Landavol | Landavolan | | Tãul ys Feynt | Feyntish |
| Spëddigh | Spëddish | | Lo-ong Ralī | Ralīn |
| Pāwa Hitō | Pāwan | | Bompaçao | Bompaçan |
| Blôc du Larg | Largen | | Rhėn Tempaol | Tempaoli |
| Xérvu | Xérvyan | | Kutré Lyn | Kutrén |
| Taktikã | Taktikãn | | Zaitgaist | Zaitgaister |
| Ĭspayk | Ĭspaykano | | | |
| A'ace | A'aceni | | | |

### The shape system: a region signs its name with a gesture

The rule used to read *"a minor region should share its major neighbour's
spelling"*, sat under a heading that said **Open**, and was audited by hand. That
is how `Kutre den Lyn` shipped carrying Blôc du Larg's connector while sitting
beside Xérvu — announcing kinship with the wrong region, caught after release.

**It also could not be enforced as written, because it compared languages.** `ç`
is French and `ş` is Turkish, so Bompaşao beside a French neighbour read as a
mismatch; and Blôc du Larg carried no mark at all, so the literal reading said
Bompaşao should be bare, which nobody wanted. A rule that cannot answer its own
audit table is not a rule.

`ç` and `ş` **are the same thing**: a tail hung below the letter. They come from
unrelated languages and a player neither knows nor cares, because what a player
perceives is the *shape*. So the unit is the **gesture** — the movement that
draws the mark — and `scripts/data/region_language.gd` holds it as data with
four suite checks over it.

**Three relations, and only three.** *Same gesture* (Xérvu and Kutré Lyn share
the acute). *Same family* — different marks, one movement (Spëddigh's two dots
above, Rhėn Tempaol's one). *Opposed* — the same mark mirrored across the letter,
used **once**: Blôc du Larg's roof above and Bompaçao's hook below are a
metropole and a coastal colony that defines itself against it, and the opposition
says what kinship would have said wrongly. Anything else is a stranger, and a
minor region may not be a stranger to its own neighbour.

**The shape says something about the volleyball**, which is the whole reason a
made-up orthography is worth having rather than decorative:

| region | gesture | what the shape is |
| --- | --- | --- |
| Landavol · Zaitgaist | *bare* | no lean by design; never developed a style |
| Spëddigh | two dots **¨** | quick, tight, doubled — like its consonants |
| ⌞ Rhėn Tempaol | one dot **˙** | a colony's half-inheritance of two |
| Pāwa Hitō | a bar **¯** | held, sustained, deep into the rally |
| ⌞ Lo-ong Ralī | a bar **¯** | the same endurance at altitude |
| Blôc du Larg | a roof **ˆ** | the wall at the net |
| ⌞ Bompaçao | a hook below **¸** | getting *under* the ball; the first contact |
| Xérvu | a stroke **´** | the serve |
| ⌞ Kutré Lyn | a stroke **´** | the same hand, finer |
| Taktikã | a wave **~** | the read |
| ⌞ Tãul ys Feynt | a wave **~** | reading, with less to read with |
| Ĭspayk | a cup **˘** | on the epenthetic i itself — the mark *is* the pun |
| A'ace | a gap **ʼ** | a hole where a history should be |

Renamed by this sweep, all with `LEGACY_REGIONS` entries: **Blôc du Larg**,
**Bompaçao**, **Rhėn Tempaol**, **Tãul ys Feynt** (which also dropped an
apostrophe that collided with A'ace, a region it does not border), **Ĭspayk**,
and **Lo-ong Ralī** (whose `ğ` was a breve filed under a macron region).
`Spëddigh`'s `Lïv` needed no fix: `ï` and `ë` are the same gesture, which the
language-based reading could not see.

### Given names are exempt; surnames are not

The orthography belongs to the **map**. The people draw on real, attested naming
traditions, and marking `Noé` or `Miloš` with the local gesture to tidy a roster
is our world's habit of flattening other people's spelling into whichever
alphabet is convenient — the same thing the demonym rule forbids, applied to a
person instead of a place.

A **family name is the other half of that, and it is the half that is invented.**
It is place-derived, it belongs to a place on this map, and a place on this map
has a gesture. So the asymmetry runs the whole naming system in one line:

| | drawn from | marked? | why |
|---|---|---|---|
| given name | a real tradition, borrowed and left alone | no | a person is not a place |
| family name | a place invented for this world | yes, its region's gesture | a place is a place |

Nine surnames per region against eight given names, which are coprime on
purpose. A founded club fields twelve volis and the roster used to read `Kiko 1`
through `Kiko 12` — that is one person and a counter, not twelve people, and the
counter was doing real work by keeping them distinct. `VolleyballRegions.person_name`
does the same work with arithmetic instead of a suffix, and the gate counts what
a full squad is actually called rather than asserting that 8 and 9 are coprime,
because the tables are editable and the failure would be silent.

Two regions say the family name **first** — Pāwa Hitō and Rhėn Tempaol — and
`RegionLanguage.full_name` is the only place that is decided. The alternative was
a display order computed wherever a name is drawn, and the failure that rules out
is a Pāwan sorting under their given name while their own teammates sort under
family. Composed once, at generation, there is only ever one string.

What the lists are made of, region by region: landscape (Landavol), streets and
gates (Zaitgaist), real Japanese landscape surnames whose long vowel already *is*
the region's gesture (Pāwa Hitō), clan seats (Rhėn Tempaol), fortification
(Blôc du Larg), shoreline (Bompaçao), cities (Xérvu), provinces from a colonial
surname register (Ĭspayk), Welsh place-prefixes spelled with a wave because the
roof belongs to someone else (Tãul ys Feynt), and nine nisbas of places the
region did not come from (A'ace, which is the joke it deserves).

Two of them are worth knowing about because they are where the rule bit:

- **`Côte`, not Côté.** The natural French surname carries a roof *and* an
  acute, and the acute is Xérvu's — so the obvious name for a French-shaped
  region announced kinship with a region three seas away. The gate caught it on
  its first run.
- **Kutré Lyn is patronymic, not toponymic**, which is the one place the
  place-derived rule bends, and it bends because the tradition is real and the
  rule is ours. Its whole list had to be picked around `č`, which looks almost
  identical to its own `ć` at roster size and belongs to nobody on this map.

### What can actually be drawn

The palette is bounded by **Cherry Bomb One**, the heading face and the fallback
under `body_font.tres`, which covers eleven complete families. Deliberately
absent: the underdot (`ḍḥṇṛṣṭ`, 2 of 8), the stroke-through (`đħłøŧ`, 5 of 7) and
the letterform substitutions (`þðŋ`, 3 of 5). A mark that renders as a hollow box
is worse than no mark.

This was not theoretical. `voli_card.gd`, `board_tray.gd`, `board_court.gd` and
`lock_in_screen.gd` all `preload()`-ed the raw `.ttf` and so got **no fallback** —
and Short Stack draws no macron at all and one caron in eight, so `Pāwa Hitō`,
`Ralī` and `Miloš` were hollow boxes on every card and tray in the game. They now
go through `board_face.tres` and `board_hand.tres`, which carry the same fallback
`body_font.tres` has had all along.

The gate that was supposed to catch it named six glyphs — `ë ā ō é ã ç` — written
down when six were all there were. Surnames took the real set to twenty-five, and
a sampled instrument does not notice: it went on passing while `Ġ`, `ĕ`, `ĭ` and
`ẽ` went unchecked. It now walks every region name, demonym, club, given name and
surname, keeps whatever `RegionLanguage.GESTURES` claims, and asks the fonts about
that. Measured across the three faces in the repository: Cherry Bomb One is
missing none of them, Yatra One six, Short Stack seventeen — which is the fallback
chain's whole job stated as a number.

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
- ~~The Sixnet, standings and region power exist as background state but the
  player has no screen to see any of it.~~ **Answered, 2026-08-06.** The
  dashboard's Sixnet section renders both stages — the seeded upper bracket plus
  the qualifier's advancing two, then the lower bracket with its advancement
  markers — followed by every participant's strength and Sixnet form, all read
  from `career.sixnet_slots` / `sixnet_championship_standings` /
  `sixnet_qualifier_standings` / `region_strength` / `sixnet_form`
  (`journal_screen.gd:_refresh_sixnet`). It lives in the dashboard rather than
  its own screen. What is still missing is *history*: the view is this season
  only, so a region's rise or fall over a career is state the game holds and
  never shows.
- Now that flagship slots are established as contested rather than fixed
  (see Ĭspayk/A'ace), does the player's own academy ever get a shot at
  Sixnet contention as a mechanic, or does that stay aspirational flavor?
- World players develop purely as a function of age -- nobody fails to reach
  their ceiling through injury, poor coaching or bad luck, and nobody exceeds
  it. That is a deliberate simplification, not an oversight, but "a prospect
  who never made it" is a story the world cannot currently tell.
- Only the managed roster gains from training. World players follow the age
  curve regardless of where they play, so a spell at a strong academy does
  nothing for them.
- Retirement is the only exit. Injuries, loss of form and players simply
  falling out of the game are unmodelled.
- Spëddigh and Landavol don't have a named signature rival yet (Pāwa
  Hitō/Blôc du Larg and Ĭspayk/A'ace do) -- worth inventing one each, or is
  an uneven spread fine?
