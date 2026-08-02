class_name ContactEnvelopeSystem
extends RefCounted

## Game-balance mappings, not claims of biomechanical measurement. Body
## dimensions define the envelope; athletic and technical ratings determine
## how much of it is available for this action and body state.
##
## A fixed `MIN_JUMP_DISPLACEMENT_METERS`/`MAX_JUMP_DISPLACEMENT_METERS` band
## used to live here. `nominal_jump_displacement_meters()` derives the same
## quantity from the player's own reach instead, and the constants were left
## behind unread -- describing a model the file had already outgrown.
##
## Lowest contact a player would bother leaving the floor for. Setting overhead
## starts lower than swinging at a ball does.
const SET_MINIMUM_JUMP_HEIGHT_METERS: float = 1.55
const ATTACK_MINIMUM_JUMP_HEIGHT_METERS: float = 1.85


## Effort each action can put into its jump, as a share of a full committed
## approach jump, when the player has no run-up at all.
##
## A single displacement band calibrated for a spike approach used to serve
## every action, which was quietly generous: it let a 178 cm setter meet a
## ball at 2.75 m, erasing height as a setter attribute entirely.
##
## A jump set is not a fixed hop, though. A setter with time takes a short
## approach into it precisely to gain the height and momentum a high ball needs,
## which is why `set` carries the widest gap between its standing and
## fully-approached effort -- see `action_jump_effort()`.
const ACTION_STANDING_EFFORT := {
	&"set": 0.34,
	&"attack": 0.55,
	&"block": 0.80,
	&"assist_block": 0.80,
}
const ACTION_APPROACHED_EFFORT := {
	&"set": 0.72,
	&"attack": 1.00,
	&"block": 0.92,
	&"assist_block": 0.92,
}


## How much of a full jump this action gets, given how much of an approach the
## player could afford. `approach_quality` is 0 for a player taking off flat
## footed from where they stand and 1 for one who arrived early enough to load
## a proper run-up.
static func action_jump_effort(
	action_type: StringName,
	approach_quality: float,
) -> float:
	return lerpf(
		float(ACTION_STANDING_EFFORT.get(action_type, 0.55)),
		float(ACTION_APPROACHED_EFFORT.get(action_type, 1.00)),
		clampf(approach_quality, 0.0, 1.0),
	)


## How high this player can add to their standing reach for this action, before
## live body state is considered. Exposed because reach is a question the
## resolver needs to ask outside a full `RallyPlayerState` -- notably of a setter
## about to receive a pass -- and answering it with a second copy of this
## arithmetic is how the two would drift apart.
static func nominal_jump_displacement_meters(
	player: VolleyballPlayer,
	action_type: StringName = &"attack",
	approach_quality: float = 1.0,
) -> float:
	if player == null:
		return 0.0
	var effort := action_jump_effort(action_type, approach_quality)
	return (player.jumping_reach_cm(effort) - player.standing_reach_cm()) / 100.0


static func evaluate(
	actor: RallyPlayerState,
	action_type: StringName,
	contact_height_meters: float,
	available_time: float,
	allow_jump: bool = false,
	approach_profile: Dictionary = {},
) -> Dictionary:
	if actor == null or actor.player == null:
		return {"physically_reachable": false}
	var player := actor.player
	var standing_reach := player.standing_reach_cm() / 100.0
	var horizontal_reach := _horizontal_reach(
		player, action_type, actor.body_state, actor.balance
	)
	var explosiveness := float(player.explosiveness) / 100.0
	var readiness_factor := clampf(actor.readiness, 0.0, 1.0)
	var takeoff_time := lerpf(0.34, 0.13, explosiveness) \
		* lerpf(1.18, 0.92, readiness_factor)
	if action_type == &"attack" and not approach_profile.is_empty():
		## An approach already contains the loading steps for takeoff. A clean
		## run-up therefore reserves less additional stationary preparation time.
		takeoff_time *= lerpf(
			1.0, 0.38,
			clampf(float(approach_profile.get("runup_quality", 0.0)), 0.0, 1.0)
		)
	var can_take_off := allow_jump \
		and actor.body_state not in [
			RallyPlayerState.BodyState.DIVING,
			RallyPlayerState.BodyState.RECOVERING,
		] \
		and available_time >= takeoff_time
	var jump_multiplier := float(approach_profile.get("jump_multiplier", 1.0)) \
		if action_type == &"attack" else 1.0
	## An attack's run-up quality already arrives as `jump_multiplier`; other
	## actions report how much approach they managed through the same channel.
	var approach_quality := clampf(
		float(approach_profile.get("runup_quality", 1.0)), 0.0, 1.0
	) if not approach_profile.is_empty() else 1.0
	var accessible_jump := nominal_jump_displacement_meters(
		player, action_type, approach_quality
	) * jump_multiplier * readiness_factor if can_take_off else 0.0
	var maximum_height := standing_reach + accessible_jump
	var standing_possible := contact_height_meters <= standing_reach
	var jump_action := action_type in [&"set", &"attack", &"block", &"assist_block"]
	var minimum_jump_height := SET_MINIMUM_JUMP_HEIGHT_METERS \
		if action_type == &"set" else ATTACK_MINIMUM_JUMP_HEIGHT_METERS
	var jump_possible := can_take_off and jump_action \
		and contact_height_meters >= minimum_jump_height \
		and contact_height_meters <= maximum_height
	var set_balance := float(player.set_balance) / 100.0
	var set_stability := float(player.set_stability) / 100.0
	var reception_balance := float(player.reception_balance) / 100.0
	var reception_stability := float(player.reception_stability) / 100.0
	var action_balance := reception_balance * 0.48 + reception_stability * 0.52
	if action_type == &"set":
		action_balance = set_balance * 0.48 + set_stability * 0.52
	elif action_type == &"attack":
		action_balance = (
			float(player.approach_timing) * 0.58
			+ float(player.explosiveness) * 0.22
			+ float(player.attack_accuracy) * 0.20
		) / 100.0
	elif action_type in [&"block", &"assist_block"]:
		action_balance = (
			float(player.block_timing) * 0.62
			+ float(player.explosiveness) * 0.20
			+ float(player.tactical_discipline) * 0.18
		) / 100.0
	var vertical_pressure := clampf(
		contact_height_meters / maxf(maximum_height, 0.05), 0.0, 1.2
	)
	var approach_balance := float(approach_profile.get("balance_multiplier", 1.0)) \
		if action_type == &"attack" else 1.0
	return {
		"physically_reachable": standing_possible or jump_possible,
		"horizontal_reach_meters": horizontal_reach,
		"standing_reach_meters": standing_reach,
		"maximum_contact_height_meters": maximum_height,
		"vertical_margin_meters": maximum_height - contact_height_meters,
		"standing_reachable": standing_possible,
		"jump_reachable": jump_possible,
		"requires_jump": jump_possible and not standing_possible,
		"required_takeoff_time_seconds": takeoff_time,
		"takeoff_time_seconds": takeoff_time if jump_possible else 0.0,
		"recovery_time_seconds": lerpf(0.36, 0.18, action_balance) \
			if jump_possible else 0.0,
		"balance_factor": clampf(
			action_balance * lerpf(1.0, 0.62, vertical_pressure) * approach_balance,
			0.0, 1.0
		),
		"approach_jump_multiplier": jump_multiplier,
		"approach_balance_multiplier": approach_balance,
	}


static func _horizontal_reach(
	player: VolleyballPlayer,
	action_type: StringName,
	body_state: RallyPlayerState.BodyState,
	current_balance: float,
) -> float:
	var span_factor := clampf(inverse_lerp(160.0, 225.0, player.wingspan_cm), 0.0, 1.0)
	var base := lerpf(0.30, 0.62, span_factor)
	var stability := float(player.reception_stability) / 100.0
	if action_type == &"set":
		stability = float(player.set_stability) / 100.0
	elif action_type == &"attack":
		stability = float(player.approach_timing) / 100.0
	elif action_type in [&"block", &"assist_block"]:
		stability = float(player.block_timing) / 100.0
	var posture_factor := 1.0
	match body_state:
		RallyPlayerState.BodyState.MOVING:
			posture_factor = 0.90
		RallyPlayerState.BodyState.REACHING:
			posture_factor = 1.10
		RallyPlayerState.BodyState.DIVING:
			posture_factor = 1.22 if action_type in [&"receive", &"dig"] else 0.55
		RallyPlayerState.BodyState.AIRBORNE:
			posture_factor = 0.82
		RallyPlayerState.BodyState.RECOVERING:
			posture_factor = 0.68
	return base * posture_factor \
		* lerpf(0.76, 1.0, stability) \
		* lerpf(0.78, 1.0, clampf(current_balance, 0.0, 1.0))
