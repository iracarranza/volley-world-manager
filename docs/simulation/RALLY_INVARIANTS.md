# Rally invariants

Status: **NORMATIVE INDEX.** This file gives stable identifiers to rally contracts that are owned and explained elsewhere. It is deliberately terse. Do not duplicate the design essays, measurements, or historical reasoning here.

A test, probe, bug report, review note, or diagnostic trace may cite these IDs. The linked design document remains the semantic authority.

## Ball and contact authority

### INV-BALL-001 — one authoritative ball
A rally leg has one authoritative outgoing ball state. Gameplay, cognition, event records, and presentation must not independently reconstruct different launch physics.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§2–8.

### INV-BALL-002 — launch survives truncation
Truncating a free flight at an actual later contact must not retroactively change the launch state that left the previous contact.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§3–6.

### INV-BALL-003 — presentation is downstream
Presentation may sample, interpolate, transform, and truncate authoritative physical state. It must not author gameplay-relevant speed, gravity, contact success, reachability, or rally outcome.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§7–8; `ARCHITECTURE.md`.

### INV-CONTACT-001 — intent is not outcome
An intended recipient or target does not determine the actual future interceptor or realized endpoint.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§1, 9.

### INV-CONTACT-002 — contact is one event
The contact time and position used by simulation must be the same physical event consumed by the outgoing trajectory and represented by playback. A visual snap or second independently-derived contact is a defect.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§2, 5, 7.

### INV-CONTACT-003 — contact outcome precedes continuation
A contact resolver may determine whether/how the ball was played and produce an outgoing state. It does not get to manufacture the later interceptor or terminal result merely because the contact was poor.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§2–5.

## Flight and legality

### INV-FLIGHT-001 — free flight exists before the next actor
Once a contact produces a launch, the ball's free flight exists independently of who may later intercept it.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§3–5.

### INV-FLIGHT-002 — one gravity per ball
Every query of one published flight uses that flight's authoritative gravity. Net clearance, landing, gameplay reads, and display sampling may not silently use different gravity constants.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` serve-authority sections.

### INV-NET-001 — net legality is chronological
When a trajectory reaches the net plane, legality is evaluated from that same authoritative trajectory. An illegal net crossing terminates the leg before any later scheduled reception or contact can occur.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md`; rules-level contract under `docs/design/VOLLEYBALL_FIDELITY.md`.

### INV-DEAD-001 — earliest terminal event owns the rally
Rally outcome is determined by the earliest authoritative terminal physical/legal event on the live ball path: legal contact, net fault, floor contact, out condition, or another explicitly modelled terminal event. A downstream classification cannot reach backward and manufacture that event.

Owner: contact/flight semantics in `docs/design/CONTACT_AND_BALL_FLIGHT.md`; fidelity standard in `docs/design/VOLLEYBALL_FIDELITY.md`.

### INV-DEAD-002 — poor contact is not automatically a lost rally
A failed or poor reception/dig execution may produce a ball that dies locally, goes out, faults at the net, crosses legally, is played by the opponent, or lands on the opponent court. The contact-quality verdict alone is not sufficient to assign the rally winner when an outgoing live trajectory exists.

Owner: `docs/design/CONTACT_AND_BALL_FLIGHT.md` §§2–5.

### INV-DEAD-003 — classification follows terminal resolution
`ACE`, `SERVE_ERROR`, `KILL`, `ATTACK_ERROR`, and equivalent terminal labels are classifications of a resolved dead-ball result, not inputs used to create that result. Player-facing commentary must not publish a terminal label before its terminal event exists.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md`; contact/flight causality in `docs/design/CONTACT_AND_BALL_FLIGHT.md`.

## Responsibility, perception, and decision

### INV-CLAIM-001 — responsibility precedes raw pursuit
Reachability decides whether a responsible voli can make the play; it must not by itself erase receive/defensive responsibility and assign the ball to an implausible rescuer.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md` §§1, 4, 6; provenance in `docs/review/RALLY_SIMULATOR_REDESIGN_LOG.md` §3.5.

### INV-CLAIM-002 — immediate ownership is strong
A ball already inside a prepared or assigned player's immediate control space should not transfer to a farther teammate without an explicit reason such as unavailability, prior contact, obstruction, or assignment logic.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md`; `docs/review/RALLY_SIMULATOR_REDESIGN_LOG.md` §3.5.

### INV-PERCEPTION-001 — decisions cannot read future truth
A voli's decision may consume only information available or perceived by that decision boundary. Authoritative eventual landing, winner, terminal classification, or later contact may grade the decision afterwards but cannot leak into the read that preceded it.

Owner: cognition/perception contracts and `docs/design/CONTACT_AND_BALL_FLIGHT.md` §8.

### INV-SETTER-001 — setter choice is situational
The setter chooses among physically and tactically viable options using the shared option vocabulary. A predetermined hitter or eventual attack outcome may not replace that choice.

Owner: `docs/design/SETTER_DECISION.md`.

### INV-SETTER-002 — capability is not permission
A called play biases the setter; it does not force an impossible option. Conversely, setter autonomy must not make the tactical call decorative.

Owner: `docs/design/SETTER_DECISION.md`.

## Continuous volleyball action

### INV-TIME-001 — ball legs do not bound whole athlete actions
Ball motion is contact-to-contact, but athlete actions may begin before a leg and survive across multiple ball-event boundaries. Do not assume one ball flight equals one complete player-action window.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md` §5.

### INV-FIDELITY-001 — responsibility is visible before contact
Receiving, setting, attacking, blocking, and defending responsibilities should become legible through positioning and movement before the decisive contact rather than being explained only after it.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md` §§1, 4.

### INV-FIDELITY-002 — ordinary side-out is the certification case
Changes on the fidelity track must survive the controlled canonical side-out on neutral rosters before exotic rallies are treated as proof of convincing volleyball.

Owner: `docs/design/VOLLEYBALL_FIDELITY.md` §§2–4.

## Engineering and evidence

### INV-ENG-001 — one source for one physical fact
Before deriving a physical quantity, find whether an authority already computes it. Multiple independent derivations are defects unless the distinction is explicit and documented.

Owner: `docs/FAILURE_MODES.md` §4.

### INV-ENG-002 — production path is the evidence path
A probe or calibration used as evidence must exercise the production model it claims to measure, or explicitly state the difference and its limit.

Owner: `docs/FAILURE_MODES.md` §§6, 9; `docs/review/PROBE_HANDOFF.md`.

### INV-ENG-003 — measure before tuning
Thresholds, bounds, ratios, and calibration constants must be interpreted against the live distribution they act on. A desired count is not a substitute for measuring that distribution.

Owner: `docs/FAILURE_MODES.md` §§0, 2, 3, 5, 16.

### INV-ENG-004 — deterministic changes are attributable
New randomness must not silently resequence unrelated downstream seeded outcomes. Draw ordering and deterministic derivation must preserve attribution unless resequencing is itself the intended change.

Owner: `docs/FAILURE_MODES.md` §8; `docs/design/SETTER_DECISION.md` constraints.

## Using this registry

When a rally defect is reported, first name the smallest violated invariant. If none fits, that is evidence of a missing contract: add the semantic rule to the owning design document first, then give it an ID here. Do not turn an implementation accident into a new invariant.

A regression test should preferably state the invariant ID in its comment or failure text. A probe should list which invariant IDs it can actually test and which it cannot. `docs/simulation/RALLY_DIAGNOSTIC_MAP.md` maps these contracts onto the rally sequence.