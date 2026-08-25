# The serve arrives steeply, and the drawing is not why

A user report against the M8/§5 build: *"incorrect-looking serve trajectory with
ball teleporting down onto hitter instead of actually landing on hitter."*

The seams measure zero. So did the horizontal chain, once it was measured. What
is left is the arc between them, and this records where it comes from.

## A hypothesis stated to the user, and refuted

The first explanation offered was that `terminate_trajectory` cuts a flight's
position and duration and `display_trajectory` then re-solves a fresh parabola
from the shortened endpoints, losing the launch the ball actually left with.

That is wrong, and it was refuted by the cheapest possible measurement --
comparing each serve leg's published `launch_vertical_mps` against
`BallFlightModel.rise_speed_between(start, end, duration)`, which is the rise the
drawn curve actually uses:

```
serve legs 68 | truncated 0 | duration != physical 0
mean |drawn rise - published launch| = 0.000 m/s, worst 0.000
```

Zero truncated legs, so the mechanism named was not running at all; and a mean
disagreement of 0.000 m/s, so the launch is not lost. **The drawing is faithful
to the flight.** Hand-checked on one leg: the resolver's own launch integrates to
an apex of 6.11 m and the drawn curve apexes at 6.12 m.

Recorded because the retraction is the useful part. A plausible mechanism, named
before it was measured, would have sent the repair into `BallPresentation` --
where nothing is wrong, and where any change would have been fitting a curve to
a complaint.

## What the horizontal chain says, and a second instrument error

Every leg's drawn endpoint against the next contact's start, over 120 rallies:

```
ATTACK -> BLOCK [home] attack                25   25 breaks   mean 5.171   worst 10.041
ATTACK -> BLOCK [home] attack_to_block       26    0 breaks   mean 0.000
ATTACK -> BLOCK [opponent] attack            24   24 breaks   mean 5.374   worst  8.558
ATTACK -> BLOCK [opponent] attack_to_block   23    0 breaks   mean 0.000
DIG -> SET, RECEPTION -> SET, SERVE -> RECEPTION, SET -> ATTACK, BLOCK -> *
                                            all    0 breaks   mean 0.000
```

The 49 breaking legs are the blocks that never touched the ball:
`block_contact_kind` is empty on every one of them, the swing correctly keeps its
full arc, and the block is drawn at the net while the ball flies past it to the
floor. That is `BLOCK_REALISED_CONTACT.md`'s proven exception, not a seam.

The instrument said otherwise twice before it said this. First it read
`display["end"]`, and the key is `end_position`, so every row was the fallback
and the split was invisible. Then the "did this contact publish a ball" filter
used `metadata.has("outgoing_trajectory")` -- and a beaten block publishes the
key holding an **empty dictionary**, so the filter passed everything and the
correct exception looked like a defect on all 49. B0's test has to be *is the
trajectory non-empty*, not *is the key present*.

**The horizontal chain is clean.** Nothing teleports sideways.

## What is actually steep

`tools/_servechk` walks the shipped `BallPresentation.display_trajectory` at the
cadence `MatchCourt3D` samples it, over 120 serves:

```
launch mode      n   mean s   max s   mean m/s   min m/s   mean apex   max apex
driven         118    1.308   1.835      12.58      6.52        3.85       6.12
lofted           2    2.446   2.523       6.34      6.25        9.83      10.37
```

A serve contacted at 2.60 m and drawn apexing at a mean of 3.85 m, a driven
maximum of 6.12 m, and two punts over ten metres in the air. Flight times to
1.835 s driven and 2.523 s lofted. A ball that spends that long climbing has to
come down steeply, and that is the reported symptom exactly.

Two separable causes, and they are worth very different amounts.

### 1. The drawn leg ends at a height its own duration does not reach

`_canonical_serve` takes the flight's duration as
`distance(contact, landing) / horizontal_speed`, where `landing` is where the
resolver's flight reaches **the floor**. At that moment the ball is at 0 m. The
drawn leg is then made to end at the *receiver's contact height* -- a mean of
0.617 m -- over that same duration, so `rise_speed_between` hands the curve more
rise than the flight ever had:

```
drawn apex - apex of the same leg ending on the floor:
  mean 0.230 m, worst 1.214 m, over 120 legs
```

This is not a bug to be fixed in the drawing. It is
`CONTACT_AND_BALL_FLIGHT.md`'s **unresolved item 5**, which `_ball_trajectory`'s
own comment already names: `end_height_meters` is read by
`BallFlight.from_trajectory` as the height of the *next contact*, while the
serve's flight solves to the floor, and those are different numbers. The serve
publishes `end_height = NAN` (`height_source == "start_resolved"`) precisely
because the question is open.

Resolving it toward the physics means the reception happens *before* the floor
landing -- earlier in time and shorter in ground -- which moves the reception
point, which moves the reception claim. That is a simulation change, not a
drawing change, and it is why the item is reserved. What is new here is that the
reserved item now has a measured, user-visible cost: 0.230 m of mean apex and
1.214 m at worst.

### 2. The serve is delivered near the slowest ball that reaches at all

`GeometricAttackResolver._serve_launch` sweeps pace downward from what the server
can generate to `BallFlightModel.minimum_speed_to_reach` -- the maximum-range
launch, which is by construction the slowest and highest arc that carries to the
aim -- and keeps the fastest candidate clearing the tape by the margin its own
execution spread demands. `tools/probe_serve_pace_relief.gd`, 240 serves, both
sides:

```
mode       n   mean full   mean flr   mean got     mean frac   at floor   mean clear
driven   237       29.55      11.54      13.80   0.126-0.357         16         0.73
lofted     3       29.55      11.50      13.64   0.119-0.328          0         6.68
```

`frac` is where in its own stated range the knob settled, given as an interval
because the tactical risk each serve was struck at is not published: the low end
assumes full drive intent, the high end full control intent. The truth is inside
it, and all of it is low. **Between 64% and 87% of the server's available pace is
spent buying net clearance**, and what arrives is 2.26 m/s above a floor that is a
property of the geometry alone and identical for every server on the roster.

The margin is not obviously wrong on its own -- a mean 0.73 m of clearance is at
the top of the real range rather than off it. What is wrong is the *price*: a
serve is struck nine metres behind the tape, so the same
`ground_to_net * tan(2 sigma)` rule that costs a swing centimetres costs a serve
most of its pace. `SERVE_SPREAD_MULTIPLIER`'s own comment measured this geometry
from the other side and the `_power_shortfall_scale` parameter records an
attempt at it that produced "a **2.8 second lob** at 66 degrees with nine metres
of clearance and no aces at all". Three serves in this sample clear by 6.68 m.

The swing has two bounds on the same rule that the serve does not: a `scraped`
tier that drops an unaffordable preference rather than forcing the shot
(`NET_CLEARANCE_FLOOR_METERS`), and a cap on the loft it will accept
(`LOFT_MAX_APEX_RISE_METERS`, *"a roll clears the wall; it is not a lob"*).
Adding the first to the serve changes nothing measurable -- the margin *is* met,
just expensively -- so this is not a missing branch. It is a magnitude.

## What this does not settle

Making the serve flatter and faster is a calibration change on a **gated** band:
serve error currently sits at 0.181 and the sweep in `SERVE_SPREAD_MULTIPLIER`
shows the response is steeply nonlinear, because the lofted branch amplifies
angle error into range error. Nothing here licenses a number, and inventing one
is what this repository's process rules forbid a fidelity pass from doing. The
measurement is the deliverable; the magnitude is a decision.

One thing the probe could not answer: every server in the vertical slice falls in
a single `serve_power` band, so whether the attribute reaches the delivered ball
is untestable on this roster. The probe reports the empty bands rather than
averaging across a population that does not vary.

## Also measured, and not defects

- **Setter desync**: 0 of 217 set contacts more than 0.75 m from the ball, mean
  0.329 m, worst 0.524. The reported symptom is not the setter being
  mispositioned.
- **`SET -> ATTACK`**: 217 legs, 0 falling, all climbing. The set rises to its
  hitter, which is correct, and the arrival-shape probe reports the climbing
  population apart from the falling one so a rising family cannot read as a flat
  one.
- **Serve contact**: 240 of 240 at 0.000 m. The server is exactly where the ball
  leaves from.

The same `has()`-versus-non-empty error described above was in
`probe_drawn_flight_fidelity.gd`'s desync filter and is repaired here. It was
admitting every beaten block -- a contact that is *supposed* to leave the body
away from the ball -- into a measurement of bodies away from the ball. Corrected,
the block row is 1 of 87 apart at a mean of 0.405 m.

## A separate desync worth a look

```
family                n   apart   mean m   worst m
ATTACK_COVERAGE      10       6    1.271     2.325
ATTACK              217      45    0.617     0.899
```

Attack coverage is drawn a mean of 1.27 m from the ball it plays and up to
2.33 m, on 6 of 10 contacts -- small population, but the only family where the
mean itself is outside the tolerance. The attack row's 45 all sit between 0.75
and 0.90 m, which is one arm rather than a gap, against a deliberately tight
0.75 m bar.

## Still open, from the same report

- **First tempo**: T0 measures 0.119 s and T1 0.205 s of set flight, against the
  sport's rough 0.3-0.5 s. A magnitude, separately.
- **`RECEPTION -> SET`**: 150 legs climb and 18 fall, the falling ones at a
  ratio of 26.70 against a true projectile's 3.91 -- the same pathology as the
  serve, on the pass.
