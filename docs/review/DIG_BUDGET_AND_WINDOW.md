# Repair 2: the dig's budget and its window, and why neither is wrong

`docs/review/MOVEMENT_CONTRACT_GATE.md` recorded a contradiction: 97 of 109 digs
had a `movement_available_seconds` longer than the window playback draws them in,
and named the likely cause as `attack_time` being floored at
`BLOCK_DEFLECTION_MIN_SECONDS` while `physical_time` places the dig at the end of
the deflection flight.

**That was the wrong cause, and measuring it said so in one run.**

## The floor never binds

`tools/run_deflection_budget_probe.gd`, 400 rallies, seeds 61000-61199, 175
BLOCK→DIG pairs:

| | |
|---|---:|
| pairs where `BLOCK_DEFLECTION_MIN_SECONDS` binds | **0** |
| BLOCK events publishing no outgoing flight at all | 159 of 175 |
| shortest published deflection flight | ≥ 0.70 s |

The floor sits at 0.22 s and the distribution it acts on starts at 0.70 s. It is
inert -- which is the §0 failure mode inverted: not a threshold that does nothing
because it is outside its distribution and was believed to be doing something,
but a threshold correctly suspected and then measured before being moved.

## What the overrun actually is

159 of 175 BLOCK events publish no deflection at all -- an untouched block, where
the ball passes the hands. `attack_time` then falls through to the **attack
flight's** duration, and `_stamp_physical_times:12466-12475` stamps that BLOCK at
the swing's **net crossing**, deliberately, because "the ball passed the hands
rather than meeting them, so its moment is the net crossing of the swing it
failed to intercept."

So the budget runs from the hitter's contact and the window runs from the net.
The difference should be exactly the part of the swing spent before the net:

| | |
|---|---:|
| mean budget | 0.6971 s |
| mean window | 0.5102 s |
| pairs with budget > window | 159 of 175 |
| **mean overrun** | **0.2058 s** |
| **mean swing before the net** | **0.2058 s** |

Four decimals, on 159 samples. It is not an approximation of the cause, it is the
cause.

## Neither fact is wrong

A floor defender reads the swing and sets off at the hitter's contact. That is
what the resolver's budget says and it is correct volleyball. The block really
does happen when the ball reaches the tape, and that is what `physical_time` says
and it is correct physics. **The journey simply spans two playback windows**, and
the contract has no way to say so.

This is criterion eight of the gate -- *whether a movement continues across an
intermediate contact* -- arriving with a number attached rather than as a
suspicion. It is the one criterion the gate said genuinely wants a consolidated
record.

## What was deliberately not shipped here

The obvious presentation patch is to tell the leg it is already `0.2058 s` old
when the window opens. It was written, measured against `_plan_fraction`, and
reverted: the fraction is a lerp parameter over the drawn path, so entering the
window at fraction 0.295 puts the body 29.5% along its path in one frame. That is
a teleport at the window boundary -- the exact defect class this whole pass
exists to remove -- traded for a pace error.

Changing `BLOCK_DEFLECTION_MIN_SECONDS` was also not done, and now cannot be
justified at all: it binds on none of 175 pairs.

The repair belongs in the window *before* the block, where the journey actually
begins. That is repair 4.
