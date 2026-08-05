# Tempo, set height, and the hitter's approach

Status: **Links 1-2 hold and are gated. Link 3 is measured: the deficit is real, small
and tempo-ordered, which is what step 4 needs to be worth building.** No structural fix
is outstanding — the one I thought I had found is withdrawn below, with the measurement
that disproves it.

## The chain

> **A higher set takes longer to arrive, so the hitter has longer to get there,
> so everyone else has longer too.**

Today tempo is a label on a set that changes the attacker's quality and the
block's difficulty by table. It does not change how long anything *takes*. That
is the whole defect: tempo is the game's main lever on time, and it is currently
the one thing about it that is not time.

The chain, in the order the causes actually run:

1. **Tempo sets the set's peak height.** A third-tempo ball is thrown high; a
   first-tempo ball is flat and fast off the setter's hands.
2. **Height sets the flight time.** This part already exists --
   `RallyKinematics.solve_launch_arc` and `ball_flight_model.gd` both solve real
   arcs, and the set's `duration` is already a computed number rather than a
   constant.
3. **Flight time is the hitter's budget.** From the moment the set leaves the
   setter, the attacker has exactly that long to reach the start of their
   approach and run it.
4. **The same budget is everyone else's.** The block gets that long to read,
   move and set their hands. The floor defence gets that long to finish
   positioning. These are not separate timers to calibrate -- they are the same
   number seen from three sides.

## The hitter's budget, precisely

Two quantities, both already tracked:

- **Required** -- `RallyMovementSystem.traversal_seconds()` from where the
  attacker actually is to the start of their ideal approach, plus the approach
  run itself. The first term is why *where they were standing* matters and not
  only who they are.
- **Available** -- the set's flight time, from `set_contact_time` to the
  attacker's contact.

Three outcomes, and they are the point:

| case | what happens |
| --- | --- |
| available ≥ required | **Full approach.** The hitter reaches the ideal start at ordinary speed and runs a proper approach. No sliding, no teleport. |
| available < required | **Compromise.** One of two, and the hitter chooses. |

The two compromises are not the same, and a hitter with a different temperament
should pick differently:

- **Abandon the ideal angle.** Take a shorter, worse-angled run from wherever
  they are. They arrive on time and hit from a bearing that costs them.
- **Leave early.** Start moving before the set is up, which buys the distance
  and **tells the block where the ball is going.** The read model already
  supports a blocker seeing more than they should; this is the thing it should
  be seeing.

**A third-tempo ball should always afford the full approach.** That is close to
its definition -- it is the safe, slow set, and if it does not guarantee a proper
run-up then nothing in the tempo system means what its name says. A first-tempo
ball to the same hitter from the same spot should routinely force a compromise,
and that asymmetry is what makes tempo a decision rather than a modifier.

## What this fixes that is currently papered over

**Playback sliding is a symptom, not a bug.** Attackers slide into position
because playback is handed an arrival time the movement model cannot meet. Every
fix so far has been at the drawing layer -- interpolating from the visible
position, turning instead of snapping -- and those were right, but the residue
is real: the resolver is asking for arrivals that are not physically available.
Deriving the budget from the set's own flight is what removes the ask.

**Block set time stops being a constant.** It becomes the same number as the
hitter's budget, measured from the other end.

**Tempo gets a cost.** Fast sets currently buy block difficulty for free. Under
this they buy it by spending the hitter's approach, which is a trade a manager
can feel and a tactic that can be wrong.

## Order to build it

1. ~~**Set peak height from tempo**, and let the existing arc solver produce the
   flight time.~~ **Already true**, and now gated. Measured spread below.
2. ~~**Publish the budget**~~ **Done**, as `approach_budget` on the ATTACK event
   (the set event is stamped before the hitter has been staged, so the attack is
   where the approach is described). Two windows, never added — measured below.
2b. ~~**Place the approach mark from the set**, not from the lane.~~ **Withdrawn** —
   it already is. See below; the mark moves about three and a half metres across a
   sample and the walk to it varies by a quarter-second.
3. **Spend it in playback only.** Attacker arrival draws from the budget. If
   sliding disappears at this step, the residue was the ask and not the drawing.
4. **Spend it in the resolver.** A compromised approach costs attack quality; an
   early departure feeds the block's read. This is the step that changes results
   and therefore the one that needs the symmetry suite re-run.

Steps 1 and 2 change no outcomes and are worth doing on their own, because they
turn "tempo should cost time" from an assertion into a number.

## What step 2 measured

`tools/run_approach_budget.gd`, 4 pairings x 90 rallies per tempo, home attacks. **Two
windows, reported separately, because the approach is paid for out of two clocks.**

`ApproachMechanicsSystem.prepare_for_attack()` runs the walk to the approach mark during
`set_contact_time - release_time` — the window between the hitter being released from
their previous duty and the setter touching the ball. That leg is over before the set
goes up. Only the **run-up** competes with the set's flight.

**Run-up, against the set's flight** — the tempo chain's own question:

| tempo | n | flight | run-up | deficit p10 | p50 | p90 | short |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 312 | 0.376 | 0.663 | +0.227 | +0.286 | +0.347 | 100% |
| 2 | 312 | 0.554 | 0.793 | +0.172 | +0.241 | +0.295 | 100% |
| 3 | 312 | 0.806 | 0.937 | +0.025 | +0.144 | +0.209 | **91%** |

**Walk, against the pre-set window:**

| tempo | window | to mark | deficit p50 | short | missed mark |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 2.006 | 0.847 | −1.066 | 0% | 0% |
| 2 | 1.995 | 0.847 | −1.057 | 0% | 0% |
| 3 | 1.986 | 0.847 | −1.049 | 0% | 0% |

**The shape is the design intent.** The deficit halves as tempo slows — +0.286 s at first
tempo to +0.144 s at third — and at third tempo the best tenth of attacks (p10 +0.025 s)
essentially afford the full approach already, which is why 91% rather than 100% are short.
A first-tempo ball to the same hitter from the same spot routinely forces the compromise.
That asymmetry is exactly what makes tempo a decision rather than a modifier, and it is
now a measured quantity.

### Corrected: the first version of this measurement was wrong

It reported a deficit on 100% of attacks at every tempo, roughly 1.0–1.15 s, and concluded
that step 4 must not be built because a branch everybody enters is the model rather than a
compromise. **That was my own tool double-charging the walk**, adding the pre-set leg to
the run-up and comparing the sum against the set's flight alone.

The way it was caught is worth keeping. The same measurement also reported that the
approach model reached its mark on 100% of attacks, and two measures of one event cannot
both be right when they disagree completely. `RallyMovementSystem.project_toward()` reports
`reached_target` from `traveled >= distance`, honestly; it came back true because the walk
genuinely does fit, in 2.0 s of window for 0.847 s of walking. The engine was right and the
instrument was wrong. The two now agree — 0% short on the walk, 0% missed mark — and
agreement between two independent measures is the only reason to trust either.

### Withdrawn: "the approach mark does not move with the ball"

I wrote that here last pass, and it is wrong. The evidence offered was that `to mark`
measures a mean of **0.847 s at every tempo**, from which I concluded that
`approach_start_position()` places the mark from the lane and never reads the set.

It reads the set. The `_lane` argument is unused and named so. The mark is
`target + (outward, depth)` where the outward offset comes from how far off centre the
delivered set is, and `target` is the *delivered* point, scattered ball to ball. Measured
within a single tempo across 312 attacks:

| within one tempo | p10 | p90 | spread |
| --- | ---: | ---: | ---: |
| approach mark x | −0.032 | 0.361 | ~3.5 m |
| delivered set x | 0.038 | 0.374 | tracked over the same range |
| walk to the mark | 0.707 s | 0.981 s | 0.27 s |

The mean is stable across tempos because **tempo changes the arc, not the aim point** —
so a walk time that does not move when only tempo moves is correct behaviour, not a
constant. The question was always the ball-to-ball spread, and I never looked at it.

`_test_the_approach_mark_tracks_the_set()` now pins it: the mark follows the set across
the net and in depth, the lane name does not move it, and each side's mark sits behind
its own net. Kept as a guard, since if the mark ever *did* become a constant nothing else
would notice.

**The lesson, twice in two passes.** Both corrections on this page come from the same
mistake: reading a stable mean as a stable quantity. The double-charged walk looked like a
100% deficit; the tracking mark looked like a fixed offset. It is the same failure as the
thresholds set outside their own distributions that bit four times in the recovery work —
one number where the distribution was the question. When a summary statistic supports a
structural claim, the spread is the thing to check first.

### And no harness had ever measured first or second tempo

With no called play the resolver falls through to `_fallback_assignment`, whose tempo is
hardcoded to 3, and every calibration tool in the repository seeds the vertical slice. The
whole tempo system had been calibrated at one setting; the sweep above had to install a
play per rotation to see the other two, and the first version of it silently did not,
reporting tempo 3 three times. Gated by the second half of
`_test_tempo_buys_flight_time()`.

## Open

- Which compromise a hitter picks. Temperament is the obvious driver and
  `attack_power_model.gd` already models a choice of that shape.
- Whether the opponent's hitters run the same branch. They must, or this becomes
  the fifth thing in this codebase modelled fully on one side of the net and
  approximated on the other.
- Whether an early departure is visible to the block always, or filtered through
  the blocker's own read quality. The second is better and costs nothing extra.
