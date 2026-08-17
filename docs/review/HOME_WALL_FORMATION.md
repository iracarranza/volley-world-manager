# The home wall's missing quarter: one write, applied twice

Run: 2026-08-17, from `cefcb04`. Instrument:
`tools/run_home_wall_diagnosis.gd`. **Diagnosis only — no behaviour changed.**

`docs/BACKLOG.md` recorded the figure and named the next step:

> why the wall was missed (opponent swings, 120)
>   (none)=39   around=30   **no wall=31**   over=14   contacted=6
>
> The home wall does not form at all on 31 of 120 opponent swings … The
> equivalent row for the opponent's wall carries no "no wall" at all. That is the
> defect, and it sits upstream of every band.
>
> `_form_home_block` is the producer. Ask what it returns on those 31 rows before
> changing anything in it.

Three flags (`ENABLE_UNIFIED_ATTACK_SHAPE`, `ENABLE_UNIFIED_RECEPTION_SKILL`,
`ENABLE_HOME_MIDDLE_OFFENSE`) and tasks #62–#64 are held behind it.

---

## 0. The first measurement was wrong, and how

The first draft of this probe ran the **raw vertical slice** and read the
**ATTACK** event. It found **zero** "no wall" rows and would have been reported
as "already fixed by later work."

`tools/run_block_band_probe.gd` — the instrument the original figure came from —
does neither of those things. It applies `ExecutionScale.apply_generated_attributes`
to both rosters, sets a block intent per rotation, and reads the **BLOCK** event.
Matched to that population, the figure reproduces exactly: **134 of 383**, which
is the same 134 the band probe reports.

Recorded because a null result from the wrong population reads exactly like a
fix, and this one was one keystroke from being published as one.

---

## 1. Which of the two causes — unambiguous

`"no wall"` is produced by `AttackResolutionModel` when the blockers array is
empty, and `GeometricAttackPromotion.block_wall` drops any blocker whose close
fraction is below `WALL_JOIN_CLOSE` (0.34). For the home side that leaves exactly
two possibilities, and they want opposite fixes:

| cause | count |
|---|---:|
| **nobody was assigned** — `front_blockers` empty | **0** |
| **nobody arrived** — a primary existed and closed under 0.34 | **134** |
| neither | 0 |

Three front-row blockers were offered on all 383 swings. The `block_participation`
filter — which the home former has and the opponent former does not — is **not**
the cause. Every failure is a body that was there and could not get across.

---

## 2. What separates the two populations

| | wall formed (n=249) | no wall (n=134) |
|---|---:|---:|
| `primary_close` p50 | 1.000 | **0.000** |
| set flight s p50 | 0.284 | **0.128** |
| preset window s p50 | 1.684 | 1.689 |
| displaced from slot, m p50 | 1.105 | **1.299** |
| footwork m p50 | 0.544 | **1.007** |
| usable s p50 | 0.745 | **0.425** |
| deficit s p50 | — | 0.483 |

**The preset window is identical.** The discriminator is set flight time, and it
nearly separates the two populations outright: the no-wall p75 is 0.157 s against
a formed p25 of 0.185 s. These are **first-tempo balls**.

So the shape of it: the home blocker is standing about 1.3 m from their rotation
slot, has about 1.0 m of net left to cover, gets 0.43 s to do it, and is 0.48 s
short. On a slower set the same displacement is survivable. On a quick set it is
not.

---

## 3. The cause, proven by suppression

Both formers compute the same setter pull:

```gdscript
var pull_weight := (1.0 - discipline) * 0.18
var pulled_x := lerpf(start.x, opponent_setter_x, pull_weight)
setter_pull[player.id] = absf(pulled_x - start.x)
```

`_form_home_block` then adds one line the opponent's former does not have:

```gdscript
live_positions[player.id] = Vector2(pulled_x, start.y)
```

The home wall's drift is **written onto the body**; the opponent's is computed
and discarded. And `_form_home_block` is called **twice per rally** — once
pre-release (`:4599`) and once re-formed after staging (`:4817`) — so the second
call reads the already-pulled position as `start` and pulls again from it.

Measured by suppressing terms one at a time, everything else held:

| variant | "no wall" |
|---|---:|
| as shipped — pull written, applied twice | **134** |
| pull anchored to the rotation slot (idempotent) | **42** |
| pull not written to the body at all | **0** |

So **92 of the 134 rows (69%) are the double application**, and the remaining 42
are one honest application of the pull plus whatever else has displaced the body
(pre-release phase targets, and the wall-staging write from an earlier phase).

The rows do not vanish from the census when the wall forms — they become `over`
and `around`. A wall that exists can still be beaten, and that is the correct
downstream behaviour rather than a saved ball.

---

## 4. What was changed here: nothing but publication

Two additions, both forwarding values that were already computed:

- `home_block_terms` on the opponent's ATTACK event — front-blocker count,
  primary close, the primary's itemised close terms, read quality, preset window
  and set flight. The code comment beside `wall_size` had already recorded the
  gap: *"`wall_size` … is the only figure that says whether 'no wall' means
  nobody was assigned or nobody arrived — and those want opposite fixes."*
- `start_x` and `slot_x` on `_blocker_close_terms`, so a close deficit can be
  attributed to displacement rather than only to time.

Suite: **2,126 checks, no failures** — unchanged, which is what a
publication-only change must do.

---

## 5. The repair is two decisions, not one

**The compounding is a bug under any design.** Nobody intends a drift applied
twice because a function is called twice; the second call is a *re-formation of
the same wall* with better information, not a second drift event. Fixing it needs
one choice: whether the de-compounded pull anchors on the rotation slot (simple,
idempotent, but discards legitimate live displacement such as a blocker who has
just landed from their own swing) or is applied once by the first call only
(preserves live displacement, needs the pull moved out of the former).

**Whether the pull should reach the body at all is a symmetry question**, and it
is one of the ones task #63 already owns. Today one wall pays for its own misread
and the other does not, on identical arithmetic. Making the opponent pay it
weakens their wall; making neither pay it deletes a modelled consequence of
`tactical_discipline` and `anticipation` for blockers. Both are balance
decisions, and defensive calibration is deferred behind the locomotion rework.

Neither is taken here. The diagnosis is what was asked for and the numbers above
are what a decision should be made against.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_home_wall_diagnosis.gd
```

Matches `tools/run_block_band_probe.gd`'s population exactly, by construction —
same roster seeds, same rally range, same event stream. If the two ever disagree
about the "no wall" count, one of them has drifted.
