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
@export var explanation: String = ""
