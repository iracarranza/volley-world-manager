class_name OverpassActionSystem
extends RefCounted

## An overpass is the receiving side's ordinary first-team-contact decision.
## This layer owns neither the incoming launch nor new contact physics. It asks
## the shared free-flight system which actions are physically reachable, applies
## rotation legality, and ranks the remaining actions from existing player and
## tactical state.

const FreeFlight := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)
const PlatformContact := preload(
	"res://scripts/simulation/platform_contact_model.gd"
)
const DecisionSystem := preload(
	"res://scripts/simulation/rally_decision_system.gd"
)
const GeometricAttackResolver := preload(
	"res://scripts/simulation/geometric_attack_resolver.gd"
)
const GeometricAttackPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)
const AttackCourse := preload(
	"res://scripts/simulation/attack_course_model.gd"
)
const BallTrajectoryModel := preload("res://scripts/models/ball_trajectory.gd")


static func choose(
	free_flight: Dictionary,
	actors: Array[RallyPlayerState],
	lineup: RotationLineup,
	side: StringName,
	principles: Resource,
) -> Dictionary:
	var crossing := FreeFlight.net_crossing(free_flight)
	if str(crossing.get("reason", "")) != "crossed_net_unresolved":
		return {"available": false, "reason": "flight is not a legal overpass"}
	var search_time := float(crossing.get("time", NAN))
	var control_physical := FreeFlight.opportunities(
		free_flight, actors, &"receive", false, [], null, NAN,
		true, search_time, false,
	)
	var attack_physical := FreeFlight.opportunities(
		free_flight, actors, &"attack", true, [], null, NAN,
		true, search_time, true,
	)
	var candidates: Array[Dictionary] = []
	var control_by_actor: Dictionary = control_physical.get("opportunities", {})
	var attack_by_actor: Dictionary = attack_physical.get("opportunities", {})
	for actor in actors:
		if actor == null or actor.player == null:
			continue
		var perception := _mean([
			_rating(actor.player, "anticipation"),
			_rating(actor.player, "court_vision"),
		])
		if control_by_actor.has(actor.player_id):
			var control: Dictionary = control_by_actor[actor.player_id]
			var contact_forms := DecisionSystem.available_first_contact_actions(
				actor.player, control, perception
			)
			## A quick overhead release is deliberately absent. The current set
			## resolver assumes second-contact hitter selection and contact state;
			## hand shape alone cannot relabel this first contact as SET.
			var control_action := ""
			if "safe_center_pass" in contact_forms:
				control_action = "controlled_first_contact"
			elif "emergency_keep_alive" in contact_forms:
				control_action = "emergency_first_contact"
			if not control_action.is_empty():
				candidates.append(_control_candidate(
					actor, control, control_action, perception, principles
				))
		if attack_by_actor.has(actor.player_id):
			var attack: Dictionary = attack_by_actor[actor.player_id]
			if _attack_legal(actor, attack, lineup, side):
				candidates.append(_attack_candidate(
					actor, attack, perception, principles
				))
	if candidates.is_empty():
		return {
			"available": false,
			"reason": "no physically and legally feasible first contact",
			"terminal": control_physical.get("terminal", {}),
			"authoritative_free_flight": free_flight,
			"net_crossing": crossing,
		}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) > float(b.score)
		if int(a.player_id) != int(b.player_id):
			return int(a.player_id) < int(b.player_id)
		return str(a.action) < str(b.action)
	)
	var selected := candidates[0].duplicate(true)
	selected["available"] = true
	selected["candidates"] = _public_candidates(candidates)
	selected["authoritative_free_flight"] = free_flight
	selected["net_crossing"] = crossing
	selected["terminal"] = control_physical.get("terminal", {})
	selected["realised_trajectory"] = FreeFlight.realised_prefix(
		free_flight, float(selected.contact_time)
	)
	return selected


static func execute_control(
	choice: Dictionary,
	intent: Dictionary,
	seed_value: int,
) -> Dictionary:
	if str(choice.get("action", "")) not in [
		"controlled_first_contact", "emergency_first_contact",
	]:
		return {"available": false, "reason": "choice is not platform control"}
	var player := choice.get("player") as VolleyballPlayer
	var incoming_flight: Dictionary = choice.get("authoritative_free_flight", {})
	if player == null or incoming_flight.is_empty():
		return {"available": false, "reason": "missing player or incoming flight"}
	var target_value: Variant = intent.get("target_anchor", null)
	var height_value: Variant = intent.get("height_anchor_meters", null)
	if not target_value is Vector2 or not _is_number(height_value):
		return {"available": false, "reason": "first-contact intent incomplete"}
	var contact_time := float(choice.get("contact_time", 0.0))
	var incoming_velocity := FreeFlight.velocity_at_time(
		incoming_flight, contact_time
	)
	var severity := 1.0 - minf(
		clampf(float(choice.get("arrival_balance", 0.0)), 0.0, 1.0),
		clampf(float(choice.get("physical_feasibility", 0.0)), 0.0, 1.0),
	)
	var resolved := PlatformContact.evaluate({
		"incoming_velocity_mps": incoming_velocity,
		"contact_position": Vector2(choice.contact_position),
		"contact_height_meters": float(choice.contact_height_meters),
		"body_velocity_mps": _body_velocity(choice),
		"circumstance_severity": severity,
		"stability_ability": _mean([
			_rating(player, "reception_balance"),
			_rating(player, "reception_stability"),
		]),
		"technique_ability": _mean([
			_rating(player, "reception"), _rating(player, "ball_control"),
		]),
		"intent_target_anchor": Vector2(target_value),
		"intent_height_anchor_meters": float(height_value),
		"intent_arrival_floor_seconds": float(intent.get(
			"arrival_floor_seconds", 0.0
		)),
		"seed": seed_value,
	})
	if not bool(resolved.get("selection_available", false)) \
			or not resolved.has("realised_velocity_mps"):
		return {
			"available": false,
			"reason": str(resolved.get("reason", "platform launch unavailable")),
			"platform_contact": resolved,
		}
	var outgoing := FreeFlight.from_launch(
		"first_contact", Vector2(choice.contact_position),
		float(choice.contact_height_meters),
		Vector3(resolved.realised_velocity_mps), contact_time,
		"%s:overpass-control:%d:%.6f" % [
			str(choice.get("side", "")), int(choice.player_id), contact_time,
		],
	)
	return {
		"available": not outgoing.is_empty(),
		"action": str(choice.action),
		"actor_id": int(choice.player_id),
		"outgoing_trajectory": outgoing,
		"platform_contact": resolved,
		"team_contact_number": 1,
	}


static func execute_attack(
	choice: Dictionary,
	blockers: Array,
	defenders: Array,
	team_decisiveness: float,
	flow_for_team: float,
	seed_value: int,
) -> Dictionary:
	if str(choice.get("action", "")) != "attack":
		return {"available": false, "reason": "choice is not attack"}
	var hitter := choice.get("player") as VolleyballPlayer
	if hitter == null:
		return {"available": false, "reason": "missing hitter"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var approach: Dictionary = choice.get("approach_profile", {})
	var attacking_negative_y := StringName(choice.get("side", &"home")) == &"home"
	var swing := GeometricAttackResolver.resolve_swing(
		hitter, Vector2(choice.contact_position),
		float(choice.contact_height_meters),
		CourtConstants.lane_at_x(float(Vector2(choice.contact_position).x)),
		blockers, defenders, attacking_negative_y,
		clampf(float(approach.get("runup_quality", 0.0)), 0.0, 1.0),
		clampf(team_decisiveness, 0.0, 1.0),
		float(hitter.match_confidence), flow_for_team,
		GeometricAttackPromotion.draws(rng, blockers.size(), defenders.size()),
	)
	if not bool(swing.get("available", false)):
		return {
			"available": false,
			"reason": str(swing.get("reason", "attack unavailable")),
		}
	var delivered: Dictionary = swing.get("delivered", {})
	var speed := float(delivered.get("speed_mps", 0.0))
	var angle := deg_to_rad(float(delivered.get(
		"vertical_angle_degrees", 0.0
	)))
	var ground_direction := AttackCourse.direction_meters(
		float(delivered.get("bearing_degrees", 0.0)), attacking_negative_y
	).normalized()
	var horizontal_speed := speed * cos(angle)
	var velocity := Vector3(
		ground_direction.x * horizontal_speed,
		speed * sin(angle),
		ground_direction.y * horizontal_speed,
	)
	var outgoing := FreeFlight.from_launch(
		"attack", Vector2(choice.contact_position),
		float(choice.contact_height_meters), velocity,
		float(choice.contact_time),
		"%s:overpass-attack:%d:%.6f" % [
			str(choice.get("side", "")), int(choice.player_id),
			float(choice.contact_time),
		],
	)
	return {
		"available": not outgoing.is_empty(),
		"action": "attack",
		"actor_id": int(choice.player_id),
		"outgoing_trajectory": outgoing,
		"swing": swing,
		"team_contact_number": 1,
	}


## Apply the selected first contact to persistent rally state. Crossing the net
## changes possession, so `register_contact()` resets the receiving team's count
## to one regardless of whether the chosen form was attack or platform control.
static func apply_first_contact(
	state: RallyState,
	side: StringName,
	choice: Dictionary,
	execution: Dictionary,
) -> Dictionary:
	if state == null or not bool(execution.get("available", false)):
		return {"applied": false, "reason": "missing state or outgoing ball"}
	var actor_id := int(choice.get("player_id", -1))
	var actor := state.player_state(side, actor_id)
	if actor == null:
		return {"applied": false, "reason": "selected actor missing from state"}
	var trajectory_data: Dictionary = execution.get("outgoing_trajectory", {})
	if trajectory_data.is_empty():
		return {"applied": false, "reason": "outgoing trajectory missing"}
	var contact_time := float(choice.get("contact_time", state.simulation_time))
	actor.movement_mode = RallyPlayerState.MovementMode.APPROACH \
		if str(choice.get("action", "")) == "attack" \
		else RallyPlayerState.MovementMode.LATERAL
	actor.apply_position(
		Vector2(choice.get("body_contact_position", actor.position)),
		_body_velocity(choice),
	)
	actor.body_state = RallyPlayerState.BodyState.AIRBORNE \
		if bool(choice.get("requires_jump", false)) \
		else RallyPlayerState.BodyState.REACHING
	actor.balance = clampf(float(choice.get("arrival_balance", 0.0)), 0.0, 1.0)
	actor.last_contact_time = contact_time
	state.advance_to(contact_time)
	state.register_contact(side, actor_id)
	var trajectory := BallTrajectoryModel.from_dict(trajectory_data)
	state.ball.launch(trajectory, side, actor_id, state.contact_number)
	return {
		"applied": true,
		"actor_id": actor_id,
		"action": str(choice.get("action", "")),
		"team_contact_number": state.contact_number,
		"ball_contact_count": state.ball.contact_count,
		"ball_last_touch_side": state.ball.last_touch_side,
		"outgoing_flight_id": str(trajectory_data.get(
			"authoritative_flight_id", ""
		)),
	}


static func _control_candidate(
	actor: RallyPlayerState,
	opportunity: Dictionary,
	action: String,
	perception: float,
	principles: Resource,
) -> Dictionary:
	var quality := _quality_center(opportunity)
	var ability := _mean([
		_rating(actor.player, "reception"),
		_rating(actor.player, "ball_control"),
		_rating(actor.player, "dig_control"),
		_rating(actor.player, "reception_balance"),
		_rating(actor.player, "reception_stability"),
	])
	var judgment := _mean([
		_rating(actor.player, "decision_making"),
		_rating(actor.player, "composure"),
	])
	var decisiveness := _principle(principles, "decisiveness", 0.5)
	var tactical_control := _mean([
		1.0 - decisiveness, _rating(actor.player, "tactical_discipline"),
	])
	var result := opportunity.duplicate(true)
	result.merge({
		"action": action,
		"side": actor.team_side,
		"score": _mean([
			quality, ability, judgment, perception, tactical_control,
			float(opportunity.get("physical_feasibility", 0.0)),
		]),
		"score_terms": {
			"expected_contact_quality": quality,
			"control_ability": ability,
			"judgment": judgment,
			"perception": perception,
			"tactical_control": tactical_control,
			"physical_feasibility": float(opportunity.get(
				"physical_feasibility", 0.0
			)),
		},
	}, true)
	return result


static func _attack_candidate(
	actor: RallyPlayerState,
	opportunity: Dictionary,
	perception: float,
	principles: Resource,
) -> Dictionary:
	var quality := _quality_center(opportunity)
	var ability := _mean([
		float(actor.player.usable_attack_power()) / 100.0,
		_rating(actor.player, "attack_accuracy"),
		_rating(actor.player, "approach_timing"),
	])
	var judgment := _mean([
		_rating(actor.player, "decision_making"),
		_rating(actor.player, "composure"),
	])
	var tactical_attack := _mean([
		_principle(principles, "decisiveness", 0.5),
		_principle(principles, "transition_commitment", 0.5),
	])
	var result := opportunity.duplicate(true)
	result.merge({
		"action": "attack",
		"side": actor.team_side,
		"score": _mean([
			quality, ability, judgment, perception, tactical_attack,
			float(opportunity.get("physical_feasibility", 0.0)),
		]),
		"score_terms": {
			"expected_contact_quality": quality,
			"attack_ability": ability,
			"judgment": judgment,
			"perception": perception,
			"tactical_attack": tactical_attack,
			"physical_feasibility": float(opportunity.get(
				"physical_feasibility", 0.0
			)),
		},
	}, true)
	return result


static func _attack_legal(
	actor: RallyPlayerState,
	opportunity: Dictionary,
	lineup: RotationLineup,
	side: StringName,
) -> bool:
	if actor == null or actor.player == null or lineup == null:
		return false
	if str(actor.player.position_role) == "Libero" \
			or str(actor.player.position_code) == "L":
		return false
	var slot := lineup.slot_for_player(actor.player_id)
	if slot < 1:
		return false
	if CourtConstants.is_front_row_slot(slot):
		return true
	## A back-row player may attack only from behind their attack line when the
	## ball is above the tape. Below it, the contact is not a back-row attack
	## fault. Body centre is used rather than ball coordinate: legality follows
	## where the player took off, not where their hand reached.
	if float(opportunity.get("contact_height_meters", 0.0)) \
			<= CourtConstants.NET_HEIGHT_METERS:
		return true
	var body := Vector2(opportunity.get(
		"body_contact_position", actor.position
	))
	return body.y >= CourtConstants.HOME_ATTACK_LINE_Y if side == &"home" \
		else body.y <= CourtConstants.OPPONENT_ATTACK_LINE_Y


static func _public_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in candidates:
		var copy := candidate.duplicate(true)
		copy.erase("player")
		copy.erase("authoritative_free_flight")
		result.append(copy)
	return result


static func _body_velocity(choice: Dictionary) -> Vector2:
	var start := Vector2(choice.get("start", choice.get(
		"body_contact_position", Vector2.ZERO
	)))
	var contact := Vector2(choice.get("body_contact_position", start))
	var travel := float(choice.get("travel_time", 0.0))
	if travel <= 0.0001:
		return Vector2.ZERO
	return Vector2(
		(contact.x - start.x) * CourtConstants.COURT_WIDTH_METERS / travel,
		(contact.y - start.y) * CourtConstants.COURT_LENGTH_METERS / travel,
	)


static func _quality_center(opportunity: Dictionary) -> float:
	var quality := Vector2(opportunity.get("expected_quality", Vector2.ZERO))
	return (quality.x + quality.y) * 0.5


static func _rating(player: VolleyballPlayer, property: String) -> float:
	if player == null:
		return 0.0
	return clampf(float(player.get(property)) / 100.0, 0.0, 1.0)


static func _principle(
	principles: Resource, property: String, fallback: float
) -> float:
	if principles == null:
		return fallback
	var value: Variant = principles.get(property)
	return fallback if value == null else clampf(float(value), 0.0, 1.0)


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
