extends SceneTree

## The drawn ball's height across one rally, before and after the repair.
##
## There is no rally-sequence renderer in this repository -- the render tools are
## galleries and single-screen shots -- so "before and after frames" of playback
## is not something existing instrumentation can produce. This is the strongest
## substitute that is honest: the *same* numbers the court draws the ball from,
## plotted against time, with the contacts marked.
##
## It is not a screenshot and does not replace watching the app. What it does
## show is the one thing the machine can settle about the seam -- where the drawn
## ball is, and by how much it jumps at each contact -- for a person to judge
## whether the result reads as volleyball.
##
## Both curves come from one pass: the repaired far end integrates the launch
## across the flight's own duration, and the "before" curve reproduces the defect
## by integrating across the drawing floor instead.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BP := preload("res://scripts/simulation/ball_presentation.gd")

const SEED := 76005
const WIDTH := 1180.0
const HEIGHT := 460.0
const PAD_LEFT := 74.0
const PAD_BOTTOM := 64.0
const PAD_TOP := 40.0
const SAMPLES := 26


func _initialize() -> void:
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	manager.match_state.serving_home = true
	var result: Resource = manager.resolve_active_rally(SEED)
	if result == null:
		push_error("seed %d resolved to nothing" % SEED)
		quit(1)
		return
	var profiles: Dictionary = result.player_physical_profiles
	var contacts: Array = []
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null or int(event.actor_id) < 0:
			continue
		if int(event.event_type) in [
			RallyEvent.EventType.SET_DECISION, RallyEvent.EventType.POINT
		]:
			continue
		contacts.append(event)

	var after: Array = []
	var before: Array = []
	var marks: Array = []
	var clock := 0.0
	var tallest := 1.0
	for position in range(contacts.size()):
		var event: RallyEvent = contacts[position]
		var next_contact: RallyEvent = (
			contacts[position + 1] if position + 1 < contacts.size() else null
		)
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var display: Dictionary = BP.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		var drawn := maxf(float(display.get("duration", 0.5)), 0.08)
		var start_height := float(display.get("start_height_meters", 1.0))
		var end_after := float(display.get("end_height_meters", 1.0))
		## The pre-repair far end: the same integration, across the drawn
		## duration instead of the flight's own.
		var end_before := end_after
		if display.has("launch_vertical_mps"):
			end_before = maxf(
				start_height + float(display.launch_vertical_mps) * drawn
					- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * drawn * drawn,
				BP.FLOOR_CONTACT_HEIGHT_METERS,
			)
		marks.append({
			"t": clock,
			"label": str(RallyEvent.EventType.keys()[int(event.event_type)]),
			"height": start_height,
		})
		for step in range(SAMPLES + 1):
			var fraction := float(step) / float(SAMPLES)
			var at := clock + fraction * drawn
			after.append(Vector2(
				at, BallFlightModel.height_between(
					start_height, end_after, drawn, fraction
				)
			))
			before.append(Vector2(
				at, BallFlightModel.height_between(
					start_height, end_before, drawn, fraction
				)
			))
			tallest = maxf(tallest, maxf(
				float(after[-1].y), float(before[-1].y)
			))
		clock += drawn
	if after.is_empty():
		push_error("no drawn legs for seed %d" % SEED)
		quit(1)
		return
	_write_svg(after, before, marks, clock, tallest)
	print("seed %d, %d contacts, %.2f s drawn, tallest %.2f m" % [
		SEED, contacts.size(), clock, tallest,
	])
	quit(0)


func _x(at: float, span: float) -> float:
	return PAD_LEFT + (at / maxf(span, 0.001)) * (WIDTH - PAD_LEFT - 24.0)


func _y(height: float, tallest: float) -> float:
	return HEIGHT - PAD_BOTTOM - (height / maxf(tallest, 0.1)) \
		* (HEIGHT - PAD_BOTTOM - PAD_TOP)


func _polyline(points: Array, span: float, tallest: float) -> String:
	var parts: PackedStringArray = []
	for point in points:
		parts.append("%.1f,%.1f" % [_x(float(point.x), span), _y(float(point.y), tallest)])
	return " ".join(parts)


func _write_svg(
	after: Array, before: Array, marks: Array, span: float, tallest: float
) -> void:
	var out := PackedStringArray()
	out.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" font-family="ui-sans-serif,system-ui,sans-serif">' % [
		int(WIDTH), int(HEIGHT), int(WIDTH), int(HEIGHT),
	])
	out.append('<rect width="100%" height="100%" fill="#12161c"/>')
	## Net height, because "did the ball clear the tape" is the first thing a
	## reader asks of a height plot.
	var net_y := _y(CourtConstants.NET_HEIGHT_METERS, tallest)
	out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#3d4756" stroke-dasharray="5 5"/>' % [
		PAD_LEFT, net_y, WIDTH - 24.0, net_y,
	])
	out.append('<text x="%.1f" y="%.1f" fill="#7c8896" font-size="11">net %.2f m</text>' % [
		PAD_LEFT + 4.0, net_y - 5.0, CourtConstants.NET_HEIGHT_METERS,
	])
	var floor_y := _y(0.0, tallest)
	out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#4a5565"/>' % [
		PAD_LEFT, floor_y, WIDTH - 24.0, floor_y,
	])
	out.append('<text x="14" y="%.1f" fill="#7c8896" font-size="11">floor</text>' % floor_y)
	for mark in marks:
		var mark_x := _x(float(mark["t"]), span)
		out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#2a3340"/>' % [
			mark_x, PAD_TOP, mark_x, floor_y,
		])
		out.append('<text x="%.1f" y="%.1f" fill="#8f9bab" font-size="10" transform="rotate(-90 %.1f %.1f)">%s</text>' % [
			mark_x + 3.0, floor_y - 6.0, mark_x + 3.0, floor_y - 6.0, str(mark["label"]),
		])
	out.append('<polyline fill="none" stroke="#c2603a" stroke-width="2" stroke-dasharray="6 4" points="%s"/>' % _polyline(before, span, tallest))
	out.append('<polyline fill="none" stroke="#37c2a8" stroke-width="2.5" points="%s"/>' % _polyline(after, span, tallest))
	out.append('<text x="%.1f" y="20" fill="#37c2a8" font-size="12">after — integrated across the flight\'s own duration</text>' % PAD_LEFT)
	out.append('<text x="%.1f" y="34" fill="#c2603a" font-size="12">before — integrated across the 0.08 s drawing floor</text>' % PAD_LEFT)
	out.append('<text x="%.1f" y="%.1f" fill="#7c8896" font-size="11">seed %d · %.2f s of drawn ball · height in metres</text>' % [
		PAD_LEFT, HEIGHT - 18.0, SEED, span,
	])
	out.append("</svg>")
	var path := "res://artifacts/m8-visual/ball_height_trace.svg"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		"res://artifacts/m8-visual"
	))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return
	file.store_string("\n".join(out))
	file.close()
	print("wrote %s" % path)
