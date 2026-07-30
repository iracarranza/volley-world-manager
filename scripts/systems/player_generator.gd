class_name VolleyballPlayerGenerator
extends RefCounted

const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")

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
		_apply_body_variation(player, rng)
		var academy := organization_type == "Academy"
		player.age = rng.randi_range(16, 20) if academy else rng.randi_range(21, 31)
		player.professional_experience = 0 if academy else maxi(player.age - 20, 1)
		player.potential = rng.randi_range(74, 94) if academy else rng.randi_range(64, 88)
		_apply_attributes(player, region, rng, academy)
		Familiarity.initialize_player(player, rng)
		AttributeProfiles.assign_serve_style(player)
		result.append(player)
	return result


## Produces correlated individual bodies around role templates. These are
## roster-generation ranges for gameplay variety, not anatomical claims.
static func _apply_body_variation(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
) -> void:
	var height_spread := float({
		"Setter": 7.0,
		"Outside Hitter": 7.5,
		"Middle Blocker": 8.0,
		"Opposite": 7.5,
		"Libero": 6.0,
	}.get(player.position_role, 7.0))
	var height_delta := (
		rng.randf_range(-height_spread, height_spread)
		+ rng.randf_range(-height_spread, height_spread)
	) * 0.5
	var mass_delta := height_delta * 0.55 + rng.randf_range(-5.0, 5.0)
	var span_delta := height_delta * 0.70 + rng.randf_range(-4.0, 5.0)
	player.height_cm = clampf(player.height_cm + height_delta, 150.0, 220.0)
	player.mass_kg = clampf(player.mass_kg + mass_delta, 50.0, 130.0)
	player.wingspan_cm = clampf(player.wingspan_cm + span_delta, 150.0, 235.0)


static func generate_market(region_name: String, seed_value: int, first_id: int = 1000, count: int = 120) -> Array[Resource]:
	var result: Array[Resource] = []
	var batch := 0
	while result.size() < count:
		var generated := generate_roster(region_name, "Club", seed_value + batch * 7919)
		for player in generated:
			if result.size() >= count: break
			player.id = first_id + result.size()
			player.display_name = "%s %03d" % [player.display_name.get_slice(" ", 0), result.size() + 1]
			result.append(player)
		batch += 1
	return result


static func _apply_attributes(
	player: VolleyballPlayer,
	region: Dictionary,
	rng: RandomNumberGenerator,
	academy: bool,
) -> void:
	var base := rng.randi_range(42, 62) if academy else rng.randi_range(52, 72)
	for property_name in ["acceleration", "lateral_speed", "transition_speed", "jump_reach",
		"explosiveness", "stamina", "arm_speed", "serve_power", "serve_accuracy",
		"serve_technique", "serve_placement", "serve_consistency", "serve_aggression",
		"serve_variation", "reception",
		"reception_balance", "reception_stability", "set_accuracy", "set_balance",
		"set_stability", "tempo_control", "set_disguise", "hand_control",
		"attack_power", "attack_accuracy", "approach_timing", "tooling", "feinting", "finesse", "shot_variety",
		"block_timing", "ball_control", "dig_control", "court_vision", "anticipation",
		"decision_making", "composure", "tactical_discipline", "improvisation", "adaptability"]:
		var modifier := int(region.physical) if property_name in ["acceleration", "lateral_speed", "transition_speed", "jump_reach", "explosiveness", "stamina"] else (
			int(region.mental) if property_name in ["court_vision", "anticipation", "decision_making", "composure", "tactical_discipline", "improvisation", "adaptability"] else int(region.technical)
		)
		player.set(property_name, clampi(base + modifier + rng.randi_range(-8, 8), 20, 92))
