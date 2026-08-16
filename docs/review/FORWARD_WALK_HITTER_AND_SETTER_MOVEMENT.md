# Forward walk: choose hitter ✔, setter movement ✘ — STOP

Run: 2026-08-16, from `41a57b6`. Instruments:
`tools/run_choose_hitter_probe.gd`, `tools/run_setter_movement_probe.gd`.

Nodes reached, in causal order:

| # | node | verdict |
|---|---|---|
| 1 | **choose hitter** | **✔ pass** — continued |
| 2 | **setter movement** | **✘ fail** — authority break, corrected, **STOP** |
| 3 | set quality | not inspected |
| 4 | generate set | not inspected |

Nodes 3 and 4 were not opened. The walk stops at the first structural failure by
instruction, and inspecting a node downstream of a broken one measures the break
rather than the node.

---

## NODE 1 — CHOOSE HITTER ✔

### The before-flow

`rally_simulator.gd` 1905, after the second contact is selected:

```gdscript
_choose_assignment(
    active_play, result.play_was_followed, players, lineup,
    setter.id,                       ## excluded: cannot make two contacts
    setter,                          ## whose read is doing the choosing
    float(result.reception_quality),
    current_match_flow,
)
```

**Eligibility is the tactical plan, not the roster.** Candidates come from
`play.assignments` and nothing else, minus decoys, minus `excluded_player_id`,
minus anyone failing `_can_enter_attack` (recovery debt), minus anyone not in the
lineup. A voli the manager did not name in the play cannot be set to at all.

**The call enters twice**: once as the candidate pool, and once as
`instruction_bias = 0.20` for `play.primary_hitter_id` when `follow_play` is
true.

**The setter's read is a modulator, not a bonus.** `judgment` —
`decision_making` 0.42, `court_vision` 0.33, `composure` 0.25 — never adds to a
score. It scales how accurately the setter perceives each option's feasibility
cost and height cost, scales `trust_pull`, and inversely scales `misread`. A poor
setter does not choose worse options *directly*; they misjudge the costs and then
choose consistently with what they misjudged. That is the right shape for a
decision node.

### The four gates

Exact — the setter branch returns before the function's only `rng` draw.

**A — same roster and ball, the call moves.**

| called primary | followed | abandoned |
|---|---|---|
| left pin | left pin | left pin |
| middle | **middle** | left pin |
| pipe | **pipe** | left pin |

The call was honoured 3 of 3, and the abandoned column pins to the same voli
regardless — so the movement is the call's doing, not the fixture's. A primary
marked `is_decoy` is correctly *not* chosen. ✔

**B — same call, the challenger's attacking ratings move.**

| middle's attack ratings | followed | abandoned |
|---:|---|---|
| 50, 60 | left pin | left pin |
| 70, 80, 90 | **left pin** | middle |
| 99 | middle | middle |

Ratings **refine**, the call **resists**. Without the call the ball moves at 70;
with it, at 99. That is `instruction_bias`'s +0.20 against an attack term
spanning ~1.0, and it is a defensible reading of volleyball — a setter does go to
a hitter who is two full grades better than the called option. Responsibility is
not replaced. ✔

**C — the second contact cannot swing.** The setter was named as the play's
primary, given a lane, and spiked to 99 across all three attack attributes:

| | chosen |
|---|---|
| `follow_play` true | left pin |
| `follow_play` false | left pin |
| **control: no exclusion** | **the setter** |

The control is what makes this evidence: with the exclusion lifted the same
fixture does pick them, so the rows above are the rule holding rather than the
fixture never offering them. ✔ Guarded three times over — `excluded_player_id`,
a re-check at 1929, and a live-attack rejection at 1916.

**D — only the realized pass moves.** Flat at every `pass_quality` from 0.05 to
1.00, in both columns.

`_choose_assignment` **takes no pass destination and no pass trajectory** — a
displaced pass cannot be expressed to this node at all. Per the intended
architecture that is correct: approach feasibility belongs to the later movement
stage, and this node is choosing an intention. ✔

### Two inputs that look load-bearing and are not

Recorded because both read as live and neither is. **No cleanup was made** — the
node passes, and manufacturing work for a passing node is what this walk was told
not to do.

1. **`_set_arc`'s `distance_meters`**, fed the hardcoded `Vector2(0.5, 0.60)` at
   the call site. With `ENABLE_SET_HEIGHT_TIMING` (true) the duration comes from
   `BallFlightModel.duration_for_apex` and the distance is never read — measured
   flat at 1.2351 s for 0.5, 2.0, 5.0 and 9.0 m. The fictional origin is
   **unreachable, not wrong**.
2. **`set_quality * 0.10`** in the option score. Added identically to every
   candidate, so it shifts all scores by the same amount and cannot reorder them.
   `pass_quality` reaches the *ranking* only through the provisional arc.

---

## NODE 2 — SETTER MOVEMENT ✘

### The break, in one number

The home path consumes the selection (1856–1859). The opponent path rebuilt all
four quantities from scratch. Running **one** selection and applying both recipes
to it — same fixture, same ball, same chosen voli:

| setter at the net, head start 1.34 s | start | distance | travel | margin |
|---|---|---:|---:|---:|
| home (consume) | (0.56, 0.68) | 0.000 m | 0.000 s | **+0.420** |
| opponent (rebuild) | (0.66, 0.60) | 1.698 m | 0.967 s | **−0.287** |

One recipe has the setter standing on the ball; the other has them 1.7 m away.
Same instant, same voli.

And the tell:

| realized pass duration | opponent's margin |
|---:|---:|
| 0.42 s | −0.287 |
| 0.68 s | −0.287 |
| 0.95 s | −0.287 |
| 1.30 s | −0.287 |
| 1.80 s | −0.287 |

**A constant cannot hear the ball.** The margin was
`DEFAULT_SECOND_CONTACT_SECONDS − travel`, so the pass's own flight had no effect
on how comfortably the opponent's setter was judged to have arrived. That is a
direct contradiction of this node's premise, and it is the STOP.

Three reconstructions, all of state the choice already carried:

| quantity | was | now |
|---|---|---|
| `setter_start` | re-read from `opponent_live_positions`, ignoring the head start | `opponent_setter_choice.start` |
| route / travel | re-solved, re-timed on the `lateral` profile | `opponent_setter_choice.navigation` / `.travel_time` |
| `setter_arrival_margin` | `DEFAULT_SECOND_CONTACT_SECONDS − travel` | `second_contact_window − travel` |

The profile change from `lateral` to `transition` rides along and is **not**
cosmetic: it is the profile the chooser timed the decision on, so keeping
`lateral` would preserve the disagreement rather than the model. An earlier note
held the travel time back to avoid "a second change wearing this one's name" —
correct when both recipes at least started from the same position; `41a57b6`'s
head start ended that.

Guarded: `_spatial_setter_choice` can return a `player` that is not
`opponent_setter` after the two null-fallbacks above it, and consuming another
voli's run would be worse than rebuilding one.

### A fourth break, one argument upstream

`second_contact_window` is `incoming_pass_trajectory.duration`, and the opponent's
serve-receive caller passed **`{}`** — so even after the fix above, the opponent's
first ball fell through to the same 0.68 literal. The realized flight was two
lines away, already published on the reception event as its `outgoing_trajectory`.
It is now passed. This was the last feed on either side handing the second
contact a number instead of a ball.

`_opponent_transition_phase_map` was handed the same literal for the other five
volis' transition budget; it now takes the realized window too.

### What the two sides publish

| key | home | opponent, before | opponent, after |
|---|---|---|---|
| `movement_start` | 349/349 | 310/310 | 309/309 |
| `movement_duration` | 349/349 | 310/310 | 309/309 |
| **`arrival_margin`** | 349/349 | **0/310** | **309/309** |
| **`emergency_setter`** | 349/349 | **0/310** | **309/309** |
| `reach_margin_meters` | 349/349 | 310/310 | 309/309 |
| `setter_position` | **0**/349 | 310/310 | 309/309 |

No opponent second contact in the game could be audited for how comfortably it
arrived, or for whether it was an emergency at all.
`_stamp_second_contact_claim`'s note says every call site stamps its own
`arrival_margin`; that was true of the home paths and false here.

`setter_position` remains home-absent and is left alone — it is a naming
difference, not a missing fact, and node 1 does not depend on it.

### In situ

600 isolated rallies, both serving sides.

| | before | after |
|---|---:|---:|
| home sets / margin / travel | 349 / 1.0375 / 0.2533 | 309 / 1.0935 / 0.2084 |
| **opponent sets / margin / travel** | 310 / **absent** / **0.8110** | 305 / **1.0359** / **0.2720** |
| opponent late (margin < 0) | absent | 0.1344 |
| opponent emergency rate | absent | 0.0361 |

The opponent's travel falls from 0.81 s to 0.27 s and lands beside home's 0.21 s:
the two sides finally describe the same kind of movement. Their margins now sit
at 1.09 and 1.04 rather than one being unmeasurable.

Outcome mix, **regression observation only, not tuned**:

| | before | after |
|---|---:|---:|
| home points | 316/600 (0.5267) | 310/600 (0.5167) |
| kill | 185 | 183 → 168 |
| opponent_kill | 149 | 152 → 170 |
| **counter_block** | **19** | **46** |
| attack_error | 53 | 38 |

`counter_block` is the largest mover and worth naming rather than burying: an
opponent setter who now has a realistic window and arrives on the ball produces
better sets, and better opponent offence meets the home block more often. It is
recorded, not steered.

### The short-leg question — and a correction to `SECOND_CONTACT_TRANSFER.md` §7

That document attributed a margin collapsing from +1.200 s to −0.133 s over
12.5 cm to "the movement model charging a full standing start however short the
leg." **That attribution is wrong.** Clear travel is continuous and monotone:

| distance | travel | implied speed | Δ travel |
|---:|---:|---:|---:|
| 0.005 m | 0.0671 s | 0.07 m/s | +0.0671 |
| 0.05 m | 0.1690 s | 0.30 m/s | +0.0548 |
| 0.125 m | **0.2556 s** | 0.49 m/s | +0.0866 |
| 0.50 m | 0.4914 s | 1.02 m/s | +0.1381 |
| 2.00 m | 0.9628 s | 2.08 m/s | +0.2761 |
| 4.00 m | 1.4123 s | 2.83 m/s | +0.4496 |

12.5 cm costs 0.2556 s, not the ~1.33 s that collapse implies. The earlier
fixture had a body parked **exactly on the contact point**, so the route bent
around them:

| distance | clear | obstructed | detour? |
|---:|---:|---:|---|
| 0.005 m | 0.0671 | **1.3588** | yes |
| 0.125 m | 0.2556 | **1.3484** | yes |
| 0.50 m | 0.4914 | **1.3661** | yes |
| 4.00 m | 1.4123 | 2.1083 | yes |

The cause was `_navigation_waypoint`, not the standing start — and the obstructed
cost is very nearly **independent of distance** (1.359 at 5 mm, 1.348 at 12.5 cm,
1.366 at 50 cm). That is a fixed toll for having somebody on your contact point.
Whether a toll that ignores distance is right belongs to the movement/approach
work, not here.

For **this** node the answer is clean: travel time is continuous and monotone in
distance, so setter movement is physically meaningful and the short-leg issue
**does not** invalidate the authority chain. Documented, not repaired, and no
cutoff invented.

---

## Tests

`_test_opponent_setter_movement_consumes_selection`, four checks, built around one
identity on published data:

```text
arrival_margin + movement_duration == the realized pass's own duration
```

It cannot hold unless the margin is measured against the ball, the travel is the
one selection used, and both are actually published.

1. every opponent set publishes the arrival margin it was resolved with;
2. every opponent set says whether it was an emergency second contact;
3. the identity holds exactly (tolerance 5×10⁻⁴);
4. margins take more than five distinct values — because a constant window and a
   constant travel would satisfy the identity too.

**Verified bidirectional: all four fail on the pre-change resolver.** Check 2
initially passed on both versions because the loop `continue`d on a missing margin
before it could test for `emergency_setter`; the guard order was fixed. That is
the third time this branch has caught a gate that could not fail, and it keeps
being caught only by actually reverting and re-running.

An existing gate was **widened, not loosened**:
`_test_gate_twenty_two_setter_progression` asserted `reach_states.has("jump")`
over 40 seeds that produced **two** jump sets. Any resolver change that reshuffles
which rallies run long can move both. Measured across 400 seeds, the home jump
rate went 18 → 22 — unharmed and slightly up — while the forty-seed window went
2 → 0. The window is now 160 seeds, carrying roughly nine, so it measures its own
claim instead of a coin on its edge.

Suite: **2,098 checks, no failures.** 2,095 + 4 written − 1: one sampling gate
drew a check fewer, which is what a production change does to a population.

---

## The exact next boundary

The walk resumes at **node 3, set quality**, with node 2's chain now:

```text
selected second-contact voli
+ realized pass destination      ✔ opponent_setter_position / set_contact
+ realized pass duration         ✔ second_contact_window, both sides, all feeds but one
+ actual start state             ✔ the selection's own start, both sides
→ physical setter movement       ✔ one owner
→ realized arrival state         ✔ published, both sides
```

Three things the next pass should carry rather than rediscover:

1. **The coverage feed into `_resolve_opponent_transition` still publishes no
   flight**, so its window is honestly the fallback. The test skips those rather
   than counting them as failures. Two dig callers also still pass no head start
   (`41a57b6` recorded this); neither is measured yet.
2. **`reception_quality` still crosses into `SetterCapabilityModel.evaluate`** —
   untouched here on instruction, and the first question node 3 has to answer is
   what independent job it is doing now that arrival margin, contact height and
   the realized window all reach the same model.
3. **The obstruction toll is distance-independent** at ~1.35 s. It did not block
   this node and it will matter to hitter approach.
