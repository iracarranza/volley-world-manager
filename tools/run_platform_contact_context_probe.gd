extends SceneTree

## M4 authority-boundary probe: facts already present at every platform contact.
##
##     godot --headless --path . \
##       --script res://tools/run_platform_contact_context_probe.gd
##
## This probe is production-inert. It neither calls a replacement resolver nor
## supplies any unauthored T1/T2/T3 value. It joins the canonical event record to
## the contacting voli, derives velocities from the published trajectories, and
## reports both coverage and missingness. A missing vertical component stays
## missing when the trajectory does not own enough height/launch state to derive
## it; a default endpoint height is not silently promoted into physical truth.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const BallTrajectoryScript := preload("res://scripts/models/ball_trajectory.gd")
const BallFlightScript := preload("res://scripts/simulation/ball_flight_model.gd")
const GeometricPromotionScript := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300
const UNSET := "unset"


func _initialize() -> void:
	var rows := _sweep()
	_print_population(rows)
	_print_fact_coverage(rows)
	_print_authority_sources(rows)
	_print_measured_context(rows)
	_print_samples(rows)
	quit()


func _sweep() -> Array:
	var rows: Array = []
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				manager.free()
				continue
			var home_by_id := _players_by_id(manager.players)
			var opponent_by_id := _players_by_id(
				manager.opponent_team.players if manager.opponent_team != null else []
			)
			for entry in result.events:
				var event := entry as RallyEvent
				if event == null:
					continue
				var family := _family(event)
				if family.is_empty():
					continue
				var player_map: Dictionary = home_by_id \
					if str(event.metadata.get("side", "")) == "home" \
					else opponent_by_id
				rows.append(_row(
					event, family, player_map.get(event.actor_id) as VolleyballPlayer,
					seed_value, serving_home,
				))
			manager.free()
	return rows


func _family(event: RallyEvent) -> String:
	match event.event_type:
		RallyEventScript.EventType.RECEPTION:
			return "reception"
		RallyEventScript.EventType.DIG:
			return "controlled_dig"
		RallyEventScript.EventType.ATTACK_COVERAGE:
			return "attack_coverage"
	return ""


func _players_by_id(players: Array) -> Dictionary:
	var by_id := {}
	for entry in players:
		var player := entry as VolleyballPlayer
		if player != null:
			by_id[player.id] = player
	return by_id


func _row(
	event: RallyEvent,
	family: String,
	player: VolleyballPlayer,
	seed_value: int,
	serving_home: bool,
) -> Dictionary:
	var metadata: Dictionary = event.metadata
	var incoming: Dictionary = metadata.get("incoming_trajectory", {})
	var outgoing: Dictionary = metadata.get("outgoing_trajectory", {})
	## Coverage has no production contact resolver. `_ensure_event_trajectories`
	## later adds a display fallback to these events, but that is not an outgoing
	## ball owned by the contact and must not be laundered into physical evidence.
	if family == "attack_coverage":
		outgoing = {}
	var incoming_state := _flight_state(incoming, true)
	var outgoing_state := _flight_state(outgoing, false)
	var movement_start := Vector2(metadata.get(
		"movement_start", event.start_position
	))
	var has_body_position := metadata.has("movement_target")
	var body_position := Vector2(metadata.get(
		"movement_target", event.start_position
	))
	var required_move_time := float(metadata.get("movement_duration", -1.0))
	var available_time := float(incoming.get(
		"duration", metadata.get("flight_time", -1.0)
	))
	var motion_time := -1.0
	if available_time > 0.0:
		motion_time = minf(required_move_time, available_time) \
			if required_move_time > 0.0 else available_time
	var body_velocity := {}
	if has_body_position and motion_time > 0.0001:
		var normalized_velocity := (body_position - movement_start) / motion_time
		body_velocity = _court_velocity(normalized_velocity)
	var contact_height := -1.0
	var contact_height_source := "missing"
	if float(metadata.get("pass_contact_height_meters", 0.0)) > 0.0:
		contact_height = float(metadata.pass_contact_height_meters)
		contact_height_source = "event"
	elif not outgoing.is_empty() \
			and str(outgoing.get("height_source", "default")) in [
				"resolved", "start_resolved",
			]:
		contact_height = float(outgoing.get("start_height_meters", -1.0))
		contact_height_source = "outgoing_trajectory"
	elif player != null:
		contact_height = GeometricPromotionScript.pass_contact_height_meters(player)
		contact_height_source = "body_model"
	var intent: Dictionary = metadata.get("platform_intent", {})
	var target_anchor: Variant = intent.get("target_anchor", UNSET)
	var actual_target: Variant = outgoing.get("end_position", UNSET)
	var target_gap := -1.0
	if target_anchor is Vector2 and actual_target is Vector2:
		target_gap = _court_distance(target_anchor, actual_target)
	var arrival: Dictionary = metadata.get("arrival", {})
	var reach_margin := float(metadata.get(
		"reach_margin_meters", arrival.get("reach_margin_meters", NAN)
	))
	var read_error := float(metadata.get(
		"read_error_meters", arrival.get("read_error_meters", NAN)
	))
	var contact_offset := {}
	if has_body_position:
		contact_offset = _court_offset(event.start_position - body_position)
	var resolved_composite := -1.0
	if family == "reception":
		resolved_composite = float(Dictionary(metadata.get(
			"reception_terms", {}
		)).get("base", -1.0))
	elif family == "controlled_dig":
		resolved_composite = float(Dictionary(metadata.get(
			"dig_terms", {}
		)).get("capability", -1.0))
	return {
		"seed": seed_value,
		"serving_home": serving_home,
		"side": str(metadata.get("side", "unstated")),
		"family": family,
		"success": event.success,
		"actor_id": event.actor_id,
		"actor": event.actor_name,
		"contact_position": event.start_position,
		"contact_time": float(metadata.get(
			"event_time", incoming.get("end_time", NAN)
		)),
		"contact_height": contact_height,
		"contact_height_source": contact_height_source,
		"incoming": incoming_state,
		"outgoing": outgoing_state,
		"published_incoming_speed": float(metadata.get(
			"incoming_speed_mps", NAN
		)),
		"body_position": body_position if has_body_position else UNSET,
		"body_velocity": body_velocity,
		"body_contact_offset": contact_offset,
		"movement_required_seconds": required_move_time,
		"movement_available_seconds": available_time,
		"posture": str(metadata.get("contact_posture", "unstated")),
		"reach_margin": reach_margin,
		"read_error": read_error,
		"intent_purpose": str(intent.get("purpose", "missing")),
		"intent_target_anchor": target_anchor,
		"intent_anchor_source": str(intent.get("anchor_source", "missing")),
		"intent_height_anchor": intent.get("height_anchor_meters", UNSET),
		"intent_arrival_floor": intent.get("arrival_floor_seconds", UNSET),
		"intent_recipient_id": int(intent.get("intended_recipient_id", -1)),
		"actual_target": actual_target,
		"actual_to_intent_meters": target_gap,
		"ratings": _ratings(player, family),
		"resolved_capability_composite": resolved_composite,
	}


## Velocity of the published trajectory at one of its contacts. Horizontal
## motion comes from BallTrajectory's canonical curve derivative. Vertical
## motion comes from an owned launch state when present, otherwise from the two
## resolved contact heights. No default endpoint height is accepted as truth.
func _flight_state(data: Dictionary, at_end: bool) -> Dictionary:
	if data.is_empty() or float(data.get("duration", 0.0)) <= 0.0:
		return {}
	var trajectory: Resource = BallTrajectoryScript.from_dict(data)
	var ground_normalized: Vector2 = trajectory.velocity_at_progress(
		1.0 if at_end else 0.0
	)
	var ground := _court_vector(ground_normalized)
	var duration := float(data.get("duration", 0.0))
	var vertical := NAN
	var vertical_source := "missing"
	if data.has("launch_vertical_mps"):
		vertical = float(data.launch_vertical_mps)
		if at_end:
			vertical -= float(data.get(
				"launch_gravity_mps2", BallFlightScript.DEFAULT_GRAVITY_MPS2
			)) * duration
		vertical_source = "resolver_launch"
	elif str(data.get("height_source", "default")) == "resolved":
		vertical = BallFlightScript.rise_speed_between(
			float(data.get("start_height_meters", 1.0)),
			float(data.get("end_height_meters", 1.0)), duration,
		)
		if at_end:
			vertical -= BallFlightScript.DEFAULT_GRAVITY_MPS2 * duration
		vertical_source = "resolved_contact_heights"
	var speed := NAN
	if not is_nan(vertical):
		speed = sqrt(ground.length_squared() + vertical * vertical)
	return {
		"x_mps": ground.x,
		"y_mps": ground.y,
		"horizontal_mps": ground.length(),
		"vertical_mps": vertical,
		"speed_mps": speed,
		"vertical_source": vertical_source,
		"height_source": str(data.get("height_source", "missing")),
	}


func _court_velocity(value: Vector2) -> Dictionary:
	var meters := _court_vector(value)
	return {"x_mps": meters.x, "y_mps": meters.y, "speed_mps": meters.length()}


func _court_offset(value: Vector2) -> Dictionary:
	var meters := _court_vector(value)
	return {
		"x_meters": meters.x,
		"y_meters": meters.y,
		"distance_meters": meters.length(),
	}


func _court_vector(value: Vector2) -> Vector2:
	return Vector2(
		value.x * CourtConstants.COURT_WIDTH_METERS,
		value.y * CourtConstants.COURT_LENGTH_METERS,
	)


func _court_distance(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * CourtConstants.COURT_WIDTH_METERS,
		(a.y - b.y) * CourtConstants.COURT_LENGTH_METERS,
	).length()


func _ratings(player: VolleyballPlayer, family: String) -> Dictionary:
	if player == null:
		return {}
	var names: Array[String] = []
	if family == "reception":
		names = [
			"reception", "ball_control", "composure",
			"reception_balance", "reception_stability",
		]
	elif family == "controlled_dig":
		names = ["reception", "anticipation", "dig_control", "lateral_speed"]
	else:
		names = ["reception", "ball_control", "dig_control"]
	var values := {}
	for property_name in names:
		values[property_name] = int(player.get(property_name))
	return values


func _print_population(rows: Array) -> void:
	print("=".repeat(88))
	print("M4 PLATFORM CONTACT CONTEXT -- PARAMETER-FREE PRODUCTION FACTS")
	print("=".repeat(88))
	print("  %d contacts over %d fixed rallies; no resolver or rollout changed.\n" % [
		rows.size(), RALLIES_PER_SERVER * 2,
	])
	var counts := {}
	for row in rows:
		var key := "%s / %s" % [row.family, "success" if row.success else "miss"]
		counts[key] = int(counts.get(key, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		print("  %-38s %4d" % [str(key), int(counts[key])])


func _print_fact_coverage(rows: Array) -> void:
	print("\n" + "=".repeat(88))
	print("FACT COVERAGE -- PRESENT MEANS DERIVED WITHOUT A NEW PARAMETER")
	print("=".repeat(88))
	print("  %-20s %6s %8s %8s %8s %8s %8s %8s %8s" % [
		"family", "n", "in xyz", "out xyz", "height", "body v", "offset",
		"intent", "ratings",
	])
	for family in _families(rows):
		var subset: Array = rows.filter(func(row): return row.family == family)
		var fields := {
			"incoming": 0, "outgoing": 0, "height": 0, "body": 0,
			"offset": 0, "intent": 0, "ratings": 0,
		}
		for row in subset:
			fields.incoming += 1 if _has_vector_state(row.incoming) else 0
			fields.outgoing += 1 if _has_vector_state(row.outgoing) else 0
			fields.height += 1 if float(row.contact_height) > 0.0 else 0
			fields.body += 1 if not Dictionary(row.body_velocity).is_empty() else 0
			fields.offset += 1 if not Dictionary(row.body_contact_offset).is_empty() else 0
			fields.intent += 1 if row.intent_target_anchor is Vector2 else 0
			fields.ratings += 1 if not Dictionary(row.ratings).is_empty() else 0
		print("  %-20s %6d %8d %8d %8d %8d %8d %8d %8d" % [
			family, subset.size(), fields.incoming, fields.outgoing, fields.height,
			fields.body, fields.offset, fields.intent, fields.ratings,
		])
	print("\n  'in/out xyz' requires an authoritative vertical component. Horizontal")
	print("  trajectory derivatives remain available even where endpoint height is open.")


func _has_vector_state(state: Dictionary) -> bool:
	return not state.is_empty() and not is_nan(float(state.get("vertical_mps", NAN)))


func _print_authority_sources(rows: Array) -> void:
	print("\n  Authority sources (count; absence remains explicit):")
	for family in _families(rows):
		var incoming_sources := {}
		var outgoing_sources := {}
		var height_sources := {}
		for row in rows:
			if row.family != family:
				continue
			var incoming: Dictionary = row.incoming
			var outgoing: Dictionary = row.outgoing
			var incoming_key := str(incoming.get("vertical_source", "no trajectory"))
			var outgoing_key := str(outgoing.get("vertical_source", "no trajectory"))
			incoming_sources[incoming_key] = int(incoming_sources.get(
				incoming_key, 0
			)) + 1
			outgoing_sources[outgoing_key] = int(outgoing_sources.get(
				outgoing_key, 0
			)) + 1
			height_sources[str(row.contact_height_source)] = int(height_sources.get(
				str(row.contact_height_source), 0
			)) + 1
		print("    %-20s incoming=%s" % [family, _counts_text(incoming_sources)])
		print("    %-20s outgoing=%s" % ["", _counts_text(outgoing_sources)])
		print("    %-20s contact height=%s" % ["", _counts_text(height_sources)])


func _counts_text(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s %d" % [str(key), int(counts[key])])
	return ", ".join(parts)


func _print_measured_context(rows: Array) -> void:
	print("\n" + "=".repeat(88))
	print("MEASURED CONTEXT -- DISTRIBUTIONS, NOT CALIBRATION TARGETS")
	print("=".repeat(88))
	print("  %-20s %6s %13s %13s %13s %13s" % [
		"family", "n", "incoming m/s", "outgoing m/s", "body m/s", "offset m",
	])
	for family in _families(rows):
		var subset: Array = rows.filter(func(row): return row.family == family)
		var incoming := _values(subset, func(row): return Dictionary(row.incoming).get(
			"speed_mps", NAN
		))
		var outgoing := _values(subset, func(row): return Dictionary(row.outgoing).get(
			"speed_mps", NAN
		))
		var body := _values(subset, func(row): return Dictionary(row.body_velocity).get(
			"speed_mps", NAN
		))
		var offsets := _values(subset, func(row): return Dictionary(
			row.body_contact_offset
		).get("distance_meters", NAN))
		print("  %-20s %6d %13s %13s %13s %13s" % [
			family, subset.size(), _compact_stats(incoming), _compact_stats(outgoing),
			_compact_stats(body), _compact_stats(offsets),
		])
	var actual_gaps := _values(rows, func(row): return row.actual_to_intent_meters)
	print("\n  actual outgoing endpoint -> stated intent anchor: %s m (n=%d)" % [
		_compact_stats(actual_gaps), actual_gaps.size(),
	])
	var speed_deltas: Array = []
	for row in rows:
		var derived := float(Dictionary(row.incoming).get("speed_mps", NAN))
		var published := float(row.published_incoming_speed)
		if not is_nan(derived) and not is_nan(published):
			speed_deltas.append(absf(derived - published))
	print("  |contact-speed derived - published incoming_speed|: %s m/s (n=%d)" % [
		_compact_stats(speed_deltas), speed_deltas.size(),
	])
	print("  The published scalar usually describes launch pace; the derived vector")
	print("  describes arrival at this contact. Their gap is expected under gravity.")


func _print_samples(rows: Array) -> void:
	print("\n" + "=".repeat(88))
	print("ONE COMPLETE RECORD PER FAMILY")
	print("=".repeat(88))
	for family in _families(rows):
		var sample := {}
		for row in rows:
			if row.family == family and row.success and _has_vector_state(row.incoming):
				sample = row
				break
		if sample.is_empty():
			for row in rows:
				if row.family == family:
					sample = row
					break
		print("\n  %s" % family)
		print("    seed=%d side=%s actor=%s success=%s" % [
			int(sample.seed), str(sample.side), str(sample.actor), str(sample.success),
		])
		print("    contact pos=%s height=%.3f (%s) time=%.3f" % [
			str(sample.contact_position), float(sample.contact_height),
			str(sample.contact_height_source), float(sample.contact_time),
		])
		print("    incoming=%s" % _state_text(sample.incoming))
		print("    body velocity=%s  body->ball offset=%s" % [
			_state_text(sample.body_velocity), _offset_text(sample.body_contact_offset),
		])
		print("    posture=%s reach_margin=%s read_error=%s" % [
			str(sample.posture), _number_text(sample.reach_margin),
			_number_text(sample.read_error),
		])
		print("    intent=%s anchor=%s height=%s arrival_floor=%s recipient=%d" % [
			str(sample.intent_purpose), str(sample.intent_target_anchor),
			str(sample.intent_height_anchor), str(sample.intent_arrival_floor),
			int(sample.intent_recipient_id),
		])
		print("    ratings=%s composite=%.3f" % [
			str(sample.ratings), float(sample.resolved_capability_composite),
		])
		print("    canonical legacy outgoing=%s" % _state_text(sample.outgoing))
	print("\n  These rows are sufficient to evaluate a future shadow relation once")
	print("  T1/T2/T3 magnitudes are measured or explicitly authored. This probe")
	print("  does not choose those magnitudes and cannot certify an envelope.")


func _families(rows: Array) -> Array:
	var seen := {}
	for row in rows:
		seen[str(row.family)] = true
	var values: Array = seen.keys()
	values.sort()
	return values


func _values(rows: Array, getter: Callable) -> Array:
	var values: Array = []
	for row in rows:
		var value := float(getter.call(row))
		if not is_nan(value) and value >= 0.0:
			values.append(value)
	return values


func _compact_stats(values: Array) -> String:
	if values.is_empty():
		return "missing"
	var ordered := values.duplicate()
	ordered.sort()
	return "%.2f/%.2f/%.2f" % [
		float(ordered[0]), float(ordered[ordered.size() / 2]),
		float(ordered[ordered.size() - 1]),
	]


func _state_text(state: Dictionary) -> String:
	if state.is_empty():
		return "missing"
	if state.has("vertical_mps"):
		return "(x=%s y=%s z=%s speed=%s; %s)" % [
			_number_text(state.get("x_mps", NAN)),
			_number_text(state.get("y_mps", NAN)),
			_number_text(state.get("vertical_mps", NAN)),
			_number_text(state.get("speed_mps", NAN)),
			str(state.get("vertical_source", "missing")),
		]
	return "(x=%s y=%s speed=%s)" % [
		_number_text(state.get("x_mps", NAN)),
		_number_text(state.get("y_mps", NAN)),
		_number_text(state.get("speed_mps", NAN)),
	]


func _offset_text(offset: Dictionary) -> String:
	if offset.is_empty():
		return "missing"
	return "(x=%s y=%s distance=%s)" % [
		_number_text(offset.get("x_meters", NAN)),
		_number_text(offset.get("y_meters", NAN)),
		_number_text(offset.get("distance_meters", NAN)),
	]


func _number_text(value: Variant) -> String:
	var number := float(value)
	return "missing" if is_nan(number) else "%.3f" % number
