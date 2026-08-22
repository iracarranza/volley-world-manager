# 04 — Club Operations and the Desk

Status: **MIXED VERIFIED / PARTIALLY IMPLEMENTED BY SUBSYSTEM**

VWM's management layer is increasingly organized around the manager's physical/diegetic workspace: journal, clipboard, scouting board/folders, housing, kitchen/meal plan, phone/answering machine and related club services.

The architecture goal is not “make every menu look like an object.” It is:

> make long-term club problems legible as things the manager can understand, revisit and act on.

## Desk object versus management system

The desk itself only routes to systems/screens. The underlying facts live elsewhere.

Examples:

```text
training clipboard
→ training/schedule systems

scouting board/folders
→ scouting/world/offer systems

housing folder
→ accommodation/care data + career state

meal plan/kitchen
→ food supply/palate state

phone / answering machine
→ communication/event systems as implemented
```

Do not put accommodation calculations into `DeskScreen` because the housing folder is drawn there.

## Housing is persistent club state

`CareerState.housing_structure` and related accommodation data represent what the club leases/provides rather than only a creation-time “club type” label.

This is a useful management design shift:

```text
abstract category: Established Club
→ persistent operational facts: housing, money, staff, roster, services
```

Those concrete facts can create decisions and visible consequences.

## Food/palate state

`CareerState.palate_clock` persists food-related adaptation/history rather than keeping it as an unsaved manager variable.

Players also carry `palate_regions` as categorical familiarity.

The design preference is readable state:

```text
comfortable with Landavol / Xérvu food
```

rather than a mysterious `foreign_food_tolerance = 0.63` when the categorical history is what the manager can understand.

## Staff is part of the club, not a screen

Staff Resources live in career state and can carry familiarity/development of their own.

Scouting quality, services and future staff systems should read those persistent staff objects.

A staff screen may display/edit decisions, but closing it should not remove the employees.

## Contractors and services

Design docs describe additional club-service/contractor directions. Treat each as its own management subsystem with:

- durable contract/state owner;
- recurring cost/benefit mechanism;
- clear schedule/event integration;
- manager-facing screen/object.

Do not implement service effects as one-time UI buttons if the fiction is a continuing contract.

## Diegetic readability over forced prose

A strong VWM screen should show state the manager can interpret rather than telling the player what to think.

For example, prefer:

```text
cookbook · in 5 rooms
```

or a visible lease/equipment fact over narrative text insisting “the squad will remember what you did.”

The system should create the consequence; the interface should show evidence.

## The desk is a hub, not the only navigation possible

Some screens can link directly to related screens where the relationship is itself meaningful (training ↔ daily schedule, lock-in ↔ match). The desk provides a stable home state, not a rule that every transition must bounce through it.

Navigation should follow the task while preserving the room/document metaphor.

## Operational systems should meet match systems through player/team state

Housing/food/staff care should not directly add `+5% kill chance`.

A more interpretable path is:

```text
operational condition
→ player/team state (fatigue, satisfaction, availability, familiarity, etc.)
→ existing match mechanisms consume that state
```

Only add a new match-facing variable when the existing model genuinely cannot express the consequence.

## Scope honesty

The design directory contains ambitious specifications for club life, accommodations, contractors, diegetic management and related world systems. Not all prose in those docs is guaranteed to be fully live.

When implementing from this chapter:

1. inspect current source first;
2. label absent behavior **PROPOSED**;
3. reuse persistent state that already exists;
4. do not make a design document's illustrative example into an undocumented constant.

## Safe extension example: equipment service

A robust path might be:

```text
career owns contract/equipment assignment
→ service system applies weekly/conditional consequence
→ report records it
→ screen displays current equipment and effect
→ relevant player/team state changes
→ match/training reads that state if appropriate
```

Avoid:

```text
click equipment card
→ mutate attack_power immediately
```

unless that is explicitly the designed mechanic.

## Reading exercise

Choose housing or food.

Trace:

- current persistent field(s);
- system/data module;
- screen/desk entry;
- save path;
- any actual player/team consequence.

Separate what is live from what the design document proposes next.

## Source trail

- `scenes/screens/desk_screen.gd`
- `scripts/models/career_state.gd`
- `scripts/managers/career_manager.gd`
- `scripts/data/accommodation.gd`
- `scripts/data/food_supply.gd`
- staff models/systems
- `docs/design/CLUB_LIFE.md`
- `docs/design/ACCOMMODATIONS_AND_CARE.md`
- `docs/design/CONTRACTORS_AND_SERVICES.md`
- `docs/design/DIEGETIC_MANAGEMENT.md`

Next: the final causal chain—how any management decision earns its place by changing something the match engine can actually observe.