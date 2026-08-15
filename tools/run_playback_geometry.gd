extends SceneTree

## Three things playback draws that the resolver has to state correctly first.
##
## Each was reported from watching the 3D view, and each turned out to be the
## resolver handing playback a number that could not be drawn any other way.
##
## 1. **When does a blocker leave the ground?** A block happens partway through
##    the swing it contests, at the tape -- not when that swing finishes. Reported
##    as the blocker rising *after* the ball had already landed. Measured here as
##    the gap between the attack's contact and the block's stamped moment, against
##    the attack's own flight time: a healthy block sits a small fraction in, and a
##    broken one sits at or past 1.0.
##
## 2. **How far apart are the two blockers?** `_floor_phase_positions` handed both
##    the same point, so their bodies were stacked by construction. Measured as the
##    metres between the primary's and the assist's staged positions.
##
## 3. **Where does the server stand?** The ball has always launched from behind the
##    baseline while the server was placed inside the court. Measured as the gap
##    between the serve's launch point and the server's own position at rally start.
##
## Run:
##   godot --headless --path . --script res://tools/run_playback_geometry.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const RallyKinematicsScript := preload("res://scripts/simulation/rally_kinematics.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90


func _initialize() -> void:
	var block_fractions: Array = []
	var late_blocks := 0
	var wall_gaps: Array = []
	var stacked := 0
	var serve_gaps: Array = []
	var serve_inside := 0
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				var starts: Dictionary = result.initial_home_positions.duplicate()
				starts.merge(result.initial_opponent_positions)
				for raw_event in result.events:
					var event := raw_event as RallyEvent
					if event == null:
						continue
					if event.event_type == RallyEventScript.EventType.SERVE:
						var stand: Vector2 = starts.get(
							int(event.actor_id), event.start_position
						)
						var gap := RallyKinematicsScript.court_delta_meters(
							stand, event.start_position
						).length()
						serve_gaps.append(gap)
						if gap > 0.30:
							serve_inside += 1
					elif event.event_type == RallyEventScript.EventType.BLOCK:
						var incoming: Dictionary = event.metadata.get(
							"incoming_trajectory", {}
						)
						var duration := float(incoming.get("duration", 0.0))
						if duration > 0.001:
							var swing := float(incoming.get("start_time", 0.0))
							var fraction := (
								float(event.metadata.get("physical_time", swing)) - swing
							) / duration
							block_fractions.append(fraction)
							if fraction > 0.9:
								late_blocks += 1
						var primary: Vector2 = event.metadata.get(
							"primary_position", Vector2.ZERO
						)
						var assist_id := int(event.metadata.get("assist_id", -1))
						if assist_id >= 0:
							var phase: Dictionary = _phase_targets(event)
							if phase.has(assist_id) and phase.has(int(event.actor_id)):
								var wall_gap := RallyKinematicsScript.court_delta_meters(
									Vector2(phase[int(event.actor_id)]),
									Vector2(phase[assist_id]),
								).length()
								wall_gaps.append(wall_gap)
								if wall_gap < 0.05:
									stacked += 1
			manager.free()

	print("Playback geometry -- %d pairings x %d rallies, both service sides"
		% [PAIRINGS, RALLIES])
	print("")
	block_fractions.sort()
	wall_gaps.sort()
	serve_gaps.sort()
	print("1. block moment, as a fraction of the swing's flight")
	print("   p10 %.3f  p50 %.3f  p90 %.3f   (n=%d)  at or past the landing: %d" % [
		_percentile(block_fractions, 0.10), _percentile(block_fractions, 0.50),
		_percentile(block_fractions, 0.90), block_fractions.size(), late_blocks,
	])
	print("   A block belongs early in the flight. 1.0 means the hands moved after")
	print("   the ball had already landed, which is what was being watched.")
	print("")
	print("2. metres between the two blockers, where a wall was staged")
	print("   p10 %.3f  p50 %.3f  p90 %.3f   (n=%d)  stacked (<0.05 m): %d" % [
		_percentile(wall_gaps, 0.10), _percentile(wall_gaps, 0.50),
		_percentile(wall_gaps, 0.90), wall_gaps.size(), stacked,
	])
	print("")
	print("3. metres between the server and the ball they struck")
	print("   p10 %.3f  p50 %.3f  p90 %.3f   (n=%d)  standing off it (>0.30 m): %d" % [
		_percentile(serve_gaps, 0.10), _percentile(serve_gaps, 0.50),
		_percentile(serve_gaps, 0.90), serve_gaps.size(), serve_inside,
	])
	quit()


## Whichever side's staging this block belongs to. Both are stamped on the swing
## that preceded it, so the block event carries only one of them.
func _phase_targets(event: RallyEvent) -> Dictionary:
	var home: Dictionary = event.metadata.get("home_phase_targets", {})
	if not home.is_empty():
		return home
	return event.metadata.get("opponent_phase_targets", {})


func _percentile(sorted_samples: Array, fraction: float) -> float:
	if sorted_samples.is_empty():
		return 0.0
	var index := clampi(
		int(round(fraction * float(sorted_samples.size() - 1))),
		0, sorted_samples.size() - 1,
	)
	return float(sorted_samples[index])
