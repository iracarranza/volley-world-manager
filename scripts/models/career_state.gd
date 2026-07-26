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
		"match_format": match_format.to_dict() if match_format != null else {}}


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
	return state
