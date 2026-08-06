extends SceneTree

## Does the reachability clamp move the hitter out of the lane they were assigned?
##
## `opponent_lane` is derived from the contact the set aimed at.
## `_reachable_contact` then pulls that contact back along the hitter's route to
## wherever they can actually get, and the lane is never re-read -- so the wall is
## restaged against the new contact but the old lane, familiarity accrues to the
## old lane, and the swing is resolved along the old lane's natural course.
##
## Same clamp, same shape, as the stale arrival margin (FAILURE_MODES.md 15).
## This measures whether it also binds.
##
## Run:
##   godot --headless --path . --script res://tools/run_lane_drift_probe.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 150


func _initialize() -> void:
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	ExecutionScale.apply_generated_attributes(manager.players, 900006)
	ExecutionScale.apply_generated_attributes(
		manager.opponent_team.players, 900006
	)
	var total := 0
	var drifted := 0
	var pairs := {}
	var shift_sum := 0.0
	for serving_home in [true, false]:
		manager.match_state.serving_home = serving_home
		for seed_value in range(5000, 5000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw in result.events:
				var event := raw as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.ATTACK \
						or str(event.metadata.get("side", "")) != "opponent":
					continue
				if not event.metadata.has("lane"):
					continue
				var assigned := str(event.metadata.lane)
				var struck := CourtConstants.lane_at_x(
					float(event.metadata.get("lane_x", 0.5))
				)
				total += 1
				if assigned == struck:
					continue
				drifted += 1
				var key := "%s -> %s" % [assigned, struck]
				pairs[key] = int(pairs.get(key, 0)) + 1
				shift_sum += absf(
					CourtConstants.lane_target(assigned).x
					- float(event.metadata.get("lane_x", 0.5))
				)
	manager.free()

	print("Lane drift across the reachability clamp -- %d rallies x 2 sides"
		% RALLIES)
	print("")
	if total == 0:
		print("no opponent attacks carried a lane")
		quit()
		return
	print("%d of %d opponent swings were struck outside the lane they were" % [
		drifted, total])
	print("assigned (%.0f%%)." % [float(drifted) / float(total) * 100.0])
	if drifted > 0:
		print("mean lateral shift from the assigned lane's target: %.3f court widths"
			% (shift_sum / float(drifted)))
	print("")
	var keys: Array = pairs.keys()
	keys.sort()
	for key in keys:
		print("  %-28s %d" % [str(key), int(pairs[key])])
	print("")
	print("Every drifted row is a swing whose wall, familiarity and natural")
	print("course were all resolved for a lane it was not hit from.")
	quit()
