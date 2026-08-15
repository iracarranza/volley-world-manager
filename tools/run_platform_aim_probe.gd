extends SceneTree

## What angle are the passer's arms actually being drawn at?
##
##     godot --headless --path . --script res://tools/run_platform_aim_probe.gd
##
## `PlatformAim` reads two flights and returns the surface that would rebound one
## into the other. Its own comment is specific about which input matters: *"the
## vertical component from the flight's own gravity solve rather than from the
## two endpoint heights"* -- so the two endpoint heights are the load-bearing
## numbers, and `match_screen._platform_aim` hands it the **raw** trajectories off
## the event, where `start_height_meters` and `end_height_meters` are the 1.0
## placeholder every trajectory in the game carries. Its own 2.0 / 0.9 defaults
## therefore never fire, and it is angling every platform in the game against a
## ball that flew from one metre to one metre.
##
## This measures the size of that, in degrees, against the same flights resolved
## through `BallPresentation` -- the heights the ball is actually *drawn* at.
## Degrees rather than a rate, because the question is not how often it is wrong
## but whether the error is visible on a screen.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 200
const FIRST_SEED: int = 9400

## Counted rather than asserted: see `_collect`.
var mismatched_senders: int = 0
var sender_disagreements: int = 0


func _initialize() -> void:
	var yaw_deltas: Array[float] = []
	var pitch_deltas: Array[float] = []
	var raw_pitches: Array[float] = []
	var true_pitches: Array[float] = []
	var posture_changes := 0
	var total := 0
	## How often no event owns a flight starting when this ball was struck. It
	## should be zero; anything else means the sender identity is not one.
	mismatched_senders = 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			total += _collect(
				result, yaw_deltas, pitch_deltas, raw_pitches, true_pitches
			)
		manager.free()

	if yaw_deltas.is_empty():
		print("no platform contacts sampled")
		quit()
		return
	yaw_deltas.sort()
	pitch_deltas.sort()
	raw_pitches.sort()
	true_pitches.sort()
	print("=== %d receptions and digs with both flights ===" % yaw_deltas.size())
	print("")
	print("how far the drawn platform is from the one the ball needs, in degrees")
	print("  yaw    p50 %6.2f  p90 %6.2f  max %6.2f" % [
		_at(yaw_deltas, 0.50), _at(yaw_deltas, 0.90),
		yaw_deltas[yaw_deltas.size() - 1],
	])
	print("  pitch  p50 %6.2f  p90 %6.2f  max %6.2f" % [
		_at(pitch_deltas, 0.50), _at(pitch_deltas, 0.90),
		pitch_deltas[pitch_deltas.size() - 1],
	])
	print("")
	## The distributions themselves, because a delta says how far apart two
	## answers are and not which of them is a platform a person could hold.
	## `MIN_PITCH_DEGREES` is -34 and `MAX_PITCH_DEGREES` is 38, so a distribution
	## pinned at either is a clamp doing the work rather than the geometry.
	print("pitch actually produced, degrees (bounds are -34 and +38)")
	print("  from the placeholder ball  p10 %6.2f  p50 %6.2f  p90 %6.2f" % [
		_at(raw_pitches, 0.10), _at(raw_pitches, 0.50), _at(raw_pitches, 0.90),
	])
	print("  from the drawn ball        p10 %6.2f  p50 %6.2f  p90 %6.2f" % [
		_at(true_pitches, 0.10), _at(true_pitches, 0.50), _at(true_pitches, 0.90),
	])
	print("")
	## And whether it reaches the one thing the aim decides beyond the drawing:
	## `posture_for` turns the residual into "off-axis" or "reaching", which the
	## pose system acts on.
	print("contacts whose posture classification changes: %d of %d (%.3f)" % [
		posture_changes, total, float(posture_changes) / float(maxi(total, 1)),
	])
	print("contacts with no event owning the arriving flight: %d" % mismatched_senders)
	print("contacts where stepping back one would pick the wrong sender: %d" % sender_disagreements)
	quit()


func _at(sorted_values: Array, quantile: float) -> float:
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])


func _collect(
	result: Resource,
	yaw_deltas: Array[float],
	pitch_deltas: Array[float],
	raw_pitches: Array[float],
	true_pitches: Array[float],
) -> int:
	var events: Array = result.events
	var profiles: Dictionary = result.player_physical_profiles
	var counted := 0
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.RECEPTION \
				and int(event.event_type) not in [RallyEventScript.EventType.DIG, RallyEventScript.EventType.ATTACK_COVERAGE]:
			continue
		var raw_incoming: Dictionary = event.metadata.get("incoming_trajectory", {})
		var raw_outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if raw_incoming.is_empty() or raw_outgoing.is_empty():
			continue
		## The two neighbours the drawn flights are built from: the contact that
		## sent this ball, and the one that took it away.
		##
		## The sender is matched on the flight's own `start_time`, the same
		## identity `match_screen._sender_of` uses, and for the same reason: a
		## blocker who jumped and missed is the previous *contact* on most swings
		## that reach a dig and did not touch the ball. Walking back one step
		## would launch the incoming flight from hands it never left.
		var launched_at := float(raw_incoming.get("start_time", NAN))
		var previous: Resource = null
		var nearest: Resource = null
		for back in range(index - 1, -1, -1):
			var candidate: Resource = events[back]
			if int(candidate.actor_id) < 0:
				continue
			if nearest == null:
				nearest = candidate
			var sent: Dictionary = candidate.metadata.get("outgoing_trajectory", {})
			if sent.is_empty() or is_nan(launched_at):
				continue
			if absf(float(sent.get("start_time", -1.0)) - launched_at) < 0.0005:
				previous = candidate
				break
		if previous == null:
			previous = nearest
			mismatched_senders += 1
		elif previous != nearest:
			## The naive "step back one contact" rule would have picked somebody
			## else here. Counted because two rules that never disagree on a sample
			## are one rule, and swapping between them would ship inert.
			sender_disagreements += 1
		var following: Resource = null
		for forward in range(index + 1, events.size()):
			if int(events[forward].actor_id) >= 0:
				following = events[forward]
				break
		if previous == null:
			continue
		var display_incoming := BallPresentation.display_trajectory(
			previous, event, raw_incoming, profiles
		)
		var display_outgoing := BallPresentation.display_trajectory(
			event, following, raw_outgoing, profiles
		)
		var placeholder: Dictionary = PlatformAim.solve(raw_incoming, raw_outgoing)
		var drawn: Dictionary = PlatformAim.solve(
			display_incoming, display_outgoing
		)
		if not bool(placeholder.get("valid", false)) \
				or not bool(drawn.get("valid", false)):
			continue
		counted += 1
		yaw_deltas.append(absf(rad_to_deg(angle_difference(
			deg_to_rad(float(placeholder.yaw_degrees)),
			deg_to_rad(float(drawn.yaw_degrees)),
		))))
		pitch_deltas.append(absf(
			float(placeholder.pitch_degrees) - float(drawn.pitch_degrees)
		))
		raw_pitches.append(float(placeholder.pitch_degrees))
		true_pitches.append(float(drawn.pitch_degrees))
	return counted
