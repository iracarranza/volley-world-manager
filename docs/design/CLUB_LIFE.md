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

> I think I'm allergic to Xervyan food.

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
cause.** One who says they are allergic to Xervyan food may have high palate
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
