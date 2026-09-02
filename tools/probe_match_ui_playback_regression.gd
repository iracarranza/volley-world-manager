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
	var preview_card := PanelContainer.new()
	preview_card.name = "GameplayPreview"
	preview_card.size = Vector2(300.0, 120.0)
	host.add_child(preview_card)
	UIStyleSystem.apply(preview_card, false, UIStyleSystem.MEDIUM_DRAWN)
	await process_frame
	var preview_outline := preview_card.get_node_or_null("InkOutline")
	_expect(
		preview_card.theme_type_variation == &"InsetPanel"
			and preview_outline != null
			and not bool(preview_outline.hover_highlight)
			and preview_card.get_node_or_null("InkHighlight") == null,
		"preview surface keeps its card edge without becoming a highlighted button",
	)
	var dashboard_card := Button.new()
	dashboard_card.name = "RosterCard"
	dashboard_card.text = "ROSTER"
	dashboard_card.size = Vector2(280.0, 120.0)
	host.add_child(dashboard_card)
	UIStyleSystem.apply(dashboard_card, false, UIStyleSystem.MEDIUM_DRAWN)
	await process_frame
	var dashboard_outline := dashboard_card.get_node_or_null("InkOutline")
	_expect(
		dashboard_card.theme_type_variation == &"DashboardCard"
			and dashboard_outline != null
			and not bool(dashboard_outline.hover_highlight)
			and dashboard_card.get_node_or_null("InkHighlight") == null,
		"pressable card remains a card rather than a highlighted menu action",
	)
	var nav := Button.new()
	nav.name = "MenuItem"
	nav.text = "01  NEW CAREER"
	nav.theme_type_variation = &"NavAction"
	nav.size = Vector2(240.0, 52.0)
	host.add_child(nav)
	UIStyleSystem.apply(nav, false, UIStyleSystem.MEDIUM_DRAWN)
	await process_frame
	var nav_outline := nav.get_node_or_null("InkOutline")
	_expect(
		nav.theme_type_variation == &"NavAction"
			and nav_outline != null
			and not bool(nav_outline.draw_perimeter)
			and nav.get_node_or_null("InkHighlight") != null,
		"navigation item keeps its mark without becoming a boxed button",
	)
	var title := load("res://scenes/screens/title_screen.tscn").instantiate() as Control
	UIStyleSystem.apply(title, false, UIStyleSystem.MEDIUM_DRAWN)
	for title_item_name in [
		"NewCareerButton", "LoadMenuButton", "OptionsButton", "ExitButton",
	]:
		var title_item := title.get_node("%%%s" % title_item_name) as Button
		var title_mark := title_item.get_node_or_null("InkOutline")
		_expect(
			title_item.theme_type_variation == &"NavAction"
				and title_mark != null
				and not bool(title_mark.draw_perimeter),
			"title %s remains a navigation item" % title_item_name,
		)
	title.free()

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
