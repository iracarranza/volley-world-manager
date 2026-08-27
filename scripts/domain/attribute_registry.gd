class_name AttributeRegistry
extends RefCounted

## Canonical player-attribute vocabulary and metadata. Gameplay formulas stay in
## their owning systems; this registry makes integration points auditable.

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

## Player traits which generation/profile data may reference but which are not
## trainable ability attributes. Leadership acts on teammates; ego is temperament.
const NON_ABILITY_TRAITS: Array[String] = ["leadership", "ego"]

static func all_ids() -> Array[String]:
	return ABILITY_ATTRIBUTES.duplicate()

static func all_player_traits() -> Array[String]:
	var result: Array[String] = ABILITY_ATTRIBUTES.duplicate()
	for trait in NON_ABILITY_TRAITS:
		if trait not in result:
			result.append(trait)
	return result

static func category_of(attribute_id: String) -> String:
	if attribute_id in PHYSICAL_ATTRIBUTES:
		return "Physical"
	if attribute_id in MENTAL_ATTRIBUTES:
		return "Mental"
	if attribute_id in NON_ABILITY_TRAITS:
		return "Temperament"
	return "Technical"

static func definition(attribute_id: String) -> Dictionary:
	return {
		"id": attribute_id,
		"category": category_of(attribute_id),
		"trainable": attribute_id in ABILITY_ATTRIBUTES,
		"scoutable": attribute_id in all_player_traits(),
	}
