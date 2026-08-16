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

---

# Extension: three more gates

Added 2026-08-16, on `3249dbb`. Coverage is now **6 of 22**. Gate 39 (attack
progression), Gate 46 (blocker progression) and Gate 21 (setter handoff) joined
the sweep, and the tool learned to discover its own bucket key.

## The instrument was wrong twice more, in two new ways

Both worth recording because both are the same §0 shape as the first two, and
both produced output that looked fine.

- **The `const` dictionary is read-only through every reference.** The first
  extended run aborted on its first case: `Dictionary(entry)` wraps a `const`
  entry, it does not copy it, so writing the discovered bucket key back into the
  case was an assignment to read-only state. The discovered key now lives in a
  local.
- **The production `n` and seed were guessed round numbers.** `CASES` carried
  `n=6, seed=300000` for attack progression; the gate runs `n=12, seed=420000`.
  Measuring the right harness on the wrong population is the bucket-key mistake
  one column over, and it is *less* visible, because the output is full of
  plausible figures rather than blank. Every row is now read out of
  `test_runner.gd`.

The figures below are at the sample sizes the gates actually run at.

## Finding 5 — Gate 46 is the only gate whose asserted margins are thin, and it already guards itself

At its production `n=8`, elite against developing:

| field | margin n=8 | margin n=32 | elite vs developing | asserted? |
|---|---|---|---|---|
| `confidence_late_mean` | +0.2546 | +0.2527 | 0.7780 vs 0.5253 | yes |
| `recognition_delay_mean` | −0.1674 | −0.1674 | 0.0828 vs 0.2502 | yes |
| `maximum_speed_mps_mean` | +0.0000 | +0.0000 | **2.7214 vs 2.7214** | yes |
| `wrong_read_rate` | −0.0208 | −0.0130 | 0.0495 vs 0.0625 | yes |
| `hesitation_rate` | −0.0208 | −0.0260 | **0.0000** vs 0.0260 | yes |

**The zero row is the assertion, not a defect.** Gate 46 asserts
`movement_speed_tier_independent` — stronger readers see more and earlier
*without moving faster* — so two identical figures are the gate passing on
purpose. That is exactly the distinction Finding 1 needed absolutes to make, and
here the same reading comes out the other way. A margin of zero means nothing
until you know which direction the gate wanted.

`wrong_read_rate` is the thinnest genuinely-directional margin in the audit:
1.3 percentage points, holding its sign at four times the sample. `hesitation_rate`
is a floor effect — elite hesitate exactly never — and Gate 46 is the one gate in
the suite that already carries the guard against a floor becoming a hole:

```gdscript
## A monotonic rate over an all-zero column proves nothing. The sweep has to
## actually contain the outcomes it claims to be calibrating.
bool(coverage.get("hesitation_observed", false))
```

**That comment is the fix for Finding 1, written by whoever built Gate 46 and
never backfilled to Gate 22.** The practice exists in this codebase; it is just
not applied uniformly. Gate 22's `quick_tempo_rate_monotonic` is precisely the
case the comment describes.

### Why Gate 22's dead channel is dead

Traced this time rather than left as an observation. `quick_tempo_set` is
appended only under a four-way conjunction:

```gdscript
if opportunity.reachable and opportunity.arrival_balance >= 0.68 \
        and confidence >= 0.58 and player.tempo_control >= 68:
```

Gate 22's own fixture reports `arrival_margin_mean_seconds` of 0.1436 for elite
setters and 0.0083 for developing ones — the harness's setters arrive with almost
no margin at all — and `standing_set_rate`, which needs only 0.38 balance, is
0.1351 for elite and 0.0000 for developing. A 0.68 balance threshold sits above
everything the fixture produces.

So this is not merely an unused option: it is **a threshold outside the
distribution it acts on**, `FAILURE_MODES.md` §0 verbatim, and it is guarded by a
gate clause that reports the situation as healthy. Nobody measured the joint
distribution of four conditions before requiring all four.

## Finding 6 — two of Gate 39's five clauses have never disagreed

Gate 39 at `n=12`, elite against developing:

| field | margin n=12 | margin n=48 | elite vs developing |
|---|---|---|---|
| `confidence_mean` | +0.2057 | +0.2063 | 0.7742 vs 0.5679 |
| `perceived_reachable_rate` | +0.8333 | +0.5833 | 1.0000 vs 0.4167 |
| `true_reachable_rate` | +0.9167 | +0.9792 | **0.9792 vs 0.0000** |
| `executable_action_rate` | +0.9167 | +0.9792 | **0.9792 vs 0.0000** |
| `action_count_mean` | +4.3333 | +4.1667 | 4.5833 vs 0.4167 |

`true_reachable_rate` counts `response.true_reachable`; `executable_action_rate`
counts a non-empty `selected_action`. Different quantities, and **identical on
every sample at both sizes**. Either a hitter selects an action exactly when the
ball is truly reachable — in which case one of the two clauses is free — or this
fixture never produces the case that separates them.

Not a defect, and not repaired: a redundant clause costs nothing but a false
sense of five independent checks. It is listed because "five clauses" and "four
clauses and a copy" are different amounts of protection and the gate reads as the
former.

Every other Gate 39 margin is enormous and stable. If any gate in the suite could
run *smaller*, it is this one.

## Finding 7 — a sign flip that is not a finding, and how to tell

Gate 21 at `n=6`:

| field | margin n=6 | margin n=24 | reading | asserted? |
|---|---|---|---|---|
| `handoff_valid_rate` | +1.0000 | +1.0000 | stable | yes |
| `selected_reachable_rate` | +1.0000 | +0.6745 | stable | no |
| `expected_reachable_rate` | +0.6667 | +0.1451 | **shrinks with sample** | no |
| `available` | −4.0000 | +2.0000 | **SIGN FLIPS** | as `> 0` only |
| `skipped` | +4.0000 | −2.0000 | **SIGN FLIPS** | no |

Two sign flips and a collapsing margin, and **none of the three is a gate risk**.
`available` and `skipped` are sample *counts* across two differently-sized
fixtures; the gate asserts only that both exceed zero, which they do at 17 and 15.
`expected_reachable_rate` is published and unread.

This is the reading the instrument cannot do for you. The tool sweeps every
numeric field a harness publishes, and across these six harnesses the gates assert
on roughly a dozen of the fifty-odd fields available. **The unread fields are
where a dead channel hides until a clause reaches for it** — which is the entire
history of Gate 22's `quick_tempo_set_rate` — but a flag on an unread field is
diagnosis, not alarm.

## What the extension changes about the original conclusion

Nothing about Findings 1–4, and one thing about the framing. The first pass read
as "gates are fragile". Six gates in, the distribution is clearer:

- **most asserted margins are very large** — Gate 39 and Gate 22's
  `controlled_set_rate` sit at 1.0000 against 0.0000;
- **one gate is genuinely thin** (Gate 46, and it guards itself);
- **one clause is vacuous** (Gate 22's quick tempo), and it is vacuous because a
  threshold sits outside its distribution rather than because the gate is weak.

The risk is concentrated, not spread. Sixteen gates remain unmeasured.
