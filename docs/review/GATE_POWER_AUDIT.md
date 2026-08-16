# Gate power and fixture fragility audit

Run: 2026-08-16, on `12fc5a3`. Instruments:
`tools/run_gate_power_audit.gd`, `tools/run_seed_fixture_fragility.gd`.
**Findings only — no gate was changed.**

Two gates failed this session for reasons that were not about the thing they
test. Gate 10's tiers came back **exactly equal** at four pairs — 0.2982 against
0.2982, a tie rather than an inversion — and the identity gate's serve-error
clause turned out to be *converged negative* rather than noisy, which is the
opposite diagnosis and needed measurement to tell apart. Both cost a diagnosis
cycle that had nothing to do with the serve work that triggered them.

Slice 2 of the platform-contact work will move outcomes on purpose. Every fragile
gate in the suite will fire when it does. This is the inventory.

## The shape of the problem

| | count |
|---|---|
| `_check` calls comparing two or more measured floats | **159**, across 65 test functions |
| of those, comparing two **sampled populations** | **22** test functions |
| test functions pinning a literal rally seed | **8** |
| of those, needing the rally to have a particular *shape* | **6** |
| of those six, guarding against that shape's absence | **0** |

## Finding 1 — Gate 22 asserts monotonicity on a dead channel

`_test_gate_twenty_two_setter_progression` requires:

```gdscript
bool(progression.get("quick_tempo_rate_monotonic", false))
```

Measured across setter tiers, at the production sample and at four times it:

| field | n=8 margin | n=32 margin | elite vs developing |
|---|---|---|---|
| `quick_tempo_set_rate` | +0.0000 | +0.0000 | **0.0000 vs 0.0000** |

**No setter of any tier ever runs a quick tempo set in this harness.** The clause
is satisfied by a channel that is zero for everyone, so it protects nothing and
would keep passing if setter tempo selection were deleted outright.

This is the same defect class as the unreachable `match` arms in
`UNREACHABLE_BRANCH_AUDIT.md` — a knob that cannot reach its own range — arriving
in a *test* rather than in the model. A gate whose metric is dead is worse than
no gate, because it reports safety.

`handoff_rate` is also 0.0000 for both tiers in this harness, which is worth a
look from whoever owns Gate 21.

## Finding 2 — the setter progression harness discards three quarters of its samples

| | requested | available | skipped |
|---|---|---|---|
| setter progression, n=8 | 160 | **37** | **123** |
| reception progression, n=2 | 120 | 117 | 3 |

77% of setter samples are skipped. Gate 22's `available > 0` check passes on the
37 that survive. Nothing says *why* the others are dropped, and a harness that
discards three quarters of its population may be selecting a biased subset — the
surviving rallies are, by construction, the ones that got far enough to have a
setter action worth recording.

Not diagnosed here. It is the next thing to look at before Gate 22 is trusted.

## Finding 3 — small samples are not automatically underpowered

Gate 4 runs at **n=2** and asserts `confidence_mean`, elite over weak:

| n=2 margin | n=8 margin | reading |
|---|---|---|
| +0.1995 | +0.2063 | stable |

The effect is large against its own noise and does not move with sample size.
**Gate 4 is fine.** Sample size alone is not the diagnostic; margin against noise
is. Cataloguing "gates with small n" and raising them all would have been busywork
that also slowed the suite.

Gate 10, by contrast, genuinely was underpowered — `decision_rate` runs +0.1111
at n=8 and +0.2005 at n=32, so the effect is real and *grows* with sample. Raising
it from four pairs to eight this session was correct, and it could go higher.

## Finding 4 — seed 1002 is now load-bearing for two gates, and it is the least robust

`run_seed_fixture_fragility.gd` asks the question that matters about a pinned
fixture: not whether the seed works today, but **what fraction of neighbouring
seeds would also have worked.** A property that holds on nine seeds in ten is
incidental to the seed. One that holds on three in four is a coin flip currently
showing heads.

| gate | seed | pinned holds | neighbours holding |
|---|---|---|---|
| `_test_shadow_reception_trace` | 1002 | yes | **30/40 = 0.75** |
| `_test_gate_fifty_continuous_reachability_timeline` | 1002 | yes | **30/40 = 0.75** |
| `_test_gate_fifteen_disabled_rollout` | 150001 | yes | 35/40 = 0.88 |
| `_test_geometric_attack_promotion_translates_a_rally` | 770012 | yes | 38/40 = 0.95 |
| `_test_minor_region_behaviour` | 77531 | yes | 40/40 = 1.00 |
| `_test_default_offense_without_saved_play` | 4411 | yes | 40/40 = 1.00 |

**Two gates now depend on seed 1002's serve landing in, and that seed is the
least robust of the six.** One of those two is a fixture I moved onto 1002 this
session while repairing the serve work — I moved it onto a seed another gate was
already standing on, and did not check either the concentration or the rate.
A quarter of nearby rallies do not reach a reception, so one physics change takes
out two gates at once.

The 0.75 figure is itself a serve-error consequence: the live serve error rate is
about 18–24%, so roughly a quarter of first-serve rallies never reach a reception
at all. Any fixture that needs a reception is drawing from a 75% population.

## The remedy, not applied here

A seed-pinned test that needs a rally *shape* should search a small range for the
first rally with that shape and assert the property holds *somewhere* in the
range, rather than pinning one seed and assuming. That converts "the fixture
broke" — which says nothing — into "this property is absent from forty
consecutive rallies", which is a real failure worth stopping for.

It is cheap to apply and it is a change to tests, so it is a separate pass with
its own suite run. The six candidates are listed above; the two at 1.00 do not
need it.

## Instrument notes

Both probes had to be corrected mid-audit, in the same way and for the same
reason:

- the power audit initially printed **nothing** for two of three gates, because
  the bucket keys were guessed (`by_player_tier` where the harness publishes
  `by_reader_tier` and `by_setter_tier`). A blank line reads exactly like "no
  finding". It now names the keys it could not find instead of staying silent.
- it then printed **margins only**, and a margin of zero cannot distinguish two
  tiers that are equal and active from two that are both dead. Finding 1 is only
  visible with absolutes beside the margin, and would have been invisible a
  revision earlier.

Both are the `FAILURE_MODES.md` §0 lesson happening inside an audit built to look
for §0 defects, which is the third time in two days. Assume the instrument is
wrong until it reproduces something already known.

## Re-running

```bash
godot --headless --path . --script res://tools/run_gate_power_audit.gd
godot --headless --path . --script res://tools/run_seed_fixture_fragility.gd
```

The power audit covers three gates of the twenty-two. Extending it is a matter of
adding rows to `CASES` with the right bucket and tier names — check them against
the harness rather than guessing, per the note above.
