class_name VolleyballPlayerGenerator
extends RefCounted

const POSITIONS: Array[Dictionary] = [
	{"role": "Setter", "code": "S"},
	{"role": "Outside Hitter", "code": "OH1"},
	{"role": "Outside Hitter", "code": "OH2"},
	{"role": "Middle Blocker", "code": "M1"},
	{"role": "Middle Blocker", "code": "M2"},
	{"role": "Opposite", "code": "OP"},
	{"role": "Libero", "code": "L"},
	{"role": "Setter", "code": "S2"},
	{"role": "Outside Hitter", "code": "OH3"},
	{"role": "Middle Blocker", "code": "M3"},
]


static func generate_roster(
	region_name: String,
	organization_type: String,
	seed_value: int,
) -> Array[VolleyballPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var region := VolleyballRegions.definition(region_name)
	var names: Array = region.names
	var roster_size := 12 if organization_type == "Academy" else 10
	var result: Array[VolleyballPlayer] = []
	for index in range(roster_size):
		var position: Dictionary = POSITIONS[index % POSITIONS.size()]
		var player := VolleyballPlayer.new()
		player.id = index + 1
		player.display_name = "%s %d" % [str(names[index % names.size()]), index + 1]
		player.position_role = str(position.role)
		player.position_code = str(position.code)
		player.apply_role_physical_defaults()
		var academy := organization_type == "Academy"
		player.age = rng.randi_range(16, 20) if academy else rng.randi_range(21, 31)
		player.professional_experience = 0 if academy else maxi(player.age - 20, 1)
		player.potential = rng.randi_range(74, 94) if academy else rng.randi_range(64, 88)
		_apply_attributes(player, region, rng, academy)
		result.append(player)
	return result


static func generate_market(region_name: String, seed_value: int, first_id: int = 1000) -> Array[Resource]:
	var generated := generate_roster(region_name, "Club", seed_value)
	var result: Array[Resource] = []
	for index in range(mini(generated.size(), 8)):
		generated[index].id = first_id + index
		result.append(generated[index])
	return result


static func _apply_attributes(
	player: VolleyballPlayer,
	region: Dictionary,
	rng: RandomNumberGenerator,
	academy: bool,
) -> void:
	var base := rng.randi_range(42, 62) if academy else rng.randi_range(52, 72)
	for property_name in ["acceleration", "lateral_speed", "transition_speed", "jump_reach",
		"explosiveness", "stamina", "arm_speed", "serve_power", "serve_accuracy", "reception",
		"reception_balance", "reception_stability", "set_accuracy", "set_balance",
		"set_stability", "tempo_control", "set_disguise", "hand_control",
		"attack_power", "attack_accuracy", "approach_timing", "tooling", "feinting", "finesse", "shot_variety",
		"block_timing", "ball_control", "dig_control", "court_vision", "anticipation",
		"decision_making", "composure", "tactical_discipline", "improvisation"]:
		var modifier := int(region.physical) if property_name in ["acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness", "stamina"] else (
			int(region.mental) if property_name in ["court_vision", "anticipation", "decision_making", "composure", "tactical_discipline", "improvisation"] else int(region.technical)
		)
		player.set(property_name, clampi(base + modifier + rng.randi_range(-8, 8), 20, 92))
