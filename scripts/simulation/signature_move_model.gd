class_name SignatureMoveModel
extends RefCounted

## The moves that let a spike beat a block it has physically met.
##
## A block that engages a swing cleanly should win -- that is the premise. These
## are the two ways a hitter beats one anyway, and they are deliberately keyed to
## *different* attributes so that two different builds each have an answer:
##
## - **Block Crush** is the power route. A ball struck harder than the block can
##   absorb rips through and keeps going down, carrying most of its speed.
## - **High Hands** is the accuracy route. A ball placed deliberately on the
##   outside edge of the hands leaves high and away from the court.
##
## Tips, rolls and cut shots never physically meet the block, so they have no
## move here. Nothing is lost by that: they beat a block by not touching it.
##
## ## Charge is not a consumable
##
## There is no meter to spend. `charge()` asks whether a player *currently has
## the game in them*, from their own ability, their belief, and which way the
## match is running. Attempting costs nothing and succeeding costs nothing --
## **only failing is expensive**, and it is expensive because it damages the
## belief the charge was reading in the first place.
##
## That asymmetry is what makes it self-regulating rather than a resource to
## hoard: a hitter who goes for it and misses drops below the line and has to
## earn their way back, and one who keeps landing them stays hot. Streaks fall
## out of it without anyone scripting streaks.
##
## Confidence is the existing `VolleyballPlayer.match_confidence` -- point to
## point belief, already moved by `flow_shift` and already decayed between sets.
## No new state.

## How the three inputs weigh into the surge. Ability dominates, because a
## player who cannot do this does not get to do it on a good day; belief and
## flow decide *when* someone who can, does.
const CAPABILITY_WEIGHT: float = 0.55
const CONFIDENCE_WEIGHT: float = 0.25
const FLOW_WEIGHT: float = 0.20

## Where the surge switches on. Set so it is a minority of approaches rather
## than a constant hum -- an indicator that shows every rally is wallpaper, and
## the whole point of it is that it means something when it appears.
const AVAILABILITY_THRESHOLD: float = 0.62

## What a failed attempt takes out of a player's belief. Large relative to an
## ordinary point's confidence movement (~0.07), because going for the big one
## and missing should be felt.
const FAILURE_CONFIDENCE_COST: float = 0.16

## How much speed a block absorbs before it starts giving way, in metres per
## second, and what deep contact and a second pair of hands add to that. A ball
## met on the fingertips of one blocker is a very different proposition from one
## met on two sets of solid hands.
const BLOCK_ABSORB_BASE_MPS: float = 17.0
const BLOCK_ABSORB_PER_DEPTH_METER: float = 14.0
const BLOCK_ABSORB_PER_EXTRA_BLOCKER: float = 4.5

## How straight a hitter has to have struck it for edge contact to count as
## aimed rather than lucky. Wider than this and the ball found the edge because
## the swing missed, which is an ordinary tool and nobody's signature move.
const HIGH_HANDS_AIM_TOLERANCE_DEGREES: float = 2.6


## How much of the game a player has in them right now, 0-1.
##
## `capability` is the attribute composite for the move being asked about, and
## `flow_for_team` is `match_flow` already signed toward this player's side, so
## a hitter riding a run is more likely to have it than one being run over.
static func charge(
	capability: float,
	match_confidence: float,
	flow_for_team: float,
) -> float:
	return clampf(
		clampf(capability, 0.0, 1.0) * CAPABILITY_WEIGHT
		+ (clampf(match_confidence, -1.0, 1.0) + 1.0) * 0.5 * CONFIDENCE_WEIGHT
		+ (clampf(flow_for_team, -1.0, 1.0) + 1.0) * 0.5 * FLOW_WEIGHT,
		0.0, 1.0,
	)


static func is_available(charge_value: float) -> bool:
	return charge_value >= AVAILABILITY_THRESHOLD


## The power route's capability: how hard they hit, how much they back
## themselves, and how much the room follows them.
static func crush_capability(
	attack_power: float,
	ego: float,
	leadership: float,
) -> float:
	return clampf(
		clampf(attack_power, 0.0, 1.0) * 0.58
		+ clampf(ego, 0.0, 1.0) * 0.24
		+ clampf(leadership, 0.0, 1.0) * 0.18,
		0.0, 1.0,
	)


## The accuracy route's capability: how precisely they place it, and whether
## they are composed and clear-headed enough to pick the edge of the hands
## rather than swing at the middle of them.
static func high_hands_capability(
	attack_accuracy: float,
	composure: float,
	decision_making: float,
) -> float:
	return clampf(
		clampf(attack_accuracy, 0.0, 1.0) * 0.54
		+ clampf(composure, 0.0, 1.0) * 0.24
		+ clampf(decision_making, 0.0, 1.0) * 0.22,
		0.0, 1.0,
	)


## How much ball speed this block can take before it gives way.
static func block_absorb_mps(
	depth_below_reach_meters: float,
	blocker_count: int,
) -> float:
	return BLOCK_ABSORB_BASE_MPS \
		+ maxf(depth_below_reach_meters, 0.0) * BLOCK_ABSORB_PER_DEPTH_METER \
		+ float(maxi(blocker_count - 1, 0)) * BLOCK_ABSORB_PER_EXTRA_BLOCKER


## Resolve a swing that has physically met the block.
##
## The move is *attempted* whenever the charge is up and the ball touched hands
## -- there is no separate decision to make one. It then succeeds or fails on
## the physics, which is what keeps the indicator honest: it says this hitter
## has it in them, never that it is going to work.
##
## `block_kind` is `AttackResolutionModel`'s classification, `bearing_error` is
## the swing's own horizontal miss, and `depth_below_reach` says where on the
## hands it landed.
static func resolve_contact(
	block_kind: String,
	delivered_speed_mps: float,
	bearing_error_degrees: float,
	depth_below_reach_meters: float,
	blocker_count: int,
	crush_charge: float,
	high_hands_charge: float,
) -> Dictionary:
	var crush_ready := is_available(crush_charge)
	var hands_ready := is_available(high_hands_charge)
	var absorb := block_absorb_mps(depth_below_reach_meters, blocker_count)

	## Edge contact with the charge up and a swing that went where it was aimed
	## is a placed ball. The same contact off a wild swing is an ordinary tool --
	## the ball found the edge, the hitter did not put it there.
	if block_kind == "tool" and hands_ready:
		if absf(bearing_error_degrees) <= HIGH_HANDS_AIM_TOLERANCE_DEGREES:
			return _result("high_hands", true, "high_hands", absorb)
		return _result("tool", false, "high_hands", absorb)

	## Solid contact with the charge up is a power attempt: through the hands if
	## it is hit harder than they can hold, stuffed if not.
	if block_kind == "stuff" and crush_ready:
		if delivered_speed_mps > absorb:
			return _result("block_crush", true, "block_crush", absorb)
		return _result("stuff", false, "block_crush", absorb)

	return _result(block_kind, false, "", absorb)


static func _result(
	outcome: String,
	succeeded: bool,
	attempted: String,
	absorb: float,
) -> Dictionary:
	return {
		"outcome": outcome,
		"move_succeeded": succeeded,
		"attempted_move": attempted,
		"block_absorb_mps": absorb,
		## Only a failed *attempt* costs anything. A contact that never had the
		## charge up was never a move and should not be punished as one.
		"confidence_cost": FAILURE_CONFIDENCE_COST \
			if (not attempted.is_empty() and not succeeded) else 0.0,
	}
