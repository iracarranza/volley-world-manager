# Rally simulation documentation

Use this directory as the entry point for rally diagnosis. It is an index, not another semantic authority.

## Start here

- [`RALLY_DIAGNOSTIC_MAP.md`](RALLY_DIAGNOSTIC_MAP.md) — current rally sequence, five diagnostic levels, phase ownership, trace questions, and focused recipes.
- [`RALLY_INVARIANTS.md`](RALLY_INVARIANTS.md) — stable invariant IDs for tests, probes, reviews, and bug reports.

## Existing authorities

- [`../design/VOLLEYBALL_FIDELITY.md`](../design/VOLLEYBALL_FIDELITY.md) — what convincing volleyball means and the canonical side-out standard.
- [`../design/CONTACT_AND_BALL_FLIGHT.md`](../design/CONTACT_AND_BALL_FLIGHT.md) — contact, launch, free-flight, realized-segment, and presentation ownership.
- [`../design/SETTER_DECISION.md`](../design/SETTER_DECISION.md) — setter option semantics and measurement criteria.
- [`../FAILURE_MODES.md`](../FAILURE_MODES.md) — engineering diagnostic discipline and recurring failure patterns.
- [`../review/PROBE_HANDOFF.md`](../review/PROBE_HANDOFF.md) — current instruments, measurements, and known limits.
- [`../review/RALLY_SIMULATOR_REDESIGN_LOG.md`](../review/RALLY_SIMULATOR_REDESIGN_LOG.md) — provenance, rejected approaches, and reasoning history.
- [`../../ARCHITECTURE.md`](../../ARCHITECTURE.md) — repository-level ownership and data-flow boundaries.

## Ownership rule

Do not copy long-form design reasoning or live measurements into the diagnostic map. The map should point to the authority. Do not copy current probe numbers into the invariant registry. The invariant registry should remain stable when calibration populations change.

When adding a rally regression:

1. cite the smallest applicable `INV-*` ID in the test comment or failure text;
2. use `RALLY_DIAGNOSTIC_MAP.md` to identify the owning phase and trace boundary;
3. use `FAILURE_MODES.md` §0 before changing a threshold/model;
4. update `PROBE_HANDOFF.md` when a measurement instrument gains or loses evidentiary scope;
5. update the specialist design document first if the investigation exposes a genuinely missing physical or tactical rule.