# P4-C5 — Migration Plan and Visible Proof

Status: reception, setter, and attack have **DEVELOPMENT-ONLY GUARDED SLICES**;
production replacement remains off; attack-to-block perception is **NEXT**
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

The complete reception slice now runs behind an audited development-only
rollout. Production remains disabled.

## Slice 2: reception to set

The pass destination and arrival time must define second-contact opportunities. The setter is not automatically placed at a traditional spot. An emergency setter becomes possible when the normal setter cannot arrive or took first contact.

This slice now has an observation-only ownership decision, candidate audit,
guarded rollout, and development-only live contact through Gate 36. Attack and
later contacts remain on the legacy continuation.

## Slice 3: set to attack

Attack options arise from hitter approach state, set trajectory, eligibility, tempo familiarity, and opponent geometry. A pipe attack must begin from the hitter's actual back-row state and meet its contact window.

This slice now has perceived setter option ranking, repeated hitter reads,
perceived defensive targeting, candidate audit, guarded rollout, and a
development-only live contact through Gate 42. Block and later contacts remain
on the legacy continuation.

Gate 43 additionally makes responsibility-driven approach preparation active in
ordinary home attacks and defense-to-counterattack continuations. It changes
run-up speed, lateral control, jump conversion, quality, and attack availability;
it does not enable the production continuous-attack flag.

## Slice 4: attack to block — current next work

Blockers must not receive the resolver's selected lane as private foreknowledge.
They should observe setter, ball, and hitter cues over time; form individual
hypotheses; coordinate primary and assisting commitments; and then resolve their
movement and contact against authoritative attack truth.

The first implementation must be shadow-only and preserve official block event
identity. Wrong commits, hesitation, solo blocks, coordinated assists, and late
closes must remain possible and visible. The complete input boundary, test list,
and proposed Gate 44–49 sequence are in the
[Fresh-Agent Handoff](../FRESH_AGENT_HANDOFF.md#the-one-current-next-objective).

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

## Historical manual continuity scenario: seed 1001

Keep seed 1001 as a manual continuity scenario because transition set and pipe movement were previously reported as suspicious after roughly ten seconds. Record the first inconsistent event rather than depending on elapsed visual time alone.

This scenario is regression evidence, not the current roadmap. Current roadmap
work starts from the attack-to-block observation contract in the handoff.
