extends SceneTree

## M5 reachability census for the only free-flight terminal whose next action is
## not yet governed: a platform ball that clears the net. Outcome counts are not
## targets. This asks only whether the unresolved semantic branch is reachable.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const PlatformContact := preload(
	"res://scripts/simulation/platform_contact_model.gd"
)
const FreeFlightInterception := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)

const FIRST_SEED: int = 47000
const SEEDS_PER_CELL: int = 100


func _initialize() -> void:
	var counts := {
		"rallies": 0,
		"physical_digs": 0,
		"intercepted": 0,
		"floor": 0,
		"net": 0,
		"out": 0,
		"crossed_net_unresolved": 0,
		"unresolved_outcomes": 0,
	}
	var examples: Array[String] = []
	for rotation in range(1, 7):
		for serving_home in [false, true]:
			for offset in range(SEEDS_PER_CELL):
				var manager: Object = GameManagerScript.new()
				manager.seed_vertical_slice_data()
				manager.select_rotation(rotation)
				manager.match_state.serving_home = serving_home
				var seed_value := FIRST_SEED + offset
				var rally: Resource = manager.resolve_active_rally(
					seed_value, false, true
				)
				counts.rallies += 1
				if str(rally.terminal_outcome) == "m5_unresolved_overpass":
					counts.unresolved_outcomes += 1
				for raw_event in rally.events:
					var event := raw_event as RallyEvent
					if event == null \
							or event.event_type != RallyEventScript.EventType.DIG:
						continue
					var platform: Dictionary = event.metadata.get(
						"platform_contact", {}
					)
					if str(platform.get("source", "")) \
							!= "shared_physical_platform":
						continue
					counts.physical_digs += 1
					var resolution := str(event.metadata.get(
						"free_flight_resolution", "missing"
					))
					if counts.has(resolution):
						counts[resolution] += 1
					if resolution == "crossed_net_unresolved" \
							and examples.size() < 12:
						examples.append(
							"rotation %d serving_home=%s seed=%d side=%s" % [
								rotation, str(serving_home), seed_value,
								str(event.metadata.get("side", "missing")),
							]
						)
				manager.free()
	print(counts)
	for example in examples:
		print("  %s" % example)
	var synthetic := _synthetic_overpass()
	print("synthetic narrow-envelope contact: %s" % synthetic)
	var terminal: Dictionary = synthetic.get("terminal", {})
	if str(terminal.get("reason", "missing")) != "crossed_net_unresolved":
		push_error(
			"M5 overpass reachability witness no longer reaches the policy boundary"
		)
		quit(1)
		return
	quit(0)


func _synthetic_overpass() -> Dictionary:
	## Same coordinate/velocity convention as production: a descending attack
	## arrives toward the home baseline (+z), and its natural platform rebound is
	## back toward the net (-z). Full circumstance narrowing is an already
	## authored T2 endpoint, not a new test-only physical value.
	var contact := Vector2(0.50, 0.62)
	var resolved := PlatformContact.evaluate({
		"incoming_velocity_mps": Vector3(0.0, -20.0, 14.0),
		"contact_position": contact,
		"contact_height_meters": 0.95,
		"body_velocity_mps": Vector2.ZERO,
		"circumstance_severity": 0.8,
		"stability_ability": 1.0,
		"technique_ability": 0.8,
		"intent_target_anchor": Vector2(0.50, 0.52),
		"intent_height_anchor_meters": 2.35,
		"intent_arrival_floor_seconds": 0.45,
		"seed": 88421,
	})
	if not resolved.has("realised_velocity_mps"):
		return {"available": false, "reason": resolved.get("reason", "missing")}
	var flight := FreeFlightInterception.from_launch(
		"dig", contact, 0.95, Vector3(resolved.realised_velocity_mps),
		0.0, "synthetic-overpass",
	)
	var physical := FreeFlightInterception.opportunities(flight, [])
	return {
		"available": true,
		"launch_velocity_mps": resolved.realised_velocity_mps,
		"terminal": physical.get("terminal", {}),
	}
