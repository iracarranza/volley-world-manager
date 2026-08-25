class_name TacticalInstructionModel
extends RefCounted

## Pure translation from authored tactical vocabulary to pre-resolution intent.
## Nothing here decides a contact or an outcome.  It produces targets, choice
## weights and role preferences which the existing movement/contact authority
## remains free to defeat.

const PHASE_ATTACK := "Attack"
const PHASE_BLOCK := "Block"
const PHASE_FLOOR := "Floor"

const ATTACK_BEHAVIOURS: Array[String] = [
	"spike line", "spike cross", "tool", "roll", "feint",
]
const BLOCK_BEHAVIOURS: Array[String] = [
	"close line", "close cross", "soft block", "kill block",
]
const FLOOR_BEHAVIOURS: Array[String] = [
	"dig line", "dig cross", "cover the tip", "chase",
]


## Convert worksheet metres (x from court centre, y back from the net) to the
## resolver's normalized home court.  Mirroring is done once for the opponent.
static func normalized_placement(sheet: Resource, player_id: int, opponent_side: bool) -> Dictionary:
	if sheet == null or not sheet.has_method("placement_for_player"):
		return {"authored": false}
	var authored: Dictionary = sheet.placement_for_player(player_id)
	if not bool(authored.get("authored", false)):
		return authored
	var meters := Vector2(authored.get("meters", Vector2.ZERO))
	var target := Vector2(
		clampf(0.5 + meters.x / 9.0, 0.06, 0.94),
		clampf(0.5 + absf(meters.y) / 18.0, 0.52, 0.98),
	)
	if opponent_side:
		target.y = 1.0 - target.y
	authored["target"] = target
	return authored


## A tactical call is a preference.  Discipline controls whether the player
## follows it on this opportunity, and a stable caller-supplied roll keeps
## paired trials deterministic without perturbing the rally RNG stream.
static func adherence(call: String, tactical_discipline: float, roll: float) -> Dictionary:
	if call.is_empty():
		return {"requested": "", "effective": "", "followed": false,
			"activated": false, "override_reason": "no instruction"}
	var chance := lerpf(0.42, 0.92, clampf(tactical_discipline, 0.0, 1.0))
	var followed := clampf(roll, 0.0, 1.0) < chance
	return {
		"requested": call,
		"effective": call if followed else "",
		"followed": followed,
		"activated": true,
		"adherence_chance": chance,
		"override_reason": "" if followed else "player judgment overrode call",
	}


static func attack_type_for_call(current_type: String, call: String, wall_available: bool) -> Dictionary:
	var result := {"attack_type": current_type, "effective": call, "override_reason": ""}
	match call:
		"tool":
			if wall_available:
				result.attack_type = "Tool attempt"
			else:
				result.effective = ""
				result.override_reason = "no block available to tool"
		"roll":
			result.attack_type = "Controlled roll"
		"feint":
			result.attack_type = "Short tip"
	return result


## Bias a selected floor point without commanding it.  The normal resolver
## still evaluates every available course and may prefer a sufficiently open
## alternative.
static func attack_target_score_bias(
	call: String, contact: Vector2, target: Vector2, attacking_negative_y: bool
) -> float:
	if call not in ["spike line", "spike cross"]:
		return 0.0
	var local_target := target if attacking_negative_y \
		else Vector2(target.x, 1.0 - target.y)
	var local_contact := contact if attacking_negative_y \
		else Vector2(contact.x, 1.0 - contact.y)
	var lateral := absf(local_target.x - local_contact.x)
	if call == "spike line":
		return lerpf(0.34, -0.18, clampf(lateral / 0.55, 0.0, 1.0))
	return lerpf(-0.18, 0.34, clampf(lateral / 0.55, 0.0, 1.0))


static func legacy_attack_target(
	target: Vector2, contact: Vector2, call: String, mirrored: bool
) -> Vector2:
	if call not in ["spike line", "spike cross", "feint"]:
		return target
	var local := Vector2(target.x, 1.0 - target.y) if mirrored else target
	if call == "spike line":
		local.x = lerpf(local.x, contact.x, 0.42)
	elif call == "spike cross":
		local.x = lerpf(local.x, 1.0 - contact.x, 0.42)
	else:
		local.y = lerpf(local.y, 0.70, 0.70)
	return Vector2(local.x, 1.0 - local.y) if mirrored else local


## Compose the two instructions that address the wall's lateral geometry.
## Clipboard close calls are the manager's shot-lane request; the match-board
## seam assignment is the named responsibility within that shape.  Keeping the
## composition pure makes order and symmetry executable facts instead of two
## side-specific branches hidden inside block formation.
static func block_formation_target(
	attack_x: float, behaviour: String, seam_responsibility: String
) -> Dictionary:
	var target_x := attack_x
	match behaviour:
		"close line":
			target_x = lerpf(attack_x, 0.08 if attack_x < 0.5 else 0.92, 0.16)
		"close cross":
			target_x = lerpf(attack_x, 0.50, 0.24)
	var after_behaviour := target_x
	match seam_responsibility:
		"Close blocking seam": target_x = lerpf(target_x, attack_x, 0.10)
		"Own inside seam": target_x = lerpf(target_x, 0.50, 0.12)
		"Own line seam":
			target_x = lerpf(target_x, 0.08 if attack_x < 0.5 else 0.92, 0.10)
		"Release cross-court seam": target_x = lerpf(target_x, 0.50, 0.20)
	return {
		"target": clampf(target_x, 0.08, 0.92),
		"after_behaviour": clampf(after_behaviour, 0.08, 0.92),
		"behaviour": behaviour,
		"seam_responsibility": seam_responsibility,
	}


## Each defensive label maps to a distinct geometric intent.  These are modest
## shifts toward a responsibility; actual travel is still resolved by the live
## movement system and the ball may make the request obsolete.
static func defensive_target(
	base: Vector2,
	assignment: Resource,
	attack_x: float,
	opponent_side: bool,
) -> Dictionary:
	if assignment == null:
		return {"target": base, "terms": {}}
	var target := base
	var forward := -1.0 if opponent_side else 1.0
	var net_y := 0.44 if opponent_side else 0.56
	var local_depth := 1.0 - base.y if opponent_side else base.y
	var front_row_base := local_depth <= 0.70
	## The plan generator has always assigned Net/Close/Cover-tip to its front
	## row and Perimeter/Inside/Step-tip to its back row.  Treat that historical
	## combination as the migration-neutral base.  Selecting another label still
	## creates a distinct target, while an old save does not acquire six surprise
	## position shifts simply because M9 connected the vocabulary.
	var terms := {}
	match str(assignment.base_responsibility):
		"Net defense":
			if not front_row_base:
				target.y = lerpf(target.y, net_y + 0.05 * forward, 0.34)
			terms.base = "shallower net support"
		"Perimeter defense":
			if front_row_base:
				target.x = lerpf(target.x, 0.12 if target.x < 0.5 else 0.88, 0.18)
				target.y += 0.025 * forward
			terms.base = "deep perimeter support"
		"Rotation coverage":
			target.x = lerpf(target.x, 1.0 - attack_x, 0.18)
			terms.base = "rotated behind the block"
		"Middle-up defense":
			target.x = lerpf(target.x, 0.50, 0.22)
			target.y = lerpf(target.y, net_y + 0.12 * forward, 0.28)
			terms.base = "middle-up support"
	match str(assignment.seam_responsibility):
		"Close blocking seam":
			if not front_row_base:
				target.x = lerpf(target.x, attack_x, 0.12)
			terms.seam = "close attack seam"
		"Own inside seam":
			if front_row_base:
				target.x = lerpf(target.x, 0.50, 0.13)
			terms.seam = "own inside seam"
		"Own line seam":
			target.x = lerpf(target.x, attack_x, 0.13)
			terms.seam = "hold line seam"
		"Release cross-court seam":
			target.x = lerpf(target.x, 1.0 - attack_x, 0.13)
			terms.seam = "release to cross seam"
	match str(assignment.short_ball_responsibility):
		"Cover tip behind block":
			if not front_row_base:
				target.x = lerpf(target.x, attack_x, 0.10)
				target.y = lerpf(target.y, net_y + 0.09 * forward, 0.18)
			terms.short_ball = "tip behind block"
		"Step into tip coverage":
			if front_row_base:
				target.y = lerpf(target.y, net_y + 0.13 * forward, 0.24)
			terms.short_ball = "step into tip"
		"Hold for roll shot":
			target.y = lerpf(target.y, net_y + 0.23 * forward, 0.16)
			terms.short_ball = "hold roll depth"
		"No short-ball duty":
			target.y += 0.018 * forward
			terms.short_ball = "hold ordinary depth"
	return {
		"target": Vector2(
			clampf(target.x, 0.06, 0.94),
			clampf(target.y, 0.04, 0.44) if opponent_side \
				else clampf(target.y, 0.56, 0.96),
		),
		"terms": terms,
	}


## Clipboard floor calls and the four net priorities compose into a floor
## target.  Zero priorities are meaningful: they remove that zone's pull.
static func clipboard_floor_target(
	base: Vector2,
	behaviour: String,
	priorities: Array,
	attack_x: float,
	opponent_side: bool,
) -> Dictionary:
	var target := base
	var net_y := 0.44 if opponent_side else 0.56
	var forward := -1.0 if opponent_side else 1.0
	match behaviour:
		"dig line": target.x = lerpf(target.x, attack_x, 0.20)
		"dig cross": target.x = lerpf(target.x, 1.0 - attack_x, 0.20)
		"cover the tip": target.y = lerpf(target.y, net_y + 0.10 * forward, 0.28)
		"chase": target = lerp(target, Vector2(attack_x, net_y + 0.17 * forward), 0.16)
	var p: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for index in range(mini(priorities.size(), 4)):
		p[index] = float(clampi(int(priorities[index]), 0, 3))
	var total := p[0] + p[1] + p[2] + p[3]
	if total > 0.0:
		var focus_x := (attack_x * p[0] + 0.5 * p[1] + (1.0 - attack_x) * p[2] + attack_x * p[3]) / total
		var tip_share := p[3] / total
		## The worksheet opens at [3, 2, 1, 2].  That historical default is
		## baseline-neutral; changing its relative weights is the instruction.
		## This closes the stored-only seam without silently moving every defender
		## in every old save the day M9 is installed.
		var default_total := 8.0
		var default_focus_x := (
			attack_x * 3.0 + 0.5 * 2.0 + (1.0 - attack_x) + attack_x * 2.0
		) / default_total
		var default_tip_share := 2.0 / default_total
		target.x += (focus_x - default_focus_x) * 0.18
		target.y -= (tip_share - default_tip_share) * 0.08 * forward
	return {"target": target, "behaviour": behaviour, "priorities": p}


static func emergency_second_contact_bonus(responsibility: String) -> float:
	match responsibility:
		"Release to emergency set": return 0.14
		"Take second contact": return 0.20
		"Pursue deep deflection": return -0.05
		"Cover hitter": return -0.08
	return 0.0


static func emergency_coverage_bonus(responsibility: String, target: Vector2) -> float:
	match responsibility:
		"Pursue deep deflection": return lerpf(-0.03, 0.14, clampf(absf(target.y - 0.5) * 2.0, 0.0, 1.0))
		"Cover hitter": return 0.12
		"Take second contact": return 0.04
		"Release to emergency set": return 0.02
	return 0.0
