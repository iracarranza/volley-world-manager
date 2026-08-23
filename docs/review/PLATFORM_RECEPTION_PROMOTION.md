# Serve reception — physical authority, and its promotion

Built, reconciled and promoted 2026-08-22 on
`claude/system-fit-serve-receive-von64k`, after `6ce8f3b`.

Reception was the last platform family still authoring its own outgoing ball.
It now obeys the same authority model as the controlled dig and attack coverage:

    serve → receiver body/contact state → existing reception intent
      → shared PlatformContactModel T1–T3
      → ONE authoritative outgoing free flight
      → M5 interception / terminal / overpass
      → the actual second contact

The intended setter is soft intent. The actual interceptor owns contact two. The
SET consumes the realised intercepted prefix, never the untouched full flight.

## Why it was harder than the other two

Dig and coverage feed a **transition** set, and both transition resolvers already
had an `authoritative_free_flight` branch. Reception feeds the **first-ball** set,
which was a pre-M5 inline resolver: it chose the setter spatially against the
pass destination (`_spatial_setter_choice`) and had no interception branch at
all. So the opponent side needed no retrofit — it funnels through
`_resolve_opponent_transition` — while the home first ball needed the whole M5
path added: interception selection, truthful terminals (floor/net/out gives the
serving side the point, a legal crossing is the opponent's ordinary first
contact), and realised-prefix reporting into the SET.

## The reconciliation: four stale endpoints and one instrument gap

Opening the flag first exposed a cluster of failures that looked like a physics
problem and was not. Every one was a place where the **authored pass endpoint**
was still standing in for the **actual interception** — the same class of defect
the dig promotion had already corrected once, in four more places:

| what read the wrong point | what it reads now |
|---|---|
| the setter's capability height (`reception_pass.set_contact_height_meters`, NaN under a physical launch) | the interception's `contact_height_meters` — the value `_stamp_free_flight_resolution` already publishes on the reception event. The opponent path had done this since its own promotion; this is the home side catching up |
| the reception's published `actual_pass_target` (the untouched flight's floor) | the point the ball was actually played to, kept in step with `end_position` where the shared stamp already reconciles it |
| the opponent SET's displayed `start_position` (`dig_position`, where the feed was *aimed*) | `opponent_setter_position`, where a body actually met the flight. Identical on the legacy arm, where the setter stands on the pass destination by construction |
| the SET_DECISION moment (`pass_trajectory.end_time` — where the untouched ball *would have* landed) | the interception the flight resolved to. Reading the flight's end stamped the decision *after* the set it precedes, which is what the causality floor was spending 33 corrections on |

The instrument gap was separate and is the one that mattered for the
movement-agreement gate. The home first-ball SET never published
`body_contact_position` or `movement_entry_velocity`, because the legacy spatial
choice starts from rest and targets the ball. Both other set paths publish them
from their physical choice. Without them the movement diagnostic measured a
traversal to the **ball** (a reach further than the body actually travels)
against a duration charged to a **moving** setter rebuilt at rest — comparing a
different leg under a different assumption. Publishing the two values the
interception already carries closed the gate. **No band was widened and no
movement constant was added.**

One further latent inconsistency surfaced, older than this work: the cognition
compiler budgets `OPTION_GLANCE_SECONDS` (0.16 s) per setter glance while the cue
model's default dwell is `GLANCE_DWELL_SECONDS` (0.18 s), so a slice landing
between the two produces a glance whose dwell outlasts the glance —
`is_well_formed()` rejects it by design. It only binds when the setter's scan is
short enough for the affordability cut to fire, which physical reception made
ordinary. The dwell is now capped at its own slice, which says what the
neighbouring truncation already says: a setter short of time takes shorter looks.

## Evidence

| measurement | result |
|---|---|
| paired reception rollout (`run_reception_rollout_probe`, 2,800 rallies) | **14/14 PASS** |
| owned launches | 1,117 / 1,117 |
| launch mutations after interception | 0 |
| realised-prefix failures / SET chain breaks | 0 / 0 |
| intended setter ≠ interceptor | 32 alternates, 164 intended misses |
| T1–T3 outgoing-speed bound violations | 0 |
| live resolutions | intercepted 980, floor 130, net 4, overpass 3 |
| both serving sides | home 549, opponent 568 |

Suite with reception open, tracked across the reconciliation: **7 → 4 → 3 → 1 →
0** failing checks, ending at **PASS: 2,132**. Dig, coverage, reception and
overpass rollouts all PASS, and `run_m5_overpass_census` reports **0 unresolved
outcomes** over 1,200 rallies — no certified family was reopened.

## Observations, not bounds — and one worth looking at next

About **12%** of physical receptions (130 of 1,117) end on the floor: a pass no
setter can run down. The legacy scatter always landed a playable ball at the
setter, so this is a real change in what a bad pass costs, and it is reported
rather than tuned.

It moves the balance profile, measured on `run_rally_balance_probe` over 700
rallies both serving sides, against the same probe at the dig/coverage promotion:

| | dig + coverage | + reception |
|---|---:|---:|
| kill rate, both sides *(target 0.45–0.50)* | 0.544 | **0.661** |
| contacts per rally *(target above 6.0)* | 5.200 | **4.771** |
| swing balance *(near 1.00)* | 1.032 | 0.934 |
| dig rate *(0.35–0.55)* | 0.353 | 0.387 |
| stuff rate *(0.08–0.14)* | 0.120 | 0.114 |

Dig and stuff stay in band and swing balance stays near one. Kill rate and
contacts-per-rally move the wrong way, and the mechanism is the same 12%: a
rally that ends on an unplayable pass is a rally with two contacts and a point
for the serving side. **None of these is an acceptance bound** — the balance
probe is a reporting tool with no gate, and the suite, which is the acceptance
mechanism, passes 2,132/2,132. Both figures were already outside their advisory
targets before reception was promoted.

So this is recorded as the honest next question rather than fitted away: **is 12%
the right price for a shanked serve-receive?** It is a question about the
reception launch envelope and the setter's interception search, not about the
authority model, and answering it must not be done by widening a band.

One gate's fixture moved as a consequence: the geometric-attack end-to-end check
stood on the single seed 770012, whose pass is now one of those floored ones —
the rally ends truthfully with no attack, so a gate asking whether an attack was
measured had nothing to measure. It now scans a short span for a rally that
actually swings; the assertion itself is unchanged.
