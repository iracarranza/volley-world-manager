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
| **M2 — physical preparation state** | **IN PROGRESS** | Facing/readiness describe real body preparation. Stationary orientation is side-relative and reaches defensive arrival; moving orientation and the separate meaning of `readiness` must close without arbitrary thresholds or double-spending state. | [`READY_ORIENTATION.md`](../review/READY_ORIENTATION.md), `RallyPlayerState`, `LocomotionModel`, `ContactEnvelopeSystem` |
| **M3 — body centre vs contact geometry** | **NEXT** | A voli's body location is distinct from the point where hands/platform contact the ball. Reach, wingspan, body type and net encroachment use one physical geometry instead of placing the sternum on the ball. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), platform-offset measurement history, [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md) |
| **M4 — physical platform contact** | **DESIGNED** | Reception, controlled dig, emergency dig and attack coverage produce an outgoing ball from incoming ball + body/contact state + intent/selection + execution, not from event-specific apex bands. | [`PLATFORM_CONTACT.md`](PLATFORM_CONTACT.md) |
| **M5 — free-flight and interception authority** | **PLANNED** | Outgoing launch exists independently of who later intercepts it. Intended recipient ≠ physical endpoint; free flight ≠ realized segment; shanks may be intercepted en route; gameplay physics no longer depends on presentation reconstruction. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), `OUTSTANDING.md` second-contact/shank section |
| **M6 — all-contact consistency audit** | **PLANNED** | Serve, set, attack, block and platform families obey one ownership rubric: incoming ball → physical feasibility → intent/selection where applicable → execution → one authoritative outgoing ball. Reopen a certified family only on controlled proof of an authority break. | [`CONTACT_AND_BALL_FLIGHT.md`](CONTACT_AND_BALL_FLIGHT.md), review ledgers |
| **M7 — continuous per-voli rally actions** | **PLANNED** | Player action state survives ball-event boundaries: previous contacter clears, setter transition overlaps the first ball, hitters approach before release, blockers/defenders establish before contact, early arrivals wait instead of stretching motion to fill a flight. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md), `RALLY_PHYSICAL_TIME.md`, `OFF_BALL_MOVEMENT.md` |
| **M8 — canonical side-out certification** | **PLANNED** | On neutral hand-authored rosters and without debug captions, an ordinary medium-float side-out is visibly convincing from serve receive through transition. | [`VOLLEYBALL_FIDELITY.md`](VOLLEYBALL_FIDELITY.md) §§2–4 |
| **M9 — tactical A/B certification** | **PLANNED** | Manager instructions create the predicted visible volleyball differences through voli interpretation and physical feasibility, not merely hidden coefficient movement. | `TACTICS_AND_TRAINING.md`, platform-contact tactical audit |
| **M10 — presentation and legibility cleanup** | **PLANNED** | Presentation reports the certified simulation cleanly: cogniticons coalesce and persist semantically, waiting belongs to pre-serve, ready state is visibly legible, and remaining block/contact poses expose real intent/state without inventing simulation facts. | `OUTSTANDING.md`, `READABLE_BODIES.md`, presentation review docs |

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