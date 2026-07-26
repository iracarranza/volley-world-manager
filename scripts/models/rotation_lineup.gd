class_name RotationLineup
extends Resource

@export_range(1, 6) var rotation_number: int = 1
@export var setter_id: int = -1
@export var slot_player_ids: Dictionary = {}


func assign_slot(slot_number: int, player_id: int) -> String:
	if slot_number < 1 or slot_number > 6:
		return "Rotation slot must be between 1 and 6."
	for existing_slot in slot_player_ids:
		if int(existing_slot) != slot_number \
				and int(slot_player_ids[existing_slot]) == player_id:
			return "A player cannot occupy two rotation slots."
	slot_player_ids[slot_number] = player_id
	return ""


func player_at_slot(slot_number: int) -> int:
	return int(slot_player_ids.get(slot_number, -1))


func slot_for_player(player_id: int) -> int:
	for slot_number in slot_player_ids:
		if int(slot_player_ids[slot_number]) == player_id:
			return int(slot_number)
	return -1


func front_row_player_ids() -> Array[int]:
	var result: Array[int] = []
	for slot_number in [2, 3, 4]:
		var player_id := player_at_slot(slot_number)
		if player_id >= 0:
			result.append(player_id)
	return result


func validate() -> Array[String]:
	var errors: Array[String] = []
	if rotation_number < 1 or rotation_number > 6:
		errors.append("Rotation number must be between 1 and 6.")
	if slot_player_ids.size() != 6:
		errors.append("A rotation requires exactly six occupied slots.")
	var unique_players := {}
	for slot_number in range(1, 7):
		var player_id := player_at_slot(slot_number)
		if player_id < 0:
			errors.append("Rotation slot %d is vacant." % slot_number)
		elif unique_players.has(player_id):
			errors.append("Player %d appears more than once." % player_id)
		else:
			unique_players[player_id] = true
	if setter_id not in unique_players:
		errors.append("The setter must occupy a rotation slot.")
	return errors


func to_dict() -> Dictionary:
	return {
		"rotation_number": rotation_number,
		"setter_id": setter_id,
		"slot_player_ids": slot_player_ids.duplicate(true),
	}


static func from_dict(data: Dictionary) -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = clampi(int(data.get("rotation_number", 1)), 1, 6)
	lineup.setter_id = int(data.get("setter_id", -1))
	var saved_slots: Dictionary = data.get("slot_player_ids", {})
	for raw_slot in saved_slots:
		lineup.slot_player_ids[int(raw_slot)] = int(saved_slots[raw_slot])
	return lineup
