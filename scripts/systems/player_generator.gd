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
##
## Xérvu carries a wingspan-led bias rather than a height/mass one: serving
## leans on arm swing and reach, not on being the tallest or heaviest player
## on the court. Taktikã carries a small negative bias in all three -- a
## tactical region's identity is game intelligence, not physical presence, and
## a slightly smaller-than-average profile reinforces that this specialty
## isn't won by size. Landavol stays at zero across the board: the one region
## with no physical lean at all, matching it now having no attribute
## specialty either (see REGION_SPECIALTY below). Ispayk is lean rather than
## bulky -- craft over size, matching a program built on setting touch and a
## quick arm rather than raw mass. A'ace leans slightly positive across all
## three: assembled, well-resourced athletes rather than a developed body
## type of its own.
const REGION_HEIGHT_BIAS := {
	"Pāwa Hitō": 4.0, "Spëddigh": -2.0, "Bloc du Larg": 1.0, "Landavol": 0.0,
	"Xérvu": 1.0, "Taktikã": -1.0, "Ispayk": 0.0, "A'ace": 1.0,
}
const REGION_MASS_BIAS := {
	"Pāwa Hitō": 5.0, "Spëddigh": -3.0, "Bloc du Larg": 1.0, "Landavol": 0.0,
	"Xérvu": 0.0, "Taktikã": -1.0, "Ispayk": -1.0, "A'ace": 1.0,
}
const REGION_WINGSPAN_BIAS := {
	"Pāwa Hitō": 3.0, "Spëddigh": -2.0, "Bloc du Larg": 2.0, "Landavol": 0.0,
	"Xérvu": 2.0, "Taktikã": 0.0, "Ispayk": 1.0, "A'ace": 1.0,
}

## Attributes that receive a +8 specialty bonus for players from each region.
##
## Serving and the abstract mental/tactical attributes used to be scattered
## across other regions with no home of their own (Pāwa Hitō carried
## serve_power as one bonus among five; Bloc du Larg and Landavol both leaned
## mental with overlapping attributes). Xérvu and Taktikã now own those
## identities outright, which is also why Pāwa Hitō drops serve_power and
## Bloc du Larg drops tactical_discipline -- each specialty lives in exactly
## one region rather than being diluted across several.
##
## Landavol has no specialty at all: it is deliberately the generic, no-lean
## region, so every attribute develops purely on role and talent there.
##
## Ispayk owns Setting & Ball Control -- the one wheel category that no
## region specialized in before -- plus attack_power and shot_variety for the
## "and spike" half of its set-and-spike identity. A'ace deliberately gets
## only three attributes spanning three different categories (attack_power,
## serve_power, block_timing) rather than one deep specialty: it represents
## assembled star talent across a few glamour positions bought in with money,
## not a systemic developmental identity the way every other region's
## specialty represents an actual local training tradition.
const REGION_SPECIALTY := {
	"Pāwa Hitō": ["attack_power", "block_timing", "jump_reach", "explosiveness"],
	"Spëddigh": ["acceleration", "lateral_speed", "reception_balance", "reception_stability", "dig_control"],
	"Bloc du Larg": ["block_timing", "ball_control", "court_vision", "anticipation"],
	"Landavol": [],
	"Xérvu": ["serve_power", "serve_technique", "serve_placement", "serve_consistency",
		"serve_aggression", "serve_variation"],
	"Taktikã": ["decision_making", "composure", "tactical_discipline", "improvisation",
		"adaptability", "unpredictability"],
	"Ispayk": ["set_accuracy", "set_disguise", "tempo_control", "hand_control",
		"attack_power", "shot_variety"],
	"A'ace": ["attack_power", "serve_power", "block_timing"],
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
		_apply_body_variation(player, rng, canonical_region)
		player.stride_length_m = player.default_stride_length_m()
		## Sets every attribute and derives `potential` from the ceilings it built.
		_apply_attributes(player, canonical_region, rng, academy)
		Familiarity.initialize_player(player, rng)
		AttributeProfiles.assign_serve_style(player)
		result.append(player)
	return result


## Attributes that fade with age rather than keep developing. Power and
## turnover peak in the early twenties and go backwards afterwards; technique
## and reading do not.
const PHYSICAL_ATTRIBUTES: Array[String] = [
	"acceleration", "lateral_speed", "transition_speed", "jump_reach",
	"explosiveness", "stamina", "arm_speed", "serve_power", "attack_power",
]

## Attributes that keep improving for as long as a player keeps playing.
const MENTAL_ATTRIBUTES: Array[String] = [
	"court_vision", "anticipation", "decision_making", "composure",
	"tactical_discipline", "improvisation", "adaptability", "unpredictability",
]

## Age at which physical qualities stop improving and begin to fade.
const PHYSICAL_PEAK_AGE: int = 24

## Chance an attribute is innately far from the player's general level, and how
## far. Most attributes sit near it; a minority do not, and those are what make
## a player worth scouting rather than a uniform block of numbers. A teenager
## with a freakish leap and no reading, or a veteran with one glaring hole, both
## come from here.
const STANDOUT_CHANCE: float = 0.06
const DEFICIENCY_CHANCE: float = 0.06
const ORDINARY_SPREAD: float = 6.0
const OUTLIER_MINIMUM: float = 14.0
const OUTLIER_MAXIMUM: float = 30.0


## How far a single attribute sits from the player's general level, innately.
static func _innate_deviation(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < STANDOUT_CHANCE:
		return rng.randf_range(OUTLIER_MINIMUM, OUTLIER_MAXIMUM)
	if roll < STANDOUT_CHANCE + DEFICIENCY_CHANCE:
		return -rng.randf_range(OUTLIER_MINIMUM, OUTLIER_MAXIMUM)
	return rng.randf_range(-ORDINARY_SPREAD, ORDINARY_SPREAD)


## Rating points still separating this attribute from its own ceiling.
##
## The same number covers two different causes, which is why it is one function.
## For a young player it is undevelopment: they have not grown into the quality
## yet. For an old player in a physical attribute it is decline: they had it and
## are losing it. Both are honestly described as "distance from your ceiling",
## and the cause is recorded separately so scouting can tell them apart.
##
## The three categories age on genuinely different curves. A seventeen-year-old
## is already close to their physical ceiling and nowhere near their tactical
## one, which is exactly what lets a gifted teenager compete with a veteran:
## they are not a worse player, they are a differently-shaped one.
static func _attribute_reserve(
	property_name: String,
	age: int,
	rng: RandomNumberGenerator,
) -> float:
	var jitter := rng.randf_range(-3.0, 3.0)
	if property_name in PHYSICAL_ATTRIBUTES:
		if age <= PHYSICAL_PEAK_AGE:
			return maxf(lerpf(
				12.0, 1.5,
				clampf(float(age - 15) / float(PHYSICAL_PEAK_AGE - 15), 0.0, 1.0)
			) + jitter, 0.0)
		## Past peak the gap reopens, and this time it is loss rather than youth.
		return maxf(1.5 + float(age - PHYSICAL_PEAK_AGE) * 1.9 + jitter, 0.0)
	if property_name in MENTAL_ATTRIBUTES:
		return maxf(lerpf(
			38.0, 1.0, clampf(float(age - 15) / 19.0, 0.0, 1.0)
		) + jitter, 0.0)
	return maxf(lerpf(
		28.0, 1.0, clampf(float(age - 15) / 15.0, 0.0, 1.0)
	) + jitter, 0.0)


## The general level this player was born with, before role, region, and innate
## per-attribute variation shape it. Age must not touch it: doing so conflates
## being old with being untalented and guarantees veterans are the weaker
## players. Academies scout for ceiling, so their intake skews high -- that is a
## selection effect, not an age effect.
static func _talent_level(rng: RandomNumberGenerator, academy: bool) -> int:
	return rng.randi_range(62, 92) if academy else rng.randi_range(48, 90)


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


## Builds this player's per-attribute ceilings and the current values that sit
## below them, then derives `potential` from the ceilings themselves.
##
## Potential is no longer rolled and then approximated. It is the ability score
## this player *would* display with every attribute at its own ceiling, computed
## with the same weighting `current_ability_score()` uses. That makes the bound
## exact by construction rather than by correction: current ability is the same
## function of strictly smaller numbers, so it cannot exceed potential, and the
## offset hack this replaces is gone.
##
## Each ceiling is the player's general talent shifted by what their role
## demands, what their region produces, and an innate per-attribute deviation
## that is usually small and occasionally extreme. That last term is what allows
## a teenager with a freakish leap and nothing else, or a veteran with one
## glaring hole.
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
	var talent := float(_talent_level(rng, academy))

	var ceilings := {}
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		ceilings[property_name] = clampf(
			talent
			+ float(_tier_bonus(
				property_name, primary_list, secondary_list, specialty_list
			))
			+ _innate_deviation(rng),
			1.0, 99.0,
		)

	## Potential is what those ceilings are worth, scored exactly as current
	## ability will be scored.
	player.potential = _weighted_score(ceilings, primary_list)

	## Kept individually, not only as the aggregate above -- a potential
	## attribute wheel reads this rather than approximating a shape from one
	## number. Rounded to match every other attribute's integer scale.
	player.attribute_ceilings.clear()
	for property_name in ceilings:
		player.attribute_ceilings[property_name] = roundi(float(ceilings[property_name]))

	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		var ceiling := float(ceilings[property_name])
		var reserve := _attribute_reserve(property_name, player.age, rng)
		player.set(property_name, clampi(
			roundi(ceiling - reserve), 1, roundi(ceiling)
		))


## The role-weighted ability score of an attribute set. Mirrors
## `VolleyballPlayer.current_ability_score()`; if that weighting changes, this
## must follow, and the regression check comparing a fully-developed player's
## score against their potential is what catches it.
static func _weighted_score(values: Dictionary, primary_list: Array) -> int:
	var scored: Array = primary_list if not primary_list.is_empty() \
		else VolleyballPlayer.ABILITY_ATTRIBUTES
	var role_total := 0.0
	for property_name in scored:
		role_total += float(values.get(str(property_name), 0.0))
	var role_score := role_total / maxf(float(scored.size()), 1.0)
	var complete_total := 0.0
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		complete_total += float(values.get(property_name, 0.0))
	var complete_score := complete_total \
		/ float(VolleyballPlayer.ABILITY_ATTRIBUTES.size())
	return clampi(roundi(role_score * 0.75 + complete_score * 0.25), 1, 100)


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
