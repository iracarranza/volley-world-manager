class_name VolleyballPhilosophyPreview
extends SubViewportContainer

## Deterministic teaching vignette used by 02 VOLLEYBALL. The court, actors,
## locomotion, approach, contact, block and landing poses are the production
## match presentation; only the tactical situation and decision are authored.
const COURT_SCENE := preload("res://scenes/components/match_court_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const HOME_BASE := {
	1: Vector2(0.20, 0.58), 2: Vector2(0.50, 0.57), 3: Vector2(0.80, 0.58),
	4: Vector2(0.20, 0.82), 5: Vector2(0.50, 0.84), 6: Vector2(0.80, 0.82),
}
const AWAY_BASE := {
	101: Vector2(0.20, 0.42), 102: Vector2(0.50, 0.43), 103: Vector2(0.80, 0.42),
	104: Vector2(0.20, 0.18), 105: Vector2(0.50, 0.16), 106: Vector2(0.80, 0.18),
}

var _viewport: SubViewport
var _court: MatchCourt3D
var _vignette_id := "good_ball_read"
var _montage_vignettes: Array[String] = [
	"good_ball_read", "serve_target", "defense_read",
	"transition_opportunity", "broken_available", "construction_flexible",
]
var _clock := 0.0
var _ready_to_draw := false


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.name = "GameplayViewport"
	_viewport.size = Vector2i(760, 300)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_court = COURT_SCENE.instantiate() as MatchCourt3D
	_viewport.add_child(_court)
	await get_tree().process_frame
	_court.setup_players(HOME_BASE, AWAY_BASE)
	for actor_value in _court.player_actors.values():
		var actor := actor_value as PlayerActor3D
		if actor == null:
			continue
		actor.identity_label.visible = false
		actor.focus_ring.visible = false
	## Q1 is decided at the net. Keep one fixed A/B/C camera, but spend the frame
	## on the reception-to-block corridor rather than on empty free zone.
	_court.camera_3d.position = Vector3(9.1, 8.2, 8.9)
	_court.camera_3d.fov = 37.0
	_court.camera_3d.look_at(Vector3(-0.25, 0.85, 1.15), Vector3.UP)
	_ready_to_draw = true
	_apply_frame(0.0)


func set_vignette(vignette_id: String) -> void:
	_vignette_id = vignette_id
	_clock = 0.0
	if _ready_to_draw:
		_apply_frame(0.0)


func set_montage_vignettes(vignette_ids: Array[String]) -> void:
	if vignette_ids.is_empty():
		return
	_montage_vignettes = vignette_ids.duplicate()
	_clock = 0.0


func _process(delta: float) -> void:
	if not _ready_to_draw or not visible:
		return
	_clock = fmod(_clock + delta, _loop_seconds())
	_apply_frame(_clock / _loop_seconds())


func _loop_seconds() -> float:
	if _vignette_id.begins_with("good_ball_"):
		return 5.8
	if _vignette_id == "serve_aggressive":
		return 5.0
	if _vignette_id == "volleyball_montage":
		return 7.2
	return 4.2


func _apply_frame(raw_t: float) -> void:
	## Q1 places every body exactly once per frame so the production gait sees a
	## continuous journey. The older generic previews still rebuild from base.
	if not _vignette_id.begins_with("good_ball_"):
		_reset_players()
	var t := clampf(raw_t / 0.88, 0.0, 1.0)
	if _vignette_id == "volleyball_montage":
		_montage(t)
	else:
		_draw_vignette(_vignette_id, t)


func _draw_vignette(id: String, t: float) -> void:
	match id:
		"good_ball_quick": _good_ball(t, "quick")
		"good_ball_read": _good_ball(t, "read")
		"good_ball_hitter": _good_ball(t, "hitter")
		"serve_controlled": _serve(t, "controlled")
		"serve_target": _serve(t, "target")
		"serve_aggressive": _serve(t, "aggressive")
		"defense_floor": _defense(t, "floor")
		"defense_read": _defense(t, "read")
		"defense_block": _defense(t, "block")
		"transition_reset": _transition(t, "reset")
		"transition_opportunity": _transition(t, "opportunity")
		"transition_pressure": _transition(t, "pressure")
		"broken_structure": _broken_ball(t, "structure")
		"broken_available": _broken_ball(t, "available")
		"broken_pressure": _broken_ball(t, "pressure")
		"construction_combination": _construction(t, "combination")
		"construction_flexible": _construction(t, "flexible")
		"construction_isolation": _construction(t, "isolation")
		_: _good_ball(t, "read")


func _reset_players() -> void:
	for raw_id in HOME_BASE:
		_court.set_player_position(int(raw_id), HOME_BASE[raw_id])
	for raw_id in AWAY_BASE:
		_court.set_player_position(int(raw_id), AWAY_BASE[raw_id])
	for actor_value in _court.player_actors.values():
		var actor := actor_value as PlayerActor3D
		if actor == null:
			continue
		actor.ready_stance = "defending"
		actor.block_arms = &"two"
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)


func _ball(tactical: Vector2, height: float) -> void:
	_court.ball_actor.position = _court.tactical_to_world(tactical.x, tactical.y, height)


func _arc(a: Vector2, b: Vector2, t: float, peak: float = 3.1) -> void:
	var p := a.lerp(b, clampf(t, 0.0, 1.0))
	var h := 0.8 + sin(clampf(t, 0.0, 1.0) * PI) * peak
	_ball(p, h)


func _flight(a: Vector2, a_h: float, b: Vector2, b_h: float, progress: float, lift: float) -> void:
	var f := clampf(progress, 0.0, 1.0)
	var p := a.lerp(b, f)
	var h := lerpf(a_h, b_h, f) + sin(f * PI) * lift
	_ball(p, h)


func _move(player_id: int, target: Vector2, t: float, begin: float, end: float) -> void:
	var base: Vector2 = HOME_BASE.get(player_id, AWAY_BASE.get(player_id, target))
	_court.set_player_position(player_id, base.lerp(target, smoothstep(begin, end, t)))


func _sample(points: Array, times: Array, t: float) -> Vector2:
	if points.is_empty() or points.size() != times.size():
		return Vector2.ZERO
	if t <= float(times[0]):
		return Vector2(points[0])
	for i in range(points.size() - 1):
		var a_t := float(times[i])
		var b_t := float(times[i + 1])
		if t <= b_t:
			return Vector2(points[i]).lerp(Vector2(points[i + 1]), smoothstep(a_t, b_t, t))
	return Vector2(points[-1])


func _path(player_id: int, points: Array, times: Array, t: float) -> void:
	_court.set_player_position(player_id, _sample(points, times, t))


func _stance(player_id: int, stance: String) -> void:
	var actor := _court.player_actors.get(player_id) as PlayerActor3D
	if actor != null:
		actor.ready_stance = stance


func _pose_action(
	player_id: int,
	event_type: int,
	t: float,
	begin: float,
	contact: float,
	end: float,
	peak_elevation: float,
	direction: Vector2,
	context: Dictionary = {},
) -> void:
	if t < begin or t > end:
		return
	var actor := _court.player_actors.get(player_id) as PlayerActor3D
	if actor == null:
		return
	var phase := 0.0
	var elevation := 0.0
	if t <= contact:
		var f := inverse_lerp(begin, contact, t)
		phase = lerpf(-1.0, 0.0, f)
		elevation = lerpf(0.0, peak_elevation, smoothstep(0.0, 1.0, f))
	else:
		var f := inverse_lerp(contact, end, t)
		phase = lerpf(0.0, 1.0, f)
		elevation = lerpf(peak_elevation, 0.0, smoothstep(0.0, 1.0, f))
	actor.set_pose(event_type, elevation, phase, direction, true, context)


func _q1_positions(mode: String, t: float) -> Dictionary:
	var p: Dictionary = {}
	for id in HOME_BASE:
		p[int(id)] = HOME_BASE[id]
	for id in AWAY_BASE:
		p[int(id)] = AWAY_BASE[id]
	## Identical reception/release geometry in every answer.
	p[5] = _sample([HOME_BASE[5], Vector2(0.50, 0.82), Vector2(0.48, 0.73)], [0.00, 0.08, 0.28], t)
	p[3] = _sample([HOME_BASE[3], Vector2(0.66, 0.57)], [0.00, 0.20], t)
	p[4] = _sample([HOME_BASE[4], Vector2(0.19, 0.76), Vector2(0.28, 0.69)], [0.00, 0.18, 0.34], t)
	p[1] = _sample([HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.54)], [0.00, 0.18, 0.34], t)
	p[2] = _sample([HOME_BASE[2], Vector2(0.48, 0.54)], [0.00, 0.28], t)
	p[6] = _sample([HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.73, 0.66)], [0.00, 0.24, 0.38], t)
	if mode == "quick":
		p[2] = _sample([HOME_BASE[2], Vector2(0.48, 0.54), Vector2(0.50, 0.515)], [0.00, 0.27, 0.37], t)
		p[1] = _sample([HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.54), Vector2(0.24, 0.58)], [0.00, 0.18, 0.35, 0.66], t)
		p[102] = _sample([AWAY_BASE[102], Vector2(0.48, 0.445)], [0.00, 0.42], t)
		## A3 is intentionally still travelling when H2 contacts at .40.
		p[103] = _sample([AWAY_BASE[103], Vector2(0.72, 0.445), Vector2(0.58, 0.445)], [0.00, 0.36, 0.58], t)
		p[104] = _sample([AWAY_BASE[104], Vector2(0.25, 0.20)], [0.00, 0.58], t)
		p[105] = _sample([AWAY_BASE[105], Vector2(0.50, 0.20)], [0.00, 0.58], t)
		p[106] = _sample([AWAY_BASE[106], Vector2(0.71, 0.21)], [0.00, 0.58], t)
	elif mode == "read":
		p[1] = _sample([HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.535)], [0.00, 0.18, 0.43], t)
		p[2] = _sample([HOME_BASE[2], Vector2(0.48, 0.535), Vector2(0.46, 0.515)], [0.00, 0.30, 0.41], t)
		## Commit, register, then repair. The set starts only after .42.
		p[102] = _sample([AWAY_BASE[102], Vector2(0.43, 0.445), Vector2(0.29, 0.445), Vector2(0.29, 0.445), Vector2(0.38, 0.445)], [0.00, 0.30, 0.38, 0.43, 0.67], t)
		p[103] = _sample([AWAY_BASE[103], Vector2(0.70, 0.445), Vector2(0.60, 0.445), Vector2(0.32, 0.445)], [0.00, 0.34, 0.43, 0.67], t)
		p[104] = _sample([AWAY_BASE[104], Vector2(0.28, 0.20), Vector2(0.20, 0.22)], [0.00, 0.40, 0.72], t)
		p[105] = _sample([AWAY_BASE[105], Vector2(0.46, 0.20), Vector2(0.40, 0.22)], [0.00, 0.40, 0.72], t)
		p[106] = _sample([AWAY_BASE[106], Vector2(0.72, 0.21)], [0.00, 0.65], t)
	else:
		p[1] = _sample([HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.17, 0.535)], [0.00, 0.18, 0.44], t)
		p[2] = _sample([HOME_BASE[2], Vector2(0.49, 0.535)], [0.00, 0.34], t)
		## A2 and A3 finish a square double before the hitter contacts at .61.
		p[102] = _sample([AWAY_BASE[102], Vector2(0.28, 0.445), Vector2(0.235, 0.445)], [0.00, 0.43, 0.53], t)
		p[103] = _sample([AWAY_BASE[103], Vector2(0.20, 0.445), Vector2(0.155, 0.445)], [0.00, 0.45, 0.53], t)
		p[104] = _sample([AWAY_BASE[104], Vector2(0.22, 0.20)], [0.00, 0.52], t)
		p[105] = _sample([AWAY_BASE[105], Vector2(0.48, 0.19)], [0.00, 0.52], t)
		p[106] = _sample([AWAY_BASE[106], Vector2(0.74, 0.21), Vector2(0.67, 0.18)], [0.00, 0.52, 0.78], t)
	return p


func _q1_prepare(mode: String, t: float) -> void:
	var positions := _q1_positions(mode, t)
	for id in positions:
		_court.set_player_position(int(id), Vector2(positions[id]))
	for id in _court.player_actors:
		var actor := _court.player_actors[id] as PlayerActor3D
		actor.block_arms = &"two"
		actor.ready_stance = "blocking" if int(id) in [101, 102, 103] else "defending"
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
	## Production reception pose: platform forms before contact and drives through.
	_pose_action(5, RallyEventModel.EventType.RECEPTION, t, 0.00, 0.08, 0.22, 0.0, Vector2(0.16, -0.25))


func _good_ball(t: float, mode: String) -> void:
	var receive := Vector2(0.50, 0.82)
	var setter := Vector2(0.66, 0.57)
	_q1_prepare(mode, t)
	## Every clip begins with the same visible serve-reception and clean pass.
	if t < 0.08:
		_flight(Vector2(0.52, 0.46), 3.4, receive, 0.92, t / 0.08, 0.35)
		return
	if t < 0.22:
		_flight(receive, 0.92, setter, 2.08, (t - 0.08) / 0.14, 0.72)
		return

	if mode == "quick":
		_pose_action(3, RallyEventModel.EventType.SET, t, 0.16, 0.25, 0.36, 0.05, Vector2(-0.16, -0.06))
		_pose_action(2, RallyEventModel.EventType.ATTACK, t, 0.25, 0.40, 0.55, 0.86, Vector2(-0.02, -0.34))
		_pose_action(102, RallyEventModel.EventType.BLOCK, t, 0.30, 0.42, 0.57, 0.66, Vector2(0.0, 0.20))
		## The late outside blocker only starts loading at contact; one arm never
		## becomes a useful second wall before the ball has crossed it.
		var a3 := _court.player_actors[103] as PlayerActor3D
		a3.block_arms = &"one"
		_pose_action(103, RallyEventModel.EventType.BLOCK, t, 0.38, 0.53, 0.68, 0.58, Vector2(-0.18, 0.20))
		if t < 0.28:
			_flight(setter, 2.08, Vector2(0.50, 0.515), 2.82, (t - 0.22) / 0.06, 0.38)
		elif t < 0.40:
			_flight(Vector2(0.50, 0.515), 2.82, Vector2(0.49, 0.40), 3.02, (t - 0.28) / 0.12, 0.28)
		elif t < 0.58:
			_flight(Vector2(0.49, 0.40), 3.02, Vector2(0.49, 0.17), 0.30, (t - 0.40) / 0.18, 0.12)
		else:
			_ball(Vector2(0.49, 0.17), 0.30)
		return

	if mode == "read":
		## H2 and A2 physically sell the quick. The ball stays with H3 until A2
		## has completed the inward commitment and held it for a readable beat.
		_pose_action(2, RallyEventModel.EventType.ATTACK, t, 0.27, 0.40, 0.54, 0.72, Vector2(-0.02, -0.25))
		_pose_action(102, RallyEventModel.EventType.BLOCK, t, 0.27, 0.40, 0.55, 0.63, Vector2(0.0, 0.22))
		_pose_action(3, RallyEventModel.EventType.SET, t, 0.34, 0.44, 0.55, 0.04, Vector2(-0.48, -0.04))
		_pose_action(1, RallyEventModel.EventType.ATTACK, t, 0.43, 0.60, 0.76, 0.88, Vector2(0.16, -0.34))
		_pose_action(103, RallyEventModel.EventType.BLOCK, t, 0.49, 0.61, 0.77, 0.67, Vector2(-0.18, 0.22))
		var late := _court.player_actors[102] as PlayerActor3D
		late.block_arms = &"one"
		_pose_action(102, RallyEventModel.EventType.BLOCK, t, 0.54, 0.69, 0.82, 0.48, Vector2(-0.20, 0.22))
		if t < 0.44:
			_ball(setter, 2.08)
		elif t < 0.57:
			_flight(setter, 2.08, Vector2(0.18, 0.535), 2.92, (t - 0.44) / 0.13, 0.72)
		elif t < 0.76:
			_flight(Vector2(0.18, 0.535), 2.92, Vector2(0.34, 0.20), 0.32, (t - 0.57) / 0.19, 0.14)
		else:
			_ball(Vector2(0.34, 0.20), 0.32)
		return

	## Trust hitters: the block is not late or broken. Both blockers finish the
	## close and reach together before H1 strikes; the only failure is the tool.
	_pose_action(3, RallyEventModel.EventType.SET, t, 0.22, 0.34, 0.46, 0.05, Vector2(-0.49, -0.04))
	_pose_action(1, RallyEventModel.EventType.ATTACK, t, 0.40, 0.61, 0.80, 0.90, Vector2(-0.02, -0.25))
	_pose_action(102, RallyEventModel.EventType.BLOCK, t, 0.42, 0.57, 0.76, 0.72, Vector2(-0.10, 0.22))
	_pose_action(103, RallyEventModel.EventType.BLOCK, t, 0.42, 0.57, 0.76, 0.72, Vector2(-0.10, 0.22))
	if t < 0.47:
		_flight(setter, 2.08, Vector2(0.17, 0.535), 2.94, (t - 0.22) / 0.25, 0.82)
	elif t < 0.61:
		_flight(Vector2(0.17, 0.535), 2.94, Vector2(0.155, 0.445), 3.12, (t - 0.47) / 0.14, 0.20)
	elif t < 0.66:
		## Contact is visibly at the formed outside hand.
		_flight(Vector2(0.155, 0.445), 3.12, Vector2(0.10, 0.40), 3.06, (t - 0.61) / 0.05, 0.02)
	elif t < 0.80:
		## Sharp change of direction after the hand, ending clearly outside court.
		_flight(Vector2(0.10, 0.40), 3.06, Vector2(-0.09, 0.31), 0.55, (t - 0.66) / 0.14, 0.06)
	else:
		_ball(Vector2(-0.09, 0.31), 0.55)


## Q2. Reliability, targeting and direct pressure remain the existing deterministic
## teaching sketches until their own choreography pass.
func _serve(t: float, mode: String) -> void:
	var server_start := Vector2(0.80, 0.97)
	var contact := Vector2(0.80, 1.03)
	_move(6, contact, t, 0.0, 0.18)
	if mode == "controlled":
		_move(105, Vector2(0.50, 0.20), t, 0.38, 0.72)
		_arc(contact, Vector2(0.50, 0.20), t / 0.74, 2.5)
		return
	if mode == "target":
		_move(104, Vector2(0.34, 0.20), t, 0.30, 0.68)
		_move(105, Vector2(0.38, 0.20), t, 0.30, 0.68)
		_arc(contact, Vector2(0.36, 0.20), t / 0.70, 3.0)
		return
	if t < 0.50:
		_move(106, Vector2(0.74, 0.24), t, 0.20, 0.44)
		_arc(contact, Vector2(0.74, 0.18), t / 0.46, 4.1)
	else:
		_court.set_player_position(6, server_start.lerp(contact, smoothstep(0.50, 0.60, t)))
		_arc(contact, Vector2(1.08, 0.08), (t - 0.50) / 0.42, 4.5)


func _defense(t: float, mode: String) -> void:
	var away_setter := Vector2(0.50, 0.38)
	if mode == "floor":
		_move(1, Vector2(0.17, 0.54), t, 0.08, 0.28)
		_move(2, Vector2(0.27, 0.54), t, 0.08, 0.28)
		_move(6, Vector2(0.66, 0.77), t, 0.08, 0.28)
		if t < 0.23: _arc(away_setter, Vector2(0.22, 0.44), t / 0.23, 2.0)
		elif t < 0.58: _arc(Vector2(0.22, 0.44), Vector2(0.66, 0.77), (t - 0.23) / 0.35, 2.5)
		else: _arc(Vector2(0.66, 0.77), Vector2(0.50, 0.62), (t - 0.58) / 0.25, 1.8)
		return
	if mode == "read":
		if t < 0.28:
			_arc(away_setter, Vector2(0.78, 0.44), t / 0.28, 2.4)
		else:
			_move(2, Vector2(0.70, 0.54), t, 0.28, 0.50)
			_move(3, Vector2(0.80, 0.54), t, 0.28, 0.50)
			_move(5, Vector2(0.58, 0.77), t, 0.30, 0.56)
			_move(6, Vector2(0.80, 0.75), t, 0.30, 0.56)
			_arc(Vector2(0.78, 0.44), Vector2(0.58, 0.77), (t - 0.28) / 0.45, 2.5)
		return
	_move(1, Vector2(0.17, 0.54), t, 0.02, 0.22)
	_move(2, Vector2(0.27, 0.54), t, 0.02, 0.22)
	if t < 0.24: _arc(away_setter, Vector2(0.22, 0.44), t / 0.24, 2.0)
	elif t < 0.53: _arc(Vector2(0.22, 0.44), Vector2(0.23, 0.51), (t - 0.24) / 0.29, 2.1)
	else: _arc(Vector2(0.23, 0.51), Vector2(0.26, 0.34), (t - 0.53) / 0.24, 1.3)


func _transition(t: float, mode: String) -> void:
	var dig := Vector2(0.72, 0.82)
	var setter := Vector2(0.52, 0.65)
	_move(6, dig, t, 0.0, 0.24)
	_move(5, setter, t, 0.08, 0.34)
	if t < 0.24:
		_arc(Vector2(0.24, 0.42), dig, t / 0.24, 2.3)
		return
	if t < 0.39:
		_arc(dig, setter, (t - 0.24) / 0.15, 1.7)
		return
	if mode == "reset":
		_move(1, Vector2(0.20, 0.56), t, 0.30, 0.57)
		_move(2, Vector2(0.50, 0.55), t, 0.30, 0.57)
		_move(3, Vector2(0.80, 0.56), t, 0.30, 0.57)
		if t < 0.60: _ball(setter, 1.05)
		elif t < 0.78: _arc(setter, Vector2(0.50, 0.54), (t - 0.60) / 0.18, 2.3)
		else: _arc(Vector2(0.50, 0.54), Vector2(0.50, 0.22), (t - 0.78) / 0.18, 2.0)
		return
	if mode == "opportunity":
		_move(3, Vector2(0.80, 0.53), t, 0.34, 0.50)
		_move(103, Vector2(0.70, 0.45), t, 0.46, 0.68)
		if t < 0.58: _arc(setter, Vector2(0.80, 0.54), (t - 0.39) / 0.19, 2.2)
		else: _arc(Vector2(0.80, 0.54), Vector2(0.72, 0.22), (t - 0.58) / 0.28, 2.1)
		return
	_move(1, Vector2(0.24, 0.53), t, 0.30, 0.46)
	if t < 0.50: _arc(setter, Vector2(0.24, 0.54), (t - 0.39) / 0.11, 1.7)
	else: _arc(Vector2(0.24, 0.54), Vector2(0.18, 0.23), (t - 0.50) / 0.24, 2.0)


func _broken_ball(t: float, mode: String) -> void:
	var receiver := Vector2(0.92, 0.82)
	var off_net := Vector2(0.78, 0.66)
	_move(6, receiver, t, 0.0, 0.22)
	if t < 0.22:
		_arc(Vector2(0.58, 0.15), receiver, t / 0.22, 3.0)
		return
	if t < 0.38:
		_arc(receiver, off_net, (t - 0.22) / 0.16, 1.5)
		return
	if mode == "structure":
		_move(1, Vector2(0.20, 0.55), t, 0.30, 0.62)
		_move(2, Vector2(0.50, 0.54), t, 0.30, 0.62)
		_move(3, Vector2(0.80, 0.55), t, 0.30, 0.62)
		if t < 0.62: _arc(off_net, Vector2(0.50, 0.64), (t - 0.38) / 0.24, 2.5)
		elif t < 0.80: _arc(Vector2(0.50, 0.64), Vector2(0.50, 0.54), (t - 0.62) / 0.18, 2.0)
		else: _arc(Vector2(0.50, 0.54), Vector2(0.48, 0.22), (t - 0.80) / 0.16, 1.9)
		return
	if mode == "available":
		_move(3, Vector2(0.78, 0.54), t, 0.30, 0.48)
		if t < 0.60: _arc(off_net, Vector2(0.78, 0.54), (t - 0.38) / 0.22, 2.0)
		else: _arc(Vector2(0.78, 0.54), Vector2(0.70, 0.22), (t - 0.60) / 0.27, 2.1)
		return
	_move(1, Vector2(0.25, 0.53), t, 0.30, 0.46)
	if t < 0.53: _arc(off_net, Vector2(0.25, 0.54), (t - 0.38) / 0.15, 2.2)
	else: _arc(Vector2(0.25, 0.54), Vector2(0.18, 0.22), (t - 0.53) / 0.25, 2.1)


func _construction(t: float, mode: String) -> void:
	var target_x := 0.50
	if mode == "combination":
		var cross := smoothstep(0.12, 0.58, t)
		_court.set_player_position(1, HOME_BASE[1].lerp(Vector2(0.54, 0.54), cross))
		_court.set_player_position(2, HOME_BASE[2].lerp(Vector2(0.30, 0.54), cross))
		target_x = 0.80
	elif mode == "flexible":
		target_x = 0.20 if t < 0.48 else 0.80
	else:
		target_x = 0.18
		_court.set_player_position(101, Vector2(0.18, 0.45))
		_court.set_player_position(102, Vector2(0.30, 0.45))
	if t < 0.42:
		_arc(Vector2(0.50, 0.78), Vector2(0.50, 0.58), t / 0.42, 2.0)
	else:
		_arc(Vector2(0.50, 0.58), Vector2(target_x, 0.30), (t - 0.42) / 0.58, 3.0)


func _montage(t: float) -> void:
	var count := maxi(_montage_vignettes.size(), 1)
	var scaled := clampf(t, 0.0, 0.9999) * float(count)
	var segment := mini(int(floor(scaled)), count - 1)
	var local_t := fmod(scaled, 1.0)
	_draw_vignette(_montage_vignettes[segment], local_t)
