# Evidence Ledger

This is a **compact high-value evidence map**, not a second STATUS file and not a historical Gate ledger. Use current source/design/review docs for details.

| Claim | Status | Primary evidence |
|---|---|---|
| Screen navigation/lazy construction is coordinated by the application controller | VERIFIED | `scenes/application.gd` — `_ready`, `_adopt_screen`, `_show_only`, `_ensure_*` |
| VWM UI uses shared Theme/StyleBox + recursive medium styling rather than per-screen appearance copies | VERIFIED | `scripts/systems/ui_style_system.gd`; `scenes/themes/*.tres` |
| `MenuCard` is a real `Button`-derived reusable component whose children do not steal the hit area | VERIFIED | `scenes/components/menu_card.gd` |
| Voli stickers are baked from the real 3D player rig into an off-screen viewport, traced/processed, and cached | VERIFIED | `scenes/components/voli_sticker.gd`; `player_actor_3d.gd` |
| Persistent player identity/ability/body/career data lives on `VolleyballPlayer` Resource rather than UI Nodes | VERIFIED | `scripts/models/volleyball_player.gd` |
| Ability attributes are explicitly separated from temperament/state/reputation fields | VERIFIED | `VolleyballPlayer.ABILITY_ATTRIBUTES` and field comments |
| Generation reuses the player model's position-weight vocabulary and applies fictional region/role/individual shaping | VERIFIED | `scripts/systems/player_generator.gd`; `VolleyballPlayer.POSITION_WEIGHTS` |
| Training uses scheduled activities/regimens and fractional per-attribute progress bounded by ceilings | VERIFIED | `scripts/systems/training_system.gd`; `VolleyballPlayer.training_progress`, `attribute_ceilings` |
| Career state is a persistent Resource and `CareerManager` coordinates creation/calendar/training/save/world behavior | VERIFIED | `scripts/models/career_state.gd`; `scripts/managers/career_manager.gd` |
| World population can be stored separately/lazy loaded instead of embedded in every frequently written career save | VERIFIED | current `CareerManager` / `CareerState` persistence path |
| `RallyEvent` is a resolved action record, not the complete physical rally state | VERIFIED | `scripts/models/rally_event.gd`; current Part IV/source consumers |
| `RallyPlayerState` carries position/velocity/facing/body state/intent/recovery and no longer carries the old unused `readiness` scalar | VERIFIED | `scripts/models/rally_player_state.gd`; `docs/review/READINESS_REMOVAL.md` |
| Actor recovery/body state survives phase reconstruction | VERIFIED | `docs/review/ACTOR_CONTINUITY.md`; live rally state-seeding code |
| Platform body centre can differ from contact point through derived arm/contact geometry | VERIFIED | `docs/review/BODY_CENTRE_SCOPE.md`, `BODY_CENTRE_PROMOTION.md` |
| Reception/dig/coverage platform physics share one T1–T3 model with no event-family physics band | VERIFIED | `scripts/simulation/platform_contact_model.gd`; `docs/review/PLATFORM_AUTHORED_CALIBRATION.md` |
| Current six T1–T3 magnitudes are explicit authored game abstractions, not measured biomechanics | VERIFIED DESIGN AUTHORITY | `platform_contact_model.gd` comments/constants; `PLATFORM_AUTHORED_CALIBRATION.md` |
| T3 internal execution sigma is angular, while recent leverage probe values were downstream spatial error in metres | VERIFIED UNIT AUDIT | active-branch T3 unit correction checkpoint + producer `spatial_error_meters` |
| Successful physical digs can create one authoritative free flight; failed digs emit no replacement ball in development certification | VERIFIED DEVELOPMENT | `docs/review/FREE_FLIGHT_INTERCEPTION.md` |
| Intended recipient is not the physical endpoint; alternate same-side actors can intercept an immutable source flight | VERIFIED DEVELOPMENT | `free_flight_interception_system.gd`; `FREE_FLIGHT_INTERCEPTION.md` |
| Realised trajectories are exact prefixes linked to the same authoritative flight/launch | VERIFIED DEVELOPMENT | `FreeFlightInterceptionSystem.realised_prefix()` + certification fixtures |
| A legal overpass is governed as the receiving side's ordinary first team contact, with physical/legal attack/control candidates | VERIFIED POLICY + IMPLEMENTATION | `scripts/simulation/overpass_action_system.gd`; `docs/review/OVERPASS_ACTION_HANDOFF.md` |
| Overpass control is live-wired at both unresolved exits and certified by a constructed live fixture at the last audited active checkpoint | VERIFIED ACTIVE-BRANCH CHECKPOINT | `c147c30`, `f766cf9`, `da6575d`; active `OVERPASS_ACTION_HANDOFF.md` |
| At that same checkpoint the overpass attack live continuation remained open; `execute_attack()` already reused ordinary geometric swing resolution | VERIFIED SNAPSHOT | active `OVERPASS_ACTION_HANDOFF.md`; `OverpassActionSystem.execute_attack()` |
| `ENABLE_PHYSICAL_PLATFORM_DIG` remained false at the last audited active checkpoint | VERIFIED SNAPSHOT | active branch source/handoff |
| Team contact number is context rather than a permanent action-type mapping | VERIFIED CURRENT PRINCIPLE / PARTIAL IMPLEMENTATION | current overpass first-contact attack/control + `docs/design/RALLY_ACTION_SPACE.md` |
| Setter dump, set-on-one, joust, live net-rebound consistency and broader contact-number action space remain future M6/M7 work unless newer source explicitly promotes them | PROPOSED / PLANNED | `docs/design/RALLY_ACTION_SPACE.md`, `RALLY_MILESTONES.md` |
| Coverage physical state/T1–T3 envelope exists but keep-alive launch preference is not yet governed | VERIFIED CURRENT POLICY BOUNDARY | `docs/design/RALLY_MILESTONES.md`; platform/coverage review docs |
| Tests/probes are evidence for their exact assertions/fixtures; suite counts and outcome rates are not standalone acceptance criteria | VERIFIED PROJECT METHOD | current review methodology; Part VII; `docs/design/MEASUREMENT_CONFOUNDS.md` |

## Historical evidence

The large Gate 1–51 evidence chain, old shadow reception/set/attack/block rollout records, and the previous version of this ledger remain available in Git history and `docs/calibration/`.

They are useful for understanding **how** the architecture reached its current form. Do not use an old Gate's activation/next-step statement as current authority without checking the current roadmap/source.

## Maintenance

When adding a row here, prefer a claim that helps a maintainer answer one of:

- what owns this fact?
- is this live or proposed?
- why is this path enabled/disabled?
- what evidence closed/reopened this boundary?

Detailed measurements belong in the owning review document, not this table.