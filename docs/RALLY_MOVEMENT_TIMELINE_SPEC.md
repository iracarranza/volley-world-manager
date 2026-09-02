# Rally Movement Timeline — Investigation Record + Implementation Spec

**Reference commit investigated:** `f625ff3ef8c5137f425e2479bf4f6daec9a75160`

## Purpose

Compact handoff preserving the questions, answers, rejected hypotheses, examined alternatives, repo findings, and proposed fix.

**Core conclusion:** do not turn every locomotor action into a semantic `RallyEvent`. Preserve resolved player movement as a first-class timed rally output, then have playback sample ball + players from one authoritative rally clock. Reception is the first migration/acceptance case, not a special-case patch.

## Investigation trail: questions → answers

**Q: Why does spike reception look like the ball travels to a hypothetical dig point, then the receiver snaps into dig posture?**  
A: Initial suspicion was that movement occurred only after ball arrival. That was not sufficiently supported.

**Q: Do the animation strips prove runtime scheduling is wrong?**  
A: No. The strips are staged pose sweeps; they support the visual symptom but do not prove live-rally timing.

**Q: Does the repo already move the upcoming receiver during ball flight?**  
A: Yes. `TacticalCourt.animate_spatial_transition(ball_event, next_contact_event, duration)` prepares the next contact actor and unit support movement during the preceding trajectory. Therefore “no anticipatory receiver movement exists” is false.

**Q: Does off-ball movement exist?**  
A: Yes, substantially. Presentation has per-player starts, targets, optional waypoints, sampled movement paths, live positions, resolver phase positions/targets, and continuity checks.

**Q: What weakness remained plausible?**  
A: Temporal grouping. Players have individual spatial paths, but `TacticalCourt` drives participating paths with one `playback_progress`/`playback_tween` over the containing phase. Spatial independence exists; temporal independence is limited.

**Q: Should every movement therefore be an independent RallyEvent?**  
A: Probably not. `RallyEvent` is useful as the semantic volleyball record (serve/reception/set/attack/block/dig). Turning every shuffle, transition, approach, landing, and recovery into RallyEvents would pollute that stream and still leave arbitrary movement boundaries.

**Q: How does simulation itself represent time?**  
A: `RallyScheduler` orders `RallyMoment`s by absolute time. `RallyMoment.Kind` includes `PERCEPTION`, `MOVEMENT_UPDATE`, opportunity boundaries, `BALL_CONTACT`, `BALL_LANDING`, and `RECOVERY_COMPLETE`. This is a lower-level timed mechanism distinct from semantic RallyEvents.

**Q: Is MOVEMENT_UPDATE already a global authoritative movement timeline?**  
A: No. Important correction: the concrete continuous use inspected is reception opportunity evaluation. It operates on a snapshot/shadow state and returns evidence; it does not globally mutate authoritative rally state.

**Q: Does reception simulation actually model movement during flight?**  
A: Yes. `evaluate_reception_timeline` schedules `PERCEPTION + MOVEMENT_UPDATE` across inter-read gaps. `MOVEMENT_UPDATE` uses `ShadowMovementSystem.integrate()`, which samples the real movement model through time while respecting perceived information rather than omniscient ball truth.

**Q: What happens when the chosen reception becomes official?**  
A: `LiveReceptionIntegrator` promotes the selected receiver’s arrival state/velocity and advances authoritative state to contact time. The detailed traversal that established feasibility is not preserved as the canonical replay path.

**Q: So what is the deeper seam?**  
A: Continuous movement is calculated as simulation evidence, then largely collapsed at the promotion/result boundary. Playback later reconstructs physical history from semantic events/endpoints/phases.

**Q: Could the reception snap instead be only a pose/root-animation issue?**  
A: Still possible as a secondary defect. Position timing and pose timing must be diagnosed separately. The architecture fix must not assume every visible snap comes from locomotion alone.

**Q: Could `movement_target` / `event.start_position` be wrong?**  
A: Also a possible local contributor. Existing playback can use `movement_target` or `event.start_position`; bad endpoint semantics could worsen reception. The generalized architecture should preserve authoritative simulator positions so presentation does not invent them.

**Q: Could `arrived_via_transition` cause duplication or suppression errors?**  
A: Yes; it is part of the current handoff between preceding-flight movement and event-local movement. Migration must ensure a journey is consumed exactly once and eventually reduce/remove this ownership ambiguity.

**Q: Is the correct abstraction “one Tween per player”?**  
A: No requirement. The requirement is independent physical-time intervals/tracks. A single shared rally-clock sampler is cleaner and deterministic.

**Q: Should presentation use resolver future knowledge to start movement immediately?**  
A: No. Simulation may know the final rally, but the voli may act only after legitimate perception/cognition. Movement traces must preserve cognition/read timing.

**Q: Is reception unique enough for a special fix?**  
A: Use it as the first vertical slice because continuous pursuit already exists there. Do not special-case it unless evidence proves genuinely reception-specific semantics.

## Cases and causes examined

Potential causes investigated or retained for validation:

- no off-ball movement — **rejected**;
- receiver movement starts only after ball flight — **rejected as a general description**;
- shared phase-relative playback timing — **supported as a presentation limitation**;
- continuous simulator movement discarded at promotion/result boundary — **strongly supported for reception**;
- wrong `movement_start` / `movement_target` / contact endpoint semantics — still possible locally;
- `arrived_via_transition` duplicate/suppressed movement — still requires migration validation;
- dig pose begins only at contact and creates apparent root/COM snap — possible secondary issue;
- 2D `TacticalCourt` vs 3D actor presentation mismatch — distinguish in visual validation;
- movement path normalized to allotted phase rather than natural traversal time — known presentation concern;
- cognition and locomotion clocks disagree — cognition already uses physical rally time, while movement presentation is more phase-relative;
- support/off-ball destinations may exist without authoritative independent timing — expected migration gap.

## Architecture decision

Resolved rally should expose two complementary records:

1. **RallyEvents** = semantic volleyball actions/results.
2. **PlayerMovementTraces** = authoritative physical traversal through simulation time.

> Playback must not reconstruct physical movement from RallyEvents when simulation has already resolved that movement.

## Movement trace contract

Introduce/adapt a compact `PlayerMovementTrace`-like record:

- `side`, `player_id`
- `start_time`, `end_time`
- `start_position`, `end_position`
- timed samples: `time`, `position`, `velocity`
- `movement_mode` / `intent`
- source event/phase reference
- `cognition_not_before` where relevant
- optional contact event/time anchor
- `reached_target` / completion evidence

Exact names should follow repo architecture.

This is simulation evidence, not animation instruction: no easing, playback-speed duration, pose styling, or UI captions.

## Reuse existing physics

Do not create a second locomotion model. Generalize/promote proven machinery around `RallyMovementSystem.project_toward()` and `ShadowMovementSystem.integrate()`. Preserve speed, acceleration, mass/fatigue effects, direction-change cost, waypoints, carried velocity, and deterministic sampling.

The selected official movement trace must correspond to the same physical traversal/evidence that made the official action feasible. Playback must not recompute a cosmetically similar path.

## Reception first vertical slice

For `ATTACK → DIG` and `SERVE → RECEPTION`:

1. Preserve the selected receiver’s perception-driven pursuit as an official timed trace.
2. Preserve target changes caused by later reads.
3. Attach absolute simulation times to samples.
4. Promote the trace alongside the official reception result.
5. Playback samples it during incoming ball flight.
6. Do not also replay the same movement through old event-local/transition movement.
7. Contact remains the synchronization anchor.
8. Diagnose pose/root snapping separately after positional trace playback is correct.

## Shared rally clock

At rally time `t`:

```text
ball_position = authoritative ball trajectory sampled at t
P1_position   = P1 movement track sampled at t
P2_position   = P2 movement track sampled at t
...
```

Different players may start/end movement at different times during the same ball flight. Playback speed changes wall-clock viewing speed only; it must not alter simulation-time relationships.

## Position vs pose

Keep physical position and action pose separate.

- Physical track: **where is the player?**
- Pose/action track: **what is the player doing?**

A receiver can move, lower, establish platform, contact, and recover without the pose system being allowed to teleport the authoritative root position. A locomotion fix must not hide a remaining pose-transition defect.

## Contact invariants

At every resolved contact time `T`:

- ball is at authoritative contact point;
- actor physical track is at authoritative player/contact position;
- required movement is complete or in the exact resolved contact state;
- pose/contact phase is synchronized;
- blockers/contact participants synchronize to the same physical time.

Contacts are synchronization anchors, not start signals for all movement associated with an event.

## Off-ball migration

Generalize the same representation to setter release, hitter transition/approach, block close/jump, defensive shifting, attack coverage, landing, recovery, and emergency pursuit.

Existing resolver phase positions/targets remain useful inputs where full timing is not yet authoritative. During migration, legacy phase movement may remain only for players/actions without official traces. Never let legacy and trace systems move the same player over the same interval.

## Implementation sequence

1. Define movement-trace output contract.
2. Identify where selected shadow/continuous traversal can be promoted without changing outcomes.
3. Reception first: preserve official pursuit trace.
4. Expose traces in resolved rally result.
5. Add shared rally-clock sampling in 2D playback.
6. Disable legacy movement ownership for traced receiver.
7. Validate displaced `ATTACK → DIG`.
8. Validate little/no-displacement DIG and `SERVE → RECEPTION`.
9. Separate/fix any remaining dig-pose root snap.
10. Extend to setter movement.
11. Extend to hitter transition/approach.
12. Extend to block movement.
13. Extend to general support/defensive movement.
14. Retire shared unit-wide `playback_progress` as movement authority once coverage is sufficient.
15. Simplify `arrived_via_transition` / event-local pre-movement where superseded.

## Acceptance fixtures

Required deterministic fixtures:

- `ATTACK → DIG` requiring displacement.
- `ATTACK → DIG` with little/no displacement.
- `SERVE → RECEPTION`.
- `RECEPTION → SET`: setter can release while pass develops.
- `SET → ATTACK`: hitter staging/approach overlaps set flight.
- `ATTACK → BLOCK`: block close/jump synchronizes with attack.
- `DEFLECTION → emergency pursuit`.
- Previous attacker landing/recovering while next play develops.
- Long rally with several simultaneous off-ball transitions.
- Multi-player fixture proving different movement start/end times within one ball leg.

## Test invariants

Where applicable:

```text
start_time >= cognition_not_before
start_time < end_time
end_time <= required_contact_time
position(end_time) == authoritative target
sampling mid-flight changes position when displacement is required
no unintended overlapping physical ownership for same player
movement consumed exactly once
same seed => identical RallyEvents, ball trajectories, and movement traces
skip playback => coherent final state
playback speed => same simulation relationships
```

For `ATTACK → DIG` specifically prove:

```text
attack_time < receiver movement interval <= dig_time
```

and receiver position changes before dig contact.

## Non-goals / prohibitions

Do not:

- change rally outcomes to make playback look correct;
- move authoritative contact points;
- re-resolve decisions in presentation;
- add generic cosmetic lerps over resolved physics;
- grant future knowledge before cognition permits reaction;
- serialize independent actions merely because RallyEvents are sequential;
- create one Tween per player as an architectural requirement;
- keep two competing systems moving the same player over the same interval;
- promote every locomotor action into semantic RallyEvents.

## Target architecture

```text
Simulation resolves:
    semantic RallyEvents
    ball trajectories
    player movement traces
            ↓
      one rally clock
            ↓
        playback
```

**Guiding rule:** playback may interpolate authoritative simulation evidence; it must not reconstruct physical movement from semantic RallyEvents when the simulator has already resolved that movement.

## Codex investigation requirement before broad refactor

Before implementing beyond reception, trace one deterministic `ATTACK → DIG` numerically:

- attack contact time;
- ball trajectory duration;
- perception/read times;
- receiver source position/velocity;
- each selected pursuit segment/sample;
- promoted arrival position/velocity;
- dig contact time;
- RallyEvent `movement_start` / `movement_target` / `movement_duration`;
- TacticalCourt actual movement start/end;
- dig pose onset;
- whether any journey is executed twice or suppressed.

State explicitly which visible defect came from:

A. lost simulator movement timing;  
B. shared presentation phase timing;  
C. wrong endpoints;  
D. duplicate/suppressed ownership;  
E. pose/root transition;  
or a combination.

Then implement the smallest general architecture that preserves authoritative movement evidence.
