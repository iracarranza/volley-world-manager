# Tempo, set height, and the hitter's approach

Status: **Links 1-2 hold and are now measured and gated. Steps 3-4 are blocked,
and the measurement is what blocks them.** See "What step 2 measured" below before
building anything further — the compromise branch would fire on *every* attack,
which means the ask is wrong rather than the compromise being needed.

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
   where the approach is described). Measured below, and the answer changes what
   steps 3 and 4 should be.
3. **Spend it in playback only.** Attacker arrival draws from the budget. If
   sliding disappears at this step, the residue was the ask and not the drawing.
4. **Spend it in the resolver.** A compromised approach costs attack quality; an
   early departure feeds the block's read. This is the step that changes results
   and therefore the one that needs the symmetry suite re-run.

Steps 1 and 2 change no outcomes and are worth doing on their own, because they
turn "tempo should cost time" from an assertion into a number.

## What step 2 measured

`tools/run_approach_budget.gd`, 4 pairings x 90 rallies per tempo, home attacks:

| tempo | n | flight | to mark | run-up | needed | median deficit | short |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 312 | 0.376 | 0.847 | 0.663 | 1.510 | 1.152 | **100%** |
| 2 | 312 | 0.554 | 0.847 | 0.793 | 1.639 | 1.105 | **100%** |
| 3 | 312 | 0.806 | 0.847 | 0.937 | 1.784 | 1.016 | **100%** |

**Link 1 and 2 were already built.** Tempo drives the set's launch angle (12-18°
at first tempo, 45-55° at third) and the arc solver turns that into a real flight
time, so a third-tempo ball genuinely takes more than twice as long to arrive as a
first-tempo one. Neither link was gated, so nothing stopped a future tuning pass
from flattening the angle table and quietly ending tempo's only connection to
time; `_test_tempo_buys_flight_time()` pins the ordering now.

**Step 4 must not be built yet.** The deficit is positive on 100% of attacks at
every tempo. A compromise branch everybody enters is not a compromise, it is the
model — and the tool says so in its own output. The ask is wrong before the
response is missing.

Three things to fix first, in this order:

1. **The approach model never reports failure.** `reached_ideal_mark` came back
   true on every one of 936 attacks while the deficit was positive on every one of
   them. Two measures of the same event disagreeing completely means one is not
   measuring. That is the first thing to look at, because everything else is
   judged against it.
2. **`to mark` is a constant 0.847 s at every tempo.** The traversal to the ideal
   approach mark does not vary with the ball at all, which is only possible if the
   mark is placed at a fixed offset from the hitter rather than from the set. A
   proper approach start is a function of where the ball is going.
3. **No harness has ever measured first or second tempo.** With no called play the
   resolver falls through to `_fallback_assignment`, whose tempo is hardcoded to 3,
   and every calibration tool in the repository seeds the vertical slice. The whole
   tempo system has been calibrated at one setting; the sweep above had to install
   a play per rotation to see the other two. Gated by the second half of
   `_test_tempo_buys_flight_time()`.

Only once the required side is trustworthy does the available side mean anything,
and only then is the three-way outcome table above a decision rather than a
foregone conclusion.

## Open

- Which compromise a hitter picks. Temperament is the obvious driver and
  `attack_power_model.gd` already models a choice of that shape.
- Whether the opponent's hitters run the same branch. They must, or this becomes
  the fifth thing in this codebase modelled fully on one side of the net and
  approximated on the other.
- Whether an early departure is visible to the block always, or filtered through
  the blocker's own read quality. The second is better and costs nothing extra.
