# The day and the clock

How time works: what the club does while the manager is not looking, what the
manager spends when they *are*, and why the player is allowed to think for as
long as they like.

Status: **the plan exists, the clock does not.** `DailySchedule` and
`DailyScheduleSystem` are built and priced. `career.day_of_week` and
`advance_day()` are built. Nothing advances *within* a day. This document is
what to build and, more usefully, the four decisions to get right before
building it.

**Not the current build priority.** `docs/BACKLOG.md` puts volleyball fidelity
first and holds the clock. The order in §11 is the order *within this system*
for whenever it is picked up — it is not a claim about what to build next, and
§11 is the section most likely to be misread as one.

---

## 0. The problem this is against

The monotony common to deep simulators:

> inspect data → make decisions → advance time repeatedly → reach match → repeat

The fix is not more decisions per unit of time. It is that the club keeps
living whether or not the manager is watching, and the manager chooses where to
look. `DIEGETIC_MANAGEMENT.md` is the wider version of that argument; this
document is the machinery.

Two failure modes, and the second is the one a fine-grained clock invites:

- **Football Manager's.** Read screens, press Continue, wait for a match.
- **Ours, if we are careless.** Approve breakfast. Approve training. Approve
  lunch. Approve free time. The same monotony at a finer grain, which is worse
  because it is dressed as depth.

---

## 1. The unit is the block, and hours are presentation

**This is the single most important decision here and it is already made.**

`daily_schedule.gd` defines a day as **36 blocks of 40 minutes**, and says so in
its own header:

> Nothing in the model reads hours; the conversion exists for the one label that
> shows them.

Every brief about the clock is naturally written in hours — *07:00 Wake, 08:00
Meal*. Building it that way would put a second authoritative time unit beside
the one that the training budget, the recovery model, the meal count and the
deviation pricing all already use, and every boundary between them becomes a
conversion waiting to be wrong.

So:

| | unit |
|---|---|
| the clock's position | block index, 0..35 |
| scheduling, pricing, recovery, training budget, deviation | block index |
| anything drawn for a human | `DailySchedule.clock_label(index)` |

`clock_label` is the conversion boundary and should stay the only one.

---

## 2. Live clock, pause, speed, skip

The club needs continuous time. The **player** does not need time pressure.

```
PAUSED   1x   2x   4x        SKIP TO ...
```

Skip-to targets are the things a manager actually means: the next block, the
next meal, the next training, the evening, tomorrow, the next fixture.

**Skipping is skipping observation, not simulation.** Everything between here
and there resolves. That sentence is easy to write and has one trap, below.

### 2.1 The trap: a skip that stops for everything is a skip nobody uses

`THE_DESK_AND_THE_PHONE.md` wants phone calls to be *ordinary* — an average week
holds several, most of them not important. If fast-forward halts on each one,
"skip to tomorrow" stops four times and the player learns to distrust the
button, which is worse than either extreme.

The fix is not fewer events. **A skip declares what it will stop for, and a
longer skip has a narrower filter.**

| skip | stops for |
|---|---|
| next block | anything |
| next meal / next training | anything that cannot be reviewed later |
| tomorrow / next fixture | only what expires unheard |

---

## 3. Four things to get right before writing the tick

These are cheap now and expensive later.

### 3.1 Events are derived, never rolled

Everything in this world is derived rather than rolled, and the reason is stated
in the food system: `PasteRatio.approximated` is deterministic in the week so
that *a manager who reloads a save is not rerolling their dinner*.
`Larder.produces` derives from region and season. Scouting estimates salt by
player and attribute.

A clock that generates events as it ticks is the first system that could break
this, because a player can pause, save, reload and re-run the same minute. So a
spontaneous event resolves from a stable key:

```
(week, day, block, subject, event_type)
```

Same rule the rest of the world already obeys, applied to time.

### 3.2 The clock ticks in memory

`CareerManager` calls `save_career()` on essentially every mutation — that is
correct for a week-grained game and catastrophic for a block-grained one, which
would write the save 36 times a day. The clock advances in memory; saves happen
at day boundaries and at manager actions.

### 3.3 Interruption is a property of the event, not a setting

Four presentation levels are worth *designing* immediately and worth *exposing*
slowly:

| level | behaviour |
|---|---|
| ambient | happens; nothing is raised |
| noteworthy | reviewable later |
| attention | a visible indicator; time continues |
| interrupt | stops fast-forward, because the decision expires |

Build the contract with all four. Drive only two at first — ambient and
stop-fast-forward — and no preferences screen until there is something to
prefer. The expensive thing to retrofit is the contract; which behaviours it
currently drives is cheap.

### 3.4 No real-time reaction, ever

"Immediate" means *this must be resolved now in simulated time*. It never means
*you personally have six seconds to read four options*. The scarce resource is
the fictional manager's time, not the player's reflexes. This is an
accessibility rule and a genre rule at once.

---

## 4. The schedule is intent; the simulation resolves behaviour

A day that says SLEEP until block 12 means *the club expects to be up around
then*. It does not mean twelve volis change state simultaneously. Some wake
early, some late, some do not get up.

**This needs no new model.** `DailySchedule` already carries a per-voli personal
schedule, and `DailyScheduleSystem` already prices how far it sits from the
club's:

```
deviation_from()
DEVIATION_TOLERANCE_BLOCKS   -- one or two blocks is a rehab slot, not a rebellion
INDIVIDUAL_SCHEDULE_TOLERANCE -- how much of the roster can run its own day
COHESION_FRACTURE_PENALTY
```

That machinery exists to price *authored* individual exceptions. Compliance is
the same quantity **produced by the simulation instead of authored by the
manager**. So the personal schedule takes on a second role:

| role | who writes it |
|---|---|
| expected individual exception | the manager |
| what the voli actually did | the simulation |

and the already-calibrated deviation pricing reads both. This is much cleaner
than a separate attendance subsystem, and it means the cost of a squad drifting
out of step is a number that has already been tuned once.

---

## 5. Day identity and templates

Two levels, and they are not the same level.

**Day identity** — Training Day, Match Day, Rest Day, Media Day, Travel Day — is
a *template*, a convenience for stamping out a normal day. It does not replace
the schedule and nothing in the simulation should branch on it.

**The hourly schedule** — the 36 blocks — is the structure the simulation
actually reads.

Meals are the test case. Meal *timing* matters to the simulation: energy,
recovery, mood, social opportunity, training readiness, how late the evening
runs. But no player should repaint breakfast every week. So meals are **explicit
to the simulation and implicit to the player's workload**, which is exactly what
a template is for.

> Routine should be cheap. Deviations should be interesting.

---

## 6. The planner is already the right kind of object

`schedule_screen.gd` is a **painted strip**: pick a brush, click blocks, watch
the consequences update beside you, eighteen blocks to a row because the day
breaks at noon. Nothing refuses an edit — a club may sleep four hours and train
at dawn, and the panel tells them what it costs.

Do **not** replace this with `Add Event → type → start → duration → confirm`.
The direct-manipulation approach is correct and wants extending — to a week
rather than a day, with a NOW line, drag and resize, copy a day onto another
day.

**The NOW line is also a rule, not decoration.** Everything before it is
history and cannot be rewritten. Paused at block 21 with training scheduled
21–25, the manager may change 22–25 and may not change 21. No retroactive
edits.

---

## 7. Manager time is the actual resource

The team's schedule and the manager's activity are different things.

```
TEAM     blocks 15-18   training
MANAGER  15  watch the session
         16  call the scout
         17  read the board
         18  interview a recruit
```

The team keeps doing what was scheduled. The manager decides where their
attention goes. That is where management becomes a decision rather than a form.

**This is what makes staff worth money without a percentage.** A good assistant
means *training does not need you*. A poor one means the last time you left,
they drilled the wrong rotation for three hours — and you find out by phone.
See `STAFF_AND_FALLIBILITY.md`.

### 7.1 Thinking is free; doing costs simulated time

| | may be done paused | costs simulated time |
|---|---|---|
| read anything — roster, journal, inbox, board, housing, food, encyclopedia | yes | no |
| design tactics, plan training, edit the future schedule, arrange the board | yes | no |
| prepare an offer | yes | no |
| make a phone call | initiate paused | yes |
| interview a recruit | initiate paused | yes |
| coach somebody personally | decide paused | yes |
| attend training | decide paused | yes |
| hold a meeting, travel, visit | arrange paused | yes |

The decision is always free. The *doing* occupies the manager.

---

## 8. Free time is simulation space, not empty time

FREE does not mean nothing happens. It means **the manager has declined to
prescribe this time**, and the volis fill it themselves: rest, socialise, call
home, use the console, study, eat, train alone, sit with a roommate, leave the
club, do nothing.

This is where the equipment table finally gets read. `Accommodation`'s small
equipment each declares what it `answers` and what it `costs`, and nothing
dispatches on those strings today. They are not waiting for a modifier — they
are waiting for a **behaviour**:

| instead of | prefer |
|---|---|
| Landline: homesickness −12% | a homesick voli actually calls home |
| Console: morale +5 | the roommates visibly play it together |
| Longhouse: cohesion +8 | communal behaviour happens |

The numbers may exist underneath. What the player sees should usually be
somebody doing something.

---

## 9. Exceptions deserve presentation

The manager schedules a midnight picnic over the top of sleep. The schedule
creates the *opportunity*; it does not create attendance. Who comes depends on
fatigue, morale, cohesion, their relationship to the manager, tomorrow's
obligations, their roommate, and their own habits.

```
23:32  the manager arrives
23:38  five volis
23:51  a roommate talks another into coming
00:10  somebody very tired leaves
00:40  two of them are still talking
01:13  the last group goes back
```

And tomorrow their short night is real. The consequence should emerge from who
came and how long they stayed — not from `Midnight Picnic: Team Morale +4`.

---

## 10. Match time is separate

The world clock hands off at the fixture and resumes after it. The match viewer
paces rallies however rallies want to be paced; it does not inherit the world
clock's speed. See `RALLY_PHYSICAL_TIME.md`.

---

## 11. What exists, and what to build

### Already built

- `DailySchedule` — 36 blocks, activity enum, a legal default day,
  `deviation_from`, `clock_label`.
- `DailyScheduleSystem` — sleep to recovery, meals to penalty, training block
  bounds, deviation to morale, roster fracture.
- `schedule_screen.gd` — the painted strip.
- `calendar_rules.gd` — days per week, day names, `display_date(week, day)`.
  Its own header already reached this document's conclusion: *"the calendar
  counted weeks and nothing smaller… it stopped being fine the moment the club
  had a session the manager could attend: you cannot turn up to a week."*
- `career.day_of_week`, `advance_day()`, `training_day_is_today()`,
  `hold_drill_session()` — **the first manager appointment**, already day-pinned.

### To build, in order

1. **A block cursor and a tick.** In memory, deriving events from stable keys,
   with the two interruption behaviours.
2. **Compliance** — the personal schedule as an output, read by the existing
   deviation pricing.
3. **The interview**, as the *second* manager appointment. See
   `RECRUITMENT_AND_THE_OFFER.md`.
4. **Then, and only then, the shared activity contract** — extracted from the
   drill session and the interview once both work. A twelve-field generic
   `Activity` schema written in advance is `FAILURE_MODES.md` §0 at schema
   altitude: fields nothing reads, invented before anything needed them. Two
   working appointments will show what is genuinely shared.
5. The week-grid planner with a NOW line, drag and copy.

---

## 12. The first save

Nobody's first Tuesday is built from scratch.

> **Never present a new player with 36 blank blocks and ask them to construct a
> day.**

A new save opens on a **working schedule** — `DailySchedule.default_blocks()`
already exists for this and its own comment says why: *"deliberately a legal day
rather than an empty one. A manager opening the screen for the first time should
be looking at something that works, so the warnings they see later are ones they
caused."*

That is the whole onboarding argument, already implemented for one day. What it
wants is the same at week scale, via day templates (§5).

**Routine templates are the onboarding. Deviations are the lesson.** The player
does not learn the schedule by being taught its rules; they learn it by moving
one block and reading what the panel says it costs. So the only thing the first
day has to establish is:

> you can change any future block.

### What the first day should demonstrate

- routine runs on its own — no mandatory stop at any phase
- the player may watch or skip, and neither is prompted
- free time is real simulation space, not a gap (§8)
- an ordinary day can be **inhabited or skipped**

And both of these must be first-class:

> *"I want to spend five real minutes watching this ordinary Tuesday."*
> *"Nothing here matters to me. Take me to tomorrow."*

**Neither is the more correct way to play.** A clock that punishes the second
becomes a chore; a clock that makes the first pointless wastes the simulation.
This is the same rule §13 states negatively, and it is worth stating positively
once because it is the reason the skip filters in §2.1 exist at all.

The wider first-save philosophy — a club that already functions, the dual
reading of one save, the first week's shape — is in `DIEGETIC_MANAGEMENT.md`
§9a.

---

## 13. What the player should never have to do

Manually start a scheduled phase. Approve a meal. Click *begin training*. Click
*begin free time*. Rebuild a normal week. Handle every ambient event. React in
real time. Keep the game running while reading something complicated.

## And what they should

Plan the routine. Run time. Watch whatever interests them. Spend their own
attention where it is worth spending. Deal with the interruptions that are worth
dealing with. Skip a quiet Tuesday without skipping the world.

> **Pause is for the player to think. The clock is for the manager and the club
> to live.**
