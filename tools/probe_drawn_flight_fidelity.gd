extends SceneTree

## Does the drawn ball behave, *between* the seams and *beside* the bodies?
##
## The M8/§5 work certified that each leg's endpoint height equals the next
## contact's height. That is continuity at the joins and it says nothing about
## three other things a viewer sees immediately, all four of which were reported
## against a build whose seams measure zero:
##
##   plunge    the leg's descent rate over its last tenth against its own mean.
##             A ball that travels flat and then drops onto the receiver reads as
##             a teleport even though both endpoints are correct.
##   desync    the drawn ball's position at a contact against the *body* that
##             made it. A platform that never meets the ball, and a setter
##             standing away from where the ball is, are the same measurement.
##   tempo     set flight seconds by tempo. A first-tempo ball that arrives
##             faster than a hitter can leave the floor is not a quick, it is a
##             missing constraint.
##
## Every quantity is read from published metadata and the shipped
## `BallPresentation` call, so a number here is a number the game draws.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const BallPresentationScript := preload(
	"res://scripts/simulation/ball_presentation.gd"
)
const BallFlightModel := preload("res://scripts/simulation/ball_flight_model.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

const RALLIES: int = 240
## A body and the ball it is playing are within arm's length of each other.
## Wider than a real contact on purpose: this is looking for volis metres away,
## not for centimetre error.
const DESYNC_TOLERANCE_METERS: float = 0.75
## How much steeper the last tenth may be than the leg's own average before the
## arrival reads as a drop rather than a flight.
const PLUNGE_RATIO: float = 2.5


func _initialize() -> void:
	var legs := {}
	var desync := {}
	var tempo := {}
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
				var next_contact: RallyEvent = contacts[position + 1] \
					if position + 1 < contacts.size() else null
				_measure_desync(event, profiles, desync)
				_measure_tempo(event, tempo)
				var trajectory: Dictionary = event.metadata.get(
					"outgoing_trajectory", {}
				)
				if trajectory.is_empty():
					trajectory = event.metadata.get("trajectory", {})
				if trajectory.is_empty():
					continue
				var display: Dictionary = BallPresentationScript.display_trajectory(
					event, next_contact, trajectory, profiles
				)
				_measure_plunge(event, next_contact, display, legs)
	_report(legs, desync, tempo)
	quit(0)


## The drawn arc's shape, sampled the way the court samples it.
##
## `BallFlightModel.height_between` is what `MatchCourt3D` asks for each frame,
## so walking it at a fixed cadence is walking the drawn ball itself rather than
## a second opinion about it.
func _measure_plunge(
	event: RallyEvent,
	next_contact: RallyEvent,
	display: Dictionary,
	rows: Dictionary,
) -> void:
	var duration := float(display.get("duration", 0.0))
	if duration <= 0.02:
		return
	var start_height := float(display.get("start_height_meters", 1.0))
	var end_height := float(display.get("end_height_meters", 1.0))
	var samples: Array[float] = []
	for step in range(21):
		## `progress` is a 0-1 fraction and is clamped as one. The first version
		## of this probe passed `duration * step / 20` -- elapsed *seconds* --
		## so every leg longer than a second was clamped to its endpoint and
		## every shorter one was sampled at the wrong place entirely. It reported
		## 188 of 192 serves "arriving while still rising", which was the
		## instrument and not the engine.
		samples.append(BallFlightModel.height_between(
			start_height, end_height, duration, float(step) / 20.0
		))
	## Metres per second of descent over the final tenth, against the mean
	## descent across the whole leg. Only descending legs can plunge.
	var final_drop := (samples[18] - samples[20]) / (duration * 0.1)
	var total_drop := (samples[0] - samples[20]) / duration
	var label := "%s -> %s" % [
		str(RallyEvent.EventType.keys()[int(event.event_type)]),
		str(RallyEvent.EventType.keys()[int(next_contact.event_type)]) \
			if next_contact != null else "floor",
	]
	if not rows.has(label):
		rows[label] = {
			"n": 0, "climbs": 0, "rising": 0, "level": 0, "falling": 0,
			"worst": 0.0, "ratio_total": 0.0,
		}
	var row: Dictionary = rows[label]
	row["n"] = int(row["n"]) + 1
	## **Three populations, counted apart.** Pooling them was the first version's
	## defect: legs that never descend contribute nothing to the ratio and were
	## still dividing it, so a family of rising balls reported a mean near zero
	## and read as "arrives flat" when it actually means "arrives climbing".
	## Reporting the denominator separately from the effect is the same rule M9's
	## own C6 gate states, and this probe broke it.
	## Net-rising, genuinely level, and net-falling are three different things
	## and the first version conflated the first two: testing `total_drop <= 0.05`
	## before anything else swallowed every climbing leg into "level", which would
	## have reported a set rising correctly to its hitter as a flat translation.
	if total_drop < -0.05:
		row["climbs"] = int(row.get("climbs", 0)) + 1
		return
	if total_drop <= 0.05:
		row["level"] = int(row["level"]) + 1
		return
	if final_drop <= 0.0:
		row["rising"] = int(row["rising"]) + 1
		return
	row["falling"] = int(row["falling"]) + 1
	var ratio := final_drop / total_drop
	row["ratio_total"] = float(row["ratio_total"]) + ratio
	row["worst"] = maxf(float(row["worst"]), ratio)


## Is the body that made this contact where the ball is?
func _measure_desync(
	event: RallyEvent, profiles: Dictionary, rows: Dictionary
) -> void:
	var body: Variant = event.metadata.get("body_contact_position", null)
	if body == null:
		return
	## **Only contacts that actually met the ball.** A beaten block and a dig that
	## never arrived are *supposed* to leave the body away from the ball -- that
	## is FD-007's whole point -- so counting them as desync would manufacture a
	## defect out of correct behaviour. B0's test: did this contact publish a
	## ball.
	##
	## **Non-empty, not present.** This asked `metadata.has(...)`, and a beaten
	## block publishes the key holding an *empty dictionary* -- so the filter
	## passed every block that never touched the ball and counted the whole of
	## FD-007's correct behaviour as desync. Measured on the same population, the
	## key is present on 100% of `ATTACK -> BLOCK` legs and non-empty on half.
	if Dictionary(event.metadata.get("outgoing_trajectory", {})).is_empty():
		return
	var family := str(RallyEvent.EventType.keys()[int(event.event_type)])
	if not rows.has(family):
		rows[family] = {"n": 0, "apart": 0, "total": 0.0, "worst": 0.0}
	var row: Dictionary = rows[family]
	var metres := RallyKinematics.court_delta_meters(
		Vector2(body), Vector2(event.start_position)
	).length()
	row["n"] = int(row["n"]) + 1
	row["total"] = float(row["total"]) + metres
	row["worst"] = maxf(float(row["worst"]), metres)
	if metres > DESYNC_TOLERANCE_METERS:
		row["apart"] = int(row["apart"]) + 1


## How long a set of each tempo actually spends in the air.
func _measure_tempo(event: RallyEvent, rows: Dictionary) -> void:
	if int(event.event_type) != RallyEvent.EventType.SET:
		return
	var flight := float(event.metadata.get("set_flight_time", -1.0))
	if flight < 0.0:
		return
	var label := "T%d" % int(event.metadata.get("achieved_tempo", -1))
	if not rows.has(label):
		rows[label] = {"n": 0, "total": 0.0, "min": INF, "max": -INF}
	var row: Dictionary = rows[label]
	row["n"] = int(row["n"]) + 1
	row["total"] = float(row["total"]) + flight
	row["min"] = minf(float(row["min"]), flight)
	row["max"] = maxf(float(row["max"]), flight)


func _report(legs: Dictionary, desync: Dictionary, tempo: Dictionary) -> void:
	print("-- arrival shape: does the leg drop onto its contact? --")
	print("%-26s %5s %7s %6s %7s %8s %10s %9s" % [
		"leg", "n", "climbs", "level", "lifts", "falls", "mean ratio", "worst",
	])
	var leg_keys: Array = legs.keys()
	leg_keys.sort()
	for key in leg_keys:
		var row: Dictionary = legs[key]
		var falling := maxi(int(row["falling"]), 1)
		print("%-26s %5d %7d %6d %7d %8d %10.2f %9.2f" % [
			str(key), int(row["n"]), int(row.get("climbs", 0)),
			int(row["level"]), int(row["rising"]), int(row["falling"]),
			float(row["ratio_total"]) / float(falling), float(row["worst"]),
		])
	print("")
	print("ratio = descent rate over the last tenth / the leg's own mean, over")
	print("the FALLING legs only. Calibrated against true projectiles through the")
	print("same `BallFlightModel.height_between` the court samples:")
	print("  serve -> pass  2.40->0.90 m in 0.90 s  ratio 3.91")
	print("  attack -> floor 2.30->0.30 m in 0.75 s ratio 2.42")
	print("A real ball accelerates downward, so a correct arrival is ABOVE 2.")
	print("Well below that is a ball that fell early and skimmed in flat.")
	print("")
	print("-- body against ball at the contact --")
	print("%-20s %6s %8s %10s %10s" % [
		"family", "n", "apart", "mean m", "worst m",
	])
	var desync_keys: Array = desync.keys()
	desync_keys.sort()
	for key in desync_keys:
		var row: Dictionary = desync[key]
		var n := maxi(int(row["n"]), 1)
		print("%-20s %6d %8d %10.3f %10.3f" % [
			str(key), int(row["n"]), int(row["apart"]),
			float(row["total"]) / float(n), float(row["worst"]),
		])
	print("")
	print("apart = contacts where the body is more than %.2f m from the" % DESYNC_TOLERANCE_METERS)
	print("published contact point.")
	print("")
	print("-- set flight seconds by achieved tempo --")
	print("%-8s %6s %10s %10s %10s" % ["tempo", "n", "mean s", "min s", "max s"])
	var tempo_keys: Array = tempo.keys()
	tempo_keys.sort()
	for key in tempo_keys:
		var row: Dictionary = tempo[key]
		var n := maxi(int(row["n"]), 1)
		print("%-8s %6d %10.3f %10.3f %10.3f" % [
			str(key), int(row["n"]), float(row["total"]) / float(n),
			float(row["min"]), float(row["max"]),
		])
