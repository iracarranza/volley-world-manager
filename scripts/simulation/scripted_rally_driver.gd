class_name ScriptedRallyDriver
extends RallySimulator

## Intent adapter over production rally systems. A script states timed volleyball
## intentions; only a body-reachable opportunity on the production ball becomes
## a physical RallyEvent.

const ACTIONS: Array[StringName] = [
	&"serve", &"receive", &"set", &"attack", &"block", &"dig", &"cover",
]
const TOP_LEVEL_KEYS: Array[String] = [
	"serving_side", "initial_positions", "actions", "note",
]
const COMMON_ACTION_KEYS: Array[String] = [
	"actor", "action", "intent_time", "target", "note",
]
const FAMILY_ACTION_KEYS := {
	&"serve": ["serve_type", "course", "aggression"],
	&"receive": ["attempted_action"],
	&"set": ["set_family", "tempo"],
	&"attack": ["attack_action", "course", "aggression"],
	&"block": ["block_intent", "course"],
	&"dig": ["attempted_action"],
	&"cover": ["attempted_action"],
}
const SIDE_HOME := &"home"
const SIDE_OPPONENT := &"opponent"

var last_refusal: String = ""
var _script_states: Dictionary = {}
var _intent_records: Array[Dictionary] = []
var _expected_families: Array[StringName] = []
var _expected_side: StringName = &""


## Schema validation. Roster-dependent validation completes in `resolve_script`,
## where the production rosters are available.
static func validate(script: Dictionary) -> String:
	for raw_key in script:
		if str(raw_key) not in TOP_LEVEL_KEYS:
			return "script has an unknown key '%s'" % str(raw_key)
	var serving_side := StringName(script.get("serving_side", &""))
	if serving_side not in [SIDE_HOME, SIDE_OPPONENT]:
		return "serving_side must be 'home' or 'opponent'"
	var positions: Variant = script.get("initial_positions", {})
	if not positions is Dictionary or Dictionary(positions).size() != 12:
		return "initial_positions must contain exactly 12 volis"
	var ids: Dictionary = {}
	for raw_id: Variant in Dictionary(positions):
		if not raw_id is int or int(raw_id) < 0:
			return "initial_positions contains an invalid voli id"
		var point: Variant = Dictionary(positions)[raw_id]
		if not point is Vector2 or not CourtConstants.is_normalized(point):
			return "initial position for voli %s is outside normalized court" % raw_id
		ids[int(raw_id)] = true
	var actions: Variant = script.get("actions", [])
	if not actions is Array or Array(actions).is_empty():
		return "actions must contain at least one timed intention"
	if not Array(actions)[0] is Dictionary:
		return "action 0 must be a dictionary"
	if StringName(Dictionary(Array(actions)[0]).get("action", &"")) != &"serve":
		return "the first action must be the serve"
	for index in Array(actions).size():
		if not Array(actions)[index] is Dictionary:
			return "action %d must be a dictionary" % index
		var action: Dictionary = Array(actions)[index]
		var family := StringName(action.get("action", &""))
		if family not in ACTIONS:
			return "action %d has unsupported action '%s'" % [index, family]
		var permitted: Array = COMMON_ACTION_KEYS + Array(FAMILY_ACTION_KEYS[family])
		for raw_key in action:
			if str(raw_key) not in permitted:
				return "action %d has an unknown key '%s'" % [index, str(raw_key)]
		if not action.get("actor", null) is int or not ids.has(int(action.actor)):
			return "action %d names an unknown actor" % index
		var at: Variant = action.get("intent_time", null)
		if not (at is float or at is int) or not is_finite(float(at)) or float(at) < 0.0:
			return "action %d has an invalid intent_time" % index
		var target_error := _validate_target(index, family, action.get("target", null), ids)
		if not target_error.is_empty():
			return target_error
		if family in [&"serve", &"attack"]:
			var aggression: Variant = action.get("aggression", 0.5)
			if not (aggression is float or aggression is int) \
					or float(aggression) < 0.0 or float(aggression) > 1.0:
				return "action %d aggression must be between 0 and 1" % index
		if family == &"set":
			var tempo: Variant = action.get("tempo", 2)
			if not tempo is int or int(tempo) < 0 or int(tempo) > 3:
				return "action %d tempo must be an integer from 0 through 3" % index
	return ""


static func _validate_target(index: int, family: StringName, target: Variant, ids: Dictionary) -> String:
	if family == &"block" and target == null:
		return ""
	if target is int:
		if family in [&"serve", &"attack", &"block"]:
			return "action %d target must be a normalized court coordinate" % index
		if not ids.has(int(target)):
			return "action %d names an unknown target voli" % index
		return ""
	if not target is Vector2 or not CourtConstants.is_normalized(target):
		return "action %d target must be a voli id or normalized court coordinate" % index
	return ""


## Audit physical contacts, not authored intentions. A block attempt without a
## touch is intentionally skipped.
static func seam_census(events: Array) -> String:
	var previous_outgoing: Dictionary = {}
	for index in events.size():
		var event: Variant = events[index]
		if event == null or not event is Resource:
			return "event %d is not a RallyEvent" % index
		var meta: Dictionary = event.metadata
		if not bool(meta.get("physical_contact", false)):
			continue
		if not meta.has("resolved_contact_time"):
			return "event %d has no resolved_contact_time" % index
		if not meta.has("contact_height_meters"):
			return "event %d has no contact_height_meters" % index
		var incoming: Dictionary = meta.get("incoming_trajectory", {})
		if not previous_outgoing.is_empty() and not incoming.is_empty() \
				and not _same_flight_endpoint(previous_outgoing, incoming):
			return "event %d incoming flight differs from the previous contact" % index
		var outgoing: Dictionary = meta.get("outgoing_trajectory", {})
		if outgoing.is_empty():
			return "event %d has no outgoing production flight" % index
		if not incoming.is_empty() and not _same_contact_seam(incoming, outgoing):
			return "event %d breaks the contact flight seam" % index
		previous_outgoing = outgoing
	return ""


static func _same_flight_endpoint(left: Dictionary, right: Dictionary) -> bool:
	return Vector2(left.get("end_position", Vector2.INF)) == Vector2(right.get("end_position", Vector2.INF)) \
		and is_equal_approx(float(left.get("end_time", NAN)), float(right.get("end_time", NAN))) \
		and is_equal_approx(float(left.get("end_height_meters", NAN)), float(right.get("end_height_meters", NAN)))


static func _same_contact_seam(incoming: Dictionary, outgoing: Dictionary) -> bool:
	return Vector2(incoming.get("end_position", Vector2.INF)) == Vector2(outgoing.get("start_position", Vector2.INF)) \
		and is_equal_approx(float(incoming.get("end_time", NAN)), float(outgoing.get("start_time", NAN))) \
		and is_equal_approx(float(incoming.get("end_height_meters", NAN)), float(outgoing.get("start_height_meters", NAN)))


func resolve_script(
	script: Dictionary,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	seed_value: int = 1,
) -> Resource:
	last_refusal = validate(script)
	if not last_refusal.is_empty():
		return null
	var home_serving := StringName(script.serving_side) == SIDE_HOME
	rally_seed = seed_value
	rng.seed = seed_value
	geometric_rng.seed = seed_value
	geometric_swing_index = 0
	rally_clock = 0.0
	var result: Resource = RallyResultModel.new()
	var state: RallyState = RallyStateBuilderModel.build(
		players, lineup, defensive_plan, opponent_team, null, home_serving, seed_value
	)
	if state == null:
		last_refusal = "production could not build the initial rally state"
		return null
	_script_states.clear()
	for raw_id in state.home_players:
		_script_states[int(raw_id)] = state.home_players[raw_id]
	for raw_id in state.opponent_players:
		_script_states[int(raw_id)] = state.opponent_players[raw_id]
	last_refusal = _apply_authored_positions(Dictionary(script.initial_positions))
	if not last_refusal.is_empty():
		return null
	_sync_live_positions()
	result.initial_home_positions = live_positions.duplicate(true)
	result.initial_opponent_positions = opponent_live_positions.duplicate(true)
	_intent_records = []
	_expected_families = [&"serve"]
	_expected_side = StringName(script.serving_side)
	var actions: Array = script.actions
	var serve_action: Dictionary = actions[0]
	var server_state: RallyPlayerState = _script_states.get(int(serve_action.actor))
	if server_state == null or server_state.team_side != StringName(script.serving_side):
		last_refusal = "serve actor is not on serving_side"
		return null
	var current_flight := _resolve_serve_intent(result, serve_action, server_state, home_serving, 0)
	var index := 1
	while not current_flight.is_empty() and index < actions.size():
		var action: Dictionary = actions[index]
		var family := StringName(action.action)
		if family == &"serve":
			last_refusal = "action %d attempts a second serve" % index
			break
		if family == &"block":
			_record_intent(index, action, "missed", "no preceding attack to contest")
			index += 1
			continue
		if family not in _expected_families:
			_record_intent(index, action, "failed", "action is illegal for the resolved ball state")
			result.terminal_outcome = "scripted_illegal_intention"
			break
		var acting_state: RallyPlayerState = _script_states.get(int(action.actor))
		if acting_state == null or acting_state.team_side != _expected_side:
			_record_intent(index, action, "failed", "actor is on the illegal side for the resolved ball state")
			result.terminal_outcome = "scripted_illegal_side"
			break
		var opportunity := _contact_opportunity(action, current_flight)
		if opportunity.is_empty():
			_record_intent(index, action, "missed", "body and ball never coincided")
			_publish_uncontrolled_terminal(result, current_flight, action, index)
			break
		var incoming := FreeFlightInterceptionModel.realised_prefix(current_flight, float(opportunity.contact_time))
		_truncate_previous_contact(result, incoming)
		_apply_contact_state(opportunity)
		var resolved := {}
		match family:
			&"receive", &"dig", &"cover":
				resolved = _resolve_platform_intent(result, action, opportunity, incoming, family, index)
			&"set":
				resolved = _resolve_set_intent(result, action, opportunity, incoming, index)
			&"attack":
				var blocks: Array[Dictionary] = []
				var scan := index + 1
				while scan < actions.size() and StringName(Dictionary(actions[scan]).action) == &"block":
					blocks.append(Dictionary(actions[scan]))
					scan += 1
				resolved = _resolve_attack_intent(result, action, opportunity, incoming, blocks, index)
				index = scan - 1
		if resolved.is_empty():
			break
		current_flight = Dictionary(resolved.get("authoritative_free_flight", {}))
		index += 1
	result.analysis["scripted_intents"] = _intent_records.duplicate(true)
	return result


func _apply_authored_positions(authored: Dictionary) -> String:
	if authored.size() != _script_states.size():
		return "initial_positions must name the twelve production on-court volis"
	for raw_id in authored:
		var actor_id := int(raw_id)
		if not _script_states.has(actor_id):
			return "initial_positions names voli %d who is not on court" % actor_id
		var actor: RallyPlayerState = _script_states[actor_id]
		actor.position = Vector2(authored[raw_id])
		actor.intent_target = actor.position
		actor.tactical_home = actor.position
	return ""


func _sync_live_positions() -> void:
	live_positions = {}
	opponent_live_positions = {}
	for raw_id in _script_states:
		var actor: RallyPlayerState = _script_states[raw_id]
		if actor.team_side == SIDE_HOME:
			live_positions[int(raw_id)] = actor.position
		else:
			opponent_live_positions[int(raw_id)] = actor.position


func _resolve_serve_intent(
	result: Resource, action: Dictionary, server_state: RallyPlayerState,
	home_serving: bool, index: int,
) -> Dictionary:
	var intent_time := float(action.intent_time)
	rally_clock = intent_time
	var server := server_state.player
	var requested_type := str(action.get("serve_type", server.primary_serve_style))
	var resolving_server: VolleyballPlayer = server
	if requested_type != str(server.primary_serve_style):
		resolving_server = server.duplicate(true) as VolleyballPlayer
		resolving_server.primary_serve_style = requested_type
	var origin := CourtConstants.serve_origin(server_state.position.x, home_serving)
	var served := _canonical_serve(
		"scripted-%d" % index, resolving_server, origin, Vector2(action.target),
		home_serving, float(action.get("aggression", 0.5)),
	)
	if served.is_empty():
		_record_intent(index, action, "failed", "production serve resolver refused the attempt")
		return {}
	var outgoing: Dictionary = served.authoritative_free_flight
	var height := float(served.contact_height_meters)
	_add_event(
		result, RallyEventModel.EventType.SERVE, server.id, server.display_name,
		origin, Vector2(served.landing), not bool(served.error), 0.5,
		"%s attempts a %s serve" % [server.display_name, requested_type], "",
		_contact_metadata(action, index, intent_time, height, {}, outgoing, {
			"side": String(server_state.team_side), "serve_style": requested_type,
			"serve_outcome": str(served.outcome), "intended_target": Vector2(action.target),
			"actual_landing": Vector2(served.landing),
		}),
	)
	_record_intent(index, action, "contacted", "", intent_time, height)
	_expected_families = [&"receive"]
	_expected_side = _opposite_side(server_state.team_side)
	return outgoing


func _contact_opportunity(action: Dictionary, free_flight: Dictionary) -> Dictionary:
	var actor: RallyPlayerState = _script_states.get(int(action.actor))
	if actor == null:
		return {}
	var family := StringName(action.action)
	var scan := FreeFlightInterceptionModel.opportunities(
		free_flight, [actor], family,
		family in [&"set", &"attack", &"block"], [], null, NAN,
		true, float(action.intent_time), family == &"attack",
	)
	return Dictionary(Dictionary(scan.get("opportunities", {})).get(actor.player_id, {}))


func _apply_contact_state(opportunity: Dictionary) -> void:
	var actor: RallyPlayerState = _script_states.get(int(opportunity.player_id))
	if actor == null:
		return
	actor.position = Vector2(opportunity.body_contact_position)
	actor.last_contact_time = float(opportunity.contact_time)
	actor.velocity = Vector2.ZERO
	rally_clock = float(opportunity.contact_time)
	_sync_live_positions()


func _resolve_platform_intent(
	result: Resource, action: Dictionary, opportunity: Dictionary,
	incoming: Dictionary, family: StringName, index: int,
) -> Dictionary:
	var actor: RallyPlayerState = _script_states[int(action.actor)]
	var target := _target_position(action.target)
	var recipient := _target_actor(action.target)
	var height_anchor := GeometricAttackPromotionModel.set_contact_height_meters(recipient) \
		if recipient != null else GeometricAttackPromotionModel.set_contact_height_meters(actor.player)
	var platform_intent := {
		"purpose": String(family), "target_anchor": target,
		"anchor_source": "authored_intent",
		"intended_recipient_id": recipient.id if recipient != null else -1,
		"height_anchor_meters": height_anchor, "arrival_floor_seconds": 0.0,
		"preference_source": "scripted_intent",
	}
	var body_velocity := _platform_body_velocity(
		Vector2(opportunity.start), Vector2(opportunity.body_contact_position),
		float(opportunity.travel_time), float(opportunity.available_time),
	)
	var arrival := {
		"reach_margin_meters": float(opportunity.reach_margin_meters),
		"edge_ratio": clampf(1.0 - float(opportunity.arrival_balance), 0.0, 1.0),
	}
	var physical := _physical_platform_dig_result(
		actor.player, Vector2(opportunity.contact_position), incoming, arrival,
		body_velocity, platform_intent, float(opportunity.contact_time), String(family),
	)
	if physical.is_empty():
		last_refusal = "action %d did not reach the production platform resolver" % index
		return {}
	var event_type := RallyEventModel.EventType.RECEPTION
	if family == &"dig":
		event_type = RallyEventModel.EventType.DIG
	elif family == &"cover":
		event_type = RallyEventModel.EventType.ATTACK_COVERAGE
	var quality := clampf(
		float(opportunity.physical_feasibility) * 0.5
		+ float(opportunity.arrival_balance) * 0.5, 0.0, 1.0,
	)
	var outgoing: Dictionary = physical.authoritative_free_flight
	_add_event(
		result, event_type, actor.player_id, actor.player.display_name,
		Vector2(opportunity.contact_position), Vector2(physical.destination), true,
		quality, "%s attempts %s" % [actor.player.display_name, String(family)], "",
		_contact_metadata(action, index, float(opportunity.contact_time),
			float(opportunity.contact_height_meters), incoming, outgoing, {
				"side": String(actor.team_side), "intended_target": target,
				"actual_target": Vector2(physical.destination),
				"body_contact_position": Vector2(opportunity.body_contact_position),
				"platform_contact": physical.platform_contact,
				"target_error_meters": float(physical.target_error_meters),
			}),
	)
	_record_intent(index, action, "contacted", "", float(opportunity.contact_time),
		float(opportunity.contact_height_meters))
	_expected_families = [&"set"]
	_expected_side = actor.team_side
	return physical


func _resolve_set_intent(
	result: Resource, action: Dictionary, opportunity: Dictionary,
	incoming: Dictionary, index: int,
) -> Dictionary:
	var actor: RallyPlayerState = _script_states[int(action.actor)]
	var intended := _target_position(action.target)
	var hitter := _target_actor(action.target)
	var tempo := int(action.get("tempo", 2))
	var geometry := _set_geometry(
		actor.player, Vector2(opportunity.start), Vector2(opportunity.contact_position),
		intended, actor.position, -1.0 if actor.team_side == SIDE_HOME else 1.0,
	)
	var terms := _set_terms(actor.player, 0.65, float(tempo) * 0.025, 0.0,
		float(opportunity.arrival_margin), float(geometry.difficulty))
	var quality := float(terms.quality)
	var delivered := _delivered_point(
		intended, quality, 0.85, 0.08,
		0.51 if actor.team_side == SIDE_HOME else 0.02,
		0.98 if actor.team_side == SIDE_HOME else 0.49,
		float(geometry.distance_meters),
	)
	var release_height := float(opportunity.contact_height_meters)
	var arrival_height := GeometricAttackPromotionModel.contact_height_meters(
		hitter if hitter != null else actor.player, 1.0)
	var distance := RallyKinematics.court_distance_meters(Vector2(opportunity.contact_position), delivered)
	var arc := _set_arc(actor.player, tempo, quality, release_height, arrival_height, distance)
	var outgoing := _free_flight_between(
		"set", Vector2(opportunity.contact_position), delivered, release_height,
		arrival_height, float(arc.duration_seconds), float(opportunity.contact_time),
		"set:%d" % index)
	if outgoing.is_empty():
		last_refusal = "action %d did not reach the production set-flight seam" % index
		return {}
	_add_event(
		result, RallyEventModel.EventType.SET, actor.player_id, actor.player.display_name,
		Vector2(opportunity.contact_position), delivered, true, quality,
		"%s attempts a %s" % [actor.player.display_name, str(action.get("set_family", "set"))], "",
		_contact_metadata(action, index, float(opportunity.contact_time), release_height,
			incoming, outgoing, {
				"side": String(actor.team_side), "tempo": tempo,
				"set_family": str(action.get("set_family", "set")),
				"intended_target": intended, "actual_target": delivered,
				"set_terms": terms, "set_geometry": geometry,
				"body_contact_position": Vector2(opportunity.body_contact_position),
			}),
	)
	_record_intent(index, action, "contacted", "", float(opportunity.contact_time), release_height)
	_expected_families = [&"attack"]
	_expected_side = actor.team_side
	return {"authoritative_free_flight": outgoing}


func _resolve_attack_intent(
	result: Resource, action: Dictionary, opportunity: Dictionary,
	incoming: Dictionary, block_actions: Array[Dictionary], index: int,
) -> Dictionary:
	var actor: RallyPlayerState = _script_states[int(action.actor)]
	var attacking_negative_y := actor.team_side == SIDE_HOME
	var approach: Dictionary = opportunity.get("approach_profile", {})
	var contact_height := float(opportunity.contact_height_meters)
	geometric_rng.seed = hash("%d|scripted-attack|%d" % [rally_seed, index])
	var draws := GeometricAttackPromotionModel.draws(geometric_rng, block_actions.size(), 0)
	var aggression := float(action.get("aggression", 0.5))
	var attack_type := str(action.get("attack_action", "Power swing"))
	var tactical_call := str(action.get("course", ""))
	var lane := _lane_for_target(Vector2(action.target))
	var approach_quality := maxf(float(approach.get(
		"runup_quality", opportunity.physical_feasibility)), 0.05)
	## Resolve once against open court to expose the untouched attack flight. Block
	## intentions then establish physically reachable hands on that flight; the
	## exact same draws are replayed with that wall so no random stream is consumed.
	var open_swing := GeometricAttackResolverModel.resolve_swing(
		actor.player, Vector2(opportunity.contact_position), contact_height,
		lane, [], [], attacking_negative_y, approach_quality, aggression,
		float(actor.player.match_confidence), 0.0, draws, attack_type, tactical_call)
	if not bool(open_swing.get("available", false)):
		last_refusal = "action %d did not reach the production attack resolver" % index
		return {}
	var probe_flight := _attack_free_flight(open_swing, opportunity, index)
	var blocking_side := _opposite_side(actor.team_side)
	var formation := _block_formation(block_actions, probe_flight, blocking_side)
	var wall := GeometricAttackPromotionModel.block_wall(
		formation, _position_map_for_side(blocking_side),
		_position_map_for_side(blocking_side),
		str(formation.get("block_intent", "Balanced")), 0.0)
	var swing := GeometricAttackResolverModel.resolve_swing(
		actor.player, Vector2(opportunity.contact_position), contact_height,
		lane, wall, [], attacking_negative_y, approach_quality, aggression,
		float(actor.player.match_confidence), 0.0, draws, attack_type, tactical_call)
	var record := _geometric_swing_record(swing, String(actor.team_side))
	if not bool(record.get("available", false)):
		last_refusal = "action %d attack produced no production continuation" % index
		return {}
	var outgoing := _attack_free_flight(swing, opportunity, index)
	if outgoing.is_empty():
		last_refusal = "action %d attack produced no production flight" % index
		return {}
	_add_event(
		result, RallyEventModel.EventType.ATTACK, actor.player_id, actor.player.display_name,
		Vector2(opportunity.contact_position), Vector2(record.landing), true,
		float(record.quality), "%s attempts %s" % [actor.player.display_name, attack_type], "",
		_contact_metadata(action, index, float(opportunity.contact_time), contact_height,
			incoming, outgoing, {
				"side": String(actor.team_side), "attack_type": attack_type,
				"intended_target": Vector2(action.target),
				"actual_landing": Vector2(record.landing), "geometric_attack": record,
				"body_contact_position": Vector2(opportunity.body_contact_position),
				"jump_multiplier": float(approach.get("jump_multiplier", 1.0)),
			}),
	)
	_record_intent(index, action, "contacted", "", float(opportunity.contact_time), contact_height)
	return _publish_block_consequences(result, block_actions, formation, record, outgoing, index + 1)


func _block_formation(
	actions: Array[Dictionary], attack_flight: Dictionary, blocking_side: StringName,
) -> Dictionary:
	var formation := {"read_quality": 1.0, "block_intent": "Balanced"}
	var role_index := 0
	for action in actions:
		var actor: RallyPlayerState = _script_states.get(int(action.actor))
		if actor == null or actor.team_side != blocking_side:
			continue
		var scan := FreeFlightInterceptionModel.opportunities(
			attack_flight, [actor], &"block", true, [], null, NAN, true,
			float(action.intent_time), false)
		var opportunity: Dictionary = Dictionary(
			Dictionary(scan.get("opportunities", {})).get(actor.player_id, {}))
		var role := "primary" if role_index == 0 else "assist"
		formation[role] = actor.player
		formation["%s_close" % role] = 1.0 if not opportunity.is_empty() else 0.0
		formation["%s_net_x" % role] = float(Vector2(
			opportunity.get("contact_position", actor.position)).x)
		formation["%s_opportunity" % role] = opportunity
		formation["block_intent"] = str(action.get("block_intent", "Balanced"))
		role_index += 1
		if role_index >= 2:
			break
	return formation


func _publish_block_consequences(
	result: Resource, actions: Array[Dictionary], formation: Dictionary,
	record: Dictionary, attack_flight: Dictionary, first_index: int,
) -> Dictionary:
	var contact_kind := str(record.get("block_contact_kind", ""))
	var contact_actor_id := int(record.get("block_contact_actor_id", -1))
	var current_flight := attack_flight
	var block_contact_time := NAN
	var block_contact_position := Vector2.ZERO
	var block_incoming := {}
	if not contact_kind.is_empty():
		var crossing := FreeFlightInterceptionModel.net_crossing(attack_flight)
		if not crossing.is_empty():
			block_contact_time = float(crossing.time)
			block_contact_position = Vector2(crossing.position)
			block_incoming = FreeFlightInterceptionModel.realised_prefix(attack_flight, block_contact_time)
			_truncate_previous_contact(result, block_incoming)
			current_flight = _block_deflection_free_flight(record, crossing, first_index)
	for offset in actions.size():
		var action := actions[offset]
		var actor: RallyPlayerState = _script_states.get(int(action.actor))
		if actor == null:
			continue
		var touched := actor.player_id == contact_actor_id and not contact_kind.is_empty()
		var role := "primary" if offset == 0 else "assist"
		var opportunity: Dictionary = formation.get("%s_opportunity" % role, {})
		var metadata := {
			"script_action_index": first_index + offset,
			"intent_time": float(action.intent_time), "physical_contact": touched,
			"side": String(actor.team_side),
			"block_contact_kind": contact_kind if touched else "",
			"block_miss_reason": str(record.get("block_miss_reason", "")),
			"body_contact_position": Vector2(opportunity.get("body_contact_position", actor.position)),
		}
		var resolved_time := block_contact_time if touched else NAN
		var height := float(block_incoming.get("end_height_meters", NAN)) if touched else NAN
		if touched:
			metadata["resolved_contact_time"] = resolved_time
			metadata["contact_height_meters"] = height
			metadata["incoming_trajectory"] = block_incoming
			metadata["outgoing_trajectory"] = current_flight
		_add_event(
			result, RallyEventModel.EventType.BLOCK, actor.player_id, actor.player.display_name,
			block_contact_position if touched else Vector2(opportunity.get("contact_position", actor.position)),
			Vector2(current_flight.get("end_position", actor.position)), touched,
			float(record.get("quality", 0.0)), "%s attempts a block" % actor.player.display_name,
			"", metadata)
		_record_intent(first_index + offset, action, "contacted" if touched else "missed",
			"" if touched else "the attack did not meet this wall", resolved_time, height)
	if contact_kind.is_empty():
		_expected_families = [&"dig"]
		_expected_side = _opposite_side(_expected_side)
	elif contact_kind == "recycle":
		_expected_families = [&"cover"]
		_expected_side = _opposite_side(_script_states[contact_actor_id].team_side)
	elif contact_kind == "touch":
		_expected_families = [&"dig"]
		_expected_side = _script_states[contact_actor_id].team_side
	else:
		_expected_families = []
		result.terminal_outcome = "scripted_block_%s" % contact_kind
		return {"authoritative_free_flight": {}}
	return {"authoritative_free_flight": current_flight}


func _attack_free_flight(swing: Dictionary, opportunity: Dictionary, index: int) -> Dictionary:
	var delivered: Dictionary = swing.get("delivered", {})
	var course: Dictionary = swing.get("course", {})
	var speed := float(delivered.get("speed_mps", 0.0))
	var angle := float(delivered.get("vertical_angle_degrees", 0.0))
	if speed <= 0.0:
		return {}
	var actor: RallyPlayerState = _script_states[int(opportunity.player_id)]
	var direction := AttackCourseModelRef.direction_meters(
		float(course.get("bearing_degrees", 0.0)), actor.team_side == SIDE_HOME)
	var radians := deg_to_rad(angle)
	return FreeFlightInterceptionModel.from_launch(
		"attack", Vector2(opportunity.contact_position), float(opportunity.contact_height_meters),
		Vector3(direction.x * speed * cos(radians), speed * sin(radians),
			direction.y * speed * cos(radians)), float(opportunity.contact_time),
		"%d:scripted-attack:%d" % [rally_seed, index])


func _block_deflection_free_flight(record: Dictionary, crossing: Dictionary, index: int) -> Dictionary:
	var speed := float(record.get("block_deflection_speed_mps", 0.0))
	var angle := float(record.get("block_deflection_vertical_angle_degrees", 0.0))
	var landing_value: Variant = record.get("block_deflection_landing", null)
	if speed <= 0.0 or not landing_value is Vector2:
		return {}
	var from := Vector2(crossing.position)
	var delta := RallyKinematics.court_delta_meters(from, Vector2(landing_value))
	var direction := delta.normalized() if delta.length_squared() > 0.0001 else Vector2(0.0, 1.0)
	var radians := deg_to_rad(angle)
	return FreeFlightInterceptionModel.from_launch(
		"block_deflection", from, float(crossing.height_meters),
		Vector3(direction.x * speed * cos(radians), speed * sin(radians),
			direction.y * speed * cos(radians)), float(crossing.time),
		"%d:scripted-block:%d" % [rally_seed, index])


func _free_flight_between(
	kind: String, start: Vector2, target: Vector2, start_height: float,
	end_height: float, duration: float, start_time: float, key: String,
) -> Dictionary:
	var safe_duration := maxf(duration, BallFlightModel.MIN_FLIGHT_DURATION)
	var delta := RallyKinematics.court_delta_meters(start, target)
	var horizontal := delta / safe_duration
	var vertical := BallFlightModel.rise_speed_between(start_height, end_height, safe_duration)
	return FreeFlightInterceptionModel.from_launch(
		kind, start, start_height, Vector3(horizontal.x, vertical, horizontal.y),
		start_time, "%d:scripted-%s" % [rally_seed, key])


func _truncate_previous_contact(result: Resource, incoming: Dictionary) -> void:
	for index in range(result.events.size() - 1, -1, -1):
		var event: Resource = result.events[index]
		if bool(event.metadata.get("physical_contact", false)):
			event.metadata["outgoing_trajectory"] = incoming
			event.end_position = Vector2(incoming.end_position)
			return


func _publish_uncontrolled_terminal(
	result: Resource, flight: Dictionary, action: Dictionary, index: int,
) -> void:
	var scan := FreeFlightInterceptionModel.opportunities(
		flight, [], &"dig", false, [], null, NAN, true)
	var terminal: Dictionary = scan.get("terminal", {})
	if not result.events.is_empty() and not terminal.is_empty():
		var realised := FreeFlightInterceptionModel.realised_prefix(flight, float(terminal.time))
		_truncate_previous_contact(result, realised)
	result.terminal_outcome = "scripted_uncontrolled_%s" % str(terminal.get("reason", "flight"))
	result.ending_reason = &"scripted_intent_missed"
	result.analysis["unresolved_action_index"] = index
	result.analysis["unresolved_actor_id"] = int(action.actor)


func _contact_metadata(
	action: Dictionary, index: int, resolved_time: float, contact_height: float,
	incoming: Dictionary, outgoing: Dictionary, extra: Dictionary = {},
) -> Dictionary:
	var metadata := {
		"script_action_index": index, "intent_time": float(action.intent_time),
		"resolved_contact_time": resolved_time,
		"contact_height_meters": contact_height, "physical_contact": true,
		"incoming_trajectory": incoming, "outgoing_trajectory": outgoing,
	}
	metadata.merge(extra, true)
	return metadata


func _record_intent(
	index: int, action: Dictionary, status: String, reason: String,
	resolved_time: float = NAN, contact_height: float = NAN,
) -> void:
	var record := {
		"action_index": index, "actor": int(action.actor),
		"action": String(action.action), "intent_time": float(action.intent_time),
		"status": status, "reason": reason,
	}
	if not is_nan(resolved_time):
		record["resolved_contact_time"] = resolved_time
	if not is_nan(contact_height):
		record["contact_height_meters"] = contact_height
	_intent_records.append(record)


func _target_actor(target: Variant) -> VolleyballPlayer:
	if not target is int:
		return null
	var state: RallyPlayerState = _script_states.get(int(target))
	return state.player if state != null else null


func _target_position(target: Variant) -> Vector2:
	if target is Vector2:
		return Vector2(target)
	var state: RallyPlayerState = _script_states.get(int(target))
	return state.position if state != null else Vector2(0.5, 0.5)


func _position_map_for_side(side: StringName) -> Dictionary:
	var positions := {}
	for raw_id in _script_states:
		var actor: RallyPlayerState = _script_states[raw_id]
		if actor.team_side == side:
			positions[int(raw_id)] = actor.position
	return positions


static func _opposite_side(side: StringName) -> StringName:
	return SIDE_OPPONENT if side == SIDE_HOME else SIDE_HOME


static func _lane_for_target(target: Vector2) -> String:
	if target.x < 0.34:
		return "Left Pin"
	if target.x > 0.66:
		return "Right Pin"
	return "Middle"
