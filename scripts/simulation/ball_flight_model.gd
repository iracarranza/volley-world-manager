class_name BallFlightModel
extends RefCounted

## Projectile motion launched from a contact height, with a signed launch angle.
##
## This exists alongside `RallyKinematics.solve_launch_arc()` rather than
## replacing it, because the two answer opposite questions and the old one is
## still wired into every live call site.
##
## `solve_launch_arc` is the *level-ground* solution: it assumes the ball is
## launched and lands at the same height, it clamps the launch angle positive,
## and it takes the landing point as given and back-solves the force needed to
## reach it. That is the right shape for "the setter is putting the ball on the
## pin" and the wrong shape for a spike. A spike contacts near 3.2 m and is
## struck *downward*; a negative angle puts a negative under that square root,
## so the engine currently models every attack as a ball lobbed upward from the
## floor to the floor and only gets away with it because nothing ever asks
## whether the flight is physical.
##
## Here the causal direction is inverted. Speed and angle are chosen, and the
## landing is whatever the physics produces -- including landing out. That is
## what allows in/out, block contact and the drawn arc to be one computation
## instead of three that have to be kept in agreement by hand.
##
## Purely the vertical plane along the shot's bearing: distances are horizontal
## ground distance, not court coordinates. Callers compose this with a
## horizontal bearing to get a 3D path, which keeps the physics free of court
## geometry and keeps the bearing free of gravity.
##
## No drag and no spin. That is a real simplification, but a smaller one than it
## sounds: a struck volleyball's range is dominated by its downward launch angle
## rather than by aerodynamics, and allowing negative angles does most of the
## work a drag term would otherwise have to. Float and topspin serves remain
## outside what this can express.

## Gravity, for every ball in the engine.
##
## The single declaration. It stood at 9.8 here and in `RallyKinematics` and at
## 9.81 in `BlockJumpModel` -- one physical constant with two values, which is a
## small error and exactly the kind that survives because nobody looks at it.
## Unified downward to 9.8, which is what two of the three declarations used and
## what the hand-derived expectations in `_test_ball_flight_from_contact_height`
## were computed from. The other 0.1% buys no physical fidelity and would have
## invalidated every one of those literals.
const DEFAULT_GRAVITY_MPS2: float = 9.8
const MIN_SPEED_MPS: float = 0.1
const MIN_FLIGHT_DURATION: float = 0.01
## Signed, unlike the level-ground model's 2..75. Negative is a struck ball
## driven downward and is the *ordinary* case for an attack, not an edge case.
## The bounds exist only to keep cos(theta) away from zero, where horizontal
## range collapses and the inverse solve stops being meaningful.
const MIN_LAUNCH_ANGLE_DEGREES: float = -85.0
## Deliberately *not* the same bound as `RallyKinematics.MAX_LAUNCH_ANGLE_DEGREES`,
## which sits at 75 degrees. That one bounds the apex of a drawn ground-to-ground
## arc, where an unclamped steep solution implies a physically silly apex over a
## real court distance. This one bounds a launch from three metres up whose
## outcome is read off where it lands, and a serve or a heavily lifted ball
## genuinely leaves the hand steeper than 75.
##
## The divergence is the point and is stated in both files. What was wrong was
## that neither knew the other existed, so a reader of either would have assumed
## it was the bound.
const MAX_LAUNCH_ANGLE_DEGREES: float = 85.0


## Where a ball struck at `speed_mps` and `launch_angle_degrees` from
## `contact_height_meters` comes back to the floor.
##
## Always solves for a contact above the floor -- the ball always comes down --
## so a shot with too little speed lands short rather than failing to resolve.
## There is no "cannot reach" case to special-case anywhere downstream.
static func solve_flight(
	speed_mps: float,
	launch_angle_degrees: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var speed := maxf(speed_mps, MIN_SPEED_MPS)
	var gravity := maxf(gravity_mps2, 0.1)
	var height := maxf(contact_height_meters, 0.0)
	var angle := clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	)
	var radians := deg_to_rad(angle)
	var vertical := speed * sin(radians)
	var horizontal := speed * cos(radians)
	## t = (v*sin(theta) + sqrt(v^2*sin^2(theta) + 2*g*h)) / g
	var duration := (
		vertical + sqrt(vertical * vertical + 2.0 * gravity * height)
	) / gravity
	duration = maxf(duration, MIN_FLIGHT_DURATION)
	## A ball already descending at contact never rises, so its apex is the
	## contact itself. Only a ball struck upward has an apex above the hand.
	var apex := height
	if vertical > 0.0:
		apex = height + vertical * vertical / (2.0 * gravity)
	return {
		"range_meters": maxf(horizontal * duration, 0.0),
		"duration_seconds": duration,
		"apex_height_meters": apex,
		"landing_speed_mps": sqrt(speed * speed + 2.0 * gravity * height),
		"launch_angle_degrees": angle,
		"speed_mps": speed,
		"contact_height_meters": height,
		"horizontal_speed_mps": horizontal,
		"vertical_speed_mps": vertical,
	}


## How high the ball is once it has travelled `horizontal_distance_meters` along
## the ground.
##
## This is what a block intersection test reads: put the blocker's distance in,
## compare the height out against their reach. Returns a negative height past
## the landing point, so callers can tell "the ball was already down" from "the
## ball passed over low".
static func height_at_distance(
	flight: Dictionary,
	horizontal_distance_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var horizontal := float(flight.get("horizontal_speed_mps", 0.0))
	if horizontal <= MIN_SPEED_MPS:
		return float(flight.get("contact_height_meters", 0.0))
	var gravity := maxf(gravity_mps2, 0.1)
	var elapsed := maxf(horizontal_distance_meters, 0.0) / horizontal
	return float(flight.get("contact_height_meters", 0.0)) \
		+ float(flight.get("vertical_speed_mps", 0.0)) * elapsed \
		- 0.5 * gravity * elapsed * elapsed


## The launch angle that lands a ball of this speed at this range.
##
## The inverse of `solve_flight`, for a decision layer that knows where it wants
## the ball and how hard it intends to hit it. Substituting the trajectory
## equation at y = 0 and writing u = tan(theta) gives a quadratic:
##
##   k*u^2 - R*u + (k - h) = 0,  where k = g*R^2 / (2*v^2)
##
## Its two roots are the two ways to hit the same spot at the same speed: the
## flatter, driven one and the lofted one. They are returned separately rather
## than picked here, because which is wanted is a decision -- a spike takes the
## driven root, a roll shot takes the lofted one -- and that decision does not
## belong to the physics.
##
## `found` is false when the discriminant is negative: no angle at this speed
## reaches this far, which is the honest answer for a ball hit too softly.
##
## Each root is flagged separately, and **a root outside the representable angle
## band is reported unusable rather than clamped into it**. Clamping looks
## harmless and is not: the lofted root for a fast ball at short range is a
## near-vertical lob -- 22 m/s over 4 m solves to 87.7 degrees -- and pinning
## that to 85 returns an angle that carries 8.8 m instead of the 4 m asked for.
## A solver that answers a different question than the one posed is the exact
## failure this whole model exists to remove, so it declines instead.
static func solve_angle_for_range(
	speed_mps: float,
	range_meters: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> Dictionary:
	var speed := maxf(speed_mps, MIN_SPEED_MPS)
	var target_range := maxf(range_meters, 0.0)
	var height := maxf(contact_height_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var unreachable := {
		"found": false,
		"driven_found": false, "driven_angle_degrees": 0.0,
		"lofted_found": false, "lofted_angle_degrees": 0.0,
	}
	if target_range <= 0.0001:
		return unreachable
	var k := gravity * target_range * target_range / (2.0 * speed * speed)
	if k <= 0.0000001:
		return unreachable
	var discriminant := target_range * target_range - 4.0 * k * (k - height)
	if discriminant < 0.0:
		return unreachable
	var root := sqrt(discriminant)
	var driven := rad_to_deg(atan((target_range - root) / (2.0 * k)))
	var lofted := rad_to_deg(atan((target_range + root) / (2.0 * k)))
	var driven_usable := driven >= MIN_LAUNCH_ANGLE_DEGREES \
		and driven <= MAX_LAUNCH_ANGLE_DEGREES
	var lofted_usable := lofted >= MIN_LAUNCH_ANGLE_DEGREES \
		and lofted <= MAX_LAUNCH_ANGLE_DEGREES
	return {
		"found": driven_usable or lofted_usable,
		"driven_found": driven_usable,
		"driven_angle_degrees": driven,
		"lofted_found": lofted_usable,
		"lofted_angle_degrees": lofted,
	}


## The slowest a ball can be struck at this angle and still carry this far.
## Useful to a decision layer deciding whether a course is available at all
## before it commits to a power.
static func minimum_speed_for_range(
	range_meters: float,
	launch_angle_degrees: float,
	contact_height_meters: float,
	gravity_mps2: float = DEFAULT_GRAVITY_MPS2,
) -> float:
	var target_range := maxf(range_meters, 0.0)
	var height := maxf(contact_height_meters, 0.0)
	var gravity := maxf(gravity_mps2, 0.1)
	var radians := deg_to_rad(clampf(
		launch_angle_degrees, MIN_LAUNCH_ANGLE_DEGREES, MAX_LAUNCH_ANGLE_DEGREES
	))
	var cosine := cos(radians)
	if target_range <= 0.0001 or cosine <= 0.0001:
		return MIN_SPEED_MPS
	## From y = 0 at x = R:  v^2 = g*R^2 / (2*cos^2(theta)*(R*tan(theta) + h))
	var denominator := 2.0 * cosine * cosine \
		* (target_range * tan(radians) + height)
	if denominator <= 0.0000001:
		## The angle alone already carries the ball past the range no matter how
		## softly it is struck.
		return MIN_SPEED_MPS
	return maxf(
		sqrt(gravity * target_range * target_range / denominator), MIN_SPEED_MPS
	)
