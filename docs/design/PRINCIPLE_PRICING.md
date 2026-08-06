# What a team principle costs, and what it buys

Date: 2026-08-06
Measured at: `ecd04b4`.

Status: **measured, one defect fixed, half the gate closed.** §8 records what
the fix did, what it did not do, and the one band it moved the wrong way.

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

## 6. Why no fix in the first pass

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


---

## 8. What the fix did — 2026-08-06, `ccb59b6`+

### The change

One term, in both walls, touching only the assist blocker.

The block's closing budget is mostly *pre-set*. Measured, the window ahead of
the set runs 0.78–1.07 s and barely moves with tempo, while the set's own
flight runs 0.20–0.99 s:

| tempo | set flight | close budget | pre-set portion |
| ---: | ---: | ---: | ---: |
| 0 | 0.204 | 0.988 | 0.784 (79%) |
| 1 | 0.380 | 1.266 | 0.886 |
| 2 | 0.440 | 1.372 | 0.932 |
| 3 | 0.993 | 2.064 | 1.071 |

At tempo 0, **79% of the blocker's closing time is credited before the ball is
set**. For the primary that is fair — they are by definition the blocker
already nearest the attacked lane, so their pre-set time is spent reading. For
the assist, who has to cross a slot, it credits them with having crossed it
before the lane was chosen.

`ASSIST_COMMIT_FLIGHT_SECONDS` now bounds what the assist's read can buy by how
much post-set time they have to *finish* the crossing. Anticipation still pays;
it just cannot substitute for the ball existing.

The constant is anchored on `primary_close_terms.required_seconds`, which runs
0.58–0.67 s across tempos 0–2 — the measured cost of a close, and therefore the
post-set time an assist needs before committing is worth it. **Set to 0.65.**
Tried first at 0.95, taken from the high ball's own flight, and that was far too
severe: double blocks fell to 18% at tempo 1 and 24% at tempo 2, which deletes
the ordinary read block rather than the one that should not have formed.

### Double-block rate by tempo

| tempo | before | at 0.95 | **at 0.65** |
| ---: | ---: | ---: | ---: |
| 0 | 0.368 | 0.000 | **0.000** |
| 1 | 0.823 | 0.182 | **0.374** |
| 2 | 0.883 | 0.239 | **0.460** |
| 3 | 0.960 | 0.962 | **0.960** |

A zero-tempo ball now never draws a double block, which is the correction that
started this: zero tempo is a setter capability, and it has to be *committed*
to rather than read. The 1→2→3 band has real slope where it was flat.

### What it fixed, and what it did not

The gate's two clauses moved apart completely.

| clause | before | after |
| --- | ---: | ---: |
| error rate, Defensive − Physical | −0.0008 | **−0.0352** |
| kill rate, Defensive − Physical | +0.0574 | +0.0501 |

**The error-rate clause is genuinely fixed.** It was passing on 0.6% — a margin
indistinguishable from noise, and three of these gates have historically gone
red purely from an unrelated change shifting the RNG stream. It now passes on
22%, and for the right reason: a decisive side pressing quick tempo against a
wall that can no longer double it takes more risk and errs more (0.1440 →
0.1592) while a conservative one errs less (0.1432 → 0.1241).

**The kill-rate clause is not fixed.** Isolated, `decisiveness` still runs
0.3875 / 0.3170 / 0.2765 against 0.3977 / 0.3237 / 0.2825 before — essentially
unmoved. The block was not what was pricing it.

That is a useful negative result. The remaining inversion is **entirely on the
hitter's side of the chain**: a quicker set costs 35% of the hitter's arrival
margin, and the identity lever only moves the mean tempo from 1.97 to 1.25,
where the double-block difference is now 9 points. Nine points of block relief
does not pay for a third of the approach. Whatever fixes the second clause is a
change to what a rushed approach costs, not to the wall.

### The regression this caused, and the state it landed in

`stuff_rate` moved from **0.0333 (inside, margin +0.0033) to 0.0243 (outside,
margin −0.0057)** on the default calibration fixture. Fewer double blocks means
fewer terminal blocks; that is the change working as designed, and it crossed a
floor it was already sitting on.

It should be read against the fixture's actual state, which is worse than one
metric. Measured at 160 samples, **five of eight reference metrics were already
outside their bands before this change**:

| metric | before | after | band |
| --- | ---: | ---: | --- |
| side_out_rate | 0.531 ✗ | 0.556 ✗ | [0.58, 0.78] |
| ace_rate | 0.000 ✗ | 0.000 ✗ | [0.02, 0.10] |
| serve_error_rate | 0.141 ✓ | 0.141 ✓ | [0.08, 0.20] |
| kill_rate | 0.311 ✗ | 0.298 ✗ | [0.38, 0.60] |
| attack_error_rate | 0.267 ✗ | 0.285 ✗ | [0.06, 0.20] |
| stuff_rate | 0.033 ✓ | **0.024 ✗** | [0.03, 0.14] |
| block_touch_rate | 0.051 ✗ | 0.038 ✗ | [0.15, 0.45] |
| mean_contacts | 6.67 ✓ | 6.67 ✓ | [4.0, 9.0] |

`block_touch_rate` at 0.051 against a floor of 0.15 is the one to notice: the
wall on this fixture already touches the ball **three times less often than the
reference band expects**, and that predates this work entirely. Which is worth
holding beside §4's finding that double blocks *form* on 82% of swings —
formation and contact are not the same thing, and the gap between them is
large and unexamined.

**Nothing gates on any of this.** The suite reports 925 checks with the one
known failure both before and after; the reference bands are computed, printed
into `outside_reference`, and asserted nowhere. A fixture five metrics out of
band that no test objects to is its own finding, and a bigger one than the gate
this pass set out to close.

### Next

1. The hitter's side of the tempo chain — what a rushed approach costs — is
   what the kill-rate clause is waiting on.
2. Recalibrate the fixture, or the bands, or gate on them. At present they are
   documentation.
3. `block_touch_rate` at a third of its floor, against 82% double-block
   formation, wants explaining before either of the above is tuned against it.


---

## 9. The correction — commitment, not just flight

§8's fix produced **zero double blocks at tempo 0. Every rally, every wall,
every roster.** That is not a model of anything. It is a threshold driving a
degenerate distribution, which is the same defect class §5 names — arrived at
by fixing a different instance of it.

The reasoning was wrong, not just the constant. Bounding the assist by the
set's flight alone says *no one can be there on a quick ball*, and that is
false in the sport for two named reasons:

- **Commit blocking exists.** A blocker who decided before the set to be at the
  middle is there when the middle is set. That is what committing is for, and
  it is the standard answer to a first-tempo offence.
- **Blockers read.** A fast reader who picks the setter's body early gets there
  sometimes, and should.

So only the **reactive** share of the pre-set credit is bounded by the flight.
The committed share survives whatever the tempo, because committing is a
decision taken *before* the tempo is known. Its cost is already priced
elsewhere: a wall that commits and guesses wrong has moved away from where the
ball went.

`_assist_committed_share(commitment, read_quality)` reads the wall's own
`block_commitment` principle and its measured read, and is applied identically
on both sides of the net so neither bench gets a block philosophy the other
lacks. The floor and span put the median wall — both inputs near 0.5 — near
zero committed share, and a genuinely committed or fast-reading one near full.

### Double-block rate by tempo, all three versions

| tempo | original | flight-only | **committed-aware** |
| ---: | ---: | ---: | ---: |
| 0 | 0.368 | 0.000 | **0.053** |
| 1 | 0.823 | 0.374 | **0.577** |
| 2 | 0.883 | 0.460 | **0.635** |
| 3 | 0.960 | 0.960 | **0.959** |

A zero ball now draws a second blocker about one time in twenty, and when it
does it is because that wall committed or read it — not because the arithmetic
allowed it.

### Gate state

| clause | original | flight-only | committed-aware |
| --- | ---: | ---: | ---: |
| error rate, Defensive − Physical | −0.0008 | −0.0352 | **−0.0195** |
| kill rate, Defensive − Physical | +0.0574 | +0.0501 | **+0.0415** |

The error clause still passes on 13% where it used to pass on 0.6%. The kill
clause still fails, but the gap is 28% smaller than where this started — and
notably the gentler fix closes *more* of it than the severe one did, so the
mechanism is not simply "fewer double blocks".

`stuff_rate` recovered most of what §8 cost: 0.0284 against a 0.030 floor
(margin −0.0016) where the flight-only version read 0.0243 (−0.0057) and the
baseline 0.0333 (+0.0033). Still a hair outside, on a fixture where five other
metrics are far outside and nothing gates on any of them. Tuning the two new
constants to chase a metric sitting within noise of its floor, on that fixture,
would be fitting to noise.

Suite unchanged throughout: 925 checks, the one known failure.

### A caveat on every number in this document

These are **static sweeps**. The defensive plan, the blocking strategy and the
identity are fixed for the whole run; nothing learns, scouts, or adjusts
between rallies. A real match has a bench that watches a quick offence work
twice and starts committing to it, and that feedback loop is exactly what
decides whether running quick stays profitable. None of it is modelled here, so
every rate above should be read as "what this configuration does against that
one", not as what the game does over a set.
