class_name BlockRolloutAudit
extends RefCounted

## Gate 44 information/legality/immutability audit for ShadowBlockSystem
## output. Mirrors AttackRolloutAudit's pattern: it never gates or promotes
## anything by itself, it only certifies that a shadow_block result honors
## the observation boundary (no truth-prefixed keys in any blocker's
## perceived data), front-row legality for every blocker plus the resolved
## primary/assist roles, and that the source RallyState was left untouched.


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
	for raw_blocker in blockers:
		var blocker: Dictionary = raw_blocker
		var blocker_id := int(blocker.get("blocker_id", -1))
		var observation: Dictionary = blocker.get("observation", {})
		if observation.is_empty() or _contains_truth(observation):
			reasons.append("blocker_observation_invalid:%d" % blocker_id)
		if bool(observation.get("decision_uses_authoritative_truth", true)):
			reasons.append("blocker_decision_uses_truth:%d" % blocker_id)
		if bool(blocker.get("decision_uses_authoritative_truth", true)):
			reasons.append("blocker_result_uses_truth:%d" % blocker_id)
		if opponent_lineup != null and not _is_front_row(opponent_lineup, blocker_id):
			reasons.append("blocker_not_front_row:%d" % blocker_id)

	if not bool(shadow_block.get("source_state_unchanged", false)):
		reasons.append("source_state_mutated")

	var primary_id := int(shadow_block.get("primary_id", -1))
	if primary_id >= 0 and opponent_lineup != null \
			and not _is_front_row(opponent_lineup, primary_id):
		reasons.append("primary_not_front_row")
	var assist_id := int(shadow_block.get("assist_id", -1))
	if assist_id >= 0 and opponent_lineup != null \
			and not _is_front_row(opponent_lineup, assist_id):
		reasons.append("assist_not_front_row")
	if assist_id >= 0 and assist_id == primary_id:
		reasons.append("assist_matches_primary")

	return _result(reasons, shadow_block)


static func _is_front_row(lineup: RotationLineup, player_id: int) -> bool:
	var slot := lineup.slot_for_player(player_id)
	return slot >= 1 and CourtConstants.is_front_row_slot(slot)


static func _result(reasons: Array[String], shadow_block: Dictionary) -> Dictionary:
	return {
		"eligible": reasons.is_empty(),
		"failure_reasons": reasons,
		"blocker_count": int(shadow_block.get("blockers", []).size()),
		"primary_id": int(shadow_block.get("primary_id", -1)),
		"assist_id": int(shadow_block.get("assist_id", -1)),
		"observation_boundary_valid": reasons.is_empty(),
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
