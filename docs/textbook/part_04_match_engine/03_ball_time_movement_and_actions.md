# P4-C3 — Ball Time, Movement, and Actions

Status: **PARTIALLY IMPLEMENTED**, with **PROPOSED** integration rules
Keywords: trajectory, arrival, movement, opportunity, feasibility, contact, continuous state
Primary sources: `scripts/models/ball_trajectory.gd`; `scripts/models/ball_contact_signature.gd`; `scripts/models/ball_flight.gd`; `scripts/models/ball_flight_estimate.gd`; `scripts/models/rally_ball_state.gd`; `scripts/models/action_opportunity.gd`; `scripts/models/action_opportunity_window.gd`; `scripts/models/rally_decision.gd`; `scripts/simulation/ball_read_system.gd`; `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/rally_opportunity_system.gd`; `scripts/simulation/rally_decision_system.gd`; `scripts/simulation/coverage_calculator.gd`

## Ball activity creates deadlines

A launched ball has a start time, duration, path, and destination. Its arrival time creates a deadline. Players do not move because the phase says “receive now”; they move because their prediction of the ball creates a target and a shrinking time window.

## Movement creates or removes actions

`RallyMovementSystem.estimate_movement()` evaluates travel from current state toward a target. `evaluate_opportunity()` combines movement with contact technique and timing. `generate_reception_opportunities()` produces candidate reception actions for multiple players.

The intended relationship is:

```text
distance + velocity + movement ratings + available time
                         ↓
                 arrival estimate
                         ↓
       contact window and body feasibility
                         ↓
              ActionOpportunity score
```

## Opportunity is not outcome

An opportunity says an action can be attempted and how favorable the setup is. It does not guarantee success. Contact skill, pressure, fatigue, ball difficulty, decision quality, and controlled randomness can still determine the resolved quality.

Separating opportunity from outcome makes player growth clearer. Speed may unlock the attempt; technique may improve the result; perception may help choose the correct attempt.

## True flight versus perceived flight

`BallContactSignature` records calculated speed, angles, signed topspin and
sidespin, and stability without simulating aerodynamic forces. `BallFlight`
stores the authoritative destination and arrival time. `BallReadSystem` produces
a player-specific `BallFlightEstimate` containing perceived destination,
perceived arrival, recognition time, confidence, and novelty.

This foundation is deterministic and tested, but it operates only in tests and
shadow calculations. It selects a diagnostic shadow receiver, not the receiver
used by the live rally.

## Verified development effect

The controlled Gate 10 fixture changes a complete reception profile while
holding paired serves and formations constant. Developing, established, and
elite profiles show monotonic increases in window duration, decision rate,
contact choices, and contact success. Elite profiles also unlock the
`quick_release_pass` choice that developing profiles never receive in the
fixture.

Exact conditions and measured values are recorded in
`docs/calibration/GATE_10_PLAYER_OPTIONS_AND_PROGRESSION.md`. Those measurements
describe the game fixture, not real-world performance standards.

## Trajectory continuity contract

Every contact should satisfy:

1. incoming ball position at contact time matches the contact location;
2. actor state reaches that location according to movement rules;
3. resolved action defines the outgoing ball trajectory;
4. the next opportunities derive from that outgoing trajectory;
5. playback's `outgoing_trajectory` is derived from the same resolved trajectory.

If playback invents a different trajectory, visible motion and simulated reality diverge.

## Needed systems

**Partially implemented in shadow reception:**

- `RallyOpportunitySystem`: schedules reception windows in a copied rally state.
- `RallyDecisionSystem`: ranks open reception options and grades the selected contact against ball truth.

**Still proposed:**

- `RallyContactSystem`: resolves contact quality and launches the next ball.
- `RallyRuleSystem`: enforces three contacts, double contacts, eligibility, rotation, net/out boundaries, and terminal outcomes.
- `RallyEventAdapter`: converts resolved state transitions to the existing playback contract.
- `RallyTrace`: records state, candidates, decisions, and reasons for debugging and user-facing analysis.

`BallReadSystem` is now a partially implemented foundation rather than a purely
proposed system. Its scalar familiarity argument must eventually be replaced by
experience with learned signature regions.

Keep these separate so movement does not quietly decide tactics and playback does not decide physics.
