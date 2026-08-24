extends SceneTree

## Three numbers claim to be the ball's height at a contact. Which is physics?
##
## §5 says the incoming segment's far end, the contact, and the outgoing
## segment's start are one point. Three published quantities offer to be it, and
## they are not the same kind of claim:
##
##   flown    the incoming flight's launch state integrated across the time it
##            actually flew -- the ball's own trajectory evaluated at the moment
##            of contact, and the only one derived from the incoming ball
##   launch   the contact's own outgoing flight `start_height_meters`, which is
##            the resolver's statement about where it launched from
##   body     `GeometricAttackPromotion`'s reach/platform/hip for this actor,
##            which is what playback drew before any of this
##
## `flown` is the incoming ball; `launch` is the outgoing one. Where they agree
## the contact is coherent. Where they do not, one of them is a body measurement
## wearing a flight's clothes, and this says which family and by how much.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload(
	"res://scripts/simulation/ball_presentation.gd"
)
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")

const RALLIES: int = 200


func _initialize() -> void:
	var rows := {}
	for side in range(2):
		for index in range(RALLIES / 2):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(950000 + index)
			if result == null:
				continue
			var profiles: Dictionary = result.player_physical_profiles
			var contacts: Array = []
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) == RallyEvent.EventType.POINT:
					continue
				contacts.append(event)
			for position in range(1, contacts.size()):
				var event: RallyEvent = contacts[position]
				var previous: RallyEvent = contacts[position - 1]
				var incoming: Dictionary = previous.metadata.get(
					"outgoing_trajectory", {}
				)
				var outgoing: Dictionary = event.metadata.get(
					"outgoing_trajectory", {}
				)
				if incoming.is_empty():
					continue
				var family := str(
					RallyEvent.EventType.keys()[int(event.event_type)]
				)
				if not rows.has(family):
					rows[family] = {
						"n": 0, "flown": 0, "launch": 0,
						"fl": 0.0, "fb": 0.0, "lb": 0.0,
						"fl_worst": 0.0,
					}
				var row: Dictionary = rows[family]
				## The incoming ball, evaluated where it was touched.
				var flown := NAN
				if incoming.has("launch_vertical_mps") \
					and str(incoming.get("height_source", "default")) in [
						"resolved", "start_resolved"
					]:
					var t := maxf(float(incoming.get(
						"physical_duration_seconds",
						float(incoming.get("duration", 0.0)),
					)), 0.0)
					flown = float(incoming.get("start_height_meters", 1.0)) \
						+ float(incoming["launch_vertical_mps"]) * t \
						- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * t * t
				## The incoming flight evaluated at *this contact's own stamp*,
				## rather than at the flight's far end. The distinction is the
				## whole of the serve's case: the flight runs on to where the
				## ball would land, and the pass happens partway along it.
				var timed := NAN
				var t_start := float(incoming.get("start_time", NAN))
				var t_contact := float(event.metadata.get(
					"physical_time", event.metadata.get("event_time", NAN)
				))
				if incoming.has("launch_vertical_mps") 					and str(incoming.get("height_source", "default")) in [
						"resolved", "start_resolved"
					] and not is_nan(t_start) and not is_nan(t_contact):
					var dt := clampf(
						t_contact - t_start, 0.0,
						float(incoming.get("duration", 0.0)),
					)
					timed = float(incoming.get("start_height_meters", 1.0)) 						+ float(incoming["launch_vertical_mps"]) * dt 						- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * dt * dt
				if not is_nan(timed):
					row["timed"] = int(row.get("timed", 0)) + 1
					row["tsum"] = float(row.get("tsum", 0.0)) + timed
					row["tmin"] = minf(float(row.get("tmin", 99.0)), timed)
					row["tmax"] = maxf(float(row.get("tmax", -99.0)), timed)
				var launch := NAN
				if str(outgoing.get("height_source", "default")) in [
					"resolved", "start_resolved"
				]:
					launch = float(outgoing.get("start_height_meters", 1.0))
				var body := BallPresentationScript.contact_height(event, profiles)
				row["n"] = int(row["n"]) + 1
				if not is_nan(flown):
					row["fsum"] = float(row.get("fsum", 0.0)) + flown
					row["fmin"] = minf(float(row.get("fmin", 99.0)), flown)
					row["fmax"] = maxf(float(row.get("fmax", -99.0)), flown)
					row["bsum"] = float(row.get("bsum", 0.0)) + body
				if not is_nan(flown):
					row["flown"] = int(row["flown"]) + 1
				if not is_nan(launch):
					row["launch"] = int(row["launch"]) + 1
				if not is_nan(flown) and not is_nan(launch):
					var d := absf(flown - launch)
					row["fl"] = float(row["fl"]) + d
					row["fl_worst"] = maxf(float(row["fl_worst"]), d)
				if not is_nan(flown):
					row["fb"] = float(row["fb"]) + absf(flown - body)
				if not is_nan(launch):
					row["lb"] = float(row["lb"]) + absf(launch - body)
	print("%-16s %5s %6s %7s %11s %11s %11s %10s" % [
		"family", "legs", "flown", "launch", "|flown-lau|", "|flown-body|",
		"|lau-body|", "worst f-l",
	])
	var keys: Array = rows.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = rows[key]
		var flown := maxi(int(row["flown"]), 1)
		var launch := maxi(int(row["launch"]), 1)
		var both := maxi(mini(int(row["flown"]), int(row["launch"])), 1)
		print("%-16s %5d %6d %7d %11.3f %11.3f %11.3f %10.3f" % [
			str(key), int(row["n"]), int(row["flown"]), int(row["launch"]),
			float(row["fl"]) / float(both), float(row["fb"]) / float(flown),
			float(row["lb"]) / float(launch), float(row["fl_worst"]),
		])
	print("")
	print("%-16s %10s %10s %10s %10s" % [
		"family", "mean flown", "min flown", "max flown", "mean body",
	])
	for key in keys:
		var row: Dictionary = rows[key]
		if int(row["flown"]) == 0:
			continue
		var n := float(int(row["flown"]))
		print("%-16s %10.3f %10.3f %10.3f %10.3f" % [
			str(key), float(row.get("fsum", 0.0)) / n,
			float(row.get("fmin", 0.0)), float(row.get("fmax", 0.0)),
			float(row.get("bsum", 0.0)) / n,
		])
	print("")
	print("%-16s %8s %11s %10s %10s" % [
		"family", "timed n", "mean timed", "min timed", "max timed",
	])
	for key in keys:
		var row: Dictionary = rows[key]
		if int(row.get("timed", 0)) == 0:
			continue
		var n := float(int(row["timed"]))
		print("%-16s %8d %11.3f %10.3f %10.3f" % [
			str(key), int(row["timed"]), float(row.get("tsum", 0.0)) / n,
			float(row.get("tmin", 0.0)), float(row.get("tmax", 0.0)),
		])
	print("")
	print("flown/launch = legs where that candidate is available at all")
	print("`body` is whatever BallPresentation.contact_height returns today,")
	print("which already prefers a published contact height where one exists --")
	print("so a zero in the last column means the migration has landed there.")
	quit(0)
