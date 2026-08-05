# Accommodations: food, flavour, and lodging

Draft. Nothing here is built. `CLUB_LIFE.md` holds the frame around this --
the audience thesis, staff, sponsorships and what a voli has to say -- and
should be read first; this is the food and lodging detail. Both are written down
while the simulation work they sit on top of is still in flight, so that when
they are built the shape is already argued rather than improvised.

**Terminology note.** `CLUB_LIFE.md` adopts *voli* for the people on court,
because "player" currently means both them and the person holding the
controller. This document was written before that and still says "player" in
most places. The migration is deliberate but unfinished; where the two
disagree, *voli* is the intended term and `VolleyballPlayer` remains the class
name.

## Why this exists at all

The player-facing case for this game is not that the volleyball model is
correct. It is that these are *your* players. The body-type work — Feli, Avi,
Vegi and the produce silhouettes — is the first thing that spent design budget
on making a roster feel inhabited rather than tabulated. Accommodations is the
second: a system whose entire output is *how the people you are responsible for
are living*.

That framing sets a hard constraint on the mechanics below. **Every number in
this system must be legible as care or neglect.** A player is not a stat block
receiving a nutrition modifier; they are someone who has been eating the same
grey paste for six weeks and has started to mind. If a mechanic cannot be read
that way at the table, it does not belong here — it belongs in training.

## 0. Where the culture lives

**The block is not the culture. The flavour is.**

This is a deliberate inversion of how food works for us. In our world a dish
*is* a culture -- you learn a place by eating its cooking, and the recipe is the
heritage. Here the meal itself is an **industrial product**: a block, manufactured
at scale, shipped, uniform, bought by the case. What carries region and identity
is the **paste** -- the ingredient, the flavour, the thing that was grown
somewhere and tastes of it.

So there are no regional dishes in this game. There are regional *flavours*
applied to manufactured food. Every design decision below follows from that, and
anything that starts to make a block read as somebody's home cooking is drifting
back toward the version this replaced.

The consequences are load-bearing rather than thematic:

- **Palate fatigue belongs to the paste layer**, because that is the layer with
  cultural memory. Nobody gets homesick for a block.
- **Preference is about flavour, not about meals.** A voli's `home_region`
  predicts which pastes taste like home. It says nothing about which block they
  want.
- **The block layer therefore has to earn its differentiation mechanically**, not
  culturally. See below; this is the part that is still open.

### Block names carry where they were made

The names are the one place the block layer does touch geography, and it is
orthographic rather than culinary. *Chutum Üch* takes its diacritic from the
region that manufactures it -- **Spëddigh** already spells with the umlaut
(`scripts/data/regions.gd`), so the product name is legibly Spëddigh-made
without a tooltip saying so. This is the existing region-naming device from
`docs/world/STYLE_AND_SETTING.md` used one layer down: reskinned English
dressed in a region's spelling.

That gives products a readable origin, which then means something because origin
sets import cost. A player who has seen four product names learns four spelling
systems, and the atlas is where they find out those spellings are places.

*Supergruel*, *Mixigence* and *Vollyslommy* are plainly spelled, so by the same
rule they read as made somewhere with no orthographic signature -- Landavol, or
A'ace, which bought a food industry the way it bought a roster. **Unassigned on
purpose.** The device is settled; which factory sits where is not.

### Name and function are separate axes

A previous draft claimed the pun *states* the mechanic, and asked every product
name to derive its effect. That is too strong. **A name's worldbuilding value is
allowed to be entirely independent of what the block does.** Chutum Üch is from
Spëddigh *and* it is a cheap, thick, unpleasant block; the second fact is not an
explanation of the first, and demanding that it be one turns naming into a puzzle
with one solution.

So: the **name** carries origin and character. The **function** is designed on
its own terms. Where the two happen to rhyme, take the free coherence and do not
build a rule on it.

Chutum Üch is exactly that lucky case. It is *chew too much*, and separately it
is thick -- and thick is why it soaks up more paste. That rhyme is a gift, not a
law, and Mixigence should not be contorted to match it.

### How many blocks, and the answer that is not a number

The tension is between *choice* and *ladder*. Four to six rows differing only on
nutrition, morale and cost is a ladder, and on a ladder you pick by budget and
never think about it again -- so more rows make it worse, not richer. But once
each block has a **week when it is the right answer**, they stop being rungs and
become a toolkit, and then more is fine.

So the count is not chosen directly. **A block exists if you can name the week it
wins.** Applying that:

- **Supergruel** -- fixture congestion, where condition outranks mood and nothing
  else holds a squad together through it. It also keeps a second job: it needs no
  preparation, so it is the one block that still works on a travel day when the
  kitchen is not running.
- **Chutum Üch** -- a thin month with a well-stocked paste cupboard. Cheap brick,
  expensive flavour, and the saturation makes that trade actually pay.
- **Vollyslommy** -- the room needs rescuing. Biggest morale spike and the
  fastest decay, so it is event food and never a diet.
- **Mixigence** -- *no answer*.

**Mixigence fails its own test, and it should be treated as failing.** "The safe
middle that nobody loves and nobody refuses" is a description of a design slot,
not of a week anyone would choose it. A block whose identity is being
unremarkable is a rung, and rungs are the thing this section exists to prevent.

There is one perk that would save it: **Mixigence is the block palate fatigue
does not accumulate on.** It is engineered to be forgettable, so it is what you
feed the squad while a beloved ratio recovers -- the reset week, deliberately
chosen, with a real cost in that nothing good happens during it. That is a week.

If that perk is not taken, cut it. Three blocks with three distinct weeks is
stronger than four with a spare, and the catalogue can grow later from products
that arrive with a reason.

**The case for many more is real, though, and it is a different argument.** If
blocks are manufactured by regions, the block list is a *map* -- six regions,
six products, and the catalogue becomes an anchor for the geography. That is
worth having.

Both survive if **the world holds more blocks than your kitchen can reach**. The
catalogue is large; availability is set by import cost and trade, so your menu is
three or four at a time out of a dozen. Variety without a scroll list, and the
products you cannot currently afford are one more reason to open the globe. It
also means a club in a different region has a visibly different menu, which is
worldbuilding you get for free from a mechanic already needed for pastes.

## 1. Food blocks

A base block is chosen per-week (or per-trip; see lodging). They vary along axes
that deliberately do **not** move together, so there is no dominant choice:

| block | what it is | nutrition | morale | cost | saturation |
| --- | --- | --- | --- | --- | --- |
| Supergruel | engineered nutrition | high | very low | very low | low |
| Chutum Üch | thick, cheap, hard work to eat | moderate | low | low | **high** |
| Mixigence | manufactured, consistent | moderate | moderate | moderate | normal |
| Vollyslommy | indulgence, pre-flavoured | low | very high | very high | very low |

**Saturation is not the paste slot count.** The chef sets how *many* pastes a
block can hold (two to four); the block sets how *much* of each it can take. Two
limiters from two places, and they do not substitute for one another -- a great
chef on Supergruel still gets a thin, four-way mix, and Chutum Üch under a weak
chef gets a lot of two things.

### Chutum Üch is a cheap block, not a good one

It sits one rung above Supergruel and no further. It is *chew too much*: edible,
tiring, and nobody looks forward to it -- morale **low**, not good. What it has
is thickness, and thickness is the mechanic: **it absorbs more paste per serving
than anything else on the list.**

That makes it the block for a club that is short on money and long on flavour.
You buy the cheap thick brick and you spend on the paste instead, and the meal
that comes out is genuinely decent -- but it is decent because of what you put on
it, which is exactly where this design wants the value to live.

It also gives the low end a real decision rather than a price floor. Supergruel
and Chutum Üch are both cheap, and they fail in opposite directions: Supergruel
feeds the squad properly and cannot be improved, Chutum Üch feeds them adequately
and can be rescued entirely. That is a choice at the bottom of the table, which
is where budget-constrained clubs actually live.

The two ends are deliberately *both* bad choices taken alone. Supergruel is
nutritionally complete and joyless: it holds condition together and grinds
morale down. Vollyslommy is gluttonous, beloved, and does not feed an athlete --
a squad living on it is happy and slowly getting worse.

Neither extreme is a trap to be discovered once and avoided forever.
**Supergruel is correct during brutal fixture congestion** when condition
matters more than mood, and **Vollyslommy is correct after a cup exit** when the
room needs rescuing. The system rewards reading the season, not finding the best
row.

### The fourth axis, and why it is needed

Recorded honestly, because it is a problem this document created for itself: an
earlier draft gave Chutum Üch a morale value of *depends*, on the grounds that it
was a region's own cooking and therefore worth more to volis raised there. That
is exactly the regional-dish reading this design rejects, so it is gone -- but
removing it left the block layer thinner than it was. Four rows differing on
nutrition, morale and cost is a ladder with a price tag, and a ladder is solvable.

The proposed recovery is the **takes paste** column: how well a block carries
flavour. It is the right axis specifically because culture lives in the paste, so
a block's real job is to be a better or worse *carrier* of it.

- **Supergruel** resists flavour. Dense, engineered, and it fights whatever you
  mix in. This is the substantive cost of gruel -- not merely that it is joyless,
  but that **you cannot paste your way out of it**. Otherwise cheap-plus-heavy-mix
  is a dominant strategy and the tier list collapses.
- **Chutum Üch** takes paste well. It is milled to be finished at the table, so
  the same paste budget goes further on it. That, not sentiment, is why it costs
  more than Mixigence.
- **Mixigence** takes paste exactly as advertised and never surprises anyone. The
  safe middle, and the one that never becomes a story.
- **Vollyslommy** arrives already flavoured, so paste on it is at best wasted and
  at worst clashes. An indulgent squad has bought a strong opinion along with the
  meal.

The consequence worth having: the two layers **interact** rather than stack. The
value of a paste mix depends on which block is under it, so the choice cannot be
made by reading either table alone. It is also the expansion slot -- new products
are new carriers, not new cuisines.

**Untested.** The multiplier shape (does a bad carrier scale the paste's morale
return, or cap the ratio the chef can apply, or both?) is unchosen, and the
interaction could easily read as an arbitrary penalty rather than a property of
the food.

## 2. Flavouring pastes

Pastes are mixed into a base meal at a chosen ratio. At least eight, and they
are the part of this system that carries identity rather than optimisation.

Sketch of the axis each should occupy — the point is coverage, not these exact
names: a sharp ferment, a bitter herb, a heavy sweet, a fatty savoury, a sour
citrus, a numbing spice, a smoky char, a clean umami.

Three rules make the paste layer more than a second tier list:

**Ratio costs, non-linearly.** A trace is cheap; a heavy mix costs
disproportionately. So a squad-wide indulgence is a real budget decision, and
targeting one player's preference is affordable.

**A block holds two to four pastes, and the chef decides how many.** A weak chef
combines two flavours effectively; the best cannot hold five. This is the answer
to the objection that eight pastes is a large combinatorial surface for a system
whose output is a morale figure: what governs comprehension is not how many
pastes exist but how many are in play at once, and that is bounded at four
regardless. It converts the problem from one of scale into one of discovery,
which is a better problem to have. It also gives the chef a legible progression
axis with a hard ceiling, so chef quality cannot run away.

**Preference is per-player, and it comes from two sources.** The design
question raised was body type *or* region of origin. It should be **both, and
they should be allowed to disagree** — that disagreement is where characters
come from. `home_region` and `club_region` already exist on `VolleyballPlayer`
and are already surfaced in the roster bio panel, as does the body type. A Vegi
raised in one region and playing in another has a *culinary* history as well as
a professional one.

Concretely: region supplies a familiarity — the taste of home, comforting,
morale-positive at moderate ratios. Body type supplies a physiological
tolerance — how much of it they can take before it stops being pleasant. A
player whose region loves a paste their body type tolerates poorly is a player
with a favourite food that does not love them back, and that is a more
interesting person than either input alone.

**Allergies are real, and sometimes mistaken.** Some volis genuinely cannot eat
a thing. The setback should be low impact and low urgency -- tangible, easy to
address, never an irritant. What makes it more than an admin task is that it is
the ground truth underneath the complaint system: a voli who says "I think I'm
allergic to Xérvyan food" may be right, may have high palate fatigue on a paste
from that region, or may be blaming their dinner for something else entirely.
Some real allergies go unreported. See unreliable self-report in
`CLUB_LIFE.md`; the physio and scout earn their slots translating one into the
other.

**Palate fatigue.** Holding a ratio constant decays its morale return toward
zero and then past it. This is the mechanic that stops the system from being
solved once. It should decay on the *specific ratio*, not the paste — so
varying the mix is a real answer, and rotating pastes entirely is a stronger
one. Recovery while a ratio is unused should be slower than the decay, so a
beloved paste over-used is a resource genuinely spent.

## 2b. Who cooks, and where the food comes from

Staff carry a region of origin and a current location exactly as volis do.
Ingredients near the club are cheap and distance adds an import cost; chefs are
familiar with particular regional cuisines and cook those better.

The convergence risk and what prevents it are recorded in `CLUB_LIFE.md`: cheap
local ingredients plus a locally-familiar chef would be a dominant strategy were
it not that a squad drawn from six regions cannot all eat local. Cheap food is
homesick food for most of them.

### Two geographies over one map

Pastes are **grown**; blocks are **made**. Both carry an origin and both pay
import cost by distance, but they are not the same map laid twice:

- Growing follows land and climate. A region rich in ingredients need not have a
  factory.
- Making follows capital and industry. A region with a factory need not grow
  anything worth eating.

So a wealthy manufacturing region imports cheap ingredients and exports expensive
product, and a poor agricultural one is surrounded by flavour it sells onward.
That is a trade shape rather than a distance table, and it gives the atlas
something to say beyond "1.4x".

### A major's signature paste grows in its minor neighbour

The strongest version of that trade shape, and it needs no new data:
**`REGION_ADJACENCY` already pairs each core region with exactly one minor one.**

| grows it | sells it |
| --- | --- |
| Rhen Tempaol | Spëddigh |
| Lo-onğ Ralī | Pāwa Hitō |
| Bompaşao | Bloc du Larg |
| Kutre den Lyn | Xérvu |
| Tu'ul ys Feynt | Taktikã |
| Zaitgaist | Landavol |

Six and six, one each, already in `scripts/data/regions.gd`. The paste sold as
Xérvyan grows in Xérvu's minor neighbour, the way a thing grows where the land
suits it and is sold from wherever the road goes.

**This is what finally gives the minor tier a reason to be known.** Minor regions
currently exist in adjacency tables and the scouting population and nowhere a
player would ever look. Under this rule you learn one exists *because you bought
paste*, which is the same principle as everything else here -- you arrive because
you needed something, and the world is what you find.

**Not an extraction story.** An earlier draft framed this as the major holding
the margin while the minor holds the land, which is our world's arrangement
imported wholesale and is explicitly not this world's (`STYLE_AND_SETTING.md`:
the tone is earnest and warm, and the same reason body types are simply accepted
rather than a source of division). Growing and selling are two ordinary jobs done
in two places. The pairing exists to make the map legible and to give distance a
cost, not to give the player something to feel bad about buying.

**Zaitgaist is the exception, and it should be.** The region with no tradition of
its own, which borrows whatever just won: its crop follows the Sixnet champion.
`career.sixnet_champion_region` already exists, so the joke is mechanically live
-- Zaitgaist grows this year's flavour, every year, and is never early.

### The stores open onto the world

The paste stores panel needs a **jump-to-globe** control, because the store is
where a player first has a reason to care where anything comes from. They came to
find out why clean umami is short and expensive; the answer is geography, and the
shortest path from that question to the map should be one button.

This is the same principle as teaching volleyball through playback: arrive because
you needed something, and the world is what you find. The atlas being reachable
from a nav tab is not sufficient -- reachable from the moment of need is.

## 2c. Team-wide by default, differentiated at a compounding cost

A meal plan applies to the whole squad by default. Feeding volis separately is
possible and costs more each time it is done, the way bespoke costs more than
mass production.

This is what makes a sponsor's dietary requirement a real decision rather than
an unwinnable constraint -- without it, satisfying one voli means harming five,
and the correct answer is always to ignore the sponsor.

**Unresolved, and it matters:** if differentiation costs only money the decision
collapses into arithmetic -- sponsor pays X, differentiation costs Y, act when X
exceeds Y. That is a solvable optimum. The proposed fix is to spend the chef's
*attention* instead: a limited number of separate plans per week, scaling with
chef quality. Money is fungible and therefore dull; attention is a real
allocation, and it makes a better chef's reward flexibility rather than a larger
number.

## 3. Lodging

Less developed, deliberately — food is the richer vein and should be built
first.

The axis that matters is **home versus foreign**. Domestic lodging is a
standing cost with a small, stable effect. Travel lodging is where the drama
is: an away trip into an unfamiliar region, with the quality of the stay
mediating how much the travel costs the squad.

The hook back into the existing model is `home_region` again. A player billeted
somewhere close to where they were raised should feel differently about the
trip than one taken somewhere alien — and the Sixnet regional structure already
gives the world enough geography for that to mean something.

Other candidates, unresolved: travel *method* (a long coach journey versus
flying), room allocation (who shares with whom — which is where this system
touches mentoring, below), and recovery facilities at the venue.

## 4. What this connects to

Accommodations should not be a closed loop. The three neighbouring systems
sketched alongside it:

- **Mentoring and partnership.** Pairing players socially. The obvious contact
  point with this document is room allocation on away trips, and a shared table
  — a mentor pairing that eats together should mean something.
- **Sponsorships.** Players representing interests, for morale, club culture,
  and money. The natural tension with this system is a food sponsor: cheap
  catering that pays you, and costs the room.
- **Club culture.** The aggregate the two above feed. Accommodations is the
  most legible weekly input into it.

## 5. Deliberately unresolved

- Whether differentiation is paid in the chef's attention, in money, or both.
  (The squad-wide-with-exceptions question this replaced is now settled: team
  default, differentiated at a compounding cost. See 2c.)
- How many pastes exist. Eight was the first instinct; the slot limit bounds the
  decision but not the authoring burden, and the number is still unchosen.
- Whether nutrition feeds the fatigue model directly or sits beside it. The
  staged fatigue design (tiredness → forced errors → unforced errors) is not
  built yet, and this should hook into it rather than duplicate it.
- Whether palate fatigue is visible to the player as a number or has to be read
  from behaviour. Reading it from behaviour is better for the fiction and worse
  for usability; a confidence-graded hint, like the roster thought-bubble idea,
  may be the middle.
