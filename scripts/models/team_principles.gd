class_name TeamPrinciples
extends Resource

const PRESET_NAMES: Array[String] = [
	"Balanced", "Technical", "Physical", "Defensive", "Fast Tempo", "Development",
]

const PRESETS := {
	"Balanced": {
		"decisiveness": 0.50, "pin_focus": 0.50, "tempo_variation": 0.50,
		"emotional_expression": 0.50, "serve_aggression": 0.50,
		"transition_commitment": 0.50, "block_commitment": 0.50,
	},
	"Technical": {
		"decisiveness": 0.38, "pin_focus": 0.32, "tempo_variation": 0.42,
		"emotional_expression": 0.25, "serve_aggression": 0.34,
		"transition_commitment": 0.48, "block_commitment": 0.46,
	},
	"Physical": {
		"decisiveness": 0.86, "pin_focus": 0.82, "tempo_variation": 0.38,
		"emotional_expression": 0.72, "serve_aggression": 0.78,
		"transition_commitment": 0.76, "block_commitment": 0.82,
	},
	"Defensive": {
		"decisiveness": 0.18, "pin_focus": 0.42, "tempo_variation": 0.24,
		"emotional_expression": 0.30, "serve_aggression": 0.22,
		"transition_commitment": 0.28, "block_commitment": 0.26,
	},
	"Fast Tempo": {
		"decisiveness": 0.78, "pin_focus": 0.44, "tempo_variation": 0.88,
		"emotional_expression": 0.62, "serve_aggression": 0.66,
		"transition_commitment": 0.92, "block_commitment": 0.58,
	},
	"Development": {
		"decisiveness": 0.42, "pin_focus": 0.38, "tempo_variation": 0.72,
		"emotional_expression": 0.46, "serve_aggression": 0.30,
		"transition_commitment": 0.62, "block_commitment": 0.40,
	},
}

const DESCRIPTIONS := {
	"Balanced": "Adapts risk, tempo, and attack distribution to the players on court.",
	"Technical": "Values control, middle involvement, disciplined responses, and repeatable tempo.",
	"Physical": "Commits to decisive pin attacks, forceful serving, and an aggressive block.",
	"Defensive": "Extends rallies, protects floor coverage, and limits unnecessary risk.",
	"Fast Tempo": "Pushes transition speed and changes tempo frequently to keep the block unsettled.",
	"Development": "Shares attacking responsibility and varies tempo without overloading young players.",
}

const AXIS_KEYS: Array[String] = [
	"decisiveness", "pin_focus", "tempo_variation", "emotional_expression",
	"serve_aggression", "transition_commitment", "block_commitment",
]

@export var preset_name: String = "Balanced"
@export_range(0.0, 1.0) var decisiveness: float = 0.50
@export_range(0.0, 1.0) var pin_focus: float = 0.50
@export_range(0.0, 1.0) var tempo_variation: float = 0.50
@export_range(0.0, 1.0) var emotional_expression: float = 0.50
@export_range(0.0, 1.0) var serve_aggression: float = 0.50
@export_range(0.0, 1.0) var transition_commitment: float = 0.50
@export_range(0.0, 1.0) var block_commitment: float = 0.50


static func for_identity(identity_name: String) -> TeamPrinciples:
	var principles := TeamPrinciples.new()
	principles.apply_preset(identity_name)
	return principles


static func custom(identity_name: String, values: Dictionary) -> TeamPrinciples:
	var principles := TeamPrinciples.new()
	principles.preset_name = identity_name.strip_edges()
	if principles.preset_name.is_empty():
		principles.preset_name = "Custom Identity"
	for axis_name in AXIS_KEYS:
		principles.set(axis_name, _saved_axis(values, axis_name, 0.5))
	return principles


func apply_preset(identity_name: String) -> void:
	preset_name = identity_name if identity_name in PRESET_NAMES else "Balanced"
	var values: Dictionary = PRESETS[preset_name]
	decisiveness = float(values.decisiveness)
	pin_focus = float(values.pin_focus)
	tempo_variation = float(values.tempo_variation)
	emotional_expression = float(values.emotional_expression)
	serve_aggression = float(values.serve_aggression)
	transition_commitment = float(values.transition_commitment)
	block_commitment = float(values.block_commitment)


func to_dict() -> Dictionary:
	return {
		"preset_name": preset_name,
		"decisiveness": decisiveness,
		"pin_focus": pin_focus,
		"tempo_variation": tempo_variation,
		"emotional_expression": emotional_expression,
		"serve_aggression": serve_aggression,
		"transition_commitment": transition_commitment,
		"block_commitment": block_commitment,
	}


static func from_dict(data: Dictionary, fallback_identity: String = "Balanced") -> TeamPrinciples:
	var saved_name := str(data.get("preset_name", fallback_identity))
	var principles := for_identity(saved_name)
	if data.is_empty():
		return principles
	principles.preset_name = saved_name.strip_edges()
	if principles.preset_name.is_empty():
		principles.preset_name = "Balanced"
	principles.decisiveness = _saved_axis(data, "decisiveness", principles.decisiveness)
	principles.pin_focus = _saved_axis(data, "pin_focus", principles.pin_focus)
	principles.tempo_variation = _saved_axis(data, "tempo_variation", principles.tempo_variation)
	principles.emotional_expression = _saved_axis(
		data, "emotional_expression", principles.emotional_expression
	)
	principles.serve_aggression = _saved_axis(
		data, "serve_aggression", principles.serve_aggression
	)
	principles.transition_commitment = _saved_axis(
		data, "transition_commitment", principles.transition_commitment
	)
	principles.block_commitment = _saved_axis(
		data, "block_commitment", principles.block_commitment
	)
	return principles


func alignment_distance(other: TeamPrinciples) -> float:
	if other == null:
		return 0.0
	var distance := 0.0
	for axis_name in AXIS_KEYS:
		distance += absf(float(get(axis_name)) - float(other.get(axis_name)))
	return distance / float(AXIS_KEYS.size())


func alignment_percent(other: TeamPrinciples) -> int:
	return roundi((1.0 - alignment_distance(other)) * 100.0)


static func description_for(identity_name: String) -> String:
	return str(DESCRIPTIONS.get(identity_name, DESCRIPTIONS.Balanced))


static func _saved_axis(data: Dictionary, key: String, fallback: float) -> float:
	return clampf(float(data.get(key, fallback)), 0.0, 1.0)
