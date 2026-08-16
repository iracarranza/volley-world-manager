# Set quality and generation: the order was already right

Run: 2026-08-16, from `1a12946`. Instrument:
`tools/run_set_generation_probe.gd`. **One production change, and it publishes a
number rather than changing one.** All six controlled gates pass.

The section audited, the last two nodes of it new:

```text
generated pass
→ choose 2nd contact        certified 41a57b6
→ choose hitter             certified 1a12946
→ setter movement           certified 1a12946
→ set quality                          ← this pass
→ ONE generated set                    ← this pass
```

The finding is a negative one and worth stating plainly: **the causal order the
brief asks for is already what the code does**, and the one thing genuinely
missing was that a threshold the design calls unmeasured had no published
quantity behind it. That is now measured, and it turns out to be well placed.

---

## 1. The before-flow, exactly

Home first ball, `rally_simulator.gd`. Line order *is* the argument here, because
what separates a legitimate architecture from a broken one at this node is
entirely which value is computed before which.

| line | what happens | class |
|---:|---|---|
| 1905 | `_choose_assignment(…, setter.id, setter, reception_quality, flow)` | **decision** — the hitter |
| 1996 | `setter_approach_quality = inverse_lerp(−0.25, 0.45, setter_arrival_margin)` | realized arrival |
| 1999 | `SetterCapabilityModel.evaluate(setter, tempo, quality, realized contact height, approach)` | **feasibility** |
| 2015 | `if tempo_downgraded: assignment = _downgraded_assignment(assignment, resolved_tempo)` | **feasibility constrains the form** |
| 2027 | `intended_set_target = HitterPlacementModel.preferred_point(hitter, lane, …)` | the aim |
| 2036 | `set_geometry(setter, setter_start, set_contact, intended_target, release)` | difficulty |
| 2065 | `result.set_quality = set_terms.quality + _execution_error(setter, …)` | **execution** |
| 2073 | `set_target = _delivered_point(intended, set_quality, …, distance, apex)` | execution moves **the ball** |
| 2099 | `jump_set = _jump_set_decision(setter, pass_apex, arrival_margin, run_m, run_s)` | posture |
| 2110 | `set_arc(…, min(release_height, pass_apex), …)` | clamped by the realized pass |
| 2150 | `set_trajectory = _ball_trajectory("set", set_contact, set_target, …)` | **ONE ball** |

Everything the brief forbids set quality from doing is prevented by that
ordering rather than by a rule:

| set quality must not… | why it cannot |
|---|---|
| move the setter | `setter_start` / `setter_move_time` are fixed at 1857–1858, ~200 lines earlier |
| extend pass arrival time | `second_contact_window` is the pass's own duration, fixed before the setter is even chosen |
| grant additional reach | release height comes from `jump_set` (2099) and is clamped by `pass_apex`; quality is not an input |
| retroactively change the pass | nothing writes back to `pass_trajectory` |
| replace the chosen hitter | the hitter is chosen at 1905, 160 lines before quality exists |

`_downgraded_assignment` is the one place feasibility touches the tactical call,
and it copies the assignment and edits **only `tempo`** — `player_id` and `lane`
survive. In situ **15.08% of sets are tempo-downgraded**: feasibility constrains
what is attempted at a meaningful rate, and never who it is attempted to.

---

## 2. The six gates

### 1 — same pass, setter nearer vs farther

Pass held at (0.56, 0.68), flight 1.20 s, apex 2.95 m.

| start distance | travel | margin | closing | posture | reason |
|---:|---:|---:|---:|---|---|
| 0.000 m | 0.000 s | +1.200 | 0.00 | jump | jump set |
| 0.752 m | 0.598 s | +0.602 | 1.26 | jump | jump set |
| 1.879 m | 0.934 s | +0.266 | 2.01 | standing | no time to load |
| 3.759 m | 1.358 s | −0.158 | 2.77 | standing | no time to load |
| 6.390 m | 1.948 s | −0.748 | 3.28 | standing | no time to load |
| 9.396 m | 2.622 s | −1.422 | 3.58 | standing | no time to load |

Monotone in travel and margin; the contact circumstances degrade with the run.
Set quality cannot make the setter arrive — by §1's ordering, not by assertion. ✔

### 2 — same setter, faster vs slower pass

Start held 2.14 m away; only the ball's flight moves.

| flight | travel | margin | posture / reason |
|---:|---:|---:|---|
| 0.35 s | **0.934 s** | −0.584 | standing, no time to load |
| 0.80 s | **0.934 s** | −0.134 | standing, no time to load |
| 1.10 s | **0.934 s** | +0.166 | standing, no time to load |
| 1.60 s | **0.934 s** | +0.666 | standing, **arriving too fast to plant** |
| 2.20 s | **0.934 s** | +1.266 | standing, arriving too fast to plant |

Travel is constant to four decimals — the body did not change. The margin moves
only because the ball did. **No independent timer.** ✔

The last two rows are the design working: a generous margin is *not* sufficient
for a jump set, because the setter is still carrying 2.01 m/s into the plant.

### 3 — intended hitter preservation

Covered by `1a12946`'s gates A–D and by §1 here. The tactical call survives a
challenger two full rating grades better; the exclusion of the second contact
holds at rating 99 with a control proving the fixture would otherwise pick them;
and feasibility's only reach into the decision is the tempo downgrade, which
preserves `player_id` and `lane` by construction. ✔

### 4 — jump-set stability

**Identical arrival margins in every row. Only the run differs.**

| case | run | over | margin | posture | reason |
|---|---:|---:|---:|---|---|
| stood and waited | 0.15 m | 0.30 s | 0.90 | **jump** | jump set |
| short shuffle | 0.55 m | 0.50 s | 0.90 | **jump** | jump set |
| brisk two steps | 1.40 m | 0.85 s | 0.90 | **jump** | jump set |
| covered ground | 4.20 m | 1.50 s | 0.90 | **standing** | arriving too fast to plant |
| sprinted in | 7.00 m | 1.90 s | 0.90 | standing | arriving too fast to plant |
| sprinted, no time | 7.00 m | 1.90 s | 0.10 | standing | no time to load |

A model reading time alone cannot separate rows 3 and 4. This one does, and the
last two rows show the two refusals are distinguishable from each other. ✔

The other failure mode stays separate too — a ball that never rose to the hands:

| pass apex | posture | reason |
|---:|---|---|
| 1.600 m | standing | under the hands |
| 2.175 m | standing | under the hands |
| **2.275 m** | **jump** | jump set |
| 3.200 m | jump | jump set |

The crossing is the setter's standing release height, **2.225 m**, exactly. ✔

### 5 — set height and distance are not free

Two existing channels, no new one introduced.

**Geometric difficulty**, which enters set quality:

| distance | difficulty | difficulty (steady setter) | delta |
|---:|---:|---:|---:|
| 2.197 m | 0.00348 | 0.00267 | 0.00081 |
| 2.952 m | 0.00961 | 0.00796 | 0.00165 |
| 3.865 m | 0.01946 | 0.01603 | 0.00343 |
| 4.847 m | 0.03028 | 0.02486 | 0.00542 |

Rises with distance, and a setter with better balance and stability pays less —
existing physical capability participating, exactly as asked. (The 1.836 m row is
omitted from the trend: it is below `distance_difficulty`'s 2.0 m floor, so its
0.00867 is entirely the orientation and release terms. Difficulty is not a pure
function of distance and the table should not be read as one.)

**Delivery scatter**, which is where the ball actually lands — mean displacement
from the aim over 400 seeds:

| distance | apex | spread at quality 0.35 | at 0.85 |
|---:|---:|---:|---:|
| 1.50 m | 1.20 m | 0.337 m | 0.137 m |
| 4.00 m | 1.20 m | 0.613 m | 0.249 m |
| 7.50 m | 1.20 m | 0.998 m | 0.406 m |
| 4.00 m | 2.60 m | 0.797 m | 0.324 m |
| 4.00 m | 4.00 m | 0.981 m | 0.399 m |

Grows with distance **and** with apex, and shrinks with execution. A higher
rescue ball is bought, not given. ✔ **No `set power` system was added and none is
needed** — the architecture already prices both axes twice over.

### 6 — one ball, end to end

600 isolated rallies:

| | |
|---|---:|
| the set was resolved against the exact ball the previous contact published | **586 / 586** |
| the swing was resolved against the exact set the setter published | **232 / 232** |

Identity by start point, end point and duration. The ATTACK event's
`incoming_trajectory` is literally the same `set_trajectory` variable the SET
event published as `outgoing_trajectory`, so the second row is identity by
construction and the measurement confirms nothing was substituted in between. ✔

> **The first draft of this gate reported 468/586, and the probe was wrong.** It
> tracked "the last RECEPTION's pass", so every transition set — fed by a dig —
> was compared against a serve reception from earlier in the same rally. Walking
> *the last ball any contact published* is the correct comparison and gives
> 586/586. Recorded because a 20% failure rate in an instrument reads exactly
> like a 20% failure rate in the engine.

---

## 3. The one production change: a threshold with nothing behind it

`JUMP_SET_STABLE_APPROACH_MPS = 1.9` guards the "arriving too fast to plant"
branch, and its own comment says:

> *Unmeasured, and named as such: nothing has published a setter's closing speed
> at the moment of contact, so this is a starting value and the probe comes
> before the tuning.*

That is `FAILURE_MODES.md` §0 stated in advance by the author — and the quantity
the branch turns on was computed inside `_jump_set_decision` and thrown away, so
the threshold could not be audited from the rally record at all.

`_jump_set_decision` now returns `closing_speed_mps` on every path, and all three
call sites stamp it as `set_closing_speed_mps`. **No behaviour changed** — the
value was already being computed and compared.

The distribution, 610 sets:

| | |
|---|---:|
| n | 610 |
| min | 0.0257 m/s |
| p05 | 0.1924 |
| **median** | **1.9971** |
| p95 | 3.5674 |
| max | 4.0072 |

**The threshold sits at the 47th percentile — almost exactly the median.** It is
inside its own distribution, spans it in both directions, and does real work:

| posture | | rate |
|---|---:|---:|
| jump | 275 | 0.4508 |
| standing | 335 | 0.5492 |
| — *arriving too fast to plant* | 231 | **0.3787** |
| — *no time to load* | 97 | 0.1590 |
| — *under the hands* | 7 | 0.0115 |

Nearly two fifths of all sets are refused a jump specifically because the setter
was still travelling. The starting value the author flagged as a guess turns out
to be well placed, and it is now falsifiable rather than merely plausible. **No
tuning was done** — the point of measuring was to find out, and the answer was
"leave it alone."

---

## 4. Tests

`_test_set_feasibility_then_execution`, six checks:

1. a setter still travelling cannot jump-set on a margin that lets a planted one;
2. a pass under the hands and a rushed setter are refused for *different* reasons;
3. a tempo the setter cannot command changes the set form, never the hitter;
4. every set publishes the closing speed its jump decision turned on;
5. a set is resolved against the exact ball the previous contact published;
6. a swing is resolved against the exact set the setter published.

**Only check 4 fails on the pre-change resolver**, and that is the honest report:
this pass changed one thing and one check guards it. The other five lock
pre-existing invariants that had no gate at all — the jump-set distinction, the
downgrade's provenance, and the two one-ball identities were all correct and all
unprotected. A regression in any of them would previously have been silent.

Suite: **2,104 checks, no failures** — 2,098 plus exactly the six written, which
is what a publication-only change should do to a sampling population: nothing.

### Rally outcomes, regression observation only

| | |
|---|---:|
| home points | 298 / 600 (0.4967) |
| kill / opponent_kill | 147 / 165 |
| attack_error / opponent_attack_error | 43 / 45 |
| blocked / counter_block | 28 / 40 |
| ace / serve_error | 8 / 124 |

Unchanged by this pass by construction — nothing here alters a decision.

---

## 5. The exact remaining boundary into `hitter approach`

The set node hands the approach node these, all published on the SET event:

| carried | status |
|---|---|
| `outgoing_trajectory` — the one realized set | ✔ authoritative, consumed by identity |
| `intended_target` vs `end_position` | ✔ aim and result kept separate |
| `set_posture`, `set_release_height_meters`, `set_closing_speed_mps` | ✔ published |
| `tempo_coordination`, `requested_tempo` | ✔ |

Three things the next pass should carry rather than rediscover:

1. **The hitter's approach is timed against the *intended* target, not the
   delivered one.** `hitter_move_time = _movement_time(hitter, hitter_start,
   intended_hitter_body, "transition")` and `hitter_arrival_margin =
   set_flight_time − hitter_move_time`. That is defensible — a hitter reads the
   set's intent and adjusts late — but it means the approach budget is computed
   against a point the ball is not going to, and `_delivered_point`'s scatter
   reaches 1.00 m at long range. Whether the adjustment is modelled or merely
   assumed is the first question `hitter approach` has to answer.
2. **Set quality's reach into attack quality is untested here.** The brief
   forbids set quality from *directly determining* attack quality; this pass
   stopped at the generated set and did not open the swing.
3. **`reception_quality` still crosses into `SetterCapabilityModel.evaluate`**
   alongside the realized contact height and approach quality. Deliberately not
   removed — `PLATFORM_CONTACT.md` sequences that inversion later. What this
   pass can add is that it is no longer the *only* thing the model sees: arrival
   margin (as approach quality) and the realized contact height both reach it,
   so the abstraction is now one input among three rather than the whole story.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_set_generation_probe.gd
```

Gates 1, 2, 4 and 5 are exact and reproduce byte-for-byte. Gate 5's scatter table
averages 400 seeded draws per row. The census is one fixture; its rates are
description, never targets.
