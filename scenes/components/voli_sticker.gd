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
## 2. **The body**, in flat colour. The rig is rendered *unshaded*, so what comes
##    back is the material colours themselves -- kit, shorts, skin, crown -- as
##    regions the eye can name. Lit and posterised it looked like real form and
##    read as mud: a hundred pixels of directional shading is a smudge, not a
##    body. The silhouette does the shaping instead, which is what the die-cut
##    border was always for.
## 3. **The border.** The traced contour, at constant weight, hugging the edge.
##    Constant is the operative word: every other line on this sheet varies with
##    the hand, and this one does not, because a die cut does not.

const ACTOR_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

signal sticker_ready(key: String)
## Fired when the cache is dropped, so whoever asked for a sticker knows to ask
## again. There is no way to repaint a baked one -- the tones are burnt into the
## texture -- so a theme change is a rebake, and the alternative is a caller
## holding a texture in the wrong palette forever.
signal stickers_reset

## What the bake renders into. Bigger than it is drawn, so the border trace has
## sub-pixel detail to simplify away rather than the staircase it would get from
## tracing at final size.
const BAKE_SIZE := Vector2i(256, 320)
## How far the boundary may stray from the traced path before a point is kept.
## At 1.6 px a pose came out at 42-55 points, measured.
const SIMPLIFY_TOLERANCE: float = 1.6

## How far the flat colours are stepped.
##
## The render is already flat -- the rig bakes unshaded -- so this is not
## posterising light and shade, it is **quantising the palette**: a printed sticker
## has a countable number of inks, and a value that can only land on one of six
## levels per channel reads as printed rather than as sampled. Six is enough that
## two body types are still different colours and few enough that the whole set
## looks like it came off one press.
##
## Twelve, not six. At six the steps are 1/6 apart, which is coarser than the
## saturation cap below is trying to hold: an ink capped to s=0.40 at v=0.67 wants
## its dark channel at 0.40, the nearest sixth is 0.333, and the rounding puts the
## saturation back up to 0.50. Measured off the rendered sheet, that is exactly
## what came out -- every colour at s=0.50 with a 0.40 cap in the code above it.
## A knob that cannot survive the stage after it is not a knob.
const COLOUR_STEPS: float = 12.0
## And how strong an ink is allowed to get. A club colour still reads as that
## club's colour at this saturation; it stops competing with the red pencil, which
## is the only thing on the sheet allowed to shout.
const INK_SATURATION_CAP: float = 0.30

## Which of the two palettes the bakes are being laid down in.
##
## Was a local `var light_mode := true` inside `_shade`, which is a stub written
## as if it were a decision -- so the dark theme got the light palette and every
## voli came out a near-white blob on a near-black sheet, with a pale die-cut
## border on a pale body and no edge at all. The tell was that the figures were
## the brightest thing on a dark board, which is exactly what the sticky note's
## own comment warns against.
var light_mode: bool = true

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
	## The arms, traced on their own, in the same unit box. Drawn as a second cut
	## edge over the body's -- not as a second sticker, so no shadow and no fill.
	var arm_contours: Array = []
	var aspect: float = 1.0
	## How many world metres tall the cropped image is.
	##
	## The bake camera is orthogonal, so its `size` *is* the world height of the
	## uncropped frame -- and once the crop is known, so is the world height of
	## what survived. That turns "how big should this sticker be" from a number
	## somebody picked into arithmetic: metres times the view's pixels-per-metre.
	## Without it a voli was drawn at a share of the panel and came out roughly
	## four metres tall in a plan view.
	var world_height: float = 2.0
	## And how far the bottom edge of the crop sits *below* the voli's own ground
	## point, in metres on the same axis. Negative for anything airborne.
	##
	## This is what lets a caller place a sticker by saying where the voli is
	## **standing** rather than where the image goes. A jumping body's crop starts
	## above the floor, and by exactly the height of the jump the pose already
	## contains -- so a drawing that anchors the crop's bottom to the floor puts a
	## blocker at full extension flat on the ground, which is what it did. The
	## alternative was writing the jump out a second time in the drawing code,
	## where it drifts the moment the pose changes.
	var ground_offset: float = 0.0


func sticker(key: String) -> Sticker:
	return _baked.get(key, null) as Sticker


## Drop every baked sticker, because the palette they were baked in is no longer
## the one on screen. Callers re-request off `stickers_reset`.
func set_palette(is_light: bool) -> void:
	if light_mode == is_light:
		return
	light_mode = is_light
	clear()


## Drop the cache without changing anything about how the next bake runs. Used
## when *who* is being drawn changes rather than how -- a new lineup is new
## people, and a sticker is a photograph of one specific voli.
func clear() -> void:
	_baked.clear()
	_queue.clear()
	stickers_reset.emit()


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


## Drain the queue, then stop.
##
## A loop rather than the tail call it was. That was fine while every job took
## frames, because each one unwound the stack on its first `await` -- but a job
## served from disk never awaits anything, so a cold cache of forty-nine stickers
## became forty-nine frames of nested `_pump`. The loop is the same behaviour with
## a bound that does not depend on how fast a bake happens to be.
func _pump() -> void:
	_working = true
	while not _queue.is_empty():
		var rendered := await _bake(_queue.pop_front())
		## **One render per frame, guaranteed, and the guarantee is the point.**
		##
		## `_bake` already awaits frames inside itself, so this looked redundant
		## and is not: those awaits are for the *renderer* -- pose the rig, let it
		## draw, read it back -- and nothing stopped several jobs sharing one
		## main-loop iteration between them. Measured, single frames were carrying
		## several bakes and running for seconds, which is a freeze rather than a
		## stutter: the whole game stops, including whatever screen you navigated
		## to while it was still going.
		##
		## Yielded only after a job that actually rendered. A cache hit costs a
		## file read, and spending a frame on each of those would make a warm open
		## slower than a cold one by exactly the thing meant to speed it up.
		if rendered:
			await get_tree().process_frame
	_working = false
	## **Stop rendering when there is nothing to render.**
	##
	## The rig is kept between bakes -- building it is the expensive part and a
	## sheet re-bakes constantly -- but keeping it did not have to mean keeping
	## it *drawing*. On `UPDATE_ALWAYS` this viewport renders a posed 3D voli in
	## its own world every frame forever, long after the last sticker was cut,
	## and every screen that owns a baker adds another one. They are invisible by
	## construction: nothing on screen shows this viewport, so nothing about the
	## sheet looks different whether it is running or not.
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


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


## Where cut stickers are kept between runs, and whether they are kept at all.
##
## A bake is a posed 3D render, two texture readbacks and two contour traces, and
## the clipboard asks for forty-nine of them the first time it opens. None of that
## work depends on anything that changes between runs: the same voli in the same
## pose from the same angle in the same palette cuts the same sticker every time.
## So it is done once and kept.
##
## `disk_cache` is off for the preview tools, which exist precisely to look at a
## rig that has just changed -- a tool that draws yesterday's bake is a tool that
## cannot show you what you did.
const CACHE_DIR := "user://sticker_cache"
static var disk_cache: bool = true
## How many stickers the directory may hold before the oldest are dropped. A
## sticker is a few kilobytes, and a long career sees a lot of volis; without a
## bound this grows for the life of the save and nothing ever looks at it.
const CACHE_LIMIT: int = 900

## What a cached sticker was baked *by*, so a changed rig cannot serve an old one.
##
## The inputs to a bake are in the filename, but the *behaviour* is in the code --
## line weight, colour steps, the shape of a shoulder -- and none of that shows up
## in a job. A hand-bumped version constant would work exactly as often as
## somebody remembered to bump it, which for a cache that fails silently and
## looks fine is not often enough. The fingerprint therefore digests every source
## that can change the baked body's geometry or surface treatment.
const FINGERPRINT_SOURCES: Array[String] = [
	"res://scenes/components/voli_sticker.gd",
	"res://scenes/components/player_actor_3d.gd",
	"res://scenes/components/player_actor_3d.tscn",
	"res://scenes/components/surface_mark_renderer_3d.gd",
	"res://scripts/data/body_type_models.gd",
	## **The face was missing, and a missing entry fails exactly like a cache
	## that works.** `face_expressions.gd` owns the mouth's shape, its sampling
	## and how far it stands off a muzzle -- all of it geometry, all of it baked
	## into the headshot. It was not listed, so rebuilding the mouth invalidated
	## nothing and every cached sticker kept serving the old face from disk. The
	## comment above already states the rule this violated: digest every source
	## that can change the baked body's geometry.
	"res://scripts/data/face_expressions.gd",
]
static var _fingerprint: String = ""
static var _pruned: bool = false


static func _bake_fingerprint() -> String:
	if not _fingerprint.is_empty():
		return _fingerprint
	var parts := PackedStringArray()
	for path in FINGERPRINT_SOURCES:
		## Empty when a source is not readable as a file, which is what an
		## exported build can do. An empty part is honest -- it weakens the
		## fingerprint rather than faking one -- and the rest still change.
		parts.append(FileAccess.get_md5(path))
	_fingerprint = "|".join(parts).md5_text().substr(0, 12)
	return _fingerprint


## Everything a bake depends on, in one canonical string.
##
## Sorted keys, because a `Dictionary` keeps insertion order and two callers
## building the same profile in a different order would otherwise be two
## different stickers. The request's own `key` is deliberately *not* in here: it
## is a caller's name for a slot, not a description of a pose, and two screens
## naming the same pose differently should share one bake.
func _job_signature(job: Dictionary) -> String:
	var profile: Dictionary = job.get("profile", {})
	var names := profile.keys()
	names.sort()
	var parts := PackedStringArray()
	for name in names:
		parts.append("%s=%s" % [name, profile[name]])
	parts.append("event=%d" % int(job.get("event_type", 0)))
	## Rounded to a thousandth. These arrive from tweens and view tables as
	## floats, and a pose 0.0000001 off the last one is the same drawing --
	## caching at full float precision would miss every time and never say so.
	for number in ["elevation", "phase", "yaw", "pitch"]:
		parts.append("%s=%.3f" % [number, float(job.get(number, 0.0))])
	parts.append("head=%s" % str(bool(job.get("headshot", false))))
	parts.append("light=%s" % str(light_mode))
	parts.append("rig=%s" % _bake_fingerprint())
	return "|".join(parts)


func _cache_path(job: Dictionary) -> String:
	return "%s/%s.sticker" % [CACHE_DIR, _job_signature(job).md5_text()]


func _read_cache(job: Dictionary) -> Sticker:
	if not disk_cache:
		return null
	var path := _cache_path(job)
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw: Variant = file.get_var()
	file.close()
	if not (raw is Dictionary):
		return null
	var stored: Dictionary = raw
	var image := Image.new()
	## PNG rather than the raw buffer: a sticker is mostly transparent, so the
	## compression is most of the file, and `Image` is an Object that `store_var`
	## will not serialise anyway.
	if image.load_png_from_buffer(stored.get("png", PackedByteArray())) != OK:
		return null
	image.generate_mipmaps()
	var built := Sticker.new()
	built.texture = ImageTexture.create_from_image(image)
	built.contours = stored.get("contours", [])
	built.arm_contours = stored.get("arm_contours", [])
	built.aspect = float(stored.get("aspect", 1.0))
	built.world_height = float(stored.get("world_height", 2.0))
	built.ground_offset = float(stored.get("ground_offset", 0.0))
	return built


## `shaded` is passed in rather than read back off the texture, because a texture
## that has had mipmaps generated hands back the chain and not the image.
func _write_cache(job: Dictionary, built: Sticker, shaded: Image) -> void:
	if not disk_cache or shaded == null:
		return
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	_prune_cache()
	var file := FileAccess.open(_cache_path(job), FileAccess.WRITE)
	if file == null:
		return
	file.store_var({
		"png": shaded.save_png_to_buffer(),
		"contours": built.contours,
		"arm_contours": built.arm_contours,
		"aspect": built.aspect,
		"world_height": built.world_height,
		"ground_offset": built.ground_offset,
	})
	file.close()


## Drop the oldest stickers once past the limit, once per run.
##
## Once per run and not per write, because the check is a directory listing plus
## a stat per file and the thing it guards against takes seasons to happen. A
## dropped sticker is not lost, only uncut -- the next request bakes it again.
func _prune_cache() -> void:
	if _pruned:
		return
	_pruned = true
	var names := DirAccess.get_files_at(CACHE_DIR)
	if names.size() <= CACHE_LIMIT:
		return
	var aged: Array = []
	for name in names:
		var path := "%s/%s" % [CACHE_DIR, name]
		aged.append({"path": path, "at": FileAccess.get_modified_time(path)})
	aged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["at"]) < int(b["at"])
	)
	for index in range(aged.size() - CACHE_LIMIT):
		DirAccess.remove_absolute(str(aged[index]["path"]))


## Cut stickers, and the disk they are kept on, forgotten.
##
## Separate from `clear()`, which drops what is in memory because the palette or
## the squad changed -- both of those are reasons to re-read the disk, not to
## throw it away.
static func forget_disk_cache() -> void:
	for name in DirAccess.get_files_at(CACHE_DIR):
		DirAccess.remove_absolute("%s/%s" % [CACHE_DIR, name])


## Returns whether this job actually rendered, so the pump knows whether it owes
## the main loop a frame.
func _bake(job: Dictionary) -> bool:
	## Disk first. A hit costs a file read and no frames at all, which is the
	## point: the whole reason a sheet is expensive is that it renders.
	var cached := _read_cache(job)
	if cached != null:
		_baked[str(job["key"])] = cached
		sticker_ready.emit(str(job["key"]))
		return false
	_ensure_rig()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var profile: Dictionary = job["profile"]
	## Flat, before `configure` builds the materials. Set after, it would repaint
	## nothing -- the meshes already have their `material_override`.
	_actor.flat_shading = true
	## **The id comes off the profile, and it used to be the literal 1.**
	##
	## Everything that makes one voli look unlike another of the same species is
	## seeded from the player id -- which produce a Vegi is, which colourway they
	## wear, and now which coat they carry. Baking every sticker as player 1 meant
	## every one of them resolved the same produce, the same colours and the same
	## markings, so a tactic sheet of seven volis was seven copies of one voli in
	## different heights. The differentiators were all there and none of them could
	## reach the page.
	##
	## The id is part of the cache key already, because the key is the whole
	## profile -- so this does not need a cache version bump, it needs callers to
	## put the id in the profile, which they now do.
	_actor.configure(
		int(profile.get("player_id", 1)), true, "",
		str(profile.get("dominant_hand", "Right")), profile
	)
	## `configure` paints the kit from the dark palette unconditionally, which is
	## right for the court and wrong here -- a sticker is going onto a sheet whose
	## theme the caller already knows. Repainting after is the cheap fix and keeps
	## the kit the same colour as the rest of the interface it is sitting in.
	_actor.apply_ui_palette(light_mode)
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
	## The up hint is world up *projected into the camera's own plane*, which for
	## anything short of straight down is the same thing `Vector3.UP` would give.
	## At straight down it is not: UP is parallel to the look direction there, and
	## `look_at` has no basis to build, so the plan-view bake came out of a
	## degenerate transform. This is perpendicular to the look direction at every
	## pitch by construction.
	_camera.look_at(focus, Vector3(0.0, cos(pitch), sin(pitch)))

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
	## The yaw goes on **after** the pose, because the pose takes it off.
	##
	## `set_pose` ends by calling `_turn_toward`, which writes `rotation.y`
	## outright -- a block squares to the net at 180 degrees and everything else
	## turns to face the contact direction, which for the bake's `(0, -1)` is
	## zero. So the angle set before posing was discarded every time, and every
	## attack and defence sticker came back chest-on to the reader no matter which
	## view had asked for it. The blocks looked nearly right only because 180
	## happens to be close to what three quarter wanted.
	##
	## That behaviour is correct on a court -- somebody playing the ball faces the
	## ball -- and wrong for a drawing, where the body has to be seen from wherever
	## the reader is standing. Re-applied here rather than suppressed in the rig,
	## because the rig is not wrong.
	_actor.rotation_degrees = Vector3(0.0, float(job["yaw"]), 0.0)
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
		return true
	var cropped := image.get_region(Rect2i(bounds))

	## A second pass, for the arms alone.
	##
	## Everything flat black, the arms flat white, rendered again: the white pixels
	## are exactly the arm pixels that are *visible*, occlusion included, because
	## the depth buffer does the work. Tracing the arms from the colour render
	## instead would not work -- an arm is painted the same skin colour as the head
	## -- and hiding the rest of the body would let an arm behind the torso show
	## through, which is worse than not drawing it.
	##
	## Why bother: a pose is mostly arms, and an arm that crosses the torso vanishes
	## into one outline. A blocker, a spiker at the cock and a passer on their
	## platform are three arm positions on one body; without an edge round the arms
	## they are one shape three times.
	_actor.paint_flat(_actor.body_meshes(), Color.BLACK)
	_actor.paint_flat(_actor.arm_meshes(), Color.WHITE)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var arm_mask := _viewport.get_texture().get_image().get_region(Rect2i(bounds))
	_actor.apply_ui_palette(light_mode)

	var built := Sticker.new()
	built.contours = _trace(cropped)
	built.arm_contours = _trace_mask(arm_mask)
	## Mipmapped, and that is the whole of why the bodies looked smudged.
	##
	## A sticker is baked at 256 by 320 and drawn at sixty to a hundred pixels
	## tall -- a four-to-one minification. Without mipmaps the sampler takes one
	## texel in sixteen, so a posterised body with hard tone boundaries comes back
	## as a chewed edge that crawls whenever the panel resizes. The generation cost
	## is a third of a millisecond on an image this size and it is paid once.
	var shaded := _shade(cropped)
	shaded.generate_mipmaps()
	built.texture = ImageTexture.create_from_image(shaded)
	built.aspect = bounds.size.x / bounds.size.y
	built.world_height = _camera.size * (bounds.size.y / float(BAKE_SIZE.y))
	## Where the crop's bottom edge is relative to the voli's own feet, measured
	## down the camera's vertical axis in metres. The camera looks at `focus`, so
	## the frame centre is that point; the ground under the voli is `focus.y` metres
	## of world-up below it, which the tilt foreshortens by `cos(pitch)`.
	built.ground_offset = (bounds.end.y / float(BAKE_SIZE.y) - 0.5) * _camera.size \
		- focus.y * cos(pitch)
	_baked[str(job["key"])] = built
	_write_cache(job, built, shaded)
	sticker_ready.emit(str(job["key"]))
	return true


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


## Flatten the render into printed colour.
##
## With the rig unshaded there is nothing to posterise -- every pixel is already
## its material's own colour -- so the work here is keeping it that way: quantise
## each channel so the sticker has a countable palette, and keep the renderer's
## alpha so the edge has partial coverage for the mipmap chain to filter with.
##
## The previous version mapped luminance onto three hand-mixed "coloured pencil"
## tones, which threw away the kit and the skin and replaced a specific voli with
## a generic grey-brown one. Measured, the render's luminance ran 0.000 to 0.799
## with a median of 0.283 -- it was spreading across the three tones exactly as
## designed, and the design was the problem.
func _shade(source: Image) -> Image:
	var shaded := Image.create(
		source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8
	)
	## The dark theme prints the same sticker on darker stock, so the inks come
	## down a little rather than being a second palette. `apply_ui_palette` has
	## already given the rig its theme colours; this is only the paper showing
	## through.
	var lift := 1.0 if light_mode else 0.82
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var pixel := source.get_pixel(x, y)
			if pixel.a < 0.02:
				shaded.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			## Screen colour is not ink.
			##
			## The kit and the accents are mixed to sit on a lit 3D court, and taken
			## unshaded straight onto paper they came out fluorescent -- a magenta
			## torso over teal shorts, which is nobody's kit and is louder than
			## anything else on the sheet including the red pencil. Capping saturation
			## and lifting the value is what a press does to a screen colour: the hue
			## survives, so two clubs are still two colours, and the strength comes
			## down to something a printed sticker could actually be.
			var ink := Color.from_hsv(
				pixel.h, minf(pixel.s, INK_SATURATION_CAP),
				clampf(pixel.v * lift * 0.70 + 0.28, 0.0, 1.0)
			)
			shaded.set_pixel(x, y, Color(
				roundf(ink.r * COLOUR_STEPS) / COLOUR_STEPS,
				roundf(ink.g * COLOUR_STEPS) / COLOUR_STEPS,
				roundf(ink.b * COLOUR_STEPS) / COLOUR_STEPS,
				pixel.a
			))
	return shaded


## The silhouette: everything the renderer drew.
func _trace(image: Image) -> Array:
	return _walk_mask(image, func(pixel: Color) -> bool: return pixel.a > 0.5)


## One part of it, off the mask pass, where the part is white on black.
func _trace_mask(image: Image) -> Array:
	return _walk_mask(
		image,
		func(pixel: Color) -> bool:
			return pixel.a > 0.5 and pixel.get_luminance() > 0.5
	)


func _walk_mask(image: Image, keep: Callable) -> Array:
	var width := image.get_width()
	var height := image.get_height()
	var mask := PackedByteArray()
	mask.resize(width * height)
	for y in range(height):
		for x in range(width):
			mask[y * width + x] = 1 if bool(keep.call(image.get_pixel(x, y))) else 0

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


## Douglas-Peucker, on an explicit stack rather than the call stack.
##
## It was recursive, and that was fine while the only baked pose was a blocker
## traced at a few hundred boundary pixels. Adding the attack and defence poses
## broke it: a crouched dig has a long, convoluted outline, and the split can
## degenerate to one point per level, so the depth is O(n) in the contour length
## rather than O(log n). Godot overflowed and every sticker on the sheet came back
## empty -- and an empty sticker draws as nothing, so the failure was silent
## except in the log.
##
## Nothing about the algorithm changes; only where the pending spans are kept.
func _simplify(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep := {0: true, points.size() - 1: true}
	var pending: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not pending.is_empty():
		var span: Vector2i = pending.pop_back()
		if span.y <= span.x + 1:
			continue
		var worst := 0.0
		var worst_index := -1
		for index in range(span.x + 1, span.y):
			var distance := _line_distance(points[index], points[span.x], points[span.y])
			if distance > worst:
				worst = distance
				worst_index = index
		if worst < tolerance or worst_index < 0:
			continue
		keep[worst_index] = true
		pending.append(Vector2i(span.x, worst_index))
		pending.append(Vector2i(worst_index, span.y))
	var out := PackedVector2Array()
	for index in range(points.size()):
		if keep.has(index):
			out.append(points[index])
	return out


func _line_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	if span.length_squared() < 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(span) / span.length_squared(), 0.0, 1.0)
	return point.distance_to(a + span * t)
