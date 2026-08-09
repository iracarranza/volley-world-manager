extends Node

## Two strips about the tactic sheet's figures: which way they are turned, and
## how their edge is drawn.
##
## Both questions were being asked through the training screen, which is a page
## of chrome around one component and about five minutes of render for a single
## frame. Neither question is about the screen. So this stands the worksheet up
## on its own and bakes what it needs.
##
##     xvfb-run -a godot --path . res://tools/preview/sheet_strip.tscn -- turntable
##     xvfb-run -a godot --path . res://tools/preview/sheet_strip.tscn -- diecut
##
## With no argument it does both.
##
## **turntable** answers the facing bug the only way a sign can honestly be
## answered -- by measuring it. One blocker, one pose, the whole way round in 45
## degree steps, so which yaw shows a back and which shows a chest is something
## you read off the sheet rather than derive from a comment. `_bake_angles` is
## then a lookup into that row instead of an argument.
##
## **diecut** is the A/B the strip was asked for: the same worksheet drawn three
## ways, with the cut border on at the current ink weight and off at two heavier
## ones. This one has to go through `UIWorksheet` and not the baker, because the
## die cut is not in the sticker -- it is a polyline the sheet draws around the
## sticker's contour, so a bake alone cannot show it.

const WorksheetScript := preload("res://scenes/components/worksheet.gd")
const StickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const ActorScript := preload("res://scenes/components/player_actor_3d.gd")

const CELL := Vector2i(190, 300)
const TURNTABLE_METRES: float = 3.6

## The blocker the sheet already draws, so the turntable is the same body the
## bug was reported against rather than a stand-in.
const PROFILE := {
	"key": "tall", "height_cm": 201.0, "wingspan_cm": 209.0,
	"stride_length_m": 0.93, "body_type": "Vegi", "dominant_hand": "Right",
	"standing_reach_meters": 2.62, "jumping_reach_meters": 3.42,
}

## One row per pose, because a block and a platform are turned by the same
## formula and fail differently: a block is near enough symmetric front to back
## that only the face gives it away, while a passer's platform is unmistakably
## in front of them.
const TURNTABLE_ROWS := [
	{
		"name": "block", "event": RallyEventModel.EventType.BLOCK,
		"elevation": 0.85, "phase": 0.0, "pitch": -14.0,
	},
	{
		"name": "floor", "event": RallyEventModel.EventType.DEFENSE,
		"elevation": 0.0, "phase": -0.08, "pitch": -14.0,
	},
]

const YAWS := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

## Cut on at the weight the sheet ships, then off at two heavier inks. The crown
## keeps its ratio to the body line (0.030 against 0.018) in every variant, so
## what changes between cells is one number and not two.
const DIE_CUT_VARIANTS := [
	{"name": "cut on, ink 0.018", "cut": true, "ink": 0.018},
	{"name": "cut off, ink 0.034", "cut": false, "ink": 0.034},
	{"name": "cut off, ink 0.048", "cut": false, "ink": 0.048},
]
const CROWN_INK_RATIO: float = 0.030 / 0.018


func _ready() -> void:
	var wanted: Array[String] = []
	for argument in OS.get_cmdline_user_args():
		if argument in ["turntable", "diecut", "views"]:
			wanted.append(str(argument))
	if wanted.is_empty():
		wanted = ["turntable", "diecut", "views"]
	for job in wanted:
		match job:
			"turntable":
				await _turntable()
			"diecut":
				await _die_cut()
			_:
				await _views()
	get_tree().quit()


## The same phase from every angle the sheet can be looked at.
##
## The facing is one formula shared by all three views, so a fix that is right at
## three quarter and wrong along the net is a fix that has not been checked. The
## plan view is in here too even though it bakes a headshot rather than a body:
## a face is the one figure whose facing cannot be wrong, and having it in the
## strip is what makes that obvious rather than assumed.
func _views() -> void:
	var viewport := get_viewport()
	var frame := viewport.get_visible_rect().size
	var shots: Array[Image] = []
	var sheet: UIWorksheet = WorksheetScript.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	await _settled(sheet)
	for for_view: String in WorksheetScript.VIEWS:
		sheet.set_view(for_view)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shots.append(shot)
		print("view %-14s captured" % for_view)
	sheet.queue_free()
	var strip := Image.create(
		int(frame.x), int(frame.y) * shots.size(), false, Image.FORMAT_RGBA8
	)
	for index in range(shots.size()):
		strip.blit_rect(
			shots[index], Rect2i(Vector2i.ZERO, shots[index].get_size()),
			Vector2i(0, int(frame.y) * index)
		)
	print("views save err=%d" % strip.save_png("user://views_strip.png"))


## Every yaw the bake can be asked for, in one row per pose.
func _turntable() -> void:
	var baker: UIVoliSticker = StickerScript.new()
	add_child(baker)
	baker.light_mode = true
	baker._ensure_rig()

	var sheet := Image.create(
		CELL.x * YAWS.size(), CELL.y * TURNTABLE_ROWS.size(), false,
		Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.96, 0.96, 0.94, 1.0))
	var per_metre := float(CELL.y) * 0.92 / TURNTABLE_METRES

	print("--- turntable: yaw is the actor's rotation about Y ---")
	for row in range(TURNTABLE_ROWS.size()):
		var pose: Dictionary = TURNTABLE_ROWS[row]
		for column in range(YAWS.size()):
			var yaw: float = YAWS[column]
			var key := "t%d_%d" % [row, column]
			baker.request(
				key, int(pose["event"]), float(pose["elevation"]),
				float(pose["phase"]), PROFILE, yaw, float(pose["pitch"])
			)
			while baker._working or not baker._queue.is_empty():
				await get_tree().process_frame
			var built: UIVoliSticker.Sticker = baker.sticker(key)
			if built == null or built.texture == null:
				print("%s MISSING" % key)
				continue
			_place(sheet, built, row, column, per_metre)
			print("r%d %-6s column %d  yaw %3.0f" % [
				row, str(pose["name"]), column, yaw,
			])
	print("turntable save err=%d" % sheet.save_png("user://turntable_strip.png"))
	baker.queue_free()


func _place(
	sheet: Image, built: UIVoliSticker.Sticker, row: int, column: int,
	per_metre: float
) -> void:
	var body := built.texture.get_image()
	body.convert(Image.FORMAT_RGBA8)
	var tall := int(built.world_height * per_metre)
	var wide := int(float(tall) * built.aspect)
	if tall < 4 or wide < 4:
		return
	body.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
	## One floor line per row, with the figure hung off it, so a pose that sits
	## lower reads as lower rather than as smaller.
	var ground := CELL.y * row + CELL.y - 20
	sheet.blend_rect(
		body, Rect2i(Vector2i.ZERO, Vector2i(wide, tall)),
		Vector2i(
			CELL.x * column + (CELL.x - wide) / 2,
			ground + int(built.ground_offset * per_metre) - tall
		)
	)
	for x in range(CELL.x * column + 6, CELL.x * column + CELL.x - 6):
		sheet.set_pixel(x, ground, Color(0.62, 0.60, 0.56, 1.0))
	## A tick at the left of every cell in the top row marks column zero of the
	## pair, so the strip can be read without counting from the edge.
	if column % 2 == 0:
		for y in range(CELL.y * row + 6, CELL.y * row + 18):
			sheet.set_pixel(CELL.x * column + 6, y, Color(0.62, 0.60, 0.56, 1.0))


## The same worksheet, drawn once per edge treatment, stacked.
##
## Captured off the window rather than a `SubViewport` because the worksheet
## paints itself from the palette on its own ancestry, and a detached viewport
## is not on anybody's ancestry.
## Wait for a freshly added worksheet to have every figure it asked for.
##
## The bake is queued from the worksheet's own `_ready`, so this can only start
## after the add -- and it has to finish before the capture, because a sheet
## drawn early is a court with nobody on it, which is a picture that looks fine
## and shows nothing.
func _settled(sheet: UIWorksheet) -> void:
	var baker := sheet.stickers()
	var spent := 0
	while baker != null and (baker._working or not baker._queue.is_empty()):
		await get_tree().process_frame
		spent += 1
		if spent > 2000:
			print("bake did not settle")
			break
	sheet.queue_redraw()
	await get_tree().process_frame


func _die_cut() -> void:
	var viewport := get_viewport()
	var frame := viewport.get_visible_rect().size
	var shots: Array[Image] = []

	for variant: Dictionary in DIE_CUT_VARIANTS:
		WorksheetScript.draw_die_cut = bool(variant["cut"])
		ActorScript.ink_metres = float(variant["ink"])
		ActorScript.crown_ink_metres = float(variant["ink"]) * CROWN_INK_RATIO

		var sheet: UIWorksheet = WorksheetScript.new()
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(sheet)
		await _settled(sheet)
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shots.append(shot)
		print("%-18s captured %dx%d" % [
			variant["name"], shot.get_width(), shot.get_height()
		])
		sheet.queue_free()
		await get_tree().process_frame

	if shots.is_empty():
		return
	var strip := Image.create(
		int(frame.x), int(frame.y) * shots.size(), false, Image.FORMAT_RGBA8
	)
	strip.fill(Color(0.10, 0.10, 0.11, 1.0))
	for index in range(shots.size()):
		strip.blend_rect(
			shots[index], Rect2i(Vector2i.ZERO, shots[index].get_size()),
			Vector2i(0, int(frame.y) * index)
		)
	print("diecut save err=%d" % strip.save_png("user://diecut_strip.png"))
	_zoom(shots)
	## Left as the sheet ships it, so a tool that only looked at something does
	## not leave a static behind for whatever runs next in the same process.
	WorksheetScript.draw_die_cut = true
	ActorScript.ink_metres = 0.018
	ActorScript.crown_ink_metres = 0.030


## The blockers alone, side by side and four times up.
##
## The full sheet is the honest test of whether an edge treatment works -- a line
## weight is only right against the court it sits on -- but at sheet size the
## difference between two ink weights is a couple of pixels, and a couple of
## pixels stacked vertically a screen apart is not a comparison anybody can make.
## So the strip is both: the whole sheet to judge it in place, and this to see it.
const ZOOM_CROP := Rect2i(230, 110, 240, 220)
const ZOOM: int = 4


func _zoom(shots: Array[Image]) -> void:
	var cell := ZOOM_CROP.size * ZOOM
	var strip := Image.create(
		cell.x * shots.size(), cell.y, false, Image.FORMAT_RGBA8
	)
	for index in range(shots.size()):
		var crop := shots[index].get_region(ZOOM_CROP)
		## Nearest, deliberately. Any smoothing here would soften exactly the
		## thing being compared and make every variant look like the middle one.
		crop.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		strip.blit_rect(
			crop, Rect2i(Vector2i.ZERO, cell), Vector2i(cell.x * index, 0)
		)
	print("diecut zoom save err=%d" % strip.save_png("user://diecut_zoom.png"))
