class_name RallyCommentaryRouter
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const CommentaryLines := preload("res://scripts/data/rally_commentary_lines.gd")

const STATUS_PBP: StringName = &"pbp"
const STATUS_ANALYST: StringName = &"analyst"
const STATUS_OPTIONAL: StringName = &"optional_often_silent"
const STATUS_UI: StringName = &"ui_diagnostic"
const STATUS_SUPPRESSED: StringName = &"suppressed"

const DENSE_RALLY_CONTACTS: int = 8
const DENSE_RALLY_OPTIONAL_CUTOFF: int = 6


static func route(result: Resource) -> void:
	if result == null:
		return
	var final_contact := _final_contact_index(result.events)
	var contact_count := _contact_count(result.events)
	var contact_ordinal := 0
	var analyst_candidates: Array[Dictionary] = []
	for index in range(result.events.size()):
		var event: Resource = result.events[index]
		if event == null:
			continue
		_reset_commentary(event)
		event.physical_event_id = StringName("contact_%d" % int(event.sequence))
		event.event_subtype = StringName(_event_subtype(result, index))
		event.dedupe_group = StringName(_dedupe_group(result.events, index))
		event.diagnostics = _diagnostics(event)
		var is_contact := int(event.event_type) not in [
			RallyEventModel.EventType.SET_DECISION,
			RallyEventModel.EventType.POINT,
		]
		if is_contact:
			contact_ordinal += 1
		var pbp_key := _pbp_key(result, index, final_contact)
		var required := _pbp_required(result, index, final_contact, pbp_key)
		var optional := not required and _pbp_optional(event, pbp_key)
		var dense_silence := contact_count >= DENSE_RALLY_CONTACTS \
			and contact_ordinal > DENSE_RALLY_OPTIONAL_CUTOFF \
			and not required and not bool(event.metadata.get("named_action", false))
		if not pbp_key.is_empty() and (required or optional) and not dense_silence:
			event.commentary_headline = CommentaryLines.pbp(
				pbp_key, _line_values(result, index)
			)
			event.commentary_status = STATUS_PBP if required else STATUS_OPTIONAL
			event.commentary_silent = event.commentary_headline.is_empty()
		elif int(event.event_type) == RallyEventModel.EventType.POINT:
			event.commentary_status = STATUS_SUPPRESSED
		else:
			event.commentary_status = STATUS_OPTIONAL if is_contact else STATUS_UI
		var evidence := _analyst_evidence(result, index)
		event.analyst_evidence.assign(evidence)
		for item in evidence:
			var candidate := item.duplicate(true)
			candidate["event_index"] = index
			analyst_candidates.append(candidate)
	_dedupe_physical_groups(result.events)
	_select_analyst(result, analyst_candidates)
	result.commentary_headline = "Point won." if bool(result.home_team_won) \
		else "Point lost."
	result.commentary_diagnostics.assign(_result_diagnostics(result))


static func _reset_commentary(event: Resource) -> void:
	event.commentary_status = STATUS_UI
	event.commentary_headline = ""
	event.commentary_detail = ""
	event.commentary_silent = true
	event.analyst_evidence.clear()
	event.diagnostics.clear()


static func _event_subtype(result: Resource, index: int) -> String:
	var event: Resource = result.events[index]
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			if bool(event.success):
				return "in_play"
			var serve_reason := str(event.metadata.get("serve_out_reason", ""))
			return "error_%s" % serve_reason if serve_reason in ["net", "long", "wide"] \
				else "error_other"
		RallyEventModel.EventType.RECEPTION:
			if str(result.terminal_outcome) == "ace" and not bool(event.success):
				return "ace"
			if bool(event.metadata.get("seam_conflict", false)):
				return "seam_conflict"
			if bool(event.success) and float(event.metadata.get("arrival_margin", 0.1)) < 0.0:
				return "scramble"
			if float(event.quality) >= 0.72:
				return "excellent"
			if float(event.quality) < 0.42 or not bool(event.success):
				return "poor"
			return "routine"
		RallyEventModel.EventType.SET_DECISION:
			return "emergency_decision" if bool(event.metadata.get("emergency_setter", false)) \
				else "tactical_decision"
		RallyEventModel.EventType.SET:
			var action := str(event.metadata.get("action_outcome", ""))
			if bool(event.metadata.get("emergency_setter", false)):
				return "emergency_second_contact"
			if action == "Save set":
				return "save"
			if action == "Perfect set":
				return "excellent"
			if action == "Predictable set":
				return "predictable"
			return "routine"
		RallyEventModel.EventType.ATTACK:
			if bool(event.metadata.get("set_path_whiff", false)):
				return "error_whiff_unvalidated"
			var attack_type := str(event.metadata.get("attack_type", "")).to_lower()
			if "emergency tip" in attack_type:
				return "emergency_tip"
			if "tip" in attack_type:
				return "tip"
			if "roll" in attack_type:
				return "roll"
			if not bool(event.success) or bool(event.metadata.get("attack_missed", false)):
				var reason := str(event.metadata.get("geometric_out_reason", ""))
				return "error_%s" % reason if reason in ["net", "long", "wide", "antenna"] \
					else "error_other"
			var direction := str(event.metadata.get("attack_direction", ""))
			return "attack_%s" % direction.replace("-", "_") if not direction.is_empty() \
				else "attack_generic"
		RallyEventModel.EventType.BLOCK:
			return str(event.metadata.get("outcome", "miss"))
		RallyEventModel.EventType.DIG:
			if bool(event.success) and float(event.metadata.get("arrival_margin", 0.1)) < 0.0:
				return "diving_save"
			if not bool(event.success) and float(event.metadata.get("arrival_margin", 0.0)) > 0.24:
				return "easy_miss"
			return "controlled" if bool(event.success) else "beaten"
		RallyEventModel.EventType.ATTACK_COVERAGE:
			return "controlled" if bool(event.success) else "lost"
		RallyEventModel.EventType.POINT:
			return "home" if bool(result.home_team_won) else "opponent"
	return "other"


static func _pbp_key(result: Resource, index: int, final_contact: int) -> String:
	var event: Resource = result.events[index]
	var subtype := str(event.event_subtype)
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			match subtype:
				"error_net": return "serve_net"
				"error_long": return "serve_long"
				"error_wide": return "serve_wide"
				"error_other": return "serve_error"
			return "serve_in"
		RallyEventModel.EventType.RECEPTION:
			match subtype:
				"ace": return "ace"
				"seam_conflict": return "pass_seam"
				"scramble": return "pass_scramble"
				"excellent": return "pass_good"
				"poor": return "pass_trouble"
		RallyEventModel.EventType.SET:
			match subtype:
				"emergency_second_contact": return "emergency_set"
				"save": return "save_set"
				"excellent": return "perfect_set"
				"predictable": return ""
			return "set"
		RallyEventModel.EventType.ATTACK:
			if subtype == "error_whiff_unvalidated":
				return ""
			if subtype == "emergency_tip":
				return "emergency_tip"
			if not bool(event.success) or bool(event.metadata.get("attack_missed", false)):
				match subtype:
					"error_net": return "attack_net"
					"error_long": return "attack_long"
					"error_wide": return "attack_wide"
					"error_antenna": return "attack_antenna"
				return "attack_error"
			var block := _next_type(result.events, index, RallyEventModel.EventType.BLOCK)
			var block_outcome := str(block.metadata.get("outcome", "")) if block != null else ""
			if block_outcome == "tool":
				return "kill_tool"
			if block_outcome == "touch" and _event_side_won(result, event):
				return "off_block"
			if _event_side_won(result, event) or index == final_contact:
				if subtype == "tip": return "kill_tip"
				if subtype == "roll": return "kill_roll"
				if subtype == "attack_line": return "kill_line"
				if subtype == "attack_cross_court": return "kill_cross"
				if subtype == "attack_seam": return "kill_seam"
				return "kill"
			return "attack"
		RallyEventModel.EventType.BLOCK:
			if subtype == "stuff": return "block_stuff"
			if subtype == "touch": return "block_touch"
		RallyEventModel.EventType.DIG:
			if subtype == "diving_save": return "diving_save"
			if subtype == "easy_miss": return "easy_miss"
			if subtype == "beaten": return "defense_beaten"
			return "dig"
		RallyEventModel.EventType.ATTACK_COVERAGE:
			if bool(event.success): return "coverage"
	return ""


static func _pbp_required(
	result: Resource, index: int, final_contact: int, key: String
) -> bool:
	if key.is_empty():
		return false
	var event: Resource = result.events[index]
	if index == final_contact:
		return true
	if not bool(event.success):
		return true
	if str(event.event_subtype) in [
		"ace", "seam_conflict", "scramble", "emergency_second_contact",
		"emergency_tip", "stuff", "diving_save", "easy_miss",
	]:
		return true
	return bool(event.metadata.get("named_action", false))


static func _pbp_optional(event: Resource, key: String) -> bool:
	if key.is_empty():
		return false
	return int(event.event_type) in [
		RallyEventModel.EventType.SERVE,
		RallyEventModel.EventType.SET,
		RallyEventModel.EventType.ATTACK,
	] or str(event.event_subtype) == "excellent"


static func _analyst_evidence(result: Resource, index: int) -> Array[Dictionary]:
	var event: Resource = result.events[index]
	var evidence: Array[Dictionary] = []
	var values := _line_values(result, index)
	var subtype := str(event.event_subtype)
	var action := str(event.metadata.get("action_outcome", ""))
	if int(event.event_type) == RallyEventModel.EventType.SET:
		if subtype == "save":
			evidence.append(_evidence("setter_save", 76, "poor first contact followed by a successful set", values))
		if subtype == "predictable" or action == "Predictable set":
			evidence.append(_evidence("predictable_set", 72, "assist blocker closed before the attack", values))
		var requested := int(event.metadata.get("requested_tempo", -1))
		var achieved := int(event.metadata.get("achieved_tempo", requested))
		if requested >= 0 and achieved >= 0 and requested != achieved:
			evidence.append(_evidence("timing_mismatch", 80, "requested and achieved hitter-setter timing differ", values))
	elif int(event.event_type) == RallyEventModel.EventType.ATTACK:
		if subtype == "emergency_tip":
			evidence.append(_evidence("emergency_tip", 78, "approach constraints downgraded the selected attack to an emergency tip", values))
		if bool(result.play_was_followed) and not str(result.active_play_name).is_empty() \
				and _event_side_won(result, event):
			evidence.append(_evidence("called_play", 90, "selected offensive play was followed and the attack scored", values))
	elif int(event.event_type) == RallyEventModel.EventType.BLOCK:
		if subtype == "funnel" and str(event.metadata.get("block_intent", "")) == "Funnel":
			evidence.append(_evidence("funnel", 86, "saved Funnel intent produced a resolved funnel outcome toward floor defense", values))
		elif subtype == "touch" and _next_successful_dig(result.events, index):
			evidence.append(_evidence("block_touch", 68, "block touch slowed the ball before a successful dig", values))
		elif action == "Late block" \
				and int(event.metadata.get("block_tempo", -1)) in [0, 1]:
			evidence.append(_evidence("late_block", 74, "T0/T1 attack and low assist close left the travelling blocker late", values))
	elif int(event.event_type) == RallyEventModel.EventType.DIG and subtype == "easy_miss":
		evidence.append(_evidence("easy_miss", 66, "defender had positive arrival margin but did not control the ball", values))
	return evidence


static func _evidence(key: String, priority: int, basis: String, values: Dictionary) -> Dictionary:
	return {
		"key": key,
		"priority": priority,
		"inference_basis": basis,
		"classification": "ANALYST",
		"line": CommentaryLines.analyst(key, values),
	}


static func _select_analyst(result: Resource, candidates: Array[Dictionary]) -> void:
	result.commentary_analysis = ""
	if candidates.is_empty():
		return
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.priority) != int(right.priority):
			return int(left.priority) > int(right.priority)
		return int(left.event_index) > int(right.event_index)
	)
	var chosen: Dictionary = candidates[0]
	result.commentary_analysis = str(chosen.get("line", ""))
	var event: Resource = result.events[int(chosen.event_index)]
	if event.commentary_headline.is_empty():
		event.commentary_status = STATUS_ANALYST


static func _dedupe_physical_groups(events: Array) -> void:
	var owners := {}
	for index in range(events.size()):
		var event: Resource = events[index]
		if event == null or event.commentary_headline.is_empty():
			continue
		var group := str(event.dedupe_group)
		var priority := _ownership_priority(event)
		if not owners.has(group) or priority > int(owners[group].priority):
			owners[group] = {"index": index, "priority": priority}
	for index in range(events.size()):
		var event: Resource = events[index]
		if event == null or event.commentary_headline.is_empty():
			continue
		var owner: Dictionary = owners.get(str(event.dedupe_group), {})
		if int(owner.get("index", index)) == index:
			continue
		event.commentary_headline = ""
		event.commentary_silent = true
		event.commentary_status = STATUS_SUPPRESSED


static func _ownership_priority(event: Resource) -> int:
	if int(event.event_type) == RallyEventModel.EventType.BLOCK \
			and str(event.event_subtype) == "stuff":
		return 100
	if int(event.event_type) == RallyEventModel.EventType.ATTACK \
			and str(event.event_subtype) != "attack_generic":
		return 90
	if bool(event.metadata.get("named_action", false)):
		return 80
	return 50


static func _dedupe_group(events: Array, index: int) -> String:
	var event: Resource = events[index]
	if int(event.event_type) == RallyEventModel.EventType.BLOCK:
		var attack_index := _previous_type_index(events, index, RallyEventModel.EventType.ATTACK)
		if attack_index >= 0:
			return "attack_%d" % int((events[attack_index] as Resource).sequence)
	if int(event.event_type) == RallyEventModel.EventType.ATTACK:
		return "attack_%d" % int(event.sequence)
	if int(event.event_type) == RallyEventModel.EventType.POINT:
		var previous := _previous_contact_index(events, index)
		return str((events[previous] as Resource).dedupe_group) if previous >= 0 else "point"
	return "contact_%d" % int(event.sequence)


static func _line_values(result: Resource, index: int) -> Dictionary:
	var event: Resource = result.events[index]
	var actor := str(event.actor_name)
	if int(event.event_type) == RallyEventModel.EventType.RECEPTION \
			and str(event.event_subtype) == "ace":
		var serve_index := _previous_type_index(
			result.events, index, RallyEventModel.EventType.SERVE
		)
		if serve_index >= 0:
			actor = str((result.events[serve_index] as Resource).actor_name)
	var target := "the hitter"
	var next_attack := _next_type(result.events, index, RallyEventModel.EventType.ATTACK)
	if next_attack != null:
		target = str(next_attack.actor_name)
	return {
		"actor": actor,
		"target": target,
		"play": str(result.active_play_name),
	}


static func _diagnostics(event: Resource) -> Dictionary:
	var result := {
		"quality": float(event.quality),
		"event_time": float(event.metadata.get("event_time", 0.0)),
	}
	for key in [
		"arrival_margin", "reach_margin_meters", "requested_tempo",
		"achieved_tempo", "tempo_relationship", "attack_type",
		"attack_direction", "outcome", "primary_close", "assist_close_attempted",
	]:
		if event.metadata.has(key):
			result[key] = event.metadata[key]
	return result


static func _result_diagnostics(result: Resource) -> Array[String]:
	var lines: Array[String] = []
	for factor in result.key_factors:
		lines.append(str(factor))
	lines.append("Reception %d%% · Set %d%% · Attack %d%%" % [
		roundi(float(result.reception_quality) * 100.0),
		roundi(float(result.set_quality) * 100.0),
		roundi(float(result.attack_quality) * 100.0),
	])
	return lines


static func _event_side_won(result: Resource, event: Resource) -> bool:
	return bool(result.home_team_won) if str(event.metadata.get("side", "home")) == "home" \
		else not bool(result.home_team_won)


static func _contact_count(events: Array) -> int:
	var count := 0
	for event_resource in events:
		var event: Resource = event_resource
		if int(event.event_type) not in [RallyEventModel.EventType.SET_DECISION, RallyEventModel.EventType.POINT]:
			count += 1
	return count


static func _final_contact_index(events: Array) -> int:
	return _previous_contact_index(events, events.size())


static func _previous_contact_index(events: Array, index: int) -> int:
	for candidate in range(index - 1, -1, -1):
		var event: Resource = events[candidate]
		if int(event.event_type) not in [RallyEventModel.EventType.SET_DECISION, RallyEventModel.EventType.POINT]:
			return candidate
	return -1


static func _previous_type_index(events: Array, index: int, event_type: int) -> int:
	for candidate in range(index - 1, -1, -1):
		var event: Resource = events[candidate]
		if int(event.event_type) == event_type:
			return candidate
		if int(event.event_type) in [RallyEventModel.EventType.DIG, RallyEventModel.EventType.ATTACK_COVERAGE, RallyEventModel.EventType.POINT]:
			break
	return -1


static func _next_type(events: Array, index: int, event_type: int) -> Resource:
	for candidate in range(index + 1, events.size()):
		var event: Resource = events[candidate]
		if int(event.event_type) == event_type:
			return event
		if int(event.event_type) == RallyEventModel.EventType.POINT:
			break
	return null


static func _next_successful_dig(events: Array, index: int) -> bool:
	var dig := _next_type(events, index, RallyEventModel.EventType.DIG)
	return dig != null and bool(dig.success)
