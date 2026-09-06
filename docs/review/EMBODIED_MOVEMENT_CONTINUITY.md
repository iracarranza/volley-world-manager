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
| regression added | `_test_leg_exit_velocity_is_one_number` |

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
