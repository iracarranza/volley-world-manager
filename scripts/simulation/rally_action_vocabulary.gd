class_name RallyActionVocabulary
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")


## Names outcomes from situation plus delivery. The result is written on the
## event once and then shared by captions, cognition, and later statistics.
static func annotate(result: Resource) -> void:
	if result == null:
		return
	for index in range(result.events.size()):
		var event: Resource = result.events[index]
		var classification := classify(result, index)
		event.metadata["action_outcome"] = str(classification.name)
		event.metadata["action_notability"] = float(classification.notability)
		event.metadata["named_action"] = bool(classification.named)


static func classify(result: Resource, index: int) -> Dictionary:
	var event: Resource = result.events[index] if result != null \
		and index >= 0 and index < result.events.size() else null
	if event == null:
		return _result("", 0.0, false)
	var previous := _previous_contact(result.events, index)
	var next := _next_contact(result.events, index)
	var event_type := int(event.event_type)
	match event_type:
		RallyEventModel.EventType.SERVE:
			if str(result.terminal_outcome) == "ace":
				return _result("Ace", 1.0, true)
			if not bool(event.success):
				return _result("Missed serve", 0.82, true)
			if next != null and int(next.event_type) == RallyEventModel.EventType.RECEPTION \
					and float(next.quality) < 0.45:
				return _result("Service pressure", 0.68, true)
			return _result("Serve in", 0.25, false)
		RallyEventModel.EventType.RECEPTION:
			var reception_margin := float(event.metadata.get("arrival_margin", 0.2))
			if float(event.quality) >= 0.74 and reception_margin <= 0.12:
				return _result("Platform dime", 0.88, true)
			if float(event.quality) < 0.25 and reception_margin >= 0.18:
				return _result("Shank", 0.84, true)
			if bool(event.success) and reception_margin < 0.0:
				return _result("Scramble pass", 0.72, true)
			return _result("Pass controlled" if bool(event.success) else "Reception lost", 0.35, false)
		RallyEventModel.EventType.SET_DECISION:
			return _result("Option chosen", 0.34, false)
		RallyEventModel.EventType.SET:
			var following_block := _next_type(result.events, index, RallyEventModel.EventType.BLOCK)
			var prior_quality := float(previous.quality) if previous != null else 0.5
			if bool(event.success) and float(event.quality) >= 0.72 \
					and following_block != null \
					and float(following_block.metadata.get("primary_close", 1.0)) < 0.48:
				return _result("Dime", 0.90, true)
			if bool(event.success) and prior_quality < 0.42 and float(event.quality) >= 0.56:
				return _result("Save set", 0.75, true)
			if following_block != null and float(following_block.metadata.get(
					"primary_close", 0.0)) >= 0.88:
				return _result("Telegraphed", 0.74, true)
			return _result("Set delivered" if bool(event.success) else "Set missed", 0.34, false)
		RallyEventModel.EventType.ATTACK:
			var attack_block := _next_type(result.events, index, RallyEventModel.EventType.BLOCK)
			var attack_side_won := _side_won(result, str(event.metadata.get("side", "home")))
			var block_outcome := str(attack_block.metadata.get("outcome", "")) \
				if attack_block != null else ""
			if attack_side_won and block_outcome in ["touch", "funnel", "recycle"]:
				return _result("Tool off the block", 1.0, true)
			if block_outcome == "stuff":
				return _result("Swung into the block", 0.90, true)
			if attack_side_won:
				var attack_type := str(event.metadata.get("attack_type", ""))
				var direction := str(event.metadata.get("attack_direction", ""))
				if attack_type in ["Roll shot", "Tip", "Short tip", "Emergency tip"]:
					return _result(attack_type, 0.76, true)
				if direction == "line":
					return _result("Line shot", 0.78, true)
				if direction == "seam":
					return _result("Seam kill", 0.80, true)
				if direction == "cross-court" and float(event.quality) >= 0.70:
					return _result("Cross-court bullet", 0.84, true)
			if not bool(event.success) or bool(event.metadata.get("attack_missed", false)):
				return _result("Attack error", 0.76, false)
			return _result("Swing continued", 0.30, false)
		RallyEventModel.EventType.BLOCK:
			var outcome := str(event.metadata.get("outcome", "miss"))
			var block_side_won := _side_won(result, str(event.metadata.get("side", "home")))
			if outcome == "stuff":
				return _result("Roof", 1.0, true)
			if outcome in ["touch", "funnel", "recycle"] and not block_side_won:
				return _result("Got tooled", 0.96, true)
			if outcome == "funnel" and next != null \
					and int(next.event_type) == RallyEventModel.EventType.DEFENSE \
					and bool(next.success):
				return _result("Funnel", 0.78, true)
			if outcome == "touch" and next != null \
					and int(next.event_type) == RallyEventModel.EventType.DEFENSE \
					and bool(next.success):
				return _result("Soft block", 0.80, true)
			if outcome == "miss" and float(event.metadata.get("primary_close", 1.0)) < 0.35:
				return _result("Beaten by tempo", 0.70, true)
			return _result("Block formed", 0.32, false)
		RallyEventModel.EventType.DEFENSE:
			var defense_margin := float(event.metadata.get("arrival_margin", 0.2))
			if bool(event.success) and defense_margin < 0.0:
				return _result("Sprawl dig", 0.86, true)
			if bool(event.success) and str(event.metadata.get("coverage", "")) == "attack":
				return _result("Cover", 0.72, true)
			if not bool(event.success) and defense_margin > 0.24:
				return _result("Missed the easy one", 0.82, true)
			return _result("Dig controlled" if bool(event.success) else "Defense beaten", 0.36, false)
		RallyEventModel.EventType.POINT:
			return _result("Point won" if bool(result.home_team_won) else "Point lost", 0.55, false)
	return _result(event.type_name(), 0.2, false)


static func _result(name: String, notability: float, named: bool) -> Dictionary:
	return {"name": name, "notability": clampf(notability, 0.0, 1.0), "named": named}


static func _side_won(result: Resource, side: String) -> bool:
	return bool(result.home_team_won) if side == "home" else not bool(result.home_team_won)


static func _previous_contact(events: Array, index: int) -> Resource:
	for candidate_index in range(index - 1, -1, -1):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) != RallyEventModel.EventType.SET_DECISION \
				and int(candidate.event_type) != RallyEventModel.EventType.POINT:
			return candidate
	return null


static func _next_contact(events: Array, index: int) -> Resource:
	for candidate_index in range(index + 1, events.size()):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) != RallyEventModel.EventType.SET_DECISION \
				and int(candidate.event_type) != RallyEventModel.EventType.POINT:
			return candidate
	return null


static func _next_type(events: Array, index: int, event_type: int) -> Resource:
	for candidate_index in range(index + 1, events.size()):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) == event_type:
			return candidate
		if int(candidate.event_type) == RallyEventModel.EventType.POINT:
			break
	return null
