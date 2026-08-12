# Accommodations: food, flavour, and lodging

Draft. **No mechanic here is built.** An inert Accommodations screen exists
under the dashboard's Club section, populated with sample data that persists
nowhere; see the status note at the top of `CLUB_LIFE.md`. `CLUB_LIFE.md` holds
the frame around this --
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

*Blan'deral* takes **A'ace's apostrophe**, so it is A'aceni-made: the region that
bought a food industry the way it bought a roster, on ground reclaimed within
living memory, where nothing has a name older than the money. A product with no
story, from the region with no history.

### Two of them are not label names at all

*Supergruel* and *Vollyslommy* are plainly spelled, and the reason is not that
their factory sits in a region without a signature. **They are not what is
printed on the box.** They are what people call the stuff, and a nickname is
spelled however the person saying it spells things.

- **Supergruel** is mildly derisive. Nobody's marketing department wrote it.
- **Vollyslommy** is *slommy*: the babytalk word for food you give a small
  creature you are spoiling. A cat can have a lil slommy.

That second one is worth taking seriously rather than filing as a joke, because
it is the **register of the entire game stated in one product name**.
`CLUB_LIFE.md` describes the relationship as looking after creatures who have
opinions about their food and their limbs; *slommy* is exactly the word somebody
in that relationship would use. It decodes to a tone rather than a place, which is
a real answer -- and it means the block everyone loves is named the way you talk
to something you love.

So product names come from two sources, and the spelling tells you which:

| source | spelled | examples |
| --- | --- | --- |
| **the label** -- named by whoever makes it | the factory's orthography | Chutum Üch (Spëddigh), Blan'deral (A'ace) |
| **the mouth** -- named by whoever eats it | however the speaker spells | Supergruel, Vollyslommy |

The open question of which region manufactures Supergruel and Vollyslommy is
therefore **dissolved rather than answered**. Their spelling was never going to
say, because the name is not the factory's.

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
law, and Blan'deral should not be contorted to match it.

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
- **Blan'deral** -- the reset week. See below.

### Blan'deral is the reset block (settled)

It had no answer, which is the same as being a rung: "the safe middle nobody
loves and nobody refuses" describes a design slot, not a week anyone would
choose. It now has one.

**Palate fatigue does not accumulate on Blan'deral.** It is engineered to be
forgettable, and forgettable is the mechanic -- it is what you feed the squad
while a beloved ratio recovers. A deliberate week, with a real price: nothing
good happens during it. You spend a week of morale to buy back a paste you had
worn out.

That makes it the only block whose value is about **time** rather than about the
meal. The other three are answers to *this week*; Blan'deral is an investment in
the next one, which is a different kind of decision and the reason it can sit in
the middle without being a rung.

It also protects palate fatigue from becoming an unmanageable ratchet. Without a
reset, a long career only ever accumulates worn-out ratios, and the flavour layer
narrows toward nothing. This is the pressure valve, and it costs something to
pull.

**Renamed from Mixigence.** That name was reverse-engineered from "exigence,
mixed", which stopped describing the block the moment it became the reset. The
replacement is *bland + mineral*, which reads as an engineered nutrition product
and quietly admits what it is, dressed in **A'ace's apostrophe** so the factory
is legible from the label.

That tie is the useful part. Under the separate-axes rule the name does not owe
the mechanic an explanation -- but it does owe the *world* a location, and a
plainly-spelled name gives none. Every product name should be traceable to a
region by spelling alone, because that is the whole reason product names carry
orthography in the first place.

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
| Blan'deral | engineered to be forgettable | moderate | moderate | moderate | normal |
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
  more than Blan'deral.
- **Blan'deral** takes paste exactly as advertised and never surprises anyone. The
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
| Kutré Lyn | Xérvu |
| Tu'ul ys Feynt | Taktikã |
| Zaitgaist | Landavol |

Six and six, one each, already in `scripts/data/regions.gd`. The paste sold as
Xérvyan grows in Xérvu's minor neighbour, the way a thing grows where the land
suits it and is sold from wherever the road goes.

**There are six minor regions, not eight.** The eight is the *majors* -- the
Sixnet participants. Only the six **core** regions sit in `REGION_ADJACENCY`;
Ispayk and A'ace are deliberately outside the geography system entirely, because
their identity comes from history and money rather than from a local tradition
that could spread. So they have no minor neighbour, and the rule above leaves
them with no paste.

**That gap is worth keeping, because the two absences are different and both are
already the region's story:**

- **A'ace grows nothing and imports everything.** Desert coast, much of it
  reclaimed within living memory -- there is no land under it old enough to grow
  a flavour. It buys its pantry the way it bought its roster, which means the most
  expensive table in the world sits in the richest region, and an A'aceni club is
  the one place where import cost is not a solvable problem.
- **Ispayk grows its own, and sells it on.** Volcanic archipelago in the storm
  track, which is famously the most fertile ground there is. It is the only major
  that needs no minor neighbour -- and it exports most of what it grows, exactly
  as it exports the players it raises and cannot keep. Cheap flavour at home,
  Ispaykano paste on every shelf in the world, and a program that stays poor
  anyway.

Three different relationships to flavour across eight majors, from one structural
fact that was already in the data. A uniform map would have been worse.

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

---

## 6. Proposal: what a manager actually does with this, weekly

Everything above settles the *world* — the blocks, the pastes, the two
geographies, who cooks. What it does not yet say is what a manager sees, what
they choose, and what changes as a result. This section proposes that, at the
smallest size that is still a system rather than a menu.

**The blocker named in §5 is gone.** That section says the open question is
"whether nutrition feeds the fatigue model directly or sits beside it — the
staged fatigue design is not built yet, and this should hook into it rather than
duplicate it." It is built. `FatigueModel` carries `LABOURED_ONSET`,
`SPENT_ONSET`, and separate forced and unforced error additions, which is
exactly the staged design that was waiting for. So the proposal below hooks
into it and duplicates nothing.

### The weekly object: a board with four rows

Accommodation is not a shop. It is four standing arrangements that persist until
changed, shown together because their cost is shared and their effects trade
against each other.

| row | what you set | what it moves |
|---|---|---|
| **Table** | the week's food block, plus up to two pastes | recovery rate between sessions; palate over time |
| **Dorms** | room size and who shares | recovery *ceiling*; the pairings mentoring reads |
| **Hours** | how much of the day is unstructured | the friction term against a voli leaving |
| **Care** | physio and rest-day policy | how much of a match's fatigue carries into next week |

Four rows, set once, changed when something is wrong. A manager who never opens
this screen has a default arrangement that is adequate and dull, which is the
correct floor: accommodation should be a thing you *improve*, not a tax you must
pay attention to in order to not be punished.

### What each row does, in terms that already exist

**Table → recovery rate.** `FatigueModel` already knows how fatigue is spent.
What food buys is the rate it comes back at between sessions, as a multiplier on
weekly recovery. A good block moves it perhaps ±15%; the pastes are smaller and
are where the *regional* character lives, because a paste is grown somewhere.

**Dorms → recovery ceiling.** Distinct from rate on purpose. Somewhere to sleep
properly sets how far down fatigue can go at all; cramped lodging means a voli
starts the week already carrying something. Rate and ceiling being two numbers
is what stops food and lodging collapsing into one "comfort" slider.

**Hours → the friction term.** §3 of
`CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` calls accommodation the retention
loop. This is where that lands: unstructured time is what a voli weighs against
another club's offer. A club that does not prioritise social time trains more and
holds people less well, and that is a real choice rather than a worse one.

**Care → carryover.** Match fatigue that survives the week. The one row whose
value is invisible until a congested run of fixtures, which is exactly when a
manager who ignored it finds out.

### Palate: the one mechanic that has to be new

Everything above is a multiplier on a number that exists. Palate is not: it is
the rule that **the same food stops working**. A block held too long drifts its
own recovery multiplier toward zero effect, and a paste held too long goes
slightly negative — the same plate, resented.

That single rule is what makes the table a decision every few weeks rather than
a solved one. Without it a manager finds the best block in season one and never
opens the screen again, and the entire authored world of blocks and pastes is
spent in a single click.

Two things it must not become. It is not a timer to be optimised against, so the
drift is slow and the recovery from rotating is fast. And it should be **read
from behaviour before it is read from a number** — §5's own preference — which
the cogniticon vocabulary can already carry: a voli with a tired palate is a
voli whose morale line moves without their form moving.

### What this needs that does not exist

1. A **club entity** to own the arrangement. Today the career holds finances and
   nothing holds lodging. This is the same blocker `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md`
   §3 names, and accommodation is the second consumer of it.
2. **Weekly recovery** as a named function rather than a step inside
   `advance_week`, so a multiplier has somewhere to attach.
3. A **palate clock** per voli per block and per paste. Two small dictionaries.
4. The **screen**, which is four rows and a cost line.

Order: (2) first because it is refactoring something that already runs, then (3)
because it is the only genuinely new state, then (1) and (4) together.

### Deliberately still open

- How many blocks and pastes are authored. The slot limit bounds the decision;
  the authoring burden does not, and the number is still unchosen.
- Whether differentiating one voli's table from the squad's is paid in money, in
  the chef's attention, or both. §2c settles that it *compounds*; it does not
  settle in what currency.

---

## 7. Review: three of the four rows cannot work yet, and one row got better

### The measurement §6 skipped

§6 proposes four rows. Three of them — table, dorms, care — are multipliers on
fatigue recovery, and it names "perhaps ±15%" before anything had looked at what
that is fifteen percent *of*.

`tools/run_recovery_headroom_probe.gd`, a career simulated 30 weeks, 300 weekly
readings of every voli's fatigue:

| p10 | p50 | p75 | p90 | p99 | peak |
|---|---|---|---|---|---|
| 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | **0.014** |

**One week in thirty had anybody carrying any fatigue at all**, and the worst
reading all season was 0.014 against a `LABOURED_ONSET` of 0.34.

So the table, the dorms and the care row are three dials on a number that is
already spent. Not mis-tuned — *inoperable*. A ±15% multiplier on a recovery
that has nothing to recover is exactly §0: a knob that cannot reach its own
stated range, failing silently, and it would fail silently here because a
manager buying better food and seeing no change has no way to tell whether the
food is weak or the mechanic is dead.

This is not an accommodation bug. Weekly recovery currently returns every voli
to zero, which means `FatigueModel`'s three stages are unreachable outside a
single match — the staged design §6 correctly notes is built is also, between
matches, never entered. **That is the prerequisite, and it is a simulation
change rather than a screen.** Accommodation cannot be built on top of it until
a week can end with somebody tired.

### And the rows are not four decisions

Even once fatigue persists: table, dorms and care all move the same quantity,
so they are one decision with three dials. They trade only against **money**,
which is the weakest axis available — it asks a manager to have funds, not to
understand anything. A player will set all three as high as the budget allows
and never think about them again.

Hours is the exception and shows what the others should look like: unstructured
time against training time is a real opposition, and a club that chooses either
is choosing, not merely affording.

### The row that can be fixed today: dorms

§6 gives dorms "recovery ceiling, and the pairings mentoring reads" — the second
half vague because nothing pair-shaped existed. `PairFamiliarity` exists now,
it is symmetric, it is on the same 0–100 scale as everything else, and the
setter already reads it when choosing a hitter.

So **who shares a room is who knows each other**, and the row becomes a real
opposition rather than a purchase:

| arrangement | recovery | what it builds |
|---|---|---|
| singles | best ceiling | nothing; every pair drifts at the idle rate |
| shared, chosen | slightly worse | the pairs you chose, faster than matches build them |
| shared, crowded | worst | pairs across the whole squad, thinly |

That is a decision with two goods on opposite ends, it is legible without a
tutorial, and it lands somewhere the manager already looks: a setter and a
hitter who room together are a setter and a hitter who get set to each other.
It also gives the connection lines in `FILLING_THE_SIX.md` a **second input the
manager controls**, which is the difference between a graph you watch and a
graph you play.

### Palate's open question has an answer now

§5 leaves open "whether palate fatigue is visible as a number or has to be read
from behaviour", preferring behaviour and worrying about usability.

The cogniticon layer answers it. It has an **ambient tier** — quiet, persistent,
drawn above every voli — which is currently carrying almost nothing but
`committed`, and a rule that ambient marks are *dimmer, not smaller*. A tired
palate is exactly that shape: a low-grade standing state, true of somebody for
weeks, that should never interrupt a rally. It reads from behaviour because it
is a mark on a voli rather than a row in a table, and it is legible because the
grade colour is the same scale as everything else.

### Order, revised

1. **Fatigue has to survive a week.** Nothing else here is buildable first, and
   the measurement above is the argument.
2. **Weekly recovery as a named function**, per §6 — but now with something to
   attach to.
3. **Dorms against pair familiarity**, which is the only row that already has
   both of its ends built.
4. Palate, table, care, and the screen.

§6 had (2) first and that was right for the wrong reason: it read as a
refactor, and it is actually the seam where the missing quantity goes.

---

## 8. The room is a loadout, not a tier

A revision of §6 and §7, and a better one. Recorded as a working design rather
than a settled one.

### The correction that fixes the money problem

**A dorm is still a dorm.** Even at base it is a room built for athletes to
sleep in, and there is no reason rest should be *poor* because of where somebody
lives. That single line kills the failure §7 named — three dials that only trade
against money — because it removes quality-of-bed as an axis at all.

What is left is far better: a room is differentiated by **what else it does**,
not by how much it cost. Accommodation stops being a tier list you climb and
becomes a loadout you compose.

### Rest is reduced by conditions, not by furniture

The things that make rest worth less are **personal and situational**: jet lag,
homesickness, a voli who cannot eat what the region eats. All three vary by who
you signed and where you are playing, which is exactly what a purchase cannot
replicate — the same room is a different room for two different volis.

**On hunger.** The instinct to wave away *they did not eat* is right, and there
is a framing that does it without a hand-wave: hunger here is not a quantity
problem, it is a **familiarity** problem. A voli whose region's food is wrong for
them eats badly rather than not at all — the same safe thing every day, snacks
in the room — and pays for it in recovery.

Which makes aversion and palate **one mechanic seen from two ends**: aversion is
*this food is wrong for me*, palate is *this food has been right for too long*.
Both are the same term, and unifying them means the cookbook has something to
act on and the paste rotation has a reason to exist beyond variety for its own
sake.

### Equipment answers a condition, not a role

The two-sided costs are the strongest idea here. Free weights buy physical
growth and cost fatigue decay — a gain in the long horizon paid for in the short
one, which is a genuinely different axis from spending money. The console buys
morale and in-room socialising and costs tactical familiarity growth.

**The risk is that it solves.** A manager finds *weights for middles, console
for the young ones* and never opens the screen again — the money pitfall
returning in a different costume.

The cookbook and the landline already avoid it, and they show why: they answer a
**condition** — aversion, homesickness — which a voli has or does not have, and
which changes. The weights and the console do not; they are flat bonuses.

So the rule that keeps the system alive is to generalise what the cookbook is
already doing: **equipment answers a condition, not a role.** Weights matter to a
voli with growth headroom left and are nearly wasted on one without. A console
matters to a voli whose morale is low and is a tactical tax on one whose morale
is fine. Then a room's right loadout changes as the voli in it changes, and the
screen stays open.

### Rooming, and the asymmetry that makes it a risk

Roommates trading rest for relationship is the right shape, and
`PairFamiliarity` is already the quantity — symmetric, 0–100, and the setter
already reads it when choosing a hitter.

One structural note. The upside should be a **rate** and the downside should be
**conditional**: rooming builds a pair steadily, the way matches do, and the
crash is what happens when fatigue is high *and* rest keeps coming up short.
Making the gain a chance as well would turn a season-long relationship into a
slot machine, and the interesting version is the one where you can rely on the
gain and cannot ignore the risk.

**And the crash cannot be a surprise.** A relationship that fails silently
teaches a manager nothing except that something invisible was taken. The strain
needs a surface before the break — the card already has a condition stripe and
the cogniticon layer has a quiet ambient tier carrying almost nothing. A pair
under strain should be legible for weeks before it goes.

### What the pavilion should be, so it is not a cohesion buff

A social area that raises team cohesion is a purchase again. The version that
is not: **rooms build pairs, the pavilion builds the graph between them.**

Rooming makes a few strong edges — the two or three people you actually live
with. The pavilion makes many weak ones, across rooms. Those are different
squads at the same average familiarity: a side of tight pairs who barely know
each other, against a side that all know each other a little. The first has
devastating combinations and falls apart when a rotation splits a pair; the
second has no standout connection and no hole either.

That is a real strategic choice, it is legible on the connection lines in
`FILLING_THE_SIX.md`, and it gives the pavilion something to do that money
alone cannot buy.

### What this needs, and what it already fixes

**It fixes §7's blocker by design.** "They regain some of what they lost after a
match, and some more each week of rest" *is* the persistent-fatigue prerequisite
— measured at 0.000 across 300 weekly readings today. Partial recovery is the
change; everything else here sits on top of it and nothing else can be built
first.

Still owed:

1. **Numbers for partial recovery**, measured rather than chosen. The target is
   that a congested run pushes somebody past `LABOURED_ONSET` (0.34) and a quiet
   fortnight brings them back — the model's own stages are the calibration
   target and they are currently unreachable between matches.
2. **Jet lag needs travel.** Fixtures know home and away; nothing models distance
   or a trip. It is the one reducer here with no substrate at all.
3. **Growth headroom as a readable quantity**, if weights are to answer a
   condition rather than a role.
4. **Oversized equipment** is still open, and the constraint that makes it
   interesting is already stated: it needs a bigger room *and* fewer people in
   it. Anything that trades occupancy against capability is buying its place.

---

## 9. Events are the loadout's readout; and a purchase is allowed to be a purchase

Two corrections to §8, one of them factual.

### The weights and the console do have costs

§8 called them "flat bonuses". That was wrong: free weights cost fatigue decay
and the console costs tactical familiarity growth, and both were stated from the
start.

The real objection survives the correction but is narrower than the one written
down. **A two-sided trade still solves if both sides are constant.** Weights are
always growth-for-recovery; a manager works out which volis want that once and
the room stops being a question. The cookbook and the landline escape it not by
having a downside but because their *value* varies — a voli either is homesick or
is not, and that changes.

So the problem was never missing costs. It was that the cost is **not felt**. A
standing −X% on a number nobody watches is a downside on paper.

### Which is what the events are for

Random events sent by volis, staff and the world are not a separate system that
happens to touch this one. **They are how a room's downside becomes knowable.**

- a voli hurts their arm doing extra training — *the weights room, reporting*
- an assistant coach says a set of roommates keeps turning up behind on tactical
  work — *the console, reporting*
- a voli says they have stopped getting on with their roommate — *the rooming
  trade, reporting, and early enough to act on*
- the chef says the paste is short after record snowfall — *the supply chain
  behind the table, reporting*

That closes the loop §8 was reaching for and closes it better than varying the
numbers would. The loadout's effects stay legible and constant — which is good,
because a manager should be able to reason about them — and what varies is
**whether you have been told yet**. A room does not become a question because
its multiplier moved; it becomes a question because somebody knocked on the
door.

It also answers §8's demand that a relationship crash cannot be silent. The
warning is not a gauge, it is a voli mentioning it.

### Housing is a purchase, and that is fine

§8 leaned too hard on *not a purchase*. A better voli is a purchase; a better
staff member is a purchase. Paying for capability is not the failure mode.

The failure mode is a purchase you would **never decline**. And the reasons to
decline are already the interesting ones everywhere else in this game:
familiarity, sentiment, and what the club needs right now.

For housing that does not translate one-to-one, and the reason it does not is
the good part: **upgrading displaces people.** You do not decline the pavilion
because it is secretly bad. You decline it because building it means the squad
sleeps somewhere temporary for a stretch, and the stretch you have available
runs straight into a Sixnet qualifier. Or because a squad that has been in a
small complex for four years is *familiar* there, and a bigger facility spends
something that took four years to build.

So the pavilion **should read as an upgrade**, plainly, and the friction should
be the **transition** rather than a hidden catch. That makes it a timing
decision — do it in the off-season, or gamble on a gap mid-season — which is the
same decision a real club makes and is far more interesting than a hidden
downside would be. A manager who never finds a window they can afford is not
being denied content; they are declining for a reason they can state.

### On stakes, since §9's example raised it

*"Anti-volleyball protesters have blockaded the new high-rise"* sits badly
against a world without real conflict, and the discomfort is worth listening to,
because the two are separable.

**Stakes do not require antagonism.** A world can be full of friction that costs
you something without containing anybody who is against you:

| indifference | antagonism |
|---|---|
| record snowfall ruined the paste harvest | someone destroyed the harvest |
| the permit is stuck behind a bridge repair | the council has it in for your club |
| the hall is booked for a wedding | a rival booked the hall to spite you |

The left column generates events with real consequence, real cost and no
villains — the world simply has its own business, and volleyball is not the
centre of it. That is a *warmer* fiction than a conflict-free one, not a colder
one: a setting where nothing can go wrong is a setting where nothing else is
happening.

The high-rise example works if the objection is ordinary — neighbours who did
not want a large building, which is a thing that happens to buildings — and
stops working the moment the objection is *to volleyball*, because that imports
a value conflict the setting has no use for.

Recorded as a lean, not a decision: **indifference, not antagonism.**

---

## 10. Housing in full: floor, rooms, and three sizes of thing to put in them

A complete proposal, built on one constraint. Everything below is shape rather
than calibration — no number here has been measured, and none should be until
fatigue survives a week (§7).

### The one rule: **occupancy and equipment compete for the same floor**

A room has a capacity measured in **floor**. A person takes floor. So does a
rack of weights. That single rule generates every decision in this section, and
it is the reason the design cannot collapse into a ladder: a bigger room does
not mean *better*, it means *you may choose differently*.

| | floor |
|---|---|
| one occupant | 2 |
| small equipment | 1 |
| large equipment | 3 |

**Comfort, and one over.** A room at or under its floor is comfortable. A room
one occupant over is **crowded**: rest efficacy drops, pair familiarity builds
faster, and the crash condition in §8 becomes reachable. Crowding is a
deliberate play, not a failure — you crowd a room when you want two volis to
know each other by the qualifier.

### Housing types

Three, and the third is deliberately not "the best one".

#### Bunkhouse — the base, and genuinely adequate

Many small rooms, **5 floor** each. No common area.

Two occupants and one small item, or one occupant and three. It is a place built
for athletes to sleep, and it does that job completely: **nobody rests badly
because they live in a bunkhouse.** What it lacks is room to do anything else.

Its quiet strength is that almost everybody has a roommate, so a bunkhouse squad
builds pairs faster than any other housing. A young side in a bunkhouse is doing
the right thing.

#### Pavilion — the upgrade, and it reads as one

Fewer, larger rooms at **9 floor**, plus the pavilion itself: a common area.

Two occupants leave 5 floor — a large item and two small, or five small. Three
occupants fit at 6 floor and are crowded, which is a choice rather than a
penalty. And the common area unlocks the third size of equipment, below.

Pavilion is a plain upgrade and should look like one. Per §9, what makes it a
decision is not a hidden catch but **the transition**.

#### The Row — private units, and the wrong answer for a young squad

Individual units at **7 floor**, one occupant. No roommates anywhere, no common
area.

Best rest in the game, the most equipment floor per voli, and it **builds no
pairs at all** — every relationship drifts at the idle rate. A squad that has
played together for four seasons and is carrying a congested calendar wants the
Row. A squad still learning each other would be buying the thing they least
need, at the highest price.

That is what stops the housing types being a ladder. The Row is not above the
Pavilion; it is *later*, and only for some sides.

> **Siting** — whether housing sits at the hall, in town, or out of it — is a
> second axis trading commute time against social access and homesickness. It is
> real design space and it is not proposed here, because one axis at a time is
> how a system stays legible while it is being tuned.

### Small equipment: one floor, and it answers a condition

Per §8's rule. Each of these is nearly worthless to a voli who does not have the
condition it addresses, which is what keeps the room worth reopening.

| item | answers | effect | cost |
|---|---|---|---|
| **Cookbook** | food aversion | removes the aversion penalty for this voli | a slot |
| **Landline** | homesickness | scales with distance from `home_region` | a slot |
| **Blackout curtain** | jet lag | shortens travel recovery | a slot |
| **Foam mat** | nothing in particular | small flat recovery | a slot |
| **Games console** | low morale | ↑morale, ↑in-room pair gain | ↓tactical familiarity growth |
| **Study desk** | tactical lag | ↑tactical familiarity growth | ↓morale, slightly |
| **Plant** | nothing | a very small morale trickle | a slot |

Three notes on the table.

**The console and the desk are deliberate opposites.** Room for one, not both,
in most bunkhouse rooms — which is the smallest complete version of this whole
system: two items, one slot, and no correct answer.

**The foam mat's cost is the slot.** An item with no downside is fine as long as
floor is scarce; the opportunity cost does the work a drawback would.

**The plant earns its place by being nearly nothing.** A system where every
choice is optimal pressure is exhausting. One item that is just *nice* is what
makes the others read as decisions rather than as a test.

### Large equipment: three floor, and it trades across time horizons

These need a Pavilion or Row room, and they are the reason to want floor.

| item | buys | costs |
|---|---|---|
| **Free weights** | physical growth ceiling | fatigue decay — you recover slower while you have them |
| **Ice bath** | strong recovery | physical growth — cold blunts adaptation |
| **Tape setup** | tactical familiarity, *and* pair familiarity for the occupants | morale: it is work, at home |
| **Kitchenette** | removes food aversion entirely, and lets a paste be used privately | morale of anyone rooming with the cook, occasionally |

**Weights and the ice bath are the same axis pointing opposite ways**, and a
room can only hold one. That is the clearest trade in the design: are these two
volis *becoming* better, or *staying available*? A squad mid-season with a
qualifier coming wants baths. The same squad in preseason wants weights. Which
means the right answer changes twice a year without a single number moving.

**The tape setup is the one that builds a pair through work.** Two volis who
study together get familiarity the way roommates do, plus tactical growth, and
pay in morale. It is the mirror of the console: same pair gain, opposite
mechanism, opposite side-effect.

### Oversized equipment: it does not go in a room at all

§8 left this open, and the resolution is that the question was pointed the wrong
way. Oversized things are not *large equipment for larger rooms* — they are
**shared equipment that requires a common area**, which is what a Pavilion is
for.

| installation | effect |
|---|---|
| **The long table** | squad-wide recovery trickle; builds **cross-room** familiarity — the weak edges of §8 |
| **The gym** | squad-wide physical growth, but it is *scheduled*, so it competes with training hours |
| **The film room** | squad-wide tactical familiarity, same competition for hours |
| **The kit wall** | a second small-equipment slot in every room, since storage stops living in them |

This gives the Pavilion a reason beyond bigger rooms: it is the gateway to an
entire equipment class, and that class is the only one that touches the whole
squad at once. It also makes the Row's missing common area a real cost rather
than a cosmetic one — private units cannot install any of this.

**The gym and the film room compete with training hours**, which connects
housing to the planner rather than leaving it a sealed screen. A club that
installs a gym has a training week with less room in it, and that is the same
kind of decision as the Hours row in §6.

### What the events say, per installation

Per §9 — every effect below has a voice, and the voice is how the effect becomes
knowable:

| installation | who tells you, and about what |
|---|---|
| free weights | a voli, about their arm, after doing extra |
| console | an assistant coach, about a room turning up behind |
| desk | a voli, about the room being no fun |
| crowded room | a voli, about their roommate — early enough to act |
| ice bath | a coach, about somebody's numbers plateauing |
| kitchenette | the chef, about somebody cooking for themselves |
| long table | nobody, ever — it just works, which is what makes it worth its cost |

### The transition, which is what makes housing a real decision

Per §9. Changing housing type **displaces the squad** for a stretch:

- rest efficacy reduced for the duration
- **no equipment at all** while displaced, so every condition goes unanswered
- pair familiarity drifts at the idle rate

The duration is the design's real currency. Bunkhouse → Pavilion is the long
one; adding a single installation to an existing common area is short. Which
makes the question *when*, not *whether* — and a manager who never finds a
window is declining for a reason they can state, which is exactly what §9 asks
of a purchase.

### Order of work, and what must be measured

1. **Fatigue survives a week.** Nothing here is buildable first; §7 measured the
   current state at 0.000 across 300 weekly readings.
2. **Floor, rooms, occupancy.** The constraint before anything that uses it.
   Crowding is the first effect, and it can be measured against `PairFamiliarity`
   immediately — that quantity already exists and already feeds the setter.
3. **Small equipment.** Cheapest to author, and the console-versus-desk pair is
   the whole system in miniature; if that one choice is not interesting, the
   large items will not rescue it.
4. **The Pavilion and shared installations**, which is also when the transition
   cost has to be real.
5. **Large equipment**, last, because weights-versus-baths only means anything
   once growth and recovery both have measured ranges to trade against.

**Nothing above should be given a number until step 1 lands.** Every effect here
is a multiplier on recovery, growth or familiarity, and two of those three are
currently pinned — recovery at zero, and growth headroom not yet readable at all.
Choosing magnitudes now would be picking thresholds outside their distributions,
which is the mistake this document has already recorded twice.

---

## 11. Accommodation is a home, not a facility

§10's shared installations were **the gym, the film room, the long table**. Two
of those three are wrong, and wrong in a way that mattered: every club has a
gym. Every club has a film room. Putting them here made accommodation into a
second training facility, which is the one thing it is not.

**The volis live here.** That is the whole subject. Accommodation answers *what
is it like to be at this club when you are not working* — and everything in it
should be something a person would recognise from a home, not from a
performance centre.

That also settles the ice bath, which §10 got wrong for the same reason. An ice
bath is recovery equipment and belongs to the medical staff. **A bath** is a
different object entirely: it is domestic, it is comfort, it happens to help,
and a voli would think of it as a nice place to live rather than as treatment.
Same effect, right register.

Everything below supersedes §10's installation list. The floor rule survives
unchanged.

### The structures, which specialise rather than climb

A structure gets something by **giving something up**. There is no top of this
list — a club picks the shape that suits the squad it has.

| structure | capacity | floor / room | what it specialises in | what it gives up |
|---|---|---|---|---|
| **Bunkhouse** | high | 5 | pairs, cheaply — almost everybody shares | space, privacy, anywhere to be together as a squad |
| **The Commons** | medium | 6 | a genuine shared room at the heart of it | in-room floor; nobody gets a big private setup |
| **The Row** | low | 7 | rest and personal floor | pair building entirely; no shared room |
| **Longhouse** | high | 3 | the whole squad knowing the whole squad | rest, and personal space almost completely |
| **Farmhouse** | low | 6 | food and homeliness — a real kitchen, a garden | capacity; it houses a small squad and no more |
| **The Block** | very high | 6 | housing everyone, including the youth setup | cohesion — people do not run into each other |

Notes on four of them.

**The Commons is §10's Pavilion, renamed and corrected.** Pavilion reads as a
sports structure, which is exactly the confusion this section is fixing. The
thing wanted is a *dorm with a shared room at the heart of it*, and the cost is
that the rooms themselves are ordinary — you cannot also have the club with the
best-equipped bedrooms. Other candidate names: **the Hall**, **the Lodge**,
**the Hearth**. Commons is the plainest and says what it is.

**The Longhouse is the Bunkhouse taken to its end**, and it should be a real
option for a young squad in a poor club: everybody knows everybody, nobody
sleeps well. It is not a punishment tier, it is a bet on familiarity over
condition.

**The Farmhouse is where the food design lives.** A kitchen and a garden mean
aversion is answered squad-wide without a single cookbook, and the paste
rotation has somewhere to happen. It cannot house a full senior squad, which is
the price.

**The Block is the high-rise** from §9's example. Its weakness is the honest one
for a tower: you can house everyone and they still never meet.

### Small equipment — one floor, and all of it domestic

Twelve, so the matrix is a matrix.

| item | answers | what it does | what it costs |
|---|---|---|---|
| **Cookbook** | food aversion | removes the aversion penalty for this voli | a slot |
| **Letterbox** | homesickness | slow, cheap; letters rather than calls | a slot |
| **Landline** | homesickness | fast and strong; scales with distance from home | a slot |
| **Blackout curtain** | jet lag, bad sleep | shortens travel recovery | a slot |
| **Mattress topper** | nothing in particular | small flat recovery | a slot |
| **Fan / stove** | climate mismatch | a voli from a cold region in a hot one, or the reverse | a slot |
| **Games console** | low morale | ↑morale, ↑in-room pair gain | ↓tactical familiarity growth |
| **Bookshelf** | tactical lag | slow tactical growth, and morale for some volis | ↓nothing, but it is slow |
| **Study desk** | tactical lag | fast tactical growth | ↓morale |
| **Record player** | low morale | morale for the room, and it **carries into the corridor** — a small cross-room tie | ↓rest for the neighbours |
| **Kettle and tin** | isolation | people come round; small pair gain with *visitors*, not roommates | a slot |
| **Privacy screen** | crowding | buys back one occupant of crowding friction | a slot, obviously |
| **Houseplant** | nothing | a very small morale trickle | a slot |
| **Drying rack** | mundane friction | a small standing morale floor — the room works | a slot |

Four of those are doing structural work rather than being flavour.

**The privacy screen is the best item on the list**, because it spends floor to
buy back occupancy. A crowded three-person room plus a screen is a real
alternative to a two-person room, at a different price, with a different
familiarity outcome. That is the floor rule paying off.

**The letterbox and the landline are the same condition at two prices.** Cheap
and slow against strong and immediate is a shape this list should use more than
once; it is how a small club and a rich one make the same decision differently.

**The record player is the only small item that leaves the room.** It builds a
weak cross-room tie and costs the neighbours rest — which makes it the one small
item whose right answer depends on who is in the *next* room.

**The kettle builds pairs with visitors rather than roommates.** Every other
pair-building thing here strengthens edges you already have; this one adds new
ones. In a Bunkhouse it is nearly redundant. In the Row it is the only thing
that works at all.

### Large equipment — three floor, and still domestic

| item | what it does | what it costs |
|---|---|---|
| **Free weights** | physical growth ceiling | fatigue decay, and it is the source of the "hurt my arm doing extra" event |
| **The bath** | strong recovery, and morale | floor, and it is the most expensive comfort here |
| **Kitchenette** | removes aversion for the room; a paste can be used privately | occasional morale cost for whoever lives with the cook |
| **Lounge corner** | in-room social area: pairs and morale together | ↓tactical growth and ↓rest — it is never quiet |
| **Wardrobe and storage** | frees **two** small slots in this room | three floor to give back two |
| **Study nook** | the desk, at scale: strong tactical growth for the room | ↓morale for everyone in it |
| **Instrument corner** | morale, and it draws people from other rooms | ↓rest for the room and its neighbours |

**Wardrobe and storage is deliberately a bad trade on paper** — three floor for
two slots — and becomes a good one in a large room where floor is not the
binding constraint. An item that is wrong in most rooms and right in a few is
worth more to this design than one that is mildly correct everywhere.

**Weights are the only athletic object left**, and they survive because volis
genuinely keep weights in their rooms and genuinely hurt themselves doing extra.
It is the exception that the register allows, not the start of a category.

### Shared installations — what a common room can hold

Only structures with a shared room can install these, which is what the Commons
buys and what the Row gives up. All of them are **domestic**: this is a living
room, not a facility.

| installation | what it does |
|---|---|
| **The long table** | everybody eats together; squad-wide comfort, and it builds **cross-room** ties — the weak edges of §8 |
| **The hearth** | a place to sit after a bad night; squad-wide morale floor, strongest when results are poor |
| **The big kitchen** | aversion answered for the whole squad, and the paste rotation lives here |
| **The washing room** | mundane, squad-wide, removes a small standing friction — the club that has one never thinks about it |
| **The porch / garden** | outdoor sitting; morale that scales with the region's climate and season |
| **The noticeboard** | events reach the squad faster — a strain warning arrives a week earlier |

The noticeboard is the one that touches §9 directly: it does not change what
happens, it changes **when you are told**, which is the whole currency of the
event system.

### What this changed, and what it did not

- **Removed**: gym, film room, ice bath. All facility, none of them home.
- **Renamed**: Pavilion → the Commons, with the reason recorded.
- **Kept**: floor as the single constraint, crowding as a play rather than a
  failure, equipment answering conditions, events as the readout, transition as
  the cost of changing structure.
- **Grew**: six structures against three, fourteen small items against seven,
  seven large against four, six shared against four.

Still no numbers, for the reason in §10: two of the three quantities everything
here multiplies are currently pinned.

---

## 12. Cutting the wardrobe, regional structures, and where the food comes from

### The wardrobe was arithmetic, not a decision

Three floor to give back two slots is strictly worse than three floor of slots.
There is no room in which it is right, and §11's defence of it — *wrong in most
rooms and right in a few* — was a good-sounding sentence wrapped around a bad
item. **Cut.**

If storage should exist it is small and it does something real rather than
playing with the slot economy. The version that works:

| item | floor | what it does |
|---|---|---|
| **Trunk** | 1 | somewhere to keep what they brought with them: a small standing reduction in homesickness, permanent and cheap |

That is a domestic object doing a domestic job. It does not touch the floor
rule at all, which is the point — the floor rule should be the thing items are
*spent against*, never the thing they are about.

### Structures as regional practice

Drafted for a read, not proposed. The claim: a structure is not neutral
architecture, it is **how a region houses its athletes**, and a club importing
one is importing somebody else's idea of how to live.

| structure | reads as | because that region's own words say |
|---|---|---|
| **Longhouse** | Spëddigh | *"close-knit and compact"* — the phrase is already a description of how they live |
| **Farmhouse** | Landavol | *"intentionally broad… specialize into anything"* — a generalist culture that grows what it eats |
| **The Quarters** | Pāwa Hitō | *"conditioning halls mold the Hitōue"* — you live where you train, and the hall is the address |
| **The Block** | Bloc du Larg | *"methodical… perfecting its structure"*, and the name is already the building |
| **The Row** | Xérvu | *"individualism and deep respect for routine"* — separate quarters, kept the same way every day |
| **The Commons** | Taktikã | *"cerebral… strip the game down to its roots"* — a shared room, but it is a **working** room, not a warm one |
| **Bunkhouse** | everywhere | which is why it is nobody's identity |

**Corrected, and worth recording why.** The first draft of this table assigned
the Commons to *Nõ Errõ*, which is not a region — it is a **club**, one of
Taktikã's, sitting in `CLUB_NAMES` two lines away from the list I should have
read. The rest of the mapping was no better: it was assigned by vibe rather than
against the taglines each region already has, which are specific and were right
there. Redone above by quoting them.

**The Quarters is new**, and it exists because Pāwa Hitō's tagline demanded a
structure nothing on the list provided: housing attached to the training hall.
Best conditioning in the game, no separation between work and home, and the cost
is that it is the one structure where *nothing about living there is not about
volleyball* — no kitchen worth the name, nowhere to be a person. A region can be
right about how to build athletes and wrong about how to keep them.

**The Commons reads differently under Taktikã** than it did as a generic warm
hall, and better: the shared room is where the squad works through what
happened, not where they relax. Same structure, opposite temperature, which is
what makes it Taktikã's rather than everybody's.

Two consequences worth having, if this survives:

**A structure out of its region costs something.** Building a Row in Landavol is
importing a way of living that the local staff and the local volis do not
practise — so it works, and it works slightly worse, and it makes you slightly
strange. That is a *far* better cost than money.

**And it makes a club legible before you read a single number.** A Longhouse
club and a Row club are different places to work, and a voli deciding whether to
sign is deciding about that as much as about wages.

The risk, stated so it can be checked later: this could collapse into *pick your
region's structure, always*. It only stays interesting if a squad's needs and
its region's practice disagree often enough — which is a thing to measure once
squads have needs, not a thing to assert now.

### What is built: character creation and food

**Character creation is club creation, and the manager is barely in it.**
`scenes/screens/new_career_screen.gd` runs region → club type → identity, and
writes principles. `docs/design/CHARACTER_CREATION.md` is about *who the manager
is*, and almost none of that is there. `BACKLOG` already carries the
consequence: entry "Mirror the clipboard for a left-handed manager" depends on a
manager handedness that nothing sets.

**Food is not built at all.** There is a `Chef` staff role in
`scripts/models/staff_member.gd` — with a good note already on it, that a chef
cooks their own region's food and carries a palate memory — and mentions in the
encyclopedia and the inbox. No blocks, no pastes, no aversion, no palate. The
whole of §1 and §2 of this document is unwritten code.

### Where the food comes from: a flow, not a stockpile

The question is whether the club stocks up, and the answer that fits everything
else here is **no — you have a supply, not an inventory.**

A weekly flow from the chef, sourced from **where you are**:

- every region grows and makes certain things, continuously
- a club receives its own region's staples as a matter of course, at no
  particular cost and no particular thought
- anything from elsewhere arrives by distance: further is dearer, slower, and
  more easily interrupted
- the chef manages all of it, and the manager hears about it **only when
  something breaks** — which is §9's event system doing exactly its job

That gives three things at once.

**No inventory screen.** Counting sacks of flour is the wrong game. The manager
sets a standing arrangement and the chef runs it, the same way the four rows of
§6 are standing arrangements.

**Geography becomes a constraint rather than a label.** Your menu is bounded by
what your region produces. A Landavol club eats Landavol food without deciding
to; eating anything else is a supply line you are choosing to run.

**And it closes the loop on aversion.** §11 has volis with food aversions and
gives the cookbook, the kitchenette and the Farmhouse as answers — but never
said what an aversion *is*. Now it is obvious: **a voli is averse because the
region they are in does not grow what they grew up eating.** Aversion is not a
personality quirk, it is a fact about two places, and it appears the moment you
sign somebody from far away. Which makes the landline, the letterbox, the
cookbook and the trunk all the same shape of problem — *this is not where they
are from* — approached four different ways.

The chef's own origin, already noted in `staff_member.gd`, becomes load-bearing
under this: a chef from a voli's home region can cook what that voli misses, and
hiring one is a signing decision about the squad you have rather than about
staff quality. That is the same "purchase you might decline" test §9 sets, and
it passes.

### Order, unchanged in shape

Fatigue persisting still gates everything. But the food supply is the one part
of this document that could be drafted *without* it, because a flow, a
geography and an aversion are all facts about the world rather than multipliers
on recovery — and having them would give the events in §9 something real to
interrupt.

---

## 13. The food supply: a flow with a geography

Drafted because it is the one part of this document not blocked on fatigue
persisting — a flow, a geography and an aversion are facts about the world
rather than multipliers on recovery.

### The shape: nobody counts anything

A club does not hold stock. It has a **standing supply**, which arrives, and
which the chef turns into a week of meals. The manager sets an arrangement and
hears about it only when it breaks.

That is deliberate on two counts. Counting sacks of flour is a different and
worse game, and — per §9 — a supply that simply works is a supply whose *events*
carry all the information. You learn you were dependent on one region's harvest
by the week it fails.

### What a region has

Every region produces a small set of **staples** and one or two **pastes**.
Staples are the base of a food block; pastes are the flavour and the character,
and `docs/world/` already treats them as regional.

The list is not proposed here — authoring it is a world job, not a systems one.
What the system needs from it is only this:

- a region **produces** some things, always, at no cost to a club sited there
- some of those things are **seasonal**, so the year has a shape
- anything a region does not produce has to come from one that does

### Distance is already modelled

`VolleyballRegions.REGION_ADJACENCY` exists. A supply line's cost and fragility
should be read off it rather than from a new number:

| source | cost | reliability |
|---|---|---|
| your own region | none | total |
| an adjacent region | modest | high |
| two steps away | real | interruptible |
| further | expensive | the events section's favourite target |

**This is the thing that makes geography a constraint rather than a label.** A
Landavol club eats Landavol food without ever choosing to. Eating like Pāwa Hitō
is a supply line you are running on purpose, it costs, and a bad winter two
regions away is now your problem.

### Which is what an aversion *is*

§11 gave volis food aversions and never defined one. Under a supply with a
geography it defines itself:

> **A voli is averse because the region they are in does not produce what they
> grew up eating.**

Not a personality quirk — a fact about two places, computed from the voli's
`home_region` and the club's. It appears the moment you sign somebody from far
away, it is *predictable at signing*, and it has four different answers already
on the board: the **cookbook** (this voli, cheaply), the **kitchenette** (this
room), the **Farmhouse** (the whole squad, structurally), and a **supply line**
to their home region (the whole squad, expensively, and it feeds everyone else's
palate rotation too).

Four answers at four prices to one problem is the shape §11 wanted more of.

### And palate is the same term, running the other way

Aversion is *this is not what I eat*. Palate is *this is what I eat, and it has
been for two months*. Both are a distance between a voli and what is on the
plate; one is measured against where they are from, the other against what they
have had recently.

Modelling them as one quantity with two inputs is what stops the table needing
two systems, and it means the paste rotation is not variety for its own sake:
rotating is how you keep palate down, and the pastes you *can* rotate through
are exactly what your geography and your supply lines allow.

### The chef, who is already written for this

`scripts/models/staff_member.gd` already says a chef cooks their own region's
food and carries a palate memory. Under this design that note becomes
load-bearing:

- a chef **extends your supply** into their own region at reduced cost — they
  know who to ask
- a chef from a voli's home region can **answer that voli's aversion** directly,
  without a cookbook or a supply line
- a chef's palate memory is **how many pastes they can rotate before repeating**

Which makes hiring a chef a decision about the squad you have rather than about
staff quality — the §9 test for a purchase worth declining, and it passes
cleanly. A brilliant chef from the wrong region is worse than a decent one from
the right one, for a squad with two homesick imports.

### The weekly loop, in full

1. The supply arrives — your region's produce, plus whatever your lines carry.
2. The chef builds the week from what is there, honouring the arrangement.
3. Aversion is answered or it is not, per voli.
4. Palate moves: up on repetition, down on rotation.
5. Something occasionally fails, and you hear about it.

The manager touches step 1 (which lines to run) and the arrangement in step 2.
Everything else is the world running.

### What it needs

1. **Region produce lists** — a world-authoring job, and the only genuinely new
   content. Staples and pastes per region, with seasonality.
2. **Supply lines** on the club: which regions you source from. A short list,
   costed by adjacency.
3. **Aversion as a derived value**, from `home_region` against what is on the
   plate. Nothing stored per voli — it is computed, which means it stays true
   when a voli transfers.
4. **One palate figure per voli**, moved weekly. The only new persistent state
   in the whole design.
5. **Interruption events**, which §9 already has a home for.

Items 2 to 5 are small. Item 1 is the work, and it is the enjoyable kind.

**It can all be built before fatigue persists**, and it should be: it gives the
event system something real to interrupt, it gives the cookbook and the
kitchenette something real to answer, and it turns the six regions from taglines
into places that grow different things.
