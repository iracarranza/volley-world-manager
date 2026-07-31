# Gate 47: Block Candidate Audit

Review date: 2026-07-31

Status: **PASS; SHADOW ONLY**

`BlockRolloutAudit.evaluate()` is now the promotion boundary a guarded block
rollout (Gate 48) would have to pass before an official `BLOCK` event could ever
be built from shadow evidence. Gate 44 shipped only its information half; Gate
47 adds physical feasibility and role consistency, plus an extractable
candidate and a deterministic fingerprint.

## What it certifies

**Information purity (Gate 44, retained).** No key beginning with `true_` or
`authoritative_` anywhere in a blocker's observation, and
`decision_uses_authoritative_truth` false on both the observation and the
blocker record.

**Teammate-cue privacy (new).** A Gate 45 teammate cue may not carry
`confidence_late`, `confidence_early`, `decisive_threshold`, `implied_zone`,
`perceived_attack_x`, or `wrong_read`. Coordination created a brand-new channel
through which one player's private hypothesis could reach another, and it needs
guarding exactly as the truth boundary does.

**Legality (Gate 44, retained).** Every evaluated blocker, and every named role,
occupies a front-row slot.

**Movement feasibility (new).** Every blocker carries a usable movement profile:
a positive maximum speed and a non-negative direction-change delay.

**Contact envelope (new).** A blocker who committed to a close and is certified
reachable must actually be able to touch the ball: maximum contact height at
least the block contact height, a positive takeoff time whenever the close
requires a jump, and a non-negative arrival margin.

**State immutability (Gate 44, retained).** `source_state_unchanged` must hold.

**Role consistency (new).** A named primary or assist must exist in the blocker
set, must actually be closing, and must be reachable. Assist may not duplicate
primary, and an assist may not exist without a primary.

## Candidate and fingerprint

`candidate()` extracts the promotable shape -- roles, closer count, contact time
and height, and each role's commitment, target, arrival margin, and jump
requirement. It contains only resolved facts a `BLOCK` event would need and no
perceived state, so Gate 48 can promote from it without re-reading any
observation.

`fingerprint()` composes the roles with every blocker's commitment fingerprint,
sorted, giving a stable identity for the whole coordinated block.

## Verification

Across 1,200 ordinary rally seeds every available shadow block passed the full
audit with an empty `failure_reasons`.

That result alone would be weak evidence -- an audit that cannot fail certifies
nothing -- so the regression suite also corrupts one property at a time and
requires the audit to catch each by name: a teammate cue carrying a private
hypothesis, an observation carrying a truth-prefixed key, mutated source state,
a role naming a blocker absent from the set, and a close that cannot reach the
contact height.
