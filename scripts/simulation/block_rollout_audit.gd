class_name BlockRolloutAudit
extends RefCounted

## Gates 44 and 47 audit for ShadowBlockSystem output.
##
## Gate 44 needed only the observation boundary: no truth-prefixed keys in any
## blocker's perceived data, front-row legality, and an untouched source
## RallyState. Gate 47 turns that into a promotion boundary -- the check a
## guarded rollout would have to pass before an official BLOCK event could ever
## be built from this evidence. It therefore also certifies that the closing
## blockers are physically able to do what they committed to: the movement is
## feasible, the contact envelope actually reaches the ball including takeoff
## time and height, and the resolved roles are internally consistent with the
## blockers they name.
##
## Like AttackRolloutAudit, this never gates or promotes anything by itself.

## The candidate is promotable only when every one of these is clean. Anything
## that fails lands in `failure_reasons` with the blocker it belongs to.


static func evaluate(
	shadow_block: Dictionary,
	opponent_lineup: RotationLineup = null,
) -> Dictionary:
	var reasons: Array[String] = []
	if not bool(shadow_block.get("available", false)):
		reasons.append("shadow_block_unavailable")
		return _result(reasons, shadow_block)

	var blockers: Array = shadow_block.get("blockers", [])
	if blockers.is_empty():
		reasons.append("no_blockers_evaluated")

	var contact_height := float(shadow_block.get("block_contact_height_meters", 0.0))
	var by_id := {}
	for raw_blocker in blockers:
		var blocker: Dictionary = raw_blocker
		var blocker_id := int(blocker.get("blocker_id", -1))
		by_id[blocker_id] = blocker
		var observation: Dictionary = blocker.get("observation", {})

		## Gate 44: information purity and legality.
		if observation.is_empty() or _contains_truth(observation):
			reasons.append("blocker_observation_invalid:%d" % blocker_id)
		if bool(observation.get("decision_uses_authoritative_truth", true)):
			reasons.append("blocker_decision_uses_truth:%d" % blocker_id)
		if bool(blocker.get("decision_uses_authoritative_truth", true)):
			reasons.append("blocker_result_uses_truth:%d" % blocker_id)
		if opponent_lineup != null and not _is_front_row(opponent_lineup, blocker_id):
			reasons.append("blocker_not_front_row:%d" % blocker_id)

		## Gate 47: a teammate cue may only ever carry what one player could see
		## across a net. Leaking a teammate's confidence or private hypothesis
		## here would be the same boundary break as leaking authoritative truth.
		for raw_cue in observation.get("perceived_teammate_cues", []):
			var cue: Dictionary = raw_cue
			for key in cue:
				if str(key) in [
					"confidence_late", "confidence_early", "decisive_threshold",
					"implied_zone", "perceived_attack_x", "wrong_read",
				]:
					reasons.append("teammate_cue_leaks_private_state:%d" % blocker_id)

		## Gate 47: movement feasibility. Every blocker must carry a usable
		## movement profile whether or not they ended up closing.
		if float(blocker.get("maximum_speed_mps", 0.0)) <= 0.0:
			reasons.append("blocker_has_no_movement_profile:%d" % blocker_id)
		if float(blocker.get("direction_change_delay_seconds", -1.0)) < 0.0:
			reasons.append("blocker_negative_direction_change_delay:%d" % blocker_id)

		## Gate 47: contact envelope. A blocker who committed to a close and is
		## marked reachable must genuinely be able to reach the ball -- high
		## enough, and with the takeoff time a jump requires.
		if _is_closing(blocker) and bool(blocker.get("commitment_reachable", false)):
			if contact_height > 0.0 and float(blocker.get(
				"commitment_maximum_contact_height_meters", 0.0
			)) < contact_height:
				reasons.append("close_cannot_reach_contact_height:%d" % blocker_id)
			if bool(blocker.get("commitment_requires_jump", false)) \
					and float(blocker.get("commitment_takeoff_time_seconds", 0.0)) <= 0.0:
				reasons.append("jumping_close_has_no_takeoff_time:%d" % blocker_id)
			if float(blocker.get("commitment_arrival_margin", -99.0)) < 0.0:
				reasons.append("reachable_close_arrives_late:%d" % blocker_id)

	if not bool(shadow_block.get("source_state_unchanged", false)):
		reasons.append("source_state_mutated")

	## Gate 47: role consistency. A named role must belong to a blocker that
	## actually exists in this evaluation and actually committed to a close.
	var primary_id := int(shadow_block.get("primary_id", -1))
	var assist_id := int(shadow_block.get("assist_id", -1))
	for role_name in [["primary", primary_id], ["assist", assist_id]]:
		var label: String = role_name[0]
		var role_id: int = role_name[1]
		if role_id < 0:
			continue
		if opponent_lineup != null and not _is_front_row(opponent_lineup, role_id):
			reasons.append("%s_not_front_row" % label)
		if not by_id.has(role_id):
			reasons.append("%s_not_in_blocker_set" % label)
		else:
			var role_blocker: Dictionary = by_id[role_id]
			if not _is_closing(role_blocker):
				reasons.append("%s_is_not_closing" % label)
			if not bool(role_blocker.get("commitment_reachable", false)):
				reasons.append("%s_close_not_reachable" % label)
	if assist_id >= 0 and assist_id == primary_id:
		reasons.append("assist_matches_primary")
	if assist_id >= 0 and primary_id < 0:
		reasons.append("assist_without_primary")

	return _result(reasons, shadow_block)


## The promotable shape of this block, extracted for a future guarded rollout.
## Contains only resolved facts a BLOCK event would need; no perceived state.
static func candidate(shadow_block: Dictionary) -> Dictionary:
	var primary_id := int(shadow_block.get("primary_id", -1))
	var assist_id := int(shadow_block.get("assist_id", -1))
	var by_id := {}
	for raw_blocker in shadow_block.get("blockers", []):
		var blocker: Dictionary = raw_blocker
		by_id[int(blocker.get("blocker_id", -1))] = blocker
	var primary: Dictionary = by_id.get(primary_id, {})
	var assist: Dictionary = by_id.get(assist_id, {})
	return {
		"primary_id": primary_id,
		"assist_id": assist_id,
		"closer_count": int(shadow_block.get("closer_count", 0)),
		"contact_time": float(shadow_block.get("attack_contact_time", 0.0)),
		"contact_height_meters": float(shadow_block.get(
			"block_contact_height_meters", 0.0
		)),
		"primary_commitment": str(primary.get("commitment", "")),
		"primary_target_x": float(primary.get("commitment_target_x", 0.0)),
		"primary_arrival_margin": float(primary.get("commitment_arrival_margin", 0.0)),
		"primary_requires_jump": bool(primary.get("commitment_requires_jump", false)),
		"assist_commitment": str(assist.get("commitment", "")),
		"assist_target_x": float(assist.get("commitment_target_x", 0.0)),
		"assist_arrival_margin": float(assist.get("commitment_arrival_margin", 0.0)),
	}


static func fingerprint(shadow_block: Dictionary) -> String:
	var parts: Array[String] = [
		"p%d" % int(shadow_block.get("primary_id", -1)),
		"a%d" % int(shadow_block.get("assist_id", -1)),
		"n%d" % int(shadow_block.get("closer_count", 0)),
	]
	var entries: Array[String] = []
	for raw_blocker in shadow_block.get("blockers", []):
		var blocker: Dictionary = raw_blocker
		entries.append("%d:%s" % [
			int(blocker.get("blocker_id", -1)),
			str(blocker.get("commitment_fingerprint", "")),
		])
	entries.sort()
	parts.append_array(entries)
	return "|".join(parts)


static func _is_closing(blocker: Dictionary) -> bool:
	return str(blocker.get("commitment", "")) in ShadowBlockSystem.CLOSING_COMMITMENTS


static func _is_front_row(lineup: RotationLineup, player_id: int) -> bool:
	var slot := lineup.slot_for_player(player_id)
	return slot >= 1 and CourtConstants.is_front_row_slot(slot)


static func _result(reasons: Array[String], shadow_block: Dictionary) -> Dictionary:
	var information_reasons: Array[String] = []
	for reason in reasons:
		if reason.begins_with("blocker_observation_invalid") \
				or reason.begins_with("blocker_decision_uses_truth") \
				or reason.begins_with("blocker_result_uses_truth") \
				or reason.begins_with("teammate_cue_leaks_private_state"):
			information_reasons.append(reason)
	return {
		"eligible": reasons.is_empty(),
		"failure_reasons": reasons,
		"blocker_count": int(shadow_block.get("blockers", []).size()),
		"primary_id": int(shadow_block.get("primary_id", -1)),
		"assist_id": int(shadow_block.get("assist_id", -1)),
		"observation_boundary_valid": information_reasons.is_empty() \
			and bool(shadow_block.get("available", false)),
		"block_candidate": candidate(shadow_block),
		"fingerprint": fingerprint(shadow_block),
	}


static func _contains_truth(value: Variant) -> bool:
	if value is Dictionary:
		for key in value:
			var normalized := str(key).to_lower()
			if normalized.begins_with("true_") or normalized.begins_with("authoritative_"):
				return true
			if _contains_truth(value[key]):
				return true
	elif value is Array:
		for item in value:
			if _contains_truth(item):
				return true
	return false
