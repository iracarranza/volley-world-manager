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
| **M4 — physical platform contact** | **DONE** | All three platform families — reception, controlled dig and attack coverage — hold production authority on one shared authored T1--T3 relation, with no event-family bands. Each takes the authoritative incoming ball and real body/contact state, launches **one** outgoing free flight, and hands it to M5: interception decides the actual next contact, the intended recipient is soft intent that may miss, and the following contact consumes the realised prefix by identity. `ENABLE_PHYSICAL_PLATFORM_DIG` and `ENABLE_PHYSICAL_RECEPTION` are both `true`. Reception was the hardest and last: its home first-ball path was a pre-M5 inline resolver, so promotion needed the M5 branch retrofitted **and** four places reconciled where the authored pass endpoint still stood in for the actual interception (capability height, published pass target, opponent set contact, SET_DECISION moment), plus one instrument gap where the first-ball SET never published the body-contact/entry-velocity the other two set paths already did. Suite **2,132 PASS**; reception/dig/coverage/overpass rollouts PASS; M5 census 0 unresolved. Observed and not fitted: ~12% of physical receptions floor, which moves kill rate 0.544→0.661 and contacts/rally 5.200→4.771 — advisory targets, not acceptance bounds, and the recorded next question. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md), [`PLATFORM_RECEPTION_PROMOTION.md`](../review/PLATFORM_RECEPTION_PROMOTION.md), [`PLATFORM_DIG_PROMOTION.md`](../review/PLATFORM_DIG_PROMOTION.md), [`COVERAGE_KEEP_ALIVE.md`](../review/COVERAGE_KEEP_ALIVE.md) |
| **M5 — free-flight and interception authority** | **DONE** | Every exit condition met and certified: outgoing launch is authoritative and immutable, intended recipient ≠ endpoint/interceptor, realised segment is an exact prefix of the free flight, same-side interception/floor terminals are truthful, and a legal net crossing becomes the receiving side's **ordinary first-team-contact choice** — an overpass — resolved through `OverpassActionSystem` at both live exits, in **both** the control and attack branches, live and symmetric, with the launch invariant asserted. This closed as an architecture milestone *before* any platform family was promoted, and the row said so — that `ENABLE_PHYSICAL_PLATFORM_DIG` stays `false`, so production ran the legacy dig and the free-flight/overpass path fired 0× in 1,200 ordinary rallies. **That sentence outlived its subject.** M4 has since promoted all three platform families and both flags are `true`, which the M4 row directly above states — so the table contradicted itself, in the half a reader checks for the current production state. Recorded rather than quietly deleted because this is the same failure mode as a stale test baseline: prose written as a present-tense fact about a flag is only true on the commit it was measured on, and nothing re-reads it when the flag moves. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), [`OVERPASS_ACTION_HANDOFF.md`](../review/OVERPASS_ACTION_HANDOFF.md), [`FREE_FLIGHT_INTERCEPTION.md`](../review/FREE_FLIGHT_INTERCEPTION.md) |
| **M6 — all-contact consistency audit** | **DONE** | Every ordinary contact family obeys one ownership rubric, and the cross-family chain now holds **by launch identity rather than by shape**. `tools/run_contact_authority_census.gd` measures all nine canonical edges over 600 rallies: every one hands over the same ball, none is missing an incoming ball, none is ordered backwards in time, and all nine are 100% same-lineage after `_ball_trajectory` began stamping `authoritative_flight_id` on the four families that published anonymous balls (serve, set, attack, block). The id and deliberately **not** `trajectory_role` — M5's role string gates `FreeFlightInterceptionModel`, and stamping it on a serve arc would let that flight walk into the interception search. One authority break was found and repaired: 100 of 443 `ATTACK → BLOCK` edges handed the home block a *superseded* swing, because both block paths re-slice a touched swing to the tape and only the opponent path re-read the result. The same stale local set the block's timestamp via `_contact_time` — a flight's `end_time`, which on an untruncated swing is the moment the ball reaches the floor behind the blockers, measured up to **1.140 s** late. `tools/run_block_authority_probe.gd` reports 100/100 on home against 0/113 on opponent before, 0 and 0 on both after; no decision changed, and the balance probe reads kill 0.661 and contacts 4.771 either side of it. B5 confirms one shared `PlatformContactModel.evaluate` call site serving all three platform families with no per-family coefficients. `_test_one_ball_chain_by_launch_identity` holds both halves permanently. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), review ledgers |
| **M7 — continuous per-voli rally actions** | **BUILT, with named gaps** | The architecture exists and `tools/run_continuous_action_probe.gd` certifies nine structural claims over 400 rallies. Two repairs carried it there. **C6:** every off-ball journey now publishes `traversal_seconds` against `window_seconds`, from the same `_movement_time` `_reached_point` already computed and discarded — the C0 census had measured **0 of 8,125** placed volis carrying any duration, which made "early arrivals wait" unfalsifiable rather than false. Now 4,130 of 4,184 journeys arrive early with 0.433 s of mean slack, 54 run out of window, and **0** are stretched past it. **C5:** `_floor_phase_positions` computed the defensive shape and all three callers wrote it straight into `live_positions` — the defence *appeared* in the diagram when the attacker swung, from any distance, for free, and that shape is gameplay because `CoverageModel.choose_claimant` reaches from it. `_establish_shape` walks them instead, through the same traversal authority every other leg uses, with the set flight as the window; partial establishment stays partial. Recovery debt is now published from `_add_event`, so C1's carry is visible outside the resolver for the first time. Cost, measured and not fitted: dig rate 0.387 → 0.393, contacts 4.771 → 4.796, kill 0.661 → 0.659, no band crossed — the teleport was a *relocation*, not a buff, so walking defenders from where they really stood raised the dig rate slightly. **Still open:** the serve leg publishes nothing about the other eleven volis, and the drawn receive formation is a different set of coordinates from the one gameplay reaches from. 46.4% of voli-legs remain presentation's invention. See `FIRST_DRAFT_DEBT.md` FD-001 to FD-004. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), `RALLY_PHYSICAL_TIME.md`, `OFF_BALL_MOVEMENT.md` |
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
