# Training Play Designer

## Status

Design authority for a visual training/tactics interface. This extends the existing training model rather than replacing it.

## 1. Purpose

Add a visual **Play Designer** training interface in which the manager can demonstrate coordinated volleyball structures directly on the court.

The interface represents:

> **what the manager wants the team to learn**

It does **not** script future rallies, author ball physics, or guarantee that players execute the demonstrated sequence.

The existing training model remains authoritative. Play Designer is a higher-level authoring interface that decomposes a demonstrated play into existing trainable units such as:

- hitter coordinates;
- hitter-setter tempo relationships;
- starting and transition positions;
- approach routes;
- defensive loci;
- blocking relationships/posture;
- option responsibilities.

## 2. Core Interaction

The manager begins from a volleyball situation rather than an empty tactics board.

Initial templates should include at minimum:

- **Serve Reception**
- **Dig / Transition**
- **Free Ball**

The court contains the selected rotation and actual Volis.

The manager can:

- reposition relevant Volis;
- draw movement/approach paths;
- establish intended attack locations;
- indicate desired tempo where necessary;
- identify attacking options;
- establish coverage/transition destinations where appropriate;
- replay and revise the demonstration.

The interface continuously loops the demonstrated sequence.

Routine volleyball actions are portrayed automatically:

`incoming ball -> reception/dig -> setter contact -> set -> attack`

The manager does **not** manually animate the ball or author contact points frame-by-frame. The ball exists to contextualize the tactical demonstration.

## 3. Intent, Not Choreography

A drawn path is an **instruction**, not a deterministic movement rail.

A demonstrated play means:

> "This is the structure I want us to create."

It does not mean:

> "Every Voli must occupy these coordinates at these timestamps regardless of rally state."

Actual execution remains governed by:

- physical feasibility;
- attributes;
- traits;
- learned familiarity;
- hitter-setter familiarity;
- pass quality;
- approach availability;
- current positioning;
- confidence/state;
- opponent behavior;
- setter judgment;
- authoritative rally physics.

If the demonstrated play becomes impossible, Volis adapt according to their actual decision systems.

## 4. Plays Are Option Structures

The Play Designer should strongly discourage designing predetermined set destinations.

For example, a manager may demonstrate:

- MB runs first tempo;
- OH runs an inside route;
- OP remains available at the pin.

This creates **three learned options**. It does not mean the setter must set the MB.

During a match, the setter chooses among viable options using the existing authoritative decision model.

A poor pass may remove the middle. A committed opposing blocker may make the opposite preferable. A repeatedly exposed lane may become expensive. A hitter in exceptional form may attract more volume.

The trained play establishes the team's shared vocabulary. The setter still plays volleyball.

## 5. Decomposition

The Play Designer must **not create a parallel tactical system**.

Saving a play decomposes the demonstration into the smallest existing authoritative trainable relationships.

Example:

```text
DRAWN PLAY

MB -> first-tempo route
OH -> inside approach
OP -> right-pin outlet
S  -> target release region

DERIVED TRAINING

MB:
  coordinate = X
  tempo = first
  setter relationship = S

OH:
  coordinate = Y
  route = inside
  tempo = medium
  setter relationship = S

OP:
  coordinate = Z
  tempo = high
  setter relationship = S

team:
  option structure = MB / OH / OP
```

If a demonstrated concept requires a trainable relationship that the underlying model cannot currently represent, implementation should expose that missing seam rather than store the drawing as independent gameplay authority.

## 6. Demonstration Versus Execution

The interface should eventually support two related views.

**Demonstration** shows the clean intended structure.

**Practice execution** shows the actual selected Volis attempting it.

These may differ.

A hitter unfamiliar with the requested coordinate may drift. A hitter-setter pair with poor tempo familiarity may mistime the route. A player may naturally prefer a different approach. A highly intelligent setter may salvage a broken structure.

This discrepancy is useful feedback, not animation error.

The manager should be able to learn:

> "The idea works, but these players don't understand it yet."

## 7. Training Effects

Practicing a drawn play should improve its **component relationships**, not a monolithic `play_familiarity` number.

Repeated practice might therefore improve:

- setter-middle first-tempo familiarity;
- hitter coordinate comfort;
- outlet familiarity;
- transition positioning;
- relevant coverage relationships.

Consequently, two lineups can know the "same play" differently.

Replacing the setter may preserve hitter coordinate familiarity while degrading tempo execution. Replacing the middle may preserve the structure while introducing a new pair relationship.

This is intended.

## 8. Emergent Learning

Match experience may alter learned behavior independently of manager instruction.

If a hitter repeatedly succeeds from a slightly different route or coordinate, that successful behavior may begin influencing their learned preference.

The Play Designer should eventually make this visible by contrasting:

**Designed route** vs **Observed / learned route**.

The manager can then reinforce the emergent variation or retrain the intended structure.

## 9. Scouting Interaction

Repeated use of a recognizable structure generates opponent evidence.

Scouting the play does not apply a direct effectiveness penalty. Instead, defenders become increasingly capable of anticipating its likely options. That changes their decisions and physical positioning.

The offense can then exploit that adaptation. A heavily scouted play may remain valuable because the movements themselves manipulate the defense.

Thus:

`train structure -> execute -> opponent observes -> opponent anticipates -> setter/hitters respond -> structure evolves`

## 10. Relationship to Individual Drills

The Play Designer does not replace existing direct training controls such as specifying when, where, or how a hitter should attack.

The two interfaces operate at different scales:

| Interface | Manager is teaching |
| --- | --- |
| Individual drill | "I want you comfortable attacking here, at this tempo." |
| Play Designer | "I want these Volis to create this option structure together." |

The Play Designer decomposes into the same underlying training authority used by individual drills. The two interfaces must never maintain competing versions of tactical truth.

## 11. UX Principle

The Play Designer should feel closer to **drawing volleyball on a whiteboard and then watching the team attempt it** than programming agents.

Avoid:

- frame timelines;
- animation keyframes;
- explicit ball trajectory editing;
- deterministic branching scripts;
- programming-style conditionals;
- numerical coordinate entry as the primary interface.

Direct manipulation of Volis and paths should be primary.

## 12. Authority Boundary

The Play Designer is an authoring and training interface downstream of existing simulation authority.

It may author managerial intent and training asks.

It may not:

- become rally physics authority;
- prescribe authoritative ball trajectories;
- force contacts;
- force setter destinations;
- bypass physical feasibility;
- create a second familiarity system;
- guarantee execution because a route was drawn.

The manager creates conditions and shared intentions. Volis still perceive, decide, adapt, and execute according to authoritative gameplay systems.