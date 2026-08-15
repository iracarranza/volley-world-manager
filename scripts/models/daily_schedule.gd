class_name DailySchedule
extends Resource

## How one day is spent, in blocks.
##
## The unit is a block rather than an hour, and there are 36 of them in a day.
## That is the flavour -- a day here is thirty-six *somethings* -- without asking
## anyone to relearn what sleep is: a block is forty minutes, so 36 of them is a
## 24-hour day, eight hours of sleep is twelve blocks, and a manager who never
## converts anything still gets a day that behaves the way days behave. Nothing
## in the model reads hours; the conversion exists for the one label that shows
## them.
##
## A schedule belongs either to the team or to one voli. Both are the same shape,
## because an individual schedule is a team schedule somebody has changed, and
## the interesting quantity is how far it has been changed.

const BLOCKS_PER_DAY: int = 36
const MINUTES_PER_BLOCK: int = 40

enum Activity {
	## The default. Unassigned time is not rest -- it is a voli left to their own
	## devices, which is neither restorative nor useful.
	FREE,
	SLEEP,
	MEAL,
	TRAINING,
	SOCIAL,
	## Assigned by the physio and not the manager's to move. A voli carrying one
	## of these has fewer blocks to give the club, which is the point.
	REHAB,
	## The club owes somebody an appearance. Mandatory, and it lands wherever the
	## sponsor put it.
	SPONSOR,
	TRAVEL,
}

## -1 for the club's own schedule; a player id for a personal one.
@export var owner_id: int = -1
@export var blocks: Array[int] = []


func _init() -> void:
	if blocks.is_empty():
		blocks = default_blocks()


## A day nobody has touched: eight hours asleep, three meals, two training
## sessions, an evening with the squad, the rest free.
##
## Deliberately a *legal* day rather than an empty one. A manager opening the
## screen for the first time should be looking at something that works, so the
## warnings they see later are ones they caused.
static func default_blocks() -> Array[int]:
	var day: Array[int] = []
	for index in range(BLOCKS_PER_DAY):
		day.append(Activity.FREE)
	for index in range(0, 12):
		day[index] = Activity.SLEEP
	day[13] = Activity.MEAL
	for index in range(15, 18):
		day[index] = Activity.TRAINING
	day[19] = Activity.MEAL
	for index in range(21, 24):
		day[index] = Activity.TRAINING
	day[27] = Activity.MEAL
	for index in range(29, 32):
		day[index] = Activity.SOCIAL
	return day


static func activity_name(value: int) -> String:
	match value:
		Activity.SLEEP:
			return "Sleep"
		Activity.MEAL:
			return "Meal"
		Activity.TRAINING:
			return "Training"
		Activity.SOCIAL:
			return "Social"
		Activity.REHAB:
			return "Rehab"
		Activity.SPONSOR:
			return "Sponsor"
		Activity.TRAVEL:
			return "Travel"
	return "Free"


## Blocks the manager may not reassign. A physio's rehab and a sponsor's
## appearance are obligations, not preferences.
static func is_locked(value: int) -> bool:
	return value in [Activity.REHAB, Activity.SPONSOR, Activity.TRAVEL]


func count_of(activity: int) -> int:
	var total := 0
	for value in blocks:
		if int(value) == activity:
			total += 1
	return total


## The clock label for a block index, for the one place that shows hours.
static func clock_label(index: int) -> String:
	var minutes := index * MINUTES_PER_BLOCK
	return "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]


## How many blocks of this day differ from the club's.
##
## The quantity individual scheduling is priced on: a voli who has moved one
## block to fit a rehab slot is not the same as one running their own day.
func deviation_from(other: DailySchedule) -> int:
	if other == null:
		return 0
	var differences := 0
	for index in range(mini(blocks.size(), other.blocks.size())):
		if int(blocks[index]) != int(other.blocks[index]):
			differences += 1
	return differences


func to_dict() -> Dictionary:
	return {"owner_id": owner_id, "blocks": blocks.duplicate()}


static func from_dict(data: Dictionary) -> DailySchedule:
	var schedule := DailySchedule.new()
	schedule.owner_id = int(data.get("owner_id", -1))
	var saved: Array = data.get("blocks", [])
	if saved.size() == BLOCKS_PER_DAY:
		schedule.blocks.assign(saved)
	return schedule
