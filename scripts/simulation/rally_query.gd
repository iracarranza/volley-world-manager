class_name RallyQuery
extends RefCounted

## Pure, deterministic predicates over an already-resolved rally.
##
## The resolver remains the only owner of the rally. This class neither rolls
## randomness nor mutates match state; command-line and in-game searches hand it
## the same result and receive the same normalized facts and clause verdicts.

const RallyEventModel := preload("res://scripts/models/rally_event.gd")


## Human-facing catalog for the in-game builder. Selectors and operations are
## still the same values accepted by the CLI and evaluator; this is prompting,
## not a second query language.
static func guided_fields() -> Array[Dictionary]:
	return [
		_field("Serve style", "serve.style", ["eq", "neq"], [
			"Jump Float", "Jump Topspin", "Standing Float", "Standing Topspin",
		]),
		_field("Serve mode", "serve.mode", ["eq", "neq"], [
			"targeted", "aggressive", "safe",
		]),
		_field("Serve target", "serve.target", ["eq", "neq"], []),
		_field("Serve result", "serve.result", ["eq", "neq"], [
			"in", "net", "long", "wide", "short",
		]),
		_field("Serve error reason", "serve.error_reason", ["eq", "neq"], [
			"net", "long", "wide", "short",
		]),
		_field("Terminal event", "terminal.event", ["eq", "neq"], [
			"SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG",
		]),
		_field("Terminal outcome", "terminal.outcome", ["eq", "neq"], [
			"kill", "opponent_kill", "attack_error", "opponent_attack_error",
			"blocked", "counter_block", "tool", "ace", "serve_error",
		]),
		_field("Sequence", "sequence", ["contains"], [
			"SERVE > RECEPTION > SET > ATTACK",
			"SERVE > RECEPTION > SET > ATTACK > BLOCK",
		]),
		_field("Has event", "events", ["has"], [
			"SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG",
		]),
		_field("Missing event", "events", ["absent"], [
			"RECEPTION", "SET", "ATTACK", "BLOCK", "DIG",
		]),
		_field("First set requested tempo", "set[1].requested_tempo", ["eq", "neq"], [
			"T0", "T1", "T2", "T3",
		]),
		_field("First set achieved tempo", "set[1].achieved_tempo", ["eq", "neq"], [
			"T0", "T1", "T2", "T3",
		]),
		_field("First set lane", "set[1].lane", ["eq", "neq"], [
			"Left Pin", "Left Quick", "Middle Quick", "Right Quick",
			"Right Pin", "Pipe",
		]),
		_field("First set posture", "set[1].posture", ["eq", "neq"], [
			"standing", "jump", "underhand",
		]),
		_field("First set direction", "set[1].side", ["eq", "neq"], [
			"front", "back",
		]),
		_field("First set quality", "set[1].quality", _numeric_ops(), []),
		_field("First set duration (s)", "set[1].duration", _numeric_ops(), []),
		_field("First attack type", "attack[1].type", ["eq", "neq", "contains"], [
			"quick", "power", "roll", "tip",
		]),
		_field("First attack is quick", "attack[1].quick", ["eq"], ["true", "false"]),
		_field("First attack lane", "attack[1].lane", ["eq", "neq"], [
			"Left Pin", "Left Quick", "Middle Quick", "Right Quick",
			"Right Pin", "Pipe",
		]),
		_field("First attack side", "attack[1].side", ["eq", "neq"], [
			"home", "opponent",
		]),
		_field("First attack result", "attack[1].result", ["eq", "neq"], [
			"kill", "error", "blocked", "tool", "dig",
		]),
		_field("First block contact", "block[1].contact_kind", ["eq", "neq"], [
			"stuff", "tool", "touch",
		]),
		_field("First block wall size", "block[1].wall_size", _numeric_ops(), ["0", "1", "2", "3"]),
		_field("Signature name", "signature", ["eq", "neq", "contains"], []),
		_field("Contact count", "contacts", _numeric_ops(), []),
		_field("Numeric metadata", "attack[1].metadata.wall_size", _numeric_ops(), []),
	]


static func guided_presets() -> Array[Dictionary]:
	return [
		{"label": "Choose a preset…", "query": ""},
		{"label": "Jump Float reception", "query": "serve.style=Jump Float;events has RECEPTION"},
		{"label": "Jump Topspin reception", "query": "serve.style=Jump Topspin;events has RECEPTION"},
		{"label": "Terminal block", "query": "terminal.event=BLOCK"},
		{"label": "Terminal tool", "query": "terminal.outcome=tool"},
		{"label": "First set achieved T1", "query": "set[1].achieved_tempo=T1"},
		{"label": "Sub-0.18 s achieved T1", "query": "set[1].achieved_tempo=T1;set[1].duration<0.18"},
		{"label": "First attack is quick", "query": "attack[1].quick=true"},
		{"label": "Full attack sequence", "query": "sequence contains SERVE > RECEPTION > SET > ATTACK"},
		{"label": "Standing front set", "query": "set[1].posture=standing;set[1].side=front"},
		{"label": "Jump back set", "query": "set[1].posture=jump;set[1].side=back"},
		{"label": "Underhand second contact", "query": "set[1].posture=underhand"},
	]


static func clause(selector: String, operation: String, value: Variant) -> Dictionary:
	return _clause(selector, operation, value)


static func clauses_to_text(clauses: Array[Dictionary]) -> String:
	var expressions: Array[String] = []
	for query_clause in clauses:
		var selector := str(query_clause.get("selector", ""))
		var operation := str(query_clause.get("op", "eq"))
		var value := str(query_clause.get("value", ""))
		var token: String = {
			"eq": "=", "neq": "!=", "lt": "<", "lte": "<=",
			"gt": ">", "gte": ">=", "contains": " contains ",
			"has": " has ", "absent": " absent ", "present": " present",
		}.get(operation, "=")
		expressions.append(selector + token + ("" if operation == "present" else value))
	return ";".join(expressions)


static func clauses_from_arguments(arguments: Dictionary) -> Array[Dictionary]:
	var clauses: Array[Dictionary] = []
	_add_argument_clause(clauses, arguments, "serve-style", "serve.style")
	_add_argument_clause(clauses, arguments, "serve-mode", "serve.mode")
	_add_argument_clause(clauses, arguments, "serve-target", "serve.target")
	_add_argument_clause(clauses, arguments, "serve-result", "serve.result")
	_add_argument_clause(clauses, arguments, "serve-error", "serve.error_reason")
	_add_argument_clause(clauses, arguments, "terminal-event", "terminal.event")
	_add_argument_clause(clauses, arguments, "outcome", "terminal.outcome")
	_add_argument_clause(clauses, arguments, "sequence", "sequence", "contains")
	_add_argument_clause(clauses, arguments, "has", "events", "has")
	_add_argument_clause(clauses, arguments, "absent", "events", "absent")
	_add_argument_clause(clauses, arguments, "set-tempo", "set[1].requested_tempo")
	_add_argument_clause(clauses, arguments, "set-achieved-tempo", "set[1].achieved_tempo")
	_add_argument_clause(clauses, arguments, "set-lane", "set[1].lane")
	_add_argument_clause(clauses, arguments, "set-posture", "set[1].posture")
	_add_argument_clause(clauses, arguments, "set-side", "set[1].side")
	_add_argument_clause(clauses, arguments, "set-quality", "set[1].quality")
	_add_argument_clause(clauses, arguments, "set-duration", "set[1].duration")
	_add_argument_clause(clauses, arguments, "attack-type", "attack[1].type")
	_add_argument_clause(clauses, arguments, "attack-lane", "attack[1].lane")
	_add_argument_clause(clauses, arguments, "attack-side", "attack[1].side")
	_add_argument_clause(clauses, arguments, "attack-result", "attack[1].result")
	_add_argument_clause(clauses, arguments, "block", "block[1].contact_kind")
	_add_argument_clause(clauses, arguments, "wall", "block[1].wall_size")
	_add_argument_clause(clauses, arguments, "signature", "signature", "present")
	_add_argument_clause(clauses, arguments, "signature-name", "signature")
	_add_argument_clause(clauses, arguments, "min-contacts", "contacts", "gte")
	_add_argument_clause(clauses, arguments, "max-contacts", "contacts", "lte")
	for expression in str(arguments.get("where", "")).split(";", false):
		var clause := parse_expression(expression)
		if not clause.is_empty():
			clauses.append(clause)
	return clauses


static func clauses_from_text(text: String) -> Array[Dictionary]:
	var clauses: Array[Dictionary] = []
	for raw_clause in text.split(";", false):
		var phrase := raw_clause.strip_edges()
		if phrase.is_empty():
			continue
		var lowered := phrase.to_lower()
		var clause: Dictionary = {}
		if lowered.begins_with("serve is "):
			clause = _clause("serve.style", "eq", phrase.substr(9))
		elif lowered.begins_with("terminal event is "):
			clause = _clause("terminal.event", "eq", phrase.substr(18))
		elif lowered.begins_with("terminal outcome is "):
			clause = _clause("terminal.outcome", "eq", phrase.substr(20))
		elif lowered.begins_with("first set achieved tempo is "):
			clause = _clause("set[1].achieved_tempo", "eq", phrase.substr(28))
		elif lowered.begins_with("first set duration is below "):
			clause = _clause("set[1].duration", "lt", phrase.substr(28).trim_suffix(" seconds"))
		elif lowered.begins_with("first attack is "):
			var wanted_attack := phrase.substr(16)
			clause = _clause("attack[1].quick", "eq", true) \
				if _canonical(wanted_attack) == "quick" \
				else _clause("attack[1].type", "contains", wanted_attack)
		elif lowered.begins_with("sequence contains "):
			clause = _clause("sequence", "contains", phrase.substr(18))
		elif lowered.begins_with("has "):
			clause = _clause("events", "has", phrase.substr(4))
		elif lowered.begins_with("no "):
			clause = _clause("events", "absent", phrase.substr(3))
		else:
			clause = parse_expression(phrase)
		if not clause.is_empty():
			clauses.append(clause)
	return clauses


static func parse_expression(expression: String) -> Dictionary:
	var source := expression.strip_edges()
	if source.to_lower().ends_with(" present"):
		return _clause(
			source.substr(0, source.length() - 8).strip_edges(), "present", true
		)
	for named_operation in [" contains ", " absent ", " has "]:
		var named_at := source.to_lower().find(named_operation)
		if named_at > 0:
			return _clause(
				source.substr(0, named_at).strip_edges(),
				named_operation.strip_edges(),
				source.substr(named_at + named_operation.length()).strip_edges(),
			)
	for token in ["<=", ">=", "!=", "<", ">", "="]:
		var at := source.find(token)
		if at > 0:
			var operation: String = {
				"<=": "lte", ">=": "gte", "!=": "neq",
				"<": "lt", ">": "gt", "=": "eq",
			}[token]
			return _clause(
				source.substr(0, at).strip_edges(), operation,
				source.substr(at + token.length()).strip_edges(),
			)
	return {}


static func normalize(result: Resource, serving_home: bool) -> Dictionary:
	var normalized_events: Array[Dictionary] = []
	var by_type := {}
	var sequence: Array[String] = []
	for index in range(result.events.size()):
		var event: Resource = result.events[index]
		if int(event.event_type) == RallyEventModel.EventType.SET_DECISION:
			continue
		var type_name := _event_type_name(int(event.event_type))
		var occurrence := int(by_type.get(type_name, 0)) + 1
		by_type[type_name] = occurrence
		var metadata: Dictionary = event.metadata
		var record := {
			"index": index,
			"occurrence": occurrence,
			"event": event,
			"event_type": type_name,
			"side": str(metadata.get("side", "")),
			"success": bool(event.success),
			"quality": float(event.quality),
			"metadata": metadata,
		}
		normalized_events.append(record)
		sequence.append(type_name.to_upper())
	var terminal_event := ""
	for index in range(normalized_events.size() - 1, -1, -1):
		var candidate := str(normalized_events[index]["event_type"])
		if candidate != "point":
			terminal_event = candidate
			break
	return {
		"result": result,
		"serving_side": "home" if serving_home else "opponent",
		"events": normalized_events,
		"sequence": sequence,
		"contacts": normalized_events.size(),
		"terminal_event": terminal_event,
		"terminal_outcome": str(result.terminal_outcome),
	}


static func evaluate(
	result: Resource, serving_home: bool, clauses: Array[Dictionary]
) -> Dictionary:
	var facts := normalize(result, serving_home)
	var verdicts: Array[Dictionary] = []
	var all_match := not clauses.is_empty()
	for clause in clauses:
		var actual: Variant = value_for(facts, str(clause.get("selector", "")))
		var passed := _compare(actual, str(clause.get("op", "eq")), clause.get("value"))
		verdicts.append({
			"name": clause_label(clause), "passed": passed, "actual": actual,
		})
		all_match = all_match and passed
	return {"matches": all_match, "clauses": verdicts, "facts": facts}


static func value_for(facts: Dictionary, selector: String) -> Variant:
	var path := selector.strip_edges().to_lower().replace("-", "_")
	match path:
		"serving", "serving_side": return facts["serving_side"]
		"contacts": return facts["contacts"]
		"terminal.event": return facts["terminal_event"]
		"terminal.outcome": return facts["terminal_outcome"]
		"sequence": return facts["sequence"]
		"events": return facts["sequence"]
		"signature":
			for record in facts["events"]:
				var signature := str(record["metadata"].get("signature_move", ""))
				if not signature.is_empty(): return signature
			return ""
	var head := path.get_slice(".", 0)
	var field := path.substr(head.length() + 1) if path.contains(".") else ""
	var occurrence := 1
	if head.contains("["):
		occurrence = maxi(int(head.get_slice("[", 1).trim_suffix("]")), 1)
		head = head.get_slice("[", 0)
	var record := _event_record(facts, head, occurrence)
	if record.is_empty(): return null
	return _event_field(record, field, facts)


static func result_summary(seed: int, evaluation: Dictionary) -> String:
	var facts: Dictionary = evaluation["facts"]
	var matching: Array[String] = []
	for verdict in evaluation["clauses"]:
		if bool(verdict["passed"]): matching.append(str(verdict["name"]))
	return "seed %d · %s serving · %s/%s · %d contacts · %s" % [
		seed, facts["serving_side"], str(facts["terminal_event"]).to_upper(),
		facts["terminal_outcome"], facts["contacts"], ", ".join(matching),
	]


static func reproduction_command(
	from_seed: int, to_seed: int, serving: String, query_text: String
) -> String:
	return "godot --headless --path . --script res://tools/run_seed_search.gd -- --from=%d --to=%d --serving=%s --query=\"%s\"" % [
		from_seed, to_seed, serving, query_text.replace("\"", "\\\""),
	]


static func clause_label(clause: Dictionary) -> String:
	return "%s %s %s" % [clause.get("selector", ""), clause.get("op", "eq"), clause.get("value", "")]


static func _add_argument_clause(
	clauses: Array[Dictionary], arguments: Dictionary, argument: String,
	selector: String, operation: String = "eq",
) -> void:
	if arguments.has(argument):
		clauses.append(_clause(selector, operation, arguments[argument]))


static func _field(
	label: String, selector: String, operations: Array, values: Array,
) -> Dictionary:
	return {
		"label": label, "selector": selector,
		"operations": operations.duplicate(), "values": values.duplicate(),
	}


static func _numeric_ops() -> Array[String]:
	return ["eq", "lt", "lte", "gt", "gte", "neq"]


static func _clause(selector: String, operation: String, value: Variant) -> Dictionary:
	return {"selector": selector, "op": operation, "value": _typed(value)}


static func _typed(value: Variant) -> Variant:
	if value is bool or value is int or value is float: return value
	var text := str(value).strip_edges()
	if text.is_valid_int(): return int(text)
	if text.is_valid_float(): return float(text)
	if text.length() == 2 and text.left(1).to_upper() == "T" \
		and text.right(1).is_valid_int():
		return int(text.right(1))
	if text.to_lower() == "true": return true
	if text.to_lower() == "false": return false
	return text


static func _compare(actual: Variant, operation: String, expected: Variant) -> bool:
	if operation == "present":
		return actual != null and (not str(actual).is_empty())
	if operation in ["lt", "lte", "gt", "gte"]:
		if actual == null or not str(actual).is_valid_float() or not str(expected).is_valid_float():
			return false
		var left := float(actual)
		var right := float(expected)
		match operation:
			"lt": return left < right
			"lte": return left <= right
			"gt": return left > right
			"gte": return left >= right
	if operation in ["has", "absent"]:
		var wanted := _canonical(str(expected))
		var found := false
		for item in actual if actual is Array else [actual]:
			if _canonical(str(item)) == wanted:
				found = true
				break
		return found if operation == "has" else not found
	if operation == "contains":
		if actual is Array:
			var wanted_sequence: Array[String] = []
			for token in str(expected).replace(">", " ").split(" ", false):
				wanted_sequence.append(_canonical(token))
			var source: Array[String] = []
			for token in actual: source.append(_canonical(str(token)))
			return _contains_sequence(source, wanted_sequence)
		return _canonical(str(actual)).contains(_canonical(str(expected)))
	var equal := false
	if actual is int or actual is float or expected is int or expected is float:
		equal = str(actual).is_valid_float() and str(expected).is_valid_float() \
			and is_equal_approx(float(actual), float(expected))
	else:
		equal = _canonical(str(actual)) == _canonical(str(expected))
	return not equal if operation == "neq" else equal


static func _contains_sequence(source: Array[String], wanted: Array[String]) -> bool:
	if wanted.is_empty() or wanted.size() > source.size(): return false
	for start in range(source.size() - wanted.size() + 1):
		var matches := true
		for offset in range(wanted.size()):
			if source[start + offset] != wanted[offset]:
				matches = false
				break
		if matches: return true
	return false


static func _event_record(facts: Dictionary, type_name: String, occurrence: int) -> Dictionary:
	for record in facts["events"]:
		if record["event_type"] == type_name and int(record["occurrence"]) == occurrence:
			return record
	return {}


static func _event_field(record: Dictionary, field: String, facts: Dictionary) -> Variant:
	var event: Resource = record["event"]
	var metadata: Dictionary = record["metadata"]
	match field:
		"success": return record["success"]
		"style": return metadata.get("serve_style", "")
		"mode": return metadata.get("serve_mode", "")
		"target": return metadata.get("target", "")
		"error_reason": return metadata.get("serve_out_reason", "")
		"result":
			if record["event_type"] == "serve":
				return "in" if bool(event.success) else str(metadata.get("serve_out_reason", "error"))
			return _event_result(record)
		"requested_tempo": return metadata.get("requested_tempo", metadata.get("tempo", null))
		"achieved_tempo": return Dictionary(metadata.get("tempo_coordination", {})).get("achieved_tempo", metadata.get("achieved_tempo", null))
		"lane":
			if metadata.has("lane"): return metadata["lane"]
			if record["event_type"] == "set":
				var next_attack := _next_event(facts, int(record["index"]), "attack", str(record["side"]))
				return Dictionary(next_attack.get("metadata", {})).get("lane", "")
			return ""
		"posture":
			if record["event_type"] == "set" and _set_is_underhand(record): return "underhand"
			return metadata.get("set_posture", metadata.get("contact_posture", ""))
		"side":
			if record["event_type"] == "set":
				return "back" if bool(metadata.get("back_set", false)) else "front"
			return record["side"]
		"team_side": return record["side"]
		"quality": return record["quality"]
		"duration": return Dictionary(metadata.get("outgoing_trajectory", {})).get("duration", metadata.get("set_flight_time", metadata.get("flight_time", null)))
		"type": return metadata.get("attack_type", "")
		"quick":
			var timing: Dictionary = metadata.get("tempo_coordination", {})
			return int(timing.get("achieved_tempo", metadata.get(
				"achieved_tempo", metadata.get("tempo", 3)
			))) <= 1
		"contact_kind": return metadata.get("block_contact_kind", "")
		"wall_size": return metadata.get("wall_size", 0)
	if field.begins_with("metadata."):
		return _dictionary_path(metadata, field.trim_prefix("metadata."))
	return metadata.get(field, null)


static func _set_is_underhand(record: Dictionary) -> bool:
	var metadata: Dictionary = record["metadata"]
	if str(Dictionary(metadata.get("setter_capability", {})).get(
		"reach_state", ""
	)) == "platform":
		return true
	var incoming: Dictionary = metadata.get("incoming_trajectory", {})
	var contact_height := float(incoming.get("end_height_meters", metadata.get("set_contact_height_meters", 99.0)))
	var release_height := float(metadata.get("set_release_height_meters", contact_height))
	return str(metadata.get("set_posture", "standing")) != "jump" \
		and contact_height + 0.08 < release_height


static func _event_result(record: Dictionary) -> String:
	var metadata: Dictionary = record["metadata"]
	for key in ["attack_result", "block_contact_kind", "serve_out_reason", "result"]:
		if metadata.has(key) and not str(metadata[key]).is_empty(): return str(metadata[key])
	return "success" if bool(record["success"]) else "failure"


static func _next_event(
	facts: Dictionary, after_index: int, type_name: String, side: String
) -> Dictionary:
	for record in facts["events"]:
		if int(record["index"]) > after_index and record["event_type"] == type_name \
			and (side.is_empty() or str(record["side"]) == side):
			return record
	return {}


static func _dictionary_path(dictionary: Dictionary, path: String) -> Variant:
	var current: Variant = dictionary
	for component in path.split(".", false):
		if not current is Dictionary or not current.has(component): return null
		current = current[component]
	return current


static func _event_type_name(event_type: int) -> String:
	return str(RallyEventModel.EventType.keys()[event_type]).to_lower()


static func _canonical(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", " ").replace("-", " ")
