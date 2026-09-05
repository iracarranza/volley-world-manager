# Voli animation aesthetic direction

Status: presentation authority for how biomechanically correct volleyball motion is stylized, clarified, and given Voli character.

This document sits **beside** `RALLY_ACTION_ANIMATION_CHOREOGRAPHY.md`, not above it.

- `RALLY_ACTION_ANIMATION_CHOREOGRAPHY.md` owns volleyball biomechanics, contact sequencing, support, launch, recovery, and the requirement that playback never rewrite simulation truth.
- This document owns **readability, timing emphasis, silhouette, inertia, attention, transitions, and character tone** once those biomechanical constraints are satisfied.

The target is:

> **cool, clean, polished volleyball performed by cozy, toy-like Volis.**

The animation must never become cute at the expense of volleyball credibility, and it must never become clinically realistic at the expense of clarity or character.

---

## 1. Core principle: preserve the physics, exaggerate the idea

Biomechanical correctness is the **skeleton, not the finished aesthetic**.

A real player can communicate motion through subtle scapular movement, finger articulation, spinal detail, foot pressure, muscle tension, and facial micro-expression. The Voli rig cannot depend on all of those cues at match-view scale.

Therefore the animation may selectively exaggerate the **important physical idea** of a movement while preserving its actual support, sequencing, contact geometry, and momentum.

Examples:

- a jump topspin serve may emphasize the compression of the plant, the release into launch, the suspended reach, and the late whip;
- a float serve may emphasize compact preparation, a short rise, a firm punch, and an abrupt arrest;
- a dink may emphasize the full-swing sell followed by a tiny late interruption;
- a block may emphasize low load, sudden vertical wall, and compact absorption on landing;
- a reception may emphasize the read, final stride, platform formation, and controlled rebound.

Stylization must make the underlying biomechanics easier to read. It must not replace them.

---

## 2. Three animation laws

### 2.1 Volleyball is precise

Contacts, support, momentum, timing, and sequencing must remain recognizable as real volleyball.

Do not distort technique merely to make a pose cuter, larger, or more dramatic.

The following remain non-negotiable:

- grounded actions preserve believable foot support;
- jumping actions load, launch, contact, and land continuously;
- striking chains remain proximal-to-distal;
- contact occurs at the simulator-authored phase and height;
- follow-through carries momentum through contact instead of freezing;
- floor recoveries stay grounded and hand off coherently to the next stance;
- tactical variants remain distinct through actual volleyball mechanics rather than arbitrary pose changes.

### 2.2 Volis have mass

Motion must not propagate through the whole rig simultaneously.

The body should read as a compact toy-like object with mass, softness, and inertia:

- the torso and pelvis carry most of the visible mass;
- support legs commit decisively;
- the head may lag or settle slightly after large body motion;
- hands may trail or finish after the torso has already begun to settle;
- landings produce a small whole-body compression after correct ankle-knee-hip absorption;
- direction changes require visible commitment before reversal;
- recovery poses should settle rather than snap into place;
- attached body-type anatomy should participate naturally in the same acceleration, inertia, and settle where the rig permits it.

This does **not** mean rubbery motion, squash-and-stretch that changes anatomy, or loose joints. The toy quality comes from timing, inertia, softness, and recovery — not incompetence.

A tail following a landing, a hanging ear lagging a head turn, feathers settling after a jump, or a Vegi crown carrying a little residual motion are part of this physical-performance layer. They are not a separate character-animation phase.

### 2.3 Volis are attentive

Whenever the rally clock permits it, perception should visibly precede action.

The preferred order is:

> **eyes -> head -> torso -> feet/body -> contact apparatus**

Examples:

- a receiver acquires the ball with eyes/head before committing the sternum and feet;
- a blocker reads the setter/hitter before closing and loading;
- a setter checks the pass before establishing the second-contact solution;
- a defender tracks the outgoing ball before beginning recovery.

Attention is one of the main ways a procedural Voli stops reading as a simulation puppet and begins reading as a character. Eyes may therefore be disproportionately important to the finished aesthetic: a small gaze change can establish perception and intention before the larger body motion arrives.

Full blinks remain suppressed around contact as defined by the biomechanics/choreography authority.

---

## 3. Aesthetic hierarchy

When animation goals conflict, resolve them in this order:

1. **simulation truth** — event, timing, contact, ball path, outcome;
2. **volleyball biomechanics** — support, sequencing, launch, contact geometry, recovery;
3. **action clarity** — readable silhouette and unmistakable action identity;
4. **continuity** — believable handoff from the previous and into the next action;
5. **timing polish** — anticipation, acceleration, deceleration, holds, and settle;
6. **Voli character** — inertia, attention, body-specific behavior, restrained personality;
7. **decorative flourish** — only when it does not weaken any layer above.

A polished animation that violates the first two layers is wrong. A biomechanically correct animation that fails layers three through six is unfinished.

---

## 4. Key-pose clarity

Every important action should be readable from a small set of graphic anchor poses.

The standard sequence is:

1. **anticipation** — what is about to happen;
2. **load** — where energy is stored or commitment becomes irreversible;
3. **launch / commit** — where the body begins the action proper;
4. **contact** — the authored volleyball event;
5. **follow-through** — where momentum proves contact was not a freeze-frame;
6. **recovery / handoff** — how the actor returns to useful volleyball posture.

Not every action needs six equally strong poses, but every action must expose enough of these anchors to remain readable at match-view scale.

### Silhouette rule

A major action should survive a flat-silhouette test.

With the Voli rendered as a single dark shape, the viewer should still be able to distinguish, where relevant:

- jump topspin from jump float;
- standing serve from sky ball;
- front set from back set;
- power swing from roll shot from dink;
- standing reception from diving reception;
- ready stance from idle;
- block load from attack load;
- landing/recovery from an unfinished contact pose.

If the distinction depends on a subtle elbow angle visible only in close-up, the action is not yet clear enough for match view.

---

## 5. Timing direction: cool comes from rhythm and commitment

The game should not rely on flashy secondary effects to make volleyball feel exciting. The sport itself supplies the spectacle when motion is timed well.

Each action should have a recognizable rhythmic identity.

### Reference rhythms

- **jump topspin:** travel -> coil -> release -> whip -> carry -> absorb
- **jump float:** compact gather -> rise -> punch -> arrest -> absorb
- **standing serve:** settle -> toss -> transfer -> strike -> step-in
- **sky ball:** rock -> low toss -> upward sweep -> high finish
- **power attack:** approach -> penultimate -> plant -> launch -> late whip -> carry -> land
- **roll shot:** same sell as power -> late deceleration -> smooth contact -> relaxed carry
- **dink/tip:** same sell as power -> compact interruption -> touch -> withdraw
- **block:** read -> close -> load -> vertical wall -> press -> absorb
- **reception:** read -> move -> final stride -> platform -> rebound -> recover
- **dive:** read -> commit -> push -> flight -> platform/contact -> floor handoff
- **set:** arrive -> establish base -> load -> contact -> extension -> release

The exact simulator timing remains authoritative. Presentation may redistribute emphasis inside that available clock, but must not move phase zero or invent extra tactical delay.

### Acceleration rule

The viewer should feel where force enters and leaves the system.

Avoid:

- constant-speed interpolation between poses;
- simultaneous movement of every joint;
- abrupt braking at contact;
- follow-through that begins as a new animation after phase zero;
- identical easing for every action.

Prefer:

- visible loading before explosive release;
- late acceleration for striking limbs;
- continuous angular velocity through contact;
- restrained overshoot or settle after large motions;
- action-specific deceleration patterns.

The desired form of “cool” is therefore mostly **rhythm and commitment**: quiet preparation, decisive commitment, sharp contact, and clean continuation.

---

## 6. Toy-like body language without incompetence

The desired tone is not “cute volleyball.” It is:

> **elite volleyball performed by bodies with charming physical properties.**

During live contacts, volleyball precision wins.

Toy-like character should appear primarily through:

- compact whole-body inertia;
- slight head and hand lag;
- gentle post-landing settle;
- soft breathing and weight transfer;
- readable gaze and attention;
- restrained recovery gestures;
- natural secondary response from attached anatomy where applicable.

Do not make elite players look clumsy, floppy, surprised by routine actions, or unable to control their own momentum.

### Landing example

A correct landing still uses ankle-knee-hip absorption. The Voli performance layer may add:

- a small visible compression of the whole body after foot contact;
- a fractionally delayed head settle;
- hands finishing their arc after the torso begins to stabilize;
- attached ears, tails, feathers, crowns, or stalks carrying and settling residual motion where appropriate;
- a clean return toward the next stance.

The result should feel soft and object-like without becoming rubbery.

---

## 7. Attention and gaze system

Eyes and head are high-value animation channels because they remain legible even when limb detail is small.

### Rules

- gaze should target rally-relevant information when known;
- eyes may lead the head by a small amount;
- the head may lead the torso when reaction time allows;
- contact actions should not show visible blinking through the ball;
- post-contact gaze should usually follow the ball or next tactical responsibility;
- gaze motion should remain bounded and deterministic during replay.

### Reception clarity

A reception should never read as:

> ball travels to a predetermined point -> receiver suddenly displays a dig pose.

It should read as:

> ball leaves attacker -> receiver acquires line -> body commits -> feet/path resolve -> platform forms -> contact occurs.

The simulation may already know the destination. Presentation must make the Voli appear to discover and respond to that information through believable attention and movement.

---

## 8. Baseline life is not the cozy-character pass

Several quiet presentation behaviors belong to the general living-body and volleyball-performance foundation rather than to body-specific character animation.

The current presentation system already has foundations for:

- breathing and slow weight sway;
- small arm lag tied to idle motion;
- blinking and pupil motion;
- head/gaze behavior during rally playback;
- stance settling and transitions;
- small deterministic pre-serve routine variation.

These systems should continue to be refined where necessary, but they should not be counted as the new body-specific “cozy behavior” feature. Mid-rally head tracking in particular is volleyball perception and readability, not decorative character acting.

The character layer begins when a Voli uses or attends to anatomy that is distinctive to its body type.

### Body-specific character behavior

These behaviors belong primarily in genuinely safe dead-ball or waiting windows. They should be **rare, interruptible, and subordinate to volleyball information**.

Current direction:

- **Vegi:** tend or straighten a crown, stalk, leaf, calyx, or similar produce anatomy;
- **Feli:** groom the face or head with a hand/paw;
- **Cani:** shake off with the head or whole body, allowing hanging ears and tail to follow;
- **Avi:** preen/smooth the opposite arm feathers or make a small crest adjustment;
- **Ursi:** a large, slow yawn using the broad muzzle and heavy body settle;
- **Simi:** a long-arm stretch, forearm rub, or shoulder rub that makes use of its unusual proportions.

Prefer **causal or contextual opportunities** over arbitrary idle timers where practical. A dive may leave a Vegi crown needing attention; floor contact may motivate Feli grooming; a long rally may motivate a Cani shake-off; a large Avi movement may leave feathers to be smoothed. Random selection can remain a fallback, but behavior that appears to follow from what just happened will read as more intentional.

Do not fire these gestures merely because an animation slot is available. Constant “cute” motion would flatten the contrast and reduce both coziness and athletic impact.

The intended contrast is:

> **quiet, physically alive Volis -> sudden serious volleyball -> quiet, body-specific character**

### Social and emotional behavior is separate

Point celebrations, disappointment, teammate acknowledgement, high-fives, substitution behavior, and other social acting are a later animation layer. They may eventually make the spaces between rallies much richer, but they are **not required** to complete the body-specific cozy pass and should not expand its scope.

---

## 9. Transition quality is a first-class requirement

A match can contain excellent isolated actions and still feel synthetic if the viewer perceives state changes instead of a continuous rally.

Transitions must therefore receive the same level of scrutiny as headline contacts.

High-priority transitions include:

- idle/ready -> locomotion;
- ready -> shuffle;
- shuffle/run -> reception;
- reception -> recovery/coverage;
- approach -> plant -> launch;
- attack landing -> transition/coverage;
- block landing -> defensive transition;
- set -> cover/defend;
- serve landing -> court entry;
- dive/floor recovery -> kneel -> ready;
- watching -> active defensive stance;
- active stance -> dead-ball relaxation.

### Transition rule

The next action should begin from the actual body state produced by the previous action whenever physically possible.

Avoid resetting to a canonical neutral pose between actions unless the rally contains enough real time for the actor to genuinely return there.

The player should perceive **one rally**, not a queue of animation windows.

---

## 10. Action-family direction

### 10.1 Serves

Serves should feel self-paced and intentional before becoming explosive.

The quiet possession beat is useful preparation space: target check, shoulder settle, ball transfer, small deterministic routine differences. This is part of the action-performance foundation, not the body-specific cozy layer.

Variant identity must then become unmistakable:

- standing = controlled transfer and step-in;
- topspin = longest travel, deepest load, biggest release, longest carry;
- float = compact support, quiet torso, abbreviated strike;
- hybrid = float-like preparation with a later rotational reveal;
- sky ball = grounded underhand sweep with high visual finish.

### 10.2 Reception and defense

Defense should communicate **reading and commitment** before floor contact.

The receiver's center of mass should visibly begin solving the ball before the final platform pose appears.

Dives should feel brave and decisive, not like the actor simply rotates toward the floor. Push precedes fall. Flight precedes settlement. Recovery returns to useful volleyball posture.

### 10.3 Setting

Setting should read as controlled redirection rather than a hand animation attached to a standing body.

The lower body establishes timing first. Hands finish the kinetic chain.

Back sets should preserve disguise: preparation remains visually close to front-set preparation and only separates late through chest opening, crown carry, and weight shift.

### 10.4 Attacking

The shared approach is central to attack deception.

Power, roll, and dink should remain nearly identical through the sell, then diverge late.

The aesthetic difference should come from force handling:

- power accelerates through contact and carries violently but cleanly;
- roll visibly removes force late while preserving a long arm path;
- dink interrupts the whip and replaces it with a compact reach and withdrawal.

### 10.5 Blocking

Blocking should read vertically and structurally.

The Voli closes, plants, compresses, rises into a wall, presses over, then absorbs the return to the floor.

Avoid floaty jumps or static “hands up” poses that lack the preceding load and closing responsibility.

---

## 11. Polish constraints

### Avoid visual noise

Secondary movement must remain subordinate to volleyball information.

During important contacts, reduce or suppress:

- large idle sway;
- unnecessary head bob;
- decorative hand motion;
- expressive blinks;
- deliberate body-specific maintenance gestures;
- personality gestures that compete with the contact silhouette.

Passive physical response of attached anatomy may remain when it follows naturally from the action, but it must not obscure the action.

### Avoid over-animation

Not every body part needs visible motion in every frame.

Stillness is useful when it focuses attention on the moving chain.

### Avoid procedural sameness

Determinism does not require identical rhythm across all players.

Stable per-player variation may affect small pre-action and idle qualities such as:

- possession rhythm;
- stance settle;
- weight-shift phase;
- head/gaze responsiveness;
- breathing phase;
- minor hand/arm lag;
- frequency or variant of eligible body-specific maintenance behavior.

These variations must not alter phase zero, action identity, tactical outcome, or biomechanical class.

---

## 12. Acceptance framework

Animation acceptance should operate on **two parallel tracks**.

### Track A — biomechanical correctness

Owned by `RALLY_ACTION_ANIMATION_CHOREOGRAPHY.md` and its executable contracts.

Questions include:

- are support and contact geometry correct?
- is launch continuous?
- are feet grounded when required?
- does momentum continue through contact?
- is recovery physically coherent?
- are action variants mechanically distinct?

### Track B — aesthetic/readability correctness

Owned by this document.

For every important action, review:

1. **silhouette:** can the action be identified in flat shape?
2. **timing:** is the force/rhythm legible without the ball?
3. **commitment:** does preparation visibly become decisive action rather than merely arriving at a contact pose?
4. **attention:** does the actor appear to perceive before responding where time allows?
5. **mass:** do torso, head, hands, legs, and eligible attached anatomy move with believable sequencing and settle?
6. **transition:** does the action enter from and leave toward plausible neighboring states?
7. **restraint:** are idle/personality overlays subordinate during important volleyball information?
8. **character:** does the actor still feel like a Voli rather than a generic human mannequin?

An action is production-ready only when it passes both tracks.

---

## 13. Visual review artifacts

The existing deterministic frame-strip system remains useful, but aesthetic review should add explicit presentation samples.

For each major action family, retain:

- side view;
- three-quarter view;
- exact phase-zero frame;
- representative anticipation/load frame;
- representative launch/commit frame;
- follow-through frame;
- recovery/handoff frame;
- optional flat-silhouette version for clarity testing.

For transition review, use short continuous clips rather than isolated strips where possible.

Priority clips should include:

- approach -> plant -> launch -> attack -> landing;
- moving reception -> contact -> coverage/recovery;
- block close -> load -> jump -> landing -> transition;
- serve routine -> toss -> contact -> court entry;
- dive commit -> flight/contact -> floor -> kneel/ready;
- idle/watch -> attention -> ready -> locomotion.

Body-specific character review should use separate dead-ball clips so maintenance gestures are not judged by inserting them into rally action strips.

---

## 14. Animation roadmap

Do not continue adding joint-detail realism indefinitely once the corrective biomechanical floor is stable. Biomechanical accuracy supplies the skeleton; the next work is to turn that skeleton into the game's finished animation aesthetic.

### Step 1 — Core Voli performance polish

This is the immediate priority. It is not another biomechanics-completion pass.

Refine the existing volleyball actions in this order of concern:

1. **silhouette and key-pose clarity** — actions must read at match-view scale;
2. **anticipation and commitment** — the body visibly develops toward the action instead of displaying the correct pose only when contact arrives;
3. **rhythm and force timing** — “cool” comes primarily from the cadence of preparation, release, contact, continuation, and absorption;
4. **attention and perception** — eyes/head establish what the Voli is reading before the larger body response where time permits;
5. **toy-like inertia, softness, and recovery** — mass propagates through the body with lag and settle without making the athlete incompetent;
6. **natural secondary response of attached anatomy** — crowns, stalks, hanging ears, tails, feathers, crests, and similar parts participate in the same acceleration and settle where appropriate;
7. **continuous transitions** — the body produced by one action becomes the starting body for the next rather than resetting between animation windows.

Existing breathing, sway, blinking/pupil motion, rally head tracking, stance transitions, and pre-serve routine foundations belong inside or beneath this performance layer. They should be refined rather than reinvented.

### Step 2 — Body-specific character behavior

After the core volleyball performance reads correctly, add the rare, interruptible maintenance behaviors defined in section 8:

- Vegi crown/stalk tending;
- Feli grooming;
- Cani shake-off;
- Avi preening;
- Ursi yawn;
- Simi long-arm stretch/rub.

Prefer contextual opportunities over arbitrary firing. These behaviors should enrich quiet time without becoming the reason the viewer notices that quiet time.

### Step 3 — Social/emotional match behavior

Treat celebrations, disappointment, teammate interactions, substitutions, high-fives, and related social acting as a separate later system.

This layer is valuable, but it is not a dependency for either polished volleyball motion or the body-specific cozy identity.

---

## 15. Definition of the target state

The target is reached when a rally can be watched with minimal UI and still communicate all of the following:

- what volleyball action each player is performing;
- where force is being generated and redirected;
- which player is reading/reacting to which event;
- that contact and recovery belong to one continuous movement;
- that different tactical variants have different physical identities;
- that the actors possess weight, attention, and individual presence;
- that attached anatomy feels physically connected to the moving body rather than rigidly decorative;
- that the match feels clean, committed, and athletic at full speed;
- that safe quiet spaces can reveal restrained, body-specific Voli character without competing with the sport.

The intended overall contrast is:

> **quiet, physically alive Volis -> sudden serious volleyball -> quiet, body-specific character**

The final aesthetic should not look like realistic humans reduced into simplified models. It should look like **Volis who genuinely know how to play volleyball.**