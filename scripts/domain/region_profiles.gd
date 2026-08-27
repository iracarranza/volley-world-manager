class_name RegionProfiles
extends RefCounted

## Player-development/profile inputs by region. PlayerGenerator composes these
## profiles; it no longer authors the world's regional definitions.

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


static func specialty(region_name: String) -> Array:
    return Array(REGION_SPECIALTY.get(region_name, []))


static func physique(region_name: String) -> Dictionary:
    return {
        "height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
        "mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
        "wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
    }
