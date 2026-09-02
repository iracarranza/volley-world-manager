extends SceneTree

## Change 1's proof: is the contact actor's leg drawn on its own journey's clock?
##
##     godot --headless --path . --script res://tools/run_contact_leg_pacing.gd
##
## `movement_duration` times the trip to the *ball*; `movement_target` is as far
## as the body got inside the budget it was truncated against. Pairing the two
## drew a short leg on a long clock -- measured at 0.59 m/s for a beaten digger
## whose own shuffle is 2.05 m/s. `movement_available_seconds` publishes the
## budget so `_pace_plan` can clamp to it.
##
## This reproduces both pacing rules from published metadata alone and prints
## them side by side, so the change is falsifiable without a rendered frame:
##
##     old: seconds = max(metres / speed, movement_duration)
##     new: seconds = max(metres / speed, min(movement_duration, budget))
##
## `speed` and the `max` are `match_screen._pace_plan`'s, reproduced here rather
## than imported because a probe that called into the screen would be measuring
## the screen's live state instead of the record.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 150

const COURT_W: float = 9.0
const COURT_L: float = 18.0

## `match_screen.PLAUSIBLE_TOP_SPEED_MPS`.
const PLAUSIBLE_TOP_SPEED_MPS: float = 7.0


func _metres(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	return Vector2(delta.x * COURT_W, delta.y * COURT_L).length()


func _initialize() -> void:
	var families := {}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var profiles: Dictionary = result.player_physical_profiles
			var events: Array = result.events
			for index in range(events.size() - 1):
				var from_event: Resource = events[index]
				var to_event: Resource = events[index + 1]
				if from_event == null or to_event == null:
					continue
				var meta: Dictionary = to_event.metadata
				if not meta.has("movement_duration") \
						or not meta.has("movement_target"):
					continue
				var start := Vector2(meta.get("movement_start", Vector2.ZERO))
				var target := Vector2(meta["movement_target"])
				var distance := _metres(start, target)
				var duration := maxf(float(meta["movement_duration"]), 0.0)
				if duration <= 0.0:
					continue
				var budget := float(meta.get("movement_available_seconds", -1.0))
				var window := float(meta.get("physical_time", -1.0)) \
					- float(from_event.metadata.get("physical_time", -1.0))
				var physical: Dictionary = profiles.get(int(to_event.actor_id), {})
				var speed := maxf(float(physical.get(
					"transition_speed_mps", PLAUSIBLE_TOP_SPEED_MPS
				)), 0.01)
				var old_seconds := maxf(distance / speed, duration)
				var clamped := duration
				if budget > 0.0:
					clamped = minf(duration, budget)
				var new_seconds := maxf(distance / speed, clamped)
				var key := "%s->%s%s" % [
					RallyEventScript.EventType.keys()[int(from_event.event_type)],
					RallyEventScript.EventType.keys()[int(to_event.event_type)],
					"" if bool(to_event.success) else " (failed)",
				]
				var bucket: Dictionary = families.get(key, {
					"n": 0, "budgeted": 0, "truncated": 0,
					"old_v": 0.0, "new_v": 0.0, "distance": 0.0,
					"old_fits": 0, "new_fits": 0, "early": 0,
					"window": 0.0, "old_s": 0.0, "new_s": 0.0,
					"budget": 0.0, "over_window": 0,
					"ready": 0.0, "ready_n": 0, "ready_fits": 0, "overrun": 0.0,
				})
				bucket["n"] = int(bucket.n) + 1
				bucket["distance"] = float(bucket.distance) + distance
				bucket["window"] = float(bucket.window) + window
				bucket["old_s"] = float(bucket.old_s) + old_seconds
				bucket["new_s"] = float(bucket.new_s) + new_seconds
				bucket["old_v"] = float(bucket.old_v) + distance / old_seconds
				bucket["new_v"] = float(bucket.new_v) + distance / new_seconds
				if budget > 0.0:
					bucket["budgeted"] = int(bucket.budgeted) + 1
					bucket["budget"] = float(bucket.budget) + budget
					if window > 0.0 and budget > window + 0.001:
						bucket["over_window"] = int(bucket.over_window) + 1
					if duration > budget:
						bucket["truncated"] = int(bucket.truncated) + 1
					elif new_seconds < budget:
						## The resolver said this body had time to spare, so the
						## drawn leg finishes before the deadline and the player
						## stands. That is a thing a volleyball player does and
						## the old rule could not express it.
						bucket["early"] = int(bucket.early) + 1
				var ready := float(meta.get("movement_ready_seconds", -1.0))
				if ready >= 0.0:
					bucket["ready_n"] = int(bucket.ready_n) + 1
					bucket["ready"] = float(bucket.ready) + ready
					if budget > 0.0:
						var overrun := ready + clamped - budget
						if overrun <= 0.0:
							bucket["ready_fits"] = int(bucket.ready_fits) + 1
						else:
							bucket["overrun"] = float(bucket.overrun) + overrun
				if window > 0.0:
					if old_seconds <= window:
						bucket["old_fits"] = int(bucket.old_fits) + 1
					if new_seconds <= window:
						bucket["new_fits"] = int(bucket.new_fits) + 1
				families[key] = bucket
	print("family|n|budgeted|truncated|arrive_early|mean_dist_m|mean_window_s"
		+ "|old_s|new_s|old_mps|new_mps|old_fits|new_fits"
		+ "|mean_budget_s|budget>window|ready_n|mean_ready_s|ready_fits|mean_overrun_s")
	var keys: Array = families.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = families[key]
		var n := maxf(float(b.n), 1.0)
		print("%s|%d|%d|%d|%d|%.2f|%.3f|%.3f|%.3f|%.2f|%.2f|%d|%d|%.3f|%d|%d|%.3f|%d|%.3f" % [
			key, int(b.n), int(b.budgeted), int(b.truncated), int(b.early),
			float(b.distance) / n, float(b.window) / n,
			float(b.old_s) / n, float(b.new_s) / n,
			float(b.old_v) / n, float(b.new_v) / n,
			int(b.old_fits), int(b.new_fits),
			float(b.budget) / maxf(float(b.budgeted), 1.0), int(b.over_window),
			int(b.ready_n), float(b.ready) / maxf(float(b.ready_n), 1.0),
			int(b.ready_fits),
			float(b.overrun) / maxf(float(int(b.ready_n) - int(b.ready_fits)), 1.0),
		])
	quit()
