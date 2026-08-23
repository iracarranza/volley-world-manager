# The receive leg: audited, already authoritative, no production change

Run: 2026-08-16, on `9ffc1f2`. Instrument:
`tools/run_receive_chain_probe.gd`. **No production code changed** — and that is
the finding, not a shortfall. The pass was authorised to stop if the gates turned
out to be already satisfied. They are.

The leg audited, immediately after the certified serve:

```text
authoritative serve → choose receiver → ball-timed movement/read
→ realized reception → quality/playability → ONE pass
```

---

## 1. The before-flow, exactly

`rally_simulator.gd`, home side. The opponent path mirrors it; §6 notes the one
asymmetry.

| # | line | what happens | authority |
|---|---:|---|---|
| 1 | 1302 | `_canonical_serve` | **one launch state** — certified `d63a6f7` |
| 2 | 1306 / 1311 | `serve_landing`, `serve_time` read **out of** the canonical serve | ✔ realized ball |
| 3 | 1313 | `serve_trajectory` built, `_stamp_launch_state` applied | ✔ |
| 4 | 1367 | `if serve_error: return _finish_serve_error(...)` | ✔ **OUT exits here** |
| 5 | 1387 | `CoverageModel.choose_claimant(players, serve-receive zones, landing, serve_time, origins)` | responsibility + reachability |
| 6 | 1472 | `arrival = _read_adjusted_arrival(claim.arrival, _read_error_meters(receiver, serve_trajectory, spin, start_time))` | ✔ one arrival, read off the real flight |
| 7 | 1528–1536 | `reception_quality` from skill − serve pressure − body penalty + arrival bonus + support − seam + noise | consumes arrival |
| 8 | 1543 | `reception_success = receiver_arrived and quality >= RECEPTION_PLAYABLE_FLOOR` | derived, not an independent roll |
| 9 | 1563 | `receiver_reach = _reached_point(receiver, start, landing, **serve_time**, "lateral", read_error)` | ✔ **the ball's clock is the window** |
| 10 | 1576 | `_reception_pass_result(...)` → one dict with `trajectory`, `set_contact_height_meters`, `reach_margin_meters`, incoming momentum | ✔ one pass |
| 11 | 1607 | `pass_trajectory = reception_pass.trajectory` | ✔ |
| 12 | 1824 / 1982 / 2195 | `second_contact_window = pass_trajectory.duration`; `event_time`, `deadline`, `incoming_trajectory` | ✔ consumed, not re-fabricated |

**Receiver selection is responsibility-first.** `choose_claimant` takes the
manager's `SERVE_RECEIVE` zones from `defensive_plan`, evaluates each voli's
arrival against the **authoritative ball time** (minus per-player time penalties,
from their **actual live positions**), discards everyone who cannot reach, and
only then scores. It is "who is responsible and can get there", not "who would
produce the best result". The brief's anticipated defect is not present.

---

## 2. The four gates

### Gate 1 — same receiver and start, faster vs slower serve

Driven directly through `_reached_point`. Required trip held at **6.6533 m**;
only the flight time moves.

| serve seconds | reached, m | shortfall, m |
|---:|---:|---:|
| 0.60 | 0.7277 | 5.9256 |
| 0.90 | 1.4554 | 5.1979 |
| 1.20 | 2.2871 | 4.3662 |
| 1.60 | 3.2227 | 3.4306 |
| 2.20 | 4.7821 | 1.8712 |

Monotone, and the implied speed rises 1.21 → 2.17 m/s across the range rather
than staying constant — the locomotion model's stride/cadence ramp, so a longer
flight buys more than proportionally more ground. **The ball's own clock is the
movement budget.** ✔

### Gate 2 — same serve, receiver nearer vs farther

Flight held at **1.20 s** in every row.

| required trip, m | reached, m | shortfall, m |
|---:|---:|---:|
| 0.4025 | 0.4025 | 0.0000 |
| 1.6100 | 1.6100 | 0.0000 |
| 3.2199 | 2.2640 | 0.9559 |
| 5.2324 | 2.2892 | 2.9432 |
| 7.6474 | 2.2703 | 5.3770 |

Reached saturates at ~2.27 m — everything this receiver can cover in 1.20 s —
and shortfall absorbs the rest. Required movement changes; what the ball does
not. The serve trajectory is an input here and cannot be written by the
receiver. ✔

### Gate 3 — an OUT serve never enters reception

1000 rallies, **194 serve errors, 0 receptions after a failed serve.** The
short-circuit at line 1367 sits before receiver selection at 1387. ✔

### Gate 4 — a playable reception produces one pass, and the next stage consumes it

806 receptions:

| | count | rate |
|---|---:|---:|
| set contact height taken **from the realized pass** | 806 | **1.0000** |
| set contact height absent → setter falls back | **0** | 0.0000 |
| reach margin absent | 0 | 0.0000 |
| outgoing trajectory absent | 0 | 0.0000 |

✔ — and §4 is where the one real finding lives.

---

## 3. The census

1000 isolated rallies, fresh `GameManager` per seed, both serving sides.

| | |
|---|---|
| serve events / errors / in | 1000 / 194 (0.1940) / 806 |
| receptions | 806 |
| playable | 798 (0.9901) |
| unplayable | 8 |
| mean reception quality | 0.4328 |
| **mean serve flight** | **1.3432 s** — the response window |
| mean start distance | 1.6931 m |
| **receptions the receiver did not fully reach** | **412 (0.5112), mean shortfall 0.4520 m** |

That last row is the strongest single piece of evidence that the ball is
authoritative: **on half of all receptions the receiver is measurably short of
the ball**, by 45 cm on average, because `_reached_point` clamps their travel to
what the serve's own duration allowed. Nothing teleports anyone to the contact.

Rally outcomes, recorded as regression observation and not as a target: home
points 513/1000, kill 302, opponent_kill 269, serve_error 194, attack_error 84,
opponent_attack_error 70, counter_block 37, blocked 36, ace 8.

---

## 4. The one defect found — latent, development-only

`_reception_pass_result` always returns `set_contact_height_meters`,
`reach_margin_meters`, `incoming_force` and `incoming_speed_mps`. The
**live-reception branch at 1588–1606 rebuilds `reception_pass` from scratch** and
carries only six keys:

```gdscript
reception_pass = {
    "trajectory": …, "destination": …, "body_alignment": 1.0,
    "platform_feasibility": …, "contact_posture": …,
    "contact_recovery": str(reception_pass.contact_recovery),   ## carried across
}
```

`set_contact_height_meters` is **not** among them, so the setter's read falls
through to:

```gdscript
SetterCapabilityModel.pass_contact_height_meters(
    float(result.reception_quality), rng.randf()
)
```

— which is the abstract, quality-derived, randomly-sailed model the comment four
lines above it says was retired, *and* it consumes an RNG draw that the normal
path does not. `reach_margin_meters` and the two incoming-momentum keys are
dropped the same way.

**It cannot fire in production.** The branch needs all three of
`development_continuous_reception` (a caller argument defaulting false),
`OS.is_debug_build()`, and `RallyFeatureFlagsModel.ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE`.
Measured: 0 of 806 receptions took it.

So this is a **landmine rather than a live defect** — the parallel abstract model
the brief forbids exists, is wired, and is currently unreachable. It will fire the
day the continuous-reception promotion is enabled, and it will do so silently,
because the fallback produces a plausible number.

**Not repaired here**, for a stated reason: the fix is to carry four more keys
across in the same manner `contact_recovery` already is, and with zero
occurrences it is a change no measurement in this repository can verify. It
belongs to whoever enables that path, with a gate asserting the promoted pass
publishes the same key set as the official one. That assertion is worth more than
the fix.

---

## 5. Verdict, and why nothing was changed

| gate | before | after |
|---|---|---|
| 1 — ball time is the movement window | pass | unchanged |
| 2 — required movement responds to distance, serve does not | pass | unchanged |
| 3 — OUT never enters reception | pass | unchanged |
| 4 — one realized pass, consumed downstream | pass | unchanged |

The leg was already built the way the target chain describes. Per
`RALLY_SIMULATOR_REDESIGN_LOG.md` §2.7 — *a local inconsistency is evidence, not
automatically an implementation task* — and the pass's own instruction to stop if
the gates were already satisfied, **no production change was made.**

Suite: **2,087 checks, no failures**, unchanged, as it must be when no production
file was touched.

---

## 6. Two asymmetries, documented rather than repaired

**The opponent's claim omits `origins`.** Home passes `reception_origins`;
`_opponent_reception` calls `choose_claimant` with five arguments, so every
opponent receiver is judged from their **zone centre** rather than their live
position. `choose_claimant`'s own doc says this is *"true in a serve-receive
formation and true nowhere else"* — which is exactly the phase in question, so
both are defensible. It is recorded because the two sides answer the same
question with different inputs, which is the shape that drifts.

**`receiver_move_time` is computed and published, not consumed.** Line 1546
computes it; it reaches event metadata as `movement_duration` and nothing else
reads it. The actual bound is `_reached_point`, which takes `serve_time`. Not a
defect — a diagnostic — but worth knowing before someone assumes the published
duration gates anything.

---

## 7. The exact remaining boundary into `choose 2nd contact`

Three things cross from the realized reception into the second contact:

| carried | from | status |
|---|---|---|
| `pass_trajectory` — geometry, duration, heights | the realized pass | ✔ authoritative |
| `set_contact_height_meters` | the realized pass | ✔ authoritative |
| **`result.reception_quality`** — a scalar | computed at 1528 | **the remaining abstract channel** |

`SetterCapabilityModel.evaluate(setter, tempo, **reception_quality**, contact_height,
approach)` judges what tempo the setter can command against *quality*, not
against the realized pass's geometry. So the pass's shape decides where the ball
is, and a separate scalar decides how hard it is to set.

That is the last place the receive leg hands the next stage an abstraction rather
than a ball — and it is precisely `PLATFORM_CONTACT.md` §7's `quality → ball`
inversion, sequenced there as **slice 5**, behind the shadow measurement, the
transfer relation T1 and the selection rule. It is named here so the boundary is
explicit; it is not this pass's to close.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_receive_chain_probe.gd
```

The controlled gates are exact and should reproduce byte-for-byte. The census is
one fixture; treat its rates as description, never as a target.
