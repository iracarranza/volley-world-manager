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
	_court.camera_3d.position = Vector3(11.8, 10.5, 11.3)
	_court.camera_3d.fov = 40.0
	_court.camera_3d.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
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
	_reset_players()
	## Every teaching loop spends its last twelve percent holding the consequence.
	## Without that pause the eye sees continuous motion but gets no stable frame
	## in which to understand what the tactical decision actually changed.
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
		actor.position.y = 0.0
		actor.ready_stance = "defending"
		actor.block_arms = &"two"


func _ball(tactical: Vector2, height: float) -> void:
	_court.ball_actor.position = _court.tactical_to_world(tactical.x, tactical.y, height)


func _arc(a: Vector2, b: Vector2, t: float, peak: float = 3.1) -> void:
	var p := a.lerp(b, clampf(t, 0.0, 1.0))
	var h := 0.8 + sin(clampf(t, 0.0, 1.0) * PI) * peak
	_ball(p, h)


func _move(player_id: int, target: Vector2, t: float, begin: float, end: float) -> void:
	var base: Vector2 = HOME_BASE.get(player_id, AWAY_BASE.get(player_id, target))
	var fraction := smoothstep(begin, end, t)
	_court.set_player_position(player_id, base.lerp(target, fraction))


## Piecewise path helper for authored choreography. Each frame starts from the
## canonical base state; this reconstructs the player's entire route at time t
## rather than accumulating arbitrary teleports between beats.
func _path(player_id: int, points: Array, times: Array, t: float) -> void:
	if points.is_empty() or points.size() != times.size():
		return
	if t <= float(times[0]):
		_court.set_player_position(player_id, Vector2(points[0]))
		return
	for i in range(points.size() - 1):
		var a_t := float(times[i])
		var b_t := float(times[i + 1])
		if t <= b_t:
			var f := smoothstep(a_t, b_t, t)
			_court.set_player_position(player_id, Vector2(points[i]).lerp(Vector2(points[i + 1]), f))
			return
	_court.set_player_position(player_id, Vector2(points[-1]))


func _stance(player_id: int, stance: String) -> void:
	var actor := _court.player_actors.get(player_id) as PlayerActor3D
	if actor != null:
		actor.ready_stance = stance


func _jump(player_id: int, t: float, begin: float, end: float, height: float) -> void:
	if t < begin or t > end:
		return
	var actor := _court.player_actors.get(player_id) as PlayerActor3D
	if actor == null:
		return
	var phase := clampf((t - begin) / maxf(end - begin, 0.001), 0.0, 1.0)
	actor.position.y = sin(phase * PI) * height


func _q1_shared_opening(t: float) -> void:
	## H5 owns the clean reception. H3 is the setter. H1/H2/H6 release as three
	## real threats while H4 and H5 begin the coverage transition. Away starts
	## from the same neutral read-block and floor-defense picture in every clip.
	var receive := Vector2(0.50, 0.82)
	var setter := Vector2(0.66, 0.57)
	_path(5, [HOME_BASE[5], receive, Vector2(0.48, 0.74)], [0.00, 0.06, 0.18], t)
	_path(3, [HOME_BASE[3], setter], [0.00, 0.10], t)
	_path(4, [HOME_BASE[4], Vector2(0.19, 0.76), Vector2(0.28, 0.70)], [0.00, 0.12, 0.24], t)
	_path(1, [HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.54)], [0.00, 0.10, 0.23], t)
	_path(2, [HOME_BASE[2], Vector2(0.48, 0.54)], [0.00, 0.16], t)
	_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.76, 0.69)], [0.00, 0.15, 0.28], t)
	for id in [101, 102, 103]:
		_stance(id, "blocking")
	for id in [104, 105, 106]:
		_stance(id, "defending")
	if t <= 0.11:
		_arc(receive, setter, t / 0.11, 1.9)


## Q1. These are three choreographed answers to the same good-ball problem.
## Quick spends the pass on time; Read preserves the decision until the block
## declares; Hitters accepts a formed wall and asks the attacker to solve it.
func _good_ball(t: float, mode: String) -> void:
	var setter := Vector2(0.66, 0.57)
	_q1_shared_opening(t)
	if t <= 0.11:
		return

	if mode == "quick":
		## H2 goes first. H1 and H6 stay credible, but A2 is still travelling when
		## the quick is already in the hitter's window; A3 cannot complete the wall.
		_path(2, [HOME_BASE[2], Vector2(0.48, 0.54), Vector2(0.50, 0.515)], [0.00, 0.16, 0.25], t)
		_path(1, [HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.54), Vector2(0.22, 0.56)], [0.00, 0.10, 0.25, 0.52], t)
		_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.72, 0.66)], [0.00, 0.15, 0.31], t)
		_path(102, [AWAY_BASE[102], Vector2(0.47, 0.445)], [0.00, 0.30], t)
		_path(103, [AWAY_BASE[103], Vector2(0.66, 0.445)], [0.00, 0.38], t)
		_path(104, [AWAY_BASE[104], Vector2(0.25, 0.20)], [0.00, 0.48], t)
		_path(105, [AWAY_BASE[105], Vector2(0.50, 0.20)], [0.00, 0.48], t)
		_path(106, [AWAY_BASE[106], Vector2(0.71, 0.21)], [0.00, 0.48], t)
		_stance(102, "blocking")
		_stance(103, "blocking")
		if t < 0.23:
			_arc(setter, Vector2(0.50, 0.515), (t - 0.11) / 0.12, 1.6)
		elif t < 0.34:
			_jump(2, t, 0.18, 0.34, 0.72)
			_jump(102, t, 0.23, 0.39, 0.58)
			_arc(Vector2(0.50, 0.515), Vector2(0.48, 0.28), (t - 0.23) / 0.11, 1.85)
		elif t < 0.52:
			_jump(102, t, 0.23, 0.39, 0.58)
			_jump(103, t, 0.33, 0.49, 0.48)
			_arc(Vector2(0.48, 0.28), Vector2(0.49, 0.17), (t - 0.34) / 0.18, 0.8)
		else:
			## Coverage closes around the landing while Away finishes the late close.
			_path(3, [HOME_BASE[3], setter, Vector2(0.60, 0.63)], [0.00, 0.10, 0.62], t)
			_path(4, [HOME_BASE[4], Vector2(0.19, 0.76), Vector2(0.34, 0.68)], [0.00, 0.12, 0.62], t)
			_path(5, [HOME_BASE[5], Vector2(0.50, 0.82), Vector2(0.48, 0.68)], [0.00, 0.06, 0.62], t)
			_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.68, 0.69)], [0.00, 0.15, 0.62], t)
			_ball(Vector2(0.49, 0.17), 0.35)
		return

	if mode == "read":
		## The same three Home threats remain live. H2's quick forces A2 inward;
		## A3 compresses to stay connected. Only after that information exists does
		## H3 release to H1, leaving A2 in a realistic late-repair race.
		_path(1, [HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.18, 0.535)], [0.00, 0.10, 0.31], t)
		_path(2, [HOME_BASE[2], Vector2(0.48, 0.535), Vector2(0.46, 0.515)], [0.00, 0.18, 0.31], t)
		_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.72, 0.66)], [0.00, 0.16, 0.35], t)
		_path(102, [AWAY_BASE[102], Vector2(0.43, 0.445), Vector2(0.34, 0.445), Vector2(0.28, 0.445)], [0.00, 0.20, 0.31, 0.38], t)
		_path(103, [AWAY_BASE[103], Vector2(0.70, 0.445), Vector2(0.58, 0.445), Vector2(0.33, 0.445)], [0.00, 0.24, 0.34, 0.58], t)
		_path(104, [AWAY_BASE[104], Vector2(0.28, 0.20), Vector2(0.20, 0.22)], [0.00, 0.32, 0.64], t)
		_path(105, [AWAY_BASE[105], Vector2(0.46, 0.20), Vector2(0.40, 0.22)], [0.00, 0.32, 0.64], t)
		_path(106, [AWAY_BASE[106], Vector2(0.72, 0.21)], [0.00, 0.55], t)
		if t < 0.31:
			## The setter is deliberately quiet: ball held in the setting window while
			## the block makes the first irreversible choice.
			_ball(setter, 1.12)
		elif t < 0.47:
			_jump(2, t, 0.27, 0.43, 0.62)
			_jump(102, t, 0.27, 0.44, 0.54)
			_arc(setter, Vector2(0.18, 0.535), (t - 0.31) / 0.16, 2.45)
		elif t < 0.66:
			_jump(1, t, 0.45, 0.64, 0.76)
			_jump(103, t, 0.48, 0.67, 0.62)
			_jump(102, t, 0.55, 0.72, 0.46)
			## H1 attacks the interior seam produced by A2's late repair.
			_arc(Vector2(0.18, 0.535), Vector2(0.34, 0.20), (t - 0.47) / 0.19, 2.15)
		else:
			_path(3, [HOME_BASE[3], setter, Vector2(0.54, 0.64)], [0.00, 0.10, 0.74], t)
			_path(4, [HOME_BASE[4], Vector2(0.19, 0.76), Vector2(0.26, 0.68)], [0.00, 0.12, 0.74], t)
			_path(5, [HOME_BASE[5], Vector2(0.50, 0.82), Vector2(0.42, 0.69)], [0.00, 0.06, 0.74], t)
			_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.64, 0.70)], [0.00, 0.16, 0.74], t)
			_ball(Vector2(0.34, 0.20), 0.32)
		return

	## Trust hitters. Away gets the best defensive structure of the trio: A3 owns
	## the pin, A2 closes all the way, and the floor organizes behind them. H1's
	## solution is an intentional high-hands tool, not another open seam.
	_path(1, [HOME_BASE[1], Vector2(0.12, 0.61), Vector2(0.17, 0.535)], [0.00, 0.10, 0.36], t)
	_path(2, [HOME_BASE[2], Vector2(0.49, 0.535)], [0.00, 0.28], t)
	_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.72, 0.66)], [0.00, 0.17, 0.36], t)
	_path(102, [AWAY_BASE[102], Vector2(0.28, 0.445), Vector2(0.24, 0.445)], [0.00, 0.38, 0.50], t)
	_path(103, [AWAY_BASE[103], Vector2(0.20, 0.445), Vector2(0.16, 0.445)], [0.00, 0.40, 0.50], t)
	_path(104, [AWAY_BASE[104], Vector2(0.22, 0.20)], [0.00, 0.50], t)
	_path(105, [AWAY_BASE[105], Vector2(0.48, 0.19)], [0.00, 0.50], t)
	_path(106, [AWAY_BASE[106], Vector2(0.74, 0.21)], [0.00, 0.50], t)
	if t < 0.36:
		_arc(setter, Vector2(0.17, 0.535), (t - 0.11) / 0.25, 2.65)
	elif t < 0.55:
		_jump(1, t, 0.34, 0.56, 0.78)
		_jump(102, t, 0.41, 0.61, 0.68)
		_jump(103, t, 0.40, 0.60, 0.68)
		_arc(Vector2(0.17, 0.535), Vector2(0.15, 0.44), (t - 0.36) / 0.19, 1.7)
	elif t < 0.63:
		_jump(102, t, 0.41, 0.61, 0.68)
		_jump(103, t, 0.40, 0.60, 0.68)
		## Visible block touch: contact high on A3's outside hand, then redirect out.
		_arc(Vector2(0.15, 0.44), Vector2(0.05, 0.32), (t - 0.55) / 0.08, 0.7)
	else:
		_path(2, [HOME_BASE[2], Vector2(0.49, 0.535), Vector2(0.34, 0.63)], [0.00, 0.28, 0.72], t)
		_path(3, [HOME_BASE[3], setter, Vector2(0.48, 0.64)], [0.00, 0.10, 0.72], t)
		_path(4, [HOME_BASE[4], Vector2(0.19, 0.76), Vector2(0.24, 0.68)], [0.00, 0.12, 0.72], t)
		_path(5, [HOME_BASE[5], Vector2(0.50, 0.82), Vector2(0.42, 0.68)], [0.00, 0.06, 0.72], t)
		_path(6, [HOME_BASE[6], Vector2(0.78, 0.73), Vector2(0.63, 0.69)], [0.00, 0.17, 0.72], t)
		_ball(Vector2(0.04, 0.30), 0.45)


## Q2. Reliability, targeting and direct pressure are different intentions, not
## low/medium/high power. The aggressive loop deliberately spends its second
## half on a miss so the risk is visible in the same teaching surface.
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
		var miss_t := (t - 0.50) / 0.42
		_court.set_player_position(6, server_start.lerp(contact, smoothstep(0.50, 0.60, t)))
		_arc(contact, Vector2(1.08, 0.08), miss_t, 4.5)


## Q3. All competent versions block and defend the floor. The distinction is
## where commitment is spent and when information is consumed.
func _defense(t: float, mode: String) -> void:
	var away_setter := Vector2(0.50, 0.38)
	if mode == "floor":
		_move(1, Vector2(0.17, 0.54), t, 0.08, 0.28)
		_move(2, Vector2(0.27, 0.54), t, 0.08, 0.28)
		_move(6, Vector2(0.66, 0.77), t, 0.08, 0.28)
		if t < 0.23:
			_arc(away_setter, Vector2(0.22, 0.44), t / 0.23, 2.0)
		elif t < 0.58:
			_arc(Vector2(0.22, 0.44), Vector2(0.66, 0.77), (t - 0.23) / 0.35, 2.5)
		else:
			_arc(Vector2(0.66, 0.77), Vector2(0.50, 0.62), (t - 0.58) / 0.25, 1.8)
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
	if t < 0.24:
		_arc(away_setter, Vector2(0.22, 0.44), t / 0.24, 2.0)
	elif t < 0.53:
		_arc(Vector2(0.22, 0.44), Vector2(0.23, 0.51), (t - 0.24) / 0.29, 2.1)
	else:
		_arc(Vector2(0.23, 0.51), Vector2(0.26, 0.34), (t - 0.53) / 0.24, 1.3)


## Q4. Every option starts from the same difficult defensive save. Only what the
## team does with the continuation changes.
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
		if t < 0.60:
			_ball(setter, 1.05)
		elif t < 0.78:
			_arc(setter, Vector2(0.50, 0.54), (t - 0.60) / 0.18, 2.3)
		else:
			_arc(Vector2(0.50, 0.54), Vector2(0.50, 0.22), (t - 0.78) / 0.18, 2.0)
		return

	if mode == "opportunity":
		_move(3, Vector2(0.80, 0.53), t, 0.34, 0.50)
		_move(103, Vector2(0.70, 0.45), t, 0.46, 0.68)
		if t < 0.58:
			_arc(setter, Vector2(0.80, 0.54), (t - 0.39) / 0.19, 2.2)
		else:
			_arc(Vector2(0.80, 0.54), Vector2(0.72, 0.22), (t - 0.58) / 0.28, 2.1)
		return

	_move(1, Vector2(0.24, 0.53), t, 0.30, 0.46)
	if t < 0.50:
		_arc(setter, Vector2(0.24, 0.54), (t - 0.39) / 0.11, 1.7)
	else:
		_arc(Vector2(0.24, 0.54), Vector2(0.18, 0.23), (t - 0.50) / 0.24, 2.0)


## Q5. This starts with serve reception rather than defense, so the teaching
## question is how side-out survives an imperfect first contact.
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
		if t < 0.62:
			_arc(off_net, Vector2(0.50, 0.64), (t - 0.38) / 0.24, 2.5)
		elif t < 0.80:
			_arc(Vector2(0.50, 0.64), Vector2(0.50, 0.54), (t - 0.62) / 0.18, 2.0)
		else:
			_arc(Vector2(0.50, 0.54), Vector2(0.48, 0.22), (t - 0.80) / 0.16, 1.9)
		return

	if mode == "available":
		_move(3, Vector2(0.78, 0.54), t, 0.30, 0.48)
		if t < 0.60:
			_arc(off_net, Vector2(0.78, 0.54), (t - 0.38) / 0.22, 2.0)
		else:
			_arc(Vector2(0.78, 0.54), Vector2(0.70, 0.22), (t - 0.60) / 0.27, 2.1)
		return

	_move(1, Vector2(0.25, 0.53), t, 0.30, 0.46)
	if t < 0.53:
		_arc(off_net, Vector2(0.25, 0.54), (t - 0.38) / 0.15, 2.2)
	else:
		_arc(Vector2(0.25, 0.54), Vector2(0.18, 0.22), (t - 0.53) / 0.25, 2.1)


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


## Review is now the player's six actual answers rather than a hard-coded sample
## of the middle choices. Each segment uses the same teaching vignette already
## seen on its question page.
func _montage(t: float) -> void:
	var count := maxi(_montage_vignettes.size(), 1)
	var scaled := clampf(t, 0.0, 0.9999) * float(count)
	var segment := mini(int(floor(scaled)), count - 1)
	var local_t := fmod(scaled, 1.0)
	_draw_vignette(_montage_vignettes[segment], local_t)
