extends SceneTree

## Every regional strip on one body.
##
## One voli throughout -- the same Feli the style drafts use -- so the only thing
## changing between tiles is the club. That is the point of the sheet: `KITS` is
## fourteen dark colours chosen against the court's albedo, and `BUILD` gives
## nine of them a distinct construction, but until the construction marks were
## put on the outside of the shirt the whole second table rendered nothing. This
## is the first look at what the regions actually wear.
##
## Front and back, because half the marks are on the back by construction --
## `RegionalKits.marks_for` mirrors every front mark -- and a sheet of fronts
## would show half the design.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")
const RegionalKitsScript := preload("res://scripts/data/regional_kits.gd")

const OUTPUT_DIR := "res://artifacts/all-kits"
const VIEWS := {"front": 0.0, "back": 180.0}
const PROPORTIONS := [
	{"slug": "vegi-stalk", "body_type": "Vegi", "height_cm": 188.0,
		"wingspan_cm": 188.0, "mass_kg": 82.0,
		"appearance": {"produce": "Stalk", "marking": "none"}},
	{"slug": "feli-standard", "body_type": "Feli", "height_cm": 188.0,
		"wingspan_cm": 191.0, "mass_kg": 82.0},
	{"slug": "avi-tall", "body_type": "Avi", "height_cm": 204.0,
		"wingspan_cm": 212.0, "mass_kg": 70.0},
	{"slug": "cani-short", "body_type": "Cani", "height_cm": 171.0,
		"wingspan_cm": 168.0, "mass_kg": 74.0},
	{"slug": "ursi-heavy", "body_type": "Ursi", "height_cm": 196.0,
		"wingspan_cm": 201.0, "mass_kg": 112.0},
	{"slug": "simi-reach", "body_type": "Simi", "height_cm": 183.0,
		"wingspan_cm": 218.0, "mass_kg": 78.0},
]

## Somebody has to have won for Zaitgaist to have anything to copy. Xérvu
## because its rhythm is the least mistakable quote on the sheet.
const CHAMPION := "Xérvu"

var _viewport: SubViewport
var _camera: Camera3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_stage()
	print("%-16s %-12s %-8s %s" % ["region", "pattern", "kit", "marks"])
	for region_raw in RegionalKitsScript.KITS:
		var region: String = str(region_raw)
		var slug := region.to_lower().replace(" ", "-")
		## All three authored passes, on the same reference body and camera.
		for attempt in range(3):
			await _shot(
				region, "iterations/%s_attempt-%d" % [slug, attempt + 1],
				0.0, attempt, PROPORTIONS[1]
			)
		for view_raw in VIEWS:
			var view: String = str(view_raw)
			await _shot(
				region, "%s_%s" % [slug, view], float(VIEWS[view]), -1,
				PROPORTIONS[1]
			)
		## The selected design on every body family, including a Stalk Vegi whose
		## produce torso must remain unpainted while its real garments carry marks.
		for profile_raw in PROPORTIONS:
			var profile: Dictionary = profile_raw
			await _shot(
				region, "proportions/%s_%s" % [slug, str(profile.slug)],
				0.0, -1, profile
			)
		print("%-16s %-12s %-8s %d" % [
			region, RegionalKitsScript.pattern_for(region, CHAMPION),
			Color(RegionalKitsScript.KITS[region]).to_html(false),
			RegionalKitsScript.marks_for(region, CHAMPION).size(),
		])
	quit()


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(560, 560)
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
	## The draft-6 light: warm wrap, cool fill, a rim for the edge.
	environment.ambient_light_color = Color("efe4d6")
	environment.ambient_light_energy = 0.54
	world.environment = environment
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_viewport.add_child(_camera)
	_camera.current = true
	for lamp in [
		[Vector3(-38.0, -34.0, 0.0), Color("fff6e8"), 0.92],
		[Vector3(-14.0, 128.0, 0.0), Color("c4b9c8"), 0.44],
		[Vector3(-58.0, 176.0, 0.0), Color("ffffff"), 0.62],
	]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = lamp[0]
		light.light_color = lamp[1]
		light.light_energy = lamp[2]
		_viewport.add_child(light)


func _shot(
	region: String, output_name: String, yaw: float, attempt: int,
	proportion: Dictionary
) -> void:
	## A fresh actor per tile. The style tool learned this the hard way: reusing
	## one and reconfiguring it left the previous cosmetics alive for a frame, so
	## alternate tiles rendered doubled face marks.
	var actor := ACTOR_SCENE.instantiate()
	_viewport.add_child(actor)
	(actor.get_node("Shadow") as Node3D).visible = false
	(actor.get_node("FocusRing") as Node3D).visible = false
	(actor.get_node("IdentityLabel") as Node3D).visible = false
	var profile := proportion.duplicate(true)
	profile.merge({
		"club_region": region,
		"champion_region": CHAMPION,
		"kit_design_attempt": attempt,
	}, true)
	if not profile.has("appearance"):
		profile["appearance"] = {
			"palette_index": 0, "marking": "none",
			"ears": "tall", "muzzle": "standard", "build": "heavy",
		}
	actor.configure(90210, true, str(profile.body_type), "Right", profile)
	actor.rotation_degrees = Vector3(0.0, yaw, 0.0)
	var rig := float(actor.silhouette.get("rig_height", 2.0))
	var focus := Vector3(0.0, rig * 0.52, 0.0)
	_camera.size = rig * 1.24
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
		push_error("Blank render %s %s" % [region, output_name])
		quit(1)
		return
	var output_path := "%s/%s.png" % [OUTPUT_DIR, output_name]
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(output_path.get_base_dir())
	)
	image.save_png(output_path)
	_viewport.remove_child(actor)
	actor.free()
