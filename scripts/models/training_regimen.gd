class_name TrainingRegimen
extends Resource

## What one training squad is being asked to do this week.
##
## The old system had a single activity for the entire roster and moved every
## attribute in that activity's list by +1 for every player. Nothing about it
## could express the two things that make training a decision: *who* is doing
## what, and *how narrowly*.
##
## A regimen is a squad plus an activity plus a focus. The squad is a set of
## player ids, so a club can run its middles on blocking while the pins do film
## review. The focus is the trade the manager actually makes.

enum Focus {
	## Turn up and work. The squad takes what the session gives them: attributes
	## come out of the activity's pool at random, progress is thin, and it costs
	## the least fatigue of the three.
	LOW,
	## Work with a plan. The pool is still the source, but the manager can strike
	## attributes off it -- "no more jump training on the setter" -- and what is
	## left is sampled.
	MEDIUM,
	## Work on one thing. The manager names the attributes outright, and because
	## the week's progress is divided among however many are named, naming fewer
	## moves each of them further.
	HIGH,
}

@export var squad_name: String = "First Squad"
@export var activity: String = "Team Practice"
@export var focus: Focus = Focus.MEDIUM
@export var player_ids: Array[int] = []
## At `HIGH` these are the attributes chosen. At `MEDIUM` they are the ones
## struck off. At `LOW` they are ignored, because a squad working at low focus
## does not get to choose.
@export var attributes: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"squad_name": squad_name,
		"activity": activity,
		"focus": int(focus),
		"player_ids": player_ids.duplicate(),
		"attributes": attributes.duplicate(),
	}


static func from_dict(data: Dictionary) -> TrainingRegimen:
	var regimen := TrainingRegimen.new()
	regimen.squad_name = str(data.get("squad_name", "First Squad"))
	regimen.activity = str(data.get("activity", "Team Practice"))
	regimen.focus = int(data.get("focus", Focus.MEDIUM)) as Focus
	regimen.player_ids.assign(data.get("player_ids", []))
	regimen.attributes.assign(data.get("attributes", []))
	return regimen


static func focus_name(value: int) -> String:
	match value:
		Focus.LOW:
			return "Low"
		Focus.HIGH:
			return "High"
	return "Medium"
