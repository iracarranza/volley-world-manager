# Ready orientation: preparation is real, and stops at the turn

Run: 2026-08-16, from `e0b4516`. Instrument:
`tools/run_ready_orientation_probe.gd`. **Three production repairs, then a
narrower BLOCKED than the one this replaces.**

`facing` is physical feet/body preparation orientation — not gaze, not a
predicted landing point, not the route being evaluated. `DEFENSIVE_READINESS_BOUNDARY.md`
found it carried no information. It now does, and the defensive claimant reads
it. What remains missing is one transition.

---

## 1. The lifecycle, before and after

| stage | before | after |
|---|---|---|
| initialisation | class default `Vector2(0, −1)` for **both** sides — an opponent defender faced away from the net | `create()` mirrors on `side`: home `(0, −1)`, opponent `(0, +1)`, both toward the net |
| at rest | preserved (`apply_position` only rewrites on non-zero velocity) | unchanged — already correct |
| route evaluation | **`_travel` overwrote facing with the route**, so `facing_fit` was 1.0 for every voli on every leg | `_travel` takes an `entry_facing`; zero means *unknown* and keeps the old behaviour |
| defensive claim | `evaluate_arrival` had no facing and no directional startup | takes a facing, spends it through `LocomotionModel.direction_change_seconds` |
| **after movement** | velocity-derived, wired at six hitter sites only | **unchanged — this is the boundary, §4** |

Three changes, none of them a new constant:

1. `RallyPlayerState.side_relative_ready_facing(side)` — mirrors the existing
   convention (`square_up_sign`, `attacking_negative_y`). Toward the **net**, not
   toward the ball: preparation must not gain information from the action it is
   about to be tested against.
2. `_travel` no longer faces its own route. `Vector2.ZERO` means *unknown*, and
   `_movement_profile` already leaves `facing_fit` at 1.0 for an unreadable
   facing — so every un-migrated caller lands bit-for-bit unchanged.
3. `evaluate_arrival` charges the turn out of **the ball's clock**, never off
   `movement_speed`. The relation is `direction_change_seconds`, the same one
   `_movement_profile` uses for every other body, with `RallyMovementSystem`'s
   own bounds.

---

## 2. Gates

| gate | result |
|---|---|
| **A1** mirrored initialisation | **PASS** — home `(0.00, −1.00)`, opponent `(0.00, +1.00)` |
| **A2** rest preserves | **PASS** — unchanged at rest, changes on a committed move |
| **A3** monotone in startup, flat in top speed | **PASS** |
| **A4** route cannot prepare itself | **PASS** |
| **A5** the future ball does not choose preparation | **PASS** — one facing across four landing points |
| **A6** velocity and facing independent | **PASS** — each moves the trip alone |
| **A7** claimant differs by direction | **PASS** |
| **A8** B–H still green | **PASS** |

**A3** — same body, same trip, same clock, only the orientation moves:

| facing | `facing_fit` | turn delay | travel | max speed |
|---|---:|---:|---:|---:|
| toward | 1.0000 | 0.0200 s | 1.3739 s | 2.5649 |
| 45° off | 0.8536 | 0.0462 s | 1.4001 s | 2.5649 |
| across | 0.5000 | 0.1097 s | 1.4636 s | 2.5649 |
| 135° off | 0.1464 | 0.1732 s | 1.5271 s | 2.5649 |
| away | 0.0000 | 0.1995 s | 1.5534 s | 2.5649 |

Monotone in startup; **one distinct top speed**. Preparation buys a cheaper
first step and nothing else.

**A7** — the measurement this whole sequence was for. Same defender, same
2.5 m, same 1.60 s, set toward the net:

| ball from | `facing_fit` | turn delay | reach margin |
|---|---:|---:|---:|
| the net (front) | 1.0000 | 0.0200 s | **1.2665 m** |
| left / right | 0.5000 | 0.1097 s | **1.0004 m** |
| behind | 0.0000 | 0.1995 s | **0.7344 m** |

Three distinct answers where there was one. Before this pass all four rows read
1.0840 m.

---

## 3. BLOCKED — the post-movement turn

§6's exact transition, and it is now the only thing missing.

A defender who has **not** moved has a real orientation: the side-relative one
they were set in. A defender who **has** moved has none the simulation can
justify. The one existing rule — `apply_position`'s `facing = velocity.normalized()`
— is wired at six sites, **all hitters**, and generalising it would make a
backpedalling defender face away from the net, which contradicts the policy's own
"a voli may move laterally/backward relative to their existing preparation."

Deciding *when a moving body turns versus travels while holding its orientation*
requires a turn/open-up relation that does not exist in the simulation. It exists
in **presentation** — `ff25eb8` and `ready_stance.gd`, which is consumed only by
`player_actor_3d`, `match_court_3d` and `match_screen` and never by the resolver
— and §7 forbids importing its thresholds without independent physical authority.
So no turn speed, angular cone, distance threshold or reaction constant was
invented.

**What the claimant reads today** is `_ready_facings(...)`: the side-relative
standing orientation for every candidate. Honest for a defender who has not
moved, and stale for one who has. That staleness is the boundary, stated rather
than hidden.

---

## 4. Readiness disposition

Per §10, audited only now that facing reaches the claimant.

**Not closed by facing, and not invented.** `readiness` defaults to `1.0`, is
never written outside `snapshot()`, and `ContactEnvelopeSystem` spends it on the
contact envelope and the take-off multiplier. That is a different physical fact
from orientation — how ready the body is to extend and leave the floor, versus
which way the feet are set. Facing does not supply it, so the two are not being
spent twice on one preparation fact.

It is therefore a **distinct load-bearing state with missing semantics**, and the
policy says demonstrate and stop rather than invent coefficients. Recorded as the
boundary after the turn.

---

## 5. Tests

`_test_ready_orientation`, five checks. **Two fail on the pre-pass behaviour**,
verified by surgically reverting the two behavioural changes while keeping the
signatures so the suite still compiles:

- ✗→✓ *a route cannot make itself perfectly prepared by facing its own direction* (A4)
- ✗→✓ *a ball behind a set defender costs more than the same ball in front* (A7)

The other three are invariant or structural and labelled as such. A1's mirror
would also fail on the pre-pass `create()`, but it cannot be demonstrated in the
same run because the check calls a static that did not exist — stated rather than
claimed as a failing gate.

Suite: **2,117 checks, no failures.** 2,111 + 5 written + 1: a sampling gate drew
one more, because defenders now pay a turn and rallies resolve differently.
Population movement is an observation and was not tuned.

---

## 6. Next boundary

**When does a moving body turn, versus travel while holding its orientation?**

Then, behind it: **what does `readiness` mean?**
