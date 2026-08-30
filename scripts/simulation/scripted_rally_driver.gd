class_name ScriptedRallyDriver
extends RallySimulator

## NOTE authors the *inputs* to the production resolvers, never a second physics
## NOTE see docs/design/SCRIPTED_RALLY.md for the contact format and the boundary

## A rally whose contacts are stated instead of decided.
##
## The production resolver chooses who plays the ball, where they aim it and how
## well they execute, then physics turns that into a flight. This subclass keeps
## the last step and replaces the first three with a written list. Nothing here
## resolves a ball: every contact goes through the same `resolve_serve`,
## `PlatformContactModel.evaluate` and `FreeFlightInterceptionModel` calls a
## live rally makes, with the arguments supplied rather than drawn.
##
## That boundary is the whole design, and `VignetteRallySimulator`'s docstring
## already draws it for the vignettes: character creation "is allowed to author
## the tactical problem and the opponent's information state, but not a second
## movement/ball system". This is the same permission, widened from a formation
## to a contact list. The moment this file computes a trajectory of its own it
## stops being an instrument and becomes a fork.
##
## **Execution is authored as draws, not as quality.** The resolvers already take
## normalised error samples -- `{"bearing": 0.0, "vertical": -0.4, "power": 0.2}`
## in units of sigma -- and abilities come from the voli. Authoring a draw picks
## one sample out of the distribution the model already has, the way a fixed seed
## does. A "quality" dial would be a new calibration magnitude with no authority
## behind it, which is the thing this repository refuses everywhere else.
##
## A contact is a dictionary so a script can be written as a GDScript literal
## with no resource plumbing:
##
##     [
##         {"actor": 105, "family": "serve", "aim": Vector2(0.45, 0.78),
##          "draws": {"bearing": 0.0, "vertical": -0.4, "power": 0.2}},
##         {"actor": 6, "family": "reception", "aim": Vector2(0.62, 0.60),
##          "height": 2.40},
##     ]
##
## Absent keys mean "no opinion": omitted draws are zero, which is the median
## execution rather than a good one.

## NOTE what a script may state; anything else is refused rather than ignored
const CONTACT_KEYS: Array[String] = [
	"actor", "family", "aim", "height", "draws", "note",
]
const FAMILIES: Array[String] = ["serve", "reception"]


## Why a script was refused, or empty when it was accepted.
##
## Refusing beats ignoring: a misspelled key that silently does nothing produces
## a rally that looks authored and is not, which is the one failure mode an
## instrument like this cannot afford.
static func validate(contacts: Array) -> String:
	if contacts.is_empty():
		return "a script needs at least one contact"
	if str(Dictionary(contacts[0]).get("family", "")) != "serve":
		return "the first contact must be the serve"
	for index in contacts.size():
		var contact := Dictionary(contacts[index])
		for key in contact:
			if not str(key) in CONTACT_KEYS:
				return "contact %d has an unknown key '%s'" % [index, str(key)]
		var family := str(contact.get("family", ""))
		if not family in FAMILIES:
			return "contact %d has family '%s', which is not built yet" % [
				index, family,
			]
		if not contact.has("actor"):
			return "contact %d does not say who makes it" % index
		var draws := Dictionary(contact.get("draws", {}))
		for draw_key in draws:
			if not str(draw_key) in ["bearing", "vertical", "power"]:
				return "contact %d draws an unknown channel '%s'" % [
					index, str(draw_key),
				]
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
	contacts: Array,
	players: Array[VolleyballPlayer],
	lineup: RotationLineup,
	opponent_team: Resource,
	defensive_plan: Resource,
	home_serving: bool,
	seed_value: int = 1,
) -> Resource:
	var refusal := validate(contacts)
	if not refusal.is_empty():
		push_error("scripted rally refused: %s" % refusal)
		return null
	rally_seed = seed_value
	rng.seed = seed_value
	geometric_rng.seed = seed_value
	var result: Resource = RallyResultModel.new()
	_seed_positions(players, lineup, opponent_team, defensive_plan, home_serving)

	var serve := Dictionary(contacts[0])
	var served := _script_serve(result, serve, players, opponent_team, home_serving)
	if served.is_empty():
		return result
	if contacts.size() < 2:
		return result
	_script_reception(
		result, Dictionary(contacts[1]), players, opponent_team, served
	)
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
		push_error("no actor %d for the serve" % int(contact.actor))
		return {}
	var origin := CourtConstants.serve_origin(0.82, home_serving)
	var aim := Vector2(contact.get("aim", Vector2(0.5, 0.75)))
	var contact_height := GeometricAttackPromotionModel.serve_contact_height_meters(
		server,
		GeometricAttackPromotionModel.serve_effort_for_style(
			str(server.primary_serve_style)
		),
	)
	var serve: Dictionary = GeometricAttackResolverModel.resolve_serve(
		server, origin, contact_height, aim, home_serving, 0.5,
		_draws(contact), _serve_spin(server),
	)
	if not bool(serve.get("available", false)):
		push_error("the authored serve is not available: %s" % str(
			serve.get("reason", "unstated")
		))
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
		push_error("the authored serve produced no flight")
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
) -> void:
	live_positions = _initial_home_positions(
		lineup, defensive_plan, not home_serving, true, players
	)
	opponent_live_positions = _initial_opponent_positions(
		opponent_team, home_serving, true
	)


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
		push_error("no actor %d for the reception" % int(contact.actor))
		return {}
	var free_flight: Dictionary = served.free_flight
	var platform_height := GeometricAttackPromotionModel \
		.pass_contact_height_meters(receiver)
	var descent := FreeFlightInterceptionModel.descent_to_height(
		free_flight, platform_height
	)
	if not bool(descent.get("available", false)):
		push_error("the authored serve never descends to %.2f m" % platform_height)
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
		push_error("the sliced serve states no incoming velocity")
		return {}
	var aim := Vector2(contact.get("aim", Vector2(0.5, 0.60)))
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
		"intent_height_anchor_meters": float(contact.get("height", 2.40)),
		"intent_arrival_floor_seconds": 0.0,
		"seed": hash("%d|scripted-reception|%d" % [rally_seed, receiver.id]),
	})
	if not bool(shadow.get("selection_available", false)):
		push_error("the platform refused the authored reception")
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
