# P5-C2 — Connecting Development to Match Options

Status: **PROPOSED** integration model using verified player and rally systems
Keywords: progression, unlock, affordance, information, training feedback, option set, development project, latent potential, role projection
Primary sources: `scripts/models/volleyball_player.gd`; `scripts/systems/training_system.gd`; `scripts/systems/attribute_profile_system.gd`; `scripts/simulation/rally_movement_system.gd`

## Prerequisites

- [P5-C1 Career, Roster and Training](01_career_roster_and_training.md) — the systems this proposes to build on
- [P4-C4 Tactics, Information and Progression](../part_04_match_engine/04_tactics_information_and_progression.md) — the match side of the same loop

## Learning goals

After this chapter you should be able to:

1. state the product fantasy and the three ingredients of a development project;
2. explain why projects train **responsibilities**, not position labels;
3. apply the three-outputs test to a proposed development feature;
4. describe an option-set comparison and what it gives the user;
5. apply the design test that catches an invisible progression feature.

## Vocabulary

| Term | Meaning |
|---|---|
| **Development project** | A multi-season programme training responsibilities toward a possible future role. |
| **Latent potential** | Traits that could support a responsibility the current position does not use. |
| **Tactical need** | A responsibility the system lacks. |
| **Role projection** | An uncertain, evidence-based estimate of future fit. |
| **Option set** | The actions available to a player in a situation. |
| **Affordance** | What a player's body and skill make possible, before skill decides quality. |

## 1. Product fantasy

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

## 2. Development projects rather than direct position training

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

## 3. Three outputs of development

Every meaningful development feature should answer:

- What new action becomes possible?
- What existing action becomes more reliable?
- What new information becomes visible or trustworthy?

Not every attribute must affect all three, but the full player-development system should produce all three types of benefit.

## 4. Option-set comparison

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

## 5. Information progression

Decision-making attributes should not magically change physical truth. They should affect which alternatives are recognized, how accurately risks are estimated, and whether an actor follows or abandons a plan when circumstances change.

Scouting and familiarity can reduce uncertainty. The interface can initially say “opponent may favor left pin,” then become more precise as evidence accumulates.

## 6. Design test

When adding progression, compare two otherwise identical players around a threshold. If the only visible difference is a hidden two-percent outcome change, the feature probably needs clearer opportunity or information feedback.

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| Training a position label directly | Skips the responsibilities that make the role real |
| A projection presented as certain | Scouting stops being a judgement and becomes an oracle |
| Progression that only raises success rate | Fails the design test in section 6 |
| Decision attributes changing physical truth | A smart player becomes a fast one |
| Showing coefficients instead of options | Explains the formula, not the decision |

---

## 8. Check yourself

1. What are the three ingredients of a development project? *(Tactical need, latent potential, opportunity.)*
2. Why train responsibilities rather than a position? *(A position label is a result; the responsibilities are what actually transfer.)*
3. Name the three outputs every development feature should be tested against. *(A new action possible, an existing action more reliable, new information visible or trustworthy.)*
4. A decision attribute improves. What may it change, and what may it not? *(Which alternatives are recognised and how risks are estimated; not physical truth.)*
5. Two players either side of a threshold differ only by a hidden 2% outcome shift. What does the design test say? *(The feature needs clearer opportunity or information feedback.)*

---

## Where this leads

- [P4-C3 §3](../part_04_match_engine/03_ball_time_movement_and_actions.md) — opportunity versus outcome, which this chapter depends on
- [`SCOUTING.md`](../../design/SCOUTING.md) — uncertainty and what a report means
- [`TRAITS.md`](../../design/TRAITS.md) — latent potential as a first-class thing
