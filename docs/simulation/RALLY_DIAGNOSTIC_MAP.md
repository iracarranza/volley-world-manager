# Rally diagnostic map

Status: **CURRENT EXECUTION INDEX + DIAGNOSTIC MAP.**

This document answers one question: **when a rally looks or resolves wrongly, what phase owns the problem, what must be true there, and where should the investigation go next?**

It is not a replacement for the specialist design documents. Long-form semantics remain owned by `VOLLEYBALL_FIDELITY.md`, `CONTACT_AND_BALL_FLIGHT.md`, `SETTER_DECISION.md`, the other design specs, and the provenance log. Measurements remain in `PROBE_HANDOFF.md`. Stable contracts live in `RALLY_INVARIANTS.md`.

## How to read a phase

Every phase can be inspected at five levels:

1. **L1 — volleyball flow:** what problem the athletes are solving.
2. **L2 — ownership:** which subsystem owns each fact and which facts must already exist.
3. **L3 — branch/decision:** the causal ordering and meaningful alternatives.
4. **L4 — invariants:** contracts that must hold regardless of tuning.
5. **L5 — evidence:** concrete values, event metadata, probes, tests, and renders that distinguish candidate causes.

The diagnostic chain is:

```text
visible symptom
→ smallest plausible phase
→ violated invariant
→ candidate causes
→ one discriminating measurement
→ owning subsystem
→ focused regression
→ broad population/render validation only after the local cause is known
```

This is the rally-specific application of `docs/FAILURE_MODES.md` §0. Do not tune a threshold merely because a screenshot looks wrong.

## Authority map

| Question | Authority |
|---|---|
| What counts as convincing volleyball? | `docs/design/VOLLEYBALL_FIDELITY.md` |
| Who owns contact, launch, free flight and realized segments? | `docs/design/CONTACT_AND_BALL_FLIGHT.md` |
| What must always hold? | `docs/simulation/RALLY_INVARIANTS.md` |
| Why did the simulator reach this architecture? | `docs/review/RALLY_SIMULATOR_REDESIGN_LOG.md` |
| What do current instruments actually measure? | `docs/review/PROBE_HANDOFF.md` |
| How does the setter choose? | `docs/design/SETTER_DECISION.md` |
| How should an investigation avoid false evidence? | `docs/FAILURE_MODES.md` |

## Canonical rally sequence

```text
PRE-SERVE STATE
→ SERVE INTENT
→ SERVE CONTACT
→ SERVE FREE FLIGHT + NET/FLOOR LEGALITY
→ RECEIVE RESPONSIBILITY + PERCEPTION
→ RECEIVER MOVEMENT / ARRIVAL
→ RECEPTION CONTACT
→ RECEPTION OUTGOING FREE FLIGHT
→ SECOND-CONTACT RESPONSIBILITY
→ SETTER MOVEMENT / POSTURE
→ SETTER DECISION
→ SET CONTACT + OUTGOING FLIGHT
→ HITTER PREPARATION / APPROACH
→ BLOCK READ / COMMIT / CLOSE
→ FLOOR-DEFENCE BASE
→ ATTACK CONTACT + OUTGOING FLIGHT
→ BLOCK CONTACT OR PASSAGE
→ DIG / COVERAGE RESPONSIBILITY
→ DEFENSIVE CONTACT + OUTGOING FLIGHT
→ TRANSITION
→ repeat from second-contact responsibility
→ EARLIEST TERMINAL PHYSICAL/LEGAL EVENT
→ SCORE
→ TERMINAL CLASSIFICATION
→ COMMENTARY / STATISTICS / PRESENTATION
```

Athlete actions overlap this sequence. The arrows describe causal ownership, not animation windows. `INV-TIME-001` forbids treating each ball leg as a complete player-action window.

---

# A. Pre-serve and serve

## A1. Pre-serve state

**L1.** Both teams establish legal rotation, receiving/serving shape, responsibilities, and tactical intent before the ball is struck.

**L2.** Match/rotation state owns who is on court and who serves. Tactical plans own intended receive/serve structure. Presentation reads those facts.

**L3.** Validate the lineup and current server before any serve-specific choice. Establish receiver responsibility before reachability is evaluated.

**L4.** `INV-CLAIM-001`, `INV-FIDELITY-001`.

**L5.** Trace rotation, court unit, server ID, receive zones/assignments, initial positions, and any role substitution such as libero replacement. If the wrong player later receives, first verify the pre-serve assignment rather than the eventual claimant.

## A2. Serve intent and selection

**L1.** The server chooses a target/style/risk that the body can attempt; the result is not known yet.

**L2.** Serve repertoire/tactical intent owns the attempted serve. The physical launch resolver owns the realized ball.

**L3.** Intent → feasible launch search → execution error. Do not decide landing or `ACE` first and fit physics backwards.

**L4.** `INV-CONTACT-001`, `INV-BALL-001`, `INV-ENG-004`.

**L5.** Trace intended target, style, intended pace/angle/spin, feasible candidate set, selected launch, execution error, authoritative gravity. See the forward-serve sections of `CONTACT_AND_BALL_FLIGHT.md`.

## A3. Serve contact and free flight

**L1.** A legal serve leaves the hand and either clears the net into/out of court or faults before reception.

**L2.** Physical contact owns launch state. Free flight owns position/height over time, net crossing, natural landing and bounds result.

**L3.** Contact → one launch → free flight → earliest of net/floor/out/eligible reception contact.

**L4.** `INV-BALL-001`, `INV-BALL-002`, `INV-FLIGHT-001`, `INV-FLIGHT-002`, `INV-NET-001`, `INV-DEAD-001`.

**L5.** Trace launch position/height/time, velocity or equivalent state, gravity, exact net-plane crossing time/height, natural floor intersection and landing. If the drawn ball passes through the net, compare the authoritative crossing height with the presentation sample before deciding simulation versus playback.

---

# B. Serve reception

## B1. Reception responsibility and perception

**L1.** The receive formation determines whose ball it is before a race between all six players does. Middles or protected passers should not take deep balls merely because a generic distance function can reach them.

**L2.** Serve-receive assignments plus perceived/intercept geometry own the claim. Reachability grades whether the responsible receiver can execute it.

**L3.** Legal incoming serve → assigned responsibility candidates → perception/read → claimant → arrival evaluation. Emergency transfer is explicit rather than the default definition of ownership.

**L4.** `INV-CLAIM-001`, `INV-CLAIM-002`, `INV-PERCEPTION-001`.

**L5.** Trace landing/intercept estimate, receive zones, candidate IDs/roles, immediate-owner count, distances, emergency flag, winner distance, reach margin. Primary instrument: `responsibility_probe`; focused serve-reception authority probes/tests may add contact evidence.

## B2. Receiver movement and contact

**L1.** The receiver reads, moves, establishes a platform and meets the ball at one physically plausible place and time.

**L2.** Movement/reach owns body arrival. Platform contact owns the actual body-ball result. The incoming trajectory remains ball authority until contact.

**L3.** Claim → movement → arrival → platform contact. Contact success/control is decided at the physical contact boundary, not by a pre-contact pass-quality shortcut.

**L4.** `INV-CONTACT-002`, `INV-CONTACT-003`, `INV-PERCEPTION-001`.

**L5.** Trace movement start/target/duration, contact time, incoming trajectory sample at that time, body/platform anchor, separation at contact, contact control, failure chance/roll if used. A render gate proves visual seam only when it samples the same published trajectory and contact event.

## B3. Reception outgoing ball

**L1.** A clean pass, shank, overpass, or emergency continuation is still a ball in play until physics/rules make it dead.

**L2.** Platform contact owns outgoing launch. Free flight owns what happens next. The reception-quality verdict does not own the rally winner.

**L3.** Contact → outgoing launch → free flight → earliest net/floor/out/next-contact event. A poor reception may die, cross legally, score on the opponent court, or remain playable.

**L4.** `INV-CONTACT-003`, `INV-FLIGHT-001`, `INV-NET-001`, `INV-DEAD-001`, `INV-DEAD-002`, `INV-DEAD-003`.

**L5.** Trace outgoing launch, exact net-plane crossing, landing, last toucher, court side, next eligible contact and terminal timestamp. Critical regression: a reception with a poor/failed contact verdict that legally crosses and lands untouched in the serving team's court must score for the receiving team and must not be an ace.

---

# C. Second contact and setter

## C1. Second-contact responsibility

**L1.** The setter normally takes second contact, but a displaced/unreachable setter can yield to an appropriate teammate. The intended setter cannot physically terminate the pass merely because they were the target.

**L2.** Incoming free flight exists first. Responsibility/interception selects who can actually make the second contact.

**L3.** Outgoing platform flight → candidate second-contact actors → responsibility → reach/obstruction → actual interceptor.

**L4.** `INV-CONTACT-001`, `INV-FLIGHT-001`, `INV-CLAIM-001`, `INV-CLAIM-002`.

**L5.** Trace actual free-flight state, intended recipient separately, candidate reach margins, obstruction/waypoint, claim gap, selected actor and actual interception. Instruments: `pass_and_set_probe`, `obstruction_probe`, `second_contact_preview` where applicable.

## C2. Setter movement and posture

**L1.** Reaching the ball is necessary but not sufficient for a stable jump/standing set. Approach, plant, body momentum and contact window matter.

**L2.** Locomotion owns travel; setter capability/posture logic owns the feasible action envelope; ball flight owns available time.

**L3.** Actual incoming flight + setter state → movement window → arrival → posture/action family → contact capability.

**L4.** `INV-TIME-001`, `INV-CONTACT-002`.

**L5.** Trace arrival margin, approach speed, plant/stability condition, release posture, contact height and incoming ball state. `pass_and_set_probe` is the current population instrument.

## C3. Setter attack choice

**L1.** The setter chooses among viable hitters based on this pass, this rotation, the forming block, player quality, tactical instruction and imperfect judgment.

**L2.** `SETTER_DECISION.md` owns the option semantics. The setter decision consumes perceived/current state; it does not own future attack success.

**L3.** Enumerate eligible hitters → gate physical feasibility → score matchup/quality/instruction under setter perception → choose hitter/tempo → resolve set attempt.

**L4.** `INV-PERCEPTION-001`, `INV-SETTER-001`, `INV-SETTER-002`, `INV-ENG-004`.

**L5.** Trace the event's option decomposition, candidate availability, arrival/lateness, rescue height, block read/exposure, instruction bias and stable judgment error. For tuning/long-sample criteria use the measurements specified in `SETTER_DECISION.md`, not a single rally.

## C4. Set contact and outgoing ball

**L1.** The setter redirects the ball toward an attackable window; the intended hitter is not guaranteed to become the actual next contact if the ball/body geometry says otherwise.

**L2.** Set contact owns outgoing launch. Free flight owns the ball. Hitter preparation consumes that flight and the already-made decision.

**L3.** Contact → authoritative set launch → free flight → hitter approach/interception or terminal event.

**L4.** `INV-BALL-001`, `INV-BALL-002`, `INV-CONTACT-001`, `INV-CONTACT-002`, `INV-FLIGHT-001`.

**L5.** Trace contact point, delivered launch, flight time, target versus realized ball, hitter reachable contact, achieved tempo and any posture-dependent delivery terms.

---

# D. Attack preparation, block, and defence

## D1. Hitter preparation and approach

**L1.** Attackers become available before the set arrives. A hitter cannot teleport to a quick contact after release.

**L2.** Setter choice supplies intended option/tempo; locomotion/approach mechanics own preparation and reachable contact; set free flight supplies the clock.

**L3.** Read developing second contact → begin preparation → setter releases → continue approach → takeoff/contact if reachable.

**L4.** `INV-TIME-001`, `INV-FIDELITY-001`.

**L5.** Trace preparation start, movement origin, approach path, travel budget, takeoff, reachable contact and set flight time. If playback slides a hitter across court during a quick, compare preparation start and available flight time before changing animation speed.

## D2. Block read, commitment and close

**L1.** Blockers read the setter/hitter, commit with imperfect information, close laterally and jump. A late blocker must be late for a causal reason visible before attack contact.

**L2.** Perception/read owns believed lane/timing; locomotion owns close; block geometry owns the wall actually present at attack crossing/contact.

**L3.** Observe developing attack → recognize → commit → close → jump → form whatever wall actually arrives. Attempted blockers and collision-effective blockers are not necessarily the same set.

**L4.** `INV-PERCEPTION-001`, `INV-TIME-001`, `INV-FIDELITY-001`.

**L5.** Trace recognition time, believed lane, commitment, close distance/time, jump timing, hand/reach envelope and collision-effective wall. `rally_resolution_probe` verifies several current wall-routing and timing contracts.

## D3. Floor-defence base

**L1.** Defenders establish line/cross/short responsibility before the swing and react from that prepared state; they do not simply chase the eventual landing coordinate after attack contact.

**L2.** Defensive plan owns base responsibility. Perception/read owns believed threat. Locomotion/reach owns reaction and arrival.

**L3.** Establish base → read set/hitter/block → adjust → attack contact reveals more information → react/intercept.

**L4.** `INV-CLAIM-001`, `INV-PERCEPTION-001`, `INV-FIDELITY-001`, `INV-TIME-001`.

**L5.** Trace base position, line/cross/short responsibility, orientation, recognition delay, attack speed, reaction window, movement path and reach margin. Distinguish DIG from ATTACK_COVERAGE when interpreting evidence.

---

# E. Attack, block contact, dig, and continuation

## E1. Attack contact and flight

**L1.** The hitter contacts from the body state actually achieved and sends one ball through the available geometry. The attack's later success is not known at contact.

**L2.** Attack contact owns outgoing launch. Block/flight geometry owns what the ball encounters next.

**L3.** Reachable hitter contact → swing/contact result → one launch → earliest block/net/floor/out/defensive contact.

**L4.** `INV-BALL-001`, `INV-CONTACT-002`, `INV-FLIGHT-001`, `INV-DEAD-001`.

**L5.** Trace body centre separately from contact point, contact height/depth, launch, net crossing, wall geometry, candidate floor endpoint and timing. `net_encroachment_probe` is relevant to body/contact separation; `rally_resolution_probe` covers attack/block routing.

## E2. Block contact

**L1.** A formed wall may stuff, deflect, funnel, tool, or miss. A block touch creates a new outgoing ball rather than a caption-level result.

**L2.** Block contact geometry owns whether/how hands touch. The resulting contact owns the new launch/deflection. Free flight owns the consequence.

**L3.** Attack flight intersects wall → resolve contact if any → outgoing deflection/free flight → next physical event.

**L4.** `INV-BALL-001`, `INV-CONTACT-002`, `INV-DEAD-001`, `INV-DEAD-003`.

**L5.** Trace wall members, hand geometry, intersection, touch type, outgoing launch, landing and last toucher. `rally_resolution_probe` currently checks out-after-block winner correctness and playable-touch routing.

## E3. Dig / coverage responsibility and contact

**L1.** A defender or covering teammate owns a playable ball according to prepared responsibility and actual availability, then uses an appropriate platform/emergency contact.

**L2.** Responsibility selects the actor; platform contact resolves the body-ball interaction; outgoing ball is independent of the intended setter.

**L3.** Incoming flight → responsibility/read → movement/arrival → contact → outgoing free flight.

**L4.** `INV-CLAIM-001`, `INV-CLAIM-002`, `INV-CONTACT-001`, `INV-CONTACT-002`, `INV-FLIGHT-001`.

**L5.** Trace event family (`DIG` versus `ATTACK_COVERAGE`), claim candidates, readiness, previous-contact recovery, arrival, platform intent, launch and next-contact selection. Do not copy unresolved DIG height/miss heuristics into coverage merely to make plumbing symmetrical.

## E4. Transition

**L1.** After a playable defensive contact, the team reorganizes: previous contacter clears, setter regains a lane, attackers recreate approaches and the opponent re-establishes block/defence.

**L2.** The outgoing defensive flight supplies the clock. Continuous athlete action owns recovery and preparation across event boundaries.

**L3.** Defensive contact → outgoing flight while multiple athletes recover/prepare → second-contact responsibility → setter choice → next attack.

**L4.** `INV-TIME-001`, `INV-FIDELITY-001`, `INV-FIDELITY-002`.

**L5.** Trace previous contacter recovery, setter route, hitter preparation starts, blocker/floor reset, incoming trajectory and actual next interceptor. A transition that works only because actors snap to phase starts violates the fidelity standard even if the event order is legal.

---

# F. Terminal authority, score, classification, and presentation

## F1. Terminal physical/legal event

**L1.** The rally ends because something physically/rules-wise ended it: the ball hit the floor, went out, faulted at the net, or another modelled terminal rule fired.

**L2.** The live trajectory plus rules owns the terminal event. Contact-quality labels, captions and statistics do not.

**L3.** For each live leg, compare candidate event times and resolve the earliest legal/physical event. Only after that event exists can a winner be assigned.

**L4.** `INV-NET-001`, `INV-DEAD-001`, `INV-DEAD-002`.

**L5.** Trace all candidate event timestamps on the leg: net crossing/fault, floor intersection, bounds, scheduled player contact, and any special terminal rule. The diagnostic question is always "which happened first?"

## F2. Score and terminal classification

**L1.** Once the ball is dead, award the point from the terminal event and last-touch/rules context, then describe what kind of point it was.

**L2.** Match/rally scoring owns winner assignment after terminal resolution. Classification consumes the resolved terminal chain.

**L3.** Terminal event → winner → classification (`ACE`, `SERVE_ERROR`, `KILL`, etc.) → statistics/commentary.

**L4.** `INV-DEAD-001`, `INV-DEAD-003`.

**L5.** Trace terminal timestamp, terminal reason, last toucher, landing side/in-bounds state, winner, classification timestamp and emitted commentary timestamp. No `ACE` should exist while the authoritative ball is still live.

## F3. Presentation and replay

**L1.** Playback shows the rally that was resolved. It may make it legible; it may not repair or rewrite it.

**L2.** `RallyResult`/event physical records are upstream. 2D/3D presentation samples them. Replay consumes stored result state rather than re-resolving gameplay.

**L3.** Resolved event/trajectory stream → physical-time sampler → body/ball presentation → optional explanation/cognition overlays.

**L4.** `INV-BALL-003`, `INV-CONTACT-002`, `INV-TIME-001`.

**L5.** When a visual defect appears, compare authoritative event values with the exact values arriving at the renderer before changing either side. If authoritative net/contact geometry is correct and the picture is wrong, fix playback. If the published physical state is wrong, presentation must not compensate for it.

---

# Focused diagnostic recipes

## Ball appears to pass through the net

```text
1. Identify the exact trajectory leg.
2. Sample its authoritative net-plane crossing time and height.
3. Compare against legal clearance using the same ball/net geometry as production.
4. If illegal in simulation but rally continues: INV-NET-001 / INV-DEAD-001 defect.
5. If legal in simulation but drawn below tape: INV-BALL-003 presentation defect.
6. Do not move the net mesh or trajectory merely to make the screenshot look right.
```

## Wrong player takes a ball

```text
1. Dump assignment/responsibility candidates before arrival.
2. Verify role/rotation/receive or defensive zones.
3. Verify immediate-owner and availability state.
4. Only then inspect reach/movement competition.
5. If raw reach created ownership: INV-CLAIM-001 defect.
6. If responsibility was correct but body could not arrive: movement/reach defect instead.
```

## Contact is visually desynchronized

```text
1. Read authoritative contact time/position.
2. Sample incoming trajectory there.
3. Read posed body contact anchor there.
4. Compare simulation contact, outgoing launch origin, and rendered anchor.
5. One disagreement identifies the boundary; do not snap all three together in presentation.
```

## Point/commentary appears before the ball is dead

```text
1. Find classification creation timestamp.
2. Find terminal physical event timestamp.
3. Enumerate live outgoing trajectory after the preceding contact.
4. If classification precedes terminal event: INV-DEAD-003 defect.
5. Move scoring/classification authority downstream; do not merely delay the UI animation.
```

## A poor reception automatically becomes an ace

```text
1. Confirm whether receiver physically contacted the ball.
2. If no contact occurred, continue to terminal serve flight and classify only after it dies.
3. If contact occurred, inspect the outgoing reception launch.
4. Resolve net/floor/out/next contact chronologically.
5. If reception verdict alone chose the winner: INV-DEAD-002 defect.
6. Regression: poor contact legally over the net, untouched in bounds on server court -> receiving team point, ACE false.
```

# Evidence discipline

A screenshot is evidence of a visible symptom, not automatically of its layer. A deterministic seed is evidence only when the relevant inputs are held constant. A probe is evidence only for the production path and denominator it actually exercises. A test count is not a behavioral metric.

For any new rally repair:

```text
A. Name the violated invariant.
B. List candidate causes.
C. Choose one measurement that separates them.
D. Inspect what already reaches the downstream consumer.
E. Change the smallest owning layer.
F. Add a focused regression tied to the invariant ID.
G. Re-run the relevant production probe/render.
H. Run the broad suite and report population movement separately from PASS/FAIL count.
```

If the investigation reaches a physical question for which no authoritative model exists, stop. That is authoring physics, not plumbing; record it in the appropriate design/review document before inventing a constant in the repair.