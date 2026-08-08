extends Node

## The four dig postures, from two angles, on one ground line.
##
## The companion to `spike_strip`, and it exists for the same reason: a passing
## platform is a *shape the whole body makes* -- knees, hips, trunk and both arms
## together -- and no single number describes it. Side on shows whether the
## platform is actually below the waist and out in front; three quarter shows
## whether any of that survives the angle the tactic sheet looks from.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/receive_strip.tscn
##
## and it writes `user://receive_sheet.png`.

const StickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")

const CELL := Vector2i(210, 300)
const POSTURES: Array[String] = ["planted", "moving", "reaching", "off-axis"]
## Side on, then the angle the three-quarter view of the sheet bakes at.
const ANGLES: Array[Vector2] = [Vector2(90.0, -6.0), Vector2(142.0, -26.0)]
const PROFILE := {
	"height_cm": 190.0, "wingspan_cm": 196.0, "stride_length_m": 0.86,
	"body_type": "Cani", "dominant_hand": "Right",
	"standing_reach_meters": 2.48, "jumping_reach_meters": 3.20,
}


func _ready() -> void:
	_run()


func _run() -> void:
	var baker: UIVoliSticker = StickerScript.new()
	add_child(baker)
	baker.light_mode = true
	## `contact_posture` is set on the actor rather than passed through `request`,
	## so the rig has to be reached into between bakes. Queued one at a time for
	## that reason -- the baker shares one actor, and a posture set for the next
	## job would land on the one still rendering.
	var sheet := Image.create(
		CELL.x * POSTURES.size(), CELL.y * ANGLES.size(), false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.96, 0.96, 0.94, 1.0))
	## The rig has to exist before its posture can be set, and `_ensure_rig` is
	## what builds it -- `request` alone only queues.
	baker._ensure_rig()
	for row in range(ANGLES.size()):
		for column in range(POSTURES.size()):
			var key := "r%d%d" % [row, column]
			baker._actor.contact_posture = POSTURES[column]
			baker.request(
				key, RallyEventModel.EventType.DEFENSE, 0.0, -0.08,
				PROFILE, ANGLES[row].x, ANGLES[row].y
			)
			while baker._working or not baker._queue.is_empty():
				await get_tree().process_frame
			var built: UIVoliSticker.Sticker = baker.sticker(key)
			if built == null or built.texture == null:
				print("%s / %s MISSING" % [POSTURES[column], ANGLES[row]])
				continue
			var body := built.texture.get_image()
			body.convert(Image.FORMAT_RGBA8)
			var per_metre := float(CELL.y) * 0.66 / 2.2
			var tall := int(built.world_height * per_metre)
			var wide := int(float(tall) * built.aspect)
			if tall < 4 or wide < 4:
				continue
			body.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
			var ground := CELL.y * row + CELL.y - 60
			sheet.blend_rect(
				body, Rect2i(Vector2i.ZERO, Vector2i(wide, tall)),
				Vector2i(
					CELL.x * column + (CELL.x - wide) / 2,
					ground + int(built.ground_offset * per_metre) - tall
				)
			)
			for x in range(CELL.x * column + 6, CELL.x * column + CELL.x - 6):
				sheet.set_pixel(x, ground, Color(0.62, 0.60, 0.56, 1.0))
			print("%-9s yaw %5.0f  %.2f m tall" % [
				POSTURES[column], ANGLES[row].x, built.world_height
			])
	print("save err=%d" % sheet.save_png("user://receive_sheet.png"))
	get_tree().quit()
