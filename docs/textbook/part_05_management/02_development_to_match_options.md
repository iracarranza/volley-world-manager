# P5-C2 — Connecting Development to Match Options

Status: **PROPOSED** integration model using verified player and rally systems
Keywords: progression, unlock, affordance, information, training feedback, option set
Primary sources: `scripts/models/volleyball_player.gd`; `scripts/systems/training_system.gd`; `scripts/systems/attribute_profile_system.gd`; `scripts/simulation/rally_movement_system.gd`

## Three outputs of development

Every meaningful development feature should answer:

- What new action becomes possible?
- What existing action becomes more reliable?
- What new information becomes visible or trustworthy?

Not every attribute must affect all three, but the full player-development system should produce all three types of benefit.

## Option-set comparison

**PROPOSED:** preserve a compact opportunity summary before and after training:

```text
Before
- receive line serve: late, unavailable
- receive seam serve: reachable, poor posture

After lateral-speed block
- receive line serve: reachable, narrow window
- receive seam serve: reachable, balanced posture
```

This gives the user causal feedback without exposing every coefficient.

## Information progression

Decision-making attributes should not magically change physical truth. They should affect which alternatives are recognized, how accurately risks are estimated, and whether an actor follows or abandons a plan when circumstances change.

Scouting and familiarity can reduce uncertainty. The interface can initially say “opponent may favor left pin,” then become more precise as evidence accumulates.

## Design test

When adding progression, compare two otherwise identical players around a threshold. If the only visible difference is a hidden two-percent outcome change, the feature probably needs clearer opportunity or information feedback.
