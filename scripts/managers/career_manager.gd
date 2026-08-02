extends Node

const CareerStateModel := preload("res://scripts/models/career_state.gd")
const TeamModel := preload("res://scripts/models/team.gd")
const FixtureModel := preload("res://scripts/models/fixture.gd")
const MatchFormatModel := preload("res://scripts/models/match_format.gd")
const Generator := preload("res://scripts/systems/player_generator.gd")
const Training := preload("res://scripts/systems/training_system.gd")
const Calendar := preload("res://scripts/data/calendar_rules.gd")
const SixnetLeague := preload("res://scripts/systems/sixnet_league.gd")

signal career_changed
signal career_loaded
signal week_advanced(report: Dictionary)
signal transfer_pool_changed

const SAVE_DIRECTORY := "user://careers"

var career: Resource
var last_training_report: Dictionary = {}
var game_manager_override: Node


func has_career() -> bool:
	return career != null


func create_career(
	career_name: String,
	organization_name: String,
	region: String,
	organization_type: String,
	identity: String,
) -> String:
	if career_name.strip_edges().is_empty() or organization_name.strip_edges().is_empty():
		return "Career and organization names are required."
	var state: Resource = CareerStateModel.new()
	state.career_name = career_name.strip_edges()
	state.organization_name = organization_name.strip_edges()
	state.save_id = _safe_id(state.career_name)
	state.region = region
	state.organization_type = organization_type
	state.identity = identity
	state.reputation = 6 if organization_type == "Academy" else 10
	state.finances = 65000 if organization_type == "Academy" else 120000
	state.match_format = MatchFormatModel.new()
	state.match_format.format_name = "Career Best of 3"
	state.match_format.best_of_sets = 3
	state.match_format.regular_set_target = 25
	state.match_format.deciding_set_target = 25
	var seed_value: int = absi((state.career_name + region + organization_type).hash())
	var generated: Array[VolleyballPlayer] = Generator.generate_roster(
		region, organization_type, seed_value
	)
	var team: Resource = TeamModel.new()
	team.team_name = state.organization_name
	team.short_name = _short_name(state.organization_name)
	team.identity = identity
	var error: String = _game_manager().configure_managed_team(team, generated)
	if not error.is_empty():
		return error
	state.transfer_pool = Generator.generate_market(region, seed_value + 991)
	state.fixtures = _starting_fixtures(region)
	SixnetLeague.ensure_bootstrapped(state)
	career = state
	last_training_report = {}
	save_career()
	career_changed.emit()
	career_loaded.emit()
	return ""


func calendar_state() -> Dictionary:
	return Calendar.state_for_week(int(career.absolute_week)) if career != null else {}


func date_text() -> String:
	return Calendar.display_date(int(career.absolute_week)) if career != null else "No career"


func next_fixture() -> Resource:
	if career == null:
		return null
	for fixture in career.fixtures:
		if not bool(fixture.completed):
			return fixture
	return null


func fixture_by_id(fixture_id: int) -> Resource:
	if career == null:
		return null
	for fixture in career.fixtures:
		if int(fixture.id) == fixture_id:
			return fixture
	return null


func set_training_focus(activity_name: String) -> String:
	if career == null:
		return "No active career."
	if activity_name not in Training.ACTIVITIES:
		return "Unknown training activity."
	career.training_focus = activity_name
	career_changed.emit()
	return ""


func advance_week() -> String:
	if career == null:
		return "No active career."
	var fixture := next_fixture()
	if fixture != null and int(fixture.week) <= int(career.absolute_week) \
			and not bool(fixture.completed):
		return "Play the scheduled fixture before advancing the week."
	SixnetLeague.ensure_bootstrapped(career)
	last_training_report = Training.apply_week(
		career.training_focus, _game_manager().players, _game_manager().team
	)
	var pre_year: int = Calendar.state_for_week(career.absolute_week).year
	career.absolute_week += 1
	var post_year: int = Calendar.state_for_week(career.absolute_week).year
	if post_year != pre_year:
		SixnetLeague.resolve_season_boundary(career)
	for player in _game_manager().players:
		player.fatigue = maxf(player.fatigue - 0.04, 0.0)
	save_career()
	week_advanced.emit(last_training_report)
	career_changed.emit()
	return ""


func prepare_fixture(fixture_id: int) -> String:
	var fixture := fixture_by_id(fixture_id)
	if fixture == null or fixture.completed:
		return "That fixture is unavailable."
	if int(fixture.week) > int(career.absolute_week):
		return "That fixture is not yet due."
	var errors: Array[String] = _game_manager().match_roster_errors()
	if not errors.is_empty():
		return errors[0]
	career.active_fixture_id = fixture_id
	_game_manager().start_new_match(career.match_format)
	career_changed.emit()
	return ""


func complete_active_match() -> void:
	if career == null or not bool(_game_manager().match_state.match_complete):
		return
	var fixture := fixture_by_id(int(career.active_fixture_id))
	if fixture != null:
		fixture.completed = true
		fixture.home_sets = int(_game_manager().match_state.home_sets)
		fixture.opponent_sets = int(_game_manager().match_state.opponent_sets)
		career.reputation = clampi(int(career.reputation) + (
			2 if fixture.home_sets > fixture.opponent_sets else -1
		), 0, 100)
	career.active_fixture_id = -1
	save_career()
	career_changed.emit()


func sign_transfer(player_id: int) -> String:
	if career == null:
		return "No active career."
	var candidate: VolleyballPlayer
	for player_resource in career.transfer_pool:
		if int(player_resource.id) == player_id:
			candidate = player_resource as VolleyballPlayer
			break
	if candidate == null:
		return "That player is no longer available."
	var error: String = _game_manager().register_player(candidate)
	if not error.is_empty():
		return error
	career.transfer_pool.erase(candidate)
	save_career()
	transfer_pool_changed.emit()
	career_changed.emit()
	return ""

func release_to_pool(player_id: int) -> String:
	var player := _game_manager().player_by_id(player_id) as VolleyballPlayer
	if player == null: return "Player not found."
	if player_id in _game_manager().team.starting_player_ids: return "Move the player to the bench first."
	_game_manager().clear_player_from_rotations(player_id)
	var error: String = _game_manager().unregister_player(player_id)
	if not error.is_empty(): return error
	career.transfer_pool.append(player)
	transfer_pool_changed.emit()
	career_changed.emit()
	return ""

func delete_save(save_id: String) -> String:
	var path := _save_path(save_id)
	if not FileAccess.file_exists(path): return "Career save not found."
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK: return "Could not delete the career save."
	if career != null and str(career.save_id) == _safe_id(save_id): career = null
	return ""


func transfer_cost(player: VolleyballPlayer) -> int:
	return int(round((2500.0 + float(player.potential) * 140.0 \
		+ maxf(26.0 - float(player.age), 0.0) * 260.0) / 500.0) * 500.0)


func save_career() -> String:
	if career == null:
		return "No active career."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	var payload := {"save_version": 1, "metadata": _metadata(),
		"career": career.to_dict(), "game_state": _game_manager().to_dict()}
	var file := FileAccess.open(_save_path(career.save_id), FileAccess.WRITE)
	if file == null:
		return "Could not open the career save file."
	file.store_string(JSON.stringify(payload, "\t"))
	return ""


func load_career(save_id: String) -> String:
	var file := FileAccess.open(_save_path(save_id), FileAccess.READ)
	if file == null:
		return "Career save not found."
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return "Career save is invalid."
	var payload: Dictionary = parsed
	career = CareerStateModel.from_dict(payload.get("career", {}))
	_game_manager().from_dict(payload.get("game_state", {}))
	career_loaded.emit()
	career_changed.emit()
	return ""


func list_save_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var file := FileAccess.open("%s/%s" % [SAVE_DIRECTORY, file_name], FileAccess.READ)
			var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
			if parsed is Dictionary:
				var metadata: Dictionary = parsed.get("metadata", {}).duplicate(true)
				metadata["save_id"] = file_name.trim_suffix(".json")
				result.append(metadata)
		file_name = directory.get_next()
	directory.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_saved_unix", 0)) > int(b.get("last_saved_unix", 0)))
	return result


func _metadata() -> Dictionary:
	var fixture := next_fixture()
	return {"career_name": career.career_name,
		"organization_name": career.organization_name,
		"organization_type": career.organization_type, "region": career.region,
		"absolute_week": career.absolute_week, "date": date_text(),
		"reputation": career.reputation,
		"next_fixture": fixture.opponent_name if fixture != null else "None",
		"last_saved_unix": int(Time.get_unix_time_from_system())}


func _starting_fixtures(region: String) -> Array[Resource]:
	var opponents := ["Port Azure VC", "%s Select" % region, "Northbridge Volley"]
	var result: Array[Resource] = []
	for index in range(opponents.size()):
		var fixture: Resource = FixtureModel.new()
		fixture.id = index + 1
		fixture.week = (index + 1) * 2
		fixture.opponent_name = opponents[index]
		fixture.competition_name = "Regional Series"
		result.append(fixture)
	return result


func _save_path(save_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIRECTORY, _safe_id(save_id)]


func _safe_id(value: String) -> String:
	var safe := value.to_lower().strip_edges().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		safe = safe.replace(character, "")
	return safe if not safe.is_empty() else "career_1"


func _short_name(value: String) -> String:
	var words := value.split(" ", false)
	var result := ""
	for word in words:
		result += word.left(1).to_upper()
	return result.left(4) if not result.is_empty() else "VWM"


func _game_manager() -> Node:
	if game_manager_override != null:
		return game_manager_override
	return get_node("/root/GameManager")
