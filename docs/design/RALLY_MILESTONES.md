# Rally milestones

This file is the **canonical index for the current rally-development sequence**.
It answers only:

1. What phase are we in?
2. What must be true for that phase to close?
3. Which document owns detailed design/certification?

Measurements belong in `docs/review/`; live debt belongs in [`OUTSTANDING.md`](OUTSTANDING.md).

The governing fidelity milestone remains [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md):

> I can watch a normal rally and argue about the volleyball decision instead of arguing about whether the athlete could physically have been there.

## Current position

```text
M4 platform contact
  ↕
M5 authoritative free flight / interception
  └─ overpass CONTROL live + certified
  └─ overpass ATTACK live continuation open
  ↓
M5 closure reassessment / physical-dig production review
  ↓
coverage selection policy
  ↓
finish M4 production promotion / legacy retirement
  ↓
M6 cross-contact/action-space audit
```

M4 and M5 overlap because truthful platform contact exposed free-flight/interception requirements before M4 could retire the legacy ball. Milestone numbers are dependencies, not strict implementation walls.

## Status

| milestone | status | exit condition | authority |
|---|---|---|---|
| **M0 — authoritative rally skeleton** | **DONE** | One causal rally chain exists; no parallel transition architecture or hidden replacement ball. | [`FORWARD_WALK_ATTACK_CHAIN.md`](../review/FORWARD_WALK_ATTACK_CHAIN.md) + review chain |
| **M1 — responsibility / defensive ownership** | **DONE** | Feasibility gates ownership; responsibility, transfer/fallback and recovery debt explicit. | defensive-readiness / short-ball review chain |
| **M2 — physical preparation state** | **DONE; locomotion relation deferred** | Facing evolves by movement form; fake `readiness` removed; no invented turn/opening constant. Defensive form/opening-speed relation remains explicitly deferred. | [`MOVING_ORIENTATION.md`](../review/MOVING_ORIENTATION.md), [`READINESS_REMOVAL.md`](../review/READINESS_REMOVAL.md) |
| **M3 — body centre vs contact geometry** | **DONE** | Platform arrivals place body from real contact height + derived reach geometry rather than putting body on ball. | [`BODY_CENTRE_SCOPE.md`](../review/BODY_CENTRE_SCOPE.md), [`BODY_CENTRE_PROMOTION.md`](../review/BODY_CENTRE_PROMOTION.md) |
| **M4 — physical platform contact** | **IN PROGRESS / PHYSICS BUILT, PRODUCTION MIGRATION OPEN** | Shared T1–T3 owns reception/dig/coverage physical feasibility without family bands. Close when truthful outgoing platform balls own production paths and old apex/spoil authority is retired. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md), [`PLATFORM_AUTHORED_CALIBRATION.md`](../review/PLATFORM_AUTHORED_CALIBRATION.md) |
| **M5 — authoritative free flight / interception** | **IN PROGRESS / CONTROL OVERPASS LIVE-CERTIFIED** | Launch exists independently of later interceptor; realised segments are exact prefixes; intended recipient ≠ endpoint. Same-side dig interception is development-certified. Overpass CONTROL is live/certified at both exits; ATTACK still must enter the real block→floor-defence→continuation path symmetrically before M5 closure reassessment. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`FREE_FLIGHT_INTERCEPTION.md`](../review/FREE_FLIGHT_INTERCEPTION.md), [`OVERPASS_ACTION_HANDOFF.md`](../review/OVERPASS_ACTION_HANDOFF.md) |
| **M6 — all-contact consistency + action semantics** | **PLANNED** | Every contact/interaction follows the common causal rubric and team-contact number no longer hard-wires action type. Audit first-ball attack/set, attack/dump on 2, safe returns, block-touch continuation, live net rebounds, jousts and legality-driven availability. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) |
| **M7 — continuous per-voli actions / late commitment** | **PLANNED** | Action state survives ball-event boundaries; movement overlaps flight; early arrivals wait; preparation can preserve several future actions until commitment without precognition. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), [`RALLY_PHYSICAL_TIME.md`](RALLY_PHYSICAL_TIME.md), [`OFF_BALL_MOVEMENT.md`](OFF_BALL_MOVEMENT.md) |
| **M8 — canonical side-out certification** | **PLANNED** | Neutral medium-float side-out visibly convincing from serve through transition without debug captions. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md) |
| **M9 — tactical A/B certification** | **PLANNED** | Manager instructions create predicted visible differences through perception/choice/feasibility rather than direct outcome coefficients. | tactics docs + [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) |
| **M10 — presentation / legibility cleanup** | **PLANNED** | Presentation reports certified simulation cleanly without inventing simulation facts. | [`OUTSTANDING.md`](OUTSTANDING.md), [`READABLE_BODIES.md`](READABLE_BODIES.md) |

## M4 sub-status

1. **Intent publication — DONE.**
2. **Shared physical envelope / T1–T3 — DONE.** Six shared values are explicit game abstractions, not measured biomechanics; attribute leverage is strong/monotonic under paired circumstance.
3. **Controlled dig — DEVELOPMENT ROLLOUT BUILT.** Successful digs can emit one physical launch; failed digs emit no ball. Production stays closed while M5 downstream semantics finish.
4. **Coverage contact state — DONE.** Incoming flight, arrival, posture and contact height published; no outgoing preference fabricated.
5. **Reception + coverage promotion / legacy retirement — OPEN.** Coverage first needs governed keep-alive selection.

Shared relations:

- **T1:** incoming speed + platform/body state + absorption/generation ability → outgoing speed;
- **T2:** reachable direction envelope around derived natural rebound, narrowed by circumstance;
- **T3:** selected-to-realised angular execution error driven by technique.

No event-family-specific physics band is authorized.

**T3 reporting note:** leverage probe values such as `0.696 → 0.140` and `1.507 → 0.151` are downstream **spatial error in metres** (`spatial_error_meters`), not angular units. T3's authored sigma endpoints themselves remain degrees.

## M5 sub-status

Development certification already establishes:

- one authoritative free flight per successful physical dig;
- no ball from failed dig;
- intended setter may miss;
- alternate teammate may intercept;
- uncontrolled ball may reach natural terminal;
- downstream contacts do not mutate source launch;
- realised segment remains a prefix of the same flight.

Approved overpass policy: legal crossing → receiving side's ordinary first team contact → physical/legal action availability → shared choice → execution → one outgoing ball with `team_contact_number = 1`. No fixed attack-over-control priority, forced reception or overpass-specific physics.

### Live integration certified through CONTROL

Checkpoint chain on active rally branch:

- `8ae3f87` — T3 leverage reporting units repaired (metres).
- `c147c30` — overpass CONTROL wired into both live unresolved-overpass exits.
- `f766cf9` — constructed live fixture certifies the wiring; suite check count 2160→2164 from added assertions.
- `da6575d` — handoff updated with integration status.

Certification: focused overpass probe PASS; ordinary 1,200-rally census reaches the exit 0× and remains byte-neutral; constructed live fixture proves actors are built from authoritative live position/velocity/facing/recovery/commitment maps, one authoritative outgoing first-contact ball is applied, and incoming launch remains unchanged. `ENABLE_PHYSICAL_PLATFORM_DIG` remains false.

### Current open M5 plumbing

`OverpassActionSystem.execute_attack()` already resolves the swing through the existing geometric attack resolver using real positions/blockers/defenders. No fabricated set parameters are required. Remaining work is to map that output into the existing attack → block → floor-defence → continuation/terminal path at both live exits, certify home/opponent symmetry, then reassess M5 closure.

Overhead/set-like first contact remains excluded until set contact form can be generalized without second-contact hitter-selection/contact-count assumptions.

## Next genuine policy boundary

After M5 attack integration/closure review, the known M4 policy question is **coverage selection**:

> What does a covering voli value when choosing among physically feasible keep-alive launches, given teammate availability, recovery, tactics and continuation quality?

Do not answer with fixed apex/pop, forced recipient, coverage-only trajectory band or new physics coefficient. This is decision policy.

## Contact-family disposition

| family | disposition |
|---|---|
| **Serve** | **CERTIFIED FORWARD CONTACT.** Closed absent controlled authority failure. |
| **Set** | **STRUCTURALLY CERTIFIED.** Later cross-contact-form generalization is not a ground-up rewrite. |
| **Attack** | **STRUCTURALLY CERTIFIED.** Existing attack selection/geometry reused by overpass attack execution. |
| **Block** | **STRUCTURALLY CERTIFIED AS INTERACTION.** M6 still needs nonterminal block-touch/joust consistency. |
| **Platform** | **ACTIVE MIGRATION.** M4 owns promotion/legacy retirement. |

## Architecture invariant

```text
attributes + tactics
→ perception / responsibility / intent / action choice

ball + body state
→ legal / physical feasibility

attributes
→ execution quality

contact physics
→ one outgoing ball

free flight / interaction
→ actual next situation

classification afterward
```

Outcome labels do not author trajectories. See [`RALLY_ACTION_SPACE.md`](RALLY_ACTION_SPACE.md) for deferred action vocabulary and the rule that **team-contact number is context, not action type**.

## Maintenance rule

When a milestone changes:

1. update status + exit condition here;
2. link review/commit proving the change;
3. advance to first genuine dependency;
4. keep detailed measurements in review docs;
5. do not reopen DONE/CERTIFIED work because a nearby symptom exists—require controlled evidence that its authority boundary failed.
