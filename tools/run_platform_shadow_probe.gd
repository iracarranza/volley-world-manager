extends SceneTree

## M4 slice 2: evaluate the authored shared T1–T3 layer in shadow.
##
##     godot --headless --path . \
##       --script res://tools/run_platform_shadow_probe.gd
##
## The probe resolves ordinary rallies, reconstructs only already-published
## contact facts, and calls `PlatformContactModel`. It never writes the shadow
## result back into a RallyEvent and never changes the production ball.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const PlatformModel := preload(
	"res://scripts/simulation/platform_contact_model.gd"
)
const GeometricPromotion := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300
const LEVERAGE_SAMPLES: int = 400
const LEVERAGE_FIRST_SEED: int = 61000

var failures: int = 0


func _initialize() -> void:
	var rows := _sweep()
	_print_calibration_contract()
	_print_population(rows)
	_print_satisfiability(rows)
	_print_legacy_against_envelope(rows)
	_print_attribute_leverage()
	_run_architecture_gates()
	if failures == 0:
		print("\nPASS: shared platform shadow gates")
		quit(0)
	else:
		push_error("FAIL: %d shared platform shadow gates" % failures)
		quit(1)


func _sweep() -> Array:
	var rows: Array = []
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally == null:
				manager.free()
				continue
			var home_by_id := _players_by_id(manager.players)
			var opponent_by_id := _players_by_id(
				manager.opponent_team.players if manager.opponent_team != null else []
			)
			for entry in rally.events:
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
					seed_value,
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
	var result := {}
	for entry in players:
		var player := entry as VolleyballPlayer
		if player != null:
			result[player.id] = player
	return result


func _row(
	event: RallyEvent,
	family: String,
	player: VolleyballPlayer,
	seed_value: int,
) -> Dictionary:
	var metadata: Dictionary = event.metadata
	var incoming_data: Dictionary = metadata.get("incoming_trajectory", {})
	var outgoing_data: Dictionary = metadata.get("outgoing_trajectory", {})
	if family == "attack_coverage":
		## Event normalisation supplies only a display fallback here.
		outgoing_data = {}
	var legacy_outgoing := PlatformModel.outgoing_velocity_at_launch(outgoing_data)
	var contact_height := float(metadata.get("pass_contact_height_meters", 0.0))
	if contact_height <= 0.0 and not outgoing_data.is_empty() \
			and str(outgoing_data.get("height_source", "default")) in [
				"resolved", "start_resolved",
			]:
		contact_height = float(outgoing_data.get("start_height_meters", 0.0))
	if contact_height <= 0.0 and player != null:
		contact_height = GeometricPromotion.pass_contact_height_meters(player)
	var incoming := PlatformModel.incoming_velocity_at_contact(
		incoming_data, contact_height
	)
	var intent: Dictionary = metadata.get("platform_intent", {})
	var target_value: Variant = intent.get("target_anchor", null)
	var height_value: Variant = intent.get("height_anchor_meters", null)
	var floor_value: Variant = intent.get("arrival_floor_seconds", 0.0)
	var body_velocity := _body_velocity(metadata, incoming_data)
	var severity := _circumstance_severity(metadata)
	var stability := 0.5
	var technique := 0.5
	if player != null:
		stability = (
			float(player.reception_balance) + float(player.reception_stability)
		) / 200.0
		technique = (
			float(player.reception) + float(player.ball_control)
		) / 200.0
	var shadow := {}
	if bool(incoming.get("available", false)):
		shadow = PlatformModel.evaluate({
			"incoming_velocity_mps": incoming.velocity_mps,
			"contact_position": event.start_position,
			"contact_height_meters": contact_height,
			"body_velocity_mps": body_velocity,
			"circumstance_severity": severity,
			"stability_ability": stability,
			"technique_ability": technique,
			"intent_target_anchor": target_value,
			"intent_height_anchor_meters": height_value,
			"intent_arrival_floor_seconds": floor_value \
				if floor_value is float or floor_value is int else 0.0,
			"seed": hash("%d|platform|%d" % [seed_value, event.actor_id]),
		})
	var legacy_inside := false
	if bool(shadow.get("available", false)) \
			and bool(legacy_outgoing.get("available", false)):
		var velocity := Vector3(legacy_outgoing.velocity_mps)
		legacy_inside = velocity.length() \
			<= float(shadow.maximum_outgoing_speed_mps) + 0.0001 \
			and rad_to_deg(Vector3(shadow.natural_direction).angle_to(
				velocity.normalized()
			)) <= float(shadow.redirection_half_angle_degrees) + 0.0001
	return {
		"family": family,
		"success": event.success,
		"incoming": incoming,
		"legacy_outgoing": legacy_outgoing,
		"legacy_inside": legacy_inside,
		"shadow": shadow,
		"severity": severity,
	}


func _body_velocity(metadata: Dictionary, incoming: Dictionary) -> Vector2:
	if not metadata.has("movement_start") or not metadata.has("movement_target"):
		return Vector2.ZERO
	var start := Vector2(metadata.movement_start)
	var target := Vector2(metadata.movement_target)
	var available := float(incoming.get(
		"duration", metadata.get("flight_time", 0.0)
	))
	var required := float(metadata.get("movement_duration", -1.0))
	var duration := minf(required, available) \
		if required > 0.0 and available > 0.0 else available
	if duration <= 0.0001:
		return Vector2.ZERO
	return Vector2(
		(target.x - start.x) * CourtConstants.COURT_WIDTH_METERS / duration,
		(target.y - start.y) * CourtConstants.COURT_LENGTH_METERS / duration,
	)


## One dimensionless circumstance signal, independent of event family. The
## arrival model already publishes distance / assigned reach as `edge_ratio`.
## Body alignment can only make the constraint stricter; `max`, rather than a
## weighted blend, prevents a new constant from deciding which physical fact
## matters more.
func _circumstance_severity(metadata: Dictionary) -> float:
	var arrival: Dictionary = metadata.get("arrival", {})
	var edge := float(arrival.get("edge_ratio", 0.0))
	var alignment_severity := 0.0
	if metadata.has("body_alignment"):
		alignment_severity = 1.0 - float(metadata.body_alignment)
	elif metadata.has("movement_alignment"):
		alignment_severity = 1.0 - float(metadata.movement_alignment)
	return clampf(maxf(edge, alignment_severity), 0.0, 1.0)


func _print_calibration_contract() -> void:
	print("=".repeat(92))
	print("M4 SHARED PLATFORM SHADOW -- CATEGORY-3 GAME ABSTRACTION")
	print("=".repeat(92))
	print("  T1 pace retained       %.2f" % PlatformModel.PACE_RETENTION)
	print("  T1 active generation   %.2f m/s" % PlatformModel.ACTIVE_GENERATION_MPS)
	print("  T2 planted half-angle  %.1f deg" % \
		PlatformModel.PLANTED_REDIRECTION_HALF_ANGLE_DEGREES)
	print("  T2 maximum narrowing   %.0f%%" % \
		(PlatformModel.MAX_CIRCUMSTANCE_NARROWING_SHARE * 100.0))
	print("  T3 weak / elite sigma  %.1f / %.1f deg" % [
		PlatformModel.WEAK_TECHNIQUE_SIGMA_DEGREES,
		PlatformModel.ELITE_TECHNIQUE_SIGMA_DEGREES,
	])
	print("  These are authored game calibration, not biomechanical measurements.\n")


func _print_population(rows: Array) -> void:
	print("=".repeat(92))
	print("POPULATION AVAILABILITY -- 600 FIXED RALLIES")
	print("=".repeat(92))
	print("  %-20s %7s %9s %10s %11s %12s" % [
		"family", "events", "physical", "selection", "satisfiable", "realised",
	])
	for family in _families(rows):
		var subset: Array = rows.filter(func(row): return row.family == family)
		var physical := 0
		var selection := 0
		var satisfiable := 0
		var realised := 0
		for row in subset:
			var shadow: Dictionary = row.shadow
			physical += 1 if bool(shadow.get("available", false)) else 0
			selection += 1 if bool(shadow.get("selection_available", false)) else 0
			satisfiable += 1 if bool(shadow.get("intent_satisfiable", false)) else 0
			realised += 1 if shadow.has("realised_velocity_mps") else 0
		print("  %-20s %7d %9d %10d %11d %12d" % [
			family, subset.size(), physical, selection, satisfiable, realised,
		])
	print("\n  Coverage now supplies complete physical contact state on this population.")
	print("  Its height/floor intent remains unset and no keep-alive preference exists,")
	print("  so T1–T3 describe the envelope but deliberately select no outgoing ball.")


func _print_satisfiability(rows: Array) -> void:
	print("\n" + "=".repeat(92))
	print("INTENT SATISFIABILITY AND BINDING CONSTRAINT")
	print("=".repeat(92))
	for family in _families(rows):
		var subset: Array = rows.filter(func(row): return row.family == family)
		var bindings := {}
		var speed_caps: Array = []
		var cone_widths: Array = []
		var selected_errors: Array = []
		var realised_errors: Array = []
		var realised_speeds: Array = []
		var realised_angles: Array = []
		var realised_apexes: Array = []
		var realised_durations: Array = []
		var realised_ranges: Array = []
		for row in subset:
			var shadow: Dictionary = row.shadow
			if not bool(shadow.get("available", false)):
				bindings["physical_state_missing"] = int(bindings.get(
					"physical_state_missing", 0
				)) + 1
				continue
			speed_caps.append(float(shadow.maximum_outgoing_speed_mps))
			cone_widths.append(float(shadow.redirection_half_angle_degrees))
			if not bool(shadow.get("selection_available", false)):
				var unavailable_reason := str(shadow.get(
					"reason", "selection_unavailable"
				)).replace(" ", "_")
				bindings[unavailable_reason] = int(bindings.get(
					unavailable_reason, 0
				)) + 1
				continue
			var binding := str(shadow.get("binding_constraint", "missing"))
			bindings[binding] = int(bindings.get(binding, 0)) + 1
			selected_errors.append(float(Dictionary(shadow.selected).spatial_error_meters))
			realised_errors.append(float(Dictionary(shadow.realised).spatial_error_meters))
			var realised: Dictionary = shadow.realised
			realised_speeds.append(float(shadow.realised_speed_mps))
			realised_angles.append(float(realised.launch_angle_degrees))
			realised_apexes.append(float(realised.apex_height_meters))
			realised_durations.append(float(realised.floor_duration_seconds))
			realised_ranges.append(float(realised.floor_range_meters))
		print("  %s" % family)
		print("    binding: %s" % _counts_text(bindings))
		print("    speed ceiling min/p50/max: %s m/s" % _stats_text(speed_caps))
		print("    cone half-angle min/p50/max: %s deg" % _stats_text(cone_widths))
		print("    selected anchor error min/p50/max: %s m" % \
			_stats_text(selected_errors))
		print("    realised anchor error min/p50/max: %s m" % \
			_stats_text(realised_errors))
		print("    realised launch speed min/p50/max: %s m/s" % \
			_stats_text(realised_speeds))
		print("    realised launch angle min/p50/max: %s deg" % \
			_stats_text(realised_angles))
		print("    realised apex height min/p50/max: %s m" % \
			_stats_text(realised_apexes))
		print("    realised floor time min/p50/max: %s s" % \
			_stats_text(realised_durations))
		print("    realised floor range min/p50/max: %s m" % \
			_stats_text(realised_ranges))


func _print_legacy_against_envelope(rows: Array) -> void:
	print("\n" + "=".repeat(92))
	print("LEGACY BALL AGAINST SHADOW FEASIBLE SPACE -- DESCRIPTION, NOT A TARGET")
	print("=".repeat(92))
	for family in _families(rows):
		var comparable: Array = rows.filter(func(row):
			return row.family == family \
				and bool(Dictionary(row.shadow).get("available", false)) \
				and bool(Dictionary(row.legacy_outgoing).get("available", false))
		)
		var inside := comparable.filter(func(row): return row.legacy_inside).size()
		print("  %-20s %4d / %-4d inside (%.1f%%)" % [
			family, inside, comparable.size(),
			100.0 * float(inside) / maxf(float(comparable.size()), 1.0),
		])
	print("  A legacy ball outside the envelope diagnoses the old bands. It does")
	print("  not widen the authored shadow and is not used to tune these constants.")


func _print_attribute_leverage() -> void:
	print("\n" + "=".repeat(92))
	print("SHADOW ATTRIBUTE LEVERAGE -- IDENTICAL BALL, BODY, INTENT AND DRAWS")
	print("=".repeat(92))
	print("  %-7s %-11s %-11s %-13s %-13s %-11s" % [
		"rating", "easy cap", "hard cap", "easy error", "hard error", "hard exact",
	])
	var previous_easy_error := INF
	var previous_hard_error := INF
	var previous_easy_cap := -INF
	var previous_hard_cap := -INF
	for level in [20, 40, 60, 80]:
		var easy := _leverage_measure(level, 0.12)
		var hard := _leverage_measure(level, 0.88)
		print("  %-7d %-11.2f %-11.2f %-13.3f %-13.3f %10.1f%%" % [
			level, float(easy.speed_cap), float(hard.speed_cap),
			float(easy.mean_error), float(hard.mean_error),
			float(hard.exact_rate) * 100.0,
		])
		_gate(float(easy.speed_cap) > previous_easy_cap,
			"easy-contact T1 capacity rises with stability")
		_gate(float(hard.speed_cap) > previous_hard_cap,
			"difficult-contact T1 capacity rises with stability")
		_gate(float(easy.mean_error) < previous_easy_error,
			"easy-contact T3 error falls with technique")
		_gate(float(hard.mean_error) < previous_hard_error,
			"difficult-contact T3 error falls with technique")
		previous_easy_cap = float(easy.speed_cap)
		previous_hard_cap = float(hard.speed_cap)
		previous_easy_error = float(easy.mean_error)
		previous_hard_error = float(hard.mean_error)


func _leverage_measure(level: int, severity: float) -> Dictionary:
	var total_error := 0.0
	var exact := 0
	var selected := 0
	var speed_cap := 0.0
	for offset in range(LEVERAGE_SAMPLES):
		var result := PlatformModel.evaluate({
			"incoming_velocity_mps": Vector3(-1.0, -8.0, 14.0),
			"contact_position": Vector2(0.35, 0.78),
			"contact_height_meters": 1.0,
			"body_velocity_mps": Vector2(0.2, -0.4),
			"circumstance_severity": severity,
			"stability_ability": float(level) / 100.0,
			"technique_ability": float(level) / 100.0,
			"intent_target_anchor": Vector2(0.52, 0.60),
			"intent_height_anchor_meters": 2.20,
			"intent_arrival_floor_seconds": 0.55,
			"seed": LEVERAGE_FIRST_SEED + offset,
		})
		speed_cap = float(result.maximum_outgoing_speed_mps)
		if not bool(result.get("selection_available", false)):
			continue
		selected += 1
		exact += 1 if bool(result.intent_satisfiable) else 0
		total_error += float(Dictionary(result.realised).spatial_error_meters)
	return {
		"speed_cap": speed_cap,
		"mean_error": total_error / maxf(float(selected), 1.0),
		"exact_rate": float(exact) / maxf(float(selected), 1.0),
		"selected_rate": float(selected) / LEVERAGE_SAMPLES,
	}


func _run_architecture_gates() -> void:
	print("\n" + "=".repeat(92))
	print("ARCHITECTURE GATES")
	print("=".repeat(92))
	var base := {
		"incoming_velocity_mps": Vector3(0.0, -7.0, 13.0),
		"contact_position": Vector2(0.32, 0.80),
		"contact_height_meters": 1.0,
		"body_velocity_mps": Vector2.ZERO,
		"circumstance_severity": 0.15,
		"stability_ability": 0.65,
		"technique_ability": 0.65,
		"intent_target_anchor": Vector2(0.52, 0.61),
		"intent_height_anchor_meters": 2.18,
		"intent_arrival_floor_seconds": 0.50,
		"seed": 77001,
	}
	var ordinary := PlatformModel.evaluate(base)
	var renamed := base.duplicate(true)
	renamed["event_family"] = "anything"
	renamed["result_label"] = "SHANK"
	var label_free := PlatformModel.evaluate(renamed)
	_gate(ordinary == label_free,
		"event family and result label cannot reach the shared model")

	var other_intent := base.duplicate(true)
	other_intent["intent_target_anchor"] = Vector2(0.20, 0.68)
	var changed_intent := PlatformModel.evaluate(other_intent)
	_gate(is_equal_approx(
		float(ordinary.maximum_outgoing_speed_mps),
		float(changed_intent.maximum_outgoing_speed_mps),
	) and is_equal_approx(
		float(ordinary.redirection_half_angle_degrees),
		float(changed_intent.redirection_half_angle_degrees),
	), "intent changes selection but never the physical envelope")

	var slow := base.duplicate(true)
	var fast := base.duplicate(true)
	slow["incoming_velocity_mps"] = Vector3(0.0, -3.0, 5.0)
	fast["incoming_velocity_mps"] = Vector3(0.0, -12.0, 28.0)
	_gate(
		float(PlatformModel.evaluate(fast).maximum_outgoing_speed_mps)
			> float(PlatformModel.evaluate(slow).maximum_outgoing_speed_mps),
		"T1 carries incoming pace into available outgoing pace",
	)

	var planted := base.duplicate(true)
	var stretched := base.duplicate(true)
	planted["circumstance_severity"] = 0.0
	stretched["circumstance_severity"] = 1.0
	var planted_result := PlatformModel.evaluate(planted)
	var stretched_result := PlatformModel.evaluate(stretched)
	_gate(
		float(stretched_result.redirection_half_angle_degrees)
			< float(planted_result.redirection_half_angle_degrees)
			and float(stretched_result.maximum_outgoing_speed_mps)
			< float(planted_result.maximum_outgoing_speed_mps),
		"circumstance narrows T2 and active T1 without selecting a ball",
	)

	var weak_error := _leverage_measure(20, 0.45)
	var elite_error := _leverage_measure(80, 0.45)
	_gate(
		float(elite_error.mean_error) < float(weak_error.mean_error),
		"T3 is technique-scaled deviation from the selected launch",
	)
	_gate(
		float(weak_error.selected_rate) == 1.0
			and float(elite_error.selected_rate) == 1.0,
		"weak and elite volis both retain a launch on a feasible contact",
	)
	_gate(
		not bool(PlatformModel.evaluate({}).get("available", false)),
		"missing physical contact state cannot manufacture a launch",
	)


func _gate(condition: bool, message: String) -> void:
	print("  %s  %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		failures += 1


func _families(rows: Array) -> Array:
	var seen := {}
	for row in rows:
		seen[str(row.family)] = true
	var result: Array = seen.keys()
	result.sort()
	return result


func _counts_text(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s %d" % [str(key), int(counts[key])])
	return ", ".join(parts)


func _stats_text(values: Array) -> String:
	if values.is_empty():
		return "missing"
	var ordered := values.duplicate()
	ordered.sort()
	return "%.3f / %.3f / %.3f" % [
		float(ordered[0]), float(ordered[ordered.size() / 2]),
		float(ordered[-1]),
	]
