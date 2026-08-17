# Short-ball responsibility: the lock did not ask whether the body could move

Run: 2026-08-17, from `63d3034`. Instrument:
`tools/run_short_ball_sweep.gd`. **One production change, and no weight was
swept.**

The governing policy:

> assignment → feasible controlled contact → existing relationship/tiebreak.
> Proximity informs feasibility ≠ authority. No blanket front-row priority. A
> compromised nominal claimant may transfer to a clearly viable adjacent
> defender. The immediate-control lock retains precedence.

with the sweep scoped to claimant **ordering** — no tuning toward a dig, kill,
side-out or rally-length target, and no standalone short-ball bonus unless the
existing authority + feasibility model demonstrably cannot express the policy.

---

## 1. Three of the six fixtures failed, and two of the three were my fixtures

This is the part worth reading first, because two "selector defects" were
instrument defects and would have justified changing weights that were fine.

| fixture | first verdict | after correction |
|---|---|---|
| 1 — clear responsibility → A | PASS | PASS |
| 2 — A compromised, B viable → B may own | **FAIL** | **fixture defect ×2** |
| 3 — boundary, two viable → relationship resolves | PASS | PASS |
| 4 — distant elite cannot steal | **FAIL** | **fixture defect** |
| 5 — committed blocker cannot auto-own | **FAIL** | **assertion too strong** |
| 6 — recovered blocker may own | PASS | PASS |

**Fixture 2, first draft.** "B clearly viable" was placed 2.88 m out on a 0.95 s
ball, where B's reach margin was **−1.047 m** — B was never a candidate at all.
"Never transferred" was measuring an empty alternative.

**Fixture 2, second draft.** With B genuinely viable it still never transferred —
but the debt only swept to 0.80 s on a 1.25 s ball, which leaves A 0.45 s against
a 0.37 s reaction. A could genuinely still play it, and keeping the ball was
*correct*. The sweep had never entered the regime it was named for.

**Fixture 4.** "Distant elite steals at 1.5 m" — 1.5 m is adjacent, not distant,
and both volis had been given the same zone priority, so the policy's opening
clause (assignment defines the plausible set) was not expressed at all. Two
co-owners with equal responsibility, the better athlete taking it, is not a
steal. With the near defender actually assigned and "distant" starting at 2.5 m,
nothing steals at any distance.

**Fixture 5.** The assertion was that *no* recovery debt could leave the ball
with the blocker. That is stronger than the policy and worse volleyball: a
blocker landing with 0.3 s of usable time and the ball a metre behind them digs
it, constantly. What the policy forbids is owning it **while unable to act**.

---

## 2. The defect, once the fixtures were honest

At **1.24 s of recovery debt against a 1.25 s ball** — one hundredth of a second
of usable time — the compromised defender still held `immediate_control`, still
fired the lock, and still took the ball off a fully available teammate:

| A's debt | A reach margin | A immediate | chosen |
|---:|---:|---|---:|
| 0.00 s | 1.373 | YES | 1 |
| 0.40 s | 0.852 | YES | 1 |
| 0.80 s | 0.348 | YES | 1 |
| 1.10 s | 0.334 | YES | 1 |
| **1.24 s** | **0.334** | **YES** | **1** |

The margin freezes at 0.334 because `available_time` floors at zero, so
`travel_distance` is zero and `physical_reach` collapses to `base_reach`. From
there **geometry alone grants possession**:

```gdscript
var immediate_control := distance <= base_reach + IMMEDIATE_CONTROL_STEP_METERS
```

Nothing in it asks whether the body can act. A voli owing more recovery than the
ball's entire flight immediately controls a ball landing on them.

This is the same root cause as fixture 5: a blocker still in the air, with zero
usable time, owning the tip dropped behind them.

---

## 3. The repair — and no weight moved

```gdscript
var immediate_control := available_time > 0.0 \
    and distance <= base_reach + IMMEDIATE_CONTROL_STEP_METERS
```

`available_time` is the ball's flight less this voli's recovery debt (subtracted
by `choose_claimant` before the call), less their reaction, less their turn. It
was already computed six lines above.

**No threshold was introduced.** The test is whether *any* usable time exists,
which is the absence of time rather than a quantity of it. How *much* time a
landing body needs to make a controlled contact is a different question and an
unmeasured one; it is not answered here.

**No standalone short-ball bonus was added, and no claim weight was changed.**
The policy proved expressible entirely inside the existing authority +
feasibility structure — which is what the sweep scope required be demonstrated
before any bonus could be justified. `claim_score`'s five terms are exactly as
they were.

### All six fixtures pass

The transfer point in fixture 5 is **emergent, not chosen**:

| blocker's debt | usable s | immediate | chosen |
|---:|---:|---|---:|
| 0.00 | 0.580 | YES | blocker |
| 0.20 | 0.380 | YES | blocker |
| 0.40 | 0.180 | YES | blocker |
| **0.58** | **0.000** | — | **defender** |
| 0.70 | 0.000 | — | defender |
| 0.90 | 0.000 | — | defender |

0.95 − 0.58 = 0.37 s, which is the voli's own reaction delay. The boundary is
where the body runs out of time, and nobody placed it there.

---

## 4. Observation: the outcome mix is byte-identical

600 rallies, before and after: 288 home points, 3,955 events, kill 154,
opponent_kill 174, attack_error 66, opponent_attack_error 43, counter_block 32,
blocked 18, ace 5, serve_error 108 — every figure unchanged.

**Reported, not targeted.** And it carries a real fact: byte-identical means no
live claim in this fixture ever reached the zero-usable-time condition. If one
had, the claimant would have changed and the mix would have moved. So the repair
is currently **latent in live play** and fires only where the compromised state
is constructed deliberately — which the sweep was explicitly authorised to do.

That puts it beside `ContactEnvelopeSystem`'s AIRBORNE takeoff gate: both are
correctness statements that become load-bearing once a body's compromised state
survives a leg boundary, and both are waiting on the same missing structure.

---

## 5. Tests

`_test_immediate_control_needs_a_usable_body`, two checks. Check 1 fails on the
pre-pass selector, verified by reverting the conjunct and re-running:

```
TEST FAILED: a voli with no usable time does not immediately control the ball on them
```

Check 2 — a viable teammate takes the ball the compromised body cannot — passes
on both and is **labelled an invariant** in the test. It guards the other
direction: that narrowing the lock did not open a hole where the ball belongs to
nobody.

Suite: **2,131 checks, no failures.**

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_short_ball_sweep.gd
```

Deterministic; no rally is resolved and no RNG is drawn.
