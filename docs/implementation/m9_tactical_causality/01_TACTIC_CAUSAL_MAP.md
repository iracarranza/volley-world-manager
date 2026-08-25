# Player-selectable tactic causal map

> Historical trace plus implemented corrections. The tables below preserve the pre-implementation findings; the authoritative 39-row before/after map is `artifacts/m9-tactical-causality/{before_census.json,after_census.json}` and the compact final chain for every row is `docs/review/m9_tactical_causality/CERTIFICATION_SUMMARY.md`.

## Match board — offence and systems

Each row is one independently authored value family; named alternatives share the same consumer.

| Selection (all options) | UI → store | Simulator consumer → decision → physical consequence | Class |
|---|---|---|---|
| Attack lane (`Left Pin`, `Front Quick`, `Right Quick`, `Right Pin`, `Pipe`) | `main.gd` assignment editor → `HitterAssignment.lane` in saved `OffensivePlay` | assignment option/placement and setter selection → set target, approach geometry and attack lane | **causal** |
| Tempo (`T0`–`T3`) | assignment editor → `HitterAssignment.tempo` | setter capability/tempo coordination and set arc → release relationship, flight time, approach availability and block closing time | **causal** |
| Responsibility (`Primary`, `Secondary`, `Option`, `Decoy`) | UI maps Primary/Secondary to play IDs and Decoy to `is_decoy`; ordinary Option remains eligible | `_choose_assignment()` filters decoys and biases primary when following call → hitter chosen / decoy excluded | **causal** (labels collapse to three mechanics; Secondary has no dedicated preference) |
| Assignment priority (`HitterAssignment.priority`) | created/reordered by play editor and serialized | exposed in shadow/assignment facts but official `_choose_assignment()` does not rank by it | **partial** |
| Dragged attack start | editor → `HitterAssignment.start_position` | persisted and visible in preview; official live approach starts from live state/lane geometry, not authored start | **stored-only** |
| Called play per rotation | saved-play control → `active_play_ids_by_rotation` / `called_play_id` | passed to resolver; follow-play path biases primary and supplies assignment set | **causal** |
| Play `fallback_lane` | serialized `OffensivePlay` metadata; **no dedicated player control** | no official consumer | **latent schema; excluded from selectable census** |
| `secondary_hitter_id` | derived from the selectable Secondary responsibility | `_choose_assignment()` now applies its documented fallback preference | **part of Responsibility/order; not an independent selector** |
| Setting system (`5-1`, `6-2`) and selected second setter | system controls → every `RotationLineup.setting_system` / `designated_setter_ids` | `active_setter_id()` selects eligible back-row setter → setter identity, release movement and set execution | **causal** |

## Match board — serve receive and serve

| Selection | UI → store | Simulator consumer → decision → physical consequence | Class |
|---|---|---|---|
| Serve target (`Zone 1`, `Zone 5`, `Short Middle`, `Weak Passer`) | defensive editor → `DefensivePlan.serve_target` | home serve decision → aim region/selected opponent target → authoritative serve trajectory and reception context | **causal** |
| Serve risk (0–100%) | slider → `DefensivePlan.serve_risk` | home serve decision/error/quality → error probability, pace/trajectory quality and receiving pressure | **causal** |
| Reception-zone centre | dragged zone → `DefensiveZone.center` | state builder/coverage claimant → receiver intent, arrival and reception candidate | **causal** |
| Reception radius | zone editor → `radius_meters` | coverage arrival/claim eligibility → receiver choice and arrival margin | **causal** |
| Reception priority (0–3) | zone editor → `priority` | movement/coverage claimant weighting → receiver intent/claim | **causal** |
| Reception enabled | zone editor → `enabled` | coverage candidate inclusion → passer availability and receiver selection | **causal** |
| Setter release target | independent drag → `setter_release_targets[player_id]` | reception/setter handoff and continuation paths → pass target, setter route/contact location | **causal** |

## Match board — block and floor/transition

| Selection | UI → store | Simulator consumer → decision → physical consequence | Class |
|---|---|---|---|
| Block strategy (`Read Block`, `Commit Pin`, `Commit Middle`) | editor → `DefensivePlan.block_strategy` | shadow and official block formation → precommit lane/closing budget → wall location/close quality | **causal** |
| Block participation | defender popup → `DefensiveAssignment.block_participation` | home block candidate filter → bodies offered to wall | **causal** |
| Seam responsibility (four labels) | defender editor → `seam_responsibility` | inside-seam formation adjustment and defensive fit → blocker/defender target and contact fit; not every label has a distinct branch | **partial** |
| Floor preset (`Perimeter`, `Rotation Defense`, `Middle-Up`) | preset applies `floor_system`, defender positions and zones | defender bases/zone geometry plus system fit term → arrival/claim/contact fit | **causal** |
| Floor-zone centre / defender position | drag → zone centre and `defender_positions` | state construction, movement and dig targeting → starting/intent position and arrival | **causal** |
| Floor radius / enabled / priority | zone editor → `floor_defense_zones` | coverage/movement consumers → candidate reach/intent and claim weighting | **causal** |
| Block–defence relationship (`Balanced`, `Defend Line`, `Defend Cross`) | editor → plan field | block/defence formation helpers → wall/coverage lane targets | **causal** |
| Defensive depth (`Shallow`, `Balanced`, `Deep`) | editor → plan field | home dig positioning/defence instructions → target depth and arrival geometry | **causal** |
| Short-ball posture (`Standard`, `Compress Short`) | editor → plan field | home dig positioning → compressed target depth for short balls | **causal** |
| Base responsibility (four labels) | defender editor → assignment | defensive fit/system matching; some strings only affect summary unless paired with matching system | **partial** |
| Short-ball duty (four labels) | defender editor → `short_ball_responsibility` | short-tip fit checks only recognise strings containing `Tip`; other options are not distinct decisions | **partial** |
| Short-ball priority (0–3) | popup → assignment | short-tip defensive fit → contact candidate quality | **causal** |
| Emergency pursuit toggle | popup → assignment | pursuit/free-flight and approach readiness paths → candidate participation and transition debt | **causal** |
| Emergency responsibility (four labels) | editor → assignment | persisted, but no direct simulator read | **stored-only** |
| Attack coverage (four labels) | editor → assignment | coverage target/recovery and approach preparation → movement target and subsequent attack readiness | **causal** |
| Deflection priority (0–3) | popup → assignment | deflection pursuit candidate score → pursuer choice/movement | **causal** |
| Second-contact duty (four labels) | editor → assignment | emergency-setter selection and approach duty → setter candidate and transition availability | **causal** |

`DefensivePlan.block_intent` (`Seal`, `Balanced`, `Funnel`) is already strongly causal in block promotion/contact margins but is **not player-selectable** in the audited UI. M9 must not silently count its default as an implemented choice; a later UI decision requires its own certification row.

## Clipboard tactics and training

Clipboard phase/view are editing lenses, not tactical inputs. Preset names are explicitly placeholder presentation and do not decompose into sheet state, so they are not counted as tactics.

| Selection | UI → store | Consumer → consequence | Class |
|---|---|---|---|
| Per-slot Block behaviour: `soft block`, `kill block` | worksheet → `TacticSheet.behaviours[slot:Block]` | `_hands_instruction_for()` → discipline-mediated hands intent → block contact intent/margins and published followed/ignored call | **causal** |
| Per-slot Block behaviour: `close line`, `close cross` | same | handed to the hands-intent seam, but not interpreted as closing geometry or a hands option | **partial** |
| Per-slot Attack behaviours: `spike line`, `spike cross`, `tool`, `roll`, `feint` | worksheet → persisted sheet | no rally consumer (`behaviour_of(..., "Attack")` absent); drill session only turns phase instructions into generic activities | **partial** overall; **stored-only for match gameplay** |
| Per-slot Floor behaviours: `dig line`, `dig cross`, `cover the tip`, `chase` | worksheet → persisted sheet | no rally consumer (`behaviour_of(..., "Floor")` absent); generic drill activity only | **partial** overall; **stored-only for match gameplay** |
| Per-slot clipboard placement | drag/coordinate entry → `TacticSheet.placements` | generic drill-session zone activity tests only whether any placement exists; rally never reads coordinates | **partial** for training, **stored-only** for match gameplay |
| Net priorities: Line/Seam/Cross/Tip 0–3 | worksheet → `zone_priorities` | no rally or drill consumer | **stored-only** |
| Circled drill zone: Line/Seam/Cross/Tip | worksheet → `drill_zone` | `DrillSession.from_tactic_sheet()` selects named zone activity → training focus/session content, not rally | **causal** as training tactic; not a match tactic |

## Implemented correction and totals

The original rows totalled 39 only by coincidence. They included two values without independent selectors, combined independently editable floor-zone fields, and combined setting-system/second-setter selection. The executable UI census resolves those boundaries at **39 reachable families**.

- BEFORE (`4df1cfd02536629951b0055bff3a7916ed7a45de`): **28 causal, 8 partial, 3 stored-only, 0 dead, 0 ambiguous**.
- AFTER: **39 causal, 0 partial, 0 stored-only, 0 dead, 0 ambiguous**.

Implemented changes promote the partial/stored rows as follows: Secondary/priority orders otherwise feasible setter options; authored starts feed physically bounded approach preparation; all seam/base/short/emergency labels have distinct shared decision terms; Clipboard Attack/Block/Floor behaviour and identity-routed placements reach match authority; net priorities compose into floor positioning; and `Team` career serialization owns the sheet. Exact consumers, physical mediators, evidence and interactions for every row are in the linked certification summary and JSON rows.
