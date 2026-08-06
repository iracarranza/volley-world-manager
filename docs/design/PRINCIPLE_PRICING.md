# What a team principle costs, and what it buys

Date: 2026-08-06
Measured at: `ecd04b4`.

Status: **the measurement is done and the defect is located. No fix is applied
here.** The last section says exactly what to change and why it was not changed
in the same pass.

This exists because a suite gate has been red for a long time under a diagnosis
nobody had tested — "tempo priced backwards" — and the first thing an isolated
measurement showed was that the diagnosis named the wrong quantity.

---

## 1. The red gate, and what it actually says

`defensive attack lowers both error risk and terminal pressure across six career
seeds` asserts two things at once:

```
defensive.home_attack_error_rate < physical.home_attack_error_rate
defensive.home_kill_rate         < physical.home_kill_rate
```

Measured at the gate's own sample size (48 rallies × 6 career seeds):

| | Defensive | Physical | delta | |
| --- | ---: | ---: | ---: | --- |
| `home_attack_error_rate` | 0.1432 | 0.1440 | −0.0008 | passes, but on 0.6% |
| `home_kill_rate` | 0.3633 | 0.3059 | **+0.0574** | **fails, by 19%** |

So one half passes on a margin indistinguishable from noise and the other fails
by a wide, clearly-signed margin. **Physical has the lowest kill rate of all six
identities** — the power identity attacks worst.

Full table, all six identities:

| identity | home kill | home attack error | serve error | ace |
| --- | ---: | ---: | ---: | ---: |
| Technical | 0.3907 | 0.1325 | 0.1337 | 0.0017 |
| Defensive | 0.3633 | 0.1432 | 0.1337 | 0.0017 |
| Development | 0.3284 | 0.1536 | 0.1337 | 0.0017 |
| Balanced | 0.3238 | 0.1445 | 0.1441 | 0.0017 |
| Fast Tempo | 0.3168 | 0.1454 | 0.1458 | 0.0017 |
| Physical | 0.3059 | 0.1440 | 0.1510 | 0.0035 |

The serving half of Physical works exactly as designed — most pressure, most
aces, most errors. It is the attacking half that is inverted.

---

## 2. Why a ranking across identities cannot answer this

The presets co-vary almost completely. Physical is high on every principle
(decisiveness 0.86, pin focus 0.82, serve aggression 0.78, transition commitment
0.76, block commitment 0.82); Defensive is low on every one (0.18 / 0.42 / 0.22
/ 0.28 / 0.26). A kill-rate ordering across the six identities correlates
negatively with *all* of them and therefore identifies none of them.

This is the confound `MEASUREMENT_CONFOUNDS.md` exists to catch, arriving from a
direction it had not recorded: not two numbers taken under different conditions,
but **seven conditions moved at once and one number read off the end**.

`RallyReadinessReport._sweep()` and `outcome_calibration()` now take
`principle_overrides`, which sets named principles on the home team after the
identity is applied. `tools/run_principle_isolation_probe.gd` uses it to pin six
principles at 0.50 and sweep the seventh.

---

## 3. What each principle is actually worth

Six careers × 32 rallies × both serving sides, generated rosters, everything
except the named principle held at 0.50.

| principle | 0.15 | 0.50 | 0.85 | verdict |
| --- | ---: | ---: | ---: | --- |
| `decisiveness` | 0.3977 | 0.3237 | 0.2825 | **backwards**, −29% |
| `transition_commitment` | 0.4288 | 0.3237 | 0.3157 | **backwards**, −26% |
| `tempo_variation` | 0.3078 | 0.3237 | 0.3237 | one-sided; 0.50 and 0.85 identical |
| `serve_aggression` | 0.3171 | 0.3237 | 0.3236 | inert on kills, as it should be |
| `block_commitment` | 0.3164 | 0.3237 | 0.3266 | mild, right sign |
| `pin_focus` | 0.3237 | 0.3237 | 0.3237 | **no effect at all** |

Two things fall out.

**`pin_focus` produced bit-identical output at all three levels.** It has a
consumer — `_choose_assignment` weights pin lanes against middle lanes by it —
but in this fixture that branch either never runs or never has two candidates to
choose between. Whether that is a fixture limitation or a dead lever is not yet
established, and it should not be assumed to be the former.

**`decisiveness` and `transition_commitment` are the whole inversion.** They are
the two principles Physical is high on and Defensive is low on, and both cost
kills. Together they more than account for the gate's 0.057 gap.

---

## 4. The chain, link by link

Both principles reach the attack through one place. `_apply_identity_tempo()`
blends them:

```gdscript
var commitment := lerpf(decisiveness, transition_commitment, 0.45)
if commitment >= high_gate:  tempo_shift -= 1   # quicker set
elif commitment <= low_gate: tempo_shift += 1   # slower set
```

So a committed identity runs quicker sets. Measured on the isolated
`decisiveness` sweep, with everything else at 0.50:

| decisiveness | mean tempo | arrival margin | approach quality | primary close | assist close | double-block rate | kill | stuff |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.15 | 1.968 | 0.0414 | 0.3833 | 0.9709 | 0.6638 | 0.7690 | 0.3733 | 0.0922 |
| 0.50 | 1.547 | 0.0404 | 0.3613 | 0.9519 | 0.6620 | 0.7671 | 0.2991 | 0.0888 |
| 0.85 | 1.245 | 0.0267 | 0.3469 | 0.9332 | 0.6278 | 0.7427 | 0.2639 | 0.1065 |

Every link is signed correctly. Quicker sets do squeeze the hitter, and they do
relieve the block. **The two are simply not the same size.**

Across nearly a full tempo step (1.97 → 1.25):

- the hitter loses **35%** of their arrival margin (0.0414 → 0.0267) and 9.5%
  of their approach quality;
- the block gives up **3.4%** of its double-block rate (0.769 → 0.743), 5.4% of
  its assist closure and 3.9% of its primary closure.

An order of magnitude apart. **77% of all swings face a double block whatever
the tempo.** In the sport, a first-tempo ball to a middle routinely draws a
single blocker; here the wall is essentially always there, so running quick is
all cost.

This is not a missing mechanism. `_form_opponent_block` computes `close_time`
from the set's real flight time, exactly as its comment claims, and closure does
reach `block_quality` through `_block_contact_skill`. The channel exists and is
too weak to matter.

---

## 5. Where the strength went

Two candidates, both located, neither yet tested by changing it.

**The pre-set window swamps the set's flight time.** `close_time` is

```
set_flight_time
  + preset_window_seconds * preset_share      # 0.26 to 0.72 by read quality
  + (1 - set_quality) * 0.10
  + read and commitment shifts
```

Only the first term varies with tempo. If the pre-set window is comparable to
the set's flight, then most of the wall's closing happens before the set exists
and tempo cannot move it much. That would explain the entire magnitude gap.

**`primary_close` is a gate outside its own distribution.** In `_contest_block`:

```gdscript
if contest > attack_quality + BLOCK_STUFF_MARGIN + intent_shift.stuff \
        and primary_close >= 0.78:
    outcome = "stuff"
```

Measured `primary_close` runs **0.933 to 0.971**. The gate is at 0.78. It never
binds, at any tempo, for any identity. Closure therefore influences the stuff
outcome only through `block_quality`, and not at all as the "did the wall
actually seal" test it is written to be.

That second one is this project's signature defect class and worth naming as
such: **a threshold set outside the distribution it cuts.** It joins
`RECOVERY_POOR_SHARE` at p75, `RECOVERY_HEAVY_FORCE` documented as "top tenth"
and measured at p68, and `RECOVERY_ANCHOR_SWING` putting a threshold at 1.11 on
a scale capped at 1.0. Every one of them looks like a considered constant and is
inert.

---

## 6. Why no fix in this pass

The change is a rebalance of the block, and the block's outcome rates sit in
`REFERENCE_BANDS` with several suite checks on them. `MEASUREMENT_CONFOUNDS.md`
records the last attempt at a home-tempo decision change: it closed `dig`, moved
the points baseline, cost `attack_quality` and `kill`, **broke the suite twice —
two failures then seven — and was stashed rather than pushed both times.**

Making that change at the end of a long session, on a suite that already carries
one red check, with no room left to re-run the match-sense gate beside it, is
how a measured finding turns into two unmeasured ones. The instruments and the
finding are worth landing on their own; the balance change wants its own pass.

## 7. The next step, precisely

1. Measure `preset_window_seconds` against `set_flight_time` per tempo. If the
   pre-set window dominates, that is the fix and nothing else needs touching.
2. Replace the `primary_close >= 0.78` gate with a graded term. A wall that
   closed 0.93 and one that closed 0.97 should not be the same wall, and
   currently they are.
3. Re-run the full suite **and** `tools/run_match_sense_report.gd` together, per
   the confounds doc. The target is `home_kill_rate` ordered with decisiveness
   rather than against it, without moving `stuff_rate` outside its reference
   band.
4. Settle whether `pin_focus` is inert in the fixture or inert everywhere. If
   everywhere, it is a principle the player can set that does nothing, which is
   worse than a missing feature because it reads as working.
