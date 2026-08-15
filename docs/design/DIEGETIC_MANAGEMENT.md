# Diegetic management

The cross-cutting argument the other design docs assume. What the interface is
*for*, which object each system lives on, and the rule that decides whether a
thing becomes an interaction or stays a number.

This is a principles document. The systems are elsewhere:
`THE_DAY_AND_THE_CLOCK.md`, `RECRUITMENT_AND_THE_OFFER.md`,
`STAFF_AND_FALLIBILITY.md`, `CONTRACTORS_AND_SERVICES.md`,
`ACCOMMODATIONS_AND_CARE.md`, `HOUSING_WORKSPACE_AND_ARCHITECTURE.md`,
`ABSTRACTION_AND_MANIFESTATION.md`, `THE_DESK_AND_THE_PHONE.md`.

---

## 0. The problem

Deep simulators tend toward one loop:

> inspect data → decide → advance time, repeatedly → reach match → repeat

The simulation is the point of this game, and the simulation is not the problem.
The problem is that **managing** becomes reading tables and pressing Continue,
and the only thing that feels like play is the match.

The fix is not to add decisions. It is that the club keeps living, the manager
chooses where to look, and the looking is done through objects rather than
through one menu language wearing different headings.

Avoid: one generic menu grammar for every system; opening statistical screens
repeatedly; clicking through uneventful days; turning every simulation value
into a meter; waiting for a match to reach "real gameplay".

---

## 0a. Management with presence

The target is not *Football Manager, but cozy*. It is a **deep simulator whose
management is experienced at human scale** — the player runs a complicated
institution without feeling detached from it.

Six things together, and the combination is the point rather than any one of
them:

| | |
|---|---|
| **simulation depth** | the variables genuinely interact |
| **materiality** | changes show up in places, objects and behaviour |
| **character** | the things being managed become recognisable individuals |
| **routine** | the player inhabits the job instead of teleporting between decisions |
| **playfulness** | not every interaction exists to optimise an output |
| **role fantasy** | the interface keeps saying *I am this club's manager* |

### The trade we are refusing

Cozy management games often buy their accessibility by **reducing simulation
depth**. VWM must not.

Instead: keep an unusually deep model and make its causes and consequences
understandable through people, places, behaviour, physical interfaces and
recurring routine.

> The simulator player can inspect the causal model.
> The cozy player can understand much of the same model by watching what
> happens.
> **They are not playing two different games.**

`CLUB_LIFE.md` §0 has the other half of this argument — the two audiences do not
conflict on *depth*, they conflict on *failure*, and the resolution there
(failure is legible and gentle; cozy systems must be expressive rather than
optimal) is what makes one system serve both.

---

## 0b. The reference family

A lens, not a feature list. What each is useful for *studying*:

| | useful for |
|---|---|
| **Football Manager** | deep sporting simulation and tactical/player causality — and the monotony we are explicitly not inheriting: inspect → advance → advance → match |
| **Kairosoft sports** (Tennis Club Story, Basketball Club Story) | sports-management concepts compressed into charming, visible progression. Borrow the legibility and the charm, **not** the stat-upgrade abstraction |
| **Moonlighter** | alternating loops keep one activity from eating the whole game |
| **Dave the Diver** | loop variety attached to the same place, cast and world |
| **Software Inc.** | people plus workplace plus organisation, at real systemic depth |
| **Stardew Valley** | routine, familiarity, attachment to an inhabited place |
| **Potionomics / Recettear** | business decisions become interpersonal and expressive rather than only economic |
| **Travellers Rest / Bear & Breakfast** | the managed institution is also a physical place |
| **Sticky Business / A Little to the Left / Cooking Mama** | mundane organisation is pleasurable when the interaction itself is tangible |
| **Mii Plaza** | simple generated characters become memorable through repeated, recognisable identity |

The shared lesson, and the only thing to take from the list as a whole:

> **Managing something should feel like being somewhere and knowing the things
> you manage.**

---

## 0c. Two loops, not one

The anti-monotony structure is not one large management loop that occasionally
reaches a match. It oscillates:

```
        CLUB LIFE                         VOLLEYBALL
  people · training · housing   ↕   matches · tactical problems
  food · recruitment · staff        performance · execution
  planning · relationships
  routine                       ↕
```

A match should produce **management questions**. Management should change what
the next match **means**.

Worked example:

> A match exposes an opposite being hunted in reception. The manager can train
> them, protect them tactically, recruit around them, or change the system —
> and meanwhile that voli is also a person in the club with a roommate and a
> palate and an opinion. The next match tests whichever answer was chosen.

Avoid the rhythm where management is a long stretch of screens punctuated by a
match. The two sides should keep handing work to each other, which is also why
the calendar (§7) matters more than a fixture list would.

---

## 1. The interaction rule

> **Physicalize decisions. Automate maintenance.**

| decision — make it physical | maintenance — automate it |
|---|---|
| putting a recruit in a room: occupants, floor, equipment, roommate, the conflict | making the beds |
| changing the club's regular paste ratio | cooking each meal |
| pinning and comparing prospects | re-pinning unchanged reports weekly |
| painting the week's schedule | starting each scheduled block |

The test: *would a manager do this once and mean it, or every day and resent
it?* The first is an interface. The second is a chore wearing one.

---

## 2. Behaviour beats modifiers

Numbers may exist underneath. What the player *sees* should usually be somebody
doing something.

| instead of | prefer |
|---|---|
| Landline: homesickness −12% | a homesick voli calls home |
| Console: morale +5 | the roommates play it together |
| Longhouse: cohesion +8 | communal behaviour actually happens |
| Paste ratio changed: satisfaction −6% | volis eat differently, recover differently, mention it |

This has a concrete target today. `Accommodation.SMALL_EQUIPMENT` and
`LARGE_EQUIPMENT` each declare what they `answer` and what they `cost`, and
**nothing dispatches on those strings**. They are not waiting for a modifier to
be wired — they are waiting for a **behaviour**, and free time is where it
happens (`THE_DAY_AND_THE_CLOCK.md` §8).

---

## 3. The club should be interesting when nothing is wrong

The time between matches must not be made interesting by spawning problems.
Mundane life is feedback:

roommates on the console · somebody calling home · a voli sitting somewhere
unusual · people eating together · somebody studying · weights being used ·
staff leaving early for the snail racing · a friendship forming · a room slowly
filling with objects that mean something

None of these needs a decision. They tell the player **what kind of club they
have built**, which is the thing a dashboard can never say.

---

## 4. One object per activity

The desk is objects, not tabs. `CLAUDE.md`'s medium table is the visual half of
this; the verbs are the functional half.

| object | verbs | note |
|---|---|---|
| **journal** — the club | read, review, reference | persistent, formal. Do **not** default new systems into it because it has tabs |
| **scouting board** — cork | pin, mark, arrange, compare | an imperfect-knowledge workspace. Not the signing interface |
| **tactical whiteboard** | arrange, draw, assign | where tactical ideas become spatial. The match viewer answers whether they happened |
| **housing folder** — manila | inspect, compare, assign, purchase | expose the physical consequences, never collapse to a Housing Quality rating |
| **kitchen** | ? | the simulation is strong and the verbs are the least settled thing here — see §5 |
| **planner** — the day | paint, resize, copy | already a painted strip; keep it |
| **phone** | answer, ignore, call, replay | synchronous. Ringing means *now*, not *important* |
| **encyclopedia** | browse | reference. Do not hang active management on it |
| **match centre** | observe, intervene | where every prior decision becomes visible |

### 4.1 Two standing corrections

**Don't force new systems into the journal.** It has tabs, so everything fits,
which is exactly why it is the wrong default.

**The board's marks are annotations.** `MARK_SIGN` / `MARK_WATCH` / `MARK_PASS`
are verdicts pinned to a card, not buttons that do things. When a real action
landed beside them they stopped reading as annotations, and the fix was three
presentational changes rather than a redesign — see
`RECRUITMENT_AND_THE_OFFER.md` §5.

### 4.2 Record, workspace, presence

A useful boundary now exists across the desk.

The **journal is chronology**. It answers:

> **What happened?**

Other objects own the active state of their subject:

| object | answers |
|---|---|
| **planner** | what is going to happen, and when? |
| **scouting board** | who might we sign, and what do we know? |
| **tactical workspace** | how are we trying to play? |
| **housing folder** | where/how are we living, and what should change? |
| **phone** | who needs me now? |
| **encyclopedia** | what is this thing/place/category? |

A journal entry may point to another workspace without becoming that workspace.
*Architect proposal received* belongs in today's record; the proposal itself
belongs in the housing folder. *Scout report received* is history; the current
prospect belongs on the scouting board.

There is a second boundary as well: the desk works with **representations** of
things. Sometimes the manager can be physically present for the thing itself —
attend a drill, attend a match, visit the current home, meet a recruit. Presence
is not an overworld and does not replace the workspace.

See `ABSTRACTION_AND_MANIFESTATION.md` for the 2D/3D form of this distinction.

---

## 5. The kitchen is the weakest interaction over the strongest simulation

Underneath: blocks, pastes, ratios, nutrition, comfort bands, regional
familiarity, chef approximation, palate fatigue, supply lines and their
reliability — and allergies designed and waiting.

Above: verbs that are not yet settled. What is wanted is an interface that helps
the manager *understand and alter what the club actually eats* without inventing
a cooking chore. §1's test applies hard here: choosing the club's regular
mixture is a decision; producing each meal is maintenance.

---

## 6. The match viewer explains rather than animates

Every management decision becomes visible in a rally. The viewer's job is not to
show that something happened but **why** — responsibility, cognition, body
position, tactical legibility, cause and effect. A viewer that animates outcomes
is a replay; one that explains them is the argument for having a simulation this
detailed at all.

`ABSTRACTION_AND_MANIFESTATION.md` now makes the general rule explicit: the 2D
view is the manager's compressed, actionable representation; the 3D court view is
an observational manifestation used to understand what that representation
became. The same relation should govern drills and housing without making those
interfaces look alike.

---

## 7. The calendar is the backbone

The most underdeveloped interface relative to its importance. It is not a list
of fixtures — it is the interface through which the player understands what is
happening now, what is supposed to happen next, how much time is left, what has
already happened, and what can still be changed. It sets the context the whole
simulation runs in.

`THE_DAY_AND_THE_CLOCK.md` is that document.

---

## 8. Routine cheap, exceptions interesting

The single scheduling principle, and it generalises past scheduling:

> The more something deviates from established routine, the more presentation it
> deserves.

Ordinary breakfast: simulation. Midnight picnic: worth watching. Normal
training: delegable. Emergency pre-match session: worth your attention. Roommates
on the console: ambient. A serious argument during free time: an interruption.

---

## 9. What the player should be able to do

Inhabit an ordinary club day in detail if they want to. Watch small things
happen. Answer people. Work physical interfaces. Make real choices all week.

**And** skip a quiet Tuesday, delegate the ordinary work, and not process every
phase by hand.

Depth available without becoming mandatory friction.

---

## 9a. The first save

Where the whole argument above either lands or does not. The schedule-specific
half is in `THE_DAY_AND_THE_CLOCK.md` §12; the New Career → first day handoff is
in `TITLE_SCREEN.md`. This is the philosophy.

### The club already works

> **A first-time player must not be required to configure every system before
> being allowed to play.**

A new save arrives with sensible but **imperfect** defaults already in place:
a roster, room assignments, a food mixture, staff, basic tactics, a weekly and
daily schedule, an upcoming fixture, some equipment.

The player begins from a **functioning institution**, not from a blank form.
Imperfect matters as much as functioning — a club with nothing wrong with it
gives the player nothing to be for.

> Depth available immediately. Very little depth *mandatory* immediately.

### Same save, two first impressions

The same starting club, read two ways, with no mode switch and no difficulty
setting.

| a cozy-leaning player first notices | a simulator-leaning player first notices |
|---|---|
| names, faces, bodies | weak serve receive |
| roommates, rooms, objects | roster construction, rotation |
| phone calls, meals, routines | attributes, tactical principles |
| who spends time with whom | training, scouting, the schedule |
| **"these people actually live here"** | **"this roster has problems I can solve"** |

**Do not solve this with a Cozy Mode and a Simulator Mode.** The systems are the
same systems; only the entry point differs. The convergence being aimed at is a
single realisation that arrives from either side:

> **"These particular people *are* the system I am trying to solve."**

### The first day is observational

No tutorial choreography — no *open the food screen, now open housing, now open
scouting*. The existing schedule runs and the first lesson is:

> **the club functions when I am not clicking things.**

A cozy player might learn who wakes late, who eats with whom, who uses which
object. A simulator player might attend training, find the tactical problem,
delegate a session, or change tomorrow. Both are correct and neither is
prompted.

Teach through curiosity, consequence and need. Not through a syllabus.

### By day three, and by the end of week one

Several volis should be recognisable **without the roster list**, and their
identities should be arriving from both directions at once:

> *the libero who keeps calling home* · *the opposite I don't trust in
> reception* · *those two are roommates* · *the setter I'm trying to make more
> aggressive*

The first meaningful match should come early. The opening arc:

```
meet the club → notice problems → make small changes → watch people live
   and train → MATCH → see what those changes did
```

and the match reads at two depths as well — consequences, fatigue and reactions
on one side; tactical evidence, patterns and analysis on the other. Same event.

By the end of week one the player should understand the **shape** of VWM
without having met every mechanic. So week one must **not** be made to contain
everything: no mandatory allergy, staff catastrophe, housing crisis, transfer
saga or rare-trait showcase. Those are what make weeks two, ten and forty
distinct from each other, and spending them on the tutorial spends them for
good.

---

## 10. The rule that decides an argument

When something could be a number or an interaction, ask which of these it is:

1. Would a manager do it **once and mean it**, or **repeatedly and resent it**?
2. Can it be shown as **somebody doing something** instead of a modifier?
3. Does it deviate from routine? Deviation earns presentation.
4. Is it a **physical fact** (show the number) or a **judgment about a person**
   (say the sentence)? — see `RECRUITMENT_AND_THE_OFFER.md` §2.1.

> Physicalize decisions. Automate maintenance. Make routine inexpensive. Make
> deviations meaningful.
