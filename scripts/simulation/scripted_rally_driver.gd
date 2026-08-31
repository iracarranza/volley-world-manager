class_name ScriptedRallyDriver
extends RallySimulator

const ACTIONS: Array[StringName] = [
	&"serve", &"receive", &"set", &"attack", &"block", &"dig", &"cover",
]
const ACTION_KEYS: Array[String] = [
	"actor", "action", "target", "time", "contact_height_m", "draws",
	"quality_override", "note",
]
const DRAW_KEYS: Array[String] = ["bearing", "vertical", "power"]

## Intent adapter over production resolution. It supplies decisions; production
## still owns movement, contacts, legality, quality terms and every ball flight.
## Omitted draws are zero-sigma samples: median execution, not perfect quality.
var last_refusal: String = ""


## Return the first stable schema refusal, or an empty string when accepted.
static func validate(script: Dictionary) -> String:
	var positions: Dictionary = script.get("initial_positions", {})
	if positions.size() != 12:
		return "initial_positions must contain exactly 12 volis"
	var ids: Dictionary = {}
	for raw_id: Variant in positions:
		if not (raw_id is int) or int(raw_id) < 0:
			return "initial_positions contains an invalid voli id"
		ids[int(raw_id)] = true
		var point: Variant = positions[raw_id]
		## UNRESOLVED_SLOT_POSITION is a diagnostic emitted by production for a
		## missing rotation slot, not a place an author may deliberately start.
		if not (point is Vector2) or not CourtConstants.is_normalized(point):
			return "initial position for voli %s is outside normalized court" % raw_id
	var actions: Variant = script.get("actions", [])
	if not (actions is Array) or actions.is_empty():
		return "actions must contain at least one authored contact"
	if StringName(Dictionary(actions[0]).get("action", &"")) != &"serve":
		return "the first action must be the serve"
	var previous_time := -INF
	for index in actions.size():
		if not (actions[index] is Dictionary):
			return "action %d must be a dictionary" % index
		var action: Dictionary = actions[index]
		for key in action:
			if not str(key) in ACTION_KEYS:
				return "action %d has an unknown key '%s'" % [index, str(key)]
		var family := StringName(action.get("action", &""))
		if family not in ACTIONS:
			return "action %d has unsupported action '%s'" % [index, family]
		if not (action.get("actor", null) is int) or not ids.has(int(action.actor)):
			return "action %d names an unknown actor" % index
		var target: Variant = action.get("target", null)
		if target is int:
			if not ids.has(int(target)):
				return "action %d names an unknown target voli" % index
		elif not (target is Vector2) or not CourtConstants.is_normalized(target):
			return "action %d target must be a voli id or normalized court coordinate" % index
		var at: Variant = action.get("time", null)
		if not (at is float or at is int) or not is_finite(float(at)):
			return "action %d has an invalid time" % index
		## Equal times are legal only for a block responding to the immediately
		## preceding attack: the two hands may touch the same ball at one instant.
		if float(at) < previous_time or (is_equal_approx(float(at), previous_time) \
				and family != &"block"):
			return "action %d must occur after the previous contact" % index
		if family == &"block" and index > 0 and is_equal_approx(float(at), previous_time) \
				and StringName(Dictionary(actions[index - 1]).get("action", &"")) != &"attack":
			return "action %d may share time only with the preceding attack" % index
		previous_time = float(at)
		var height: Variant = action.get("contact_height_m", null)
		if not (height is float or height is int) or float(height) < 0.0:
			return "action %d must declare a non-negative contact_height_m" % index
		var draws: Variant = action.get("draws", {})
		if not (draws is Dictionary):
			return "action %d draws must be a dictionary" % index
		for draw_key in draws:
			if not str(draw_key) in DRAW_KEYS:
				return "action %d draws an unknown channel '%s'" % [index, str(draw_key)]
		if action.has("quality_override"):
			var quality: Variant = action.quality_override
			if not (quality is float or quality is int) or float(quality) < 0.0 or float(quality) > 1.0:
				return "action %d quality_override must be between 0 and 1" % index
	return _validate_paths(script.get("movement", []), ids)


static func _validate_paths(raw_paths: Variant, ids: Dictionary) -> String:
	if not (raw_paths is Array):
		return "movement must be an array"
	for index in raw_paths.size():
		if not (raw_paths[index] is Dictionary):
			return "movement %d must be a dictionary" % index
		var path: Dictionary = raw_paths[index]
		if not (path.get("actor", null) is int) or not ids.has(int(path.actor)):
			return "movement %d names an unknown actor" % index
		var start: Variant = path.get("start_time", null)
		var finish: Variant = path.get("end_time", null)
		if not (start is float or start is int) or not (finish is float or finish is int) \
				or not is_finite(float(start)) or not is_finite(float(finish)) or float(finish) <= float(start):
			return "movement %d must have a finite positive interval" % index
		var target: Variant = path.get("target", null)
		if not (target is Vector2) or not CourtConstants.is_normalized(target):
			return "movement %d target is outside normalized court" % index
	return ""


## Audit resolved/saved contact records, never authored intent. Each entry must
## publish its outgoing production flight; adjacent flights must share the exact
## contact boundary in court position, height, and time.
static func seam_census(records: Array) -> String:
	for index in records.size():
		if not (records[index] is Dictionary):
			return "record %d must be a dictionary" % index
		var outgoing: Dictionary = Dictionary(records[index]).get("outgoing", {})
		if outgoing.is_empty():
			return "record %d has no outgoing production flight" % index
		if index == 0:
			continue
		var incoming: Dictionary = Dictionary(records[index]).get("incoming", {})
		var previous: Dictionary = Dictionary(records[index - 1]).get("outgoing", {})
		if incoming.is_empty():
			return "record %d has no incoming production flight" % index
		if Vector2(previous.get("end_position", Vector2.INF)) != Vector2(
				incoming.get("end_position", Vector2.INF)) \
				or not is_equal_approx(float(previous.get("end_time", NAN)), float(
					incoming.get("end_time", NAN)
				)) \
				or not is_equal_approx(float(previous.get("end_height_meters", NAN)), float(
					incoming.get("end_height_meters", NAN)
				)):
			return "record %d incoming flight differs from the saved previous flight" % index
		if Vector2(incoming.get("end_position", Vector2.INF)) != Vector2(
				outgoing.get("start_position", Vector2.INF)) \
				or not is_equal_approx(float(incoming.get("end_time", NAN)), float(
					outgoing.get("start_time", NAN)
				)) \
				or not is_equal_approx(float(incoming.get("end_height_meters", NAN)), float(
					outgoing.get("start_height_meters", NAN)
				)):
			return "record %d breaks the contact flight seam" % index
	return ""


## The draws a contact states, with the median for anything it does not.
static func _draws(contact: Dictionary) -> Dictionary:
	var stated := Dictionary(contact.get("draws", {}))
	return {
		"bearing": float(stated.get("bearing", 0.0)),
		"vertical": float(stated.get("vertical", 0.0)),
		"power": float(stated.get("power", 0.0)),
	}


## Walk a script and return the rally it produces.
##
## The context arguments are the ones a live rally takes, because the resolvers
## read them: a serve needs a server with real attributes, a platform contact
## needs the passer's stability and technique. Only the *decisions* are replaced.
func resolve_script(
	script: Dictionary,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int = 1,
) -> Resource:
	last_refusal = validate(script)
	var refusal := last_refusal
	var contacts: Array = script.get("actions", [])
	if not refusal.is_empty():
		return null
	rally_seed = seed_value
	rng.seed = seed_value
	geometric_rng.seed = seed_value
	var result: Resource = RallyResultModel.new()
	_seed_positions(
		players, lineup, opponent_team, defensive_plan, home_serving,
		Dictionary(script.initial_positions),
	)

	var serve := Dictionary(contacts[0])
	var served := _script_serve(result, serve, players, opponent_team, home_serving)
	if served.is_empty():
		return result
	if contacts.size() < 2:
		return result
	var received := _script_reception(
		result, Dictionary(contacts[1]), players, opponent_team, served
	)
	if received.is_empty():
		return result
	if contacts.size() > 2:
		## Never pretend an unexecuted tail happened. The next slice must hand
		## each family to its production resolver before this gate is removed.
		last_refusal = "action 2 has not reached a production resolver"
	return result


## The authored serve, through the production launch search.
func _script_serve(
	result: Resource,
	contact: Dictionary,
	players: Array[VolleyballPlayer],
	opponent_team: Resource,
	home_serving: bool,
) -> Dictionary:
	var server: VolleyballPlayer = _script_actor(
		int(contact.actor), players, opponent_team
	)
	if server == null:
		last_refusal = "no actor %d for the serve" % int(contact.actor)
		return {}
	var origin := CourtConstants.serve_origin(0.82, home_serving)
	var aim := Vector2(contact.get("target", Vector2(0.5, 0.75)))
	var contact_height := float(contact.contact_height_m)
	var serve: Dictionary = GeometricAttackResolverModel.resolve_serve(
		server, origin, contact_height, aim, home_serving, 0.5,
		_draws(contact), _serve_spin(server),
	)
	if not bool(serve.get("available", false)):
		last_refusal = "the authored serve is not available: %s" % str(serve.get("reason", "unstated"))
		return {}
	var launch: Dictionary = serve.launch
	var horizontal := maxf(
		float(launch.get("horizontal_speed_mps", 0.0)),
		BallFlightModel.MIN_SPEED_MPS,
	)
	var direction := AttackCourseModelRef.direction_meters(
		float(launch.get("bearing_degrees", 0.0)), home_serving
	)
	var free_flight := FreeFlightInterceptionModel.from_launch(
		"serve", origin, contact_height,
		Vector3(
			direction.x * horizontal,
			float(launch.get("vertical_speed_mps", 0.0)),
			direction.y * horizontal,
		),
		0.0, "%d:scripted-serve:%d" % [rally_seed, server.id],
		float(launch.get("gravity_mps2", BallFlightModel.DEFAULT_GRAVITY_MPS2)),
	)
	if free_flight.is_empty():
		last_refusal = "the authored serve produced no flight"
		return {}
	return {
		"server": server,
		"origin": origin,
		"free_flight": free_flight,
		"landing": Vector2(serve.landing),
		"outcome": str(serve.outcome),
		"result_event_pending": true,
	}


## The voli this contact names, on whichever side of the net they are.
##
## A script says "actor 105" and does not say which roster that is, because the
## author is looking at a court rather than at two arrays.
func _script_actor(
	actor_id: int,
	players: Array[VolleyballPlayer],
	opponent_team: Resource,
) -> VolleyballPlayer:
	var home := _player_by_id(players, actor_id)
	if home != null:
		return home
	if opponent_team == null:
		return null
	for raw in opponent_team.on_court_players():
		var candidate: VolleyballPlayer = raw as VolleyballPlayer
		if candidate != null and int(candidate.id) == actor_id:
			return candidate
	return null


## Both sides standing where a rally would start them.
##
## The same two calls `resolve` makes. A script that does not say where anybody
## stands still gets a legal court rather than everyone at the origin, and a
## later slice can let a contact override one voli without inventing the rest.
func _seed_positions(
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	authored_positions: Dictionary,
) -> void:
	live_positions = _initial_home_positions(
		lineup, defensive_plan, not home_serving, true, players
	)
	opponent_live_positions = _initial_opponent_positions(
		opponent_team, home_serving, true
	)
	for raw_id: Variant in authored_positions:
		var actor_id := int(raw_id)
		if live_positions.has(actor_id):
			live_positions[actor_id] = Vector2(authored_positions[raw_id])
		elif opponent_live_positions.has(actor_id):
			opponent_live_positions[actor_id] = Vector2(authored_positions[raw_id])


## The authored reception: this passer, meeting that serve, aiming there.
##
## The passer is stated, so no claim search runs. Everything after that is the
## production path -- the serve is sliced where it descends to this body's own
## platform height, `PlatformContactModel` decides what a platform can do with
## the ball arriving at that speed, and the outgoing ball is a free flight. The
## script supplies the intent the live rally would have derived from a defensive
## plan, and nothing else.
func _script_reception(
	result: Resource,
	contact: Dictionary,
	players: Array[VolleyballPlayer],
	opponent_team: Resource,
	served: Dictionary,
) -> Dictionary:
	var receiver: VolleyballPlayer = _script_actor(
		int(contact.actor), players, opponent_team
	)
	if receiver == null:
		last_refusal = "no actor %d for the reception" % int(contact.actor)
		return {}
	var free_flight: Dictionary = served.free_flight
	var platform_height := float(contact.contact_height_m)
	var descent := FreeFlightInterceptionModel.descent_to_height(
		free_flight, platform_height
	)
	if not bool(descent.get("available", false)):
		last_refusal = "the authored serve never descends to %.2f m" % platform_height
		return {}
	var contact_time := float(descent.contact_time)
	var contact_position := Vector2(descent.contact_position)
	var realised := FreeFlightInterceptionModel.realised_prefix(
		free_flight, contact_time
	)
	var incoming := PlatformContactModel.incoming_velocity_at_contact(
		realised, float(descent.contact_height_meters)
	)
	if not bool(incoming.get("available", false)):
		last_refusal = "the sliced serve states no incoming velocity"
		return {}
	var aim := Vector2(contact.get("target", Vector2(0.5, 0.60)))
	var shadow := PlatformContactModel.evaluate({
		"incoming_velocity_mps": incoming.velocity_mps,
		"contact_position": contact_position,
		"contact_height_meters": float(descent.contact_height_meters),
		## Stated as planted until a script can say otherwise. A body velocity
		## and a severity are things an author will want to set, and inventing
		## values for them here would be authoring the very thing this is meant
		## to make explicit.
		"body_velocity_mps": Vector2.ZERO,
		"circumstance_severity": 0.0,
		"stability_ability": (
			_rating(receiver, "reception_balance")
			+ _rating(receiver, "reception_stability")
		) * 0.5,
		"technique_ability": (
			_rating(receiver, "reception") + _rating(receiver, "ball_control")
		) * 0.5,
		"intent_target_anchor": aim,
		"intent_height_anchor_meters": float(contact.get("contact_height_m", 2.40)),
		"intent_arrival_floor_seconds": 0.0,
		"seed": hash("%d|scripted-reception|%d" % [rally_seed, receiver.id]),
	})
	if not bool(shadow.get("selection_available", false)):
		last_refusal = "the platform refused the authored reception"
		return {}
	var pass_flight := FreeFlightInterceptionModel.from_launch(
		"reception_pass", contact_position,
		float(descent.contact_height_meters),
		Vector3(shadow.realised_velocity_mps), contact_time,
		"%d:scripted-reception:%d" % [rally_seed, receiver.id],
	)
	return {
		"receiver": receiver,
		"realised_incoming": realised,
		"free_flight": pass_flight,
		"contact_time": contact_time,
		"contact_position": contact_position,
		"contact_height_meters": float(descent.contact_height_meters),
		"target_error_meters": float(
			Dictionary(shadow.realised).get("horizontal_error_meters", 0.0)
		),
	}


## Median intent fidelity, not the source of overall determinism. The production
## rally seeds its RNG and contains many other seeded draws; this override removes
## only contact scatter that would alter an explicitly authored action.
func _execution_error(
	_player: VolleyballPlayer,
	_control_attribute: String,
	_base_spread: float,
) -> float:
	return 0.0
