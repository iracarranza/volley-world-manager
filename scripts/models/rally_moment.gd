class_name RallyMoment
extends RefCounted

enum Kind {
	PERCEPTION,
	MOVEMENT_UPDATE,
	OPPORTUNITY_OPEN,
	INTENT_DEADLINE,
	OPPORTUNITY_CLOSE,
	BALL_CONTACT,
	BALL_LANDING,
	RECOVERY_COMPLETE,
}

var time: float = 0.0
var kind: Kind = Kind.PERCEPTION
var side: StringName = &""
var player_id: int = -1
var data: Dictionary = {}


static func create(
	at_time: float,
	moment_kind: Kind,
	moment_side: StringName = &"",
	moment_player_id: int = -1,
	payload: Dictionary = {},
) -> RallyMoment:
	var moment := RallyMoment.new()
	moment.time = at_time
	moment.kind = moment_kind
	moment.side = moment_side
	moment.player_id = moment_player_id
	moment.data = payload.duplicate(true)
	return moment
