extends SceneTree

## Does anybody attack from a place their rotation does not allow?
##
## A back-row player may not contact the ball above the net in front of the attack
## line. `OpponentTeam.eligible_hitters()` filters by position code and never reads
## the row, which is what put this on the list -- but the filter is only half the
## question. The other half is whether the *contact point* is placed legally
## anyway, and `_opponent_attack_contact_point` does read the lineup and does pull
## back-row hitters behind the line.
##
## So the two halves may already agree, and an audit is cheaper than a fix that
## turns out to be for a defect that does not occur. This reports, per side, how
## many attacks were taken by a back-row player and how many of those were struck
## in front of the line -- the second number is the violation, and the first is the
## sample that makes the second meaningful.
##
## Run:
##   godot --headless --path . --script res://tools/run_front_row_legality.gd

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const ExecutionScale := preload(
	"res://scripts/simulation/execution_scale_calibration.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const PAIRINGS: int = 4
const RALLIES: int = 90

## The attack line, as a fraction of court length from the opponent baseline. The
## court runs 0 (opponent baseline) to 1 (home baseline) with the net at 0.5, so
## each side's line sits three metres of an eighteen-metre court from the net.
const LINE_OFFSET: float = 3.0 / 18.0


func _initialize() -> void:
	var tally := {
		"home": {"attacks": 0, "back_row": 0, "illegal": 0, "unknown_slot": 0},
		"opponent": {"attacks": 0, "back_row": 0, "illegal": 0, "unknown_slot": 0},
	}
	for pairing_index in range(PAIRINGS):
		var roster_seed := 900006 + pairing_index * 1000
		for serving_home in [true, false]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			ExecutionScale.apply_generated_attributes(manager.players, roster_seed)
			ExecutionScale.apply_generated_attributes(
				manager.opponent_team.players, roster_seed
			)
			manager.match_state.serving_home = serving_home
			for seed_value in range(5000, 5000 + RALLIES):
				var result: Resource = manager.resolve_active_rally(seed_value)
				if result == null:
					continue
				_collect(manager, result, tally)
			manager.free()

	print("Front-row attack legality -- %d pairings x %d rallies, both service sides"
		% [PAIRINGS, RALLIES])
	print("")
	print("%-10s %9s %10s %9s %12s" % [
		"side", "attacks", "back row", "illegal", "slot unknown"
	])
	for side in ["home", "opponent"]:
		var row: Dictionary = tally[side]
		print("%-10s %9d %10d %9d %12d" % [
			side, int(row.attacks), int(row.back_row), int(row.illegal),
			int(row.unknown_slot),
		])
	print("")
	print("`illegal` is a back-row player contacting in front of their own attack")
	print("line. Zero with a non-zero `back row` column means the contact point")
	print("already carries the rule and the missing filter is not reachable.")
	quit()


func _collect(manager: Object, result: Resource, tally: Dictionary) -> void:
	for raw_event in result.events:
		var event := raw_event as RallyEvent
		if event == null \
				or event.event_type != RallyEventScript.EventType.ATTACK:
			continue
		var side := str(event.metadata.get("side", ""))
		if not tally.has(side):
			continue
		var row: Dictionary = tally[side]
		row.attacks += 1
		var slot := _slot_for(manager, side, int(event.actor_id))
		if slot < 1:
			row.unknown_slot += 1
			tally[side] = row
			continue
		if CourtConstants.is_front_row_slot(slot):
			tally[side] = row
			continue
		row.back_row += 1
		## The contact point is where the swing started. Home attacks from the
		## larger-y half, the opponent from the smaller.
		var contact_y: float = event.start_position.y
		var in_front := contact_y < CourtConstants.NET_Y + LINE_OFFSET \
			if side == "home" else contact_y > CourtConstants.NET_Y - LINE_OFFSET
		if in_front:
			row.illegal += 1
		tally[side] = row


func _slot_for(manager: Object, side: String, player_id: int) -> int:
	var lineup: Resource = null
	if side == "home":
		lineup = manager.current_lineup() if manager.has_method("current_lineup") \
			else null
	else:
		lineup = manager.opponent_team.current_lineup()
	if lineup == null:
		return -1
	return int(lineup.slot_for_player(player_id))
