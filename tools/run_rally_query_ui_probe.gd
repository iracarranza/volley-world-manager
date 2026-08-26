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
