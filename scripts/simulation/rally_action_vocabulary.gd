class_name RallyActionVocabulary
extends RefCounted

const RallyEventModel := preload("res://scripts/models/rally_event.gd")


## At most this many named actions in one rally.
##
## From `docs/design/ACTION_VOCABULARY_DRAFT.md`, and it is the entire reason
## the vocabulary is worth having: "if every contact carries one, the labels
## become texture and we are back where we started." The classifier below is
## generous on purpose -- it says what each contact *would* be called -- and the
## budget is what turns that into a rally a viewer can read.
const NAMED_ACTIONS_PER_RALLY: int = 2
## Below this, a name is not worth spending budget on even if the classifier
## offered one. The draft's two named quadrants are the highlight and the
## blunder; everything between them is competent volleyball and reads best as
## silence.
const NAMING_THRESHOLD: float = 0.70


## Names outcomes from situation plus delivery. The result is written on the
## event once and then shared by captions, cognition, and later statistics.
##
## Two passes, because the budget is a property of the rally rather than of any
## contact: classify everything, then decide which classifications survive.
## `action_outcome` and `action_notability` stay on every event -- statistics
## will want the full picture -- and `named_action` is the one field that says
## whether a viewer should be told.
static func annotate(result: Resource) -> void:
	if result == null:
		return
	var candidates: Array[Dictionary] = []
	for index in range(result.events.size()):
		var event: Resource = result.events[index]
		var classification := classify(result, index)
		event.metadata["action_outcome"] = str(classification.name)
		event.metadata["action_notability"] = float(classification.notability)
		event.metadata["named_action"] = false
		if bool(classification.named) \
				and float(classification.notability) >= NAMING_THRESHOLD:
			candidates.append({
				"index": index,
				"notability": float(classification.notability),
				## The action that decided the point is always eligible, whatever
				## else the rally contained. A point whose decisive moment goes
				## unnamed while two earlier ones are named reads as the labels
				## having missed the thing everyone was watching.
				##
				## The last contact before the POINT event, rather than a match
				## on `decisive_actor_id`: the actor credited with a point is not
				## always the actor of its final contact -- a stuffed swing
				## credits the blocker while the last contact is the attack -- and
				## the moment a viewer watched is the contact, whoever it scored
				## for.
				"decisive": index == _final_contact_index(result.events),
			})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if bool(left.decisive) != bool(right.decisive):
			return bool(left.decisive)
		if not is_equal_approx(float(left.notability), float(right.notability)):
			return float(left.notability) > float(right.notability)
		## Later contacts win ties: the rally builds, and the moment nearer the
		## point is the one a viewer remembers.
		return int(left.index) > int(right.index)
	)
	for rank in range(mini(candidates.size(), NAMED_ACTIONS_PER_RALLY)):
		var chosen: Dictionary = candidates[rank]
		(result.events[int(chosen.index)] as Resource).metadata["named_action"] = true


static func classify(result: Resource, index: int) -> Dictionary:
	var event: Resource = result.events[index] if result != null \
		and index >= 0 and index < result.events.size() else null
	if event == null:
		return _result("", 0.0, false)
	var previous := _previous_contact(result.events, index)
	var next := _next_contact(result.events, index)
	var event_type := int(event.event_type)
	match event_type:
		RallyEventModel.EventType.SERVE:
			## **A serve is not named for how the rally ended.**
			##
			## This branch used to read `result.terminal_outcome` and call the
			## serve an Ace, which is information that does not exist until the
			## reception fails. The caption is shown when the serve is struck, so
			## 2D playback announced the ace while the ball was still in the air
			## and the receiver had not touched it. A caption that knows the
			## future is the same defect as a blocker who does.
			##
			## The name moves to the reception below, which is where the moment
			## actually resolves and the contact a viewer is watching when it
			## does.
			if not bool(event.success):
				return _result("Missed serve", 0.82, true)
			if next != null and int(next.event_type) == RallyEventModel.EventType.RECEPTION \
					and float(next.quality) < 0.45:
				return _result("Service pressure", 0.68, true)
			return _result("Serve in", 0.25, false)
		RallyEventModel.EventType.RECEPTION:
			## Where the ace is named. By the time this caption is on screen the
			## ball has already beaten the receiver, so nothing is given away --
			## and a reception that ended the rally is exactly the contact the
			## name belongs to.
			if str(result.terminal_outcome) == "ace" and not bool(event.success):
				return _result("Ace", 1.0, true)
			var reception_margin := float(event.metadata.get("arrival_margin", 0.2))
			if float(event.quality) >= 0.74 and reception_margin <= 0.12:
				return _result("Dime pass", 0.88, true)
			if float(event.quality) < 0.25 and reception_margin >= 0.18:
				return _result("Shank", 0.84, true)
			if bool(event.success) and reception_margin < 0.0:
				return _result("Scramble pass", 0.72, true)
			return _result("Pass controlled" if bool(event.success) else "Reception lost", 0.35, false)
		RallyEventModel.EventType.SET_DECISION:
			return _result("Option chosen", 0.34, false)
		RallyEventModel.EventType.SET:
			var following_block := _next_type(result.events, index, RallyEventModel.EventType.BLOCK)
			var prior_quality := float(previous.quality) if previous != null else 0.5
			## Both set names ask the same question -- did the wall get
			## there? -- and both asked it of `primary_close`, which cannot
			## answer it. The primary blocker is *selected* as the front-row
			## player nearest the attack lane, so their close saturates at
			## 1.00 at every percentile: measured, the excellent-set label fired
			## zero times across 800 rallies while the predictable-set label was
			## 20.5% of every
			## name in the game. The most important entry in the vocabulary
			## was unreachable and its opposite was the most common thing
			## that happened, both from one field.
			##
			## The blocker who travels is the assist, at 1.8-3.4 m against
			## the primary's 0.5-1.0 m. Isolation is the assist failing to
			## arrive; a full wall is the assist sealing.
			var assist_close := _assist_close(following_block)
			if bool(event.success) and float(event.quality) >= 0.72 \
					and following_block != null and assist_close < 0.48:
				return _result("Perfect set", 0.90, true)
			if bool(event.success) and prior_quality < 0.42 and float(event.quality) >= 0.56:
				return _result("Save set", 0.75, true)
			if following_block != null and assist_close >= 0.88:
				return _result("Predictable set", 0.74, true)
			return _result("Set delivered" if bool(event.success) else "Set missed", 0.34, false)
		RallyEventModel.EventType.ATTACK:
			var attack_block := _next_type(result.events, index, RallyEventModel.EventType.BLOCK)
			var attack_side_won := _side_won(result, str(event.metadata.get("side", "home")))
			var block_outcome := str(attack_block.metadata.get("outcome", "")) \
				if attack_block != null else ""
			if attack_side_won and block_outcome == "tool":
				return _result("Tool off the block", 1.0, true)
			if attack_side_won and block_outcome == "touch":
				return _result("Off the block", 0.82, true)
			if block_outcome == "stuff":
				return _result("Swung into the block", 0.90, true)
			if attack_side_won:
				var attack_type := str(event.metadata.get("attack_type", ""))
				var direction := str(event.metadata.get("attack_direction", ""))
				if attack_type in ["Roll shot", "Tip", "Short tip", "Emergency tip"]:
					return _result(attack_type, 0.76, true)
				if direction == "line":
					return _result("Line shot", 0.78, true)
				if direction == "seam":
					return _result("Seam kill", 0.80, true)
				if direction == "cross-court" and float(event.quality) >= 0.70:
					return _result("Hard cross-court attack", 0.84, true)
			if not bool(event.success) or bool(event.metadata.get("attack_missed", false)):
				return _result("Attack error", 0.76, false)
			return _result("Swing continued", 0.30, false)
		RallyEventModel.EventType.BLOCK:
			var outcome := str(event.metadata.get("outcome", "miss"))
			var block_side_won := _side_won(result, str(event.metadata.get("side", "home")))
			if outcome == "stuff":
				return _result("Roof", 1.0, true)
			if outcome == "tool" and not block_side_won:
				return _result("Tool off the block", 0.96, true)
			## Floor dig only. A funnel is the wall steering the ball into its own
			## back court; if the next contact is attack coverage the ball went
			## back to the hitters, which is the opposite result.
			if outcome == "funnel" and next != null \
					and int(next.event_type) == RallyEventModel.EventType.DIG \
					and bool(next.success):
				return _result("Funnel", 0.78, true)
			if outcome == "touch" and next != null \
					and int(next.event_type) == RallyEventModel.EventType.DIG \
					and bool(next.success):
				return _result("Block touch", 0.80, true)
			## Same correction: a wall beaten by tempo is one the
			## travelling blocker could not reach, which `primary_close`
			## cannot express.
			if outcome == "miss" and _assist_close(event) < 0.35:
				return _result("Late block", 0.70, true)
			return _result("Block formed", 0.32, false)
		## **The metadata test is gone because the event type now carries it.**
		## "Cover" was reached by asking a `DEFENSE` event whether its metadata
		## said `coverage == "attack"` -- a discriminator living beside the type
		## rather than in it, which is how the two contacts stayed conflated
		## everywhere else. The arms below are now decided by what the contact is.
		RallyEventModel.EventType.ATTACK_COVERAGE:
			if bool(event.success):
				return _result("Cover", 0.72, true)
			## A spilled cover keeps the wording it had before the split. It is
			## unreachable today -- coverage came up 38 times out of 38 across 700
			## rallies -- and inventing a phrase for a case nothing produces would
			## be adding vocabulary under cover of a rename.
			return _result("Defense beaten", 0.36, false)
		RallyEventModel.EventType.DIG:
			var defense_margin := float(event.metadata.get("arrival_margin", 0.2))
			if bool(event.success) and defense_margin < 0.0:
				return _result("Diving save", 0.86, true)
			if not bool(event.success) and defense_margin > 0.24:
				return _result("Missed the easy one", 0.82, true)
			return _result("Dig controlled" if bool(event.success) else "Defense beaten", 0.36, false)
		RallyEventModel.EventType.POINT:
			return _result("Point won" if bool(result.home_team_won) else "Point lost", 0.55, false)
	return _result(event.type_name(), 0.2, false)


## The last real contact of the rally, which is the moment the point turned on.
static func _final_contact_index(events: Array) -> int:
	for index in range(events.size() - 1, -1, -1):
		var event_type := int((events[index] as Resource).event_type)
		if event_type != RallyEventModel.EventType.POINT \
				and event_type != RallyEventModel.EventType.SET_DECISION:
			return index
	return -1


## How completely the second blocker sealed, before the 0.34 cut that zeroes it.
##
## `assist_close` is set to 0.0 when the best available blocker could not get
## there, so it cannot tell "nobody travelled" from "somebody travelled and
## failed" -- opposite readings for a set. `assist_close_attempted` keeps the
## pre-cut figure for exactly this.
static func _assist_close(block_event: Resource) -> float:
	if block_event == null:
		return 0.0
	return float(block_event.metadata.get(
		"assist_close_attempted",
		block_event.metadata.get("assist_close", 0.0),
	))


static func _result(name: String, notability: float, named: bool) -> Dictionary:
	return {"name": name, "notability": clampf(notability, 0.0, 1.0), "named": named}


static func _side_won(result: Resource, side: String) -> bool:
	return bool(result.home_team_won) if side == "home" else not bool(result.home_team_won)


static func _previous_contact(events: Array, index: int) -> Resource:
	for candidate_index in range(index - 1, -1, -1):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) != RallyEventModel.EventType.SET_DECISION \
				and int(candidate.event_type) != RallyEventModel.EventType.POINT:
			return candidate
	return null


static func _next_contact(events: Array, index: int) -> Resource:
	for candidate_index in range(index + 1, events.size()):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) != RallyEventModel.EventType.SET_DECISION \
				and int(candidate.event_type) != RallyEventModel.EventType.POINT:
			return candidate
	return null


static func _next_type(events: Array, index: int, event_type: int) -> Resource:
	for candidate_index in range(index + 1, events.size()):
		var candidate: Resource = events[candidate_index]
		if int(candidate.event_type) == event_type:
			return candidate
		if int(candidate.event_type) == RallyEventModel.EventType.POINT:
			break
	return null
