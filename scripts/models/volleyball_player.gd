class_name VolleyballPlayer
extends Resource

@export var id: int = -1
@export var display_name: String = "Player"
@export var position_role: String = "Outside Hitter"
@export var position_code: String = "OH"

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

@export_category("Technical")
@export_range(1, 100) var serve_power: int = 50
@export_range(1, 100) var serve_accuracy: int = 50
@export_range(1, 100) var reception: int = 50
@export_range(1, 100) var reception_balance: int = 50
@export_range(1, 100) var reception_stability: int = 50
@export_range(1, 100) var set_accuracy: int = 50
@export_range(1, 100) var attack_power: int = 50
@export_range(1, 100) var attack_accuracy: int = 50
@export_range(1, 100) var approach_timing: int = 50
@export_range(1, 100) var block_timing: int = 50
@export_range(1, 100) var ball_control: int = 50

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


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"position_role": position_role,
		"position_code": position_code,
		"height_cm": height_cm,
		"mass_kg": mass_kg,
		"wingspan_cm": wingspan_cm,
		"acceleration": acceleration,
		"lateral_speed": lateral_speed,
		"transition_speed": transition_speed,
		"jump_reach": jump_reach,
		"explosiveness": explosiveness,
		"stamina": stamina,
		"serve_power": serve_power,
		"serve_accuracy": serve_accuracy,
		"reception": reception,
		"reception_balance": reception_balance,
		"reception_stability": reception_stability,
		"set_accuracy": set_accuracy,
		"attack_power": attack_power,
		"attack_accuracy": attack_accuracy,
		"approach_timing": approach_timing,
		"block_timing": block_timing,
		"ball_control": ball_control,
		"court_vision": court_vision,
		"anticipation": anticipation,
		"decision_making": decision_making,
		"composure": composure,
		"tactical_discipline": tactical_discipline,
		"improvisation": improvisation,
		"fatigue": fatigue,
		"current_form": current_form,
		"traits": traits.duplicate(),
	}


static func from_dict(data: Dictionary) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = int(data.get("id", -1))
	player.display_name = str(data.get("display_name", "Player"))
	player.position_role = str(data.get("position_role", "Outside Hitter"))
	player.position_code = str(data.get("position_code", "OH"))
	player.apply_role_physical_defaults()
	player.height_cm = clampf(float(data.get("height_cm", player.height_cm)), 150.0, 220.0)
	player.mass_kg = clampf(float(data.get("mass_kg", player.mass_kg)), 50.0, 130.0)
	player.wingspan_cm = clampf(float(data.get("wingspan_cm", player.wingspan_cm)), 150.0, 235.0)
	for property_name in [
		"acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness",
		"stamina", "serve_power", "serve_accuracy", "reception",
		"reception_balance", "reception_stability",
		"set_accuracy", "attack_power", "attack_accuracy", "approach_timing",
		"block_timing", "ball_control", "court_vision", "anticipation",
		"decision_making", "composure", "tactical_discipline", "improvisation",
	]:
		player.set(property_name, clampi(int(data.get(property_name, 50)), 1, 100))
	player.fatigue = clampf(float(data.get("fatigue", 0.0)), 0.0, 1.0)
	player.current_form = clampf(float(data.get("current_form", 0.0)), -1.0, 1.0)
	player.traits = Array(data.get("traits", []), TYPE_STRING, "", null)
	return player


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
