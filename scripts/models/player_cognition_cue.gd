class_name PlayerCognitionCue
extends Resource

## A replay-safe statement about what one player is attending to, deciding, or
## feeling during a rally.  This is semantic evidence: renderers decide how an
## eye, flame, face, punctuation mark, or arrow depicts it.
##
## **A cue never names a picture.** `state`, `attention_kind` and `affect` are
## the vocabulary; an eye shape, a call symbol or a colour is a renderer's
## reading of them. The 2D badge and the 3D billboard consume the same cue and
## must agree on meaning without agreeing on geometry, which is only possible if
## nothing here is a sprite name.
##
## **A cue carries only what its player perceived.** The resolver knows where
## the ball actually went; a blocker reading the setter does not. Grading an
## outcome is allowed after the decision boundary the cue describes, never
## before it -- otherwise the badge shows a player being certain about something
## they had no way to know, which is the one failure that would make the whole
## layer read as fake.

## The closed vocabularies. Declared rather than left as loose strings because
## two renderers and one compiler have to agree on them, and a typo in a
## `StringName` is silent everywhere.
const STATES: Array[StringName] = [
	&"searching", &"recognizing", &"deciding", &"calling",
	&"committed", &"lost_sight", &"reacting",
]
const ATTENTION_KINDS: Array[StringName] = [
	&"ball", &"setter", &"hitter", &"teammate", &"position", &"none",
]
const VISIBILITIES: Array[StringName] = [
	&"visible", &"partially_obscured", &"occluded",
]
const AUDIENCES: Array[StringName] = [&"private", &"public", &"observable"]
const AFFECTS: Array[StringName] = [
	&"neutral", &"confident", &"urgent", &"upset", &"sad", &"pleased",
]
## The volleyball job this cognition belongs to. State says *when* the player is
## in the read/decision/execution cycle; action says *what they are trying to
## do*. Keeping those separate prevents an emotional reaction from turning into
## a generic starburst and lets receive, floor defence, block and attack keep
## their own visual language through the whole rally.
const ACTION_KINDS: Array[StringName] = [
	&"none", &"receive", &"defend", &"block", &"attack",
]

## The shortest interval anyone can read. A cue thinner than this flickers past
## at 2x playback and reads as a rendering fault rather than a thought.
const MINIMUM_DURATION_SECONDS: float = 0.08

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
@export var action_kind: StringName = &"none"
## -1 means the action has not been graded yet. Once execution evidence exists,
## 0 is failing and 1 is excellent; renderers map that common scale to colour.
@export_range(-1.0, 1.0) var execution_quality: float = -1.0
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
	cue.ends_at = maxf(to_time, cue.starts_at + MINIMUM_DURATION_SECONDS)
	cue.state = cue_state
	cue.phase = cue_phase
	return cue


func is_active_at(simulation_time: float) -> bool:
	return simulation_time >= starts_at and simulation_time <= ends_at


func duration() -> float:
	return maxf(ends_at - starts_at, 0.0)


## Whether this cue may be shown to a viewer watching the whole court.
##
## `private` is a thought the player had and nobody could see -- a setter's
## option weighing, a blocker's belief about the lane. It is still recorded,
## because the 2D tactical board is a coaching instrument and may show it, but
## the 3D presentation is a camera in a gym and must not.
func is_visible_to_spectators() -> bool:
	return audience != &"private"


## Every field, so a saved rally replays identically to the one that was
## resolved. Godot serialises `@export`ed resources on its own, but a rally
## result also crosses a JSON save, and a cue that survived one and not the
## other would produce two different replays of the same seed.
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
		"action_kind": str(action_kind),
		"execution_quality": execution_quality,
		"urgency": urgency,
		"punctuation": punctuation,
		"affect": str(affect),
		"affect_intensity": affect_intensity,
		"trend": trend,
		"outcome_name": outcome_name,
		"audience": str(audience),
		"priority": priority,
	}


static func from_dict(data: Dictionary) -> PlayerCognitionCue:
	var cue := PlayerCognitionCue.new()
	cue.sequence = int(data.get("sequence", 0))
	cue.action_sequence = int(data.get("action_sequence", -1))
	cue.player_id = int(data.get("player_id", -1))
	cue.side = StringName(str(data.get("side", "")))
	cue.phase = StringName(str(data.get("phase", "before")))
	cue.state = StringName(str(data.get("state", "searching")))
	cue.starts_at = float(data.get("starts_at", 0.0))
	cue.ends_at = float(data.get("ends_at", 0.0))
	cue.attention_kind = StringName(str(data.get("attention_kind", "ball")))
	cue.attention_player_id = int(data.get("attention_player_id", -1))
	## A Vector2 survives Godot's own resource format and does not survive JSON,
	## where it arrives as a dictionary or an array. Accepting all three is
	## cheaper than discovering at load time which writer produced the save.
	cue.attention_position = _to_vector2(data.get("attention_position", Vector2.ZERO))
	cue.visibility = StringName(str(data.get("visibility", "visible")))
	cue.certainty = clampf(float(data.get("certainty", 0.5)), 0.0, 1.0)
	cue.action_kind = StringName(str(data.get("action_kind", "none")))
	cue.execution_quality = clampf(
		float(data.get("execution_quality", -1.0)), -1.0, 1.0
	)
	cue.urgency = clampf(float(data.get("urgency", 0.5)), 0.0, 1.0)
	cue.punctuation = str(data.get("punctuation", ""))
	cue.affect = StringName(str(data.get("affect", "neutral")))
	cue.affect_intensity = clampf(float(data.get("affect_intensity", 0.0)), 0.0, 1.0)
	cue.trend = clampf(float(data.get("trend", 0.0)), -1.0, 1.0)
	cue.outcome_name = str(data.get("outcome_name", ""))
	cue.audience = StringName(str(data.get("audience", "observable")))
	cue.priority = int(data.get("priority", 0))
	return cue


static func _to_vector2(raw: Variant) -> Vector2:
	if raw is Vector2:
		return raw
	if raw is Dictionary:
		return Vector2(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)))
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


## Whether every field holds a value from its own vocabulary and the interval
## runs forwards. Used by the gate rather than by the compiler: a cue that fails
## this is a bug in whoever built it, and silently repairing one would hide the
## bug rather than the badge.
func is_well_formed() -> bool:
	return (
		player_id >= 0
		and STATES.has(state)
		and ATTENTION_KINDS.has(attention_kind)
		and VISIBILITIES.has(visibility)
		and AUDIENCES.has(audience)
		and AFFECTS.has(affect)
		and ACTION_KINDS.has(action_kind)
		and execution_quality >= -1.0 and execution_quality <= 1.0
		and starts_at >= 0.0
		and ends_at >= starts_at
		and duration() >= MINIMUM_DURATION_SECONDS - 0.0001
	)
