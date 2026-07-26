class_name VolleyballFixture
extends Resource

@export var id: int = -1
@export var week: int = 1
@export var opponent_name: String = "Port Azure VC"
@export var competition_name: String = "Regional League"
@export var completed: bool = false
@export var home_sets: int = 0
@export var opponent_sets: int = 0


func result_text() -> String:
	return "%d–%d" % [home_sets, opponent_sets] if completed else "Scheduled"


func to_dict() -> Dictionary:
	return {"id": id, "week": week, "opponent_name": opponent_name,
		"competition_name": competition_name, "completed": completed,
		"home_sets": home_sets, "opponent_sets": opponent_sets}


static func from_dict(data: Dictionary) -> VolleyballFixture:
	var fixture := VolleyballFixture.new()
	fixture.id = int(data.get("id", -1))
	fixture.week = maxi(int(data.get("week", 1)), 1)
	fixture.opponent_name = str(data.get("opponent_name", "Port Azure VC"))
	fixture.competition_name = str(data.get("competition_name", "Regional League"))
	fixture.completed = bool(data.get("completed", false))
	fixture.home_sets = int(data.get("home_sets", 0))
	fixture.opponent_sets = int(data.get("opponent_sets", 0))
	return fixture
