class_name PlayerCognitionCue
extends Resource

## A replay-safe statement about what one player is attending to, deciding, or
## feeling during a rally.  This is semantic evidence: renderers decide how an
## eye, flame, face, punctuation mark, or arrow depicts it.
@export var sequence: int = 0
@export var action_sequence: int = -1
@export var player_id: int = -1
@export var side: StringName = &""
@export var phase: StringName = &"before"
@export var state: StringName = &"searching"
@export var starts_at: float = 0.0
@export var ends_at: float = 0.0
@export var attention_kind: StringName = &"ball"
@export var attention_player_id: int = -1
@export var attention_position: Vector2 = Vector2.ZERO
@export var visibility: StringName = &"visible"
@export_range(0.0, 1.0) var certainty: float = 0.5
@export_range(0.0, 1.0) var urgency: float = 0.5
@export var punctuation: String = ""
@export var affect: StringName = &"neutral"
@export_range(0.0, 1.0) var affect_intensity: float = 0.0
@export_range(-1.0, 1.0) var trend: float = 0.0
@export var outcome_name: String = ""
@export var audience: StringName = &"observable"
@export var priority: int = 0


static func create(
	player: int,
	player_side: StringName,
	action: int,
	from_time: float,
	to_time: float,
	cue_state: StringName,
	cue_phase: StringName = &"before",
) -> PlayerCognitionCue:
	var cue := PlayerCognitionCue.new()
	cue.player_id = player
	cue.side = player_side
	cue.action_sequence = action
	cue.starts_at = maxf(from_time, 0.0)
	cue.ends_at = maxf(to_time, cue.starts_at + 0.01)
	cue.state = cue_state
	cue.phase = cue_phase
	return cue


func is_active_at(simulation_time: float) -> bool:
	return simulation_time >= starts_at and simulation_time <= ends_at


func to_dict() -> Dictionary:
	return {
		"sequence": sequence,
		"action_sequence": action_sequence,
		"player_id": player_id,
		"side": str(side),
		"phase": str(phase),
		"state": str(state),
		"starts_at": starts_at,
		"ends_at": ends_at,
		"attention_kind": str(attention_kind),
		"attention_player_id": attention_player_id,
		"attention_position": attention_position,
		"visibility": str(visibility),
		"certainty": certainty,
		"urgency": urgency,
		"punctuation": punctuation,
		"affect": str(affect),
		"affect_intensity": affect_intensity,
		"trend": trend,
		"outcome_name": outcome_name,
		"audience": str(audience),
		"priority": priority,
	}
