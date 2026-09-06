extends SceneTree

## A full rally, drawn from the movement the simulation actually solved.
##
## Every trace here is read back out of the production playback path: the tool
## drives a real `TacticalCourt` through `animate_spatial_transition` leg by leg
## and samples `_sample_movement_path`, so what is drawn is what the court draws.
## Nothing is re-integrated for the picture.
##
## Two things are marked, because the point of the picture is the difference
## between them:
##
##   solid  -- a leg the resolver solved and published. The shape is the model's:
##             it accelerates, it corners, it can stop short.
##   dotted -- a *correction*. The simulation did not move this body, and the
##             drawn body was somewhere else, so playback closes the gap and
##             records it. These used to be re-integrated as if they were
##             journeys. See AUTHORITATIVE_MOVEMENT_EXECUTION.md P13.2.
##
## Run:
##   godot --headless --path . --script res://tools/render_authoritative_movement.gd

const GM := preload("res://scripts/managers/game_manager.gd")
const TC := preload("res://scenes/components/tactical_court.gd")

const OUT_DIR := "res://artifacts/authoritative-movement"
const W := 720
const H := 1160
const MARGIN := 40
const SAMPLES_PER_LEG := 40

const GROUND := Color(0.086, 0.094, 0.118)
const COURT_INK := Color(0.36, 0.40, 0.47)
const NET := Color(0.72, 0.74, 0.80)
const HOME := Color(0.35, 0.72, 0.98)
const AWAY := Color(0.98, 0.58, 0.30)
const CORRECTION := Color(0.98, 0.32, 0.36)


func _initialize() -> void:
	var manager: Object = GM.new()
	manager.seed_vertical_slice_data()
	var court: Object = TC.new()
	get_root().add_child(court)
	court.set_lineup(manager.rotations[1], manager.players)
	court.set_opponent_team(manager.opponent_team, true)

	## Three rallies chosen for length rather than picked by hand: the longest
	## three in the window have the most legs to disagree about.
	var ranked: Array = []
	for seed_value in range(4000, 4060):
		var result: Variant = manager.resolve_active_rally(seed_value)
		if result == null or result.events.size() < 4:
			continue
		ranked.append({"seed": seed_value, "events": result.events.size()})
	ranked.sort_custom(func(a, b): return int(a.events) > int(b.events))

	var written := 0
	for index in mini(3, ranked.size()):
		var seed_value := int(ranked[index].seed)
		var result: Variant = manager.resolve_active_rally(seed_value)
		var traces := _trace_rally(court, result)
		var image := _draw(traces, seed_value, int(result.events.size()))
		var path := "%s/rally_%d.png" % [OUT_DIR, seed_value]
		image.save_png(path)
		written += 1
		print("wrote %s -- %d events, %d traced legs, %d corrections" % [
			path, result.events.size(), int(traces.legs), int(traces.corrections),
		])
	print("%d frames in %s" % [written, OUT_DIR])
	quit()


## Every player's drawn position through every leg, plus which legs were
## corrections rather than solved journeys.
func _trace_rally(court: Object, result: Variant) -> Dictionary:
	var events: Array = result.events
	court.begin_rally_playback(
		result.get("initial_home_positions") \
			if result.get("initial_home_positions") is Dictionary else {},
		result.get("initial_opponent_positions") \
			if result.get("initial_opponent_positions") is Dictionary else {},
	)
	var strokes: Array = []
	var legs := 0
	var corrections := 0
	for index in range(events.size() - 1):
		court.animate_spatial_transition(events[index], events[index + 1], 1.0)
		for raw_player_id in court.unit_movement_targets:
			var player_id := int(raw_player_id)
			var path: Dictionary = court.movement_paths.get(player_id, {})
			if path.is_empty():
				continue
			legs += 1
			var is_correction := bool(path.get("correction", false))
			if is_correction:
				corrections += 1
			var points: Array[Vector2] = []
			for step in range(SAMPLES_PER_LEG + 1):
				points.append(court._sample_movement_path(
					path, float(step) / float(SAMPLES_PER_LEG)
				))
			strokes.append({
				"points": points,
				"opponent": court._is_opponent_player(player_id),
				"correction": is_correction,
			})
		court.finish_event_animation()
	return {"strokes": strokes, "legs": legs, "corrections": corrections}


func _draw(traces: Dictionary, seed_value: int, event_count: int) -> Image:
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	image.fill(GROUND)
	_court_lines(image)
	for raw_stroke in traces.strokes:
		var stroke: Dictionary = raw_stroke
		var colour: Color = CORRECTION if bool(stroke.correction) \
			else (AWAY if bool(stroke.opponent) else HOME)
		var points: Array = stroke.points
		for index in range(1, points.size()):
			## A correction is drawn as a dashed line so it cannot be mistaken
			## for motion the simulation decided.
			if bool(stroke.correction) and index % 4 >= 2:
				continue
			_line(image, _place(points[index - 1]), _place(points[index]), colour)
	## Caption, drawn as a legend block rather than text: no font is loaded in a
	## headless SceneTree and a swatch says the same thing.
	_swatch(image, 0, HOME, "home")
	_swatch(image, 1, AWAY, "opponent")
	_swatch(image, 2, CORRECTION, "correction")
	print("  seed %d: %d events, %d legs, %d corrections" % [
		seed_value, event_count, int(traces.legs), int(traces.corrections),
	])
	return image


func _court_lines(image: Image) -> void:
	var corners := [
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
	]
	for index in 4:
		_line(image, _place(corners[index]), _place(corners[(index + 1) % 4]), COURT_INK)
	_line(image, _place(Vector2(0.0, 0.5)), _place(Vector2(1.0, 0.5)), NET)
	for line_y in [1.0 / 3.0, 2.0 / 3.0]:
		_line(image, _place(Vector2(0.0, line_y)), _place(Vector2(1.0, line_y)), COURT_INK)


func _swatch(image: Image, row: int, colour: Color, _label: String) -> void:
	var top := MARGIN / 2 + row * 10
	for y in range(top, top + 6):
		for x in range(MARGIN / 2, MARGIN / 2 + 24):
			image.set_pixel(x, y, colour)


func _place(court_point: Vector2) -> Vector2:
	return Vector2(
		MARGIN + court_point.x * float(W - 2 * MARGIN),
		MARGIN + court_point.y * float(H - 2 * MARGIN),
	)


func _line(image: Image, from: Vector2, to: Vector2, colour: Color) -> void:
	var steps := int(maxf(from.distance_to(to), 1.0)) * 2
	for step in range(steps + 1):
		var point := from.lerp(to, float(step) / float(maxi(steps, 1)))
		var x := int(round(point.x))
		var y := int(round(point.y))
		if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
			continue
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				image.set_pixel(x + dx, y + dy, colour)
