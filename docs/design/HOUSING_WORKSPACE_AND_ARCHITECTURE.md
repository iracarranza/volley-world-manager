# Housing workspace and architecture

The interface and decision layer around `ACCOMMODATIONS_AND_CARE.md`.

That document owns what housing **does** to the club: structures, rooms, floor,
equipment, roommates, regional practice, renting, owning, moving and food/living
consequences.

This document owns how the manager **understands the home they inherited, manages
it now, and changes it later**.

The central correction is simple:

> **The player manages housing. They are not an architect.**

---

## 0. Housing has three jobs

One screen was being asked to do three different things:

1. show **where the volis live now**;
2. let the manager **adjust the current living arrangement**;
3. let the club **plan a different home for the future**.

All three belong to housing, but they should not be flattened into one blueprint.

The housing folder should therefore have a clear present/future distinction:

### Present — **Our Home**

The lived situation:

- current structure;
- owned or rented;
- occupants and roommates;
- equipment;
- common spaces;
- current problems and strengths;
- current squad fit;
- lease/ownership facts;
- the option to visit and observe the home being inhabited.

### Future — **Property / Change Our Housing**

The long-horizon decision:

- available rentals or purchases;
- plots;
- architect portfolios;
- recommendations;
- quotes;
- proposals;
- revisions;
- construction/renovation;
- moving and transition cost.

The **present is the default**. Housing exists because these are the places the
volis actually live, not because property development is the main game.

---

## 1. Taking over a club means inheriting a housing situation

A new manager should not receive a blank accommodation system.

When taking over an existing club, the player inherits:

- its current building or buildings;
- whether they are rented or club-owned;
- lease terms where relevant;
- room assignments;
- existing equipment/installations;
- history of recent moves;
- the current squad's relationship to the place.

The first read should answer ordinary management questions:

> Do we own this or rent it?
>
> What kind of home is it?
>
> How well does it suit this squad?
>
> What currently causes friction?
>
> Are we likely to outgrow it?
>
> What would changing it cost in money, time and disruption?

Different clubs should feel different before the manager changes anything.

---

## 2. Do not collapse housing into a universal quality rating

`DIEGETIC_MANAGEMENT.md` already warns against `Housing Quality: 67`, and this
remains correct.

A structure's **type** and its **fit for the current squad** are more important
than a ladder from bad to luxury.

A very well-made Row can be wrong for a young, unfamiliar roster. An ordinary
Bunkhouse can be exactly right.

If broad descriptors are needed, keep distinct concepts distinct:

### Building standard / condition

A property fact about this particular building:

- newly built;
- well kept;
- sound;
- worn;
- needs repair.

This is not the same as how useful it is to the squad.

### Squad fit

A contextual judgment about the **current** roster:

- strong fit;
- workable;
- strained;
- likely to be outgrown;
- wrong for current needs.

Prefer prose/reasons to `/100`.

The useful sentence is not:

> Housing quality 73.

It is:

> Well-kept Commons; good fit for this young squad, but two rooms are already
> crowded and there is little expansion room.

---

## 3. Architecture must remove expertise from the player

The manager should not have to know:

- wall insulation;
- circulation theory;
- ventilation;
- structural efficiency;
- corridor geometry;
- architectural acoustics;
- how to draw a floor plan.

Those may exist underneath if a simulation eventually needs them. They are not
the player's vocabulary.

The manager's question is:

> **What do I want this housing to accomplish, what can I afford, and when do I
> need it?**

The architect's question is:

> **How do I make a building accomplish that?**

This is the same professional boundary used elsewhere:

- chef knows how to prepare food; manager sets the club's food arrangement;
- physio knows treatment; manager decides staffing/workload and whether to heed
  advice;
- scout knows how to investigate; manager decides what they need to know;
- architect knows buildings; manager gives the brief.

> **Professionals translate manager intent into specialist execution. The player
> manages the brief, resources, personnel and consequences — not the profession
> itself.**

---

## 4. Architects are portfolios, not matrices

The housing interface should move away from a blueprint editor and toward
**commissioning professional work**.

An architect is presented through a portfolio:

- prior projects;
- structures they are known for;
- broad specialties/tendencies;
- region/local familiarity;
- usual cost/time character;
- availability;
- relationship with the club;
- interest in taking this particular commission.

Good player-facing specialties are broad:

- Longhouses;
- communal living;
- private-unit projects;
- compact builds;
- renovations;
- high-capacity housing;
- inexpensive projects;
- regional adaptation;
- expandable projects.

Avoid a skill spreadsheet such as:

> Bedrooms 71 / Kitchens 64 / Circulation 83 / Climate 76.

That makes architectural expertise the player's homework.

Two or three readable strengths plus relevant experience are enough.

### Interest matters

An architect should not be a vending machine.

Interest may depend on:

- club reputation;
- region;
- project type;
- prior work with the club;
- project budget;
- their schedule;
- whether the project is prestigious, unusual or personally interesting.

This supports good stories:

> The famous architect is not interested.
>
> A younger local practice loves the brief and quotes aggressively.
>
> The architect who built the current home already understands the club.

---

## 5. The player gives a brief

The construction interaction should be closer to:

```
STRUCTURE
Commons

NEEDS
12–14 volis

PRIORITIES
Communal living
Room to expand

BUDGET
Moderate

TIMING
Ready before next season
```

than:

```
TARGET QUALITY: 78
BEDROOM QUALITY: 65
CORRIDOR WIDTH: ...
```

Possible manager-level priorities include:

- keep cost low;
- finish quickly;
- maximize privacy;
- emphasize communal living;
- leave room for equipment;
- suit the local climate;
- leave room to expand;
- maximize capacity;
- preserve a familiar regional way of living.

The brief should be intentionally over-constrained if the player wants it to be.
The architect's competence appears in how well competing requests are reconciled.

---

## 6. Skill means solving the brief, not producing hidden defects

A weak architect should not routinely create technical traps the player had no
way to understand.

Most projects should fall between:

> They delivered almost exactly what was asked for.

and:

> Something had to give.

A stronger architect:

- handles more competing priorities;
- estimates cost/time more accurately;
- adapts unfamiliar structures better;
- wastes fewer usable constraints;
- makes better compromises when budget/timing tighten;
- gives better recommendations before the club commits.

A weaker architect may return a proposal such as:

> We can house 12 comfortably, or 14 if two rooms are crowded. The shared room
> can stay large, but expansion would be difficult at this budget.

That is management information. The player does not need to know which wall
caused it.

### Local and structure familiarity matter

Raw architect skill should not dominate every decision.

A great Xérvyan architect may know:

- local trades;
- materials;
- climate;
- permitting;
- Rows;

but have little experience with Longhouses.

A merely good Pāwan architect may understand Longhouses perfectly but be working
outside their region.

A mediocre local architect may be cheap, available and very reliable on a
straightforward local build.

This is the same shape used elsewhere in staff design: **skill × familiarity ×
task complexity**, not one quality number.

---

## 7. Quotes, recommendations and revisions

An architect should be able to do more than return a price.

Useful interactions:

- **Ask for a quote** — cost and timing range for the current brief.
- **Ask for a recommendation** — what structure/compromise they think suits the
  squad, site and budget.
- **Ask for a proposal** — a manager-readable schematic and the trade-offs they
  expect.
- **Request one revision** — e.g. more capacity, stronger communal emphasis,
  cheaper, faster, more expandable.

A good architect may disagree intelligently:

> You asked for a Commons, but with fifteen volis and this site I would build a
> Block with a proper shared hall.

The player may still insist. Expertise informs agency; it does not replace it.

---

## 8. The proposal is a functional schematic, not a blueprint

The architect translates architecture into the same simplified language the
finished housing workspace will use.

Example:

```
NAL ËRU — PROPOSAL

      Room    Room
        \      /
      COMMON ROOM
       /   |    \
    Room Room  Room

12 comfortably
14 with crowding

Strong shared space
Moderate private floor
Expansion possible

Quoted: ...
Completion: ...
```

This is not supposed to tell the player where a structural wall sits. It tells
them **what kind of living arrangement the proposal creates**.

See `ABSTRACTION_AND_MANIFESTATION.md`: the schematic preserves social and
functional topology, while the 3D view owns literal place.

---

## 9. Renting and building ask different questions

### Renting / buying existing stock

The player chooses among **existing compromises**.

An estate/property listing may communicate:

- structure;
- capacity;
- rent/purchase price;
- condition;
- existing installations;
- current location/region;
- lease term;
- broad fit for the present squad.

Example:

> Cheap Bunkhouse, small rooms, good for a young squad, little equipment space.

### Building

The player can **commission the compromise** they want.

They choose:

- structure/site;
- brief;
- budget;
- timing;
- architect.

The architect returns the actual proposal.

This makes ownership meaningful without turning it into a quality upgrade.

---

## 10. Why deliberately build modest housing?

A modest project needs more reasons than simply "you are poor".

Defensible reasons include:

- preserve cash for wages/recruitment;
- complete it before the season;
- the club expects to outgrow it;
- roster size is uncertain;
- unfamiliar structure/foreign region raises execution cost;
- local materials/practice favor a simpler build;
- build a first phase and expand later;
- the site/lease future is uncertain;
- prioritize one part of the brief and deliberately leave another plain;
- avoid displacement during a competitive window;
- the current club culture genuinely prefers a simple communal home.

A modest house is not automatically neglect.

The game should not encourage the manager to commission "5/100 housing" where
saving money means knowingly making the volis live somewhere unsafe or
inhumane. Truly bad housing is better expressed through old rental stock,
damage, emergency accommodation, failed maintenance or unusual circumstances —
not a normal optimization slider.

---

## 11. Housing economics

Housing can be one of the game's largest **capital** decisions without importing
a contemporary real-world housing crisis as the setting's central economic fact.

Useful distinction:

- **salary** — major recurring competitive expense, scales with roster quality;
- **rent** — meaningful recurring overhead, especially for small clubs;
- **owned housing** — enormous long-horizon capital expense, eventually buys
  control and removes rent.

Owned housing matters because it is the club's and can be deliberately shaped,
not because ownership grants a global quality buff.

---

## 12. The housing folder: current organization

The folder is the desk representation. It should be recognisably different from
both the tactical worksheet and an architectural blueprint.

Conceptually:

### Current Home

The first page.

- large image/illustration/live thumbnail of the property;
- structure;
- owned/rented;
- capacity/occupancy;
- broad current squad fit;
- condition if relevant;
- common spaces/installations;
- current concerns;
- **Visit Home** when observation is available.

### Rooms

A simplified functional diagram/cards:

- occupants;
- remaining floor;
- equipment;
- crowding;
- roommate changes;
- room assignments.

### Property

The hard record:

- title/lease;
- expiration;
- recurring cost;
- capacity;
- structure;
- existing building installations;
- move history where useful.

### Change Our Housing

Future-facing:

- available stock;
- architects;
- quotes;
- proposals;
- construction/renovation;
- moving.

These are conceptual divisions; the final physical folder may use papers,
photos, envelopes and inserts rather than literal software tabs.

---

## 13. Visit Home: housing's manifestation layer

The home should be observable because accommodation's entire point is **how the
volis live when they are not working**.

The 3D housing scene may show:

- who is currently home;
- who is together;
- equipment being used;
- people sleeping or resting;
- somebody cooking;
- use or non-use of a common room;
- visitors moving between rooms;
- small social patterns that the schematic compresses away.

It should not become mandatory nightly surveillance.

Visiting is one instance of a broader **presence** grammar shared with attending
training, a drill, a match, a recruit meeting or a social event. There is no need
for a generic "outside mode" or a walkable overworld to justify it.

See `ABSTRACTION_AND_MANIFESTATION.md`.

---

## 14. The journal does not own housing

The journal is chronology and record:

> **What happened?**

The housing folder is the current workspace:

> **Where and how are we living, and what do we want to change?**

So:

- *Architect proposal received* may appear in the journal because it happened
  today;
- opening that entry should lead to the actual proposal in the housing folder;
- *Pāla complained about Room 4* belongs in the journal as history;
- Room 4 itself remains managed in housing.

The same distinction should hold across the desk:

| object | answers |
|---|---|
| **journal** | what happened? |
| **planner** | what is going to happen, and when? |
| **scouting board** | who might we sign, and what do we know? |
| **tactical workspace** | how are we trying to play? |
| **housing folder** | where/how are we living, and what should change? |
| **phone** | who needs me now? |
| **encyclopedia** | what is this thing/place/category? |

The journal may point to another workspace. It should not absorb that workspace.

---

## 15. Implementation restraint

Do not build a generic architecture simulator before the housing life underneath
it is visible.

Order of proof:

1. **Existing housing structures visibly change life.** Longhouse feels broad and
   communal; Row feels private; Commons actually gathers people; roommates and
   equipment produce observable behaviour.
2. **Current housing workspace** can express rooms, occupants, equipment,
   ownership/rent and present fit without a blueprint editor.
3. **Individual rental properties** can differ through condition, stock,
   installations and a small number of manager-readable facts.
4. **Architect portfolios + brief + proposal** become the construction workflow.
5. Only then test whether architect familiarity/specialisation needs more depth.

Do not author a dozen architecture ratings in anticipation of future complexity.
