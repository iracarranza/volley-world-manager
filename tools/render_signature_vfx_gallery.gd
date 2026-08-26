extends Node

## Exact in-engine review frames for signature-move VFX.
## No illustration/reconstruction: real PlayerActor3D + SignatureSurge3D under
## the match court's camera, materials and lighting.

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const CASES := [
	{"id": "block_crush", "move": "block_crush", "event": RallyEventModel.EventType.ATTACK, "pose": 0.92, "anchor": 2.28, "succeeded": true},
	{"id": "high_hands", "move": "high_hands", "event": RallyEventModel.EventType.ATTACK, "pose": 0.92, "anchor": 2.28, "succeeded": true},
	{"id": "foresight_read", "move": "foresight", "event": RallyEventModel.EventType.DIG, "pose": 0.54, "anchor": 1.42, "succeeded": true},
	## A misread is the same pre-contact field: presentation must not reveal the
	## answer early. Only later authoritative body/ball playback distinguishes it.
	{"id": "foresight_misread", "move": "foresight", "event": RallyEventModel.EventType.DIG, "pose": 0.54, "anchor": 1.42, "succeeded": false},
	{"id": "heroics_committed", "move": "heroics", "event": RallyEventModel.EventType.DIG, "pose": 0.76, "anchor": 1.15, "succeeded": true},
	{"id": "heroics_denied", "move": "heroics", "event": RallyEventModel.EventType.DIG, "pose": 0.34, "anchor": 1.15, "succeeded": false},
	{"id": "monster_block", "move": "monster_block", "event": RallyEventModel.EventType.BLOCK, "pose": 0.84, "anchor": 2.34, "succeeded": true},
]
const PHASES := [
	{"id": "gather", "phase": -0.20},
	{"id": "contact", "phase": 0.14},
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
	## `club_region` is the production kit input: PlayerActor3D.configure reads
	## it from the same profile channel MatchCourt3D supplies, then
	## `apply_ui_palette` resolves RegionalKits. Keep the review on that path
	## instead of teaching the renderer a second way to dress an actor.
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
	var case_id := str(case_data.id)
	var event_type := int(case_data.event)
	var pose_phase := float(case_data.pose)
	var anchor := float(case_data.anchor)
	_actor.block_arms = &"two" if event_type == RallyEventModel.EventType.BLOCK else &""
	_actor.set_pose(event_type, pose_phase, 0.50, Vector2(0.0, -1.0), true)
	var surge := _actor.get_node("SignatureSurge3D") as SignatureSurge3D
	surge.contact_anchor_meters = anchor
	for phase_data in PHASES:
		var phase := float(phase_data.phase)
		surge.set_cue(move, 1.0, bool(case_data.succeeded), phase)
		await get_tree().process_frame
		await get_tree().process_frame
		var path := "res://artifacts/signature-vfx/%s_%s.png" % [case_id, str(phase_data.id)]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/signature-vfx"))
		get_tree().root.get_texture().get_image().save_png(path)
		print("saved %s" % ProjectSettings.globalize_path(path))
	surge.clear()


func _hide_readouts() -> void:
	for path in ["IdentityLabel", "FocusRing", "CognitionBillboard3D"]:
		var node := _actor.get_node_or_null(path)
		if node is Node3D:
			(node as Node3D).visible = false
