class_name RallyResult
extends Resource

@export var events: Array[Resource] = []
@export var home_team_won: bool = false
@export var terminal_outcome: String = ""
@export var decisive_actor_id: int = -1
@export var active_play_name: String = ""
@export var play_was_followed: bool = false
@export_range(0.0, 1.0) var reception_quality: float = 0.0
@export_range(0.0, 1.0) var set_quality: float = 0.0
@export_range(0.0, 1.0) var attack_quality: float = 0.0
@export var key_factors: Array[String] = []
@export var analysis: Dictionary = {}
## Authoritative home-player locations at t=0. Playback must begin from this
## snapshot instead of whichever tactical-planner view happens to be open.
@export var initial_home_positions: Dictionary = {}
@export var initial_opponent_positions: Dictionary = {}
## Presentation identity captured with the rally so replay does not depend on
## whichever roster is active later (or mirror every attacker onto one arm).
@export var player_handedness: Dictionary = {}
## Height, wingspan and stride captured at resolution time. Presentation uses
## these values for body proportions and gait without consulting live rosters.
@export var player_physical_profiles: Dictionary = {}
## What each player's trips to the floor cost them in condition, keyed by id.
##
## Reported rather than applied. `jumping_reach_cm()` reads `fatigue`, so charging
## it inside the resolver made a rally mutate the roster it was resolving and two
## replays of the same seed stopped matching -- the determinism gate caught it
## immediately. Fatigue accrual belongs to the match layer, which already has a
## post-rally step for exactly this.
@export var recovery_fatigue: Dictionary = {}
@export var explanation: String = ""
## The resolved headline, filled in by `RallySimulator._finish`.
##
## Stored rather than re-derived from `terminal_outcome` at display time,
## because headlines now carry `{hitter}`-style placeholders and the UI has no
## access to the names that fill them. `main.gd` called
## `RallyExplanations.headline(terminal_outcome)` with no values and would print
## the raw tokens.
@export var headline: String = ""
@export var ending_reason: StringName = &""
