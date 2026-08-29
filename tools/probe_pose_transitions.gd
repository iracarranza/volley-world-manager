extends Node

## Does a voli move between poses, or arrive in the next one?
##
## `set_pose` writes every joint from scratch each frame out of the per-action
## biomechanics modules, which is right *within* a frame and says nothing about
## what happens *between* two of them. `StanceTransition`'s own header names the
## failure for the two cases it covers -- "nothing tweens it because nothing
## holds the previous one" -- and it was never extended to contact poses. This
## measures whether that shows.
##
## The instrument is angular speed per joint, in degrees per second, sampled off
## the live rig while `MatchScreen.load_and_play_rally` runs. A body moving has
## bounded joint speed; a body arriving has one sample of hundreds of degrees a
## second and neighbours near zero. So the distribution's *tail* is the whole
## measurement and its mean is nearly meaningless -- reported apart, for the
## reason every probe in this repository now reports its denominator apart.
##
## Must be run with a renderer, never `--headless`:
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/pose_transitions.tscn

const MATCH_SCREEN := preload("res://scenes/screens/match_screen.tscn")
const MANAGER := preload("res://scripts/managers/game_manager.gd")

## Fast enough that a one-frame snap cannot hide between two samples, and slow
## enough that a whole rally fits in a few hundred rows per voli.
const SAMPLE_SECONDS: float = 1.0 / 30.0
const MAX_SAMPLES: int = 4000
## Filmed in slow motion, and this is the whole reason the probe can see
## anything. Under xvfb with software GL and twelve outlined actors the
## renderer holds 4 fps, so a real-time sample lands every 0.25 s -- sixty
## times coarser than a one-frame snap, and it duly reported zero of them.
## Joint angles are a function of *rally* time, so stretching the playback
## buys back resolution in the clock that matters: at 0.1x, 4 wall-clock
## samples a second are 40 samples per rally second. Every speed below is
## divided back out, so the figures are rally deg/s, not wall deg/s.
##
## **`Engine.time_scale`, not `playback_speed`, and the difference is the whole
## measurement.** `playback_speed` stretches the rally alone; every duration the
## rig keeps in seconds -- the stance blend, the floor recovery, the pose
## transition -- runs on `get_process_delta_time()` and would keep real time
## while the body it belongs to moved at a tenth of it. At 4 fps that is a
## 0.25 s frame against a 0.14 s transition: one frame swallows the whole thing,
## and a probe built that way reports that no transition ever happened. It did
## report exactly that. Scaling the engine clock slows the rally and everything
## timed against it by the same factor, which is the relationship real playback
## has and the only one worth measuring.
const PLAYBACK_SPEED: float = 0.1
## Above this, a joint moved further in one sample than a body can move a limb.
## Set from the sport rather than from the data: a spiking arm is the fastest
## thing on a volleyball court and its shoulder turns over at roughly 1500 deg/s
## at the top of the swing, so anything past twice that is not a limb moving.
const SNAP_DEGREES_PER_SECOND: float = 3000.0
## And the band below it that is still faster than a person, kept separate so a
## genuine fast swing is not counted as a defect.
const FAST_DEGREES_PER_SECOND: float = 1200.0

## The joints, by node path under the actor, in the order a reader wants them.
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
var _previous: Dictionary = {}
var _rows: Array = []
var _side := ""
var _elapsed := 0.0
var _posed_total := 0
var _easing_total := 0
var _posed_last := 0
var _easing_last := 0


func _ready() -> void:
	## Small on purpose. The bottleneck is fragments, not the rig, and every
	## pixel not drawn is another sample of the rally.
	get_window().size = Vector2i(480, 300)
	Engine.time_scale = PLAYBACK_SPEED
	for side in range(2):
		_side = "home" if side == 0 else "opponent"
		var chosen := _find_full_chain_rally(side == 0)
		if chosen.is_empty():
			push_error("no %s-serving rally walked the whole chain" % _side)
			continue
		print("sampling %s serve, seed %d: %s" % [
			_side, int(chosen.seed), str(chosen.chain),
		])
		_previous.clear()
		_elapsed = 0.0
		_posed_total = 0
		_easing_total = 0
		_posed_last = 0
		_easing_last = 0
		_screen = MATCH_SCREEN.instantiate() as Control
		add_child(_screen)
		await get_tree().process_frame
		_screen.load_and_play_rally(chosen.result as RallyResult, 1.0)
		await _sample()
		_screen.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_report()
	get_tree().quit(0)


## The same search the playback renderer uses, so both instruments look at the
## same rallies rather than at two hand-picked ones.
func _find_full_chain_rally(serving_home: bool) -> Dictionary:
	for index in range(240):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = serving_home
		var result: Resource = manager.resolve_active_rally(970000 + index)
		if result == null:
			continue
		var chain: Array = []
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event != null:
				chain.append(str(
					RallyEvent.EventType.keys()[int(event.event_type)]
				))
		if chain.has("SERVE") and chain.has("RECEPTION") \
				and chain.has("SET") and chain.has("ATTACK") \
				and (chain.has("BLOCK") or chain.has("DIG")):
			return {
				"seed": 970000 + index, "result": result, "chain": chain,
			}
	return {}


func _sample() -> void:
	var court = _screen.get("match_court_3d")
	if court == null:
		push_error("no MatchCourt3D on the screen")
		return
	var taken := 0
	## The elapsed time this probe *actually* got, not the interval it asked
	## for. A `SceneTree` timer resolves on a frame boundary, and under xvfb the
	## renderer does not hold 30 fps -- so dividing by the requested 1/30 s
	## inflates every speed by however far the frame cadence has slipped, which
	## is exactly how a physical limb gets filed as a snap.
	var last_usec := Time.get_ticks_usec()
	## Stop when the playback does. `MAX_SAMPLES` is thirty seconds and a rally
	## is a few, so a fixed count would spend most of its samples on a screen
	## that has already finished -- and every one of those would land in the
	## "did not move" column and drag the share down for a reason that has
	## nothing to do with posing.
	while taken < MAX_SAMPLES and bool(_screen.get("playback_active")):
		## Ignoring the time scale, so the sampling cadence stays a real-time
		## one while everything it looks at is slowed.
		await get_tree().create_timer(SAMPLE_SECONDS, true, false, true).timeout
		taken += 1
		var now_usec := Time.get_ticks_usec()
		var elapsed := maxf(float(now_usec - last_usec) / 1000000.0, 0.0001)
		last_usec = now_usec
		_elapsed += elapsed
		_posed_total += _posed_last
		_easing_total += _easing_last
		## Which leg of the rally the drawing is on, taken off the screen's own
		## caption rather than recomputed, so the two agree by construction. A
		## snap is only diagnosable if you know which pose it arrived into.
		var leg := "?"
		var label := _screen.get("event_label") as Label
		if label != null:
			leg = str(label.text)
		## Which actors `set_pose` actually reached this frame, and which are
		## mid-transition. Read off the rig's own bookkeeping rather than
		## inferred from the joints, because "did not move" and "was never
		## asked to move" look identical from outside and mean opposite things.
		var posed_now := 0
		var easing_now := 0
		for player_id in court.player_actors:
			var actor := court.player_actors[player_id] as Node3D
			if actor == null:
				continue
			if int(actor.get("_pose_frame")) == int(Engine.get_process_frames()):
				posed_now += 1
			if float(actor.get("_pose_remaining")) > 0.0:
				easing_now += 1
			for joint in JOINTS:
				var node := actor.get_node_or_null(
					str(JOINTS[joint])
				) as Node3D
				if node == null:
					continue
				var key := "%s|%d|%s" % [_side, int(player_id), joint]
				var now: Vector3 = node.rotation_degrees
				if _previous.has(key):
					## Per-axis, then the largest of the three. A snap on one axis
					## is a snap; averaging the three would let a big yaw hide
					## behind two still axes.
					var was: Vector3 = _previous[key]
					var step := maxf(maxf(
						absf(_wrapped(now.x - was.x)),
						absf(_wrapped(now.y - was.y))),
						absf(_wrapped(now.z - was.z)))
					_rows.append({
						"side": _side, "joint": joint,
						## Rally degrees per second. At 0.1x, one wall second is
						## a tenth of a rally second, so the rally rate is the
						## larger of the two -- divide by `elapsed * SPEED`, not
						## by `elapsed / SPEED`, which is a hundredfold error in
						## the direction that makes every limb look calm.
						"speed": step / (elapsed * PLAYBACK_SPEED),
						"step": step,
						"elapsed": elapsed,
						"sample": taken,
						## The gap between one movement and the next is a
						## property of *one voli's* joint, not of a joint name.
						## Keyed on the name alone, twelve actors interleave at
						## the same sample index and every gap collapses to one
						## frame -- which is what the first run of this probe
						## reported, and it was an artifact of the key.
						"body": "%s|%d" % [_side, int(player_id)],
						"leg": leg,
					})
				_previous[key] = now
		_posed_last = posed_now
		_easing_last = easing_now
	print("  posed by set_pose: %.2f of %d actors per frame; mid-ease: %.2f" % [
		float(_posed_total) / float(maxi(taken, 1)),
		court.player_actors.size(),
		float(_easing_total) / float(maxi(taken, 1)),
	])
	print("  %s: %d samples over %.2f s of rally, %d actors, %.1f samples/rally-second" % [
		_side, taken, _elapsed * PLAYBACK_SPEED, court.player_actors.size(),
		float(taken) / maxf(_elapsed * PLAYBACK_SPEED, 0.0001),
	])


## Degrees, brought back into -180..180 so a wrap past the boundary is not
## counted as a 360-degree snap. Every one of those would be a false positive,
## and on a yaw that tracks a ball round the court there would be many.
static func _wrapped(delta: float) -> float:
	var value := fposmod(delta + 180.0, 360.0) - 180.0
	return value


func _report() -> void:
	if _rows.is_empty():
		print("no samples")
		return
	print("")
	print("-- joint angular speed through a rally, deg/s --")
	print("%-10s %8s %9s %9s %9s %9s %9s" % [
		"joint", "n", "mean", "p50", "p95", "max", "snaps",
	])
	var by_joint := {}
	for row in _rows:
		var joint := str(row["joint"])
		if not by_joint.has(joint):
			by_joint[joint] = []
		by_joint[joint].append(float(row["speed"]))
	var order: Array = JOINTS.keys()
	var total_snaps := 0
	var total_fast := 0
	for joint in order:
		if not by_joint.has(joint):
			continue
		var speeds: Array = by_joint[joint]
		speeds.sort()
		var count := speeds.size()
		var sum := 0.0
		var snaps := 0
		var fast := 0
		for speed in speeds:
			sum += float(speed)
			if float(speed) >= SNAP_DEGREES_PER_SECOND:
				snaps += 1
			elif float(speed) >= FAST_DEGREES_PER_SECOND:
				fast += 1
		total_snaps += snaps
		total_fast += fast
		print("%-10s %8d %9.1f %9.1f %9.1f %9.1f %9d" % [
			joint, count, sum / float(count),
			float(speeds[int(count * 0.50)]),
			float(speeds[int(count * 0.95)]),
			float(speeds[count - 1]), snaps,
		])
	print("")
	print("snaps   = samples at or above %.0f deg/s, which is twice the shoulder" % SNAP_DEGREES_PER_SECOND)
	print("          speed of a spike at the top of the swing -- not a limb moving")
	print("fast    = %.0f-%.0f deg/s, quick but physical. Counted apart so a real" % [
		FAST_DEGREES_PER_SECOND, SNAP_DEGREES_PER_SECOND,
	])
	print("          swing is not filed as a defect: %d of them" % total_fast)
	print("")
	print("total snaps across every joint and both sides: %d of %d samples" % [
		total_snaps, _rows.size(),
	])
	## **The stillness, which is the number that matters.** A p95 of zero says
	## almost nothing moved between two samples a thirtieth of a second apart, and
	## a rig that is still 95% of the time is not one that needs its transitions
	## smoothed -- it is one that only moves at the moments something tells it to.
	## Reported as how often a joint moved at all, and as the gap between the
	## moments it did.
	print("")
	print("-- how often anything moves --")
	print("%-10s %8s %8s %8s %10s %10s %10s %10s %10s" % [
		"joint", "moved", "of", "share", "mean gap s", "max gap s",
		"p50 move", "p50 step", "p95 step",
	])
	var moved_by_joint := {}
	var samples_by_joint := {}
	var moving_speeds := {}
	var moving_steps := {}
	## Gaps are counted in samples and reported in seconds, so they need the
	## real mean interval for the same reason the speeds do.
	var interval := 0.0
	for row in _rows:
		interval += float(row["elapsed"]) * PLAYBACK_SPEED
	interval /= float(maxi(_rows.size(), 1))
	## Keyed on actor **and** joint. Keyed on the joint name alone, twelve
	## actors interleave at the same sample index and every gap reads as one
	## frame regardless of what the bodies did.
	var last_move := {}
	var gaps := {}
	for row in _rows:
		var joint := str(row["joint"])
		samples_by_joint[joint] = int(samples_by_joint.get(joint, 0)) + 1
		if float(row["speed"]) <= 0.0001:
			continue
		moved_by_joint[joint] = int(moved_by_joint.get(joint, 0)) + 1
		var speeds: Array = moving_speeds.get(joint, [])
		speeds.append(float(row["speed"]))
		moving_speeds[joint] = speeds
		var steps: Array = moving_steps.get(joint, [])
		steps.append(float(row["step"]))
		moving_steps[joint] = steps
		var key := "%s|%s" % [str(row["body"]), joint]
		var at := int(row["sample"])
		if last_move.has(key):
			var gap: Array = gaps.get(joint, [])
			gap.append(at - int(last_move[key]))
			gaps[joint] = gap
		last_move[key] = at
	for joint in JOINTS.keys():
		if not samples_by_joint.has(joint):
			continue
		var moved := int(moved_by_joint.get(joint, 0))
		var total := int(samples_by_joint[joint])
		var gap_list: Array = gaps.get(joint, [])
		var gap_mean := 0.0
		var gap_max := 0
		for gap in gap_list:
			gap_mean += float(gap)
			gap_max = maxi(gap_max, int(gap))
		gap_mean = (gap_mean / float(maxi(gap_list.size(), 1))) * interval
		var moving: Array = moving_speeds.get(joint, [])
		moving.sort()
		var median := 0.0
		if not moving.is_empty():
			median = float(moving[int(moving.size() * 0.50)])
		var steps: Array = moving_steps.get(joint, [])
		steps.sort()
		var step_median := 0.0
		var step_p95 := 0.0
		if not steps.is_empty():
			step_median = float(steps[int(steps.size() * 0.50)])
			step_p95 = float(steps[int(steps.size() * 0.95)])
		print("%-10s %8d %8d %7.1f%% %10.3f %10.3f %10.1f %10.2f %10.2f" % [
			joint, moved, total,
			100.0 * float(moved) / float(maxi(total, 1)),
			gap_mean, float(gap_max) * interval, median,
			step_median, step_p95,
		])
	print("")
	print("share    = samples where this joint's angle differed at all from the")
	print("           previous sample, a thirtieth of a second earlier")
	print("gap      = seconds between one movement of *one voli's* joint and its")
	print("           next, so a still body reports a long gap rather than the")
	print("           next actor's movement")
	## Where the tail lands. A snap at an event boundary is a pose *transition*
	## with nothing holding the previous one; a snap in the middle of a leg is a
	## different defect and wants a different repair, so they are separated here
	## rather than summed into one count.
	var tail: Array = []
	for row in _rows:
		if float(row["speed"]) >= FAST_DEGREES_PER_SECOND:
			tail.append(row)
	tail.sort_custom(func(a, b): return float(a["step"]) > float(b["step"]))
	## **Is 17% a cadence, or a population?**
	##
	## Twelve bodies are on court and `match_screen` poses only the contact actor
	## and the blockers -- one to three of twelve, which is 8 to 25 per cent. A
	## share in that band therefore has two readings that mean opposite things:
	## every body updating nine times a rally second, or two bodies updating
	## every frame while ten never move at all. Counting distinct bodies per
	## sample separates them, and nothing else does.
	var bodies := {}
	var moved_per_sample := {}
	var samples_seen := {}
	for row in _rows:
		var body := str(row["body"])
		bodies[body] = true
		var at := "%s|%d" % [str(row["side"]), int(row["sample"])]
		if not samples_seen.has(at):
			samples_seen[at] = {}
		if float(row["speed"]) > 0.0001:
			var moving: Dictionary = moved_per_sample.get(at, {})
			moving[body] = true
			moved_per_sample[at] = moving
	var total_moving := 0
	var still_samples := 0
	for at in samples_seen:
		var count := int(Dictionary(moved_per_sample.get(at, {})).size())
		total_moving += count
		if count == 0:
			still_samples += 1
	print("")
	print("-- how many of the bodies move in a given frame --")
	print("bodies on court            %d" % bodies.size())
	print("mean bodies moving/frame   %.2f" % [
		float(total_moving) / float(maxi(samples_seen.size(), 1)),
	])
	print("frames with nobody moving  %d of %d" % [
		still_samples, samples_seen.size(),
	])
	var per_body := {}
	var per_body_total := {}
	for row in _rows:
		var body := str(row["body"])
		per_body_total[body] = int(per_body_total.get(body, 0)) + 1
		if float(row["speed"]) > 0.0001:
			per_body[body] = int(per_body.get(body, 0)) + 1
	var shares: Array = []
	for body in per_body_total:
		shares.append(100.0 * float(per_body.get(body, 0))
			/ float(maxi(int(per_body_total[body]), 1)))
	shares.sort()
	print("per-body move share, min/median/max  %.1f%% / %.1f%% / %.1f%%" % [
		shares[0], shares[int(shares.size() * 0.5)], shares[shares.size() - 1],
	])
	print("")
	print("-- the biggest single-frame turns, and the leg they landed in --")
	print("%-9s %-9s %9s %11s   %s" % ["side", "joint", "degrees", "deg/s", "leg"])
	for index in range(mini(tail.size(), 18)):
		var row: Dictionary = tail[index]
		print("%-9s %-9s %9.1f %11.0f   %-28s %s" % [
			str(row["side"]), str(row["joint"]), float(row["step"]),
			float(row["speed"]), str(row["leg"]), str(row["body"]),
		])
	var by_leg := {}
	for row in tail:
		var leg := str(row["leg"])
		by_leg[leg] = int(by_leg.get(leg, 0)) + 1
	print("")
	print("-- and how they distribute across the legs --")
	for leg in by_leg:
		print("%-42s %6d" % [leg, int(by_leg[leg])])
	print("")
	print("p50 move = median rally deg/s across the samples where it did move,")
	print("           which is the number the all-sample p50 of zero was hiding")
	print("step     = degrees the joint actually turned in one sample. A body")
	print("           moving turns a little every frame; a body arriving turns")
	print("           nothing for many frames and then a lot in one")
