class_name CourtConstants
extends RefCounted

## Normalized tactical-board coordinates. X runs left-to-right; Y runs from the
## opponent baseline (0.0) to the home baseline (1.0). The net is at Y = 0.5.

const NET_Y: float = 0.5
const HOME_BASELINE_Y: float = 0.96
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

const ROTATION_SLOT_POSITIONS := {
	1: Vector2(0.82, 0.84), # back-right / serving position
	2: Vector2(0.82, 0.57), # front-right
	3: Vector2(0.50, 0.56), # front-middle
	4: Vector2(0.18, 0.57), # front-left
	5: Vector2(0.18, 0.84), # back-left
	6: Vector2(0.50, 0.87), # back-middle
}


static func is_valid_lane(lane_name: String) -> bool:
	return lane_name in LANES


static func is_valid_tempo(tempo: int) -> bool:
	return tempo in TEMPOS


static func is_front_row_slot(slot_number: int) -> bool:
	return slot_number in [2, 3, 4]


static func slot_position(slot_number: int) -> Vector2:
	return ROTATION_SLOT_POSITIONS.get(slot_number, Vector2(0.5, 0.85))


static func lane_target(lane_name: String) -> Vector2:
	var lane_x := float(LANE_X.get(lane_name, 0.5))
	var target_y := 0.66 if lane_name == "Pipe" else 0.53
	return Vector2(lane_x, target_y)


static func is_normalized(point: Vector2) -> bool:
	return point.x >= 0.0 and point.x <= 1.0 \
		and point.y >= 0.0 and point.y <= 1.0
