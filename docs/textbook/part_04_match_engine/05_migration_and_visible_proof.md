# P4-C5 — Migration Plan and Visible Proof

Status: shadow reception and its 2D inspector are **PARTIALLY IMPLEMENTED**;
live replacement remains **PROPOSED**
Keywords: migration, reception slice, debug overlay, visible sign, acceptance tests
Primary sources: `scripts/simulation/rally_state_builder.gd`; `scripts/simulation/rally_movement_system.gd`; `scripts/simulation/rally_scheduler.gd`; `scenes/main/main.gd`

## Do not replace the whole rally at once

Migrate one closed vertical slice while preserving the event playback contract.

## Slice 1: serve to reception

1. Build initial persistent state.
2. Resolve or import a serve trajectory.
3. Advance ball state and schedule its arrival.
4. Generate reception opportunities from current player states.
5. Select the claimant with a decision policy.
6. Advance the selected player's movement state.
7. resolve reception contact and outgoing pass trajectory.
8. emit serve and reception `RallyEvent` records.
9. compare with legacy behavior using fixed seeds.

Steps 1–5 and 9 now run as a non-authoritative shadow comparison on opponent
serves. `ShadowReceptionSystem` records candidates in `RallyTrace`, and debug
builds display the comparison. Replacing the live contact has not begun.

## Slice 2: reception to set

The pass destination and arrival time must define second-contact opportunities. The setter is not automatically placed at a traditional spot. An emergency setter becomes possible when the normal setter cannot arrive or took first contact.

## Slice 3: set to attack

Attack options arise from hitter approach state, set trajectory, eligibility, tempo familiarity, and opponent geometry. A pipe attack must begin from the hitter's actual back-row state and meet its contact window.

## Visible signs that it works

A correct implementation should make these observable in 2D playback and debug output:

- the same actor begins the next movement from the previous resolved location;
- no unexplained snap to a default formation occurs mid-rally;
- ball arrival and player contact coincide;
- a late player is visibly late and the action is unavailable or degraded;
- different attributes can change the candidate set, not only the displayed quality;
- the same seed and inputs reproduce the same trace;
- each chosen action can display a reason and rejected alternatives.

## Debug overlay fields

Add a developer-only overlay or log with simulation time, ball state, ball destination and arrival, actor position and intent, top opportunities, arrival margins, chosen action, and rejection reasons.

The first overlay now shows the true serve destination, each candidate's
perceived destination and path, reachability, arrival margin, legacy claimant,
shadow claimant, contact signature, and comparison reason.

This is stronger evidence than animation alone. Animation can look smooth while displaying an inconsistent simulation.

## Acceptance scenario: seed 1001

Keep seed 1001 as a manual continuity scenario because transition set and pipe movement were previously reported as suspicious after roughly ten seconds. Record the first inconsistent event rather than depending on elapsed visual time alone.
