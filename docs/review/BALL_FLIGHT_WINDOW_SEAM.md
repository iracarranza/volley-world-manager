# The attack's ball is drawn four times too fast, and the repair exists twice

Found while asking a different question -- why a spike does not read as an
impact. Measured at `543826d` by `tools/run_ball_window_probe.gd`, 60 rallies,
seeds 61000-61059.

## The same defect shape as the movement pass, on the ball

Nine commits of the movement-contract work went into one shape: a journey's own
duration and the window it is drawn in disagreeing, so a body is drawn at a pace
nothing authorised. The ball has it too, and worse.

| flight from | n | flight s | window s | flight/window | window shorter | window longer | worst gap |
|---|---:|---:|---:|---:|---:|---:|---:|
| SERVE | 60 | 1.180 | 1.180 | **1.00** | 0 | 0 | 0.000 |
| SET | 48 | 1.104 | 1.104 | **1.00** | 0 | 0 | 0.000 |
| BLOCK | 10 | 0.574 | 0.574 | **1.00** | 0 | 0 | 0.000 |
| **ATTACK** | 44 | 0.553 | **0.243** | **4.00** | **27** | 3 | **1.050** |
| RECEPTION | 48 | 0.892 | 1.021 | 0.88 | 0 | 19 | 0.505 |
| DIG | 11 | 1.069 | 1.359 | 0.80 | 0 | 9 | 0.454 |
| ATTACK_COVERAGE | 2 | 0.703 | 1.137 | 0.62 | 0 | 2 | 0.496 |

**The serve, the set and the block are exact.** Not approximately -- 1.00 with a
worst gap of 0.000 across every sample. Whatever else is wrong with playback,
those three flights are drawn on their own clocks.

**The attack is asked to complete a half-second flight in a quarter-second**, on
27 of 44 swings, with a worst case of 1.050 s. The ball must be drawn at four
times its published speed or jump to keep up. Either way what a viewer sees is
not the flight the resolver resolved.

## Why, and it is one `if`

`rally_simulator.gd:3021` already re-slices the attack to the net crossing:

```gdscript
if block_contacts_ball:
    var attack_to_block_arc := _truncated_arc(...)
    attack_event.metadata["outgoing_trajectory"] = _ball_trajectory(
        "attack_to_block", set_target, net_contact, ...
```

Its own comment says exactly the right thing -- *"same shot as
`attack_trajectory` above, re-sliced to where it actually crosses the net rather
than where it was originally headed"*.

**When the block does not touch the ball, that slice does not happen.** The
BLOCK event is still stamped at the net crossing -- deliberately, by
`_stamp_physical_times:12466`, which says *"the ball passed the hands rather than
meeting them, so its moment is the net crossing of the swing it failed to
intercept"* -- while the attack goes on publishing its full flight to the floor.
One launch, two endpoints, one window.

`DIG_BUDGET_AND_WINDOW.md` measured the untouched block at **159 of 175** dig
pairs, which is the right order of magnitude for the 27 of 44 here.

## The third instance of a repair already made twice

- The **serve** got it: `FreeFlightInterceptionModel.realised_prefix` at
  `:1197` and `:4015`, and the serve now measures 1.00 with a 0.000 worst gap.
  That is `BACKLOG.md`'s "slice the serve's incoming leg at the reception
  contact", closed.
- The **touched block** got it: `_truncated_arc` at `:3021`.
- The **untouched block** did not.

So this needs no new machinery and no new model. It needs the existing slice
moved outside its `if`, with the endpoint taken from the same net crossing
`_stamp_physical_times` already derives for the BLOCK's own timestamp -- which
is what guarantees the two agree rather than merely being close.

## The opposite sign, on the other three families

RECEPTION, DIG and ATTACK_COVERAGE all run the other way: 19 of 48 receptions
and 9 of 11 digs have a window **longer** than the flight, so the ball arrives
and then waits. Worst gap 0.505 s on a reception. That is very likely
`BACKLOG.md`'s *"the quick vignette's drawn ball is 0.22 s late to its
reception"* seen at scale, and it is a different defect from the attack's --
under-run rather than over-run -- so it wants its own diagnosis rather than
being folded in here.

## What this probably explains, and what it does not

It is a strong candidate for why a spike does not read as an impact. A ball
drawn at four times its own speed across a fraction of its arc reads as a smear
or a pop, not as a struck ball following a line -- and it is worst exactly where
a viewer would most expect to see a clean one, on a hard swing that beats the
block untouched.

**Two things this does not establish.** Sixty rallies is a small sample, and the
tails should be read as indicative. And the probe measures the *record*: it does
not trace whether `match_screen` resolves the mismatch by compressing the flight
or by jumping to the endpoint. Both are wrong, but which one decides what is
actually on screen, and that wants a rendered frame rather than a number.
