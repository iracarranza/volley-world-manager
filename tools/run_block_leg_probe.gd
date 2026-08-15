extends SceneTree

## Where does the attack-to-block leg lose the net?
##
##     godot --headless --path . --script res://tools/run_block_leg_probe.gd
##
## `run_ball_flight_probe` found that 43 of 205 blocked swings are drawn crossing
## the tape below net height, and answered the one question it could: the
## resolver had cleared the net on 45 of the 46 flights it flagged, so the
## clearance is being lost between the solve and the drawing.
##
## That is as far as a summary can go. Reported per flight, the same defect has
## at least three candidate mechanisms and they call for different fixes:
##
##   * the leg is drawn to `(hitter.x, 0.50)` -- straight forward to the tape --
##     rather than to the point the swing's own line crosses it, so a
##     cross-court spike is drawn along a line it never took;
##   * the leg's duration is the parent's scaled by a *distance* ratio taken
##     between two points that are not both on the flight, so the share is not
##     the share of the flight that was flown;
##   * the far end is derived from the carried launch speed over that duration,
##     so any error in the duration lands on the height, and a height below the
##     floor is clamped to it -- which is what `-> 0.12 m` in the flight probe's
##     worst-five table is.
##
## So this prints the parts rather than the total, and beside them the same
## flight's *untruncated* arc measured at the tape. The full swing is what the
## resolver cleared; if it clears here too, the loss is entirely in the
## truncation and the fix belongs there rather than in the launch solve.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const RALLIES: int = 120
const NET_HEIGHT_METERS: float = CourtConstants.NET_HEIGHT_METERS


func _initialize() -> void:
	var cases: Array[Dictionary] = []
	var total := 0
	for serving_home in [true, false]:
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		for seed_value in range(7000, 7000 + RALLIES):
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			total += _collect(result, cases)
		manager.free()

	var under: Array[Dictionary] = []
	for case in cases:
		if float(case.tape) < NET_HEIGHT_METERS:
			under.append(case)

	print("=== attack -> block legs: %d, under the tape: %d ===" % [
		total, under.size(),
	])
	print("")
	print("`full tape` is the same swing measured before truncation -- the arc")
	print("the resolver actually cleared. `x drift` is how far the leg's drawn")
	print("end sits from where that arc crosses y = 0.50, in metres.")
	print("")
	print("%8s %8s %8s %8s %8s %8s %8s" % [
		"tape", "full tape", "x drift", "leg s", "true s", "swing s", "v0",
	])
	under.sort_custom(func(a, b): return float(a.tape) < float(b.tape))
	for index in range(mini(12, under.size())):
		var case: Dictionary = under[index]
		print("%8.2f %8.2f %8.2f %8.3f %8.3f %8.3f %8.2f" % [
			case.tape, case.full_tape, case.x_drift, case.leg_seconds,
			case.true_seconds, case.swing_seconds, case.launch_vertical,
		])

	print("")
	## **The split that decides which defect this is.** A block that never
	## touches the ball leaves the swing's own flight in place, so those legs are
	## the resolver's arc drawn honestly and a tape violation among them is the
	## *launch* being wrong. A block that touches re-slices the flight, and a
	## violation there is the *truncation* being wrong. Totalled together the two
	## are indistinguishable, which is how the first reading of this came out
	## backwards.
	var sliced: Array[Dictionary] = []
	var whole: Array[Dictionary] = []
	for case in cases:
		if bool(case.truncated):
			sliced.append(case)
		else:
			whole.append(case)
	_summarise("all attack -> block legs", cases)
	_summarise("re-sliced at the block (it touched the ball)", sliced)
	_summarise("left whole (the block missed)", whole)

	## And what the resolver thought it was swinging, for the legs that miss the
	## tape. `launch_mode` is the branch of the clearance search that answered;
	## `drawn angle` is the angle the drawing ended up with. Where they disagree
	## in sign, the certified launch was discarded on the way to the screen.
	print("what the resolver certified, against what was drawn")
	print("")
	print("%-12s %6s %8s %10s %10s %10s" % [
		"launch mode", "n", "cleared", "drawn angle", "at the tape", "apex m",
	])
	var by_mode := {}
	for entry in cases:
		var mode := str(entry.launch_mode)
		if not by_mode.has(mode):
			by_mode[mode] = []
		(by_mode[mode] as Array).append(entry)
	var modes := by_mode.keys()
	modes.sort()
	for mode in modes:
		var group: Array = by_mode[mode]
		var cleared := 0
		var angle := 0.0
		var tape_total := 0.0
		var below := 0
		for entry in group:
			if bool(entry.launch_cleared):
				cleared += 1
			angle += float(entry.drawn_angle)
			tape_total += float(entry.tape)
			if float(entry.tape) < NET_HEIGHT_METERS:
				below += 1
		var apex := 0.0
		## How many were drawn going *down* when the resolver said up. `_swing_arc`
		## carries the certified angle only when the drawn target is the resolver's
		## own; anything else re-solves a driven root, which is the shot the
		## clearance search had already rejected.
		var inverted := 0
		for entry in group:
			apex += float(entry.apex)
			if float(entry.drawn_angle) < 0.0 and mode.ends_with("lofted"):
				inverted += 1
		print("%-12s %6d %8d %10.1f %10.2f %10.2f   (under: %d, drawn down: %d)" % [
			mode if mode != "" else "(none)", group.size(), cleared,
			angle / float(group.size()), tape_total / float(group.size()),
			apex / float(group.size()), below, inverted,
		])
	quit()


func _summarise(title: String, cases: Array) -> void:
	if cases.is_empty():
		return
	var tape := 0.0
	var full_tape := 0.0
	var drift := 0.0
	var leg := 0.0
	var truth := 0.0
	var full_clears := 0
	var under := 0
	for case in cases:
		if float(case.tape) < NET_HEIGHT_METERS:
			under += 1
		tape += float(case.tape)
		full_tape += float(case.full_tape)
		drift += absf(float(case.x_drift))
		leg += float(case.leg_seconds)
		truth += float(case.true_seconds)
		if float(case.full_tape) >= NET_HEIGHT_METERS:
			full_clears += 1
	var n := float(cases.size())
	print("%s (%d, under the tape: %d)" % [title, cases.size(), under])
	print("  drawn at the tape      %6.2f m" % (tape / n))
	print("  untruncated at the tape %5.2f m   (clears: %d of %d)" % [
		full_tape / n, full_clears, cases.size(),
	])
	print("  drawn end vs crossing  %6.2f m of lateral drift" % (drift / n))
	print("  leg duration           %6.3f s  against %.3f s of real flight" % [
		leg / n, truth / n,
	])
	print("")


func _collect(result: Resource, cases: Array[Dictionary]) -> int:
	var contacts: Array = []
	for raw_event in result.events:
		var event: Resource = raw_event
		if int(event.event_type) in [
			RallyEventScript.EventType.SET_DECISION,
			RallyEventScript.EventType.POINT,
		]:
			continue
		contacts.append(event)
	var profiles: Dictionary = result.player_physical_profiles
	var counted := 0
	for index in range(contacts.size()):
		var event: Resource = contacts[index]
		if int(event.event_type) != RallyEventScript.EventType.ATTACK:
			continue
		var next_contact: Resource = contacts[index + 1] \
			if index + 1 < contacts.size() else null
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if trajectory.is_empty():
			continue
		var display := BallPresentation.display_trajectory(
			event, next_contact, trajectory, profiles
		)
		var tape := BallPresentation.net_crossing_height(display)
		if tape < 0.0:
			continue
		counted += 1

		## The same swing before anything shortened it: the hitter's contact, the
		## floor target the swing was aimed at, and the parent's own flight time,
		## which `_truncated_arc` carries forward precisely so this is answerable.
		var aimed := Vector2(event.end_position)
		var contact := Vector2(event.start_position)
		var swing_seconds := maxf(float(
			trajectory.get("swing_duration_seconds", trajectory.get("duration", 0.5))
		), 0.02)
		var launch_vertical := float(trajectory.get("launch_vertical_mps", NAN))
		var start_height := BallPresentation.contact_height(event, profiles)

		## Where the swing's own line crosses the tape, and when. Horizontal
		## motion is uniform, so the share of the flight is the share of the
		## distance along that line -- which is what the leg's duration should be
		## and is not.
		var share := 0.0
		if absf(aimed.y - contact.y) > 0.00001:
			share = clampf((0.5 - contact.y) / (aimed.y - contact.y), 0.0, 1.0)
		var crossing := contact.lerp(aimed, share)
		var true_seconds := swing_seconds * share
		var full_tape := start_height
		if not is_nan(launch_vertical):
			full_tape = start_height + launch_vertical * true_seconds \
				- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 \
				* true_seconds * true_seconds

		cases.append({
			"tape": tape,
			"full_tape": full_tape,
			"x_drift": (float(Vector2(display.get(
				"end_position", crossing
			)).x) - crossing.x) * 9.0,
			"leg_seconds": float(display.get("duration", 0.0)),
			"true_seconds": true_seconds,
			"swing_seconds": swing_seconds,
			"launch_vertical": 0.0 if is_nan(launch_vertical) else launch_vertical,
			"apex": float(display.get("apex_height_meters", 0.0)),
			"met_block": next_contact != null and int(
				next_contact.event_type
			) == RallyEventScript.EventType.BLOCK,
			"truncated": str(
				trajectory.get("trajectory_type", "")
			) == "attack_to_block",
			## What the resolver said it was swinging, against what the drawing
			## swung. `_swing_arc` carries the resolver's cleared angle only for a
			## downward one, and re-solves a driven root otherwise -- so a lofted
			## launch that was certified over the tape is drawn as a flat one that
			## was not, and these two columns are where that shows.
			"launch_mode": "%s/%s" % [
				str(event.metadata.get("side", "?")),
				str(event.metadata.get("launch_mode", "")),
			],
			"launch_cleared": bool(event.metadata.get("launch_cleared", true)),
			"drawn_angle": rad_to_deg(atan2(
				0.0 if is_nan(launch_vertical) else launch_vertical,
				maxf(RallyKinematics.court_distance_meters(contact, aimed)
					/ swing_seconds, 0.01),
			)),
		})
	return counted
