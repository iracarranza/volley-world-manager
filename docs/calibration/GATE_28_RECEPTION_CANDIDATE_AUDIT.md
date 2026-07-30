# Gate 28: Reception Candidate Audit

Review date: 2026-07-30

Status: **PASS**

`ReceptionRolloutAudit` certifies a shadow reception before promotion. It
rejects unavailable or unsuccessful contacts, illegal receiver ownership,
wrong event types or sides, invalid quality, discontinuous trajectories,
contact time/position mismatches, official-event mutation, and source-state
mutation. Eligible candidates receive a deterministic fingerprint.

Any failed check produces named fallback reasons and leaves official events
selected.

Across 600 serve fixtures, 47.86% produced candidates that passed the complete
audit. All ineligible samples remained on official reception.
