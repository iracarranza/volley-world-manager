# Geometric attack resolver -- the reasoning behind each constant and branch

Relocated verbatim from `scripts/simulation/geometric_attack_resolver.gd`.
Every comment block of eight lines or more is reproduced here in full and left
in the code as a single NOTE. The shorter blocks -- section markers and one-line
notes on dictionary keys -- stayed where they were, because they are navigation
rather than prose.

Sections are keyed on the declaration or statement the block sat above.

## ``

Gate E. The five Gate B-D models composed into one call the resolver can make.

Everything upstream of this is a pure model that knows nothing about a rally.
This is the seam: one function that takes a hitter, a contact, a block and a
defence, and returns a fully resolved swing -- course chosen, power chosen,
swing delivered, ball flown, outcome read off where it landed.

It exists so that promoting the geometry into `RallySimulator` is *one*
substitution rather than five. The simulator has three attack paths and the
serve has two more; wiring each of them to five models individually is how
three copies of `_attack_execution` happened in the first place.

Deterministic given its draws. Every random input arrives through `draws`,
so a seeded rally replays identically and a caller can hand it fixed values
to test a specific swing.

## `const STRAIN_AVERSION: float = 0.85`

How much a hitter weighs an open lane against the strain of turning to reach
it. Higher and everyone hits where their approach already points; lower and
everyone swings across their body at the biggest gap.

Re-derived in Gate E, because it had to be. While `openness` came out flat
across the whole cone -- block clearance normalised against a 4 m scale for a
quantity that spans 30 cm -- this constant was the *only* term with any range,
so it decided every shot and 91.7% of swings went down the natural line. With
openness spanning -1 to 1 the balance inverted and 89% went to the sharpest
available cut instead.

Derived twice, and the second derivation overturned the first. Three roster
pairings said 1.10; eight say 0.85. Attack error and stuff both move by
several points between those two samples at a *fixed* value of this constant,
which is the whole lesson of `ATTACK_SIDE_SYMMETRY_2026_08_03.md` arriving in
a second place: a figure read off one handful of pairings is a draw from a
wide distribution, not a measurement.

Eight pairings, both serving assignments, all three attack paths pooled:

value | off natural line | attack error | block involvement | stuff
0.85 |            60.4% |        11.7% |             24.7% | 11.7%
1.10 |            37.1% |         9.2% |             27.4% | 13.3%
1.40 |            16.8% |         7.6% |             32.8% | 16.3%

0.85 is the only row with attack error inside the sport's 10-15%, and its
11.7% stuff is the closest any row gets to the 12% target. 1.10 -- the value
three pairings chose -- sits below the error band and overshoots stuff.

Involvement reads lower here than in the per-path tables because this sweep
pools the transition swing, whose block forms off a dig and is genuinely
weaker. Read it as a comparison between rows, not against the 35-45% band.

## `const NET_SPEED_RELIEF_STEPS: int = 6`

How many slower swings a hitter will consider when nothing at full pace gets
over the tape, and how far down they will go.

A hitter who cannot clear the net at full pace takes pace off. That is the one
thing the resolver could not previously do: `_feasible_launch` searched angles
and aim distances at a *fixed* speed, because `choose_power` had already
committed to one without knowing the net existed. From a tight set that never
mattered -- any speed clears from 0.36 m. From four metres back nothing does,
so the search fell through to its `forced` branch and flew the flat ball
anyway: Gate D measured balls into the net climbing 4.7% to 54.5% across the
depth sweep while long, wide and antenna barely moved.

The floor is 0.45 rather than zero because a swing taken at under half pace is
a different shot -- a roll or a tip -- and that decision belongs to the power
model's intent, not to a feasibility search quietly turning a spike into one.

## `const NET_BODY_CLEARANCE_FULL_DEMAND_METERS: float = 0.16`

The body-clearance problem immediately under the tape.

A contact close to the net is not merely an easier, shorter attack. The
hitter has less room to finish the arm, land without crossing, and keep the
torso and trailing hand out of the net. Geometry previously rewarded that
contact twice -- shorter path and a fuller block view -- without charging any
of the control required to avoid a net fault. The band is measured from the
contact to the net plane, in metres; skill and a settled approach mitigate
the spread but never erase the clearance demand entirely.

## `const NET_PATH_STRETCH_CAP: float = 2.0`

The furthest a bearing error is allowed to stretch the path to the tape when
a hitter is budgeting for it, as a multiple of the path they aimed on.

Needed because the stretch is `1 / cos` of the error against the net normal
and runs away without bound as a course approaches parallel with the tape. A
sharp cross-court swing off the pin genuinely does fly a long way before it
crosses, but a hitter does not plan around the degenerate tail of that -- they
plan around a swing that misses by about as much as their swings miss by. Two
is roughly a 60-degree course budgeting for its own worst realistic day.

## `const NET_CLEARANCE_SPREAD_SIGMAS: float = 2.0`

How many standard deviations of vertical execution error a hitter aims to
clear the tape by.

It was one, implicitly, by multiplying the spread by itself once -- and one
sigma is the margin that puts a sixth of your swings in the net on purpose.
That is what the measurement showed: 5th-percentile clearance sat 0.10 m under
a planned 0.15 m margin at 2.50 m off the net, exactly one sigma low, with net
rates of 0.22-0.33 to match. The bearing budget above is worth 1-3 points of
that; this is worth the rest.

Two rather than three because the relief search below has to be able to find
the bar. A margin nothing can clear does not stop a hitter swinging -- it drops
them through to `forced` and flies the same flat ball with no plan at all,
which is how the previous attempt at this moved the 4.00 m net rate by a point
and a half in the wrong direction.

## `const NET_CLEARANCE_FLOOR_METERS: float = 0.03`

The least air a hitter will accept over the tape when the margin they wanted
is not on offer.

`NET_CLEARANCE_MARGIN_METERS` and the sigma budget above are what a hitter
*aims* for. This is the tape. They were the same branch: the search looked for
the margin, and anything that missed it fell through to `forced` and flew a
ball with no plan behind it -- including balls that cleared the net by twenty
centimetres and merely missed the preference. Measured, `forced` was 0.15 of
swings at 2.50 m off the net and 0.36 at 4.00 m, and it netted 86-95% of them,
which made it 64% and 77% of all net errors at those depths. The netted balls
averaged +0.04 standard deviations of vertical error -- they were not misses,
they were plans into the tape.

A preference you cannot afford is a preference you drop. A net you cannot
clear is a different problem, and only that one is allowed to force a swing.

## `const NET_SHORTFALL_FLOOR: float = 0.25`

How much of the air between a hitter's contact point and the tape may be spent
on safety margin, leaving the rest for the ball to fall through.

The bound that was missing, and the one that made every other number here
misbehave. A swing cannot arrive at the net higher than it left the hand --
only a lofted ball does that, and it is a different shot. So the margin a
hitter asks for is capped by the headroom they actually have, which for a
2.91 m reach is 2.81 m of contact against a 2.43 m tape: 0.38 m, all in.

Unbounded, the distance-scaled margin computed to 0.27 m at 2.50 m off the net
and 0.43 m at 4.00 m. The second is more headroom than exists. The search was
asking for a ball that cannot be struck, failing to find one, and dropping
through to `forced` -- which is why `forced` ran 0.14 and 0.34 of swings at
those depths while relieving the pace all the way to 20% of full moved it by
nothing at all. It was never a pace problem. It was a request for altitude
nobody had.

Half, because the remainder has to cover the ball falling on the way: about
0.06 m over 2.7 m and 0.15 m over 4.3 m at a driven pace.
How short a hitter will settle for when they cannot carry the ball to where
they aimed, as a fraction of the distance they wanted.

A quarter, because past that it is not the same shot -- a ball dropped at a
third of its intended distance is a tip, and tips are chosen by the power
model's intent rather than arrived at by a feasibility search.

## `const SERVE_SPREAD_MULTIPLIER: float = 0.70`

How much of a spike's execution spread a serve carries.

A serve is struck from a standstill, off a self-toss, with no set to read and
no block to beat -- the one contact in the sport a player rehearses in
isolation. It should not scatter like a swing taken off a bad set with hands
in the way.

It matters more here than anywhere else because a serve has to be launched
*upward*: from a 2.6 m contact a flat ball is 1.5 m high at the net, so the
driven root cannot clear the tape and every serve takes the lofted one. On
the lofted branch range is steeply sensitive to launch angle, so vertical
error turns directly into balls long. Swept on live rallies, 360 serves each,
measured on both sides of the net:

value | serve error, home | opponent | combined
1.00 |             32.8% |    32.2% |    32.5%
0.70 |             15.6% |    10.6% |    13.1%
0.45 |              3.9% |     0.0% |     1.9%

The response is steeply nonlinear because the lofted branch amplifies angle
error into range error. 0.70 lands inside the sport's 8-15%; 0.45 produces a
serve that essentially cannot miss.

## `const SERVE_PACE_RELIEF_STEPS: int = 8`

How far a server may come off full pace to get the ball over the tape, and in
how many steps. The same shape as the swing's own relief sweep and for the
same reason: a server who cannot clear the net at full pace does not serve
through it, they take something off.

**These four lived in `rally_simulator._serve_arc` and have been moved here
whole.** They were the working half of the old inverse solve -- the half that
priced arc and pace together and picked the quickest ball that cleared -- and
the audit in `docs/design/CONTACT_AND_BALL_FLIGHT.md` kept them on purpose.
What was wrong was never the sweep; it was that the sweep was aimed at a
landing point an RNG draw had already decided on.

## ``

The fourth was a flat `SERVE_NET_CLEARANCE_METERS = 0.12`, and it is gone.

`_feasible_launch` had already found that exact constant to be "a constant
standing where a function belongs" and replaced it, for the swing, with the
margin the shot's own vertical spread demands -- because execution error
arrives at the tape as `ground_to_net * tan(error)`, which is centimetres from
a tight set and a third of a metre from four metres back. **A serve is struck
nine metres back**: the same geometry, at its extreme.

The old sweep did not notice, and could not: it solved toward a landing point
that had already been decided, with no execution error applied afterwards, so
the margin never had to cover anything. Pointing the same sweep forward is
what exposed it -- measured, the median serve cleared by 0.071 m against a
planned 0.12, and 90% of the resulting errors were into the tape.

So there is no serve clearance constant any more. There is one clearance
*rule*, `NET_CLEARANCE_MARGIN_METERS` floored and `NET_CLEARANCE_SPREAD_SIGMAS`
budgeted, and both contacts obey it.

## `var commitment_share := AttackReadModel.commitment_share(approach_quality)`

**The wall as it was when the choice was made, not as it finished.**

`blockers` carries the close already multiplied into every half width, so
handing it straight to perception showed the hitter a block that had not
formed yet -- they picked their shot against the future. The contest below
still resolves against the finished wall; only the choosing sees the
earlier one, which is the whole of the difference between beating a block
and swinging into one that was still shutting.

How much of the close they get to see is bought by the approach, not by
their reading: a hitter who timed their run has the air time to keep
looking, and one still adjusting their feet to reach the ball spends part
of that window doing it.

## `var swing_spread := float(cost.spread_multiplier) \`

**How much air this swing has, once commitment is paid for.**

`cost.spread_multiplier` is the across-body strain of the *course* -- how
turned the hitter had to be. It says nothing about how hard they then
decided to swing, so a full-commitment hammer and a controlled roll off the
same approach were judged by identical accuracy, and the bench's
decisiveness instruction reached the ball as speed and nothing else.

Combined rather than replaced: they are two independent ways to lose a
swing, and a hitter turned back across themselves *and* swinging at their
ceiling should pay for both. Placed here, above every consumer, because the
last three of these went in below one of theirs.

## `* AttackSwingModel.block_spread_multiplier(`

**And the wall, which until now reached the swing through nothing.**

The reported defect: hitters swinging out at an open net while the
blockers stand there not jumping, because they already know it is
going out. A miss with nobody in front of you is an unforced error and
should be rare; a miss is what pressure produces. Measured over 600
rallies, the rate was no lower against nothing than against two, which
is what a cone with no block term in it has to produce.

Read off the **actual** wall rather than `perceived_blockers`. What a
hitter believes decides which course they pick -- that is the read
model's job, above -- but what they have to hit over is whatever is
really there. A hitter who misread the block does not get an easier
swing for having been wrong; they get a worse outcome, which is the
point.

## `var gravity_mps2 := BallFlightModel.DEFAULT_GRAVITY_MPS2`

--- the angle that puts that speed where it was aimed -------------------

Constrained by the tape. Nothing above this point knows the net exists:
the course scan reads the block and the floor, and the power model reads
the distance, so a hitter could pick a short cut shot whose driven
solution is a 53-degree dive into the net and swing at it. Measured in
shadow on live rallies that was 24% of swings -- the resolution layer
dutifully reported "net" for a choice the decision layer should never have
offered. A hitter knows where the tape is.

## `"block_jump_timing": _wall_jump_timing(blockers),`

**When the wall jumped**, taken off the actual blockers rather than off
the contact.

Read from `blockers` and not from `resolution.block`, because a wall that
never touched the ball still left the floor -- keying this off the
contact would give playback a jump for the blocks that connected and
nothing for the ones that were beaten, which are exactly the jumps whose
timing is worth seeing.

## `"block_contact_actor_id": int(Dictionary(`

**Which hand met the ball, and how high it was when they met it.**

`_block_contact` proves both -- it is a ball-by-body intersection, not a
quality comparison -- and both were consumed inside it. The consequence
was not that the proof was missing but that nothing downstream could
quote it: the BLOCK event named the formation's *primary* blocker and
placed the contact at the hitter's own contact x, because those were the
only two facts that survived this seam.

The centrality note inside `_block_contact` is the reason the id matters
rather than being cosmetic: 32% of two-blocker contacts were credited to
a less central hand than the ball met, which that function fixed for its
own bands and could not fix for the event.

## `static func resolve_serve(`

One serve, start to finish.

A serve is the same ball as a spike and a different decision. There is no
approach, so no natural line and no repertoire cone -- a server picks a spot
and hits it. There is no block, so the only things between contact and the
floor are the tape and the lines. What is shared is everything that matters:
the same flight solver, the same net-clearance constraint, the same execution
channels, and the same resolution that reads the outcome off where the ball
landed rather than off a quality scalar.

Sharing them is the point. Serves were hardcoded in or out -- a serve that
visibly stayed inside the court could be scored an error -- because the serve
path derived its own trajectory and then decided the outcome separately. Two
descriptions of one ball will always drift apart; there is now one.

## `static func _serve_launch(`

The ball this server actually chooses to hit, at the target they aimed at.

**Production's sweep, kept whole and pointed forward.** It used to run in
`rally_simulator._serve_arc` against a landing point that a serve-error coin
flip had already moved, so it was solving "what launch puts the ball where the
verdict says it went". Nothing about the search was wrong -- it prices arc and
pace together, insists on the tape, and prefers the quickest ball rather than
the first one found. What was wrong was the question. Here it is asked of the
*aim*, and the landing is left to the physics.

Two things are swept because the answer is a combination and picking either
half first throws the other away: how much pace the server keeps, and how much
they brush the ball. Topspin buys the dive that lets a hard serve drop inside
the endline and pays for it in range, so a server's full spin applied to every
serve puts the far court out of reach entirely.

The candidate kept is the one with the greatest horizontal ground speed,
because what a receiver is given is *time*, and minimising the flight is
therefore what a server is trying to do.

## `_power_shortfall_scale: float,`

**The fraction of intended pace one sigma of power shortfall removes, and
it is deliberately not used.**

The serve's dominant net-error channel is power, not angle -- measured, a
power-shortfall draw past one sigma put 0.81 of live serves into the tape
against 0.16 for an equally bad vertical draw. Budgeting the clearance
against it at the same two sigma the angle already gets was tried, both by
adding the two shortfalls and by combining them in quadrature as the
independent draws they are. Both work, and both cost too much: the net rate
went to 0.001-0.007, and the live serve became a **2.8 second lob** at 66
degrees with nine metres of clearance and no aces at all.

The reason is the distance. Height at the tape carries a gravity drop going
as `1/v^2`; from nine metres behind the endline two sigma of pace is worth
over two metres of height, against half a metre for two sigma of angle. A
serve that insures against its own mishit at the rate an angle is insured
stops being a serve.

Making it work needs a *smaller* sigma count for pace than for angle, and
nothing in the model says what that number is. It is a real design
question -- how much pace does a server hold back? -- and inventing a
fourth constant to answer it is what this repository's process rules forbid
a fidelity pass from doing. The parameter stays on the signature so the
quantity is named and reachable when that decision is made.
See `docs/design/CONTACT_AND_BALL_FLIGHT.md`, UNRESOLVED PHYSICS 7.

## `for spin_step in range(SERVE_SPIN_LEVELS):`

A float is struck through the centre with almost no rotation; it does not
buy the Magnus dive that makes a steep topspin launch viable. Above this
angle the authoritative solve produced the visibly rising, punt-like ball
the float report identifies. This is a launch-selection constraint, not a
display curve: candidates still use the shared projectile model and must
clear the same tape.
**Spin outside, pace inside, because the floor of the pace sweep is a
property of the spin.** A ball falling at 25 m/s squared needs more speed
to carry the same distance than one falling at 9.8, so there is no single
slowest serve -- there is one per brush setting, and it has to be solved
before the pace can be swept against it.

## `var reach_floor := float(BallFlightModel.minimum_speed_to_reach(`

**The floor is derived, and it used to be a dial.**

`SERVE_PACE_RELIEF_FLOOR` stopped the sweep at 0.55 of full pace
whatever the shot was, and for a strong float server nothing inside
that bound clears: measured, the driven root's height at the tape
climbed 1.447 -> 2.674 m as pace came off and was *still* short of the
2.877 m needed when the sweep ran out. The search then fell to the
lofted root and served a 68 degree ball with 10.1 m of clearance and a
2.98 s flight -- a punt, on 6.5% of live serves, and worse for a better
server, because technique purifies a float and removes the topspin that
would have let it dive.

`_quickest_clearing_loft` had already written down the answer, about
its own floor, forty lines away: *"The floor is a derived quantity, not
a dial. Below the minimum speed for the range nothing reaches at any
angle, and at it the two roots merge."* That is the honest bottom of a
pace sweep -- past it there is no serve to find, and short of it there
are serves being refused for no physical reason.

## `static func _feasible_launch(`

The steepest ball this hitter can actually hit, at the speed they chose.

For a fixed speed, a longer target range means a flatter driven solution and
therefore more height at the net. So the search is monotone: start at the
distance the hitter aimed for, and if that ball is in the tape, push the
target deeper until it clears. That is what a hitter does -- a ball they
cannot cut sharp gets hit deeper, not into the net.

Three outcomes, in the order a hitter would take them:

driven   the intended ball clears, or clears once pushed deeper
lofted   nothing driven clears, so the ball goes *over* rather than through
-- the roll shot a hitter takes off a set that is too tight
forced   neither clears at this speed. The swing happens anyway and will
very likely be in the net, which is correct: a hitter under a bad
set does hit the tape. This is the only path that should produce a
net error, and it should be rare.

## `gravity_mps2: float = BallFlightModel.DEFAULT_GRAVITY_MPS2,`

**The gravity this ball actually flies under.**

The search solved every candidate at 9.8 while the drawing flew the chosen
one at up to 26, so the launch certified over the tape and the launch drawn
were different balls. On a spike that is a small inconsistency; on a serve
it is the whole feature, because a topspin serve exists precisely to be
launched steeper than a flat ball could afford and still land inside the
endline. Solving it flat means the search never sees the shot the spin
makes possible, and settles for a lob instead.

## `var aimed_to_net := _ground_distance_to_net(`

The path the hitter aimed on, and the longer one a bearing error puts them
on -- and it is the longer one every check below is made against.

The vertical budget alone was measured holding at a tight set and failing
everywhere else: net errors ran 0.000-0.073 at 0.36 m, 0.147-0.253 at
1.20 m and 0.233-0.367 at 2.50 m, with 5th-percentile clearance falling
from 0.112 m (sitting right on the flat margin, exactly as designed) to
0.038 m. A margin that grows with distance was being computed on a distance
the ball did not fly. Horizontal error lengthens the path, the ball has to
stay in the air over the extra ground, and nothing budgeted for it -- the
netted balls off the pin flew 3.70 m to the tape against 3.25 m for the
ones that cleared.

## `var wanted := maxf(`

How much air *this* swing needs, rather than how much air any swing needs.

The margin was a flat `NET_CLEARANCE_MARGIN_METERS` whatever the distance to
the tape, which is a constant standing where a function belongs. Vertical
execution error arrives at the net as `ground_to_net * tan(error)`, so one
degree costs half a centimetre from a tight set and seven centimetres from
four metres back, where the spread runs to 0.35 m against a 0.12 m margin.
Aiming to clear by 12 cm from there is aiming to miss.

It travels with the speed relief below and not on its own. Measured alone it
moved the 4.00 m net rate by a point and a half, because a higher bar with no
way to hit softer only sends more solves down the `forced` branch.

## `var fallback_height := -INF`

The least-bad swing seen anywhere in the search, kept in case nothing
clears.

The fallback used to be the flattest thing tried -- the driven solve at full
pace, from the first relief step, chosen because it was the first thing
written to `best_driven` and never because it was any good. So a hitter who
could not get the ball over swung the one ball least likely to get over,
and that branch is where the residual net errors live: measured at 2.50 m
off the net, `forced` ran 0.10-0.20 of swings against net rates of
0.16-0.30, tracking it lane for lane.

A hitter who cannot clear the tape still tries to clear the tape. This
keeps the highest ball the search found instead, which is the same swing
they were always going to take, aimed at the problem.

## `var lofted_solve := BallFlightModel.solve_angle_for_range(`

Nothing driven gets over at this pace. Try lifting it instead, before
giving up any more speed -- arc is cheaper than pace.

**But the flattest arc that clears, not the first one found.** There are
only two angles that carry a ball a given range at a given speed, and
the lofted root is the high one -- the faster the swing, the closer that
root sits to vertical. Taking the first loft the sweep meets therefore
took the *steepest* one available, because the sweep starts at full pace.

Measured over 240 attacks: 36 came back lofted, mean apex **9.34 m**,
mean height at the tape 7.82 m. That is not a roll shot, it is a punt,
and the game had been playing them all along -- the drawing re-solved a
driven angle over the top of the record, so a nine-metre lob appeared on
screen as a flat spike. §0 exactly: the branch went unmeasured because
the only instrument pointed at it was reporting a different curve.

`_quickest_clearing_loft` takes pace off *within* this decision instead,
which walks the lofted root down toward 45 degrees where the arc is
shallowest. The order of preference is untouched: a driven ball first, a
roll shot before another notch of relief. Deferring the whole loft to
the end of the sweep was tried and is worse -- a slower driven root is
a higher one, so it swallowed every roll shot in the game and the lofted
branch went to zero of 232. One dead branch traded for another.

## `return _quickest_clearing_loft(`

**Down to the least force that reaches, not to a fraction of
full pace.** `NET_SPEED_RELIEF_FLOOR` is 0.45, and from a tight
set that still leaves 11 m/s trying to land 7 m away -- which
only a near-vertical arc does, so the search kept returning one:
the median roll shot came out at 76 degrees and 2.5 s of hang
time. The floor is a derived quantity, not a dial. Below the
minimum speed for the range nothing reaches at any angle, and at
it the two roots merge, which is the shallowest and quickest arc
the shot has.

## `if fallback_height == -INF:`

Nothing above was even solvable: this hitter cannot carry the ball to where
they aimed at the pace they chose, so every probe came back with a negative
discriminant and the search never evaluated a real trajectory.

The sweep above only ever probes *longer* and only ever relieves speed
*downward*, and both are the wrong direction for this failure -- which is
why relieving all the way to 20% of full pace moved it by nothing. The
failure grows with depth because every target is further away from four
metres back than from thirty-six centimetres: `unsolved` ran 0.06 of swings
at 0.36 m and 0.15 at 4.00 m, and it put the ball in the net 100% of the
time from 1.20 m out, making it the single largest source of net errors at
every depth past the tightest.

A hitter who cannot drive it that far hits it shorter. The ball goes over
and lands in front of the defence, which is a weak attack -- and a weak
attack is a thing this game can already resolve. A ball into the tape is
not what happens when someone is asked for more than they have.

Shortening on its own is not the answer, and measuring it said so: it
cleared `unsolved` to zero but the shortened balls still netted 0.65 at
2.50 m and 0.85 at 4.00 m, because a driven solve onto a *nearer* target is
a steeper solve, and steeper from four metres back is further into the
tape. The shortened candidates have to face the same clearance test as
every other candidate, and they have to be allowed to arc -- lifting it is
the whole point of giving up the distance.

## `static func _quickest_clearing_loft(`

The quickest roll shot that still gets over, at or below this pace.

A hitter who has decided to lift the ball has one dial left: how hard. For a
fixed range there are only two angles that carry the ball, the lofted root is
the high one, and softening the swing walks it down toward 45 degrees.

**The objective is hang time, not steepness, and getting that wrong is
instructive.** The first version searched for the flattest clearing loft, on
the reasoning that a flatter arc is a better shot. It is not, on its own: a
flat lob is slow, and flight time is `range / (speed * cos(angle))`, so giving
up pace to flatten can easily *lengthen* the flight. Measured at each attempt
on the same population:

full pace, steepest root      apex 9.34 m
flattest clearing loft        median flight 2.367 s, p90 3.018
bounded to 80% of pace        median flight 3.165 s, p90 3.797

All three are the same mistake -- optimising a proxy. What the defence
actually gets from a roll shot is *time*, and what a hitter is trying to deny
them is time, so the thing to minimise is the flight itself. Horizontal speed
is that, exactly and directly, and it prices the arc and the pace together
instead of trading one for the other blind.

`steepest_angle` is the loft already known to clear at `from_speed`, returned
unchanged when nothing softer beats it. This can only improve on it.

## `static func _wall_seal(blockers: Array) -> float:`

How closed the wall is, 0 to 1.

Measured where a seam exists: the widest gap between neighbouring blockers'
spans, against a body's width. Spans that touch or overlap read as sealed; a
gap you could stand in reads as split.

A wall of one has no seam, so it is sealed by definition. That is not a
generosity -- what a single blocker lacks is *size*, and the size term
already charges for it. Folding "there is only one of them" into the seal as
well would be the same fact billed twice.
