# `readiness` was a field, not a quantity

Run: 2026-08-17, immediately after `MOVING_ORIENTATION.md` closed orientation.
Instrument: `tools/run_readiness_audit.gd`.

Verdict: **REMOVED.**

---

## 1. The finding, which ends the audit before it starts

Every assignment form — `=`, `+=`, `-=`, `*=` — across `scripts/`, `tests/` and
`tools/` returns exactly one hit:

```
scripts/models/rally_player_state.gd:126:  copy.readiness = readiness
```

That is `snapshot()` propagating the declared default. **Nothing in production
ever moved it off 1.0.** The field was not under-specified; it was inert, and
its three consumers were consuming a constant.

| consumer | what it evaluated to |
|---|---|
| `lerpf(1.18, 0.92, readiness)` on takeoff time | always **0.92** |
| `accessible_jump * readiness` | always **×1.0**, an identity |
| `readiness < 0.45` in the setter classifier | **could never fire** |

The third is `FAILURE_MODES.md` §0 in its purest form: a threshold at 0.45
acting on a distribution that is a single point at 1.0. The classifier's
`body_state` cause was already, in every real rally, entirely `balance < 0.38`.

---

## 2. Why derivation was not the answer

The policy's §3 nominates BodyState, MovementMode, balance, recovery/landing and
approach as readiness's inputs; §8 permits it two consequences. Measured, every
one of those inputs already reaches both of those consequences by a route that
is physical rather than scalar:

**Takeoff preparation**, by run-up quality — already live:

| `runup_quality` | takeoff time |
|---:|---:|
| 0.00 | 0.2162 s |
| 0.35 | 0.1693 s |
| 0.70 | 0.1224 s |
| 1.00 | 0.0822 s |

**Accessible extension**, by body state and balance — already live:

| body state | horizontal reach (bal 1.0 / 0.35) | can take off |
|---|---:|---|
| BALANCED | 0.3983 / 0.3413 | yes |
| REACHING | 0.4381 / 0.3755 | yes |
| MOVING | 0.3585 / 0.3072 | yes |
| AIRBORNE | 0.3266 / 0.2799 | **yes** ← |
| DIVING | 0.2191 / 0.1877 | no |
| RECOVERING | 0.2708 / 0.2321 | no |

There is no consequence left for a separate preload scalar to own. §10 applies:
*prefer eliminating the redundant scalar over inventing semantics merely to
preserve the field.*

---

## 3. The one genuine physical gap it was standing in front of

Read the AIRBORNE row. `_horizontal_reach` gives an airborne body a posture
factor of **0.82** against a balanced 1.0 — the model already believes it is
compromised — and `can_take_off` ten lines above still lets it leave the floor
again. DIVING and RECOVERING are excluded by name; AIRBORNE was not.

Repaired as a body-state gate, which is what it physically is and is exactly how
its two neighbours are already expressed. **No coefficient introduced.**

Honestly scoped: this changes nothing measurable today. `recovery_until` already
shadows an airborne body — the four live integrators set AIRBORNE and a recovery
window together, and `is_available` refuses the actor before the envelope is
ever asked. The gate is a correctness statement that becomes load-bearing the
moment any path asks the envelope about a body mid-flight. It is recorded as a
repair to an unreachable case, not as a live defect closed.

---

## 4. The trap in removal, and how it was avoided

`lerpf(1.18, 0.92, 1.0)` = **0.92**, baked into every takeoff the engine has
ever resolved. Deleting the readiness factor without folding it would have made
every takeoff **8.7% slower** and called it a cleanup — a real calibration shift
wearing a refactor's clothes, which is the failure this repository keeps
catching.

Folded exactly:

```gdscript
## was: lerpf(0.34, 0.13, explosiveness) * lerpf(1.18, 0.92, readiness)
var takeoff_time := lerpf(0.3128, 0.1196, explosiveness)
```

0.34 × 0.92 = 0.3128 and 0.13 × 0.92 = 0.1196. The other two consumers needed no
fold: one was an identity, and the classifier clause could not fire.

---

## 5. What changed

| file | change |
|---|---|
| `rally_player_state.gd` | field and snapshot copy removed; a comment in their place says why |
| `contact_envelope_system.gd` | constant folded; `* readiness_factor` dropped; **AIRBORNE added to the takeoff exclusion** |
| `setter_failure_classifier.gd` | the unreachable `readiness < 0.45` clause and its evidence key dropped |
| `shadow_setter_response_system.gd` | the `final_readiness` publication dropped |

**Outcome mix over 600 rallies is byte-identical**: 295 home points, kill 151,
opponent_kill 164, attack_error 69, opponent_attack_error 40, counter_block 45,
blocked 18, ace 5, serve_error 108. Which is what an exact fold plus an
unreachable gate must look like.

---

## 6. Tests

`_test_readiness_is_body_state`, three checks. Two fail on the pre-pass engine,
verified by restoring the field and removing AIRBORNE from the exclusion:

```
TEST FAILED: a body off the floor or on it cannot take off for a second contact
TEST FAILED: no free-running readiness meter survives beside the body state
```

The third — a cleaner run-up reserves less stationary takeoff preparation — is
an **invariant** and is labelled as one in the test. It was true before the
removal and is true after; it guards against a future pass reintroducing a third
factor spending the same preparation the run-up already spends.

Suite: **2,126 checks, no failures** — 2,123 plus exactly the three written.

---

## 7. What is not claimed

Nothing here says a physical preload quantity would be worthless. It says the
engine did not have one, and that manufacturing values for it would have meant
choosing 0.6 or 0.8 by taste — which §9 forbids and which no measurement in this
repository supports. If a later pass wants one, it needs a measured relation
between landing, load and takeoff, and it should start from the AIRBORNE gate
above rather than from a scalar named after the idea.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_readiness_audit.gd
```

Layer 1's proof is now structural: the probe reads no `readiness` anywhere, and
would fail to parse if it did.
