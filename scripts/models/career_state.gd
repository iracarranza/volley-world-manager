class_name VolleyballCareerState
extends Resource

const Regions := preload("res://scripts/data/regions.gd")

@export var save_id: String = "career_1"
@export var career_name: String = "New Career"
@export var organization_name: String = "Harbor City VC"
@export_enum("Club", "Academy") var organization_type: String = "Club"
@export var region: String = "Landavol"
@export var identity: String = "Balanced"
@export var absolute_week: int = 1
@export var reputation: int = 10
@export var finances: int = 100000
@export var training_focus: String = "Team Practice"
@export var fixtures: Array[Resource] = []
@export var transfer_pool: Array[Resource] = []
@export var active_fixture_id: int = -1
@export var match_format: Resource

## Sixnet world-league state. Populated once at career creation
## (`SixnetLeague.ensure_bootstrapped()`) and updated at each season boundary
## inside `CareerManager.advance_week()`. Saves from before this feature
## existed load these as empty/zero, which `ensure_bootstrapped()` treats as
## "not yet set up" and lazily backfills -- no migration step needed.
@export var region_power: Dictionary = {}  ## region_name -> float (10-95)
@export var sixnet_slots: Dictionary = {}  ## "upper_1".."lower_4" -> region_name
## Per-region additive generation deltas from influence drift, layered on top
## of `PlayerGenerator`'s static `REGION_SPECIALTY`/`REGION_*_BIAS` consts,
## never replacing them. A region absent here (or present with an empty
## dict) generates identically to before this feature existed.
@export var region_overlay: Dictionary = {}
@export var sixnet_standings: Dictionary = {}  ## slot_id -> {wins, losses, sets_won, sets_lost}
@export var sixnet_season_start_week: int = 0


func to_dict() -> Dictionary:
	var fixture_data: Array[Dictionary] = []
	for fixture in fixtures:
		fixture_data.append(fixture.to_dict())
	var market_data: Array[Dictionary] = []
	for player in transfer_pool:
		market_data.append(player.to_dict())
	return {"save_id": save_id, "career_name": career_name,
		"organization_name": organization_name, "organization_type": organization_type,
		"region": region, "identity": identity, "absolute_week": absolute_week,
		"reputation": reputation, "finances": finances,
		"training_focus": training_focus, "fixtures": fixture_data,
		"transfer_pool": market_data, "active_fixture_id": active_fixture_id,
		"match_format": match_format.to_dict() if match_format != null else {},
		"region_power": region_power.duplicate(true),
		"sixnet_slots": sixnet_slots.duplicate(true),
		"region_overlay": region_overlay.duplicate(true),
		"sixnet_standings": sixnet_standings.duplicate(true),
		"sixnet_season_start_week": sixnet_season_start_week}


static func from_dict(data: Dictionary) -> VolleyballCareerState:
	var state := VolleyballCareerState.new()
	state.save_id = str(data.get("save_id", "career_1"))
	state.career_name = str(data.get("career_name", "New Career"))
	state.organization_name = str(data.get("organization_name", "Harbor City VC"))
	state.organization_type = str(data.get("organization_type", "Club"))
	state.region = Regions.canonical_name(str(data.get("region", "Landavol")))
	state.identity = str(data.get("identity", "Balanced"))
	state.absolute_week = maxi(int(data.get("absolute_week", 1)), 1)
	state.reputation = clampi(int(data.get("reputation", 10)), 0, 100)
	state.finances = int(data.get("finances", 100000))
	state.training_focus = str(data.get("training_focus", "Team Practice"))
	for fixture_data in data.get("fixtures", []):
		state.fixtures.append(VolleyballFixture.from_dict(fixture_data))
	for player_data in data.get("transfer_pool", []):
		state.transfer_pool.append(VolleyballPlayer.from_dict(player_data))
	state.active_fixture_id = int(data.get("active_fixture_id", -1))
	state.match_format = VolleyballMatchFormat.from_dict(data.get("match_format", {}))
	state.region_power = Dictionary(data.get("region_power", {})).duplicate(true)
	state.sixnet_slots = Dictionary(data.get("sixnet_slots", {})).duplicate(true)
	state.region_overlay = Dictionary(data.get("region_overlay", {})).duplicate(true)
	state.sixnet_standings = Dictionary(data.get("sixnet_standings", {})).duplicate(true)
	state.sixnet_season_start_week = maxi(int(data.get("sixnet_season_start_week", 0)), 0)
	return state
