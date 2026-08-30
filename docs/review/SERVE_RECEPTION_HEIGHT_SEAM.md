# The reception is played 2.79 m above the ball

The visual report on the three Q1 vignettes was three separate complaints: the
serve reception happens far above the ground, it bumps *down* to the setter, and
the serve flight itself is wrong. They are one defect, it is in the simulation
rather than the playback, and `tools/probe_serve_receive_chain.gd` prints it in
nine lines.

## What the record says

```
SERVE      actor=105  t=0.000  source=start_resolved
    published: 2.29 m -> 1.00 m over 0.822 s, apex rise 0.817
    launch:    v=5.86 m/s -> apex rise 1.753, end 3.79 m
    own gravity: 21.009 m/s2 (default 9.800) -> apex rise 0.817, end -0.00 m
    realised end height read by the next contact: 3.79 m
RECEPTION  actor=6    t=0.822  source=resolved
    published: 3.79 m -> 2.23 m over 1.040 s, apex rise 0.658
    own gravity: 9.800 m/s2 -> apex rise 0.658, end 2.23 m
```

`good_ball_high` and `good_ball_back` are the same shape with 2.96 m instead of
2.79 m. All three answers, one defect.

**The serve's own record is not wrong.** Read with the gravity it publishes it
is exact to three decimals: apex rise 0.817 against a published 0.817, and an
endpoint of −0.00 m, which is the floor and is where a served ball that lands in
ends up. Nothing in `geometric_attack_resolver` needs changing.

**The reader is wrong, twice.** `RallySimulator.realised_flight_end_height`
integrates `launch_vertical_mps` across the flight using
`BallFlightModel.DEFAULT_GRAVITY_MPS2`, and the serve flies under 21.009 m/s²
-- a topspin serve's effective gravity, published as `launch_gravity_mps2` in
the same dictionary, one key away from the velocity being read. Substituting
9.800 for 21.009 turns a ball at the floor into a ball at 3.79 m. That is the
whole of "the reception is happening far above the ground", and it is
§0 of `FAILURE_MODES.md` in its plainest form: a value measured with the wrong
instrument.

The second error survives fixing the first. Even integrated correctly, the
number asked for is the height at the flight's **end**, and the serve's
published duration runs to its landing point on the floor. The reception does
not happen at the end of the serve; it happens partway through it. The right
question is the height at the interception time, and no caller asks it.

So the fix is not "use the published gravity" -- that alone moves the reception
from 3.79 m to the floor, where `PlatformContactModel` refuses the contact
outright and the vignettes lose their reception entirely. The incoming leg has
to be **sliced at the contact**, which is what §5's `incoming.end ≡ C` has always
said and what the serve is the one family still not doing.

## Why the other two complaints are the same one

The drawn ball follows the trajectory's `start_height_meters` and
`end_height_meters`: 2.29 m down to 1.00 m, and the 1.00 is
`BallTrajectory.create`'s default, because the serve deliberately publishes
`end_height = NAN` (the ruling at `rally_simulator.gd:1406`). The receiver's
*outgoing* flight starts at 3.79 m. Same contact, two heights, 2.79 m apart --
so the drawn ball jumps up at the moment of contact and then descends 3.79 →
2.23 m to the setter. "Bumping down" is not a bad pass; it is a good pass
launched from a height nobody could reach.

And the pass covers 2.55 m at 2.4 m/s where a serve-receive pass is 4-5 m, which
is the "reaches the setter too quickly" -- a downstream consequence of the
receiver having been placed against a ball that was, by the record, already on
the floor.

## What this says about the vignettes as instruments

`VIGNETTES_AS_DIAGNOSTICS.md` argued the value is in defects visible only by
comparison. This one is not: it is visible in a single still, to an eye that
knows what a serve receive looks like, and it survived 2,178 checks because no
check compares a flight's published apex against its own published launch.
The vignette did not find it -- a person watching the vignette did. That is a
different and cheaper mechanism than the situation grid, and worth naming
separately: the grid finds what a person would have to tabulate, and the
vignette finds what a person only has to *see*.
