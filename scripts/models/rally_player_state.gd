class_name RallyPlayerState
extends RefCounted

enum MovementMode {
	IDLE,
	LATERAL,
	TRANSITION,
	APPROACH,
	BLOCK_CLOSE,
	RECOVERY,
}

enum BodyState {
	BALANCED,
	MOVING,
	REACHING,
	DIVING,
	AIRBORNE,
	RECOVERING,
}

var player: VolleyballPlayer
var player_id: int = -1
var team_side: StringName = &"home"
var rotation_slot: int = -1

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
## Which way the feet and hips are set -- **preparation orientation, not gaze and
## not a route.**
##
## The class default is the home side's, and that was the whole of the state
## until `create()` learned to mirror it: every voli on both sides began facing
## -y, so an opponent defender was initialised facing away from the net. See
## `docs/review/READY_ORIENTATION.md`.
##
## Zero is legitimate and means **unknown**, not "aligned": `_movement_profile`
## leaves `facing_fit` at 1.0 when it cannot read a direction, which is exactly
## the behaviour every caller had before facing was carried at all. A caller that
## has no orientation to offer must pass zero rather than guess one.
var facing: Vector2 = Vector2(0.0, -1.0)

var movement_mode: MovementMode = MovementMode.IDLE
var body_state: BodyState = BodyState.BALANCED
var balance: float = 1.0
## `readiness` used to sit here, declared 1.0 and never written by anything.
##
## It was removed rather than given semantics. Every input a preload scalar
## could have been derived from already reaches the two consequences it was
## permitted to touch: DIVING, RECOVERING and AIRBORNE gate takeoff directly in
## `ContactEnvelopeSystem`, `balance` and `body_state` drive horizontal reach
## there, and the run-up's own quality drives both takeoff time and jump height.
## See `docs/review/READINESS_REMOVAL.md`.

var intent: StringName = &"idle"
var intent_target: Vector2 = Vector2.ZERO
var committed_until: float = 0.0
var last_contact_time: float = -1.0
var recovery_until: float = 0.0

## Tactical homes are desired destinations, never forced resets.
var tactical_home: Vector2 = Vector2.ZERO
var responsibility_priority: int = 1


static func create(
	profile: VolleyballPlayer,
	side: StringName,
	slot: int,
	start_position: Vector2,
) -> RallyPlayerState:
	var state := RallyPlayerState.new()
	state.player = profile
	state.player_id = profile.id
	state.team_side = side
	state.rotation_slot = slot
	state.position = start_position
	state.intent_target = start_position
	state.tactical_home = start_position
	state.facing = side_relative_ready_facing(side)
	return state


## Where a body is set before anything has happened, per side.
##
## **Toward the net, and mirrored** -- the two sides stand on opposite halves of
## the same axis, so one world-space constant cannot describe both. The home
## side occupies high `y` and attacks toward low `y`, which is the convention
## `_set_geometry`'s `square_up_sign` and `SetPathReadModel`'s
## `attacking_negative_y` already encode; the opponent is its mirror.
##
## Toward the *net*, deliberately, and not toward the ball. A body orienting
## itself at the live ball would be preparation gaining information from the
## action it is about to be tested against, which is the one thing preparation
## must not do. The net does not move.
static func side_relative_ready_facing(side: StringName) -> Vector2:
	return Vector2(0.0, 1.0) if side == &"opponent" else Vector2(0.0, -1.0)


func is_available(at_time: float) -> bool:
	return at_time >= committed_until and at_time >= recovery_until


func set_intent(
	new_intent: StringName,
	target: Vector2,
	commitment_end: float,
	mode: MovementMode,
) -> void:
	intent = new_intent
	intent_target = target
	committed_until = commitment_end
	movement_mode = mode


## Which movement forms physically establish where the body is set.
##
## **The form decides, not the angle.** A shuffle, a block close and a standing
## body keep the orientation they already had -- that is what ready footwork
## *is*, and it is precisely why a defender may travel sideways or backward
## while staying square to the net. An approach and a transition run are opened
## up: the torso turns and the legs run, so the route *is* the orientation.
## Recovery invents nothing; it keeps the last orientation some real movement or
## action established.
##
## This replaces `facing = velocity` applied to every mode alike, which claimed a
## backpedalling defender was facing away from the net and a shuffling blocker
## was facing down the net rather than across it. See
## `docs/review/MOVING_ORIENTATION.md`.
func movement_establishes_facing() -> bool:
	return movement_mode in [
		MovementMode.APPROACH, MovementMode.TRANSITION,
	]


func apply_position(new_position: Vector2, new_velocity: Vector2) -> void:
	position = Vector2(
		clampf(new_position.x, 0.0, 1.0),
		clampf(new_position.y, 0.0, 1.0),
	)
	velocity = new_velocity
	## A caller that means "this body opened up and ran" says so by being in the
	## mode that describes that movement. It must be in that mode *before* the
	## position is applied, because this is the leg being applied, not the next
	## one; `RallyMovementSystem.project_toward` used to set it afterwards and
	## therefore classified every projection by the mode of the previous leg.
	if movement_establishes_facing() and velocity.length_squared() > 0.0001:
		facing = velocity.normalized()


func snapshot() -> RallyPlayerState:
	var copy := RallyPlayerState.create(player, team_side, rotation_slot, position)
	copy.velocity = velocity
	copy.facing = facing
	copy.movement_mode = movement_mode
	copy.body_state = body_state
	copy.balance = balance
	copy.intent = intent
	copy.intent_target = intent_target
	copy.committed_until = committed_until
	copy.last_contact_time = last_contact_time
	copy.recovery_until = recovery_until
	copy.tactical_home = tactical_home
	copy.responsibility_priority = responsibility_priority
	return copy
