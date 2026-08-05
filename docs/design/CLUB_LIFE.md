# Club life: staff, sponsorships, and what a voli has to say

Living draft. Nothing here is built, and the thinking that produced it is not
finished. It is written down at this size because the pieces have started to
depend on each other, and a design that has begun to interlock is one you can
no longer hold a corner of at a time.

`ACCOMMODATIONS_AND_CARE.md` holds the food and lodging detail. This is the
frame around it.

## 0. What the game is for

Two audiences normally treated as opposites: deep-simulation players, and cozy
slice-of-life players. And a third condition on top -- someone should be able to
arrive with no interest in volleyball and leave with an appreciation for it,
without ever being required to learn the intricacies, and with those intricacies
available to anyone who wants them.

**These audiences do not actually conflict on depth.** Cozy players tolerate
enormous systems; the turnip market is not shallow. They conflict on *failure*.
A simulation player wants failure legible, causal and their own fault, because
that is the reward. A cozy player wants failure low-stakes and recoverable,
because punishment breaks the register.

So the rule is: **failure is legible and gentle.** You can always see exactly
why something went wrong, and it never spirals. A lost sponsorship costs morale
and standing with that organisation, never the club's survival. A bad month of
meals is a bad month, not a death spiral.

The corresponding rule for the cozy systems is that they must be **expressive
rather than optimal**. The moment a system has a correct answer it belongs to
the simulation half; if it does not, it has to be protected from acquiring one.
Palate fatigue decaying on the specific ratio rather than the paste is the
model: there is no stable best meal, only choices that stay interesting.

### Teaching the sport

Not through tooltips and glossaries -- those only reach people who already want
to learn. People come to appreciate a sport by caring about an outcome first and
noticing why it happened second. The sport should be learnable backwards: you
notice your voli keeps getting stuffed, then that the block is always there
early, then you find tempo.

That makes **playback the teaching surface**, not the UI. A rally drawn as
captioned beats in sequence teaches nothing. A rally at true physical time,
where the block lands *with* the swing and a defender is visibly forced to their
knees, teaches volleyball without a word of instruction. It is the strongest
argument for finishing the playback timeline work, and the reason the dig
postures are driven by the resolver's own verdict rather than chosen for looks.

### The interface principle

Pastes are dragged onto a food block to set a ratio, and a raw number editor is
there for anyone who wants to type it exactly. That one control is the whole
thesis: cozy players never see a number, simulation players never fight the
mouse, neither mode is the "real" one and there is no toggle between them.

Hold every other system to it. **Can this be operated by feel and inspected by
number, without either being the authoritative version?** Training, lineup and
scouting should all take that shape.

## 1. Volis

The umbrella term for players. Worth adopting for a practical reason as well as
a flavour one: "player" currently means both the thing on court and the person
holding the controller, and every document so far has had to disambiguate that
by hand.

### What they say

Football Manager players voice **professional grievances** -- playing time,
wages, transfers. Volis voice **bodily and domestic** ones:

> I think I'm allergic to Xérvyan food.

> Our physio stretched my arms out too long.

That difference is the point rather than a joke. It changes the relationship
from managing employees negotiating their careers to looking after creatures who
have opinions about their food and their limbs, which is the same register the
accommodations design is written in: every number legible as care or neglect.

Note that in this world the second complaint is not necessarily a metaphor. Arm
length is a real per-player property that the silhouette reads from. Occasional
small, semi-permanent physical consequences of staff action are mechanically
trivial and exactly on tone, and they give the physio a signature failure mode
that is not merely "recovered slower".

### Unreliable self-report

Every utterance is caused by real state. **The voli may be wrong about the
cause.** One who says they are allergic to Xérvyan food may have high palate
fatigue on a paste from that region, or a morale drop that happened to land near
a meal change, or a mentoring pairing that is not working.

This does three things at once:

- Complaints become functional without becoming oracles. You get a signal, not
  a readout.
- The scout and physio earn their slots by **translating** complaints into
  causes. Weak staff leave you with a voli who believes they are allergic to
  aubergine.
- A wrong complaint is still a true feeling. Acting on a mistaken one has real
  morale value even when it fixes nothing, which is a good dilemma.

Real allergies exist underneath as ground truth: some volis report one they do
not have, some have one they have not noticed. Low impact, low urgency,
tangible, addressable without being an irritant -- and the presence of genuine
allergies is what gives the complaint system stakes rather than making it
flavour text.

**Keep utterances rare.** The failure mode is Football Manager's: enough of them
that they become noise to be dismissed. Once every few weeks, always about
something real, and every one gets read.

### What their faces are for

Volis have faces (`scripts/data/face_expressions.gd`): nine of them, and the
name is derived rather than authored -- three eye states by three mouth shapes,
and the label is whatever the pair reads as. Narrowed eyes under a smile *is*
devious; it is called that because of what it is made of.

**Unresolved: whether a face is who someone is, or a report on how they are
doing.** Both, is the proposal, and the split matters:

- A **resting face** as a trait -- stable, part of how you recognise a voli
  across a season, and what makes a roster look inhabited rather than staffed.
- A **live expression** that overrides it when something is actually true: a real
  complaint, a morale drop, a ratio worn through.

Neither alone works. Purely a trait and the expression system can never say
anything, so the art budget bought decoration. Purely state-driven and a settled
squad is a wall of identical neutrals, which is worse than no faces at all.

If the live half is built, it inherits both existing rules. It is a **signal, not
a readout** -- a worried face says something is off, not what, and the voli may
be as wrong about it as their utterances are. And it stays **rare**: three
worried volis every week is wallpaper, and the resting face should be what you
see nearly always.

Assigned at random today, hashed from the voli's id so it is at least stable.

**They do not read at match distance.** Eyes survive as dots and mouth curves do
not, so this is a roster and close-up feature unless the match camera comes in.
Worth knowing before anything is designed around reading a voli's mood from the
court.

## 1b. Where social conflict comes from

The open problem: social systems need conflict to be about anything, and the
usual engine is unavailable here on purpose.

**Football Manager's engine is employment.** Grievance, negotiation, opposed
interests, someone treated unfairly. That works because it sits on a
sociopolitical substrate -- status, money, class, who deserves what. This world
deliberately does not have one. Body types are simply accepted rather than a line
anyone divides along, and regions trade without any of it meaning exploitation.
Strip that substrate out and grievance conflict has nothing underneath it.

**The move is to stop equating conflict with antagonism.** Most conflict in cozy
games is not two parties opposed; it is **one finite thing and more than one
legitimate claim on it**. Nobody is behaving badly. You simply cannot do both.

This game already generates that everywhere and has not noticed:

- **The chef's attention.** A fixed number of separate meal plans per week. Two
  volis need one. Both are right.
- **The squad-wide table.** One block, one ratio, a roster raised in six places.
  Somebody's favourite is somebody else's fatigue.
- **Minutes.** A sponsorship participation quota against the lineup that wins the
  match. The voli chasing it has a real claim; so does the season.
- **Training hours.** The assistant coach's throughput is finite and the
  development curve is not patient.
- **Rooms on an away trip**, and **a mentor's time**, which is the scarcest thing
  in the building the moment mentoring exists.

So the rule: **social conflict here is two volis both being right.** No villain,
no bad behaviour, nothing to forgive -- just care that does not divide evenly.

That serves both audiences without compromise, which is rare. The cozy player
gets conflict with nobody to be angry at and no moral failure to sit with. The
simulation player gets allocation problems, which are the most legible kind there
is: finite input, competing claims, measurable outcome, and your decision is
visibly the cause. It also explains why the world does not need a political layer
-- **the conflict is in the household, not the polity.**

Two smaller sources sit alongside it and need no other party at all:

- **Conflict with the body.** Allergies, fatigue, a physio who stretched
  somebody's arms too far. Friction with nobody on the other side of it.
- **Conflict with your own past decisions.** You promised minutes in week 3 and
  the lineup needs someone else in week 9. Self-inflicted, legible, and gentle,
  which is the house style.

**The honest cost of this model: allocation conflict is quiet.** Nobody storms
out of a room over a meal plan, so it will not generate drama on its own the way
a grievance system does. It surfaces only through what volis say, which puts far
more weight on the utterance system than it would otherwise carry -- and makes
"rare, always about something real, every one gets read" a requirement rather
than a preference. If the utterances are noise, this whole model is invisible and
the systems read as spreadsheets.

## 2. Staff

Four roles, two tiers. Each owns exactly one resource, which is what stops the
roster being four hires in a list.

| role | owns | hooks into |
| --- | --- | --- |
| Assistant Coach | training throughput | training, development |
| Scout | information confidence | scouting, hidden potential |
| Chef / Nutritionist | morale and nourishment | accommodations |
| Physio | condition and fatigue recovery | staged fatigue |

Two make volis *better*; two keep them *knowable and available*.

The scout owning information confidence means staff quality becomes **how far
you can trust your own numbers**. A bad scout does not give you worse volis, it
gives you a blurrier roster -- a more interesting failure than a stat penalty,
and the same mechanism the thought-bubble idea and hidden potential both need.

The physio is the fourth because it pairs with the chef as fuel and repair, and
because it is the only candidate that gives the staged-fatigue design an owner.
The alternative considered was a Quartermaster owning travel and lodging, which
pairs more neatly with the chef but leaves fatigue ownerless and is thinner.

**Recorded honestly:** the fourth slot exists because a lone chef at that tier
felt out of place. That is an aesthetic reason for a mechanical decision, and
the 2x2 above is a rationalisation built on top of an instinct rather than a
test of it. The instinct may well be right. It has not been checked.

### Staff have origins too

Staff carry a region of origin and a current location, like volis. Ingredients
near the club are cheap; distance adds import cost. Chefs are familiar with
particular regional cuisines and cook them better.

**Convergence risk:** cheap local ingredients plus a locally-familiar chef is an
obvious dominant strategy, and every club would converge on hiring local and
cooking local. What prevents it is that **volis' own regional preferences pull
against it** -- a squad drawn from six regions cannot all eat local, so cheap
food is homesick food for most of them. That tension has to be deliberate rather
than hoped for.

The pleasant consequence: every club tastes of where it is, and its imports are
always a little homesick.

## 3. Sponsorships as quests

A sponsor contacts **a voli, not the club.** That is the engine. It generates
obligations you did not agree to and may not want to serve.

Requirement archetypes:

- **Performance** -- a number of kills or digs across five matches. Pushes a
  voli to swing when they should tip.
- **Participation** -- simply play. The strongest case is a weaker voli earning
  by appearing: a direct, legible tension between winning this match and funding
  the club.
- **Behavioural** -- follow a particular diet. Collides with the chef.
- **Development** -- reach an attribute threshold. Slow-burn, and it makes
  training allocation a financial decision.

**Failure must cost something other than money.** Losing a sponsorship should
hit the voli's morale and burn standing with that organisation so future offers
dry up. Otherwise a failed quest is an unclaimed bonus and there is no reason to
care.

**The voli has an opinion.** Benching someone who is chasing a participation
quota carries a morale cost, which drags sponsorship into the social systems
instead of leaving it as finance.

**Sponsor archetypes, keyed to content that already exists:** a produce brand
that specifically wants a Vegi, a regional organisation that wants a voli with
that `home_region`, an equipment maker that wants raw physical numbers. All
three read as characterful and none of them needs new data.

### The collision, and whether it is real

A sponsor demanding a diet against the chef's meal plan is the first genuine
cross-system conflict in the design. Conflicts like that are what management
games live on -- two systems you own, both correct, pulling opposite ways.

But it only works if you have agency on both sides. Meals default to team-wide
and can be differentiated at a compounding cost, which restores that agency:
feeding one voli separately is possible, and it is expensive in a way that grows
as you do it more, exactly as mass production is cheaper than bespoke.

**The remaining hole:** if the only cost is money, the decision collapses into
arithmetic. Sponsor pays X, differentiation costs Y, do it when X exceeds Y --
a solvable optimum, which is the thing being guarded against everywhere else.

Proposed fix, not yet settled: differentiation should cost **the chef's
attention** rather than only funds. A limited number of separate meal plans per
week, scaling with chef quality. Money is fungible and therefore dull; attention
is a real allocation. It also means a better chef's reward is *flexibility*
rather than a larger number, which is harder to power-creep.

## 3b. The world is a ball, and that is usable

A volleyball has **18 panels in 6 groups of 3**. Sixnet already has six regions.
That is not a coincidence to force -- it is a structure that hands over three
things a geography system needs:

- **Adjacency for free.** Regions sharing a seam are neighbours.
- **Distance that already has a job.** Import cost follows seam distance, which
  is exactly what paste and ingredient availability needs.
- **A shape nobody else has.** Every other fantasy map is a landmass.

**Do not render it as a sphere.** Players cannot see the back, curvature makes
adjacency ambiguous, and nothing can be labelled legibly. The version that works
is the **flattened panel pattern** -- the way a shoe upper or a sail plan is
drawn -- with the six groups laid flat and the seams visible. The identity and
the adjacency both survive; the readability problem does not.

### The atlas

The world needs somewhere to be learned, and it should earn its place
mechanically rather than being a lore page nobody opens. Per region:

- what it **grows** -- pastes and ingredients, with their import multiplier from
  your club. Mostly this is the **minor** regions' entry: each core region sells
  a paste its minor neighbour grows, which is the atlas's reason to have a page
  for a place that runs no academy
- what it is **called by** -- its demonym (`VolleyballRegions.DEMONYMS`), which
  is the word that appears in every complaint and sponsor line about food
- what it **makes** -- food blocks, which is a different map over the same
  panels: growing follows land, manufacturing follows capital, and the two do not
  coincide (see `ACCOMMODATIONS_AND_CARE.md`)
- who it **produces** -- volis carrying that `home_region`
- how it **spells** -- the region's orthographic signature, which is what lets a
  product name declare its own factory
- its **seam distance** from where you are

Then the atlas is where you go to understand why your clean umami costs 1.4x.
That is the same principle as teaching volleyball through playback: you arrive
because you needed something, and the geography is what you find. Nobody learns
a map they were handed; they learn one they had a reason to read.

**So it must be reachable from the moment of need, not only from a nav tab.** The
paste stores panel gets a jump-to-globe control; anywhere else that shows an
import multiplier should get the same. A map you can only reach by deciding to
look at a map is the lore page this is trying not to be.

## 4. Open questions

- Whether a fourth staff member earns its slot mechanically, or whether the chef
  simply belongs at the coach and scout tier. Untested.
- Whether differentiation cost is attention, money, or both.
- Whether sponsorship requirement progress is precisely visible, or graded by
  the scout's information confidence. Leaning visible for your own volis and
  fuzzy for rivals'.
- Whether nutrition feeds the staged-fatigue model directly or sits beside it.
  It should hook in rather than duplicate.
- Whether palate fatigue is a visible number or has to be read from behaviour.
  Reading it from behaviour is better for the fiction and worse for usability; a
  confidence-graded hint is probably the middle.
- What the block layer differentiates on beyond nutrition/morale/cost, now that
  regional-dish morale is off the table. The proposal is how well a block carries
  paste; the multiplier shape is unchosen and it could read as an arbitrary
  penalty. See `ACCOMMODATIONS_AND_CARE.md`.
- Which regions manufacture Supergruel and Vollyslommy -- now known to be
  unanswerable from the name, since neither is a label name. Both are nicknames,
  so the spelling is the speaker's rather than the factory's. Chutum Üch and
  Blan'deral do carry their factory (Spëddigh, A'ace). See
  `ACCOMMODATIONS_AND_CARE.md`.
- How large the block catalogue is, given that availability rather than
  existence is what bounds the menu. "More than your kitchen can reach" answers
  the design question but not the authoring one.
- Whether the atlas is its own nav section or lives inside Club. The jump-to-globe
  control makes it reachable either way, which lowers the stakes of the answer.
- How many pastes exist. Eight was the first instinct and is a lot of
  combinatorial surface for a system whose output is a morale figure. The slot
  limit below reduces the objection from a scale problem to a discovery problem,
  which is a better problem, but the number is still unchosen.

## 5. Foundations this depends on

Most of the above is downstream of three pieces that do not exist yet, and
building any single feature without them means building a private version that
later has to be unified -- the defect shape this codebase has repeatedly.

1. **Persistent per-player state.** Fatigue, morale, palate fatigue,
   relationships and confidence all need mutable per-voli state that survives
   matches and decays. `VolleyballPlayer` is currently static attributes.
2. **A between-match tick with ordered phases.** `advance_week` exists as a step
   rather than a pipeline. The moment two of these systems exist, "which happens
   first, meals or training?" becomes a real question.
3. **Information confidence.** Scouting confidence exists for the opponent;
   nothing models your uncertainty about your own volis. Thought bubbles, hidden
   potential, unreliable self-report and scout reports are all one mechanism.
