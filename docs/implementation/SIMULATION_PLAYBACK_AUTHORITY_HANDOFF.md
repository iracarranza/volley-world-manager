# Simulation → Playback Authority Handoff

## Goal

Fix the recurring class of visible rally defects where the simulation resolves a physically meaningful rally, but playback does not have a complete enough authoritative description to render that rally without guessing, re-timing, or reconstructing movement/ball history.

This document is an implementation handoff for Codex/Claude. It is intentionally broader than any single reception/dig bug, but it must be implemented incrementally and measured against the current visible failures.

## Historical pattern

The repository has repeatedly produced the same family of symptoms:

- ball teleportation;
- ball/player contact desync;
- players appearing at tactical positions without visible traversal;
- impossible player speeds;
- movement stretched over the wrong ball-flight window;
- failed contacts visually shown as successful arrivals;
- blocks/deflections replaying or double-counting windows;
- movement/ball trajectories reconstructed differently by playback than by the resolver.

Representative commits:

- `fe376d7` — playback shortened/fabricated block trajectories and produced a ball teleport onto a digger;
- `1b11916` — simulator knew a defender was beaten, playback nevertheless walked them onto the ball;
- `0d93379` — writing a new `live_positions` state moved the player for simulation but teleported them for the viewer because no staged traversal was published;
- `a4eca6b` — resolver itself placed an attack contact where the movement model said the hitter could not physically arrive;
- `4fc237a` — set destination and later-adjusted attack contact diverged;
- `207b1f7` — playback correctly re-anchored a journey to simulator metadata, then snapped the visible actor to that start before drawing the journey;
- `1e71fcb` — playback treated the attack's aimed endpoint as the actual interception endpoint;
- `4bc31e4` — playback retargeted a flight to a failed defender, visually creating a contact that did not happen;
- `cf065cf` — resolver supplied distance, ball model supplied time, and playback created speeds owned by neither system (up to 57 m/s);
- `b5efe00` — a ball-flight interval was double-counted by playback;
- `a2321af` — floor-defence positions were written into state without corresponding traversal and therefore appeared instantly;
- `3438656` — a terminal ball stopped above the floor and later snapped down because the visible trajectory ended before the physical landing;
- current movement verification around `bca2653` / `988e84f` — movement endpoint, duration, start timing and off-ball timing do not yet describe one uniform physical journey.

The recurring architectural smell is not simply “playback bad” or “simulator bad.” It is that the simulation and playback often hold **different partial descriptions of the same physical rally**.

## Important counterexample

Do not assume every visual complaint is this seam.

`505a9b3` measured a reported serve “teleporting down” and found that playback was faithful to the published flight; the serve itself was simply too lofted. That was a simulation/calibration issue, not a presentation authority break.

The implementation must preserve that diagnostic discipline: prove the seam before fixing it.

---

# What already exists and should be reused

The repository is not missing basic physics.

## `RallyMovementSystem`

Already models, among other things:

- current carried velocity;
- directional velocity toward the target;
- acceleration;
- maximum speed;
- direction-change cost;
- facing fit;
- movement mode;
- available time;
- contact reach;
- jump/takeoff timing;
- movement capacity;
- travel time;
- arrival margin;
- arrival balance;
- physical feasibility;
- recovery timing.

This is detailed enough to answer physically meaningful movement questions.

## `ShadowMovementSystem`

Already turns the movement model into a fixed-step time function:

- sampled positions;
- sampled times;
- sampled speeds;
- direction changes;
- carried velocity;
- waypoint traversal;
- reached/not-reached result.

Its own stated role is evidence-only: it deliberately does not mutate source state and is not the global resolver/playback authority.

This is important. The repository already contains most of the machinery needed to derive continuous motion. The problem is **authority and contract**, not lack of a locomotion model.

## Off-ball movement / phase movement

The simulator already resolves substantial off-ball behaviour:

- defensive floor shapes;
- block formation;
- coverage targets;
- hitter approaches and transition;
- setter release/chase;
- phase targets and intents;
- `live_positions` updates;
- recovery/commitment windows.

So the target architecture must not regress to a simplistic contact-only model.

---

# The actual missing capability

The simulator is authoritative enough to **decide** sophisticated volleyball actions, but not yet uniformly self-describing enough to **replay** them without interpretation.

There is no single consistent contract that allows playback to answer:

> At physical rally time `t`, where is every player, what velocity are they carrying, what movement/action are they in, and what authoritative physical journey brought them there?

Instead the current system distributes that answer across several partly overlapping representations:

- `live_positions` — authoritative state snapshot, but not traversal history;
- `movement_start` / `movement_target` — some journey endpoints, not universal;
- `movement_duration` — meaningful, but not always the duration of the same truncated journey represented by `movement_target`;
- `movement_delay_seconds` — exists only for some families;
- `physical_time` — authoritative contact/ball timing;
- `resolver_event_time` — retained but generally unused;
- `home_phase_targets` / `opponent_phase_targets` — off-ball destinations, often without independent timing;
- `receiver_arrived` and similar completion facts — published but sometimes unread;
- continuous reception samples — detailed, but evidence/debug-only and not the general rally authority;
- 2D movement paths — reuse the movement model but normalize away natural timing;
- 3D movement plans — more temporally expressive, but still consume incomplete/mismatched journey metadata.

## Key distinction

`live_positions` can be correct for simulation and still be insufficient for playback.

A state transition:

```text
A at t0
B at t1
```

is enough for the resolver to continue from B.

Playback still needs to know whether the player:

- started immediately or after a read delay;
- accelerated from rest or carried momentum;
- changed direction midway;
- reached early and waited;
- failed to reach the requested target;
- continued the same leg across an intermediate event;
- changed target after a new read.

The historical teleport bugs repeatedly occur when simulation advances state without publishing enough information to reconstruct the physical transition.

---

# Current verified movement findings

Use `docs/review/RALLY_MOVEMENT_TIMELINE_VERIFICATION.md` as supporting evidence.

Important corrections already established there:

1. `ATTACK -> DIG` is not the real adjacent event stream in the measured cases. Use `ATTACK -> BLOCK -> DIG`.
2. 3D already has per-leg timing; shared `playback_progress` is primarily a 2D limitation.
3. The continuous reception shadow path is not an appropriate first universal implementation target: it is gated, home-side only and reception-specific.
4. A new `PlayerMovementTrace` structure is not yet justified. Much of that shape already exists in event metadata and movement plans.
5. The current dominant 3D contact-leg defect is a semantic mismatch: `movement_target` may describe the truncated endpoint reached within the available window while `movement_duration` may still describe the full journey toward the ball.
6. `movement_duration` is not presentation-only. It feeds simulation-side body velocity/calibration, so retiming it to the truncated endpoint is unsafe.
7. Off-ball movement targets currently lack independent durations in important paths, causing their movement to be stretched/compressed to the active ball-flight window.

The corrected recommendation at `988e84f` is therefore the immediate baseline, not the superseded first recommendation in `bca2653`.

---

# Immediate implementation sequence

The first objective is to make the existing movement contract complete enough that playback no longer has to combine facts from different journeys.

Do **not** introduce a new global movement-trace object before this sequence is measured.

## Gate 0 — capture a before-figure for off-ball movement

This must happen before change 5 below because those players currently publish no independent duration.

Measure representative off-ball legs across a substantial deterministic sample:

- player id / side;
- movement family / phase;
- start position;
- target position;
- distance;
- active ball-flight window;
- natural traversal time from the existing movement model;
- fraction physically completable inside the window;
- whether playback currently stretches/compresses the leg;
- whether the player arrives early, exactly, or cannot complete it.

Include at least:

- setter release during reception/pass flight;
- outside hitter transition/approach during set development;
- middle approach;
- block close;
- floor-defence shift;
- attack coverage;
- recovery/landing where represented.

Record this baseline before changing the contract.

## 1 — publish the movement budget used for truncation

Do **not** change the semantic meaning of `movement_duration`.

Where `_reached_point` or equivalent truncates a movement because only N seconds are available, publish that available movement budget separately, e.g.:

```text
movement_available_seconds
```

or the closest name consistent with repository conventions.

Playback pacing should use the authoritative budget when drawing the truncated endpoint:

```text
drawn_seconds = min(authored_duration, movement_available_seconds)
```

when the budget exists.

Preserve legacy/fallback behaviour for movement families that do not yet publish this field.

### Required proof

- simulation outcomes are byte/seed stable where expected;
- calibration that consumes `movement_duration` is unchanged;
- a truncated defender reaches the published `movement_target` at the correct contact deadline;
- an untruncated player may arrive early and remain there rather than being stretched to the whole flight.

## 2 — publish legitimate movement start timing

Generalise `movement_delay_seconds` or equivalent to every movement family that has a meaningful read/recognition/departure time.

Do not let playback assume that because the resolver knows the final rally, the actor knew the target at the previous contact.

Use existing perception/cognition timing where available.

Required families include at minimum:

- reception;
- dig/floor defence;
- set chase/release;
- hitter approach/adjustment;
- block close/jump where the timing model provides the information.

### Required proof

```text
movement_start_time >= cognition/read/not-before time
```

where such a constraint exists.

## 3 — complete endpoint publication

Publish authoritative `movement_target` (or equivalent end position) on movement families that currently force playback to infer the endpoint, especially `SET` and `ATTACK` if still missing at current HEAD.

Do not infer a journey endpoint in presentation from generic contact/start/body fields when simulation already knows the physical endpoint.

## 4 — use the instrumentation already present

Before adding new probes, consume and assert existing diagnostics where applicable:

- `playback_start_mismatches`;
- `playback_leg_overspeed`;
- `resolver_event_time` vs `physical_time`;
- `receiver_arrived`;
- continuity mismatch instrumentation in 2D/3D;
- ball/contact identity and trajectory authority tests already present.

The fix must be falsifiable from repository instrumentation.

## 5 — give off-ball movement independent timing

The ten non-contact players must not automatically inherit the entire active ball-flight window as the duration of whatever tactical movement they are making.

Extend phase/off-ball plan entries so a movement can say:

```text
start
 target
 duration / traversal_seconds
 optional delay
 optional waypoint
 completion / arrival progress
```

Use the existing movement model to derive the timing. Do not author arbitrary cosmetic durations.

Players may:

- arrive early and wait;
- remain in motion at the next contact;
- continue the same journey into the next window;
- fail to reach a tactical target before the phase changes.

### Critical requirement

A journey that spans `ATTACK -> BLOCK -> DIG` must not restart, freeze, teleport, or be consumed twice merely because `BLOCK` is an intermediate semantic event.

The same principle must hold for other multi-window journeys.

---

# Architectural gate after changes 1–5

After the five changes above, re-run deterministic simulation and render representative rallies.

Then answer this question explicitly:

> Does the existing metadata + shared movement model now define every physical player journey unambiguously enough that playback only renders it, or does playback still have to infer physical history?

If playback still must infer any of the following, stop adding isolated keys and consider consolidating the movement contract:

- movement start time;
- movement endpoint;
- available/deadline time;
- carried start velocity;
- movement mode;
- waypoint/target changes;
- whether a movement completed;
- whether a movement continues across an intermediate contact;
- which simulator position is authoritative when multiple representations disagree.

Only at that point reconsider a named `PlayerMovementTrace` / `PlayerMovementLeg` / equivalent structure.

The existence of many metadata keys is not itself a problem. The problem is whether they compose into exactly one physical interpretation.

---

# Preferred target architecture

Do not require storage of every rendered frame.

The repository already has deterministic movement physics, so the ideal compact authority can be expressed as a set of physical movement legs, each carrying enough inputs/constraints for the **same movement model** to reproduce the trajectory.

Conceptually:

```text
player_id
side
start_time
start_position
start_velocity
movement_mode
intent/target
optional waypoint
deadline / available_seconds
completion result
end_position
end_velocity
```

Then:

```text
authoritative movement leg
    +
shared RallyMovementSystem / fixed-step integration
    =
position(t), velocity(t)
```

Playback speed may change wall-clock viewing speed, but it must not alter the relationships on simulation time.

The ball already behaves much closer to this model because a trajectory carries start/end/timing/shape and can be sampled as a function of time. Player movement should reach the same level of temporal authority without creating a second locomotion model.

---

# Position authority vs pose authority

Keep these separate.

## Physical/root track

Answers:

> Where is this player in world/court space at time `t`?

This must come from simulation-authoritative movement.

## Pose/action track

Answers:

> What is the body doing at time `t`?

Examples:

- read;
- shuffle;
- platform;
- set;
- approach;
- jump;
- swing;
- block;
- landing;
- recovery.

A pose must not teleport the authoritative root to make contact look correct.

After movement authority is corrected, a remaining visual snap at DIG/RECEPTION may be a pure pose-transition issue. Diagnose that separately rather than contaminating movement timing to hide it.

---

# Ball authority

Preserve the repository's existing “one ball / one authoritative trajectory” direction.

Playback must never:

- fabricate a trajectory that simulation did not publish;
- treat an aimed destination as an actual interception point;
- retarget a flight to a failed contact;
- invent a deflection for an untouched block;
- terminate a flight without updating its physical duration consistently;
- publish/draw an outgoing trajectory for a contact that never occurred.

The known ace/failed-reception `outgoing_trajectory` case should be investigated/fixed as a small independent authority bug, not used to justify broad movement architecture.

---

# 2D and 3D

Do not assume one renderer's defect proves the other's.

## 3D

Already has per-leg `seconds` timing and continuation machinery. The immediate contract fixes above should be tested here first because the current measured issue lives here.

## 2D

`TacticalCourt` already uses the real movement model to build paths, but historically normalises the sampled time axis to 0–1. That discards natural traversal timing.

After the current 3D contract work is verified, remove/reconcile that normalization so 2D consumes the same physical movement authority rather than independently pacing the same path.

Do not implement a separate 2D movement physics solution.

---

# Required acceptance fixtures

Use deterministic fixtures / reproducible seeds. At minimum:

1. `SERVE -> RECEPTION` requiring meaningful receiver movement.
2. `SERVE -> RECEPTION` with little/no receiver displacement.
3. `ATTACK -> BLOCK -> DIG` where the floor defender begins moving before the block event and continues the same journey through it.
4. Failed dig / beaten defender: playback must not show successful arrival at the ball.
5. `RECEPTION -> SET`: setter releases/chases while the pass develops.
6. `SET -> ATTACK`: hitter transition/approach overlaps the set flight.
7. `ATTACK -> BLOCK`: blockers close/jump on their own timing.
8. Attack coverage with multiple off-ball players.
9. Previous attacker landing/recovering while the next play develops.
10. Long rally with several simultaneous off-ball movements.
11. A player who arrives early and visibly waits.
12. A player who cannot complete the tactical movement before the next contact and therefore carries the unfinished journey forward.
13. A terminal ball landing with no hang/snap.
14. A failed reception/ace that publishes no phantom playable outgoing trajectory.

---

# Core invariants

Where applicable:

```text
simulation outcome is unchanged by presentation-only contract additions
same seed => same rally decisions and authoritative physical facts
ball contact point == authoritative ball position at contact time
contact actor root is physically compatible with contact at that time
movement cannot begin before legitimate cognition/read time
movement endpoint belongs to the same journey as its pacing budget
truncated movement reaches its published truncated endpoint by its deadline
untruncated movement may arrive early
no player leg is consumed twice
no player leg is silently dropped at an intermediate semantic event
no playback system invents a target, trajectory, duration, or contact the simulator did not authorize
playback speed changes viewing rate only, not simulation-time relationships
2D and 3D ultimately consume the same physical movement semantics
```

Add targeted tests before broad migration rather than relying only on total suite count.

---

# Non-goals

Do not use this work to:

- retune serve arcs merely because they look odd if playback matches them;
- change rally outcomes just to make animation easier;
- move contact points cosmetically;
- clamp actor motion visually while leaving simulation/contact elsewhere;
- add a second movement physics model inside presentation;
- force every locomotor action into semantic `RallyEvent`s;
- serialize naturally overlapping volleyball actions;
- require one Tween per player;
- hide pose/root snaps by corrupting movement timing;
- promote gated continuous reception machinery wholesale before the ordinary movement contract is corrected and measured.

---

# Implementation discipline

1. Measure the current case before changing it.
2. State which authoritative fact is missing/ambiguous.
3. Add or repair that fact at the simulation boundary.
4. Make playback consume it without reinterpreting it.
5. Prove outcomes are unchanged unless the simulation itself was wrong.
6. Re-render.
7. Classify remaining defect as one of:
   - simulation physics/decision wrong;
   - authority contract incomplete/ambiguous;
   - playback ignores/misreads authoritative data;
   - pose/action track wrong;
   - calibration/aesthetic issue despite faithful playback.

Avoid solving a visual symptom before identifying which category it belongs to.

---

# Success condition

The target is not “no visible bugs in one rally.”

The target is:

> **Playback cannot contradict or invent the physical journey of the ball or any player when the simulator has already resolved that journey.**

Once that is true, remaining visible defects should be local pose/animation/calibration problems rather than recurring simulator→playback continuity failures.
