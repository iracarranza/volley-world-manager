extends Node

## Any contact, frame by frame, as a contact sheet.
##
## Replaces `spike_strip` and `receive_strip`, which were the same tool twice
## with a different table of phases at the top. There are five contacts and every
## one of them is a *sequence* whose whole claim is an ordering -- the legs before
## the trunk, the trunk before the shoulder, the elbow last; the platform set
## before the legs drive; the hands opening only after the ball has gone -- and a
## single frame cannot show an ordering. So each one gets a strip, and they get
## the same strip.
##
## Baked through `UIVoliSticker` rather than a hand-rolled rig, because that is
## the path the tactic sheet actually uses: what this shows is what gets drawn.
##
## Run it:
##
##     xvfb-run -a godot --path . res://tools/preview/contact_strip.tscn -- serve
##
## and it writes `user://serve_sheet.png`. With no argument it does all five.
##
## **Two angles for every action, and never one.** Each of these poses has an axis
## it is blind to from the obvious camera: a swing's abduction does not exist side
## on, a passing platform is edge-on from behind, a block's seal is invisible from
## the side. The pair is the minimum that can catch a pose being wrong, and this
## tool spent its first version baking the spike side-on only -- which is exactly
## the view the missing axis does not appear in.

const StickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SpikeBiomechanics := preload("res://scripts/data/spike_biomechanics.gd")
const BlockBiomechanics := preload("res://scripts/data/block_biomechanics.gd")

const CELL := Vector2i(196, 280)
const COLUMNS: int = 7
const PROFILE := {
	"height_cm": 194.0, "wingspan_cm": 201.0, "stride_length_m": 0.88,
	"body_type": "Cani", "standing_reach_meters": 2.54,
	"jumping_reach_meters": 3.30,
}

## What each action is worth looking at, and from where.
##
## `metres` is how much vertical world the cell has to hold -- a jumping action
## needs nearly four, a standing one barely two -- and it is what keeps every cell
## in a sheet at one pixels-per-metre. Bottom-aligning each frame instead would
## hide the very thing a jump strip exists to show.
const ACTIONS := {
	"serve": {
		"event": RallyEventModel.EventType.SERVE,
		## Side on, then from behind: the sweep lives in the first and the roll
		## that carries the elbow off the ribs lives only in the second.
		"angles": [Vector2(90.0, -6.0), Vector2(180.0, -8.0)],
		"phases": [
			-1.00, -0.82, -0.66, -0.50, -0.34, -0.22, -0.12,
			-0.04, 0.00, 0.10, 0.22, 0.40, 0.62, 0.90,
		],
		"metres": 2.9,
	},
	"set": {
		"event": RallyEventModel.EventType.SET,
		## Side on for the dip and the rise, three-quarter for the hands.
		"angles": [Vector2(90.0, -6.0), Vector2(142.0, -20.0)],
		"phases": [
			-0.80, -0.56, -0.34, -0.16, -0.06, 0.00, 0.08,
			0.18, 0.30, 0.44, 0.62, 0.88,
		],
		"metres": 2.6,
	},
	"block": {
		"event": RallyEventModel.EventType.BLOCK,
		## Face on is how a hitter sees a block and is the only view the seal
		## appears in; side on is the only view the penetration does.
		"angles": [Vector2(0.0, -8.0), Vector2(90.0, -6.0)],
		"phases": [
			-1.00, -0.72, -0.52, -0.40, -0.30, -0.18, -0.08,
			0.00, 0.14, 0.34, 0.52, 0.74, 0.90, 1.00,
		],
		"metres": 3.6,
	},
	"attack": {
		"event": RallyEventModel.EventType.ATTACK,
		"angles": [Vector2(90.0, -6.0), Vector2(180.0, -8.0)],
		"phases": [
			-1.00, -0.78, -0.62, -0.48, -0.34, -0.20, -0.14,
			-0.06, 0.00, 0.12, 0.28, 0.45, 0.70, 1.00,
		],
		"metres": 3.9,
	},
	"receive": {
		"event": RallyEventModel.EventType.DEFENSE,
		"angles": [Vector2(90.0, -6.0), Vector2(142.0, -26.0)],
		## The platform starts forming at -0.34 and is set by -0.08; the legs
		## drive from -0.14 and finish at +0.34, so the strip has to reach past the
		## ball to show a follow-through at all.
		"phases": [-0.40, -0.28, -0.18, -0.08, 0.00, 0.16, 0.36],
		"metres": 2.3,
		## The one action whose pose is chosen by the simulator rather than by the
		## phase, so it gets an extra row of all four at the moment they differ
		## most. `contact_posture` lives on the actor and is not part of `request`,
		## which is why these are queued one at a time further down.
		"postures": ["planted", "moving", "reaching", "off-axis"],
		"posture_phase": -0.08,
	},
}


func _ready() -> void:
	## Off: a strip of a pose that has just been edited must show the edit, and a
	## cached sticker is one cut before it.
	StickerScript.disk_cache = false
	var wanted: Array = []
	for argument in OS.get_cmdline_user_args():
		if ACTIONS.has(argument):
			wanted.append(argument)
	if wanted.is_empty():
		wanted = ACTIONS.keys()
	for action: String in wanted:
		await _sheet(action)
	get_tree().quit()


## How far off the floor this action is at this phase, 0 to 1.
##
## Read from the action's own model where there is one rather than invented here,
## so a strip cannot disagree with playback about when a voli left the ground.
func _lift(action: String, phase: float) -> float:
	match action:
		"attack":
			if phase <= SpikeBiomechanics.PLANT_END:
				return 0.0
			return clampf(
				sin((phase - SpikeBiomechanics.PLANT_END) / 1.62 * PI), 0.0, 1.0
			)
		"block":
			return BlockBiomechanics.new().elevation(phase)
	return 0.0


func _sheet(action: String) -> void:
	var spec: Dictionary = ACTIONS[action]
	var phases: Array = spec.phases
	var angles: Array = spec.angles
	var postures: Array = spec.get("postures", [])

	var baker: UIVoliSticker = StickerScript.new()
	add_child(baker)
	baker.light_mode = true
	baker._ensure_rig()

	## One job per cell: which row, which column, which posture, phase, angle.
	var jobs: Array = []
	var per_angle := int(ceil(float(phases.size()) / float(COLUMNS)))
	for angle in range(angles.size()):
		for index in range(phases.size()):
			jobs.append([
				angle * per_angle + index / COLUMNS, index % COLUMNS,
				"planted", float(phases[index]), angles[angle],
			])
	for index in range(postures.size()):
		jobs.append([
			per_angle * angles.size(), index, str(postures[index]),
			float(spec.get("posture_phase", 0.0)), angles[0],
		])

	var rows := per_angle * angles.size() + (1 if postures.size() > 0 else 0)
	var sheet := Image.create(
		CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0.96, 0.96, 0.94, 1.0))
	var per_metre := float(CELL.y) * 0.92 / float(spec.metres)

	print("--- %s ---" % action)
	for job: Array in jobs:
		var row: int = job[0]
		var column: int = job[1]
		var phase: float = job[3]
		var angle: Vector2 = job[4]
		var key := "c%d_%d" % [row, column]
		## Queued one at a time because the baker shares a single actor, so a
		## posture set for the next job would land on the one still rendering.
		baker._actor.contact_posture = str(job[2])
		baker.request(
			key, int(spec.event), _lift(action, phase), phase,
			PROFILE, angle.x, angle.y
		)
		while baker._working or not baker._queue.is_empty():
			await get_tree().process_frame
		var built: UIVoliSticker.Sticker = baker.sticker(key)
		if built == null or built.texture == null:
			print("%s MISSING" % key)
			continue
		var body := built.texture.get_image()
		body.convert(Image.FORMAT_RGBA8)
		var tall := int(built.world_height * per_metre)
		var wide := int(float(tall) * built.aspect)
		if tall < 4 or wide < 4:
			continue
		body.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
		## Every cell standing on the same floor, at the same pixels-per-metre.
		## `ground_offset` is how far the crop's bottom sits below the voli's own
		## ground point, so the line is drawn once and the figure hangs off it.
		var ground := CELL.y * row + CELL.y - 22
		sheet.blend_rect(
			body, Rect2i(Vector2i.ZERO, Vector2i(wide, tall)),
			Vector2i(
				CELL.x * column + (CELL.x - wide) / 2,
				ground + int(built.ground_offset * per_metre) - tall
			)
		)
		for x in range(CELL.x * column + 6, CELL.x * column + CELL.x - 6):
			sheet.set_pixel(x, ground, Color(0.62, 0.60, 0.56, 1.0))
		print("r%dc%d %-9s phase %+.2f yaw %4.0f lift %.2f  %.2f m" % [
			row, column, str(job[2]), phase, angle.x,
			_lift(action, phase), built.world_height,
		])
	print("%s save err=%d" % [
		action, sheet.save_png("user://%s_sheet.png" % action)
	])
	baker.queue_free()
