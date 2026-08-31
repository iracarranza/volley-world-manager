extends Node3D

## All six bodies in kit, front on, for judging the sleeve and the neckline.
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/garment_sheet.tscn -- --tag before
##
## `--tag` names the file, so the same harness renders both sides of a change and
## the two can be put next to each other. The measurement in
## `docs/review/GARMENT_INK_CLEARANCE.md` says the clearances are right; this
## says what they cost, which is a different question and not one a table answers.
##
## Two rows of three rather than six across, because a sleeve is a few dozen
## pixels at six-across and this exists to look at a sleeve.

const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const TYPES: Array[String] = ["Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi"]
const PER_ROW: int = 3


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.96, 0.95, 0.92)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.88, 0.91, 0.98)
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	add_child(environment)
	## One body filling the frame, when the subject is a seam rather than a set.
	var only := _argument("--only")
	only_one = not only.is_empty()
	## NOTE `[only] as Array[String]` does not convert -- it aborts `_ready`
	var types: Array[String] = []
	if only.is_empty():
		types.assign(TYPES)
	else:
		types.append(only)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	## `--size` and `--eye` frame a detail: the feet want a different window from
	## the shoulders and neither wants the whole sheet.
	var framed_size := _argument("--size")
	var framed_eye := _argument("--eye")
	camera.size = float(framed_size) if not framed_size.is_empty() \
		else (6.4 if only.is_empty() else 2.4)
	camera.position = Vector3(0.0, float(framed_eye) if not framed_eye.is_empty() \
		else (2.6 if only.is_empty() else 1.30), 6.0)
	## NOTE `look_at` needs the node in the tree; adding after it silently no-ops
	add_child(camera)
	camera.look_at(Vector3(0.0, camera.position.y, 0.0))

	for index in types.size():
		var actor := ActorScene.instantiate() as PlayerActor3D
		actor.flat_shading = true
		add_child(actor)
		actor.position = Vector3.ZERO if only_one else Vector3(
			float(index % PER_ROW) * 1.45 - 1.45,
			float(1 - index / PER_ROW) * 2.30,
			0.0,
		)
		## A club region so the kit is a real strip rather than the palette's
		## stand-in teal -- the sleeve is the subject and it has to be the sleeve
		## a viewer will actually see.
		## `--garment formal` dresses the whole sheet as managers, and
		## `--libero` as liberos, so the three classes are one harness.
		var profile := {
			"height_cm": 186.0, "mass_kg": 82.0, "wingspan_cm": 191.0,
			"body_type": types[index], "club_region": "Landavol",
			"standing_reach_meters": 2.48, "jumping_reach_meters": 3.20,
		}
		var wear := _argument("--garment")
		if not wear.is_empty():
			profile["garment"] = wear
		if "--libero" in OS.get_cmdline_user_args():
			profile["position_role"] = "Libero"
		actor.configure(5 + index, true, types[index], "Right", profile)
		## Standing, not digging: a bent arm hides the cuff behind the forearm.
		actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
		## `--side` turns the body ninety degrees, which is the only view that can
		## show whether a foot is pitched forward or back.
		actor.rotation_degrees = Vector3(
			0.0, 90.0 if "--side" in OS.get_cmdline_user_args() else 180.0, 0.0
		)


var only_one: bool = false
var _frame: int = 0


## One flagged value from the command line, or empty.
func _argument(flag: String) -> String:
	var args := OS.get_cmdline_user_args()
	var marker := args.find(flag)
	return str(args[marker + 1]) if marker >= 0 and marker + 1 < args.size() else ""


func _process(_delta: float) -> void:
	_frame += 1
	if _frame != 14:
		return
	var tag := _argument("--tag")
	if tag.is_empty():
		tag = "sheet"
	var path := "user://garment_%s.png" % tag
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	get_tree().quit()
