extends Node

## What do a passer's arms do after the ball has gone?
##
## Reported: they stay extended and then snap back to ready. Held out is a
## follow-through and correct; the snap is the seam. Both are visible in one
## trace, so this prints the arm angle every frame from the contact onward and
## names the largest single-frame drop rather than judging it.

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const FACTORY := preload(
	"res://scripts/simulation/volleyball_vignette_rally_factory.gd"
)
const EVENT := preload("res://scripts/models/rally_event.gd")

const SAMPLE_SECONDS: float = 1.0 / 60.0
const MAX_SAMPLES: int = 4000
const TIME_SCALE: float = 0.1

var _screen: Control


func _ready() -> void:
	get_window().size = Vector2i(480, 300)
	Engine.time_scale = TIME_SCALE
	for mode in ["quick", "read", "hitter"]:
		var result: Resource = FACTORY.q1(mode)
		if result == null:
			continue
		var passer := -1
		var at := 0.0
		for raw in result.events:
			var event: Resource = raw
			if event != null \
					and event.event_type == EVENT.EventType.RECEPTION:
				passer = int(event.actor_id)
				at = float(event.metadata.get("physical_time", 0.0))
				break
		if passer < 0:
			continue
		_screen = MATCH_SCREEN.instantiate() as Control
		add_child(_screen)
		await get_tree().process_frame
		_screen.load_and_play_rally(result as RallyResult, 1.0)
		await _trace(mode, passer, at)
		_screen.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	get_tree().quit(0)


func _trace(mode: String, passer: int, contact_at: float) -> void:
	var court = _screen.get("match_court_3d")
	if court == null:
		return
	var rows: Array = []
	var taken := 0
	var last_usec := Time.get_ticks_usec()
	var clock := 0.0
	while taken < MAX_SAMPLES and bool(_screen.get("playback_active")):
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		taken += 1
		var now_usec := Time.get_ticks_usec()
		clock += float(now_usec - last_usec) / 1000000.0 * TIME_SCALE
		last_usec = now_usec
		var actor := court.player_actors.get(passer) as Node3D
		if actor == null:
			continue
		var left := actor.get_node_or_null("BodyPivot/LeftArm") as Node3D
		var right := actor.get_node_or_null("BodyPivot/RightArm") as Node3D
		if left == null or right == null:
			continue
		rows.append({
			"t": clock,
			## Both arms averaged: a platform is symmetric, and averaging keeps a
			## one-armed gait swing from reading as a platform.
			"arm": (left.rotation_degrees.x + right.rotation_degrees.x) * 0.5,
		})
	if rows.is_empty():
		return
	print("\n=== %s: passer %d, contact at %.2f s ===" % [
		mode, passer, contact_at,
	])
	var worst := 0.0
	var worst_at := 0.0
	var held := 0.0
	var previous := 0.0
	var seeded := false
	var line := ""
	for row in rows:
		var t := float(row["t"])
		if t < contact_at - 0.10:
			continue
		var arm := float(row["arm"])
		if seeded:
			var drop := previous - arm
			if drop > worst:
				worst = drop
				worst_at = t
			if absf(drop) < 0.5:
				held += 1.0
		previous = arm
		seeded = true
		line += "%.0f " % arm
	print("  arm angle each frame from contact: %s" % line.strip_edges())
	print("  largest single-frame drop: %.1f deg at %.2f s (%.2f s after contact)" % [
		worst, worst_at, worst_at - contact_at,
	])
