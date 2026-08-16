# Forward walk: hitter approach ✔, and the ball every swing was struck against

Run: 2026-08-16, from `71cbbe1`. Instrument:
`tools/run_attack_chain_probe.gd`. **One production change, and it publishes a
ball rather than changing one.**

The node the previous pass named as the first open boundary:

```text
ONE generated set
→ hitter approach          ← this pass
→ choose attack
→ …
```

---

## 1. Hitter approach — PASS

The concern `71cbbe1` raised: the attacking assignment is chosen before the set
exists, the delivered point scatters up to ~1 m from the intended target, and
the approach appeared to be timed against the *intended* point. If an approach
to the intended point were simply assumed to reach the delivered ball, that
would be an authority break.

It is not. The four stages exist and are separate, and the code says so at each
handoff.

### A — pre-set commitment

`assignment_data.target = intended_hitter_body`, with the comment:

> *Before release this hitter knows the spot they requested, not the setter's
> eventual delivery error.*

Legitimate: the intended target is all that exists when the run-up starts.

### B — observation, once the ball is real

`SetPathReadModel.evaluate(hitter, intended, delivered, flight, quality, pair, …)`
returns a **perceived** contact, `intended.lerp(delivered, tracking)` plus a
hash-driven error band. Same hitter, same intended target, same flight; only the
scatter moves:

| scatter | toward the ball | residual to the ball |
|---:|---:|---:|
| 0.00 m | 0.164 m | 0.164 m |
| 0.35 m | 0.203 m | 0.254 m |
| 0.60 m | 0.330 m | 0.337 m |
| 1.00 m | 0.563 m | 0.478 m |
| 1.60 m | 0.928 m | 0.699 m |

The perceived point sits **between** the two and never reaches either. A hitter
with foreknowledge would show residual 0 in every row; one ignoring the delivery
would show 0 in the first column. Neither happens.

And tracking is bought, not given:

| flight | tracking (ability 50) | (90) | (15) |
|---:|---:|---:|---:|
| 0.20 s | 0.380 | 0.612 | 0.177 |
| 0.55 s | 0.469 | 0.701 | 0.266 |
| 1.05 s | 0.620 | 0.852 | 0.417 |

A ball in the air longer is read better, and a better reader reads it better.
**No radius, no reaction constant, no teleport** — the read is a function of
court vision, anticipation, approach timing, composure, the flight time and pair
familiarity.

### C — late adjustment, clamped by the remaining flight

`_reachable_contact` pulls the contact back toward the body when the trip cannot
be made. Required trip 1.800 m in 0.914 s:

| budget | reached | short by |
|---:|---:|---:|
| 0.10 s | 0.197 m | 1.603 m |
| 0.40 s | 0.787 m | 1.013 m |
| 0.70 s | 1.378 m | 0.422 m |
| 1.20 s | 1.800 m | 0.000 m |

The ball is never moved to the hitter. `_retarget_set_event`'s own comment states
the principle:

> *The set is a ball, not a favour the reachability clamp does for a late hitter.
> It remains where the setter delivered it. The body stops where its own budget
> and path read put it, and the gap is paid at contact.*

### D — the gap is paid at contact

`assess_contact(hitter, body_position, ideal_body_position)`:

| body error | outcome | quality × |
|---:|---|---:|
| 0.10 m | clean | 1.000 |
| 0.35 m | strained | 0.828 |
| 0.55 m | mishit | 0.441 |
| 0.80 m | **whiff** | 0.000 |

A hitter who cannot reach the delivered ball mishits or misses it. In situ over
611 swings: mean set scatter **0.304 m**, mean body-to-ball error at contact
**0.185 m**, 12.0% late hitters, 157 strained, 17 mishits, 4 whiffs.

**Verdict: PASS.** No repair needed and none made. The architecture already
distinguishes what the hitter committed to, what they can see, what they can
still do about it, and what it costs them.

---

## 2. The defect: two of three swings did not publish the ball they struck

Three paths produce an ATTACK event — the home first ball, the opponent
transition, and the home continuation. **Only the first carried
`incoming_trajectory`.**

| | before | after |
|---|---:|---:|
| set → attack, identity by start/end/duration | **240 / 611** | **611 / 611** |
| attacked-or-blocked ball → defensive contact | 285 / 285 | 285 / 285 |

This is a **reporting** gap, not an authority one, and the distinction is load
bearing: all three paths were already *resolved* against their own set's flight
(`set_flight_time`, that set's arc, and `_retarget_set_event` on the same event).
The swing was correct; it just could not be proven from the rally record on two
paths out of three.

The correction reads the ball straight off the SET event each path already
published, so the identity holds by construction:

```gdscript
var opponent_attack_event := result.events[-1] as RallyEvent
if opponent_attack_event != null and opponent_set_event != null:
    opponent_attack_event.metadata["incoming_trajectory"] = Dictionary(
        opponent_set_event.metadata.get("outgoing_trajectory", {})
    )
```

**The outcome mix is byte-identical across the change** — home points 300/600,
and every terminal category unchanged (kill 152, opponent_kill 161,
attack_error 66, counter_block 48, blocked 19, ace 5, serve_error 108). That is
what a publication-only change must look like.

---

## 3. What the walk found downstream, and why it did not stop

The remaining nodes were inspected far enough to establish ownership. None
produced a defect that this pass could repair without inventing policy, and none
produced a STOP.

**Choose attack.** The opponent path already carries the correct ordering, and
its own comment is explicit that shot choice is re-read against the *delivered*
set while the hitter is not: *"Who swings stays chosen on the estimate; only what
they do with it is re-read."* Tactics choose the swinger; the realized ball
constrains what they do with it.

**Physical attack / one ball.** Every ATTACK event publishes an
`outgoing_trajectory`, and the defensive contact that follows is resolved against
it: **285 / 285**.

**Form block / block result.** The defence's clock is
`home_block_trajectory.duration` when the block touched the ball and the swing's
own duration otherwise — the *realized post-block ball*, not the pre-block one.
Block outcomes over 504 blocks arise as six distinct interaction categories
(funnel 0.238, miss 0.234, tool 0.181, touch 0.165, stuff 0.133, recycle 0.050)
rather than a single roll.

**Coverage / choose defender.** Uses **the same `CoverageModel.choose_claimant`**
as the certified serve reception — the manager's `FLOOR_DEFENSE` zones, arrival
evaluated against the ball's own time from live positions, and
`_recovery_time_penalties(rally_clock)` so a voli still getting up has that much
less time to reach the next ball. Responsibility-first with reachability able to
override, and *not* nearest-wins. The behavioural concerns the goal lists —
distant claimants, tips, adjacent bodies — are calibration questions inside a
selector whose *authority* structure is the one already certified at the second
contact, so they are not this walk's to answer.

**Loop re-entry.** Already proven in `SECOND_CONTACT_AUDIT.md` §1: three call
sites, one implementation. `_resolve_opponent_transition` and
`_resolve_home_continuation` both call `_second_contact_setter` and
`_spatial_setter_choice` — the same selector the serve-receive path uses. **There
is no parallel transition-rally architecture**, which is the requirement.

---

## 4. Ledger

| node | verdict |
|---|---|
| hitter approach | **PASS** |
| choose attack | **PASS** — ordering correct, tactics upstream of feasibility |
| attack quality / physical attack | **PASS** — one published ball per swing |
| form block | **PASS** — timed against the realized ball |
| block result | **PASS** — six interaction categories, defence reads the post-block ball |
| coverage / choose defender | **PASS (structure)** — the certified claimant, responsibility + reachability |
| dig outcome | **PASS** — 285/285 resolved against the incoming ball |
| generate dig / loop re-entry | **PASS** — same second-contact selector, no parallel path |

Deferred, and named rather than fixed:

1. **Defensive calibration** — distant claimants, short-ball ownership, adjacent
   bodies. The selector's authority structure is certified; its *weights* have
   never been swept the way the second contact's were. That is the natural next
   pass and it needs a policy statement about short-ball responsibility before
   any number moves.
2. **`counter_block` 0.080** on this fixture, against `blocked` 0.032. Recorded
   as observation; tasks #62–#64 already own the block outcome bands.
3. **12.0% of hitters arrive late** with a mean approach margin of +0.056 s. Thin,
   and worth knowing before anyone reads an attack rate.

---

## 5. Tests

`_test_every_swing_publishes_the_ball_it_struck`, two checks:

1. every swing on every path publishes the ball it was struck against;
2. that ball is the exact set the setter published, on every path.

**Check 1 fails on the pre-change resolver** — verified by reverting and
re-running. Check 2 passes on both and is an invariant test, labelled as such: it
guards against a future path substituting a different ball, which no path does
today.

Suite: **2,106 checks, no failures** — 2,104 plus exactly the two written, which
is what a publication-only change should do to a sampling population.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_attack_chain_probe.gd
```

The approach tables are exact and reproduce byte-for-byte. The census is one
fixture; its rates are description, never targets.
