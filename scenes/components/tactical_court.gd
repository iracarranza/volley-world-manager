class_name TacticalCourt
extends Control

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const RotationLegalityModel := preload("res://scripts/simulation/rotation_legality.gd")

signal player_selected(player_id: int)
signal player_instruction_requested(player_id: int, marker_screen_position: Vector2)
signal player_drag_started(player_id: int)
signal court_background_clicked()
signal assignment_dragged(player_id: int, lane_name: String, marker_position: Vector2)
signal defender_position_changed(player_id: int, court_position: Vector2)
signal coverage_zone_position_changed(
	player_id: int, zone_type: int, court_position: Vector2
)
signal setter_release_position_changed(player_id: int, court_position: Vector2)

const LIGHT_PALETTE := {
	"outside": Color("eaf2ed"),
	"court": Color("ffffff"),
	"court_alt": Color("e7f0e9"),
	"line": Color("176b45"),
	"net": Color("d94343"),
	"marker": Color("176b45"),
	"marker_selected": Color("d94343"),
	"opponent_marker": Color("d94343"),
	"opponent_text": Color("ffffff"),
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
	"opponent_marker": Color("f4d329"),
	"opponent_text": Color("090d16"),
	"text": Color("f6f3d4"),
	"path": Color("f4d329"),
	"secondary_path": Color("62b4ff"),
}

const SHADOW_LAYER_CORE: int = 1
const SHADOW_LAYER_INTENT: int = 2
const SHADOW_LAYER_READS: int = 4
const SHADOW_LAYER_OPPORTUNITIES: int = 8
const SHADOW_LAYER_LABELS: int = 16
const SHADOW_LAYER_ENVELOPES: int = 32
const SHADOW_LAYER_DEFAULT: int = \
	SHADOW_LAYER_CORE | SHADOW_LAYER_INTENT | SHADOW_LAYER_LABELS \
	| SHADOW_LAYER_ENVELOPES
const SHADOW_LAYER_ALL: int = SHADOW_LAYER_DEFAULT \
	| SHADOW_LAYER_READS | SHADOW_LAYER_OPPORTUNITIES

var lineup: RotationLineup
var players_by_id: Dictionary = {}
var opponent_team: Resource
var opponent_players_by_id: Dictionary = {}
var show_opponents: bool = false
var assignments: Array[HitterAssignment] = []
var primary_hitter_id: int = -1
var secondary_hitter_id: int = -1
var selected_player_id: int = -1
var palette: Dictionary = DARK_PALETTE
var playback_event: Resource
var contact_overlay_event: Resource
var playback_progress: float = 1.0
var playback_tween: Tween
var dragging_player_id: int = -1
var drag_position: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO
var dragging_release_target: bool = false
var defensive_mode: bool = false
var defensive_plan: Resource
var defensive_zone_type: int = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
var defensive_phase: int = 0
var landscape_orientation: bool = false
var live_player_positions: Dictionary = {}
var movement_player_id: int = -1
var movement_start: Vector2 = Vector2.ZERO
var movement_target: Vector2 = Vector2.ZERO
var playback_ball_visible: bool = true
var coverage_zones_visible: bool = true
var movement_trails: Dictionary = {}
var movement_phase_caption: String = ""
var unit_movement_starts: Dictionary = {}
var unit_movement_targets: Dictionary = {}
var shadow_reception_trace: Dictionary = {}
var shadow_overlay_layers: int = SHADOW_LAYER_DEFAULT


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_theme_mode(light_mode: bool) -> void:
	palette = LIGHT_PALETTE if light_mode else DARK_PALETTE
	queue_redraw()


func set_lineup(p_lineup: RotationLineup, players: Array[VolleyballPlayer]) -> void:
	clear_rally_playback()
	shadow_reception_trace.clear()
	lineup = p_lineup
	players_by_id.clear()
	for player in players:
		players_by_id[player.id] = player
	selected_player_id = -1
	queue_redraw()


func set_opponent_team(team: Resource, visible: bool = true) -> void:
	opponent_team = team
	show_opponents = visible and team != null
	opponent_players_by_id.clear()
	if team != null:
		for player_resource in team.on_court_players():
			var player: VolleyballPlayer = player_resource as VolleyballPlayer
			if player != null:
				opponent_players_by_id[player.id] = player
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


func set_defensive_view(
	enabled: bool,
	plan: Resource = null,
	zone_type: int = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE,
	phase: int = 0,
) -> void:
	defensive_mode = enabled
	defensive_plan = plan
	defensive_zone_type = zone_type
	defensive_phase = phase
	queue_redraw()


func set_coverage_zones_visible(visible: bool) -> void:
	coverage_zones_visible = visible
	queue_redraw()


func set_shadow_reception_trace(trace: Dictionary) -> void:
	shadow_reception_trace = trace.duplicate(true)
	queue_redraw()


func clear_shadow_reception_trace() -> void:
	shadow_reception_trace.clear()
	queue_redraw()


func set_shadow_overlay_layers(layers: int) -> void:
	shadow_overlay_layers = layers
	queue_redraw()


func set_landscape_orientation(enabled: bool) -> void:
	landscape_orientation = enabled
	queue_redraw()


func select_player(player_id: int) -> void:
	selected_player_id = player_id
	queue_redraw()


func player_marker_screen_position(player_id: int) -> Vector2:
	if lineup == null:
		return get_screen_position()
	var slot_number := lineup.slot_for_player(player_id)
	if slot_number < 0:
		return get_screen_position()
	return get_screen_position() + _court_to_local(
		_player_court_position(player_id, slot_number)
	)


func animate_event(event: Resource, duration: float) -> void:
	playback_event = event
	contact_overlay_event = null
	playback_ball_visible = true
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	_start_playback_tween(duration)


func animate_spatial_transition(
	ball_event: Resource,
	next_contact_event: Resource,
	duration: float,
) -> void:
	playback_event = ball_event
	contact_overlay_event = next_contact_event \
		if int(next_contact_event.event_type) == RallyEventModel.EventType.BLOCK else null
	playback_ball_visible = true
	_prepare_player_movement(next_contact_event)
	unit_movement_starts.clear()
	unit_movement_targets = _unit_support_targets(
		next_contact_event, _movement_action_target(next_contact_event)
	)
	if movement_player_id >= 0:
		unit_movement_targets[movement_player_id] = _movement_action_target(
			next_contact_event
		)
	for raw_player_id in unit_movement_targets:
		var player_id := int(raw_player_id)
		var slot_number := lineup.slot_for_player(player_id)
		var start: Vector2 = live_player_positions.get(
			player_id, _player_court_position(player_id, slot_number)
		)
		if player_id == movement_player_id \
				and next_contact_event.metadata.has("movement_start"):
			start = Vector2(next_contact_event.metadata["movement_start"])
			live_player_positions[player_id] = start
		unit_movement_starts[player_id] = start
		_append_movement_trail(player_id, start)
		_append_movement_trail(player_id, unit_movement_targets[player_id])
	movement_phase_caption = "Tracking live ball"
	_start_playback_tween(duration)


func animate_player_movement(event: Resource, duration: float) -> void:
	playback_event = event
	contact_overlay_event = null
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
	contact_overlay_event = null
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
				targets.append(_defensive_read_position(
					player_id, current, action_target, true
				))
				targets.append(action_target)
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				targets.append(_defensive_read_position(
					player_id, current, action_target, false
				))
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


func _defensive_read_position(
	player_id: int,
	base_position: Vector2,
	action_target: Vector2,
	blocking: bool,
) -> Vector2:
	var player := players_by_id.get(player_id) as VolleyballPlayer
	var read_quality := 0.5
	if player != null:
		read_quality = (
			float(player.anticipation)
			+ float(player.decision_making)
			+ float(player.tactical_discipline)
		) / 300.0
	var read_weight := lerpf(0.10, 0.31, clampf(read_quality, 0.0, 1.0))
	var read_position := base_position.lerp(action_target, read_weight)
	if blocking:
		read_position.y = lerpf(base_position.y, 0.54, 0.42)
	else:
		read_position.y = clampf(read_position.y, 0.56, 0.94)
	return Vector2(
		clampf(read_position.x, 0.06, 0.94),
		clampf(read_position.y, 0.53, 0.96),
	)


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
	contact_overlay_event = null
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
	if event.metadata.has("movement_start") \
			and movement_player_id not in live_player_positions:
		movement_start = Vector2(event.metadata["movement_start"])
		live_player_positions[movement_player_id] = movement_start
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
	if event is InputEventMouseMotion and (dragging_player_id >= 0 or dragging_release_target):
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
		if _release_target_at_local_position(mouse_event.position):
			dragging_release_target = true
			drag_start_position = mouse_event.position
			drag_position = mouse_event.position
			accept_event()
			return
		dragging_player_id = _player_at_local_position(mouse_event.position)
		if dragging_player_id >= 0:
			drag_start_position = mouse_event.position
			drag_position = mouse_event.position
			select_player(dragging_player_id)
			player_selected.emit(dragging_player_id)
			player_drag_started.emit(dragging_player_id)
			accept_event()
			return
		court_background_clicked.emit()
		accept_event()
		return
	if dragging_release_target:
		dragging_release_target = false
		var release_position := _local_to_court(mouse_event.position)
		setter_release_position_changed.emit(lineup.active_setter_id(), release_position)
		queue_redraw()
		accept_event()
		return
	if dragging_player_id >= 0:
		var released_player_id := dragging_player_id
		var was_dragged := drag_start_position.distance_to(mouse_event.position) >= 7.0
		dragging_player_id = -1
		queue_redraw()
		if defensive_mode and not was_dragged:
			var marker_local := _court_to_local(_player_court_position(
				released_player_id, lineup.slot_for_player(released_player_id)
			))
			player_instruction_requested.emit(
				released_player_id, get_screen_position() + marker_local
			)
		elif defensive_mode:
			var court_position := _local_to_court(mouse_event.position)
			if court_position.y >= CourtConstants.NET_Y:
				coverage_zone_position_changed.emit(
					released_player_id, defensive_zone_type, court_position
				)
		elif was_dragged:
			var lane_name := _nearest_lane(mouse_event.position, released_player_id)
			if not lane_name.is_empty():
				assignment_dragged.emit(released_player_id, lane_name, mouse_event.position)
		accept_event()


func _release_target_at_local_position(local_position: Vector2) -> bool:
	if not defensive_mode or defensive_phase != 0 or defensive_plan == null or lineup == null:
		return false
	var target: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id())
	return local_position.distance_to(_court_to_local(target)) <= 22.0


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
	# White is the neutral net state; block events paint only occupied sections.
	draw_line(net_start, net_end, Color("f4f4f4"), 5.0)
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
	_draw_serve_receive_legality()
	_draw_defensive_zones()
	_draw_setter_release_path()
	_draw_assignment_drag()
	_draw_movement_trails()
	_draw_shadow_reception_trace()
	_draw_opponents()
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


func _draw_defensive_zones() -> void:
	if not coverage_zones_visible or not defensive_mode or defensive_plan == null or lineup == null:
		return
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var zones: Dictionary = defensive_plan.zones_for(defensive_zone_type)
		var zone: Resource = zones.get(player_id) as Resource
		if zone == null or not bool(zone.enabled):
			continue
		var points := PackedVector2Array()
		for point_index in range(41):
			var angle := TAU * float(point_index) / 40.0
			var court_point: Vector2 = Vector2(zone.center) + Vector2(
				cos(angle) * float(zone.radius_meters) / 9.0,
				sin(angle) * float(zone.radius_meters) / 18.0,
			)
			points.append(_court_to_local(court_point))
		var zone_color: Color = palette["secondary_path"]
		zone_color.a = 0.12 + float(zone.priority) * 0.035
		draw_colored_polygon(points, zone_color)
		var outline_color: Color = palette["secondary_path"]
		outline_color.a = 0.45 if player_id != selected_player_id else 0.90
		draw_polyline(points, outline_color, 2.0 if player_id != selected_player_id else 3.5)
		var label_position := _court_to_local(zone.center)
		draw_string(
			ThemeDB.fallback_font, label_position + Vector2(23, -19),
			"P%d · %.1fm" % [int(zone.priority), float(zone.radius_meters)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, outline_color,
		)


func _draw_serve_receive_legality() -> void:
	if not coverage_zones_visible or not defensive_mode or defensive_plan == null or lineup == null:
		return
	if defensive_zone_type != DefensiveZoneModel.ZoneType.SERVE_RECEIVE:
		return
	var selected_slot := lineup.slot_for_player(selected_player_id)
	if selected_slot < 1:
		return
	var reception_zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	var positions_by_slot := {}
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var zone: Resource = reception_zones.get(player_id) as Resource
		positions_by_slot[slot_number] = Vector2(zone.center) \
			if zone != null else CourtConstants.slot_position(slot_number)
	var bounds: Rect2 = RotationLegalityModel.legal_bounds(
		selected_slot, positions_by_slot
	)
	var selected_position: Vector2 = positions_by_slot[selected_slot]
	var legal := RotationLegalityModel.is_position_legal(
		selected_slot, selected_position, positions_by_slot
	)
	var legality_color := Color("52c781") if legal else Color("ef6461")
	var bounds_points := PackedVector2Array([
		_court_to_local(bounds.position),
		_court_to_local(Vector2(bounds.end.x, bounds.position.y)),
		_court_to_local(bounds.end),
		_court_to_local(Vector2(bounds.position.x, bounds.end.y)),
	])
	var fill_color := legality_color
	fill_color.a = 0.075
	draw_colored_polygon(bounds_points, fill_color)
	var constraint_color := legality_color
	constraint_color.a = 0.82
	var related: Dictionary = RotationLegalityModel.related_slots(selected_slot)
	for relation_name in ["left", "right", "counterpart"]:
		var related_slot := int(related[relation_name])
		if related_slot < 0:
			continue
		var related_position: Vector2 = positions_by_slot[related_slot]
		if relation_name == "counterpart":
			draw_dashed_line(
				_court_to_local(Vector2(0.06, related_position.y)),
				_court_to_local(Vector2(0.94, related_position.y)),
				constraint_color, 2.0, 8.0,
			)
		else:
			draw_dashed_line(
				_court_to_local(Vector2(related_position.x, 0.53)),
				_court_to_local(Vector2(related_position.x, 0.96)),
				constraint_color, 2.0, 8.0,
			)
		draw_dashed_line(
			_court_to_local(related_position),
			_court_to_local(selected_position),
			_with_alpha(constraint_color, 0.62), 1.5, 6.0,
		)
	var label_position := _court_to_local(bounds.position) + Vector2(8, 18)
	draw_string(
		ThemeDB.fallback_font, label_position,
		"LEGAL AT SERVE" if legal else "ROTATION OVERLAP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, constraint_color,
	)


func _draw_setter_release_path() -> void:
	if not defensive_mode or defensive_phase != 0 or defensive_plan == null or lineup == null:
		return
	var setter_id := lineup.active_setter_id()
	var setter_slot := lineup.slot_for_player(setter_id)
	if setter_slot < 0:
		return
	var start := _player_court_position(setter_id, setter_slot)
	var target: Vector2 = _local_to_court(drag_position) if dragging_release_target \
		else defensive_plan.setter_release_target(setter_id)
	var start_local := _court_to_local(start)
	var target_local := _court_to_local(target)
	_draw_directional_line(start_local, target_local, palette["secondary_path"])
	draw_circle(target_local, 17.0, palette["outside"])
	draw_circle(target_local, 17.0, palette["secondary_path"], false, 3.0)
	draw_string(
		ThemeDB.fallback_font, target_local + Vector2(-11, 5),
		"S→", HORIZONTAL_ALIGNMENT_CENTER, 22, 12, palette["text"],
	)


func _draw_directional_line(start: Vector2, target: Vector2, color: Color) -> void:
	draw_line(start, target, color, 3.0, true)
	var direction := (target - start).normalized()
	if direction.length_squared() <= 0.0:
		return
	var midpoint := start.lerp(target, 0.52)
	var perpendicular := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		midpoint + direction * 10.0,
		midpoint - direction * 7.0 + perpendicular * 6.0,
		midpoint - direction * 7.0 - perpendicular * 6.0,
	])
	draw_colored_polygon(arrow, color)


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


func _draw_shadow_reception_trace() -> void:
	if shadow_reception_trace.is_empty():
		return
	var summary: Dictionary = shadow_reception_trace.get("summary", {})
	if not bool(summary.get("available", false)):
		return
	var show_core := bool(shadow_overlay_layers & SHADOW_LAYER_CORE)
	var show_intent := bool(shadow_overlay_layers & SHADOW_LAYER_INTENT)
	var show_reads := bool(shadow_overlay_layers & SHADOW_LAYER_READS)
	var show_opportunities := bool(
		shadow_overlay_layers & SHADOW_LAYER_OPPORTUNITIES
	)
	var show_labels := bool(shadow_overlay_layers & SHADOW_LAYER_LABELS)
	var show_envelopes := bool(shadow_overlay_layers & SHADOW_LAYER_ENVELOPES)
	var true_destination := Vector2(
		summary.get("true_destination", Vector2.ZERO)
	)
	if show_reads:
		var true_local := _court_to_local(true_destination)
		var truth_color := Color("ff5fd1")
		draw_circle(true_local, 13.0, _with_alpha(truth_color, 0.18))
		draw_circle(true_local, 13.0, truth_color, false, 3.0)
		draw_line(
			true_local + Vector2(-8.0, 0.0),
			true_local + Vector2(8.0, 0.0), truth_color, 2.0,
		)
		draw_line(
			true_local + Vector2(0.0, -8.0),
			true_local + Vector2(0.0, 8.0), truth_color, 2.0,
		)
		if show_labels:
			draw_string(
				ThemeDB.fallback_font, true_local + Vector2(15.0, -10.0),
				"TRUE LANDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, truth_color,
			)
	var candidates: Array = shadow_reception_trace.get("entries", [])
	var shadow_decision: Dictionary = summary.get("shadow_decision", {})
	var decision_player_id := int(shadow_decision.get("selected_player_id", -1))
	var outgoing_candidate: Dictionary = summary.get("outgoing_flight_candidate", {})
	var outgoing_flight: Dictionary = outgoing_candidate.get("flight", {})
	if show_core and bool(outgoing_candidate.get("available", false)):
		var outgoing_origin := _court_to_local(Vector2(
			outgoing_flight.get("origin", true_destination)
		))
		var outgoing_local := _court_to_local(Vector2(
			outgoing_flight.get("destination", true_destination)
		))
		draw_dashed_line(
			outgoing_origin, outgoing_local, Color("b388ff"), 2.5, 6.0,
		)
		draw_circle(outgoing_local, 6.0, Color("b388ff"), false, 2.0)
	var setter_response: Dictionary = summary.get("shadow_setter_response", {})
	var selected_setter_id := int(setter_response.get("selected_setter_id", -1))
	if show_intent:
		_draw_shadow_setter_intent(setter_response, show_labels)
	if show_envelopes:
		_draw_shadow_contact_envelope(
			setter_response, outgoing_flight, show_labels
		)
	if not show_reads and not show_opportunities:
		return
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		var start := _court_to_local(Vector2(
			candidate.get("start_position", Vector2.ZERO)
		))
		var perceived := _court_to_local(Vector2(
			candidate.get("perceived_destination", Vector2.ZERO)
		))
		var shadow_selected := bool(candidate.get("shadow_selected", false))
		var legacy_selected := bool(candidate.get("legacy_selected", false))
		var decision_selected := int(candidate.get("player_id", -1)) \
			== decision_player_id
		var reachable := bool(candidate.get("reachable", false))
		var candidate_color := Color("53d769") if reachable else Color("ef6461")
		if shadow_selected:
			candidate_color = Color("62b4ff")
		if show_reads:
			draw_dashed_line(
				start, perceived, _with_alpha(candidate_color, 0.60),
				3.0 if shadow_selected else 1.5, 7.0,
			)
			draw_circle(
				perceived, 10.0 if shadow_selected else 7.0,
				candidate_color, false, 3.0 if shadow_selected else 2.0,
			)
			if legacy_selected:
				draw_arc(perceived, 14.0, 0.0, TAU, 20, Color("f2c94c"), 2.5)
			if decision_selected:
				draw_arc(perceived, 18.0, 0.0, TAU, 24, Color("b388ff"), 3.0)
		if bool(candidate.get("repeated_read_selected", false)):
			var repeated: Dictionary = candidate.get("repeated_read_candidate", {})
			var read_points := PackedVector2Array()
			var movement_points := PackedVector2Array([start])
			for raw_moment in repeated.get("moments", []):
				var moment: Dictionary = raw_moment
				var read_local := _court_to_local(Vector2(
					moment.get("perceived_destination", Vector2.ZERO)
				))
				read_points.append(read_local)
				if show_reads:
					draw_circle(read_local, 4.0, Color("ff9f43"))
				var projected_local := _court_to_local(Vector2(
					moment.get("projected_position", candidate.get(
						"start_position", Vector2.ZERO
					))
				))
				movement_points.append(projected_local)
				if show_reads:
					draw_circle(projected_local, 3.5, Color("8ee3c7"))
			if show_reads and read_points.size() > 1:
				draw_polyline(read_points, Color("ff9f43"), 2.0)
			if show_reads and movement_points.size() > 1:
				draw_polyline(movement_points, Color("8ee3c7"), 3.0)
			var opportunity_timeline: Dictionary = repeated.get(
				"opportunity_timeline", {}
			)
			if show_opportunities:
				for raw_transition in opportunity_timeline.get("timeline", []):
					var transition: Dictionary = raw_transition
					var read_index := int(transition.get("read_index", -1))
					if read_index < 0 or read_index >= read_points.size():
						continue
					var transition_name := str(transition.get(
						"window_transition", "sample"
					))
					if transition_name == "opened":
						draw_arc(
							read_points[read_index], 9.0, 0.0, TAU, 16,
							Color("53d769"), 2.5,
						)
					elif transition_name == "closed":
						draw_arc(
							read_points[read_index], 9.0, 0.0, TAU, 16,
							Color("ef6461"), 2.5,
						)
		var label := "%s %+.2fs" % [
			str(candidate.get("player_name", candidate.get("player_id", "?"))),
			float(candidate.get("arrival_margin", 0.0)),
		]
		if shadow_selected:
			label += " · SHADOW"
		if legacy_selected:
			label += " · LEGACY"
		if decision_selected:
			label += " · DECISION"
		if show_labels and show_reads:
			draw_string(
				ThemeDB.fallback_font, perceived + Vector2(12.0, 14.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, candidate_color,
			)


func _draw_shadow_setter_intent(
	setter_response: Dictionary,
	show_labels: bool,
) -> void:
	var intended_id := int(setter_response.get("expected_setter_id", -1))
	var actual_id := int(setter_response.get("selected_setter_id", -1))
	var intended_target := _court_to_local(Vector2(setter_response.get(
		"expected_setter_target", Vector2(0.50, 0.60)
	)))
	var intent_color := Color("b388ff")
	var diamond := PackedVector2Array([
		intended_target + Vector2(0.0, -10.0),
		intended_target + Vector2(10.0, 0.0),
		intended_target + Vector2(0.0, 10.0),
		intended_target + Vector2(-10.0, 0.0),
	])
	draw_colored_polygon(diamond, _with_alpha(intent_color, 0.22))
	draw_polyline(PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
	]), intent_color, 2.5)
	var intended_candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), intended_id
	)
	if not intended_candidate.is_empty():
		var source_local := _court_to_local(Vector2(intended_candidate.get(
			"source_position", Vector2.ZERO
		)))
		var prepared_local := _court_to_local(Vector2(intended_candidate.get(
			"prepared_position", Vector2.ZERO
		)))
		draw_dashed_line(
			source_local, prepared_local, Color("53d769"), 3.0, 6.0,
		)
	var actual_candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), actual_id
	)
	if not actual_candidate.is_empty():
		var actual_start := _court_to_local(Vector2(actual_candidate.get(
			"prepared_position", Vector2.ZERO
		)))
		var actual_final := _court_to_local(Vector2(actual_candidate.get(
			"final_position", Vector2.ZERO
		)))
		draw_dashed_line(
			actual_start, actual_final, Color("55e6c1"), 3.0, 5.0,
		)
		draw_circle(actual_final, 8.0, Color("55e6c1"), false, 2.5)
		if bool(setter_response.get("ownership_changed", false)):
			draw_dashed_line(
				intended_target, actual_final, Color("f2c94c"), 2.5, 5.0,
			)
			draw_circle(
				intended_target.lerp(actual_final, 0.5), 7.0,
				Color("f2c94c"), false, 2.5,
			)
	if show_labels:
		draw_string(
			ThemeDB.fallback_font, intended_target + Vector2(13.0, -9.0),
			"TARGET: %s" % str(setter_response.get(
				"expected_setter_name", intended_id
			)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, intent_color,
		)
		if bool(setter_response.get("ownership_changed", false)):
			draw_string(
				ThemeDB.fallback_font, intended_target + Vector2(13.0, 8.0),
				"ACTUAL: %s · HANDOFF" % str(setter_response.get(
					"selected_setter_name", actual_id
				)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2c94c"),
			)


func _draw_shadow_contact_envelope(
	setter_response: Dictionary,
	outgoing_flight: Dictionary,
	show_labels: bool,
) -> void:
	if not bool(setter_response.get("available", false)):
		return
	var selected_id := int(setter_response.get("selected_setter_id", -1))
	var candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), selected_id
	)
	if candidate.is_empty():
		return
	var final_position := Vector2(candidate.get("final_position", Vector2.ZERO))
	var contact_position := Vector2(outgoing_flight.get(
		"destination", final_position
	))
	var reach_meters := maxf(float(candidate.get(
		"contact_reach_meters", 0.0
	)), 0.0)
	var reachable := bool(candidate.get("true_reachable", false))
	var envelope_color := Color("55e6c1") if reachable else Color("ef6461")
	var points := PackedVector2Array()
	for point_index in range(41):
		var angle := TAU * float(point_index) / 40.0
		points.append(_court_to_local(final_position + Vector2(
			cos(angle) * reach_meters / 9.0,
			sin(angle) * reach_meters / 18.0,
		)))
	if points.size() > 1:
		draw_colored_polygon(points, _with_alpha(envelope_color, 0.10))
		draw_polyline(points, _with_alpha(envelope_color, 0.90), 2.5)
	var final_local := _court_to_local(final_position)
	var contact_local := _court_to_local(contact_position)
	draw_dashed_line(final_local, contact_local, envelope_color, 2.0, 4.0)
	draw_circle(contact_local, 8.0, envelope_color, false, 2.5)
	if not show_labels:
		return
	var contact_height := float(candidate.get("contact_height_meters", 0.0))
	var standing_reach := float(candidate.get("standing_reach_meters", 0.0))
	var maximum_height := float(candidate.get(
		"maximum_contact_height_meters", standing_reach
	))
	var access_mode := "LATE"
	if bool(candidate.get("requires_jump", false)):
		access_mode = "JUMP"
	elif bool(candidate.get("standing_reachable", false)):
		access_mode = "STAND"
	draw_string(
		ThemeDB.fallback_font, contact_local + Vector2(12.0, 26.0),
		"%s · reach %.2fm · ball %.2fm / stand %.2fm / max %.2fm" % [
			access_mode, reach_meters, contact_height, standing_reach,
			maximum_height,
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, envelope_color,
	)


func _shadow_setter_candidate(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


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
				var phase_label := ""
				if defensive_phase == 1:
					phase_label = "BLOCK" if bool(assignment.block_participation) \
						and CourtConstants.is_front_row_slot(slot_number) else "NO BLOCK ROLE"
				elif defensive_phase == 2:
					var floor_zone: Resource = defensive_plan.zone_for(
						player_id, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
					)
					phase_label = "FLOOR ACTIVE" if floor_zone != null and bool(floor_zone.enabled) \
						else "OUT OF FLOOR DEFENSE"
				elif defensive_phase == 3:
					phase_label = "ACTIVE SETTER" if player_id == lineup.active_setter_id() \
						else str(assignment.attack_coverage_responsibility)
				else:
					var receive_zone: Resource = defensive_plan.zone_for(
						player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
					)
					phase_label = "PASSER" if receive_zone != null and bool(receive_zone.enabled) \
						else "HIDDEN"
				draw_string(
					ThemeDB.fallback_font, center + Vector2(-48, 52),
					phase_label,
					HORIZONTAL_ALIGNMENT_CENTER, 96, 10,
					_with_alpha(palette["text"], 0.78),
				)


func _draw_opponents() -> void:
	if not show_opponents or opponent_team == null:
		return
	for player_resource in opponent_team.on_court_players():
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var court_position: Vector2 = opponent_team.court_position(player.id, "defense")
		if playback_event != null \
				and str(playback_event.metadata.get("side", "")) == "opponent" \
				and int(playback_event.actor_id) == player.id:
			var movement_origin: Vector2 = playback_event.metadata.get(
				"movement_start",
				playback_event.metadata.get("hitter_start", court_position),
			)
			var action_target: Vector2 = playback_event.start_position
			if int(playback_event.event_type) == RallyEventModel.EventType.SET:
				action_target = playback_event.metadata.get(
					"setter_position", playback_event.start_position
				)
			court_position = movement_origin.lerp(action_target, playback_progress)
		var center := _court_to_local(court_position)
		var active := playback_event != null \
			and str(playback_event.metadata.get("side", "")) == "opponent" \
			and int(playback_event.actor_id) == player.id
		var radius := 19.0 if active else 16.0
		draw_circle(center + Vector2(3, 4), radius, Color(0, 0, 0, 0.30))
		draw_circle(center, radius, palette["opponent_marker"])
		draw_circle(center, radius, palette["line"], false, 2.0)
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-14, 5), player.position_code,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 12, palette["opponent_text"],
		)
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-38, -24), player.display_name,
			HORIZONTAL_ALIGNMENT_CENTER, 76, 10,
			_with_alpha(palette["text"], 0.82),
		)


func _short_responsibility(value: String) -> String:
	return value.replace(" defense", "").replace("Net ", "Block ")


func _draw_rally_playback() -> void:
	if playback_event == null:
		return
	var followup_block := _followup_block_event()
	var trajectory: Dictionary = playback_event.metadata.get("outgoing_trajectory", {})
	if followup_block != null and int(playback_event.event_type) == RallyEventModel.EventType.ATTACK:
		var block_outcome := str(followup_block.metadata.get("outcome", ""))
		if block_outcome == "stuff":
			trajectory = {}
		elif block_outcome in ["touch", "funnel", "recycle"]:
			var deflection_target: Vector2 = followup_block.metadata.get(
				"deflection_target", followup_block.end_position
			)
			trajectory = {
				"start_position": playback_event.start_position,
				"control_position": playback_event.start_position.lerp(deflection_target, 0.5),
				"end_position": deflection_target,
			}
	var trajectory_start: Vector2 = trajectory.get(
		"start_position", playback_event.start_position
	)
	var trajectory_control: Vector2 = trajectory.get(
		"control_position", trajectory_start.lerp(playback_event.end_position, 0.5)
	)
	var trajectory_end: Vector2 = trajectory.get(
		"end_position", playback_event.end_position
	)
	var start := _court_to_local(trajectory_start)
	var finish := _court_to_local(trajectory_end)
	var control := _court_to_local(trajectory_control)
	var inverse := 1.0 - playback_progress
	var ball_position := inverse * inverse * start \
		+ 2.0 * inverse * playback_progress * control \
		+ playback_progress * playback_progress * finish
	var event_color: Color = _playback_event_color(followup_block)
	if playback_event.actor_id >= 0 and lineup != null:
		var slot_number := lineup.slot_for_player(playback_event.actor_id)
		if slot_number >= 0:
			var actor_position := _court_to_local(_player_court_position(
				int(playback_event.actor_id), slot_number
			))
			draw_circle(actor_position, 27.0, event_color, false, 4.0)
	if not playback_ball_visible:
		return
	if trajectory.is_empty():
		if followup_block != null and int(playback_event.event_type) == RallyEventModel.EventType.ATTACK:
			_draw_block_reach_marker(followup_block)
		return
	var path_points := PackedVector2Array()
	for path_index in range(21):
		var path_t := float(path_index) / 20.0
		var path_inverse := 1.0 - path_t
		path_points.append(
			path_inverse * path_inverse * start
			+ 2.0 * path_inverse * path_t * control
			+ path_t * path_t * finish
		)
	draw_polyline(path_points, _with_alpha(event_color, 0.34), 2.0)
	var block_event: Resource = followup_block
	if block_event == null and playback_event.event_type == RallyEventModel.EventType.BLOCK:
		block_event = playback_event
	if block_event != null:
		_draw_block_coverage(block_event)
	var shadow_position := ball_position + Vector2(3.0, 5.0)
	draw_circle(shadow_position, 9.0, Color(0, 0, 0, 0.3))
	var apex_height := float(trajectory.get("apex_height_meters", 0.0))
	var height_scale := sin(PI * playback_progress) * apex_height
	draw_circle(ball_position, 9.0 + height_scale * 0.8, Color("f5d328"))
	draw_arc(ball_position, 6.0, 0.0, TAU, 16, Color("245ba7"), 2.0)


func _draw_block_coverage(block_event: Resource) -> void:
	var segments: Array = block_event.metadata.get("coverage_segments", [])
	if segments.is_empty():
		segments.append({
			"x_min": clampf(block_event.end_position.x - 0.08, 0.0, 1.0),
			"x_max": clampf(block_event.end_position.x + 0.08, 0.0, 1.0),
			"completeness": float(block_event.quality),
		})
	for segment_data in segments:
		var segment: Dictionary = segment_data
		var completeness := clampf(float(segment.get("completeness", 0.0)), 0.0, 1.0)
		var coverage_color := _block_flash_color(block_event, completeness)
		draw_line(
			_court_to_local(Vector2(float(segment.get("x_min", 0.45)), CourtConstants.NET_Y)),
			_court_to_local(Vector2(float(segment.get("x_max", 0.55)), CourtConstants.NET_Y)),
			coverage_color, 7.0 + completeness * 4.0,
		)


func _followup_block_event() -> Resource:
	if contact_overlay_event != null \
			and int(contact_overlay_event.event_type) == RallyEventModel.EventType.BLOCK:
		return contact_overlay_event
	return null


func _playback_event_color(followup_block: Resource) -> Color:
	var event_type := int(playback_event.event_type)
	if event_type == RallyEventModel.EventType.BLOCK:
		var block_outcome := str(playback_event.metadata.get("outcome", ""))
		if block_outcome == "stuff":
			return Color("e64f4f")
		if block_outcome in ["touch", "funnel", "recycle"]:
			return Color("f2c94c")
		if block_outcome == "miss":
			return Color("4ad66d")
		return palette["path"] if playback_event.success else Color("e64f4f")
	if followup_block == null or event_type != RallyEventModel.EventType.ATTACK:
		return palette["path"] if playback_event.success else Color("e64f4f")
	var block_outcome := str(followup_block.metadata.get("outcome", ""))
	if block_outcome == "stuff":
		return Color("e64f4f")
	if block_outcome in ["touch", "funnel", "recycle"]:
		return Color("f2c94c")
	return Color("4ad66d")


func _block_flash_color(block_event: Resource, completeness: float) -> Color:
	var outcome := str(block_event.metadata.get("outcome", ""))
	match outcome:
		"stuff":
			return Color("e64f4f").lerp(Color("a60d22"), completeness)
		"touch", "funnel", "recycle":
			return Color("f2c94c").lerp(Color("c18f1a"), completeness)
		_:
			return Color("4ad66d").lerp(Color("1f8c4e"), completeness)


func _draw_block_reach_marker(block_event: Resource) -> void:
	var net_point := _court_to_local(Vector2(float(block_event.end_position.x), CourtConstants.NET_Y))
	var intensity := clampf(float(block_event.quality), 0.0, 1.0)
	draw_circle(net_point, 12.0 + intensity * 5.0, _block_flash_color(block_event, intensity), false, 4.0)


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
		var zones: Dictionary = defensive_plan.zones_for(defensive_zone_type)
		var zone: Resource = zones.get(player_id) as Resource
		if zone != null:
			return Vector2(zone.center)
		return defensive_plan.defender_position(player_id, fallback)
	return fallback


func _with_alpha(raw_color: Variant, alpha: float) -> Color:
	var result: Color = raw_color
	result.a = alpha
	return result
