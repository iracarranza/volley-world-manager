extends Node

## Exact in-engine causal review frames for signature action VFX.
##
## Every image uses the production player, ball, court, net, materials, poses,
## and SignatureSurge3D. The sequences deliberately move the body and ball so
## success/failure is readable from volleyball truth rather than colour.

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const BALL := preload("res://scenes/components/ball_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const REVIEW_CASES := [
	{
		"id": "foresight_correct", "move": "foresight", "succeeded": true,
		"stages": [
			{"id": "anticipation", "phase": -0.54},
			{"id": "action", "phase": -0.02},
			{"id": "dissipation", "phase": 0.48},
		],
	},
	{
		"id": "foresight_misread", "move": "foresight", "succeeded": false,
		"stages": [
			{"id": "anticipation", "phase": -0.54},
			{"id": "divergence", "phase": 0.12},
			{"id": "dissipation", "phase": 0.48},
		],
	},
	{
		"id": "heroics_actionable", "move": "heroics", "succeeded": true,
		"stages": [
			{"id": "activation", "phase": -0.12},
			{"id": "action", "phase": 0.10},
			{"id": "dissipation", "phase": 0.52},
		],
	},
	{
		"id": "heroics_denied", "move": "heroics", "succeeded": false,
		"stages": [
			{"id": "initial_tell", "phase": -0.12},
			{"id": "extinguish", "phase": 0.04},
			{"id": "ordinary_continuation", "phase": 0.34},
		],
	},
	{
		"id": "block_crush", "move": "block_crush", "succeeded": true,
		"stages": [
			{"id": "preparation", "phase": -0.24},
			{"id": "contested_contact", "phase": 0.10},
			{"id": "dissipation", "phase": 0.52},
		],
	},
	{
		"id": "high_hands", "move": "high_hands", "succeeded": true,
		"stages": [
			{"id": "preparation", "phase": -0.24},
			{"id": "high_hand_interaction", "phase": 0.10},
			{"id": "dissipation", "phase": 0.52},
		],
	},
	{
		"id": "monster_block", "move": "monster_block", "succeeded": true,
		"stages": [
			{"id": "establishment", "phase": -0.18},
			{"id": "maximum_coverage", "phase": 0.12},
			{"id": "dissipation", "phase": 0.52},
		],
	},
]

var _court: MatchCourt3D
var _primary: PlayerActor3D
var _opponent: PlayerActor3D
var _ball: BallActor3D


func _ready() -> void:
	get_window().size = Vector2i(720, 720)
	_court = COURT.instantiate() as MatchCourt3D
	add_child(_court)
	await get_tree().process_frame
	_primary = ACTOR.instantiate() as PlayerActor3D
	_opponent = ACTOR.instantiate() as PlayerActor3D
	_ball = BALL.instantiate() as BallActor3D
	_court.add_child(_primary)
	_court.add_child(_opponent)
	_court.add_child(_ball)
	_primary.configure(77, true, "Signature review", "Right", {
		"body_type": "Feli", "body_marking": "blaze", "club_region": "Pāwa Hitō",
	})
	_opponent.configure(78, false, "Interaction partner", "Left", {
		"body_type": "Vegi", "body_marking": "freckles", "club_region": "Ahi Tokerau",
	})
	_hide_readouts(_primary)
	_hide_readouts(_opponent)
	_primary.has_facing = true
	_primary.facing_yaw = 0.0
	_opponent.has_facing = true
	_opponent.facing_yaw = PI
	var camera := _court.camera_3d
	camera.position = Vector3(4.25, 2.65, 5.55)
	camera.fov = 35.0
	camera.look_at(Vector3(0.0, 1.42, 0.18), Vector3.UP)

	for case_data in REVIEW_CASES:
		await _render_case(Dictionary(case_data))
	get_tree().quit()


func _render_case(case_data: Dictionary) -> void:
	var stages: Array = case_data.stages
	for index in range(stages.size()):
		var stage := Dictionary(stages[index])
		_compose_frame(
			str(case_data.move), bool(case_data.succeeded), index,
			float(stage.phase),
		)
		await get_tree().process_frame
		await get_tree().process_frame
		_save_frame("%s_%s" % [str(case_data.id), str(stage.id)])
	_primary.signature_surge.clear()


func _compose_frame(move: String, succeeded: bool, stage: int, phase: float) -> void:
	_reset_scene()
	match move:
		"foresight":
			_compose_foresight(succeeded, stage)
		"heroics":
			_compose_heroics(succeeded, stage)
		"block_crush", "high_hands":
			_compose_attacker_signature(move, stage)
		"monster_block":
			_compose_monster_block(stage)
	var surge := _primary.signature_surge
	surge.action_direction = Vector2.LEFT if move == "heroics" else Vector2.RIGHT
	surge.set_cue(move, 1.0, succeeded, phase)


func _reset_scene() -> void:
	_primary.visible = true
	_opponent.visible = true
	_ball.reset_flight()
	_ball.visible = true
	_primary.rotation.y = 0.0
	_opponent.rotation.y = PI
	_primary.block_arms = &""
	_opponent.block_arms = &""
	_primary.signature_surge.clear()
	_opponent.signature_surge.clear()


func _compose_foresight(succeeded: bool, stage: int) -> void:
	## The defender visibly leaves neutral space before the hitter has supplied a
	## true trajectory. In the misread sequence the ball then travels to the
	## opposite seam, leaving the early mover stranded.
	var x_positions := [-0.58, -0.10, 0.04] if succeeded else [-0.58, 0.02, 0.22]
	_primary.position = Vector3(float(x_positions[stage]), 0.0, 0.92)
	_opponent.position = Vector3(-0.18, 0.0, -0.42)
	_primary.set_pose(
		RallyEventModel.EventType.DIG, [0.18, 0.48, 0.76][stage], 0.0,
		Vector2(0.0, -1.0), stage > 0,
	)
	_opponent.set_pose(
		RallyEventModel.EventType.ATTACK, [0.62, 0.88, 0.98][stage],
		[0.34, 0.48, 0.28][stage], Vector2(0.0, 1.0), true,
	)
	_primary.signature_surge.contact_anchor_meters = 1.12
	if stage == 0:
		_ball.position = Vector3(-0.08, 2.42, -0.30)
	elif succeeded:
		_ball.position = [Vector3(-0.05, 1.74, 0.28), Vector3(0.04, 1.16, 0.78)][stage - 1]
	else:
		_ball.position = [Vector3(-0.92, 1.66, 0.25), Vector3(-1.18, 0.92, 0.82)][stage - 1]


func _compose_heroics(succeeded: bool, stage: int) -> void:
	## Actionable Heroics closes an impossible lateral gap after the attack is
	## real. Denied Heroics never moves to or contacts the unreachable ball.
	var x_positions := [0.70, 0.06, -0.18] if succeeded else [0.70, 0.66, 0.64]
	_primary.position = Vector3(float(x_positions[stage]), 0.0, 0.92)
	_opponent.position = Vector3(0.10, 0.0, -0.42)
	_primary.contact_posture = "reaching" if succeeded else "planted"
	_primary.contact_recovery = "fall" if succeeded else "platform"
	_primary.set_pose(
		RallyEventModel.EventType.DIG,
		[0.30, 0.74, 0.94][stage] if succeeded else [0.20, 0.28, 0.44][stage],
		0.0, Vector2(-1.0, -0.25), succeeded and stage > 0,
	)
	_opponent.set_pose(
		RallyEventModel.EventType.ATTACK, [0.78, 0.96, 0.98][stage],
		[0.42, 0.34, 0.12][stage], Vector2(0.0, 1.0), true,
	)
	_primary.signature_surge.contact_anchor_meters = 0.94
	if succeeded:
		_ball.position = [
			Vector3(-0.78, 1.52, 0.22),
			Vector3(-0.38, 0.86, 0.72),
			Vector3(-0.24, 1.18, 0.88),
		][stage]
	else:
		_ball.position = [
			Vector3(-0.88, 1.48, 0.20),
			Vector3(-1.18, 0.92, 0.72),
			Vector3(-1.34, 0.34, 1.12),
		][stage]


func _compose_attacker_signature(move: String, stage: int) -> void:
	_primary.position = Vector3(0.25, 0.0, 0.46)
	_opponent.position = Vector3(-0.20, 0.0, -0.30)
	_opponent.block_arms = &"two"
	_primary.set_pose(
		RallyEventModel.EventType.ATTACK, [0.72, 0.92, 0.99][stage],
		[0.36, 0.52, 0.24][stage], Vector2(0.0, -1.0), true,
	)
	_opponent.set_pose(
		RallyEventModel.EventType.BLOCK, [0.72, 0.88, 0.96][stage],
		[0.34, 0.50, 0.22][stage], Vector2(0.0, 1.0), true,
	)
	_primary.signature_surge.contact_anchor_meters = 2.34
	if stage == 0:
		_ball.position = Vector3(0.22, 2.26, 0.18)
	elif stage == 1:
		_ball.position = Vector3(0.16, 2.48 if move == "high_hands" else 2.36, -0.01)
	else:
		_ball.position = Vector3(
			0.56 if move == "high_hands" else 0.14,
			2.70 if move == "high_hands" else 2.05,
			-0.36,
		)


func _compose_monster_block(stage: int) -> void:
	_primary.position = Vector3(-0.04, 0.0, 0.36)
	_opponent.position = Vector3(0.28, 0.0, -0.42)
	_primary.block_arms = &"two"
	_primary.set_pose(
		RallyEventModel.EventType.BLOCK, [0.66, 0.86, 0.98][stage],
		[0.34, 0.52, 0.24][stage], Vector2(0.0, -1.0), true,
	)
	_opponent.set_pose(
		RallyEventModel.EventType.ATTACK, [0.64, 0.90, 0.99][stage],
		[0.32, 0.48, 0.20][stage], Vector2(0.0, 1.0), true,
	)
	_primary.signature_surge.contact_anchor_meters = 2.38
	_ball.position = [
		Vector3(0.30, 2.30, -0.24),
		Vector3(0.02, 2.42, 0.00),
		Vector3(-0.20, 2.04, -0.28),
	][stage]


func _save_frame(stem: String) -> void:
	var directory := "res://artifacts/signature-vfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := "%s/%s.png" % [directory, stem]
	var error := get_tree().root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("could not save %s: %s" % [path, error_string(error)])
	else:
		print("saved %s" % ProjectSettings.globalize_path(path))


func _hide_readouts(actor: PlayerActor3D) -> void:
	for path in ["IdentityLabel", "FocusRing", "CognitionBillboard3D"]:
		var node := actor.get_node_or_null(path)
		if node is Node3D:
			(node as Node3D).visible = false
