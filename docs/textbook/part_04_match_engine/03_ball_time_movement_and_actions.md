# P4-C3 — Ball Time, Movement, and Actions

Status: **PARTIALLY IMPLEMENTED**, with **PROPOSED** integration rules
Keywords: trajectory, arrival, deadline, movement, opportunity, feasibility, perception, continuity contract
Primary sources: `scripts/models/ball_trajectory.gd`; `scripts/models/ball_contact_signature.gd`; `scripts/models/ball_flight.gd`; `scripts/models/ball_flight_estimate.gd`; `scripts/models/action_opportunity.gd`; `scripts/simulation/ball_read_system.gd`; `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/rally_opportunity_system.gd`; `scripts/simulation/rally_decision_system.gd`; `scripts/simulation/coverage_calculator.gd`

## Prerequisites

- [P4-C2 Persistent Rally State](02_persistent_rally_state.md) — the models this chapter puts in motion
- [P3-C2 §2](../part_03_workflow/02_debugging_testing_and_git.md) — determinism, which the perception layer depends on

## Learning goals

After this chapter you should be able to:

1. explain why a ball creates a **deadline** rather than a cue;
2. distinguish **opportunity** from **outcome**, and say why the split matters for player growth;
3. distinguish **true flight** from **perceived flight**, and name what separates them;
4. state the five-step trajectory continuity contract;
5. read the implemented/required list and place a proposed change in it.

## Vocabulary

| Term | Meaning |
|---|---|
| **Deadline** | The arrival time a launched ball imposes on everyone who might play it. |
| **Opportunity** | A possible action, with timing and feasibility. Not a prediction of success. |
| **Window** | The interval during which a projected action stays available. |
| **`BallFlight`** | Authoritative destination and arrival time. Truth. |
| **`BallFlightEstimate`** | One player's *belief* about destination and arrival. |
| **Recognition time** | How long before a player has read the flight at all. |
| **Novelty** | How unfamiliar this flight is to this player. |
| **Continuity contract** | The five conditions every contact must satisfy. |

---

## 1. Ball activity creates deadlines

### 1.1 The reframe

A launched ball has a start time, duration, path and destination. Its arrival
time creates a **deadline**.

> Players do not move because the phase says "receive now"; they move because
> their prediction of the ball creates a target and a shrinking time window.

### 1.2 Why this is the whole model in one sentence

Everything else follows. A deadline is a quantity, so it can be compared against
a traversal time, which is also a quantity — and the comparison is what makes
an action possible or impossible. No phase needs to grant permission.

---

## 2. Movement creates or removes actions

### 2.1 The chain

```text
distance + velocity + movement ratings + available time
                         ↓
                 arrival estimate
                         ↓
       contact window and body feasibility
                         ↓
              ActionOpportunity score
```

### 2.2 The functions

- `RallyMovementSystem.estimate_movement()` — travel from current state toward a target;
- `evaluate_opportunity()` — movement combined with contact technique and timing;
- `generate_reception_opportunities()` — candidate reception actions for multiple players.

### 2.3 Body feasibility is not just arrival

Arriving is necessary and not sufficient. A body arriving `DIVING` has a
different contact envelope than one arriving `BALANCED`, and one already
`AIRBORNE` cannot take off again. See
[P7-C1](../part_07_art_and_assets/01_the_voli_body.md) for how the drawn body
expresses the same states.

---

## 3. Opportunity is not outcome

### 3.1 The distinction

An opportunity says an action **can be attempted** and how favourable the setup
is. It does not guarantee success. Contact skill, pressure, fatigue, ball
difficulty, decision quality and controlled randomness can still determine the
resolved quality.

### 3.2 Why the split makes growth legible

Separating them lets three different attributes do three different jobs:

| Attribute family | Changes |
|---|---|
| Speed, acceleration | Whether the attempt exists at all |
| Technique, control | How well the attempt resolves |
| Perception, decision | Which attempt is chosen |

This is [P1-C1 §3](../part_01_project/01_what_you_are_building.md)'s legibility
requirement, made structural. A single "dig chance" number could not express it.

---

## 4. True flight versus perceived flight

### 4.1 The three models

| Model | Holds |
|---|---|
| `BallContactSignature` | Calculated speed, angles, signed topspin and sidespin, stability — **without** simulating aerodynamic forces |
| `BallFlight` | The authoritative destination and arrival time |
| `BallFlightEstimate` | One player's perceived destination, perceived arrival, recognition time, confidence and novelty |

`BallReadSystem` converts the first two into the third, per player.

### 4.2 Why perception is a separate model

Because a player acting on truth is a player who cannot be deceived. Every
disguise, every read, every "he was going the other way" depends on the estimate
being allowed to be **wrong** in a principled, deterministic way.

### 4.3 Status

This foundation is deterministic and tested. Reception, setter and attack use it
in shadow calculations and may promote audited contacts only in an explicitly
requested development fixture. **Ordinary production flags remain off.**
Approach mechanics also consume persistent-style movement evidence in normal
home attacks, but the complete rally is not yet one persistent loop.

### 4.4 A known limitation

`BallReadSystem`'s scalar familiarity argument must eventually be replaced by
**experience with learned signature regions** — that is, familiarity with *this
kind of ball*, not one number.

---

## 5. Verified development effect

### 5.1 What Gate 10 showed

The controlled Gate 10 fixture changes a complete reception profile while
holding paired serves and formations constant. Developing, established and elite
profiles show **monotonic increases** in window duration, decision rate, contact
choices and contact success. Elite profiles also unlock the `quick_release_pass`
choice that developing profiles never receive in the fixture.

### 5.2 What it does and does not claim

Exact conditions and measured values are in
`docs/calibration/GATE_10_PLAYER_OPTIONS_AND_PROGRESSION.md`.

> Those measurements describe **the game fixture**, not real-world performance
> standards.

This distinction is the reason the gate is quotable at all. A measurement whose
scope is stated can be relied on; one that quietly implies more cannot.

---

## 6. The trajectory continuity contract

### 6.1 The five conditions

Every contact should satisfy:

1. incoming ball position at contact time matches the contact location;
2. actor state reaches that location according to movement rules;
3. resolved action defines the outgoing ball trajectory;
4. the next opportunities derive from that outgoing trajectory;
5. playback's `outgoing_trajectory` is derived from the same resolved trajectory.

### 6.2 What each one prevents

| Condition | Prevents |
|---|---|
| 1 | A contact made where the ball is not |
| 2 | A player teleporting to the ball |
| 3 | An outgoing flight unrelated to the contact |
| 4 | A next phase that ignores where the ball went |
| 5 | Drawn motion diverging from simulated reality |

> **Condition 5 is the one that fails quietly.** If playback invents a different
> trajectory, visible motion and simulated reality diverge — and the screen is
> what people trust.

---

## 7. Implemented, and still required

### 7.1 Partially integrated

- `RallyOpportunitySystem` schedules reception windows in copied rally state;
- `RallyDecisionSystem` ranks perceived reception options;
- `ShadowSetterResponseSystem` and `ShadowAttackSystem` extend observation and
  movement through second and third contacts;
- `RallyContactSystem`, `RallyPlaybackAdapter` and `RallyTrace` exist for
  bounded slices — **not yet universal rally services**;
- `ApproachMechanicsSystem` makes responsibility release and run-up evidence
  causal for home attack availability and quality.

### 7.2 Still required

- player-specific, coordinated block observations and commitments;
- persistent opponent-side reception, offence and transition decisions;
- a universal rule system for contacts, eligibility, rotation, net/out
  boundaries and terminal outcomes;
- a single scheduler-driven resolver replacing the remaining phase flow;
- user-facing explanations derived from decision evidence rather than inferred
  afterward.

### 7.3 The separation to preserve

> Keep these separate so **movement does not quietly decide tactics** and
> **playback does not decide physics**.

Both failures look like a small convenience at the time. A movement system that
picks the claimant has become a tactical system; a playback layer that smooths a
discontinuity has become a physics system, and a wrong one.

---

## 8. Common mistakes

| Mistake | Consequence |
|---|---|
| Letting a player act on `BallFlight` truth | Nobody can ever be deceived |
| Treating opportunity as probability of success | Growth stops being legible |
| Smoothing a trajectory gap in playback | Drawn motion diverges from simulation |
| Letting movement choose the claimant | Movement has silently become tactics |
| Quoting a gate figure as a real-world standard | It describes a fixture |

---

## 9. Check yourself

1. Why does a ball create a deadline rather than a cue? *(Its arrival time is a quantity comparable with traversal time; no phase must grant permission.)*
2. Which attribute family decides whether an attempt exists at all? *(Speed and acceleration — technique changes the result, not the existence.)*
3. Why must perception be a separate model from truth? *(A player acting on truth cannot be deceived; disguise depends on principled error.)*
4. Which continuity condition fails most quietly, and why? *(5 — the screen is what people trust, so divergence is believed.)*
5. What does Gate 10 measure? *(The game fixture — explicitly not real-world performance standards.)*

---

## Where this leads

- [P4-C4 Tactics, Information and Progression](04_tactics_information_and_progression.md) — how a choice is made among opportunities
- [P4-C5 Migration and Visible Proof](05_migration_and_visible_proof.md) — how shadow systems prove themselves
- [P4-C6 Adjusting and Extending Live Systems](06_adjusting_and_extending_live_systems.md) — changing any of this safely
