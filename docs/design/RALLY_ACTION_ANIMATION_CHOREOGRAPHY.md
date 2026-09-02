# Rally action animation choreography and biomechanics

Status: presentation authority for the procedural 3D voli rig.

The simulator owns which action happened, whether contact occurred, the contact
time and height, and the ball that left it. Playback owns only how that resolved
action is embodied. Every action below therefore consumes published event
metadata and a signed presentation phase (`-1` preparation, `0` contact, `+1`
recovery). It must never change an event, move the ball, or turn a miss into a
touch.

## Shared movement grammar

Every contact is a complete action, not a contact pose:

1. orient and establish support;
2. load from the floor or, if already airborne, organize the legs as ballast;
3. sequence proximal-to-distal motion (legs, pelvis/trunk, shoulder, elbow);
4. meet the authoritative contact at phase zero;
5. carry momentum through the ball without freezing at contact;
6. land or recover into the next published stance.

The support foot must not visibly skate. Grounded actions keep a stagger or
balanced base; jumping actions leave from a bilateral plant and return through
an absorbing knee/hip fold. Mirrored quantities are limited to handedness and
direction. Phase boundaries, joint magnitudes, and action identity do not change
between left- and right-handed volis.

## Serve routines

All serves begin with a quiet possession beat. The server checks the target,
lets the shoulders settle, and transfers the ball into the guide hand before the
toss. A stable per-voli rhythm may vary the length of that beat, the number of
small ball-settling pulses, and the amount of pre-toss weight rock; it may not
move phase zero or resample during replay.

### Standing serve

- Support: staggered base, lead foot toward the court, weight initially on the
  trail leg.
- Toss: compact and mostly vertical, with the guide elbow nearly straight.
- Load: modest knee fold and trunk coil; the feet remain grounded.
- Contact: tall over the lead foot with a long striking arm.
- Follow-through: hand travels down and across, trail hip comes through, and the
  first court-entry step follows the ball.

This is a controlled kinetic chain. It must read as self-paced and repeatable,
not as a jump serve with its elevation removed.

### Jump topspin

- Support: a three-beat approach closes into a bilateral plant.
- Toss: high and forward so the body must travel to it.
- Load/take-off: deep penultimate knee fold, both arms contribute to lift, then
  the legs extend before the trunk bows.
- Contact: airborne at the highest reachable point, shoulder internally
  rotating and elbow opening last; the torso snaps over the ball.
- Follow-through/landing: striking arm crosses the body, legs tuck slightly,
  then both feet absorb before the server enters the court.

The silhouette must distinguish topspin through a long approach, full bow, high
contact, and forceful cross-body finish. Spin itself remains the ball renderer's
job.

### Jump float

- Support: short two-beat gather into a square bilateral plant.
- Toss: lower, closer, and less forward than topspin.
- Take-off: compact vertical jump with limited trunk arch.
- Contact: firm open-hand punch near the body midline, elbow extending into the
  ball with minimal shoulder sweep.
- Follow-through/landing: hand arrests shortly after contact; torso stays quiet;
  feet land together and absorb symmetrically.

The visible contrast with topspin is reduced approach travel, reduced coil, a
short striking path, and an intentionally abbreviated follow-through.

### Hybrid

- Support and toss follow the jump float's compact approach.
- Load retains more hip-shoulder separation than a float.
- Contact uses a longer shoulder path than float but less bow and carry than
  topspin.
- Follow-through continues past the ball without the full topspin wrap.

Hybrid must read as an ambiguous preparation resolved late, not as a linear
average that lacks a recognizable support pattern.

### Sky ball

- Support: open stance with a pronounced side-to-side weight rock.
- Toss: low in the striking-side channel.
- Contact: grounded underhand upswing, long elbow, shoulder rising from below
  the hip while the legs and trunk extend upward.
- Follow-through: striking hand points high after the ball; chest and gaze lift
  to follow the steep flight.

It must never borrow the overhead arm path used by the other four styles.

## First-contact variants

### Planted and moving reception

The existing platform remains authoritative: shoulders round slightly, elbows
lock, thumbs align, and the legs drive through the ball. A moving receiver forms
the platform only over the final stride. Platform angle follows resolved launch
geometry, not a generic target pose.

### Diving receive

- Read/commit: head and sternum lead toward the ball; the last support leg bends
  and pushes laterally or forward.
- Flight: hips follow the sternum, legs trail, and both forearms assemble ahead
  of the shoulders. The body must not fall before it has pushed.
- Contact: authoritative at phase zero, with the platform ahead of the head and
  close to the floor. The chest remains off the ground at the instant of touch.
- Floor arrival: hands/forearms and the outside thigh or side of the trunk share
  load; the neck stays extended so the face does not strike the floor.
- Recovery: slide or shoulder-to-hip roll according to resolved direction, then
  kneel and stand on the simulator's published recovery clock.

A missed dive still draws the commitment and floor arrival, but never the
platform drive or contact follow-through.

## Second-contact variants

### Front set

Feet stagger toward the target; knees load before the hands; extension proceeds
ankle-knee-hip-shoulder-elbow-fingers. Hands finish high and out. Existing
standing, jump, and underhand support states remain distinct.

### Back set

- Preparation disguises the target: shoulders and hands gather as for a front
  set and the head may continue reading forward.
- Delivery: chest opens upward, hands carry over the crown, and the pelvis shifts
  onto the trailing foot rather than rotating to face the target.
- Contact: elbows extend symmetrically above/just behind the forehead.
- Recovery: the arch releases promptly and the setter regains a neutral spine.

Back-set identity is orthogonal to standing/jump/underhand posture. Playback must
not turn the whole actor toward the outgoing ball, because doing so erases the
action's defining relationship.

## Attack variants

Every attack shares the published approach and jump timing. Variant identity
changes the striking chain only after the same credible approach has sold a
full swing.

### Power swing

The existing spike is the reference: bilateral plant, leg drive, trunk bow,
guide-arm pull, delayed elbow whip, full extension at contact, cross-body
follow-through, tuck, and two-foot absorption.

### Roll shot

- Preparation preserves the power-swing approach and high elbow.
- Deceleration begins late, after the block has had time to read a swing.
- Contact uses an open hand above the ball with a softer elbow and reduced trunk
  snap; the shoulder continues smoothly instead of punching.
- Follow-through is long but relaxed, finishing forward rather than wrapping
  violently across the body.

The late change of speed is the action. A permanently slow arm from take-off is
not a roll shot because it deceives nobody.

### Feint / dink / tip

- Preparation preserves the approach, jump, guide arm, and initial cock.
- The striking elbow stays flexed as the hand comes forward.
- Contact occurs in front of the hitting shoulder with a compact one-hand reach;
  trunk rotation and shoulder speed are sharply reduced.
- Follow-through stops close to the ball, then the arm withdraws for landing.

`Feint`, `Dink`, `Tip`, `Short tip`, and `Emergency tip` share this biomechanical
family, with emergency variants allowed a smaller reach and less balanced trunk.
They remain distinct tactical labels in event metadata.

## Idle, attention, and readiness

Idle motion is subordinate to volleyball information. It may make a living body
visible; it may not obscure the stance, contact timing, gaze target, or movement
path.

### Standing idle

- Breathing is a slow, shallow chest expansion with an opposing millimetric body
  rise; shoulders do not pump.
- Weight transfers between feet over several seconds. The pelvis shifts first,
  then the torso counterbalances by a few degrees.
- Knees remain soft and elbows unlocked. Hands lag the torso slightly.
- Each voli receives a stable phase offset so twelve bodies do not breathe and
  sway in unison.

Idle motion fades continuously as locomotion or a contact pose gains weight.

### Standing to ready, and settling

- Attention leads with the eyes/head.
- Hips move back and down before the knees reach their final fold.
- Feet widen or stagger through a short weight shift rather than snapping apart.
- Arms arrive last: platform-ready low for defence, hands high at the net, or
  loose at the side while watching.
- The final tenth is a decelerating settle, not a frozen endpoint.

The existing stance-distance duration remains authoritative; no pairwise timing
table is introduced.

### Blink and micro-saccade

- Blinks close quickly, hold briefly, and reopen slightly slower.
- Both eyelids move together; pupils remain seated inside the eye geometry.
- Blink interval and phase are stable per player and deterministic in replay.
- A small pupil drift may occur between blinks, bounded well inside the eye.
- Full blinks are suppressed around contact so the actor does not visibly close
  their eyes while playing the ball.

Expression remains the long-lived eye/mouth combination. Blinking and saccades
are transient overlays and must never rebuild or rename that expression.

## Traceability and acceptance

Each implementation must provide a pure resolver or pure diagnostic for its
stage boundaries and joint values. Contracts must establish:

- every serve style resolves to a distinct support/contact silhouette;
- jump styles leave the floor and standing/sky-ball styles do not;
- sky ball uses an underhand path;
- a dive moves the torso toward the ball before floor arrival;
- a back set arches/carries behind while preserving its posture class;
- roll and dink preserve the approach but diverge at the striking arm;
- idle amplitude is bounded and fades during action;
- blink timing is deterministic and open at contact;
- left/right handed variants mirror signed motion without changing timing.

Frame strips are the visual acceptance artifact. At minimum they show the five
serve styles, the diving reception, front/back set comparison, power/roll/dink
attack comparison, standing-to-ready settle, breathing/weight shift, and one
complete blink from both side and three-quarter cameras where appropriate.

## Implementation conformance

The implemented presentation follows this specification through four pure
resolvers and one rig integration point:

- `ServeActionBiomechanics` consumes the published serve style. Standing keeps
  zero rise and uses a compact toss/step transfer; jump topspin adds the longest
  approach, deepest loading, highest rise, trunk bow, and cross-body carry;
  jump float uses a lower compact rise and arrests the striking hand; hybrid
  retains the float support pattern but releases into a longer rotational path;
  sky ball bypasses the overhead resolver and supplies its own grounded
  underhand shoulder path. `routine_variant(player_id)` chooses the possession
  rhythm deterministically without changing contact phase.
- `DefenseActionBiomechanics` activates only from the event's resolved
  `posture` and `recovery`. Its pre-contact envelope moves the sternum forward
  and centre of mass down before phase zero; the existing platform resolver
  still owns the arms and the recovery resolver owns floor contact. The forward
  slide now unwinds on the existing recovery rise, returning a coherent kneel
  instead of carrying a below-floor translation into the next event.
- The existing set resolver receives `back_set` independently of standing,
  jump, or underhand posture. The rig keeps its gaze/facing forward, then applies
  the resolver's larger chest arch and behind-crown shoulder carry. This is why
  the front/back strips share preparation and support but separate at delivery.
- `AttackActionBiomechanics` delegates the entire approach, plant, jump, and
  early arm cock to `SpikeBiomechanics`. Its late envelope begins at phase
  `-0.18`: power remains the reference whip; roll retains a long arm while
  opening the shoulder, softening the elbow, quieting the torso, and holding the
  guide arm for balance; dink/feint/tip keeps the elbow markedly flexed and
  stops the hand in front of the shoulder. The first half of all three proof
  strips is therefore the same sell, while contact and follow-through diverge.
- `IdleBiomechanics` produces bounded breathing, pelvis-led weight shift,
  counter-sway, arm lag, pupil drift, and a stable per-player phase. The stance
  transition continues to use the existing stance-distance duration and its
  decelerating settle. Blink close/hold/open bands are deterministic, scale the
  existing eye parts rather than rebuilding the expression, and are overridden
  to fully open during a contact action.

`PlayerActor3D.set_pose()` applies these values only after event metadata has
selected the action; none of the resolvers writes simulation position, contact,
ball flight, or outcome. `MatchScreen._action_context()` supplies the already
published `serve_style`, `back_set`, and `attack_type`, so playback contains no
second tactical classifier.

The executable evidence is `tests/rally_action_animation_contract.gd` plus the
deterministic side and three-quarter strips produced by
`tools/animation_frames.tscn` in `artifacts/rally-action-animations/`. Each row
uses one fixed physical profile, palette, player ID, camera, and light rig; only
the authored phase or documented input changes between frames.

## Corrective pass: continuous launch and overhead contact

This section records the observed defects in the first implementation and is
authoritative over conflicting timing language above.

### Approach into launch

`ApproachBiomechanics` remains the sole owner from phase `-1` through
`SpikeBiomechanics.PLANT_END`. Its directional step, long penultimate, closing
step, bilateral plant, arm gather, and forward trunk load must be reused without
variant-specific substitutes. During that interval the actor's vertical
elevation is exactly zero.

At `PLANT_END`, both feet are planted and the knees are at maximum load. The
launch then belongs to `SpikeBiomechanics`: knees and hips extend first, the
body rises continuously from zero, the arms lift out of the existing backswing,
and peak elevation occurs at phase zero. No gallery or playback path may drive
an independent sine jump over the approach.

### Overhead striking path

The striking hand must travel in an arc, not translate horizontally into the
ball. From high-elbow cock to contact:

- shoulder drive begins early enough to occupy at least four 60 fps frames on
  the published 0.18--0.25 second takeoff-to-contact clock;
- elbow extension starts after the shoulder but overlaps it through contact;
- shoulder pitch, elbow extension, and the elbow plane's internal rotation
  carry the hand upward, forward, and inward around the shoulder;
- angular velocity is continuous through phase zero; contact is not a clamped
  endpoint followed by a separately eased follow-through;
- the hand continues down and across after contact, then decelerates before the
  landing recovery begins.

The contact hand must be above, ahead of, and outside the striking shoulder,
with positive forward travel and a visible vertical component in the final
pre-contact samples. Late recovery must not exceed contact hand speed.

### Dink contact

A dink shares the canonical approach, plant, launch, guide-arm sell, and early
high-elbow cock. Its late change keeps the elbow flexed but carries the upper arm
past vertical so the hand reaches in front of the striking shoulder. The hand
stops near the ball and withdraws; a compact elbow attached to an arm still
behind the head is not a dink.

### Diving floor handoff

The dive overlay may supply pre-contact forward travel, centre-of-mass
commitment, and torso pitch. It must run before the shared floor settlement or
fade its vertical offset before settlement. `PlayerActor3D`'s existing recovery
grounding remains the sole final authority: after every rendered phase the
lowest body surface is on or above the court, and phase `+1` returns a coherent
kneel/ready handoff without buried limbs.

### Corrective acceptance measurements

- attack elevation is zero for every phase below `PLANT_END` and increases only
  after the canonical close has planted;
- approach joint values at the handoff equal the legacy/currently wired
  `ApproachBiomechanics.resolve(1.0, handedness)` values;
- shoulder and elbow angular velocity immediately before and after contact do
  not contain the former order-of-magnitude brake;
- dense world-space hand samples show an overhead arc rather than a final
  horizontal shove;
- dink contact places the striking hand ahead of its shoulder while retaining a
  more flexed elbow than power or roll;
- the dive's lowest body point never falls below the rendered floor;
- visual strips include an exact phase-zero frame and separately identify the
  approach, plant, launch, contact, and landing samples.

## Vocabulary expansion: contacts made while arriving or under pressure

This pass expands presentation vocabulary only. The event, contact phase,
contact height, trajectory, reach verdict, posture, recovery, attack label, and
block participation remain inputs. None of the motions below can create a touch
or reinterpret an outcome.

### Shared arrival-to-contact handoff

An action begins from the locomotion state already on the rig. The active foot,
stride phase, body heading, and carried momentum are not reset when preparation
starts.

- Eyes and head acquire the ball first. Upper-body preparation may begin while
  the lower body is still finishing a shuffle, crossover, or running step.
- An early arrival decelerates through small adjustment steps, establishes its
  base, and then performs the ordinary contact chain.
- A late arrival retains the active stride longer. Its final support foot plants
  during preparation and the other leg finishes travelling through contact or
  the first part of follow-through.
- Platform or setting-hand assembly progresses independently of the lower-body
  settle. The apparatus may be ready before the feet are quiet, but the feet may
  not teleport into a canonical stance.
- Recovery inherits the last support and momentum. It may gather into ready,
  continue into coverage, or absorb a landing; it may not return through a
  neutral pose that the action never occupied.

The shared arrival resolver supplies only blend weights and active-step carry.
Existing gait owns stride geometry; the contact-family resolver owns the final
biomechanical shape.

### Reception and bump pressure variants

**Settled bump:** the final adjustment step finishes before the platform is
still. Knees drive under quiet forearms and the body rises toward the target.

**Moving / late bump:** the active support leg remains visible through platform
assembly. The trailing leg is still finishing the stride at contact, the torso
counterbalances the carried momentum, and recovery resolves the unequal stance
rather than snapping both feet square.

**Reaching bump:** the last support leg lengthens into a lunge while the far
shoulder and arm chase the near arm to preserve one platform. Contact remains at
phase zero; the continued reach and fall are consequences of arriving extended.

**Strained / off-balance pass:** platform geometry remains the published one,
but the body pays for residual alignment with trunk counter-rotation, unequal
support, and a slower balance recovery. Strain must not be represented by an arm
swing, bent platform elbows, or a new ball path.

### Sets while moving

The hands gather on their existing timeline while the live stride continues
beneath them. At low arrival speed the split stance is established early. At
higher speed the active step fades progressively into the target split, and the
setter can contact while the trailing foot is still completing its placement.
The leg drive then absorbs that carried step into the normal extension. Front,
back, standing, jump, and underhand set identities remain unchanged.

### Compromised attack variants

All variants retain the canonical approach, plant, launch, and phase-zero
contact. They alter only how the airborne body organizes around an already
resolved poor contact.

- **Reaching adjustment:** the hitting shoulder and hand lengthen toward the
  ball, the guide arm opens for counterbalance, and the torso/legs oppose the
  reach so the body does not rotate as one rigid piece.
- **Mistimed / cramped attack:** the elbow remains more flexed, trunk snap and
  shoulder carry are reduced, and the legs organize for an earlier asymmetric
  landing. The motion still continues through phase zero.
- **Missed swing adjustment:** the arm follows the attempted overhead arc, then
  the torso and guide arm recover the unspent rotation. It does not add contact
  follow-through or imply the ball was touched.

### Block response variants

Every response begins from the existing read, close, load, drive, and press.

- **Hard impact absorbed:** hands give minimally after phase zero, elbows and
  shoulders yield together without collapsing the wall, the torso recoils, and
  the knees prepare a deeper two-foot absorption.
- **Tooled / deflected:** the contacted hand yields and turns on the deflection
  side while the opposite hand remains structurally high. The torso
  counter-rotates after the ball has left; the response never redirects it.
- **Late / beaten block:** the reach stays incomplete or one-sided according to
  the already supplied arm participation. The blocker continues upward, then
  withdraws and lands from that asymmetry instead of displaying a successful
  sealed-wall hold.

### Expanded acceptance

- the active stride foot is the same immediately before and during preparation;
- increasing arrival speed delays lower-body settlement without delaying the
  authoritative upper-body contact;
- platform and set hands reach contact geometry continuously from locomotion;
- no arrival variant changes root court position or contact phase;
- compromised attacks preserve the canonical approach values;
- block impact, tool, and beaten responses share the same pre-contact wall and
  diverge only at/after contact;
- side and three-quarter strips expose support, lateral travel, front/back limb
  separation, contact, and recovery for each added family.
