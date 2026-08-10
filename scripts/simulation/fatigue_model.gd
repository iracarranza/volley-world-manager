class_name FatigueModel
extends RefCounted

## What being tired actually does, in three stages rather than one slope.
##
## **The model this replaces was one multiplier.** `_rating` returned
## `raw * (1.0 - fatigue * 0.18)` and every consequence of tiredness in the game
## came out of that single line. Two things are wrong with it, and they are
## different problems.
##
## The first is that it is linear, so the first percent of fatigue costs exactly
## what the last percent costs. That is not how a body works and it is not how a
## match reads: a player two sets in is *slightly* off, and a player who has
## nothing left is not slightly worse than that, they are making mistakes they
## would never make. A straight line cannot say both.
##
## The second is that it has one channel, so a tired setter and a tired middle
## degrade in the same shape. Everything the player has gets quietly worse at the
## same rate, which is legible as nothing at all — a rating that drifts down
## invisibly is a rating nobody can see change.
##
## ## The three stages
##
## Named for what a viewer would say about the player, because that is the test
## of whether the stage is worth having.
##
##   **Working** — the whole match, from the first rally. Everything a player has
##   is fractionally worse. Small enough that no single contact is decided by it,
##   which is the point: this is the stage that should never produce a story.
##
##   **Laboured** — the legs go first. Work rate, explosiveness, the jump, the
##   speed across the floor. A player in this stage still *reads* the game
##   exactly as well as they did; they just cannot get there any more, and cannot
##   get as high once they do. This is the stage a viewer sees before any error
##   is made — the reach that comes up short, the approach that starts late.
##
##   **Spent** — and only now, mistakes. First forced ones, because the range has
##   already gone and the ball is arriving in places the player can no longer
##   cover well; then unforced ones, the serve into the net, the swing long with
##   nobody near it. Errors are their own channel rather than a by-product of the
##   attribute loss, because the two are genuinely different: a shanked pass under
##   pressure and a serve dumped into the tape at 24-22 do not come from the same
##   place.
##
## ## Why each channel is logarithmic
##
## Within a stage the loss bends and then flattens: most of what that stage is
## going to take, it takes early. The escalation a player feels comes from the
## *stages arriving in sequence*, not from any one of them accelerating — which
## is what keeps the whole curve from turning into the cliff the old linear
## model was accused of not having. A staircase of three flattening steps rises
## further than a straight line and never has a moment where everything goes at
## once.

## Where each stage begins, as a share of the fatigue scale.
##
## `Working` starts at zero because a player is tiring from the first rally.
## The other two are placed to leave the middle third of the range as the
## *legs-only* band -- the widest of the three, because it is the one a match
## actually spends its time in and the one the design asks to be visible.
const LABOURED_ONSET: float = 0.34
const SPENT_ONSET: float = 0.68

## Where each stage has taken almost all it is going to take. Broad loss
## saturates early on purpose: it is background, and background that keeps
## growing becomes foreground.
const WORKING_SATURATION: float = 0.55

## How much each channel costs at its own saturation.
##
## `BROAD_LOSS` is deliberately smaller than the 0.18 it replaces, because it is
## no longer carrying the whole model -- the range and error channels carry the
## part that used to be smeared across every attribute at once. Summed at full
## fatigue a physical attribute now loses more than it used to (0.07 broad plus
## 0.22 range) and a mental one less (0.07 alone), which is the split the old
## single multiplier could not express.
const BROAD_LOSS: float = 0.07
const RANGE_LOSS: float = 0.22

## What the spent stage adds to an error chance, as an absolute probability.
##
## Forced first and larger: a spent player is beaten to more balls, and being
## beaten to a ball is not a mistake. The unforced share is smaller and arrives
## later within the same stage, which is why it is scaled by the square of the
## stage's progress rather than by the stage directly -- the last of the fatigue
## range is where a serve goes into the net for no reason at all.
const FORCED_ERROR_ADDED: float = 0.14
const UNFORCED_ERROR_ADDED: float = 0.09

## How hard each channel bends. Higher is more front-loaded; at 0 it would be a
## straight line and this whole file would be the model it replaces.
const CURVE_SHARPNESS: float = 3.2

## How far `work_rate` moves the fatigue a player's *consequences* are computed
## at.
##
## **Stamina and work rate are different virtues and this is the split.** Stamina
## is capacity — it decides how fast the tank empties, and it acts on accrual, in
## `stamina_fatigue_scale`. Work rate is what a player does about an empty tank:
## they keep chasing, keep jumping, keep arriving, and they execute those plays
## better than a comfortable player would at the same reading on the gauge. So it
## does not slow the accrual at all; it moves where on the curve the same amount
## of fatigue *lands*.
##
## At full work rate a voli behaves as though they were three quarters as tired,
## which is enough to hold them in `laboured` where a lazier team-mate has
## already reached `spent` — and being the last player on the court still making
## the play is precisely what the attribute is for. At zero work rate the same
## fatigue reads worse than it is.
const RESILIENCE_AT_FULL_WORK_RATE: float = 0.74
const RESILIENCE_AT_NO_WORK_RATE: float = 1.16

## Within a rally, a player spends burst energy they do not get back until the
## rally ends. `winded` is that spend as a share of what they can carry.
##
## **This is a different clock from fatigue and it needs to be.** Fatigue is the
## match: it climbs across five sets and never comes down inside a rally.
## Windedness is the rally: three jumps and a dive in one exchange leaves a
## player heaving whether it is 2-1 in the first set or 24-23 in the fifth, and
## it is gone by the next serve. A model with only the slow clock cannot show a
## long rally being *won by the fitter side*, which is the thing a viewer
## actually watches for.
##
## Capacity scales with stamina -- a conditioned player gets winded later -- and
## the *penalty* is fought with work rate, on the same split as above.
const WINDED_CAPACITY_LOW: float = 0.030
const WINDED_CAPACITY_HIGH: float = 0.075
## What being completely blown costs the legs, before work rate is applied. Large
## on purpose: a player at the end of a twenty-contact rally should visibly not
## have their jump any more.
const WINDED_RANGE_LOSS: float = 0.20
## And what a blown player pays, on top, for every further action they are made
## to take. The feedback term: a long rally that empties somebody also ages them
## faster than the same work would have fresh.
const WINDED_ACTION_SURCHARGE: float = 0.85

## The attributes the laboured stage takes, and nothing else.
##
## Every one of them is a claim about *getting somewhere or getting off the
## floor*. Reading, timing, control and decision-making are deliberately absent:
## a tired player who still knows exactly what to do and cannot do it is the
## whole of what this stage is for, and adding a judgement attribute here would
## collapse it back into the broad channel.
const RANGE_ATTRIBUTES := {
	"work_rate": true, "explosiveness": true, "jump_reach": true,
	"acceleration": true, "lateral_speed": true, "transition_speed": true,
	"arm_speed": true, "stamina": true,
}


## How far into a stage this fatigue is, 0 to 1, bent.
##
## The bend is the log: at a quarter of the way through a stage the channel has
## already spent about half of what it will spend. Shared by all three channels
## so the shape is stated once.
static func stage_progress(fatigue: float, from: float, to: float) -> float:
	var span := maxf(to - from, 0.0001)
	var linear := clampf((clampf(fatigue, 0.0, 1.0) - from) / span, 0.0, 1.0)
	return log(1.0 + CURVE_SHARPNESS * linear) / log(1.0 + CURVE_SHARPNESS)


## The multiplier every attribute gets, physical or mental.
static func broad_scale(fatigue: float) -> float:
	return 1.0 - BROAD_LOSS * stage_progress(fatigue, 0.0, WORKING_SATURATION)


## The extra multiplier the legs and the engine get, on top of `broad_scale`.
##
## Returns exactly 1.0 below `LABOURED_ONSET`, so a fresh player's explosiveness
## is untouched by this channel rather than being scaled by something very close
## to one. A no-op that is *exactly* a no-op is checkable.
static func range_scale(fatigue: float) -> float:
	return 1.0 - RANGE_LOSS * stage_progress(fatigue, LABOURED_ONSET, 1.0)


## Whether this attribute is one the laboured stage takes.
static func is_range_attribute(property_name: String) -> bool:
	return RANGE_ATTRIBUTES.has(property_name)


## The full multiplier for one attribute at one fatigue level.
##
## The one function every caller should use. Kept as the composition of the two
## above rather than a third formula, so there is no way for the parts and the
## whole to disagree.
static func attribute_scale(fatigue: float, property_name: String) -> float:
	var scale := broad_scale(fatigue)
	if is_range_attribute(property_name):
		scale *= range_scale(fatigue)
	return scale


## Added chance that a contact under pressure is missed.
##
## Zero until the spent stage, which is the design's whole point: fatigue must
## not "immediately lead to large mistakes".
static func forced_error_bias(fatigue: float) -> float:
	return FORCED_ERROR_ADDED * stage_progress(fatigue, SPENT_ONSET, 1.0)


## Added chance that a contact nobody pressured is missed.
##
## Squared against the stage rather than linear in it, so the serve into the tape
## belongs to the very end of the range rather than to the whole of the spent
## stage.
static func unforced_error_bias(fatigue: float) -> float:
	var progress := stage_progress(fatigue, SPENT_ONSET, 1.0)
	return UNFORCED_ERROR_ADDED * progress * progress


## Where this much fatigue actually lands for this player, after work rate.
##
## Every consequence in this file should be asked of *this* rather than of the
## raw figure: the raw number is how empty the tank is, and this is how much that
## emptiness is costing the player in front of you.
static func effective_fatigue(fatigue: float, work_rate: float) -> float:
	return clampf(fatigue, 0.0, 1.0) * lerpf(
		RESILIENCE_AT_NO_WORK_RATE, RESILIENCE_AT_FULL_WORK_RATE,
		clampf(work_rate, 0.0, 1.0),
	)


## How much burst energy this rally has already cost, as a share of what this
## player carries. `spent_this_rally` is exertion booked since the serve.
static func winded_fraction(spent_this_rally: float, stamina: float) -> float:
	return clampf(spent_this_rally / maxf(lerpf(
		WINDED_CAPACITY_LOW, WINDED_CAPACITY_HIGH,
		clampf(stamina, 0.0, 1.0),
	), 0.0001), 0.0, 1.0)


## What being this winded does to the legs, fought with work rate.
##
## Range only. A blown player still reads the play exactly as well as they did
## thirty seconds ago -- they simply cannot get there or get up, which is the
## same distinction the `laboured` stage draws on the slow clock and is why the
## two channels multiply rather than each inventing their own attribute list.
static func winded_scale(winded: float, work_rate: float) -> float:
	return 1.0 - WINDED_RANGE_LOSS \
		* clampf(winded, 0.0, 1.0) \
		* lerpf(RESILIENCE_AT_NO_WORK_RATE, RESILIENCE_AT_FULL_WORK_RATE,
			clampf(work_rate, 0.0, 1.0))


## How much more one action costs while already blown.
##
## **Moving while winded is more expensive than moving fresh**, which is the
## feedback term that stops windedness being a purely cosmetic within-rally
## penalty: a player dragged around at the end of a long exchange pays for it on
## the match clock too, so the rally that blew them out is also the rally that
## aged them. Multiplicative on whatever the action already cost, so a jump taken
## while blown costs more than a step taken while blown -- which is true.
static func winded_surcharge(winded: float) -> float:
	return 1.0 + WINDED_ACTION_SURCHARGE * clampf(winded, 0.0, 1.0)


## What to call this player's condition, for a caption or a probe.
##
## Published so no renderer has to re-derive the bands, and so a probe can report
## how much of a match is spent in each -- which is the measurement that says
## whether the three stages are three stages or one.
static func stage_name(fatigue: float) -> StringName:
	if fatigue >= SPENT_ONSET:
		return &"spent"
	if fatigue >= LABOURED_ONSET:
		return &"laboured"
	return &"working"
