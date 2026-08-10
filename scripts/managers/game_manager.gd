extends Node

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const MatchStateScript := preload("res://scripts/models/match_state.gd")
const DefensivePlanScript := preload("res://scripts/models/defensive_plan.gd")
const OpponentTeamScript := preload("res://scripts/models/opponent_team.gd")
const TeamScript := preload("res://scripts/models/team.gd")
const MatchFormatScript := preload("res://scripts/models/match_format.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")

signal rotation_changed(rotation_number: int)
signal playbook_changed
signal roster_changed

var players: Array[VolleyballPlayer] = []
var rotations: Dictionary = {} # rotation number -> RotationLineup
var saved_plays: Array[OffensivePlay] = []
var selected_rotation: int = 1
var called_play_id: int = -1
var active_play_ids_by_rotation: Dictionary = {}
var _next_play_id: int = 1
var match_state: Resource
var defensive_plans: Dictionary = {}
var opponent_team: Resource
var team: Resource


func _ready() -> void:
	if players.is_empty():
		seed_vertical_slice_data()


func seed_vertical_slice_data() -> void:
	players.clear()
	players.append(_make_player(1, "Mira", "Setter", "S", {
		"set_accuracy": 86, "set_balance": 82, "set_stability": 84,
		"court_vision": 90, "decision_making": 84,
		## The brain of the squad: reads and runs the offence, serves for
		## placement rather than pace, and is not a terminal attacker.
		"tempo_control": 88, "hand_control": 86, "set_disguise": 79,
		"composure": 82, "tactical_discipline": 85, "leadership": 88,
		"adaptability": 76, "unpredictability": 74, "ego": 44,
		"serve_accuracy": 74, "serve_power": 58, "shot_variety": 46,
		"finesse": 72, "feinting": 66, "tooling": 40, "dig_control": 68,
		"acceleration": 74, "work_rate": 80, "arm_speed": 55,
		"attack_power": 42, "attack_accuracy": 55, "approach_timing": 62,
		"block_timing": 58, "lateral_speed": 76, "transition_speed": 78,
		"stamina": 80, "ball_control": 84, "anticipation": 80,
		"reception": 62, "age": 27, "professional_experience": 6,
		"potential": 74,
		"improvisation": 78, "height_cm": 185.0, "mass_kg": 77.0,
		"wingspan_cm": 188.0, "explosiveness": 73,
	}))
	players.append(_make_player(2, "Tala", "Outside Hitter", "OH1", {
		"reception": 78, "attack_accuracy": 76, "approach_timing": 80,
		## The dependable six-rotation outside. Good at everything, best at
		## nothing, which is what makes the lane distribution a real question.
		"serve_accuracy": 76, "serve_power": 72, "shot_variety": 74,
		"finesse": 70, "feinting": 68, "tooling": 66, "composure": 76,
		"tactical_discipline": 72, "leadership": 68, "adaptability": 74,
		"unpredictability": 62, "ego": 58, "hand_control": 66,
		"tempo_control": 62, "set_disguise": 40, "dig_control": 74,
		"acceleration": 78, "work_rate": 82, "arm_speed": 74,
		"attack_power": 74, "block_timing": 68, "lateral_speed": 76,
		"transition_speed": 74, "stamina": 80, "ball_control": 76,
		"court_vision": 70, "anticipation": 74, "decision_making": 72,
		"improvisation": 66, "set_accuracy": 42, "set_balance": 46,
		"set_stability": 44, "age": 25, "professional_experience": 4,
		"potential": 79,
		"height_cm": 191.0, "mass_kg": 84.0, "wingspan_cm": 197.0,
		"explosiveness": 82, "reception_balance": 82, "reception_stability": 76,
	}))
	players.append(_make_player(3, "Boro", "Middle Blocker", "M1", {
		"jump_reach": 88, "block_timing": 84, "approach_timing": 79,
		## Runs the quick, so the tempo attributes have to be there -- a middle
		## who cannot read tempo is a middle who never gets set.
		"tempo_control": 76, "serve_accuracy": 58, "serve_power": 66,
		"shot_variety": 52, "tooling": 70, "feinting": 48, "finesse": 44,
		"composure": 68, "tactical_discipline": 74, "leadership": 60,
		"adaptability": 62, "unpredictability": 48, "ego": 52,
		"hand_control": 52, "set_disguise": 30, "dig_control": 46,
		"acceleration": 80, "work_rate": 76, "arm_speed": 78,
		"attack_power": 80, "attack_accuracy": 66, "lateral_speed": 62,
		"transition_speed": 58, "stamina": 70, "ball_control": 52,
		"court_vision": 58, "anticipation": 66, "decision_making": 62,
		"improvisation": 48, "set_accuracy": 30, "set_balance": 38,
		"set_stability": 34, "age": 26, "professional_experience": 5,
		"potential": 72,
		"height_cm": 205.0, "mass_kg": 98.0, "wingspan_cm": 214.0,
		"explosiveness": 91,
	}))
	players.append(_make_player(4, "Sena", "Opposite", "OP", {
		"attack_power": 91, "jump_reach": 86, "lateral_speed": 38,
		## The bomber, and priced like one: enormous serve and swing, thin
		## control and discipline. The one player who should be serving big.
		"serve_power": 90, "serve_accuracy": 62, "arm_speed": 88,
		"shot_variety": 66, "tooling": 74, "feinting": 54, "finesse": 48,
		"composure": 58, "tactical_discipline": 52, "leadership": 46,
		"adaptability": 48, "unpredictability": 70, "ego": 84,
		"hand_control": 50, "tempo_control": 54, "set_disguise": 28,
		"dig_control": 40, "acceleration": 62, "work_rate": 66,
		"attack_accuracy": 70, "approach_timing": 76, "block_timing": 72,
		"transition_speed": 60, "stamina": 68, "ball_control": 54,
		"court_vision": 60, "anticipation": 58, "decision_making": 56,
		"improvisation": 62, "set_accuracy": 32, "set_balance": 40,
		"set_stability": 36, "age": 28, "professional_experience": 8,
		"potential": 68,
		"height_cm": 199.0, "mass_kg": 99.0, "wingspan_cm": 207.0,
		"explosiveness": 86,
	}))
	players.append(_make_player(5, "Ivo", "Outside Hitter", "OH2", {
		"transition_speed": 82, "attack_accuracy": 73, "court_vision": 76,
		## The crafty one. Wide repertoire and high adaptability, so shot
		## variety and feinting have somebody to belong to.
		"serve_accuracy": 70, "serve_power": 68, "shot_variety": 78,
		"finesse": 74, "feinting": 76, "tooling": 62, "composure": 70,
		"tactical_discipline": 76, "leadership": 58, "adaptability": 80,
		"unpredictability": 72, "ego": 54, "hand_control": 64,
		"tempo_control": 66, "set_disguise": 36, "dig_control": 70,
		"acceleration": 84, "work_rate": 78, "arm_speed": 70,
		"attack_power": 72, "approach_timing": 74, "block_timing": 64,
		"lateral_speed": 80, "stamina": 76, "ball_control": 78,
		"anticipation": 76, "decision_making": 78, "improvisation": 80,
		"set_accuracy": 48, "set_balance": 52, "set_stability": 50,
		"age": 24, "professional_experience": 3, "potential": 81,
		"height_cm": 195.0, "mass_kg": 90.0, "wingspan_cm": 200.0,
		"explosiveness": 76, "reception_balance": 72, "reception_stability": 80,
	}))
	players.append(_make_player(6, "Nemi", "Libero", "L", {
		"reception": 92, "ball_control": 90, "anticipation": 88,
		"attack_power": 20, "height_cm": 176.0, "mass_kg": 69.0,
		## Floor defence made of one person. Everything that touches a dug ball
		## is high; everything that terminates one is not.
		"dig_control": 92, "composure": 86, "tactical_discipline": 84,
		"leadership": 72, "adaptability": 82, "unpredictability": 44,
		"ego": 38, "hand_control": 78, "tempo_control": 58,
		"serve_accuracy": 66, "serve_power": 40, "shot_variety": 30,
		"finesse": 66, "feinting": 34, "tooling": 22, "set_disguise": 44,
		"acceleration": 90, "work_rate": 88, "arm_speed": 48,
		"lateral_speed": 92, "transition_speed": 88, "stamina": 90,
		"court_vision": 84, "decision_making": 82, "improvisation": 74,
		"approach_timing": 40, "block_timing": 30, "attack_accuracy": 40,
		"set_accuracy": 60, "set_balance": 70, "set_stability": 68,
		"age": 29, "professional_experience": 9, "potential": 66,
		"wingspan_cm": 180.0, "explosiveness": 75,
		"reception_balance": 94, "reception_stability": 95,
	}))
	players.append(_make_player(7, "Kiri", "Middle Blocker", "M2", {
		"jump_reach": 84, "block_timing": 79, "transition_speed": 74,
		## The second middle, deliberately a step behind Boro on every axis
		## that decides who gets set.
		"tempo_control": 70, "serve_accuracy": 54, "serve_power": 60,
		"shot_variety": 48, "tooling": 64, "feinting": 42, "finesse": 40,
		"composure": 62, "tactical_discipline": 66, "leadership": 50,
		"adaptability": 58, "unpredictability": 42, "ego": 48,
		"hand_control": 48, "set_disguise": 26, "dig_control": 44,
		"acceleration": 76, "work_rate": 72, "arm_speed": 72,
		"attack_power": 72, "attack_accuracy": 60, "lateral_speed": 58,
		"stamina": 66, "ball_control": 48, "court_vision": 54,
		"anticipation": 60, "decision_making": 58, "improvisation": 44,
		"set_accuracy": 28, "set_balance": 36, "set_stability": 32,
		"age": 23, "professional_experience": 2, "potential": 77,
		"height_cm": 201.0, "mass_kg": 92.0, "wingspan_cm": 208.0,
		"explosiveness": 82,
	}))
	players.append(_make_player(8, "Rui", "Outside Hitter", "OH3", {
		"reception": 70, "attack_accuracy": 68, "stamina": 76,
		## The young one: adaptable and willing, not yet composed. The squad
		## needs somebody with room to grow for development to read as growth.
		"serve_accuracy": 60, "serve_power": 64, "shot_variety": 58,
		"finesse": 56, "feinting": 50, "tooling": 52, "composure": 54,
		"tactical_discipline": 58, "leadership": 42, "adaptability": 70,
		"unpredictability": 66, "ego": 62, "hand_control": 54,
		"tempo_control": 56, "set_disguise": 32, "dig_control": 62,
		"acceleration": 72, "work_rate": 74, "arm_speed": 66,
		"attack_power": 66, "approach_timing": 68, "block_timing": 60,
		"lateral_speed": 72, "transition_speed": 70, "ball_control": 68,
		"court_vision": 64, "anticipation": 66, "decision_making": 60,
		"improvisation": 62, "set_accuracy": 40, "set_balance": 44,
		"set_stability": 42, "age": 20, "professional_experience": 1,
		"potential": 88,
		"height_cm": 190.0, "mass_kg": 83.0, "wingspan_cm": 194.0,
		"explosiveness": 74,
	}))
	team = TeamScript.new()
	team.player_ids.assign([1, 2, 3, 4, 5, 6, 7, 8])
	team.captain_id = 1
	team.libero_ids.assign([6])
	team.depth_chart = {
		"Setter": [1], "Outside Hitter": [2, 5, 8],
		"Middle Blocker": [3, 7], "Opposite": [4], "Libero": [6],
	}
	rotations.clear()
	var base_rotation_ids: Array[int] = [1, 2, 3, 4, 5, 7]
	for rotation_number in range(1, 7):
		var lineup := RotationLineup.new()
		lineup.rotation_number = rotation_number
		lineup.setter_id = 1
		lineup.designated_setter_ids = [1]
		for slot_number in range(1, 7):
			var player_index := posmod(slot_number - rotation_number, 6)
			var player_id: int = base_rotation_ids[player_index]
			if slot_number in [1, 5, 6] and player_id in [3, 7]:
				player_id = 6
			lineup.assign_slot(slot_number, player_id)
		rotations[rotation_number] = lineup
	selected_rotation = 1
	saved_plays.clear()
	called_play_id = -1
	active_play_ids_by_rotation.clear()
	_next_play_id = 1
	match_state = MatchStateScript.new()
	defensive_plans.clear()
	for rotation_number in range(1, 7):
		var plan: Resource = DefensivePlanScript.new()
		plan.rotation_number = rotation_number
		plan.plan_name = "Rotation %d Defense" % rotation_number
		plan.ensure_defaults(rotations[rotation_number])
		defensive_plans[rotation_number] = plan
	_seed_opponent()
	var prototype_format: Resource = MatchFormatScript.new()
	prototype_format.format_name = "Best of 5"
	prototype_format.best_of_sets = 5
	prototype_format.deciding_set_target = 15
	match_state.match_format = prototype_format


func _seed_opponent() -> void:
	opponent_team = OpponentTeamScript.new()
	opponent_team.team_name = "Port Azure VC"
	## Port Azure is Landavolan, which is exactly as neutral as it was before.
	##
	## `REGIONAL_PRINCIPLES.Landavol` and `PRESETS.Balanced` are the same seven
	## 0.50s -- asserted in the suite, not assumed here -- so the mirrored roster
	## remains a mirrored *side*, and every symmetry reading this slice exists to
	## take is untouched. What it buys is that the opponent now has a region to
	## be changed, which is the whole of playing somebody else.
	opponent_team.region = "Landavol"
	opponent_team.setter_id = 101
	opponent_team.scouting_confidence = 0.56
	opponent_team.tendencies = {
		"preferred_lane": "Left Pin", "tempo": 1, "serve_target": "Zone 5",
	}
	## **Port Azure is the home squad, position for position.**
	##
	## It used to be a sketch: five attributes on its setter, two on a middle,
	## three on an outside, and everything else left on `VolleyballPlayer`'s class
	## default of 50. Counted, **245 of its 287 ability attributes had never been
	## specified** against 14 of the home squad's 328 -- so every attribute this
	## engine has learned to read since that fixture was written read 50 for one
	## of the two teams. `SetterCapabilitySystem.command()` came out at exactly
	## 0.500 for that side across 347 sets, which is how it was found: an exactly
	## constant number is never a model, it is a value nobody set.
	##
	## That made every side-versus-side reading in this repository a measurement
	## of the roster before it was a measurement of the simulation. Kill, dig,
	## stuff and swing-balance have all been compared across the net for a year
	## against an opponent that was mostly blank.
	##
	## Mirroring the home squad fixes that completely: the two teams are now
	## identical, so **any residual gap between the sides is engine asymmetry by
	## definition**. That is the control this vertical slice never had, and it is
	## worth more than the flavour the sketch was carrying -- Port Azure's
	## signature numbers (Oren's 86 block timing, Pax's 88 power) were expressive
	## but they were noise sitting on top of 85% silence.
	##
	## Derived rather than transcribed. A hand-written mirror would drift the
	## first time a home attribute changed and nothing would say so; copying at
	## construction cannot. When Port Azure becomes a club with a character of its
	## own, that is a design act layered on top of this, not a return to blanks.
	var opponent_blueprints := [
		[101, "Ari", "Setter", "S", 1],
		[102, "Vale", "Outside Hitter", "OH1", 2],
		[103, "Oren", "Middle Blocker", "M1", 3],
		[104, "Pax", "Opposite", "OP", 4],
		[105, "Lio", "Outside Hitter", "OH2", 5],
		[106, "Emi", "Libero", "L", 6],
		[107, "Noa", "Middle Blocker", "M2", 7],
	]
	var opponent_players: Array[Resource] = []
	for blueprint in opponent_blueprints:
		opponent_players.append(_mirror_player(
			int(blueprint[0]), str(blueprint[1]), str(blueprint[2]),
			str(blueprint[3]), _player_by_id(int(blueprint[4])),
		))
	opponent_team.players = opponent_players
	var opponent_base_ids: Array[int] = [101, 102, 103, 104, 105, 107]
	for rotation_number in range(1, 7):
		var lineup := RotationLineup.new()
		lineup.rotation_number = rotation_number
		lineup.setter_id = 101
		lineup.designated_setter_ids = [101]
		for slot_number in range(1, 7):
			var player_index := posmod(slot_number - rotation_number, 6)
			var player_id: int = opponent_base_ids[player_index]
			if slot_number in [1, 5, 6] and player_id in [103, 107]:
				player_id = 106
			lineup.assign_slot(slot_number, player_id)
		opponent_team.rotations[rotation_number] = lineup
	opponent_team.select_rotation(1)


func configure_managed_team(new_team: Resource, generated_players: Array[VolleyballPlayer]) -> String:
	var by_role := {"Setter": [], "Outside Hitter": [], "Middle Blocker": [],
		"Opposite": [], "Libero": []}
	for player in generated_players:
		if player.position_role in by_role:
			by_role[player.position_role].append(player.id)
	for required in {"Setter": 1, "Outside Hitter": 2, "Middle Blocker": 2,
		"Opposite": 1, "Libero": 1}:
		if Array(by_role[required]).size() < int({"Setter": 1, "Outside Hitter": 2,
			"Middle Blocker": 2, "Opposite": 1, "Libero": 1}[required]):
			return "Generated roster lacks required %s coverage." % required
	players.assign(generated_players)
	team = new_team
	team.player_ids.clear()
	team.roster_limit = 200
	for player in players:
		team.player_ids.append(player.id)
	team.captain_id = int(by_role["Setter"][0])
	team.libero_ids.assign([int(by_role["Libero"][0])])
	team.depth_chart.clear()
	for role_name in by_role:
		team.depth_chart[role_name] = Array(by_role[role_name]).duplicate()
	var base_ids: Array[int] = [int(by_role.Setter[0]), int(by_role["Outside Hitter"][0]),
		int(by_role["Middle Blocker"][0]), int(by_role.Opposite[0]),
		int(by_role["Outside Hitter"][1]), int(by_role["Middle Blocker"][1])]
	var libero_id := int(by_role.Libero[0])
	team.starting_player_ids = base_ids.duplicate()
	team.starting_player_ids.append(libero_id)
	rotations.clear()
	for rotation_number in range(1, 7):
		var lineup := RotationLineup.new()
		lineup.rotation_number = rotation_number
		lineup.setter_id = int(by_role.Setter[0])
		lineup.designated_setter_ids = [lineup.setter_id]
		for slot_number in range(1, 7):
			var player_id := base_ids[posmod(slot_number - rotation_number, 6)]
			if slot_number in [1, 5, 6] and player_id in by_role["Middle Blocker"]:
				player_id = libero_id
			lineup.assign_slot(slot_number, player_id)
		rotations[rotation_number] = lineup
	selected_rotation = 1
	saved_plays.clear()
	called_play_id = -1
	active_play_ids_by_rotation.clear()
	_next_play_id = 1
	defensive_plans.clear()
	for rotation_number in range(1, 7):
		var plan: Resource = DefensivePlanScript.new()
		plan.rotation_number = rotation_number
		plan.plan_name = "Rotation %d Defense" % rotation_number
		plan.ensure_defaults(rotations[rotation_number])
		defensive_plans[rotation_number] = plan
	_seed_opponent()
	start_new_match(MatchFormatScript.new())
	roster_changed.emit()
	rotation_changed.emit(1)
	return ""


func start_new_match(format: Resource) -> void:
	match_state = MatchStateScript.new()
	match_state.match_format = MatchFormatScript.from_dict(format.to_dict()) \
		if format != null else MatchFormatScript.new()
	selected_rotation = 1
	if opponent_team == null:
		_seed_opponent()
	opponent_team.select_rotation(1)
	_configure_opponent_identity_scouting()
	for player in players:
		player.match_confidence = 0.0
	for opponent_player in opponent_team.players:
		opponent_player.match_confidence = 0.0
	rotation_changed.emit(1)


func _make_player(
	player_id: int,
	player_name: String,
	role_name: String,
	position_code: String,
	overrides: Dictionary,
) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = player_name
	player.position_role = role_name
	player.position_code = position_code
	player.apply_role_physical_defaults()
	for property_name in overrides:
		player.set(str(property_name), overrides[property_name])
	if not overrides.has("serve_technique"):
		player.serve_technique = player.serve_accuracy
	if not overrides.has("serve_placement"):
		player.serve_placement = player.serve_accuracy
	if not overrides.has("serve_consistency"):
		player.serve_consistency = player.serve_accuracy
	if not overrides.has("serve_aggression"):
		player.serve_aggression = roundi(
			float(player.serve_power) * 0.60 + float(player.serve_accuracy) * 0.40
		)
	if not overrides.has("serve_variation"):
		player.serve_variation = player.serve_accuracy
	AttributeProfiles.assign_serve_style(player)
	Familiarity.initialize_player(player)
	return player


func set_position_training(player_id: int, position_name: String) -> String:
	var player := player_by_id(player_id)
	if player == null: return "Player not found."
	if position_name != "None" and position_name not in Familiarity.POSITIONS:
		return "Unknown training position."
	player.position_training_target = "" if position_name == "None" else position_name
	roster_changed.emit()
	return ""

func assign_player_position(player_id: int, position_name: String) -> String:
	var player := player_by_id(player_id)
	if player == null or position_name not in Familiarity.POSITIONS: return "Invalid position assignment."
	if float(player.position_familiarity.get(position_name, 0.0)) < 20.0: return "The player is not yet emergency-ready there."
	for role_name in team.depth_chart:
		var ids: Array = team.depth_chart[role_name]
		ids.erase(player_id)
		team.depth_chart[role_name] = ids
	if position_name not in team.depth_chart: team.depth_chart[position_name] = []
	team.depth_chart[position_name].append(player_id)
	player.position_role = position_name
	player.position_code = {"Setter": "S", "Outside Hitter": "OH", "Middle Blocker": "M", "Opposite": "OP", "Libero": "L"}.get(position_name, "P")
	if position_name != "Libero": team.libero_ids.erase(player_id)
	_rebuild_testing_rotations()
	roster_changed.emit()
	return ""


func select_rotation(rotation_number: int) -> String:
	if rotation_number not in rotations:
		return "Rotation %d is unavailable." % rotation_number
	selected_rotation = rotation_number
	called_play_id = int(active_play_ids_by_rotation.get(rotation_number, -1))
	rotation_changed.emit(selected_rotation)
	return ""


func current_lineup() -> RotationLineup:
	return rotations.get(selected_rotation) as RotationLineup


func current_defensive_plan() -> Resource:
	return defensive_plans.get(selected_rotation) as Resource


func match_roster_errors() -> Array[String]:
	var errors: Array[String] = team.validate() if team != null else ["No managed team exists."]
	var lineup := current_lineup()
	if lineup == null:
		errors.append("No rotation lineup is selected.")
		return errors
	for lineup_error in lineup.validate():
		errors.append(lineup_error)
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if team != null and player_id not in team.player_ids:
			errors.append("Slot %d contains an unregistered player." % slot_number)
			continue
		var player := player_by_id(player_id)
		if player == null:
			errors.append("Slot %d references a missing player." % slot_number)
		elif player.availability in ["Injured", "Suspended"]:
			errors.append("%s is unavailable (%s)." % [player.display_name, player.availability])
	return errors


func configure_setting_system(system_name: String, second_setter_id: int = -1) -> String:
	if system_name not in ["5-1", "6-2"]:
		return "Unknown setting system."
	if system_name == "6-2":
		for rotation_number in rotations:
			var candidate_lineup := rotations[rotation_number] as RotationLineup
			var first_slot := candidate_lineup.slot_for_player(candidate_lineup.setter_id)
			var second_slot := candidate_lineup.slot_for_player(second_setter_id)
			if second_slot < 0:
				return "The second setter must appear in every current rotation."
			if CourtConstants.is_front_row_slot(first_slot) \
					== CourtConstants.is_front_row_slot(second_slot):
				return "The two 6-2 setters must remain in opposite rows."
	for rotation_number in rotations:
		var lineup := rotations[rotation_number] as RotationLineup
		lineup.setting_system = system_name
		lineup.designated_setter_ids = [lineup.setter_id]
		if system_name == "6-2":
			lineup.designated_setter_ids.append(second_setter_id)
		var plan: Resource = defensive_plans.get(rotation_number) as Resource
		if plan != null:
			plan.ensure_defaults(lineup)
	rotation_changed.emit(selected_rotation)
	return ""


func save_defensive_plan(
	block_strategy: String,
	floor_system: String,
	serve_target: String,
	serve_risk: float,
) -> void:
	var plan: Resource = current_defensive_plan()
	if plan == null:
		plan = DefensivePlanScript.new()
		plan.rotation_number = selected_rotation
		defensive_plans[selected_rotation] = plan
	plan.block_strategy = block_strategy
	plan.floor_system = floor_system
	plan.serve_target = serve_target
	plan.serve_risk = clampf(serve_risk, 0.0, 1.0)


func set_defender_position(player_id: int, position: Vector2) -> void:
	var plan: Resource = current_defensive_plan()
	if plan != null:
		plan.set_defender_position(player_id, position)


func set_coverage_zone(
	player_id: int,
	zone_type: int,
	radius_meters: float,
	priority: int,
	enabled: bool,
) -> void:
	var plan: Resource = current_defensive_plan()
	if plan != null:
		plan.set_zone(player_id, zone_type, radius_meters, priority, enabled)


func set_coverage_zone_center(
	player_id: int,
	zone_type: int,
	position: Vector2,
) -> void:
	var plan: Resource = current_defensive_plan()
	if plan != null:
		plan.set_zone_center(player_id, zone_type, position)


func player_by_id(player_id: int) -> VolleyballPlayer:
	for player in players:
		if player.id == player_id:
			return player
	return null


func save_offensive_play(play: OffensivePlay) -> Dictionary:
	var lineup := rotations.get(play.rotation_number) as RotationLineup
	if lineup == null:
		return {"success": false, "errors": ["Play rotation is unavailable."]}
	for assignment in play.assignments:
		var assigned_player := player_by_id(assignment.player_id)
		if assigned_player != null and assigned_player.position_role == "Libero":
			return {
				"success": false,
				"errors": ["The libero cannot be assigned an attack."],
			}
	var errors := PlayValidator.validate(play, lineup)
	if not errors.is_empty():
		return {"success": false, "errors": errors}
	var saved_copy := OffensivePlay.from_dict(play.to_dict())
	if saved_copy.id < 0:
		saved_copy.id = _next_play_id
		_next_play_id += 1
	var replaced := false
	for index in range(saved_plays.size()):
		if saved_plays[index].id == saved_copy.id:
			saved_plays[index] = saved_copy
			replaced = true
			break
	if not replaced:
		saved_plays.append(saved_copy)
	if int(active_play_ids_by_rotation.get(saved_copy.rotation_number, -1)) < 0:
		active_play_ids_by_rotation[saved_copy.rotation_number] = saved_copy.id
		if saved_copy.rotation_number == selected_rotation:
			called_play_id = saved_copy.id
	playbook_changed.emit()
	return {"success": true, "play": saved_copy}


func call_play(play_id: int) -> String:
	for play in saved_plays:
		if play.id == play_id and play.rotation_number == selected_rotation:
			called_play_id = play_id
			active_play_ids_by_rotation[selected_rotation] = play_id
			return ""
	return "The selected play is not available for rotation %d." % selected_rotation


func called_play() -> OffensivePlay:
	for play in saved_plays:
		if play.id == called_play_id:
			return play
	return null


func resolve_active_rally(
	seed_value: int,
	development_continuous_reception: bool = false,
) -> Resource:
	var simulator: RefCounted = RallySimulatorScript.new()
	return simulator.resolve(
		players, current_lineup(), called_play(), opponent_team,
		current_defensive_plan(), bool(match_state.serving_home), seed_value,
		development_continuous_reception,
		team.principles if team != null else null,
		team.team_name if team != null else "",
		match_state.serve_context() if match_state != null else {},
		float(match_state.match_flow) if match_state != null else 0.0,
	)


func record_rally(result: Resource) -> Dictionary:
	if match_state == null:
		match_state = MatchStateScript.new()
	var update: Dictionary = match_state.record_rally(result)
	_record_serve_familiarity(result)
	if opponent_team != null:
		opponent_team.observe_rally(result)
	_apply_rally_dynamics(result, update)
	if bool(update.get("rotated", false)):
		select_rotation(int(match_state.home_rotation))
	if bool(update.get("opponent_rotated", false)) and opponent_team != null:
		opponent_team.select_rotation(int(match_state.opponent_rotation))
	return update


func _record_serve_familiarity(result: Resource) -> void:
	if result == null:
		return
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null or event.event_type != RallyEvent.EventType.SERVE:
			continue
		var side := str(event.metadata.get("side", ""))
		var server_id := int(event.metadata.get("server_id", event.actor_id))
		var server: VolleyballPlayer = player_by_id(server_id) if side == "home" \
			else opponent_team.player_by_id(server_id) as VolleyballPlayer
		if server != null:
			Familiarity.record_exposure(server, [
				"serve_target:%s" % str(event.metadata.get("target", "unknown")),
			])
		return


func call_timeout() -> String:
	if match_state == null or match_state.match_complete:
		return "No active match is available."
	if match_state.home_timeouts_remaining <= 0:
		return "No timeouts remain in this set."
	match_state.home_timeouts_remaining -= 1
	var captain := player_by_id(int(team.captain_id)) if team != null else null
	var leadership := float(captain.leadership) / 100.0 if captain != null else 0.5
	var confidence_recovery := clampf(
		0.25 + float(team.cohesion) * 0.20 + leadership * 0.15, 0.25, 0.60
	)
	for player in players:
		player.fatigue = maxf(player.fatigue - 0.08, 0.0)
		player.match_confidence = lerpf(
			player.match_confidence, 0.0,
			confidence_recovery if player.match_confidence < 0.0 else 0.12,
		)
	return ""


func substitute_current_rotation(player_out_id: int, player_in_id: int) -> String:
	var current := current_lineup()
	var slot_number := current.slot_for_player(player_out_id)
	if slot_number < 0:
		return "The outgoing player is not on court."
	if current.slot_for_player(player_in_id) >= 0:
		return "The incoming player is already on court."
	var player_out := player_by_id(player_out_id)
	var player_in := player_by_id(player_in_id)
	if player_out == null or player_in == null:
		return "Both substitution players must exist."
	if player_out.position_role == "Setter" and player_in.position_role != "Setter":
		return "A setter requires another setter as the legal replacement."
	var libero_exchange := player_out.position_role == "Libero" \
		or player_in.position_role == "Libero"
	if libero_exchange:
		var partner := player_in if player_out.position_role == "Libero" else player_out
		if partner.position_role != "Middle Blocker":
			return "The libero may only exchange with a middle blocker."
		if CourtConstants.is_front_row_slot(slot_number):
			return "The libero exchange is only legal in a back-row slot."
		var error := current.assign_slot(slot_number, player_in_id)
		if not error.is_empty():
			return error
		match_state.substitution_history.append({
			"out": player_out_id, "in": player_in_id, "counted": false,
			"changes": [{"rotation": selected_rotation, "slot": slot_number}],
		})
		return ""
	if match_state.home_substitutions_used >= 6:
		return "The six-substitution limit has been reached for this set."
	var existing_partner := int(match_state.substitution_pairs.get(player_out_id, -1))
	if existing_partner >= 0 and existing_partner != player_in_id:
		return "The outgoing player is already paired with another substitute."
	var changes: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		var lineup := rotations[rotation_number] as RotationLineup
		var rotation_slot := lineup.slot_for_player(player_out_id)
		if rotation_slot < 0:
			continue
		if lineup.slot_for_player(player_in_id) >= 0:
			return "The incoming player already appears in rotation %d." % rotation_number
		changes.append({"rotation": rotation_number, "slot": rotation_slot})
	if changes.is_empty():
		return "The outgoing player has no rotation-sheet positions to replace."
	for change in changes:
		var lineup := rotations[int(change["rotation"])] as RotationLineup
		lineup.assign_slot(int(change["slot"]), player_in_id)
		var plan: Resource = defensive_plans.get(int(change["rotation"])) as Resource
		if plan != null:
			plan.set_defender_position(
				player_in_id, CourtConstants.slot_position(int(change["slot"]))
			)
			plan.ensure_defaults(lineup)
	match_state.home_substitutions_used += 1
	match_state.substitution_pairs[player_out_id] = player_in_id
	match_state.substitution_pairs[player_in_id] = player_out_id
	match_state.substitution_history.append({
		"out": player_out_id, "in": player_in_id, "counted": true,
		"changes": changes,
	})
	return ""


func undo_last_substitution() -> String:
	if match_state.substitution_history.is_empty():
		return "There is no substitution to undo."
	var entry: Dictionary = match_state.substitution_history.pop_back()
	var player_out_id := int(entry.get("out", -1))
	var player_in_id := int(entry.get("in", -1))
	for change in entry.get("changes", []):
		var rotation_number := int(change.get("rotation", selected_rotation))
		var slot_number := int(change.get("slot", -1))
		if rotation_number in rotations and slot_number >= 1:
			(rotations[rotation_number] as RotationLineup).assign_slot(
				slot_number, player_out_id
			)
	if bool(entry.get("counted", false)):
		match_state.home_substitutions_used = maxi(
			match_state.home_substitutions_used - 1, 0
		)
		match_state.substitution_pairs.erase(player_out_id)
		match_state.substitution_pairs.erase(player_in_id)
	return ""


func bench_player_ids() -> Array[int]:
	var result: Array[int] = []
	var lineup := current_lineup()
	for player in players:
		if lineup.slot_for_player(player.id) < 0:
			result.append(player.id)
	return result


func set_team_captain(player_id: int) -> String:
	var error: String = team.set_captain(player_id)
	if error.is_empty():
		roster_changed.emit()
	return error


func set_team_libero(player_id: int, enabled: bool) -> String:
	var player := player_by_id(player_id)
	if player == null:
		return "That roster player does not exist."
	if enabled and player.position_role != "Libero":
		return "Only a libero-role player can receive the libero designation."
	var error: String = team.set_libero(player_id, enabled)
	if error.is_empty():
		roster_changed.emit()
	return error


func register_player(player: VolleyballPlayer) -> String:
	if player == null or player.id < 0:
		return "A registered player requires a valid identity."
	if player_by_id(player.id) != null:
		return "That player identity is already in use."
	var error: String = team.add_player(player.id)
	if not error.is_empty():
		return error
	players.append(player)
	roster_changed.emit()
	return ""

func set_player_starting(player_id: int, starting: bool) -> String:
	if player_by_id(player_id) == null: return "Player not found."
	if starting:
		if player_id in team.starting_player_ids: return ""
		var candidate := player_by_id(player_id)
		var same_kind := 0
		for starter_id in team.starting_player_ids:
			if (player_by_id(starter_id).position_role == "Libero") == (candidate.position_role == "Libero"): same_kind += 1
		var limit := 1 if candidate.position_role == "Libero" else 6
		if same_kind >= limit: return "Bench another %s first." % ("libero" if limit == 1 else "court starter")
		team.starting_player_ids.append(player_id)
	else:
		team.starting_player_ids.erase(player_id)
		clear_player_from_rotations(player_id)
	_rebuild_testing_rotations()
	roster_changed.emit()
	return ""

func clear_player_from_rotations(player_id: int) -> void:
	for rotation_number in rotations:
		var lineup := rotations[rotation_number] as RotationLineup
		var slot_number := lineup.slot_for_player(player_id)
		if slot_number >= 1: lineup.assign_slot(slot_number, -1)

func _rebuild_testing_rotations() -> void:
	var court_ids: Array[int] = []
	var libero_id := -1
	for player_id in team.starting_player_ids:
		if player_by_id(player_id).position_role == "Libero": libero_id = player_id
		else: court_ids.append(player_id)
	if court_ids.size() != 6: return
	var setter_id := int(court_ids[0])
	for player_id in court_ids:
		if player_by_id(player_id).position_role == "Setter": setter_id = player_id; break
	rotations.clear()
	for rotation_number in range(1, 7):
		var lineup := RotationLineup.new()
		lineup.rotation_number = rotation_number
		lineup.setter_id = setter_id
		lineup.designated_setter_ids = [setter_id]
		for slot_number in range(1, 7):
			var player_id := int(court_ids[posmod(slot_number - rotation_number, 6)])
			if libero_id >= 0 and slot_number in [1, 5, 6] and player_by_id(player_id).position_role == "Middle Blocker": player_id = libero_id
			lineup.assign_slot(slot_number, player_id)
		rotations[rotation_number] = lineup


func unregister_player(player_id: int) -> String:
	for rotation_number in rotations:
		if (rotations[rotation_number] as RotationLineup).slot_for_player(player_id) >= 0:
			return "Remove the player from every rotation sheet before unregistering them."
	var error: String = team.remove_player(player_id)
	if not error.is_empty():
		return error
	for index in range(players.size() - 1, -1, -1):
		if players[index].id == player_id:
			players.remove_at(index)
			break
	roster_changed.emit()
	return ""


## What one rally costs an on-court player of average stamina, and the extra
## the decisive actor pays for having been the one who had to swing, dig or
## chase the ball down.
## A typical 70-rally match should tax the lineup without pinning everyone at
## exhaustion. The former 0.008 base alone charged 0.56 before decisive work,
## pushing low-stamina lineups toward 1.0 and recreating the attack-error cliff
## inside a single fixture even after between-match recovery was repaired.
const RALLY_FATIGUE_BASE: float = 0.0035
const RALLY_FATIGUE_DECISIVE: float = 0.006

## How far stamina moves that cost. `stamina` is trained by the Strength & Jump
## focus and was read by nothing: every player tired at exactly the same rate
## no matter how conditioned they were, which made the attribute decorative and
## left squad fitness with no way to express itself over a season. A player at
## 50 -- the default every hand-authored fixture player sits at -- pays exactly
## the old flat rate, so this changes *who* tires rather than shifting the
## baseline every other calibration was measured against.
const STAMINA_FATIGUE_SCALE_MIN: float = 0.6
const STAMINA_FATIGUE_SCALE_MAX: float = 1.4


static func stamina_fatigue_scale(player: VolleyballPlayer) -> float:
	if player == null:
		return 1.0
	return lerpf(STAMINA_FATIGUE_SCALE_MAX, STAMINA_FATIGUE_SCALE_MIN,
		clampf(float(player.stamina) / 100.0, 0.0, 1.0))


func _apply_rally_dynamics(result: Resource, update: Dictionary) -> void:
	var home_on_court: Array[VolleyballPlayer] = []
	var lineup := current_lineup()
	for slot_number in range(1, 7):
		var player := player_by_id(lineup.player_at_slot(slot_number))
		if player != null:
			home_on_court.append(player)
	var opponent_on_court: Array[VolleyballPlayer] = []
	if opponent_team != null:
		for opponent_resource in opponent_team.on_court_players():
			var opponent_player := opponent_resource as VolleyballPlayer
			if opponent_player != null:
				opponent_on_court.append(opponent_player)

	for player in home_on_court + opponent_on_court:
		player.fatigue = minf(
			player.fatigue + rally_fatigue_cost(player, RALLY_FATIGUE_BASE), 1.0
		)
		## And what the floor cost them on top of the rally itself. A libero who
		## hits the deck three times in a rally has worked harder than one who
		## stayed on their feet, and the base cost cannot tell them apart.
		var floor_cost := float(result.recovery_fatigue.get(player.id, 0.0))
		if floor_cost > 0.0:
			player.fatigue = minf(player.fatigue + floor_cost, 1.0)

	var decisive := player_by_id(int(result.decisive_actor_id))
	if decisive == null and opponent_team != null:
		decisive = opponent_team.player_by_id(int(result.decisive_actor_id)) \
			as VolleyballPlayer
	if decisive != null:
		decisive.fatigue = minf(
			decisive.fatigue + rally_fatigue_cost(
				decisive, RALLY_FATIGUE_DECISIVE
			), 1.0
		)
	var captain := player_by_id(int(team.captain_id)) if team != null else null
	var home_leadership := float(captain.leadership) / 100.0 \
		if captain != null and captain in home_on_court else 0.5
	var opponent_leadership := 0.5
	for opponent_player in opponent_on_court:
		opponent_leadership = maxf(
			opponent_leadership, float(opponent_player.leadership) / 100.0
		)
	_apply_confidence_shift(
		home_on_court, bool(result.home_team_won),
		float(team.cohesion) if team != null else 0.5,
		home_leadership, int(result.decisive_actor_id),
		identity_confidence_volatility(),
	)
	_apply_confidence_shift(
		opponent_on_court, not bool(result.home_team_won), 0.5,
		opponent_leadership, int(result.decisive_actor_id),
	)
	if bool(update.get("set_complete", false)):
		for player in home_on_court + opponent_on_court:
			player.match_confidence *= 0.55
	result.analysis["home_match_confidence"] = _average_confidence(home_on_court)
	result.analysis["opponent_match_confidence"] = _average_confidence(
		opponent_on_court
	)
	var effects: Dictionary = result.analysis.get("identity_effects", {})
	effects["confidence_volatility"] = identity_confidence_volatility()
	result.analysis["identity_effects"] = effects
	if opponent_team != null:
		result.analysis["identity_scouting"] = {
			"regional_alignment": float(team.regional_alignment) if team != null else 0.5,
			"opponent_scouting_confidence": float(opponent_team.scouting_confidence),
			"opponent_adaptation_rate": float(opponent_team.adaptation_rate),
		}


static func rally_fatigue_cost(player: VolleyballPlayer, base_cost: float) -> float:
	return maxf(base_cost * stamina_fatigue_scale(player), 0.0)


func _apply_confidence_shift(
	side_players: Array[VolleyballPlayer],
	won: bool,
	cohesion: float,
	leadership: float,
	decisive_actor_id: int,
	volatility: float = 1.0,
) -> void:
	## 0.28 rather than 0.14 because halving the flow impact band also halved the
	## shifts this reads. Doubling the coefficient keeps confidence moving exactly
	## as far as it did before, so lengthening flow's memory changes flow and
	## nothing else.
	var magnitude := (0.035 + absf(float(match_state.last_flow_shift)) * 0.28) \
		* volatility
	for player in side_players:
		var sensitivity := lerpf(1.25, 0.60, float(player.composure) / 100.0)
		var team_response := lerpf(0.90, 1.05, cohesion) if won \
			else lerpf(1.10, 0.75, cohesion)
		var leader_response := lerpf(1.0, 1.10, leadership) if won \
			else lerpf(1.0, 0.75, leadership)
		var shift := magnitude * sensitivity * team_response * leader_response
		if player.id == decisive_actor_id:
			shift += 0.035 * sensitivity
		player.match_confidence = clampf(
			player.match_confidence * 0.98 + (shift if won else -shift),
			-1.0, 1.0,
		)


func identity_confidence_volatility() -> float:
	if team == null or team.principles == null:
		return 1.0
	return 1.0 + (float(team.principles.emotional_expression) - 0.5) * 0.6


func _configure_opponent_identity_scouting() -> void:
	if opponent_team == null:
		return
	var alignment := float(team.regional_alignment) if team != null else 0.5
	## Familiar regional systems are easier to prepare for. A countercultural
	## identity pays for integration up front, then gives opponents less useful
	## film and slows how quickly their block and floor defense adapt in-match.
	opponent_team.scouting_confidence = lerpf(0.26, 0.52, alignment)
	opponent_team.adaptation_rate = lerpf(0.09, 0.18, alignment)


func _average_confidence(side_players: Array[VolleyballPlayer]) -> float:
	if side_players.is_empty():
		return 0.0
	var total := 0.0
	for player in side_players:
		total += player.match_confidence
	return total / float(side_players.size())


func to_dict() -> Dictionary:
	var player_data: Array[Dictionary] = []
	for player in players:
		player_data.append(player.to_dict())
	var rotation_data: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		if rotation_number in rotations:
			rotation_data.append((rotations[rotation_number] as RotationLineup).to_dict())
	var play_data: Array[Dictionary] = []
	for play in saved_plays:
		play_data.append(play.to_dict())
	return {
		"players": player_data,
		"team": team.to_dict() if team != null else {},
		"rotations": rotation_data,
		"saved_plays": play_data,
		"selected_rotation": selected_rotation,
		"called_play_id": called_play_id,
		"active_play_ids_by_rotation": active_play_ids_by_rotation.duplicate(),
		"next_play_id": _next_play_id,
		"match_state": match_state.to_dict() if match_state != null else {},
		"defensive_plans": _defensive_plans_to_data(),
		"opponent_adaptation": opponent_team.adaptation_to_dict() \
			if opponent_team != null else {},
	}


func from_dict(data: Dictionary) -> void:
	_seed_opponent()
	players.clear()
	for player_data in data.get("players", []):
		var player := VolleyballPlayer.from_dict(player_data)
		AttributeProfiles.assign_serve_style(player)
		players.append(player)
	team = TeamScript.from_dict(data.get("team", {}))
	if team.player_ids.is_empty():
		for player in players:
			team.player_ids.append(player.id)
	rotations.clear()
	for rotation_data in data.get("rotations", []):
		var lineup := RotationLineup.from_dict(rotation_data)
		rotations[lineup.rotation_number] = lineup
	if team.starting_player_ids.is_empty():
		for rotation_number in rotations:
			var loaded_lineup := rotations[rotation_number] as RotationLineup
			for slot_number in range(1, 7):
				var loaded_id := loaded_lineup.player_at_slot(slot_number)
				if loaded_id >= 0 and loaded_id not in team.starting_player_ids:
					team.starting_player_ids.append(loaded_id)
	saved_plays.clear()
	for play_data in data.get("saved_plays", []):
		saved_plays.append(OffensivePlay.from_dict(play_data))
	selected_rotation = clampi(int(data.get("selected_rotation", 1)), 1, 6)
	active_play_ids_by_rotation.clear()
	var active_data: Dictionary = data.get("active_play_ids_by_rotation", {})
	for rotation_key in active_data:
		active_play_ids_by_rotation[int(rotation_key)] = int(active_data[rotation_key])
	called_play_id = int(active_play_ids_by_rotation.get(
		selected_rotation, data.get("called_play_id", -1)
	))
	if called_play_id >= 0 and selected_rotation not in active_play_ids_by_rotation:
		active_play_ids_by_rotation[selected_rotation] = called_play_id
	_next_play_id = maxi(int(data.get("next_play_id", 1)), 1)
	match_state = MatchStateScript.new()
	match_state.load_dict(data.get("match_state", {}))
	opponent_team.select_rotation(int(match_state.opponent_rotation))
	opponent_team.load_adaptation(data.get("opponent_adaptation", {}))
	defensive_plans.clear()
	for plan_data in data.get("defensive_plans", []):
		var plan: Resource = DefensivePlanScript.new()
		plan.load_dict(plan_data)
		plan.ensure_defaults(rotations[plan.rotation_number])
		defensive_plans[plan.rotation_number] = plan
	for rotation_number in range(1, 7):
		if rotation_number not in defensive_plans:
			var fallback: Resource = DefensivePlanScript.new()
			fallback.rotation_number = rotation_number
			fallback.ensure_defaults(rotations[rotation_number])
			defensive_plans[rotation_number] = fallback


func _defensive_plans_to_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rotation_number in range(1, 7):
		if rotation_number in defensive_plans:
			result.append(defensive_plans[rotation_number].to_dict())
	return result


## One opponent voli built as a copy of the home voli in the same position.
##
## Every ability attribute plus the body, because reach decides blocking and
## height decides reach -- a mirror that copied technique and not measurements
## would be a control in name only. Identity stays theirs: id, name and position
## code are the club's, everything that decides a rally is the same on both
## sides of the net.
##
## Handedness is deliberately included. It is the one presentation field that
## also changes geometry, and leaving it at a default would have quietly made
## every Port Azure attacker right-handed against a home squad that may not be.
## Play somebody else: re-region the opponent in place.
##
## **Everything physical stays mirrored and only the identity moves.** That is
## the whole design of this function and it is worth being explicit about,
## because the obvious implementation — generate a fresh regional roster — would
## destroy the one control this project has. Port Azure is a position-for-
## position copy of the home squad, which is what makes any residual gap between
## the two sides engine asymmetry by definition; a Xérvyan roster with Xérvyan
## attributes would confound identity with talent on the first rally, and no
## measurement taken afterward could separate them.
##
## So a Xérvu opponent is the same seven bodies with the same seven-hundred
## attributes, wearing Xérvu's name, called by Xérvyan names, playing by Xérvu's
## principles. Any difference a player sees across the net *is* the region. When
## academies exist and each region raises its own volis, that is a deliberate
## second act — regional talent layered on top of regional identity — and it
## should be added knowing it spends this control.
##
## Names are indexed rather than drawn at random so the same fixture always
## fields the same eleven people.
func set_opponent_region(region_name: String, club_index: int = 0) -> void:
	if opponent_team == null:
		return
	var resolved := VolleyballRegions.canonical_name(region_name)
	opponent_team.region = resolved
	opponent_team.team_name = VolleyballRegions.club_name(resolved, club_index)
	var definition := VolleyballRegions.definition(resolved)
	var given_names: Array = definition.get("names", [])
	for index in range(opponent_team.players.size()):
		var player := opponent_team.players[index] as VolleyballPlayer
		if player == null:
			continue
		## `home_region` is where a voli was raised and `club_region` where they
		## play now. A club's own squad is overwhelmingly local, and both being
		## the region is the honest default until transfers move people.
		player.home_region = resolved
		player.club_region = resolved
		if not given_names.is_empty():
			player.display_name = str(given_names[index % given_names.size()])


func _mirror_player(
	player_id: int,
	player_name: String,
	role_name: String,
	position_code: String,
	source: VolleyballPlayer,
) -> VolleyballPlayer:
	var overrides := {}
	if source != null:
		for attribute_name in VolleyballPlayer.ABILITY_ATTRIBUTES:
			overrides[attribute_name] = source.get(attribute_name)
		for measurement in [
			"height_cm", "mass_kg", "wingspan_cm",
			"age", "professional_experience", "potential", "dominant_hand",
		]:
			overrides[measurement] = source.get(measurement)
	return _make_player(player_id, player_name, role_name, position_code, overrides)


## The home voli with this id, during seeding, before any lineup exists.
func _player_by_id(player_id: int) -> VolleyballPlayer:
	for candidate in players:
		var player: VolleyballPlayer = candidate as VolleyballPlayer
		if player != null and player.id == player_id:
			return player
	return null
