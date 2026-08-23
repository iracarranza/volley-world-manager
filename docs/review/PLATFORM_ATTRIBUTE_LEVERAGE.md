# Platform attribute-leverage certification

Run: 2026-08-17, after M3 promotion. Instrument:
`tools/run_platform_attribute_leverage.gd`. Four fixed rating tiers, 400 paired
draws per tier and circumstance.

This is an architecture certification, not a balance target. It asks whether a
physical platform model can be introduced without making the volis disappear:

```text
same ball + same body circumstance + same intent + same RNG
different attributes
→ observably different feasible contact
```

The current production paths are deliberately measured as they exist.
Reception resolves quality and then `_reception_pass_result`; floor defence
resolves `_defense_terms` / `_dig_outcome` and then `_dig_pass_result`. The probe
does not claim these are already one resolver and does not introduce a semantic
dig-pass class that production does not own.

---

## 1. Bundle sweep

### Easy, physically feasible contact

Every tier contacts and controls the ball. Skill changes what leaves the body.

| path | ratings | survives | mean quality/control | target error | angle error | apex | mean setter tempo options |
|---|---:|---:|---:|---:|---:|---:|---:|
| reception | 20 | 100% | 0.286 | 1.561 m | 26.55° | 3.23 m | 2.00 |
| reception | 80 | 100% | 0.885 | 0.212 m | 3.28° | 4.44 m | 3.00 |
| floor dig | 20 | 100% | 0.108 | 2.029 m | 38.73° | 3.17 m | 2.00 |
| floor dig | 80 | 100% | 0.736 | 0.640 m | 9.48° | 3.76 m | 3.00 |

This is the required easy-contact shape: physics does not erase the weak voli's
play, and attributes still buy control, direction and downstream choice.

### Difficult but feasible contact

| path | ratings | survives | mean quality/control | target error among survivors | angle error among survivors |
|---|---:|---:|---:|---:|---:|
| reception | 20 | 0% | 0.000 | — | — |
| reception | 40 | 0% | 0.004 | — | — |
| reception | 60 | 72.5% | 0.163 | 1.489 m | 24.70° |
| reception | 80 | 100% | 0.417 | 0.955 m | 15.19° |
| floor dig | 20 | 0% | 0.054 | — | — |
| floor dig | 40 | 57.0% | 0.117 | 2.582 m | 52.06° |
| floor dig | 60 | 100% | 0.281 | 2.235 m | 43.71° |
| floor dig | 80 | 100% | 0.527 | 1.691 m | 30.71° |

This is the required difficult-contact shape: the circumstance remains the
same, while the rating bundle creates a large and monotonic difference in both
survival and the ball produced after survival.

### Impossible contact

A fixed non-arrival produces no platform attempt at every rating. The transfer
helpers sit after `receiver_arrived` / `dug`; neither stamps a trajectory on a
miss. The M3 gate independently proves an elite body is not teleported to a
contact when no travel time exists.

Attributes therefore affect what a feasible body can execute. They do not
override the physical-contact gate.

---

## 2. Individual attributes are not inert

The difficult fixture was repeated with every other rating fixed at 50 and one
attribute moved 20 → 80.

### Reception

| attribute | playable rate, low → high | target error, low → high |
|---|---:|---:|
| reception | 0.0% → 97.0% | no low survivor → 1.461 m |
| ball_control | 5.5% → 49.0% | 1.858 → 1.614 m |
| composure | 10.8% → 43.0% | 1.801 → 1.736 m |
| reception_balance | 5.5% → 49.0% | 1.842 → 1.631 m |
| reception_stability | 19.0% → 34.0% | 1.951 → 1.622 m |

### Floor dig

| attribute | dig rate, low → high | target error, low → high |
|---|---:|---:|
| reception | 56.0% → 100% | 2.587 → 2.230 m |
| anticipation | 67.5% → 100% | 2.575 → 2.258 m |
| dig_control | 77.8% → 100% | 2.539 → 2.311 m |
| lateral_speed | 93.0% → 100% | 2.513 → 2.361 m |

All nine currently relevant ratings move a controlled outcome in the expected
direction. This certifies leverage, not ownership.

---

## 3. What is certified, and what is not

**Certified:** a platform migration can preserve the game's attribute premise.
Weak and elite volis remain separated after circumstance is held fixed; the
separation reaches physical output and setter options, not only a result label.
Two deterministic suite gates hold reception and floor-dig leverage under an
identical draw.

**Not certified:** the present stage ownership. Reception and `ball_control`
enter `_reception_skill`, then enter `_reception_pass_result` again through
`platform_feasibility`. `dig_control` contributes to defence capability and also
shrinks execution spread. The first is known double-spending; the second may be
a defensible technique/consistency split, but the forthcoming physical resolver
must name it explicitly rather than inherit it accidentally.

**Not certified:** current magnitudes as tuning targets. The controlled fixtures
were chosen to discriminate easy, difficult and impossible regimes. They are not
a claim that 1.561 m is an acceptable pass error or that 57% is the correct dig
rate.

**Not invented:** floor digs still have no production pass-class vocabulary.
The probe reports `unowned`; it does not map control to GOOD/OK/SHANK/MISS.

**Still open:** T1 retention/generation magnitude, T2 reachable angle, and T3
angle-error distribution. Attribute leverage is now a gate those relations must
preserve, not evidence from which their physical magnitudes can be authored.

## Verdict

**ATTRIBUTE LEVERAGE: CERTIFIED FOR THE CURRENT PLATFORM PATHS.** Do not use
physics as a replacement for player ratings, and do not preserve current
double-spending merely because this sweep is monotonic. M4's next dependency is
still the T1–T3 physical relation, with this certification run before and after
any shadow or promotion.
