extends SceneTree

## What does a block contact claim, and what did the engine prove?
##
## `AttackResolutionModel._block_contact` is a genuine ball-by-body feasibility
## test -- height against reach, lateral against half width -- and it names the
## hand the ball met. The question is not whether that test runs but whether the
## BLOCK event that follows it says the same thing: same actor, same place, same
## height.
##
## The proof is published on the **ATTACK** event, because that is the event the
## geometric record decorates. The BLOCK event is the one that names an actor, a
## contact position and an outgoing ball. So each block is read as the pair it
## is: the attack that carries the evidence, and the block that carries the
## claim. Every quantity below is read off published metadata; nothing here
## reconstructs the resolver.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

const RALLIES: int = 300


func _initialize() -> void:
	var pairs := 0
	var contacts := 0
	var kinds := {}
	var proof_on_attack := {"kind": 0, "crossing": 0, "depth": 0, "reaches": 0}
	var proof_on_block := {"kind": 0, "crossing": 0, "depth": 0, "reaches": 0}
	## |block.start_position.x - net_crossing_x| in metres: where the contact is
	## published against where the feasibility test proved the ball crossed.
	var x_gap_total := 0.0
	var x_gap_worst := 0.0
	var x_gap_n := 0
	var x_gap_over_hand := 0
	var per_side := {}
	## Solo walls only, where the contacting hand is unambiguous and the proven
	## contact height is therefore recoverable from what is published.
	var solo := 0
	var solo_height_total := 0.0
	var solo_height_min := INF
	var solo_height_max := -INF
	var wall_sizes := {}
	var credited_outside_wall := 0
	var credited_checkable := 0
	var proven_published := 0
	var actor_disagrees := 0
	var proven_outside_wall := 0
	var contact_not_primary := 0
	for side in range(2):
		for index in range(RALLIES / 2):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(910000 + index)
			if result == null:
				continue
			var previous: RallyEvent = null
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) != RallyEvent.EventType.BLOCK:
					previous = event
					continue
				pairs += 1
				var block_meta: Dictionary = event.metadata
				var attack_meta: Dictionary = previous.metadata if previous != null \
					else {}
				for key_pair in [
					["kind", "block_contact_kind"],
					["crossing", "net_crossing_x"],
					["depth", "block_depth_below_reach_meters"],
					["reaches", "wall_reach_heights"],
				]:
					if attack_meta.has(key_pair[1]) \
						and attack_meta[key_pair[1]] != null:
						proof_on_attack[key_pair[0]] = \
							int(proof_on_attack[key_pair[0]]) + 1
					if block_meta.has(key_pair[1]) and block_meta[key_pair[1]] != null:
						proof_on_block[key_pair[0]] = \
							int(proof_on_block[key_pair[0]]) + 1
				var kind := str(attack_meta.get("block_contact_kind", ""))
				if kind.is_empty():
					previous = event
					continue
				contacts += 1
				kinds[kind] = int(kinds.get(kind, 0)) + 1
				var side_key := str(block_meta.get("side", "?"))
				if not per_side.has(side_key):
					per_side[side_key] = {"n": 0, "gap": 0.0, "worst": 0.0}
				var wall_size := int(attack_meta.get("wall_size", 0))
				wall_sizes[wall_size] = int(wall_sizes.get(wall_size, 0)) + 1
				if block_meta.has("net_crossing_x"):
					var gap := absf(
						float(block_meta["net_crossing_x"]) - event.start_position.x
					) * CourtConstants.COURT_WIDTH_METERS
					x_gap_total += gap
					x_gap_worst = maxf(x_gap_worst, gap)
					x_gap_n += 1
					if gap > 0.45:
						x_gap_over_hand += 1
					var row: Dictionary = per_side[side_key]
					row["n"] = int(row["n"]) + 1
					row["gap"] = float(row["gap"]) + gap
					row["worst"] = maxf(float(row["worst"]), gap)
				## A solo wall has one reach, so reach - depth is the height the
				## ball was actually met at.
				var reaches: Array = attack_meta.get("wall_reach_heights", [])
				var depth: Variant = attack_meta.get(
					"block_depth_below_reach_meters", null
				)
				if wall_size == 1 and reaches.size() == 1 and depth != null:
					solo += 1
					var height := float(reaches[0]) - float(depth)
					solo_height_total += height
					solo_height_min = minf(solo_height_min, height)
					solo_height_max = maxf(solo_height_max, height)
				## Is the credited actor even one of the bodies that made the wall?
				## `block_jump_timing` is keyed by the id of every blocker who left
				## the floor, which is a superset of the wall, so this is a weak
				## test -- it can only catch a credit to somebody who never jumped.
				var jumps: Dictionary = attack_meta.get("block_jump_timing", {})
				if not jumps.is_empty():
					credited_checkable += 1
					if not jumps.has(int(event.actor_id)):
						credited_outside_wall += 1
				## The invariant, checked from published data alone: the contact
				## actor is the hand the feasibility test proved, and that hand
				## belongs to the wall this event holds.
				var proven_id := int(block_meta.get("block_contact_actor_id", -1))
				var wall_ids := [
					int(block_meta.get("block_wall_primary_id", -1)),
					int(block_meta.get("block_wall_assist_id", -1)),
				]
				if proven_id >= 0:
					proven_published += 1
					if int(event.actor_id) != proven_id:
						actor_disagrees += 1
					if not (proven_id in wall_ids):
						proven_outside_wall += 1
					if proven_id != wall_ids[0]:
						contact_not_primary += 1
				previous = event
	print("rallies: %d (both serving sides)" % RALLIES)
	print("attack->block pairs: %d, of which the wall touched the ball: %d" % [
		pairs, contacts,
	])
	print("contact kinds: %s" % [kinds])
	print("wall sizes at contact: %s" % [wall_sizes])
	print("")
	print("-- which event carries the proof, over %d pairs --" % pairs)
	print("%-34s %8s %8s" % ["fact", "ATTACK", "BLOCK"])
	for key in ["kind", "crossing", "depth", "reaches"]:
		print("%-34s %8d %8d" % [
			key, int(proof_on_attack[key]), int(proof_on_block[key]),
		])
	print("")
	print("-- published contact position against the proven crossing --")
	if x_gap_n > 0:
		print("  legs measured           %d" % x_gap_n)
		print("  mean |gap|              %.3f m" % (x_gap_total / float(x_gap_n)))
		print("  worst |gap|             %.3f m" % x_gap_worst)
		print("  gap wider than a hand   %d (%.1f%%)" % [
			x_gap_over_hand, 100.0 * float(x_gap_over_hand) / float(x_gap_n),
		])
		for side_key in per_side:
			var row: Dictionary = per_side[side_key]
			var n := maxi(int(row["n"]), 1)
			print("  %-20s  n=%-5d mean %.3f m  worst %.3f m" % [
				side_key, int(row["n"]), float(row["gap"]) / float(n),
				float(row["worst"]),
			])
	else:
		print("  net_crossing_x is not published anywhere on the pair")
	print("  contacts with no crossing published: %d of %d" % [
		contacts - x_gap_n, contacts,
	])
	print("")
	print("-- the height the ball was met at, on solo walls --")
	if solo > 0:
		print("  solo contacts           %d" % solo)
		print("  mean proven height      %.3f m" % (solo_height_total / float(solo)))
		print("  range                   %.3f m .. %.3f m" % [
			solo_height_min, solo_height_max,
		])
	else:
		print("  none recoverable")
	print("")
	print("credited actor never jumped: %d of %d checkable" % [
		credited_outside_wall, credited_checkable,
	])
	print("")
	print("-- the contact actor, against the wall that formed --")
	print("  contacts publishing a proven hand   %d of %d" % [
		proven_published, contacts,
	])
	print("  event actor disagrees with it       %d" % actor_disagrees)
	print("  proven hand outside this wall       %d" % proven_outside_wall)
	print("  ball met a hand other than primary  %d (%.1f%%)" % [
		contact_not_primary,
		100.0 * float(contact_not_primary) / float(maxi(proven_published, 1)),
	])
	quit(0)
