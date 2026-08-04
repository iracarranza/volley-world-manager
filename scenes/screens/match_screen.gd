class_name MatchScreen
extends Control

signal close_requested

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const NET_HEIGHT_METERS: float = 2.43

@onready var match_court_3d: MatchCourt3D = %MatchCourt3D
@onready var caption_label: Label = %CaptionLabel
@onready var detail_label: Label = %DetailLabel
@onready var event_label: Label = %EventLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var pause_button: Button = %PauseButton
@onready var replay_button: Button = %ReplayButton
@onready var skip_button: Button = %SkipButton
@onready var camera_button: Button = %CameraButton
@onready var close_button: Button = %CloseButton
@onready var speed_option: OptionButton = %SpeedOption

var playback_speed: float = 1.0
var active_result: RallyResult
var playback_generation: int = 0
var playback_paused: bool = false
var skip_requested: bool = false
var playback_active: bool = false
var player_names: Dictionary = {}
var player_handedness: Dictionary = {}
var player_physical_profiles: Dictionary = {}


func _ready() -> void:
	pause_button.pressed.connect(_toggle_pause)
	replay_button.pressed.connect(_replay)
	skip_button.pressed.connect(_skip)
	camera_button.pressed.connect(_cycle_camera)
	close_button.pressed.connect(_close)
	speed_option.item_selected.connect(_speed_changed)
	_populate_speeds()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		KEY_C:
			_cycle_camera()
			get_viewport().set_input_as_handled()


func load_and_play_rally(rally_result: RallyResult, requested_speed: float = 1.0) -> void:
	if rally_result == null or rally_result.events.is_empty():
		return
	playback_generation += 1
	var generation := playback_generation
	active_result = rally_result
	playback_speed = clampf(requested_speed, 0.1, 4.0)
	_select_speed(playback_speed)
	playback_paused = false
	skip_requested = false
	playback_active = true
	pause_button.text = "Pause"
	replay_button.disabled = true
	skip_button.disabled = false
	visible = true
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_player_names(rally_result.events)
	player_handedness = rally_result.player_handedness.duplicate(true)
	player_physical_profiles = rally_result.player_physical_profiles.duplicate(true)
	var home_positions: Dictionary = rally_result.initial_home_positions
	var opponent_positions: Dictionary = rally_result.initial_opponent_positions
	if home_positions.is_empty() and opponent_positions.is_empty():
		var fallback := _fallback_positions_from_events(rally_result.events)
		home_positions = fallback["home"]
		opponent_positions = fallback["opponent"]
	match_court_3d.setup_players(
		home_positions, opponent_positions, player_names, player_handedness,
		player_physical_profiles,
	)
	match_court_3d.ball_actor.reset_flight()
	progress_bar.value = 0.0
	await _run_rally(generation)
	if generation != playback_generation:
		return
	playback_active = false
	replay_button.disabled = false
	skip_button.disabled = true
	pause_button.disabled = false
	pause_button.text = "Pause"
	match_court_3d.ball_actor.hold_at_rest()
	match_court_3d.reset_player_poses()
	event_label.text = "POINT COMPLETE"
	caption_label.text = rally_result.terminal_outcome.replace("_", " ").to_upper()
	detail_label.text = rally_result.explanation
	progress_bar.value = 100.0


func _run_rally(generation: int) -> void:
	var events := active_result.events
	for event_index in range(events.size()):
		if generation != playback_generation or skip_requested:
			break
		var event := events[event_index] as RallyEvent
		if event == null:
			continue
		_show_event_text(event, event_index, events.size())
		if event.event_type == RallyEventModel.EventType.SET_DECISION:
			## Tactical choice, not a second physical touch. The preceding flight
			## already delivered the setter to this instant; pausing here created a
			## visible hitch immediately before every set.
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		var next_contact := _next_contact_event(events, event_index + 1)
		if not trajectory.is_empty():
			await _play_flight(event, next_contact, trajectory, event_index, events.size(), generation)
		else:
			## An event the ball spends no time on costs no time.
			##
			## This was a flat 0.38 s for every contact without a trajectory, so
			## a block that never touched the ball, a defender's read step and a
			## dive all bought a beat of their own -- and the rally visibly
			## stopped while nothing happened. The simulator already knows when
			## each contact occurred, so the gap to the next one is the honest
			## answer, and where that gap is zero the two events are genuinely
			## simultaneous and share a beat instead of queueing.
			await _play_contact_pulse(
				event, _gap_to_next(events, event_index), generation
			)
	match_court_3d.ball_actor.hold_at_rest()


## How long the ball actually spends between this event and the next.
##
## Read from `physical_time`, which every event now carries and which the
## timestamp gate holds to 100% coverage with zero causality corrections. A
## quarter of all inter-event gaps are under 5 ms -- `RECEPTION` into the
## setter's decision, `ATTACK` into the `BLOCK` that meets it -- and those are
## not events to draw in sequence, they are one moment.
##
## Falls back to the old flat beat only when a stamp is missing, which the gate
## says should never happen; it is there so a regression degrades to the
## previous behaviour rather than to a zero-length rally.
func _gap_to_next(events: Array, event_index: int) -> float:
	var current := events[event_index] as RallyEvent
	if current == null or not current.metadata.has("physical_time"):
		return 0.38
	var moment := float(current.metadata["physical_time"])
	for later_index in range(event_index + 1, events.size()):
		var later := events[later_index] as RallyEvent
		if later == null or not later.metadata.has("physical_time"):
			continue
		return maxf(float(later.metadata["physical_time"]) - moment, 0.0)
	## The last contact of the rally has nothing after it, so it gets a short
	## outro rather than a gap.
	return 0.38


func _play_flight(
	event: RallyEvent,
	next_contact: RallyEvent,
	trajectory: Dictionary,
	event_index: int,
	event_count: int,
	generation: int,
) -> void:
	var duration := clampf(float(trajectory.get("duration", 0.5)), 0.08, 3.5)
	var display_trajectory := _display_trajectory(event, next_contact, trajectory)
	var movement_plan := _build_movement_plan(event, next_contact)
	var elapsed := 0.0
	match_court_3d.ball_actor.reset_flight()
	while elapsed < duration:
		if generation != playback_generation or skip_requested:
			break
		if playback_paused:
			await get_tree().process_frame
			continue
		elapsed += get_process_delta_time() * playback_speed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		match_court_3d.set_ball_trajectory_sample(display_trajectory, progress)
		match_court_3d.apply_movement_plan(movement_plan, progress)
		_apply_contact_poses(event, next_contact, progress)
		progress_bar.value = (
			(float(event_index) + progress) / maxf(float(event_count), 1.0)
		) * 100.0
		await get_tree().process_frame
	match_court_3d.finish_movement_plan(movement_plan)
	match_court_3d.reset_player_poses()


func _play_contact_pulse(event: RallyEvent, duration: float, generation: int) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		if generation != playback_generation or skip_requested:
			break
		if playback_paused:
			await get_tree().process_frame
			continue
		elapsed += get_process_delta_time() * playback_speed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		match_court_3d.reset_player_poses()
		var peak := _event_elevation(event, int(event.actor_id))
		match_court_3d.set_player_pose(
			int(event.actor_id), int(event.event_type),
			peak * sin(progress * PI), progress,
			event.end_position - event.start_position, true,
			_contact_posture(event),
		)
		await get_tree().process_frame


## How strained this contact was, as the resolver recorded it.
##
## `_reception_pass_result` classifies every reception and dig from the
## defender's reach margin, how deep into the edge of their range the ball was,
## and how well their body could face it, and writes the verdict onto the event.
## Reading it here is what makes a defender dropping to their knees mean
## something rather than being a flourish: the pose says what the simulation
## already decided, and a player forced low really was forced low.
##
## Defaults to `planted` for every other contact type, which is what the pose
## code treats as an ordinary athletic stance.
func _contact_posture(event: RallyEvent) -> String:
	if event == null:
		return "planted"
	return str(event.metadata.get("contact_posture", "planted"))


func _apply_contact_poses(event: RallyEvent, next_contact: RallyEvent, progress: float) -> void:
	match_court_3d.reset_player_poses()
	var event_actor := int(event.actor_id)
	var event_peak := _event_elevation(event, event_actor)
	var event_direction := event.end_position - event.start_position
	var outgoing_weight := 1.0 - smoothstep(0.18, 0.75, progress)
	var incoming_weight := smoothstep(0.48, 1.0, progress)
	## One player can legally contact twice in a row -- a blocker digging their
	## own deflection is the common case, since a block touch is not one of the
	## team's three contacts. Posing both events for them wrote the incoming
	## pose over the outgoing one at every progress value, so the block collapsed
	## to a standing dig the instant the deflection started travelling. That is
	## the "one play reading as several actions" the viewer sees. Whichever pose
	## currently carries more weight is the one drawn, so the block holds until
	## the dig genuinely takes over.
	var same_actor := next_contact != null and int(next_contact.actor_id) == event_actor
	var draw_outgoing := not same_actor or outgoing_weight >= incoming_weight
	if draw_outgoing:
		match_court_3d.set_player_pose(
			event_actor, int(event.event_type),
			event_peak * outgoing_weight, progress, event_direction, true,
			_contact_posture(event),
		)
	var event_assist := int(event.metadata.get("assist_id", -1))
	if event_assist >= 0 and event.event_type == RallyEventModel.EventType.BLOCK:
		match_court_3d.set_player_pose(
			event_assist, int(event.event_type),
			_event_elevation(event, event_assist) * outgoing_weight,
			progress, event_direction, true,
		)
	if next_contact == null:
		return
	var next_actor := int(next_contact.actor_id)
	var next_peak := _event_elevation(next_contact, next_actor)
	var next_direction := next_contact.end_position - next_contact.start_position
	if not same_actor or not draw_outgoing:
		match_court_3d.set_player_pose(
			next_actor, int(next_contact.event_type),
			next_peak * incoming_weight, progress, next_direction, true,
		)
	var next_assist := int(next_contact.metadata.get("assist_id", -1))
	if next_assist >= 0 and next_contact.event_type == RallyEventModel.EventType.BLOCK:
		match_court_3d.set_player_pose(
			next_assist, int(next_contact.event_type),
			_event_elevation(next_contact, next_assist) * smoothstep(0.48, 1.0, progress),
			progress, next_direction, true,
		)


func _build_movement_plan(event: RallyEvent, next_contact: RallyEvent) -> Dictionary:
	var plan := {}
	if next_contact == null:
		return plan
	var action_target := Vector2(next_contact.metadata.get(
		"movement_target", next_contact.start_position
	))
	var event_is_home := _event_is_home(next_contact)
	for raw_player_id in match_court_3d.live_positions:
		var player_id := int(raw_player_id)
		var start := Vector2(match_court_3d.live_positions[raw_player_id])
		var home_team := match_court_3d.home_player_ids.has(player_id)
		var target := _support_target(
			start, action_target, int(next_contact.event_type), home_team, event_is_home
		)
		if start.distance_to(target) > 0.002:
			plan[player_id] = {"start": start, "target": target}
	_apply_explicit_targets(plan, next_contact.metadata.get("home_phase_targets", {}))
	_apply_explicit_targets(plan, next_contact.metadata.get("opponent_phase_targets", {}))
	var staged_id := int(event.metadata.get("staged_next_actor_id", -1))
	if staged_id >= 0:
		_set_plan_target(
			plan, staged_id, Vector2(event.metadata.get("staged_next_position", action_target))
		)
	var next_actor_id := int(next_contact.actor_id)
	if next_actor_id >= 0:
		var actor_home := _event_is_home(next_contact)
		var actor_start := Vector2(next_contact.metadata.get(
			"movement_start", match_court_3d.live_positions.get(next_actor_id, action_target)
		))
		match_court_3d.ensure_player(
			next_actor_id, actor_start, actor_home,
			str(player_names.get(next_actor_id, next_contact.actor_name)),
			str(player_handedness.get(next_actor_id, "Right")),
			Dictionary(player_physical_profiles.get(next_actor_id, {})),
		)
		_set_plan_target(plan, next_actor_id, action_target)
		## Start the drawn journey where the simulator timed it from, not
		## wherever the previous leg happened to leave this actor standing. The
		## two disagreed most sharply for a blocker who then dug their own
		## deflection: the block phase parked them at the net, the dig was timed
		## from their floor-defence position, and playback drew the whole gap in
		## the 0.24s the deflection was in the air -- about 20 m/s.
		if next_contact.metadata.has("movement_start") and plan.has(next_actor_id):
			plan[next_actor_id]["start"] = actor_start
			match_court_3d.set_player_position(next_actor_id, actor_start)
		if next_contact.metadata.has("approach_start_position"):
			plan[next_actor_id]["waypoint"] = Vector2(
				next_contact.metadata["approach_start_position"]
			)
	return plan


func _apply_explicit_targets(plan: Dictionary, targets: Dictionary) -> void:
	for raw_player_id in targets:
		_set_plan_target(plan, int(raw_player_id), Vector2(targets[raw_player_id]))


func _set_plan_target(plan: Dictionary, player_id: int, target: Vector2) -> void:
	if not match_court_3d.live_positions.has(player_id):
		return
	var start := Vector2(match_court_3d.live_positions[player_id])
	plan[player_id] = {"start": start, "target": target}


func _support_target(
	position: Vector2,
	action_target: Vector2,
	event_type: int,
	home_team: bool,
	event_is_home: bool,
) -> Vector2:
	var local_position := position if home_team else Vector2(position.x, 1.0 - position.y)
	var local_action := action_target if home_team else Vector2(action_target.x, 1.0 - action_target.y)
	var own_phase := home_team == event_is_home
	var front_row := local_position.y < 0.72
	var target := local_position
	if own_phase:
		match event_type:
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				target = local_position.lerp(local_action, 0.08 if front_row else 0.15)
			RallyEventModel.EventType.SET:
				target = local_position.lerp(Vector2(local_action.x, 0.62), 0.16)
			RallyEventModel.EventType.ATTACK:
				target = local_position.lerp(Vector2(local_action.x, 0.68), 0.12)
			RallyEventModel.EventType.BLOCK:
				target = local_position.lerp(Vector2(local_action.x, 0.54), 0.18)
	else:
		match event_type:
			RallyEventModel.EventType.SET, RallyEventModel.EventType.ATTACK:
				var depth := 0.56 if front_row else clampf(local_position.y, 0.74, 0.92)
				target = local_position.lerp(Vector2(local_action.x, depth), 0.18)
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				target = local_position.lerp(Vector2(local_action.x, local_position.y), 0.04)
	target = Vector2(clampf(target.x, 0.05, 0.95), clampf(target.y, 0.52, 0.97))
	return target if home_team else Vector2(target.x, 1.0 - target.y)


func _event_elevation(event: RallyEvent, player_id: int) -> float:
	if event == null or player_id < 0:
		return 0.0
	var is_actor := int(event.actor_id) == player_id
	match int(event.event_type):
		RallyEventModel.EventType.ATTACK:
			if is_actor:
				return clampf(inverse_lerp(
					0.55, 1.25, float(event.metadata.get("jump_multiplier", 1.0))
				), 0.35, 1.0)
		RallyEventModel.EventType.BLOCK:
			if is_actor or int(event.metadata.get("assist_id", -1)) == player_id:
				return 0.85
		RallyEventModel.EventType.SET:
			if is_actor:
				var capability: Dictionary = event.metadata.get("setter_capability", {})
				match str(capability.get("reach_state", "")):
					"jump":
						return 0.55
					"beyond_reach":
						return 0.70
	return 0.0


func _display_trajectory(
	event: RallyEvent,
	next_contact: RallyEvent,
	trajectory: Dictionary,
) -> Dictionary:
	var display := trajectory.duplicate(true)
	var start_height := _event_contact_height(event)
	var end_height := _event_contact_height(next_contact) \
		if next_contact != null else 0.12
	var rise := maxf(float(trajectory.get(
		"apex_rise_meters", trajectory.get("apex_height_meters", 0.0)
	)), 0.0)
	var rise_scale := 1.0
	var minimum_lift := 0.25
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			rise_scale = 1.35
			minimum_lift = 0.42
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			rise_scale = 1.55
			minimum_lift = 0.62
		RallyEventModel.EventType.SET:
			rise_scale = 1.75
			minimum_lift = 0.90
		RallyEventModel.EventType.ATTACK:
			rise_scale = 0.35
			minimum_lift = 0.12
		RallyEventModel.EventType.BLOCK:
			rise_scale = 0.45
			minimum_lift = 0.16
	var apex_height := maxf(start_height, end_height) \
		+ maxf(rise * rise_scale, minimum_lift)
	if event.event_type == RallyEventModel.EventType.SERVE:
		apex_height = maxf(apex_height, NET_HEIGHT_METERS + 0.48)
	elif event.event_type == RallyEventModel.EventType.SET:
		apex_height = maxf(apex_height, NET_HEIGHT_METERS + 1.05)
	elif event.event_type == RallyEventModel.EventType.ATTACK:
		apex_height = maxf(apex_height, start_height + 0.08)
	display["start_height_meters"] = start_height
	display["end_height_meters"] = end_height
	display["apex_height_meters"] = apex_height
	display["height_contract"] = "absolute_3d_presentation"
	return display


func _event_contact_height(event: RallyEvent) -> float:
	if event == null or event.actor_id < 0:
		return 0.12
	var profile: Dictionary = player_physical_profiles.get(int(event.actor_id), {})
	var height_meters := float(profile.get("height_cm", 188.0)) / 100.0
	var wingspan_meters := float(profile.get("wingspan_cm", 191.0)) / 100.0
	var standing_reach := float(profile.get(
		"standing_reach_meters",
		height_meters * 1.215 + (wingspan_meters - height_meters) * 0.32,
	))
	var jumping_reach := float(profile.get(
		"jumping_reach_meters", standing_reach + 0.52
	))
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			var serve_style := str(event.metadata.get("serve_style", "Standing"))
			return lerpf(standing_reach, jumping_reach, 0.68) \
				if serve_style.contains("Jump") else standing_reach * 0.92
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			return clampf(height_meters * 0.52, 0.72, 1.16)
		RallyEventModel.EventType.SET:
			var capability: Dictionary = event.metadata.get("setter_capability", {})
			var reach_state := str(capability.get("reach_state", "standing"))
			if reach_state in ["jump", "beyond_reach"]:
				return lerpf(standing_reach, jumping_reach, 0.58)
			return standing_reach * 0.97
		RallyEventModel.EventType.ATTACK:
			var jump_effort := clampf(inverse_lerp(
				0.55, 1.25, float(event.metadata.get("jump_multiplier", 1.0))
			), 0.35, 1.0)
			return lerpf(standing_reach, jumping_reach, jump_effort)
		RallyEventModel.EventType.BLOCK:
			return jumping_reach * 0.96
	return float(event.metadata.get("contact_height_meters", 1.0))


func _event_is_home(event: RallyEvent) -> bool:
	var side := str(event.metadata.get("side", ""))
	if side == "home":
		return true
	if side == "opponent":
		return false
	return match_court_3d.home_player_ids.has(int(event.actor_id))


func _next_contact_event(events: Array[Resource], start_index: int) -> RallyEvent:
	for index in range(start_index, events.size()):
		var candidate := events[index] as RallyEvent
		if candidate == null:
			continue
		if candidate.event_type in [
			RallyEventModel.EventType.SET_DECISION,
			RallyEventModel.EventType.POINT,
		]:
			continue
		return candidate
	return null


func _show_event_text(event: RallyEvent, event_index: int, event_count: int) -> void:
	event_label.text = "%02d / %02d   %s   t=%.2fs" % [
		event_index + 1, event_count, event.type_name().to_upper(),
		float(event.metadata.get("event_time", 0.0)),
	]
	caption_label.text = event.headline if not event.headline.is_empty() else event.type_name()
	detail_label.text = event.detail


func _build_player_names(events: Array[Resource]) -> void:
	player_names.clear()
	for event_resource in events:
		var event := event_resource as RallyEvent
		if event == null or event.actor_id < 0 or event.actor_name.is_empty():
			continue
		player_names[int(event.actor_id)] = event.actor_name


func _fallback_positions_from_events(events: Array[Resource]) -> Dictionary:
	var home := {}
	var opponent := {}
	for event_resource in events:
		var event := event_resource as RallyEvent
		if event == null or event.actor_id < 0:
			continue
		var target := opponent if str(event.metadata.get("side", "")) == "opponent" else home
		if not target.has(int(event.actor_id)):
			target[int(event.actor_id)] = event.start_position
	return {"home": home, "opponent": opponent}


func _populate_speeds() -> void:
	speed_option.clear()
	for speed in [0.25, 0.5, 1.0, 1.5, 2.0]:
		speed_option.add_item("%s×" % str(speed))
		speed_option.set_item_metadata(speed_option.item_count - 1, speed)
	_select_speed(1.0)


func _select_speed(speed: float) -> void:
	for index in range(speed_option.item_count):
		if is_equal_approx(float(speed_option.get_item_metadata(index)), speed):
			speed_option.select(index)
			return


func _speed_changed(index: int) -> void:
	playback_speed = float(speed_option.get_item_metadata(index))


func _toggle_pause() -> void:
	if not playback_active:
		return
	playback_paused = not playback_paused
	pause_button.text = "Resume" if playback_paused else "Pause"


func _skip() -> void:
	skip_requested = true
	playback_paused = false


func _replay() -> void:
	if active_result != null:
		load_and_play_rally(active_result, playback_speed)


func _cycle_camera() -> void:
	camera_button.text = match_court_3d.cycle_camera()


func _close() -> void:
	playback_generation += 1
	playback_active = false
	playback_paused = false
	skip_requested = true
	match_court_3d.ball_actor.reset_flight()
	match_court_3d.reset_player_poses()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_requested.emit()
