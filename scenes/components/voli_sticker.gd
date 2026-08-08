class_name UIVoliSticker
extends Node

## Bakes a posed voli into a **sticker**: a traced border, a shaded interior, and
## a shadow under it.
##
## The worksheet's figures were a circle and a few lines, which is the one thing
## on the clipboard that is a symbol rather than a likeness -- and the game
## already owns a posed 3D body carrying this voli's height, wingspan, body type
## and handedness. The spike recorded in `BACKLOG.md` measured the trace at 8-10
## ms and 42-55 points per pose; this is that spike made real.
##
## **Why a sticker rather than a drawing.** Everything else on the sheet is drawn
## *into* the paper -- pencil in the tooth, the same value range as the grid it
## sits on. A sticker is not: it is a separate object lying *on* the sheet, with a
## border of constant weight that hugs its own edge and a shadow proving it has
## thickness. That contrast is the whole point. The net and the court stay
## detailed drawings and stay quiet; the bodies are bold and sit forward, and the
## difference reads as intentional rather than as two things drawn to different
## standards.
##
## Three passes, in this order, and none of them is optional:
##
## 1. **The shadow.** The traced contour again, offset and darkened. Without it a
##    sticker is a shape with a thick outline; with it the shape is *above* the
##    paper. It is doing the same job a drop shadow does and for the same reason.
## 2. **The body.** The baked render, posterised to a few tones and tinted toward
##    coloured-pencil hues. Keeping the render is what buys real form -- the
##    light and shade come off the actual mesh rather than being invented -- and
##    posterising is what stops it reading as a 3D screenshot pasted onto a
##    drawing.
## 3. **The border.** The traced contour, at constant weight, hugging the edge.
##    Constant is the operative word: every other line on this sheet varies with
##    the hand, and this one does not, because a die cut does not.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

signal sticker_ready(key: String)

## What the bake renders into. Bigger than it is drawn, so the border trace has
## sub-pixel detail to simplify away rather than the staircase it would get from
## tracing at final size.
const BAKE_SIZE := Vector2i(256, 320)
## How far the boundary may stray from the traced path before a point is kept.
## At 1.6 px a pose came out at 42-55 points, measured.
const SIMPLIFY_TOLERANCE: float = 1.6

## Coloured pencil rather than graphite.
##
## A skilled hand does not shade with one pencil darkened -- they lay a warm tone
## in the light and a *cooler, more saturated* one in the shadow, because that is
## what a shadow does to a colour. Three steps, because a posterised render with
## more than about four tones stops reading as pencil and starts reading as a
## render with banding.
const TONE_STEPS: int = 3
const TONE_LIGHT := Color(0.93, 0.88, 0.79)
const TONE_MID := Color(0.72, 0.62, 0.56)
const TONE_DARK := Color(0.42, 0.36, 0.42)
## And the same three for the dark theme, which is the same drawing under a desk
## lamp rather than a different one.
const TONE_LIGHT_DARK := Color(0.72, 0.70, 0.66)
const TONE_MID_DARK := Color(0.48, 0.45, 0.46)
const TONE_DARK_DARK := Color(0.26, 0.24, 0.29)

var _viewport: SubViewport = null
var _actor: PlayerActor3D = null
var _camera: Camera3D = null
var _baked: Dictionary = {}
var _queue: Array[Dictionary] = []
var _working: bool = false


## What a finished sticker is: the shaded body, its outline, and the box the
## outline was normalised into.
class Sticker extends RefCounted:
	var texture: ImageTexture
	var contours: Array = []
	var aspect: float = 1.0


func sticker(key: String) -> Sticker:
	return _baked.get(key, null) as Sticker


## Ask for a pose. Returns immediately; `sticker_ready` fires when the bake lands.
##
## Requests are queued rather than run at once because they all share one
## viewport and one actor -- rebuilding either per request would cost far more
## than the trace does, and the trace is the expensive part.
## `pitch_degrees` is how far above the voli the camera sits, and it is not a
## flourish: a sticker baked head-on and dropped into a top-down court is a body
## standing up out of a plan view. The bake camera has to stand where the *view*
## stands, so each view keys its own bake and they coexist in the cache.
func request(
	key: String, event_type: int, elevation: float, phase: float,
	profile: Dictionary, yaw_degrees: float = 0.0, pitch_degrees: float = 0.0,
	headshot: bool = false
) -> void:
	if _baked.has(key):
		return
	for pending in _queue:
		if str(pending.get("key", "")) == key:
			return
	_queue.append({
		"key": key, "event_type": event_type, "elevation": elevation,
		"phase": phase, "profile": profile, "yaw": yaw_degrees,
		"pitch": pitch_degrees, "headshot": headshot,
	})
	if not _working:
		_pump()


func _pump() -> void:
	if _queue.is_empty():
		_working = false
		return
	_working = true
	var job: Dictionary = _queue.pop_front()
	await _bake(job)
	_pump()


func _ensure_rig() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.size = BAKE_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	add_child(_viewport)

	_actor = ACTOR_SCENE.instantiate() as PlayerActor3D
	_viewport.add_child(_actor)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	## Wide enough for a blocking pose. At 3.2 the raised arms left the frame and
	## traced as three islands rather than one body.
	_camera.size = 4.6
	_viewport.add_child(_camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38.0, 34.0, 0.0)
	key_light.light_energy = 1.15
	_viewport.add_child(key_light)
	## A second, weak light opposite the first. One light gives a shadow side that
	## goes to black, and a coloured-pencil shadow never does -- it goes to a
	## cooler hue with the form still readable in it.
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-14.0, -140.0, 0.0)
	fill_light.light_energy = 0.42
	_viewport.add_child(fill_light)


func _bake(job: Dictionary) -> void:
	_ensure_rig()
	var profile: Dictionary = job["profile"]
	_actor.configure(1, true, "", str(profile.get("dominant_hand", "Right")), profile)
	## Neither belongs in a silhouette: the shadow is a separate mesh on the floor
	## and would trace as its own island, and the focus ring is interface.
	(_actor.get_node("Shadow") as Node3D).visible = false
	(_actor.get_node("FocusRing") as Node3D).visible = false
	(_actor.get_node("IdentityLabel") as Node3D).visible = false
	_actor.rotation_degrees = Vector3(0.0, float(job["yaw"]), 0.0)
	## The camera orbits the voli at the view's own pitch, looking at the middle
	## of the body. At 0 it is level with the chest; at -60 it is most of the way
	## overhead, which is what a plan view asks for.
	var pitch := deg_to_rad(float(job["pitch"]))
	## A headshot frames the head and shoulders and nothing else, so it looks at
	## eye height with a much tighter orthogonal size. It is the same rig and the
	## same trace -- a face is just a very small silhouette -- which is why this is
	## a framing flag rather than a second baker.
	var head_only := bool(job.get("headshot", false))
	var focus := Vector3(0.0, 1.62 if head_only else 1.15, 0.0)
	_camera.size = 0.95 if head_only else 4.6
	var radius := 4.0
	_camera.position = focus + Vector3(
		0.0, sin(-pitch) * radius, cos(-pitch) * radius
	)
	_camera.look_at(focus, Vector3.UP)

	for _index in range(3):
		await get_tree().process_frame
	## Posed *after* the actor has settled, and as the contact actor.
	##
	## `set_pose` returns early unless `is_contact_actor` is true -- every
	## pose-specific limb movement is behind that gate -- so posing with false
	## leaves the rig silently in its neutral stance and every pose bakes
	## identically. Both mistakes were made during the spike.
	_actor.set_pose(
		int(job["event_type"]), float(job["elevation"]), float(job["phase"]),
		Vector2(0.0, -1.0), true
	)
	for _index in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := _viewport.get_texture().get_image()
	## Cropped to the body before anything else.
	##
	## The bake frames a whole standing figure so a blocking pose does not lose its
	## arms, which means a crouched one occupies well under half the sheet -- and
	## drawn into a box sized from the bake, that voli came out at a third the
	## height of the one beside them. Cropping to the silhouette makes the box
	## *mean* the body, so a caller asking for a 160px sticker gets 160px of voli
	## whatever the pose, and the aspect carries the difference instead.
	var bounds := _body_bounds(image)
	if bounds.size.x < 4.0 or bounds.size.y < 4.0:
		return
	var cropped := image.get_region(Rect2i(bounds))
	var built := Sticker.new()
	built.contours = _trace(cropped)
	built.texture = ImageTexture.create_from_image(_shade(cropped))
	built.aspect = bounds.size.x / bounds.size.y
	_baked[str(job["key"])] = built
	sticker_ready.emit(str(job["key"]))


## The box the body actually occupies, with a couple of pixels of air so the
## border has somewhere to sit.
func _body_bounds(image: Image) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.5:
				continue
			low.x = minf(low.x, float(x))
			low.y = minf(low.y, float(y))
			high.x = maxf(high.x, float(x))
			high.y = maxf(high.y, float(y))
	if not is_finite(low.x):
		return Rect2()
	var pad := 3.0
	low = (low - Vector2(pad, pad)).maxf(0.0)
	high = (high + Vector2(pad, pad)).minf(
		float(maxi(image.get_width(), image.get_height()))
	)
	high.x = minf(high.x, float(image.get_width() - 1))
	high.y = minf(high.y, float(image.get_height() - 1))
	return Rect2(low, high - low)


## Posterise the render into coloured-pencil tones.
##
## The render's own luminance is the input, so the form is the mesh's and not an
## invention -- which is the whole reason to keep the render rather than fill the
## silhouette flat. What changes is the *palette*: three steps, warm in the light
## and cooler and more saturated in the shadow, which is what a coloured pencil
## does and what a greyscale ramp cannot.
func _shade(source: Image) -> Image:
	var light_mode := true
	var shaded := Image.create(
		source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8
	)
	## Built rather than written as a ternary between two literals: a typed
	## `Array[Color]` will not take an untyped array, and the ternary produces one.
	var tones: Array[Color] = []
	if light_mode:
		tones.append_array([TONE_LIGHT, TONE_MID, TONE_DARK])
	else:
		tones.append_array([TONE_LIGHT_DARK, TONE_MID_DARK, TONE_DARK_DARK])
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var pixel := source.get_pixel(x, y)
			if pixel.a < 0.5:
				shaded.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var step := clampi(
				int((1.0 - pixel.get_luminance()) * float(TONE_STEPS)),
				0, TONE_STEPS - 1
			)
			shaded.set_pixel(x, y, tones[step])
	return shaded


func _trace(image: Image) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	for y in range(height):
		for x in range(width):
			mask[y * width + x] = 1 if image.get_pixel(x, y).a > 0.5 else 0

	var seen := {}
	var contours: Array = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if mask[y * width + x] == 0 or seen.has(y * width + x):
				continue
			if _interior(mask, width, x, y):
				continue
			var walked := _walk(mask, width, height, x, y, seen)
			if walked.size() < 24:
				continue
			contours.append(_normalise(_simplify(walked, SIMPLIFY_TOLERANCE), width, height))
	return contours


func _interior(mask: PackedByteArray, width: int, x: int, y: int) -> bool:
	return mask[y * width + x - 1] == 1 and mask[(y - 1) * width + x] == 1 \
		and mask[y * width + x + 1] == 1 and mask[(y + 1) * width + x] == 1


## Moore-neighbour boundary tracing: keep the direction of approach and always
## resume clockwise of where the walk came from, so it hugs the boundary all the
## way round instead of wandering into a dead end -- which a plain
## nearest-unvisited walk does, and which lost a blocker's raised arms.
func _walk(
	mask: PackedByteArray, width: int, height: int,
	start_x: int, start_y: int, seen: Dictionary
) -> PackedVector2Array:
	var neighbours := [
		Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	]
	var path := PackedVector2Array()
	var start := Vector2i(start_x, start_y)
	var at := start
	var entry := 4
	var guard := 0
	while guard < 40000:
		guard += 1
		path.append(Vector2(at))
		seen[at.y * width + at.x] = true
		var moved := false
		for step in range(1, 9):
			var index: int = (entry + step) % 8
			var next: Vector2i = at + neighbours[index]
			if next.x < 1 or next.y < 1 or next.x >= width - 1 or next.y >= height - 1:
				continue
			if mask[next.y * width + next.x] == 0:
				continue
			at = next
			entry = (index + 5) % 8
			moved = true
			break
		if not moved:
			break
		if at == start and path.size() > 8:
			break
	return path


## Into the unit box, so the caller places and scales without knowing the bake
## resolution.
func _normalise(points: PackedVector2Array, width: int, height: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		out.append(Vector2(point.x / float(width), point.y / float(height)))
	return out


func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep := {0: true, points.size() - 1: true}
	_split(points, 0, points.size() - 1, tolerance, keep)
	var out := PackedVector2Array()
	for index in range(points.size()):
		if keep.has(index):
			out.append(points[index])
	return out


func _split(
	points: PackedVector2Array, first: int, last: int,
	tolerance: float, keep: Dictionary
) -> void:
	if last <= first + 1:
		return
	var worst := 0.0
	var worst_index := -1
	for index in range(first + 1, last):
		var distance := _line_distance(points[index], points[first], points[last])
		if distance > worst:
			worst = distance
			worst_index = index
	if worst < tolerance or worst_index < 0:
		return
	keep[worst_index] = true
	_split(points, first, worst_index, tolerance, keep)
	_split(points, worst_index, last, tolerance, keep)


func _line_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	if span.length_squared() < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(a + span * t)
