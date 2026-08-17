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
| **M3 — body centre vs contact geometry** | **RELATION DERIVED, promotion pending** | A voli's body location is distinct from the point where hands/platform contact the ball. Reach, wingspan, body type and net encroachment use one physical geometry instead of placing the sternum on the ball. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), platform-offset measurement history, [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md) |
| **M4 — physical platform contact** | **DESIGNED** | Reception, controlled dig, emergency dig and attack coverage produce an outgoing ball from incoming ball + body/contact state + intent/selection + execution, not from event-specific apex bands. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md) |
| **M5 — free-flight and interception authority** | **PLANNED** | Outgoing launch exists independently of who later intercepts it. Intended recipient ≠ physical endpoint; free flight ≠ realized segment; shanks may be intercepted en route; gameplay physics no longer depends on presentation reconstruction. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), `OUTSTANDING.md` second-contact/shank section |
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

Still open, and plumbing rather than policy: it is consumed by nothing. Promoting
it means `_reached_point` standing the body off instead of returning `target`,
which needs the contact height plumbed to each defensive site and a certified
before/after — moving every defensive body by half a metre deserves its own
measurement rather than riding along with the derivation.

## Platform-contact sub-milestones

M4 already has its own implementation order in
[`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md). Keep that order rather than expanding
M4 into parallel rewrites here:

1. **Slice 1 — intent publication.** Publish the intent/state that already exists;
outcome-neutral.
2. **Slice 2 — shadow physical envelope.** Measure T1–T3 and intent
satisfiability without changing rallies.
3. **Slice 3 — controlled dig.** First promoted platform context.
4. **Slice 4 — coverage contact state.** Resolve its missing arrival/posture/contact
state from existing facts.
5. **Slice 5 — reception + coverage.** Promote the remaining contexts and delete
the old apex/spoil machinery once the physical model owns the ball.

The three explicitly authored physical relations are:

- **T1:** incoming speed + platform/body state + absorption/generation ability → outgoing speed;
- **T2:** reachable platform-angle range from body/contact circumstance;
- **T3:** execution error as platform-angle deviation.

None is to be chosen by eye. Each requires measurement and an acceptance
criterion before promotion.

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