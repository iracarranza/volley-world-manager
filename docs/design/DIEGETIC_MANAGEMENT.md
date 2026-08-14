# Diegetic management

The cross-cutting argument the other design docs assume. What the interface is
*for*, which object each system lives on, and the rule that decides whether a
thing becomes an interaction or stays a number.

This is a principles document. The systems are elsewhere:
`THE_DAY_AND_THE_CLOCK.md`, `RECRUITMENT_AND_THE_OFFER.md`,
`STAFF_AND_FALLIBILITY.md`, `ACCOMMODATIONS_AND_CARE.md`,
`THE_DESK_AND_THE_PHONE.md`.

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

## 10. The rule that decides an argument

When something could be a number or an interaction, ask which of these it is:

1. Would a manager do it **once and mean it**, or **repeatedly and resent it**?
2. Can it be shown as **somebody doing something** instead of a modifier?
3. Does it deviate from routine? Deviation earns presentation.
4. Is it a **physical fact** (show the number) or a **judgment about a person**
   (say the sentence)? — see `RECRUITMENT_AND_THE_OFFER.md` §2.1.

> Physicalize decisions. Automate maintenance. Make routine inexpensive. Make
> deviations meaningful.
