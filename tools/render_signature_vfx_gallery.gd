extends Node

## Exact in-engine review frames for signature-move VFX.
## No illustration/reconstruction: real PlayerActor3D + SignatureSurge3D under
## the match court's camera, materials and lighting.

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const CASES := [
	{"move": "block_crush", "event": RallyEventModel.EventType.ATTACK, "pose": 0.92, "anchor": 2.28},
	{"move": "high_hands", "event": RallyEventModel.EventType.ATTACK, "pose": 0.92, "anchor": 2.28},
	## Foresight is a dig signature even though its advantage is earned before
	## the attack/serve contact. Review it on the defensive body, not a SET pose.
	{"move": "foresight", "event": RallyEventModel.EventType.DIG, "pose": 0.54, "anchor": 1.15},
	{"move": "heroics", "event": RallyEventModel.EventType.DIG, "pose": 0.76, "anchor": 1.15},
	{"move": "monster_block", "event": RallyEventModel.EventType.BLOCK, "pose": 0.84, "anchor": 2.34},
]
const PHASES := [
	{"id": "gather", "phase": -0.28},
	{"id": "release", "phase": 0.12},
	{"id": "tail", "phase": 0.46},
]

var _court: MatchCourt3D
var _actor: PlayerActor3D


func _ready() -> void:
	get_window().size = Vector2i(720, 720)
	_court = COURT.instantiate() as MatchCourt3D
	add_child(_court)
	await get_tree().process_frame
	_actor = ACTOR.instantiate() as PlayerActor3D
	_court.add_child(_actor)
	_actor.configure(77, true, "Signature review", "Right", {
		"body_type": "Feli",
		"body_marking": "blaze",
		"club_region": "Pāwa Hitō",
	})
	_hide_readouts()
	_actor.position = Vector3(0.0, 0.0, 0.4)
	_actor.rotation.y = 0.0
	_actor.has_facing = true
	_actor.facing_yaw = 0.0
	var camera := _court.camera_3d
	camera.position = Vector3(4.1, 2.45, 4.55)
	camera.fov = 34.0
	camera.look_at(Vector3(0.0, 1.48, 0.25), Vector3.UP)
	for case_data in CASES:
		await _render_case(Dictionary(case_data))
	get_tree().quit()


func _render_case(case_data: Dictionary) -> void:
	var move := str(case_data.move)
	var event_type := int(case_data.event)
	var pose_phase := float(case_data.pose)
	var anchor := float(case_data.anchor)
	_actor.block_arms = &"two" if event_type == RallyEventModel.EventType.BLOCK else &""
	_actor.set_pose(event_type, pose_phase, 0.50, Vector2(0.0, -1.0), true)
	var surge := _actor.get_node("SignatureSurge3D") as SignatureSurge3D
	surge.contact_anchor_meters = anchor
	for phase_data in PHASES:
		var phase := float(phase_data.phase)
		surge.set_cue(move, 1.0, true, phase)
		await get_tree().process_frame
		await get_tree().process_frame
		await _save_frame("%s_%s" % [move, str(phase_data.id)])

	## The defensive signatures have unusually meaningful failure reads.
	## Foresight can fully form but commit to the wrong future; Heroics can start
	## to ignite and then lose its tiny action window before the rescue exists.
	if move == "foresight":
		surge.set_cue(move, 1.0, false, 0.12)
		await get_tree().process_frame
		await get_tree().process_frame
		await _save_frame("foresight_misread")
	elif move == "heroics":
		surge.set_cue(move, 1.0, false, -0.04)
		await get_tree().process_frame
		await get_tree().process_frame
		await _save_frame("heroics_denied")

	surge.clear()


func _save_frame(stem: String) -> void:
	var directory := "res://artifacts/signature-vfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := "%s/%s.png" % [directory, stem]
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))


func _hide_readouts() -> void:
	for path in ["IdentityLabel", "FocusRing", "CognitionBillboard3D"]:
		var node := _actor.get_node_or_null(path)
		if node is Node3D:
			(node as Node3D).visible = false
