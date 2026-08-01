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

## Secondary role attributes receive a +5 bonus: the supporting skills a role
## leans on without being judged by them. The *primary* tier is deliberately not
## defined here -- it is read from `VolleyballPlayer.POSITION_WEIGHTS`, which is
## already the single source of truth for what each role is scored on. Keeping a
## second copy here let generation and `current_ability_score()` disagree about
## what a role is for. Everything in neither tier falls to tertiary (-8).
const ROLE_SECONDARY := {
	"Setter": ["composure", "adaptability", "tactical_discipline", "anticipation",
			"serve_technique", "serve_consistency", "serve_placement", "ball_control"],
	"Outside Hitter": ["feinting", "court_vision", "composure", "serve_technique",
			"serve_consistency", "explosiveness", "jump_reach", "block_timing",
			"lateral_speed", "reception_stability"],
	"Middle Blocker": ["attack_accuracy", "tooling", "feinting", "shot_variety",
			"ball_control", "serve_technique", "stamina", "transition_speed", "arm_speed"],
	"Opposite": ["feinting", "finesse", "serve_technique", "serve_aggression",
			"serve_variation", "explosiveness", "arm_speed"],
	"Libero": ["court_vision", "adaptability", "composure", "transition_speed",
			"stamina", "tactical_discipline", "acceleration"],
}

## Height variation band per role, in centimetres.
const ROLE_HEIGHT_SPREAD := {
	"Setter": 7.0,
	"Outside Hitter": 7.5,
	"Middle Blocker": 8.0,
	"Opposite": 7.5,
	"Libero": 6.0,
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
	var height_spread := float(ROLE_HEIGHT_SPREAD.get(player.position_role, 7.0))
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


## Attribute points still available for this player to grow into, in raw rating
## points. This is the literal reading of potential: the reserve is the distance
## between what a player expresses now and the ceiling they could reach.
##
## It depends on age alone, never on the size of the ceiling. That independence
## is the point -- a 16-year-old with a modest ceiling is just as undeveloped as
## a 16-year-old with a huge one, so a wide current-to-potential gap says the
## player is young, not that they are a future star. Scaling the reserve by
## potential instead would make every large gap a tell for high potential and
## give the gap away for free.
static func _growth_reserve(
	age: int,
	rng: RandomNumberGenerator,
	academy: bool,
) -> float:
	if academy:
		var academy_base := lerpf(38.0, 18.0, clampf(float(age - 16) / 4.0, 0.0, 1.0))
		return maxf(academy_base + rng.randf_range(-6.0, 6.0), 4.0)
	var club_base := lerpf(16.0, 2.0, clampf(float(age - 21) / 10.0, 0.0, 1.0))
	return maxf(club_base + rng.randf_range(-4.0, 4.0), 0.0)


const PRIMARY_TIER_BONUS: int = 15
const SECONDARY_TIER_BONUS: int = 5
const TERTIARY_TIER_PENALTY: int = -8
const SPECIALTY_BONUS: int = 8


static func _tier_bonus(
	property_name: String,
	primary_list: Array,
	secondary_list: Array,
	specialty_list: Array,
) -> int:
	var bonus := TERTIARY_TIER_PENALTY
	if property_name in primary_list:
		bonus = PRIMARY_TIER_BONUS
	elif property_name in secondary_list:
		bonus = SECONDARY_TIER_BONUS
	return bonus + (SPECIALTY_BONUS if property_name in specialty_list else 0)


## How far the tier and specialty bonuses lift `current_ability_score()` above
## the flat base every attribute starts from.
##
## Without this, potential does not bound anything: the role tier adds +15 to
## exactly the attributes `current_ability_score()` weights at 75%, so a
## generated player's displayed ability lands roughly eleven points above the
## level intended, and any player near their ceiling scores *past* it. Measuring
## the inflation with the same weighting the score itself uses lets it be
## removed up front, and keeps the correction honest if the tier constants or
## the role lists ever change.
static func _ability_score_offset(
	primary_list: Array,
	secondary_list: Array,
	specialty_list: Array,
) -> float:
	var scored: Array = primary_list if not primary_list.is_empty() \
		else VolleyballPlayer.ABILITY_ATTRIBUTES
	var role_total := 0.0
	for property_name in scored:
		role_total += float(_tier_bonus(
			str(property_name), primary_list, secondary_list, specialty_list
		))
	var complete_total := 0.0
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		complete_total += float(_tier_bonus(
			property_name, primary_list, secondary_list, specialty_list
		))
	return (role_total / maxf(float(scored.size()), 1.0)) * 0.75 \
		+ (complete_total / float(VolleyballPlayer.ABILITY_ATTRIBUTES.size())) * 0.25


## Derives each attribute from the ceiling minus the still-unrealised growth
## reserve, then applies role-tier bonuses (+15 primary, +5 secondary, -8
## tertiary) and a regional specialty bonus (+8). The bonuses redistribute
## ability across a role's profile; they do not inflate its total, so
## `current_ability_score()` lands at the intended level and stays under
## `potential`.
static func _apply_attributes(
	player: VolleyballPlayer,
	region_name: String,
	rng: RandomNumberGenerator,
	academy: bool,
) -> void:
	var primary_list: Array = Array(
		VolleyballPlayer.POSITION_WEIGHTS.get(player.position_role, [])
	)
	var secondary_list: Array = Array(ROLE_SECONDARY.get(player.position_role, []))
	var specialty_list: Array = Array(REGION_SPECIALTY.get(region_name, []))
	## The ability score this player should currently display, and the flat
	## level each attribute starts from to produce it.
	var target_score := float(player.potential) \
		- _growth_reserve(player.age, rng, academy)
	var base := target_score - _ability_score_offset(
		primary_list, secondary_list, specialty_list
	)
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		player.set(property_name, clampi(
			roundi(base) + _tier_bonus(
				property_name, primary_list, secondary_list, specialty_list
			) + rng.randi_range(-8, 8),
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
