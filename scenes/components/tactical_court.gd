class_name TacticalCourt
extends Control

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

signal player_selected(player_id: int)
signal assignment_dragged(player_id: int, lane_name: String, marker_position: Vector2)
signal defender_position_changed(player_id: int, court_position: Vector2)

const LIGHT_PALETTE := {
	"outside": Color("eaf2ed"),
	"court": Color("ffffff"),
	"court_alt": Color("e7f0e9"),
	"line": Color("176b45"),
	"net": Color("d94343"),
	"marker": Color("176b45"),
	"marker_selected": Color("d94343"),
	"text": Color("10281d"),
	"path": Color("d94343"),
	"secondary_path": Color("c77b28"),
}

const DARK_PALETTE := {
	"outside": Color("090d16"),
	"court": Color("102d63"),
	"court_alt": Color("0b214a"),
	"line": Color("f4d329"),
	"net": Color("f4d329"),
	"marker": Color("2368bf"),
	"marker_selected": Color("f4d329"),
	"text": Color("f6f3d4"),
	"path": Color("f4d329"),
	"secondary_path": Color("62b4ff"),
}

var lineup: RotationLineup
var players_by_id: Dictionary = {}
var assignments: Array[HitterAssignment] = []
var primary_hitter_id: int = -1
var secondary_hitter_id: int = -1
var selected_player_id: int = -1
var palette: Dictionary = DARK_PALETTE
var playback_event: Resource
var playback_progress: float = 1.0
var playback_tween: Tween
var dragging_player_id: int = -1
var drag_position: Vector2 = Vector2.ZERO
var defensive_mode: bool = false
var defensive_plan: Resource
var landscape_orientation: bool = false
var live_player_positions: Dictionary = {}
var movement_player_id: int = -1
var movement_start: Vector2 = Vector2.ZERO
var movement_target: Vector2 = Vector2.ZERO
var playback_ball_visible: bool = true
var movement_trails: Dictionary = {}
var movement_phase_caption: String = ""
var unit_movement_starts: Dictionary = {}
var unit_movement_targets: Dictionary = {}


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_theme_mode(light_mode: bool) -> void:
	palette = LIGHT_PALETTE if light_mode else DARK_PALETTE
	queue_redraw()


func set_lineup(p_lineup: RotationLineup, players: Array[VolleyballPlayer]) -> void:
	lineup = p_lineup
	players_by_id.clear()
	for player in players:
		players_by_id[player.id] = player
	selected_player_id = -1
	queue_redraw()


func set_play_preview(
	p_assignments: Array[HitterAssignment],
	p_primary_hitter_id: int,
	p_secondary_hitter_id: int,
) -> void:
	assignments = p_assignments
	primary_hitter_id = p_primary_hitter_id
	secondary_hitter_id = p_secondary_hitter_id
	queue_redraw()


func set_defensive_view(enabled: bool, plan: Resource = null) -> void:
	defensive_mode = enabled
	defensive_plan = plan
	queue_redraw()


func set_landscape_orientation(enabled: bool) -> void:
	landscape_orientation = enabled
	queue_redraw()


func select_player(player_id: int) -> void:
	selected_player_id = player_id
	queue_redraw()


func animate_event(event: Resource, duration: float) -> void:
	playback_event = event
	playback_ball_visible = true
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	_start_playback_tween(duration)


func animate_player_movement(event: Resource, duration: float) -> void:
	playback_event = event
	playback_ball_visible = false
	_prepare_player_movement(event)
	_start_playback_tween(duration)


func animate_player_to(
	event: Resource,
	target: Vector2,
	duration: float,
	phase_caption: String,
) -> void:
	playback_event = event
	playback_ball_visible = false
	_prepare_player_movement(event)
	unit_movement_starts.clear()
	unit_movement_targets = _unit_support_targets(event, target)
	if movement_player_id >= 0:
		movement_target = target
		unit_movement_targets[movement_player_id] = target
	movement_phase_caption = phase_caption
	for raw_player_id in unit_movement_targets:
		var player_id := int(raw_player_id)
		var slot_number := lineup.slot_for_player(player_id)
		var start: Vector2 = live_player_positions.get(
			player_id, _player_court_position(player_id, slot_number)
		)
		unit_movement_starts[player_id] = start
		_append_movement_trail(player_id, start)
		_append_movement_trail(player_id, unit_movement_targets[player_id])
	_start_playback_tween(duration)


func movement_phase_targets(event: Resource, after_contact: bool = false) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not has_player_movement(event):
		return targets
	var player_id := int(event.actor_id)
	var slot_number := lineup.slot_for_player(player_id)
	if slot_number < 0:
		if not after_contact:
			targets.append(event.end_position)
		return targets
	var current: Vector2 = live_player_positions.get(
		player_id, _player_court_position(player_id, slot_number)
	)
	var action_target := _movement_action_target(event)
	var base_target := _base_or_defensive_position(player_id, slot_number)
	if not after_contact:
		match int(event.event_type):
			RallyEventModel.EventType.ATTACK:
				targets.append(current.lerp(action_target, 0.42))
				targets.append(action_target)
			RallyEventModel.EventType.BLOCK:
				targets.append(current.lerp(action_target, 0.24))
				targets.append(action_target)
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				targets.append(current.lerp(action_target, 0.18))
				targets.append(action_target)
			RallyEventModel.EventType.SET:
				targets.append(current.lerp(action_target, 0.35))
				targets.append(action_target)
	else:
		match int(event.event_type):
			RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK:
				var landing := action_target + Vector2(0.0, 0.045)
				targets.append(landing)
				targets.append(landing.lerp(base_target, 0.38))
			RallyEventModel.EventType.DEFENSE:
				var recovery_weight := 0.18 if action_target.distance_to(current) > 0.20 else 0.32
				targets.append(action_target.lerp(base_target, recovery_weight))
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.SET:
				targets.append(action_target.lerp(base_target, 0.16))
	return targets


func movement_phase_caption_for(
	event: Resource,
	phase_index: int,
	after_contact: bool,
) -> String:
	if after_contact:
		if int(event.event_type) in [
			RallyEventModel.EventType.ATTACK,
			RallyEventModel.EventType.BLOCK,
		]:
			return "Landing" if phase_index == 0 else "Recovery"
		return "Recovery"
	if lineup == null or lineup.slot_for_player(int(event.actor_id)) < 0:
		return "Unit defensive read"
	match int(event.event_type):
		RallyEventModel.EventType.ATTACK:
			return "Transition" if phase_index == 0 else "Approach"
		RallyEventModel.EventType.BLOCK:
			return "Read step" if phase_index == 0 else "Block close"
		RallyEventModel.EventType.RECEPTION:
			return "Read step" if phase_index == 0 else "Receive move"
		RallyEventModel.EventType.DEFENSE:
			return "Read step" if phase_index == 0 else (
				"Dive" if not bool(event.success) else "Defensive move"
			)
		RallyEventModel.EventType.SET:
			return "Setter transition" if phase_index == 0 else "Set position"
	return "Movement"


func has_player_movement(event: Resource) -> bool:
	if lineup == null:
		return false
	if str(event.metadata.get("side", "")) == "opponent" \
			and int(event.event_type) == RallyEventModel.EventType.ATTACK:
		return true
	if event.actor_id < 0 or lineup.slot_for_player(int(event.actor_id)) < 0:
		return false
	return int(event.event_type) in [
		RallyEventModel.EventType.RECEPTION,
		RallyEventModel.EventType.SET,
		RallyEventModel.EventType.ATTACK,
		RallyEventModel.EventType.BLOCK,
		RallyEventModel.EventType.DEFENSE,
	]


func _start_playback_tween(duration: float) -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_progress = 0.0
	queue_redraw()
	playback_tween = create_tween()
	playback_tween.set_trans(Tween.TRANS_QUAD)
	playback_tween.set_ease(Tween.EASE_IN_OUT)
	playback_tween.tween_method(_set_playback_progress, 0.0, 1.0, duration)


func finish_event_animation() -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_progress = 1.0
	for player_id in unit_movement_targets:
		live_player_positions[player_id] = unit_movement_targets[player_id]
	queue_redraw()


func clear_rally_playback() -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_event = null
	playback_ball_visible = true
	movement_phase_caption = ""
	live_player_positions.clear()
	movement_trails.clear()
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	playback_progress = 1.0
	queue_redraw()


func _set_playback_progress(value: float) -> void:
	playback_progress = value
	for player_id in unit_movement_targets:
		var start: Vector2 = unit_movement_starts[player_id]
		var target: Vector2 = unit_movement_targets[player_id]
		live_player_positions[player_id] = start.lerp(target, value)
	queue_redraw()


func reset_live_positions() -> void:
	live_player_positions.clear()
	movement_trails.clear()
	movement_phase_caption = ""
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	queue_redraw()


func _prepare_player_movement(event: Resource) -> void:
	movement_player_id = -1
	if lineup == null or event.actor_id < 0:
		return
	var slot_number := lineup.slot_for_player(int(event.actor_id))
	if slot_number < 0:
		return
	movement_player_id = int(event.actor_id)
	movement_start = live_player_positions.get(
		movement_player_id, _player_court_position(movement_player_id, slot_number)
	)
	match int(event.event_type):
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			movement_target = event.start_position
		RallyEventModel.EventType.SET:
			movement_target = event.start_position
		RallyEventModel.EventType.ATTACK:
			movement_target = event.start_position
		RallyEventModel.EventType.BLOCK:
			movement_target = event.end_position + Vector2(0.0, 0.035)
		_:
			movement_player_id = -1


func _movement_action_target(event: Resource) -> Vector2:
	match int(event.event_type):
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			return event.start_position
		RallyEventModel.EventType.SET, RallyEventModel.EventType.ATTACK:
			return event.start_position
		RallyEventModel.EventType.BLOCK:
			return event.end_position + Vector2(0.0, 0.035)
	return event.start_position


func _base_or_defensive_position(player_id: int, slot_number: int) -> Vector2:
	var fallback := CourtConstants.slot_position(slot_number)
	if defensive_plan != null:
		return defensive_plan.defender_position(player_id, fallback)
	return fallback


func _append_movement_trail(player_id: int, point: Vector2) -> void:
	var trail: Array = movement_trails.get(player_id, [])
	var should_append := trail.is_empty()
	if not trail.is_empty():
		var last_point: Vector2 = trail[-1]
		should_append = last_point.distance_to(point) > 0.005
	if should_append:
		trail.append(point)
	while trail.size() > 5:
		trail.pop_front()
	movement_trails[player_id] = trail


func _unit_support_targets(event: Resource, action_target: Vector2) -> Dictionary:
	var targets := {}
	if lineup == null:
		return targets
	var event_type := int(event.event_type)
	var opponent_attack := str(event.metadata.get("side", "")) == "opponent" \
		and event_type == RallyEventModel.EventType.ATTACK
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id == movement_player_id:
			continue
		var base := _base_or_defensive_position(player_id, slot_number)
		var target := base
		if opponent_attack:
			if CourtConstants.is_front_row_slot(slot_number):
				target.x = lerpf(base.x, action_target.x, 0.38)
				target.y = 0.54
			else:
				target.x = lerpf(base.x, action_target.x, 0.20)
				target.y = clampf(base.y, 0.70, 0.92)
		elif event_type == RallyEventModel.EventType.ATTACK:
			var distance := 0.10 + float(slot_number % 3) * 0.035
			target = action_target.lerp(base, 0.52) + Vector2(
				-distance if slot_number % 2 == 0 else distance, 0.08
			)
		elif event_type == RallyEventModel.EventType.SET:
			target = base.lerp(
				Vector2(action_target.x, maxf(base.y - 0.05, 0.56)), 0.22
			)
		elif event_type in [
			RallyEventModel.EventType.RECEPTION,
			RallyEventModel.EventType.DEFENSE,
		]:
			target = base.lerp(
				action_target,
				0.10 if CourtConstants.is_front_row_slot(slot_number) else 0.18,
			)
		elif event_type == RallyEventModel.EventType.BLOCK:
			target = base.lerp(Vector2(action_target.x, base.y), 0.22)
		targets[player_id] = Vector2(
			clampf(target.x, 0.06, 0.94), clampf(target.y, 0.53, 0.96)
		)
	return targets


func _gui_input(event: InputEvent) -> void:
	if lineup == null:
		return
	if event is InputEventMouseMotion and dragging_player_id >= 0:
		drag_position = (event as InputEventMouseMotion).position
		queue_redraw()
		accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		dragging_player_id = _player_at_local_position(mouse_event.position)
		if dragging_player_id >= 0:
			drag_position = mouse_event.position
			select_player(dragging_player_id)
			player_selected.emit(dragging_player_id)
			accept_event()
		return
	if dragging_player_id >= 0:
		var released_player_id := dragging_player_id
		dragging_player_id = -1
		queue_redraw()
		if defensive_mode:
			var court_position := _local_to_court(mouse_event.position)
			if court_position.y >= CourtConstants.NET_Y:
				defender_position_changed.emit(released_player_id, court_position)
		else:
			var lane_name := _nearest_lane(mouse_event.position, released_player_id)
			if not lane_name.is_empty():
				assignment_dragged.emit(released_player_id, lane_name, mouse_event.position)
		accept_event()


func _player_at_local_position(local_position: Vector2) -> int:
	var best_player_id := -1
	var best_distance := 30.0
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var marker_position := _player_court_position(player_id, slot_number)
		marker_position = _court_to_local(marker_position)
		var distance := local_position.distance_to(marker_position)
		if distance < best_distance:
			best_distance = distance
			best_player_id = player_id
	return best_player_id


func _nearest_lane(local_position: Vector2, player_id: int) -> String:
	var nearest := ""
	var nearest_distance := 90.0
	var lane_names: Array[String] = CourtConstants.LANES
	var slot_number := lineup.slot_for_player(player_id)
	if not CourtConstants.is_front_row_slot(slot_number):
		lane_names = ["Pipe"]
	for lane_name in lane_names:
		var target := _court_to_local(CourtConstants.lane_target(lane_name))
		var distance := local_position.distance_to(target)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = lane_name
	return nearest


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["outside"])
	var court_rect := _court_rect()
	draw_rect(court_rect, palette["court"])
	draw_rect(
		Rect2(court_rect.position, Vector2(court_rect.size.x, court_rect.size.y * 0.5)),
		palette["court_alt"],
	)
	draw_rect(court_rect, palette["line"], false, 3.0)
	var net_start := _court_to_local(Vector2(0.0, CourtConstants.NET_Y))
	var net_end := _court_to_local(Vector2(1.0, CourtConstants.NET_Y))
	draw_line(net_start, net_end, palette["net"], 5.0)
	for attack_y in [
		CourtConstants.OPPONENT_ATTACK_LINE_Y,
		CourtConstants.HOME_ATTACK_LINE_Y,
	]:
		draw_line(
			_court_to_local(Vector2(0.0, attack_y)),
			_court_to_local(Vector2(1.0, attack_y)),
			palette["line"], 2.0,
		)
	_draw_lane_guides()
	_draw_assignments()
	_draw_assignment_drag()
	_draw_movement_trails()
	_draw_players()
	_draw_rally_playback()


func _draw_lane_guides() -> void:
	for lane_name in CourtConstants.LANES:
		var target := _court_to_local(CourtConstants.lane_target(lane_name))
		var guide_color: Color = palette["line"]
		guide_color.a = 0.45
		draw_circle(target, 5.0, guide_color)
		draw_string(
			ThemeDB.fallback_font, target + Vector2(-28, -10), lane_name,
			HORIZONTAL_ALIGNMENT_CENTER, 56, 11, _with_alpha(palette["text"], 0.68),
		)


func _draw_assignments() -> void:
	for assignment in assignments:
		var start := _court_to_local(assignment.start_position)
		var target := _court_to_local(CourtConstants.lane_target(assignment.lane))
		var path_color: Color = palette["path"]
		if assignment.player_id == secondary_hitter_id:
			path_color = palette["secondary_path"]
		elif assignment.player_id != primary_hitter_id:
			path_color = _with_alpha(palette["text"], 0.55)
		draw_dashed_line(start, target, path_color, 3.0, 8.0)
		draw_circle(target, 9.0, path_color, false, 3.0)
		draw_string(
			ThemeDB.fallback_font, target + Vector2(10, 14), "T%d" % assignment.tempo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, path_color,
		)


func _draw_assignment_drag() -> void:
	if dragging_player_id < 0 or lineup == null:
		return
	var slot_number := lineup.slot_for_player(dragging_player_id)
	if slot_number < 0:
		return
	var start := _court_to_local(_player_court_position(dragging_player_id, slot_number))
	draw_dashed_line(start, drag_position, palette["path"], 4.0, 9.0)
	draw_circle(drag_position, 10.0, palette["path"], false, 3.0)


func _draw_movement_trails() -> void:
	for player_id in movement_trails:
		var trail: Array = movement_trails[player_id]
		if trail.size() < 2:
			continue
		var local_points := PackedVector2Array()
		for court_point in trail:
			local_points.append(_court_to_local(court_point))
		draw_polyline(local_points, _with_alpha(palette["secondary_path"], 0.58), 3.0)
	if movement_player_id < 0:
		return
	var local_target := _court_to_local(movement_target)
	draw_circle(local_target, 12.0, palette["secondary_path"], false, 3.0)
	if not movement_phase_caption.is_empty():
		draw_string(
			ThemeDB.fallback_font, local_target + Vector2(14, -10),
			movement_phase_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			palette["text"],
		)


func _draw_players() -> void:
	if lineup == null:
		return
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var player := players_by_id.get(player_id) as VolleyballPlayer
		var center := _court_to_local(_player_court_position(player_id, slot_number))
		var marker_color: Color = (
			palette["marker_selected"]
			if player_id == selected_player_id else palette["marker"]
		)
		draw_circle(center + Vector2(3, 4), 20.0, Color(0, 0, 0, 0.28))
		draw_circle(center, 20.0, marker_color)
		draw_circle(center, 20.0, palette["line"], false, 2.0)
		var short_name := player.position_code if player != null else "?"
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-14, 5), short_name,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 14, palette["text"],
		)
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-46, 38),
			"%d · %s" % [slot_number, player.display_name if player != null else "Vacant"],
			HORIZONTAL_ALIGNMENT_CENTER, 92, 12, palette["text"],
		)
		if defensive_mode and defensive_plan != null:
			var assignment: Resource = defensive_plan.assignment_for(player_id)
			if assignment != null:
				draw_string(
					ThemeDB.fallback_font, center + Vector2(-48, 52),
					_short_responsibility(str(assignment.base_responsibility)),
					HORIZONTAL_ALIGNMENT_CENTER, 96, 10,
					_with_alpha(palette["text"], 0.78),
				)


func _short_responsibility(value: String) -> String:
	return value.replace(" defense", "").replace("Net ", "Block ")


func _draw_rally_playback() -> void:
	if playback_event == null:
		return
	var start := _court_to_local(playback_event.start_position)
	var finish := _court_to_local(playback_event.end_position)
	var ball_position := start.lerp(finish, playback_progress)
	var event_color: Color = palette["path"] if playback_event.success \
		else Color("e64f4f")
	if playback_event.actor_id >= 0 and lineup != null:
		var slot_number := lineup.slot_for_player(playback_event.actor_id)
		if slot_number >= 0:
			var actor_position := _court_to_local(_player_court_position(
				int(playback_event.actor_id), slot_number
			))
			draw_circle(actor_position, 27.0, event_color, false, 4.0)
	if not playback_ball_visible:
		return
	draw_line(start, finish, _with_alpha(event_color, 0.42), 2.0)
	if playback_event.event_type == RallyEventModel.EventType.BLOCK:
		var block_half_width: float = 32.0 + float(playback_event.quality) * 36.0
		draw_line(
			finish + Vector2(-block_half_width, 0.0),
			finish + Vector2(block_half_width, 0.0), event_color, 7.0,
		)
	var shadow_position := ball_position + Vector2(3.0, 5.0)
	draw_circle(shadow_position, 9.0, Color(0, 0, 0, 0.3))
	draw_circle(ball_position, 9.0, Color("f5d328"))
	draw_arc(ball_position, 6.0, 0.0, TAU, 16, Color("245ba7"), 2.0)


func _court_rect() -> Rect2:
	var margin := 34.0
	var available_size := Vector2(
		maxf(size.x - margin * 2.0, 1.0),
		maxf(size.y - margin * 2.0, 1.0),
	)
	## A full volleyball court is 9 m wide by 18 m long.
	var court_height: float
	var court_width: float
	if landscape_orientation:
		court_width = minf(available_size.x, available_size.y * 2.0)
		court_height = court_width * 0.5
	else:
		court_height = minf(available_size.y, available_size.x * 2.0)
		court_width = court_height * 0.5
	var court_size := Vector2(court_width, court_height)
	var centered_position := (size - court_size) * 0.5
	return Rect2(centered_position, court_size)


func _court_to_local(court_point: Vector2) -> Vector2:
	var rect := _court_rect()
	if landscape_orientation:
		return rect.position + Vector2(
			court_point.y * rect.size.x,
			(1.0 - court_point.x) * rect.size.y,
		)
	return rect.position + court_point * rect.size


func _local_to_court(local_point: Vector2) -> Vector2:
	var rect := _court_rect()
	if landscape_orientation:
		return Vector2(
			clampf(1.0 - (local_point.y - rect.position.y) / rect.size.y, 0.0, 1.0),
			clampf((local_point.x - rect.position.x) / rect.size.x, 0.0, 1.0),
		)
	return Vector2(
		clampf((local_point.x - rect.position.x) / rect.size.x, 0.0, 1.0),
		clampf((local_point.y - rect.position.y) / rect.size.y, 0.0, 1.0),
	)


func _player_court_position(player_id: int, slot_number: int) -> Vector2:
	if player_id in live_player_positions:
		return live_player_positions[player_id]
	var fallback := CourtConstants.slot_position(slot_number)
	if defensive_mode and defensive_plan != null:
		return defensive_plan.defender_position(player_id, fallback)
	return fallback


func _with_alpha(raw_color: Variant, alpha: float) -> Color:
	var result: Color = raw_color
	result.a = alpha
	return result
