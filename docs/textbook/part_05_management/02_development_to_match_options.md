# P5-C2 — Connecting Development to Match Options

Status: **PROPOSED** integration model using verified player and rally systems
Keywords: progression, unlock, affordance, information, training feedback, option set, development project, latent potential, role projection
Primary sources: `scripts/models/volleyball_player.gd`; `scripts/systems/training_system.gd`; `scripts/systems/attribute_profile_system.gd`; `scripts/simulation/rally_movement_system.gd`

## Product fantasy

The fantasy is not “change positions.” It is:

> See what an athlete could become before anyone else does.

The manager should identify ingredients before a future role becomes obvious:

```text
Tactical Need + Latent Potential + Opportunity = Development Project
```

- **Tactical need:** a responsibility the system lacks, such as a blocking
  setter, six-rotation outside, transition middle, or defensive specialist.
- **Latent potential:** physical, technical, cognitive, and personality traits
  that could support that responsibility even when the current position does not.
- **Opportunity:** coaching time, match repetitions, roster space, and a system
  willing to tolerate the learning period.

The important question is not “can this athlete play that position today?” It
is “does this athlete have the ingredients to become what the system needs?”

## Development projects rather than direct position training

**PROPOSED:** players undertake multi-season projects such as Future Setter,
Six-Rotation Outside, Blocking Opposite, Transition Middle, Defensive
Specialist, or Offensive Libero. Projects train responsibilities and playstyle
components first. A new primary role or position is a possible later result,
not the button the player presses at the beginning.

Examples:

- A tall, vocal, coachable but technically raw recruit develops toward setter
  because the team needs a blocking setter.
- An attacking-only outside invests in serve receive, floor defense, and
  transition play until remaining on court for six rotations becomes viable.
- A reserve outside with elite anticipation but limited offense gradually
  becomes a defensive specialist.
- In another sport, an intelligent, disciplined young winger might be redirected
  toward an inverting fullback role when the tactical system lacks one.

Scouting should therefore show developmental projections separately from
current position, for example a current Outside Hitter with stronger projected
fit at Blocking Opposite than Libero. These projections must be uncertain and
evidence-based; they are not guaranteed destiny.

The rally simulator supplies the eventual proof layer. Development should alter
recognition, available actions, physical envelopes, responsibilities, and
execution in ways the manager can observe—not merely change a position label.

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
