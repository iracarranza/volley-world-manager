extends SceneTree

## Does the ball that leaves a dig become the ball the setter plays?
##
##     godot --headless --path . --script res://tools/run_dig_lineage_probe.gd
##
## **One probe, deliberately.** The dig has been measured by five instruments
## that each saw part of it -- terms, contest, depth, shading, recovery -- and
## none of them followed the ball past the contact. This is the lineage: what
## went in, what left the platform, and whether the set that follows was
## resolved against that exact flight rather than against a constant.
##
## The identity assertion is on physical fields, not on endpoints. Two
## trajectories can share a destination and be different balls; only the same
## origin, duration and apex make them the same object.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 350
const FIRST_SEED: int = 20000


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	## Part E control: the same two fields off a RECEPTION, to test whether the
	## clustered set-contact height is a dig problem or a shared consequence of
	## `min(apex, setter contact height)` in both models.
	var reception_apex: Array = []
	var reception_set_height: Array = []
	var first_dig_attempts := 0
	var first_dig_up := 0
	var attempts := 0
	var successes := 0
	var reached_set := 0
	var lineage_ok := 0
	var lineage_broken := 0
	var emergency := 0
	var jump_sets := 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var seen_first := false
			for index in range(result.events.size()):
				var event: Resource = result.events[index]
				if int(event.event_type) == RallyEventScript.EventType.RECEPTION \
						and bool(event.success):
					reception_apex.append(float(event.metadata.get(
						"pass_apex_meters", 0.0)))
					reception_set_height.append(float(event.metadata.get(
						"set_contact_height_meters", 0.0)))
				if int(event.event_type) != RallyEventScript.EventType.DIG:
					continue
				attempts += 1
				## The first dig of a rally is decided entirely upstream of this
				## pass, so its success rate is the control: if it moves, the
				## change reached something it should not have.
				if not seen_first:
					seen_first = true
					first_dig_attempts += 1
					if bool(event.success):
						first_dig_up += 1
				if not bool(event.success):
					## Event truth: a beaten dig passed nothing.
					if event.metadata.has("outgoing_trajectory") \
							and not Dictionary(
								event.metadata["outgoing_trajectory"]
							).is_empty():
						lineage_broken += 1
					continue
				successes += 1
				var outgoing: Dictionary = event.metadata.get(
					"outgoing_trajectory", {}
				)
				var row := {
					"seed": seed_value,
					"serving_home": serving_home,
					"side": str(event.metadata.get("side", "")),
					"control": float(event.quality),
					"posture": str(event.metadata.get("contact_posture", "")),
					"reach_margin": float(event.metadata.get(
						"reach_margin_meters", 0.0
					)),
					"incoming_speed": float(event.metadata.get(
						"incoming_speed_mps", 0.0
					)),
					"duration": float(event.metadata.get(
						"pass_duration_seconds", 0.0
					)),
					"apex": float(event.metadata.get("pass_apex_meters", 0.0)),
					"set_height": float(event.metadata.get(
						"set_contact_height_meters", 0.0
					)),
					"target_error": float(event.metadata.get(
						"target_error_meters", 0.0
					)),
					"spoil": float(event.metadata.get("pass_spoil", 0.0)),
				}
				var set_event: Resource = _next_set(result.events, index)
				if set_event != null:
					reached_set += 1
					row["set_quality"] = float(set_event.quality)
					row["setter_move"] = float(set_event.metadata.get(
						"movement_duration", 0.0
					))
					if bool(set_event.metadata.get("emergency_setter", false)):
						emergency += 1
						row["emergency"] = true
					if str(set_event.metadata.get("set_posture", "")) == "jump":
						jump_sets += 1
					if _same_ball(outgoing, set_event.metadata.get(
						"incoming_pass_trajectory", {}
					)):
						lineage_ok += 1
					else:
						lineage_broken += 1
						row["broken"] = true
				rows.append(row)
		manager.free()
	_report(rows, attempts, successes, reached_set, lineage_ok, lineage_broken,
		emergency, jump_sets, first_dig_attempts, first_dig_up)
	print("")
	print("=== reception control (Part E) ===")
	_percentiles(reception_apex, "reception apex (m)")
	_percentiles(reception_set_height, "reception set height (m)")
	print("  distinct reception set heights %d" % _distinct(reception_set_height))
	quit()


## The same ball, by physical field rather than by destination.
func _same_ball(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	for key in ["start_position", "end_position"]:
		if Vector2(a.get(key, Vector2.ZERO)).distance_to(
			Vector2(b.get(key, Vector2.ONE))
		) > 0.0005:
			return false
	for key in ["duration", "apex_height_meters", "start_time"]:
		if absf(float(a.get(key, -1.0)) - float(b.get(key, -2.0))) > 0.0005:
			return false
	return true


func _next_set(events: Array, from_index: int) -> Resource:
	for index in range(from_index + 1, events.size()):
		var event: Resource = events[index]
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.SET:
			return event
		if kind in [RallyEventScript.EventType.ATTACK,
				RallyEventScript.EventType.POINT,
				RallyEventScript.EventType.SERVE]:
			return null
	return null


func _percentiles(values: Array, label: String) -> void:
	if values.is_empty():
		print("  %-26s (none)" % label)
		return
	values.sort()
	print("  %-26s p05 %6.3f  p50 %6.3f  p95 %6.3f  n=%d" % [
		label, float(values[int(float(values.size()) * 0.05)]),
		float(values[int(float(values.size()) * 0.50)]),
		float(values[mini(int(float(values.size()) * 0.95), values.size() - 1)]),
		values.size(),
	])


func _report(
	rows: Array[Dictionary], attempts: int, successes: int, reached_set: int,
	lineage_ok: int, lineage_broken: int, emergency: int, jump_sets: int,
	first_attempts: int, first_up: int
) -> void:
	print("=== dig lineage, %d rallies ===" % (RALLIES * 2))
	print("  floor dig attempts        %d" % attempts)
	print("  floor dig success rate    %.4f" % [
		float(successes) / maxf(float(attempts), 1.0)])
	print("  FIRST dig of rally        %d attempts, rate %.4f" % [
		first_attempts, float(first_up) / maxf(float(first_attempts), 1.0)])
	print("  successful digs to a SET  %d of %d" % [reached_set, successes])
	print("  lineage proven            %d" % lineage_ok)
	print("  lineage broken            %d" % lineage_broken)
	print("")
	var by := func(key: String) -> Array:
		var out: Array = []
		for row in rows:
			if row.has(key):
				out.append(float(row[key]))
		return out
	_percentiles(by.call("duration"), "dig->set duration (s)")
	_percentiles(by.call("apex"), "pass apex (m)")
	_percentiles(by.call("set_height"), "set contact height (m)")
	_percentiles(by.call("target_error"), "destination error (m)")
	_percentiles(by.call("spoil"), "platform spoil")
	_percentiles(by.call("set_quality"), "set quality after dig")
	print("")
	print("  emergency setter share    %.4f" % [
		float(emergency) / maxf(float(reached_set), 1.0)])
	print("  jump set share            %.4f" % [
		float(jump_sets) / maxf(float(reached_set), 1.0)])
	## Pathology screen: a model that gives every dig the same ball is not a
	## model, and the failure would otherwise hide inside healthy-looking medians.
	var durations: Array = by.call("duration")
	var apexes: Array = by.call("apex")
	print("  distinct durations        %d" % _distinct(durations))
	print("  distinct apexes           %d" % _distinct(apexes))
	print("")
	print("=== representative seeds ===")
	_exemplar(rows, "clean dig -> designated setter",
		func(r): return float(r.get("spoil", 1.0)) < 0.10 \
			and not bool(r.get("emergency", false)))
	_exemplar(rows, "poor but successful -> setter moves",
		func(r): return float(r.get("spoil", 0.0)) > 0.45 \
			and float(r.get("setter_move", 0.0)) > 0.20)
	_exemplar(rows, "successful dig -> emergency setter",
		func(r): return bool(r.get("emergency", false)))
	_exemplar(rows, "reaching / off-axis dig",
		func(r): return str(r.get("posture", "")) in ["reaching", "off-axis"])
	_exemplar(rows, "later-exchange transition dig",
		func(r): return str(r.get("side", "")) == "opponent" \
			and float(r.get("spoil", 0.0)) > 0.30)


func _exemplar(rows: Array, label: String, test: Callable) -> void:
	for row in rows:
		if test.call(row):
			print("  %-34s seed %d (serving_home=%s) spoil %.3f posture %s err %.2fm" % [
				label, int(row.get("seed", -1)), str(row.get("serving_home", true)),
				float(row.get("spoil", 0.0)), str(row.get("posture", "")),
				float(row.get("target_error", 0.0))])
			return
	print("  %-34s (none found)" % label)


func _distinct(values: Array) -> int:
	var seen := {}
	for value in values:
		seen[snappedf(float(value), 0.01)] = true
	return seen.size()
