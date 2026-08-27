extends SceneTree

## How high does the serve actually go, and how much of that is the drawing?
##
## The seam probes certify that each leg's endpoint height equals the next
## contact's. That says nothing about the shape in between, and a serve reported
## as "teleporting down onto" its receiver is a complaint about the shape.
##
## Two figures, and they are separable:
##
##   apex        the highest the *drawn* ball gets, sampled through the same
##               `BallFlightModel.height_between` the court walks each frame. A
##               serve contacted at 2.60 m has a real-world apex around 3.3 m;
##               well above that is a lob wearing a serve's name.
##   inflation   the same leg redrawn ending on the floor, which is where the
##               serve's own flight solves to. `_canonical_serve` takes its
##               duration as the time to that floor landing, and the drawn leg is
##               then made to end at the *receiver's* contact height over the
##               same duration -- so the curve is handed rise the flight never
##               had. The difference is how much of the arc the drawing added.
##
## Read from published metadata and the shipped `BallPresentation` call, so a
## number here is a number the game draws.
##
## See `docs/review/SERVE_ARC_AUTHORITY.md`.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload(
	"res://scripts/simulation/ball_presentation.gd"
)
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

const RALLIES: int = 120


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
			var profiles: Dictionary = result.player_physical_profiles
			var contacts: Array = []
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) in [
					RallyEvent.EventType.POINT,
					RallyEvent.EventType.SET_DECISION,
				]:
					continue
				contacts.append(event)
			for position in range(contacts.size()):
				var event: RallyEvent = contacts[position]
				if int(event.event_type) != RallyEvent.EventType.SERVE:
					continue
				var next_contact: RallyEvent = contacts[position + 1] \
					if position + 1 < contacts.size() else null
				var trajectory: Dictionary = event.metadata.get(
					"outgoing_trajectory", {}
				)
				if trajectory.is_empty():
					continue
				var display: Dictionary = BallPresentationScript.display_trajectory(
					event, next_contact, trajectory, profiles
				)
				var dur := float(display.get("duration", 0.0))
				var sh := float(display.get("start_height_meters", 1.0))
				var eh := float(display.get("end_height_meters", 1.0))
				var metres := RallyKinematics.court_delta_meters(
					Vector2(event.start_position), Vector2(event.end_position)
				).length()
				## The drawn curve's own apex, sampled the way the court samples it.
				var apex := -INF
				for step in range(41):
					apex = maxf(apex, BallFlightModel.height_between(
						sh, eh, dur, float(step) / 40.0
					))
				var analysis: Dictionary = {}
				for key in ["geometric_serve_home", "geometric_serve_opponent"]:
					if result.analysis.has(key):
						analysis = Dictionary(result.analysis[key])
				## The same leg drawn to the height the serve's own flight solves
				## to. `_canonical_serve` takes its duration as the time to the
				## *floor* landing, so at that moment the ball is on the floor --
				## and the drawn leg is made to end at the receiver's contact
				## height instead, over the same duration. The difference is the
				## rise the drawing adds that the flight never had.
				var true_apex := -INF
				for step in range(41):
					true_apex = maxf(true_apex, BallFlightModel.height_between(
						sh, 0.0, dur, float(step) / 40.0
					))
				rows.append({
					"true_apex": true_apex,
					"mode": str(analysis.get("launch_mode", "?")),
					"launch_speed": float(analysis.get("speed_mps", -1.0)),
					"clearance": float(analysis.get("net_clearance_meters", -1.0)),
					"kind": str(trajectory.get("kind", "?")),
					"dur": dur,
					"traj_dur": float(trajectory.get("flight_time_seconds", -1.0)),
					"m": metres,
					"speed": metres / maxf(dur, 0.001),
					"sh": sh,
					"eh": eh,
					"apex": apex,
					"next": str(RallyEvent.EventType.keys()[
						int(next_contact.event_type)
					]) if next_contact != null else "floor",
					"cont": event.metadata.has("continuous_reception_timing"),
				})
	_report(rows)
	quit(0)


func _report(rows: Array) -> void:
	print("serve legs: %d" % rows.size())
	var by_next := {}
	for row in rows:
		var key: String = "%s%s" % [
			str(row["mode"]), " (retimed)" if bool(row["cont"]) else "",
		]
		if not by_next.has(key):
			by_next[key] = []
		by_next[key].append(row)
	var keys: Array = by_next.keys()
	keys.sort()
	print("%-22s %5s %8s %8s %8s %8s %8s %8s" % [
		"launch mode", "n", "mean s", "max s", "mean m/s", "min m/s",
		"mean apex", "max apex",
	])
	for key in keys:
		var group: Array = by_next[key]
		var dur_total := 0.0
		var dur_max := 0.0
		var speed_total := 0.0
		var speed_min := INF
		var apex_total := 0.0
		var apex_max := 0.0
		for row in group:
			dur_total += float(row["dur"])
			dur_max = maxf(dur_max, float(row["dur"]))
			speed_total += float(row["speed"])
			speed_min = minf(speed_min, float(row["speed"]))
			apex_total += float(row["apex"])
			apex_max = maxf(apex_max, float(row["apex"]))
		var n := float(group.size())
		print("%-22s %5d %8.3f %8.3f %8.2f %8.2f %8.2f %8.2f" % [
			key, group.size(), dur_total / n, dur_max, speed_total / n,
			speed_min, apex_total / n, apex_max,
		])
	var inflation := 0.0
	var inflation_worst := 0.0
	var end_total := 0.0
	for row in rows:
		var delta := float(row["apex"]) - float(row["true_apex"])
		inflation += delta
		inflation_worst = maxf(inflation_worst, delta)
		end_total += float(row["eh"])
	print("")
	print("drawn apex - apex of the same leg ending on the floor:")
	print("  mean %.3f m, worst %.3f m, over %d legs (mean drawn end %.3f m)" % [
		inflation / float(rows.size()), inflation_worst, rows.size(),
		end_total / float(rows.size()),
	])
	print("")
	print("-- the ten tallest drawn serves --")
	rows.sort_custom(func(a, b): return float(a["apex"]) > float(b["apex"]))
	print("%-10s %7s %8s %8s %8s %7s %7s %8s  %s" % [
		"mode", "launch", "dur", "clear", "metres", "start", "end", "apex", "next",
	])
	for index in range(mini(10, rows.size())):
		var row: Dictionary = rows[index]
		print("%-10s %7.2f %8.3f %8.2f %8.2f %7.2f %7.2f %8.2f  %s%s" % [
			str(row["mode"]), float(row["launch_speed"]), float(row["dur"]),
			float(row["clearance"]),
			float(row["m"]), float(row["sh"]), float(row["eh"]),
			float(row["apex"]), str(row["next"]),
			" (retimed)" if bool(row["cont"]) else "",
		])
