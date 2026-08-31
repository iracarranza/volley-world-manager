extends SceneTree

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const DRIVER := preload("res://scripts/simulation/scripted_rally_driver.gd")
const STATE_BUILDER := preload("res://scripts/simulation/rally_state_builder.gd")


func _initialize() -> void:
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	var state = STATE_BUILDER.build(
		manager.players, manager.current_lineup(), manager.current_defensive_plan(),
		manager.opponent_team, null, false, 1)
	var positions := {}
	for id in state.home_players:
		positions[int(id)] = state.home_players[id].position
	for id in state.opponent_players:
		positions[int(id)] = state.opponent_players[id].position
	positions[6] = Vector2(0.45, 0.84)
	positions[102] = Vector2(0.50, 0.44)
	positions[103] = Vector2(0.82, 0.16)
	var script := {
		"serving_side": "opponent",
		"initial_positions": positions,
		"actions": [
			{
				"actor": 105, "action": "serve", "intent_time": 0.0,
				"target": Vector2(0.45, 0.92), "serve_type": "Standing",
				"aggression": 1.0,
			},
			{
				"actor": 6, "action": "receive", "intent_time": 0.0,
				"target": manager.current_lineup().active_setter_id(),
				"attempted_action": "platform pass",
			},
			{
				"actor": manager.current_lineup().active_setter_id(),
				"action": "set", "intent_time": 0.20,
				"target": manager.current_lineup().player_at_slot(4),
				"set_family": "outside", "tempo": 2,
			},
			{
				"actor": manager.current_lineup().player_at_slot(4),
				"action": "attack", "intent_time": 0.50,
				"target": Vector2(0.28, 0.22), "attack_action": "Power swing",
				"course": "line", "aggression": 0.72,
			},
			{
				"actor": 102, "action": "block", "intent_time": 2.20,
				"target": Vector2(0.50, 0.50), "block_intent": "Seal",
			},
			{
				"actor": 103, "action": "dig", "intent_time": 2.20,
				"target": manager.current_lineup().active_setter_id(),
				"attempted_action": "platform dig",
			},
		],
	}
	var driver = DRIVER.new()
	var seed := 16
	var result = driver.resolve_script(
		script, manager.players, manager.current_lineup(), manager.opponent_team,
		manager.current_defensive_plan(), seed)
	print("seed: %d" % seed)
	print("refusal: %s" % driver.last_refusal)
	print("events: %d" % (result.events.size() if result != null else -1))
	if result != null:
		for event in result.events:
			print("  %s actor=%d intent=%.3f contact=%s height=%s" % [
				event.type_name(), event.actor_id,
				float(event.metadata.get("intent_time", NAN)),
				str(event.metadata.get("resolved_contact_time", "miss")),
				str(event.metadata.get("contact_height_meters", "miss")),
			])
		print("seam: %s" % DRIVER.seam_census(result.events))
		print("intents: %s" % str(result.analysis.get("scripted_intents", [])))
	manager.free()
	quit()
