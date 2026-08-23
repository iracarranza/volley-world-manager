# 04 — Source and migration map

This map is intentionally **specific enough to accelerate repo work but not so brittle that it prescribes line numbers**. It is pinned to `6ce8f3b` and must be verified if HEAD moves.

## 1. Primary orchestration

### `scripts/simulation/rally_simulator.gd`

Expected role at pinned base:

- owns the high-level rally resolve sequence;
- owns `rally_clock` advancement / event timing integration;
- builds/threads phase state;
- calls responsibility, movement, contact, attack, block and transition systems;
- stores live positions/velocities/facing/recovery between phases;
- contains the first-ball reception→set path and transition loops;
- contains `_spatial_setter_choice` and platform-contact routing helpers;
- bridges physical contact outputs into events/history.

Migration rule:

- orchestration may choose **when** an authority is called and route its result;
- it should not duplicate the physical relation owned by a specialized module;
- when a helper in this file answers a physical question already owned elsewhere, M6 should converge it rather than create a third answer.

High-risk searches before changing first-ball/transition logic:

- `_spatial_setter_choice`
- `_reception_pass_result`
- `_physical_platform_dig_result`
- `_physical_second_contact_choice`
- `incoming_pass_trajectory`
- `set_contact_height_meters`
- `authoritative_free_flight`
- `realised_segment` / realised-prefix metadata
- `rally_clock`
- `player_recovery`
- `live_positions`
- `live_velocities`
- `player_facing`
- phase-target / movement-plan publication

## 2. Feature gates

### `scripts/simulation/rally_feature_flags.gd`

Relevant pinned-base production states:

- physical dig/coverage platform authority: on;
- physical reception: off, development path available;
- geometric attack: production authority already active;
- several older continuous/shadow/live rollout flags remain in the tree.

Migration rule:

- a flag documents rollout authority; it must not become a permanent second architecture;
- after a replacement is production-certified, determine whether its legacy flag/path still serves a live paired comparison;
- remove dead rollout machinery in B6/D cleanup only when it no longer protects an active validation protocol.

A first-draft completion pass should leave the production path unambiguous even if development comparison switches remain.

## 3. Platform contact

### `scripts/simulation/platform_contact_model.gd`

Authority:

- shared T1–T3 platform contact relation;
- feasible platform launch selection/execution from incoming ball + body/contact + intent/circumstance.

Must remain shared by:

- reception;
- controlled dig;
- coverage.

Do not move T1–T3 implementation into `rally_simulator.gd` or create family copies.

### Related intent / contact records

Search current types/records used to publish platform context and launch identity. Preserve the separation between:

- intent anchors / intended recipient;
- selected feasible launch;
- realised launch;
- later interception.

If current records overload these concepts, extend or clarify the existing semantic owner instead of adding parallel dictionaries with duplicate facts.

## 4. Free flight and interception

### `scripts/simulation/free_flight_interception_system.gd`

Authority:

- the free flight after an outgoing launch;
- same-side interception opportunity/resolution;
- realised prefix ending at the actual physical interaction;
- truthful floor/crossing outcomes within its contract.

### `scripts/simulation/overpass_action_system.gd`

Authority:

- receiving-side ordinary first-contact choice after a legal crossing/overpass;
- should consume the actual crossed ball rather than fabricate a replacement feed.

Migration rule:

Any M6 path that already has an authoritative launch and still chooses a future endpoint/recipient before querying free flight is a candidate authority violation.

## 5. Ball models / kinematics

Expected relevant files include:

- `scripts/models/ball_flight.gd`
- `scripts/models/ball_trajectory.gd` if still current in the path;
- `scripts/models/ball_contact_signature.gd`
- `scripts/simulation/rally_kinematics.gd`
- geometric resolver/flight modules used by serve and attack.

Authority rule:

- launch state belongs to contact physics;
- flight queries belong to ball physics;
- realised segment is derived from that flight;
- event/history records may reference/copy authoritative state but must not independently solve it.

When two trajectory-shaped records exist, classify whether one is:

1. free flight;
2. realised segment;
3. estimate/perception;
4. presentation geometry.

Do not treat them as interchangeable merely because their fields look similar.

## 6. Serve / attack physical authority

Expected relevant systems:

- `scripts/simulation/geometric_attack_resolver.gd`
- attack course/power/swing models;
- serve launch/forward-serve machinery called by the resolver.

M6 disposition:

- serve: certified forward contact; audit only;
- attack: structurally certified; audit only unless a demonstrated duplicate/stale derivation is found.

Search leads from existing source comments:

- stale hit-type-dependent derivations;
- delivered vs estimated set-quality reads;
- multiple launch/trajectory representations;
- any legacy outcome scalar that still influences physical endpoint after geometric resolution.

Do not use these comments as an instruction to tune the attack distribution.

## 7. Set / setter movement

Expected relevant systems:

- `_spatial_setter_choice` in `rally_simulator.gd`;
- `scripts/simulation/setter_capability_system.gd`;
- `scripts/simulation/set_path_read_model.gd`;
- live/shadow setter integrators still present in the rollout architecture;
- set geometry/biomechanics modules used for posture and outgoing ball.

A0/A1 searches:

- pass destination used as setter contact;
- pass-authored `set_contact_height_meters`;
- expected release target vs realised interception;
- head-start distance already covered;
- allotted movement duration;
- actual interception time;
- setter arrival margin;
- hardcoded transition-set windows.

M6 target:

```text
real incoming ball
+ actual setter state
+ set intent/choice
→ feasible/executed set contact
→ one outgoing set ball
```

Do not merge expected/perceived path state with realised input merely to reduce parameters.

## 8. Player movement / physical state

Expected relevant systems:

- `scripts/simulation/rally_movement_system.gd`
- locomotion model(s) it calls;
- `scripts/simulation/rally_state_builder.gd`
- rally player/state models;
- contact envelope / readiness systems used by shadow/live contact feasibility;
- approach mechanics;
- coverage calculator where movement reach is used.

Known current architectural facts:

- phase `RallyState` objects are rebuilt;
- live position/velocity are carried outside those phase objects;
- player recovery/body state is carried and seeded back into new phase actors;
- facing is carried when an establishing movement form changes it;
- existing continuity plumbing is certified.

M7 migration direction:

- extend persistent action/timeline truth around those existing state carriers;
- do not replace certified recovery/body carry with a new monolithic actor simulation unless controlled evidence shows the current state ownership cannot support the target.

## 9. Off-ball intentions / phase targets

Expected logic currently lives partly inside `rally_simulator.gd` and existing formation/assignment systems.

Known existing phase-map concepts from `OFF_BALL_MOVEMENT.md`:

- receive formation map;
- transition map;
- approach starts;
- cover map;
- base/release responsibilities;
- `_reached_point` / existing movement traversal.

M7 rule:

The resolver already computes many useful **where** targets. Preserve their tactical/role basis, then make the **why + when** survive long enough to drive overlapping continuous action.

Do not let playback invent missing off-ball targets.

## 10. Approach / hitter state

### `scripts/simulation/approach_mechanics_system.gd`

Expected authority:

- approach mechanics / timing / prepared hitter state.

M7 target:

The hitter's approach begins during the preceding set flight (or earlier planning where governed), and contact samples the resulting hitter state. Do not represent “approach” as a movement animation started only when the ATTACK event begins.

Audit any separate movement-speed model used by approach versus ordinary traversal. Existing source comments already identify historical divergence between locomotion models; first-draft work should converge authority only when the governing existing relation is sufficient, not by adding another speed ceiling.

## 11. Block preparation

Expected systems:

- block shadow/live integrators;
- block biomechanics/geometry;
- defensive plan / blocker assignment state;
- movement/recognition timing in the resolver.

M7 target:

Blockers begin reading/closing before attack contact. Their contact state must be the consequence of earlier recognition/commit/close actions, not a state instantiated at the block event.

Keep the current block interaction physics closed unless M6 proves an authority break.

## 12. Diagnostics and tests

### `tests/test_runner.gd`

Role:

- permanent regression/invariant suite plus historical assertions accumulated during migrations.

Migration rule:

When a test fails after an authority move:

1. state the semantic assertion in words;
2. determine whether that assertion is still valid;
3. if valid, fix implementation;
4. if obsolete, replace it with the equivalent invariant under the new authority;
5. never delete/widen solely because the implementation is inconvenient.

### `tools/`

Known relevant instruments include:

- reception rollout probe;
- platform dig/coverage probes;
- free-flight/overpass fixtures;
- actor continuity probe;
- movement-agreement / timing probes;
- rally balance/symmetry probes;
- canonical playback/timing diagnostics.

A tool is evidence infrastructure, not gameplay authority.

## 13. Presentation

Expected consumers include match playback / `scenes/main/main.gd` and cognition/presentation systems.

M7 may require presentation to consume new continuous action data, but the simulation must publish it first.

If the engine knows an actor arrived early and waited, presentation may draw the traversal then wait. Presentation may not slow the traversal until it fills the entire flight.

## 14. Migration checklist for any legacy endpoint-authored path

Apply this template wherever B0 finds the old pattern:

```text
OLD
contact/result classification
→ chosen future destination/recipient
→ synthetic trajectory to that destination
→ downstream assumes destination occurred

TARGET
intent / choice
→ physical contact
→ one outgoing launch
→ free flight / interaction
→ realised next state
→ classification
```

Checklist:

- [ ] intended target retained only as intent/planning where still useful
- [ ] one launch owner
- [ ] free flight exists without knowing next actor
- [ ] actual actor from physical/legal resolution
- [ ] realised prefix available to next contact
- [ ] event/history consumes realised state
- [ ] legacy endpoint no longer owns production physics

## 15. Map-maintenance rule

If current source differs from this map:

- prefer actual newer implementation location;
- preserve packet semantics;
- update the map if the difference is material;
- do not alter working code merely to make filenames match this document.
