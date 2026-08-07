class_name VolleyballTrainingSystem
extends RefCounted

const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const TrainingFocusModel := preload("res://scripts/systems/training_focus_model.gd")

const ACTIVITIES := {
	"Team Practice": {"attributes": ["tactical_discipline", "court_vision", "leadership"], "fatigue": 0.05, "satisfaction": 0.01, "familiarity": 0.035, "cohesion": 0.03,
		"description": "Build collective systems, tactical discipline and court vision."},
	"Serving": {"attributes": ["serve_power", "serve_technique", "serve_placement",
		"serve_consistency", "serve_aggression", "serve_variation"], "fatigue": 0.06,
		"satisfaction": 0.0, "familiarity": 0.01, "cohesion": 0.0,
		"description": "Develop serve power, contact, placement, reliability, risk and variation."},
	"Serve Receive": {"attributes": ["reception", "reception_balance", "reception_stability", "dig_control", "work_rate"], "fatigue": 0.055, "satisfaction": 0.005, "familiarity": 0.02, "cohesion": 0.01,
		"description": "Train platform control, movement balance and stability under pace."},
	"Attack & Transition": {"attributes": ["attack_power", "attack_accuracy", "approach_timing", "arm_speed", "tooling", "feinting", "finesse", "shot_variety", "transition_speed", "work_rate"], "fatigue": 0.08, "satisfaction": 0.005, "familiarity": 0.02, "cohesion": 0.005,
		"description": "Improve transition speed, approach timing and terminal attacking."},
	"Blocking & Defense": {"attributes": ["block_timing", "anticipation", "lateral_speed", "dig_control", "work_rate"], "fatigue": 0.07, "satisfaction": 0.0, "familiarity": 0.025, "cohesion": 0.01,
		"description": "Coordinate block reads, lateral closing and floor anticipation."},
	"Strength & Jump": {"attributes": ["explosiveness", "jump_reach", "stamina"], "fatigue": 0.09, "satisfaction": -0.005, "familiarity": 0.0, "cohesion": 0.0,
		"description": "Build explosive capacity and conditioning at a higher fatigue cost."},
	"Recovery": {"attributes": [], "fatigue": -0.20, "satisfaction": 0.03, "familiarity": -0.005, "cohesion": 0.005,
		"description": "Reduce fatigue and restore satisfaction; tactical familiarity may soften slightly."},
}


static func activity_names() -> Array[String]:
	var result: Array[String] = []
	for activity_name in ACTIVITIES:
		result.append(str(activity_name))
	return result


static func description(activity_name: String) -> Dictionary:
	return Dictionary(ACTIVITIES.get(activity_name, ACTIVITIES["Team Practice"]))


## Apply one week of training, one squad at a time.
##
## This used to take a single activity name and move every attribute in its list
## by +1 for every player on the roster. Two things were wrong with that and
## neither was the numbers. A club could not run its middles on blocking while
## its pins reviewed film, and a manager could not aim a week at anything -- the
## activity decided, and it decided everything in its pool at once.
##
## A regimen carries its own squad, so `apply_week` is called per regimen and
## a player trains under exactly one. Progress is a fraction now rather than a
## step: `TrainingFocusModel` hands out a budget divided among however many
## attributes the focus actually selected, it accumulates on the player, and it
## rolls into a point when it crosses one. A week of slow progress is now a thing
## the model can say.
static func apply_week(
	regimens: Array,
	players: Array[VolleyballPlayer],
	team: Resource,
	week: int = 0,
) -> Dictionary:
	var by_id := {}
	for player in players:
		by_id[player.id] = player
	var improved := 0
	var position_progress := 0.0
	var squads: Array[Dictionary] = []
	var trained_ids := {}
	for entry in regimens:
		var regimen: TrainingRegimen = entry as TrainingRegimen
		if regimen == null:
			continue
		var activity := description(regimen.activity)
		var squad_improved := 0
		var squad_fatigue := 0.0
		var squad_size := 0
		for player_id in regimen.player_ids:
			var player: VolleyballPlayer = by_id.get(int(player_id))
			if player == null or player.availability in ["Injured", "Suspended"]:
				continue
			## A player trains once a week. Listing them on two squads is a
			## manager's mistake, not a way to train twice.
			if trained_ids.has(player.id):
				continue
			trained_ids[player.id] = true
			squad_size += 1
			squad_improved += _train_player(regimen, activity, player, week)
			var cost := TrainingFocusModel.fatigue_cost(
				regimen, float(activity.fatigue)
			)
			player.fatigue = clampf(player.fatigue + cost, 0.0, 1.0)
			squad_fatigue += cost
			player.satisfaction = clampf(
				player.satisfaction + float(activity.satisfaction), 0.0, 1.0
			)
			AttributeProfiles.assign_serve_style(player)
			position_progress += Familiarity.train_position(player)
		improved += squad_improved
		squads.append({
			"squad_name": regimen.squad_name,
			"activity": regimen.activity,
			"focus": TrainingRegimen.focus_name(int(regimen.focus)),
			"players": squad_size,
			"attribute_improvements": squad_improved,
			"mean_fatigue_cost": squad_fatigue / maxf(float(squad_size), 1.0),
		})
		## Team-wide effects are paid once per squad that trains, scaled by how
		## much of the roster it was -- a two-player film session does not build
		## the same cohesion a full team practice does.
		var share := float(squad_size) / maxf(float(players.size()), 1.0)
		team.tactical_familiarity = clampf(
			float(team.tactical_familiarity) + float(activity.familiarity) * share,
			0.0, 1.0,
		)
		team.cohesion = clampf(
			float(team.cohesion) + float(activity.cohesion) * share, 0.0, 1.0
		)
	return {
		"squads": squads,
		"attribute_improvements": improved,
		"position_familiarity_progress": position_progress,
		"players_trained": trained_ids.size(),
	}


## One player's week. Returns how many attributes crossed a whole point.
static func _train_player(
	regimen: TrainingRegimen,
	activity: Dictionary,
	player: VolleyballPlayer,
	week: int,
) -> int:
	var selected := TrainingFocusModel.selected_attributes(
		regimen, Array(activity.get("attributes", [])), player.id, week
	)
	if selected.is_empty():
		return 0
	var step := TrainingFocusModel.progress_per_attribute(
		regimen, selected.size(), TrainingFocusModel.receptiveness(player)
	)
	var gained := 0
	for attribute_name in selected:
		var current := int(player.get(attribute_name))
		## A player's own ceiling where one is set, their potential otherwise, and
		## never below where they already are.
		var ceiling := maxi(
			int(player.attribute_ceilings.get(attribute_name, player.potential)),
			current,
		)
		if current >= ceiling:
			continue
		var carried := float(player.training_progress.get(attribute_name, 0.0)) + step
		while carried >= 1.0 and current < ceiling:
			current += 1
			carried -= 1.0
			gained += 1
		player.set(attribute_name, current)
		player.training_progress[attribute_name] = carried
	return gained
