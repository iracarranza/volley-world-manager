class_name BallPresentation
extends RefCounted

## What the ball looks like between two contacts, on its own so it can be
## checked without a screen to run it in.
##
## This is the same reason `terminate_trajectory` was made static and moved here
## from the match centre: every one of these decisions is geometry, every one of
## them was wrong at least once, and a defect you can only see by watching a
## rally go past at playback speed is a defect nobody finds twice.
##
## The division of labour is worth stating because it was previously blurred.
## The **resolver** owns where each contact happened and how long the ball took
## between them -- those are facts about the rally. **Presentation** owns nothing
## about the flight's shape at all any more. It reads the two contact heights off
## the two players and hands them, with the resolver's own duration, to
## `BallFlightModel`, which determines the rest. What presentation still decides
## is where a flight *ends* when somebody intercepted it, which is genuinely a
## drawing question: the aimed landing point stays true as a fact about the
## attack, and the ball still has to stop where it was touched.

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const NET_HEIGHT_METERS: float = CourtConstants.NET_HEIGHT_METERS

## Where the ball is when nobody is holding it -- resting on the floor, near
## enough. A contact with no actor is the floor.
const FLOOR_CONTACT_HEIGHT_METERS: float = 0.12


## The complete drawn flight for one contact, ready to sample.
##
## `profiles` is the rally's `player_physical_profiles`, keyed by player id, so
## the contact heights come from the two bodies actually involved rather than
## from a table of per-action constants.
static func display_trajectory(
	event: RallyEvent,
	next_contact: RallyEvent,
	trajectory: Dictionary,
	profiles: Dictionary,
) -> Dictionary:
	var display := trajectory.duplicate(true)
	terminate_at_next_contact(display, next_contact)
	var start_height := contact_height(event, profiles)
	var duration := maxf(float(display.get("duration", 0.5)), 0.08)
	var end_height := FLOOR_CONTACT_HEIGHT_METERS if next_contact == null \
		else contact_height(next_contact, profiles)
	## **A ball keeps the trajectory it was struck with.**
	##
	## The residue of the flat-spike report, and it survived the gravity-true
	## rewrite because both ends of every drawn segment were still right. A
	## parabola is determined by two endpoints and a duration only when both
	## endpoints are *landings*. A spike met by a block has a far end that is an
	## interception, and its height was taken from the **blocker's reach** --
	## around 2.9 m, within centimetres of the hitter's own contact. A curve forced
	## to arrive level after most of a second has to be launched upward to spend
	## the time, so every spike that met a block was drawn lobbing over it.
	## Measured on the drawn curve: a 6.7 m swing rose from 3.30 m to 4.07 m and
	## came back to 2.93, while the same model sent an untouched spike from 3.28 m
	## to the floor exactly as it should. Attack-to-block is 181 of 1090 flights
	## and it is the one a viewer watches most closely.
	##
	## So the launch is carried rather than re-inferred. `struck_arc_from_speed`
	## knows the vertical speed the swing produced and publishes it; where it is
	## present the far end is *derived* from it. That is `docs/BACKLOG.md` §8's own
	## requirement -- outcome, position and drawing out of one computation --
	## reaching the case it had not reached. Where it is absent, on a set, a pass
	## or a dig, none of which are struck, the two contact heights remain the
	## better answer.
	if display.has("launch_vertical_mps"):
		## Across the flight's own duration, not the drawn one. See
		## `terminate_trajectory`: a segment shorter than 0.08 s is stretched so it
		## can be seen, and integrating the launch across the stretched time moves
		## the ball to a height it never reached.
		var flown := maxf(float(display.get(
			"physical_duration_seconds", duration
		)), 0.001)
		end_height = maxf(
			start_height + float(display.launch_vertical_mps) * flown
				- 0.5 * BallFlightModel.DEFAULT_GRAVITY_MPS2 * flown * flown,
			FLOOR_CONTACT_HEIGHT_METERS,
		)
	display["start_height_meters"] = start_height
	display["end_height_meters"] = end_height
	## Reported, not chosen.
	##
	## This key used to be the input that shaped the curve, and it was computed
	## from a table of per-action `rise_scale` and `minimum_lift` constants that
	## had no physical meaning and could not be checked against anything. It is
	## now what the flight actually does, so a reader who wants to know whether a
	## ball cleared the net can ask, and a probe can find the flights that do not.
	display["apex_height_meters"] = BallFlightModel.apex_between(
		start_height, end_height, duration
	)
	display["rise_speed_mps"] = BallFlightModel.rise_speed_between(
		start_height, end_height, duration
	)
	display["height_contract"] = "gravity_true"
	return display


## How high above the floor this player's hands were when they touched the ball.
##
## Read from the body rather than assumed: a 1.72 m libero digs lower than a
## 2.06 m middle blocks, and both numbers are already on the profile. The action
## decides *which* reach applies -- standing, jumping, or somewhere between --
## and the body decides what that reach is.
static func contact_height(event: RallyEvent, profiles: Dictionary) -> float:
	if event == null or event.actor_id < 0:
		return FLOOR_CONTACT_HEIGHT_METERS
	var profile: Dictionary = profiles.get(int(event.actor_id), {})
	var height_meters := float(profile.get("height_cm", 188.0)) / 100.0
	var wingspan_meters := float(profile.get("wingspan_cm", 191.0)) / 100.0
	var standing_reach := float(profile.get(
		"standing_reach_meters",
		height_meters * 1.215 + (wingspan_meters - height_meters) * 0.32,
	))
	var jumping_reach := float(profile.get(
		"jumping_reach_meters", standing_reach + 0.52
	))
	## Every branch below is `GeometricAttackPromotion`'s, called rather than
	## copied. These were five separate expressions here and five more there,
	## carrying five pairs of constants that matched by inspection. The resolver
	## timed a serve from one number and the court drew it leaving from another,
	## and nothing in the game could have noticed.
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			## The style's own effort, from the one table that owns it. This used
			## to be a local `contains("Jump")` test against a flat constant, which
			## is a second opinion about how high a serve leaves the hand -- and it
			## disagreed with the resolver, which gave every server half a leap.
			return GeometricAttackPromotion.serve_contact_from_reach(
				standing_reach, jumping_reach,
				GeometricAttackPromotion.serve_effort_for_style(
					str(event.metadata.get("serve_style", "Standing"))
				),
			)
		## Any ball played up off a defensive contact, which is both of them: a
		## coverer bumping a block rebound is doing the same thing to the ball as
		## a defender digging a swing, from a metre instead of from six.
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DIG, \
		RallyEventModel.EventType.ATTACK_COVERAGE:
			return GeometricAttackPromotion.pass_contact_from_height(height_meters)
		RallyEventModel.EventType.SET:
			var capability: Dictionary = event.metadata.get("setter_capability", {})
			var reach_state := str(capability.get("reach_state", "standing"))
			if reach_state == "platform":
				## A bump set is played off the forearms, so it leaves from the same
				## height a dig does. Drawn that way as well as priced that way --
				## the whole point of the state is that you can see it happen.
				return GeometricAttackPromotion.pass_contact_from_height(
					height_meters
				)
			return GeometricAttackPromotion.set_contact_from_reach(
				standing_reach, jumping_reach,
				reach_state in ["jump", "beyond_reach"],
			)
		RallyEventModel.EventType.ATTACK:
			return GeometricAttackPromotion.hitter_contact_from_reach(
				standing_reach, jumping_reach,
				float(event.metadata.get("jump_multiplier", 1.0)),
			)
		RallyEventModel.EventType.BLOCK:
			return GeometricAttackPromotion.block_contact_from_reach(jumping_reach)
	return float(event.metadata.get("contact_height_meters", 1.0))


## Stop the drawn ball where it was actually next touched.
##
## An event's `end_position` is where its *own* contact was aimed -- for an
## attack, the spot on the far floor the hitter went for. That is real data and
## the simulator is right to keep it. But it is not where the ball got to when
## somebody intercepted it on the way, and playback was drawing the whole aimed
## flight regardless.
##
## Measured across 736 consecutive contact pairs, the damage is confined to
## exactly the two pairs where an interception happens:
##
##     Serve -> Reception     0.00 m
##     Reception -> Set       0.00 m
##     Set -> Attack          0.00 m
##     Attack -> Block        5.68 m mean, 10.76 m worst
##     Block -> Defense       3.29 m mean, 11.16 m worst
##     Defense -> Set         0.11 m
##
## So a blocked spike drew its ball past the block, on to a floor target several
## metres away, and the block then began from the net -- which reads as the ball
## teleporting backward, or as the next contact happening somewhere nobody is
## standing. Twenty-seven per cent of all contact pairs were discontinuous.
static func terminate_at_next_contact(
	display: Dictionary, next_contact: RallyEvent
) -> void:
	if next_contact == null:
		## Nothing touched it next, so the aimed landing point is the truth: this
		## is a ball hitting the floor.
		return
	if not next_contact.success:
		## And a contact that *failed* is a ball nobody touched. A defender who
		## could not reach the line attack after moving a metre did not stop it;
		## dragging the flight to their feet drew the ball teleporting into
		## somebody who visibly never played it, then bouncing off nothing.
		## The aimed landing point is where it actually went.
		return
	terminate_trajectory(display, Vector2(next_contact.start_position))


## The geometry, on its own so it can be checked without a screen to run it in.
##
## The control point moves with the end. This is a quadratic Bezier, so leaving
## the control where it was would swing the shortened arc wide of both contacts
## -- the ball would finish in the right place having taken a route it never
## took. Rescaling it along the original curve keeps the shape of the flight and
## simply cuts it short, which is what an interception does.
static func terminate_trajectory(display: Dictionary, touched: Vector2) -> void:
	var start := Vector2(display.get("start_position", Vector2(0.5, 0.5)))
	var aimed := Vector2(display.get("end_position", start))
	if aimed.distance_to(touched) < 0.0005:
		return
	var control := Vector2(display.get("control_position", start.lerp(aimed, 0.5)))
	## Where along the aimed flight the interception sits, so the arc is cut at
	## the same fraction its control point is rescaled by.
	var travelled := start.distance_to(aimed)
	var share := clampf(
		start.distance_to(touched) / maxf(travelled, 0.0001), 0.05, 1.0
	)
	display["end_position"] = touched
	display["control_position"] = start.lerp(control, share)
	## The time has to come down with the distance.
	##
	## Cutting the path and keeping the duration was the whole of "the ball
	## freezes in place": a spike intercepted 30% of the way to its floor target
	## still spent the full flight covering that third, so it crawled from the
	## hitter to the block over most of a second and then sat there. The ball is
	## the same ball travelling at the same speed; it simply stops sooner.
	if display.has("duration"):
		var cut := float(display["duration"]) * share
		display["duration"] = maxf(cut, 0.08)
		## The same cut, without the drawing floor above.
		##
		## 0.08 s is the shortest segment a viewer can follow, so a shorter one is
		## stretched to it -- but a stretch is a concession about *time*, and the
		## ball must not move because of it. A struck ball's far end is derived
		## from its launch across a duration, and derived across the stretched one
		## it lands somewhere the ball never was: measured at attack-to-block, a
		## 20 ms spike drawn over 80 ms fell 1.25 m instead of 0.32 m, and arrived
		## a metre and a quarter below the hands that were about to touch it.
		display["physical_duration_seconds"] = maxf(cut, 0.001)


## How fast the ball actually left the contact, in metres per second.
##
## Both components, not just the ground one. A dig goes almost straight up and
## covers a metre and a half of floor in most of a second, so its *ground* speed
## is 1.6 m/s -- which would read as the softest touch in the game when it is a
## defender getting a hand on a spike. The vertical component is where a lobbed
## ball keeps its pace.
static func launch_speed_mps(display: Dictionary) -> float:
	var duration := maxf(float(display.get("duration", 0.5)), 0.05)
	var horizontal := RallyKinematics.court_distance_meters(
		Vector2(display.get("start_position", Vector2.ZERO)),
		Vector2(display.get("end_position", Vector2.ZERO)),
	) / duration
	var vertical := BallFlightModel.rise_speed_between(
		float(display.get("start_height_meters", 1.0)),
		float(display.get("end_height_meters", 1.0)),
		duration,
	)
	return sqrt(horizontal * horizontal + vertical * vertical)


## How much harder this ball is to handle for being struck at this pace.
##
## Lives beside `launch_speed_mps` because it reads that number and nothing else,
## and because both of them are statements about a flight rather than about
## either team. The simulator applies it; what a speed *means* is decided here.
##
## The anchors are ball speeds rather than percentiles on purpose. A quantile
## bound would move every time the pace of the game moved, so raising the speed
## of a spike would silently re-centre the difficulty of digging one and the two
## changes could never be told apart. `CONTROLLED_MPS` is a set or a bump -- both
## sit at 7.7 to 8.1 m/s measured -- and `HAMMER_MPS` is a driven international
## spike. Between them the multiplier runs from a slight discount to a little
## over half again, which is what puts the attack's contribution on the same
## scale as the defender's rather than a quarter of it.
const PACE_CONTROLLED_MPS: float = 8.0
const PACE_HAMMER_MPS: float = 30.0
const PACE_CONTROLLED_MULTIPLIER: float = 0.82
const PACE_HAMMER_MULTIPLIER: float = 1.70


static func pace_pressure_multiplier(speed_mps: float) -> float:
	return lerpf(
		PACE_CONTROLLED_MULTIPLIER, PACE_HAMMER_MULTIPLIER,
		clampf(inverse_lerp(PACE_CONTROLLED_MPS, PACE_HAMMER_MPS, speed_mps),
			0.0, 1.0),
	)


## What colour the ball's trail is, and how much of one it has.
##
## **One meaning per channel.** Colour is how well the contact was made, on the
## same five-tier scale every rating in the game is coloured by -- gold, green,
## blue, white, red -- so a viewer learns one scale for the whole product.
## Length and weight are how hard the ball was struck. Asking a single channel
## to carry both is what makes a red trail ambiguous between "hammered" and
## "shanked", and those are the two things a viewer most needs to tell apart.
##
## **The bands are measured, not inherited.** `VolleyballAttributeProfileSystem`
## grades a 0-100 attribute at 96 / 89 / 66 / 50, and reusing those on a contact
## quality would have been the mistake this repository keeps making: measured
## over 1131 contacts, quality runs p10 0.17, p50 0.50, p90 0.72, so those cuts
## put nine contacts in ten at the bottom two tiers and gold would never once
## have appeared. These sit on the quartiles of the distribution they actually
## cut, which puts roughly a quarter of contacts in each of the bottom three
## bands and gold on the top tenth.
const QUALITY_TIER_FLOORS := {"S": 0.74, "A": 0.62, "B": 0.50, "C": 0.34}
## The speed band the trail's weight is read against, from a ball that is barely
## moving to the hardest struck in the game. Measured launch speeds run from
## about 2 m/s on a soft set to 22 on a driven spike.
const TRAIL_SPEED_MIN_MPS: float = 4.0
const TRAIL_SPEED_MAX_MPS: float = 20.0


static func quality_tier(quality: float) -> String:
	for tier in ["S", "A", "B"]:
		if quality >= float(QUALITY_TIER_FLOORS[tier]):
			return tier
	return "C" if quality >= float(QUALITY_TIER_FLOORS.C) else "D"


static func trail_style(
	quality: float, display: Dictionary, light_mode: bool = false
) -> Dictionary:
	var tier := quality_tier(clampf(quality, 0.0, 1.0))
	var speed := launch_speed_mps(display)
	return {
		"tier": tier,
		"color": UIPalette.grade_color(tier, light_mode),
		"speed_mps": speed,
		"power": clampf(inverse_lerp(
			TRAIL_SPEED_MIN_MPS, TRAIL_SPEED_MAX_MPS, speed
		), 0.0, 1.0),
	}


## Where the ball is, in court coordinates and metres above the floor, partway
## through a drawn flight.
##
## The court's own sampler calls this. So does every probe, which is the point:
## a probe that re-derived the position would be measuring its own arithmetic.
static func sample(display: Dictionary, progress: float) -> Dictionary:
	var t := clampf(progress, 0.0, 1.0)
	var start := Vector2(display.get("start_position", Vector2(0.5, 0.5)))
	var end := Vector2(display.get("end_position", start))
	var control := Vector2(display.get("control_position", start.lerp(end, 0.5)))
	var inverse := 1.0 - t
	return {
		"court": inverse * inverse * start + 2.0 * inverse * t * control
			+ t * t * end,
		"height_meters": BallFlightModel.height_between(
			float(display.get("start_height_meters", 1.0)),
			float(display.get("end_height_meters", 1.0)),
			float(display.get("duration", 0.5)),
			t,
		),
	}


## How high the ball is when it crosses the tape, or -1 if this flight never
## crosses it.
##
## The one question a drawn flight can fail at silently. A hump whose apex was
## floored above the net could not fail it; a real parabola can, and a ball drawn
## through the net is worse than a ball drawn too high.
static func net_crossing_height(display: Dictionary) -> float:
	var start := Vector2(display.get("start_position", Vector2(0.5, 0.5)))
	var end := Vector2(display.get("end_position", start))
	if (start.y - 0.5) * (end.y - 0.5) > 0.0:
		return -1.0
	## Walked rather than solved, because the horizontal path is a Bezier and the
	## crossing fraction of a Bezier in y is a quadratic whose root still has to
	## be mapped back through the curve. Sixty-four steps resolves the tape to
	## about 1.5% of the flight, which is finer than the question needs.
	var previous := start.y - 0.5
	for step in range(1, 65):
		var t := float(step) / 64.0
		var here := float(Vector2(sample(display, t)["court"]).y) - 0.5
		if previous == 0.0 or (previous < 0.0) != (here < 0.0):
			return BallFlightModel.height_between(
				float(display.get("start_height_meters", 1.0)),
				float(display.get("end_height_meters", 1.0)),
				float(display.get("duration", 0.5)),
				t,
			)
		previous = here
	return -1.0
