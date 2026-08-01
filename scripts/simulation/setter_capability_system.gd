class_name SetterCapabilitySystem
extends RefCounted

## What a setter can do with the ball they are about to receive, and what
## happens when they try to do more than that.
##
## **Capability is not permission.** An earlier version of this system removed
## tempos a setter could not command from the option list, so a weak setter
## could not select a quick set at all. That is wrong: a player may attempt
## anything, for good reasons or bad -- the play called for it, they misread
## their own limits, they were out of options, they gambled. What their
## attributes decide is not *whether* they can try but *how it goes*.
##
## So nothing here filters an action away. `evaluate()` reports how far outside
## a setter's command the attempted action sits, whether their judgment led them
## to back off to something safer, and the penalty the attempt carries if they
## did not. A setter who overreaches produces a bad ball, not an impossible one.
##
## Three attribute families set the limits, and each degrades differently:
##
## 1. **Technical command** over tempo. A fast set demands more command than a
##    slow one, and a poor pass raises that demand further. Attempting a tempo
##    beyond command costs quality in proportion to the shortfall.
## 2. **Pass recovery.** Command also buys back part of what a bad pass costs,
##    so skill matters most when the pass is worst. This is the interaction the
##    old linear `reception_quality` term could not express.
## 3. **Reach.** Height, arm length and leap decide how high a ball can be met,
##    and how much of an approach the setter could afford decides how much of
##    their leap is available. A ball above that is still reachable *for* -- it
##    is simply very unlikely to become a usable set.
##
## Judgment (`decision_making`, `tactical_discipline`, `composure`) decides
## whether the setter recognises the overreach and downgrades. A disciplined
## setter takes the safer ball; a reckless one tries the quick anyway. Both are
## legitimate, and the rally record shows which happened.

const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)

## Tempo indices run fast to slow: 0 is a quick set, 3 a high ball.
const QUICK_TEMPO: int = 0
const SLOWEST_TEMPO: int = 3

## Command required to run each tempo off a perfect pass.
const TEMPO_COMMAND_FLOOR: Array[float] = [0.72, 0.55, 0.36, 0.0]

## Extra command each tempo demands as the pass degrades. A high ball is
## forgiving by definition, which is why it demands nothing extra -- it is the
## option a scrambling team always has.
const TEMPO_PASS_SENSITIVITY: Array[float] = [0.35, 0.24, 0.14, 0.0]

## How hard an overreach bites. A setter a long way outside their command does
## not merely set worse, they put up something unusable.
const OVERREACH_SEVERITY: float = 1.60

## Cost of having to jump to a ball rather than take it standing, and the floor
## cost of reaching for one above even a jump.
const JUMP_SET_PENALTY: float = 0.08
const BEYOND_REACH_BASE_PENALTY: float = 0.35
const BEYOND_REACH_SEVERITY: float = 1.80

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


## How reliably this setter recognises that a ball is beyond them and takes the
## safer option instead. This is what makes an overreach a decision rather than
## a dice roll.
static func judgment(setter: VolleyballPlayer) -> float:
	if setter == null:
		return 0.0
	return clampf((
		float(setter.decision_making) * 0.50
		+ float(setter.tactical_discipline) * 0.30
		+ float(setter.composure) * 0.20
	) / 100.0, 0.0, 1.0)


## Command this tempo demands off a pass of this quality.
static func tempo_requirement(tempo: int, pass_quality: float) -> float:
	var index := clampi(tempo, QUICK_TEMPO, SLOWEST_TEMPO)
	return TEMPO_COMMAND_FLOOR[index] \
		+ (1.0 - clampf(pass_quality, 0.0, 1.0)) * TEMPO_PASS_SENSITIVITY[index]


## Height the pass arrives at. `sail` is a seeded 0-1 roll owned by the caller,
## so this stays deterministic and free of its own randomness.
static func pass_contact_height_meters(pass_quality: float, sail: float) -> float:
	var quality := clampf(pass_quality, 0.0, 1.0)
	return lerpf(LOOSE_PASS_HEIGHT_M, CONTROLLED_PASS_HEIGHT_M, quality) \
		+ (1.0 - quality) * clampf(sail, 0.0, 1.0) * MAXIMUM_PASS_SAIL_M


## Tempos this setter can run without overreaching. Informational: it is what
## the setter's own judgment consults when deciding whether to back off, and it
## never restricts what may be attempted.
static func tempos_within_capability(
	setter: VolleyballPlayer,
	pass_quality: float,
) -> Array[int]:
	var setter_command := command(setter)
	var within: Array[int] = []
	for tempo in range(TEMPO_COMMAND_FLOOR.size()):
		if setter_command >= tempo_requirement(tempo, pass_quality):
			within.append(tempo)
	return within


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


## Whether this setter backs off a tempo they cannot command.
##
## The threshold falls as the shortfall grows: almost anyone recognises a ball
## hopelessly beyond them, while a marginal one gets chanced by all but the most
## disciplined. A reckless setter attempts regardless, which is the point.
static func backs_off(setter: VolleyballPlayer, deficit: float) -> bool:
	if deficit <= 0.0:
		return false
	var threshold := lerpf(0.85, 0.25, clampf(deficit / 0.40, 0.0, 1.0))
	return judgment(setter) >= threshold


## Full capability read for one second contact.
##
## `approach_quality` is how much of a run-up the setter could afford, 0 for a
## scrambling standing contact and 1 for one they arrived early enough to load.
static func evaluate(
	setter: VolleyballPlayer,
	requested_tempo: int,
	pass_quality: float,
	contact_height_meters: float,
	approach_quality: float = 1.0,
) -> Dictionary:
	if setter == null:
		return {
			"resolved_tempo": SLOWEST_TEMPO,
			"tempo_downgraded": false,
			"attempted_beyond_capability": false,
			"quality_penalty": 1.0,
			"reach_state": "beyond_reach",
		}
	var wanted := clampi(requested_tempo, QUICK_TEMPO, SLOWEST_TEMPO)
	var setter_command := command(setter)
	var within := tempos_within_capability(setter, pass_quality)

	## Does the setter back off, and to what? Backing off means taking the
	## fastest tempo they can actually command; there is always the high ball.
	var wanted_deficit := maxf(
		tempo_requirement(wanted, pass_quality) - setter_command, 0.0
	)
	var downgraded := backs_off(setter, wanted_deficit)
	var resolved := wanted
	if downgraded:
		resolved = SLOWEST_TEMPO
		for tempo in within:
			if tempo >= wanted and tempo < resolved:
				resolved = tempo

	## Whatever they ended up attempting, how far outside their command is it?
	var deficit := maxf(
		tempo_requirement(resolved, pass_quality) - setter_command, 0.0
	)
	var overreach_penalty := deficit * OVERREACH_SEVERITY

	## Reach, at the effort this approach actually allows.
	var standing_reach := setter.standing_reach_cm() / 100.0
	var maximum_reach := standing_reach + ContactEnvelopeModel \
		.nominal_jump_displacement_meters(setter, &"set", approach_quality)
	var reach_state := "standing"
	var reach_penalty := 0.0
	if contact_height_meters > maximum_reach:
		reach_state = "beyond_reach"
		reach_penalty = BEYOND_REACH_BASE_PENALTY \
			+ (contact_height_meters - maximum_reach) * BEYOND_REACH_SEVERITY
	elif contact_height_meters > standing_reach:
		reach_state = "jump"
		reach_penalty = JUMP_SET_PENALTY

	return {
		"command": setter_command,
		"judgment": judgment(setter),
		"tempos_within_capability": within,
		"requested_tempo": wanted,
		"resolved_tempo": resolved,
		"tempo_downgraded": downgraded,
		"attempted_beyond_capability": deficit > 0.0,
		"capability_deficit": deficit,
		"effective_pass_quality": effective_pass_quality(setter, pass_quality),
		"contact_height_meters": contact_height_meters,
		"standing_reach_meters": standing_reach,
		"maximum_reach_meters": maximum_reach,
		"approach_quality": clampf(approach_quality, 0.0, 1.0),
		"reach_state": reach_state,
		"quality_penalty": overreach_penalty + reach_penalty,
	}
