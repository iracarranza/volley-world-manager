# Rally engine first-draft implementation specification

This packet is an **implementation authority for a coding agent**, not a textbook and not a history of rally development.

Its purpose is narrow:

> Starting from the pinned repository state, transform the remaining partially migrated rally architecture into one complete causal first draft, then expose that complete draft to certification as a whole.

The packet is written so that an agent should spend its implementation window editing, integrating, compiling and debugging rather than repeatedly deciding what the rally engine is supposed to mean.

## Pinned base

Repository: `iracarranza/volley-world-manager`

Source branch at authoring: `claude/system-fit-serve-receive-von64k`

Pinned commit:

`6ce8f3b56e9e533ff575d184a124d26b02431fd5`

At that commit:

- M0 authoritative rally skeleton: closed.
- M1 responsibility / defensive ownership: closed.
- M2 physical preparation: closed except the separately named locomotion relation debt.
- M3 body centre vs contact geometry: closed.
- M4 physical platform contact: dig + coverage production; reception built and development-certified, production-gated.
- M5 free-flight / interception authority: architecturally closed.
- M6 all-contact consistency: planned.
- M7 continuous per-voli rally actions: planned.
- M8 canonical side-out certification: planned.
- M9 tactical A/B certification: planned.

The physical reception implementation already exists. Do **not** rebuild it. The remaining M4 work is the first-ball realised-state semantic reconciliation, the short-leg movement-timing correctness problem, and production promotion.

## Implementation records added by the run

The packet was authored against `6ce8f3b`. It arrived on this branch after that
commit, so the newer-branch rule in `08_AGENT_HANDOFF.md` applies and the entry
point is **B0**, not A0. What moved, and what the run left behind:

| file | what it is |
|---|---|
| [`B0_CONTACT_AUTHORITY_CENSUS.md`](B0_CONTACT_AUTHORITY_CENSUS.md) | the B0 table, measured from running rallies rather than read from source |
| [`B1_B6_FAMILY_AUDITS.md`](B1_B6_FAMILY_AUDITS.md) | per-family dispositions, the one authority break found, and the cross-family chain |
| [`C0_ACTION_WINDOW_CENSUS.md`](C0_ACTION_WINDOW_CENSUS.md) | the M7 action-window audit, and what C5/C6 did about it |
| [`FIRST_DRAFT_DEBT.md`](FIRST_DRAFT_DEBT.md) | the ledger, owned by the run |

**Cluster A is already closed and was not replayed.** At the pinned base
`ENABLE_PHYSICAL_RECEPTION` is `false` and A0–A2 are named as a hard blocking
prerequisite. The very next commit on the source branch, `9e2b55d`, promoted it:
the flag is `true`, `RALLY_MILESTONES.md` reads M4 **DONE**, and the flag's own
comment names the four A0 reconciliations and the A1 instrument gap by name.
`551e29e` is one further commit of drift — the overpass attack contact-position
repair — which sits inside B3/B6's audit scope and contradicts nothing here.

The rest of the packet verified clean against HEAD before any of it was acted
on: all thirteen mapped files exist, all thirteen mapped symbols resolve, and
all six authored T1–T3 magnitudes match `platform_contact_model.gd` exactly.

## Packet order

Read the whole packet before editing. Then execute in this order:

1. [`00_EXECUTION_PROTOCOL.md`](00_EXECUTION_PROTOCOL.md)
2. [`01_TARGET_AUTHORITY_STATE.md`](01_TARGET_AUTHORITY_STATE.md)
3. [`02_FORMULAE_CONSTANTS.md`](02_FORMULAE_CONSTANTS.md)
4. [`03_DEPENDENCY_AND_WORK_UNITS.md`](03_DEPENDENCY_AND_WORK_UNITS.md)
5. [`04_SOURCE_MIGRATION_MAP.md`](04_SOURCE_MIGRATION_MAP.md)
6. [`05_CONTINUOUS_ACTION_AND_INTEGRATION.md`](05_CONTINUOUS_ACTION_AND_INTEGRATION.md)
7. [`06_FAILURE_TIME_POLICY.md`](06_FAILURE_TIME_POLICY.md)
8. [`07_CERTIFICATION_MATRIX.md`](07_CERTIFICATION_MATRIX.md)
9. [`08_AGENT_HANDOFF.md`](08_AGENT_HANDOFF.md)

## Authority hierarchy

When sources disagree, use this order:

1. **This packet's explicit target semantics and work order.**
2. Existing current design authorities linked by this packet, especially:
   - `docs/design/RALLY_MILESTONES.md`
   - `docs/design/CONTACT_AND_BALL_FLIGHT.md`
   - `docs/design/PLATFORM_CONTACT.md`
   - `docs/design/VOLLEYBALL_FIDELITY.md`
   - `docs/design/RALLY_PHYSICAL_TIME.md`
   - `docs/design/OFF_BALL_MOVEMENT.md`
3. Existing certified review evidence.
4. Current implementation details at the pinned base.
5. Historical prose and stale tests.

The hierarchy does **not** authorize ignoring implementation reality. If the source map in this packet is stale, verify the implementation, update the map, and continue toward the same semantic target.

## What this packet does not authorize

It does not authorize:

- new volleyball semantics merely to get a suite green;
- new authored calibration magnitudes unless this packet or an existing authority explicitly supplies them;
- rate fitting to legacy outcomes;
- reopening certified contact families because a nearby downstream symptom exists;
- presentation or diagnostics becoming simulation authority;
- hidden replacement balls or endpoint reconstruction;
- large unrelated cleanup.

## First-draft boundary

The first draft is a **construction state**, not a claim that every probe is green.

Construction is complete when the engine has one end-to-end causal architecture through ordinary rallies, all ordinary contact families obey the ownership contract, per-voli physical/action state is continuous enough to support the canonical side-out, superseded production authority is retired or isolated, and the complete engine can be subjected to M8/M9 certification.

M8/M9 findings then become repair/calibration work against a complete engine rather than reasons to leave major architecture intentionally unbuilt.

One exception exists at entry: the current M4 reception closeout remains blocking because the active implementation sequence already established it as the prerequisite to M6. Close M4 first. After that, use the first-draft failure policy in this packet.
