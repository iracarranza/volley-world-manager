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

## Per-region physique offsets applied before individual random variation.
## These are roster-generation ranges for gameplay variety, not anatomical claims.
const REGION_HEIGHT_BIAS := {
	"Pāwa Hitō": 4.0, "Spëddigh": -2.0, "Bloc du Larg": 1.0, "Landavol": 0.0,
}
const REGION_MASS_BIAS := {
	"Pāwa Hitō": 5.0, "Spëddigh": -3.0, "Bloc du Larg": 1.0, "Landavol": 0.0,
}
const REGION_WINGSPAN_BIAS := {
	"Pāwa Hitō": 3.0, "Spëddigh": -2.0, "Bloc du Larg": 2.0, "Landavol": 0.0,
}

## Attributes that receive a +8 specialty bonus for players from each region.
const REGION_SPECIALTY := {
	"Pāwa Hitō": ["attack_power", "block_timing", "jump_reach", "explosiveness", "serve_power"],
	"Spëddigh": ["acceleration", "lateral_speed", "reception_balance", "reception_stability", "dig_control"],
	"Bloc du Larg": ["block_timing", "ball_control", "court_vision", "anticipation", "tactical_discipline"],
	"Landavol": ["decision_making", "composure", "set_accuracy", "reception", "adaptability"],
}

## Primary role attributes receive a +15 bonus above the development target.
const ROLE_PRIMARY := {
	"Setter": ["set_accuracy", "tempo_control", "hand_control", "set_balance", "set_stability",
			"set_disguise", "court_vision", "decision_making"],
	"Outside Hitter": ["attack_power", "attack_accuracy", "approach_timing", "reception",
			"serve_consistency", "block_timing", "lateral_speed"],
	"Middle Blocker": ["block_timing", "jump_reach", "explosiveness", "attack_power",
			"approach_timing", "transition_speed", "arm_speed"],
	"Opposite": ["attack_power", "attack_accuracy", "approach_timing", "block_timing",
			"jump_reach", "serve_power", "arm_speed"],
	"Libero": ["reception", "dig_control", "reception_balance", "reception_stability",
			"lateral_speed", "acceleration", "anticipation"],
}

## Secondary role attributes receive a +5 bonus. Everything else falls to tertiary (-8).
const ROLE_SECONDARY := {
	"Setter": ["composure", "adaptability", "tactical_discipline", "anticipation",
			"serve_technique", "serve_consistency", "serve_placement", "ball_control"],
	"Outside Hitter": ["tooling", "feinting", "finesse", "shot_variety", "court_vision",
			"composure", "serve_technique", "explosiveness", "jump_reach"],
	"Middle Blocker": ["attack_accuracy", "tooling", "feinting", "shot_variety",
			"ball_control", "serve_technique", "stamina"],
	"Opposite": ["tooling", "feinting", "finesse", "shot_variety", "serve_technique",
			"serve_aggression", "serve_variation", "explosiveness"],
	"Libero": ["ball_control", "court_vision", "adaptability", "composure",
			"transition_speed", "stamina", "tactical_discipline"],
}


static func generate_roster(
	region_name: String,
	organization_type: String,
	seed_value: int,
) -> Array[VolleyballPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var canonical_region := VolleyballRegions.canonical_name(region_name)
	var region := VolleyballRegions.definition(region_name)
	var names: Array = region.names
	var roster_size := 12 if organization_type == "Academy" else 10
	var academy := organization_type == "Academy"
	var result: Array[VolleyballPlayer] = []
	for index in range(roster_size):
		var position: Dictionary = POSITIONS[index % POSITIONS.size()]
		var player := VolleyballPlayer.new()
		player.id = index + 1
		player.display_name = "%s %d" % [str(names[index % names.size()]), index + 1]
		player.position_role = str(position.role)
		player.position_code = str(position.code)
		player.apply_role_physical_defaults()
		player.age = rng.randi_range(16, 20) if academy else rng.randi_range(21, 31)
		player.professional_experience = 0 if academy else maxi(player.age - 20, 1)
		_generate_potential(player, rng, academy)
		_apply_body_variation(player, rng, canonical_region)
		player.stride_length_m = player.default_stride_length_m()
		_apply_attributes(player, canonical_region, rng, academy)
		Familiarity.initialize_player(player, rng)
		AttributeProfiles.assign_serve_style(player)
		result.append(player)
	return result


static func _generate_potential(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	academy: bool,
) -> void:
	if academy:
		player.potential = rng.randi_range(68, 96)
	else:
		var ceiling := clampi(94 - (player.age - 21) * 2, 70, 94)
		player.potential = rng.randi_range(52, ceiling)


## Produces correlated individual bodies around role templates, shifted by
## region physique bias. Stride is updated by the caller after this returns.
static func _apply_body_variation(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	region_name: String,
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
	var height_bias := float(REGION_HEIGHT_BIAS.get(region_name, 0.0))
	var mass_bias := float(REGION_MASS_BIAS.get(region_name, 0.0))
	var wingspan_bias := float(REGION_WINGSPAN_BIAS.get(region_name, 0.0))
	player.height_cm = clampf(player.height_cm + height_delta + height_bias, 150.0, 220.0)
	player.mass_kg = clampf(player.mass_kg + mass_delta + mass_bias, 50.0, 130.0)
	player.wingspan_cm = clampf(player.wingspan_cm + span_delta + wingspan_bias, 150.0, 235.0)


static func _development_fraction(
	age: int,
	rng: RandomNumberGenerator,
	academy: bool,
) -> float:
	var base: float
	if academy:
		base = 0.40 + float(age - 16) * 0.0625
		return clampf(base + rng.randf_range(-0.08, 0.08), 0.30, 0.75)
	else:
		base = 0.65 + float(age - 21) * 0.027
		return clampf(base + rng.randf_range(-0.05, 0.05), 0.55, 0.98)


## Derives each attribute from potential × development_fraction, then applies
## role-tier bonuses (+15 primary, +5 secondary, -8 tertiary) and a regional
## specialty bonus (+8). Potential is the ceiling; development fraction from
## age determines how much of that ceiling is currently expressed.
static func _apply_attributes(
	player: VolleyballPlayer,
	region_name: String,
	rng: RandomNumberGenerator,
	academy: bool,
) -> void:
	var dev_fraction := _development_fraction(player.age, rng, academy)
	var target := float(player.potential) * dev_fraction
	var primary_list: Array = Array(ROLE_PRIMARY.get(player.position_role, []))
	var secondary_list: Array = Array(ROLE_SECONDARY.get(player.position_role, []))
	var specialty_list: Array = Array(REGION_SPECIALTY.get(region_name, []))
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		var tier_bonus: int
		if property_name in primary_list:
			tier_bonus = 15
		elif property_name in secondary_list:
			tier_bonus = 5
		else:
			tier_bonus = -8
		var specialty_bonus: int = 8 if property_name in specialty_list else 0
		player.set(property_name, clampi(
			roundi(target) + tier_bonus + specialty_bonus + rng.randi_range(-8, 8),
			20, 92
		))


static func generate_market(
	region_name: String,
	seed_value: int,
	first_id: int = 1000,
	count: int = 120,
) -> Array[Resource]:
	var result: Array[Resource] = []
	var batch := 0
	while result.size() < count:
		var generated := generate_roster(region_name, "Club", seed_value + batch * 7919)
		for player in generated:
			if result.size() >= count:
				break
			player.id = first_id + result.size()
			player.display_name = "%s %03d" % [player.display_name.get_slice(" ", 0), result.size() + 1]
			result.append(player)
		batch += 1
	return result
