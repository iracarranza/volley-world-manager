class_name VolleyballCareerState
extends Resource

const Regions := preload("res://scripts/data/regions.gd")
const StaffMember := preload("res://scripts/models/staff_member.gd")

@export var save_id: String = "career_1"
@export var career_name: String = "New Career"
@export var organization_name: String = "Harbor City VC"
## The seat, not the institution. "Academy" was a value here and the academy is
## now the region's selection body -- a thing you are chosen *by*, never a thing
## you manage. Both old values described a club, so both load as `Established`.
@export_enum("Established", "Founded") var organization_type: String = "Established"
@export var region: String = "Landavol"
@export var identity: String = "Balanced"
## ## Who the manager is
##
## A save described the organisation five ways and the manager not at all. Every
## screen here is an object on somebody's desk, and the interface has been
## drawing that person's handwriting for months without saying who they are.
## See `ManagerProfile` and `docs/design/CHARACTER_CREATION.md`.
##
## `manager_region` is where *you* are from, which is frequently not where you
## manage -- a Landavoli in Taktikã is a specific and interesting position, and
## it is the position most managers in a real league are in.
@export var manager_name: String = ""
@export var manager_region: String = "Landavol"
@export var manager_background: String = "played"
## Which hand holds the clipboard. The backlog's mirrored-clipboard entry has
## been waiting on a manager who has one.
@export_enum("right", "left") var manager_hand: String = "right"
## **And what the manager looks like**, which is a voli like any other.
##
## Body type, produce variety, colourway, coat, face, height and the two limb
## proportions, as `ManagerProfile.DEFAULT_APPEARANCE` describes them. Stored as
## one dictionary rather than as nine exports because it is one answer to one
## question and because every field in it is sanitised together on the way back
## in -- a save carrying a produce a later build dropped should open as a voli,
## not as nine separate migrations.
##
## `manager_hand` above stays where it is. It is not appearance: it decides which
## way the clipboard is mirrored, and a thing with a consequence does not belong
## in the bag of things without one.
@export var manager_appearance: Dictionary = {}
## What the club leases, and whether it owns it. Replaces Established/Founded at
## save generation, per ACCOMMODATIONS_AND_CARE §15: every club has new volis and
## old ones, and nobody starts by coaching a region's academy. A lease is a
## monthly cost, a floor budget and a sentence about who you are; a club type is
## a word the player never sees again.
@export var housing_structure: String = "Bunkhouse"
## What each voli has been eating, keyed by player id. See `FoodSupply`.
##
## On the career rather than on the manager that advances the week, which is
## where it started: a bare ivar is not saved, so every load handed the whole
## squad a fresh palate and the one quantity that is *supposed* to be a slow
## clock reset to zero every time the game was reopened. Nobody would have
## noticed from the numbers -- a reset palate reads as a well-fed squad.
@export var palate_clock: Dictionary = {}
## What each staff member has got good at. See `StaffFamiliarity`.
@export var staff_familiarity: Dictionary = {}
@export var absolute_week: int = 1
## Which day of that week it is, 1 for Monday.
##
## The week is still where training is *applied* -- a regimen is a week's work
## and always was -- but the calendar now moves a day at a time, because the
## manager has somewhere to be. Advancing past Sunday is what runs the week.
@export_range(1, 7) var day_of_week: int = 1
## The day the club holds the session the manager attends.
##
## One day, not seven. The squad trains all week; this is the day the manager is
## on the floor deciding what gets drilled, and the reason a focus is worth
## choosing at all is that it only happens once.
@export_range(1, 7) var training_day: int = 3
## What the manager put the session on, from the tactic sheet's own vocabulary.
## Empty when this week's session has not been held.
@export var drill_focus: String = ""
## Sessions attended, so a week cannot be drilled twice.
@export var last_drilled_week: int = 0
@export var reputation: int = 10
@export var finances: int = 100000
## The single squad-wide activity the club used to run. Kept because a career
## saved before regimens existed has one, and it seeds the default squad.
@export var training_focus: String = "Team Practice"
## What each training squad is doing this week. Empty means the whole roster
## trains together on `training_focus`, which is what every career did before
## squads existed.
@export var training_regimens: Array[TrainingRegimen] = []
## What the manager has marked each prospect as: sign, keep an eye on, seen
## enough. Keyed by player id.
##
## On the career rather than the scouting screen, because a note you have to
## re-make every time you open the page is not a note. It survives a save for the
## same reason a shortlist does.
@export var scouting_marks: Dictionary = {}
## Who you employ. Empty is a valid, meaningful state rather than an unset one:
## a club with no scout sees its own squad clearly and the transfer market as a
## fog, which is exactly what `ScoutingSystem` returns for a scout rating of 0.
@export var staff: Array[Resource] = []
@export var fixtures: Array[Resource] = []
@export var transfer_pool: Array[Resource] = []
@export var active_fixture_id: int = -1
@export var match_format: Resource

## Sixnet world-league state. Populated once at career creation
## (`SixnetLeague.ensure_bootstrapped()`) and updated at each season boundary
## inside `CareerManager.advance_week()`. Saves from before this feature
## existed load these as empty/zero, which `ensure_bootstrapped()` treats as
## "not yet set up" and lazily backfills -- no migration step needed.
## Academy production and current Sixnet results are deliberately separate.
## Saves written before the split carried both meanings in `region_power`;
## `from_dict()` seeds both new fields from that legacy value.
@export var region_strength: Dictionary = {}  ## region_name -> current population quality
@export var sixnet_form: Dictionary = {}  ## region_name -> competitive form (10-95)
@export var sixnet_slots: Dictionary = {}  ## "upper_1".."lower_4" -> region_name
## Per-region additive generation deltas from influence drift, layered on top
## of `PlayerGenerator`'s static `REGION_SPECIALTY`/`REGION_*_BIAS` consts,
## never replacing them. A region absent here (or present with an empty
## dict) generates identically to before this feature existed.
@export var region_overlay: Dictionary = {}
@export var sixnet_standings: Dictionary = {}  ## slot_id -> {wins, losses, sets_won, sets_lost}
## The two stages recorded separately as well as combined above: the
## qualifier decides who comes up, the championship decides who is champion,
## and promotion/relegation reads each stage against its own teams.
@export var sixnet_qualifier_standings: Dictionary = {}
@export var sixnet_championship_standings: Dictionary = {}
@export var sixnet_qualified_slots: Array[String] = []
@export var sixnet_champion_region: String = ""
@export var sixnet_season_start_week: int = 0

## How many players this career's world was generated with. Metadata only --
## the players themselves live in a sidecar file (`<save_id>__world.json`)
## rather than inside the career save, because the population is megabytes
## and almost never changes while the career file is rewritten every single
## week. `CareerManager` owns loading and saving it.
@export var world_population_size: int = 0

## Birth years that produced a golden generation, in this world's own
## calendar (career year 1 minus the player's age at world generation).
## Kept rather than re-derived so the cadence carries forward across a
## career instead of restarting: `WorldAging` extends this list one year at
## a time, respecting the same spacing rule that seeded it.
@export var golden_birth_years: Array[int] = []

## Transfer-listed players, serialized as ids into the world population so a
## player is never stored twice. `CareerManager` resolves these back into
## `transfer_pool` objects once the population file has loaded. Careers saved
## before the world population existed instead carry full player dictionaries
## under the legacy `transfer_pool` key, which still load.
@export var transfer_pool_ids: Array[int] = []


func to_dict() -> Dictionary:
	var fixture_data: Array[Dictionary] = []
	for fixture in fixtures:
		fixture_data.append(fixture.to_dict())
	var market_ids: Array[int] = []
	for player in transfer_pool:
		market_ids.append(int(player.id))
	var staff_data: Array[Dictionary] = []
	for member in staff:
		staff_data.append(member.to_dict())
	return {"save_id": save_id, "career_name": career_name,
		"staff": staff_data,
		"organization_name": organization_name, "organization_type": organization_type,
		"region": region, "identity": identity, "absolute_week": absolute_week,
		"manager_name": manager_name, "manager_region": manager_region,
		"manager_background": manager_background, "manager_hand": manager_hand,
		"manager_appearance": manager_appearance.duplicate(true),
		"housing_structure": housing_structure,
		"palate_clock": palate_clock.duplicate(true),
		"staff_familiarity": staff_familiarity.duplicate(true),
		"reputation": reputation, "finances": finances,
		"training_focus": training_focus,
		"training_regimens": _regimen_data(),
		"scouting_marks": scouting_marks.duplicate(true),
		"fixtures": fixture_data,
		"transfer_pool_ids": market_ids, "active_fixture_id": active_fixture_id,
		"match_format": match_format.to_dict() if match_format != null else {},
		"region_strength": region_strength.duplicate(true),
		"sixnet_form": sixnet_form.duplicate(true),
		"sixnet_slots": sixnet_slots.duplicate(true),
		"region_overlay": region_overlay.duplicate(true),
		"sixnet_standings": sixnet_standings.duplicate(true),
		"sixnet_qualifier_standings": sixnet_qualifier_standings.duplicate(true),
		"sixnet_championship_standings": sixnet_championship_standings.duplicate(true),
		"sixnet_qualified_slots": sixnet_qualified_slots.duplicate(),
		"sixnet_champion_region": sixnet_champion_region,
		"sixnet_season_start_week": sixnet_season_start_week,
		"world_population_size": world_population_size,
		"golden_birth_years": golden_birth_years.duplicate()}


static func from_dict(data: Dictionary) -> VolleyballCareerState:
	var state := VolleyballCareerState.new()
	state.save_id = str(data.get("save_id", "career_1"))
	state.career_name = str(data.get("career_name", "New Career"))
	state.organization_name = str(data.get("organization_name", "Harbor City VC"))
	## Migrated rather than read through. A save written before the recut says
	## `Club` or `Academy`, and both of them were clubs.
	var stored_type := str(data.get("organization_type", "Established"))
	state.organization_type = "Founded" if stored_type == "Founded" else "Established"
	state.region = Regions.canonical_name(str(data.get("region", "Landavol")))
	state.identity = str(data.get("identity", "Balanced"))
	state.manager_name = str(data.get("manager_name", ""))
	state.manager_region = str(data.get("manager_region", state.region))
	state.manager_background = str(data.get("manager_background", "played"))
	state.manager_hand = str(data.get("manager_hand", "right"))
	## Sanitised on the way in rather than trusted, for the reason above the
	## field: this is the one place an old save's body meets a newer table.
	state.manager_appearance = ManagerProfile.sanitise_appearance(
		Dictionary(data.get("manager_appearance", {}))
	)
	state.housing_structure = str(data.get("housing_structure", "Bunkhouse"))
	state.palate_clock = Dictionary(data.get("palate_clock", {})).duplicate(true)
	state.staff_familiarity = Dictionary(
		data.get("staff_familiarity", {})
	).duplicate(true)
	state.absolute_week = maxi(int(data.get("absolute_week", 1)), 1)
	state.reputation = clampi(int(data.get("reputation", 10)), 0, 100)
	state.finances = int(data.get("finances", 100000))
	state.training_focus = str(data.get("training_focus", "Team Practice"))
	for raw_key in Dictionary(data.get("scouting_marks", {})):
		state.scouting_marks[int(raw_key)] = int(
			data.scouting_marks[raw_key]
		)
	for regimen_data in data.get("training_regimens", []):
		state.training_regimens.append(
			TrainingRegimen.from_dict(Dictionary(regimen_data))
		)
	## Absent in every save written before staff existed, which loads as an
	## unstaffed club rather than needing a migration -- and an unstaffed club is
	## a state the systems already handle, because it is what a new career starts
	## as.
	for staff_data in data.get("staff", []):
		state.staff.append(StaffMember.from_dict(staff_data))
	for fixture_data in data.get("fixtures", []):
		state.fixtures.append(VolleyballFixture.from_dict(fixture_data))
	## Current saves list transfer-listed players by id and let
	## `CareerManager` resolve them out of the world population. Careers
	## written before the population existed inlined the whole player, so
	## those still load directly.
	for player_id in data.get("transfer_pool_ids", []):
		state.transfer_pool_ids.append(int(player_id))
	for player_data in data.get("transfer_pool", []):
		state.transfer_pool.append(VolleyballPlayer.from_dict(player_data))
	state.active_fixture_id = int(data.get("active_fixture_id", -1))
	state.match_format = VolleyballMatchFormat.from_dict(data.get("match_format", {}))
	var legacy_power := Dictionary(data.get("region_power", {})).duplicate(true)
	state.region_strength = Dictionary(
		data.get("region_strength", legacy_power)
	).duplicate(true)
	state.sixnet_form = Dictionary(data.get("sixnet_form", legacy_power)).duplicate(true)
	state.sixnet_slots = Dictionary(data.get("sixnet_slots", {})).duplicate(true)
	state.region_overlay = Dictionary(data.get("region_overlay", {})).duplicate(true)
	state.sixnet_standings = Dictionary(data.get("sixnet_standings", {})).duplicate(true)
	state.sixnet_qualifier_standings = Dictionary(
		data.get("sixnet_qualifier_standings", {})
	).duplicate(true)
	state.sixnet_championship_standings = Dictionary(
		data.get("sixnet_championship_standings", {})
	).duplicate(true)
	for slot_id in data.get("sixnet_qualified_slots", []):
		state.sixnet_qualified_slots.append(str(slot_id))
	state.sixnet_champion_region = str(data.get("sixnet_champion_region", ""))
	state.sixnet_season_start_week = maxi(int(data.get("sixnet_season_start_week", 0)), 0)
	state.world_population_size = maxi(int(data.get("world_population_size", 0)), 0)
	for birth_year in data.get("golden_birth_years", []):
		state.golden_birth_years.append(int(birth_year))
	return state


func _regimen_data() -> Array:
	var rows: Array = []
	for regimen in training_regimens:
		rows.append(regimen.to_dict())
	return rows
