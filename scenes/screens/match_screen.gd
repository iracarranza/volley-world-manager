class_name MatchScreen
extends Control

signal close_requested

@onready var match_court_3d: MatchCourt3D = %MatchCourt3D
@onready var caption_label: Label = $HUD/CaptionLabel if has_node("HUD/CaptionLabel") else null
@onready var close_button: Button = $HUD/CloseButton if has_node("HUD/CloseButton") else null

var playback_speed: float = 1.0

# Jump reach / block-and-attack contacts happen in the air; every other
# contact (serve, pass, dig, set) happens with the player's feet on the
# floor. Keep these two concerns (ball height vs. player root height)
# separate -- the ball always arcs, the player model does not.
const AERIAL_EVENT_TYPES: Array[int] = [
	RallyEvent.EventType.ATTACK, RallyEvent.EventType.BLOCK,
]
const GROUND_PLAYER_HEIGHT: float = 0.0
const AERIAL_PLAYER_HEIGHT: float = 0.42
const GROUND_BALL_HEIGHT: float = 1.0
const AERIAL_BALL_HEIGHT: float = 2.7


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

		var event_type := int(event.get("event_type"))
		var meta = event.get("metadata") if event.get("metadata") is Dictionary else {}

		# SET_DECISION shares its physical touch with the SET event that
		# immediately follows it -- it is not a second contact. Only move
		# the setter into position for the upcoming set and update the
		# caption; do not play a ball arc for it (that was the source of
		# the phantom double-contact, and of a spurious centered ball hop
		# right before every real attack).
		if event_type == RallyEvent.EventType.SET_DECISION:
			_animate_primary_actor(
				event, meta, event.get("start_position"),
				GROUND_PLAYER_HEIGHT, 0.0,
			)
			if caption_label and event.get("headline") != null:
				caption_label.text = str(event.get("headline"))
			continue

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

		var is_aerial := event_type in AERIAL_EVENT_TYPES
		var ball_height := AERIAL_BALL_HEIGHT if is_aerial else GROUND_BALL_HEIGHT
		var player_height := AERIAL_PLAYER_HEIGHT if is_aerial else GROUND_PLAYER_HEIGHT

		# Convert 2D tactical positions to 3D World space (ball only -- the
		# ball's own contact/arc height is independent of the player root).
		var start_world = match_court_3d.tactical_to_world(start_p.x, start_p.y, ball_height)
		var end_world = match_court_3d.tactical_to_world(end_p.x, end_p.y, ball_height)
		var ctrl_world = match_court_3d.tactical_to_world(
			ctrl_p.x, ctrl_p.y, ball_height + apex_h
		) if has_ctrl else Vector3.ZERO

		# Animate primary actor movement -- grounded contacts keep the
		# player's feet on the floor; only ATTACK/BLOCK lift the root to
		# simulate a jump. Uses the simulator's own movement_start /
		# movement_duration when available so the player is seen actually
		# closing the real distance in real time, rather than snapping to
		# the contact point on the ball's flight timer.
		_animate_primary_actor(event, meta, start_p, player_height, flight_d / playback_speed)

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


## Moves the event's primary actor to their contact position. When the
## simulator attached real movement data (movement_start / movement_duration),
## the actor is placed at their actual starting point first and tweened in
## over the real transit time, so the model is seen covering the court
## between contacts instead of teleporting to each new contact point.
func _animate_primary_actor(
	event: Resource,
	meta: Dictionary,
	contact_pos: Vector2,
	height: float,
	fallback_duration: float,
) -> void:
	var raw_actor_id = event.get("actor_id")
	var actor_id: String = str(raw_actor_id) if raw_actor_id != null else ""
	if actor_id == "" or not match_court_3d.player_actors.has(actor_id):
		return
	var actor = match_court_3d.player_actors[actor_id]

	var move_start = meta.get("movement_start") if "movement_start" in meta else null
	var move_duration := float(meta.get("movement_duration", 0.0)) / playback_speed \
		if "movement_duration" in meta else 0.0
	if move_start is Vector2 and move_duration > 0.0:
		actor.global_position = match_court_3d.tactical_to_world(
			move_start.x, move_start.y, height
		)

	var target_world = match_court_3d.tactical_to_world(contact_pos.x, contact_pos.y, height)
	actor.animate_to_event(
		target_world, move_duration if move_duration > 0.0 else fallback_duration
	)
