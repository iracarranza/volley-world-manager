class_name VolleyballFamiliaritySystem
extends RefCounted

const POSITIONS: Array[String] = ["Setter", "Outside Hitter", "Middle Blocker", "Opposite", "Libero"]
const SIMILARITY := {
	"Setter": {"Opposite": 0.58, "Outside Hitter": 0.42, "Libero": 0.52, "Middle Blocker": 0.25},
	"Outside Hitter": {"Opposite": 0.82, "Libero": 0.62, "Setter": 0.38, "Middle Blocker": 0.42},
	"Middle Blocker": {"Opposite": 0.62, "Outside Hitter": 0.42, "Setter": 0.22, "Libero": 0.18},
	"Opposite": {"Outside Hitter": 0.82, "Middle Blocker": 0.62, "Setter": 0.55, "Libero": 0.28},
	"Libero": {"Outside Hitter": 0.62, "Setter": 0.55, "Opposite": 0.28, "Middle Blocker": 0.18},
}

static func initialize_player(player: VolleyballPlayer, rng: RandomNumberGenerator = null) -> void:
	player.primary_position = player.position_role
	player.natural_positions = [player.position_role]
	player.position_familiarity.clear()
	## A palate starts where they grew up and grows from there. See `FoodSupply`.
	player.palate_regions = [player.home_region] as Array[String]
	for position_name in POSITIONS:
		player.position_familiarity[position_name] = 92 if position_name == player.position_role else roundi(18.0 + 35.0 * similarity(player.position_role, position_name))
	if rng != null:
		player.dominant_hand = "Left" if rng.randf() < 0.12 else "Right"
		if player.improvisation >= 82 and player.hand_control >= 75 and rng.randf() < 0.16:
			player.traits.append("Ambidextrous")
		elif player.improvisation >= 65 and rng.randf() < 0.18:
			player.traits.append("Functional Weak Hand")

static func similarity(from_position: String, to_position: String) -> float:
	if from_position == to_position:
		return 1.0
	return float(Dictionary(SIMILARITY.get(from_position, {})).get(to_position, 0.20))

static func suitability(player: VolleyballPlayer, position_name: String) -> int:
	var values: Array[float]
	match position_name:
		"Setter": values = [player.set_accuracy, player.hand_control, player.court_vision, player.decision_making]
		"Outside Hitter": values = [player.usable_attack_power(), player.reception, player.approach_timing, player.transition_speed]
		"Middle Blocker": values = [effective_reach(player), player.explosiveness, player.block_timing, player.lateral_speed, player.approach_timing]
		"Opposite": values = [player.usable_attack_power(), effective_reach(player), player.block_timing, player.serve_power]
		_: values = [player.reception, player.dig_control, player.anticipation, player.lateral_speed, player.ball_control]
	var total := 0.0
	for value in values: total += value
	return roundi(total / values.size())

static func effective_reach(player: VolleyballPlayer) -> float:
	var physical_reach := clampf(inverse_lerp(205.0, 300.0, player.standing_reach_cm()) * 100.0, 1.0, 100.0)
	return clampf(physical_reach * 0.42 + player.jump_reach * 0.38 + player.explosiveness * 0.20, 1.0, 100.0)

static func train_position(player: VolleyballPlayer) -> float:
	var target := player.position_training_target
	if target.is_empty() or target not in POSITIONS: return 0.0
	var current := float(player.position_familiarity.get(target, 0.0))
	var gain := 2.4 * (0.65 + player.adaptability / 100.0 * 0.90) \
		* lerpf(0.55, 1.0, similarity(player.primary_position, target)) \
		* lerpf(0.65, 1.10, suitability(player, target) / 100.0) * (1.0 - current / 125.0)
	player.position_familiarity[target] = clampf(current + gain, 0.0, 100.0)
	player.fatigue = clampf(player.fatigue + 0.02, 0.0, 1.0)
	return gain

static func familiarity_label(value: float) -> String:
	if value >= 90: return "Natural"
	if value >= 75: return "Accomplished"
	if value >= 60: return "Functional"
	if value >= 40: return "Developing"
	if value >= 20: return "Emergency"
	return "Untrained"

static func execution_modifier(player: VolleyballPlayer) -> float:
	return 0.82 + float(player.position_familiarity.get(player.position_role, 0.0)) / 100.0 * 0.18

## How much this voli takes from having seen a ball once.
##
## `adaptability` is the individual half and has always been here. The regional
## half is the tradition that taught them to watch: a Taktikãn is not a better
## athlete for having seen the same set three times, they are a better *reader*,
## and that is the only mechanism in the game that makes a side genuinely harder
## to play against in the fourth set than in the first.
##
## Read from `home_region` for the same reason `stamina_fatigue_scale` is -- this
## is a habit of attention formed growing up, and it travels with the voli rather
## than with the badge on their shirt.
static func record_exposure(player: VolleyballPlayer, tags: Array[String], amount: float = 1.0) -> void:
	var modifier := (0.65 + player.adaptability / 100.0 * 0.90) \
		* VolleyballRegions.read_rate(player.home_region)
	for tag in tags: player.situation_experience[tag] = float(player.situation_experience.get(tag, 0.0)) + amount * modifier

static func familiarity(player: VolleyballPlayer, tags: Array[String]) -> float:
	if tags.is_empty(): return 0.5
	var total := 0.0
	for tag in tags: total += 1.0 - exp(-float(player.situation_experience.get(tag, 0.0)) / 18.0)
	return clampf(total / tags.size(), 0.0, 1.0)

static func attack_geometry(player: VolleyballPlayer, lane: String) -> float:
	var right_side := lane in ["Right Pin", "Inside Right", "Right Quick"]
	var natural := (player.dominant_hand == "Left" and right_side) or (player.dominant_hand == "Right" and not right_side)
	var base := 0.035 if natural else -0.035
	if "Ambidextrous" in player.traits: return 0.025
	if "Functional Weak Hand" in player.traits and not natural: return -0.012
	return base * lerpf(1.25, 0.45, (player.finesse + player.improvisation + player.approach_timing) / 300.0)

static func read_modifier(player: VolleyballPlayer, tags: Array[String], scouting: float = 0.0) -> float:
	var known := familiarity(player, tags)
	var mental := (player.anticipation * 0.35 + player.court_vision * 0.25 \
		+ player.tactical_discipline * 0.20 + player.adaptability * 0.20) / 100.0
	return clampf((known * 0.55 + scouting * 0.25 + mental * 0.20) - 0.50, -0.10, 0.10)


## ## Seeding a squad's pair table from how long they have been together
##
## `PairFamiliarity` starts every pair at its baseline, which is right for two
## volis who genuinely just met and wrong for a roster that has been training
## together for years. A fresh career would open with one flat number for every
## pair, and a connection drawn between six identical numbers says nothing at
## all -- it would take most of a season before the quantity had anything to
## report.
##
## There is no tenure field on a voli, and inventing one for this would be a new
## model to feed and persist. What the roster does carry is **age**, and a
## squad's shared history is bounded by its youngest member's career: two
## thirty-year-olds at an established club have plausibly overlapped for years,
## and anyone in the room with a twenty-year-old has known them for at most a
## few seasons.
##
## So the seed is the *younger* voli's plausible years at a club, which is
## crude and honest, and stated as such rather than dressed up: it is a starting
## position that gets overwritten by the first season of real matches.
const PAIR_SEED_FIRST_SEASON_AGE: float = 19.0
const PAIR_SEED_PER_SEASON: float = 4.5
const PAIR_SEED_CEILING: float = 62.0


static func seed_pair_familiarity(players: Array, table: Dictionary) -> void:
	for first in players:
		for second in players:
			if int(first.id) >= int(second.id):
				continue
			var shared := minf(
				float(first.age) - PAIR_SEED_FIRST_SEASON_AGE,
				float(second.age) - PAIR_SEED_FIRST_SEASON_AGE,
			)
			var seeded := PairFamiliarity.BASELINE \
				+ maxf(shared, 0.0) * PAIR_SEED_PER_SEASON
			## Capped below the ceiling a played season can reach, so a squad
			## that has actually played together always outranks one that is
			## merely old. The seed is a floor on a relationship, not a
			## substitute for one.
			table[PairFamiliarity.key(int(first.id), int(second.id))] = minf(
				seeded, PAIR_SEED_CEILING
			)
