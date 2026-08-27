class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions. Presentation remains in BodyTypeModels; the
## shared body key is validated in CI.

const BODY_TYPES: Array[String] = ["Vegi", "Avi", "Cani", "Feli", "Ursi", "Simi"]

const BODY_TYPE_METRICS := {
	## Stride is deliberately absent. It is derived from post-variation height
	## and pinned by a regression check, so morphology reaches locomotion
	## through height and mass rather than by offsetting stride directly.
	## Vegi is the no-lean body, the way Landavol is the no-lean region: it
	## exists so "unremarkable" has a home instead of every type needing an
	## identity. It replaced Homi outright -- a plain human body in a world of
	## animals and produce was the one type that was not *anything*.
	"Vegi": {"height": 0.0, "mass": 0.0, "wingspan": 0.0},
	"Avi": {"height": -4.0, "mass": -7.0, "wingspan": 6.0},
	"Cani": {"height": 0.0, "mass": 2.0, "wingspan": 0.0},
	"Feli": {"height": -3.0, "mass": -4.0, "wingspan": 0.0},
	"Ursi": {"height": 1.0, "mass": 11.0, "wingspan": 1.0},
	"Simi": {"height": -6.0, "mass": -5.0, "wingspan": 2.0},
}

const BODY_TYPE_ATTRIBUTES := {
	"Vegi": {},
	"Avi": {"jump_reach": 4.0, "block_timing": 2.0, "reception_stability": -6.0},
	"Cani": {"stamina": 3.5, "transition_speed": 3.0, "attack_power": 2.0,
		"jump_reach": -4.5, "hand_control": -4.0},
	"Feli": {"explosiveness": 4.0, "lateral_speed": 3.0, "dig_control": 2.5,
		"set_disguise": 2.0, "stamina": -6.0, "tactical_discipline": -5.5},
	"Ursi": {"reception_stability": 4.0, "attack_power": 3.0, "composure": 2.0,
		"acceleration": -3.5, "lateral_speed": -3.0, "jump_reach": -2.5},
	"Simi": {"hand_control": 4.0, "ball_control": 3.5, "finesse": 3.0,
		"tooling": 2.0, "attack_power": -7.0, "jump_reach": -5.5},
}

static func attribute_modifiers(body_type: String) -> Dictionary:
	return Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))

static func metric_modifiers(body_type: String) -> Dictionary:
	return Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
