# Signature moves, attack–block–dig scaling, and VFX direction

Status: **design authority / presentation direction**

This file records the settled semantics clarified after the causal rally first draft and the first aura-first SignatureSurge3D render pass. It does **not** replace measured evidence in `ATTACK_DEFENCE_SCALING.md`; it resolves design questions that file deliberately left open and records presentation requirements that should survive later implementation changes.

## 1. Attack → block → dig is ordered, not rock-paper-scissors

The intended confrontation has three layers:

```text
ATTACK
  ↓
BLOCK
  ↓
FLOOR DEFENCE
```

**Attack is the protagonist.** It creates the problem and has the strongest terminal ceiling, but reaching that ceiling is comparatively difficult.

**Block is the antagonist.** An established wall should be involved often enough to feel like a real obstacle. Its success is not limited to stuffs: touches, funnels and partial redirections are legitimate wins in the attack/block confrontation because they change the problem handed to the floor.

**Dig is the third layer.** Floor defence does not need the attack's persevering terminal power or the block's immediate intervention rate. It benefits structurally from a strong block changing velocity, trajectory, time, landing locus and responsibility before the ball reaches the floor defenders.

Therefore the desired relationship is asymmetric:

- poor attack vs established block: attack should usually lose the confrontation;
- roughly equal attack/block quality: block involvement should be common, especially touch/funnel rather than only clean stuff;
- attack quality just above the defensive regime: terminality should begin to climb sharply;
- elite attack quality: terminality can become very high, but entering this regime should itself be difficult;
- superior defence is collective: the wall and floor together create the defensive ceiling, not one claimant receiving a hidden quality bonus.

This **answers the open convexity question in `ATTACK_DEFENCE_SCALING.md`: the asymmetric offensive crest is intentional.** The old measured knee was explicitly the right shape for the wrong reason; future work should make the shape causal rather than preserve the old threshold/noise accident.

Do not implement this intent as a direct `dig_quality += block_bonus` or a final-outcome multiplier. The handoff should arise from the realised block contact and the downstream physical state.

## 2. Signature moves are exceptional actions inside that relationship

Signatures are not generic buffs and should not bypass causal ownership. They alter what action is attempted or what physically extraordinary interaction can occur; ordinary contact physics and realised state still determine the next situation.

All signatures can fail. A gather/charge state must never visually or mechanically guarantee the eventual outcome.

### Block Crush — attack

Power route through a block the attack physically meets.

The hitter drives the ball harder than the established hands can absorb. On success the block contact is not erased: the ball meets the wall and tears through it, continuing downward with substantial retained attack energy.

Fantasy: **the wall could not contain the swing.**

### High Hands — attack

Accuracy route through a block the attack physically meets.

The hitter deliberately finds the outside/top edge of the hands and uses that contact to send the ball high and away. A lucky edge contact from a badly aimed swing is not equivalent to intentionally tooling the hands.

Fantasy: **the hitter solved the wall rather than overpowering it.**

### Monster Block — block

A timing/denial signature.

The exceptional fact is the blocker reaching the attacking contact at the right apex and forming a real hand contact. The move should feel like perfectly timed interception rather than a summoned force field.

Fantasy: **the blocker was exactly there.**

### Foresight — dig / receive

Foresight is pre-contact prediction, not a dig-stability modifier.

Its inputs are primarily the receiver's understanding of the game — especially anticipation — together with current confidence. When actionable, the defender predicts the future endpoint/course **before the attacking or serving contact creates the realised trajectory** and begins moving toward that prediction early.

The read can concern, among other things:

- a seam through or around the block;
- a trajectory expected off the hands;
- the curve of a serve;
- the likely endpoint of a clean spike.

The causal advantage is time:

```text
ordinary defender:
contact → perceive → react → travel → dig

Foresight:
predict → travel → contact → adjust → dig
```

A correct read can therefore produce an innately easier ordinary dig because the defender arrives earlier and has more time to establish posture. **Do not add a Foresight dig-quality bonus to manufacture that advantage.**

Foresight can fail by being inaccurate. The defender has already committed body position before the world resolves:

- expected wipe takes another angle;
- expected wipe becomes a feint or clean swing;
- expected spike is sharper than read;
- serve curve differs from the prediction.

The cost is the resulting positional/body state. If the defender can instantly discard the prediction at contact and react as though they had never moved, Foresight becomes free information and loses its risk.

Fantasy: **“I knew where it was going.”**

### Heroics — dig

Heroics is post-contact emergency reach, driven by explosiveness and work rate rather than early understanding.

Where Foresight buys **time**, Heroics buys **reachable space** after the real problem becomes known. It is for attacks that ordinary defensive reach would treat as effectively untouchable: extreme driven spikes, violent wipes leaving the court, or comparable emergency trajectories.

Two canonical manifestations:

1. **Body absorption.** The defender cannot establish an ordinary platform. They put whatever body they can into the ball, absorb the attack with the whole body, redirect it upward, and may collapse or be physically pushed backward.
2. **Emergency pursuit.** A wipe/deflection leaves ordinary defensive space. The defender chases with exceptional speed and urgency and attempts an emergency return.

Heroics does not guarantee a beautiful ball. Its accomplishment is making an extraordinary contact physically available at all.

Its fail state is unusually narrow and binary. The opportunity window is the tightest of the signatures:

```text
none → forming → committed
```

The signature may begin to form and then be denied because the action window closes before the extraordinary movement can begin. Once committed, the exceptional action occurs; before commitment, a visible ignition is not permission to fabricate a rescue.

Fantasy: **“There was no way they were getting that.”**

## 3. Foresight vs Heroics

Both belong to the defensive family but express opposite solutions.

| | Foresight | Heroics |
|---|---|---|
| Core | anticipation + confidence | explosiveness + work rate |
| Timing | before strike/serve contact | after realised trajectory |
| Advantage | more time | more reachable space |
| Risk | commits to a wrong future | misses the tiny action window |
| Failure | body moves to the wrong answer | extraordinary action never begins |
| Contact | can become an increasingly ordinary dig | intentionally emergency / non-ordinary |
| Replay question | “Why were they already moving?” | “How did they get there?” |

This distinction should remain visible in simulation traces, animation and VFX.

## 4. Signature VFX language

The first aura-first render draft established the correct material direction: **signature energy should read as a temporary state of the air/body, not a tangible object attached to the voli.**

Retire the old visual dependence on toruses, cylinders, cages, rigid spokes, uniform strands and closed wire silhouettes. Shared low-level renderer primitives are fine; generic `precision`/`impact` silhouettes are not a semantic design.

Shared vocabulary:

```text
charge
→ body-local radiance
→ pressure / pulse
→ action-directed energy flow
→ turbulent or vaporous dissipation
```

Prefer:

- soft additive/translucent aura fields;
- overlapping gradients/shells rather than outlined rings;
- breathing/pulsing luminosity;
- irregular tapered tendrils that disappear into air;
- brief pressure waves;
- contact-local bloom;
- wakes aligned with realised action/ball direction where that direction is already authoritative.

Avoid:

- stable closed shapes;
- evenly thick strands;
- symmetric wire constructions;
- floating decorative props;
- pre-contact VFX that reveals or guarantees a result the simulation has not resolved.

## 5. Next VFX refinement after aura draft 1

The aura-first draft solved the dominant “wire / hot-glue arts-and-crafts” failure but slightly overcorrected toward generic glow. Preserve the material language and improve **origin + flow**, not by adding more geometry.

### Block Crush

Current draft: materially softer, but too much reads as a red aura behind the hitter.

Next:

```text
body/core → hitting shoulder/arm → hand/block compression → downward rupture
```

Pull energy toward the striking arm and actual hand/block interaction. On success, compress visibly against the wall before the energy/ball breaks downward. The rupture should follow realised post-block direction where available.

### High Hands

Current draft is the strongest attack silhouette.

Next:

- tighten origin to the striking hand/contact edge;
- narrow the upward/outward peel;
- preserve its relative restraint versus Crush;
- let the wake follow the realised tool direction rather than forming a generic upward flare.

### Foresight

Keep it the least explosive signature. Its primary spectacle is **temporal**, not a large contact flash.

Next:

- body-local calm charge;
- subtle directional field/wisps accompanying the defender's early commitment;
- no projected destination line and no psychic reticle;
- correct vs misread should chiefly be revealed by the later ball diverging from or validating the already-chosen movement.

A still frame can only partially certify this move. A normal-speed or strip render spanning **before attacking contact → defender commitment → realised ball** is the useful review instrument.

### Heroics

Current success/denied distinction is good; successful Heroics still looks too much like an emitted golden flare beside the body.

Next:

- make the whole body enter the energy state;
- pursuit: turbulent wake stretches behind the accelerating body;
- absorption: incoming force compresses the aura around the body, then the aura/body recoil together while the ball escapes upward;
- denied attempt: brief violent ignition → extinction, with no fake rescue animation.

### Monster Block

The aura draft successfully removes the cage. It is now too generic.

Next:

```text
jump/body convergence → both hands → instantaneous broad pressure pulse
```

The defining release should be a short soft pressure plane across the real blocking-hand plane at apex. It must remain atmospheric and immediately lose coherence into glow/tendrils — never bars, hoops or a persistent wall object.

## 6. Certification rules

For future signature work:

- use the actual Godot renderer, `PlayerActor3D`, match lighting/materials and the existing signature render instruments;
- render gather / release / tail for every move;
- retain explicit Foresight misread and Heroics denied review cases;
- add temporal/strip review where the move's fantasy depends on *when* the body moves rather than one contact frame;
- presentation must consume simulation facts and may not manufacture a trajectory, successful result or body action;
- visual intensity is not a balance/calibration control.

The aura-draft implementation remains review work until separately accepted. This document records the accepted direction, not acceptance of any particular draft commit.
