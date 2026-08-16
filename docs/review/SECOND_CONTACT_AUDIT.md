# Choosing the second contact: the ball is heard, the legs are capped

Run: 2026-08-16, on `71e6104`. Instrument:
`tools/run_second_contact_probe.gd`. **No production behaviour changed** — three
comments were corrected, one of which was stating a number the code does not
have. §5 is the verdict and §6 is the policy boundary this pass stopped at.

> **Every table below is the pre-change state and will no longer reproduce.**
> The boundary in §6 was decided and option 1 shipped in
> `SECOND_CONTACT_TRANSFER.md`, so re-running the probe today prints the
> corrected numbers, not these. This document is kept as the diagnosis — what
> the defect was and how it was found — and that write-up carries the before /
> after comparison. Do not read a table here as current behaviour.

The leg audited, immediately after the realized pass:

```text
realized pass → CHOOSE 2ND CONTACT → choose hitter
```

The short version: **the realized pass is genuinely consumed** — destination,
duration, live positions, recovery debt and a head start all reach the selector,
and none of it is re-fabricated. **`reception_quality` does not reach it at all**,
which is correct. What is wrong is a magnitude: the responsibility weighting is
sized so that in one rotation of six it cannot be outvoted by the legs, and in
the other five it can. Nothing asked for that difference.

---

## 1. The before-flow, exactly

Home side, first ball. `rally_simulator.gd`.

| # | line | what happens | authority |
|---|---:|---|---|
| 1 | 1607 | `pass_trajectory = reception_pass.trajectory` | ✔ the realized pass |
| 2 | 1818 | `_home_second_contact_candidates(players, lineup)` → six on-court volis **and their live positions** | ✔ real bodies |
| 3 | 1819 | `_second_contact_setter(candidates, plan, active_setter_id, receiver.id)` | responsibility **only** |
| 4 | 1823 | `set_contact = reception_pass.destination` | ✔ realized |
| 5 | 1824 | `second_contact_window = pass_trajectory.duration` | ✔ realized |
| 6 | 1825 | `_spatial_setter_choice(…, preferred_setter, set_contact, window, serve_duration, Vector2.ZERO)` | duty **+** legs |
| 7 | 1856 | `setter = setter_choice.player` | **the real decision** |
| 8 | 1893 | `emergency_setter := setter.id != lineup.active_setter_id()` | published |

Three call sites, one implementation: 1819/1825 (home first ball), 4019/4025
(opponent), 5828/5844 (home transition). §7 covers the two ways the opponent's
differs.

### 1a. Who is considered

All six on court, minus the first-contact player, who is excluded by id in both
functions. There is no role filter, no front/back-row filter and no rating cut:
a middle blocker is as admissible as the setter. That is right — anybody may
take a second ball — and it means responsibility, not eligibility, is doing all
the work of keeping the setter in charge.

### 1b. What establishes first responsibility

`DefensivePlan._default_assignment` writes `second_contact_responsibility` **per
slot**, unprompted, on every plan:

| slot | duty |
|---|---|
| 2 (front) | `Primary emergency setter` |
| 1 (back) | `Secondary emergency setter` |
| 3, 4, 5, 6 | `No second-contact duty` |

A fourth value, `Stay available to attack`, is offered by the clipboard
(`main.gd:353`) and produced by no default.

### 1c. How the designated setter is represented

Twice, in two different ways, and this is the crux.

- `_second_contact_setter` returns them **outright** — an early `return` before
  any scoring — unless they played the first contact.
- `_spatial_setter_choice` gives them **`duty_bonus += 0.46`**, *added to*
  whatever the plan already gave that voli.

The second is not a decision, it is a weight, and it is the one that ships.

---

## 2. `_second_contact_setter` does not choose the setter

It looks like the selector and it is not one. Every caller passes its answer
into `_spatial_setter_choice` as `preferred_setter`, where a non-designated
preferred voli is worth **+0.20** — one term among six. Its real contributions
are that +0.20 and a null-fallback on the opponent path.

That is the correct shape. It takes no position, no clock and no ball, so it
*could not* honestly decide reachability, and it does not try to. The audit's
anticipated defect — a position-blind selector deciding who sets — is not
present.

It does have a smaller version of the same problem: its emergency ranking is
`set_accuracy*0.44 + ball_control*0.28 + decision_making*0.16 + duty`, entirely
position-blind, and its winner then carries +0.20 into the spatial score. So a
technically excellent voli standing in the wrong half of the court gets a
tailwind in the real decision. Measured in case B, it is not currently enough to
move a ball.

---

## 3. Cases A–E

Both functions are **deterministic** — no `rng` draw in either — so every table
is exact rather than sampled. Six synthetic volis, every attribute at 50, zero
fatigue, slot 2 the designated setter. Only the named variable moves.

### A — designated setter available

| first contact | responsibility | chosen | overridden |
|---|---|---|---|
| slot 1 | slot 2\* | slot 2\* | — |
| slot 5 | slot 2\* | slot 2\* | — |
| slot 6 | slot 2\* | slot 2\* | — |
| slot 3 | slot 2\* | slot 2\* | — |

The plan's answer survives a chooser that scores five other people. ✔

### B — the setter played the first ball

| variant | responsibility | chosen |
|---|---|---|
| plan defaults | slot 1 | slot 1 |
| slot 1's `set_accuracy` cut to 10 | slot 1 | slot 1 |
| slot 6 (no duty) raised to 99 | slot 1 | slot 1 |

Slot 2 *is* the setter, so the only nomination left standing is slot 1's
secondary — and it holds against being made the worst set producer on the floor,
and against a no-duty ringer made the best. **Responsibility beats rating.** ✔
That is what a plan is for.

### C — the setter displaced

Pushing the setter away never moves the ball. Neither does squeezing the window:
at a 0.26 s pass with the setter deep in the opposite corner and an arrival
margin of **−1.32 s**, they still set it.

That is a one-sided test, though — it can only show the setter losing ground,
never what it takes for somebody else to win. So the probe walks a challenger
from the far corner onto the ball while the setter stands stranded at (0.10,
0.94), window held at 1.20 s:

| walk | challenger = slot 1 (*secondary*) | challenger = slot 6 (*no duty*) |
|---:|---|---|
| 0.00 | setter | setter |
| 0.25 | setter | setter |
| 0.50 | setter | setter |
| 0.75 | setter | setter |
| **0.90** | **slot 1 — legs won** | setter |
| **1.00** | **slot 1 — legs won** | setter |

**The crossing exists for one duty and not the other**, on identical geometry.
A nominated cover can take a ball off a stranded setter; a voli with no
nomination cannot, even standing on it.

Not *quite* cannot — and the arithmetic says exactly how nearly:

| slot 6 `set_accuracy` | chosen |
|---:|---|
| 50, 60, 65, 70 | setter |
| **75, 90, 99** | **slot 6 — won** |

So the ceiling is absolute **at equal attributes** and breakable only by being a
better setter. Which is the wrong way round: *being the only one who can reach
the ball* does not win it, and *being better at setting* does.

### C-rotation — the same stranded setter, walked round the six slots

Identical geometry in every row. Only the rotation moves.

| setter's slot | plan duty | verdict |
|---:|---|---|
| 1 | secondary | challenger — **legs won** |
| **2** | **primary** | **setter** |
| 3 | none | challenger — legs won |
| 4 | none | challenger — legs won |
| 5 | none | challenger — legs won |
| 6 | none | challenger — legs won |

**One rotation in six behaves differently, and it is an accident.** §4 is why.

### D — a poor pass

Neither selector takes `reception_quality`; this case demonstrates the absence
and measures what a bad pass *does* change.

| pass | chosen | setter's arrival margin |
|---|---|---:|
| clean, on the zone | slot 2\* | −0.169 s |
| slightly off | slot 2\* | −0.441 s |
| wide left | slot 2\* | −0.901 s |
| shanked deep left | slot 2\* | −1.652 s |
| flat, over the net side | slot 2\* | −1.199 s |

The margin moves 1.48 s across the range, entirely from the pass's own
destination and duration. **The realized ball is felt; the scalar describing it
is not consulted.** ✔ This is the structure the receive-chain audit's §7 asks
for, arriving here intact.

### E — does a rating heuristic pick the best set producer?

| variant | chosen |
|---|---|
| slot 6 `set_accuracy` 50 → 70 → 85 → 99 | slot 2\* every time |
| slot 6 `ego`/`leadership`/`aggression` 50 → 75 → 99 | slot 2\* every time |
| same spikes with the setter passing | slot 1 every time |

No. With the setter in position, neither technical quality nor temperament moves
a ball — the temperament terms reach 0.09 together against a duty gap of 1.04,
exactly as their own comment intends. ✔

---

## 4. The defect: two spans of identical width

`_spatial_setter_choice`:

```gdscript
match duty:
    "Primary emergency setter":   duty_bonus =  0.34
    "Secondary emergency setter": duty_bonus =  0.18
    "Stay available to attack":   duty_bonus = -0.16
    "No second-contact duty":     duty_bonus = -0.24
if candidate.id == designated_setter_id:
    duty_bonus += 0.46          ## stacks -- it does not replace
var arrival_score := clampf((available_time - travel_time) / 1.2, -1.0, 1.0)
var score := arrival_score * 0.52 + …
```

The `+= 0.46` **stacks on the plan's own duty**, and the plan writes duty per
slot. So the designated setter's total is not one number:

| setter stands in | plan duty | total `duty_bonus` |
|---|---:|---:|
| slot 2 | +0.34 | **+0.80** |
| slot 1 | +0.18 | +0.64 |
| slots 3–6 | −0.24 | **+0.22** |

A swing of **0.58** across the rotation that no design document asks for, and
that arises purely because the emergency-cover defaults happen to land on slots
1 and 2.

Then the sizes collide:

```text
widest duty gap    +0.80 − (−0.24)         = 1.04
arrival authority  (+1.0 − (−1.0)) × 0.52  = 1.04
```

**Identical to the last decimal.** In the slot-2 rotation the legs can tie
responsibility and never beat it; in the other five they can. The measured
tables in §3 are that arithmetic, not a coincidence beside it.

This is `FAILURE_MODES.md` §0 in its exact stated form — *a knob that cannot
reach its own range* — with the twist that it reaches it in five rotations out
of six, which is why nothing caught it. A gate written in any rotation but the
second would have passed.

**Three tables for one concept.** The same four duty strings are scored three
different ways in this one leg:

| duty | `_second_contact_setter` | `_spatial_setter_choice` | `ShadowSetterResponseSystem._duty_priority` |
|---|---:|---:|---:|
| Primary emergency setter | +0.42 | +0.34 | 0.82 |
| Secondary emergency setter | +0.24 | +0.18 | 0.62 |
| Stay available to attack | −0.10 | −0.16 | **0.08** |
| No second-contact duty | −0.22 | −0.24 | **0.15** |

The shadow system ranks `Stay available to attack` **below** having no duty at
all; both production selectors rank it above. The shadow layer is the intended
replacement path for this decision, so the two will have to agree before it is
promoted, and today they disagree about an ordering rather than a magnitude.

**And a comment that was wrong.** The `SECOND_CONTACT_*_PULL` doc block sized
those constants against "a spread of 0.70", reading the +0.46 as though it were
the whole of the designated setter's duty. The real spread is 1.04. The
conclusion survives — 0.09 against 1.04 is still under the tenth it claims — but
it survives by luck, and the comment now says so. Corrected in this pass.

---

## 5. In situ

800 isolated rallies, fresh `GameManager` per seed, both serving sides. 874 sets.

| | | |
|---|---:|---:|
| emergency second contact | 44 | 0.0503 |
| uncontested (`claimant_count` ≤ 1) | 374 | 0.4279 |
| seam conflicts | 4 | 0.0046 |
| mean claimants | | 2.849 |
| mean arrival margin | | **+0.538 s** |
| mean travel | | 0.523 s |
| late arrivals (margin < 0) | 38 | 0.0435 |
| reach margin absent | **0** | 0.0000 |

Positive mean margin, and only 4% late, because the head start is real: the
setter has been running since the serve was struck, not since the platform
touched the ball.

**Four volis take every second contact in the game.**

| actor | sets | share |
|---:|---:|---:|
| 1 (home setter) | 415 | 0.4748 |
| 2 (home emergency) | 44 | 0.0503 |
| 101 (opponent setter) | 391 | 0.4474 |
| 102 (opponent emergency) | 24 | 0.0275 |

Exactly one emergency setter per side, ever. Consistent with §3: the nomination
holds, and the only thing that displaces the designated setter is having played
the first ball. The defect in §4 is **latent on the shipped save** — it needs a
setter stranded far from a pass with a team-mate on top of it, which the vertical
slice's geometry does not produce often enough to see.

---

## 6. Verdict, and the policy boundary this pass stopped at

| question | answer |
|---|---|
| does selection read the realized pass? | **yes** — destination, duration, live positions, recovery debt, head start |
| does `reception_quality` change who is selected? | **no**, and it should not |
| is responsibility genuinely respected? | **yes** — it beats rating and temperament in every case measured |
| is movement feasibility used to assign responsibility, or only evaluated after? | **neither cleanly** — it is one weighted term inside the same score as duty |
| can another voli become the second contact? | yes, and the plan decides how easily |
| does a role/rating heuristic pick the best set producer? | **no** |
| is the selector structurally correct? | **structurally yes; numerically no** |

> **Resolved.** The policy was decided after this audit and option 1 shipped:
> *strong first responsibility, not absolute.* See
> `SECOND_CONTACT_TRANSFER.md` for the change, the six rotation gates and the
> residual boundary, which turned out to be the arrival model rather than the
> weights. The rest of this section is the decision as it stood when it was
> still open, kept because the options and what each implied are still the
> record of why option 1 was the one taken.

The structure is right. What is wrong is a magnitude, and **every available
correction answers a volleyball question nothing in `docs/design/` has decided:
should an unreachable designated setter keep the ball?** That is the named stop
condition for this pass, so it stops here. The options, stated so the decision
can be made rather than discovered:

1. **Make `+= 0.46` a replacement rather than an addition.** The designated
   setter's duty becomes a flat +0.46 in every rotation; the spread falls to
   0.70 and the rotation dependence disappears. This is what the sizing comment
   already claimed the code did. It answers the policy question with *yes, a
   stranded setter yields* — uniformly.
2. **Widen the arrival term** (raise the 0.52 weight, or the 1.2 s normaliser,
   or drop the clamp). Same answer to the policy question, applied everywhere,
   and it changes every second contact rather than the pathological ones.
3. **Give the plan a slot-independent designated-setter duty**, so the setter is
   not silently collecting an emergency nomination meant for whoever stands in
   slot 2. Fixes the rotation dependence and leaves the magnitude alone. Answers
   the policy question with *no, responsibility holds* — consistently.
4. **Leave it.** Defensible: it is latent on the shipped save, and 5% emergency
   setting is a plausible rate.

Not a decision to take from arithmetic. The measurement is here so it can be
taken from volleyball.

**Held for the same reason:** unifying the three duty tables in §4. Picking
which is canonical is the same class of decision.

---

## 7. Two asymmetries between the sides

**The opponent gets no head start and no expected area.** Home passes the
serve's own duration (1825, `serve_trajectory.duration`) and transition passes
the attack's; `_opponent_reception`'s call at 4025 passes neither, so every
opponent setter is timed from a standing start at the instant the platform
touched the ball. That is precisely the defect `head_start_seconds`' own comment
documents as having been fixed — *"a lie the engine told itself everywhere"* — and
it is still true on one side.

**The opponent discards the choice's own travel time.** Lines 4035–4050 re-read
`setter_start` from `opponent_live_positions` and recompute `setter_move_time` on
the `lateral` profile, rather than taking `travel_time` and `start` out of
`opponent_setter_choice` as the home path does. The existing comment explains the
profile difference and is right that swapping it would be a second change wearing
this one's name — but the consequence is that the opponent's published margin is
not the margin their setter was *selected* on.

Both are recorded, not repaired: they are the same class of change as §6 and want
the same decision first.

---

## 8. The exact remaining boundary into `choose hitter`

Four things cross from the chosen second contact into hitter selection, at 1905:

```gdscript
_choose_assignment(
    active_play, result.play_was_followed, players, lineup,
    setter.id,                      ## ← excluded: cannot make two contacts
    setter,                         ## ← the voli, for their own read
    float(result.reception_quality),## ← the scalar, again
    current_match_flow,
)
```

| carried | from | status |
|---|---|---|
| `setter.id` as `excluded_player_id` | the selection | ✔ three-contact legality, enforced |
| `setter` | the selection | ✔ identity |
| `play_was_followed` | `decision_making`, `tactical_discipline`, **and `reception_quality ≥ 0.42`** | the abstract channel |
| `result.reception_quality` | line 1528 | **the abstract channel** |

**None of the physical facts about how the second contact was reached cross into
who swings.** `setter_arrival_margin`, `reach_margin_meters`, `travel_time` and
`setter_start` are all published on the SET event and all stop there.

They are not wasted — `setter_arrival_margin` becomes `setter_approach_quality`
at 1994 and reaches `SetterCapabilityModel.evaluate`, so *how comfortably the
setter arrived* decides what set they can produce. It simply does not reach *who
they set to*. Whether it should is the `SETTER_DECISION.md` question and is not
this pass's.

So the boundary is: **the second contact hands the third a name, a legality
constraint and a scalar.** The scalar is the same `quality → ball` inversion
`PLATFORM_CONTACT.md` §7 sequences as slice 5, arriving one contact further
downstream than the receive-chain audit found it, and unchanged in kind.

---

## Re-running

```bash
godot --headless --path . --script res://tools/run_second_contact_probe.gd
```

Cases A–E are exact — both selectors are deterministic — and should reproduce
byte-for-byte. Part B is one fixture; treat its rates as description, never as a
target.
