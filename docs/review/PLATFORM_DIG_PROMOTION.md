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

> **Superseded on the reception question.** Reception has since been reconciled
> and promoted; the blocker described below turned out to be four more stale
> endpoints plus one instrument-bookkeeping gap, all derivable from existing
> authority, and the movement-agreement gate passes unchanged. See
> [`PLATFORM_RECEPTION_PROMOTION.md`](PLATFORM_RECEPTION_PROMOTION.md). The
> section is kept because the diagnosis it records is how the reconciliation was
> found. **M4 is DONE.**

## Remaining M4 migration — reception: built and dev-certified, production blocked

Dig and coverage feed a **continuation or transition** set, and both are
physical. Reception is the third family. Its physical path is now **built and
certified in development**, behind its own gate `ENABLE_PHYSICAL_RECEPTION`
(default false, production byte-neutral at 2161):

- `_reception_pass_result` overlays one authoritative launch on the legacy
  result when `_physical_platform_reception_enabled()`, reusing the shared
  `_physical_platform_dig_result` with a `reception` family label. The intended
  setter is the designated setter's release seat — soft intent only.
- The **home first-ball path** was retrofitted with the M5 branch it lacked:
  `_physical_second_contact_choice` selects the interceptor, terminals resolve
  truthfully (floor/net/out gives the serving side the point; a legal crossing
  is the opponent's ordinary first contact), and the SET consumes the realised
  intercepted prefix by identity. The **opponent** side needed no retrofit — it
  already funnels through `_resolve_opponent_transition`'s M5 branch.
- `tools/run_reception_rollout_probe.gd` (paired, 2,800 rallies) is **14/14**:
  1,117/1,117 owned launches, 0 launch mutations, 0 prefix failures, 0 chain
  breaks, intended setter ≠ interceptor (32 alternates, 164 intended misses),
  T1–T3 bounds held, both serving sides, truthful terminals (floor 130, net 4,
  overpass 3).

**Production promotion is blocked**, and not by distribution movement. Flipping
`ENABLE_PHYSICAL_RECEPTION` true fails several *explicit* suite invariants that
the transition families never tripped, because the first-ball set is now timed
and placed against the **interception** (a short leg) rather than the full pass:

1. *Allotted duration and the movement model agree for every phase type* — the
   **movement-agreement gate**. This is the short-leg timing instrument limit
   `_spatial_setter_choice` already documents ("the short-leg timing wants
   fixing first … widening that band a second time would be the thing this
   repository keeps being told not to do"). Physical reception makes the setter's
   remaining leg short, which is exactly where the resolver's allotted duration
   and the stepped movement model disagree most.
2. *The causality floor never has to correct a derived moment* (34 fired) and
   *two blockers on one wall recognise at their own moments* — related timing,
   downstream of the same short-leg interception moments.
3. *The height a first-ball setter is read against is the height their own pass
   delivered* — under M5 the reception's `set_contact_height_meters` is NaN (the
   interception supplies the real contact height), so the delivered-height
   invariant needs the set to read the M5 interception height, not the pass's.
4. *Setter contact follows the generated reception destination* — encodes the
   legacy spatial assumption that the setter stands on the pass endpoint; under
   M5 the setter stands at the interception point on the flight.

(3) and (4) are semantic reconciliations of the kind the dig promotion already
made (report the realised interception, not the legacy endpoint). (1) and (2)
are the **deferred short-leg movement-timing work** the codebase flagged and
must not be worked around by widening the gate — a materially separate piece,
possibly needing a movement-model change rather than a reporting fix. Reception
production therefore stays gated until that short-leg timing is resolved on its
own terms. The build and its certification stand; only the flag flip waits.

## Not deleted

The legacy dig's apex/spoil bands (`_dig_pass_result`) remain in the tree behind
the development override. Retiring them from production is what the flag does;
deleting the code would make the paired census — the instrument that validated
this promotion and will validate the next platform change — impossible to run.
