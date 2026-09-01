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
