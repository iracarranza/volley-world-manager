class_name ActionOpportunityWindow
extends RefCounted

var action_type: StringName = &""
var side: StringName = &""
var player_id: int = -1
var opened_at: float = 0.0
var closed_at: float = -1.0
var contact_time: float = 0.0
var open_reason: StringName = &""
var close_reason: StringName = &""
var best_arrival_margin: float = -INF
var samples: Array[Dictionary] = []


static func create(
	kind: StringName,
	window_side: StringName,
	actor_id: int,
	open_time: float,
	ball_contact_time: float,
	reason: StringName,
) -> ActionOpportunityWindow:
	var window := ActionOpportunityWindow.new()
	window.action_type = kind
	window.side = window_side
	window.player_id = actor_id
	window.opened_at = open_time
	window.contact_time = ball_contact_time
	window.open_reason = reason
	return window


func record_sample(sample: Dictionary) -> void:
	samples.append(sample.duplicate(true))
	best_arrival_margin = maxf(
		best_arrival_margin, float(sample.get("arrival_margin", -INF))
	)


func close(at_time: float, reason: StringName) -> void:
	if closed_at >= 0.0:
		return
	closed_at = maxf(at_time, opened_at)
	close_reason = reason


func is_open() -> bool:
	return closed_at < 0.0


func duration() -> float:
	var end_time := contact_time if is_open() else closed_at
	return maxf(end_time - opened_at, 0.0)


func to_dict() -> Dictionary:
	return {
		"action_type": String(action_type),
		"side": String(side),
		"player_id": player_id,
		"opened_at": opened_at,
		"closed_at": closed_at,
		"contact_time": contact_time,
		"duration": duration(),
		"open_reason": String(open_reason),
		"close_reason": String(close_reason),
		"best_arrival_margin": best_arrival_margin,
		"samples": samples.duplicate(true),
	}
