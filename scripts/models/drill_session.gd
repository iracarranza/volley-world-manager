class_name DrillSession
extends RefCounted

## What there is to rehearse on the one day the manager is on the floor.
##
## **The drill list is not a menu.** Every entry here is read off the club's own
## `TacticSheet` -- the phases somebody has written instructions in, the net zone
## somebody circled -- so a manager can only drill what they have actually
## decided. A screen offering "block formation" to a club that has never told a
## blocker anything is offering to rehearse nothing, and that is the shape of
## training menu this game is trying not to be.
##
## The budget is the day's, and it binds. The squad trains all week; this is the
## session the manager attends, so the question is not whether the club works but
## *what it works on*, and the hours are what makes that a choice rather than a
## checklist. Everything on the sheet gains a little familiarity from the week's
## ordinary work -- see `BASE_FAMILIARITY` -- and what is drilled here gains more.

const TacticSheetModel := preload("res://scripts/models/tactic_sheet.gd")
const DailyScheduleModel := preload("res://scripts/models/daily_schedule.gd")

## What one drill costs, in schedule blocks. Two blocks is eighty minutes, which
## is a real block of court time: long enough to run a rotation through a
## formation repeatedly, short enough that a full training day holds several.
const DRILL_BLOCKS: int = 2

## What the week's ordinary work is worth to the whole plan, and what attending
## the session and focusing on one thing is worth on top of it.
##
## The base is deliberately not zero. A club that never sends its manager still
## rehearses its own system -- that is what the other six days are -- so the
## session buys *concentration*, not existence. If the base were zero the
## sensible play would be to attend every week and nothing else would matter.
const BASE_FAMILIARITY: float = 0.006
const DRILLED_FAMILIARITY: float = 0.022

## The warm-up. Always present, never chosen, costs nothing.
##
## Here so the session opens on something happening rather than on an empty
## court: peppers and platform work are what a squad is doing when the manager
## walks in, and they are the reason the first thing you watch is not a decision.
const WARMUP := {
	"key": "warmup",
	"title": "Peppers and platform work",
	"detail": "The squad is already on it. Costs nothing and decides nothing.",
	"blocks": 0,
	"phase": "",
}


## Everything this club could put the session on, warm-up first.
##
## `roster_names` maps a sheet slot to the name standing in it, so a drill reads
## as the people who will run it rather than as a row of slot numbers. A slot
## with nobody in it is still listed -- the plan is the shape, and a hole in the
## line-up is a thing a manager should see on the training floor rather than
## discover in a match.
static func available(
	sheet: TacticSheet,
	roster_names: Dictionary = {},
) -> Array[Dictionary]:
	var drills: Array[Dictionary] = [WARMUP.duplicate()]
	if sheet == null:
		return drills
	for phase in ["Attack", "Block", "Floor"]:
		var instructions := sheet.behaviours_for(phase)
		if instructions.is_empty():
			continue
		var slots := instructions.keys()
		slots.sort()
		var parts: Array[String] = []
		for slot in slots:
			parts.append("%s %s" % [
				str(roster_names.get(int(slot), "Slot %d" % int(slot))),
				str(instructions[slot]),
			])
		drills.append({
			"key": "phase:%s" % phase,
			"title": "%s formation" % phase,
			"detail": " · ".join(parts),
			"blocks": DRILL_BLOCKS,
			"phase": phase,
		})
	if not sheet.placements.is_empty():
		drills.append({
			"key": "zone:%d" % int(sheet.drill_zone),
			"title": "Cover the %s" % _zone_label(int(sheet.drill_zone)).to_lower(),
			"detail": "The zone circled on the clipboard, run against a live swing.",
			"blocks": DRILL_BLOCKS,
			"phase": "Block",
		})
	return drills


## How many blocks of court time this day gives the session.
##
## Read off the club's own day rather than granted: a manager who scheduled two
## training blocks has two, and the schedule screen is where that is argued with.
static func budget_blocks(schedule: DailySchedule) -> int:
	if schedule == null:
		return 0
	var blocks := 0
	for value in schedule.blocks:
		if int(value) == DailyScheduleModel.Activity.TRAINING:
			blocks += 1
	return blocks


static func blocks_to_hours(blocks: int) -> float:
	return float(blocks) * float(DailyScheduleModel.MINUTES_PER_BLOCK) / 60.0


## What a set of chosen drills costs.
static func cost_blocks(chosen: Array, drills: Array[Dictionary]) -> int:
	var total := 0
	for drill in drills:
		if str(drill.key) in chosen:
			total += int(drill.blocks)
	return total


## Whether one more drill fits in what is left.
static func affords(
	chosen: Array, key: String, drills: Array[Dictionary], budget: int
) -> bool:
	if key in chosen:
		return true
	for drill in drills:
		if str(drill.key) == key:
			return cost_blocks(chosen, drills) + int(drill.blocks) <= budget
	return false


## What the session was worth, applied to the club.
##
## Returns what it did rather than only doing it, because a session the manager
## attended should be able to say what it bought -- the receipts on the clipboard
## are the consumer, and a number nothing can report is a number nobody trusts.
static func apply(team: VolleyballTeam, chosen: Array) -> Dictionary:
	if team == null:
		return {"familiarity": 0.0, "drilled": 0}
	var drilled := 0
	for key in chosen:
		if str(key) != WARMUP.key:
			drilled += 1
	var gain := BASE_FAMILIARITY + DRILLED_FAMILIARITY * float(drilled)
	team.tactical_familiarity = clampf(
		float(team.tactical_familiarity) + gain, 0.0, 1.0
	)
	return {"familiarity": gain, "drilled": drilled}


static func _zone_label(index: int) -> String:
	var labels := ["Line", "Seam", "Cross", "Tip"]
	return labels[clampi(index, 0, labels.size() - 1)]
