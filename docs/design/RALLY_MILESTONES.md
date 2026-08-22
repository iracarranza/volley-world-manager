# Rally milestones

This file is the **canonical index for the current rally-development sequence**.
It answers only:

1. What phase are we in?
2. What must be true for that phase to close?
3. Which document owns the detailed design/certification?

Detailed measurements belong in `docs/review/`; live debt belongs in
[`OUTSTANDING.md`](OUTSTANDING.md). Do not turn this file into another review
ledger.

The governing fidelity milestone remains
[`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md):

> I can watch a normal rally and argue about the volleyball decision instead of
> arguing about whether the athlete could physically have been there.

## Current position

The active dependency chain is:

```text
M4 platform contact
  ↕
M5 authoritative free flight / interception
  ↓
coverage selection policy
  ↓
finish M4 production promotion
  ↓
M6 cross-contact/action-space audit
```

M4 and M5 currently overlap because truthful platform-contact promotion exposed
free-flight/interception requirements before M4 could retire the legacy ball.
That dependency is intentional; milestone numbers are not strict implementation
walls.

## Status

| milestone | status | exit condition | authority |
|---|---|---|---|
| **M0 — authoritative rally skeleton** | **DONE** | One causal rally chain exists; no parallel transition architecture or hidden replacement ball. | [`FORWARD_WALK_ATTACK_CHAIN.md`](../review/FORWARD_WALK_ATTACK_CHAIN.md) and review chain |
| **M1 — responsibility / defensive ownership** | **DONE** | Feasibility gates ownership; responsibility, transfer/fallback, and recovery debt are explicit. | defensive-readiness / short-ball review chain |
| **M2 — physical preparation state** | **DONE; locomotion relation deferred** | Facing evolves by movement form; fake `readiness` removed; no invented turn/opening constant. Unified defensive-speed/form calibration remains deferred. | [`MOVING_ORIENTATION.md`](../review/MOVING_ORIENTATION.md), [`READINESS_REMOVAL.md`](../review/READINESS_REMOVAL.md) |
| **M3 — body centre vs contact geometry** | **DONE** | Platform arrivals place the body from real contact height + derived reach geometry rather than putting the body on the ball. | [`BODY_CENTRE_SCOPE.md`](../review/BODY_CENTRE_SCOPE.md), [`BODY_CENTRE_PROMOTION.md`](../review/BODY_CENTRE_PROMOTION.md) |
| **M4 — physical platform contact** | **IN PROGRESS / PHYSICS BUILT, PRODUCTION MIGRATION OPEN** | Shared T1–T3 physics owns reception/dig/coverage feasibility without family-specific bands; controlled dig is development-capable; coverage state is complete. Close when controlled dig, reception, and coverage own truthful outgoing balls in production and legacy apex/spoil authority is retired. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md), [`PLATFORM_AUTHORED_CALIBRATION.md`](../review/PLATFORM_AUTHORED_CALIBRATION.md), [`PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md`](../review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md) |
| **M5 — authoritative free flight / interception** | **IN PROGRESS / DEVELOPMENT AUTHORITY BUILT** | A contact launch exists independently of its later interceptor; realized segments are exact prefixes; intended recipient is not an endpoint. Same-side dig interception is certified in development. Overpass ordinary-first-contact choice is constructed but must be integrated symmetrically into both live exits and certified before production dig promotion. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`FREE_FLIGHT_INTERCEPTION.md`](../review/FREE_FLIGHT_INTERCEPTION.md), [`OVERPASS_ACTION_HANDOFF.md`](../review/OVERPASS_ACTION_HANDOFF.md) |
| **M6 — all-contact consistency + action semantics** | **PLANNED** | Every contact family obeys the same causal rubric, and team-contact number no longer hard-wires action type. Audit/cover first-ball attack/set, second-ball attack/dump/emergency distribution, safe returns, block-touch continuation, live net rebounds, jousts, and legality-driven action availability. Reopen certified contact families only on controlled proof of an authority break. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md), review ledgers |
| **M7 — continuous per-voli actions / late commitment** | **PLANNED** | Player action state survives ball-event boundaries; movement overlaps flight; early arrivals wait; preparation may preserve multiple future actions until commitment without opponent precognition. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), [`RALLY_PHYSICAL_TIME.md`](RALLY_PHYSICAL_TIME.md), [`OFF_BALL_MOVEMENT.md`](OFF_BALL_MOVEMENT.md), [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) |
| **M8 — canonical side-out certification** | **PLANNED** | A neutral medium-float side-out is visibly convincing from serve through transition without debug captions. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md) |
| **M9 — tactical A/B certification** | **PLANNED** | Manager instructions create predicted visible differences through perception, choice, and physical feasibility rather than direct outcome coefficients. | tactics docs + [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) |
| **M10 — presentation / legibility cleanup** | **PLANNED** | Presentation reports certified simulation cleanly without inventing simulation facts. | [`OUTSTANDING.md`](OUTSTANDING.md), [`READABLE_BODIES.md`](READABLE_BODIES.md), presentation reviews |

## M4 sub-status

The implementation order remains owned by [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md):

1. **Intent publication — DONE.**
2. **Shadow physical envelope / T1–T3 — DONE.** Six shared values are explicit
   game abstractions, not measured biomechanics; attribute leverage remains
   strong and monotonic under paired circumstance.
3. **Controlled dig — DEVELOPMENT ROLLOUT BUILT.** Successful digs can emit one
   shared physical launch; failed digs emit no ball. Production remains closed
   until M5's downstream branches are truthful.
4. **Coverage contact state — DONE.** Incoming flight, arrival, posture, and
   contact height are published. No outgoing preference is fabricated.
5. **Reception + coverage promotion / legacy retirement — OPEN.** Coverage first
   needs a governed keep-alive selection policy.

The shared physical relations remain:

- **T1:** incoming speed + platform/body state + absorption/generation ability → outgoing speed;
- **T2:** reachable direction envelope around the derived natural rebound, narrowed by circumstance;
- **T3:** selected-to-realized angular execution error driven by technique.

No event-family-specific physics band is authorized.

## M5 sub-status

Development certification already establishes:

- one authoritative free flight per successful physical dig;
- no ball from a failed dig;
- intended setter may miss;
- another viable teammate may intercept;
- uncontrolled balls may reach their physical terminal;
- later contacts do not mutate the source launch;
- realized segments remain prefixes of the same flight.

The next integration boundary is **overpass continuation**. The approved policy is
that a legal overpass becomes the receiving side's ordinary first team contact:
physical/legal action availability → shared action choice → execution → one
outgoing ball, with receiving `team_contact_number = 1`.

There is no fixed attack-over-control priority, no forced reception, and no
overpass-specific physics. Attack opportunities must still enter existing block
and floor-defence continuation rather than becoming automatic kills.

Overhead/set-like first contact remains excluded until the set contact form can be
generalized without inheriting second-contact hitter-selection/contact-count
assumptions.

## Next genuine policy boundary

After live overpass integration/certification, the known M4 policy question is
**coverage selection**:

> What does a covering voli value when choosing among physically feasible
> keep-alive launches, given teammate availability, recovery, tactics, and
> continuation quality?

Do not answer that question with a fixed apex, forced recipient, coverage-only
trajectory band, or new physics coefficient. It is decision policy.

## Contact-family disposition

| family | current disposition |
|---|---|
| **Serve** | **CERTIFIED FORWARD CONTACT.** Closed absent downstream proof of authority failure. |
| **Set** | **STRUCTURALLY CERTIFIED.** Later work may generalize the contact form across team-contact numbers; do not ground-up rewrite it without evidence. |
| **Attack** | **STRUCTURALLY CERTIFIED.** Existing attack selection/geometry remains authority unless M6 finds a controlled violation. |
| **Block** | **STRUCTURALLY CERTIFIED AS AN INTERACTION.** M6 still needs nonterminal block-touch/joust consistency; that does not imply current block physics is reopened. |
| **Platform** | **ACTIVE MIGRATION.** M4 owns physical promotion/legacy retirement. |

## Architecture invariant

```text
attributes + tactics
→ perception / responsibility / intent / action choice

ball + body state
→ physical feasibility

attributes
→ execution quality inside feasible space

contact physics
→ one outgoing ball

free flight / interaction
→ what actually happens next
```

Outcome labels are downstream classifications. They do not author trajectories.

See [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) for the deferred action
vocabulary and the rule that **team-contact number is context, not action type**.

## Maintenance rule

When a milestone changes:

1. update its status + exit condition here;
2. link the design/review document proving the change;
3. advance the current dependency to the first real blocker;
4. keep measurements in review docs;
5. do not reopen DONE/CERTIFIED work because a nearby symptom exists — require
   controlled evidence that its authority boundary is actually violated.
