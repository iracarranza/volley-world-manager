# Embodied Movement Continuity

Execution of `docs/specs/EMBODIED_MOVEMENT_CONTINUITY.md`, on
`claude/system-fit-serve-receive-von64k` from `57230d2`.

Evidence authority for everything this pass is responding to is
`docs/review/SIX_PLAYER_EMBODIED_MOVEMENT_AUDIT.md`.

---

# C0 — Reconcile the authoritative exit state

## C0.1 The two definitions, traced

**The closed form.** `RallyMovementSystem.traversal_result` →
`_leg_seconds`, which ends:

```gdscript
"exit_speed": minf(opening_speed + acceleration * seconds, maximum_speed)
```

A body accelerates for the whole leg and exits at whatever it reached. There is
no arrival term and no braking term. `_with_exit_velocity` then points that
scalar along the leg's heading. This is what `RallySimulator._travel` returns and
what `live_velocities` stores.

**The integrator.** `ShadowMovementSystem.integrate` steps
`RallyMovementSystem.project_toward`, whose arrival branch is:

```gdscript
var reached_target := traveled >= distance - 0.001
var arrival_velocity := direction * ending_speed
if reached_target and not carry_through:
    arrival_velocity = Vector2.ZERO
```

`RallyMovementPath.exit_velocity` is then the last velocity sample by
construction (`from_integration`, `:57`), so the published path inherits this.

## C0.2 Why a completed short leg reports ~5 m/s and ends at 0

`carry_through` is the whole answer, and the finding is that **no caller in the
repository ever passes it `true`.** Three greps across `scripts/`, `tests/` and
`tools/` return the parameter's declaration, its default, and its single use.
Every arrival in the game therefore takes the zeroing branch.

The parameter is not vestigial — its own comment states the intended contract:

> The default is a player who has got where they were going and set up there,
> which is right for a defensive mark. It is wrong for a waypoint: a hitter
> running to their approach mark does not stop on it, they run through it into
> the swing.

The distinction is right and the wiring never arrived. `ShadowMovementSystem`
then re-implemented half of it by hand — at `:131` it overwrites the zeroed
velocity when the arrival was a waypoint — which is why waypoints work and why
`carry_through` stayed dead.

**So the two models are not two theories of arrival. One of them is a correct
theory with no caller, and the other is a workaround for its absence.**

## C0.3 Measured: three answers for one leg

`tools/probe_exit_state_contract.gd`, all four cases the spec's C0.3 requires a
contract to cover. `closed` is `traversal_result().exit_velocity`, `final` is the
integrated path's last velocity sample, `path` is
`RallyMovementPath.exit_velocity`.

| case | rows | closed | final | disagreement |
|---|---:|---|---|---|
| **reached** | 15 of 15 | 4.289–5.227 | **0.000** | **4.289–5.227 m/s** |
| truncated, body at top speed | 5 of 8 | 5.227 | 5.227 | 0.000 |
| **truncated, still accelerating** | **3 of 8** | **5.227** | 1.428–3.798 | **1.428–3.798 m/s** |
| waypoint, arrives | 2 of 4 | 5.227 | 0.000 | 5.227 |
| waypoint, does not arrive | 2 of 4 | 5.227 | 5.227 | 0.000 |
| off-court target | 2 of 2 | 5.227 | 5.227 | 0.000 |

`path` equals `final` in every row, as `from_integration` guarantees.

**The truncated rows are a second defect, and the audit did not find it.**
`traversal_result` solves the *whole* journey and reports the speed at its
notional end. Truncation happens later and elsewhere — `_committed_path` caps the
duration with `minf(_movement_time(...), available_time)` — and `_travel` is
never told. A body cut off at 35% of its journey is recorded as exiting at the
speed it would have carried at 100%. The rows where this hides are the ones where
the body had already reached `maximum_speed`, which is why it survived an audit
that sampled entry speeds of 0 and 6 m/s at fixed distances.

**The off-court rows agree, which narrows A8b.** The audit recorded a clamp
divergence; these rows show it is a divergence about *landing position* only.
Neither model reaches the target, so both report the same speed. Exit velocity
and off-court legality are separate questions, and only the second is C5's.

## C0.4 The contract

Repo truth decides this, and it is already written down twice.
`reachable_distance` states the model's position on braking:

> Two segments, and no third: a body accelerates to its top speed and then holds
> it. Deceleration is deliberately not modelled here — a defender arrives *at*
> the ball rather than stopping on it, and charging them a braking phase would be
> inventing a cost the sport does not have.

A leg's duration is therefore the time to cover the distance with no braking
phase. At the instant `t = duration` the body **is** moving at `ending_speed`.
Writing `Vector2.ZERO` there is not a claim about that instant; it is a claim
about some later time the leg does not cover. The two comments only appear to
conflict because one is about the instant of arrival and the other is about the
body's state afterwards.

That gives one rule, and one detail:

> **A leg's terminal velocity is the body's velocity at its final sample.**
>
> A body that arrives as the leg ends exits at speed. A body that arrives with
> time to spare stands for the remainder and exits at rest. A body that does not
> arrive exits at the speed it actually reached — the truncated speed, not the
> speed it would have had.

Applied to the four cases:

| case | terminal velocity |
|---|---|
| reached, arrival at the end of the leg | `heading × ending_speed` |
| reached, arrival with idle time left | `Vector2.ZERO` |
| unreached / truncated | `heading ×` the speed reached **at the truncation point** |
| waypointed | the corner carries only the aligned component; the final arrival takes the reached rule |
| clamped / legal off-court | the same rule at wherever the body actually ended; position clamping is a separate question and stays C5's |

**Braking does not disappear — it moves.** Under this contract a defender who
arrives at their mark is left carrying speed, and shedding it becomes a cost of
the *next* leg. That is precisely the spec's stated goal shape, `path N → actual
exit state → brake/redirect/turn/accelerate → path N+1`, and it is why C0 must
land before C2 rather than after it.

**The idle-arrival case is real and not hypothetical.**
`rally_opportunity_system.gd:159` calls `integrate` with a perception gap length
that has no relation to the traversal time, and its own comment already guards
against "an actor who has coasted onto their target". `_committed_path` caps
duration at the traversal time so it cannot produce an idle tail, but it is not
the only caller.

## C0.5 The repair, and the two further defects it uncovered

Four changes. The first was the one the audit predicted; the other three were
found by measuring after each step, and each was hiding behind the one before it.

**1. Arrival keeps its speed.** `ShadowMovementSystem.integrate` now passes
`carry_through: true`, so the zeroing branch no longer fires, and the hand-rolled
waypoint fix-up at `:131` is deleted as redundant. That fix-up wrote
`direction * carried_speed` — the speed at the *start* of the arriving step — so
removing it also removes a small under-report.

**2. The arrival speed is solved over the distance, not the window.**
`project_toward`'s carry-through branch computes `sqrt(v0² + 2ad)` rather than
reusing `ending_speed`, which is the speed at the end of the whole slice. A body
that arrives partway through a step never reaches that speed. This removes a
discretisation bias rather than a modelling error.

**3. The turn-delay guard tested the wrong variable.** `_leg_seconds` read:

```gdscript
var opening_speed := entry_speed if entry_speed > 0.0 \
    else maxf(actor.velocity.dot(direction), 0.0)
...
if entry_speed <= 0.0:
    seconds += float(profile.direction_change_delay)
```

The comment says "a player already carrying speed into this leg has already
turned", and the guard tests the *parameter* instead of the resulting
`opening_speed`. `traversal_result` always passes `0.0` and lets the fallback
supply the speed from `actor.velocity`, so **every moving body took the
standing-start branch and was charged a turn it had already made.**

`ShadowMovementSystem` charges on the opening speed (`:86`) and therefore did
not. The two models disagreed about the leg's *duration*, the body arrived that
much early, and the arrival was then read as idling. This is why fix 1 alone
repaired only the rows entering at rest — the moving rows were failing for a
different reason underneath.

**4. The closed form credited acceleration to the turn.** `exit_speed` was
`opening_speed + acceleration * seconds` where `seconds` includes the
direction-change delay, so a body standing still to turn was accelerating
throughout it. Replaced with `sqrt(v0² + 2ad)`, which has no time term and is the
same arithmetic `project_toward` now uses. Worth a constant 0.942 m/s on the
short legs from rest.

**5. The idle threshold had to be the integrator's own step.** The first version
used `moving_time - elapsed > 0.0001`, and a leg that arrives on its final slice
leaves a rounding residue — measured at 0.16 ms on a 0.267 s leg — which that
threshold read as a body standing still. It zeroed the arrival speed on exactly
the legs the contract is about. The floor is now one integration step, because
below one step the integrator could not represent the standing anyway. A
threshold tied to the instrument's resolution rather than picked.

## C0.6 Measured after the repair

`tools/probe_exit_state_contract.gd`, same 29 rows:

| case | before | after |
|---|---|---|
| **reached** (15 rows) | **15 disagree, 4.289–5.227 m/s** | **0 disagree, 0.000** |
| waypoint (4 rows) | 2 disagree, 5.227 | 0 disagree, 0.000 |
| off-court (2 rows) | 0 disagree | 0 disagree |
| truncated (8 rows) | 3 disagree, 1.428–3.798 | 3 disagree, unchanged |

**The truncated rows are deliberately left.** `traversal_result` is never told
about a cap — truncation happens afterwards, in `_committed_path`'s
`minf(_movement_time(...), available_time)` — so its answer is the untruncated
journey's *by definition*, and no parameter was added to make it express one.
Adding an `available_seconds` nothing passes would reproduce exactly the disease
this section is about: `carry_through` sat unused for the entire life of the
feature it was written for.

The contract for a truncated leg is therefore: **the path is authoritative and
`_travel`'s whole-journey exit velocity must not be used.** That is checkable, and
production satisfies it today — all three `live_velocities` write sites
(`:2349`, `:5197`, `:7096`) use `_travel`'s `seconds` uncapped, so none of them
is a truncated leg. Recorded as a live constraint on future callers rather than
as a latent bug.

## C0.7 Validation

| control | result |
|---|---|
| exit-state probe | 26 of 29 rows agree to 0.000; the 3 are truncated, by contract |
| **P15 playback corrections** | **0 of 8,636 drawn legs, worst 0.0000 court units** |
| 700-rally balance | contacts 4.630→**4.633**, kill 0.535→**0.537**, dig 0.522→**0.520**, stuff 0.101, ace 0.099, serve error 0.194 unchanged |
| **full suite** | **2 of 2,270**, the same two known failures, no third |
| regression added | `_test_leg_exit_velocity_is_one_number`, 3 checks |

**Three checks written, three gained, and the predecessor was measured on this
tree** — 2 of 2,267 at `4e2c42d`. So the delta is authorship and nothing else.

That is worth one line, because it is the *interesting* case rather than the
usual one: C0 changed rally outcomes (contacts 4.630 → 4.633, and the drawn-leg
population 8,733 → 8,636), and **no sampling gate drew a different number of
checks anyway**. A count that moves by exactly what was written normally means
nothing moved underneath it; here something demonstrably did, and the sampling
gates happened not to be sensitive to it. The balance probe is the instrument
that saw the change; the count was never going to.

**Rally outcomes moved, and that is correct rather than tolerated.** Fix 3
changes how long a moving body takes to travel, so contacts resolve at different
times. The drift is 0.3% on contacts and 0.2 points on kill; every gated band
that was inside stays inside. Kill (0.537 against 0.45–0.50) and ace (0.099
against 0.05–0.09) remain outside, and both were already outside at the audit's
A0 baseline — 0.535 and 0.099. This pass did not put them there and has not been
used to move them.

**The drawn-leg count moved 8,733 → 8,636** for the same reason: rallies resolve
differently, so the sampled population is not the same one. The correction count
being zero across a population that changed size is the meaningful half.

The regression test fails on the predecessor by construction: it sweeps the same
five distances and three entry speeds as the probe's `reached` block, where the
predecessor disagreed on 15 of 15 rows by 4.289–5.227 m/s against a 0.01 m/s
gate.

---

# C1 — Carry momentum across production leg boundaries

## C1.0 Where the boundary actually is

The audit's population is 5,800 consecutive leg pairs, all 5,800 beginning at
rest, with 569 of the 1,482 >10 cm gaps attributed to
`phase_intent → phase_intent`. Tracing that publisher to its source:

**`_travel_intent` is the single publisher of every `phase_intent` leg.** Nineteen
call sites reach it, it calls `_committed_path` once, and it already commits the
authoritative landing (`reached_position`) rather than the closed form's answer —
the P15 repair went through this same function for the same reason. It is
therefore the one place a velocity carry has to be added for the whole
`phase_intent` population to inherit it.

The phase maps around it already thread *position* across legs, and the pattern
is uniform:

```gdscript
var here: Vector2 = live_positions.get(player.id, <a formation default>)
...
var reached := _reached_point(player, here, intent, window_seconds, mode)
out_intents[player.id] = _travel_intent(player, cue, here, intent, reached, ...)
live_positions[player.id] = <the leg's landing>
```

`live_positions` carries the position out of one leg and into the next.
**`live_velocities` exists beside it and no phase map writes to it** — the audit
found only three writers, all of them hitter sites. So the store the carry needs
is already there and only the hitter path has ever used it.

## C1.1 Classification: which boundaries must *not* join

The spec requires legitimate discontinuities be preserved rather than
mechanically joined. Three classes reset, and each is identifiable in the code
rather than by judgement:

| class | where | why it resets |
|---|---|---|
| **a contact** | `live_positions[actor.id] = contact_pos` (`:12123`, `:12186`) | the body played the ball; the leg after a contact is a new physical action |
| **a recovery** | `&"recovering"` intents (`:16252`, `:16377`) | the same body, immediately after its own contact |
| **a hold** | `_travel_intent(p, cue, here, here, here, …)` | zero-length; `_committed_path` returns `null` and there is no leg to inherit from |

Everything else — an off-ball body shuffling from one defensive shape to the next,
a coverer fanning out, a blocker sliding along the net — is an ordinary
consecutive boundary and is what C1 is for.

## C1.2 Planned increments

Three attributable steps rather than one, because the first must provably change
nothing:

1. **Plumbing, no behaviour.** `entry_velocity` parameters on `_reached_point`
   and `_travel_intent`, defaulting to `Vector2.ZERO` and forwarded to
   `_movement_time` and `_committed_path`; `_travel_intent` publishes
   `exit_velocity` from the path. With every caller still passing the default
   this must leave the balance probe byte-identical, and that is the check.
2. **Wire the phase maps.** Thread the carry through the transition, cover,
   setter-read and hold phases, honouring C1.1's three reset classes.
3. **Re-measure** the 600-rally continuity population — dead-start rate,
   moving-predecessor count, >10 cm gaps, publisher-pair breakdown, worst gap —
   against the audit's recorded baseline.

Step 1 exists to make step 2's drift attributable. A single commit doing both
would leave no way to tell a wiring mistake from a real timing change, which is
the failure the audit spent a section on.

## C1.3 The P15 regression, and the older defect under it

Wiring the cover phase broke the correction invariant: **1 correction of 8,529
drawn legs, 0.0104 court units, on a SET following ATTACK_COVERAGE.** Bisected by
neutralising each wiring in turn — the two transition maps and the three reset
classes are clean at 0, the cover carry is the trigger.

The spec forbids restoring an invariant by hiding a contradiction, so it was
traced. **Two hypotheses were wrong and measurement said so:**

1. *The home continuation SET publishes no path.* True, and it was published —
   still 1 correction, identical.
2. *The staged leg is budgeted from a `setter_choice` that predates the coverage
   carry, so it lands short.* Also true, also fixed — still 1 correction, byte
   for byte.

Both are real improvements and neither was the cause. Finding the cause needed
the seed instrumented, and reproducing it needed the audit tool's own warm-up:
`audit_playback_corrections.gd` resolves a band of seeds against **one** manager,
so seed 22004 on a fresh manager is an ace and not the rally in question.

**The failing leg is on the *opponent* SET**, not the home one that had been
edited on hypothesis 1. Its metadata carries `movement_start` and
`movement_duration` and has never carried a `movement_path` at all — the setter's
step onto the ball is an unpublished journey, so playback closes it itself. It
stayed invisible while those two points sat inside playback's 0.0005 threshold,
and moving the coverage landing by roughly a centimetre opened it.

**C1 surfaced this defect; it did not create it.** It is one of the audit's
"slots publishing no path", on a contact actor rather than an off-ball body.

Both SET sites now publish the leg, budgeted by **the journey's own duration**
rather than by what remains of the second-contact window. That remainder goes
non-positive on an emergency set, and `_committed_path` then publishes nothing at
exactly the moment a body is furthest from its contact — the shape that hid this
for as long as it did.

P15 returns to **0 corrections of 8,529, worst 0.0000**.

## C1.4 Measured: momentum crosses the boundary, and mostly still does not

120 rallies, directly comparable to the audit's 120-rally baseline — same seeds,
same instrument.

| measure | audit baseline | after C0+C1 |
|---|---:|---:|
| consecutive leg pairs | 1,044 | 1,063 |
| **next leg begins at rest** | **1,044 of 1,044 (100%)** | **946 of 1,063 (89.0%)** |
| **previous leg ended moving** | 149 | **960** |
| pairs gapped by more than 10 cm | 268 | 271 |
| worst gap | 4.781 m | 4.781 m |
| `phase_intent → phase_intent` gaps | 102 | 103 |

**Two different things moved, and they are worth separating.**

*117 legs now inherit momentum*, from a population where the audit found exactly
zero. That is C1 working, and it is the first time in the engine's history that a
leg has begun with the speed the previous one ended with.

*`previous_leg_ended_moving` went 149 → 960*, and that is **C0**, not C1. Legs
now report the exit velocity they actually have instead of a zero written at
arrival, so six times as many boundaries are visibly discarding something. The
audit's 149 was an undercount produced by the defect C0 removed.

**Which leaves the number the C1 gate is actually about: 960 boundaries have a
moving predecessor and 117 inherit it, so 843 still drop momentum.** The gate
says a decrease in dead starts is not enough and the remainder must be classified
rather than counted, and the instrument cannot classify it yet — it reports dead
starts in total and publisher pairs only for the *gap* population. Extending it
to break dead starts down by publisher pair is the next step, because that is
what distinguishes an unwired publisher from a legitimate reset.

## C1.5 Classifying the remainder, which is what the gate asks for

The gate says a decrease in dead starts is not enough and the remainder must be
classified. The instrument could not do that — it reported dead starts only in
total — so it was extended to report, per publisher pair, how many boundaries
with a *moving predecessor* kept the momentum and how many dropped it.

At 600 rallies after step 2, of 4,593 drops:

| previous → next | dropped | classification |
|---|---:|---|
| `phase_hold → phase_intent` | 2,686 | **unwired**: `_hold_phase_intents` |
| `phase_intent → phase_intent` | 744 | **unwired**: the remaining `_travel_intent` sites |
| `movement_path → phase_hold` | 388 | **intentional**: a contact resets (C1.1) |
| `movement_path → phase_intent` | 357 | **intentional**: a contact resets |
| `phase_hold → movement_path` | 219 | **unwired** |
| `phase_hold → phase_hold` | 117 | **unwired** |
| `movement_path → movement_path` | 51 | **intentional** |
| the rest | 31 | unwired |

**796 intentional, 3,797 defects with a named upstream source**, and
`_hold_phase_intents` is 3,035 of them on its own. No drop is unexplained, which
is the gate.

## C1.6 Wiring the rest, and a mistake worth the guard it produced

`_hold_phase_intents` and `_setter_read_phase` are side-generic — they take the
`live` positions dict as a parameter — so both now take the matching velocity
store beside it. `phase_hold` legs are real journeys despite the name; the
function's own comment records the pass that stopped them being published as
zero-length holds.

**Wiring them made the number worse: 705 carried boundaries fell to 243.** The
cause is a distinction the store had not been making. `_committed_path` returns
`null` for a zero-length leg and for a non-positive window, and `_travel_intent`
then reports `exit_velocity` as a *default* rather than a measurement. Writing
that back wiped the momentum the body was actually carrying.

**A leg that published no path is not a statement that the body stopped.** All
five store writes now go through `_record_exit_velocity`, which declines to
record anything with no journey behind it. This is the same error as C0's idle
threshold, in a different place: treating an absence of evidence as evidence.

## C1.7 The worst gap grew, and it was mostly the metric

After the wiring, `gap_m_worst` had gone 4.78 m → 7.54 m while the gap population
held at 25.4%. Naming the worst case explained it in one line: **seed 61173,
player 101, 3.128 s apart.**

The pair loop skips only *overlapping* legs, so two legs separated by three
seconds of rally clock still counted as consecutive — and a body covering 7.5 m
in three seconds is walking, not teleporting. `gap_m_worst` was conflating real
discontinuities with legal travel through intervals nobody published.

The metric is now split at 0.10 s, and the two populations are very different
sizes: **only 774 of 5,846 pairs actually adjoin.** The other 5,072 are the
publication-coverage finding the audit already recorded as "24% of slots publish
no path", arriving from a second direction.

## C1.8 Attribution, measured on both trees with the same instrument

The split instrument was run against `57230d2` — the pre-C0 production files,
restored into the tree and then reverted — so the comparison is same instrument,
same seeds, both sides.

| measure | pre-C0 `57230d2` | after C0+C1 |
|---|---:|---:|
| **next leg begins at rest** | **5,800 of 5,800 (100%)** | **5,073 of 5,846 (86.8%)** |
| previous leg ended moving | 801 | 5,324 |
| pairs that actually adjoin | 647 of 5,800 | 774 of 5,846 |
| **adjacent gaps over 10 cm** | **207 (32.0% of adjoining)** | **217 (28.0% of adjoining)** |
| worst adjacent gap | **4.781 m in 0.010 s** | 5.151 m in 0.065 s |

**773 boundaries now carry momentum, from zero.**

**The teleport defect predates this pass and C1 improved its rate.** The
pre-C0 worst case is 4.78 m in 10 ms — 478 m/s — against C1's 5.15 m in 65 ms,
79 m/s. Both are impossible and the older one is the more extreme by a factor of
six. The share of adjoining boundaries with a >10 cm gap *fell*, 32.0% to 28.0%,
on 20% more adjoining pairs.

So the tail figure moved and the defect did not: the worst case is a different
seed, player and publisher pair, and the population it comes from is healthier.
**That is not a C1 regression, and it is not fixed either** — 217 adjacent
discontinuities remain, they are physically impossible, and they belong to a
defect this pass did not create and has not repaired. C2 changes arrival times
again, so it is recorded here with its instrument and left for the re-measurement
after C2 rather than chased now.

**An instrument error, recorded because it nearly became a conclusion.** The
first re-measurement was invoked as `--script … audit_six_player_space.gd
rallies=600`. The tool reads `OS.get_cmdline_user_args()`, which needs `--` before
its arguments, so it silently ran the 120-rally default. It announced itself:
the A7 block came back byte-identical to the 120-rally baseline — 34, 260, 305,
worst 0.88 m, same seed — which a 600-rally sweep cannot do. Quoting those as a
600-rally result would have been the wrong-instrument failure `FAILURE_MODES.md`
§0 is about.

## C1.9 Validation

| control | result |
|---|---|
| **P15 playback corrections** | **0 of 8,580 drawn legs, worst 0.0000** |
| **full suite** | **2 of 2,272**, the same two known failures, no third |
| 700-rally balance | contacts 4.633→**4.593**, dig 0.520→**0.510**, stuff 0.101→**0.099**, block touch 0.804→**0.794**, kill 0.537 and ace 0.099 unchanged |
| swing balance | 0.973 → **0.950**, away from 1.00 — advisory, recorded not acted on |

**No checks were written and the count moved by two, which is the opposite
reading from C0's and means the opposite thing.** 2,270 was measured at
`6cd7f54` on this tree. C1 authored no test, so the whole delta is sampling
gates drawing against a different population — which is exactly what a pass that
changes arrival times has to look like. C0's +3 was entirely authorship with the
population moving invisibly underneath; C1's +2 is entirely population. The two
deltas are the same size and carry no common meaning, which is the point
`CLAUDE.md` keeps making about this number.

Every gated band that was inside stays inside. Kill (0.537 against 0.45–0.50) and
ace (0.099 against 0.05–0.09) remain outside and were outside at the audit's A0;
neither has been touched to move them.

---

# C2 — Charge braking and reversal

## C2.0 Where the momentum is discarded

Both models drop it in the same expression, one line each:

```gdscript
## RallyMovementSystem._leg_seconds
var opening_speed := entry_speed if entry_speed > 0.0 \
    else maxf(actor.velocity.dot(direction), 0.0)

## RallyMovementSystem.project_toward
var forward_speed := maxf(actor.velocity.dot(direction), 0.0)
```

`maxf(…, 0.0)` is the whole defect. Momentum along the travel direction is
credited; **everything else is deleted rather than charged.** Perpendicular
momentum vanishes for free, and a body sprinting away is treated as one standing
still — which is A3.1's table: 6 m/s at 180° costs exactly what 0 m/s costs,
1.0571 s, across every angle from 90° outward.

`project_toward` discards it a second way. It writes
`arrival_velocity = direction * ending_speed` every step, so the lateral
component is not integrated away — it is overwritten. The drawn body turns
instantly and for free.

## C2.1 The model

The requirement is a cost continuous in speed *and* angle, built from the
locomotion model already there, with no categorical penalty and no second
reversal system. Split the entry velocity against the travel direction:

- `v_forward = v · d` — signed, and may be negative
- `v_bad = v − max(v_forward, 0) · d` — everything that has to go

Then the leg is **arrest, then the traversal it already models**:

| term | value |
|---|---|
| arrest time | `t_a = ‖v_bad‖ / a` |
| ground given up | `|v_forward| · t_a / 2` when `v_forward < 0`, else 0 |
| opening speed | `max(v_forward, 0)` — unchanged |

`a` is the profile's own acceleration, so nothing new is introduced or tuned.
The second row is what separates turning from reversing: a body moving away
keeps travelling away while it decelerates, so it must cover that ground again.

Checking the ordering the spec asks for, at one speed and one distance:

| entry | `‖v_bad‖` | arrest | ground lost | opening | rank |
|---|---|---|---|---|---|
| toward | lateral only (0 if aligned) | ~0 | 0 | `+s` | **fastest** |
| stationary | 0 | 0 | 0 | 0 | baseline |
| perpendicular | `s` | `s/a` | 0 | 0 | slower |
| away | `s` | `s/a` | `s²/2a` | 0 | **slowest** |

`toward < stationary < perpendicular < strongly away`, continuous in both
variables, and it degenerates exactly to today's behaviour at zero entry speed.

## C2.2 The integrator has to stop overwriting velocity

Charging the closed form alone would break C0's contract: the two models must
agree about the same leg. `project_toward` currently forces velocity onto the
travel direction each step, which is why the integrator agrees with the *old*
free-reversal closed form today.

The fix is the one the spec prefers — use the existing integrator rather than
add a system — by making the step apply acceleration **as a vector** toward the
target and letting the velocity turn:

```
v' = v + a · Δt · d,  clamped to the profile's maximum speed
```

A body moving away then decelerates through zero and back out under its own
model, and the arrest cost is an *emergent* consequence rather than a term. That
is the same arithmetic the closed form's C2.1 split approximates in one shot, so
the two stay reconcilable — and the C0 probe plus
`_test_reachability_agrees_across_the_court` are the instruments that say whether
they actually did.

**This will move rally outcomes more than C0 or C1 did.** Reversal becoming
expensive changes who reaches what, and the audit's A3.1 table is the size of the
effect: up to 1.06 s on a 3 m leg. The balance probe is the measurement, and per
the spec the drift is reported rather than normalised away.

## C2.3 Measured: the ordering the spec asked for

`audit_embodied_locomotion.gd`, 3.0 m target, TRANSITION, seconds to target and
the delta against a body standing still:

| entry | 0° | 45° | 90° | 135° | 180° |
|---|---:|---:|---:|---:|---:|
| 0.0 | 1.0571 | 1.0571 | 1.0571 | 1.0571 | 1.0571 |
| 1.5 | 0.8111 | 1.0595 | 1.3080 | 1.3351 | 1.3464 |
| 3.0 | 0.6586 | 1.1171 | 1.5756 | 1.6843 | 1.7293 |
| 4.5 | 0.5830 | 1.2131 | 1.8433 | 2.0877 | 2.1890 |
| 6.0 | 0.5740 | 1.3476 | 2.1110 | 2.5455 | **2.7255** |

Against the audit's predecessor, where every cell from 90° outward read 1.0571
regardless of speed:

**6 m/s directly away from the target cost nothing and now costs +1.67 s.** The
surface is monotonic in both variables and increases smoothly with angle rather
than stepping at a threshold, which is the "continuous rather than categorical"
requirement. The 45° column is the one that shows it is not a reversal special
case: it crosses from a small credit at 1.5 m/s to a real charge at 6.0, because
the lateral share of the momentum grows with speed while the forward share stays
useful.

Ordering holds in every row: `toward < stationary < perpendicular < strongly
away`. No evidence-backed exception was found, so none is documented.

## C2.4 Validation

| control | result |
|---|---|
| **C0 exit-state contract** | **26 of 29 rows agree at 0.000**; the same three truncated rows, unchanged |
| **P15 playback corrections** | **0 of 8,380 drawn legs, worst 0.0000** |
| 700-rally balance | see below |

**The contract row is the one that mattered most.** Charging arrest in the closed
form alone would have re-opened the C0 split, because `project_toward` was
agreeing with the *free-reversal* closed form. Both now call the same
`arrest_terms`, and the probe says they still land together everywhere they did
before.

**Balance moved, and it moved toward the gates rather than away.**

| figure | C1 | C2 | band |
|---|---:|---:|---|
| contacts per rally | 4.593 | 4.663 | — |
| **kill rate** | 0.537 | **0.519** | 0.45–0.50 |
| dig rate | 0.510 | 0.528 | 0.35–0.55 ✓ |
| stuff rate | 0.099 | 0.104 | 0.08–0.14 ✓ |
| block touch | 0.794 | 0.800 | — |
| swing balance | 0.950 | 0.964 | near 1.00 |
| ace | 0.099 | 0.099 | 0.05–0.09 ✗ |
| serve error | 0.194 | 0.194 | 0.12–0.20 ✓ |

Kill rate is **still outside its band** and this is not a claim to have fixed it.
It is the closest it has been in this pass — 0.535 at the audit's A0, 0.537 after
C1 — and it moved without anything being tuned toward it, which is the only kind
of movement worth anything. Swing balance likewise recovered toward 1.00 rather
than continuing away from it, reversing the drift C1 recorded as an observation.

Ace remains outside at 0.099, untouched by all of C0–C2, and is
`BACKLOG.md`'s existing item rather than this pass's.

The mechanism is worth one line, because the direction is initially
counter-intuitive: charging reversal slows *everyone*, including hitters carrying
speed into an approach, so attacks arrive marginally worse-timed (attack quality
0.474 → 0.470) and more balls come up (dig 0.510 → 0.528). Fewer kills is the
consequence of a worse attack, not of a better defence.

**One judgement call, flagged as one.** The turn delay is no longer charged on
top of an arrest, on the reasoning that a body which had to shed momentum has
already been billed for the redirection and charging both prices one direction
change twice. That is an argument, not a measurement. The alternative — both
charged — would make every off-axis entry more expensive again, and nothing in
the repo settles which is right.

## C2.5 The suite found a third traversal formula

The suite came back **3 of 2,279** — a genuine regression, and the third failure
was `"Allotted duration and the movement model agree for every phase type"`.

`MovementTimingRatioCalibration` divides a modelled traversal by the window the
resolver *allotted* that contact. After C2:

| family | before | after C2 | band |
|---|---:|---:|---|
| RECEPTION | — | 0.9974 | 0.95–1.06 ✓ |
| ATTACK | — | 1.0453 | 0.95–1.12 ✓ |
| DIG | — | 0.9988 | 0.95–1.06 ✓ |
| **SET** | 0.8344 | **1.3656** | 0.80–1.06 ✗ |
| overall mean | — | 1.0753 | 0.97–1.04 ✗ |

**Two wrong diagnoses first, both rejected by measurement.**

1. *Stale momentum.* `live_velocities` keeps a value until overwritten and C1.7
   showed most boundaries do not adjoin, so a body could be charged to arrest a
   velocity it shed seconds ago. A decay at the body's own deceleration rate
   made SET **worse**, 1.366 → 1.510 — because most carried momentum is *aligned*
   and helping, so decaying it removed a credit. Reverted.
2. *The setter-choice estimator.* `_spatial_setter_choice` sizes a window with
   `_movement_time` and passed no entry velocity. Wiring it through produced a
   **byte-identical** probe, because that arm is the legacy one — its own comment
   says so — and production takes the `physical_choice` path.

**The real cause is a third copy of the traversal model.**
`RallyMovementSystem.estimate_movement` prices the *window* a contact is
allotted, `_leg_seconds` prices the *leg* the body walks, and they are separate
code. C2 gave `_leg_seconds` an arrest cost and this copy did not get one, so a
window was sized from a body that turns for free while the leg was charged for
turning.

The function's own comment had already warned about this:

> Restating the speed curve, mass penalty, facing fit, and turn cost here is how
> this function and `_movement_profile()` drifted apart in the first place — the
> copy had to be found and patched separately every time the model changed.

It drifted again, on exactly the term C2 added, and the suite caught it.

`estimate_movement` now calls the same `arrest_terms`, adds `ground_lost` to the
distance it prices, and applies the same rule about not charging a turn on top of
an arrest. Three consumers, one model.

| figure | after C2 | after C2.5 | band |
|---|---:|---:|---|
| **SET** | 1.3656 | **0.8846** | 0.80–1.06 ✓ |
| overall mean | 1.0753 | **0.9923** | 0.97–1.04 ✓ |
| perceptible rate | 0.0471 | **0.0109** | < 0.07 ✓ |
| ATTACK | 1.0453 | 1.0436 | ✓ |
| RECEPTION / DIG / COVERAGE | — | 0.9974 / 0.9988 / 0.9943 | ✓ |

Every band passes, and the overall agreement is **better than it was before C2**
— 0.9923 against 1.0753, with the perceptible rate down four-fold. Consolidating
the third copy improved a number C2 had not set out to touch.

**Balance after the consolidation**, against C2 alone: contacts 4.663 → 4.630,
kill 0.519 → 0.524, dig 0.528 → 0.522, stuff 0.104 → 0.108, block touch 0.800,
ace 0.099 and serve error 0.194 unchanged. P15 clean at **0 of 8,368**. Kill
remains outside its band and below the 0.535 the audit recorded at A0.

## C2.6 Validation

| control | result |
|---|---|
| **full suite** | **2 of 2,271**, the two known failures, the third gone |
| timing-ratio gate | all five families inside their bands |
| **P15 playback corrections** | **0 of 8,368, worst 0.0000** |
| C0 exit-state contract | 26 of 29 rows at 0.000, unchanged |
| 700-rally balance | every gated band holds; kill and ace outside where they already were |

**Three checks written and the count fell by one, which is the third distinct
reading this pass has produced from the same number.** 2,272 was measured at
`721af16`. C2 authored three checks
(`_test_reversal_costs_more_than_standing_still`), so a sampling-neutral pass
would have shown 2,275; it shows 2,271, meaning **four sampling gates drew fewer
checks** because rallies now resolve differently.

Read the three together, because they are the whole argument for not trusting
this number on its own:

| pass | written | delta | what it means |
|---|---:|---:|---|
| C0 | 3 | +3 | entirely authorship — yet the population *did* move, invisibly |
| C1 | 0 | +2 | entirely population |
| C2 | 3 | **−1** | population moved *against* authorship, by four checks |

Same instrument, three passes, three unrelated meanings. Only the FAIL line and
the probes carry information about correctness.

---

# C3 — Supply meaningful facing

## C3.0 What the model does with facing today

`_movement_profile` derives one number from it:

```gdscript
var facing_fit := 1.0
if actor.facing.length_squared() > 0.001 and direction.length_squared() > 0.001:
    facing_fit = clampf((actor.facing.normalized().dot(direction) + 1.0) * 0.5, 0.0, 1.0)
```

and `facing_fit` then sets `direction_change_delay` through
`LocomotionModel.direction_change_seconds`, between a 0.20 s worst case and a
0.02 s best.

**The default is 1.0, which means perfectly aligned — the cheapest possible
turn.** So an absent facing is not neutral; it is a discount. Every committed
site passes `Vector2.ZERO`, so every body in the game has been turning at its
floor cost.

The audit measured the size: 0.14–0.17 s per leg.

## C3.1 C2 narrowed where this matters, and sharpened it

Before C2, the turn delay was charged whenever `opening_speed <= 0.0` — which
after C0's fix meant any body without forward momentum, including one moving
sideways or backwards. C2 replaced that: a body with momentum to shed pays
`arrest_terms`, and the turn delay is charged only to a body with **nothing to
arrest and nothing to carry** — one genuinely at rest.

That is the physically right place for it, and it means C3's population is
exactly the standing bodies. For them the question is real and unanswered: a
defender standing in base facing the net, told to move to their left, should pay
more than one already facing that way.

## C3.2 The authoritative facing already exists

Three things make this the same shape as C1 rather than a new model:

- `RallyMovementPath.facings` records a facing per sample, so a leg's exit facing
  is `facings[last]` — already published, already authoritative.
- `_committed_path` and `_travel` both take `entry_facing` and set
  `actor.facing` from it. The plumbing is there; nothing supplies it.
- `player_facing` exists as a store and is written by `_commit_facing` at
  **two** sites, both hitter paths, from `exit_velocity.normalized()`.

So C3 is: publish `exit_facing` from `_travel_intent` beside `exit_velocity`,
carry it in a `live_facings` store alongside `live_velocities`, and pass it as
`entry_facing`. `_record_exit_velocity`'s rule applies unchanged — a leg with no
published path states nothing about facing either.

One detail that keeps it honest: `RallyPlayerState.apply_position` already sets
`facing = velocity.normalized()` for a moving body, so facing and travel heading
are coupled while moving and only diverge at rest. That is the distinction the
spec asks to preserve — travel heading versus body facing — and it is already
modelled, so C3 must not flatten it.

## C3.3 Wired, and measured

Two steps, the first required to change nothing:

1. **Plumbing.** `_movement_time`, `_reached_point` and `_travel_intent` take an
   `entry_facing` and forward it; `_travel_intent` publishes `exit_facing` from
   the path's own last facing sample. Balance byte-identical to C2.5 on all
   nineteen figures.
2. **Carry.** `live_facings` / `opponent_live_facings` beside the velocity
   stores, threaded through all five phase-map sites, recorded by
   `_record_exit_facing` under the same rule as velocity — a leg with no
   published path states nothing about orientation either.

**It reaches the window as well as the leg, deliberately.** All three traversal
formulas read `actor.facing`: `estimate_movement` prices the window,
`_leg_seconds` prices the leg, `project_toward` steps it. C2.5 is what happens
when a locomotion term reaches some of those and not the others, so `entry_facing`
was plumbed into `_movement_time` at the same time as `_committed_path`.

| measure | before | after |
|---|---:|---:|
| **legs beginning with an entry facing** | **0 of 5,800** | **527 of 5,775** |
| P15 corrections | 0 of 8,368 | **0 of 8,368** |
| timing-ratio gate | all bands | all bands, byte-identical |
| balance | — | contacts 4.630→4.631, dig 0.522→0.521, home dig 0.568→0.565; nothing else moved |

**`facing_fit` is causal and therefore stays.** The spec's requirement 5 offers
removal as the alternative if the model proves invalid; it does not, so it is
made causal instead.

**The effect is far smaller than the audit's 0.14–0.17 s per leg, and the reason
is C2.** The turn delay is now charged only to a body with nothing to arrest and
nothing to carry. A body that carries momentum pays `arrest_terms` instead, and
its facing is already aligned with its travel by `apply_position`. So facing bites
only on genuinely stationary bodies, which is the physically right population and
a much smaller one than the audit measured against the old free-reversal model.

**The timing-ratio probe cannot see this change, and that is the probe's
limitation rather than evidence of nothing happening.**
`MovementTimingRatioCalibration` sets `actor.facing = opening.normalized()` before
measuring — it deliberately aligns the body — so a facing change is invisible to
it by construction. Its byte-identical result is consistent with the repair and
says nothing about it either way. The balance probe is what moved.

**527 of 5,775 is the ceiling this mechanism can reach, not a shortfall.** Facing
can only be supplied where a prior leg published one, and it is supplied on
exactly the boundaries where momentum is — a leg that publishes a path yields
both, a leg that publishes none yields neither. The remaining 5,248 are the same
publication-coverage gap C1.7 measured from the other direction.

---

# C4 — Six-player traffic, re-measured after C0–C3

The spec forbids choosing a teammate-routing fix from the stale baseline, so this
is the first look at the population since the audit. Same instrument, same seeds,
600 rallies.

| measure | audit baseline | after C0–C3 |
|---|---:|---:|
| pair observations | 403,710 | 393,892 |
| minimum separation | 0.000 m | 0.000 m |
| p01 | 0.580 | **0.644** |
| p05 | 1.324 | **1.468** |
| p50 | 4.046 | **4.175** |
| **pair-samples inside 0.50 m** | 3,142 (0.778%) | **2,611 (0.663%)** |
| court-seconds inside 0.50 m | 125.7 s | **104.4 s** |
| 3+ clusters at 0.50 m | 32 | **26** |
| inside 0.72 m | 6,056 | **4,720** |
| inside 0.90 m | 10,360 | **8,121** |
| both moving | 90.9% | 87.9% |

**Traffic fell by roughly a fifth with no avoidance of any kind added.** The
relative rate inside 0.50 m is down 15%, the 0.72 m and 0.90 m populations by
22%, and every percentile of separation improved. Fixing *when* bodies arrive
moved *where* they are, which is the ordering the spec insisted on and the reason
it forbade choosing a fix from the old numbers.

The stratification also moved, and not uniformly: `DIG|opponent` fell 599 → 352
and `BLOCK|home` 463 → 341, while `RECEPTION|opponent` rose 786 → 955. The
reception phase is now the clear single concentration rather than one of three.

**The decision the spec asks for: teammate semantics are still required.**
Minimum separation is still 0.000 m, 2,611 pair-samples and 104 court-seconds
remain inside 0.50 m, and 26 instants still put three bodies there. Momentum and
reversal were worth a fifth of the problem and are not the whole of it. That is a
follow-up spec against *this* population, not this pass — and no generic
collision, bounce, slide or avoidance was added here.

---

# C5 — Net-plane traversal, diagnosed and repaired

## C5.1 The discriminating question

The audit recorded 1,669 samples past the net plane, ~2.6% of every body-instant,
and could not say why. The candidates the spec lists are tactical target,
waypoint, contact/body offset, integrator/clamp, or coordinate transform — and
they split cleanly on one question: **is the leg's committed landing already
across, or does a body drift across during a leg that ends legally?**

The instrument now answers it per sample, and names the publishing cue.

| | count |
|---|---:|
| **committed landing already across** | **1,666** |
| landing legal, body drifted | 28 |
| no leg covering the sample | 0 |
| **offending cue** | **`phase_intent/blocking`, 1,666 of 1,666** |

98.3% were *sent*. The integrator and the clamp are exonerated — they walked
bodies faithfully to targets that were already wrong — and every single one came
from one cue.

## C5.2 The cause is a coordinate frame

`_block_formation` builds the **opponent's** wall and reads:

```gdscript
var start: Vector2 = CourtConstants.slot_position(slot_number)
```

`slot_position` answers in **home** coordinates. Every front-row blocker on the
far side was therefore given a pull position on the near side of the net, and
`_setter_read_phase` published it as a `blocking` intent for the body to walk to.

That is C5's "coordinate transform" candidate, and it explains the shape of the
audit's finding better than any routing theory: the worst cases were always
opponent players, the rate was stable across sample sizes because it is
systematic rather than seeded, and it is one cue rather than a spread.

`CourtConstants.mirror_to_opponent` already existed. The repair is one call.

## C5.3 Measured

| measure | before | after |
|---|---:|---:|
| **samples past the net plane** | **1,694** | **28** |
| share of all body-instants | 2.6% | **0.043%** |
| committed landing already across | 1,666 | **0** |
| worst incursion | 0.97 m | 0.81 m |
| P15 corrections | 0 of 8,368 | **0 of 8,238** |

Balance: contacts 4.631 → 4.636, kill 0.524 → 0.527, dig 0.521 → 0.519, stuff
0.108 → 0.104, swing balance 0.948 → **0.954**. Every gated band holds.

**The 28 that remain are the other class**, and they are left rather than
clamped. Their legs end legally and the body crosses in between — which is either
interpolation across a leg whose endpoints straddle the plane, or genuine
overshoot. The spec is explicit that legal off-court pursuit must not be clamped,
and a body near the net is the case where a blanket clamp would do the most
damage. 28 samples in 65,036 is recorded, not chased.

---

# Final state, against the spec's DONE criteria

| # | criterion | where | state |
|---|---|---|---|
| 1 | one internally consistent exit-velocity contract | C0.4, C0.6 | 26 of 29 probe rows at 0.000; the 3 are truncated legs, by contract |
| 2 | all production exit-velocity consumers receive it | C0.5 | five enumerated and validated |
| 3 | ordinary legs inherit prior velocity | C1.4–C1.8 | 527–773 of ~5,800 boundaries, from 0 |
| 4 | reversal/braking physically causal | C2.3 | 6 m/s away: 0 s → +1.67 s; ordering holds at every speed |
| 5 | facing reaches the solve, or the model is removed | C3.3 | causal, therefore kept; 527 of 5,775 legs |
| 6 | continuity measured and remainder classified | C1.5, C1.7 | 796 intentional, 3,797 with a named source; the gap metric split |
| 7 | no P15 regression | every checkpoint | **0 corrections throughout**, worst 0.0000 |
| 8 | determinism, suite, balance, comparable performance | below | recorded |
| 9 | A6 re-measured only after C0–C3 | C4 | traffic down ~20%; fix deferred to a new spec |
| 10 | net-plane cause and narrow repair or scoped follow-up | C5 | frame defect, one-call repair, 1,694 → 28 |
| 11 | no scheduler, generic navigation/collision, body-state penalty, perception rewrite or animation workaround | — | none added |

## Criterion 8, in full

| control | result |
|---|---|
| **full suite** | **2 of 2,274**, the two failures older than this branch, no third |
| determinism | 700-rally probe byte-identical across two consecutive runs |
| P15 | 0 corrections of 8,238 drawn legs |
| **resolve cost** | **109 ms median** (114.0 / 105.5 / 109.2) against **117 ms** (117.3 / 116.4 / 121.7) at `4e2c42d` |

**The resolve-cost comparison is the one kind that is allowed.** Same instrument
(`tools/probe_resolve_cost.gd`), same hardware, same session as the baseline it
is compared against — which is exactly what the contract's 62.8 ms figure could
not offer. The two three-run ranges do not overlap, so the ~7% improvement is
probably real; it is three runs a side and should be read as "not slower" rather
than as a performance result. Nothing in this pass was aimed at speed.

**Suite delta: three checks gained, none written.** 2,271 at `bc0f178`, and C3
and C5 authored no test, so the whole delta is sampling gates drawing against a
changed population — the fourth distinct reading this number has produced in five
passes. It is a combined C3+C5 figure rather than two attributable ones, because
a suite running against the C3 tree was killed when C5 changed production
underneath it; the two are separately validated by their own probes.

## What this pass did not fix, stated plainly

- **217 adjacent discontinuities** (C1.7/C1.8) — bodies whose legs adjoin within
  0.10 s and whose endpoints disagree by more than 10 cm, the worst implying
  79 m/s. Older than this pass; its *rate* improved, 32.0% → 28.0% of adjoining
  boundaries, but nothing repaired it.
- **Teammate occupancy is still not a route constraint** (C4). Minimum separation
  is still 0.000 m. The population is a fifth smaller and is the right baseline
  for the follow-up spec.
- **28 net-plane samples** of the drift class (C5.3), deliberately not clamped.
- **Kill rate 0.527 and ace 0.099** remain outside their bands. Both were outside
  at the audit's A0 (0.535, 0.099); kill is lower than it was and neither was
  tuned.
- **`estimate_movement` is still a third copy of the traversal model** (C2.5). It
  now agrees with the other two about arrest, but the duplication that let them
  diverge is intact.

---

# C6 — The adjacent discontinuities, classified and mostly repaired

The 217 were recorded and not chased. `tools/audit_adjacent_discontinuity.gd`
classifies every one by publisher pair, cue pair, action pair, side and implied
speed, and separates the two things the spec asks to be told apart.

**Baseline at `86e95ae`, 600 rallies from seed 61000: 241 of 785 adjoining
boundaries.** (The 217 in C1.8 is the same defect at a different sample; this
instrument and this seed base are both ends of every figure below.)

The separation is not close. **238 of 241 imply 12 m/s or more** — median
175 m/s, maximum 4,224 m/s — and 117 sit at *exactly zero interval*. Three imply
a speed a body could reach. So this is 238 simulation contradictions and 3
legitimate fast joins, not a population of debatable cases.

## C6.1 The serve walk-in committed an intention

Both serve sites committed the intended base while publishing a path the serve
flight can cut short: **62 of 200 walk-ins landed up to 1.585 m from the point
the resolver then recorded.** The next leg for that body began at the recorded
point, which the body had never reached.

This is exactly the defect P15 fixed across the phase maps, at the two sites
that are not phase maps. The walk is solved before the event, and the landing is
what `live` and `movement_target` get.

**241 → 186**, and `movement_path -> phase_intent[defending]` (56, all
SERVE → RECEPTION) went to zero.

## C6.2 An interval leg was stamped with the wrong clock

`_phase_hold_paths` describes the interval **since** the last contact and was
stamping it `rally_clock` — *now* — so it ran forward into the next event's
window instead of backward over the one it describes. Legs published on three
consecutive events shared a start time and overlapped.

The instrument was hiding the damage rather than reporting it: overlapping pairs
are skipped as "two publishers describing one window", so a leg pointing the
wrong way in time was excluded from the adjacency test that should have caught
it. With honest stamps the adjoining population rose 785 → 865 and the
discontinuities it exposed rose with it.

`_time_at_last_contact` is a new field beside `_positions_at_last_contact`:
where the bodies were, and now when. The hold leg is stamped there, and its
budget is the interval rather than a duration guessed from its own distance.

## C6.3 Two legs for one interval

With honest stamps the double-description became visible. The phase maps run
while the metadata is built and write `live` as they go; `_phase_hold_paths`
runs afterwards inside `_add_event`. A body with a stated intent on an event was
getting **two** legs for one interval — the intent's, from where it started, and
a hold over the same interval ending where the intent left it. Those adjoin and
disagree by the whole journey.

`_phase_hold_paths` now takes the ids this event's own phase intents already
speak for and skips them. A stated journey wins; the hold fills silence.

**397 → 144** with the stamp fix in place.

## C6.4 Three more sites committing the closed form

`_establish_shape` (both sides) and `_setter_read_phase` published
`targets = reached` — `_reached_point`'s closed-form answer — while the leg they
published landed where the stepped integrator got. Swept to `reached_position`,
the same repair P15 made everywhere else.

## C6.5 Result, and the two repairs held back

| measure | `86e95ae` | after C6 |
|---|---:|---:|
| adjoining boundaries | 785 | 865 |
| **adjacent discontinuities > 10 cm** | **241 (30.7%)** | **144 (16.6%)** |
| implying >= 12 m/s | 238 | 142 |
| at exactly zero interval | 117 | **1** |
| median implied speed | 175 m/s | 87.5 m/s |
| **P15 corrections** | **0 of 8,368** | **0 of 8,555** |

Balance, 700 rallies: contacts 4.636 → 4.633, kill 0.527 → 0.525, dig 0.519 →
0.521, block touch 0.800 → 0.798, stuff unchanged. Every gated band as before.
Two probe runs byte-identical. Suite 2 of 2,274, the two known failures.

**Two further repairs are correct and are not shipped, because each breaks the
P15 zero-correction invariant.** Both are recorded with their measured cost
rather than forced through:

1. **The actor's leg ends at the contact, so the next should start there.**
   `_positions_at_last_contact` snapshots `live`, which for the body that just
   played the ball is wherever the resolver put them *afterwards*. Recording the
   contact instead is worth **122 discontinuities** and costs **24 P15
   corrections**, all on the POINT event, all the server, 0.15–0.22 court units.
   The cause is that the serve's own walk-in never reaches playback: nothing
   precedes the first contact, so the leg has no window to be drawn in, and the
   server's body is only reconciled at the end of the rally.

2. **`_setter_read_phase` should commit the wall pull it publishes.** It states
   a journey and leaves `live` alone — the C5a violation. Committing it costs
   **294 P15 corrections**, because a downstream site reads a stale origin for
   the same blockers. Those two are one knot and want one repair, not two.

## C6.6 The remaining 144

| cue pair | n |
|---|---:|
| `phase_intent[defending] -> phase_intent[blocking]` | 78 |
| `movement_path -> phase_intent[preparing_attack]` | 18 |
| `phase_hold -> phase_intent[covering]` | 18 |
| `phase_intent[defending] -> phase_intent[preparing_attack]` | 14 |
| everything else | 16 |

The first is the knot above, traced: between the DIG and the following SET,
`live` for a home blocker moves from the dig shape to the setter-pull origin
with no leg describing it, and `_setter_read_phase` then reads that origin as
where the body is. Worst case seed 61223, player 2: the dig leg ends at
(0.306, 0.720) and the blocking leg starts at (0.519, 0.667), 5.70 m away.

---

# C7 — The setter pull was a silent write

`_form_home_block` drifts an undisciplined blocker toward the setter
(`pull_weight = (1 - discipline) * 0.18`) and wrote the result straight into
`live_positions` with no leg. It is real behaviour and it stays; what changes is
that it is now described like every other movement — one `_travel_intent`, the
leg's own landing committed, exit velocity and facing recorded, and the journeys
merged onto the opponent set event the wall is reading.

Coverage improves and the adjacent count does not move (144), because the pair
this was suspected of causing is not it. P15 stays at 0 of 8,543. Suite 2 of
2,270. Balance: contacts 4.633 → 4.591, kill 0.525 → 0.527, dig 0.521 → 0.517,
block touch 0.798 → 0.791, every gated band holding.

**A repair attempted and reverted, recorded because it was nearly kept.** The
two writes at the block contest restate `home_wall_positions` over the landing
the wall close had already committed, which looked like the cause of the worst
case. Guarding them changed nothing measurable — `live_positions` always has an
entry, so the guard never fires — which means the wall position reaching
`_setter_read_phase` comes from somewhere else and the guard was a change with no
attributable effect. Reverted rather than left in.

---

# C8 — `estimate_movement` no longer restates the traversal

C2.5 made the third copy *agree* about arrest. It was still a copy: the same
accelerate-then-cruise quadratic written out inline beside
`_accelerated_seconds`, which `_leg_seconds` calls.

It now calls `_accelerated_seconds` too, opening from `arrest_terms.opening_speed`
rather than the raw directional component — so the window and the leg share the
arithmetic *and* the state they start from.

| figure | C2.5 | C8 | band |
|---|---:|---:|---|
| overall mean ratio | 0.9923 | **0.9925** | 0.97–1.04 ✓ |
| SET | 0.8846 | 0.8830 | 0.80–1.06 ✓ |
| RECEPTION / DIG / ATTACK | 0.9974 / 0.9988 / 1.0436 | 0.9974 / 0.9991 / 1.0444 | ✓ |
| perceptible rate | 0.0109 | 0.0109 | < 0.07 ✓ |

The numbers barely move, which is the point: the duplication is gone without
changing what the model says, so the *next* change to locomotion cannot reach one
copy and miss the other. That was the failure mode C2.5 documented and this
removes its cause.

---

# C9 — The spatial census, before anything is built

The spec forbids adding a teammate spatial system before characterising what
already exists. Three findings.

## C9.1 There is no engine-level collision anywhere

```
grep -rl "CollisionShape|CollisionObject|Area2D|Area3D|RigidBody|CharacterBody|
          StaticBody|PhysicsBody|move_and_slide|move_and_collide|
          intersect_ray|intersect_shape"  --include=*.gd --include=*.tscn
  -> no matches
grep -rl "collision_layer|collision_mask" --include=*.tscn  -> no matches
```

**Zero.** No physics bodies, no areas, no layers, no sweeps, in production or in
any dead path. Every spatial fact in this game is simulation arithmetic. There is
nothing engine-side to reuse, repair or connect, and nothing to accidentally
double up on.

## C9.2 A teammate avoidance mechanism already exists and is production-causal

`RallySimulator._navigation_waypoint` is a real, volleyball-shaped avoidance:

| property | value |
|---|---|
| clearance | `OBSTRUCTION_CLEARANCE_M = 0.715 m` |
| grounded bodies | `× OBSTRUCTION_GROUNDED_BERTH = 1.6` — a voli on the floor cannot step aside, so the mover does all the avoiding |
| per-mover scale | `_berth_scale(mover, other)`, from the mover's own settledness |
| geometry | closest point on the segment, corner pushed out by the shortfall |
| ties | the path's own normal, so it stays deterministic |
| published | `obstructed_by`, `obstruction_position`, `obstruction_shortfall_meters` |
| consumed | `_movement_time` stages the corner and carries speed through it |

It is not a generic separation force, it does not bounce or slide, and it already
does the two things a volleyball avoidance must: it bends a *route* rather than
displacing a body, and it gives a grounded teammate a wider berth.

## C9.3 It has two call sites

`_spatial_setter_choice` (`:12726`) and the opponent setter release (`:4585`).
**Both are setter chases.** Twenty-plus other route producers — every phase map,
every wall close, every coverage and defensive shape — never consult it.

So the mechanism is not missing, it is *unconnected*. Against the spec's
question — reuse, repair, connect, replace or leave alone — the evidence says
**connect**, and says explicitly that a new collision system is not required.

## C9.4 The population it would act on, re-measured after C6–C8

| measure | C4 baseline | after C6–C8 |
|---|---:|---:|
| pair observations | 393,892 | 385,145 |
| minimum separation | 0.000 m | 0.000 m |
| p01 / p05 / p50 | 0.644 / 1.468 / 4.175 | 0.616 / 1.457 / 4.154 |
| pair-samples inside 0.50 m | 2,611 | 2,712 |
| court-seconds inside 0.50 m | 104.4 | 108.5 |
| 3+ clusters at 0.50 m | 26 | 22 |
| both moving | 87.9% | **88.5%** |

Continuity work moved this by nothing, which is itself the finding: C4's ~20%
improvement came from fixing *arrival times*, and that source is now exhausted.
The concentration is `RECEPTION|opponent` (921 of 2,712) and `DIG|opponent`
(463), and 88.5% of it is two moving bodies — converging traffic, not two parked
volis overlapping.

**163 samples are both-parked**, and those are the ones that cannot be defended
as volleyball: two stationary bodies inside half a metre is a formation defect,
not traffic.

---

# C10 — Net-plane crossings, classified

All 28 survive C6–C8 unchanged, and the classification is unchanged with them:

| | count |
|---|---:|
| committed landing already across | **0** |
| landing legal, body drifted across | **28** |
| no leg covering the sample | 0 |

Worst 0.81 m, seed 61345, player 3, home. C5's systematic cause — the opponent
wall built in home coordinates — is gone and stayed gone; what remains is
entirely the drift class, where a leg's endpoints both sit legally and the
interpolated body passes the plane between them.

That is a **legitimate discontinuity of the model, not a contradiction**: the
path is a sampled traversal between two legal points, and no resolver statement
disagrees with any other. Clamping it is what the spec forbids, and a body near
the net is where a blanket clamp would do most damage. 28 samples in 65,036 —
0.043% — recorded and left.
