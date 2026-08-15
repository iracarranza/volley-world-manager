extends Node

## The cogniticons, photographed on the court they have to be read on.
##
##     xvfb-run -a godot --path . res://tools/cogniticon_plate.tscn
##
## Reported twice, from screenshots: the marks cannot be made out. The fix was a
## size and a contrast, and a size argued from constants is exactly the kind of
## claim this repository keeps having to withdraw -- so this photographs it.
##
## **Shot through the real court at the real camera.** `MatchCourt3D` is
## instantiated rather than a stage being built beside it, and the camera is the
## `Broadcast` preset the match centre opens on. That matters more than anything
## else here: a billboard with `fixed_size` is sized as a share of the viewport,
## so a plate shot from four metres away answers a question nobody asked. The
## whole defect was a number that read fine on the 2D board and vanished at
## playback distance.
##
## Two plates, before and after, from one run. The constants are `const` and
## cannot be swapped, so the "before" plate is drawn by writing the old values
## onto the billboard *after* `show_cue` has posed it -- 0.00010 pixel size, 0.55
## alpha, and the middle dot for `watching`. That is a reconstruction rather than
## a checkout of the old file, and it is honest about being one: it reproduces
## the three values that changed and nothing else.
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const Cue := preload("res://scripts/models/player_cognition_cue.gd")
const Billboard := preload("res://scenes/components/cognition_billboard_3d.gd")

## The old values, kept here and nowhere else, purely so the comparison can be
## drawn. Nothing reads these but the "before" plate.
const WAS_PIXEL_SIZE: float = 0.00010
const WAS_ALPHA: float = 0.55
const WAS_WATCHING_GLYPH: String = "·"

## One voli per intent, at a court position where that intent makes sense, so
## the plate reads as a moment of volleyball rather than as a row of swatches.
## `x` and `y` are normalised court space; the net is y = 0.5.
const SUBJECTS: Array[Dictionary] = [
	{"intent": &"blocking", "at": Vector2(0.32, 0.44), "home": false,
		"name": "middle"},
	{"intent": &"blocking", "at": Vector2(0.55, 0.44), "home": false,
		"name": "outside"},
	{"intent": &"defending", "at": Vector2(0.22, 0.24), "home": false,
		"name": "wing"},
	{"intent": &"watching", "at": Vector2(0.78, 0.20), "home": false,
		"name": "off the play"},
	{"intent": &"approaching", "at": Vector2(0.24, 0.62), "home": true,
		"name": "hitter", "progress": 0.62},
	{"intent": &"preparing_attack", "at": Vector2(0.74, 0.60), "home": true,
		"name": "opposite"},
	{"intent": &"setting", "at": Vector2(0.52, 0.58), "home": true,
		"name": "setter"},
	{"intent": &"covering", "at": Vector2(0.38, 0.72), "home": true,
		"name": "cover"},
	{"intent": &"receiving", "at": Vector2(0.62, 0.82), "home": true,
		"name": "libero"},
]

## And one state badge, so the two tiers can be compared in the same frame --
## which is the actual claim being made, that ambient is quieter than a badge
## rather than smaller than one.
const BADGE_SUBJECT := {
	"at": Vector2(0.86, 0.74), "home": true, "name": "badge tier",
}


func _ready() -> void:
	await get_tree().process_frame
	for plate in [
		{"name": "after", "old": false},
		{"name": "before", "old": true},
	]:
		await _shoot(bool(plate["old"]), str(plate["name"]))
	get_tree().quit()


func _shoot(as_old: bool, plate_name: String) -> void:
	var court = load("res://scenes/components/match_court_3d.tscn").instantiate()
	add_child(court)
	await get_tree().process_frame

	var next_id := 1
	var actors: Array = []
	for subject in SUBJECTS:
		var actor = court.ensure_player(
			next_id, Vector2(subject["at"]), bool(subject["home"]),
			str(subject["name"]), "Right",
			{"height_meters": 1.86 + 0.06 * float(next_id % 3), "body_type": _body(next_id)},
		)
		court.set_player_position(next_id, Vector2(subject["at"]))
		actors.append({"actor": actor, "subject": subject})
		next_id += 1
	var badge_actor = court.ensure_player(
		next_id, Vector2(BADGE_SUBJECT["at"]), true, str(BADGE_SUBJECT["name"]),
		"Right", {"height_meters": 1.92, "body_type": "Cani"},
	)
	court.set_player_position(next_id, Vector2(BADGE_SUBJECT["at"]))
	await get_tree().process_frame

	for entry in actors:
		var actor = entry["actor"]
		var subject: Dictionary = entry["subject"]
		## Ambient is `priority < 0` -- that is the whole tier test in
		## `cognition_badge.gd`, so it is what makes these the intent marks
		## rather than state badges.
		var cue = _cue(next_id, -1)
		cue.intent = subject["intent"]
		## The blade only says what it is for when it is partly full, so the
		## approaching hitter carries a real progress rather than zero. Taken
		## from `run_intent_progress_probe.gd`'s measured mean for the family.
		cue.progress = float(subject.get("progress", 0.0))
		actor.show_cognition_cue(cue, 0.5)
		if as_old:
			_wind_back(actor.cognition_billboard, str(subject["intent"]))
	## The badge tier, unchanged by any of this, as the reference the ambient
	## marks are supposed to sit under.
	var badge_cue = _cue(next_id, 3)
	badge_cue.punctuation = "!"
	badge_actor.show_cognition_cue(badge_cue, 0.5)

	for _frame in range(10):
		await get_tree().process_frame
	var path := "user://cogniticons_%s.png" % plate_name
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
	court.queue_free()
	await get_tree().process_frame


## A cue that will actually be drawn.
##
## `is_worth_drawing` declines a searching cue watching the ball at low urgency,
## which is most of a rally and none of what this plate is about, so the state
## and attention are set away from that branch deliberately.
func _cue(player: int, priority: int):
	var cue = Cue.create(player, &"home", 1, 0.0, 4.0, &"committed", &"during")
	cue.attention_kind = &"setter"
	cue.urgency = 0.7
	cue.priority = priority
	## Negative dwell means no fade, so every mark on the plate is at full
	## strength and the comparison is of size and alpha rather than of timing.
	cue.dwell_seconds = -1.0
	return cue


## Put the three changed values back, for the "before" half of the plate.
func _wind_back(billboard, intent: String) -> void:
	if billboard == null:
		return
	billboard.pixel_size = WAS_PIXEL_SIZE * Billboard.COGNITICON_SCALE
	var faded: Color = billboard.modulate
	faded.a = faded.a / maxf(Billboard.AMBIENT_ALPHA, 0.001) * WAS_ALPHA
	billboard.modulate = faded
	if intent == "watching":
		billboard.text = WAS_WATCHING_GLYPH


func _body(seed_id: int) -> String:
	var types := ["Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi"]
	return str(types[seed_id % types.size()])
