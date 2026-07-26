class_name VolleyballPlayer
extends Resource

@export var id: int = -1
@export var display_name: String = "Player"
@export var position_role: String = "Outside Hitter"
@export var position_code: String = "OH"
@export_range(15, 45) var age: int = 24
@export_range(0, 25) var professional_experience: int = 3
@export_range(1, 100) var potential: int = 70
@export_range(0.0, 1.0) var morale: float = 0.70
@export_enum("Available", "Resting", "Injured", "Suspended") var availability: String = "Available"

@export_category("Physical")
@export_range(150.0, 220.0, 0.5) var height_cm: float = 188.0
@export_range(50.0, 130.0, 0.5) var mass_kg: float = 82.0
@export_range(150.0, 235.0, 0.5) var wingspan_cm: float = 191.0
@export_range(1, 100) var acceleration: int = 50
@export_range(1, 100) var lateral_speed: int = 50
@export_range(1, 100) var transition_speed: int = 50
@export_range(1, 100) var jump_reach: int = 50
@export_range(1, 100) var explosiveness: int = 50
@export_range(1, 100) var stamina: int = 50
@export_range(1, 100) var arm_speed: int = 50

@export_category("Technical")
@export_range(1, 100) var serve_power: int = 50
@export_range(1, 100) var serve_accuracy: int = 50
@export_range(1, 100) var serve_technique: int = 50
@export_range(1, 100) var serve_placement: int = 50
@export_range(1, 100) var serve_consistency: int = 50
@export_range(1, 100) var serve_aggression: int = 50
@export_range(1, 100) var serve_variation: int = 50
@export_range(1, 100) var reception: int = 50
@export_range(1, 100) var reception_balance: int = 50
@export_range(1, 100) var reception_stability: int = 50
@export_range(1, 100) var set_accuracy: int = 50
@export_range(1, 100) var set_balance: int = 50
@export_range(1, 100) var set_stability: int = 50
@export_range(1, 100) var tempo_control: int = 50
@export_range(1, 100) var set_disguise: int = 50
@export_range(1, 100) var hand_control: int = 50
@export_range(1, 100) var attack_power: int = 50
@export_range(1, 100) var attack_accuracy: int = 50
@export_range(1, 100) var approach_timing: int = 50
@export_range(1, 100) var tooling: int = 50
@export_range(1, 100) var feinting: int = 50
@export_range(1, 100) var finesse: int = 50
@export_range(1, 100) var shot_variety: int = 50
@export_range(1, 100) var block_timing: int = 50
@export_range(1, 100) var ball_control: int = 50
@export_range(1, 100) var dig_control: int = 50

@export_category("Mental and Tactical")
@export_range(1, 100) var court_vision: int = 50
@export_range(1, 100) var anticipation: int = 50
@export_range(1, 100) var decision_making: int = 50
@export_range(1, 100) var composure: int = 50
@export_range(1, 100) var tactical_discipline: int = 50
@export_range(1, 100) var improvisation: int = 50

@export_category("State")
@export_range(0.0, 1.0) var fatigue: float = 0.0
@export_range(-1.0, 1.0) var current_form: float = 0.0
@export var traits: Array[String] = []
@export_enum("Standing", "Jump Topspin", "Jump Float", "Hybrid", "Sky Ball") var primary_serve_style: String = "Standing"
@export var serve_style_proficiencies: Dictionary = {}
@export_enum("Right", "Left") var dominant_hand: String = "Right"
@export_range(1, 100) var adaptability: int = 50
@export var primary_position: String = "Outside Hitter"
@export var natural_positions: Array[String] = []
@export var position_familiarity: Dictionary = {}
@export var situation_experience: Dictionary = {}
@export var position_training_target: String = ""

const ABILITY_ATTRIBUTES: Array[String] = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
	"stamina", "arm_speed", "serve_power", "serve_technique", "serve_placement",
	"serve_consistency", "serve_aggression", "serve_variation", "reception", "reception_balance",
	"reception_stability", "set_accuracy", "set_balance", "set_stability", "tempo_control",
	"set_disguise", "hand_control", "attack_power", "attack_accuracy", "approach_timing",
	"tooling", "feinting", "finesse", "shot_variety", "block_timing", "ball_control", "dig_control", "court_vision",
	"anticipation", "decision_making", "composure", "tactical_discipline", "improvisation", "adaptability",
]

const POSITION_WEIGHTS := {
	"Setter": ["set_accuracy", "set_balance", "set_stability", "tempo_control", "set_disguise", "hand_control", "court_vision", "decision_making"],
	"Outside Hitter": ["attack_power", "attack_accuracy", "approach_timing", "tooling", "finesse", "shot_variety", "reception", "reception_balance"],
	"Middle Blocker": ["block_timing", "jump_reach", "explosiveness", "lateral_speed", "attack_power", "approach_timing", "anticipation"],
	"Opposite": ["attack_power", "attack_accuracy", "jump_reach", "approach_timing", "tooling", "shot_variety", "block_timing", "serve_power"],
	"Libero": ["reception", "reception_balance", "reception_stability", "dig_control", "ball_control", "anticipation", "lateral_speed", "decision_making"],
}


func current_ability_score() -> int:
	var role_attributes: Array = POSITION_WEIGHTS.get(position_role, ABILITY_ATTRIBUTES)
	var role_total := 0.0
	for attribute_name in role_attributes:
		role_total += float(get(str(attribute_name)))
	var role_score := role_total / maxf(float(role_attributes.size()), 1.0)
	var complete_total := 0.0
	for attribute_name in ABILITY_ATTRIBUTES:
		complete_total += float(get(attribute_name))
	var complete_score := complete_total / float(ABILITY_ATTRIBUTES.size())
	return clampi(roundi(role_score * 0.75 + complete_score * 0.25), 1, 100)


func format_stars(score: int) -> String:
	var rating := clampf(float(score) / 20.0, 0.5, 5.0)
	var half_steps := clampi(roundi(rating * 2.0), 1, 10)
	var full_stars := half_steps / 2
	var has_half := half_steps % 2 == 1
	return "%s%s%s" % ["★".repeat(full_stars), "½" if has_half else "",
		"☆".repeat(5 - full_stars - (1 if has_half else 0))]


func current_ability_stars() -> String:
	return format_stars(current_ability_score())


func potential_ability_stars() -> String:
	return format_stars(potential)


func usable_attack_power() -> int:
	var normalized_mass := clampf(inverse_lerp(55.0, 115.0, mass_kg) * 100.0, 1.0, 100.0)
	return clampi(roundi(float(attack_power) * 0.25 + normalized_mass * 0.10 \
		+ float(explosiveness) * 0.18 + float(transition_speed) * 0.12 \
		+ float(arm_speed) * 0.20 + float(approach_timing) * 0.15), 1, 100)


func baseline_defensive_range() -> int:
	var reach := clampf(inverse_lerp(190.0, 280.0, standing_reach_cm()) * 100.0, 1.0, 100.0)
	return clampi(roundi(float(acceleration) * 0.22 + float(lateral_speed) * 0.24 \
		+ float(anticipation) * 0.22 + reach * 0.14 + float(ball_control) * 0.08 \
		+ float(stamina) * 0.10), 1, 100)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"position_role": position_role,
		"position_code": position_code,
		"age": age,
		"professional_experience": professional_experience,
		"potential": potential,
		"morale": morale,
		"availability": availability,
		"height_cm": height_cm,
		"mass_kg": mass_kg,
		"wingspan_cm": wingspan_cm,
		"acceleration": acceleration,
		"lateral_speed": lateral_speed,
		"transition_speed": transition_speed,
		"jump_reach": jump_reach,
		"explosiveness": explosiveness,
		"stamina": stamina,
		"arm_speed": arm_speed,
		"serve_power": serve_power,
		"serve_accuracy": serve_accuracy,
		"serve_technique": serve_technique,
		"serve_placement": serve_placement,
		"serve_consistency": serve_consistency,
		"serve_aggression": serve_aggression,
		"serve_variation": serve_variation,
		"reception": reception,
		"reception_balance": reception_balance,
		"reception_stability": reception_stability,
		"set_accuracy": set_accuracy,
		"set_balance": set_balance,
		"set_stability": set_stability,
		"tempo_control": tempo_control,
		"set_disguise": set_disguise,
		"hand_control": hand_control,
		"attack_power": attack_power,
		"attack_accuracy": attack_accuracy,
		"approach_timing": approach_timing,
		"tooling": tooling,
		"feinting": feinting,
		"finesse": finesse,
		"shot_variety": shot_variety,
		"block_timing": block_timing,
		"ball_control": ball_control,
		"dig_control": dig_control,
		"court_vision": court_vision,
		"anticipation": anticipation,
		"decision_making": decision_making,
		"composure": composure,
		"tactical_discipline": tactical_discipline,
		"improvisation": improvisation,
		"fatigue": fatigue,
		"current_form": current_form,
		"traits": traits.duplicate(),
		"primary_serve_style": primary_serve_style,
		"serve_style_proficiencies": serve_style_proficiencies.duplicate(true),
		"dominant_hand": dominant_hand, "adaptability": adaptability,
		"primary_position": primary_position, "natural_positions": natural_positions.duplicate(),
		"position_familiarity": position_familiarity.duplicate(true),
		"situation_experience": situation_experience.duplicate(true),
		"position_training_target": position_training_target,
	}


static func from_dict(data: Dictionary) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = int(data.get("id", -1))
	player.display_name = str(data.get("display_name", "Player"))
	player.position_role = str(data.get("position_role", "Outside Hitter"))
	player.position_code = str(data.get("position_code", "OH"))
	player.age = clampi(int(data.get("age", 24)), 15, 45)
	player.professional_experience = clampi(int(data.get("professional_experience", 3)), 0, 25)
	player.potential = clampi(int(data.get("potential", 70)), 1, 100)
	player.morale = clampf(float(data.get("morale", 0.70)), 0.0, 1.0)
	player.availability = str(data.get("availability", "Available"))
	player.apply_role_physical_defaults()
	player.height_cm = clampf(float(data.get("height_cm", player.height_cm)), 150.0, 220.0)
	player.mass_kg = clampf(float(data.get("mass_kg", player.mass_kg)), 50.0, 130.0)
	player.wingspan_cm = clampf(float(data.get("wingspan_cm", player.wingspan_cm)), 150.0, 235.0)
	for property_name in [
		"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
		"stamina", "arm_speed", "serve_power", "serve_accuracy", "reception",
		"reception_balance", "reception_stability",
		"set_accuracy", "set_balance", "set_stability", "tempo_control", "set_disguise", "hand_control",
		"attack_power", "attack_accuracy", "approach_timing", "tooling", "feinting", "finesse", "shot_variety",
		"block_timing", "ball_control", "dig_control", "court_vision", "anticipation",
		"decision_making", "composure", "tactical_discipline", "improvisation",
	]:
		player.set(property_name, clampi(int(data.get(property_name, 50)), 1, 100))
	var legacy_serve_accuracy := int(data.get("serve_accuracy", 50))
	for property_name in ["serve_technique", "serve_placement", "serve_consistency",
		"serve_aggression", "serve_variation"]:
		player.set(property_name, clampi(int(data.get(property_name, legacy_serve_accuracy)), 1, 100))
	player.primary_serve_style = str(data.get("primary_serve_style", "Standing"))
	player.serve_style_proficiencies = Dictionary(
		data.get("serve_style_proficiencies", {})
	).duplicate(true)
	player.dominant_hand = str(data.get("dominant_hand", "Right"))
	player.adaptability = clampi(int(data.get("adaptability", 50)), 1, 100)
	player.primary_position = str(data.get("primary_position", player.position_role))
	player.natural_positions = Array(data.get("natural_positions", [player.primary_position]), TYPE_STRING, "", null)
	player.position_familiarity = Dictionary(data.get("position_familiarity", {player.primary_position: 90})).duplicate(true)
	player.situation_experience = Dictionary(data.get("situation_experience", {})).duplicate(true)
	player.position_training_target = str(data.get("position_training_target", ""))
	player.fatigue = clampf(float(data.get("fatigue", 0.0)), 0.0, 1.0)
	player.current_form = clampf(float(data.get("current_form", 0.0)), -1.0, 1.0)
	player.traits = Array(data.get("traits", []), TYPE_STRING, "", null)
	return player


func active_serve_style_score() -> int:
	return clampi(int(serve_style_proficiencies.get(primary_serve_style, 50)), 1, 100)


func standing_reach_cm() -> float:
	return height_cm * 1.215 + (wingspan_cm - height_cm) * 0.32


func apply_role_physical_defaults() -> void:
	var defaults: Array = {
		"Setter": [188.0, 82.0, 191.0, 70, 64, 68],
		"Outside Hitter": [193.0, 88.0, 198.0, 78, 75, 78],
		"Middle Blocker": [203.0, 95.0, 211.0, 86, 48, 62],
		"Opposite": [198.0, 94.0, 205.0, 83, 54, 66],
		"Libero": [178.0, 72.0, 181.0, 72, 88, 91],
	}.get(position_role, [188.0, 82.0, 191.0, 68, 62, 68])
	height_cm = float(defaults[0])
	mass_kg = float(defaults[1])
	wingspan_cm = float(defaults[2])
	explosiveness = int(defaults[3])
	reception_balance = int(defaults[4])
	reception_stability = int(defaults[5])
