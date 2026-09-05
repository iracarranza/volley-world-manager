# P4-C5 — Migration Plan and Visible Proof

Status: reception, setter, and attack have **DEVELOPMENT-ONLY GUARDED SLICES**;
production replacement remains off; attack-to-block perception is **NEXT**
Keywords: migration, vertical slice, shadow system, candidate audit, rollout policy, debug overlay, acceptance
Primary sources: `scripts/simulation/rally_state_builder.gd`; `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/rally_scheduler.gd`; `scenes/main/main.gd`; `scripts/simulation/rally_feature_flags.gd`

## Prerequisites

- [P4-C2 §5](02_persistent_rally_state.md) — why one contact at a time
- [P3-C1 §1.4](../part_03_workflow/01_safe_change_workflow.md) — the vertical slice

## Learning goals

After this chapter you should be able to:

1. describe the five stages a slice passes through before production;
2. list the slices and say what is live in each;
3. state the block slice's information constraint and why it is the hard part;
4. name the visible signs that a migration step is working;
5. explain why a debug overlay is stronger evidence than animation.

## Vocabulary

| Term | Meaning |
|---|---|
| **Vertical slice** | One closed span of a rally, migrated end to end. |
| **Shadow** | Computed and compared, but not authoritative. |
| **Candidate audit** | A check that a shadow decision used only information its actor could have. |
| **Rollout policy** | The guarded selection between legacy and persistent sources. |
| **Development-only** | Enabled by an explicit fixture flag; off in production. |
| **Foreknowledge** | Information the resolver has that an actor must not read. |

---

## 1. The migration principle

> Do not replace the whole rally at once. Migrate one closed vertical slice
> while **preserving the event playback contract**.

The second clause is what makes it safe. Playback keeps consuming the same event
shape whatever produced it, so a slice can change its source without the screen
knowing.

---

## 2. Slice 1: serve to reception

### 2.1 The nine steps

1. Build initial persistent state.
2. Resolve or import a serve trajectory.
3. Advance ball state and schedule its arrival.
4. Generate reception opportunities from current player states.
5. Select the claimant with a decision policy.
6. Advance the selected player's movement state.
7. Resolve reception contact and outgoing pass trajectory.
8. Emit serve and reception `RallyEvent` records.
9. **Compare with legacy behaviour using fixed seeds.**

### 2.2 Status

The complete reception slice now runs behind an audited development-only
rollout. **Production remains disabled.**

> Step 9 is the step that makes the other eight trustworthy. Without a
> fixed-seed comparison, "the new path works" is an impression.

---

## 3. Slice 2: reception to set

### 3.1 What it requires

The pass destination and arrival time must define second-contact opportunities.
The setter is **not automatically placed at a traditional spot**. An emergency
setter becomes possible when the normal setter cannot arrive, or took first
contact.

### 3.2 Status

Observation-only ownership decision, candidate audit, guarded rollout, and
development-only live contact through **Gate 36**. Attack and later contacts
remain on the legacy continuation.

---

## 4. Slice 3: set to attack

### 4.1 What it requires

Attack options arise from hitter approach state, set trajectory, eligibility,
tempo familiarity and opponent geometry. A pipe attack must begin from the
hitter's **actual back-row state** and meet its contact window.

### 4.2 Status

Perceived setter option ranking, repeated hitter reads, perceived defensive
targeting, candidate audit, guarded rollout, and a development-only live contact
through **Gate 42**.

**Gate 43** additionally makes responsibility-driven approach preparation active
in **ordinary** home attacks and defence-to-counterattack continuations. It
changes run-up speed, lateral control, jump conversion, quality and attack
availability; it does **not** enable the production continuous-attack flag.

> Gate 43 is worth noting as the pattern's exception: evidence promoted into
> ordinary play without promoting the contact itself. Not everything has to move
> at once, even within a slice.

---

## 5. Slice 4: attack to block — current next work

### 5.1 The information constraint

> Blockers must **not** receive the resolver's selected lane as private
> foreknowledge.

They should observe setter, ball and hitter cues over time; form individual
hypotheses; coordinate primary and assisting commitments; and then resolve their
movement and contact against authoritative attack truth.

### 5.2 Why this slice is the hard one

Because the resolver already knows where the attack is going, and a blocker is
standing right there. Every previous slice could read the ball, which is
legitimately visible. A block read is about **intent**, which is not — so the
audit has to prove a negative.

### 5.3 What must remain possible

The first implementation must be shadow-only and preserve official block event
identity. **Wrong commits, hesitation, solo blocks, coordinated assists and late
closes must remain possible and visible.**

A block system that never guesses wrong has been given foreknowledge.

The complete input boundary, test list and proposed Gate 44–49 sequence are in
the [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md#the-one-current-next-objective).

---

## 6. Visible signs that it works

### 6.1 The checklist

A correct implementation should make these observable in 2D playback and debug
output:

- the same actor begins the next movement from the previous resolved location;
- no unexplained snap to a default formation occurs mid-rally;
- ball arrival and player contact coincide;
- a late player is **visibly late** and the action is unavailable or degraded;
- different attributes can change the **candidate set**, not only the displayed
  quality;
- the same seed and inputs reproduce the same trace;
- each chosen action can display a reason and rejected alternatives.

### 6.2 The two that are easiest to fake

"A late player is visibly late" and "attributes change the candidate set" are
the ones a phase model cannot produce and a careless implementation will
approximate. If a late player still makes the play at reduced quality, the
window is not being enforced.

---

## 7. The debug overlay

### 7.1 What it should carry

Simulation time, ball state, ball destination and arrival, actor position and
intent, top opportunities, arrival margins, chosen action, and rejection
reasons.

### 7.2 What exists

The first overlay shows the true serve destination, each candidate's perceived
destination and path, reachability, arrival margin, legacy claimant, shadow
claimant, contact signature, and comparison reason.

### 7.3 Why it beats animation

> This is stronger evidence than animation alone. **Animation can look smooth
> while displaying an inconsistent simulation.**

Smoothness is a property of the drawing. The overlay shows the *decision*, which
is the thing being migrated. Compare [P7-C5](../part_07_art_and_assets/05_rendering_probes_and_validation.md):
there, the render is the evidence and the numbers cannot substitute. Here it is
the reverse. **Know which question you are asking.**

---

## 8. Historical continuity scenario: seed 1001

Keep seed 1001 as a manual continuity scenario, because transition set and pipe
movement were previously reported as suspicious after roughly ten seconds.

**Record the first inconsistent event** rather than depending on elapsed visual
time alone — the same rule as
[P3-C2 §1.2](../part_03_workflow/02_debugging_testing_and_git.md).

> This scenario is regression evidence, **not** the current roadmap. Current
> roadmap work starts from the attack-to-block observation contract in the
> handoff.

---

## 9. Common mistakes

| Mistake | Consequence |
|---|---|
| Migrating a slice without a fixed-seed comparison | "It works" is an impression |
| Letting a blocker read the selected lane | Blocks stop being readable as decisions |
| A block system that never misreads | It has foreknowledge |
| Judging a migration by how smooth it looks | Animation hides an inconsistent simulation |
| Timing a bug by elapsed visual seconds | You investigate a symptom, not an origin |

---

## 10. Check yourself

1. Why must playback's contract be preserved during migration? *(So a slice can change its source without the screen knowing.)*
2. Why is attack-to-block harder than reception? *(A ball is legitimately visible; intent is not, so the audit must prove a negative.)*
3. A late player still makes the play at reduced quality. What is wrong? *(The window is not being enforced.)*
4. Why is the overlay stronger evidence than animation? *(Animation can be smooth over an inconsistent simulation; the overlay shows the decision.)*
5. What is seed 1001 for, and what is it not? *(Regression evidence for a continuity bug; not current roadmap work.)*

---

## Where this leads

- [P4-C6 Adjusting and Extending Live Systems](06_adjusting_and_extending_live_systems.md) — working on what is already live
- [Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md) — the current slice and its acceptance contract
- [P3-C2 §4](../part_03_workflow/02_debugging_testing_and_git.md) — the balance probe as promotion evidence
