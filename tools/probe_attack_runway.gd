extends Node

## How much of an attacker's approach reaches the screen?
##
## Plays the three Q1 creation vignettes through the real `MatchScreen` and
## watches the hitter, because the complaint they answer is a viewing one: a
## first-tempo quick reads as a pop rather than a swing.
##
## **Measured off the drawn body only** -- where it is and how high it is --
## and never off the rig's own bookkeeping. An approach is visible or it is
## not, and a flag saying the pose was applied does not settle that: the whole
## defect this was written for is an approach that the model knows about, pays
## for in `runup_seconds`, and never draws.
##
## The two numbers that matter are the runway (metres covered on the floor in
## the second before takeoff) and the grounded time inside it. Before
## `_apply_early_approach` existed, a first-tempo middle's drawn attack was
## 0.104 s with no grounded frames at all.
##
## Must be run with a renderer, never `--headless`:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/attack_runway.tscn

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const FACTORY := preload(
	"res://scripts/simulation/volleyball_vignette_rally_factory.gd"
)
const EVENT := preload("res://scripts/models/rally_event.gd")

const SAMPLE_SECONDS: float = 1.0 / 60.0
const MAX_SAMPLES: int = 4000
## Slow motion on the *engine* clock, so the rally and every duration timed
## against it stretch together. `playback_speed` would stretch only the rally
## and leave the rig's own seconds at wall pace, which is how an earlier probe
## in this repository measured a transition that never ran.
const TIME_SCALE: float = 0.1
## Above this the body has left the floor. Well over the locomotion bob, which
## is a couple of centimetres, and well under a real jump.
const AIRBORNE_METERS: float = 0.08
## Above this the body is travelling rather than shifting its weight.
const MOVING_MPS: float = 0.35
## How far back from takeoff to look for a runway. A volleyball approach is
## three or four steps and none of them takes longer than this.
const RUNWAY_SECONDS: float = 1.20
## Trimmed off the end of the runway so the arm statistics exclude the set
## flight, during which an attack pose is drawn whatever happens before it.
const PRE_RELEASE_SECONDS: float = 0.15
## One instant deep inside the approach, for a number that cannot be an artifact
## of where a band's edges fell.
const SNAPSHOT_SECONDS: float = 0.30

var _screen: Control


func _ready() -> void:
	get_window().size = Vector2i(480, 300)
	Engine.time_scale = TIME_SCALE
	for mode in ["quick", "read", "hitter"]:
		var result: Resource = FACTORY.q1(mode)
		if result == null:
			continue
		var hitter := -1
		for raw in result.events:
			var event: Resource = raw
			if event != null and event.event_type == EVENT.EventType.ATTACK:
				hitter = int(event.actor_id)
				break
		if hitter < 0:
			continue
		_screen = MATCH_SCREEN.instantiate() as Control
		add_child(_screen)
		await get_tree().process_frame
		_screen.load_and_play_rally(result as RallyResult, 1.0)
		await _watch(mode, hitter)
		_screen.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	get_tree().quit(0)


func _watch(mode: String, hitter: int) -> void:
	var court = _screen.get("match_court_3d")
	if court == null:
		return
	var rows: Array = []
	var taken := 0
	var last_place := Vector3.ZERO
	var placed := false
	var last_usec := Time.get_ticks_usec()
	var clock := 0.0
	while taken < MAX_SAMPLES and bool(_screen.get("playback_active")):
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		taken += 1
		var now_usec := Time.get_ticks_usec()
		var step := float(now_usec - last_usec) / 1000000.0 * TIME_SCALE
		last_usec = now_usec
		clock += step
		var actor := court.player_actors.get(hitter) as Node3D
		var pivot := actor.get_node_or_null("BodyPivot") as Node3D \
			if actor != null else null
		if actor == null or pivot == null:
			continue
		var here := actor.position
		var moved := 0.0
		if placed:
			moved = Vector2(here.x - last_place.x, here.z - last_place.z).length()
		last_place = here
		placed = true
		## **The posture worn while travelling, which is the actual question.**
		## The first version of this probe measured only where the body was, and
		## reported the change as having done nothing -- because the hitter was
		## already walking to the contact point either way. Walking there and
		## approaching there are different pictures, and the arms are what
		## separates them: an approach swings them back and up, a gait does not.
		var left := actor.get_node_or_null("BodyPivot/LeftArm") as Node3D
		var right := actor.get_node_or_null("BodyPivot/RightArm") as Node3D
		rows.append({
			"t": clock, "step": step, "moved": moved,
			"lift": float(pivot.position.y),
			"arm": maxf(
				absf(left.rotation_degrees.x) if left != null else 0.0,
				absf(right.rotation_degrees.x) if right != null else 0.0,
			),
		})
	if rows.is_empty():
		return
	## Takeoff is the first sample off the floor, and the jump is the run of
	## samples that stays off it. Found from the drawn body rather than from the
	## event's own timing, so the two can disagree and be seen to.
	var takeoff := -1.0
	var airborne := 0.0
	for row in rows:
		if float(row["lift"]) > AIRBORNE_METERS:
			if takeoff < 0.0:
				takeoff = float(row["t"])
			airborne += float(row["step"])
	var anchor := takeoff if takeoff >= 0.0 else float(rows[-1]["t"])
	var runway := 0.0
	var moving := 0.0
	var window := 0.0
	var arm_low := 9999.0
	var arm_high := -9999.0
	for row in rows:
		var at := float(row["t"])
		if at < anchor - RUNWAY_SECONDS or at > anchor:
			continue
		window += float(row["step"])
		runway += float(row["moved"])
		arm_low = minf(arm_low, float(row["arm"]))
		arm_high = maxf(arm_high, float(row["arm"]))
		if float(row["moved"]) / maxf(float(row["step"]), 0.0001) > MOVING_MPS \
				and float(row["lift"]) <= AIRBORNE_METERS:
			moving += float(row["step"])
	print("%-7s hitter %-3d   rally %.2f s, %d samples" % [
		mode, hitter, float(rows[-1]["t"]), rows.size(),
	])
	print("         takeoff at %.2f s%s" % [
		anchor, "" if takeoff >= 0.0 else "  (never left the floor)",
	])
	print("         runway in the %.2f s before takeoff: %.2f m, %.3f s of it moving" % [
		window, runway, moving,
	])
	print("         airborne %.3f s" % airborne)
	## **Strictly before the set is released**, which is the only band that can
	## answer the question. The full runway window contains the set flight, and
	## the attack pose is drawn there either way -- so a min/max across the whole
	## window saturates at the same ~80 degrees whatever happens earlier, which
	## is exactly what the first version of this reported.
	var pre_low := 9999.0
	var pre_high := -9999.0
	var at_snapshot := -1.0
	for row in rows:
		var at := float(row["t"])
		if at < anchor - RUNWAY_SECONDS or at > anchor - PRE_RELEASE_SECONDS:
			continue
		pre_low = minf(pre_low, float(row["arm"]))
		pre_high = maxf(pre_high, float(row["arm"]))
		if at_snapshot < 0.0 and at >= anchor - SNAPSHOT_SECONDS:
			at_snapshot = float(row["arm"])
	print("         arm pitch across the whole runway: %.1f to %.1f deg" % [
		arm_low, arm_high,
	])
	print("         arm pitch BEFORE the set releases: %.1f to %.1f deg" % [
		pre_low, pre_high,
	])
	print("         arm pitch %.2f s before takeoff: %.1f deg" % [
		SNAPSHOT_SECONDS, at_snapshot,
	])
