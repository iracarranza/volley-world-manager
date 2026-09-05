# P6-C2 — Beginner Project Ladder

Status: **HISTORICAL LEARNING SEQUENCE**, not the active roadmap
Keywords: roadmap, beginner projects, vertical slices, simulation migration, shadow comparison, adapter boundary

## Prerequisites

- [P4-C5 Migration and Visible Proof](../part_04_match_engine/05_migration_and_visible_proof.md) — the real migration this reconstructs
- [P6-C1 Guided Exercises](01_guided_exercises.md) — smaller practice first

## How to read this chapter

These exercises reconstruct the migration in a safe teaching order.

> **Levels 1–7 already have implementations in the repository and must not be
> mistaken for current project tasks.** A learner may rebuild them in isolated
> tests. Active development follows the
> [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md).

### Why rebuild something that exists

Because the ladder teaches the *order*, and the order is the transferable part.
Each level makes the next one safe:

| Level | Cannot be done safely until |
|---|---|
| 2 seeded replay | 1 gives you something to look at |
| 3 laboratory | 2 lets you reproduce a case |
| 4 shadow comparison | 3 produces a persistent answer to compare |
| 5 live promotion | 4 has shown the answers agree |
| 6, 7 later contacts | 5 has proved the pattern once |

**Skipping a rung does not save time; it removes the evidence the next rung
rests on.** That is the entire argument for slice migration, learned by doing it.

---

## 1. Level 1: Read-only rally inspector — *implemented*

Display event sequence, type, actor, start/end positions and trajectory
duration after a rally.

**Teaches:** Resources, Arrays, Dictionaries and UI binding, without changing
simulation.

**Why first:** it is impossible to get wrong in a way that damages anything, and
it produces the instrument every later level reads.

---

## 2. Level 2: Fixed-seed scenario runner — *implemented*

Add a developer control for entering a seed and replaying it.

**Teaches:** deterministic debugging and safe scene-to-manager calls.

**Why here:** without reproduction, every later comparison is anecdote. See
[P3-C2 §2](../part_03_workflow/02_debugging_testing_and_git.md).

---

## 3. Level 3: Persistent reception laboratory — *implemented*

Build a test-only or developer-only view showing ball destination, player start
positions, arrival estimates and candidate reception opportunities.

**Do not replace live results yet.**

**Teaches:** the persistent models in isolation, where being wrong is free.

---

## 4. Level 4: Shadow simulation comparison — *implemented*

Run the legacy reception resolution and the persistent reception model from the
same inputs. **Log differences without changing the official result.**

**Teaches:** integration and observability.

**Why this is the pivotal rung:** it is the first level where the new model is
exposed to real rallies, and the only one where that exposure costs nothing. A
disagreement here is information; the same disagreement after promotion is a
bug report.

---

## 5. Level 5: Development-only live persistent reception — *implemented*

Use the new model for serve-to-reception, convert it to existing event records,
and leave later contacts on the legacy resolver.

This may require an **adapter boundary** or a controlled hybrid resolver.

**Teaches:** that the event contract is what makes a hybrid possible at all. The
playback layer must not be able to tell which resolver produced a contact.

---

## 6. Level 6: Second-contact opportunities — *implemented*

Generate normal and emergency setting options from pass flight and actual player
state.

**Teaches:** that the second contact is where "actual player state" starts to
bite — an emergency setter exists only because the normal one might not arrive.

---

## 7. Level 7: Attack approach and choice — *implemented through Gate 43*

Generate attack options from set timing, eligibility, approach state,
familiarity and opponent information.

**Teaches:** how many independent inputs a single decision can legitimately
have, and why each must be separately verifiable.

---

## 8. Level 8: User-facing decision explanations — *future*

Expose concise reasons for chosen, rejected, newly unlocked and high-risk
actions. Connect player development to visible tactical agency.

> This remains future product work, but **it is not the next engine gate**.
> Block observations and coordinated physical resolution must first produce
> trustworthy decision evidence to explain.

### 8.1 Why explanation comes last

An explanation is only as good as the evidence beneath it. Building the
explanation layer first would produce a system that reads convincingly and
sometimes lies — the failure
[P4-C4 §6](../part_04_match_engine/04_tactics_information_and_progression.md)
warns about, where a story is reverse-engineered from the outcome.

---

## 9. What the ladder teaches that the code does not

Reading the finished implementation shows you *what* was built. Walking the
ladder shows you **the order it had to be built in**, which is the part you will
need for the next system — and the next one is not reception.

Three transferable rules:

1. **Build the instrument before the thing you will measure with it** (1 → 3).
2. **Earn exposure before you take risk** (4 → 5).
3. **Explain last**, because an explanation inherits the credibility of its
   evidence (8).

---

## 10. Where this leads

- [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md) — the actual current objective
- [P4-C5 §5](../part_04_match_engine/05_migration_and_visible_proof.md) — the block slice, which is where the ladder's next rung really is
