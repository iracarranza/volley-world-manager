# Gate 40: Attack Candidate Audit

Review date: 2026-07-30

Status: **PASS**

`AttackRolloutAudit` certifies one set-to-attack candidate. It rejects illegal
or mismatched hitters, observations containing authoritative truth, decisions
that use truth, mutated source state, unreachable contacts, actions that are
not both perceived and physically executable, and discontinuities between set
arrival, attack contact, and outgoing attack trajectory.

Eligible candidates carry a deterministic fingerprint containing owner,
selected action, contact position and time, shot target, resolved hitter center,
and observation fingerprint. Every rejection has a named fallback reason.
