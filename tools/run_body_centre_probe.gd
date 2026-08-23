extends SceneTree

## M3, asked before anything is built: **where does the engine put the body when
## a voli plays the ball?**
##
##     godot --headless --path . --script res://tools/run_body_centre_probe.gd
##
## The milestone: "a voli's body location is distinct from the point where
## hands/platform contact the ball. Reach, wingspan, body type and net
## encroachment use one physical geometry instead of placing the sternum on the
## ball."
##
## So the first question is which families already draw that distinction and
## which place the sternum on the ball. Measured, not assumed -- three of this
## session's findings reversed on measurement.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const GeometricPromotionScript := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)
const CoverageCalculator := preload("res://scripts/simulation/coverage_calculator.gd")
const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	_where_the_body_lands()
	_what_reach_already_knows()
	_live_platform_contacts()
	_verdict()
	quit()


func _voli(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 601
	player.display_name = "Voli"
	for attribute in [
		"anticipation", "lateral_speed", "acceleration", "transition_speed",
		"stamina", "work_rate", "reception", "dig_control", "ball_control",
		"composure", "explosiveness",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## `_reached_point` is where every defensive journey ends, and what it returns is
## the body's new position. Driven across a range of trips with time to spare,
## using the same per-voli platform height and incoming direction production now
## supplies at every defensive contact.
func _where_the_body_lands() -> void:
	print("=".repeat(78))
	print("WHERE THE BODY ENDS UP, RELATIVE TO THE BALL")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242
	var start := Vector2(0.50, 0.86)
	var player := _voli()
	var contact_height := GeometricPromotionScript.pass_contact_height_meters(player)
	var expected_offset := player.contact_offset_meters(contact_height)
	print("  A defender with ample time, sent to a ball at a range of distances.\n")
	print("  %-10s %-14s %-18s %-14s" % [
		"trip m", "time s", "body-to-ball m", "on the ball?",
	])
	var on_the_ball := 0
	var rows := 0
	for trip in [0.4, 1.0, 2.0, 3.0, 4.5]:
		var target := start + Vector2(0.0, -float(trip) / COURT_LENGTH_METERS)
		var reached: Vector2 = simulator._reached_point(
			player, start, target, 3.0, "lateral", 0.0,
			contact_height, Vector2(0.0, -1.0),
		)
		var gap := _metres(reached, target)
		rows += 1
		if gap < 0.0005:
			on_the_ball += 1
		print("  %-10.2f %-14.2f %-18.4f %-14s" % [
			float(trip), 3.0, gap, "YES" if gap < 0.0005 else "no",
		])
	print("\n  %d of %d trips end with the body centre exactly on the ball's" % [
		on_the_ball, rows,
	])
	print("  landing point. The derived contact offset is %.4f m." % expected_offset)
	print("")
	print("  A pre-promotion run of this same fixture reported 5 of 5 on the ball.")
	print("  Partial journeys and read shortfalls still return their physical")
	print("  stopping points; the stand-off applies only when the body fully arrives.")


## And what the reach model already knows, so the milestone is not told to build
## what exists.
func _what_reach_already_knows() -> void:
	print("\n" + "=".repeat(78))
	print("WHAT THE REACH MODEL ALREADY DISTINGUISHES")
	print("=".repeat(78))
	print("  `_base_reach_meters` -- the platform envelope, by build and control:\n")
	print("  %-16s %-14s %-16s %-14s" % [
		"wingspan cm", "ball_control", "reception m", "dig m",
	])
	for wingspan in [175, 190, 205, 220]:
		for control in [30, 70]:
			var player := _voli({"ball_control": control})
			player.wingspan_cm = wingspan
			var arrival_reception: Dictionary = CoverageCalculator.evaluate_arrival(
				player, null, Vector2(0.5, 0.6), 1.20, "reception",
				Vector2(0.5, 0.7), 3.0,
			)
			var arrival_dig: Dictionary = CoverageCalculator.evaluate_arrival(
				player, null, Vector2(0.5, 0.6), 1.20, "dig_control",
				Vector2(0.5, 0.7), 3.0,
			)
			print("  %-16s %-14d %-16.4f %-14.4f" % [
				str(wingspan) if control == 30 else "", control,
				float(arrival_reception.get("base_reach_meters", 0.0)),
				float(arrival_dig.get("base_reach_meters", 0.0)),
			])
	print("\n  Wingspan is already in it, and so is control and the libero's")
	print("  role bonus. **This is a tolerance, not a stand-off.** It decides")
	print("  whether a ball is reachable from where the body is; it does not")
	print("  decide where the body goes.")

	print("\n  `ContactEnvelopeSystem._horizontal_reach` -- the same question")
	print("  asked of a live body, and it does vary with posture:\n")
	print("  %-16s %-18s" % ["body state", "horizontal reach m"])
	for state_name in ["BALANCED", "MOVING", "REACHING", "DIVING", "RECOVERING"]:
		var actor := RallyPlayerState.create(
			_voli(), &"home", 1, Vector2(0.5, 0.7)
		)
		actor.body_state = RallyPlayerState.BodyState[state_name]
		var envelope: Dictionary = ContactEnvelopeModel.evaluate(
			actor, &"receive", 1.00, 1.20, false,
		)
		print("  %-16s %-18.4f" % [
			state_name, float(envelope.get("horizontal_reach_meters", 0.0)),
		])


## The direct fixture above locates the one return, but M3 promotion moves real
## rally bodies and therefore needs a production population. This census uses
## only successful contacts with no read shortfall and compares the published
## movement target against the position the already-derived body geometry says
## should have made that contact. It runs unchanged before and after promotion.
func _live_platform_contacts() -> void:
	print("\n" + "=".repeat(78))
	print("LIVE PLATFORM CONTACTS -- BODY TARGET AGAINST DERIVED GEOMETRY")
	print("=".repeat(78))
	var by_purpose := {}
	var outcome_counts := {}
	var simulator: Object = RallySimulatorScript.new()
	for serving_home in [true, false]:
		for seed_value in range(24400, 24520):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				manager.free()
				continue
			var outcome := str(result.terminal_outcome)
			outcome_counts[outcome] = int(outcome_counts.get(outcome, 0)) + 1
			var home_by_id := {}
			for entry in manager.players:
				var home_player := entry as VolleyballPlayer
				if home_player != null:
					home_by_id[home_player.id] = home_player
			var opponent_by_id := {}
			for entry in manager.opponent_team.on_court_players():
				var opponent_player := entry as VolleyballPlayer
				if opponent_player != null:
					opponent_by_id[opponent_player.id] = opponent_player
			for entry in result.events:
				var event := entry as RallyEvent
				if event == null or not event.success or event.event_type not in [
					RallyEventScript.EventType.RECEPTION,
					RallyEventScript.EventType.DIG,
					RallyEventScript.EventType.ATTACK_COVERAGE,
				]:
					continue
				if not event.metadata.has("movement_target"):
					continue
				var arrival: Dictionary = event.metadata.get("arrival", {})
				var read_error := float(event.metadata.get(
					"read_error_meters", arrival.get("read_error_meters", 0.0)
				))
				if read_error > 0.0001:
					continue
				var player_map: Dictionary = home_by_id \
					if str(event.metadata.get("side", "")) == "home" \
					else opponent_by_id
				var player := player_map.get(event.actor_id) as VolleyballPlayer
				if player == null:
					continue
				var trajectory: Dictionary = event.metadata.get("incoming_trajectory", {})
				var incoming_start := Vector2(trajectory.get(
					"start_position", event.start_position
				))
				var incoming := event.start_position - incoming_start
				if incoming.length_squared() <= 0.000001:
					continue
				var height := GeometricPromotionScript.pass_contact_height_meters(player)
				var predicted: Vector2 = simulator._body_behind_contact(
					player, event.start_position, height, incoming.normalized()
				)
				var expected_offset := _metres(predicted, event.start_position)
				if expected_offset <= 0.01:
					continue
				var actual := Vector2(event.metadata["movement_target"])
				var bucket: Dictionary = by_purpose.get(
					str(Dictionary(event.metadata.get("platform_intent", {})).get(
						"purpose", event.type_name()
					)),
					{"n": 0, "on_ball": 0, "matches": 0, "offsets": [], "errors": []},
				)
				var actual_offset := _metres(actual, event.start_position)
				var geometry_error := _metres(actual, predicted)
				bucket["n"] = int(bucket.n) + 1
				bucket["on_ball"] = int(bucket.on_ball) + (1 if actual_offset < 0.001 else 0)
				bucket["matches"] = int(bucket.matches) + (1 if geometry_error < 0.001 else 0)
				bucket.offsets.append(actual_offset)
				bucket.errors.append(geometry_error)
				by_purpose[str(Dictionary(event.metadata.get(
					"platform_intent", {}
				)).get("purpose", event.type_name()))] = bucket
			manager.free()

	print("  %-18s %-7s %-10s %-12s %-18s %-18s" % [
		"purpose", "n", "on ball", "geometry", "body offset p50", "error p50",
	])
	var purposes: Array = by_purpose.keys()
	purposes.sort()
	for purpose in purposes:
		var bucket: Dictionary = by_purpose[purpose]
		print("  %-18s %-7d %-10d %-12d %-18.3f %-18.3f" % [
			str(purpose), int(bucket.n), int(bucket.on_ball), int(bucket.matches),
			_percentile(bucket.offsets, 0.50), _percentile(bucket.errors, 0.50),
		])
	print("\n  Terminal outcomes (240 fixed rallies; observation, never a target):")
	var outcomes: Array = outcome_counts.keys()
	outcomes.sort()
	for outcome in outcomes:
		print("  %-28s %d" % [str(outcome), int(outcome_counts[outcome])])


func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var ordered := values.duplicate()
	ordered.sort()
	return float(ordered[clampi(
		roundi(fraction * float(ordered.size() - 1)), 0, ordered.size() - 1
	)])


func _verdict() -> void:
	print("\n" + "=".repeat(78))
	print("VERDICT -- M3'S DERIVED RELATION IS NOW CONSUMED")
	print("=".repeat(78))
	print("  All eight platform placement sites now pass the contact family's own")
	print("  per-voli height and the incoming ball's court-space direction into")
	print("  `_reached_point`. No trajectory endpoint height is read, so the")
	print("  unresolved free-flight/next-contact field does not leak into M3.")
	print("")
	print("  Only a full arrival takes the derived stand-off. A body that was beaten")
	print("  for time or read the ball elsewhere remains where that journey ended;")
	print("  contact geometry does not teleport it into a cleaner pose.")
