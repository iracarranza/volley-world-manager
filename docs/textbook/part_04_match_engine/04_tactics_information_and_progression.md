# P4-C4 — Tactics, Information, and Progression

Status: current supporting systems **VERIFIED**; integration model **PROPOSED**
Keywords: tactics, familiarity, scouting, perception, progression, capability gate, hidden truth, preference
Primary sources: `scripts/models/offensive_play.gd`; `scripts/models/defensive_plan.gd`; `scripts/systems/familiarity_system.gd`; `scripts/systems/attribute_profile_system.gd`; `scripts/tactics/play_validator.gd`; `scripts/tactics/tactical_demand.gd`

## Prerequisites

- [P4-C3 Ball, Time, Movement and Actions](03_ball_time_movement_and_actions.md) — opportunities are what tactics choose among
- [P1-C1 §3](../part_01_project/01_what_you_are_building.md) — the legibility requirement this chapter serves

## Learning goals

After this chapter you should be able to:

1. name the three layers progression must touch, and say what happens if it touches only one;
2. explain a **capability gate** and what it shows the user;
3. separate **hidden truth** from **known information**, and say why the split is load-bearing;
4. explain why a tactical instruction is a preference rather than a script;
5. propose a progression effect that is visible rather than statistical.

## Vocabulary

| Term | Meaning |
|---|---|
| **Capability gate** | A reported requirement explaining why an option is available, marginal or absent. |
| **Familiarity** | Accumulated knowledge — of a system, a role, or an opponent. |
| **Hidden truth** | What the simulator knows. |
| **Known information** | What the user and players are entitled to act on. |
| **Preference** | An instruction that biases ranking rather than forcing an outcome. |
| **Tactical demand** | What a called play requires of the players executing it. |

---

## 1. The user needs options and information

### 1.1 The three layers

Player improvement should affect at least three:

1. **Physical possibility** — which locations the player can reach in time.
2. **Execution reliability** — how well a reachable action is performed.
3. **Decision information** — which opportunities, risks and opponent patterns
   are visible or correctly interpreted.

### 1.2 What happens if only one moves

> If progression changes only a final probability, the user may not feel agency.

A probability shift is real and invisible. It cannot be pointed at, so it cannot
be *decided about* — which makes the management loop advisory rather than causal.

Compare: unlocking an additional set, revealing a vulnerable seam, or making a
demanding defensive assignment viable. Each of these changes **what the user can
choose**, not just how a choice resolves.

---

## 2. Capability gates

### 2.1 The proposed shape

**PROPOSED:** each opportunity can report requirements and reasons:

```text
Pipe attack
- physically reachable: yes
- timing window: narrow
- familiarity requirement: satisfied
- setter accuracy requirement: marginal
- user-visible confidence: 62%
- alternative: high outside ball, 84%
```

### 2.2 What a gate is for

> The user need not see raw formulas. They should see **actionable
> differences**.

The last line does the most work. "62%" alone invites the user to gamble; "62%,
and here is an 84% alternative" invites them to *decide*. A gate that reports
only the chosen option has explained nothing.

### 2.3 Design constraint

A gate must report **why**, not merely *how much*. "Timing window: narrow" tells
the user what to change; "confidence 62%" does not.

---

## 3. Knowledge should be stateful

### 3.1 The distinctions to keep

`Familiarity` already supplies execution and read-related modifiers. The fuller
design should distinguish:

- team-system familiarity;
- player-role familiarity;
- opponent scouting confidence;
- in-match exposure and adaptation;
- individual perception and decision-making.

### 3.2 Hidden truth versus known information

> The simulator may know an opponent favours Zone 4; the user and players should
> only exploit that **to the degree scouting and recognition permit**.

This is the same boundary `BallReadSystem` enforces for one flight
([P4-C3 §4](03_ball_time_movement_and_actions.md)), applied to the whole match.
Break it and every opponent tendency becomes instantly and equally known, which
deletes scouting as a system.

### 3.3 The audit that protects it

The migration slices include an **information purity** check — did a decision
read something the deciding player could not know? That audit exists because the
boundary is easy to cross accidentally: the resolver has the truth in scope, so
using it is a one-line mistake.

---

## 4. Tactical instructions are preferences

### 4.1 The rule

An offensive play or defensive plan should influence **intent and decision
ranking**, not teleport players or guarantee a scripted contact.

### 4.2 What that produces

> A called quick attack can fail to become available if the pass or movement
> destroys its timing window. A disciplined setter may then choose the safest
> available alternative.

Both halves matter. The play can **fail to be available** — physics decides, not
the instruction. And the fallback is *chosen*, by a setter whose discipline is
an attribute, so two teams given the same instruction behave differently.

### 4.3 Why not scripted contacts

A guaranteed play would make the rally a playback of the plan, and every
attribute in §1's three layers irrelevant to it. Preferences keep the plan and
the players both causal.

---

## 5. Visible progression examples

Each of these is legible in the sense of
[P1-C1 §3](../part_01_project/01_what_you_are_building.md):

| Improvement | What the user sees |
|---|---|
| Transition speed | A previously late hitter enters the candidate list |
| Court vision | The secondary hitter is exposed as better against an adapted block |
| Familiarity | Uncertainty shown for a fast tempo narrows |
| Anticipation | Movement starts earlier, improving arrival posture |
| Ball control | **More viable targets**, not just higher success |

> **The pattern.** Every right-hand entry changes a *set of options*. None of
> them is "the number went up."

---

## 6. Required UI support

**PROPOSED:** the tactical UI should explain unavailable, risky and newly
available choices using short reasons. Post-rally analysis should identify the
decision and physical constraint that mattered, **using `RallyTrace` rather than
reverse-engineering a story from the final score**.

> That last clause is the important one. An explanation inferred from the
> outcome will be plausible and sometimes wrong, and there is no way for a
> reader to tell which. Evidence recorded at decision time cannot be
> retrofitted.

---

## 7. Common mistakes

| Mistake | Consequence |
|---|---|
| Progression that only shifts a probability | Invisible; the management loop stops feeling causal |
| A gate reporting confidence without alternatives | The user gambles instead of deciding |
| Reading hidden truth in a decision | Scouting becomes pointless |
| Scripting a called play | Attributes stop mattering to it |
| Explaining a rally from its score | Plausible, sometimes wrong, unfalsifiable |

---

## 8. Check yourself

1. Training raises `ball_control`. Give the legible effect. *(More viable target choices — not a higher success number.)*
2. Why must a capability gate show an alternative? *(Otherwise the user gambles rather than choosing between options.)*
3. The resolver knows the opponent favours Zone 4. Who may act on it? *(Only to the degree scouting and recognition permit.)*
4. A called quick attack does not happen. Bug? *(Not necessarily — the pass or movement may have destroyed its window; the play is a preference.)*
5. Why must post-rally analysis use `RallyTrace`? *(An explanation inferred from the score is plausible, sometimes wrong, and unfalsifiable.)*

---

## Where this leads

- [P4-C5 Migration and Visible Proof](05_migration_and_visible_proof.md) — the information-purity audit in practice
- [P5-C2 Development to Match Options](../part_05_management/02_development_to_match_options.md) — progression from the management side
- [`SCOUTING.md`](../../design/SCOUTING.md) — what a report means, in full
