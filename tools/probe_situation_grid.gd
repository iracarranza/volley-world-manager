extends Node

## Every contact of every situation, measured the same way, in one grid.
##
## **The comparison is the instrument; there is no pass and no fail here.** The
## Q1 quick vignette scored 100/100 against its own acceptance contract and CI
## gated on that score, while the attack it showed had no approach at all. A
## contract only tests the failures somebody already imagined. What actually
## found that one was putting quick, read and hitter in a table with identical
## columns and watching a column collapse. Nobody had to know in advance that
## 0.104 s was wrong; it was wrong because its neighbours were not.
##
## So this reports numbers and leaves the reading to a person scanning for the
## row that does not look like its neighbours. Two consequences follow, and both
## are load-bearing:
##
## - **The columns are situation-independent.** A reception, a set, a spike, a
##   block and a dig are all measured by the same questions. The moment a row is
##   measured its own special way the rows stop being comparable and this
##   collapses back into the bespoke assertions it exists to replace.
## - **The columns are two-sided.** A ceiling can only catch motion that is too
##   *fast*, and the defect that motivated this was motion that was **absent** --
##   zero is under every ceiling. `share` is the column that makes an omission
##   visible, because an omission shows up as a small number beside big ones.
##
## Must be run with a renderer, never `--headless`:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/situation_grid.tscn

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const FACTORY := preload(
	"res://scripts/simulation/volleyball_vignette_rally_factory.gd"
)
const EVENT := preload("res://scripts/models/rally_event.gd")

const SAMPLE_SECONDS: float = 1.0 / 60.0
const MAX_SAMPLES: int = 4000
## Slow motion on the *engine* clock, so the rally and every duration timed
## against it stretch together. `playback_speed` stretches only the rally and
## leaves the rig's own seconds at wall pace, which is how an earlier probe here
## measured a transition that never ran.
const TIME_SCALE: float = 0.1

## **One ceiling, from the sport, and deliberately not from attributes.**
##
## A shoulder turns over at roughly 1500-2500 deg/s at the top of a spike and a
## knee extends at 700-1000 in a jump, so anything past this is not a limb
## moving. Kept universal for two reasons. Deriving it per voli would apply the
## same attribute twice -- the resolver already prices arm speed through
## `action_power` and travel through the stride-and-cadence model, and the
## drawing is meant to express what it decided, not re-judge it. And a ceiling
## that varies per body would make the same defect measure differently on a
## strong voli and a weak one, which destroys the row-to-row comparison this
## whole grid is.
##
## Reported, never enforced. Clamping would hold the limb back from a pose it
## was told to be in, which turns a visible snap into an invisible desync -- the
## bug gets harder to see rather than fixed.
const IMPLAUSIBLE_DEGREES_PER_SECOND: float = 2500.0
## A joint counts as moving above this, which is well under anything a viewer
## can see and well over floating-point noise.
const MOVED_DEGREES: float = 0.02
## How far either side of a contact to look for its fastest joint.
const CONTACT_WINDOW_SECONDS: float = 0.35
## The opening of a rally, discarded from every statistic. `setup_players` and
## the first placements move bodies across the court in a frame or two, which is
## the court seating people rather than anybody playing volleyball -- and read as
## joint rates in the thousands until it was excluded.
const SETTLE_SECONDS: float = 0.20

const SITUATIONS: Array[String] = ["quick", "read", "hitter"]

## The joints a body is made of, in the order a reader wants them. Same list for
## every contact type, because that is the point.
const JOINTS := {
	"torso": "BodyPivot",
	"l_arm": "BodyPivot/LeftArm",
	"r_arm": "BodyPivot/RightArm",
	"l_elbow": "BodyPivot/LeftArm/Elbow",
	"r_elbow": "BodyPivot/RightArm/Elbow",
	"l_leg": "BodyPivot/LeftLeg",
	"r_leg": "BodyPivot/RightLeg",
	"l_knee": "BodyPivot/LeftLeg/Knee",
	"r_knee": "BodyPivot/RightLeg/Knee",
	"head": "BodyPivot/Head",
}

var _screen: Control
var _rows: Array = []


func _ready() -> void:
	get_window().size = Vector2i(480, 300)
	Engine.time_scale = TIME_SCALE
	for mode in SITUATIONS:
		var result: Resource = FACTORY.q1(mode)
		if result == null:
			continue
		_screen = MATCH_SCREEN.instantiate() as Control
		add_child(_screen)
		await get_tree().process_frame
		_screen.load_and_play_rally(result as RallyResult, 1.0)
		await _film(mode, result)
		_screen.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_report()
	get_tree().quit(0)


## One rally, sampled frame by frame, then read against its own events.
func _film(mode: String, result: Resource) -> void:
	var court = _screen.get("match_court_3d")
	if court == null:
		return
	var frames: Array = []
	var taken := 0
	var last_usec := Time.get_ticks_usec()
	var clock := 0.0
	var previous: Dictionary = {}
	while taken < MAX_SAMPLES and bool(_screen.get("playback_active")):
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		taken += 1
		var now_usec := Time.get_ticks_usec()
		var step := float(now_usec - last_usec) / 1000000.0 * TIME_SCALE
		last_usec = now_usec
		clock += step
		var ball := court.ball_actor as Node3D
		if ball == null:
			continue
		var bodies := {}
		for raw_id in court.player_actors:
			var actor := court.player_actors[raw_id] as Node3D
			if actor == null:
				continue
			var player_id := int(raw_id)
			var pivot := actor.get_node_or_null("BodyPivot") as Node3D
			var worst := 0.0
			for joint in JOINTS:
				var node := actor.get_node_or_null(str(JOINTS[joint])) as Node3D
				if node == null:
					continue
				var key := "%d|%s" % [player_id, joint]
				var now: Vector3 = node.rotation_degrees
				if previous.has(key):
					var was: Vector3 = previous[key]
					worst = maxf(worst, maxf(maxf(
						absf(_wrapped(now.x - was.x)),
						absf(_wrapped(now.y - was.y))),
						absf(_wrapped(now.z - was.z))))
				previous[key] = now
			bodies[player_id] = {
				"at": actor.position,
				"lift": float(pivot.position.y) if pivot != null else 0.0,
				"turned": worst,
			}
		frames.append({
			"t": clock, "step": step, "ball": ball.position, "bodies": bodies,
		})
	if frames.is_empty():
		return
	var previous_time := 0.0
	for raw in result.events:
		var event: Resource = raw
		if event == null:
			continue
		var kind := str(EVENT.EventType.keys()[int(event.event_type)])
		if kind in ["SET_DECISION", "POINT"]:
			continue
		var at := float(event.metadata.get(
			"physical_time", event.metadata.get("event_time", 0.0)
		))
		## **Anchored on where the ball went, not on when a clock says it did.**
		##
		## Reconstructing playback's rally clock from wall time drifts: the drawn
		## ball is paced by each flight's own physics duration, not by the event
		## timestamps, so the two diverge across a rally. Measured -- the same
		## deterministic reception reported 15.02 m on one run and 5.33 m on the
		## next, which is the anchor moving and not the game.
		##
		## The published contact position does not drift. Finding the frame where
		## the drawn ball is nearest it removes the clock from the question, and
		## the leftover -- how late that frame is against the published time -- is
		## a real number rather than an error term.
		var spot: Vector3 = court.tactical_to_world(
			event.start_position.x, event.start_position.y, 0.0
		)
		var index := _nearest_to(frames, spot)
		if index >= 0:
			_rows.append(_measure(
				mode, kind, int(event.actor_id), at, previous_time, frames, index
			))
		previous_time = at


## The same questions of every contact, whatever kind of contact it is.
func _measure(
	mode: String, kind: String, actor_id: int, at: float, since: float,
	frames: Array, index: int,
) -> Dictionary:
	var frame: Dictionary = frames[index]
	var ball: Vector3 = frame["ball"]
	var body: Dictionary = Dictionary(frame["bodies"]).get(actor_id, {})
	## **Did the body meet the ball?** The one question every contact type
	## answers identically, which is exactly why it earns a column: a reception,
	## a set, a spike and a block are all wrong in the same way when the body is
	## somewhere the ball is not.
	var reach := INF
	var lift := 0.0
	if not body.is_empty():
		var here: Vector3 = body["at"]
		reach = Vector2(ball.x - here.x, ball.z - here.z).length()
		lift = float(body["lift"])
	## **How much of the time it had was it drawn using?** The gap between two
	## contacts is what the rally paid for; the share of it in which this body
	## actually moved is what a viewer got. A small share beside large ones is an
	## omission, and omissions are the class no ceiling can catch.
	var gap := 0.0
	var drawn := 0.0
	var peak := 0.0
	for row in frames:
		var t := float(row["t"])
		var mine: Dictionary = Dictionary(row["bodies"]).get(actor_id, {})
		if mine.is_empty():
			continue
		var turned := float(mine["turned"])
		if t > since and t <= at:
			gap += float(row["step"])
			if turned > MOVED_DEGREES:
				drawn += float(row["step"])
		if absf(t - at) <= CONTACT_WINDOW_SECONDS and t >= SETTLE_SECONDS:
			peak = maxf(peak, turned / maxf(float(row["step"]), 0.0001))
	return {
		"mode": mode, "kind": kind, "actor": actor_id, "t": at,
		"gap": gap, "drawn": drawn, "reach": reach, "lift": lift, "peak": peak,
		## How late the drawn ball was to the place the rally says it was struck.
		"lag": float(frame["t"]) - at,
	}


## The frame at which the drawn ball came closest to a published contact point.
static func _nearest_to(frames: Array, spot: Vector3) -> int:
	var best := -1
	var best_gap := INF
	for index in range(frames.size()):
		var ball: Vector3 = frames[index]["ball"]
		var gap := Vector2(ball.x - spot.x, ball.z - spot.z).length()
		if gap < best_gap:
			best_gap = gap
			best = index
	return best


## Degrees, brought back into -180..180, so a wrap past the boundary is not
## counted as a 360-degree turn. On a yaw that tracks a ball there would be many.
static func _wrapped(delta: float) -> float:
	return fposmod(delta + 180.0, 360.0) - 180.0


func _report() -> void:
	print("")
	print("-- every contact, measured the same way --")
	print("%-7s %-10s %6s %7s %7s %7s %7s %8s %7s %7s %9s %s" % [
		"where", "contact", "actor", "t s", "gap s", "drawn s", "share",
		"reach m", "lag s", "lift m", "peak d/s", "",
	])
	var last_mode := ""
	for row in _rows:
		if str(row["mode"]) != last_mode:
			last_mode = str(row["mode"])
			print("")
		var gap := float(row["gap"])
		var peak := float(row["peak"])
		## **A contact with no time before it has no share, and 0% would be a
		## lie.** The serve has no predecessor, and a block landing on the same
		## instant as the attack it met has a zero gap for a good reason. Both
		## printed blank rather than as a body that stood still.
		var timed := gap > 0.0001
		print("%-7s %-10s %6d %7.3f %7s %7s %7s %8s %7.2f %7.2f %9s %s" % [
			row["mode"], row["kind"], int(row["actor"]), float(row["t"]),
			"%.3f" % gap if timed else "   -- ",
			"%.3f" % float(row["drawn"]) if timed else "   -- ",
			"%.0f%%" % (100.0 * float(row["drawn"]) / gap) if timed else "   -- ",
			"   --  " if is_inf(float(row["reach"])) \
				else "%.2f" % float(row["reach"]),
			float(row["lag"]), float(row["lift"]),
			"%.0f" % peak if peak > 0.0 else "   -- ",
			"  <-- past a limb" if peak >= IMPLAUSIBLE_DEGREES_PER_SECOND else "",
		])
	print("")
	print("gap      = seconds between this contact and the one before it: the")
	print("           time the rally paid for")
	print("drawn    = seconds of that gap in which this body actually moved")
	print("share    = drawn / gap. A small share beside large ones is a body")
	print("           standing through time it was given -- the omission column")
	print("reach    = horizontal metres from the ball to the contacting body, at")
	print("           the frame the drawn ball came nearest the published contact")
	print("           point. Every contact answers this the same way")
	print("lag      = how late that frame was against the time the rally says the")
	print("           contact happened. The drawn ball and the resolved clock")
	print("           disagreeing is itself a finding")
	print("peak d/s = fastest joint within %.2f s of the contact. Flagged past" % CONTACT_WINDOW_SECONDS)
	print("           %.0f deg/s, which is past a shoulder at the top of a" % IMPLAUSIBLE_DEGREES_PER_SECOND)
	print("           spike. Reported, never enforced, and never per-attribute")
	print("")
	print("No pass and no fail: read down a column and find the row that does")
	print("not look like its neighbours.")
