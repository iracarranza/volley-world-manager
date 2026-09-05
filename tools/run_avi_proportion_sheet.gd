extends Node

## One Avi, six builds, three angles.
##
## Height is held fixed and the three proportion axes the rig actually draws are
## taken to their ends: mass, wingspan and stride. A facing view flatters all
## three -- a heavier torso and a longer arm both read as "wider" from the front
## and separate only once the body turns -- so every build is shot facing, at
## three-quarters and in profile.
##
## Run:
##   xvfb-run -a godot --path . res://tools/avi_proportion_sheet.tscn

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const Stage := preload("res://tools/preview/voli_sheet_stage.gd")

const BODY := "Avi"
const HEIGHT_CM := 188.0

## The ends of the ranges that already exist, never a magnitude invented here.
##
## Mass and wingspan are `player_generator.gd`'s own clamps -- 50 to 130 kg and
## 150 to 235 cm -- so both columns are a build the world really generates.
## Stride has no such pair to borrow: the generator never varies it from
## `default_stride_length_m`, which is height * 0.43 exactly. Its ends are
## therefore the ends of `leg_length_scale`'s own clamp, 0.86 and 1.16, which is
## the range the *drawing* admits rather than one the population fills.
const REFERENCE_MASS_KG := 82.0
const REFERENCE_STRIDE_M := HEIGHT_CM / 100.0 * 0.43

const VARIANTS: Array = [
	["reference", {}],
	["mass 50", {"mass_kg": 50.0}],
	["mass 130", {"mass_kg": 130.0}],
	["span 150", {"wingspan_cm": 150.0}],
	["span 235", {"wingspan_cm": 235.0}],
	["stride 0.70", {"stride_length_m": REFERENCE_STRIDE_M * 0.86}],
	["stride 0.94", {"stride_length_m": REFERENCE_STRIDE_M * 1.16}],
]

## Facing, three-quarter, profile. The rig faces the camera at zero.
const ANGLES: Array = [
	["facing", 0.0], ["three-quarter", 45.0], ["profile", 90.0],
]

const SPACING := 1.62
const ROW_RISE := 2.75


func _ready() -> void:
	get_window().size = Stage.RESOLUTION
	await get_tree().process_frame
	var root := get_tree().root
	var stage := Stage.build_stage(root)

	var rows := ANGLES.size()
	var start := -SPACING * float(VARIANTS.size() - 1) * 0.5
	for row in range(rows):
		var angle: Array = ANGLES[row]
		for column in range(VARIANTS.size()):
			var variant: Array = VARIANTS[column]
			var profile: Dictionary = {
				"height_cm": HEIGHT_CM, "body_type": BODY,
				## One colourway and one bare coat across the whole sheet. The
				## first run passed a different id per column, which hashes a
				## different palette per column -- so seven builds arrived in
				## seven colours and the eye read the colour. A proportion sheet
				## must vary proportion and nothing else.
				"appearance": {"palette_index": 0, "marking": "none"},
			}
			profile.merge(Dictionary(variant[1]))
			var actor: Node3D = ACTOR.instantiate()
			stage.add_child(actor)
			actor.configure(1, true, BODY, "Right", profile)
			actor.set_tactical_position(
				Vector2.ZERO,
				Vector3(
					-start - SPACING * float(column),
					ROW_RISE * float(rows - 1 - row),
					0.0,
				),
			)
			actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
			## Turned after posing. Nothing re-poses on a later frame -- the rig
			## has no `_process` -- so a yaw written here is the one that renders.
			actor.rotation.y = deg_to_rad(float(angle[1]))
			## Only the top row names the build and only the first column names
			## the angle, because a caption over all twenty-one cells is three
			## copies of the same seven words.
			var caption := ""
			if row == 0:
				caption = str(variant[0])
			elif column == 0:
				caption = str(angle[0])
			Stage.present(actor, caption)
			if row > 0:
				## Angle names sit under their own row's feet. Above the head is
				## where the build names live, and a row label placed there lands
				## in the shins of the row above -- the rows are 2.75 m apart and
				## a body is 2.2 m of that.
				actor.identity_label.position.y = -0.32
			if row == 0:
				_report(str(variant[0]), actor)

	for _frame in range(8):
		await get_tree().process_frame
	Stage.frame_camera(
		root, stage,
		SPACING * float(VARIANTS.size() - 1) + 2.2,
		ROW_RISE * float(rows - 1) + 3.6,
		1.15 + ROW_RISE * float(rows - 1) * 0.5,
	)
	for _frame in range(4):
		await get_tree().process_frame
	Stage.save(root, "avi_proportion_sheet")
	get_tree().quit()


## The scales the rig resolved, so the sheet says what each column actually did
## rather than what it asked for. The two are not the same wherever a clamp
## bites, and which of these clamp is the point of printing it.
func _report(label: String, actor: Node3D) -> void:
	if label == "reference":
		print("variant | mass kg | torso girth | arm scale | leg scale")
	## Torso girth is `mass_girth`, which is a local -- read back off the mesh it
	## was written to, because what the sheet shows is the scale that landed.
	print("%s | %.0f | %.3f | %.3f | %.3f" % [
		label, float(actor.mass_kg), float(actor.torso.scale.x),
		float(actor.arm_length_scale), float(actor.leg_length_scale),
	])
