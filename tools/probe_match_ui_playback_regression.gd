extends SceneTree

## Focused regression contract for the two defects reported from the player
## build: disappearing button boundaries and a replay clock/body that disagrees
## with the resolved ball contact. This is deliberately small enough to run on
## every iteration without resolving or rendering a full match.

const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const MatchScreenScript := preload("res://scenes/screens/match_screen.gd")
const MatchScreenScene := preload("res://scenes/screens/match_screen.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(320.0, 160.0)
	root.add_child(host)
	var button := Button.new()
	button.name = "ContractButton"
	button.text = "REPLAY"
	button.custom_minimum_size = Vector2(180.0, 64.0)
	button.size = button.custom_minimum_size
	host.add_child(button)
	UIStyleSystem.apply(host, false, UIStyleSystem.MEDIUM_DRAWN)
	await process_frame
	await process_frame
	var outline := button.get_node_or_null("InkOutline") as Control
	_expect(outline != null, "drawn button has a persistent indicator boundary")
	if outline != null:
		_expect(not outline.show_behind_parent,
			"persistent indicator boundary draws in front of its button")
	var highlight := button.get_node_or_null("InkHighlight") as Control
	_expect(highlight != null and highlight.show_behind_parent,
		"animated highlighter owns a separate behind-button layer")

	var screen := MatchScreenScene.instantiate() as MatchScreen
	root.add_child(screen)
	await process_frame
	var plan := {
		7: {
			"start": Vector2(0.1, 0.2), "target": Vector2(0.4, 0.2),
			"speed_mps": 1.0, "seconds": 2.0,
		},
		8: {
			"start": Vector2(0.1, 0.3), "target": Vector2(0.4, 0.3),
			"speed_mps": 1.0, "seconds": 2.0,
		},
	}
	screen._pace_plan(plan, 0.5, 7)
	_expect(is_equal_approx(float(plan[7].seconds), 0.5),
		"resolved contact actor arrives at the physical contact moment")
	_expect(float(plan[8].seconds) > 0.5,
		"off-ball actor keeps continuous production-paced movement")
	_expect(is_equal_approx(
		MatchScreenScript.playback_clock_percent(3.0, 1.0, 5.0), 50.0
	), "playback bar represents physical time rather than event count")

	host.queue_free()
	screen.queue_free()
	if failures.is_empty():
		print("PASS: match UI/playback regression contract")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
