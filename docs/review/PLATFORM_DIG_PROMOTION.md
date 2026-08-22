# Physical platform contact — production promotion

Promoted 2026-08-22 on `claude/system-fit-serve-receive-von64k`.

## What flipped

`ENABLE_PHYSICAL_PLATFORM_DIG` moved `false → true`. Production rallies now
resolve every controlled dig and every successful attack coverage through the
shared `PlatformContactModel` T1–T3 resolver: one authoritative launch, one free
flight, and M5 interception deciding the actual next contact. The legacy
apex/spoil dig arm is retired from production but kept behind the development
override, so the paired census stays a live validation protocol.

## Why it was allowed now

The dig's same-side interception contracts had been certified for some time. The
one thing holding production closed was named in the flag and in
[`FREE_FLIGHT_INTERCEPTION.md`](FREE_FLIGHT_INTERCEPTION.md): a valid authored
launch can clear the net, and an ungoverned overpass would have to manufacture
policy. That blocker is gone. M5 resolves a legal net crossing as the receiving
side's ordinary first team contact (control and attack branches, both live
exits — M5 DONE), and attack coverage — the last platform family still
fabricating its outgoing ball — now launches through the same resolver with its
intended recipient named by the existing second-contact policy.

Promotion was gated on the sequencing the roadmap set: coverage selection first
and certified, dig invariants still passing, and no existing explicit acceptance
bound failing when the flag flips. All three held.

## Evidence

| measurement | flag off | flag on |
|---|---:|---:|
| full suite | 2170 / 2170 | **2161 / 2161** |
| paired dig rollout invariants | PASS | PASS |
| paired coverage rollout invariants | PASS | PASS |

The nine-check drop is sampling movement, not a regression: several gates emit a
variable number of checks per sample, and the promoted dig distribution draws
differently. **No acceptance-bound assertion fails.** `run_rally_balance_probe`
over 700 rallies both serving sides reads swing balance 1.032, stuff rate 0.120
(0.08–0.14 band), dig rate 0.353 (0.35–0.55 band) — the promotion did not
disturb the balance profile. Distribution movement is reported, never fitted.

## The two reporting corrections that rode along

Promotion exposed a genuine reporting gap, fixed rather than masked. Two existing
one-ball-chain invariants —

- *an opponent setter's margin plus travel is the realized pass's own flight*
- *a set is resolved against the exact ball the previous contact published*

— failed with the flag on. The cause was not the physics but the metadata: a set
fed by a physical interception was reporting the **full authoritative flight to
the floor** as its incoming ball, while `_stamp_free_flight_resolution` had
already written the **realised prefix** — the segment that actually reached the
setter — onto the feeding contact as its outgoing ball. The two were the same
launch (shared `authoritative_flight_id`) but a different end and duration, so
the chain could not be proven by identity, and the setter's window read as the
untouched ball's full time-to-floor rather than the interception time it was
resolved against.

Both transition resolvers now stamp the realised prefix as the set's
`incoming_pass_trajectory` when the feed was a physical interception (legacy and
spatial feeds carry no realised segment and fall through unchanged). This makes
the chain hold by identity and is strictly more truthful — it is a correction to
the invariant's inputs, not a weakening of the invariant. `run_coverage_chain_diag.gd`
confirms zero chain mismatches across the identity fixtures' seeds.

## Not deleted

The legacy dig's apex/spoil bands (`_dig_pass_result`) remain in the tree behind
the development override. Retiring them from production is what the flag does;
deleting the code would make the paired census — the instrument that validated
this promotion and will validate the next platform change — impossible to run.
