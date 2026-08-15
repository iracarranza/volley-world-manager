# Abstraction and manifestation

A cross-cutting interface rule for systems whose **physical reality matters**.

The game repeatedly needs to show the same thing at two scales:

- a compact representation the manager can actually work on;
- an embodied version where the consequences of that work can be seen.

The match centre already points at this split. Training/drills and accommodation
should use the same principle without becoming the same interface.

---

## 0. The rule

> **2D compresses reality into manager intent. 3D manifests that intent as
> embodied state.**

### 2D — abstraction, control, intent

The 2D view is the authoritative workspace for:

- plans;
- assignments;
- tactical responsibilities;
- comparisons;
- adjustments;
- direct functional input.

It exists because a manager needs a representation simple enough to reason on.

### 3D — manifestation, observation, diagnosis

The 3D view is primarily for:

- seeing what instructions physically became;
- reading spacing, bodies, place and movement;
- noticing emergent behaviour;
- diagnosing why an abstraction is or is not working;
- enjoying character and environment at the scale where they actually live.

The 3D view is **not authoritative input**. It should not become a second set of
controls for the same system.

It is also not merely cosmetic. An observational projection can teach the player
something real even when it does not generate the simulation state itself.

---

## 1. The three current cases

| system | 2D | 3D |
|---|---|---|
| **match** | tactical/analytical match centre; adjustments | broadcast-like court view of the realised rally |
| **drills** | the playable demonstration/mini-game where the manager expresses a pattern | watch the actual squad perform the idea with their bodies and timing |
| **housing** | schematic rooms, occupants, equipment, assignments and future changes | observe the home being inhabited and diagnose whether the living arrangement is actually working |

The symmetry is intentional. The interfaces should not literally share layout or
controls; they share a relationship between **representation and reality**.

---

## 2. The match centre is the precedent

**The object keeps its name.** "Match centre" is the desk identity and does not
change; what changes is the *technical* vocabulary inside it. The distinction is
internal to the match centre — an embodied court presentation, an analytical
presentation, and the adjustment controls — rather than a new screen or a
rename of an existing one.

What should go is player-facing engine language. Two strings carry it today:

| where | reads |
|---|---|
| `scenes/screens/match_screen.tscn:101` | `3D MATCH ENGINE` |
| `scenes/screens/journal_screen.tscn:334` | `3D VIEW` |

Both name the implementation rather than the activity. It should read like a
volleyball broadcast or a court view.

The important distinction is not a graphics setting:

- **Court / broadcast view** — embodied volleyball.
- **Tactical / analytical view** — compressed volleyball the manager can act on.

The 3D court is technically optional, but it has a purpose: spacing, approach
geometry, block timing, body position and responsibility can often be understood
more quickly by watching than by reading a number.

This is especially important while the fidelity work is active. A 3D view that
lies about where a body could have been is not decoration; it is a bad diagnostic
instrument.

---

## 3. Drills make the loop explicit

The intended drill loop is:

```
ABSTRACT
manager demonstrates/builds the desired pattern in 2D
    ↓
EMBODIED
actual volis perform it
    ↓
DIAGNOSE
see what the roster can and cannot physically execute
    ↓
ABSTRACT
change the instruction
```

Examples of things a 3D drill may reveal that the 2D idea did not:

- the middle cannot arrive on the requested timing;
- the setter has to plant awkwardly;
- a hitter's body blocks a lane;
- a responsibility creates a physically bad approach;
- a supposedly strange idea works because a particular voli's body makes it
  viable.

The 2D mini-game is still where most functional interaction lives. The 3D view
shows what those instructions mean on a court.

---

## 4. Housing uses topology, not floor-plan fidelity

Accommodation is the hard case because a building is not a fixed volleyball
court. A Bunkhouse, Commons, Longhouse, Row, Farmhouse and Block can have
completely different literal geometry.

Do **not** solve this by making the manager read or edit architectural floor
plans.

> **The 2D housing view preserves social and functional topology, not literal
> architectural geometry.**

The schematic needs to answer:

- who shares a room;
- what equipment is in it;
- how much usable floor remains;
- which spaces are shared;
- which rooms/people are functionally connected;
- what the structure permits or discourages.

It does not need to preserve which wall is six metres north of another wall.
The 3D scene owns literal place.

### Different structures may use different diagram grammars

This is useful rather than a problem because the schematic can teach the
structure's social logic.

- **Bunkhouse** — repeated paired room cards; dense, local relationships.
- **Commons** — rooms arranged around a central shared-space node.
- **Longhouse** — one continuous communal strip with weak private divisions.
- **Row** — deliberately separated private units.
- **Farmhouse** — kitchen/garden/home space as the obvious centre.
- **Block** — stacked floor bands with many occupants and weak cross-group
  connection.

These are management diagrams, not blueprints.

---

## 5. Meaning must match even when geometry does not

The two views do not need one-to-one visual geometry. They need one-to-one
**causal meaning**.

If the 2D view says:

> Room 3: Pāla + Iri, games console, one floor remaining, connected to the
> Commons

then the 3D world must make those facts true.

It does not matter whether Room 3 is drawn on the left of the schematic but
exists upstairs on the right of the literal building.

A mismatch in **meaning** is a bug. A mismatch in projection is not.

---

## 6. Optional observation cannot hide mandatory information

The 3D view should reward attention without making attendance compulsory.

Hard rule:

> **Anything necessary to manage competently must eventually become legible in
> 2D, through staff communication, or through the club's records.**

Watching may reveal it earlier or more intuitively.

Housing example:

- 3D: the manager notices Pāla spends every free block alone.
- Later without 3D: Pāla says they feel isolated, a roommate mentions it, or the
  pattern becomes visible in the housing/social readout.

Volleyball example:

- 3D: the block close visibly looks late and leaves a seam.
- 2D/data: repeated seam exposure and late responsibility become measurable.

The observant player gets intuition. The analytical player gets evidence. Same
simulation.

---

## 7. Presence is an action, not an overworld

Do not invent an "outside mode" solely to justify visiting accommodation.

The reusable action is **being physically present for something that is
happening**:

- attend training;
- watch/attend a drill;
- attend a match;
- visit the current home;
- attend a team meal or social event;
- meet a recruit.

These may be contextual scenes. VWM does not need a walkable club/town merely to
connect them spatially.

The desk works with **representations**. Presence shows **the thing itself**.

That distinction may eventually support a small club overview if several real
locations earn it, but no map should be built in anticipation of content.

---

## 8. Presentation vocabulary

Avoid exposing the implementation as:

> 2D MODE / 3D MODE

Use activity-native language instead.

Possible examples, not canonical labels:

- Match: **Court** / **Tactical View**
- Drill: **Watch Drill** / **Drill Board**
- Housing: **Visit Home** / **Rooms**

The underlying relation is shared; the fiction and verbs remain specific to the
activity.

---

## 9. Connection to diegetic management

This document is the visual/interaction counterpart of
`DIEGETIC_MANAGEMENT.md`'s **management with presence** principle.

The 2D layer keeps deep simulation manageable.
The 3D layer keeps that management attached to bodies, spaces and people.

The goal is not spectacle. It is a reversible translation:

> **managerial abstraction → embodied consequence → better managerial
> understanding.**
