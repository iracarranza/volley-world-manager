class_name VolleyballPhilosophyPreview
extends SubViewportContainer

## Deterministic teaching vignette used by 02 VOLLEYBALL.
##
## This is deliberately not a second volleyball renderer. The preview owns the
## same MatchCourt3D scene, PlayerActor3D path and BallActor3D used by a match;
## only the short teaching choreography is authored here so every answer can be
## compared from the same camera, bodies and court.
const COURT_SCENE := preload("res://scenes/components/match_court_3d.tscn")

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
	## A stable high broadcast angle makes spacing, block formation and serving
	## targets legible inside a short onboarding panel.
	_court.camera_3d.position = Vector3(13.8, 13.0, 12.8)
	_court.camera_3d.fov = 43.0
	_court.camera_3d.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
	_ready_to_draw = true
	_apply_frame(0.0)


func set_vignette(vignette_id: String) -> void:
	_vignette_id = vignette_id
	_clock = 0.0
	if _ready_to_draw:
		_apply_frame(0.0)


func _process(delta: float) -> void:
	if not _ready_to_draw or not visible:
		return
	_clock = fmod(_clock + delta, _loop_seconds())
	_apply_frame(_clock / _loop_seconds())


func _loop_seconds() -> float:
	if _vignette_id == "serve_aggressive":
		return 4.8
	return 3.6


func _apply_frame(t: float) -> void:
	_reset_players()
	match _vignette_id:
		"good_ball_quick":
			_good_ball(t, 0.50, true, false)
		"good_ball_read":
			_good_ball(t, 0.78, false, true)
		"good_ball_hitter":
			_good_ball(t, 0.20, false, false)
		"serve_controlled":
			_serve(t, 0.50, false, false)
		"serve_target":
			_serve(t, 0.22, true, false)
		"serve_aggressive":
			_serve(t, 0.78, true, true)
		"defense_floor":
			_defense(t, "floor")
		"defense_read":
			_defense(t, "read")
		"defense_block":
			_defense(t, "block")
		"transition_reset":
			_transition(t, "reset")
		"transition_opportunity":
			_transition(t, "opportunity")
		"transition_pressure":
			_transition(t, "pressure")
		"broken_structure":
			_broken_ball(t, "structure")
		"broken_available":
			_broken_ball(t, "available")
		"broken_pressure":
			_broken_ball(t, "pressure")
		"construction_combination":
			_construction(t, "combination")
		"construction_flexible":
			_construction(t, "flexible")
		"construction_isolation":
			_construction(t, "isolation")
		"volleyball_montage":
			_montage(t)
		_:
			_good_ball(t, 0.78, false, true)


func _reset_players() -> void:
	for raw_id in HOME_BASE:
		_court.set_player_position(int(raw_id), HOME_BASE[raw_id])
	for raw_id in AWAY_BASE:
		_court.set_player_position(int(raw_id), AWAY_BASE[raw_id])


func _ball(tactical: Vector2, height: float) -> void:
	_court.ball_actor.position = _court.tactical_to_world(tactical.x, tactical.y, height)


func _arc(a: Vector2, b: Vector2, t: float, peak: float = 3.1) -> void:
	var p := a.lerp(b, clampf(t, 0.0, 1.0))
	var h := 0.8 + sin(clampf(t, 0.0, 1.0) * PI) * peak
	_ball(p, h)


func _good_ball(t: float, target_x: float, quick: bool, read_block: bool) -> void:
	var setter := Vector2(0.50, 0.58)
	var target := Vector2(target_x, 0.50)
	if t < 0.28:
		_arc(Vector2(0.26, 0.80), setter, t / 0.28, 2.0)
	elif t < 0.55:
		if read_block:
			var shift := smoothstep(0.0, 1.0, (t - 0.28) / 0.27)
			_court.set_player_position(102, AWAY_BASE[102].lerp(Vector2(0.38, 0.44), shift))
			_court.set_player_position(103, AWAY_BASE[103].lerp(Vector2(0.62, 0.44), shift))
		var set_t := (t - 0.28) / (0.16 if quick else 0.27)
		_arc(setter, Vector2(target_x, 0.56), set_t, 2.5)
	else:
		var attack_t := (t - 0.55) / 0.30
		_arc(Vector2(target_x, 0.56), Vector2(target_x, 0.30), attack_t, 2.2)
		if not quick:
			_court.set_player_position(102, Vector2(clampf(target_x - 0.05, 0.12, 0.88), 0.46))
			_court.set_player_position(103, Vector2(clampf(target_x + 0.05, 0.12, 0.88), 0.46))


func _serve(t: float, target_x: float, receiver_shift: bool, show_risk: bool) -> void:
	var start := Vector2(0.82, 1.02)
	var end := Vector2(target_x, 0.17)
	if show_risk and t >= 0.50:
		## Every second aggressive example is a miss. The choice teaches the
		## pressure/risk tradeoff rather than advertising only the successful serve.
		var miss_t := (t - 0.50) * 2.0
		_arc(start, Vector2(1.07, 0.10), miss_t, 4.4)
		return
	var local_t := t * (2.0 if show_risk else 1.0)
	_arc(start, end, local_t, 3.2 if show_risk else 2.4)
	if receiver_shift:
		_court.set_player_position(104, AWAY_BASE[104].lerp(Vector2(target_x, 0.19), smoothstep(0.25, 0.85, local_t)))


func _defense(t: float, mode: String) -> void:
	var attack_x := 0.22
	if mode == "read":
		attack_x = 0.76 if t > 0.38 else 0.50
	if mode == "block":
		_court.set_player_position(1, Vector2(0.25, 0.54))
		_court.set_player_position(2, Vector2(0.30, 0.54))
	elif mode == "floor":
		_court.set_player_position(4, Vector2(0.18, 0.72))
		_court.set_player_position(5, Vector2(0.45, 0.82))
		_court.set_player_position(6, Vector2(0.76, 0.76))
	else:
		var read := smoothstep(0.28, 0.58, t)
		_court.set_player_position(4, HOME_BASE[4].lerp(Vector2(attack_x, 0.72), read))
	_arc(Vector2(0.22, 0.44), Vector2(attack_x, 0.76), t, 2.6)


func _transition(t: float, mode: String) -> void:
	if t < 0.28:
		_arc(Vector2(0.24, 0.38), Vector2(0.58, 0.78), t / 0.28, 2.0)
		return
	var target_x := 0.50
	var wait := 0.18
	if mode == "opportunity":
		target_x = 0.78
		wait = 0.08
	elif mode == "pressure":
		target_x = 0.22
		wait = 0.0
	var local_t := clampf((t - 0.28 - wait) / maxf(0.72 - wait, 0.01), 0.0, 1.0)
	if mode == "reset":
		for id in [1, 2, 3]:
			_court.set_player_position(id, HOME_BASE[id].lerp(Vector2(float(id - 1) * 0.30 + 0.20, 0.58), smoothstep(0.0, 0.6, local_t)))
	_arc(Vector2(0.58, 0.78), Vector2(target_x, 0.33), local_t, 3.0)


func _broken_ball(t: float, mode: String) -> void:
	var contact := Vector2(0.93, 0.78)
	if t < 0.30:
		_arc(Vector2(0.58, 0.38), contact, t / 0.30, 2.4)
		_court.set_player_position(6, HOME_BASE[6].lerp(contact, smoothstep(0.05, 0.30, t)))
		return
	var target := Vector2(0.50, 0.58)
	var delay := 0.16
	if mode == "available":
		target = Vector2(0.78, 0.55)
		delay = 0.05
	elif mode == "pressure":
		target = Vector2(0.22, 0.48)
		delay = 0.0
	var local_t := clampf((t - 0.30 - delay) / maxf(0.70 - delay, 0.01), 0.0, 1.0)
	_arc(contact, target, local_t, 2.8)
	if mode == "structure":
		_court.set_player_position(1, HOME_BASE[1].lerp(Vector2(0.20, 0.58), local_t))
		_court.set_player_position(2, HOME_BASE[2].lerp(Vector2(0.50, 0.58), local_t))
		_court.set_player_position(3, HOME_BASE[3].lerp(Vector2(0.80, 0.58), local_t))


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
	var segment := int(floor(t * 3.0)) % 3
	var local_t := fmod(t * 3.0, 1.0)
	match segment:
		0:
			_good_ball(local_t, 0.78, false, true)
		1:
			_defense(local_t, "read")
		_:
			_transition(local_t, "opportunity")
