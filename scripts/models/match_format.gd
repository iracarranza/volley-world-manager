class_name VolleyballMatchFormat
extends Resource

@export var format_name: String = "Best of 3"
@export_range(1, 7, 2) var best_of_sets: int = 3
@export_range(15, 35) var regular_set_target: int = 25
@export_range(15, 35) var deciding_set_target: int = 25
@export_range(1, 3) var win_by: int = 2


func sets_to_win() -> int:
	return floori(float(best_of_sets) / 2.0) + 1


func target_for_set(set_number: int) -> int:
	return deciding_set_target if set_number == best_of_sets else regular_set_target


func to_dict() -> Dictionary:
	return {"format_name": format_name, "best_of_sets": best_of_sets,
		"regular_set_target": regular_set_target,
		"deciding_set_target": deciding_set_target, "win_by": win_by}


static func from_dict(data: Dictionary) -> VolleyballMatchFormat:
	var format := VolleyballMatchFormat.new()
	format.format_name = str(data.get("format_name", "Best of 3"))
	format.best_of_sets = clampi(int(data.get("best_of_sets", 3)), 1, 7)
	format.regular_set_target = clampi(int(data.get("regular_set_target", 25)), 15, 35)
	format.deciding_set_target = clampi(int(data.get("deciding_set_target", 25)), 15, 35)
	format.win_by = clampi(int(data.get("win_by", 2)), 1, 3)
	return format
