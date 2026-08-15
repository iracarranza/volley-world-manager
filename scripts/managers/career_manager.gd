extends Node

const FatigueModel := preload("res://scripts/simulation/fatigue_model.gd")
const Accommodation := preload("res://scripts/data/accommodation.gd")
const FoodSupply := preload("res://scripts/data/food_supply.gd")
const RecruitOffer := preload("res://scripts/data/recruit_offer.gd")
const FoodBlock := preload("res://scripts/data/food_block.gd")
const PasteRatioModel := preload("res://scripts/data/paste_ratio.gd")
const StaffMemberModel := preload("res://scripts/models/staff_member.gd")

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
const StaffGen := preload("res://scripts/systems/staff_generator.gd")
const StaffFamiliar := preload("res://scripts/data/staff_familiarity.gd")

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


## What seat the manager took. `Academy` is a dead value: the academy is the
## region's selection body and is not a thing anybody manages. A save written
## before this migrates to `Established`, which is what both old options
## actually were.
const ESTABLISHED_CLUB: String = "Established"
const FOUNDED_CLUB: String = "Founded"


func create_career(
	career_name: String,
	organization_name: String,
	region: String,
	organization_type: String,
	identity: String,
	custom_principles: Dictionary = {},
	## Who the manager is: name, home region, background, hand and body. Optional
	## so every existing caller -- the suite's fixtures, the probes -- keeps
	## working and gets the defaults, which is what they had before there was a
	## manager at all.
	manager: Dictionary = {},
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
	## The manager's own region defaults to the club's, which is the common case
	## and never the interesting one. `CHARACTER_CREATION.md` wants the two to
	## differ often; the creator asks for one region today and this is the seam
	## where a second question would land.
	state.manager_name = str(manager.get("name", "")).strip_edges()
	state.manager_region = VolleyballRegions.canonical_name(
		str(manager.get("region", region))
	)
	state.manager_background = str(manager.get("background", "played"))
	state.manager_hand = "left" if str(manager.get("hand", "right")) == "left" \
		else "right"
	state.manager_appearance = ManagerProfile.sanitise_appearance(
		Dictionary(manager.get("appearance", {}))
	)
	## **The save's opening position is where you are, not what you are called.**
	##
	## This was `6/65,000` for an academy and `10/120,000` for a club -- two
	## clubs, an established one and a young one, under a word that now means the
	## regional selection body. `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3
	## recuts it as major region versus minor, and the seat you take inside it.
	##
	## A major region is where the resources are: established clubs with squads
	## and accommodation somebody already built. A minor one hands you the small
	## club and the difficulty that your best volis are watched by academies that
	## are not yours. Founding is the hard route and belongs where the resources
	## are -- from nothing, against clubs that have everything -- so it costs
	## standing and money rather than being what happens when you pick the
	## smaller region.
	var major := VolleyballRegions.is_major(region)
	var founded := organization_type == FOUNDED_CLUB
	state.reputation = (10 if major else 6) - (4 if founded else 0)
	state.finances = (120000 if major else 65000) - (45000 if founded else 0)
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
	## **The club already has staff, and until now it never did.** `career.staff`
	## was empty in every save ever played, which meant `ScoutingSystem` read a
	## scout rating of zero for the whole game and nothing said so.
	state.staff.assign(StaffGen.for_club(region, organization_type, seed_value + 313))
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
		## **Recovery is now what living here buys you.**
		##
		## `ACCOMMODATIONS_AND_CARE.md` §11: a dorm is still a dorm, so the floor
		## under this is high and nobody rests badly because of where they live.
		## What reduces it are *conditions* -- a crowded room, a table with
		## nothing familiar on it, being a long way from home with no way to call
		## -- and every one of those is answerable by something a manager
		## installs or arranges.
		##
		## This is the seam the whole accommodation design attaches to, and it
		## could not exist until a match cost something that survived the week.
		recover_weekly_fatigue(player, _weekly_recovery_share(player))
		_advance_weekly_palate(player)
		player.current_form *= 0.92
		## A week spent under your own eyes. The other half of scouting
		## confidence, and the half a scout cannot buy: `ScoutingSystem`
		## saturates this after about a season and a half, so it is free to
		## climb without bound.
		player.weeks_observed += 1
	## The chef gets a week better at whatever they cooked, and a week rustier at
	## whatever they did not. Both halves here, because a decay applied somewhere
	## else is a decay somebody forgets -- and a familiarity that only climbs
	## looks exactly like a chef who is learning.
	var kitchen_chef := _chef()
	if kitchen_chef != null:
		var served_now: Dictionary = _week_service(
			str(career.region), int(career.absolute_week)
		)
		StaffFamiliar.record_week(
			career.staff_familiarity, int(kitchen_chef.id),
			Dictionary(served_now.get("pastes", {})).keys()
		)
	## And the squad settles into wherever they were moved, a week at a time.
	var housed: Resource = _game_manager().team
	if housed != null and int(housed.housing_settling_weeks) > 0:
		housed.housing_settling_weeks -= 1
	for member in career.staff:
		member.weeks_employed += 1
	save_career()
	week_advanced.emit(last_training_report)
	career_changed.emit()
	return ""


static func recover_weekly_fatigue(
	player: VolleyballPlayer, share: float = 1.0
) -> void:
	if player != null:
		player.fatigue = maxf(
			player.fatigue - WEEKLY_FATIGUE_RECOVERY * share, 0.0
		)


## What share of a full week's recovery this voli actually banks.
func _weekly_recovery_share(player: VolleyballPlayer) -> float:
	var team: Resource = _game_manager().team
	if team == null or player == null:
		return 1.0
	## The club's region lives on the career, not the team -- the squad is the
	## people and the region is the address.
	var club_region := str(career.region) if career != null else str(player.club_region)
	var week := int(career.absolute_week) if career != null else 1
	## Against what the chef put on the block, not against the whole larder --
	## see `FoodSupply.served`. Measuring the larder made a supply line a penalty
	## for a squad that was already eating what it knew.
	var served: Dictionary = _week_service(club_region, week)
	var discomfort := FoodSupply.discomfort(player.palate_regions, served)
	var crowding := Accommodation.crowding(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		team.housing_small_equipment, team.housing_large_equipment,
	)
	return Accommodation.weekly_recovery_share(
		crowding,
		Accommodation.homesick(str(player.home_region), club_region),
		discomfort,
		FoodSupply.palate_of(_palate_clock(), int(player.id)),
		team.housing_small_equipment,
		int(team.housing_settling_weeks),
		str(team.food_block),
	)


## What is on the block this week, for whoever asks.
##
## One function so the weekly seam, the palate clock and every screen agree about
## what the squad is eating -- three callers deriving it separately is how the
## page ends up naming a different paste than the week charged for.
func _week_service(club_region: String, week: int) -> Dictionary:
	var team: Resource = _game_manager().team
	if team == null:
		return {}
	var table: Dictionary = FoodSupply.table(club_region, team.supply_lines, week)
	## **A painted block is served exactly.**
	##
	## §2's rule is that only manual instruction guarantees the ratio, and
	## painting the block *is* manual instruction -- a manager who stood at the
	## bench and spread the paste themselves has done the thing the rule is about.
	## So the chef's drift does not apply: there is nothing for them to
	## approximate, because the mix is already on the block in front of them.
	##
	## This is also what stops the two inputs contradicting each other. A preset
	## is a standing order the chef interprets; a painting is this week, done.
	## When both exist the painting wins, because it is the more recent and the
	## more specific instruction.
	var painted: PastePaint = PastePaint.from_dict(team.paste_canvas)
	var painted_shares: Dictionary = painted.shares()
	if not painted_shares.is_empty():
		return FoodSupply.served_exactly(table, painted_shares, week, painted.coverage())
	var chef := _chef()
	var known := 0.0
	if chef != null:
		for paste in Dictionary(team.paste_preset):
			known += StaffFamiliar.of(
				career.staff_familiarity, int(chef.id), str(paste)
			)
		known = known / maxf(float(Dictionary(team.paste_preset).size()), 1.0)
	return FoodSupply.served(
		table, FoodBlock.paste_slots(chef_rating()), week,
		team.paste_preset, chef_rating(),
		known if known > 0.0 else StaffFamiliar.BASELINE
	)


## How good the chef is, which until this week nothing could read: no career had
## any staff at all. §1's paste ceiling is the first job the rating has.
func chef_rating() -> int:
	var member := _chef()
	return int(member.rating) if member != null else 0


func _chef() -> Resource:
	if career == null:
		return null
	for entry in career.staff:
		var member := entry as VolleyballStaffMember
		if member != null and str(member.role) == StaffMemberModel.ROLE_CHEF:
			return member
	return null


## One paste per week, rotated by the chef, and one palate figure per voli.
##
## The chef rotates through whatever the table has rather than repeating -- a
## manager who has given them three pastes gets three weeks before anything
## repeats, which is `FoodSupply`'s own rule that rotating is the fix.
##
## It lives on the career rather than here. It was an ivar on the manager, which
## is not saved, so a palate reset to zero every time the game was reopened --
## invisible in the numbers, because a reset palate looks exactly like a squad
## that has been fed well.
func _palate_clock() -> Dictionary:
	return career.palate_clock if career != null else {}


func _advance_weekly_palate(player: VolleyballPlayer) -> void:
	var team: Resource = _game_manager().team
	if team == null or player == null:
		return
	## The club's region lives on the career, not the team -- the squad is the
	## people and the region is the address.
	var club_region := str(career.region) if career != null else str(player.club_region)
	var week := int(career.absolute_week) if career != null else 1
	var served: Dictionary = _week_service(club_region, week)
	## Keyed on the **mix**, per §2 -- a voli tires of this week's blend rather
	## than of one ingredient in it, which is what makes varying the ratio a real
	## answer and rotating pastes entirely a stronger one.
	var serving := PasteRatioModel.key(Dictionary(served.get("ratio", {})))
	## Blan'deral is the reset block: §1 makes it the one thing palate fatigue
	## does not accumulate on, which is the week a manager spends to make the
	## next paste land again.
	if FoodBlock.resets_palate(str(team.food_block)):
		serving = ""
	FoodSupply.advance_palate(_palate_clock(), int(player.id), serving)
	## And a week of eating somebody else's food widens a palate, which is the
	## ceiling in §17 doing its job: comfortable is not the same as learning.
	if FoodSupply.widens_palate(player.palate_regions, served):
		FoodSupply.learn_region(player.palate_regions, club_region)


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
	## Point the match at the club on the calendar. Without this the fixture's
	## name was decoration: every match of every season was played against the
	## default squad, whatever the schedule said. Guarded on a named region so a
	## save written before fixtures carried one keeps the opponent it had.
	if not str(fixture.opponent_region).is_empty():
		_game_manager().set_opponent_region(
			str(fixture.opponent_region), int(fixture.opponent_club_index)
		)
		## Read back rather than assumed. `club_name` falls back to "<Region> VC"
		## for a region with no clubs listed, and a fixture whose printed name
		## disagreed with the squad across the net is the exact defect this is
		## fixing.
		fixture.opponent_name = str(_game_manager().opponent_team.team_name)
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
		## The figures, kept. Every one of these was already counted rally by
		## rally and then dropped here; see `VolleyballFixture.home_statistics`.
		var match_statistics: Resource = _game_manager().match_state.statistics
		if match_statistics != null:
			fixture.home_statistics = match_statistics.home.duplicate(true)
			fixture.opponent_statistics = match_statistics.opponent.duplicate(true)
			fixture.player_statistics = match_statistics.players.duplicate(true)
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
	## Who was actually on court, for the pair table below. Read off contacts
	## rather than off the lineup, because the lineup is who was *picked* and a
	## pair does not learn anything about each other from the bench.
	var _played_together: Array[int] = []
	for player in manager.players:
		var stats: Dictionary = player_statistics.get(str(player.id), {})
		var contacts := int(stats.get("contacts", 0))
		var appeared := contacts > 0
		if appeared:
			_played_together.append(int(player.id))
			## **A match has to cost something, and it was costing nothing.**
			##
			## `WEEKLY_FATIGUE_RECOVERY` is 0.40 and its own note says "a match
			## costs an on-court player roughly 0.60" -- but that cost was only
			## ever charged during live playback. A career that simulates its
			## fixtures, which is every career, charged nothing at all.
			##
			## Measured before this line existed: 300 weekly readings of every
			## voli's fatigue across 30 weeks came back **0.000 at every
			## percentile**, peak 0.014, against a `LABOURED_ONSET` of 0.34. The
			## three-stage fatigue model was unreachable between matches, and
			## every design resting on it -- the table, the dorms, the care row
			## in `ACCOMMODATIONS_AND_CARE.md` -- was a multiplier on a number
			## that was always already zero.
			##
			## Scaled by involvement rather than flat, because a libero who
			## touched the ball ninety times did not have the same afternoon as
			## an opposite who came on for one rotation, and divided by the
			## voli's own regional resistance, which `VolleyballRegions` has
			## carried since F2 and which nothing outside a live rally read.
			player.fatigue = clampf(
				player.fatigue + FatigueModel.match_cost(
					contacts, VolleyballRegions.fatigue_resistance(
						str(player.home_region)
					)
				),
				0.0, 1.0,
			)
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
	## **The pair table, updated once per match rather than per rally.**
	##
	## A relationship is built over matches, not over contacts: two volis who
	## happened to touch the ball forty times in one five-setter have not learned
	## more about each other than a pair who played four tidy matches. Rate, not
	## event -- see `PairFamiliarity`.
	if manager.team != null:
		PairFamiliarity.record_match(
			manager.team.pair_familiarity, _played_together
		)



## Offer a place to a voli, and say what was offered.
##
## ## Why this is a function and not a button
##
## The board's route onto the roster used to be `sign_transfer` reached from the
## transfers tab: one click, free, and the voli had no say and no bed checked.
## Recruiting somebody here is asking them to join a household as well as a side,
## so the thing that happens has to name the household.
##
## It returns the terms rather than storing them. Nothing reads a stored offer
## yet, and a record nothing reads is `FAILURE_MODES.md` §0 at schema altitude --
## so the room and the table are computed for the sentence the manager is told,
## which is a read, and recomputed whenever anybody asks again.
##
## **This is the seam.** When the interview exists it wraps this call and charges
## the manager's time for it; when a voli gets a say, the refusal happens here.
## Neither needs the screen rebuilt, which is the whole reason the transaction is
## one named function instead of a handler on a panel.
func offer_place(player_id: int) -> Dictionary:
	if career == null:
		return {"error": "No active career."}
	var team: Resource = _game_manager().team
	var squad: Array = _game_manager().players
	var room := RecruitOffer.proposed_room(
		str(team.housing_structure), int(team.housing_occupants_per_room),
		squad.size(), team.housing_small_equipment, team.housing_large_equipment,
	)
	var error := sign_transfer(player_id)
	if not error.is_empty():
		return {"error": error}
	var signed := _game_manager().player_by_id(player_id) as VolleyballPlayer
	var service: Dictionary = _week_service(
		str(career.region), int(career.absolute_week)
	)
	return {
		"error": "",
		"name": str(signed.display_name) if signed != null else "",
		"room": room,
		"table": RecruitOffer.table_word(
			Array(signed.palate_regions) if signed != null else [], service
		),
	}


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
	result.sort_custom(newest_first)
	return result


## Most recently saved first.
##
## Lifted out of the `sort_custom` lambda it used to be because the title
## screen's continue card now depends on it: that card opens
## `list_save_metadata()[0]` rather than carrying a "last played" field of its
## own, so this ordering is load-bearing and belongs somewhere the suite can
## assert it. A save written before `last_saved_unix` existed reads as 0 and
## sorts to the back, which is the direction that matters -- an absent
## timestamp must never present itself as the newest one.
static func newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("last_saved_unix", 0)) > int(b.get("last_saved_unix", 0))


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


## The first three matches, against clubs that exist.
##
## They used to be Port Azure VC, "<Region> Select" and Northbridge Volley --
## three names belonging to no region, matching no entry in
## `VolleyballRegions.CLUB_NAMES`, and, because `prepare_fixture` never passed
## them on, all three were played against the same default squad. A calendar of
## opponents you cannot look up and do not actually face is not a calendar.
##
## Two derbies then a trip out of the region: a new club's first season should
## start against the people it shares a region with, since that is who it is
## competing with for the Academy's attention, and the away fixture is what tells
## a manager that other regions play differently at all.
func _starting_fixtures(region: String) -> Array[Resource]:
	var home_region := VolleyballRegions.canonical_name(region)
	var neighbours: Array = VolleyballRegions.REGION_ADJACENCY.get(home_region, [])
	var away_region: String = str(neighbours[0]) if not neighbours.is_empty() \
		else home_region
	## **A region with one club cannot supply two fixtures.**
	##
	## This took club 0 and club 1 of the home region, and `club_name` wraps its
	## index -- so for any of the six minor regions, which field exactly one club,
	## weeks 2 and 4 were the *same* opponent, and that opponent was also the club
	## you had just taken over. Invisible while only the eight majors were
	## manageable, and produced the moment minors became a starting position: two
	## changes each correct on their own.
	##
	## Built by asking the region what it actually has rather than assuming two.
	## A second home club if there is one, and the neighbour otherwise -- which
	## is also the better fixture, because a minor region's difficulty is that
	## the interesting volleyball is somewhere else.
	var home_clubs := VolleyballRegions.clubs_in(home_region).size()
	var opponents := [{"region": home_region, "club": 0}]
	if home_clubs > 1:
		opponents.append({"region": home_region, "club": 1})
	else:
		opponents.append({"region": away_region, "club": 0})
	opponents.append({
		"region": away_region,
		"club": mini(1, VolleyballRegions.clubs_in(away_region).size() - 1),
	})
	var result: Array[Resource] = []
	for index in range(opponents.size()):
		var opponent: Dictionary = opponents[index]
		var opponent_region := str(opponent["region"])
		var club_index := int(opponent["club"])
		var fixture: Resource = FixtureModel.new()
		fixture.id = index + 1
		fixture.week = (index + 1) * 2
		fixture.opponent_region = opponent_region
		fixture.opponent_club_index = club_index
		fixture.opponent_name = VolleyballRegions.club_name(opponent_region, club_index)
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
