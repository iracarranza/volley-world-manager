class_name SetterCapabilitySystem
extends RefCounted

## What a setter can actually do with the ball they are about to receive.
##
## These are *limits*, not penalties. Before this, every setter could run every
## tempo off every pass and take a ball at any height; attributes only nudged
## the resulting quality by a fraction. A weak setter running a quick set paid
## 0.165 quality for it, which is a rounding error in a rally, so the difference
## between a great setter and a poor one was not visible in a single point.
##
## Three limits are modelled, and each maps to a different attribute family:
##
## 1. **Tempo command** (technical/mental). A fast set demands more command than
##    a slow one, and a poor pass raises that demand further. A setter without
##    the command for the called tempo does not run it badly -- the tempo is
##    absent from `available_tempos` and the offence is forced to downgrade.
## 2. **Pass recovery** (technical/mental). Command also buys back part of what
##    a bad pass costs, so skill matters *most* when the pass is worst. This is
##    the interaction the old linear `reception_quality * 0.28` term could not
##    express: a bad pass used to cost an elite setter exactly what it cost a
##    novice.
## 3. **Reach** (physical). A ball arriving above a setter's standing reach must
##    be jump-set, and one above their jump reach cannot be set at all. Height
##    and jump are hard walls rather than curves, because that is how they fail
##    in the sport: you either get a hand to it or you do not.
##
## The resulting dictionary is attached to the SET event, so every one of these
## decisions is legible in the rally record rather than buried in a quality roll.

const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)

## Tempo indices run fast to slow: 0 is a quick set, 3 a high ball.
const QUICK_TEMPO: int = 0
const SLOWEST_TEMPO: int = 3

## Command required to run each tempo off a perfect pass.
const TEMPO_COMMAND_FLOOR: Array[float] = [0.72, 0.55, 0.36, 0.0]

## Extra command each tempo demands as the pass degrades. A high ball is
## forgiving by definition, which is why it is always available -- it is the
## option a scrambling team always has.
const TEMPO_PASS_SENSITIVITY: Array[float] = [0.35, 0.24, 0.14, 0.0]

## How much of a bad pass a fully commanding setter can recover.
const PASS_RECOVERY_SHARE: float = 0.45

## Height band a pass arrives in. A controlled pass is delivered into the
## setter's window; a poor one sails, which is what puts it out of reach.
const CONTROLLED_PASS_HEIGHT_M: float = 2.05
const LOOSE_PASS_HEIGHT_M: float = 2.25
const MAXIMUM_PASS_SAIL_M: float = 1.10


## The technical and mental command this setter brings to the second contact.
static func command(setter: VolleyballPlayer) -> float:
	if setter == null:
		return 0.0
	return clampf((
		float(setter.tempo_control) * 0.45
		+ float(setter.hand_control) * 0.30
		+ float(setter.composure) * 0.25
	) / 100.0, 0.0, 1.0)


## Height the pass arrives at. `sail` is a seeded 0-1 roll owned by the caller,
## so this stays deterministic and free of its own randomness.
static func pass_contact_height_meters(pass_quality: float, sail: float) -> float:
	var quality := clampf(pass_quality, 0.0, 1.0)
	return lerpf(LOOSE_PASS_HEIGHT_M, CONTROLLED_PASS_HEIGHT_M, quality) \
		+ (1.0 - quality) * clampf(sail, 0.0, 1.0) * MAXIMUM_PASS_SAIL_M


## Tempos this setter can legally call, fastest first.
static func available_tempos(
	setter: VolleyballPlayer,
	pass_quality: float,
) -> Array[int]:
	var setter_command := command(setter)
	var deficit := 1.0 - clampf(pass_quality, 0.0, 1.0)
	var available: Array[int] = []
	for tempo in range(TEMPO_COMMAND_FLOOR.size()):
		var required := TEMPO_COMMAND_FLOOR[tempo] \
			+ deficit * TEMPO_PASS_SENSITIVITY[tempo]
		if setter_command >= required:
			available.append(tempo)
	## The high ball is always reachable as an option; a team out of system still
	## has to put the ball somewhere.
	if not available.has(SLOWEST_TEMPO):
		available.append(SLOWEST_TEMPO)
	return available


## Effective pass quality this setter works with. Command buys back part of a
## bad pass, so the gap between setters widens as the pass gets worse.
static func effective_pass_quality(
	setter: VolleyballPlayer,
	pass_quality: float,
) -> float:
	var quality := clampf(pass_quality, 0.0, 1.0)
	return clampf(
		quality + (1.0 - quality) * command(setter) * PASS_RECOVERY_SHARE,
		0.0, 1.0,
	)


## Full capability read for one second contact.
static func evaluate(
	setter: VolleyballPlayer,
	requested_tempo: int,
	pass_quality: float,
	contact_height_meters: float,
) -> Dictionary:
	if setter == null:
		return {
			"available_tempos": [SLOWEST_TEMPO],
			"resolved_tempo": SLOWEST_TEMPO,
			"tempo_downgraded": false,
			"reach_state": "unreachable",
		}
	var tempos := available_tempos(setter, pass_quality)
	var wanted := clampi(requested_tempo, QUICK_TEMPO, SLOWEST_TEMPO)
	## Downgrade to the fastest tempo actually available. A setter who cannot
	## run the called play does not fail it -- they put up something slower, and
	## the blockers get to read it.
	var resolved := wanted
	if not tempos.has(wanted):
		resolved = SLOWEST_TEMPO
		for tempo in tempos:
			if tempo >= wanted and tempo < resolved:
				resolved = tempo

	var standing_reach := setter.standing_reach_cm() / 100.0
	var maximum_reach := standing_reach \
		+ ContactEnvelopeModel.nominal_jump_displacement_meters(setter, &"set")
	var reach_state := "standing"
	if contact_height_meters > maximum_reach:
		reach_state = "unreachable"
	elif contact_height_meters > standing_reach:
		reach_state = "jump"

	return {
		"command": command(setter),
		"available_tempos": tempos,
		"requested_tempo": wanted,
		"resolved_tempo": resolved,
		"tempo_downgraded": resolved != wanted,
		"effective_pass_quality": effective_pass_quality(setter, pass_quality),
		"contact_height_meters": contact_height_meters,
		"standing_reach_meters": standing_reach,
		"maximum_reach_meters": maximum_reach,
		"reach_state": reach_state,
	}
