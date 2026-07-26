class_name PlayValidator
extends RefCounted


static func validate(play: OffensivePlay, lineup: RotationLineup) -> Array[String]:
	var errors := lineup.validate()
	if play.play_name.strip_edges().is_empty():
		errors.append("Play name cannot be empty.")
	if play.rotation_number != lineup.rotation_number:
		errors.append("The play and lineup must use the same rotation.")
	if play.assignments.is_empty():
		errors.append("A play requires at least one hitter assignment.")
	var assigned_players := {}
	var used_priorities := {}
	for assignment in play.assignments:
		errors.append_array(assignment.validate())
		var rotation_slot := lineup.slot_for_player(assignment.player_id)
		if rotation_slot < 0:
			errors.append("Assigned hitter %d is not in this rotation." % assignment.player_id)
		elif not CourtConstants.is_front_row_slot(rotation_slot) \
				and assignment.lane != "Pipe":
			errors.append("Back-row hitters must use the Pipe lane in this prototype.")
		if assigned_players.has(assignment.player_id):
			errors.append("A hitter can only have one assignment per play.")
		assigned_players[assignment.player_id] = true
		if used_priorities.has(assignment.priority):
			errors.append("Hitter priorities must be unique.")
		used_priorities[assignment.priority] = true
	if play.primary_hitter_id not in assigned_players:
		errors.append("Primary hitter must have an assignment.")
	if play.primary_hitter_id >= 0 \
			and play.primary_hitter_id == play.secondary_hitter_id:
		errors.append("Primary and secondary options must be different hitters.")
	if play.secondary_hitter_id >= 0 \
			and play.secondary_hitter_id not in assigned_players:
		errors.append("Secondary hitter must have an assignment.")
	if not CourtConstants.is_valid_lane(play.fallback_lane):
		errors.append("Fallback lane is invalid.")
	return errors
