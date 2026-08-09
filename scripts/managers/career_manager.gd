extends Node

const CareerStateModel := preload("res://scripts/models/career_state.gd")
const TeamModel := preload("res://scripts/models/team.gd")
const FixtureModel := preload("res://scripts/models/fixture.gd")
const MatchFormatModel := preload("res://scripts/models/match_format.gd")
const Generator := preload("res://scripts/systems/player_generator.gd")
const Training := preload("res://scripts/systems/training_system.gd")
const DailyScheduleSystem := preload("res://scripts/systems/daily_schedule_system.gd")
const Calendar := preload("res://scripts/data/calendar_rules.gd")
const SixnetLeague := preload("res://scripts/systems/sixnet_league.gd")
const WorldPopulation := preload("res://scripts/systems/world_population.gd")
const WorldAging := preload("res://scripts/systems/world_aging.gd")

signal career_changed
signal career_loaded
signal week_advanced(report: Dictionary)
signal transfer_pool_changed

const SAVE_DIRECTORY := "user://careers"
## Suffix marking a world-population sidecar. Save listing filters these out
## so they never show up as selectable careers.
const WORLD_FILE_SUFFIX := "__world"

var career: Resource
var last_training_report: Dictionary = {}
var game_manager_override: Node

## Every player in this career's world who is not on the managed roster.
## Generated once at career creation and persisted alongside the career in
## its own file, because it is megabytes of data that almost never changes
## while the career file itself is rewritten every week.
## Everyone in the world who is not on the managed roster.
##
## **Loaded on first use, not on career load.** Measured: a career's own file is
## 79 KB and parses in 4 ms, its state rebuilds in 6, and the game state in 8 --
## eighteen milliseconds for everything the player is about to look at. The world
## sidecar is 3,880 volis, and rebuilding them took **1.9 seconds of a 1.94 second
## load**, every time, before the journal could draw a single row.
##
## Nothing on the journal, the clipboard, the planner or the match centre reads
## this. It is the free-agent pool: scouting and transfers want it, and both are
## screens the player has to choose to open. So the file path is remembered at
## load and the work happens the first time somebody actually asks -- which for
## most sessions is never.
var _world_population: Array[VolleyballPlayer] = []
var _world_save_id: String = ""
var _world_loaded: bool = true

var world_population: Array[VolleyballPlayer]:
	get:
		if not _world_loaded:
			_world_loaded = true
			_read_world_population(_world_save_id)
		return _world_population
	set(value):
		## An outright assignment is an answer, so there is nothing left to defer.
		_world_loaded = true
		_world_population = value
var _world_dirty: bool = false
## What the last season's turnover did -- retirements, intake size, whether a
## golden generation arrived. Raw material for a news feed; kept in memory
## rather than saved, since it describes an event rather than a state.
var last_world_report: Dictionary = {}


func has_career() -> bool:
	return career != null


func create_career(
	career_name: String,
	organization_name: String,
	region: String,
	organization_type: String,
	identity: String,
	custom_principles: Dictionary = {},
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
	if custom_principles.is_empty():
		team.apply_identity(identity)
	else:
		team.apply_custom_identity(identity, custom_principles)
	state.identity = team.identity
	var starting_identity := VolleyballRegions.starting_identity_state(
		region, team.principles
	)
	team.tactical_familiarity = float(starting_identity.familiarity)
	team.cohesion = float(starting_identity.cohesion)
	team.regional_alignment = float(starting_identity.alignment)
	var error: String = _game_manager().configure_managed_team(team, generated)
	if not error.is_empty():
		return error
	state.fixtures = _starting_fixtures(region)
	## The world is built once, here, and then kept. The transfer market is a
	## slice taken out of it rather than a separate roll, so every player the
	## manager can sign is a real person from somewhere with a real place in
	## the world's talent distribution.
	var world_seed := seed_value + 991
	world_population = WorldPopulation.generate(
		world_seed, WorldPopulation.DEFAULT_POPULATION_SIZE, state.region_overlay
	)
	## Regional production strength reads the people this world actually made,
	## so Sixnet bootstrapping must happen after population generation rather
	## than sampling and discarding a synthetic academy roster.
	SixnetLeague.ensure_bootstrapped(state, world_population)
	## Golden years are recorded in the world's own calendar so the cadence
	## can carry forward as the career runs, rather than being re-derived
	## from ages that shift every season.
	for golden_age in WorldPopulation.golden_cohorts(world_seed):
		state.golden_birth_years.append(1 - int(golden_age))
	state.transfer_pool.assign(
		WorldPopulation.draw_market(world_population, 120, seed_value + 1777)
	)
	state.world_population_size = world_population.size() + state.transfer_pool.size()
	_world_dirty = true
	career = state
	last_training_report = {}
	save_career()
	career_changed.emit()
	career_loaded.emit()
	return ""


func calendar_state() -> Dictionary:
	return Calendar.state_for_week(int(career.absolute_week)) if career != null else {}


func date_text() -> String:
	if career == null:
		return "No career"
	return Calendar.display_date(
		int(career.absolute_week), int(career.day_of_week)
	)


## Is today the day the club holds its session, and has it been held?
##
## Two questions with one answer, because the only thing anybody wants to know
## is whether there is somewhere to be. A session that has already been attended
## this week is not somewhere to be.
func training_day_is_today() -> bool:
	if career == null:
		return false
	return int(career.day_of_week) == int(career.training_day) \
		and int(career.last_drilled_week) != int(career.absolute_week)


## Move the calendar on by one day, running the week when the week ends.
##
## The week is still the unit training is applied in -- a regimen is a week's
## work and pretending otherwise would mean re-deriving every load in the game --
## so this is a clock, and `advance_week` is still the thing that happens. What
## the day buys is a *place in the week*, which is what an appointment needs: you
## cannot turn up to a week.
func advance_day() -> String:
	if career == null:
		return "No active career."
	if training_day_is_today():
		return "The squad is on the floor today. Take the session or skip it."
	if int(career.day_of_week) < Calendar.DAYS_PER_WEEK:
		career.day_of_week += 1
		save_career()
		career_changed.emit()
		return ""
	var error := advance_week()
	if not error.is_empty():
		return error
	career.day_of_week = 1
	save_career()
	career_changed.emit()
	return ""


## Hold this week's session, on whatever the manager put it on.
##
## `focus` is a key out of the tactic sheet's own vocabulary rather than a
## string invented here, so what a manager drills is always something they
## actually drew. Skipping is a real choice and costs the focus rather than the
## session: the squad still trains, they simply train nothing in particular,
## which is what an unattended week has always silently been.
func hold_drill_session(focus: String = "") -> String:
	if career == null:
		return "No active career."
	if int(career.last_drilled_week) == int(career.absolute_week):
		return "This week's session has already been held."
	career.drill_focus = focus
	career.last_drilled_week = int(career.absolute_week)
	save_career()
	career_changed.emit()
	return ""


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


## The regimens this week runs, defaulting to the whole roster on one activity.
##
## A career with no regimens set is every career saved before squads existed and
## every new one before the manager opens the screen, so the default has to be
## the behaviour they already had rather than nobody training.
func active_regimens() -> Array:
	if career == null:
		return []
	if not career.training_regimens.is_empty():
		return career.training_regimens
	var default_regimen := TrainingRegimen.new()
	default_regimen.squad_name = "Full Squad"
	default_regimen.activity = career.training_focus
	default_regimen.focus = TrainingRegimen.Focus.MEDIUM
	for player in _game_manager().players:
		default_regimen.player_ids.append(int(player.id))
	return [default_regimen]


func set_training_focus(activity_name: String) -> String:
	if career == null:
		return "No active career."
	if activity_name not in Training.ACTIVITIES:
		return "Unknown training activity."
	career.training_focus = activity_name
	career_changed.emit()
	return ""


## Fatigue a week away from the court gives back, before that week's training
## charges its own cost on top.
##
## This has to exceed every training focus's fatigue cost or resting does not
## rest. At the previous 0.04 it exceeded none of them: the default Team
## Practice charges 0.05, so an untouched career gained 0.01 fatigue in a week
## it spent recovering, and only the explicit Recovery focus (-0.20) ever moved
## the number down. A match costs an on-court player roughly 0.60, so squads
## walked into their second fixture near exhaustion, and since `_rating()`
## applies a fatigue penalty at every stage of a swing, the compounded loss
## dragged the average attack below the error threshold -- almost every attack
## became an error, which is the bug this fixes.
##
## 0.40 is set against the fixture cadence rather than picked for feel: two
## weeks between fixtures at the default focus return enough even for the
## pathological case where one player pays the decisive cost on every rally. A
## squad that plays and trains normally holds steady, one that rests properly
## gains ground, and a congested run still wears players down. A regression
## check re-derives this against the training table and the rally cost, so
## re-tuning either without revisiting this fails loudly.
const WEEKLY_FATIGUE_RECOVERY: float = 0.40


func advance_week() -> String:
	if career == null:
		return "No active career."
	var fixture := next_fixture()
	if fixture != null and int(fixture.week) <= int(career.absolute_week) \
			and not bool(fixture.completed):
		return "Play the scheduled fixture before advancing the week."
	SixnetLeague.ensure_bootstrapped(career)
	## The day sets the training budget. A club that scheduled one session does
	## not get to run three regimens because the screen let them be typed in.
	var day: Dictionary = DailyScheduleSystem.evaluate(
		_game_manager().team.daily_schedule
	)
	last_training_report = Training.apply_week(
		active_regimens(), _game_manager().players, _game_manager().team,
		int(career.absolute_week),
		float(day.get("effective_training_blocks", 0.0)),
	)
	last_training_report["day"] = day
	## And the day pays the squad back: sleep and meals are what recovery is.
	var roster: Dictionary = DailyScheduleSystem.evaluate_roster(
		_game_manager().team.daily_schedule,
		_game_manager().team.personal_schedules,
		_game_manager().players.size(),
	)
	for player in _game_manager().players:
		player.fatigue = clampf(
			player.fatigue - float(day.get("recovery", 0.0)), 0.0, 1.0
		)
		var personal: Dictionary = Dictionary(roster.get("per_player", {})).get(
			player.id, {}
		)
		player.satisfaction = clampf(
			player.satisfaction + float(day.get("satisfaction", 0.0))
				+ float(personal.get("satisfaction", 0.0)),
			0.0, 1.0,
		)
	_game_manager().team.cohesion = clampf(
		float(_game_manager().team.cohesion) + float(roster.get("cohesion", 0.0)),
		0.0, 1.0,
	)
	last_training_report["roster_schedule"] = roster
	var pre_year: int = Calendar.state_for_week(career.absolute_week).year
	career.absolute_week += 1
	var post_year: int = Calendar.state_for_week(career.absolute_week).year
	if post_year != pre_year:
		SixnetLeague.resolve_season_boundary(career)
		## The world turns over once the season is settled: everyone ages and
		## redevelops, the players the pyramid has no room for leave, and a
		## new intake arrives. This is the only thing that makes the
		## population a history rather than a snapshot.
		_advance_world_year(post_year)
		var strength_population: Array = world_population.duplicate()
		strength_population.append_array(career.transfer_pool)
		strength_population.append_array(_game_manager().players)
		SixnetLeague.ensure_bootstrapped(career, strength_population)
	for player in _game_manager().players:
		## Weekly recovery must exceed every training load. The old 0.04 was
		## smaller than default Team Practice's 0.05, so an idle week made a
		## rested squad more tired and fixture-to-fixture fatigue only climbed.
		recover_weekly_fatigue(player)
		player.current_form *= 0.92
		## A week spent under your own eyes. The other half of scouting
		## confidence, and the half a scout cannot buy: `ScoutingSystem`
		## saturates this after about a season and a half, so it is free to
		## climb without bound.
		player.weeks_observed += 1
	for member in career.staff:
		member.weeks_employed += 1
	save_career()
	week_advanced.emit(last_training_report)
	career_changed.emit()
	return ""


static func recover_weekly_fatigue(player: VolleyballPlayer) -> void:
	if player != null:
		player.fatigue = maxf(player.fatigue - WEEKLY_FATIGUE_RECOVERY, 0.0)


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


## Base seed for a fixture's rallies, tied to this save and this fixture --
## not a fixed literal every match on every save shared, which is what let two
## different careers replay an identical scoreline for the same matchup.
func fixture_base_seed(fixture_id: int) -> int:
	return absi(hash("%s|fixture|%d" % [str(career.career_name), fixture_id]))


## Maximum rallies before giving up on a simulated match. A best-of-5 to 25
## (win by 2) runs nowhere near this in practice; it exists only to keep a
## genuine simulation bug from hanging rather than to bound a real match.
const MAX_SIMULATED_RALLIES: int = 1000


## Resolves an entire fixture in one batch -- an "instant result" rather than
## playing it out rally by rally, for a manager who wants the outcome without
## the live match screen. Uses the same rally simulator and the same
## save-specific seeding as a live match; only the playback is skipped.
func simulate_fixture(fixture_id: int) -> String:
	var error := prepare_fixture(fixture_id)
	if not error.is_empty():
		return error
	var manager := _game_manager()
	var base_seed := fixture_base_seed(fixture_id)
	var rallies := 0
	while not bool(manager.match_state.match_complete) and rallies < MAX_SIMULATED_RALLIES:
		var result: Resource = manager.resolve_active_rally(base_seed + rallies)
		manager.record_rally(result)
		rallies += 1
	if not bool(manager.match_state.match_complete):
		return "Match simulation did not resolve within the expected number of rallies."
	complete_active_match()
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
		_apply_player_match_outcomes(fixture.home_sets > fixture.opponent_sets)
	career.active_fixture_id = -1
	save_career()
	career_changed.emit()


func _apply_player_match_outcomes(won: bool) -> void:
	var manager := _game_manager()
	var player_statistics: Dictionary = manager.match_state.statistics.players
	for player in manager.players:
		var stats: Dictionary = player_statistics.get(str(player.id), {})
		var contacts := int(stats.get("contacts", 0))
		var appeared := contacts > 0
		var satisfaction_change := 0.01 if won else -0.008
		satisfaction_change += 0.005 if appeared else -0.004
		player.satisfaction = clampf(
			player.satisfaction + satisfaction_change, 0.0, 1.0
		)
		if appeared:
			var average_quality := float(stats.get("quality_total", 0.0)) \
				/ float(maxi(contacts, 1))
			var performance_signal := clampf(
				(average_quality - 0.52) / 0.28, -1.0, 1.0
			)
			player.current_form = clampf(
				lerpf(player.current_form, performance_signal, 0.35), -1.0, 1.0
			)
			var reputation_change := 2 if average_quality >= 0.75 \
				else (1 if average_quality >= 0.62 else 0)
			player.reputation = clampi(
				player.reputation + reputation_change, 1, 100
			)
		else:
			player.current_form *= 0.85
		player.match_confidence *= 0.35
	manager.team.cohesion = clampf(
		float(manager.team.cohesion) + (0.006 if won else -0.003), 0.0, 1.0
	)


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
	## A signed player belongs to the roster now, not to the world. Leaving
	## them in the population would write them into the world file as well
	## and reload as two copies of the same person.
	if world_population.has(candidate):
		world_population.erase(candidate)
		_world_dirty = true
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
	## A released player becomes part of the world rather than vanishing from
	## it: the transfer pool is written into the world file alongside the
	## population, so listing them here is enough for them to persist.
	career.transfer_pool.append(player)
	_world_dirty = true
	save_career()
	transfer_pool_changed.emit()
	career_changed.emit()
	return ""

func delete_save(save_id: String) -> String:
	var path := _save_path(save_id)
	if not FileAccess.file_exists(path): return "Career save not found."
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK: return "Could not delete the career save."
	var world_path := _world_path(save_id)
	if FileAccess.file_exists(world_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world_path))
	if career != null and str(career.save_id) == _safe_id(save_id):
		career = null
		world_population = [] as Array[VolleyballPlayer]
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
	## The population is only rewritten when it actually changed. It is
	## roughly two orders of magnitude larger than the career file, and the
	## career file is written on every single week advance.
	if _world_dirty:
		save_world_population()
	return ""


func save_world_population() -> String:
	if career == null:
		return "No active career."
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	var file := FileAccess.open(_world_path(career.save_id), FileAccess.WRITE)
	if file == null:
		return "Could not open the world population file."
	## Transfer-listed players are written here too, not in the career file.
	## The career only records their ids, so this file has to hold every
	## person those ids could point at -- the world plus its shop window.
	var everyone: Array[VolleyballPlayer] = world_population.duplicate()
	for listed in career.transfer_pool:
		everyone.append(listed as VolleyballPlayer)
	file.store_string(JSON.stringify({
		"save_version": 1, "players": WorldPopulation.to_dict_array(everyone),
	}))
	_world_dirty = false
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
	## Remembered rather than read -- see `world_population`.
	_world_population = [] as Array[VolleyballPlayer]
	_world_save_id = save_id
	_world_loaded = false
	_world_dirty = false
	career_loaded.emit()
	career_changed.emit()
	return ""


## Reads the sidecar and turns the career's transfer-listed ids back into
## player objects. A career saved before the world population existed has no
## sidecar and carries its market inline instead, which `CareerState` has
## already loaded by this point -- so that path simply leaves an empty world
## rather than failing.
func _read_world_population(save_id: String) -> void:
	_world_population = [] as Array[VolleyballPlayer]
	_world_dirty = false
	var file := FileAccess.open(_world_path(save_id), FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_world_population = WorldPopulation.from_dict_array(
				Array((parsed as Dictionary).get("players", []))
			)
	## Belt and braces: anyone already on the managed roster is not also a
	## free agent in the world, whatever the files happen to say.
	var rostered_ids := {}
	for player in _game_manager().players:
		rostered_ids[int(player.id)] = true
	var world_free_agents: Array[VolleyballPlayer] = []
	for player in _world_population:
		if not rostered_ids.has(int(player.id)):
			world_free_agents.append(player)
	_world_population = world_free_agents
	if career.transfer_pool_ids.is_empty():
		return
	var by_id := {}
	for player in _world_population:
		by_id[int(player.id)] = player
	var resolved: Array[VolleyballPlayer] = []
	for player_id in career.transfer_pool_ids:
		var player: VolleyballPlayer = by_id.get(int(player_id))
		if player != null:
			resolved.append(player)
			_world_population.erase(player)
	career.transfer_pool.assign(resolved)


func list_save_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(SAVE_DIRECTORY)
	if directory == null:
		return result
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		## World-population sidecars live in the same directory but are not
		## careers, so they must never appear in the save list.
		if file_name.ends_with(".json") \
				and not file_name.ends_with("%s.json" % WORLD_FILE_SUFFIX):
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
		"identity": career.identity,
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


func _world_path(save_id: String) -> String:
	return "%s/%s%s.json" % [SAVE_DIRECTORY, _safe_id(save_id), WORLD_FILE_SUFFIX]


## Turns the world over for one season, transfer market included.
##
## The market is merged back into the population for the duration, because a
## listed player is a person in the world like any other -- they should age,
## and they should be able to retire unsigned rather than sitting on the
## market forever at the same age. Afterwards the two are split apart again
## by the ids that were listed, minus anyone who did not survive.
func _advance_world_year(world_year: int) -> void:
	var listed_ids := {}
	var everyone: Array[VolleyballPlayer] = world_population.duplicate()
	for listed in career.transfer_pool:
		var player: VolleyballPlayer = listed as VolleyballPlayer
		if player == null:
			continue
		listed_ids[int(player.id)] = true
		everyone.append(player)

	last_world_report = WorldAging.advance_year(
		everyone, career, world_year,
		int(hash("%s|world|%d" % [str(career.career_name), world_year])),
	)

	var surviving_market: Array[VolleyballPlayer] = []
	var remaining: Array[VolleyballPlayer] = []
	for player in everyone:
		if listed_ids.has(int(player.id)):
			surviving_market.append(player)
		else:
			remaining.append(player)
	world_population = remaining
	career.transfer_pool.assign(surviving_market)
	_age_managed_roster()
	_world_dirty = true


## The managed roster ages too, but is deliberately *not* redeveloped from
## its ceilings the way world players are: these players have been trained,
## so recomputing them from age alone would silently delete every gain the
## manager earned. They get a year older, lose a little of what fades with
## age, and retire at the end of the same career span everyone else has.
func _age_managed_roster() -> void:
	var manager := _game_manager()
	for player_resource in manager.players.duplicate():
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		player.age += 1
		player.professional_experience = maxi(player.age - 20, 0)
		if player.age > WorldAging.FINAL_AGE:
			manager.clear_player_from_rotations(int(player.id))
			manager.set_player_starting(int(player.id), false)
			manager.unregister_player(int(player.id))
			continue
		if player.age <= Generator.PHYSICAL_PEAK_AGE:
			continue
		for property_name in Generator.PHYSICAL_ATTRIBUTES:
			player.set(property_name, maxi(int(player.get(property_name)) - 1, 1))


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
