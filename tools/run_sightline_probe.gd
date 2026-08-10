extends SceneTree

## Who does the block actually hide the ball from, and does standing wide help?
##
##     godot --headless --path . --script res://tools/run_sightline_probe.gd
##
## `PlayerSightlineSystem`'s own docstring makes a falsifiable claim -- *"it is
## geometry, not a block-strategy bonus, and can therefore differ for two
## defenders behind one wall"* -- and a screenshot says otherwise: a defender
## standing in the cross lane, nowhere near the line the block was shutting,
## drew the lost-sight marker anyway.
##
## So the quantity to measure is not the occlusion rate but **whether standing
## wide of the block changes the verdict at all**, and -- because a rate can be
## right for the wrong reason -- where in the flight and at what depth past the
## tape the wall was credited with hiding the ball. A wall that hides a ball
## still level with its own hands is not casting a shadow, it is standing next to
## one.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const SightlineModel := preload("res://scripts/simulation/player_sightline_system.gd")

const RALLIES: int = 200
const FIRST_SEED: int = 9100
const COURT_WIDTH_METERS: float = 9.0


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			_collect(result, rows)
		manager.free()

	if rows.is_empty():
		print("no attack/block/defence triples sampled")
		quit()
		return

	var occluded := 0
	var partial := 0
	for row in rows:
		if str(row.visibility) == "occluded":
			occluded += 1
		elif str(row.visibility) == "partially_obscured":
			partial += 1
	print("=== %d swings with a block and a following dig ===" % rows.size())
	print("  visible            %5d  %.3f" % [
		rows.size() - occluded - partial,
		float(rows.size() - occluded - partial) / float(rows.size()),
	])
	print("  partially obscured %5d  %.3f" % [
		partial, float(partial) / float(rows.size())
	])
	print("  occluded           %5d  %.3f" % [
		occluded, float(occluded) / float(rows.size())
	])
	print("")

	## **Does standing wide of the block help?** The question the screenshot
	## asked, put directly. The lateral band the wall hides is *not* the right
	## instrument for it, and measuring that first was itself a small §0 mistake:
	## the shadow of a block is a narrow cone in *time*, not a lane on the floor,
	## and while the ball is inside it no one on the court can see it. What
	## separates one defender from another is when the ball comes back out
	## relative to when it reaches them -- a defender in the shot's lane gets it
	## back with nothing left to run, a cross defender with the whole crosscourt
	## flight. So the table is by offset, and the verdict is what has to move.
	print("occlusion by how wide the defender stood of the blocker")
	print("  %-16s %6s %9s %9s %9s" % [
		"offset, metres", "n", "visible", "partial", "occluded",
	])
	_by_offset_band(rows, 0.0, 1.5)
	_by_offset_band(rows, 1.5, 3.0)
	_by_offset_band(rows, 3.0, 99.0)
	print("")
	var offsets: Array[float] = []
	for row in rows:
		if str(row.visibility) == "visible":
			continue
		offsets.append(float(row.observer_offset_meters))
	if offsets.is_empty():
		print("  nothing hidden at all")
		quit()
		return
	offsets.sort()
	print("  offset of the defenders who did lose it, metres:")
	print("                    p10 %5.2f  p50 %5.2f  p90 %5.2f" % [
		_at(offsets, 0.10), _at(offsets, 0.50), _at(offsets, 0.90),
	])
	print("")

	## Where in the flight the wall takes the ball. A wall hides a spike for the
	## instant it passes the hands; if the hidden samples are all at the very
	## start of the flight, the geometry is degenerate rather than physical --
	## the ball is *at* the net plane, so every ray to it grazes the hands.
	var starts: Array[float] = []
	var ends: Array[float] = []
	var net_heights: Array[float] = []
	for row in rows:
		if str(row.visibility) == "visible":
			continue
		starts.append(float(row.first_hidden_progress))
		ends.append(float(row.last_hidden_progress))
		net_heights.append(float(row.ball_height_at_net))
	starts.sort()
	ends.sort()
	net_heights.sort()
	print("where in the flight the ball is hidden, as a share of it")
	print("  first hidden sample  p10 %5.3f  p50 %5.3f  p90 %5.3f" % [
		_at(starts, 0.10), _at(starts, 0.50), _at(starts, 0.90),
	])
	print("  last hidden sample   p10 %5.3f  p50 %5.3f  p90 %5.3f" % [
		_at(ends, 0.10), _at(ends, 0.50), _at(ends, 0.90),
	])
	print("  ball height crossing the net, metres")
	print("                       p10 %5.2f  p50 %5.2f  p90 %5.2f" % [
		_at(net_heights, 0.10), _at(net_heights, 0.50), _at(net_heights, 0.90),
	])
	print("")

	## Whether the wall is hiding a ball that is actually behind it. The ray is
	## crossed with a plane and asked whether it lands on a blocker, so the closer
	## the ball sits to that plane the closer the crossing point is to the ball
	## itself and the less the observer's own position can contribute. At the
	## limit the test stops being a sightline at all and becomes "is the ball near
	## the wall", which is true from everywhere at once. The depth column is the
	## guard against that: every hidden sample should be past the blocker's reach,
	## not inside it.
	var depths: Array[float] = []
	var fractions: Array[float] = []
	for row in rows:
		for depth in row.hidden_sample_depths:
			depths.append(float(depth))
		for fraction in row.hidden_sample_fractions:
			fractions.append(float(fraction))
	if not depths.is_empty():
		depths.sort()
		fractions.sort()
		print("the %d individual samples the wall hid" % depths.size())
		print("  ball's distance past the net, metres")
		print("                       p10 %5.2f  p50 %5.2f  p90 %5.2f" % [
			_at(depths, 0.10), _at(depths, 0.50), _at(depths, 0.90),
		])
		print("  ray fraction (1.0 = the crossing point *is* the ball)")
		print("                       p10 %5.3f  p50 %5.3f  p90 %5.3f" % [
			_at(fractions, 0.10), _at(fractions, 0.50), _at(fractions, 0.90),
		])
		print("")

	## And the direct question the screenshot asks: of the swings this defender
	## was hidden from, how many were they *wide* of the block for?
	var wide_hidden := 0
	var wide_total := 0
	for row in rows:
		if float(row.observer_offset_meters) < 1.5:
			continue
		wide_total += 1
		if str(row.visibility) != "visible":
			wide_hidden += 1
	if wide_total > 0:
		print("defenders standing more than 1.5 m off the blocker's line:")
		print("  %d of %d lost the ball anyway (%.3f)" % [
			wide_hidden, wide_total, float(wide_hidden) / float(wide_total),
		])
	quit()


func _by_offset_band(rows: Array, from: float, to: float) -> void:
	var counts := {"visible": 0, "partially_obscured": 0, "occluded": 0}
	var total := 0
	for row in rows:
		var offset := float(row.observer_offset_meters)
		if offset < from or offset >= to:
			continue
		total += 1
		counts[str(row.visibility)] = int(counts[str(row.visibility)]) + 1
	if total == 0:
		return
	print("  %-16s %6d %9.3f %9.3f %9.3f" % [
		"%.1f to %.1f" % [from, minf(to, 9.0)], total,
		float(counts.visible) / float(total),
		float(counts.partially_obscured) / float(total),
		float(counts.occluded) / float(total),
	])


func _at(sorted_values: Array, quantile: float) -> float:
	return float(sorted_values[clampi(
		int(floor(quantile * float(sorted_values.size() - 1))),
		0, sorted_values.size() - 1,
	)])


func _collect(result: Resource, rows: Array[Dictionary]) -> void:
	var events: Array = result.events
	for index in range(events.size()):
		var event: Resource = events[index]
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var raw: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if raw.is_empty():
			continue
		var block_event: Resource = null
		var defence: Resource = null
		var next_contact: Resource = null
		for forward in range(index + 1, mini(index + 4, events.size())):
			var candidate: Resource = events[forward]
			if next_contact == null and int(candidate.actor_id) >= 0:
				next_contact = candidate
			if int(candidate.event_type) == RallyEventScript.EventType.BLOCK \
					and block_event == null:
				block_event = candidate
			elif int(candidate.event_type) == RallyEventScript.EventType.DEFENSE \
					and defence == null:
				defence = candidate
		## Touched blocks are out for the same reason the compiler drops them: the
		## flight ends at the hands, so its tail is behind them by construction.
		if block_event == null or defence == null or bool(block_event.success):
			continue
		## The drawn flight, for the same reason the compiler uses it: a raw
		## trajectory's contact heights are the 1.0 placeholder every one of them
		## carries, and this whole probe is about height.
		var trajectory := BallPresentation.display_trajectory(
			event, next_contact, raw, result.player_physical_profiles
		)
		var observer := Vector2(defence.metadata.get(
			"movement_start", defence.start_position
		))
		var profiles: Dictionary = result.player_physical_profiles
		var observer_profile: Dictionary = profiles.get(
			int(defence.actor_id), {}
		)
		var eye := {
			"eye_height_meters": float(
				observer_profile.get("height_cm", 188.0)
			) / 100.0 - 0.10,
		}
		var blocker_top: float = BallPresentation.contact_height(
			block_event, profiles
		)
		var window: Dictionary = SightlineModel.occlusion_window(
			observer, trajectory, block_event, eye, blocker_top
		)
		var visibility := str(SightlineModel.visibility_for(window))

		var blocker_x := float(Vector2(block_event.metadata.get(
			"primary_position", Vector2(block_event.start_position.x, 0.5)
		)).x)
		## Re-walk the samples the system hid, recording where the ball was when
		## it happened. The system publishes only a count, and the count cannot
		## distinguish a ball genuinely behind a wall from one level with it.
		var hidden_depths: Array[float] = []
		var hidden_fractions: Array[float] = []
		if visibility != "visible":
			_walk_hidden_samples(
				observer, trajectory, block_event,
				float(eye.eye_height_meters), blocker_top,
				hidden_depths, hidden_fractions,
			)
		rows.append({
			"hidden_sample_depths": hidden_depths,
			"hidden_sample_fractions": hidden_fractions,
			"visibility": visibility,
			"hidden_fraction": float(window.get("hidden_fraction", 0.0)),
			"observer_offset_meters": absf(observer.x - blocker_x)
				* COURT_WIDTH_METERS,
			"first_hidden_progress": _progress_of(window, trajectory, "starts_at"),
			"last_hidden_progress": _progress_of(window, trajectory, "ends_at"),
			"ball_height_at_net": _height_at_net(trajectory),
		})


## The same sweep the system runs, with the samples it hid recorded rather than
## counted. Reaches for the `_`-prefixed helpers deliberately: reimplementing the
## test here would measure my copy of it instead of the one that shipped.
func _walk_hidden_samples(
	observer: Vector2,
	trajectory: Dictionary,
	block_event: Resource,
	eye_height: float,
	blocker_top: float,
	depths: Array[float],
	fractions: Array[float],
) -> void:
	for sample_index in range(SightlineModel.SAMPLE_COUNT + 1):
		var progress := float(sample_index) / float(SightlineModel.SAMPLE_COUNT)
		var ball := SightlineModel._trajectory_position(trajectory, progress)
		if not SightlineModel._sample_is_hidden(
			observer, ball, SightlineModel._trajectory_height(trajectory, progress),
			block_event, eye_height, blocker_top,
		):
			continue
		depths.append(absf(ball.y - 0.5) * 18.0)
		fractions.append((0.5 - observer.y) / (ball.y - observer.y))


func _progress_of(
	window: Dictionary, trajectory: Dictionary, key: String
) -> float:
	if not window.has(key):
		return -1.0
	var start_time := float(trajectory.get("start_time", 0.0))
	var duration := maxf(float(trajectory.get("duration", 0.0)), 0.01)
	return clampf((float(window[key]) - start_time) / duration, 0.0, 1.0)


## Where the ball is when it passes the tape, which decides whether the wall was
## ever in a position to hide anything.
##
## Walks the curve rather than interpolating between its endpoints. A drawn
## flight is a quadratic Bezier and its control point pulls the ball off the
## straight line between contact and landing, so a linear crossing fraction is
## simply a different flight -- and reading one out of it reported half the
## swings passing the net at 1.18 m, which would have been a serious defect if it
## had been true of anything but the measurement.
func _height_at_net(trajectory: Dictionary) -> float:
	for sample_index in range(SightlineModel.SAMPLE_COUNT + 1):
		var progress := float(sample_index) / float(SightlineModel.SAMPLE_COUNT)
		var here := SightlineModel._trajectory_position(trajectory, progress)
		if sample_index > 0:
			var before := SightlineModel._trajectory_position(
				trajectory, progress - 1.0 / float(SightlineModel.SAMPLE_COUNT)
			)
			if (before.y - 0.5) * (here.y - 0.5) <= 0.0:
				return SightlineModel._trajectory_height(trajectory, progress)
	return -1.0
