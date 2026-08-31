# Scripted rally architecture

> The author specifies a sequence of timed intentions. The resolved rally is the
> consequence.

`ScriptedRallyDriver` is an intent adapter over the production rally systems. It
does not author contacts, move a ball to a mark, snap a body to the ball, or
substitute author-facing launch draws for production physics. The same
production movement, reach-envelope, contact, attack, block, and ball-flight
systems decide what actually happens.

## Ownership

| Author owns | Production owns |
| --- | --- |
| Who attempts an action | Whether body and ball coincide |
| When the actor commits (`intent_time`) | Actual contact time (`resolved_contact_time`) |
| Volleyball target, course, family/type, aggression, or tempo | Contact position and `contact_height_meters` |
| Initial placement of the twelve volis and `serving_side` | Reachability, legality, quality, launch, flight, and outcome |

Bearing, vertical-angle, power draws, and quality overrides are probe controls,
not author-facing rally vocabulary.

## Script schema

The top level contains:

- `serving_side`: `"home"` or `"opponent"`.
- `initial_positions`: exactly the twelve on-court voli IDs mapped to normalized
  court coordinates.
- `actions`: one or more timed intentions, beginning with a serve.
- optional `movement`: waypoint requests with `actor`, `start_time`, `end_time`,
  and normalized `target`;
- optional `seed`, persisted with authored files for repeatable inspection;
- optional `note`.

Every action declares `actor`, `action`, `intent_time`, and normally `target`.
Family vocabulary is deliberately narrow:

- serve: `serve_type`, destination `target`, `course`, `aggression`;
- receive, dig, cover: `attempted_action`, intended player/coordinate `target`;
- set: intended hitter/zone `target`, `set_family`, `tempo`;
- attack: `attack_action`, destination `target`, `course`, `aggression`;
- block: optional staging `target`, `block_intent`, `course`.

`intent_time` is not ordered as a contact list. Commitments may overlap: a
hitter can begin an approach before the set contact and a blocker can commit
before the hitter contacts. Resolution still consumes intentions in volleyball
action order, while each production opportunity search begins no earlier than
that action's commitment.

## Contact boundary

For every non-serve action, `FreeFlightInterceptionSystem.opportunities()` scans
the authoritative incoming flight against the named actor's production movement
and contact envelope. The earliest reachable opportunity at or after
`intent_time` is the only route to a physical contact.

If no opportunity exists, the intention is a valid miss. The incoming flight is
allowed to reach its uncontrolled production terminal. It is not retimed and no
contact event is manufactured.

The script therefore has no authored `contact_height_m`. An actual physical
contact publishes both:

- `resolved_contact_time`, derived from the body/ball intersection;
- `contact_height_meters`, derived from the ball at that intersection.

An intended outgoing height, when a production family supports that volleyball
decision, is a different family-specific target concept. It must never be used
as the incoming contact height.

## Refusal versus consequence

A refusal means the request could not be interpreted or routed safely:

- malformed schema or unknown vocabulary;
- a serve actor outside `serving_side`;
- authored identities not matching the twelve production on-court identities;
- a missing production resolver seam.

An unreachable attempt, execution error, untouched block, serve error, shank,
kill, or ace is a resolved consequence, not a refusal. `result.analysis` carries
an intent ledger mapping every processed action to `contacted`, `missed`, or
`failed`, while `result.events` remains the authoritative physical/playback
record.

## Physical record

Every physical contact event states its resolved time and height and publishes
its outgoing production flight. When a later body intercepts that flight, the
earlier event is shortened to the realized prefix; its launch is never changed.
The incoming endpoint and outgoing start at a contact must match in position,
height, and time.

Block attempts may be ordinary `BLOCK` events without a physical touch. Such an
event carries intent and miss diagnostics but no contact time, height, or ball
launch. `seam_census()` audits only events which claim `physical_contact`.

The returned `RallyResult` is directly consumable by
`MatchScreen.load_and_play_rally()` because playback reads `.events`; no second
playback implementation exists for scripts.

## Files and visible playback

The only persisted format is `volley-world-manager/scripted-rally/v1` JSON.
Coordinates are hand-authorable `[x, y]` arrays; `load_script_file()` decodes
them to production values and `save_script_file()` writes the same shape. The
examples in `tools/authored_rallies/` are therefore fixtures, editable authored
rallies, and save-file examples at once.

`tools/authored_playback.tscn` loads a named file, resolves it, and passes the
returned result directly to `MatchScreen.load_and_play_rally()`. Its persistent
overlay and stdout show every intent ledger entry, including misses and
refusals. It must run with a renderer, not `--headless`.

Movement intervals remain intentions. Production locomotion certifies whether
the requested actor can reach the waypoint during the authored interval; an
unreachable request is refused with actor, interval, and required travel time.
Validation does not place or teleport the actor. Applying twelve concurrent
movement tracks to resolved state and playback remains Slice 4.

## Audit disposition and slice 2

Must change before slice 2, and now settled:

- `actions[].time` is retired; `intent_time` is the authored commitment and
  `resolved_contact_time` exists only on a realised physical event.
- authored actions are attempts, so an unreachable attempt creates no contact;
- authored `contact_height_m` is rejected, while every realised contact records
  production-derived `contact_height_meters`;
- `serving_side` is script data, not a second resolver argument, and the server
  must belong to that side;
- the landed serve/reception slice uses the same boundary as every later family,
  rather than serving as evidence that authored time means contact time;
- set, attack, block, dig, and cover route to production resolver seams. There is
  no family-level “not reached” refusal left.

May remain outside slice 2:

- commitment mistiming may initially affect only reachability through geometry;
- the authoring UI may re-resolve prefixes without changing production playback;
- promotion of a new timing-fit quality term into ordinary rallies waits for its
  own balance-certified pass.

The revised slice-2 sequence is therefore: establish and test this boundary,
route each family through production, verify deterministic replay and alternate
seed variance, audit physical seams, then build cumulative authoring preview on
the returned `RallyResult.events`.

## Determinism and preview

`resolve_script(..., seed_value)` seeds the production simulator:

- a fixed seed gives exact repeatability for inspection;
- a new seed holds authored intentions constant while allowing execution to
  vary.

The intended authoring loop is: place twelve, choose serving side and server,
author an intention, repeatedly re-resolve the cumulative prefix, then lock the
intention. Locking freezes intent, not resolved physics. Full-rally playback is
always the same playback of the latest resolved prefix.

## Commitment-mistiming model

The intent/contact boundary does not depend on a new quality model. Geometry
alone may decide whether contact occurs while slice 2 lands.

A later authoring-only pass may add commitment-moment `SystemFitProfile`s and
fold their continuous fit into contact quality. It must derive family ideals and
tolerances from production mechanics (including the attack approach/takeoff
terms), not add authored fixture windows. It must not enter ordinary rally
simulation until separate before/after balance probes re-certify gated dig,
stuff, and serve-error bands as well as kill and ace outcomes outside them.
