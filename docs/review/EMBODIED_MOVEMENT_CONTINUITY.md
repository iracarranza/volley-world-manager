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
