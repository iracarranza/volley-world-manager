# The journal, knowledge, and the manager's working memory

The journal is the densest information object on the desk, and that is not a
failure.

It predates several specialist workspaces and has repeatedly been in danger of
becoming either of two wrong things:

- a generic dashboard wearing a stitched skin;
- a beautiful career scrapbook that the manager has no reason to open on an
  ordinary Tuesday.

This document resolves the current direction.

> **The journal is the manager's organized working record of what they currently
> know about the club, its people, its competitions and their own career.**

It can compile a great deal of information. It does **not** decide what those
facts mean, which problem deserves attention, or what the manager should do.

Specialist workspaces own specialist actions. Staff add fallible expertise.
The manager supplies diagnosis and intent.

---

## 0. Why this was reopened

The current journal grew before the desk architecture did. It contains useful
roster, club, staff and competition information, but it also accumulated old
verbs and became the navigation hub for screens that now have their own objects.

That makes current usage misleading: a player who sees the journal constantly
may be seeing it because routing sends them there, not because its information
has earned the visit.

The intended navigation home is the **desk**. The journal must remain useful
without being the door to everything else.

The problem is therefore not *how do we make the journal less important?* It is:

> **What information is genuinely stronger when organized as one persistent
> working book, and what work has earned another object?**

---

## 1. The management loop it must preserve

The journal supports the first half of management rather than completing it for
the player:

```
COMPILED INFORMATION
        ↓
READ / COMPARE / ANALYSE
        ↓
PLAYER DIAGNOSES
        ↓
SPECIALIST WORKSPACE / CONVERSATION
act, delegate, ask, change
        ↓
MATCH / TRAINING / CLUB LIFE / 3D
observe consequence
        ↓
UPDATED KNOWLEDGE
```

Do not turn the first two steps into:

> **THE GAME IDENTIFIES THE PROBLEM AND RECOMMENDS THE FIX.**

No omniscient `Current Concerns`, `Priority Actions`, `Three Problems`, composite
`Concern Score`, or automatic sentence such as *Pāla is exhausted because their
roommate keeps them awake*.

A staff member may say that. The player may write it. The neutral journal may
show the evidence.

---

## 2. Dense is allowed

A previous line of argument treated information density as suspicious because a
dashboard is dense. That is the wrong test.

A voli is a whole person across many systems. When the manager opens Pāla, they
should not need six navigation trips to reconstruct who Pāla is.

A voli page may therefore be unusually rich. Subject to what the manager
actually knows, it can include:

- name, face, age, origin and biography;
- current and estimated volleyball ability;
- known attributes, footedness/body information, traits and specialties;
- tactical roles and responsibilities;
- form, appearances and development history;
- personality and behavioural tendencies;
- wants, ambitions and role expectations;
- food preferences, preferred paste ratio, aversions and accommodations;
- allergies or perceived allergies as the club understands them;
- current housing structure, room and roommate;
- social/relationship information the club actually knows;
- contract and career information;
- staff reports;
- manager-authored notes, tabs and saved material.

> **The journal may be exhaustive about a subject. It must be selective about
> systems and actions.**

The danger is not knowing too much about Pāla on Pāla's page. The danger is one
master surface flattening every person × every system × every warning × every
action into an optimisation grid.

---

## 3. Internal subsections, one persistent subject

Because a voli has many dimensions, the answer is **clear internal subsections**,
not hiding most information in other menus merely to keep a page sparse.

Exact labels remain a UI question, but the conceptual groups are:

- **Overview** — identity, role, ability, condition, current state;
- **Volleyball** — attributes, body/footedness, traits, specialties, tactical
  roles;
- **Development** — attribute history, training emphasis, form, usage;
- **Personality / Social** — known personality, wants, relationships, relevant
  personal history;
- **Care** — food, aversions, accommodations, known medical/physical information;
- **Living** — structure, room, roommate, personal living context;
- **Reports / History** — staff interpretations and durable career record.

Do not treat those names or their count as final.

The invariant is:

> **Pāla remains Pāla while the manager changes which dimension of Pāla they are
> inspecting.**

This is the improvement over a navigation-heavy manager UI: detailed information
without repeatedly losing the subject.

---

## 4. Comparison is allowed; diagnosis is not automated

There is no hard ban on roster tables, sorting or cross-subject comparison.
That ban would protect the book metaphor by making the manager worse at managing.

A roster can reasonably show a compact set of shared facts such as:

| voli | position | condition | appearances |
|---|---|---:|---:|
| Pāla | OP | 41 | 8 |
| Iri | S | 82 | 9 |
| Vem | MB | 54 | 7 |

The player can notice Pāla.

What the journal should not do is add:

| voli | concern | likely cause | recommended action |
|---|---:|---|---|
| Pāla | HIGH | housing + workload | REST |

The useful boundary is not **table / no table**. It is:

> **The interface may compile factual source material. The player or a fallible
> person interprets what deserves attention, why it is happening, and what to do.**

Domain-specific analysis should still live with its domain. `Who has played the
fewest minutes?` can be a roster/season query. `Whose receive has deteriorated
against float serves in rotation 5?` belongs in volleyball analysis even though
it can be calculated as a fact.

The journal should be powerful reference, not the universally best answer to
every query.

---

## 5. Four information layers

Use these when deciding what the journal may state in its own voice.

### 5.1 Direct fact

Stored or directly simulated state the manager currently knows.

Examples:

- Room 3;
- condition 41;
- eight appearances;
- current training emphasis;
- contract ends after Week 30;
- Pāla told the club they avoid a particular paste.

Safe to compile.

### 5.2 Derived fact

A deterministic description of known evidence that does not assert cause or
recommended action.

Examples:

- appearances over the last five matches;
- attribute change across an observed period;
- days since last start;
- reception attempts per match.

Potentially safe. It should be clear what evidence produced it, and specialist
analysis should not be moved into the journal merely because a calculation can
be made.

### 5.3 Judgment

A conclusion dependent on expertise, uncertainty or interpretation.

Examples:

- *Pāla's fatigue pattern worries me*;
- *their development has plateaued*;
- *this recruit would suit our system*;
- *this architect is a poor fit for the brief*.

The player can conclude it. A staff member can report it and be wrong. The
neutral journal should not assert it omnisciently.

### 5.4 Recommendation

A proposed decision:

- rest Pāla;
- drop Vem;
- sign this setter;
- change the paste;
- build a Commons.

Never the journal's neutral voice. It can be a player-authored note or a named
person's advice.

---

## 6. The journal shows knowledge, not simulation truth

This is the most important constraint on its density.

> **Exhaustive means exhaustive to what the manager should currently KNOW, not
> exhaustive to hidden simulation state.**

An unknown attribute remains unknown. An estimate remains an estimate. A
perceived allergy remains a perceived allergy unless the club has learned
otherwise. A personality inference is not magically upgraded to objective truth
because the underlying object has a personality value.

The journal is therefore a visible surface for the game's broader knowledge
model.

It is not the database.

---

## 7. Where knowledge comes from

A new manager taking over an existing club should not receive either extreme:

- complete amnesia about everybody already employed;
- the previous manager's private omniscient dossier.

Knowledge has provenance.

### 7.1 Institutional / club record

Information the organisation reasonably preserves:

- identity and contract;
- match and training history;
- housing assignment;
- formal role/responsibility;
- recorded care accommodations;
- known medical arrangements;
- competition/career record;
- other explicit administrative facts.

A new manager inherits this immediately.

### 7.2 Staff knowledge

Things current staff have learned through continuity:

- development impressions;
- physical patterns;
- recurring habits;
- food/care knowledge;
- observed behavioural tendencies;
- interpretations of what has been happening.

This is not automatically equivalent to truth. It should eventually have an
owner, just as scouting beliefs need an owner. A long-serving assistant and a
new assistant should not transfer identical understanding.

### 7.3 Personally disclosed / manager-specific knowledge

Things a voli told the previous manager privately, a hypothesis the old manager
made, or a personal note they wrote are not automatically inherited.

The previous manager's personal scrapbook does **not** become yours.

### 7.4 Observed and inferred knowledge

The club may learn things because somebody repeatedly behaves a certain way.
Observation can justify knowledge without a formal interview, but the transition
must have a cause in simulated contact rather than `Week 12: trait unlocked`.

Repeated ordinary contact itself can be the cause. Not every new fact needs a
cutscene. What matters is that knowledge was earned through living, working,
reports or conversation rather than leaked from hidden state.

### 7.5 Private / undiscovered

Some information can remain unknown indefinitely.

There is no requirement that every generated preference or personality detail be
completed like a collection. If it never matters, is never disclosed and is
never observed clearly enough, the manager may never know it.

---

## 8. Personality, wants, needs, food and housing are real voli information

Do not reduce a voli page to volleyball attributes plus flavour text.

The whole point of the club-life model is that a voli is simultaneously:

- an athlete;
- a personality;
- somebody with wants and expectations;
- somebody who eats;
- somebody with allergies, aversions or beliefs about what they can eat;
- somebody who sleeps somewhere and has a roommate;
- somebody with relationships;
- somebody with a career and history.

### What is known by default?

Not all personality and preference information should be known as an objective
given.

Use the provenance in §7:

- explicit preferences/needs may be known because they were disclosed or
  formally recorded;
- repeated tendencies may be known because the club has observed them;
- interpretive personality descriptions may remain uncertain;
- private facts may remain unknown.

A manager taking over a club should often know **more about existing volis than a
cold scout would**, because an institution already lives with them, but less than
the previous manager personally knew.

---

## 9. The interview is a knowledge event

`RECRUITMENT_AND_THE_OFFER.md` remains authoritative for the recruitment flow.
The additional journal/knowledge consequence is:

> **An interview is one of the clearest ways the club acquires personal knowledge
> before a signing.**

Topics such as:

- ambition;
- expected role;
- playing time;
- food needs;
- claimed allergies or aversions;
- housing preferences;
- willingness to share/live communally;
- concerns about moving;
- why they are leaving;

may become known because the voli actually discussed them.

The interview should not expose hidden variables. Volis speak, omit, simplify,
misunderstand themselves and sometimes change their minds.

Skipping the interview therefore has a real information consequence without
requiring an arbitrary penalty: the club may simply know less when the signing
arrives.

---

## 10. Learning somebody after they join

There must be routes other than the recruitment interview, especially when the
manager takes over an existing club.

Possible sources:

- ordinary contact over time;
- staff reports;
- free-time behaviour;
- training behaviour;
- housing behaviour;
- food/care issues becoming relevant;
- relationship events;
- a voli requesting something;
- direct conversation;
- a contextual phone call.

Avoid a menu shaped like:

```
CALL PĀLA
[ Ask personality ]
[ Ask food preference ]
[ Ask hidden trait ]
```

Instead the manager calls about a real subject:

- the new Commons;
- their role;
- how training is going;
- food;
- a concern they raised;
- their contract;
- something that happened.

Their answer may reveal more than the literal topic.

> **Learning a voli should feel like learning a person, not querying a database.**

---

## 11. Staff: facts, reports, interpretation

The journal's Staff section has two legitimate jobs:

1. **directory/reference** — who works here, what they do, their known qualities
   and responsibilities;
2. **report ownership** — a stable place to find the reports and opinions that
   particular staff members have produced.

That does not mean staff own every fact in their domain.

### Physio / care example

The roster can show ordinary known physical state such as condition and known
availability.

A physio report can add:

- whether a pattern is concerning;
- likely cause;
- recurrence risk;
- specialist measurements;
- whether two similar condition values should be treated differently.

### Assistant / development example

A voli's Development section can show observed attribute growth, usage and
training emphasis.

The assistant can say:

> *Their reception work is translating, but I think their attack development has
> plateaued.*

The data belongs to the manager's knowledge. The explanation belongs to expertise.

> **Good staff save inspection and interpretation time; they do not gate ordinary
> facts the manager could otherwise inspect.**

Scouting is a partial exception because uncertainty and knowledge acquisition are
literally the scout's simulation domain.

---

## 12. Reference may overlap; specialist verbs may not

A system gaining a workspace does not require its facts to disappear from the
journal.

Valid overlap:

- Journal: `Room — 3, roommate Iri`
- Housing folder: **move room / change equipment / inspect topology**

- Journal: `Training emphasis — receive`
- Training clipboard: **construct / assign / demonstrate training**

- Journal: `Current competition / next fixture / results`
- Match centre: **observe and intervene in the match**

The rule:

> **A section may remain represented after its system graduates. Its specialist
> verbs do not remain duplicated.**

This is why old journal actions such as unilateral signing, training controls,
housing/food controls or match-play controls are design debt once their proper
workspaces exist.

---

## 13. Staff, roster, club and competition can remain journal-shaped

Do not create generic `ROSTER`, `STAFF`, `CLUB`, `COMPETITIONS` screens merely
because the journal is becoming more disciplined.

A system earns a separate object through a distinct managerial verb and
information topology, not through data volume.

Likely strong journal residents:

- roster index and voli pages;
- staff directory and staff reports;
- competition/Sixnet standings, brackets, fixtures and season record;
- current club reference information;
- inbox/correspondence record;
- career/history reference.

Scouting is different because arranging uncertain external subjects is itself
the work. Housing is different because assigning the current home and
commissioning a future one are their own work. Training is different because the
manager constructs and communicates training/tactical intent.

---

## 14. The journal is structured first, scrapbooked second

Do not destroy a working manager UI in order to prove the object is handmade.

The base layer remains:

- organized;
- stable;
- information-dense;
- easy to navigate;
- internally sectioned;
- predictable enough that key facts remain spatially familiar while the manager
  moves between volis.

The scrapbook layer records **the manager's attention, intent and taste** around
that structure.

### Functional craft

- tabs;
- bookmarks;
- sticky notes;
- margin marks;
- saved references.

### Expressive craft

- tape;
- stickers;
- doodles;
- photos;
- clippings;
- mementos;
- wear and repair.

The first group may improve retrieval. The second may mean nothing mechanically.
That is allowed.

---

## 15. Tabs and bookmarks are personalized navigation

A tab means:

> **I keep coming back to this.**

Possible targets include:

- a favorite/developing voli;
- a staff member;
- a competition;
- a current club section;
- any journal page that matters to this manager.

A clean popup listing **Tabbed pages** is allowed and probably desirable. It does
not need to simulate physically searching every tab.

The physical mark carries the meaning; the popup preserves usability.

Different managers should naturally create different working books without a
playstyle selector.

---

## 16. Sticky notes can attach beyond the journal

Sticky notes are a cross-desk expression of **player-authored working memory**.

Examples:

- on Pāla's page: `rest before cup`;
- on the scouting board: `cheap backup setter — serve first`;
- on Housing: `ask Iri before moving Room 3`;
- on Training: `test this rotation vs Rhen`;
- on the planner: `friendly here?`.

This directly solves a common manager-game failure: the human manager forms a
plan, changes screens, and has to reconstruct why they were there.

The game should not generate these notes on the player's behalf. They are where
**the player's diagnosis** can live.

### Self-inflicted obstruction is acceptable

A note the player chose to place may cover something. That can make the desk feel
used rather than pristine.

But player-created clutter cannot make the interface unrecoverable:

- notes can be dragged;
- a temporary hide/fade-all gesture may exist;
- a simple Notes popup can list every note and what it is attached to.

Again, the recovery interface does not need skeuomorphic ceremony.

---

## 17. Phone, inbox and the value of arriving information

A bad inbox turns every simulated development into equal administrative debt.
The problem is not that information arrives. It is that low-value information
can demand the same attention ritual as something meaningful.

### Phone

The phone is:

- person-to-person;
- synchronous or missed;
- conversational;
- contextual;
- interruptive when appropriate;
- capable of revealing uncertainty, personality and judgment.

It is also a legitimate way to contact a voli or staff member about a real
subject and learn more through the response.

### Inbox / journal correspondence

Correspondence is:

- durable;
- asynchronous;
- formal or substantive;
- worth retaining.

Examples:

- league ruling;
- competition draw;
- contract document;
- substantive staff report;
- scout report that genuinely changed knowledge;
- match report;
- meaningful award/recognition.

### Routine facts should often file themselves

Not every new fact deserves `+1` and a clearing ritual.

A useful attention ladder:

1. **automatic record update** — no interruption;
2. **filed new information** — available, perhaps a gentle marker;
3. **correspondence** — genuinely worth opening;
4. **needs response** — clear obligation;
5. **phone/interruption** — a person or situation needs the manager now.

Routine weekly scouting should not manufacture messages when knowledge did not
meaningfully change.

> **Presentation cost should scale with information value and required response.**

---

## 18. Match reports: compact evidence, optional depth

The report should not be a large prose box occupying attention because a match
occurred.

A useful durable report contains:

- score and sets;
- lineup/usage;
- important statistics;
- notable volleyball patterns at the appropriate summary level;
- meaningful recognition such as Player of the Match, debut, injury or
  milestone.

Detailed rally/tactical evidence remains in the Match Centre.

Recognition should feel rewarding rather than like another unread notification
the player must clear.

---

## 19. Career history: archive is automatic, meaning is curated

A pure history journal is too weak as the working object, but career continuity
still explains why this particular object is handmade and personal.

Separate:

### Working journal

Current knowledge and current reference. Used routinely.

### Automatic career archive

The game preserves the career reliably:

- every club;
- seasons;
- competition records;
- roster history;
- career statistics;
- major institutional events.

The player should not lose history because they failed to scrapbook it.

### Curated memory

The player chooses which people, matches, staff, objects, photographs or moments
deserve special prominence — a Hall-of-Fame-like layer without requiring a
literal Hall of Fame.

> **Archive = what happened. Curated memory = what mattered to this manager.**

---

## 20. The office-bedroom is the larger scrapbook

Do not make the journal carry every historical object.

The manager lives in an **office-bedroom**. Its physical state can express career
memory at a scale the journal cannot.

Possible surfaces:

- framed or taped achievements on a wall;
- one or two photographs rather than a collage on every journal page;
- shelves/objects from important moments;
- art materials and ordinary desk clutter;
- boxes containing archived material.

Different clubs can have different offices:

- size;
- architecture;
- wealth;
- age;
- regional materials;
- window/view;
- furniture;
- degree of institutional prestige or shabbiness.

Do not formalize a `WALL SYSTEM` merely because the wall is visible. It is part
of inhabiting the manager's room.

---

## 21. Changing clubs should be seen

A major job change should not be only:

```
ACCEPT JOB → LOADING → NEW CLUB
```

After a long tenure, leaving should have some amount of visual fanfare because
an inhabited space is being abandoned.

The exact sequence is open, but the target experience includes some combination
of:

- seeing the old office-bedroom one last time;
- packing or watching it be packed;
- deciding which keepsakes remain immediately prominent;
- automatic archival of the career state;
- arriving at a visually different new office-bedroom;
- boxes on the floor;
- the same personal working journal;
- most importantly, **seeing the blank wall / uninhabited new room**.

The blankness is the point. The player has history, but this place does not yet
look like theirs.

Packing should not become a forty-item inventory chore. Important history is
safe automatically; curation is expression.

---

## 22. Takeover knowledge and the blank journal problem

A new job is not a new game-state amnesia event.

On arrival:

- institutional records already populate factual sections;
- staff who remain can contribute their existing beliefs/reports;
- some personality/preferences are known because they have been repeatedly
  relevant to club life;
- some remain uncertain;
- previous-manager-only notes and private conversations do not transfer;
- the new manager begins creating their own tabs, notes and personal history.

This means an established club can feel **known institutionally but unfamiliar
personally**.

That is the correct tension for taking over somebody else's team.

---

## 23. Current implementation implications — design debt, not this pass

This document does not request code changes, but it resolves how to evaluate
legacy journal behavior.

The current journal has historically contained actions such as:

- direct transfer signing;
- training controls;
- accommodation/food controls;
- play/simulate match controls;
- launchers to specialist screens.

As the desk and specialist workspaces become authoritative, those actions should
be reviewed under §12.

Likewise, specialist screens returning to the journal make it impossible to
measure whether the journal earns voluntary use. The **desk is the intended home
state**; the journal should be one object on it.

Do not treat this paragraph as a priority override. Volleyball fidelity remains
the primary project track unless `BACKLOG.md` changes it.

---

## 24. Open questions

The identity is settled more strongly than the exact UI.

Still open:

1. exact voli subsections and which facts remain visible while switching them;
2. which roster fields deserve direct cross-subject sorting/filtering;
3. which derived facts belong in a general voli record versus domain analysis;
4. the threshold by which ordinary familiarity turns a preference/personality
   inference into recorded knowledge;
5. how staff-owned beliefs transfer when staff leave or join;
6. how uncertainty is visually expressed across personality/care/social facts;
7. exact inbox attention states and whether `unread` should exist separately from
   `needs response`;
8. the limits and interaction cost of freeform sticky notes;
9. the precise leaving/arrival sequence for a job change;
10. what qualifies for automatic wall display versus player-curated display.

These should be resolved from concrete screens and simulated cases rather than
from a desire for one universal rule.

---

## 25. The compact rules

> **The journal shows what the manager knows, not what the simulation knows.**

> **It may be dense about a subject; it may not become an omniscient problem
> list.**

> **Facts can be compiled. Judgments belong to the player or a fallible person.**

> **Reference may overlap a specialist workspace. Specialist verbs should not.**

> **Staff save time and add expertise; they do not gate ordinary club facts.**

> **The interview, observation, reports and conversation are ways of learning a
> person. Unknown information may stay unknown.**

> **Tabs and notes record the manager's attention and intent. Scrapbooking must
> not make the working interface worse.**

> **Archive what happened automatically. Let the player choose what mattered.**
