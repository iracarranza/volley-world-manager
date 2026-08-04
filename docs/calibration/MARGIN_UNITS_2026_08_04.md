# Two margins, one name

A `margin` in this engine means one of two things, and until now both were
called `arrival_margin`.

`CoverageCalculator.evaluate_arrival` reports `physical_reach - distance`: how
much further a player could have reached than the ball needed them to. That is
**metres**. The continuous reception and block systems report
`true_arrival_margin`: how many seconds a player had to spare. That is
**seconds**. They were handed to the same consumers under the same key.

## What it cost

**A rollout stopped being neutral.** `LiveReceptionIntegrator.apply` emitted its
seconds value as `arrival["arrival_margin"]`, which
`rally_simulator.gd` reads as `margin * 0.07` clamped to `[-0.16, 0.12]` -- a
scale fitted against metres. Half a second to spare is about a metre of ground,
worth the full `+0.12`; passed raw it is `0.035`. So the same receiver, in the
same position, scored roughly a tenth of a quality point lower when the
continuous reception path was promoted than when it was not, on a boundary whose
whole purpose is to leave the outcome alone. `AttackRolloutAudit` did the same
thing with the same key.

**A constant was chosen for the wrong quantity.** `_defense_execution` weighed
its input against `DIG_LATE_ARRIVAL_SECONDS = 0.45` and every production caller
was already feeding it metres. As a lateness scale 0.45s is reasonable. As a
reach scale 0.45m is very tight, and the term it gates,
`(margin + 0.45) / 0.45` clamped to `[0, 1]`, saturates at any non-negative
margin and bottoms out half a metre short. Measured on live rallies the home
defender sits at +1.03m -- saturated -- and the opponent at -0.05m, which scores
0.89. A term meant to price arrival is very nearly a step function, and it
barely separates a defender who is comfortably there from one who is not.

That second cost is the more interesting one, because the model was never
wrong -- it was consistently metres everywhere. Only the names were wrong, and
names are what a constant gets chosen against.

## What this gate changed

- `evaluate_arrival` returns `reach_margin_meters`. The key `arrival_margin` no
  longer exists on a coverage arrival, so nothing can read one by habit.
- `DIG_LATE_ARRIVAL_SECONDS` is `DIG_REACH_MARGIN_METERS`, and
  `_defense_execution`'s parameter is `reach_margin_meters`.
- `LiveReceptionIntegrator` and `AttackRolloutAudit` emit
  `arrival_margin_seconds`. The simulator converts once, explicitly, through
  `CoverageCalculator.reach_margin_from_seconds`, which uses the same movement
  speed and acceleration factor `evaluate_arrival` uses to turn available time
  into covered ground. One bridge, in one place.
- Defence events carry `reach_margin_meters` in their metadata rather than
  sharing `arrival_margin` with the attack events, which carry a hitter's or
  setter's margin in seconds. `_movement_audit` was taking a `min` across both.

## What it deliberately did not change

`DIG_REACH_MARGIN_METERS` keeps its value of 0.45. Re-scaling it is the obvious
next move and it is not this gate's: it moves every dig rate in the engine on
both sides of the net, and it needs the dig calibration sweep to choose a value
rather than a plausible-sounding one. What this gate guarantees is that the
sweep will be fitting a constant to the quantity it actually gates.
