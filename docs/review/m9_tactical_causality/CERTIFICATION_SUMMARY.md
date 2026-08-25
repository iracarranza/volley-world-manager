# M9 tactical causality certification summary

The shared workspace initially opened on concurrent presentation HEAD `4df1cfd02536629951b0055bff3a7916ed7a45de`. M9 implementation and the BEFORE census are instead rooted, as required, at accepted M8 baseline `8bd62f028fcebbbfb1dd81fc949b645a9070c5eb`. The executable census corrects the packet's coincidentally-39-row audit: `fallback_lane` and `secondary_hitter_id` are latent/derived values, not independent selectors, while second-setter selection and the separately editable floor-zone fields are real selectors.

Before: **28 CAUSAL / 8 PARTIAL / 3 STORED_ONLY / 0 DEAD / 0 AMBIGUOUS** across 39 reachable families. After: **39 CAUSAL / 0 PARTIAL / 0 STORED_ONLY / 0 DEAD / 0 AMBIGUOUS**.

The machine-readable source of truth is `artifacts/m9-tactical-causality/{before_census.json,after_census.json,certification.json}`. `tools/run_m9_tactical_causality.gd` hard-fails zero-population gates and runs live Clipboard trials through `GameManager.resolve_active_rally()` for both teams. Its final 240 gates include paired C7 distributions: 9+ line/cross attack activations, 8+ close-line/cross block activations, 72 matched floor targets, and 200 adherence observations.

## Final causal chains

Every row ends in the existing M8 movement, reach, contact, block-contest and trajectory authority. “Target” below is always intent; it never teleports a body or forces a contact/outcome.

| ID | Selection → authoritative store | Consumer → decision/physical mediator | Evidence and interaction |
|---|---|---|---|
| `offense.lane` | five lanes → `HitterAssignment.lane` | setter option/target → approach lane and set flight | existing offensive differential tests + M9 C0/C1; composes with tempo/start |
| `offense.tempo` | T0–T3 → `HitterAssignment.tempo` | setter capability/timing → set arc and approach/block window | existing tempo/approach gates + M9 C1 |
| `offense.responsibility_order` | Primary/Secondary/Option/Decoy → play IDs, priority, `is_decoy` | `_choose_assignment` orders feasible options and excludes decoys | M9 exact round trip; existing setter-decision terms; feasibility wins conflicts |
| `offense.attack_start` | dragged point → `start_position` | `ApproachMechanicsSystem.project_toward` → reachable runway mark | M9 C1 + source trace; live movement means no teleport |
| `offense.called_play` | called saved play per rotation → GameManager IDs | immutable handoff → selected assignment set | M9 C2 manifest + existing called-play tests |
| `system.setting` | 5-1/6-2 → lineup | `active_setter_id` → setter identity and route | M9 C1 + lineup legality tests |
| `system.second_setter` | eligible player → designated setter IDs | 6-2 back-row selection → contact actor | M9 C1; legality remains authoritative |
| `serve.target` | four targets → plan | shared serve decision → aim point/outgoing flight | serve event `called_target/target/aim_point`; existing serve probes |
| `serve.risk` | slider → plan | called/effective risk → mode, pace and error judgment | serve event `called_risk/effective_risk`; principles compose, not overwrite |
| `receive.center` | dragged centre → receive zone | claimant/movement → receiver intent/arrival | existing spatial-reception gates + M9 C1 |
| `receive.radius` | radius → receive zone | claimant eligibility → reach opportunity | typed zone round trips + existing zone tests |
| `receive.priority` | P0–P3 → receive zone | claim weighting → receiver identity | typed zone round trips + existing claimant tests |
| `receive.enabled` | toggle → receive zone | candidate filter → passer availability | typed zone round trips + existing claimant tests |
| `receive.setter_release` | dragged point → plan | reception/setter handoff → pass target and setter route | manifest + existing release-target tests |
| `block.strategy` | Read/Commit Pin/Commit Middle → plan | shared formation timing → close budget/wall | C1 + existing block strategy probes; opponent optional plan uses same path |
| `block.participation` | toggle → assignment | shared candidate filter → bodies offered to wall | C1 + block formation telemetry |
| `block.seam_responsibility` | four labels → assignment | `block_formation_target` + `defensive_target` → distinct wall/floor seam points | M9 C6 four-way geometry, both sides |
| `floor.system` | three systems → plan | floor base/zone builder → defensive shape | C1 + existing floor-system tests |
| `floor.position` | dragged point → plan/zone | `_floor_phase_positions` → live movement intent | C1 + tactical attribution physical target |
| `floor.radius` | radius → floor zone | floor claimant eligibility → dig opportunity | typed zone round trips + existing floor tests |
| `floor.enabled` | toggle → floor zone | candidate filter → defender availability | typed zone round trips + existing floor tests |
| `floor.priority` | P0–P3 → floor zone | claim weighting → defender identity | typed zone round trips + existing floor tests |
| `block.defense_relationship` | Balanced/Line/Cross → plan | wall/coverage focus → lane geometry | C1 + existing block/floor traces |
| `floor.depth` | Shallow/Balanced/Deep → plan | phase positioning → y target | C1 + existing depth tests |
| `floor.short_posture` | Standard/Compress → plan | phase positioning → short-ball compression | C1 + existing posture tests |
| `duty.base` | four labels → assignment | `defensive_target` → four distinct support points | M9 C6 four-way target proof |
| `duty.short_ball` | four labels → assignment | `defensive_target` → four distinct tip/roll/no-duty points | M9 C6 four-way target proof |
| `duty.short_priority` | P0–P3 → assignment | short-ball claimant → defender choice | C1 + existing short-ball tests |
| `duty.emergency_pursuit` | toggle → assignment | deflection candidate filter → pursuit/recovery | C1 + existing pursuit probes |
| `duty.emergency_responsibility` | four labels → assignment | shared second-contact and coverage scores → setter/coverer preference | M9 C6 proves all four distinct in both selectors; reachability remains decisive |
| `duty.attack_coverage` | four labels → assignment | `_resolve_attack_coverage` → coverer/transition choice | C1 + existing coverage events |
| `duty.deflection_priority` | P0–P3 → assignment | pursuit/coverage score → pursuer | C1 + existing deflection tests |
| `duty.second_contact` | four labels → assignment | emergency-setter selectors → contact actor/attack availability | C1 + existing second-contact probes; composes with emergency responsibility |
| `clipboard.block` | close line/cross, soft/kill → identity-routed sheet | geometry call or hands intent → wall target or shared block contest | live home/opponent activation for all four + C6 geometry |
| `clipboard.attack` | line/cross/tool/roll/feint → identity-routed sheet | attack action/course adapter → shot choice/target/trajectory | live home/opponent activation for all five; no-wall tool publishes override |
| `clipboard.floor` | line/cross/tip/chase → identity-routed sheet | floor adapter → defender physical target | live home/opponent activation for all four + distinct-target gate |
| `clipboard.placement` | per-player point → identity-routed sheet | normalized placement → approach/floor movement intent | round trip/identity/negative off-court gates; no teleport |
| `clipboard.net_priorities` | four P0–P3 weights → sheet | floor adapter → composed lane/tip pull | four-way C6; historical `[3,2,1,2]` is migration-neutral |
| `training.drill_zone` | Line/Seam/Cross/Tip → sheet | `DrillSession.from_tactic_sheet` → training activity/focus | persisted C1 and existing drill tests; intentionally training-only |

## Root seams repaired

- Clipboard state is now owned by `Team.to_dict/from_dict`; reload no longer erases it.
- Tray indices, rotation slots and player IDs are no longer conflated. Match consumers route calls and placements through the saved `who` identity, with a legacy slot fallback.
- GameManager captures an immutable pre-resolve manifest. Clipboard phase/view are excluded as editor lenses.
- A pure tactical intent adapter supplies attack choice, block geometry, floor geometry and emergency preferences to existing authoritative systems.
- Home and optional opponent policy now enter the same attack, block, floor and serve consumers. Neutral AI differences remain selected/default policy, not different physics.
- Assignment order/Secondary and authored approach starts now reach existing setter/approach seams.
- Every defensive responsibility label has a distinct decision or geometric meaning.

## Interaction and adversarial findings

- Order is explicit: authored base/placement → match-board responsibility → Clipboard floor behaviour → relative net-priority pull → ordinary movement/reach. Terms compose; none is last-write-wins.
- Block close line/cross changes wall geometry; soft/kill changes hands intent. Seam responsibility composes after the close call. These are intentionally separate axes.
- Attack behaviour is chosen before capability judgment. A poor set/run-up can downgrade or defeat the call; tool with no wall reports `no block available to tool` and leaves the action unchanged.
- Emergency responsibility contributes to both second-contact and coverage decisions, while the dedicated second-contact/coverage duty remains the stronger semantic axis.
- Phase/view changes and instructions for an off-court identity leave the authoritative rally trace unchanged (the input receipt itself correctly differs for the off-court authoring case).
- Historical front/back responsibility combinations and `[3,2,1,2]` net priorities are migration-neutral; choosing a different label/weight produces the certified relative target change.
- Live gates report populations separately. The final run exercised every Clipboard option on both `home` and `opponent`; no zero-population result can pass.

Balance tuning remains outside M9. The new magnitudes are decision/geometry preferences and were not fitted to kill, stuff, dig, side-out or win-rate targets.

Two excluded schema values remain explicit rather than being made artificially causal: `block_intent` is materially consumed but has no production writer and needs an ownership decision; `fallback_lane` is serialized/validated but never read by live gameplay. See `LATENT_FIELD_AUDIT.md`.
