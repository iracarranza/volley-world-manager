# Rally milestones

This file is the **canonical index for the current rally-development sequence**.
It answers two questions only:

1. What phase are we in?
2. What document owns the detailed design or certification for that phase?

It is deliberately short. Do not duplicate measurements, coefficients, or full
policy here. Those belong in the linked design and review documents.

`docs/design/OUTSTANDING.md` remains the live debt list. It is **not** the phase
roadmap and may contain older findings that have since been certified, repaired,
or superseded by later review work.

The governing fidelity milestone remains the one in
[`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md):

> I can watch a normal rally and argue about the volleyball decision instead of
> arguing about whether the athlete could physically have been there.

## Status

| milestone | status | purpose / exit condition | authority |
|---|---|---|---|
| **M0 — authoritative rally skeleton** | **DONE** | One causal rally chain: serve → receive → set → approach → attack → block → defence → dig → same set loop. No parallel transition architecture or hidden replacement ball. | Review chain in `docs/review/`; especially [`FORWARD_WALK_ATTACK_CHAIN.md`](../review/FORWARD_WALK_ATTACK_CHAIN.md) |
| **M1 — responsibility and defensive ownership** | **DONE** | Feasibility gates ownership; immediate possession, short/zone responsibility, transfer and fallback ordering are explicit; landing blockers carry real recovery debt. | `docs/review/DEFENSIVE_READINESS_BOUNDARY.md` and later readiness reviews |
| **M2 — physical preparation state** | **DONE, with one relation deferred** | Facing describes real body preparation and evolves by movement **form** — IDLE/LATERAL/BLOCK_CLOSE/RECOVERY preserve, APPROACH/TRANSITION establish the route — with no angle, distance or turn-rate constant anywhere. `readiness` was **removed**: nothing wrote it, so its two envelope consumers were a folded constant and an identity. Deferred and named rather than fudged: the defensive form comparison (§8) needs two unmeasured relations — what a hip turn costs, and a per-form top speed — and belongs to the locomotion rework. | [`READY_ORIENTATION.md`](../review/READY_ORIENTATION.md), [`MOVING_ORIENTATION.md`](../review/MOVING_ORIENTATION.md), [`READINESS_REMOVAL.md`](../review/READINESS_REMOVAL.md) |
| **M3 — body centre vs contact geometry** | **DONE** | Platform body placement consumes the contact family's real per-voli height and the already-derived shoulder/arm offset; full arrivals stand behind contact while partial journeys remain physical. No trajectory endpoint height or stand-off constant is used. | [`BODY_CENTRE_SCOPE.md`](../review/BODY_CENTRE_SCOPE.md), [`BODY_CENTRE_PROMOTION.md`](../review/BODY_CENTRE_PROMOTION.md) |
| **M4 — physical platform contact** | **PROMOTED TO PRODUCTION** | One shared authored T1--T3 relation evaluates every reception/dig and all coverage contacts without event-family bands. Controlled dig and attack coverage each launch a physical outgoing ball through the same shared resolver, routed through M5 interception so neither forces a setter endpoint. Coverage's keep-alive selection is governed by the existing second-contact policy (coverer excluded, no new ranking). `ENABLE_PHYSICAL_PLATFORM_DIG` is now **`true`**: promoted on evidence — suite 2161/2161 with the flag on (nine fewer than flag-off 2170, all sampling movement, no acceptance bound failing), paired dig/coverage rollouts PASS, balance healthy (swing 1.032, stuff 0.120, dig 0.353). A set fed by a physical interception now reports the realised prefix that reached the setter, so the one-ball chain holds by identity. The legacy apex/spoil arm is retired from production but kept behind the development override for the paired census. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md), [`PLATFORM_DIG_PROMOTION.md`](../review/PLATFORM_DIG_PROMOTION.md), [`COVERAGE_KEEP_ALIVE.md`](../review/COVERAGE_KEEP_ALIVE.md), [`PLATFORM_AUTHORED_CALIBRATION.md`](../review/PLATFORM_AUTHORED_CALIBRATION.md) |
| **M5 — free-flight and interception authority** | **DONE (architecture); production dig still gated** | Every exit condition met and certified: outgoing launch is authoritative and immutable, intended recipient ≠ endpoint/interceptor, realised segment is an exact prefix of the free flight, same-side interception/floor terminals are truthful, and a legal net crossing becomes the receiving side's **ordinary first-team-contact choice** — an overpass — resolved through `OverpassActionSystem` at both live exits, in **both** the control and attack branches, live and symmetric, with the launch invariant asserted. This is an architecture milestone and does not require flipping production authority: `ENABLE_PHYSICAL_PLATFORM_DIG` stays `false`, so production still runs the legacy dig and the free-flight/overpass path fires 0× in 1,200 ordinary rallies. Promoting the physical dig is a **separate M4-migration evaluation** — its stated blocker (an ungoverned overpass) is now cleared, but flipping the flag moves the outcome distribution and is a paired-census observation, never a fit. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`OVERPASS_ACTION_HANDOFF.md`](../review/OVERPASS_ACTION_HANDOFF.md), [`FREE_FLIGHT_INTERCEPTION.md`](../review/FREE_FLIGHT_INTERCEPTION.md) |
| **M6 — all-contact consistency audit** | **PLANNED** | Serve, set, attack, block and platform families obey one ownership rubric: incoming ball → physical feasibility → intent/selection where applicable → execution → one authoritative outgoing ball. Reopen a certified family only on controlled proof of an authority break. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), review ledgers |
| **M7 — continuous per-voli rally actions** | **PLANNED** | Player action state survives ball-event boundaries: previous contacter clears, setter transition overlaps the first ball, hitters approach before release, blockers/defenders establish before contact, early arrivals wait instead of stretching motion to fill a flight. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), `RALLY_PHYSICAL_TIME.md`, `OFF_BALL_MOVEMENT.md` |
| **M8 — canonical side-out certification** | **PLANNED** | On neutral hand-authored rosters and without debug captions, an ordinary medium-float side-out is visibly convincing from serve receive through transition. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md) §§2–4 |
| **M9 — tactical A/B certification** | **PLANNED** | Manager instructions create the predicted visible volleyball differences through voli interpretation and physical feasibility, not merely hidden coefficient movement. | `TACTICS_AND_TRAINING.md`, platform-contact tactical audit |
| **M10 — presentation and legibility cleanup** | **PLANNED** | Presentation reports the certified simulation cleanly: cogniticons coalesce and persist semantically, waiting belongs to pre-serve, ready state is visibly legible, and remaining block/contact poses expose real intent/state without inventing simulation facts. | `OUTSTANDING.md`, `READABLE_BODIES.md`, presentation review docs |

## ~~The plumbing M3 is behind~~ DONE

Two correctness repairs are certified and **latent**, and both wait on the same
missing structure: `ContactEnvelopeSystem`'s AIRBORNE takeoff exclusion
(`READINESS_REMOVAL.md` §3) and the immediate-control lock's usable-time
requirement (`SHORT_BALL_RESPONSIBILITY.md` §4). Each is correct, each fires in a
deliberately constructed fixture, and neither changes a live rally.

Located precisely, and it is smaller than "carry an actor between legs":
`rally_simulator.gd` never calls `ContactEnvelopeSystem` at all — the envelope is
reached only from the shadow systems, which read `RallyState` actors. The
resolver **rebuilds a fresh `RallyState` per phase** and seeds it from
`live_positions` and `live_velocities` only. `player_recovery` already carries a
per-rally `"state"` field, and `_note_block_airborne` already writes `"airborne"`
into it — so the compromised state survives the leg and simply is not read back
into the actor the envelope sees.

Minimum continuity is therefore: seed each freshly built phase state's actors
from the recovery state already carried. Plumbing only; no new policy, no new
value. Facing rides along but is expected **inert** while §8 is blocked — every
defensive leg is LATERAL and LATERAL preserves, measured at 2 of 796 defensive
contacts made by a body that had run — so its inertness is not a failure and
must not be reported as a consequence.

**Built and certified: [`ACTOR_CONTINUITY.md`](../review/ACTOR_CONTINUITY.md).**
Gates C1–C6 pass, including that one actor exists per player per phase and that
the carried state reaches the envelope. It fires 46 times in 300 rallies (42 of
them landing blockers) and changes no outcome, because `recovery_until` was
already excluding those bodies upstream — the clock was right and the body was
not.

## M3: the relation was already in the repository

Measured and derived: [`BODY_CENTRE_SCOPE.md`](../review/BODY_CENTRE_SCOPE.md).
The gap is one line — `_reached_point` returns the ball's landing point as the
body's position, five of five trips at 0.0000 m — and both reach models already
carry build.

What was missing was the **shoulder anchor**, and `BodyTypeModels.UNIVERSAL_RATIOS`
already carries it: `shoulder_y` 0.815, authored once as the shared figure every
body type is a pull away from, with its basis recorded in its own comment. Arm
length is then `standing_reach − shoulder`, which carries each voli's own
wingspan, and the offset is Pythagoras from the contact height every family
already has.

The cross-check is what validates it: the shared figure's own arm length and the
derived one agree to **5 mm** at the median — two independently authored parts of
the repository describing one skeleton and agreeing about it.

`VolleyballPlayer.contact_offset_meters` gives 0.449 m at the thigh, 0.642 m at
the waist, 0.786 m at the chest, and zero above the shoulder and at the floor,
both boundaries geometric rather than authored. **Nothing is authored in it.**

**Promoted and certified 2026-08-17:** [`BODY_CENTRE_PROMOTION.md`](../review/BODY_CENTRE_PROMOTION.md).
All eight platform sites now supply their contact family's own per-voli height
and the arriving ball's direction. The deterministic fixture moved 5/5 full
arrivals from the ball to the exact derived offset; partial journeys remain
untouched. The unresolved trajectory endpoint field is not read.

## Platform-contact sub-milestones

M4 already has its own implementation order in
[`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md). Keep that order rather than expanding
M4 into parallel rewrites here:

1. **Slice 1 — intent publication. DONE**, 2026-08-17. Seven fields on all eight
platform-contact events; nothing reads any of them and the outcome mix over 600
rallies is byte-identical against the stashed tree. 785 contacts carry a record,
761 name a recipient and two derived anchors, and **484 of 785 aim anywhere a
manager can reach**. See [`../review/PLATFORM_INTENT.md`](../review/PLATFORM_INTENT.md).
2. **Slice 2 — shadow physical envelope. DONE**, 2026-08-17. Measure T1–T3 and intent
satisfiability without changing rallies. **Pre-authoring measurement**, 2026-08-17: the
shipped ball measured in §6's units, and T1's own question answered — the
incoming ball's speed reaches the outgoing launch at r = +0.009 (dig) and
−0.170 (reception), and coverage's ball is a display constant, identical on all
24 contacts. So T1 is a channel that does not exist rather than a band to
recalibrate. **Attribute leverage certified**, 2026-08-17: under paired physical
circumstance and RNG, easy contacts stay playable at ratings 20 and 80 while
target error, launch direction and setter options remain strongly separated;
difficult contacts separate survival as well. At that checkpoint the envelope
still needed T1/T2 authored. A primary-evidence review found outgoing
platform speed/angle measurements but no paired incoming speed, no reachable
angle limits by circumstance, and no intended-versus-realized angle error by
skill. That established the authoring boundary later crossed by the explicit
game-abstraction ruling; none of the missing values is presented as measured. See
[`../review/PLATFORM_TRANSFER.md`](../review/PLATFORM_TRANSFER.md) and
[`../review/PLATFORM_ATTRIBUTE_LEVERAGE.md`](../review/PLATFORM_ATTRIBUTE_LEVERAGE.md),
then [`../review/PLATFORM_PHYSICS_EVIDENCE_GAP.md`](../review/PLATFORM_PHYSICS_EVIDENCE_GAP.md).
**Parameter-free preparation done**, 2026-08-17: all 785 contacts can now be
joined to contact/body/intent/attribute context without touching production.
Reception owns complete incoming and outgoing vectors; controlled digs own 230
of 277 incoming vectors and all 87 successful outgoing vectors; coverage still
owns no outgoing ball. The expanded primary search still does not supply T1/T2
magnitudes or a T3 skill slope. The exact capture route and the minimum authored
alternative are recorded in
[`../review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md`](../review/PLATFORM_PHYSICS_AUTHORITY_BOUNDARY.md).
The explicit game-abstraction ruling then authorised six shared category-3
calibration values. The final shadow has physical input and a selection for all
484 receptions and 277 controlled digs; coverage has physical input on all 24
contacts and intentionally no selection. See
[`../review/PLATFORM_AUTHORED_CALIBRATION.md`](../review/PLATFORM_AUTHORED_CALIBRATION.md).
3. **Slice 3 — controlled dig. DEVELOPMENT ROLLOUT BUILT**, 2026-08-17. All
successful digs receive a complete physical launch when its independent override
is open; production stays closed at the M5 free-flight/interception boundary.
4. **Slice 4 — coverage contact state. DONE**, 2026-08-17. All three sites publish
their existing incoming flight, arrival, posture and per-voli contact height;
outcomes and outgoing balls remain untouched.
5. **Slice 5 — reception + coverage.** Promote the remaining contexts and delete
the old apex/spoil machinery once the physical model owns the ball.

The three explicitly authored physical relations are:

- **T1:** incoming speed + platform/body state + absorption/generation ability → outgoing speed;
- **T2:** reachable platform-angle range from body/contact circumstance;
- **T3:** execution error as platform-angle deviation.

The current six magnitudes are openly authored game abstractions, not measured
biomechanics. They are calibrated against plausible contact behaviour rather
than outcome rates. The retained measurement protocol remains the path for
future empirical validation or replacement.

## Contact-family disposition

This table prevents a later milestone pass from assuming every contact needs a
fresh rewrite.

| family | current disposition |
|---|---|
| **Serve** | **CERTIFIED FORWARD CONTACT.** Leave closed absent downstream proof of an authority violation. |
| **Set** | **STRUCTURALLY CERTIFIED.** Further work is mainly free-flight/interception consistency and later cross-contact audit, not a ground-up rewrite. |
| **Attack** | **STRUCTURALLY CERTIFIED.** Hitter approach, attack selection, physical attack, publication and downstream consumption passed the forward walk. |
| **Block** | **STRUCTURALLY CERTIFIED AS AN INTERACTION.** Remaining course-change/hand/intent work is primarily fidelity and presentation unless a later authority audit proves otherwise. |
| **Platform contacts** | **MAJOR PHYSICAL MIGRATION STILL OPEN.** M4 owns it. |

## Maintenance rule

When a milestone closes:

1. update only its status and one-sentence exit condition here;
2. link the review document/commit that proves closure;
3. advance **NEXT** to the first genuine dependency;
4. do not copy measurements from the review into this file;
5. do not reopen a **DONE/CERTIFIED** milestone because a later symptom is nearby — require controlled downstream proof that its boundary is actually violated.

If the detailed design changes, update the owning spec first and this index
second. This file should tell a future pass **where to look**, not become another
independent opinion about the physics.
