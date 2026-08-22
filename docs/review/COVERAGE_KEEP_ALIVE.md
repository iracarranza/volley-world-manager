# Attack coverage keep-alive — the last fabricated platform ball

Built and certified 2026-08-22 on `claude/system-fit-serve-receive-von64k`,
from `d6c15b8`.

## What was fabricated

Attack coverage — the contact that keeps a blocked-and-recycled ball alive —
was the last successful platform contact in the rally whose outgoing ball was
not its own. `_resolve_attack_coverage` chose *who* covers (a governed contest
over responsibility, proximity, ball control and anticipation) and
`_attack_coverage_contact_state` published the coverer's real body/contact
state, but the ball itself was invented afterwards by
`_ensure_event_trajectories` at a fixed **0.58 s duration, 1.8 m apex, 1.0 m
start and end height**, aimed at a `recycle_target + (0.04, ±0.05)` offset with
a `null`-recipient intent. Over 5,000 rallies the coverage census found 213/213
successful coverage contacts fabricated this way, none owning a ball.

The missing piece was never physics — coverage already shares the T1–T3
`PlatformContactModel` envelope every reception and dig use. It was a decision:
**what does a scramble touch off a block aim at**, when it has no set target
plane (reception) and no interception endpoint (a dug ball resolved by M5)?

## The decision

Coverage owns **no recipient policy of its own**. Its intended target is
exactly the actor the existing second-contact policy names —
`_second_contact_setter`, the one selector every dig and transition already
goes through — with the coverer passed as the excluded `first_contact_player_id`
so a coverer is never named their own recipient and an unavailable designated
setter falls to that selector's existing emergency-setter branch. No new
ranking, weight, coefficient, coverage-specific band, fixed apex/pop, forced
recipient, or centre-court default was introduced.

From that intent the keep-alive is the shared physical platform contact and
nothing bespoke: the authoritative incoming block ball, the coverer's own
body/contact state, and the T1–T3 model produce one authoritative free flight
through the same `_physical_platform_dig_result` the dig uses. The launch aims
at the team's own setter release seat — the same anchor the dig and the
downstream M5 second-contact chooser both target — so the keep-alive and the set
it feeds converge on one point; height and the arrival floor track the named
actor, which is where the soft intent lives.

The launch selects nothing about who touches the ball next. The outgoing free
flight is threaded into the existing `_resolve_home_continuation` /
`_resolve_opponent_transition` machinery, whose `authoritative_free_flight`
branch runs M5 interception: the intended actor may miss, a teammate may
intercept, or the ball may floor, sail or cross untouched.

## Gating and byte-neutrality

The physical keep-alive is gated behind the same `_physical_platform_dig_enabled()`
the controlled dig uses (`ENABLE_PHYSICAL_PLATFORM_DIG`, or the development
override in a debug build). With the flag `false` — production today — coverage
keeps its legacy fabricated trajectory exactly, and the full suite is unchanged
at **2,170 checks**. Nothing is promoted by this checkpoint.

## Certification

`tools/run_coverage_rollout_probe.gd`, 2,800 paired rallies (1,400 per arm,
both serving sides), retired-legacy vs physical:

| contract | result |
|---|---:|
| legacy arm coverage owning a ball | 0 / 69 (all fabricated) |
| physical arm successful coverage owning the shared launch | 68 / 68 |
| authoritative free flights | 68 / 68 |
| launch mutations after interception | 0 |
| realised-segment prefix failures | 0 |
| intended recipient == coverer | 0 |
| intended recipient a legal available actor | 68 / 68 |
| interceptor == coverer | 0 |
| alternate (non-intended) interceptors | 32 |
| intended recipient without an opportunity | 62 |
| T1–T3 outgoing-speed bound violations | 0 |
| retired 0.58 s / 1.8 m / 1.0 m shapes on an owned ball | 0 |
| both sides launching | home 49, opponent 19 |
| live resolutions | intercepted 40, floor 28 |

Terminal vocabulary is certified directly on the shared model: an uncontrolled
in-court launch floors, one over a boundary sails out, one below the tape
terminates at the net. The dig rollout, overpass action probe, and 1,200-rally
M5 overpass census still PASS with 0 unresolved outcomes.

Counts and rates here are observational. None is a calibration target; the
retired arm remains available so this protocol validates future changes rather
than going stale when production opens.
