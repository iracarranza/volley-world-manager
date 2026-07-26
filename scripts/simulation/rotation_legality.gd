class_name RotationLegality
extends RefCounted

## Relative-position rules that apply at the instant of serve contact.
## Front row: 4 left of 3 left of 2. Back row: 5 left of 6 left of 1.
## Each front-row player must remain closer to the net than their counterpart.

const FRONT_ROW: Array[int] = [4, 3, 2]
const BACK_ROW: Array[int] = [5, 6, 1]
const FRONT_TO_BACK := {4: 5, 3: 6, 2: 1}
const BACK_TO_FRONT := {5: 4, 6: 3, 1: 2}
const HOME_MIN := Vector2(0.06, 0.53)
const HOME_MAX := Vector2(0.94, 0.96)
const SEPARATION: float = 0.012


static func related_slots(slot_number: int) -> Dictionary:
	var row: Array[int] = FRONT_ROW if slot_number in FRONT_ROW else BACK_ROW
	var row_index := row.find(slot_number)
	return {
		"left": row[row_index - 1] if row_index > 0 else -1,
		"right": row[row_index + 1] if row_index >= 0 and row_index < 2 else -1,
		"counterpart": int(FRONT_TO_BACK.get(
			slot_number, BACK_TO_FRONT.get(slot_number, -1)
		)),
		"front_row": slot_number in FRONT_ROW,
	}


static func legal_bounds(slot_number: int, positions_by_slot: Dictionary) -> Rect2:
	var minimum := HOME_MIN
	var maximum := HOME_MAX
	var related := related_slots(slot_number)
	var left_slot := int(related.left)
	var right_slot := int(related.right)
	var counterpart_slot := int(related.counterpart)
	if left_slot >= 0 and positions_by_slot.has(left_slot):
		minimum.x = float(Vector2(positions_by_slot[left_slot]).x) + SEPARATION
	if right_slot >= 0 and positions_by_slot.has(right_slot):
		maximum.x = float(Vector2(positions_by_slot[right_slot]).x) - SEPARATION
	if counterpart_slot >= 0 and positions_by_slot.has(counterpart_slot):
		var counterpart_y := float(Vector2(positions_by_slot[counterpart_slot]).y)
		if bool(related.front_row):
			maximum.y = counterpart_y - SEPARATION
		else:
			minimum.y = counterpart_y + SEPARATION
	minimum.x = minf(minimum.x, maximum.x)
	minimum.y = minf(minimum.y, maximum.y)
	return Rect2(minimum, maximum - minimum)


static func is_position_legal(
	slot_number: int, position: Vector2, positions_by_slot: Dictionary
) -> bool:
	return legal_bounds(slot_number, positions_by_slot).has_point(position)
