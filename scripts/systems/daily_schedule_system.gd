class_name DailyScheduleSystem
extends RefCounted

## What a day costs and what it buys.
##
## The schedule is the club's one lever that touches everything else: it decides
## how many training blocks the training screen has to spend, how much fatigue
## comes back overnight, whether the squad eats, and how much of the roster is
## living the same day as everybody else. A manager who wants a third training
## session has to take those blocks from something, and this is where the bill
## arrives.
##
## Warnings rather than prohibitions. A club *may* train at four in the morning
## on five hours' sleep; it will simply be worse at volleyball. Blocking the
## manager from doing it would make the schedule a form to fill in, and the point
## is that it is a set of trades.

const DailyScheduleModel := preload("res://scripts/models/daily_schedule.gd")

## The sleep a voli needs, in blocks. Twelve is eight hours.
const SLEEP_BLOCKS_IDEAL: int = 12
const SLEEP_BLOCKS_MINIMUM: int = 9
## How much of the night's recovery a fully slept day returns, against a day with
## none at all.
const RECOVERY_AT_FULL_SLEEP: float = 0.26
const RECOVERY_AT_NO_SLEEP: float = -0.04

## Meals a day, and what missing them costs.
const MEALS_EXPECTED: int = 3
const MISSED_MEAL_RECOVERY_PENALTY: float = 0.05
const MISSED_MEAL_SATISFACTION: float = 0.02

## The block index before which training is too early to be worth much, and
## after which it is too late. Read against a default day that sleeps 0-11.
const TRAINING_EARLIEST_BLOCK: int = 14
const TRAINING_LATEST_BLOCK: int = 30
## How much of a session survives being scheduled outside those bounds.
const OFF_HOURS_TRAINING_YIELD: float = 0.62

## What living the club's day is worth, and what going your own way costs.
const TEAM_SCHEDULE_MORALE: float = 0.012
const OWN_SCHEDULE_MORALE: float = -0.008
## How many blocks a voli may differ by before they count as running their own
## day. One or two is fitting a rehab slot around the club's session.
const DEVIATION_TOLERANCE_BLOCKS: int = 3
## The share of the roster that can be on its own schedule before the squad stops
## being a squad, and what it costs when they are.
const INDIVIDUAL_SCHEDULE_TOLERANCE: float = 0.34
const COHESION_FRACTURE_PENALTY: float = 0.045


## Everything a day implies, for one schedule.
##
## Returned as one dictionary rather than five functions because every consumer
## wants more than one of these and computing them separately is how two callers
## come to disagree about how many training blocks there are.
static func evaluate(schedule: DailySchedule) -> Dictionary:
	if schedule == null:
		return {
			"training_blocks": 0, "effective_training_blocks": 0.0,
			"recovery": 0.0, "satisfaction": 0.0, "warnings": [],
		}
	var sleep := schedule.count_of(DailyScheduleModel.Activity.SLEEP)
	var meals := schedule.count_of(DailyScheduleModel.Activity.MEAL)
	var social := schedule.count_of(DailyScheduleModel.Activity.SOCIAL)
	var warnings: Array[String] = []

	## Sleep is the load-bearing one: it sets recovery, and recovery is what
	## makes tomorrow's training worth anything.
	var sleep_fraction := clampf(float(sleep) / float(SLEEP_BLOCKS_IDEAL), 0.0, 1.0)
	var recovery := lerpf(RECOVERY_AT_NO_SLEEP, RECOVERY_AT_FULL_SLEEP, sleep_fraction)
	if sleep < SLEEP_BLOCKS_MINIMUM:
		warnings.append(
			"Only %s of sleep. The squad will not recover overnight."
				% _duration_label(sleep)
		)
	elif sleep < SLEEP_BLOCKS_IDEAL:
		warnings.append(
			"%s of sleep is short of a full night." % _duration_label(sleep)
		)

	if meals < MEALS_EXPECTED:
		recovery -= MISSED_MEAL_RECOVERY_PENALTY * float(MEALS_EXPECTED - meals)
		warnings.append(
			"%d meal%s scheduled. Volis eat three times a day here too."
				% [meals, "" if meals == 1 else "s"]
		)

	## Training outside the sensible window still happens, it is just worth less.
	var training_blocks := 0
	var effective := 0.0
	var off_hours := 0
	for index in range(schedule.blocks.size()):
		if int(schedule.blocks[index]) != DailyScheduleModel.Activity.TRAINING:
			continue
		training_blocks += 1
		if index < TRAINING_EARLIEST_BLOCK or index >= TRAINING_LATEST_BLOCK:
			off_hours += 1
			effective += OFF_HOURS_TRAINING_YIELD
		else:
			effective += 1.0
	if off_hours > 0:
		warnings.append(
			"%d training block%s scheduled outside %s-%s and will not land fully."
				% [
					off_hours, "" if off_hours == 1 else "s",
					DailyScheduleModel.clock_label(TRAINING_EARLIEST_BLOCK),
					DailyScheduleModel.clock_label(TRAINING_LATEST_BLOCK),
				]
		)
	if training_blocks == 0:
		warnings.append("No training scheduled. Nobody improves today.")

	var satisfaction := 0.0
	if meals < MEALS_EXPECTED:
		satisfaction -= MISSED_MEAL_SATISFACTION * float(MEALS_EXPECTED - meals)
	if social <= 0:
		satisfaction -= 0.01
		warnings.append("No social time. A squad that only trains stops liking it.")

	return {
		"sleep_blocks": sleep,
		"meal_blocks": meals,
		"social_blocks": social,
		"training_blocks": training_blocks,
		## What the training screen may actually spend. Off-hours blocks count
		## for less, so a manager who moves a session to 04:00 to fit more in
		## discovers they fitted less in.
		"effective_training_blocks": effective,
		"recovery": recovery,
		"satisfaction": satisfaction,
		"warnings": warnings,
	}


## How a roster's mix of schedules lands on morale and cohesion.
##
## Being on the club's day is worth a little morale to the individual; running
## your own costs a little. The team-level term is separate and sharper: past a
## third of the roster on their own schedules the squad stops sharing a day at
## all, and cohesion pays for it whatever the individuals feel.
static func evaluate_roster(
	team_schedule: DailySchedule,
	personal: Dictionary,
	roster_size: int,
) -> Dictionary:
	var own_day := 0
	var per_player := {}
	for player_id in personal:
		var schedule: DailySchedule = personal[player_id] as DailySchedule
		if schedule == null:
			continue
		var deviation := schedule.deviation_from(team_schedule)
		var independent := deviation > DEVIATION_TOLERANCE_BLOCKS
		if independent:
			own_day += 1
		per_player[player_id] = {
			"deviation_blocks": deviation,
			"independent": independent,
			"satisfaction": OWN_SCHEDULE_MORALE if independent else TEAM_SCHEDULE_MORALE,
		}
	var share := float(own_day) / maxf(float(roster_size), 1.0)
	var cohesion := 0.0
	var warnings: Array[String] = []
	if share > INDIVIDUAL_SCHEDULE_TOLERANCE:
		cohesion -= COHESION_FRACTURE_PENALTY \
			* (share - INDIVIDUAL_SCHEDULE_TOLERANCE) \
			/ maxf(1.0 - INDIVIDUAL_SCHEDULE_TOLERANCE, 0.001)
		warnings.append(
			"%d of %d volis are running their own day. The squad is drifting apart."
				% [own_day, roster_size]
		)
	return {
		"independent_count": own_day,
		"independent_share": share,
		"cohesion": cohesion,
		"per_player": per_player,
		"warnings": warnings,
	}


## Traits that move a voli's workable hours.
##
## `traits` has been on `VolleyballPlayer` since the model was written and read
## by nothing -- it turned up in the inert-attribute audit alongside `arm_speed`
## and `feinting`. This gives it its first job, and the schedule is the natural
## place for it: whether somebody can train at dawn is exactly the kind of fact a
## trait should carry, and it is a fact with a consequence rather than a label on
## a profile page.
##
## The shift is in blocks and applies to both ends of the sensible window, so an
## early riser gains morning and loses evening rather than gaining a longer day.
## Nobody gets more hours; they get different ones.
const TRAIT_WINDOW_SHIFT := {
	"Early Riser": -4,
	"Night Owl": 5,
}
## A voli carrying rehab has that many blocks taken out of their day by the
## physio before the manager sees it.
const REHAB_BLOCKS: int = 2


## The hours this voli can work, as a start/end pair of block indices.
static func training_window_for(player: VolleyballPlayer) -> Vector2i:
	var shift := 0
	if player != null:
		for trait_name in player.traits:
			shift += int(TRAIT_WINDOW_SHIFT.get(str(trait_name), 0))
	return Vector2i(
		clampi(TRAINING_EARLIEST_BLOCK + shift, 0, DailyScheduleModel.BLOCKS_PER_DAY),
		clampi(TRAINING_LATEST_BLOCK + shift, 0, DailyScheduleModel.BLOCKS_PER_DAY),
	)


## How much of this voli's scheduled training actually lands, given their own
## hours rather than the club's.
##
## The club-wide `evaluate` uses the default window because a club schedule has
## no single owner; this is what a personal schedule is judged by, and it is why
## a night owl on their own late schedule is not being punished for it.
static func personal_training_yield(
	schedule: DailySchedule,
	player: VolleyballPlayer,
) -> float:
	if schedule == null:
		return 0.0
	var window := training_window_for(player)
	var total := 0.0
	for index in range(schedule.blocks.size()):
		if int(schedule.blocks[index]) != DailyScheduleModel.Activity.TRAINING:
			continue
		total += 1.0 if index >= window.x and index < window.y \
			else OFF_HOURS_TRAINING_YIELD
	return total


## Put the physio's blocks on a day. Called when a voli picks up a knock, so the
## manager finds the time already gone rather than being asked to donate it.
static func assign_rehab(schedule: DailySchedule, blocks: int = REHAB_BLOCKS) -> void:
	if schedule == null:
		return
	var placed := 0
	for index in range(TRAINING_EARLIEST_BLOCK, schedule.blocks.size()):
		if placed >= blocks:
			return
		## Takes free time first and training second. It never takes sleep or a
		## meal -- a physio who books rehab over somebody's only meal is not a
		## trade the manager should be handed.
		var current := int(schedule.blocks[index])
		if current in [
			DailyScheduleModel.Activity.FREE,
			DailyScheduleModel.Activity.TRAINING,
		]:
			schedule.blocks[index] = DailyScheduleModel.Activity.REHAB
			placed += 1


## Blocks the club owes somebody, laid on the day before the manager sees it.
##
## `SPONSOR` and `TRAVEL` were enum values with nothing to create them, which is
## the same shape as an attribute nothing reads: the model could express the
## obligation and the game never handed one out. These are what hand them out.
##
## A sponsor appearance lands in the evening, where a club would actually put one
## -- it is the social block that goes, not the training. Travel takes the
## morning, because a squad that flew overnight is not training at nine.
const SPONSOR_BLOCKS: int = 3
const TRAVEL_BLOCKS: int = 6


## An appearance the club owes. Takes social time first, then free time, and
## never training -- a sponsor who costs the squad a session is a different
## decision and belongs to the manager, not to the calendar.
static func assign_sponsor_block(
	schedule: DailySchedule,
	blocks: int = SPONSOR_BLOCKS,
) -> void:
	_lay_obligation(
		schedule, blocks, DailyScheduleModel.Activity.SPONSOR,
		[DailyScheduleModel.Activity.SOCIAL, DailyScheduleModel.Activity.FREE],
		TRAINING_LATEST_BLOCK - 4,
	)


## The morning after a flight. Takes whatever the morning had, including
## training, because that is the point of jet lag.
static func assign_travel_block(
	schedule: DailySchedule,
	blocks: int = TRAVEL_BLOCKS,
) -> void:
	_lay_obligation(
		schedule, blocks, DailyScheduleModel.Activity.TRAVEL,
		[
			DailyScheduleModel.Activity.FREE,
			DailyScheduleModel.Activity.TRAINING,
			DailyScheduleModel.Activity.SOCIAL,
		],
		SLEEP_BLOCKS_IDEAL,
	)


## Lay `blocks` of `activity` from `start`, consuming only what `takeable`
## allows. Never touches sleep or meals -- an obligation that skips a squad's
## night or their food is a bug, not a hard week.
static func _lay_obligation(
	schedule: DailySchedule,
	blocks: int,
	activity: int,
	takeable: Array,
	start: int,
) -> void:
	if schedule == null:
		return
	var placed := 0
	for index in range(maxi(start, 0), schedule.blocks.size()):
		if placed >= blocks:
			return
		if int(schedule.blocks[index]) in takeable:
			schedule.blocks[index] = activity
			placed += 1


static func _duration_label(blocks: int) -> String:
	var minutes := blocks * DailyScheduleModel.MINUTES_PER_BLOCK
	if minutes % 60 == 0:
		return "%dh" % (minutes / 60)
	return "%dh%02d" % [minutes / 60, minutes % 60]
