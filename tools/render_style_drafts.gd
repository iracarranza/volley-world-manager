extends SceneTree

## Three modernized treatments of one voli in one kit.
##
## One template throughout, so the only thing changing between sheets is the
## treatment: a **Feli** -- tan, tall ears, heavy build, tabby coat -- in the
## **Ĭspayk** strip, whose `heritage` build is a single broad chest band. Feli
## because it has the most part junctions and cosmetics in the roster (ears,
## muzzle, tail) and therefore stresses the "assembled from primitives" question
## hardest; Ĭspayk because one big flat band is the clearest possible surface to
## judge shading and garment structure against.
##
## **What is engine-real here and what is not.** The lighting, the materials and
## the per-part ink are all real: they are the actor's own, set through its own
## `flat_shading` flag and its own `Ink` children. The single unified contour is
## **composited afterwards** from the alpha mask by `build_style_sheet.py`,
## because the engine has no unified body mesh to grow a hull from -- that is
## the step-1 work, not something a draft can fake in the renderer. So the
## contour in variants 1 and 2 is an honest preview of the *look* and not a
## measurement of the cost.
##
## A correction this tool exists partly to record: the bodies were described as
## unshaded. They are not. `flat_shading` defaults to false and
## `_apply_material_color` builds a lit `StandardMaterial3D` at roughness 0.72.
## `SHADING_MODE_UNSHADED` appears only in `paint_flat`, which is a mask pass for
## the silhouette tracer, and in the ink twins. The flat read in earlier sheets
## came substantially from the *probe's* own lighting -- a white ambient at 0.74
## energy flattens any form the material could have shown.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const BodyTypes := preload("res://scripts/data/body_type_models.gd")

const OUTPUT_DIR := "res://artifacts/style-drafts"
const KIT_REGION := "Ĭspayk"

const TEMPLATE := {
	"body_type": "Feli",
	"club_region": KIT_REGION,
	"appearance": {
		"palette_index": 0,       ## c98f4e, tan
		"marking": "tabby",
		"ears": "tall",
		"muzzle": "standard",
		"build": "heavy",
	},
	"height_cm": 188.0, "wingspan_cm": 191.0,
}

## Two views per treatment: the whole body, which is how a match is watched, and
## a portrait, which is where identity is actually read.
## Square-on from each side. A joint is a crease running around a limb, and a
## three-quarter view hides half of it behind the limb's own curve -- which is
## exactly why the elbows read as fine while the knees did not. Front and back
## put every joint on a silhouette edge where under-filling has nowhere to hide.
const VIEWS := {
	"front": {"focus": 1.02, "size": 2.42, "yaw": 0.0},
	"back": {"focus": 1.02, "size": 2.42, "yaw": 180.0},
	## Straight up from the floor. The one view that answers "is anything hanging
	## out from under the kit", which no elevation can -- the tail's low end sat
	## below the shorts hem for as long as this body has existed and every shot
	## ever taken of it was from eye level.
	"below": {"focus": 1.02, "size": 2.42, "yaw": 0.0, "under": true},
}

## The three treatments, as lighting and ink. Everything else is held.
##
## `ink` is whether the actor's own per-part outlines stay on. Only the current
## look keeps them; every draft below turns them off, because the per-part hull
## is the thing being questioned.
const TREATMENTS := {
	"a_skirt": {
		"ink": false, "ambient": Color("efe4d6"), "ambient_energy": 0.54,
		"key": Color("fff6e8"), "key_energy": 0.92,
		"fill": Color("c4b9c8"), "fill_energy": 0.44,
		"rim_energy": 0.62, "unified_contour": true, "roughness": 0.44,
		"garments": true,
	},
	## The shorts shell hidden, leaving only the legs.
	##
	## The shell is a section of the torso's own profile, so it is a solid ring of
	## dark all the way round the body and reads as a skirt rather than as shorts.
	## Hiding it and keeping the leg openings is the test of whether the shell was
	## carrying the garment or getting in its way -- the shirt then runs to the
	## torso's own bottom and the shorts are two cuffs on the thighs, which is how
	## a Mii's shorts are actually built.
	"b_legs_only": {
		"ink": false, "ambient": Color("efe4d6"), "ambient_energy": 0.54,
		"key": Color("fff6e8"), "key_energy": 0.92,
		"fill": Color("c4b9c8"), "fill_energy": 0.44,
		"rim_energy": 0.62, "unified_contour": true, "roughness": 0.44,
		"garments": true,
	},

}

## What `_apply_material_color` builds every body mesh with. Restored explicitly
## on treatments that name no roughness of their own, because the actor is reused
## across every treatment and a mutated material does not reset itself.
const AUTHORED_ROUGHNESS: float = 0.72

var _viewport: SubViewport
var _camera: Camera3D
var _actor: Node3D
var _environment: Environment
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	for treatment_raw in TREATMENTS:
		var treatment: String = str(treatment_raw)
		var setup: Dictionary = TREATMENTS[treatment]
		await _rebuild_actor(setup)
		_apply_treatment(setup)
		for view_raw in VIEWS:
			var view: String = str(view_raw)
			await _shot(treatment, view, Dictionary(VIEWS[view]))
	quit()


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 640)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)
	var world := World3D.new()
	_viewport.world_3d = world
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment = _environment
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_camera.current = true
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-38.0, -34.0, 0.0)
	_viewport.add_child(_key)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-14.0, 128.0, 0.0)
	_viewport.add_child(_fill)
	## Behind and above, pointing back at the camera: the edge light that gives a
	## soft surface its nap and a clay one its wax.
	_rim = DirectionalLight3D.new()
	_rim.rotation_degrees = Vector3(-58.0, 176.0, 0.0)
	_viewport.add_child(_rim)
	_actor = ACTOR_SCENE.instantiate()
	_viewport.add_child(_actor)
	(_actor.get_node("Shadow") as Node3D).visible = false
	(_actor.get_node("FocusRing") as Node3D).visible = false
	(_actor.get_node("IdentityLabel") as Node3D).visible = false
	_actor.configure(90210, true, "Feli", "Right", TEMPLATE)


## A fresh actor for every treatment.
##
## The tool used to reuse one actor and call `configure` again whenever the joint
## settings changed, which produced a defect worth recording: the face marks
## appeared **doubled** on alternate treatments, as four small spikes off the
## side of the skull. They were read as something the joints had added, and they
## were not -- `probe_head_extras` shows the joints attach only to arm and leg
## bones and leave the head-adjacent parts identical.
##
## `_build_cosmetics` clears the previous cosmetics with `queue_free`, which is
## deferred. On alternate rebuilds the old `Tabby1..3` were still in the tree
## when the frame was captured, so two copies of each face mark drew a fraction
## apart. Measuring one 70x160 box of skull across the drafts gave exactly two
## values, 3,098 and 3,523 opaque pixels, alternating with every rebuild and
## uncorrelated with the joint radius -- which is what an on/off artefact looks
## like and what a real feature never does.
##
## Building a new actor per treatment removes the shared state rather than
## papering over it with more settle frames, whose sufficiency would be a guess.
func _rebuild_actor(setup: Dictionary) -> void:
	BodyTypes.draw_garments = bool(setup.get("garments", false))
	if _actor != null:
		_viewport.remove_child(_actor)
		_actor.free()
	_actor = ACTOR_SCENE.instantiate()
	_viewport.add_child(_actor)
	(_actor.get_node("Shadow") as Node3D).visible = false
	(_actor.get_node("FocusRing") as Node3D).visible = false
	(_actor.get_node("IdentityLabel") as Node3D).visible = false
	_actor.configure(90210, true, "Feli", "Right", TEMPLATE)
	await process_frame


func _apply_treatment(setup: Dictionary) -> void:
	_environment.ambient_light_color = setup.ambient
	_environment.ambient_light_energy = float(setup.ambient_energy)
	_key.light_color = setup.key
	_key.light_energy = float(setup.key_energy)
	_fill.light_color = setup.fill
	_fill.light_energy = float(setup.fill_energy)
	_rim.light_energy = float(setup.rim_energy)
	_rim.visible = float(setup.rim_energy) > 0.0
	_set_ink_visible(_actor, bool(setup.ink))
	_set_roughness(_actor, float(setup.get("roughness", AUTHORED_ROUGHNESS)))
	## Presentation-only and reversible, which is what a draft wants: the shell is
	## hidden rather than removed, so nothing about how it is built has to be
	## decided before it has been looked at without it.
	var shell := _actor.get_node_or_null("BodyPivot/Shorts") as MeshInstance3D
	if shell != null:
		shell.visible = not bool(setup.get("hide_shorts", false))
## The actor builds one `Ink` child per outlined mesh, so turning the per-part
## outline off is a walk rather than a flag.
func _set_ink_visible(node: Node, visible_ink: bool) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and str(child.name) == "Ink":
			(child as MeshInstance3D).visible = visible_ink
		_set_ink_visible(child, visible_ink)


## Retune every body material's roughness in place. Ink hulls are skipped: they
## are unshaded by construction and a roughness on them would be a claim this
## tool cannot support.
func _set_roughness(node: Node, roughness: float) -> void:
	for child in node.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and str(mesh.name) != "Ink":
			var material := mesh.material_override as StandardMaterial3D
			if material != null:
				material.roughness = roughness
		_set_roughness(child, roughness)


func _shot(treatment: String, view: String, framing: Dictionary) -> void:
	_actor.rotation_degrees = Vector3(0.0, float(framing.yaw), 0.0)
	var focus := Vector3(0.0, float(framing.focus), 0.0)
	_camera.size = float(framing.size)
	if bool(framing.get("under", false)):
		_camera.position = focus + Vector3(0.0, -4.2, 0.0)
		## Looking straight up, so world up is degenerate as a reference; the
		## court's own forward axis stands in for it.
		_camera.look_at(focus, Vector3.FORWARD)
	else:
		_camera.position = focus + Vector3(0.0, 0.0, -4.2)
		_camera.look_at(focus, Vector3.UP)
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
		push_error("Blank render %s %s" % [treatment, view])
		quit(1)
		return
	image.save_png("%s/%s_%s.png" % [OUTPUT_DIR, treatment, view])
	print("%s %s  opaque=%d" % [treatment, view, opaque])
