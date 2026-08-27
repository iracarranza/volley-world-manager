# Interaction grammar and manager attention

Status: **cross-cutting UI / interaction authority** for how the player reads, manipulates and inhabits the career simulation.

This file extends `MASTER_UI_FLOW.md`, `DIEGETIC_MANAGEMENT.md` and `THE_DAY_AND_THE_CLOCK.md`.

It does not decide where systems live. `MASTER_UI_FLOW.md` owns that. It does not replace the simulation authority underneath mood, fatigue, training, scouting, relationships or time. It defines the interaction rules that make those systems legible and polished once they are placed.

Two problems are addressed here:

1. why a player would ever let the live clock run at ordinary speed instead of pausing to configure everything and then skipping / running at maximum speed;
2. what separates a mechanically complete, visually themed UI from a genuinely polished one.

---

## 0. The live clock must not be justified by chores

A player who prefers to:

```text
PAUSE
  ↓
read / compare / plan / configure
  ↓
4× / SKIP
  ↓
next meaningful event
```

is playing correctly.

Do **not** manufacture mandatory breakfast prompts, routine approvals or arbitrary daily tasks merely to force the player to remain at 1×.

The target is:

> **Fast-forward is efficient when nothing interests you. Ordinary speed is valuable when you want to understand or inhabit what is happening.**

The clock earns itself through simulation, observation and manager presence, not through extra clicks.

---

# 1. What each time mode is for

The player-facing contract should be conceptually stable even if exact speed multipliers change.

```text
PAUSED
best for:
- reading
- comparing
- planning
- editing
- thinking

FAST / SKIP
best for:
- ordinary routine
- quiet stretches
- reaching the next event the player already cares about

1× / 2×
best for:
- watching uncertain situations unfold
- observing people
- noticing deviations from routine
- attending or following an activity
- learning soft information
- inhabiting the club
```

Pause protects thought. Fast-forward protects the player from maintenance. Ordinary speed must expose something worth observing.

---

# 2. Observation is an information advantage, not a surveillance requirement

Watching the club should reveal **richer, earlier or more contextual evidence** than a static record can, but it must not be the only route to essential facts.

Example:

```text
STATIC RECORD
Pāla
condition 71
fatigue elevated

LIVE OBSERVATION
Pāla arrives late to breakfast
sits apart from the others
does not finish the meal
looks slow during warm-up
leaves free time early to sleep
```

The record is enough to manage safely. The live sequence gives a human-scale reading of the same underlying club.

This is the intended relationship:

```text
simulation state
      ↓
manifested behaviour
      ↓
player observation
      ↓
manager hypothesis
      ↓
optional inspection / conversation / intervention
```

Do not replace the hypothesis step with interface prose such as `Pāla is upset because Iri kept them awake` unless a named fallible person is making that claim.

---

## 2.1 Hard information versus soft information

Use this distinction when deciding what fast-forward may safely pass over.

### Hard / consequential information

Must remain recoverable through interruption, indicator, Journal record, staff report, voicemail or another durable route.

Examples:

- injury;
- missed or failed appointment;
- serious conflict;
- recruitment response;
- time-sensitive call;
- explicit Voli request;
- fixture;
- deadline;
- absence from training;
- any decision that expires if ignored.

A player must never be punished for not staring at the club at the exact second one of these occurs.

### Soft / human information

May be primarily legible through observation and later accumulate into broader evidence.

Examples:

- somebody seems unusually tired;
- two roommates increasingly spend time together;
- a Voli repeatedly trains alone;
- somebody appears to avoid another person;
- somebody keeps calling home;
- unusual use of free time;
- emerging habit, quirk or preference;
- changes in ordinary social behaviour;
- small deviations from a person's usual routine.

Soft information makes watching worthwhile without making watching mandatory.

---

# 3. Daily state should create behaviour, not a wall of need bars

The club should have meaningful day-to-day variation, but avoid turning every Voli into a set of Sims-style meters requiring routine maintenance.

Transient daily state should mostly emerge from systems already being simulated:

```text
sleep / schedule
      ↓
recovery / fatigue
      ↓
readiness / condition

food / recent eating
      ↓
energy / recovery / satisfaction

relationships / recent events
      ↓
social behaviour

training / matches / mistakes / success
      ↓
confidence / emotional state

personality + traits + current state
      ↓
what the Voli actually chooses to do today
```

The exact mood/emotional model remains a domain-design question. This document does not invent a new universal `mood` stat.

The presentation requirement is:

> **When transient state matters, it should often become visible as changed behaviour before it becomes another permanent meter.**

---

# 4. Manager attention is the scarce player-facing resource

The strongest reason not to skip every day is not that the interface needs constant input. It is that the fictional manager cannot personally be everywhere.

Keep these separate:

```text
TEAM SCHEDULE
14:00–16:00  training

MANAGER ATTENTION
14:00  attend the session
14:40  call the scout
15:20  interview a recruit
```

The team continues doing what was scheduled. The manager decides which things deserve personal presence.

This produces meaningful alternatives:

```text
TRAINING SESSION
      │
      ├── leave it to staff
      │      ↓
      │   session resolves
      │
      └── attend
             ↓
        live drill
        richer observation
        direct demonstration / coaching where allowed
```

Likewise, manager time spent on an interview, call, visit or meeting means not personally attending something else.

The intended question is:

> **What am I personally paying attention to today?**

not:

> **How do I keep myself busy until the match?**

---

# 5. Two legitimate play styles, one simulation

The game should support both of these without explicit modes.

```text
SIMULATOR READING
pause
  ↓
inspect evidence
  ↓
plan
  ↓
fast-forward

INHABITED READING
let time run
  ↓
notice behaviour
  ↓
investigate
  ↓
intervene or keep watching
```

Neither receives superior hidden outcomes merely for choosing the preferred presentation style.

A player who watches should gain texture, earlier clues and context. A player who skips should retain enough durable evidence to make competent decisions.

This preserves the existing principle from `DIEGETIC_MANAGEMENT.md`: the deep-simulator player and the cozy/presence-oriented player are not playing different games.

---

# 6. Four layers of UI quality

A complete UI system needs four distinct design passes.

```text
1. MECHANIC
What can the player do?

2. INFORMATION ARCHITECTURE
Where does the action live?

3. INTERACTION DESIGN
How does the player understand and perform it?

4. PRESENTATION / FEEL
How does it move, respond, sound and communicate state?
```

A recurring failure mode is to jump directly from 1 to 4:

```text
training mechanic exists
        ↓
make it look like a clipboard
```

while skipping:

```text
what does the player first see?
what are they trying to understand?
what has visual priority?
when do editing controls appear?
what confirms the edit?
what remains selected when they move elsewhere?
```

The Training Clipboard's old cold start is the canonical example: the mechanic and aesthetic both existed, but the arrival state did not.

---

# 7. Workspace interaction contract

Every primary workspace should eventually receive a small interaction contract. Do not treat this as another navigation hierarchy; it is a test for moment-to-moment legibility.

Template:

```text
WORKSPACE

ARRIVAL
What state does the player see first?

FIRST VISUAL FOCUS
What should their eye find first?

PRIMARY OBJECT
What thing are they actually manipulating or inspecting?

SECONDARY INFORMATION
What supports the primary object?

PRIMARY VERBS
What can be done here?

EDITING ENTRY
What deliberate action reveals deeper controls?

FEEDBACK
How does the object visibly confirm a change?

CONTEXT PRESERVATION
What subject / selection should survive entry from elsewhere?

CROSS-WORKSPACE LINKS
Where may the current subject travel without being lost?

EXIT / RETURN
What state remains when the player comes back?
```

Example for Training:

```text
WORKSPACE: Training Clipboard

ARRIVAL
current training plan

FIRST VISUAL FOCUS
next session + current work

PRIMARY OBJECT
current training sheet

SECONDARY INFORMATION
development assignments / tactical-comfort gaps

PRIMARY VERBS
inspect / edit tactics / edit development / prepare coordinated work

EDITING ENTRY
turn deliberately to Tactics or Development

FEEDBACK
current plan itself visibly changes

CONTEXT PRESERVATION
opening from Pāla's dossier may preselect Pāla in Development

CROSS-WORKSPACE
Calendar owns timing

EXIT
returning restores the same sheet / subject / local depth where practical
```

---

# 8. Visual hierarchy: object, state, context, action

At any ordinary moment, a polished workspace should make these questions easy to answer in order:

1. what am I looking at?
2. what is its current state?
3. what context matters?
4. what can I do?

Preferred reading order:

```text
OBJECT
  ↓
STATE
  ↓
CONTEXT
  ↓
ACTION
```

Suspect reading order:

```text
label | dropdown | stat | button | chart | tooltip | button
```

Dense interfaces are allowed. Hierarchy, not sparseness, is the requirement.

---

# 9. Progressive disclosure

Deep simulation does not require every control to be visible at once.

Prefer:

```text
Combination Play
      ↓
broad tactical structure
      ↓ inspect
individual asks
      ↓ inspect / edit
exact route / coordinate / tempo
```

The state remains one system. Depth is revealed as the player asks for it.

Do not manufacture `Basic Mode` and `Advanced Mode` versions of the same system unless the domain design specifically requires them. The existing training/tactics rule still applies: coarse and exact controls should be different views of the same authoritative state.

---

# 10. Context preservation

Cross-workspace navigation should carry context whenever the origin already supplies it.

Bad:

```text
Pāla dossier
    ↓
Training homepage
    ↓
select Pāla again
```

Preferred:

```text
Pāla dossier
    ↓
Training · Development
Pāla already selected
```

Other examples:

```text
candidate dossier
    ↓
Offer
same candidate remains the subject

fixture
    ↓
Lock-In
same fixture / opponent remains the subject

training gap
    ↓
Play Designer
relevant Voli / pair / situation already loaded
```

Rule:

> **Do not ask the player to re-enter information the interface already knows from the route they took.**

Contextual entry does not prevent the player from changing subject after arrival.

---

# 11. Action feedback

An action should change the represented object immediately and visibly.

Prefer:

```text
before
Pāla — Reception 2h

edit allocation

Pāla — Reception 3h
Iri  — Setting   1h
available training: 0h
```

over relying on:

```text
[Save]
Saved successfully.
```

A confirmation message may supplement the state change. It should not be the main proof that the action worked.

For physical interfaces, feedback can be material:

- a pin moves;
- a written mark changes;
- a sheet updates;
- a line redraws;
- a card changes position;
- an allocation visibly redistributes.

---

# 12. Transition choreography

Primary interfaces are physical objects in one career world. Navigation should therefore have coherent spatial / material transitions where practical.

Conceptual examples:

```text
Desk
  ↓
pick up clipboard

Clipboard
  ↓
turn to Tactics sheet

Tactics
  ↓
pull coordinated-work sheet / Play Designer forward

scheduled training begins
  ↓
planning object gives way to live drill presence
```

This does not require elaborate animation. Small consistent transitions can establish depth and continuity.

Avoid transitions that are visually decorative but contradict navigation semantics. `Back` should feel like reversing local depth; global travel should feel different from page-turning within one object.

---

# 13. Shared behavioral grammar

Workspaces may have different materials and layouts while still sharing stable interaction conventions.

Standardize, where relevant:

- selected Voli identity treatment;
- uncertainty / estimated / unknown presentation;
- clickable subject names;
- contextual cross-workspace links;
- destructive / irreversible action treatment;
- local Back behaviour;
- global workspace navigation;
- disabled / unavailable state;
- focus / hover / selected state;
- notification / interruption priority;
- manager-authored annotation treatment;
- staff-authored judgment treatment.

`ScreenShell` currently centralizes some visual anatomy. That is not enough by itself. The game also needs a shared **behavioral grammar**.

---

# 14. Design the non-happy states

A prototype often designs only the normal populated state. A polished UI defines what the player sees across the state space.

Every relevant workspace should explicitly handle cases such as:

```text
empty
nothing selected
one item
many items
unavailable
locked
unknown
estimated
stale
changed
unsaved
past deadline
no next fixture
no candidates
full corkboard
no staff
injured Voli
missing position
no training scheduled
appointment cancelled
subject no longer available
```

Do not fill empty states with generic explanatory prose if the physical object can communicate the absence directly.

---

# 15. Density rhythm

Different objects should have different natural densities.

- Journal may be very dense.
- Telephone may contain almost nothing.
- Corkboard should remain sparse enough that arrangement itself carries meaning.
- Training may alternate a quiet front sheet with a dense authoring page.

Within one screen, avoid giving every panel equal visual weight. Use hierarchy and breathing space so evidence, focal object and controls do not become one uninterrupted wall.

---

# 16. Microcopy names acts, not software operations

Prefer words that describe what the manager is doing in the fiction.

Stronger:

```text
Watch
Would sign
Open Calendar
Attend
Leave to staff
Call
Replay message
```

Weaker:

```text
Manage
Proceed
Submit
View details
Continue
```

Generic UI verbs are acceptable only when they genuinely name the act.

Avoid copy that tells the player what emotional or strategic conclusion to reach.

---

# 17. Motion and sound may carry state

Motion and sound are later polish layers, but they should communicate rather than decorate.

Potential examples:

- phone ring = live incoming contact;
- page turn = local navigation within Journal / Clipboard;
- pin landing = candidate annotation changed;
- pencil / marker sound = manager-authored note;
- clock-speed sound / motion change = 1× → fast-forward;
- sheet moving aside for live drill = planning has become presence;
- answering-machine playback = asynchronous contact rather than live conversation.

Do not use these as the sole carrier of essential information.

---

# 18. Implementation / review order

UI work should normally proceed in this order:

```text
1. MASTER UI FLOW
where does everything live?

2. WORKSPACE FLOW
what states can this object be in?

3. INTERACTION GRAMMAR
selection, editing, context, feedback, navigation

4. VISUAL / MOTION POLISH
typography, spacing, materials, animation, sound

5. EDGE-STATE PASS
non-happy-path states
```

A visually attractive mockup produced before 2 and 3 may still be useful for exploration, but it must not be mistaken for a finished interface design.

---

# 19. Cross-cutting tests

A proposed interaction is suspect if any of these are true:

- the live clock is justified mainly by mandatory routine clicks;
- essential information can be permanently missed only because the player fast-forwarded;
- watching provides no richer information than a static screen;
- ordinary speed exists but nothing changes visibly enough to reward observation;
- every Voli is reduced to a set of need bars requiring daily maintenance;
- the player is asked to select a subject again after arriving from that subject's contextual link;
- opening a workspace immediately implies the player must edit something;
- the primary object and primary action have equal visual weight before the object is understood;
- every control is visible because the mechanic supports it;
- the only evidence an action succeeded is a toast / status message;
- Back, global travel and local depth all use the same interaction language;
- the aesthetic metaphor is carrying a workflow that has not been designed;
- empty / unknown / unavailable states are treated as afterthoughts;
- animation or sound is required to perceive an essential state;
- polished appearance is being used as evidence of polished interaction.

The target is:

> **A player may efficiently skip routine, deliberately inhabit ordinary life, or move between the two as interest changes — and every major interface first makes the current reality legible, then makes changing it feel direct and specific.**
