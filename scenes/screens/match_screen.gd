class_name MatchScreen
extends Control

signal close_requested

@onready var match_court_3d: MatchCourt3D = %MatchCourt3D
@onready var caption_label: Label = $HUD/CaptionLabel if has_node("HUD/CaptionLabel") else null
@onready var close_button: Button = $HUD/CloseButton if has_node("HUD/CloseButton") else null

var playback_speed: float = 1.0


func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)


func _on_close_button_pressed() -> void:
	visible = false
	close_requested.emit()


## Called by Main or GameManager when a rally result is ready to play
func load_and_play_rally(rally_result: RallyResult) -> void:
	if rally_result == null or rally_result.events.is_empty():
		return

	# 1. Bring MatchScreen UI to front
	top_level = true
	visible = true
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 2. Setup initial lineup BEFORE playing event animations
	var lineup: Dictionary = {}
	if "initial_lineup" in rally_result and rally_result.initial_lineup != null:
		lineup = rally_result.initial_lineup
	elif GameManager.has_method("get_active_lineup"):
		lineup = GameManager.get_active_lineup()

	# Force setup players
	match_court_3d.setup_players_from_lineup(lineup)

	# 3. Play event sequence
	for event in rally_result.events:
		if event == null:
			continue

		var meta = event.get("metadata") if event.get("metadata") is Dictionary else {}
		var trajectory = meta.get("outgoing_trajectory") if "outgoing_trajectory" in meta else null

		# Extract positions
		var start_p: Vector2 = Vector2(0.5, 0.5)
		var end_p: Vector2 = Vector2(0.5, 0.5)
		var apex_h: float = 1.5
		var flight_d: float = 0.8
		var ctrl_p: Vector2 = Vector2.ZERO
		var has_ctrl: bool = false

		if trajectory is Dictionary:
			start_p = trajectory.get("start_position", Vector2(0.5, 0.5))
			end_p = trajectory.get("end_position", Vector2(0.5, 0.5))
			apex_h = trajectory.get("apex_height_meters", 1.5)
			flight_d = trajectory.get("duration", 0.8)
			if "control_position" in trajectory:
				ctrl_p = trajectory.get("control_position")
				has_ctrl = true
		else:
			start_p = event.get("start_position") if event.get("start_position") != null else Vector2(0.5, 0.5)
			end_p = event.get("end_position") if event.get("end_position") != null else Vector2(0.5, 0.5)

		# SKIP zero-movement rally end whistle events (Sequence 6 fix)
		if start_p.distance_to(end_p) < 0.01 and flight_d < 0.2:
			continue

		# Convert 2D tactical positions to 3D World space
		var start_world = match_court_3d.tactical_to_world(start_p.x, start_p.y, 1.2) # Base contact height
		var end_world = match_court_3d.tactical_to_world(end_p.x, end_p.y, 1.0)
		var ctrl_world = match_court_3d.tactical_to_world(ctrl_p.x, ctrl_p.y, 1.2 + apex_h) if has_ctrl else Vector3.ZERO

		# Animate primary actor movement
		var raw_actor_id = event.get("actor_id")
		var actor_id: String = str(raw_actor_id) if raw_actor_id != null else ""
		if actor_id != "" and match_court_3d.player_actors.has(actor_id):
			var actor = match_court_3d.player_actors[actor_id]
			actor.animate_to_event(start_world, flight_d / playback_speed)

		# Display Caption
		if caption_label and event.get("headline") != null:
			caption_label.text = str(event.get("headline"))

		# Play Ball Arc
		if has_ctrl:
			await match_court_3d.ball_actor.play_bezier_trajectory(
				start_world, ctrl_world, end_world, flight_d / playback_speed
			)
		else:
			await match_court_3d.ball_actor.play_trajectory(
				start_world, end_world, apex_h, flight_d / playback_speed
			)

	# 4. Hide ball or reset when finished
	match_court_3d.ball_actor.visible = false

	if close_button:
		close_button.visible = true
	else:
		await get_tree().create_timer(1.5).timeout
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
