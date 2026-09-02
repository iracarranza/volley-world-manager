extends SceneTree

## Lightweight scene-level gate for the guided debug-rally builder. The rally
## predicate census lives in run_rally_query_probe.gd; this verifies that the
## actual Main scene exposes and wires the prompted controls without running a
## second simulation census.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	get_root().size = Vector2i(1280, 720)
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame
	var failures := 0
	var presets := main.get_node("%RallyQueryPresetOption") as OptionButton
	var fields := main.get_node("%RallyQueryFieldOption") as OptionButton
	var clauses := main.get_node("%RallyQueryClauseList") as ItemList
	var advanced := main.get_node("%RallyQueryAdvancedToggle") as CheckButton
	var advanced_row := main.get_node("%RallyQueryAdvancedRow") as HBoxContainer
	var advanced_edit := main.get_node("%RallyQueryEdit") as LineEdit
	if presets.item_count < 10:
		failures += _failure("preset dropdown", presets.item_count, 10)
	if fields.item_count < 20:
		failures += _failure("prompted field dropdown", fields.item_count, 20)
	if clauses.item_count != 1:
		failures += _failure("default guided clause", clauses.item_count, 1)
	if advanced.button_pressed or advanced_row.visible:
		print("FAIL: advanced query should begin collapsed")
		failures += 1

	## Apply the two-clause sub-0.18 s T1 preset through the real scene callback.
	presets.select(6)
	main.call("_apply_selected_rally_query_preset")
	if clauses.item_count != 2:
		failures += _failure("preset clause count", clauses.item_count, 2)
	var round_trip := str(advanced_edit.text)
	if not round_trip.contains("set[1].achieved_tempo=1") \
			or not round_trip.contains("set[1].duration<0.18"):
		print("FAIL: guided clauses did not populate copyable advanced text: %s" % round_trip)
		failures += 1
	if capture:
		main.call("_open_debug_popup")
		await process_frame
		await process_frame
		var output := "res://artifacts/ball-contact-evidence/rally_query_builder.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
			output.get_base_dir()
		))
		get_root().get_texture().get_image().save_png(output)
		print("saved %s" % ProjectSettings.globalize_path(output))

	main.call("_toggle_advanced_rally_query", true)
	if not advanced_row.visible:
		print("FAIL: advanced text row did not open")
		failures += 1

	## Search itself is a diagnostic preview, not 250 hidden match contacts. Seed
	## every learning store with recognizable state, run a query broad enough to
	## match every candidate, then prove both the per-seed result and live roster
	## are exactly what an isolated resolution produces.
	var manager: Node = get_root().get_node("GameManager")
	var original_learning: Array[Dictionary] = main.call("_rally_learning_snapshot")
	var sentinel_player = manager.players[0]
	sentinel_player.situation_experience["query_probe:sentinel"] = 4.25
	sentinel_player.set_meta(&"placement_memory", {
		"Left Pin": Vector2(0.17, -0.11),
	})
	var sentinel_learning: Array[Dictionary] = main.call("_rally_learning_snapshot")
	var learning_before := _learning_digest()
	advanced.button_pressed = true
	advanced_edit.text = "contacts>=0"
	main.call("_search_debug_rallies")
	var retained: Array = main.get("rally_query_results")
	var report := str(main.get_node("%RallyQueryReport").text)
	if retained.size() != 25:
		print("FAIL: broad search retained %d replays, expected 25" % retained.size())
		failures += 1
	if not report.begins_with("250 combined matches."):
		print("FAIL: broad search did not report all 250 matches: %s" % report)
		failures += 1
	if _learning_digest() != learning_before:
		print("FAIL: rally search mutated live familiarity or placement memory")
		failures += 1
	if retained.size() == 25:
		var retained_entry: Dictionary = retained[24]
		var saved_serving_home := bool(manager.match_state.serving_home)
		manager.match_state.serving_home = bool(retained_entry["serving_home"])
		var isolated: Resource = manager.resolve_active_rally(int(retained_entry["seed"]))
		if _result_fingerprint(isolated) != _result_fingerprint(retained_entry["result"]):
			print("FAIL: a retained query rally depended on earlier preview seeds")
			failures += 1
		manager.match_state.serving_home = saved_serving_home
		## The isolated repeat learns too; restore the same sentinel baseline before
		## checking and before giving the original process state back below.
		main.call("_restore_rally_learning", sentinel_learning)

	## Verify the sentinel baseline, then return the autoload to the state it had
	## before this probe.
	if _learning_digest() != learning_before:
		print("FAIL: isolated replay cleanup did not restore the query baseline")
		failures += 1
	main.call("_restore_rally_learning", original_learning)

	print("%s: guided RallyQuery scene controls (%d presets, %d fields)" % [
		"PASS" if failures == 0 else "FAIL (%d)" % failures,
		presets.item_count, fields.item_count,
	])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _failure(label: String, actual: int, expected: int) -> int:
	print("FAIL: %s count %d, expected at least/exactly %d" % [label, actual, expected])
	return 1


func _learning_digest() -> String:
	var records: Array[Dictionary] = []
	var manager: Node = get_root().get_node("GameManager")
	var players: Array = manager.players.duplicate()
	if manager.opponent_team != null:
		players.append_array(manager.opponent_team.players)
	for player in players:
		records.append({
			"id": int(player.id),
			"situation_experience": player.situation_experience.duplicate(true),
			"has_placement_memory": player.has_meta(&"placement_memory"),
			"placement_memory": Dictionary(
				player.get_meta(&"placement_memory", {})
			).duplicate(true),
		})
	return var_to_str(records)


func _result_fingerprint(result: Resource) -> String:
	var events: Array[Dictionary] = []
	for event in result.events:
		events.append(event.to_dict())
	return var_to_str({
		"events": events,
		"home_team_won": result.home_team_won,
		"terminal_outcome": result.terminal_outcome,
		"decisive_actor_id": result.decisive_actor_id,
	})
