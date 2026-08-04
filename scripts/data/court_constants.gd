class_name CourtConstants
extends RefCounted

## Normalized tactical-board coordinates. X runs left-to-right; Y runs from the
## opponent baseline (0.0) to the home baseline (1.0). The net is at Y = 0.5.

const NET_Y: float = 0.5
const HOME_BASELINE_Y: float = 0.96
## Full-court dimensions, used to convert normalised offsets into real distances.
const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0
## Height of the tape. Nothing consulted this before ball flight was solved from
## a contact height -- with the landing point chosen first and the arc
## back-solved to reach it, no ball could fail to clear the net, so there was
## nothing to consult it with.
const NET_HEIGHT_METERS: float = 2.43
## Each half court is 9 m deep. The attack line is 3 m from the net, leaving a
## 3 m front zone and 6 m back zone (a 1:2 depth ratio).
const HOME_ATTACK_LINE_Y: float = 0.653333
const OPPONENT_ATTACK_LINE_Y: float = 0.346667

const LANES: Array[String] = [
	"Left Pin", "Front Quick", "Right Quick", "Right Pin", "Pipe",
]

const LANE_X := {
	"Left Pin": 0.12,
	"Front Quick": 0.40,
	"Right Quick": 0.60,
	"Right Pin": 0.88,
	"Pipe": 0.50,
}

const TEMPOS: Array[int] = [0, 1, 2, 3]

## Rotation-order reference grid: two rows of three, used to verify overlap
## legality at the moment of serve contact. This is NOT a tactical formation and
## must not be used to position players during live play. For serve reception use
## `serve_receive_formation()`; each phase owns its own real formation.
const ROTATION_SLOT_POSITIONS := {
	1: Vector2(0.82, 0.84), # back-right / serving position
	2: Vector2(0.82, 0.57), # front-right
	3: Vector2(0.50, 0.56), # front-middle
	4: Vector2(0.18, 0.57), # front-left
	5: Vector2(0.18, 0.84), # back-left
	6: Vector2(0.50, 0.87), # back-middle
}

## Three-passer serve-receive arc. The middle passer sits deeper to cover the
## long seam; the outside passers stay marginally shallower so they can play
## forward through the ball rather than backpedalling.
const SERVE_RECEIVE_PASSER_POSITIONS := {
	"left": Vector2(0.19, 0.80),
	"middle": Vector2(0.50, 0.86),
	"right": Vector2(0.81, 0.80),
}

## Where front-row attackers who are NOT passing wait for the ball. They stage
## off the passing lanes, already turned toward their approach.
const SERVE_RECEIVE_STAGING_POSITIONS := {
	2: Vector2(0.84, 0.68),
	3: Vector2(0.46, 0.60),
	4: Vector2(0.14, 0.68),
}

## A shielded setter stands close to the net so the serve travels past them to
## the passers. They are never a primary receiver, in either row.
const SETTER_SHIELD_Y: float = 0.63

const BACK_ROW_SLOTS: Array[int] = [1, 5, 6]

## Rotational front/back partners. A back-row player must stay behind their
## front-row partner at the moment of serve contact, so a shielded back-row
## setter hides directly behind this teammate: legal and screened at once.
const BACK_FRONT_SLOT_PAIRS := {1: 2, 6: 3, 5: 4}

## Realistic serve-receive presets. `lanes` are the lateral passing seams,
## `depth` is the deepest passer's Y, and `outside_depth_lift` pulls the wide
## passers marginally shallower so they play forward through the ball instead of
## backpedalling. Passers are assigned to seams left-to-right.
const SERVE_RECEIVE_FORMATIONS := {
	## Two deep passers splitting the court. The elite default: fewest seams,
	## but it demands two genuinely good passers and leaves short serves to a
	## dedicated short-coverage player.
	"two_passer": {
		"passer_count": 2,
		"lanes": [0.33, 0.67],
		"depth": 0.84,
		"outside_depth_lift": 0.0,
	},
	## Three-passer arc. The modern standard and this project's default.
	"three_passer": {
		"passer_count": 3,
		"lanes": [0.19, 0.50, 0.81],
		"depth": 0.86,
		"outside_depth_lift": 0.06,
	},
	## Four passers, used against a big server when seam risk outweighs the cost
	## of pulling an attacker out of their approach.
	"four_passer": {
		"passer_count": 4,
		"lanes": [0.15, 0.38, 0.62, 0.85],
		"depth": 0.83,
		"outside_depth_lift": 0.04,
	},
	## Legacy five-passer W. Retained deliberately so the tactical board can show
	## why it is not the default: every front-row passer is a hitter who cannot
	## start their approach on time.
	"five_passer_w": {
		"passer_count": 5,
		"lanes": [0.14, 0.32, 0.50, 0.68, 0.86],
		"depth": 0.82,
		"outside_depth_lift": 0.10,
	},
}

const DEFAULT_SERVE_RECEIVE_FORMATION: String = "three_passer"

## Where a back-row player who is not passing covers the short serve.
const SHORT_COVERAGE_POSITION := Vector2(0.50, 0.70)

## Slot promoted into the passing trio when the setter occupies the back row.
## Front-left is the conventional step-back passer. A roster-aware version could
## instead pick the best available `reception` rating.
const PROMOTED_PASSER_SLOT: int = 4


static func is_valid_lane(lane_name: String) -> bool:
	return lane_name in LANES


static func is_valid_tempo(tempo: int) -> bool:
	return tempo in TEMPOS


static func is_front_row_slot(slot_number: int) -> bool:
	return slot_number in [2, 3, 4]


## Returned for a slot number this rotation does not have -- most commonly -1,
## the result of `slot_for_player()` failing to find a player who has been
## removed from the lineup. The old default, `Vector2(0.5, 0.85)`, was chosen
## as "somewhere plausible near the back row" and landed 0.02 short of slot 6's
## real position, `Vector2(0.50, 0.87)`. On a normalized 0-1 court that is
## visually indistinguishable, so a player whose slot could not be resolved
## rendered on top of whoever actually occupies slot 6 -- reported as one
## player "attached" to another. This sentinel sits off the normalized court
## entirely so an unresolved slot fails visibly instead of coinciding with a
## real one.
const UNRESOLVED_SLOT_POSITION := Vector2(-1.0, -1.0)


static func slot_position(slot_number: int) -> Vector2:
	return ROTATION_SLOT_POSITIONS.get(slot_number, UNRESOLVED_SLOT_POSITION)


static func lane_target(lane_name: String) -> Vector2:
	var lane_x := float(LANE_X.get(lane_name, 0.5))
	var target_y := 0.66 if lane_name == "Pipe" else 0.53
	return Vector2(lane_x, target_y)


## Which lane a contact at this x belongs to.
##
## The inverse of `lane_target`, and it exists because one side of the net was
## reading a lane it never had. `_choose_opponent_attack` returns a hitter, a
## contact point and a shot -- it has never returned a lane -- so every caller
## asking it for one got the `"Left Pin"` default, and every opponent swing in
## the game was resolved as a left-pin swing no matter where the hitter was
## standing. Nothing noticed while the lane only labelled an event; it started
## to matter the moment the lane began deciding the ball's natural course.
static func lane_at_x(contact_x: float) -> String:
	var nearest := "Front Quick"
	var best := INF
	for lane_name in LANES:
		## The pipe is a back-row lane, not a place on the net. Choosing it from
		## an x alone would put a front-row hitter on a pipe every time they
		## contacted near the middle.
		if lane_name == "Pipe":
			continue
		var distance := absf(float(LANE_X[lane_name]) - contact_x)
		if distance < best:
			best = distance
			nearest = lane_name
	return nearest


static func is_normalized(point: Vector2) -> bool:
	return point.x >= 0.0 and point.x <= 1.0 \
		and point.y >= 0.0 and point.y <= 1.0


static func is_valid_serve_receive_formation(formation_name: String) -> bool:
	return formation_name in SERVE_RECEIVE_FORMATIONS


## Single canonical home-to-opponent mirror. Every system that needs an opponent
## position routes through here so both sides are guaranteed to be generated by
## identical logic; any change to home behaviour shows up on the opponent side in
## the same rally rather than drifting apart.
static func mirror_to_opponent(point: Vector2) -> Vector2:
	return Vector2(point.x, 1.0 - point.y)


## Which slots actually pass the serve, in priority order. The setter is never a
## primary passer. When the setter occupies the back row, a front-row passer is
## promoted to keep the seam count intact.
static func serve_receive_passer_slots(
	setter_slot: int,
	passer_count: int,
	libero_slot: int = -1,
) -> Array[int]:
	var candidates: Array[int] = []
	## The libero passes first whenever they are on court.
	if libero_slot in BACK_ROW_SLOTS and libero_slot != setter_slot:
		candidates.append(libero_slot)
	for slot_number in [5, 6, 1]:
		if slot_number != setter_slot and slot_number not in candidates:
			candidates.append(slot_number)
	## First front-row promotion is the setter's own rotational partner: they
	## already stand on the side the setter vacated, and the setter is shielded
	## behind them, so the step-back is the shortest possible adjustment. The one
	## exception is the front-middle, whose quick approach we protect if we can.
	var promotion_order: Array[int] = []
	var partner_slot := int(BACK_FRONT_SLOT_PAIRS.get(setter_slot, PROMOTED_PASSER_SLOT))
	if partner_slot != 3:
		promotion_order.append(partner_slot)
	for slot_number in [PROMOTED_PASSER_SLOT, 2, 3]:
		if slot_number not in promotion_order:
			promotion_order.append(slot_number)
	for slot_number in promotion_order:
		if slot_number != setter_slot and slot_number not in candidates:
			candidates.append(slot_number)
	var chosen: Array[int] = []
	for slot_number in candidates:
		if chosen.size() >= passer_count:
			break
		chosen.append(slot_number)
	return chosen


## Where the setter waits for the serve. They are shielded in both rows: a
## front-row setter stands at the net so the serve passes them, and a back-row
## setter hides directly behind their rotational front-row partner.
static func setter_serve_receive_position(setter_slot: int) -> Vector2:
	if is_front_row_slot(setter_slot):
		var front_reference := slot_position(setter_slot)
		return Vector2(clampf(front_reference.x, 0.10, 0.90), SETTER_SHIELD_Y)
	var partner_slot := int(BACK_FRONT_SLOT_PAIRS.get(setter_slot, 2))
	var partner := slot_position(partner_slot)
	## Stay behind the partner (larger Y is deeper on the home side) so the
	## overlap rule holds at serve contact while the partner screens the setter.
	return Vector2(clampf(partner.x, 0.10, 0.90), clampf(partner.y + 0.09, 0.53, 0.94))


## Exhaustive minimum-travel matching of passer slots to seams. Returns the slot
## occupying each seam, indexed the same way as `seams`. Distances are measured in
## metres so the 9 m x 18 m court aspect is respected: a lateral error and a depth
## error of the same normalised size are not the same amount of running.
static func _best_seam_assignment(
	passer_slots: Array[int],
	seams: Array[Vector2],
) -> Array[int]:
	var usable := mini(passer_slots.size(), seams.size())
	if usable <= 0:
		return []
	var empty_order: Array[int] = []
	var best := {"order": empty_order, "cost": INF}
	var working: Array[int] = []
	_search_seam_assignment(passer_slots, seams, usable, working, 0.0, best)
	var winner: Array[int] = best["order"]
	if winner.is_empty():
		for index in range(usable):
			winner.append(passer_slots[index])
	return winner


## Depth-first branch and bound. `best` carries the incumbent order and cost so
## the search can prune any partial assignment that already costs more.
static func _search_seam_assignment(
	passer_slots: Array[int],
	seams: Array[Vector2],
	usable: int,
	working: Array[int],
	cost_so_far: float,
	best: Dictionary,
) -> void:
	if working.size() >= usable:
		if cost_so_far < float(best["cost"]):
			var snapshot: Array[int] = []
			snapshot.append_array(working)
			best["cost"] = cost_so_far
			best["order"] = snapshot
		return
	var seam_index := working.size()
	for slot_number in passer_slots:
		if slot_number in working:
			continue
		var origin := slot_position(slot_number)
		var seam: Vector2 = seams[seam_index]
		var travel := Vector2(
			(seam.x - origin.x) * COURT_WIDTH_METERS,
			(seam.y - origin.y) * COURT_LENGTH_METERS
		).length()
		if cost_so_far + travel >= float(best["cost"]):
			continue
		working.append(slot_number)
		_search_seam_assignment(
			passer_slots, seams, usable, working, cost_so_far + travel, best
		)
		working.remove_at(working.size() - 1)


## Full serve-reception formation keyed by rotation slot. This is the function
## `ROTATION_SLOT_POSITIONS` points callers toward: the rotation grid is only a
## legality reference and must never position players during live play.
static func serve_receive_formation(
	setter_slot: int,
	formation_name: String = DEFAULT_SERVE_RECEIVE_FORMATION,
	libero_slot: int = -1,
	opponent_side: bool = false,
) -> Dictionary:
	var preset: Dictionary = SERVE_RECEIVE_FORMATIONS.get(
		formation_name, SERVE_RECEIVE_FORMATIONS[DEFAULT_SERVE_RECEIVE_FORMATION]
	)
	var lanes: Array = preset["lanes"]
	var depth := float(preset["depth"])
	var lift := float(preset["outside_depth_lift"])
	var passer_slots := serve_receive_passer_slots(
		setter_slot, int(preset["passer_count"]), libero_slot
	)

	## Build the seam positions. Lift is normalised against the widest seam in
	## this preset, so the outermost passers receive the full lift and the
	## three-passer arc reproduces SERVE_RECEIVE_PASSER_POSITIONS exactly.
	var widest_offset := 0.001
	for raw_lane in lanes:
		widest_offset = maxf(widest_offset, absf(float(raw_lane) - 0.5))
	var seams: Array[Vector2] = []
	for raw_lane in lanes:
		var lane_x := float(raw_lane)
		var lane_y := depth - lift * clampf(
			absf(lane_x - 0.5) / widest_offset, 0.0, 1.0
		)
		seams.append(Vector2(
			clampf(lane_x, 0.06, 0.94), clampf(lane_y, 0.53, 0.96)
		))

	## Assign passers to seams by exact minimum total travel rather than sorting
	## on X. Sorting breaks down whenever two passers share a rotational X (slots
	## 4 and 5 both sit at 0.18), which silently produced cross-court swaps: a
	## front-left passer sent to the deep middle while the back-middle passer ran
	## to the right seam. With at most five passers an exhaustive search is cheap
	## and always optimal.
	var assignment := _best_seam_assignment(passer_slots, seams)

	var formation := {}
	for lane_index in range(assignment.size()):
		formation[assignment[lane_index]] = seams[lane_index]

	formation[setter_slot] = setter_serve_receive_position(setter_slot)

	for slot_number in range(1, 7):
		if slot_number in formation:
			continue
		if is_front_row_slot(slot_number):
			formation[slot_number] = Vector2(SERVE_RECEIVE_STAGING_POSITIONS.get(
				slot_number, Vector2(0.5, 0.62)
			))
		else:
			formation[slot_number] = SHORT_COVERAGE_POSITION

	if opponent_side:
		for slot_number in formation:
			formation[slot_number] = mirror_to_opponent(formation[slot_number])
	return formation
