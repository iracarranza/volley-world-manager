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
## specialty either (see REGION_SPECIALTY below). Ĭspayk now carries the
## largest frame bias: its bomba tradition is built around terminal power.
##
## **Pāwa Hitō is large, and was not.** It sat at 0/-1/0 on the reasoning that
## its distinction was repeated effort rather than mass -- but the design is
## explicit that these are big volis with big batteries, and that the damage
## they do is a *consequence* of size arriving at a defence that has nothing
## left. Their attribute list carries no attacking attribute at all now, so the
## frame is where the threat has to live, alongside `fatigue_resistance`.
##
## Blôc du Larg rises for the same kind of reason and by a different route: its
## specialty list gave up `jump_reach` so that Ĭspayk could own air presence
## outright, which means Largôis size must be stated here or nowhere.
##
## A'ace leans slightly positive across all three: assembled, well-resourced
## athletes rather than a developed body type of its own.
const REGION_HEIGHT_BIAS := {
	"Pāwa Hitō": 3.0, "Spëddigh": -2.0, "Blôc du Larg": 3.0, "Landavol": 0.0,
	"Xérvu": 1.0, "Taktikã": -1.0, "Ĭspayk": 4.0, "A'ace": 1.0,
	"Tãul ys Feynt": -3.0,
	"Lo-ong Ralī": -5.0,
	"Bompaçao": -2.0,
	"Rhėn Tempaol": -1.0,
	"Kutré Lyn": 0.0,
	"Zaitgaist": 0.0,
}
const REGION_MASS_BIAS := {
	"Pāwa Hitō": 4.0, "Spëddigh": -3.0, "Blôc du Larg": 2.0, "Landavol": 0.0,
	"Xérvu": 0.0, "Taktikã": -1.0, "Ĭspayk": 5.0, "A'ace": 1.0,
	"Tãul ys Feynt": -4.0,
	"Lo-ong Ralī": -5.0,
	"Bompaçao": -1.0,
	"Rhėn Tempaol": -3.0,
	"Kutré Lyn": -2.0,
	"Zaitgaist": 0.0,
}
const REGION_WINGSPAN_BIAS := {
	"Pāwa Hitō": 2.0, "Spëddigh": -2.0, "Blôc du Larg": 4.0, "Landavol": 0.0,
	"Xérvu": 2.0, "Taktikã": 0.0, "Ĭspayk": 3.0, "A'ace": 1.0,
	"Tãul ys Feynt": -2.0,
	"Lo-ong Ralī": -3.0,
	"Bompaçao": 0.0,
	"Rhėn Tempaol": -1.0,
	"Kutré Lyn": 0.0,
	"Zaitgaist": 0.0,
}

## Attributes that receive a +8 specialty bonus for players from each region.
##
## Serving and the abstract mental/tactical attributes used to be scattered
## across other regions with no home of their own (Pāwa Hitō carried
## serve_power as one bonus among five; Blôc du Larg and Landavol both leaned
## mental with overlapping attributes). Xérvu and Taktikã now own those
## identities outright, which is also why Pāwa Hitō drops serve_power and
## Blôc du Larg drops tactical_discipline -- each specialty lives in exactly
## one region rather than being diluted across several.
##
## Landavol has no specialty at all: it is deliberately the generic, no-lean
## region, so every attribute develops purely on role and talent there.
##
## Pāwa Hitō sustains repeated transition attacks; Spëddigh spends effort and
## tempo to keep every phase moving; Taktikã develops players whose execution
## changes little with emotional match flow; Ĭspayk develops the large, fast
## arm and terminal contact behind its bomba tradition. A'ace deliberately gets
## only three attributes spanning three different categories (attack_power,
## serve_power, block_timing) rather than one deep specialty: it represents
## assembled star talent across a few glamour positions bought in with money,
## not a systemic developmental identity the way every other region's
## specialty represents an actual local training tradition.
const REGION_SPECIALTY := {
	## **A battery, not a swing.** Pāwa Hitō's power is a *consequence* and the
	## list is deliberately short to say so: they are large volis who are still
	## going in the fifth set, and the damage they do is done to defenders who are
	## not. Nothing here is an attacking attribute, because the attacking comes
	## from `fatigue_resistance` 0.55 holding them at full output while everybody
	## else labours, and from a frame that was raised to match the fiction.
	##
	## `approach_timing` and `attack_accuracy` were dropped from here rather than
	## from Ĭspayk: those are a spike being *perfected*, which is Ĭspayk's whole
	## claim, and having them in both was the single worst overlap in the table --
	## the two regions the design most needed to separate shared two attributes.
	"Pāwa Hitō": ["stamina", "transition_speed", "explosiveness"],
	"Spëddigh": ["work_rate", "acceleration", "lateral_speed", "tempo_control", "reception_balance"],
	## **A wall and the floor behind it, not a side that out-thinks you.**
	##
	## `court_vision` and `tactical_discipline` spelled this region as *analysis*
	## -- a side that studies you and adjusts -- and that was never what the wall
	## is for. A Largôis block does not need to guess right, because it is long
	## enough and quick enough to get a hand on the shot it guessed wrong about.
	## `anticipation` stays removed for a separate reason: it is 0.30 of dig
	## capability and 0.34 of a blocker's read, so holding it made the blocking
	## tradition the best digging tradition too.
	##
	## The cut before this one reached for
	## `lateral_speed` and `explosiveness`, which are Spëddigh's and Pāwa Hitō's,
	## so the region built on coverage was expressed in two other regions'
	## vocabulary. Size is now carried by the physique bias instead of by
	## `jump_reach` -- a different channel from Ĭspayk's air presence, which is
	## what lets both regions be tall without being the same claim -- and the
	## attributes say the thing the fiction actually says: they touch what you
	## hit, and what gets past the wall is still dug.
	"Blôc du Larg": ["block_timing", "reception_stability", "dig_control",
		"ball_control"],
	"Landavol": [],
	"Xérvu": ["serve_power", "serve_technique", "serve_placement", "serve_consistency",
		"serve_aggression", "serve_variation"],
	"Taktikã": ["decision_making", "composure", "tactical_discipline",
		"adaptability", "unpredictability"],
	## **One polished swing, fed as often as possible.** Ĭspayk is not Pāwa Hitō
	## with a bigger frame: Pāwa's claim is *repetition* -- the sixth attack of a
	## rally as good as the first -- and Ĭspayk's is a single terminal contact so
	## well drilled that it goes through a block rather than around one. The
	## bomba is a technique, not an engine.
	##
	## So `shot_variety` goes, and it is the point of the change rather than a
	## trim: a side that can hit six different shots is not predictable, and being
	## predictable is what Ĭspayk is supposed to *cost*. What replaces it is more
	## of the same swing -- `approach_timing` and `attack_accuracy` are the
	## polish, `attack_power` and `arm_speed` the terminal contact. A defence that
	## has seen it enough times knows exactly where it is going, which is what
	## makes the region beatable by the traditions built on reading.
	##
	## `block_timing` is dropped for a different reason: it sat in three regions
	## at once, so the blocking tradition, the bomba tradition and the bought
	## squad all claimed it and none of them owned it.
	"Ĭspayk": ["attack_power", "arm_speed", "jump_reach", "approach_timing",
		"attack_accuracy"],
	## **Bought terminal ability, and nothing that makes a team of it.**
	##
	## A'ace does not develop volis, it assembles them, and what it shops for is
	## exactly what shows on a highlight: somebody who ends points, wants the
	## ball, and is already good now. `attack_power` and `block_timing` are the
	## two point-ending contacts in the sport and both stay. `leadership` joins
	## them because A'ace recruits for it as openly as for the swing -- a squad of
	## strangers is bought a captain rather than growing one.
	##
	## What it cannot buy is a shared idea of how to play, and that is priced as a
	## real cost rather than a smaller bonus: see `REGION_TACTICAL_PENALTY`, which
	## takes `tactical_discipline`, `decision_making` and `court_vision` off
	## anybody A'ace raised. The fiction is a region with no historical volleyball
	## presence, so its own academies teach the swing and not the game -- and a
	## strong team that is not coached into strong decisions does not find the
	## situations its terminal players are bought for.
	"A'ace": ["attack_power", "block_timing", "leadership"],

	## Minor regions: two or three attributes, not four to six. The tier's
	## whole proposition is a narrow, deep tradition rather than a broad one,
	## and two of these fill gaps no major region claims -- `reception`, the
	## core passing technique (Spëddigh owns balance and pace resistance but
	## never reception itself), and `attack_accuracy`, claimed by nobody at all
	## despite being primary for three of the five roles.
	"Tãul ys Feynt": ["feinting", "tooling", "finesse"],
	## The long-rally tradition, which was worse at digging than the blocking
	## tradition. `dig_control` is only 0.22 of dig capability and
	## `reception_stability` enters a dig solely through the body penalty, so two
	## of its three attributes barely reached the floor. `anticipation` is 0.30
	## and is the one Blôc du Larg gives up, which takes this region from 0.22 of
	## the dig model to 0.52 without poaching `reception` -- Bompaçao's claim,
	## and the only attribute that outweighs it.
	"Lo-ong Ralī": ["stamina", "dig_control", "anticipation"],
	"Bompaçao": ["reception", "reception_balance", "ball_control"],
	"Rhėn Tempaol": ["approach_timing", "arm_speed", "transition_speed"],
	"Kutré Lyn": ["attack_accuracy", "shot_variety", "court_vision"],
	## Zaitgaist has no tradition of its own. Its specialty comes entirely from
	## `region_overlay`, rewritten each season to mirror whoever last won the
	## Sixnet -- see `SixnetLeague.apply_influence_drift()`.
	"Zaitgaist": [],
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
			"serve_variation", "explosiveness", "arm_speed", "work_rate"],
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


## `overlay` is this region's Sixnet influence-drift shape for the current
## save (see `career_state.gd`'s `region_overlay`, keyed by region name --
## callers pass `region_overlay.get(region_name, {})`, not the whole
## multi-region dict). Empty (the default) means "no drift yet" and produces
## output byte-identical to before this parameter existed: every existing
## caller passes 3 args and is unaffected. Recognized keys: `specialty_add`
## (Array[String], extra attributes added to the region's own specialty
## list), `specialty_bonus_delta` (float, added to the flat +8 specialty
## bonus), `height_bias_delta`/`mass_bias_delta`/`wingspan_bias_delta`
## (float, added to the region's physique bias).
static func generate_roster(
	region_name: String,
	organization_type: String,
	seed_value: int,
	overlay: Dictionary = {},
) -> Array[VolleyballPlayer]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var canonical_region := VolleyballRegions.canonical_name(region_name)
	## **A founded club is small and young; an established one is neither.**
	##
	## This branched on `"Academy"`, which is a dead value -- the academy is the
	## region's selection body and nobody manages one. What the branch was
	## actually describing survives the rename intact: the option that gave you
	## twelve younger volis with more headroom is the club you started yourself,
	## which is who signs for a side with no history. An established club hands
	## you a squad somebody else picked.
	##
	## The old value is still read so a save written before the recut regenerates
	## the roster it had rather than a different one.
	var founded := organization_type == "Founded" or organization_type == "Academy"
	var roster_size := 12 if founded else 10
	var academy := founded
	var result: Array[VolleyballPlayer] = []
	for index in range(roster_size):
		var position: Dictionary = POSITIONS[index % POSITIONS.size()]
		var player := VolleyballPlayer.new()
		player.id = index + 1
		player.display_name = VolleyballRegions.person_name(canonical_region, index)
		player.position_role = str(position.role)
		player.position_code = str(position.code)
		player.home_region = canonical_region
		player.apply_role_physical_defaults()
		player.age = rng.randi_range(16, 20) if academy else rng.randi_range(21, 31)
		player.professional_experience = 0 if academy else maxi(player.age - 20, 1)
		assign_body_type(player, rng)
		assign_ego(player, rng, canonical_region)
		assign_aggression(player, rng, canonical_region)
		assign_leadership(player, rng, canonical_region)
		_apply_body_variation(player, rng, canonical_region, overlay)
		player.stride_length_m = player.default_stride_length_m()
		## Sets every attribute and derives `potential` from the ceilings it built.
		_apply_attributes(player, canonical_region, rng, academy, overlay)
		Familiarity.initialize_player(player, rng)
		AttributeProfiles.assign_serve_style(player)
		result.append(player)
	return result


## How many times `generate_prospect` may re-roll a player to land on the
## requested potential. Absent attribute clamping the relationship between
## general talent and resulting potential is exactly linear, so the first
## correction is normally exact and this loop exits after two passes; the
## extra attempts only matter at the very top of the scale, where individual
## attribute ceilings saturate at 99 and the correction undershoots.
const PROSPECT_CALIBRATION_ATTEMPTS: int = 8


## Builds one player to order: a specific region, role, age and *potential*,
## rather than whatever the dice happen to produce. This is what the world
## population is built from -- talent has to be an allocated, scarce resource
## for the world to have a believable shape, which means the generator has to
## be able to fill a request rather than only roll freely.
##
## Current ability is deliberately *not* a parameter: it falls out of age via
## the same `_attribute_reserve` curve every other generated player uses, so
## a 16-year-old at potential 95 is a raw wonderkid and a 29-year-old at
## potential 95 is an established star, from the same one input.
static func generate_prospect(
	region_name: String,
	position_role: String,
	position_code: String,
	age: int,
	target_potential: int,
	player_id: int,
	display_name: String,
	seed_value: int,
	overlay: Dictionary = {},
) -> VolleyballPlayer:
	var best: VolleyballPlayer = null
	var best_error := 1000
	## First guess: potential sits above raw talent by the role/specialty tier
	## bonuses, which average out near this much across the attribute set.
	var talent := float(target_potential) - 8.0
	for _attempt in range(PROSPECT_CALIBRATION_ATTEMPTS):
		var candidate := _build_prospect(
			region_name, position_role, position_code, age,
			talent, player_id, display_name, seed_value, overlay,
		)
		var error := int(candidate.potential) - target_potential
		if absi(error) < best_error:
			best_error = absi(error)
			best = candidate
		if error == 0:
			break
		talent = clampf(talent - float(error), 1.0, 99.0)
	return best


## One deterministic player at a fixed general-talent level. Every attempt in
## `generate_prospect`'s calibration loop reseeds from the same
## `seed_value`, so the innate per-attribute deviations are identical between
## attempts and only the talent term moves -- which is exactly what makes the
## correction exact rather than a search.
static func _build_prospect(
	region_name: String,
	position_role: String,
	position_code: String,
	age: int,
	talent: float,
	player_id: int,
	display_name: String,
	seed_value: int,
	overlay: Dictionary,
) -> VolleyballPlayer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var canonical_region := VolleyballRegions.canonical_name(region_name)
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = display_name
	player.position_role = position_role
	player.position_code = position_code
	player.home_region = canonical_region
	player.apply_role_physical_defaults()
	player.age = age
	player.professional_experience = maxi(age - 20, 0)
	assign_body_type(player, rng)
	assign_ego(player, rng, canonical_region)
	assign_aggression(player, rng, canonical_region)
	assign_leadership(player, rng, canonical_region)
	_apply_body_variation(player, rng, canonical_region, overlay)
	player.stride_length_m = player.default_stride_length_m()
	_apply_attributes(player, canonical_region, rng, age <= 20, overlay, talent)
	Familiarity.initialize_player(player, rng)
	AttributeProfiles.assign_serve_style(player)
	return player


## Moves an existing player to a new age and recomputes what they can
## currently do, from the ceilings they were built with.
##
## Development is not modelled as a separate system on purpose. A player's
## current ability was already defined as "their ceiling, minus however far
## from it their age leaves them" -- so aging them is the same statement
## evaluated at a new age, using the identical curve. A season of growth for
## a nineteen-year-old and a season of decline for a thirty-four-year-old
## both fall out of that without a second model that could disagree with the
## first.
##
## `seed_value` should be stable per player, so a career sees smooth
## progression rather than the per-attribute jitter resampling every year.
##
## Two consequences worth being explicit about. Development is purely a
## function of age here, with no path dependence -- nobody fails to reach
## their ceiling through misfortune, and nobody exceeds it. And a player
## with no stored ceilings (hand-authored fixtures) is treated as already
## being at their ceiling, so they decline with age but never grow.
static func redevelop_to_age(
	player: VolleyballPlayer, new_age: int, seed_value: int,
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	player.age = clampi(new_age, 15, 45)
	player.professional_experience = maxi(player.age - 20, 0)
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		var ceiling := float(player.attribute_ceilings.get(
			property_name, player.get(property_name)
		))
		var reserve := _attribute_reserve(property_name, player.age, rng) \
			* _generational_reserve_scale(player.potential, player.age)
		player.set(property_name, clampi(
			roundi(ceiling - reserve), 1, maxi(roundi(ceiling), 1)
		))
	AttributeProfiles.assign_serve_style(player)


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
	"work_rate",
]

## Age at which physical qualities stop improving and begin to fade.
const PHYSICAL_PEAK_AGE: int = 24

## Age after which technique starts to erode too, and how fast.
##
## Only nine of the forty ability attributes are physical, so with technique
## and reading both rising monotonically to their ceiling and then holding
## there forever, a player's *overall* ability barely moved after thirty: a
## thirty-eight-year-old setter measured exactly as good as they were at
## thirty-three, and an outside hitter lost two points across five years.
## That made retirement the only thing that ever removed a veteran from the
## world, which is not how a career ends.
##
## Reading is deliberately left alone -- game sense genuinely does hold up,
## and it is the reason an old setter stays useful long after the legs go.
## The erosion here is technique: hands, timing, sharpness.
const TECHNICAL_PEAK_AGE: int = 30
const TECHNICAL_DECLINE_PER_YEAR: float = 0.9

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
				9.0, 1.5,
				clampf(float(age - 15) / float(PHYSICAL_PEAK_AGE - 15), 0.0, 1.0)
			) + jitter, 0.0)
		## Past peak the gap reopens, and this time it is loss rather than youth.
		return maxf(1.5 + float(age - PHYSICAL_PEAK_AGE) * 1.9 + jitter, 0.0)
	if property_name in MENTAL_ATTRIBUTES:
		return maxf(lerpf(
			26.0, 1.0, clampf(float(age - 15) / 19.0, 0.0, 1.0)
		) + jitter, 0.0)
	var technical_reserve := lerpf(
		17.0, 1.0, clampf(float(age - 15) / 15.0, 0.0, 1.0)
	)
	if age > TECHNICAL_PEAK_AGE:
		technical_reserve += float(age - TECHNICAL_PEAK_AGE) * TECHNICAL_DECLINE_PER_YEAR
	return maxf(technical_reserve + jitter, 0.0)


## Generational prospects still develop normally as teenagers, so an S ceiling
## is not a scouting spoiler. Once they enter their prime they realize almost
## all of that ceiling and become the only reliable source of current S players;
## the scale opens again with age so even historic talent eventually declines.
static func _generational_reserve_scale(potential: int, age: int) -> float:
	if potential < int(AttributeProfiles.GRADE_S_MIN) or age < 23:
		return 1.0
	if age <= 30:
		return 0.08
	if age <= 34:
		return lerpf(0.08, 0.45, float(age - 30) / 4.0)
	return lerpf(0.45, 1.0, clampf(float(age - 34) / 4.0, 0.0, 1.0))


## The general level this player was born with, before role, region, and innate
## per-attribute variation shape it. Age must not touch it: doing so conflates
## being old with being untalented and guarantees veterans are the weaker
## players. Academies scout for ceiling, so their intake skews high -- that is a
## selection effect, not an age effect.
static func _talent_level(rng: RandomNumberGenerator, academy: bool) -> int:
	return rng.randi_range(62, 92) if academy else rng.randi_range(48, 90)


## Produces correlated individual bodies around role templates, shifted by
## region physique bias. Stride is updated by the caller after this returns.
## Morphology, drawn uniformly. Every region produces every body type in equal
## proportion, everywhere, always -- this is a fixed property of the world and
## the one rule here that must never be softened into a tuning value.
##
## The reason is design intent rather than caution. Regional difference is
## already carried by REGION_SPECIALTY, the body biases, and the tier and
## positional affinities in world_population.gd; regions are *supposed* to feel
## distinct. Weighting body type regionally on top of that would immediately
## read as "people from here are built like that", which is the one reading
## this must never support. A flat draw keeps morphology orthogonal to origin,
## so a Tãul ys Feynt Ursi and a Pāwa Hitō Ursi are the same body in different
## traditions and the *tradition* is what differs.
const BODY_TYPES: Array[String] = ["Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi"]

## Body-metric deltas, applied after the regional bias so the two compose.
const BODY_TYPE_METRICS := {
	## Stride is deliberately absent. It is derived from post-variation height
	## and pinned by a regression check, so morphology reaches locomotion
	## through height and mass rather than by offsetting stride directly.
	## Vegi is the no-lean body, the way Landavol is the no-lean region: it
	## exists so "unremarkable" has a home instead of every type needing an
	## identity. It replaced Homi outright -- a plain human body in a world of
	## animals and produce was the one type that was not *anything*.
	"Vegi": {"height": 0.0, "mass": 0.0, "wingspan": 0.0},
	"Avi": {"height": -4.0, "mass": -7.0, "wingspan": 6.0},
	"Cani": {"height": 0.0, "mass": 2.0, "wingspan": 0.0},
	"Feli": {"height": -3.0, "mass": -4.0, "wingspan": 0.0},
	"Ursi": {"height": 1.0, "mass": 11.0, "wingspan": 1.0},
	"Simi": {"height": -6.0, "mass": -5.0, "wingspan": 2.0},
}

## Attribute deltas, applied to the *ceiling* rather than only to the generated
## value. If a body type shifted starting values alone, training would converge
## everyone and morphology would quietly evaporate over a few seasons, leaving
## character-creation flavour instead of a permanent identity.
##
## Each type sums to zero. That is not decoration: the first pass had every
## type net positive, which inflated the generated population against the
## hand-authored fixture roster (whose players default to Homi and take no
## deltas) and tripped three balance checks that had been calibrated on a
## uniform population. A body type has to trade, not upgrade.
##
## Avi carries no attack_power penalty despite being the lightest: mass already
## feeds `usable_attack_power()`, so applying one here would count it twice.
## Feli's stamina penalty is likewise load-bearing rather than cosmetic --
## `GameManager.stamina_fatigue_scale()` reads stamina directly, so a Feli
## measurably tires faster inside a single match. First-set terror, fifth-set
## liability, with no new mechanism.
const BODY_TYPE_ATTRIBUTES := {
	"Vegi": {},
	"Avi": {"jump_reach": 4.0, "block_timing": 2.0, "reception_stability": -6.0},
	"Cani": {"stamina": 3.5, "transition_speed": 3.0, "attack_power": 2.0,
		"jump_reach": -4.5, "hand_control": -4.0},
	"Feli": {"explosiveness": 4.0, "lateral_speed": 3.0, "dig_control": 2.5,
		"set_disguise": 2.0, "stamina": -6.0, "tactical_discipline": -5.5},
	"Ursi": {"reception_stability": 4.0, "attack_power": 3.0, "composure": 2.0,
		"acceleration": -3.5, "lateral_speed": -3.0, "jump_reach": -2.5},
	"Simi": {"hand_control": 4.0, "ball_control": 3.5, "finesse": 3.0,
		"tooling": 2.0, "attack_power": -7.0, "jump_reach": -5.5},
}


static func assign_body_type(player: VolleyballPlayer, rng: RandomNumberGenerator) -> void:
	player.body_type = BODY_TYPES[rng.randi_range(0, BODY_TYPES.size() - 1)]


## How much a region's players back themselves, and how much a role attracts
## players who do.
##
## Generated here rather than through `_apply_attributes` because `ego` is not
## in `ABILITY_ATTRIBUTES` -- it is a temperament, so it has no ceiling, does not
## train, and must not feed a category rating. See the note on the field.
##
## The regional leans follow the identities the world already has: Ĭspayk swings
## first and asks later, Taktikã is the region built on not being moved, and
## Xérvu's whole game is a high-risk serve that either wins the set or loses it.
const REGION_EGO_BIAS := {
	"Ĭspayk": 14.0, "Xérvu": 9.0, "Pāwa Hitō": 5.0, "A'ace": 6.0,
	"Spëddigh": 2.0, "Landavol": 0.0, "Blôc du Larg": -6.0, "Taktikã": -15.0,
	## Minor regions, listed rather than defaulted so a reader can see that the
	## silence is deliberate. The deception traditions back themselves; the
	## endurance and passing traditions are built on not needing to.
	"Tãul ys Feynt": 7.0,
	"Lo-ong Ralī": -9.0,
	"Bompaçao": -7.0,
	"Rhėn Tempaol": 3.0,
	"Kutré Lyn": 1.0,
	"Zaitgaist": 0.0,
}

## Terminal roles attract players who want the ball; the roles that keep a rally
## alive attract players who would rather it went somewhere else.
const POSITION_EGO_BIAS := {
	"Opposite": 9.0, "Outside Hitter": 5.0, "Middle Blocker": 0.0,
	"Setter": -4.0, "Libero": -8.0,
}


## How much the rest of the side plays up around this player.
##
## Generated here rather than through `_apply_attributes` because leadership
## left `ABILITY_ATTRIBUTES` -- it acts on teammates rather than on this
## player's own contacts, so it must not feed a capability rating. Without an
## explicit assignment every player would silently sit at the default 50.
##
## Roles that organise the court from within it carry more of it; the roles
## judged on terminal contacts carry less. Deliberately a milder spread than
## ego, because a squad of twelve wildly varying leaders reads as noise rather
## than as a captaincy question.
const POSITION_LEADERSHIP_BIAS := {
	"Setter": 8.0, "Libero": 5.0, "Middle Blocker": 0.0,
	"Outside Hitter": -1.0, "Opposite": -3.0,
}


static func assign_leadership(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	region_name: String,
) -> void:
	## Its own stream, for the same reason ego has one: drawing from the shared
	## generation rng advances it for every attribute after, so adding this
	## silently rerolls the world.
	var leadership_rng := RandomNumberGenerator.new()
	leadership_rng.seed = hash("%d|leadership|%d|%s" % [
		rng.seed, player.id, region_name,
	])
	player.leadership = clampi(roundi(
		leadership_rng.randfn(50.0, 12.0)
		+ float(POSITION_LEADERSHIP_BIAS.get(player.position_role, 0.0))
		+ float(player.age - 24) * 0.6
	), 1, 100)


static func assign_ego(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	region_name: String,
) -> void:
	## Drawn from its own stream rather than the shared generation one.
	##
	## Taking a number from `rng` here advances it for everything generated
	## afterwards, so adding this attribute silently rerolled every player in the
	## world -- two balance fixtures failed on a change that touches no
	## simulation code at all. Deriving a private seed keeps ego independent, so
	## it can be added, removed or retuned without perturbing a single other
	## attribute. `rng.seed` is the seed it was configured with, not its running
	## state, so this stays stable no matter when it is called.
	var ego_rng := RandomNumberGenerator.new()
	ego_rng.seed = hash("%d|ego|%d|%s" % [rng.seed, player.id, region_name])
	## Wide on purpose. Ego is the one axis where the extremes are the
	## interesting players rather than the broken ones, so it should not cluster
	## the way a skill does.
	var base := ego_rng.randfn(50.0, 16.0)
	player.ego = clampi(roundi(
		base
		+ float(REGION_EGO_BIAS.get(region_name, 0.0))
		+ float(POSITION_EGO_BIAS.get(player.position_role, 0.0))
	), 1, 100)


## How committed a region's and a role's players are to ending the rally.
##
## Shares the shape of the ego biases and deliberately not their values: the two
## used to be one number and separating them is worthless if the biases keep
## them correlated. Ĭspayk leads both, because swinging first and backing
## yourself genuinely are the same tradition -- but Taktikã is the region built
## on not being moved, which is high ego and *low* aggression, and Blôc du Larg
## defends rather than closes, which is the reverse of its ego lean.
const REGION_AGGRESSION_BIAS := {
	"Ĭspayk": 15.0, "Xérvu": 11.0, "Pāwa Hitō": 7.0, "A'ace": 4.0,
	"Spëddigh": 3.0, "Landavol": 0.0, "Blôc du Larg": -4.0, "Taktikã": -9.0,
	"Tãul ys Feynt": -3.0,
	"Lo-ong Ralī": -11.0,
	"Bompaçao": -8.0,
	"Rhėn Tempaol": 6.0,
	"Kutré Lyn": 2.0,
	"Zaitgaist": 0.0,
}

## Terminal roles want the terminal ball. Steeper than the ego lean, because
## wanting to end the rally is much more nearly the job description of an
## opposite than backing yourself is.
const POSITION_AGGRESSION_BIAS := {
	"Opposite": 12.0, "Outside Hitter": 6.0, "Middle Blocker": 2.0,
	"Setter": -7.0, "Libero": -13.0,
}


static func assign_aggression(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	region_name: String,
) -> void:
	## Its own stream, for the reason spelled out on `assign_ego`: taking a draw
	## from the shared generation rng advances it for every attribute after, so
	## adding an attribute silently rerolls the whole world. `_test_world_aging`
	## is the check that would notice, twenty seasons later.
	var aggression_rng := RandomNumberGenerator.new()
	aggression_rng.seed = hash("%d|aggression|%d|%s" % [
		rng.seed, player.id, region_name,
	])
	player.aggression = clampi(roundi(
		aggression_rng.randfn(50.0, 15.0)
		+ float(REGION_AGGRESSION_BIAS.get(region_name, 0.0))
		+ float(POSITION_AGGRESSION_BIAS.get(player.position_role, 0.0))
	), 1, 100)


static func body_type_attribute_delta(body_type: String, property_name: String) -> float:
	return float(Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {})).get(property_name, 0.0))


static func _apply_body_variation(
	player: VolleyballPlayer,
	rng: RandomNumberGenerator,
	region_name: String,
	overlay: Dictionary = {},
) -> void:
	var height_spread := float(ROLE_HEIGHT_SPREAD.get(player.position_role, 7.0))
	var height_delta := (
		rng.randf_range(-height_spread, height_spread)
		+ rng.randf_range(-height_spread, height_spread)
	) * 0.5
	var mass_delta := height_delta * 0.55 + rng.randf_range(-5.0, 5.0)
	var span_delta := height_delta * 0.70 + rng.randf_range(-4.0, 5.0)
	var height_bias := float(REGION_HEIGHT_BIAS.get(region_name, 0.0)) \
		+ float(overlay.get("height_bias_delta", 0.0))
	var mass_bias := float(REGION_MASS_BIAS.get(region_name, 0.0)) \
		+ float(overlay.get("mass_bias_delta", 0.0))
	var wingspan_bias := float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)) \
		+ float(overlay.get("wingspan_bias_delta", 0.0))
	## Region first, then morphology, both additive -- so two Ursi from
	## different regions differ by their region's bias and by nothing else.
	var morphology: Dictionary = BODY_TYPE_METRICS.get(player.body_type, {})
	player.height_cm = clampf(
		player.height_cm + height_delta + height_bias
			+ float(morphology.get("height", 0.0)), 150.0, 220.0)
	player.mass_kg = clampf(
		player.mass_kg + mass_delta + mass_bias
			+ float(morphology.get("mass", 0.0)), 50.0, 130.0)
	player.wingspan_cm = clampf(
		player.wingspan_cm + span_delta + wingspan_bias
			+ float(morphology.get("wingspan", 0.0)), 150.0, 235.0)



const PRIMARY_TIER_BONUS: int = 15
const SECONDARY_TIER_BONUS: int = 5
const TERTIARY_TIER_PENALTY: int = -8
## What a region's whole specialty is worth, spread across however many
## attributes it names.
##
## **The same mistake, a third time, and this is where it gets stated as a rule:
## a per-item constant makes unequal totals whenever the count varies.** It was
## 16 *per attribute*, so a region with six specialties carried 96 ceiling points
## and one with three carried 48 -- and re-cutting Pāwa Hitō from five attributes
## to three quietly removed 32 points from every Hitōuen ever generated. Twenty
## seasons later the world held eight elite players against a budget of seven,
## because one voli somewhere else had moved up to fill the gap.
##
## The same error had already been found twice in the same afternoon, in
## `REGION_CEILING_PENALTY` (weaknesses subtracting rather than reshaping) and in
## the rating bands (7, 13 and 21 attributes taking the same per-attribute step).
## Three tables, one bug: **a tradition distributes a fixed budget; only the
## shape of the distribution varies.**
##
## 80 is five times the old 16, which is the count most regions already had, so
## the regions that were not re-cut are untouched. The ones that were get sharper
## rather than smaller -- A'ace's three bought attributes are now worth 26.7 each,
## which is exactly right for a club that buys three stars instead of teaching
## six things, and Xérvu's six are worth 13.3 each, which is what a broad
## tradition should feel like.
const SPECIALTY_BUDGET: float = 80.0
## Retained for `region_overlay`'s `specialty_bonus_delta`, which adjusts the
## per-attribute figure a drifting region receives.
const SPECIALTY_BONUS: int = 16

## What a region's `physical` / `technical` / `mental` ratings actually do.
##
## **They did nothing at all.** Eight regions carry three of them each and, before
## this, not one of the twenty-four values was read anywhere in the codebase --
## not by the simulator, not by generation, not by the interface. They are the
## most visible statement of what a region is (`docs/world/` describes regions
## by them) and they were fiction attached to nothing, which is `FAILURE_MODES.md`
## §0's own shape: a value nobody set, or in this case a value nobody read.
##
## What they mean is a region's *breadth of emphasis*, so what they should do is
## broad and small, sitting underneath `REGION_SPECIALTY`'s sharp +16 rather than
## competing with it. A rating of 2 is the world average and does nothing; each
## point away from it is worth `RATING_CEILING_STEP` on every attribute in that
## band. Pāwa Hitō at physical 4 raises every physical attribute a little, which
## is not the same claim as its five named specialties and is exactly the claim
## the number makes.
##
## Bands rather than the six display categories, because the ratings are three:
## `technical` covers the craft categories and `mental` the reading ones, which
## is how the taglines already use the words.
## **Per rating point across the whole band, not per attribute.**
##
## This was 2.6 *per attribute*, and that is the §0 failure again: the three
## bands are wildly different sizes -- `physical` is 7 attributes, `mental` 13
## and `technical` 21 -- so one rating point of technique did three times the
## work of one rating point of physique. Summed over every ability attribute the
## net ceiling change per region ran from **-52 for Pāwa Hitō to +75 for Xérvu**,
## which is not an emphasis, it is a talent handicap dressed as one. The world's
## twenty-season talent budget noticed before I did.
##
## Normalising by band size makes a rating point mean the same thing wherever it
## is spent: a region that emphasises technique spreads that emphasis over
## twenty-one attributes and each one moves less, which is the honest reading of
## what "emphasis" is. What survives is only the residual from each region's
## ratings summing to 7 rather than the neutral 6 -- about half a point per
## attribute, and a deliberate statement rather than an accident.
const RATING_BAND_STEP: float = 18.0
const RATING_NEUTRAL: float = 2.0
const RATING_BANDS := {
	"physical": ["Physical"],
	"technical": ["Attacking", "Setting & Ball Control", "Serving"],
	"mental": ["Mental & Tactical", "Defensive"],
}


## What a region's specialty attributes gain back to pay for its weakness.
##
## **A tradition shapes a voli; it does not make them worse.** Adding
## `REGION_CEILING_PENALTY` without this drained the world's talent budget, and
## the suite caught it in one check: `potential` is derived from the ceilings
## themselves, weighted by the *position's* primary attributes, so a penalty
## landing on an attribute that is primary for a role -- Taktikã's
## `explosiveness` and `jump_reach` on a hitter, say -- cost that voli real
## potential, and after twenty seasons the top tiers had fewer players in them
## than the world is supposed to hold. That is not what a weakness means. It
## means Taktikã produces a different *kind* of elite hitter, not fewer of them.
##
## So every region's ceiling adjustment is net zero: whatever the weakness takes
## is handed back across the attributes the region actually teaches. The
## precedent is `BODY_TYPE_ATTRIBUTES`, which has summed to zero per body type
## since it was written, and for the same reason -- a body is a shape, not a
## grade, and so is a tradition.
##
## Derived rather than tabulated so the two tables cannot drift apart: edit a
## penalty and the compensation follows it.
static func _penalty_compensation(
	region_name: String, specialty_list: Array
) -> float:
	if specialty_list.is_empty():
		return 0.0
	var penalty: Dictionary = REGION_CEILING_PENALTY.get(region_name, {})
	if penalty.is_empty():
		return 0.0
	var total := 0.0
	for attribute in penalty:
		total += float(penalty[attribute])
	return -total / float(specialty_list.size())


## Which of the three ratings governs this attribute, or an empty string.
##
## Built once on first use rather than declared, so the mapping cannot drift out
## of step with `AttributeProfiles.CATEGORY_ATTRIBUTES` -- the failure this file
## has already had with `BODY_TYPES` against `PRODUCE_BODIES`.
static var _rating_for_attribute: Dictionary = {}


static func rating_band_for(property_name: String) -> String:
	if _rating_for_attribute.is_empty():
		for rating_name in RATING_BANDS:
			for category in RATING_BANDS[rating_name]:
				for attribute in AttributeProfiles.CATEGORY_ATTRIBUTES.get(
					category, []
				):
					_rating_for_attribute[str(attribute)] = str(rating_name)
	return str(_rating_for_attribute.get(property_name, ""))


## What this region's ratings are worth to this attribute's ceiling.
static func region_rating_bonus(
	region_name: String, property_name: String
) -> float:
	var band := rating_band_for(property_name)
	if band.is_empty():
		return 0.0
	var definition := VolleyballRegions.definition(region_name)
	## **Measured against the region's own mean, not a global neutral.**
	##
	## The ratings do not sum to the same total everywhere -- some regions come to
	## 6 and some to 7 -- so subtracting a fixed 2.0 left the sum-7 regions a flat
	## +18 ceiling points ahead of the sum-6 ones. That residual was small, and
	## small was still enough: it moved exactly one voli across the generational
	## boundary and the world finished twenty seasons with eight elite players
	## against a budget of seven.
	##
	## These numbers describe *relative emphasis within a tradition* -- 4/1/1 says
	## Pāwa Hitō cares about physique more than technique -- and a statement about
	## proportion should not also be a statement about quality. Anchoring on the
	## region's own mean makes every region net exactly zero, whatever its ratings
	## sum to, so emphasis reshapes a voli and never grades them. The same
	## principle as `_penalty_compensation`, applied to the other table.
	var mean := (
		float(definition.get("physical", RATING_NEUTRAL))
		+ float(definition.get("technical", RATING_NEUTRAL))
		+ float(definition.get("mental", RATING_NEUTRAL))
	) / 3.0
	return (float(definition.get(band, mean)) - mean) \
		* RATING_BAND_STEP / maxf(float(_band_size(band)), 1.0)


## How many ability attributes a rating band covers.
##
## Counted from `AttributeProfiles.CATEGORY_ATTRIBUTES` rather than written down,
## because a hand-kept size is a number that goes stale the first time an
## attribute is added to a category -- and the whole reason this function exists
## is that band sizes were not being accounted for at all.
static var _band_sizes: Dictionary = {}


static func _band_size(band: String) -> int:
	if _band_sizes.is_empty():
		for rating_name in RATING_BANDS:
			var total := 0
			for category in RATING_BANDS[rating_name]:
				total += Array(AttributeProfiles.CATEGORY_ATTRIBUTES.get(
					category, []
				)).size()
			_band_sizes[str(rating_name)] = total
	return int(_band_sizes.get(band, 1))


## Attributes a region's own upbringing leaves *short*, and by how much.
##
## **The first table in this file that takes something away**, and it exists
## because an identity built only from bonuses cannot describe a tradition with a
## hole in it. A'ace is the case that forced it: a region with no historical
## volleyball presence, buying terminal ability from everywhere and teaching the
## swing without the game. Expressed as three fewer bonuses that would read as a
## slightly duller version of everybody else; expressed as a penalty it reads as
## what it is -- volis who can end a point and cannot find the situation that
## needs ending.
##
## Applied to the *ceiling*, not the current value, so it is a limit on what
## A'ace's own academies can produce rather than a debuff on the individual. A
## voli A'ace signs from Taktikã keeps Taktikã's ceilings, which is the whole
## mechanism of the region: it is only its home-grown players who are short.
## **Every region gives something up, and no two give up the same thing.**
##
## Seven of the eight had no weakness at all: their only cost was not having a
## bonus somewhere, which makes "specialty" a synonym for "better" and turns the
## league into a power ranking instead of a set of matchups. A tradition is
## defined as much by what it never taught as by what it drills.
##
## Two rules held while choosing these. Each weakness is the *inverse of the
## region's own strength*, so it reads as a consequence of the training rather
## than as a handicap bolted on. And no two regions share a weakness, for the
## same reason no two should share a peak -- if Spëddigh and Taktikã were both
## short on power, "small" would stop being either region's problem and start
## being the league's baseline.
##
## The result is a web of counters rather than a ladder. Ĭspayk cannot adapt and
## Taktikã is built on adapting. Xérvu cannot pass and Blôc du Larg exists to
## make you pass. Bloc cannot improvise and Spëddigh is nothing but improvisation
## of tempo. Landavol is the only region with no weakness, which is the same
## statement as having no specialty and is what makes it the reference.
const REGION_CEILING_PENALTY := {
	## Quick and light, and it costs them at the net in both directions.
	"Spëddigh": {"attack_power": -10, "block_timing": -8},
	## They go through you. They have never needed to go around you, so the
	## deception attributes were never taught.
	"Pāwa Hitō": {"feinting": -11, "set_disguise": -9},
	## A structured side is a side that struggles when the structure breaks, and
	## a wall built on staying home does not learn to serve people off it.
	"Blôc du Larg": {"improvisation": -11, "serve_power": -9},
	## Six specialty attributes on serving, and a tradition that treats the first
	## contact as somebody else's problem.
	"Xérvu": {"reception": -11, "dig_control": -9},
	## The one region that will not win a physical contest, which is the point of
	## it -- and the reason its reading has to be worth something.
	"Taktikã": {"explosiveness": -12, "jump_reach": -10},
	## **The cost of the perfect swing is that it is the only swing.** Predictable
	## by construction and unable to change once read, which is exactly the
	## matchup Taktikã is built to win.
	"Ĭspayk": {"shot_variety": -12, "adaptability": -10},
	## Bought terminal ability with no shared idea of how to play.
	"A'ace": {
		"tactical_discipline": -12, "decision_making": -12, "court_vision": -9,
	},
}


static func _tier_bonus(
	property_name: String,
	primary_list: Array,
	secondary_list: Array,
	specialty_list: Array,
	specialty_bonus: int = SPECIALTY_BONUS,
) -> int:
	var bonus := TERTIARY_TIER_PENALTY
	if property_name in primary_list:
		bonus = PRIMARY_TIER_BONUS
	elif property_name in secondary_list:
		bonus = SECONDARY_TIER_BONUS
	return bonus + (specialty_bonus if property_name in specialty_list else 0)


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
## `talent_override` (>= 0) supplies the player's general level directly
## instead of rolling it, which is what lets the world-population system ask
## for a player of a *specific* calibre rather than accepting whatever the
## dice produce. The roll is skipped entirely rather than rolled-and-ignored,
## so the population path has its own rng stream; `generate_roster` never
## passes it and its stream is untouched.
static func _apply_attributes(
	player: VolleyballPlayer,
	region_name: String,
	rng: RandomNumberGenerator,
	academy: bool,
	overlay: Dictionary = {},
	talent_override: float = -1.0,
) -> void:
	var primary_list: Array = Array(
		VolleyballPlayer.POSITION_WEIGHTS.get(player.position_role, [])
	)
	var secondary_list: Array = Array(ROLE_SECONDARY.get(player.position_role, []))
	## `specialty_add` extends this region's own specialty list rather than
	## replacing it -- influence drift broadens what a region is good at, it
	## never takes away what it already had.
	var specialty_list: Array = Array(REGION_SPECIALTY.get(region_name, [])) \
		+ Array(overlay.get("specialty_add", []))
	## The budget divided by however many attributes are sharing it, so a region's
	## total never changes when its list is re-cut -- only the sharpness does.
	var specialty_bonus := int(round(
		SPECIALTY_BUDGET / maxf(float(specialty_list.size()), 1.0)
	)) + int(overlay.get("specialty_bonus_delta", 0.0)) if not specialty_list.is_empty() \
		else 0
	var talent := talent_override if talent_override >= 0.0 else float(_talent_level(rng, academy))

	var ceiling_penalty: Dictionary = REGION_CEILING_PENALTY.get(region_name, {})
	var specialty_compensation := _penalty_compensation(region_name, specialty_list)
	var ceilings := {}
	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		ceilings[property_name] = clampf(
			talent
			+ float(_tier_bonus(
				property_name, primary_list, secondary_list, specialty_list, specialty_bonus
			))
			+ float(ceiling_penalty.get(property_name, 0))
			+ (specialty_compensation if property_name in specialty_list else 0.0)
			+ region_rating_bonus(region_name, property_name)
			+ _innate_deviation(rng),
			1.0, 99.0,
		)

	## Potential is what those ceilings are worth, scored exactly as current
	## ability will be scored.
	player.potential = _weighted_score(ceilings, primary_list)

	## **A region decides a voli's shape; it must not decide their grade.**
	##
	## When a caller asks for a specific potential -- and the world's yearly
	## intake always does, drawing one from the tier it is short of -- that number
	## is a *budget decision* about how much talent the world contains, not a
	## suggestion. It was being treated as a suggestion: `talent_override` set the
	## baseline and then every regional table moved the ceilings on top of it, so
	## the achieved potential drifted off the requested one by however much that
	## region's specialty, penalty and rating tables happened to sum to. A
	## prospect requested as elite could arrive generational.
	##
	## Over twenty seasons that is a leak with a direction, and the world-aging
	## gate caught it: eight elite players against a budget of seven. It survived
	## three separate fixes that each corrected a real imbalance in those tables
	## -- weaknesses that subtracted rather than reshaped, rating bands of
	## unequal size, a specialty bonus that was per-attribute rather than a
	## budget -- because none of them addressed the actual defect, which is that
	## *any* regional shaping at all was allowed to move the total.
	##
	## Scaling the ceilings so the derived potential lands on the requested one
	## fixes the class rather than the three instances: whatever a region's tables
	## sum to now, and whatever they are edited to later, a voli asked for a given
	## potential arrives with it. The shape survives the scaling because every
	## ceiling moves by the same ratio.
	if talent_override >= 0.0 and player.potential > 0:
		var correction := talent_override / float(player.potential)
		for property_name in ceilings:
			ceilings[property_name] = clampf(
				float(ceilings[property_name]) * correction, 1.0, 99.0
			)
		player.potential = _weighted_score(ceilings, primary_list)

	## Kept individually, not only as the aggregate above -- a potential
	## attribute wheel reads this rather than approximating a shape from one
	## number. Rounded to match every other attribute's integer scale.
	## Morphology moves the ceiling, not merely the starting value -- see
	## BODY_TYPE_ATTRIBUTES. Applied here so `potential` above is still scored
	## on the untouched roll and only the per-attribute headroom shifts.
	for property_name in ceilings:
		var morph_delta := body_type_attribute_delta(player.body_type, property_name)
		if not is_zero_approx(morph_delta):
			ceilings[property_name] = clampf(
				float(ceilings[property_name]) + morph_delta, 1.0, 99.0)

	player.attribute_ceilings.clear()
	for property_name in ceilings:
		player.attribute_ceilings[property_name] = roundi(float(ceilings[property_name]))

	for property_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
		var ceiling := float(ceilings[property_name])
		var reserve := _attribute_reserve(property_name, player.age, rng) \
			* _generational_reserve_scale(player.potential, player.age)
		player.set(property_name, clampi(
			roundi(ceiling - reserve), 1, roundi(ceiling)
		))
	## Status is generated after ability so reputation reflects what the player
	## has actually established, not hidden potential. Satisfaction is club
	## context rather than talent and begins in a narrow neutral band.
	player.reputation = clampi(roundi(
		float(player.current_ability_score()) * 0.80
		+ float(player.professional_experience) * 1.50 - 20.0
	), 1, 100)
	player.satisfaction = rng.randf_range(0.62, 0.82)
	player.match_confidence = 0.0


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


## `generate_market()` used to live here, rolling 120 fresh players from
## nowhere every time a career needed a transfer list. It is gone rather than
## deprecated: `WorldPopulation.draw_market()` replaces it by taking a slice
## out of the world that already exists, which is the whole point of having
## a population -- a market of players invented on the spot has no history,
## no origin, and no relationship to how scarce talent actually is.
