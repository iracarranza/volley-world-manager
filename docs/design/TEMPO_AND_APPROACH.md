# Tempo, set height, and the hitter's approach

Status: **Specified, not built.** Nothing below is implemented. It is written
down because it is one causal chain rather than four features, and building any
link of it alone produces a version the others have to be bent around.

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

1. **Set peak height from tempo**, and let the existing arc solver produce the
   flight time. Measurable immediately: the spread of set durations by tempo
   should widen from nearly nothing.
2. **Publish the budget** on the set event -- available seconds -- without using
   it. Compare against `traversal_seconds()` to the ideal approach start and log
   the deficit distribution. This is the measurement that says whether the
   compromise branch will ever fire, before any behaviour depends on it.
3. **Spend it in playback only.** Attacker arrival draws from the budget. If
   sliding disappears at this step, the residue was the ask and not the drawing.
4. **Spend it in the resolver.** A compromised approach costs attack quality; an
   early departure feeds the block's read. This is the step that changes results
   and therefore the one that needs the symmetry suite re-run.

Steps 1 and 2 change no outcomes and are worth doing on their own, because they
turn "tempo should cost time" from an assertion into a number.

## Open

- Which compromise a hitter picks. Temperament is the obvious driver and
  `attack_power_model.gd` already models a choice of that shape.
- Whether the opponent's hitters run the same branch. They must, or this becomes
  the fifth thing in this codebase modelled fully on one side of the net and
  approximated on the other.
- Whether an early departure is visible to the block always, or filtered through
  the blocker's own read quality. The second is better and costs nothing extra.
