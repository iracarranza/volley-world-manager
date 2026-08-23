extends SceneTree

## The three physical feature axes, on the two families that share a face.
##
## Feli and Cani are the closest pair in the roster -- same head sphere, same ear
## cone, same muzzle sphere, differing mostly by where the ears point. So they
## are the honest test of both halves of the question at once: whether an axis
## gives a family enough within-family variety to tell two of them apart, and
## whether it does that without letting a long-eared cat drift into being a dog.
##
## Two sheets. The sweep holds two axes at `standard` and walks the third, so a
## column is exactly one claim. The squad takes the hash as the roster will get
## it, which is the only view that says whether the combination reads.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")

const FAMILIES: Array[String] = ["Feli", "Cani", "Ursi", "Simi"]
const OUTPUT_DIR := "res://artifacts/feature-axes"

## Ears and muzzle are face parts and are read at portrait range; build is the
## whole body and disappears at that crop. Each axis therefore names its own
## framing rather than being forced into one shared shot.
##
## **Both crops are derived from the body, not fixed.** A constant portrait height
## of 1.80 was fine while this tool only drew Feli and Cani, whose heads sit at
## 1.74 and 1.80; Simi's head is at 1.44 and Ursi's rig is shorter again, so the
## same number framed one family's face and another family's chest. A camera
## aimed at a number rather than at the thing it is measuring is the same defect
## as a threshold outside its own distribution.
const HEAD_SIZE: float = 0.98
const BODY_MARGIN: float = 1.22

const AXIS_FRAMING := {
	"ears": "head",
	"muzzle": "head",
	"build": "body",
}

## The angle each axis is actually legible from, which is not one angle.
##
## The first sweep shot everything at 26 degrees and Cani's ear axis barely read:
## a drop ear sits at x 0.15 against a head of radius 0.178, so it hangs *inside*
## the skull's own outline and near three-quarter view it merges with it. Turned
## toward profile it separates. A muzzle is length in front of a face and wants
## the same treatment; build is width and wants square-on, where a three-quarter
## view would foreshorten the thing being measured.
const AXIS_YAW := {
	"ears": 62.0,
	"muzzle": 48.0,
	"build": 0.0,
}

## A mid-tone colourway for the sweep, because the sweep is about shape.
##
## Not a fixed index across families: Feli 1 is a mid grey and Cani 1 is the
## near-black `3c3a3f`, so one shared number gave one readable row and one
## silhouette with no interior detail at all. Named per family instead.
const SWEEP_PALETTE := {
	"Feli": 0,  ## c98f4e, tan
	"Cani": 0,  ## 8a6a45, brown
	"Ursi": 2,  ## 8a6f52, mid brown -- 0 is 4a3b34 and too dark to read shape on
	"Simi": 5,  ## 9a5a3c, rust -- 1 is one of the authored four and near-black
}

var _viewport: SubViewport
var _camera: Camera3D
var _actor: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	await _sweep()
	await _squads()
	quit()


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	var world := World3D.new()
	_viewport.world_3d = world
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ffffff")
	environment.ambient_light_energy = 0.74
	world.environment = environment
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_camera.current = true
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, -30.0, 0.0)
	key.light_energy = 1.08
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 140.0, 0.0)
	fill.light_energy = 0.40
	_viewport.add_child(fill)
	_actor = ACTOR_SCENE.instantiate()
	_viewport.add_child(_actor)
	(_actor.get_node("Shadow") as Node3D).visible = false
	(_actor.get_node("FocusRing") as Node3D).visible = false
	(_actor.get_node("IdentityLabel") as Node3D).visible = false


func _frame(framing: String, silhouette: Dictionary) -> void:
	var rig := float(silhouette.get("rig_height", 2.0))
	var focus_y := float(silhouette.get("head_y", rig * 0.9)) \
		if framing == "head" else rig * 0.52
	_camera.size = HEAD_SIZE if framing == "head" else rig * BODY_MARGIN
	var focus := Vector3(0.0, focus_y, 0.0)
	_camera.position = focus + Vector3(0.0, 0.0, -4.2)
	_camera.look_at(focus, Vector3.UP)


## One case, rendered and written. Returns the silhouette so the caller can
## report what it actually got rather than what it asked for.
func _shot(
	player_id: int, family: String, appearance: Dictionary,
	framing: String, yaw: float, path: String
) -> Dictionary:
	_actor.configure(player_id, true, family, "Right", {
		"body_type": family,
		"appearance": appearance,
		"height_cm": 188.0, "wingspan_cm": 191.0,
	})
	_actor.rotation_degrees = Vector3(0.0, yaw, 0.0)
	## After `configure`, because the crop is read off the body that was just
	## built rather than assumed ahead of it.
	_frame(framing, _actor.silhouette)
	for _settle in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var opaque := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			if image.get_pixel(x, y).a > 0.04:
				opaque += 1
	if opaque < 120:
		push_error("Blank render %s" % path)
		quit(1)
		return {}
	image.save_png("%s/%s.png" % [OUTPUT_DIR, path])
	return _actor.silhouette


## Each axis walked with the other two held standard, and the numbers it moved
## printed beside it. The print is the point: an axis that renders and reports
## an unchanged dimension is a knob that cannot reach its own range.
func _sweep() -> void:
	print("%-6s %-7s %-9s %8s %8s %8s %8s" % [
		"family", "axis", "value", "ear_h", "ear_rot", "muz_z", "arm_r",
	])
	for family in FAMILIES:
		for axis_raw in BodyTypes.FEATURE_AXES:
			var axis: String = str(axis_raw)
			var framing: String = str(AXIS_FRAMING.get(axis, "head"))
			for value_raw in BodyTypes.feature_options(axis):
				var value: String = str(value_raw)
				var appearance := {
					"palette_index": int(SWEEP_PALETTE.get(family, 0)),
					"marking": "none",
					"ears": "standard", "muzzle": "standard",
					"build": "standard",
				}
				appearance[axis] = value
				var silhouette: Dictionary = await _shot(
					70000, family, appearance, framing,
					float(AXIS_YAW.get(axis, 26.0)),
					"sweep_%s_%s_%s" % [family.to_lower(), axis, value],
				)
				_report(family, axis, value, silhouette)


func _report(
	family: String, axis: String, value: String, silhouette: Dictionary
) -> void:
	var ear := _named_extra(silhouette, "EarLeft")
	var muzzle := _named_extra(silhouette, "Muzzle")
	var arm: Dictionary = silhouette.get("arm", {})
	print("%-6s %-7s %-9s %8.3f %8.1f %8.3f %8.4f" % [
		family, axis, value,
		float(ear.get("height", 0.0)),
		Vector3(ear.get("rotation", Vector3.ZERO)).z,
		Vector3(muzzle.get("position", Vector3.ZERO)).z,
		float(arm.get("top_radius", 0.0)),
	])


func _named_extra(silhouette: Dictionary, part_name: String) -> Dictionary:
	for raw_part in Array(silhouette.get("extras", [])):
		var part := Dictionary(raw_part)
		if str(part.get("name", "")) == part_name:
			return part
	return {}


## Eight volis per family, taking every axis from the hash exactly as a generated
## roster will. Palette and coat are hashed too, so this is the real question --
## not whether one axis moves, but whether eight of them together stop reading as
## the same drawing.
func _squads() -> void:
	print("")
	print("%-6s %-7s %-9s %-9s %-9s %-8s" % [
		"family", "id", "ears", "muzzle", "build", "coat",
	])
	for family in FAMILIES:
		for slot in range(8):
			var player_id := 80200 + slot * 37
			var features := BodyTypes.chosen_features(family, player_id, {})
			var coat := BodyTypes.marking_for(family, player_id)
			await _shot(
				player_id, family, {}, "body", 22.0,
				"squad_%s_%d" % [family.to_lower(), slot],
			)
			print("%-6s %-7d %-9s %-9s %-9s %-8s" % [
				family, player_id,
				str(features.get("ears", "-")),
				str(features.get("muzzle", "-")),
				str(features.get("build", "-")),
				coat,
			])
