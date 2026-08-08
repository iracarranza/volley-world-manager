class_name SpikeBiomechanics
extends RefCounted

## A spike as a sequence of segments, not a single sweep.
##
## The attack pose used to interpolate one `swing` value: the shoulder rotated
## at a constant rate, the elbow opened at a constant rate, the legs held a fixed
## stride for the entire action and the torso held a fixed lean. Everything moved
## together and nothing moved first, which is what a windmill looks like and what
## a spike does not.
##
## What separates them is **proximal-to-distal sequencing**. A hitter drives from
## the floor and each segment peaks after the one inside it: knees extend, then
## the hips and trunk, then the shoulder, then the elbow, and the hand arrives
## last and fastest. Every segment is still travelling when the next one starts,
## so the body reads as a chain being cracked rather than a diagram rotating.
## That ordering is the whole of the visual difference, and it is why this is a
## table of staggered windows rather than a curve.
##
## Deliberately pure and deterministic: phase in, angles out, no state and no
## randomness. It is the only way pose work can be checked without eyes on a
## screen, and the suite does check it.
##
## ## Phase convention
##
## `phase` is signed and **contact is at 0**.
##
##   -1.0  the plant begins -- the hitter is still on the floor, arms behind
##    0.0  the hand meets the ball, at the top of the jump
##   +1.0  the landing has been absorbed
##
## The negative half is spent during the *set's* flight and the positive half
## during the attack's own, which is why playback needs a phase that spans two
## event windows rather than restarting in each. Before this, both halves ran
## 0 to 1 independently: the swing played out completely during the approach and
## then snapped back to fully cocked at the instant of contact and played again.

## Where each phase of the spike begins, on the signed timeline above.
##
## Chosen against the real proportions of the action rather than spaced evenly.
## The plant and the takeoff take most of the wind-up; the cock is brief; the
## acceleration into contact is very brief, which is exactly why a spike looks
## fast even though the whole action is not.
const PLANT_END: float = -0.62
const TAKEOFF_END: float = -0.40
const COCK_END: float = -0.14
const FOLLOW_END: float = 0.45

## How wide a slice around zero `phase_name` is willing to call the contact.
## Narrow on purpose: it is a label for the instant, not a phase with a duration.
const CONTACT_BAND: float = 0.04

## When the swing arm starts returning to a neutral hang.
##
## Well after `FOLLOW_END`, because the follow-through does not stop when the
## legs land. Set here rather than reusing `FOLLOW_END` so the two can be tuned
## apart -- they are different events happening to different limbs.
const ARM_RECOVER_START: float = 0.72

## How far the arm swings behind the hips on the double-arm backswing.
##
## Positive rotates the arm backward on this rig. Both arms do this together --
## it is the counterweight that the takeoff converts into height, and drawing a
## hitter planting with their arms already up is the single most common way a
## spike animation reads as floaty.
const BACKSWING_DEGREES: float = 42.0

## The striking shoulder through the action. Negative carries the arm up and
## over: -180 is straight overhead, so -204 at contact is just forward of
## vertical, which is where a hitter actually meets the ball, and -252 is the
## arm continuing down across the body.
const SHOULDER_LIFT_DEGREES: float = -124.0
## The cock is a **high elbow**, not a raised arm.
##
## It was -152, which carries the upper arm to 62 degrees above horizontal --
## nearly overhead -- and with the elbow folded from there the forearm had nowhere
## to go but down and behind. Measured on the rig, that pair put the elbow 0.34 m
## above the shoulder and the hand 0.15 m above it and 0.31 m behind: the hand
## *below* its own elbow, hanging backward. A hitter never loads there.
##
## At -128 the elbow sits 0.25 m up and 0.29 m back -- pulled behind the shoulder
## line and above it, which is where the tension actually is -- and the forearm
## can then stand up out of it. The power comes from the shoulder pivoting forward
## and the forearm extending, so the load has to leave both of those with somewhere
## to travel.
const SHOULDER_COCK_DEGREES: float = -128.0
const SHOULDER_CONTACT_DEGREES: float = -204.0
const SHOULDER_FOLLOW_DEGREES: float = -252.0

## The elbow is what makes the arm a whip rather than a stick. It stays folded
## deep into the cock and opens *through* contact, one beat behind the shoulder.
##
## **Negative, and the sign was measured rather than reasoned.** The comment on
## `_set_elbow` says positive folds the forearm forward, and with the upper arm
## already tipped past vertical at the old cock that sent the hand backward and
## down instead. Sampling the rig's own node positions settles it: at -128/-46 the
## hand lands 0.22 m above the elbow and 0.04 m behind it -- a forearm standing
## very nearly vertical, hand up by the ear. At -152/+118 it landed 0.19 m *below*
## the elbow and 0.13 m further back.
##
## The travel from here to contact is 53 degrees rather than 111. That is still
## the widest joint excursion in the swing over the narrowest window, and it is
## still the whip; it is simply a whip that starts from a shape a hitter makes.
const ELBOW_COCK_DEGREES: float = -46.0
const ELBOW_CONTACT_DEGREES: float = 7.0
const ELBOW_FOLLOW_DEGREES: float = 58.0

## The bow. The trunk hyperextends during the cock and snaps forward through
## contact, and this is where most of a spike's power actually comes from.
## Negative is a forward lean on this rig, so the positive value is the arch.
const TORSO_PLANT_RADIANS: float = -0.26
## Where the trunk gets back to as the hitter leaves the floor. Without this the
## plant's forward lean was held all the way to the arch, so the one frame where
## a hitter should look tallest was the frame they looked most like they were
## falling over.
const TORSO_TAKEOFF_RADIANS: float = -0.04
const TORSO_ARCH_RADIANS: float = 0.21
const TORSO_CONTACT_RADIANS: float = -0.12
## Deep enough to read as the trunk finishing the swing, shallow enough not to
## read as a bow. At -0.44 the landing frame was folded almost double.
const TORSO_FOLLOW_RADIANS: float = -0.29

## Hip-shoulder separation, in degrees of trunk twist. The shoulders rotate away
## from the target during the cock and unwind through contact; without it the
## whole upper body is one rigid plank and the arm appears to be doing all the
## work by itself.
const TORSO_TWIST_DEGREES: float = 19.0
const TORSO_UNWIND_DEGREES: float = -13.0

## Knee flexion, negative because every knee on this rig folds backward.
## A loaded athletic stance, not a squat. At -78 with the hips also forward the
## shin came through the front of the thigh and the plant read as tangled.
const KNEE_LOAD_DEGREES: float = -58.0
const KNEE_EXTENDED_DEGREES: float = -6.0
const KNEE_TUCK_DEGREES: float = -52.0
const KNEE_LANDING_DEGREES: float = -58.0


## Eased 0-1 progress through a window, clamped outside it.
##
## Smoothstep rather than linear because a segment accelerates into its own
## motion and decelerates out of it; linear ramps are what make interpolated
## joints read as machinery. A zero-width window returns 1.0 rather than
## dividing by it.
static func window(phase: float, from_phase: float, to_phase: float) -> float:
	if to_phase - from_phase <= 0.00001:
		return 1.0 if phase >= to_phase else 0.0
	return smoothstep(from_phase, to_phase, phase)


## Every joint the attack pose needs, for one instant of the swing.
##
## `handedness_sign` is +1 for a right-handed hitter and -1 for a left-handed
## one, and only the twist and the follow-through's cross-body roll read it --
## the sagittal angles are the same swing either way.
static func resolve(phase: float, handedness_sign: float) -> Dictionary:
	var p := clampf(phase, -1.0, 1.0)
	var hand := 1.0 if handedness_sign >= 0.0 else -1.0

	## Proximal first. The legs are already extending while the arms are still
	## behind the body, which is what actually lifts the hitter.
	var load := window(p, -1.0, PLANT_END)
	var extend := window(p, PLANT_END, TAKEOFF_END)
	var tuck := window(p, TAKEOFF_END, COCK_END)
	## Then the trunk, then the shoulder, then the elbow -- each starting before
	## the previous one has finished and peaking after it.
	var arch := window(p, TAKEOFF_END, COCK_END + 0.02)
	var snap := window(p, COCK_END, 0.02)
	var lift := window(p, PLANT_END + 0.06, COCK_END)
	## The shoulder drives from the cock to the ball, and the elbow's window
	## starts *after* it and ends *after* it. That offset is the whip, and it is
	## the one relationship in this file that must not be tuned away: an elbow
	## that opens with the shoulder is a straight arm rotating from behind the
	## ear, which is the windmill this replaced.
	##
	## The elbow's is also the widest travel in the swing over the narrowest
	## window -- 111 degrees in 0.13 of phase -- because that is what a whip is.
	## It was narrower still until the continuity check pointed out that a
	## segment moving 7 degrees per sample is indistinguishable from one
	## teleporting, at the sampling rate playback actually runs at.
	var strike := window(p, COCK_END, 0.0)
	var elbow_release := window(p, COCK_END + 0.03, 0.02)
	var follow := window(p, 0.0, FOLLOW_END)
	var land := window(p, FOLLOW_END, 1.0)
	## The arm finishes after the feet do.
	##
	## Shoulder and elbow used to return to rest on `land`, the same window the
	## legs absorb on -- so the swing arm snapped back to a neutral hang the
	## instant the follow-through ended, and the spike stopped looking like a
	## spike a beat before it stopped being one. A real follow-through carries
	## down and across the body and is still unwinding while the hitter is already
	## on the floor.
	##
	## The same proximal-to-distal rule the rest of this file runs on, applied to
	## the end of the action rather than the start of it.
	var arm_recover := window(p, ARM_RECOVER_START, 1.0)

	## The shoulder walks back through the plant, up through the takeoff, into
	## the cock, through the ball, and across the body.
	var shoulder := lerpf(BACKSWING_DEGREES, 0.0, load * 0.35)
	shoulder = lerpf(shoulder, SHOULDER_LIFT_DEGREES, lift)
	shoulder = lerpf(shoulder, SHOULDER_COCK_DEGREES, tuck)
	shoulder = lerpf(shoulder, SHOULDER_CONTACT_DEGREES, strike)
	shoulder = lerpf(shoulder, SHOULDER_FOLLOW_DEGREES, follow)
	shoulder = lerpf(shoulder, -16.0, arm_recover)

	## And the elbow lags it. Folding early and opening late is the entire
	## difference between a whip and a windmill, so these windows deliberately
	## start after the shoulder's and end after it too.
	var elbow := lerpf(28.0, ELBOW_COCK_DEGREES, maxf(lift, tuck))
	elbow = lerpf(elbow, ELBOW_CONTACT_DEGREES, elbow_release)
	elbow = lerpf(elbow, ELBOW_FOLLOW_DEGREES, follow)
	elbow = lerpf(elbow, 22.0, arm_recover)

	## The guide arm is not decoration. It reaches at the ball through the cock
	## and is pulled down hard through contact -- that pull is what rotates the
	## trunk, and a hitter drawn without it looks like they are swinging at
	## something out of reach.
	var guide := lerpf(BACKSWING_DEGREES, -148.0, maxf(lift, tuck))
	guide = lerpf(guide, -34.0, snap)
	guide = lerpf(guide, -12.0, follow)
	guide = lerpf(guide, -8.0, land)
	var guide_elbow := lerpf(24.0, 18.0, tuck)
	guide_elbow = lerpf(guide_elbow, 74.0, snap)
	guide_elbow = lerpf(guide_elbow, 46.0, follow)

	## The bow, and its release.
	var torso := lerpf(0.0, TORSO_PLANT_RADIANS, load)
	torso = lerpf(torso, TORSO_TAKEOFF_RADIANS, extend)
	torso = lerpf(torso, TORSO_ARCH_RADIANS, arch)
	torso = lerpf(torso, TORSO_CONTACT_RADIANS, snap)
	torso = lerpf(torso, TORSO_FOLLOW_RADIANS, follow)
	torso = lerpf(torso, -0.14, land)
	var twist := lerpf(0.0, TORSO_TWIST_DEGREES * hand, maxf(lift, tuck))
	twist = lerpf(twist, TORSO_UNWIND_DEGREES * hand, maxf(snap, follow))
	twist = lerpf(twist, 0.0, land)

	## Legs: loaded, extended, tucked under in flight, then swung forward to
	## land and folded again to absorb it.
	var knee := lerpf(-14.0, KNEE_LOAD_DEGREES, load)
	knee = lerpf(knee, KNEE_EXTENDED_DEGREES, extend)
	knee = lerpf(knee, KNEE_TUCK_DEGREES, tuck)
	knee = lerpf(knee, -24.0, follow)
	knee = lerpf(knee, KNEE_LANDING_DEGREES, land)
	var lead_hip := lerpf(16.0, 24.0, load)
	lead_hip = lerpf(lead_hip, 4.0, extend)
	lead_hip = lerpf(lead_hip, -12.0, tuck)
	lead_hip = lerpf(lead_hip, 26.0, follow)
	lead_hip = lerpf(lead_hip, 12.0, land)
	var trail_hip := lerpf(-12.0, -22.0, load)
	trail_hip = lerpf(trail_hip, -4.0, extend)
	trail_hip = lerpf(trail_hip, -21.0, tuck)
	trail_hip = lerpf(trail_hip, 14.0, follow)
	trail_hip = lerpf(trail_hip, 6.0, land)

	return {
		"phase_name": phase_name(p),
		"striking_shoulder_degrees": shoulder,
		"striking_elbow_degrees": elbow,
		"guide_shoulder_degrees": guide,
		"guide_elbow_degrees": guide_elbow,
		"torso_pitch_radians": torso,
		"torso_twist_degrees": twist,
		"knee_degrees": knee,
		"lead_hip_degrees": lead_hip,
		"trail_hip_degrees": trail_hip,
	}


## Which named phase this instant belongs to, so a diagnostic can say where a
## swing is rather than printing nine angles.
static func phase_name(phase: float) -> String:
	if phase < PLANT_END:
		return "plant"
	if phase < TAKEOFF_END:
		return "takeoff"
	if phase < COCK_END:
		return "cock"
	if phase < 0.0:
		return "acceleration"
	## Contact is an instant rather than a span, but a diagnostic that never says
	## the word is a diagnostic that cannot report the one frame everything else
	## is timed against -- and this pose model exists because that frame was being
	## drawn wrong.
	if phase < CONTACT_BAND:
		return "contact"
	if phase < FOLLOW_END:
		return "follow_through"
	return "landing"
