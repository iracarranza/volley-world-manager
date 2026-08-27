# Master UI flow

Status: **routing and information-architecture authority** for the career UI.

This file does not replace the domain designs. It connects them.

Primary supporting authorities:

- `DIEGETIC_MANAGEMENT.md` — why management is split across physical objects, workspaces and presence.
- `THE_JOURNAL_AND_KNOWLEDGE.md` — what the journal may know, compile and own.
- `THE_DAY_AND_THE_CLOCK.md` — time, the planner, manager attention and appointments.
- `TACTICS_AND_TRAINING.md` — clipboard, tactics, development and live drill sessions.
- `SCOUTING.md` — recruitment knowledge and uncertainty.
- `RECRUITMENT_AND_THE_OFFER.md` — interview and offer flow.
- `THE_DESK_AND_THE_PHONE.md` — desk presence, calls and answering machine.
- `ACCOMMODATIONS_AND_CARE.md` and `HOUSING_WORKSPACE_AND_ARCHITECTURE.md` — housing.

The purpose here is narrower:

> **Where can the player go, what kind of interface are they entering, what does that interface own, and where does an action return them?**

When this file disagrees with an older routing choice in a scene or script, this file owns the intended UI flow. It does not override the simulation authority of the domain document or model underneath that UI.

---

## 0. Settled navigation rules

### 0.1 The desk is home, not a mandatory interchange

The career starts at the **Desk**. The Desk is the spatial home of the manager and the place where the world can physically reach them.

The player does **not** have to return to the Desk every time they want another working object.

Ordinary career workspaces share persistent navigation:

```text
GLOBAL CAREER HEADER
────────────────────────────────────────────────────────────────────────
Desk | Journal | Calendar | Training | Scouting | Housing | Kitchen | Encyclopedia
                                                        date/time · pause/speed
────────────────────────────────────────────────────────────────────────

                         selected workspace
```

The exact visual form of the header remains a presentation question. Its information architecture is settled: the primary career objects are directly reachable from one another.

`Desk` in the header means **return to the room**. `Journal` means **open the working record**. They are not synonyms.

### 0.2 The Desk still matters because the world can reach the player there

The Desk is not only a menu rendered as a room.

```text
PLAYER → Journal
PLAYER → Calendar
PLAYER → Training
PLAYER → Scouting
PLAYER → Housing
PLAYER → Kitchen

WORLD → telephone → PLAYER
WORLD → answering machine → PLAYER
WORLD → visitor / appointment → PLAYER
WORLD → office event → PLAYER
```

That asymmetry is load-bearing. The workspaces are things the player intentionally consults. The office is also a place where something can happen **to the manager**.

### 0.3 Objects do not need equal depth

Do not make every Desk object a Journal-sized application.

Depth follows the managerial verb and the information topology:

| object | expected depth | why |
|---|---:|---|
| Journal | deep | persistent, dense working record across many subjects |
| Calendar | medium-deep | finite time allocation and future schedule |
| Training clipboard | deep | tactics and development authoring |
| Scouting corkboard | medium | sparse active field of uncertain candidates |
| Housing folder | medium | one live housing matter and its documents |
| Kitchen / meal-plan object | shallow-medium | recurring food allocation/configuration |
| Encyclopedia | deep | reference corpus |
| Telephone | shallow | synchronous communication |
| Answering machine | shallow | missed/asynchronous communication |
| Desk / office | spatial | presence and world contact |

> **Objects expose the minimum interface necessary to perform their fantasy.**

### 0.4 Reference, workspace, presence

Three UI roles recur throughout the game:

```text
REFERENCE
Journal / Encyclopedia
        │
        │ known facts, records, comparison
        ▼
WORKSPACE
Calendar / Training / Scouting / Housing / Kitchen
        │
        │ authoring, allocation, arrangement
        ▼
PRESENCE
Office interview / live drill / Match / later physical visits
```

A fact may appear in more than one place. A specialist verb should not.

Examples:

```text
Journal: Room 3 · roommate Iri
Housing: move rooms / change equipment / inspect the home

Journal: training emphasis · receive
Training: construct / assign / demonstrate training

Journal: next fixture / result
Match: observe / intervene
```

### 0.5 Physical metaphor gives intuition, not literal constraints

Clicking a Voli photograph on the scouting board may open a full dossier. The fact that the object is a photograph does not require the interface to show only a photograph.

The object explains **what the player is interacting with**. It must not prevent useful navigation.

### 0.6 Figures and evidence before authored conclusions

Across the career UI, prefer observable state, known facts and source evidence over omniscient prose that tells the player what to think.

The Journal may compile evidence. Staff may make fallible judgments. The player diagnoses.

### 0.7 State before tools

A workspace should normally establish **what is currently true** before exposing controls that imply the player ought to change it.

The test is:

> **When I enter this object, do I first understand the thing I am managing, or am I immediately handed its editing tools?**

This is not a ban on direct manipulation. Once the player chooses to work, direct manipulation is preferred. The point is that opening a workspace must not itself create an implied obligation to edit.

Housing already approaches this well: the current home is visible before its change panels are opened. Scouting does too: the board shows the current candidate field before asking for a new action. Training must follow the same rule.

---

## 1. Career-level master flow

### 1.1 Session entry

```text
TITLE
│
├── New Career
│      ↓
│   NEW CAREER
│      ↓
│   functioning default club
│      ↓
│     DESK
│
└── Load Career
       ↓
      DESK
```

The New Career builder must not become a configuration wizard. The first Desk state already has a roster, rooms, food, staff, tactics, schedule and upcoming fixture sufficient for the institution to function.

### 1.2 Live career shell

Target architecture:

```text
══════════════════════════════════════════════════════════════════════
                            LIVE CAREER
══════════════════════════════════════════════════════════════════════

GLOBAL CAREER HEADER
Desk | Journal | Calendar | Training | Scouting | Housing | Kitchen | Encyclopedia
                                         current date/time · pause/speed/skip

                                  │
                                  ▼
                                DESK
                           spatial home
                                  │
      ┌───────────────┬───────────┼──────────────┬───────────────┐
      ▼               ▼           ▼              ▼               ▼
   JOURNAL         CALENDAR    TRAINING       SCOUTING         HOUSING
      │               │           │              │               │
      │               │           │              │            KITCHEN
      │               │           │              │
      │               │           │          ENCYCLOPEDIA
      │               │           │
      │               │       PHONE / ANSWERING MACHINE
      │               │
      │               └────── time / appointments ───────────────┐
      │                                                          │
      └────────── knowledge / durable record                     │
                                                                 │
                              WORLD CLOCK ◄──────────────────────┘
                                   │
                         scheduled event reached
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
                LIVE DRILL      INTERVIEW       FIXTURE
                    │              │              │
                    │              │           LOCK-IN
                    │              │              │
                    │              │             MATCH
                    └──────────────┴──────────────┘
                                   │
                              WORLD RESUMES
```

The global header is for ordinary career navigation. Presence modes may temporarily suppress or alter it when the manager is physically occupied by an event.

---

## 2. Time is a persistent layer, not an Advance button

### 2.1 Current implementation versus target

Current implementation is still principally week-grained: the player can advance the week and many systems resolve on that action.

The intended design is already established in `THE_DAY_AND_THE_CLOCK.md`:

```text
PAUSED   1×   2×   4×      SKIP TO ...
```

Time normally progresses automatically. The player may pause manually whenever they want to inspect or plan.

This is closer to `Software Inc.` / `The Sims` than to repeated `Continue` presses.

### 2.2 The block remains authoritative

Do **not** replace the existing time model with a second minute-resolution authority.

`DailySchedule` already defines:

```text
36 blocks per day
40 minutes per block
```

The block index remains authoritative for scheduling, pricing, recovery, training budget and event position. Clock time is presentation.

```text
simulation authority       player-facing presentation
block 0                     00:00
block 1                     00:40
block 2                     01:20
...
block 35                    23:20
```

A visually continuous clock may interpolate between block boundaries later, but it must not create a second competing simulation clock.

**Open design concern:** the current 36 × 40-minute structure may be less intuitive for human planning than a conventional 24-hour schedule with a more familiar planning snap. The calendar vocabulary and year structure are also under reconsideration. Do not change simulation authority here until that separate calendar/time decision is settled.

### 2.3 Thinking is free; doing costs simulated time

While paused, the player can spend arbitrary real-world time:

- reading the Journal;
- inspecting a dossier;
- comparing Volis;
- arranging the scouting board;
- drawing tactics;
- editing future schedule blocks;
- inspecting Housing;
- planning food;
- reading the Encyclopedia.

No simulated time passes merely because the player is thinking.

Manager actions can occupy simulated time:

- attend training;
- personally coach;
- make a phone call;
- interview a recruit;
- hold a meeting;
- travel / visit;
- other future manager appointments.

### 2.4 Match time is separate

At a fixture, the world clock hands off to the match.

```text
WORLD CLOCK
    ↓
fixture reached
    ↓
LOCK-IN
    ↓
MATCH
(rally pacing owns time here)
    ↓
match ends
    ↓
WORLD CLOCK RESUMES
```

The match viewer does not inherit the world clock's playback speed.

---

## 3. The Desk object map

The Desk is the physical index of the career, but specialist screens remain directly navigable once opened.

```text
DESK / OFFICE
│
├── Journal
│     persistent working record
│
├── Calendar / Planner
│     week and day scheduling
│
├── Training Clipboard
│     tactical intent + development
│
├── Scouting Corkboard
│     active unsigned candidates + uncertain evidence
│
├── Housing Folder
│     current home and housing decisions
│
├── Meal-plan / Kitchen object
│     squad food plan and supply decisions
│
├── Encyclopedia
│     world reference
│
├── Telephone
│     live two-way contact
│
├── Answering Machine
│     missed calls / replayable contact
│
└── Office space itself
      visitor / interview / presence events
```

`Settings` remains non-diegetic and belongs to the Escape/system menu rather than becoming another management object.

---

# 4. Journal

## 4.1 Identity

> **The Journal is the manager's organized working record of what they currently know about the club, its people, its competitions and their own career.**

It is allowed to be the densest object on the Desk.

It does not need to own every action merely because it can display the corresponding facts.

The Journal is no longer the navigation hub. `Home` inside the Journal is therefore renamed/reframed as **Current**; the actual career home is the Desk.

## 4.2 Accepted Journal flow

```text
JOURNAL
│
├── CURRENT
│   │
│   ├── Week / Date
│   ├── Inbox / correspondence record
│   ├── Upcoming
│   │   ├── next fixture
│   │   ├── appointments
│   │   └── notable deadlines / commitments
│   ├── Recent
│   │   ├── match results
│   │   ├── Voli events
│   │   ├── transactions / movement
│   │   └── club / world events
│   └── current schedule summary
│       └── open Calendar to edit
│
├── ROSTER
│   │
│   ├── Roster Index
│   │
│   └── select Voli
│       │
│       └── VOLI DOSSIER
│           ├── Overview
│           │   ├── identity / biography
│           │   ├── position / role
│           │   ├── current D–S positional ratings
│           │   ├── condition
│           │   └── current known state
│           │
│           ├── Volleyball
│           │   ├── attributes
│           │   ├── body / footedness
│           │   ├── traits
│           │   ├── signatures / unusual vocabulary as known
│           │   └── tactical roles / responsibilities
│           │
│           ├── Development
│           │   ├── attribute history
│           │   ├── training emphasis
│           │   ├── form
│           │   └── usage / appearances
│           │
│           ├── Personality / Social
│           │   ├── known personality
│           │   ├── wants / ambitions / expectations
│           │   ├── relationships
│           │   └── relevant personal history
│           │
│           ├── Care
│           │   ├── known food preferences / aversions
│           │   ├── accommodations
│           │   └── known physical / medical arrangements
│           │
│           ├── Living
│           │   ├── structure
│           │   ├── room
│           │   └── roommate / living context
│           │
│           └── Reports / History
│               ├── staff reports
│               ├── contract / club status
│               └── durable career history
│
├── TEAM
│   │
│   ├── LINEUP
│   │   ├── Starting Six
│   │   ├── Bench
│   │   ├── Positions / Rotation
│   │   ├── Current State
│   │   │   ├── condition
│   │   │   ├── fatigue
│   │   │   └── confidence
│   │   └── FORM
│   │       ├── individual recent form
│   │       ├── team recent results
│   │       └── current-lineup history
│   │
│   └── TEAM PROFILE
│       ├── team attribute profile
│       ├── depth
│       ├── relationships
│       ├── pair familiarity
│       ├── tactical comfort / familiarity views
│       └── longer-term tendencies
│
├── CLUB
│   │
│   ├── Overview
│   │   ├── identity
│   │   ├── reputation
│   │   └── organisation state
│   │
│   ├── Staff
│   │   ├── directory
│   │   ├── responsibilities
│   │   └── staff-authored reports
│   │
│   ├── Finance
│   │   ├── balance
│   │   ├── income / expenses
│   │   └── budget
│   │
│   ├── Sponsorship
│   │   ├── current agreements
│   │   └── history / obligations
│   │
│   └── MOVEMENT / TRANSACTIONS
│       ├── active recruitment processes as administrative state
│       ├── arrivals / departures
│       └── transfer history
│
├── COMPETITION
│   │
│   ├── Fixtures
│   │   └── select fixture
│   │       ├── fixture record
│   │       ├── known opponent information
│   │       └── fixture reached by world clock
│   │             ↓
│   │          LOCK-IN
│   │             ↓
│   │           MATCH
│   │
│   ├── Results
│   │   └── select completed match
│   │       └── match record / available evidence
│   │
│   └── competition state / standings / bracket as appropriate
│
└── SIXNET
    ├── world overview
    ├── regional / league standings and rankings
    ├── other clubs
    │   └── club profile / known record
    └── wider volleyball world
```

## 4.3 Team: form belongs to the selected lineup

There is no separate top-level `Performance` page.

The Lineup page answers:

> **Who am I putting on court, and what does this selected six look like right now?**

Therefore current form sits beside lineup selection.

Keep three concepts distinct in the data/presentation even if they are shown together:

```text
Voli form
= how this individual has performed recently

Lineup form
= evidence about this particular selected configuration

Team form
= recent club/team results regardless of six
```

Changing one Voli should be allowed to change the lineup-specific evidence without pretending that the club's previous five results changed.

Prefer evidence such as recent results, starts together and individual trends over one omniscient `Lineup Form: Excellent` label.

## 4.4 Relationships belong in Team Profile

Relationships and familiarity are properties of the team's longer-term structure. They do not need a separate Team destination unless the eventual information volume proves otherwise.

## 4.5 Transfers is no longer a primary Journal workflow

The old Journal transfer market is obsolete under the scouting/recruitment architecture.

The Journal may retain **movement / transaction records and administrative state**, but it does not own candidate discovery, dossier evaluation, interviewing or the signing action.

Do not preserve a top-level `Transfers` tab merely because the current implementation has one.

## 4.6 Journal actions that should leave

The Journal may show current state, but specialist actions should migrate:

```text
starter / bench assignment      → Team / Lineup
training configuration          → Training
schedule editing                → Calendar
scouting / candidate evaluation → Scouting
housing changes                 → Housing
food changes                    → Kitchen
recruit interview / offer       → recruitment flow / office presence
```

A Voli dossier may expose contextual links to those workspaces without duplicating their controls.

---

# 5. Calendar / Planner

## 5.1 Identity

The Calendar is a **Desk object and primary workspace**.

It is not a Training sub-screen.

Training is only one claimant on the club's finite time.

```text
                         CALENDAR
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
       TRAINING           MATCH            CLUB LIFE
                                               │
                                      ┌────────┼────────┐
                                      ▼        ▼        ▼
                                    meals    social    rehab
```

The current `Daily Schedule` screen is therefore an early implementation of the Calendar/Planner, not a permanent child of Training.

## 5.2 Existing authoritative model

The current schedule already supports:

```text
assignable
- Sleep
- Meal
- Training
- Social
- Free

locked obligations
- Rehab
- Sponsor
- Travel
```

There is a club day and optional personal Voli schedules derived from it.

The UI should continue to expose **trade-offs, not prohibitions**. A manager may author a bad day and see the cost rather than being blocked by the form.

## 5.3 Target Calendar flow

The existing painted day strip should evolve rather than be replaced by an event-form calendar.

```text
CALENDAR
│
├── WEEK VIEW
│   ├── Day 1
│   ├── Day 2
│   ├── Day 3
│   ├── Day 4
│   ├── Day 5
│   └── additional days only if the final calendar keeps them
│
├── FUTURE BLOCK AUTHORING
│   ├── paint activity
│   ├── drag / resize
│   ├── copy day / template
│   └── individual Voli exception
│
├── FIXED / LOCKED OBLIGATIONS
│   ├── rehab
│   ├── sponsor
│   ├── travel
│   ├── fixture
│   └── manager appointments such as interview
│
├── READOUT
│   ├── sleep
│   ├── meals
│   ├── training time / effective yield
│   ├── recovery
│   ├── social time
│   ├── individual deviation
│   └── warnings / consequences
│
└── NOW LINE
    ├── past blocks = history, cannot be edited
    └── future blocks = editable while paused
```

The exact number and names of days are intentionally not frozen here while the calendar naming/time structure is under review.

Routine templates are the default. The player should not rebuild a normal week by hand.

## 5.4 The Calendar reports what is scheduled; presence handles what actually happens

A block marked `TRAINING` means the club expects training then. It does not mean the player must click `Begin Training`.

At the scheduled time:

```text
TRAINING BLOCK REACHED
        │
        ├── manager does not attend
        │      ↓
        │   staff / simulation resolves session
        │      ↓
        │   world continues
        │
        └── manager attends
               ↓
            LIVE DRILL
               ↓
            world continues
```

The same pattern can support interviews and later manager appointments without turning every block into a prompt.

---

# 6. Scouting and recruitment

Status: **partly settled; retain explicit TBDs instead of filling them for symmetry.**

## 6.1 The scouting corkboard owns the active unsigned candidate field

The board is not a window into a giant hidden transfer market.

> **The Volis physically present on the board are the club's complete set of active unsigned candidates under meaningful consideration.**

The board should normally be sparse.

Do not allow the accessible recruitable population to grow far beyond the amount of information the corkboard can meaningfully hold. Recruitment is intentionally not a high-volume shopping loop.

This follows the world premise:

> **Clubs are where Volis live.**

Changing club is therefore consequential in the world even when the player-facing process remains concise.

## 6.2 Unsigned dossiers

```text
SCOUTING CORKBOARD
│
├── pinned Voli
│      ↓ click photograph / card
│   UNSIGNED VOLI DOSSIER
│   ├── identity / known biography
│   ├── known / estimated volleyball information
│   ├── uncertainty / scouting confidence
│   ├── observations / reports
│   └── known personal / club-fit information
│
└── other pinned evidence / clippings
```

The dossier is a reusable entity view. The board owns the **context** of an unsigned candidate; it does not require a separate dossier implementation from the roster's signed Voli view.

A Voli seen elsewhere does not become an active candidate merely because the player can inspect them. Being pinned to the board is meaningful state.

## 6.3 Board labels are manager dispositions, not transaction buttons

Accepted conceptual set includes labels such as:

```text
WATCH
SIGN / WOULD SIGN / PURSUE   [final wording TBD]
REJECT / SEEN ENOUGH
```

These are annotations on the manager's active field of possibilities.

They are not themselves the signing transaction.

The current implementation already distinguishes `would sign`, `watch` and `seen enough`; preserve that distinction while the final recruitment verb is refined.

## 6.4 Scouting evidence to recruitment

```text
observe / scout
      ↓
dossier develops
      ↓
manager marks candidate
      ↓
WATCH ───────────────→ remains active on board
      │
      ├── REJECT / SEEN ENOUGH → leaves active field / archives as appropriate
      │
      └── PURSUE / WOULD SIGN
                    ↓
              RECRUITMENT PROCESS
                    ↓
              contact / response
                    ↓
          ┌─────────┴─────────┐
          ▼                   ▼
       OFFER              INTERVIEW
                              │
                              ▼
                         OFFICE / DESK
                              │
                              ▼
                            OFFER
                              │
                       ┌──────┴──────┐
                       ▼             ▼
                    AGREED         FAILS
                       │             │
                       ▼             └──→ world continues
                     ROSTER
```

`RECRUITMENT_AND_THE_OFFER.md` remains authoritative that interviews are not always required and that the offer sheet is the primary signing surface.

## 6.5 Recruitment need not be a generic workspace

Current direction:

- **Scouting** is a workspace.
- **Recruitment** is principally a process/state connecting scouting, contact, appointments and an offer.
- **Interview** is a presence event in the office.
- **Offer** is a focused transaction surface.

Do not create `Recruitment` as a full conventional menu merely because the process has several stages. Add a dedicated workspace only if a distinct recurring managerial verb and information topology actually emerge.

## 6.6 Interview as Desk presence

```text
SCOUTING
mark candidate for pursuit
      ↓
time passes
      ↓
contact / agreement to meet
      ↓
CALENDAR
appointment · interview
      ↓
clock reaches appointment
      ↓
DESK / OFFICE
      ↓
INTERVIEW PRESENCE
      ↓
return to offer / world
```

The intended interview is across-the-table presence rather than a dialogue box attached to the scouting board.

It may temporarily become a first-person or otherwise spatial experience if that strengthens the canonical office and remains usable. Exact camera/presentation is not settled here.

---

# 7. Training Clipboard

## 7.1 Identity: planning first, doing later

The Training Clipboard is the club's durable **planning and authoring workspace** for two things:

- tactical intent;
- individual capability development.

It is not the place where a training session itself happens.

> **Clipboard = planning. Gym / session = doing.**

The current screen already has the correct two durable domains — `Tactics` and `Development` — but its default presentation begins directly inside editing tools. That makes the mechanic legible to its author before it is legible to the player.

Opening Training should first establish **what training currently is**, not immediately instruct the player to drag, place, select or configure something.

## 7.2 The front sheet is the default entry

The Clipboard gets a **front sheet / current plan** before its authoring pages.

This is not a generic dashboard and it does not diagnose the team. It is the current training plan lying on top of the clipboard.

Conceptual contents:

```text
TRAINING CLIPBOARD
│
├── THIS WEEK / CURRENT PLAN          ← default entry
│   │
│   ├── Next scheduled session
│   │   ├── day / time
│   │   ├── duration
│   │   └── open Calendar
│   │
│   ├── Current tactical work
│   │   ├── current team plan / preset
│   │   └── structures currently being taught
│   │
│   ├── Tactical-comfort gaps
│   │   ├── Voli / pair / slot
│   │   └── the specific ask that is unfamiliar
│   │
│   ├── Current development assignments
│   │   ├── Voli
│   │   └── attribute emphasis / allocation
│   │
│   └── Recent training evidence
│       └── what the last session actually changed / exposed
│
├── TACTICS
│
└── DEVELOPMENT
```

The front sheet must remain useful when the manager changes nothing. A player should be able to open the clipboard, verify the current plan, and leave without the interface implying that inactivity is incomplete play.

Do not write prose such as `Your team needs to improve first-tempo attack` or `Focus on Ivo`. Show the plan and evidence:

```text
Ivo 4        slide coordinate
Pāla ↔ Iri   first tempo
Rotation 5   deep-line coverage
```

The manager decides whether those facts deserve action.

## 7.3 Calendar owns when; Training owns what

The current Training ribbon's `Daily Schedule` action reflects old architecture.

Target ownership:

```text
CALENDAR
"When does the club train, and how much time is available?"
        │
        │ allocates time
        ▼
TRAINING
"What are we trying to teach or develop in that time?"
```

The Training front sheet may show:

```text
NEXT SESSION
[day] · 14:00–16:00
2h scheduled

[open in Calendar]
```

but it does not edit the schedule itself.

Calendar and Training are peer workspaces. Neither contains the other.

## 7.4 Tactics owns declared volleyball intent

The Tactics page answers:

> **How are we trying to play?**

It owns the declared system:

```text
TACTICS
│
├── team tactical intent
├── phase plans
├── presets
├── generated individual asks
├── manager exceptions / overrides
└── fit against current tactical comfort
```

A preset must eventually decompose into concrete asks in the same state space that training can change. Those asks may be inspected and overridden, but individual instructions should be generated by default rather than requiring six-rotation micromanagement.

The durable Tactics page should not visually pretend a practice session is already occurring. In particular, once the interaction becomes:

- actual Volis in one specific situation;
- routes being drawn;
- exact attack locations;
- tempo relationships;
- option structures;
- coverage relationships;
- looping demonstration;

it has crossed into the **Play Designer**, not ordinary tactics authoring.

## 7.5 Play Designer is a contextual authoring surface, not a third permanent tab

`TRAINING_PLAY_DESIGNER.md` remains authoritative for its mechanics.

Within this flow, the Play Designer answers:

> **How are we teaching this coordinated structure to these Volis?**

It can be entered from a tactical structure or a specific training gap:

```text
TACTICS
Combination Play
      ↓
coordinated structure
      ↓
[work on this]
      ↓
PLAY DESIGNER
```

or:

```text
CURRENT PLAN
Pāla ↔ Iri · first tempo
      ↓
[prepare session]
      ↓
PLAY DESIGNER
```

Target flow:

```text
PLAY DESIGNER
│
├── choose situation
│   ├── Serve Reception
│   ├── Dig / Transition
│   └── Free Ball
│
├── selected rotation / actual Volis
├── intended positions
├── routes / approaches
├── attack locations
├── tempo relationships
├── option structure
└── coverage / transition relationships
        │
        ↓
DECOMPOSE TO TRAINABLE ASKS
```

The drawing is intent, never independent rally authority. Saving must decompose into the underlying trainable relationships. If the model cannot represent one of those relationships, expose that missing seam rather than storing a parallel `play familiarity` truth.

The Play Designer may temporarily take over most of the clipboard surface. It does **not** need to sit permanently beside `Tactics` and `Development` as another top-level application tab.

## 7.6 Development owns capability, not tactical comfort

The Development page answers:

> **What individual capability are we trying to raise?**

Conceptual flow:

```text
DEVELOPMENT
│
├── select Voli
├── current attribute state / known development evidence
├── choose attribute emphasis / pool
├── choose available allocation / intensity where the model supports it
├── projection / trade-off evidence
└── save development assignment
```

Attribute training changes ratings/capability toward potential. It does not substitute for teaching tactical coordinates, tempos, loci or pair relationships.

Likewise, `focus` controls that belong to attribute development must not leak onto coordinated tactical training merely because both are called training.

## 7.7 The clipboard prepares a session; the clock starts it

There is no `Start Drill` progression button on the Clipboard.

The Clipboard prepares what the club intends to work on. The Calendar determines when training exists. The world clock reaches it.

```text
PAUSED / PLANNING

Training Clipboard [AUTHOR]
      ↓
current plan / prepared structure
      ↓
close clipboard

WORLD CLOCK RUNS
      ↓
scheduled training time arrives
      ↓
manager attention decision
      │
      ├── do not attend
      │      ↓
      │   staff runs session [RESOLVE]
      │      ↓
      │   training evidence recorded [OBSERVE]
      │
      └── attend
             ↓
         LIVE DRILL [PRACTICE / PRESENCE]
             ↓
         actual Volis attempt structure [RESOLVE]
             ↓
         training evidence recorded [OBSERVE]
             ↓
         WORLD CLOCK RESUMES
```

Routine training should not stop the clock merely to ask for approval. Attendance is a manager-time choice, not a mandatory phase confirmation.

## 7.8 Demonstration and actual execution are deliberately different

The clean plan on the clipboard is not proof the squad can execute it.

```text
DESIGNED STRUCTURE [AUTHOR]
        ↓
TACTICAL COMFORT / DEVELOPMENT STATE
        ↓
LIVE PRACTICE ATTEMPT [PRACTICE]
        ↓
Voli decisions + capability + relationships [RESOLVE]
        ↓
ACTUAL EXECUTION
        ↓
training evidence [OBSERVE]
```

A route drifting, a tempo mistiming or a setter salvaging a broken structure is useful feedback. Do not polish those discrepancies away as animation error when they are caused by the authoritative model.

## 7.9 Training flow summary

```text
TRAINING CLIPBOARD
│
├── CURRENT PLAN                     ← first thing seen
│   ├── scheduled time ───────────────→ Calendar
│   ├── tactical work
│   ├── tactical-comfort gaps
│   ├── development assignments
│   └── recent evidence
│
├── TACTICS
│   ├── broad team intent
│   ├── phase plans / presets
│   ├── generated asks
│   ├── exceptions
│   └── coordinated structure
│          ↓
│       PLAY DESIGNER
│          ├── situation
│          ├── actual Volis
│          ├── routes / locations
│          ├── tempos / options
│          └── coverage
│
└── DEVELOPMENT
    ├── Voli
    ├── ability state
    ├── attribute emphasis
    └── allocation / projection

               ↓ prepared work

CALENDAR → scheduled training block
               ↓
          WORLD CLOCK
               ↓
        training time arrives
               ↓
       ┌───────────────┐
       ▼               ▼
   DELEGATE          ATTEND
       │               │
 staff resolves     LIVE DRILL
       │               │
       └───────┬───────┘
               ▼
       TRAINING EVIDENCE
               │
        ┌──────┴──────┐
        ▼             ▼
    Clipboard       Journal
 current plan      durable record
```

---

# 8. Current implementation debt against this flow

At the time of this document, the application routing still reflects the older Journal-centred architecture.

### 8.1 Back routes

Current code effectively contains:

```text
Training      → Back → Journal
Scouting      → Back → Journal
Housing       → Back → Journal
Kitchen       → Back → Journal
Encyclopedia  → Back → Journal

Training → Daily Schedule → Back → Training
```

Target:

- ordinary primary workspaces receive the persistent career header;
- `Back` remains useful for local modal/depth navigation where there is a real previous state;
- Journal is no longer the universal destination;
- Calendar is promoted out of Training.

### 8.2 Training cold-start debt

The current Training screen opens directly into its first editing page, `Tactics`, with active manipulation controls. This is mechanically functional and presentationally premature.

Target:

- default entry becomes the current-plan/front-sheet state;
- `Tactics` and `Development` become intentional deeper pages;
- Play Designer is contextual, not a permanent third top-level tab;
- Calendar link reports/opens scheduled time rather than treating schedule as a Training child;
- no routine training action begins merely because the Clipboard is open.

### 8.3 Shared shell

`screen_shell.gd` already centralizes ordinary screen anatomy: backdrop, ribbon, title, actions and content surface.

It is the natural implementation seam for persistent career navigation, but the exact component design should be done once rather than separately on each screen.

### 8.4 Advance Week

`Advance Week` remains a valid current-build progression control while the live clock is absent.

It is **transitional architecture**, not the long-term core verb.

Do not prematurely remove it before a working clock, skip controls and event resolution replace its function.

### 8.5 Desk objects with no live screen yet

Telephone and answering machine are intentionally present as Desk concepts without completed interaction screens.

Do not fill them with placeholder application menus merely to make every object clickable.

---

# 9. Flow notation for future sections

When useful, future flowcharts may annotate nodes by role:

- `[OBSERVE]` — information/evidence the manager receives.
- `[AUTHOR]` — the manager changes intent, allocation or arrangement.
- `[PRACTICE]` — the club attempts to learn or rehearse something.
- `[RESOLVE]` — Volis/staff/simulation determine what actually happens.

Example:

```text
Opponent report [OBSERVE]
        ↓
Match plan [AUTHOR]
        ↓
Training [PRACTICE]
        ↓
Voli perception / decision [RESOLVE]
        ↓
Rally [RESOLVE]
        ↓
Playback / evidence [OBSERVE]
        ↓
Adjustment [AUTHOR]
```

These labels describe causal role, not visual styling.

---

# 10. Next sections to resolve

Do not invent these merely to complete the diagram. Extend this document as each flow is reviewed against its domain authority and current implementation.

Recommended order:

1. **Housing** — folder internal flow and optional physical visit boundary.
2. **Kitchen** — settle the meal-plan object's final interaction grammar.
3. **Club / Staff** — determine which staff operations remain Journal-shaped and which earn another verb/object.
4. **Competition / Lock-In** — fixture entry, roster commitment and return path.
5. **Match** — live view, tactical intervention, evidence and exit back to world time.
6. **Phone / answering machine** — two-way call flow, interruption level and asynchronous loss.
7. **Full cross-workspace contextual links** — Voli dossier → Training, candidate dossier → Scouting/Offer, fixture → Lock-In, etc.

The final master graph should be updated only after those local flows are settled.

---

# 11. Design tests

A proposed UI route is suspect if any of these are true:

- it makes the player return to the Journal only to reach another workspace;
- it duplicates a specialist action inside the Journal;
- it opens a workspace directly into editing before establishing the current managed state;
- it makes merely opening a workspace imply that the player ought to change something;
- it creates a large browseable transfer market behind the scouting board;
- it turns every Desk object into the same tabbed application;
- it requires the player to manually start routine scheduled phases;
- it advances fictional time while the player is merely reading or thinking;
- it lets the player rewrite schedule blocks that are already in the past;
- it treats a manager annotation as if it were a transaction;
- it turns presence into a permanent overworld the player must walk through for ordinary navigation;
- it exposes simulation truth where the manager should have uncertain knowledge;
- it turns a staff judgment into the neutral voice of the interface;
- it creates a second authoritative time unit beside the current day model before the calendar/time decision is settled;
- it preserves an old screen/tab solely because the implementation currently has it.

The target is one career whose deep simulation can be managed either by careful inspection or by inhabiting the club and watching it live, without those becoming two different games.