# Gate 48: Guarded Block Rollout Policy

Review date: 2026-07-31

Status: **PASS; PRODUCTION FLAG OFF; NO PROMOTION PATH**

Gate 48 adds the fourth and final selection boundary, mirroring what Gates 15,
29, 35, and 41 did for reception, setter, and attack. It decides *where an
official `BLOCK` event may come from*. Today the answer is always "the legacy
resolver," and Gate 48's job is to make that a reviewed decision recorded as
evidence rather than an unexamined default.

It promotes nothing. `RallySimulator._resolve_home_block` is untouched.

## What was added

**Two production-off flags.** `RallyFeatureFlags.ENABLE_CONTINUOUS_BLOCK_EVENTS`
and `ALLOW_DEVELOPMENT_BLOCK_OVERRIDE`, both `false`. The development override
differs from its three predecessors, which are `true`: those gates have a
reviewed integrator behind them, and the block does not. Setting it `true`
would advertise a debug path that does not exist.

**`RallyRolloutPolicy.select_block_source()`.** Takes the shadow summary and the
opponent lineup, calls `BlockRolloutAudit.evaluate()`, and returns the same
shape as the other three selectors: `flag_enabled`, `selected_source`,
`candidate_available`, `candidate_audit`, `official_identity_preserved`,
`activation_implemented`, and `fallback_reason`.

**`shadow_summary["block_rollout"]`.** Recorded on every rally next to
`attack_rollout`, with `selected_block` erased from the evidence copy so the
promotable candidate never travels inside the diagnostic record.

## The lineup argument is the opponent's

The three earlier selectors take the home lineup. This one takes
`state.opponent_lineup`, because blockers are opponents of the attacking home
side. Passing the home lineup would make the audit's front-row legality check
meaningless -- it would test whether opponent blocker IDs occupy home front-row
slots, a question with no correct answer.

## Why the candidate can never be selected yet

`select_block_source()` computes `candidate_available` honestly from the audit,
then holds `use_candidate` at `false` unconditionally. Even with the flag forced
on, the selected source stays `official` and `selected_block` stays empty, with
`fallback_reason` reading `activation_not_implemented`.

This is deliberate. The other three gates could flip their flag and land in a
reviewed integrator (`LiveReceptionIntegrator`, `LiveSetterIntegrator`,
`LiveAttackIntegrator`). No `LiveBlockIntegrator` exists. A boundary that
*claimed* it could activate, backed by nothing, would be a worse lie than one
that admits it cannot. `activation_implemented` is therefore `false` -- the one
field where Gate 48 legitimately differs in value, not shape, from its
predecessors.

Building that path is Gate 49, behind an explicit development fixture and
`OS.is_debug_build()`.

## Verification

Six checks in `_test_gate_forty_eight_block_rollout_boundary`:

1. every rally that reaches the attack phase records a `block_rollout` verdict
   alongside an official `BLOCK` event;
2. across 40 fixed seeds, every rally stays on the official block with the flag
   off, and no evidence copy carries `selected_block`;
3. the sweep actually contains an audit-eligible candidate -- a boundary that
   never sees one proves nothing about holding one back;
4. the same 40 seeds re-resolved produce byte-identical official `BLOCK` events
   (`var_to_str` of the full event dictionary, compared as an ordered list);
5. forcing the flag on still selects `official`, still returns an empty
   `selected_block`, and reports `activation_not_implemented`;
6. the returned dictionary carries every key the other three selectors return,
   and reports `rollout_disabled` when the flag is off.

Check 3 exists because of the lesson Gate 46 paid for: a monotonic rate over an
all-zero column proves nothing. The same applies here -- "every candidate was
held back" is vacuous if there were no candidates. Check 5 exists because a
boundary that has never been pushed against has not been tested.

Full suite: 385 checks passing (379 before this gate).
