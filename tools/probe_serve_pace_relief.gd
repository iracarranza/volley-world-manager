extends SceneTree

## Where inside its own range does the serve's pace sweep actually stop?
##
## `GeometricAttackResolver._serve_launch` sweeps pace downward from what the
## server can generate to `BallFlightModel.minimum_speed_to_reach` -- the slowest
## ball that carries to the aim at *any* angle -- and keeps the fastest candidate
## that clears the tape by the margin its own execution spread demands. Two
## quantities decide the shot and only one of them is a decision:
##
##   full     ceiling x intent x technique. Serve power, serve technique and the
##            bench's aggression all arrive here and nowhere else.
##   floor    a property of the geometry alone: aim distance, contact height and
##            the candidate's gravity. Every server has the same one.
##
## So `(chosen - floor) / (full - floor)` is where in its stated range the knob
## settled, and it is the whole question. Near 1 the serve is the ball the server
## chose. Near 0 it is the maximum-range launch -- by construction the slowest
## and highest arc that reaches at all -- and the server's attributes were spent
## on nothing.
##
## Read from `result.analysis`, which is the launch the rally flew, so a figure
## here is a figure the game served.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const AttackPowerModel := preload("res://scripts/simulation/attack_power_model.gd")
const GeometricAttackPromotionModel := preload(
	"res://scripts/simulation/geometric_attack_promotion.gd"
)

const RALLIES: int = 240
## Inside this much of the floor, the sweep ran out rather than chose.
const AT_THE_FLOOR_MPS: float = 0.75


func _initialize() -> void:
	var rows: Array = []
	for side in range(2):
		for index in range(RALLIES / 2):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(980000 + index)
			if result == null:
				continue
			var serve_event: RallyEvent = null
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event != null \
						and int(event.event_type) == RallyEvent.EventType.SERVE:
					serve_event = event
					break
			if serve_event == null:
				continue
			var analysis: Dictionary = {}
			for key in ["geometric_serve_home", "geometric_serve_opponent"]:
				if result.analysis.has(key):
					analysis = Dictionary(result.analysis[key])
			if analysis.is_empty():
				continue
			var server := _server_for(manager, result, serve_event)
			if server == null:
				continue
			## The two ends of the sweep, rebuilt the way `_serve_launch` builds
			## them. `intent` is read off the resolver's own lerp rather than
			## re-guessed, and the risk it takes is unknown here -- so both ends of
			## the intent band are reported and the *widest* range is used, which
			## can only understate how far down the sweep went.
			var contact_height: float = \
				GeometricAttackPromotionModel.serve_contact_height_meters(
					server,
					GeometricAttackPromotionModel.serve_effort_for_style(
						str(server.primary_serve_style)
					),
				)
			var ceiling: float = AttackPowerModel.serve_ceiling_mps(
				_rating(server, "serve_power")
			)
			var technique := lerpf(0.82, 1.0, _rating(server, "serve_technique"))
			## **Both ends of the intent band, because the risk this serve was
			## struck at is not published.** `_serve_launch` is handed
			## `ceiling * lerp(CONTROL_INTENT, DRIVE_INTENT, risk) * technique`,
			## and asserting one value for `risk` would be inventing the very
			## quantity the fraction is measuring against. Reporting both bounds
			## makes the fraction an interval that is honestly wide rather than a
			## point estimate that is quietly wrong.
			var full := ceiling * AttackPowerModel.DRIVE_INTENT * technique
			var full_control := ceiling * AttackPowerModel.CONTROL_INTENT * technique
			var distance := RallyKinematics.court_distance_meters(
				Vector2(serve_event.start_position),
				Vector2(serve_event.end_position),
			)
			## The default-gravity floor. A brushed candidate falls harder and has
			## a higher floor still, so this is the most generous reading.
			var floor_speed := float(BallFlightModel.minimum_speed_to_reach(
				distance, contact_height
			).speed_mps)
			var chosen := float(analysis.get("speed_mps", 0.0))
			var span := maxf(full - floor_speed, 0.0001)
			var span_control := maxf(full_control - floor_speed, 0.0001)
			rows.append({
				"mode": str(analysis.get("launch_mode", "?")),
				"power": _rating(server, "serve_power"),
				"full": full,
				"full_control": full_control,
				"floor": floor_speed,
				"chosen": chosen,
				"fraction": clampf((chosen - floor_speed) / span, -1.0, 2.0),
				"fraction_control": clampf(
					(chosen - floor_speed) / span_control, -1.0, 2.0
				),
				"over_floor": chosen - floor_speed,
				"distance": distance,
				"clearance": float(analysis.get("net_clearance_meters", 0.0)),
			})
	_report(rows)
	quit(0)


## The resolver's own reading of an attribute, so the reconstruction below is the
## same arithmetic the launch search ran rather than a second opinion about it.
static func _rating(player: VolleyballPlayer, key: String) -> float:
	return clampf(float(player.get(key)) / 100.0, 0.0, 1.0)


## The voli who struck it, found through the same rosters the rally used.
func _server_for(
	manager, result: Resource, serve_event: RallyEvent
) -> VolleyballPlayer:
	var wanted := int(serve_event.actor_id)
	for player in manager.players:
		if int(player.id) == wanted:
			return player
	if manager.opponent_team != null:
		for player in manager.opponent_team.players:
			if int(player.id) == wanted:
				return player
	## The event names the server; if the rosters do not, say so rather than
	## substituting a body and reporting its attributes as the server's.
	push_warning("serve %d has no roster body in %s" % [wanted, str(result)])
	return null


func _report(rows: Array) -> void:
	if rows.is_empty():
		print("no serves measured")
		return
	print("-- where in its own range the serve's pace sweep stopped --")
	print("%-10s %5s %8s %8s %8s %14s %9s %9s" % [
		"mode", "n", "mean full", "mean flr", "mean got", "mean frac",
		"at floor", "mean clear",
	])
	var by_mode := {}
	for row in rows:
		var key := str(row["mode"])
		if not by_mode.has(key):
			by_mode[key] = []
		by_mode[key].append(row)
	var keys: Array = by_mode.keys()
	keys.sort()
	for key in keys:
		var group: Array = by_mode[key]
		var full := 0.0
		var floor_total := 0.0
		var chosen := 0.0
		var fraction := 0.0
		var fraction_control := 0.0
		var clearance := 0.0
		var at_floor := 0
		for row in group:
			full += float(row["full"])
			floor_total += float(row["floor"])
			chosen += float(row["chosen"])
			fraction += float(row["fraction"])
			fraction_control += float(row["fraction_control"])
			clearance += float(row["clearance"])
			if float(row["over_floor"]) <= AT_THE_FLOOR_MPS:
				at_floor += 1
		var n := float(group.size())
		print("%-10s %5d %8.2f %8.2f %8.2f  %.3f-%.3f %9d %9.2f" % [
			key, group.size(), full / n, floor_total / n, chosen / n,
			fraction / n, fraction_control / n, at_floor, clearance / n,
		])
	print("")
	print("frac    = (chosen - floor) / (full - floor), given as the interval the")
	print("          unpublished tactical risk leaves it in: the low end assumes")
	print("          every serve was struck at full drive intent, the high end at")
	print("          full control intent. 1 is the ball the server chose; 0 is the")
	print("          maximum-range launch, which is the slowest and highest arc")
	print("          that reaches the aim at all.")
	print("at flr  = serves delivered within %.2f m/s of that floor." % AT_THE_FLOOR_MPS)
	print("")
	## **Does the server's own power reach the ball?** The floor is a property of
	## the geometry and every server shares it, so if the sweep runs to the floor
	## the delivered pace is the same whoever served. Grouping by the attribute is
	## the direct test, and it needs no correlation coefficient to read.
	print("-- delivered pace against the attribute that is supposed to set it --")
	print("%-14s %6s %10s %10s %10s" % [
		"serve_power", "n", "mean full", "mean got", "mean over flr",
	])
	var bands := {"0.00-0.40": [], "0.40-0.55": [], "0.55-0.70": [], "0.70-1.00": []}
	for row in rows:
		var power := float(row["power"])
		var band := "0.70-1.00"
		if power < 0.40:
			band = "0.00-0.40"
		elif power < 0.55:
			band = "0.40-0.55"
		elif power < 0.70:
			band = "0.55-0.70"
		bands[band].append(row)
	for band in ["0.00-0.40", "0.40-0.55", "0.55-0.70", "0.70-1.00"]:
		var group: Array = bands[band]
		if group.is_empty():
			print("%-14s %6d %10s %10s %10s" % [band, 0, "--", "--", "--"])
			continue
		var full := 0.0
		var chosen := 0.0
		var over := 0.0
		for row in group:
			full += float(row["full"])
			chosen += float(row["chosen"])
			over += float(row["over_floor"])
		var n := float(group.size())
		print("%-14s %6d %10.2f %10.2f %10.2f" % [
			band, group.size(), full / n, chosen / n, over / n,
		])
