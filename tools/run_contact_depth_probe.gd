extends SceneTree

## Why the opponent swings from the back of their own court.
##
## `_opponent_attack_contact` asks for 0.36 m off the tape in the front row and
## 3.60 m in the back. The contacts that actually happen have a median 5.41 m off
## it, which is a swing from the baseline, and the block is beaten in exact
## proportion: blocks that touched the ball faced a p50 contact 1.77 m off the
## net, blocks that were beaten faced 5.51 m.
##
## `_reachable_attack_contact` is what produces them -- it bisects the hitter's
## run and hands back the furthest point they can reach when they cannot make the
## pin inside the set's flight plus a grace. So the question this answers is not
## whether the clamp fires but *why*: is the set too quick, is the hitter starting
## too far away, or is the locomotion too slow?
##
## Run:
##   godot --headless --path . --script res://tools/run_contact_depth_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")
const RallyKinematicsScript := preload("res://scripts/simulation/rally_kinematics.gd")

const ROSTER_SEEDS: Array[int] = [900006, 901006, 902006, 903006]
const RALLIES: int = 150


func _initialize() -> void:
	var ideal_depth: Array = []
	var actual_depth: Array = []
	var run_distance: Array = []
	var travel: Array = []
	var flight: Array = []
	var deficit: Array = []
	var clamped := 0
	var total := 0
	for roster_seed in ROSTER_SEEDS:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
		ExecutionScale.apply_generated_attributes(
			manager.opponent_team.players, roster_seed
		)
		for serving_home in [true, false]:
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				for raw_event in result.events:
					var event := raw_event as RallyEvent
					if event == null \
							or event.event_type != RallyEventScript.EventType.ATTACK \
							or str(event.metadata.get("side", "")) != "opponent" \
							or not event.metadata.has("ideal_contact"):
						continue
					total += 1
					var ideal: Vector2 = event.metadata["ideal_contact"]
					var start: Vector2 = event.metadata["hitter_start"]
					var travel_seconds := float(event.metadata["hitter_travel_time"])
					var flight_seconds := float(event.metadata["set_flight_seconds"])
					ideal_depth.append(_off_net(ideal))
					actual_depth.append(_off_net(event.start_position))
					run_distance.append(
						RallyKinematicsScript.court_distance_meters(start, ideal)
					)
					travel.append(travel_seconds)
					flight.append(flight_seconds)
					deficit.append(travel_seconds - flight_seconds)
					if not event.start_position.is_equal_approx(ideal):
						clamped += 1
		manager.free()

	print("Contact depth -- %d rosters x %d rallies x 2 serving sides, opponent swings"
		% [ROSTER_SEEDS.size(), RALLIES])
	print("")
	_report("asked-for contact, metres off the net", ideal_depth)
	_report("actual contact, metres off the net", actual_depth)
	print("")
	_report("how far the hitter had to run, metres", run_distance)
	_report("how long that run takes, seconds", travel)
	_report("how long the set is in the air, seconds", flight)
	_report("run minus flight (positive = cannot make it)", deficit)
	print("")
	print("clamped short of the asked-for contact: %d of %d" % [clamped, total])
	print("")
	print("A run that is metres long against a set that is in the air for a few")
	print("tenths is not a hitter who is slow -- it is a hitter who was never")
	print("standing anywhere near the lane they were asked to attack from.")
	quit()


func _off_net(point: Vector2) -> float:
	return absf(CourtConstants.NET_Y - point.y) * CourtConstants.COURT_LENGTH_METERS


func _report(label: String, samples: Array) -> void:
	if samples.is_empty():
		print("%-46s (no samples)" % label)
		return
	samples.sort()
	var total := 0.0
	for value in samples:
		total += float(value)
	print("%-46s p10 %6.2f  p50 %6.2f  p90 %6.2f  mean %6.2f  (n=%d)" % [
		label,
		_percentile(samples, 0.10), _percentile(samples, 0.50),
		_percentile(samples, 0.90), total / float(samples.size()), samples.size(),
	])


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
