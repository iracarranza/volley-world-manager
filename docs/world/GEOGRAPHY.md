# Geography and geology

Status: **Creative bible, not a spec.** `THE_WORLD.md` is the canonical reference
and the place to start; `STYLE_AND_SETTING.md` holds the premise and the naming
conventions; this holds the land those conventions describe.
Nothing here is built. It exists because naming was being done case by case, and
a world with a landscape names itself.

## 0. Why the land comes first

The naming target is **Saint Kitts and Nevis**: strange to the ear, trivially
decodable once someone tells you. Saint Christopher shortened to a nickname, and
*nieves* -- snows -- for the ring of cloud that sits on the peak. Nobody had to
invent a mythology. Somebody looked at a mountain, said what they saw, and the
name outlived the sentence.

That is only available if the land exists first. So the rule is:

> **Place names describe terrain, weather or work, said in the region's own
> spelling.** If a name cannot be decoded back into something a person standing
> there would have pointed at, it is decoration.

This is deliberately a *different* device from the region names. Regions are
volleyball puns in foreign spelling (Pāwa Hitō is "power hitter"); that trick is
a one-off joke and does not scale to the hundreds of clubs, towns and venues the
world will eventually need. Terrain naming does scale, and the two coexist the
way real maps hold both a colonial-era country name and a thousand villages
called after the local river.

## 1. What each region is made of

Landform is derived from the tradition each region already teaches, on the
principle that a training culture is downstream of the ground it stands on.

### The six core regions

**Landavol** -- *"No dominant tradition."* Wide braided river plains with low
hills between them, temperate and unremarkable, roads in every direction. The
crossroads region: everyone passes through, nothing accumulates, which is exactly
why no single style ever took hold. Names are plainly spelled because the place
has never needed to distinguish itself from anyone.

**Spëddigh** -- *"Compact community gyms, tempo pressure, rapid transitions."*
Glacial fjord country. Steep-sided inlets, short valleys, towns wedged between
water and rock with nowhere to sprawl. Everything is close together because
nothing has room to be far apart, and a culture of relentless tempo comes out of
gyms you can walk between. Cold, wet, bright in summer.

**Pāwa Hitō** -- *"Conditioning halls, relentless transition attackers."* A steep
volcanic archipelago. Terraced hillsides, black sand, deep water close to shore.
Everything is uphill, which is a conditioning culture stated as terrain.

**Blôc du Larg** -- *"Methodical halls, net control, patient structure."* A broad
shallow coastal shelf with enormous tides -- sea walls, causeways that appear and
vanish, working flats. *Larg* is the offing, the water past the shallows. A place
where the ground itself rewards reading the situation and waiting is not the same
as doing nothing.

**Xérvu** -- *"Serving academies, toss discipline, first-strike aggression."* A
high dry plateau ending in a long escarpment. Thin air, hard light, sightlines
that run for tens of kilometres. Balls carry further and drop later here, which is
a serving tradition with a physical cause.

**Taktikã** -- *"Composed intelligence, execution insulated from emotion."* Cold
high altiplano and salt flats. Flat, vast, exposed, with weather visible an hour
before it arrives. Nothing here is a surprise if you are looking, and a tradition
built on reading ahead comes from a horizon you can actually see to.

### The two flagship-holders

**Ĭspayk** -- *"Once a Sixnet flagship, cash-strapped, clawing back."* A volcanic
archipelago further out than Pāwa Hitō's, in the storm track. Built, flattened,
rebuilt; every hall is somebody's third hall. The pride and the poverty are the
same fact.

**A'ace** -- *"All the resources, none of the history."* Desert coast, much of it
reclaimed within living memory. The ground is new because it was *made* new, which
is why nothing there has a name older than the money.

### The six minor regions

**Tãul ys Feynt** (Taktikã's) -- slate valleys, high rainfall, village halls with
low ceilings. Low ceilings are why nobody learned to hit over a block and
everybody learned to hit around one.

**Lo-ong Ralī** (Pāwa Hitō's) -- the thin-air plateau behind the archipelago's
mountains, three days from anywhere. Already stated in its tagline; the geology is
what makes the travel time real.

**Bompaçao** (Blôc du Larg's) -- a hot river delta. Silt, sprawl, concrete, and
water everywhere, which is why the courts are hard and improvised and the first
contact is a religion.

**Rhėn Tempaol** (Spëddigh's, but see §2) -- a temperate island in Pāwa Hitō's
seas. Small, dense, wet.

**Kutré Lyn** (Xérvu's) -- limestone karst below the escarpment. Gorges, sinkholes,
sudden corners, sightlines that end without warning. A tradition that treats a
hard swing as failure and always finds the corner comes from country made entirely
of corners. *Kutré* also takes Xérvu's acute, which is the point of the rename.

**Zaitgaist** (Landavol's) -- an enclave city on a low rise inside Landavol's
plain, walkable in a morning. No hinterland, no crop, no tradition; only whatever
arrived this year.

## 2. Colonies

**Rhėn Tempaol is the worked case, and it explains something already in the
data.** Its people carry a naming tradition adjacent to Pāwa Hitō's, and it sits
in Pāwa Hitō's seas -- yet `REGION_ADJACENCY` links it to Spëddigh, halfway
around the ball. That looked like an inconsistency. It is a colony.

Spëddigh administers it. So:

- **The place name is spelled the administrator's way.** This is how colonial
  orthography actually behaves: the map gets written in the governing power's
  alphabet while everyone living there goes on saying it their own way. Which
  means Rhėn Tempaol should become **Rhën Tempaol**, taking Spëddigh's umlaut,
  and that simultaneously fixes the spelling-kinship gap flagged in
  `STYLE_AND_SETTING.md`.
- **The people's naming tradition is untouched.** Volis raised there are named
  from their own tradition, because that is theirs and always was.
- **The demonym stays civic.** A Tempaoli is anyone from Rhėn Tempaol. The
  administrative fact does not get to reassign anybody.

### What a colony is allowed to be here

A light element, and it needs guarding, because "colony" arrives carrying a
freight of grievance and extraction that this world has deliberately refused --
the same refusal that keeps body types from being a line anyone divides along.

So the rule: **a colony shows up as adjacency and orthography, not as
resentment.** It explains why a region is administratively next to somewhere it
is nowhere near, and why its name is spelled in a foreign hand. It does not
generate a grievance system, an independence arc, or a reason to feel bad about
signing a voli. If it ever needs a feeling attached, the register is the one this
world already uses everywhere else: mild, domestic, and about a person rather
than a people.

**What it buys, mechanically:** adjacency stops being a proxy for distance.
Influence drift can travel along an administrative link while import cost follows
the physical seam, so a paste grown next door can be expensive and a tradition
from the far side of the world can be the one your neighbours play. That is a map
with two layers, and it costs nothing -- `REGION_ADJACENCY` and seam distance are
already separate tables.

## 3. Where this meets the ball

`CLUB_LIFE.md` §3b sets the world as a volleyball: 18 panels, 6 groups of 3.
Geography gives the grouping a rule.

**A group of three panels is a neighbourhood**: one core region, its minor
neighbour, and one panel of sea or a flagship-holder. Fourteen inhabited regions
across eighteen panels leaves exactly the slack a map needs.

Rhėn Tempaol is the useful exception and should be drawn as one: it sits in **Pāwa
Hitō's group**, because that is where it is, while the adjacency table links it to
Spëddigh, because that is who runs it. A player who notices that discrepancy on
the map has discovered the colony without being told, which is the same principle
as everything else here -- you arrive because you needed something, and the world
is what you find.

## 3b. Six minors, eight majors

The counts are not a matched pair and should not be forced into one. Six minor
regions sit in `REGION_ADJACENCY`, one beside each **core** region. Ĭspayk and
A'ace are Sixnet participants but stand outside the geography system entirely --
their identity comes from history and money rather than from a local tradition
that could spread to a neighbour.

Giving them a minor each would be the tidy move and the wrong one. It would put
fourteen regions into a symmetry the world does not have, and it would quietly
undo the thing that makes those two distinct: they are the regions that are *not*
of anywhere. A'ace stands on ground it made. Ĭspayk stands on ground that keeps
being remade under it. Neither has a hinterland in the sense the core regions do.

`ACCOMMODATIONS_AND_CARE.md` turns that asymmetry into three different
relationships to flavour rather than a gap to be patched -- six majors sell what a
neighbour grows, Ĭspayk's volcanic soil grows its own and exports most of it, and
A'ace grows nothing at all and buys everything.

## 4. Open

- Whether Rhėn Tempaol's rename to Rhën Tempaol happens now or with a wider
  minor-region spelling pass (Tãul ys Feynt still shares nothing with Taktikã,
  Bompaçao's ş sits where Blôc du Larg's French would put ç).
- Whether any *other* region is a colony, or whether one is the right number.
  One is legible; three is a theme, and a theme is heavier than this is meant
  to be.
- Whether terrain naming needs a generator (river/ridge/harbour elements per
  region, in that region's spelling) or whether club names stay hand-authored
  until there are enough of them to be a chore.
- What the four non-region panels are. Open ocean is the dull answer; the
  Charter's neutral ground would be a better one.
