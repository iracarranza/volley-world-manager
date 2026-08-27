class_name AttributeRegistry
extends RefCounted

## Canonical ability-attribute vocabulary. Formulas stay in their owning systems.
const ABILITY_ATTRIBUTES: Array[String] = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
	"stamina", "work_rate", "arm_speed", "serve_power", "serve_technique", "serve_placement",
	"serve_consistency", "serve_aggression", "serve_variation", "reception", "reception_balance",
	"reception_stability", "set_accuracy", "set_balance", "set_stability", "tempo_control",
	"set_disguise", "hand_control", "unpredictability", "attack_power", "attack_accuracy", "approach_timing",
	"tooling", "feinting", "finesse", "shot_variety", "block_timing", "ball_control", "dig_control", "court_vision",
	"anticipation", "decision_making", "composure", "tactical_discipline", "improvisation",
	"adaptability",
]

const PHYSICAL_ATTRIBUTES: Array[String] = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach",
	"explosiveness", "stamina", "arm_speed", "serve_power", "attack_power",
]

const MENTAL_ATTRIBUTES: Array[String] = [
	"court_vision", "anticipation", "decision_making", "composure",
	"tactical_discipline", "improvisation", "adaptability", "unpredictability",
	"work_rate",
]

static func all_ids() -> Array[String]:
	return ABILITY_ATTRIBUTES.duplicate()

static func category_of(attribute_id: String) -> String:
	if attribute_id in PHYSICAL_ATTRIBUTES: return "Physical"
	if attribute_id in MENTAL_ATTRIBUTES: return "Mental"
	return "Technical"

static func definition(attribute_id: String) -> Dictionary:
	return {"id": attribute_id, "category": category_of(attribute_id),
		"trainable": attribute_id in ABILITY_ATTRIBUTES,
		"scoutable": attribute_id in ABILITY_ATTRIBUTES}
