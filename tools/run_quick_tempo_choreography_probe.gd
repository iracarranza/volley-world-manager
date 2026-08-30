extends SceneTree

const Events := preload("res://scripts/models/rally_event.gd")
const SpikeBiomechanics := preload("res://scripts/data/spike_biomechanics.gd")
const BallPresentationModel := preload("res://scripts/simulation/ball_presentation.gd")
const MatchScreenModel := preload("res://scenes/screens/match_screen.gd")

const FROM_SEED: int = 24000
const RALLIES: int = 600
const EPSILON: float = 0.00001


func _initialize() -> void:
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()
	var records: Array[Dictionary] = []
	var requested := {}
	var achieved := {}
	var clock_errors := 0
	var takeoff_clock_errors := 0
	var pose_seams := 0
	for seed_value in range(FROM_SEED, FROM_SEED + RALLIES):
		var serving_home := seed_value % 2 == 0
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(seed_value)
		for event_index in range(result.events.size()):
			var attack: Resource = result.events[event_index]
			if int(attack.event_type) != Events.EventType.ATTACK: continue
			var timing: Dictionary = attack.metadata.get("tempo_coordination", {})
			if timing.is_empty(): continue
			var achieved_tempo := int(timing.get("achieved_tempo", attack.metadata.get("achieved_tempo", 3)))
			var requested_tempo := int(attack.metadata.get("requested_tempo", attack.metadata.get("tempo", 3)))
			requested[requested_tempo] = int(requested.get(requested_tempo, 0)) + 1
			achieved[achieved_tempo] = int(achieved.get(achieved_tempo, 0)) + 1
			if achieved_tempo > 1: continue
			var set_event := _previous_set(result.events, event_index, str(attack.metadata.get("side", "")))
			if set_event == null: continue
			var preparation: Dictionary = attack.metadata.get("transition_preparation", {})
			var release_time := float(set_event.metadata.get("event_time", 0.0))
			var contact_time := float(attack.metadata.get("event_time", release_time))
			var duration := float(timing.get("delivered_flight_seconds", attack.metadata.get("set_flight_time", 0.0)))
			if absf(contact_time - release_time - duration) > EPSILON: clock_errors += 1
			var release_progress := clampf(float(timing.get("achieved_release_progress", 0.0)), 0.0, 1.0)
			var release_phase := MatchScreenModel._attack_release_phase(attack)
			## The pre-release helper ends here; `_incoming_pose_phase(..., 0)`
			## begins at the same expression. A mismatch would be a pose reset at
			## setter release even while the ball clock remains continuous.
			var incoming_start_phase := MatchScreenModel._incoming_pose_phase(attack, 0.0)
			if absf(release_phase - incoming_start_phase) > EPSILON: pose_seams += 1
			var physical_takeoff := release_time + float(timing.get("takeoff_offset_seconds", 0.0))
			if absf(contact_time - physical_takeoff - float(timing.get(
				"takeoff_to_contact_seconds", 0.0
			))) > EPSILON:
				takeoff_clock_errors += 1
			records.append({
				"seed": seed_value,
				"serving": "home" if serving_home else "opponent",
				"event_index": event_index,
				"requested": requested_tempo,
				"achieved": achieved_tempo,
				"release_progress": float(timing.get("release_progress", 0.0)),
				"achieved_release_progress": release_progress,
				"preparation": float(preparation.get("preparation_time_seconds", 0.0)),
				"approach_begins": float(preparation.get("release_time", release_time)),
				"approach_start": preparation.get("approach_start_position", attack.metadata.get("full_approach_start_position", Vector2.ZERO)),
				"staged_position": preparation.get("prepared_position", attack.metadata.get("approach_start_position", Vector2.ZERO)),
				"takeoff_offset": float(timing.get("takeoff_offset_seconds", 0.0)),
				"takeoff_to_contact": float(timing.get("takeoff_to_contact_seconds", 0.0)),
				"duration": duration,
				"release_time": release_time,
				"contact_time": contact_time,
				"set_distance": float(set_event.metadata.get("set_distance_meters", 0.0)),
				"release_height": BallPresentationModel.contact_height(
					set_event, result.player_physical_profiles
				),
				"contact_height": BallPresentationModel.contact_height(
					attack, result.player_physical_profiles
				),
			})

	var t0 := _for_tempo(records, 0)
	var t1 := _for_tempo(records, 1)
	print("quick-tempo choreography -- %d deterministic rallies" % RALLIES)
	print("  requested counts %s" % str(requested))
	print("  achieved counts  %s" % str(achieved))
	_report("T0", t0)
	_report("T1", t1)
	print("  physical clock errors %d" % clock_errors)
	print("  takeoff clock errors  %d" % takeoff_clock_errors)
	print("  release pose seams    %d" % pose_seams)
	if not t1.is_empty():
		t1.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.duration) < float(b.duration))
		_trace("near-minimum T1", t1[0])
		_trace("median T1", t1[t1.size() / 2])
	var ok := not t1.is_empty() and clock_errors == 0 \
		and takeoff_clock_errors == 0 and pose_seams == 0 \
		and _all_have_preparation(t1)
	print("\n%s: quick-tempo physical/presentation clock gates" % ("PASS" if ok else "FAIL"))
	manager.free()
	quit(0 if ok else 1)


func _previous_set(events: Array, before: int, side: String) -> Resource:
	for index in range(before - 1, -1, -1):
		var event: Resource = events[index]
		if int(event.event_type) == Events.EventType.SET \
			and str(event.metadata.get("side", "")) == side:
			return event
	return null


func _for_tempo(records: Array[Dictionary], tempo: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for record in records:
		if int(record.achieved) == tempo: filtered.append(record)
	return filtered


func _report(label: String, records: Array[Dictionary]) -> void:
	if records.is_empty():
		print("  %s: n=0" % label)
		return
	var durations := _values(records, "duration")
	durations.sort()
	var minimum_count := 0
	var preparation_total := 0.0
	for record in records:
		if float(record.duration) <= 0.100001: minimum_count += 1
		preparation_total += float(record.preparation)
	print("  %s: n=%d  duration p05/p25/p50/p75/p95 %.3f / %.3f / %.3f / %.3f / %.3f s" % [
		label, records.size(), _percentile(durations, 0.05), _percentile(durations, 0.25),
		_percentile(durations, 0.50), _percentile(durations, 0.75), _percentile(durations, 0.95),
	])
	print("      at 0.10 s minimum %d (%.1f%%); mean preparation %.3f s" % [
		minimum_count, 100.0 * float(minimum_count) / float(records.size()),
		preparation_total / float(records.size()),
	])
	print("      median flight visible %.3f s at 1x / %.3f s at 0.25x; with prep %.3f / %.3f s" % [
		_percentile(durations, 0.50), _percentile(durations, 0.50) / 0.25,
		_percentile(durations, 0.50) + preparation_total / float(records.size()),
		(_percentile(durations, 0.50) + preparation_total / float(records.size())) / 0.25,
	])


func _trace(label: String, record: Dictionary) -> void:
	var approach_begins := float(record.approach_begins)
	var preparation := float(record.preparation)
	var plant_begins := approach_begins + preparation * 0.76
	var release := float(record.release_time)
	var takeoff := release + float(record.takeoff_offset)
	var contact := float(record.contact_time)
	print("\n  %s fixture: seed %d, %s serving, event %d" % [
		label, record.seed, record.serving, record.event_index,
	])
	print("    requested/achieved T%d/T%d; release progress %.3f/%.3f" % [
		record.requested, record.achieved, record.release_progress,
		record.achieved_release_progress,
	])
	print("    approach begins %.3f  %s -> staged %s" % [
		approach_begins, record.approach_start, record.staged_position,
	])
	print("    plant begins    %.3f" % plant_begins)
	print("    setter releases %.3f" % release)
	print("    hitter takes off %.3f (offset %+.3f)" % [takeoff, record.takeoff_offset])
	print("    ball meets hand %.3f (takeoff-to-contact %.3f)" % [contact, record.takeoff_to_contact])
	print("    attack departs  %.3f" % contact)
	print("    set flight %.3f s, distance %.3f m, heights %.3f -> %.3f m" % [
		record.duration, record.set_distance, record.release_height, record.contact_height,
	])


func _all_have_preparation(records: Array[Dictionary]) -> bool:
	for record in records:
		if float(record.preparation) <= 0.0: return false
	return true


func _values(records: Array[Dictionary], key: String) -> Array[float]:
	var values: Array[float] = []
	for record in records: values.append(float(record[key]))
	return values


func _percentile(sorted_values: Array[float], fraction: float) -> float:
	if sorted_values.is_empty(): return 0.0
	var index := clampi(roundi((sorted_values.size() - 1) * fraction), 0, sorted_values.size() - 1)
	return sorted_values[index]
