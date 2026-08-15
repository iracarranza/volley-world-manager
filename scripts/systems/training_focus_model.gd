class_name TrainingFocusModel
extends RefCounted

## What a week of focus is worth, and what it costs.
##
## Training used to give every attribute in an activity's list +1 for every
## player, every week. That is not a decision -- it is a tick, and a squad
## running "Attack & Transition" moved ten attributes at once whether the manager
## wanted three of them or not. It also meant training could never be *aimed*,
## which is the whole reason a manager would look at the screen.
##
## Focus is the trade. A squad working loosely takes what the session gives them
## and pays little for it; a squad working narrowly moves what the manager named
## and pays for that in fatigue. The progress a week is worth is a *budget*, and
## it is divided among however many attributes actually improve -- so naming
## three attributes moves each of them further than naming ten, which is the one
## rule that makes high focus mean anything.
##
## Progress is carried as a fraction rather than an integer step. The old +1 was
## the smallest change the model could express, so it was also the largest: there
## was no such thing as a week of slow progress, only a week that moved a number
## or a week that did not.

const TrainingRegimenModel := preload("res://scripts/models/training_regimen.gd")

## The week's total progress budget, in attribute points, before focus scales it.
##
## One point a week at medium focus spread over a handful of attributes is
## deliberately slow: a season is about thirty weeks, and a player who could add
## thirty points to one attribute in a season would make scouting pointless.
const WEEKLY_PROGRESS_POINTS: float = 1.15

## How focus scales the week's progress and its fatigue, indexed LOW/MEDIUM/HIGH.
##
## Low focus is cheap and thin; high focus is neither. The progress spread is
## narrower than the fatigue spread on purpose -- a hard week should cost more
## than it returns in raw points, and buy its value by being *aimed* instead.
const FOCUS_PROGRESS_SCALE: Array[float] = [0.72, 1.0, 1.22]
const FOCUS_FATIGUE_SCALE: Array[float] = [0.68, 1.0, 1.34]

## How many of an activity's attributes a squad touches when it is not choosing.
##
## Low focus draws this many at random from the pool; medium draws from what is
## left after the manager's exclusions. Three, because a pool runs to ten and a
## session that moved all of them would be high focus with none of the cost.
const UNFOCUSED_ATTRIBUTE_DRAW: int = 3

## The fewest attributes a high-focus week may be aimed at, and the most it may
## be spread across before it stops being focused.
##
## The lower bound exists because the budget is divided by this count: aiming a
## week at zero attributes would be a division by nothing, and aiming it at one
## is already the sharpest the system offers.
const HIGH_FOCUS_MIN: int = 1
const HIGH_FOCUS_MAX: int = 6


## The attributes this regimen actually moves for one player, this week.
##
## `pool` is the activity's own list. The draw is seeded from the player and the
## week so a squad does not re-roll the same session differently for each member,
## and so a week replays identically.
static func selected_attributes(
	regimen: TrainingRegimen,
	pool: Array,
	player_id: int,
	week: int,
) -> Array[String]:
	var available: Array[String] = []
	for entry in pool:
		available.append(str(entry))
	if available.is_empty():
		return available

	match regimen.focus:
		TrainingRegimenModel.Focus.HIGH:
			## Named outright. Anything not in the activity's pool is dropped
			## rather than trained -- a manager cannot decide that serving
			## practice improves a hitter's jump.
			var chosen: Array[String] = []
			for entry in regimen.attributes:
				if str(entry) in available and str(entry) not in chosen:
					chosen.append(str(entry))
				if chosen.size() >= HIGH_FOCUS_MAX:
					break
			if chosen.size() >= HIGH_FOCUS_MIN:
				return chosen
			## Nothing valid was named, so this is a loosely worked week whatever
			## the manager set it to.
			return _draw(available, player_id, week, UNFOCUSED_ATTRIBUTE_DRAW)
		TrainingRegimenModel.Focus.MEDIUM:
			var remaining: Array[String] = []
			for entry in available:
				if entry not in regimen.attributes:
					remaining.append(entry)
			if remaining.is_empty():
				remaining = available
			return _draw(remaining, player_id, week, UNFOCUSED_ATTRIBUTE_DRAW)
		_:
			return _draw(available, player_id, week, UNFOCUSED_ATTRIBUTE_DRAW)


## How much each named attribute moves, in points, for one player this week.
##
## The budget divided by the count, so three attributes move further than ten.
## `receptiveness` is the player's own half of it -- a week is worth more to
## somebody who learns quickly and to somebody who is not already exhausted.
static func progress_per_attribute(
	regimen: TrainingRegimen,
	attribute_count: int,
	receptiveness: float,
) -> float:
	if attribute_count <= 0:
		return 0.0
	var scale := FOCUS_PROGRESS_SCALE[
		clampi(int(regimen.focus), 0, FOCUS_PROGRESS_SCALE.size() - 1)
	]
	return WEEKLY_PROGRESS_POINTS * scale * maxf(receptiveness, 0.0) \
		/ float(attribute_count)


## What a week at this focus costs the body, against the activity's own base.
static func fatigue_cost(regimen: TrainingRegimen, activity_fatigue: float) -> float:
	return activity_fatigue * FOCUS_FATIGUE_SCALE[
		clampi(int(regimen.focus), 0, FOCUS_FATIGUE_SCALE.size() - 1)
	]


## How much of a week's work a player takes in.
##
## Adaptability is how quickly they pick things up and work rate is how much of
## the session they actually do; fatigue is the drag on both, because a squad
## trained into the ground stops improving before it stops turning up. Youth
## carries the rest: the same drill is worth more to a twenty-year-old, which is
## what makes an academy an academy.
static func receptiveness(player: VolleyballPlayer) -> float:
	if player == null:
		return 0.0
	var learning := clampf(float(player.adaptability) / 100.0, 0.0, 1.0) * 0.5 \
		+ clampf(float(player.work_rate) / 100.0, 0.0, 1.0) * 0.5
	var freshness := lerpf(1.0, 0.45, clampf(player.fatigue, 0.0, 1.0))
	var youth := lerpf(1.25, 0.72, clampf((float(player.age) - 18.0) / 14.0, 0.0, 1.0))
	return lerpf(0.55, 1.35, learning) * freshness * youth


static func _draw(
	source: Array[String],
	player_id: int,
	week: int,
	count: int,
) -> Array[String]:
	if source.size() <= count:
		return source.duplicate()
	## Seeded from the player and the week rather than a live RNG, so a replayed
	## week trains the same attributes and nothing downstream re-sequences.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%d|%d" % [player_id, week, source.size()])
	var pool := source.duplicate()
	var picked: Array[String] = []
	for index in range(count):
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked
