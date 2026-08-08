extends Node

## A contact sheet of the spike, one cell per frame.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/spike_strip.tscn
##
## and it writes `user://spike_sheet.png`.
##
## The swing is a pure function of phase, so it can be laid out as a strip:
## sample the phase, bake each sample, tile them. That is the only honest way to
## look at an animation whose whole claim is that the joints are *staggered* --
## the legs before the trunk, the trunk before the shoulder, the elbow last. A
## single frame cannot show an ordering.
##
## Baked through `UIVoliSticker` rather than a hand-rolled rig, because that is
## the path the tactic sheet actually uses: what this shows is what gets drawn.

const StickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SpikeBiomechanics := preload("res://scripts/data/spike_biomechanics.gd")

const CELL := Vector2i(190, 260)
const COLUMNS: int = 7
## Two angles, because the swing is not in one plane.
##
## Side on is where the sequence lives -- the arch, the high elbow, the extension
## -- and it is blind to exactly the axis that was missing from the model for a
## long time: the arm going *out* as well as back. From behind, abduction is all
## you can see and the sagittal ordering is all you cannot. Neither view is
## sufficient and the pair is, which is the same argument the tactic sheet makes
## for having three.
const ANGLES: Array[Vector2] = [Vector2(90.0, -6.0), Vector2(180.0, -8.0)]
const PHASES: Array[float] = [
	-1.00, -0.78, -0.62, -0.48, -0.34, -0.20, -0.14,
	-0.06, 0.00, 0.12, 0.28, 0.45, 0.70, 1.00,
]
const PROFILE := {
	"height_cm": 196.0, "wingspan_cm": 203.0, "stride_length_m": 0.90,
	"body_type": "Cani", "dominant_hand": "Right",
	"standing_reach_meters": 2.56, "jumping_reach_meters": 3.34,
}

func _ready() -> void:
	_run()


func _run() -> void:
	var baker: UIVoliSticker = StickerScript.new()
	add_child(baker)
	baker.light_mode = true
	for angle in range(ANGLES.size()):
		for index in range(PHASES.size()):
			var phase: float = PHASES[index]
			## Elevation follows the jump the phase is in, so the strip shows a
			## hitter leaving the floor and landing rather than hovering throughout.
			## The rise starts at the plant and the fall ends past the
			## follow-through, the same window the swing is sequenced over.
			var lift := 0.0
			if phase > SpikeBiomechanics.PLANT_END:
				lift = clampf(
					sin((phase - SpikeBiomechanics.PLANT_END) / 1.62 * PI), 0.0, 1.0
				)
			baker.request(
				"f%d%02d" % [angle, index], RallyEventModel.EventType.ATTACK,
				lift, phase, PROFILE, ANGLES[angle].x, ANGLES[angle].y
			)
	while baker._working or not baker._queue.is_empty():
		await get_tree().process_frame
	for _i in range(4):
		await get_tree().process_frame

	var per_angle := int(ceil(float(PHASES.size()) / float(COLUMNS)))
	var rows := per_angle * ANGLES.size()
	var sheet := Image.create(
		CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.96, 0.96, 0.94, 1.0))
	for slot in range(PHASES.size() * ANGLES.size()):
		var angle := slot / PHASES.size()
		var index := slot % PHASES.size()
		var phase: float = PHASES[index]
		var lift := 0.0
		if phase > SpikeBiomechanics.PLANT_END:
			lift = clampf(
				sin((phase - SpikeBiomechanics.PLANT_END) / 1.62 * PI), 0.0, 1.0
			)
		var built: UIVoliSticker.Sticker = baker.sticker("f%d%02d" % [angle, index])
		if built == null or built.texture == null:
			print("frame %2d MISSING" % index)
			continue
		var body := built.texture.get_image()
		body.convert(Image.FORMAT_RGBA8)
		## Every cell at the same pixels-per-metre, so the strip is a measurement
		## and not fourteen differently-scaled drawings. A crouched plant and a
		## fully extended contact are different heights and must look it.
		## One scale for every cell, and every cell standing on the same floor.
		##
		## Bottom-aligning each frame hid the whole jump: a hitter at full
		## extension and a hitter crouched on the plant are the same height in the
		## cell, and the strip read as fourteen people standing still. The bake
		## already knows where the floor is -- `ground_offset` is how far the crop's
		## bottom sits below the voli's own ground point -- so the ground line is
		## drawn once per cell and everything hangs off it.
		var per_metre := float(CELL.y) * 0.92 / 3.9
		var tall := int(built.world_height * per_metre)
		var wide := int(float(tall) * built.aspect)
		if tall < 4 or wide < 4:
			continue
		body.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
		var column := index % COLUMNS
		var row := angle * per_angle + index / COLUMNS
		var ground := CELL.y * row + CELL.y - 18
		sheet.blend_rect(
			body, Rect2i(Vector2i.ZERO, Vector2i(wide, tall)),
			Vector2i(
				CELL.x * column + (CELL.x - wide) / 2,
				ground + int(built.ground_offset * per_metre) - tall
			)
		)
		## The floor, so the rise is measurable rather than felt.
		for x in range(CELL.x * column + 6, CELL.x * column + CELL.x - 6):
			sheet.set_pixel(x, ground, Color(0.62, 0.60, 0.56, 1.0))
		print("yaw %3.0f frame %2d  phase %+.2f  %-14s lift %.2f  %.2f m tall" % [
			ANGLES[angle].x, index, phase,
			str(SpikeBiomechanics.resolve(phase, 1.0).phase_name),
			lift, built.world_height,
		])
	print("save err=%d" % sheet.save_png("user://spike_sheet.png"))
	get_tree().quit()
