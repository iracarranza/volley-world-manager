extends SceneTree

## M6 / B4 -- does the block intersect the ball the attack actually launched?
##
##     godot --headless --path . \
##       --script res://tools/run_block_authority_probe.gd
##
## The packet's B4 asks four things of a block, and this measures the two that
## are about *authority* rather than about outcome bands:
##
##   3. a block touch changes the same authoritative ball rather than spawning a
##      hidden replacement outcome ball;
##   -- and its unstated precondition, that the wall intersects the attack's
##      **actual** flight rather than a superseded copy of it.
##
## Plus the B3/B6 rule that "home and opponent paths consume the same category of
## physical facts even where decision logic differs".
##
## **What the B0 census found and this localizes.** 100 of 443 `ATTACK -> BLOCK`
## edges handed the block a different ball than the attack published. Both block
## paths truncate the swing to the tape when the hands actually touch it -- a
## block that intercepts must not be fed the arc that would have reached the
## floor -- but only one of them then re-reads the truncated result. The other
## captured the pre-truncation arc in a local and published that.
##
## The same variable decides the block's timestamp, so the two are one defect:
## `_swing_reaches_net` exists precisely because "a block happens partway through
## one flight" while reception, set and dig happen when a flight *finishes*, and
## a path that stamps its block with `_contact_time` of an untruncated swing puts
## the hands on the ball at the moment it would have hit the floor behind them.
##
## Reported per side, because "the engine does this 100 times" and "one of two
## symmetric paths does this every time it fires" are different findings and only
## the second one names the repair.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 71000
const RALLIES_PER_SERVER: int = 300

## How far apart two timestamps have to be before the difference is a finding
## rather than float noise. A block and a floor landing are hundreds of
## milliseconds apart when this is wrong, so the threshold is not load-bearing.
const TIME_EPSILON: float = 0.002

var failures: int = 0


func _initialize() -> void:
	var report := _run()
	_print(report)
	for side in ["home", "opponent"]:
		var row: Dictionary = report.sides.get(side, {})
		if row.is_empty():
			continue
		_gate(
			int(row.get("stale_incoming", 0)) == 0,
			"%s block receives the attack's published ball, not a stale copy" % side,
		)
		_gate(
			int(row.get("late_stamp", 0)) == 0,
			"%s block is stamped when the swing reaches the tape" % side,
		)
	if failures == 0:
		print("\nPASS: block authority gates")
		quit(0)
		return
	push_error("FAIL: %d block authority gates" % failures)
	quit(1)


func _gate(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
		return
	failures += 1
	print("  FAIL  %s" % description)


func _run() -> Dictionary:
	var report := {"rallies": 0, "sides": {}}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally != null:
				report.rallies += 1
				_scan(rally, report)
			manager.free()
	return report


func _side(report: Dictionary, name: String) -> Dictionary:
	if not report.sides.has(name):
		report.sides[name] = {
			"blocks": 0,
			"touching": 0,
			"stale_incoming": 0,
			"late_stamp": 0,
			"stamped_at_incoming_end": 0,
			"worst_lateness": 0.0,
		}
	return report.sides[name]


func _scan(rally: Resource, report: Dictionary) -> void:
	var attack: Resource = null
	for event in rally.events:
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.ATTACK:
			attack = event
			continue
		if kind != RallyEventScript.EventType.BLOCK or attack == null:
			continue
		var meta: Dictionary = event.metadata
		var row := _side(report, str(meta.get("side", "?")))
		row.blocks += 1
		var published: Dictionary = attack.metadata.get("outgoing_trajectory", {})
		var incoming: Dictionary = meta.get("incoming_trajectory", {})
		if published.is_empty() or incoming.is_empty():
			continue
		## A truncated swing is the tell that the hands touched the ball: the
		## resolver re-slices the arc to the tape only on contact. Everything
		## else is a clean pass-through and its incoming is trivially equal.
		var touched := str(published.get("trajectory_type", "")) == "attack_to_block"
		if touched:
			row.touching += 1
		if not _same_ball(published, incoming):
			row.stale_incoming += 1
		## The block's own timestamp against the ball it was given. A block is
		## partway through a flight, so its moment is the tape crossing; being
		## stamped at the flight's `end_time` means it took the moment from an
		## arc that was never the one it intersected.
		var stamped := float(meta.get("event_time", NAN))
		if is_nan(stamped):
			continue
		var incoming_end := float(incoming.get("end_time", NAN))
		var published_end := float(published.get("end_time", NAN))
		if touched and not is_nan(published_end) \
				and stamped > published_end + TIME_EPSILON:
			row.late_stamp += 1
			row.worst_lateness = maxf(
				float(row.worst_lateness), stamped - published_end
			)
		if not is_nan(incoming_end) and absf(stamped - incoming_end) <= TIME_EPSILON \
				and touched:
			row.stamped_at_incoming_end += 1


func _same_ball(first: Dictionary, second: Dictionary) -> bool:
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)


func _print(report: Dictionary) -> void:
	print("\nblock authority -- %d rallies\n" % report.rallies)
	print("%-10s %8s %9s %15s %11s %11s %10s" % [
		"side", "blocks", "touching", "stale incoming", "late stamp",
		"== in.end", "worst late",
	])
	for side in report.sides:
		var row: Dictionary = report.sides[side]
		print("%-10s %8d %9d %15d %11d %11d %10.3f" % [
			side, row.blocks, row.touching, row.stale_incoming,
			row.late_stamp, row.stamped_at_incoming_end, row.worst_lateness,
		])
	print("")
