# Regional player generation and tactical play

Status: **design direction; partially implemented**

This document separates two systems that should reinforce one another at world
scale without becoming the same system:

1. **Regional player generation** describes what kinds of individual volis a
   place tends to develop.
2. **Regional tactical play** describes the choices teams from that place tend
   to make with whichever volis are currently on their roster.

Regional strength is a third, derived result. It belongs in
[REGIONAL_STRENGTH_AND_MINOR_REGIONS.md](REGIONAL_STRENGTH_AND_MINOR_REGIONS.md),
not in either identity layer here. A region may produce distinctive players,
play a distinctive system, and still be stronger or weaker in a particular
generation because of its depth and talent distribution.

---

## 1. The separation is load-bearing

A Xérvyan and a Taktikãn can have the same height, mass, wingspan, body type,
position and overall potential while having different skill profiles. The
Xérvyan is more likely to have the serving technique, placement and variation
to apply pressure personally. The Taktikãn is more likely to have the decision
making, composure and adaptability to preserve execution while the situation
changes.

That does **not** require every Xérvyan club to serve recklessly or every
Taktikãn club to play slowly. Those are team decisions. A Taktikãn manager may
build an aggressive serving system; the roster's regional education changes
how well its players can execute it, not whether the manager is allowed to
choose it.

The ownership rule is:

| Layer | Attached to | Persists after transfer? | Changes during a match? |
| --- | --- | --- | --- |
| Development origin | `player.home_region` | Yes | No |
| Club/tactical culture | team and `player.club_region` | No; adapts over time | The plan can; familiarity cannot instantly |
| Competitive strength | population and results | Recomputed | Expressed through outcomes |

This produces useful stories. A Pāwan libero remains a Pāwan-developed player
after signing for Spëddigh, but learns to operate inside Spëddigh's faster,
more variable system. An imported Xérvyan server gives a Taktikãn team a weapon;
the import does not turn the whole team into Xérvu.

---

## 2. Current implementation audit

### Player generation: the skill-profile layer is real

`VolleyballPlayerGenerator` currently composes four independent inputs:

- a position lean;
- general talent and individual deviation;
- regional skill specialties and small regional physique offsets;
- a body type drawn uniformly in every region.

This is directionally correct. `REGION_SPECIALTY` makes similarly built players
from Xérvu and Taktikã proficient at different things, and the flat body-type
draw prevents regional culture from becoming regional morphology.

World generation also has `REGION_POSITION_AFFINITY`, which tilts how often
each region produces each position without deleting any position. This is the
correct kind of soft constraint, but its current values contradict two desired
examples:

- Pāwa Hitō currently suppresses liberos (`0.6` affinity).
- Spëddigh currently suppresses opposites (`0.7` affinity).

More importantly, frequency and quality are presently too easy to confuse.
Position affinity answers **how many** players enter a role. Regional specialty
answers **what skills they carry**. Neither explicitly answers whether a
region's tradition is unusually good at turning its skill cluster into a
particular positional archetype.

The fixed `generate_roster()` path is different again: it always emits the
same legal ten-player positional template. Its regions differ in player
attributes, not in positional supply. Population-level identity therefore
exists only when callers use the world-population path.

### Tactical play: authored, but not wired to regional opponents

`VolleyballRegions.REGIONAL_PRINCIPLES` already describes seven tactical axes
for every Sixnet region. The live rally simulator consumes those axes, so the
system can distinguish, for example:

- Spëddigh's tempo variation from Pāwa Hitō's repeated transition commitment;
- Xérvu's serve aggression from Bloc du Larg's block commitment;
- Ispayk's terminal pin focus from Taktikã's composed, less expressive play.

The career uses regional principles to calculate the managed roster's starting
alignment, familiarity and cohesion. That is valuable friction: choosing a
non-local system is legal but takes time to execute.

The missing link is the opponent. Player-facing career fixtures currently seed
the same hand-authored Port Azure roster, whose opponent identity defaults to
`Balanced`. Fixture names and regions do not yet construct a regional roster or
apply `preferred_principles(region)`. The authored tactical identities therefore
exist as data but are not presently palpable as regional opponents.

### Current verdict

The project has most of the right ingredients, but not yet the complete causal
chain:

```text
home region -> individual development profile -> selected club roster
club region -> inherited tactical principles -> decisions in live rallies
roster skills x tactical decisions x familiarity -> execution and results
```

At present the first arrow works for generated players, regional positional
supply works only in world population, and the opponent-facing part of the
second arrow is disconnected.

---

## 3. Generation should create possibilities, not regional job locks

Every region must produce every position and every body type. Regional identity
should change distributions and archetypes, never impose eligibility.

Three separate dials are required:

### A. Skill-cluster lean: what the player learned

Keep regional specialties attached to `home_region`. They should redistribute
a fixed development budget or shape ceilings rather than simply make every
specialized region stronger. Equal-potential comparisons must remain possible.

### B. Position frequency: what local programs commonly train

Keep position affinity as a mild, normalized population tilt. It exists to give
the transfer market and regional depth different shapes, not to declare that a
region cannot develop a role.

The major-region range should usually be narrow enough that every generation
contains credible depth at every position. Extreme affinities belong mainly to
minor-region stories whose deliberate weakness is inability to field a complete
elite seven.

### C. Position conversion: how a regional skill cluster manifests in a role

Add an explicit **regional role expression** concept. This does not add talent.
It describes which role archetypes naturally emerge when regional training is
combined with positional education.

Examples:

- **Pāwa Hitō libero:** stamina, transition speed and repeated-effort training
  produce a defender who recovers quickly, covers again and remains effective
  late in long rallies. This need not make Pāwa a libero-heavy region.
- **Spëddigh opposite:** acceleration, work rate and tempo control produce an
  opposite who releases rapidly, attacks in transition and stays available as
  the rally changes. This need not be the largest or most terminal opposite.
- **Xérvyan setter:** the serving tradition still appears in rotations at the
  line, while toss discipline and variation can support precise distribution;
  the player is not forced to become a pin server simply because of origin.
- **Taktikãn outside hitter:** composure and decision making create stable shot
  selection against changing blocks, even when their build resembles the
  Xérvyan outside across the net.

Initially this can be a design/test matrix rather than another additive bonus
table. If the existing specialty-plus-role composition already produces the
archetype, no new modifier is justified. Add a mechanic only where measured
generation fails the desired expression.

The immediate correction is to remove the accidental claim that Pāwa does not
produce liberos and Spëddigh does not produce opposites. Their affinities should
be neutral or mildly positive for those roles; their distinctiveness should
come primarily from the kind of libero or opposite they produce.

---

## 4. Tactical traditions are defaults, not biological destiny

Regional tactics belong to clubs and institutions, not to player birth.

For generated regional opponents:

1. Select or generate players independently using their `home_region`.
2. Assemble the club roster using `club_region`, finances, prestige and transfer
   behavior. A wealthy A'ace club should often be multinational.
3. Start the club from `preferred_principles(club_region)` unless that club has
   its own authored identity.
4. Give players familiarity based on time and training within that system, not
   on whether their birthplace matches it.
5. Let managers depart from the tradition, paying only the existing alignment,
   familiarity and cohesion costs.

This is especially important for A'ace and Ispayk. Their player supply and their
club play cannot be represented by one regional bonus package:

- A'ace's identity is acquisition and resources. Its clubs should be strong
  because they assemble high-capability rosters and can support an ambitious
  system, not because every A'aceni child receives universal glamour bonuses.
- Ispayk's identity combines a large-frame attacking tradition with a fallen
  flagship's roster economics. The former belongs to player development; the
  latter belongs to club recruitment and age distribution; its direct style
  belongs to tactics.

---

## 5. Draft regional expression matrix

Every major region should be describable with four different sentences:

1. **Education:** what an equal-talent player is more likely to do well because
   they developed there.
2. **Supply:** which positional archetypes the development system produces in
   unusual depth, without excluding any role.
3. **System:** what a locally traditional club repeatedly asks its six on court
   to do.
4. **Evidence:** what the opposing manager can actually observe in decisions,
   movement and rally results.

If education and system are the same sentence, the design is unfinished. “They
produce good servers and therefore serve well” only describes capability. A
complete identity says what kind of servers they produce, how the team deploys
them, what the choice risks, and how the opponent can respond.

### Landavol — breadth without a prescribed answer

- **Education:** low regional distortion. Landavolan players should be the
  clearest expression of position, body type, individual talent and coaching,
  rather than receiving an “all-rounder” bonus that makes them universally
  better.
- **Supply:** a stable, ordinary positional distribution with credible depth
  everywhere and fewer extreme regional archetypes.
- **System:** diagnose the roster and opponent, then use the least costly
  answer. Neutral principles are permission to adapt, not permission to have no
  behavior.
- **Evidence:** fewer repeated extremes across a match; changes in serve target,
  tempo or block plan should follow evidence from earlier rallies.
- **Failure mode:** statistically average play with no adaptation. That is an
  absence of identity, not balance.

### Spëddigh — make the next action arrive early

- **Education:** work rate, acceleration, lateral movement, tempo control and
  balance while moving. Its players should regain availability quickly rather
  than simply hit harder.
- **Supply:** setters, mobile pins and liberos are natural expressions, but the
  tradition must also produce strong transition opposites: rapid-release
  attackers who remain usable as rally geometry changes.
- **System:** change tempo frequently, release early and keep all phases moving.
  The opponent should have less time to settle into a read even when the ball
  is not perfectly controlled.
- **Evidence:** varied set tempos, earlier approach starts, more attackers
  becoming available in transition and shorter pauses between defended ball and
  organized counterattack.
- **Failure mode:** “Pāwa, only faster.” Spëddigh owns variation and early
  availability; it does not need to own the greatest repeated-effort endurance.

### Pāwa Hitō — make one more complete attack

- **Education:** stamina, explosiveness, approach timing, attack accuracy and
  transition recovery. The specialty is repeatable quality, not merely energy.
- **Supply:** transition pins and mobile middles remain common, while Pāwan
  liberos should be especially credible continuation defenders: recover after
  the first dig, cover the next contact and preserve quality late in a rally.
- **System:** use relatively legible attacking patterns but recommit harder and
  more reliably than the opponent after every defensive contact.
- **Evidence:** attackers repeatedly return to approach lanes, coverage survives
  second and third transitions, and attack quality degrades more slowly across
  long rallies and late sets.
- **Failure mode:** generic high stamina. The match must show what the extra
  stamina buys: another organized swing rather than another desperate contact.

### Bloc du Larg — make the hitter declare first

- **Education:** block timing, reach, court vision and tactical discipline.
  Individually, Largen blockers should arrive with control and retain useful
  hands rather than jumping at every possible cue.
- **Supply:** strong middle depth is expected, but disciplined blocking outsides
  and setters should also carry the tradition into non-middle rotations.
- **System:** show patience before committing, close the most consequential
  lane, and trade speculative pressure for a better formed block.
- **Evidence:** later commitment, fewer obviously false jumps, more completed
  block shapes, controlled touches and funnels into positioned defenders.
- **Failure mode:** the highest block-attempt count. Bloc du Larg should be
  distinguished by the quality and timing of commitment, not constant jumping.

### Xérvu — make first contact begin under a false assumption

- **Education:** serve power, technique, placement, consistency, aggression and
  variation. Xérvyan players should possess more usable serve options, not one
  mandatory maximum-power serve.
- **Supply:** serving value can emerge at every position. Pins may be common,
  but a Xérvyan setter or libero rotation should still visibly change the
  pressure applied from the line.
- **System:** attack receivers' expectations across rotations: establish a toss
  or target pattern, depart from it deliberately, and accept calculated errors
  for damaged first contacts.
- **Evidence:** broader serve selection, purposeful target sequences, more
  receiver displacement, aces and errors, and more opponent offense beginning
  away from its preferred setting point.
- **Failure mode:** permanent full aggression. Without sequencing and variation,
  Xérvu is only a serve-power bonus rather than a serving culture.

### Taktikã — preserve the decision while the situation changes

- **Education:** decision making, composure, discipline, adaptability and
  controlled unpredictability. Equal-built Taktikãn players should lose less
  execution quality when reads, score pressure or emotional state change.
- **Supply:** setters and reading defenders are obvious products, but stable
  decision-making must also produce excellent pins: hitters who revise shot and
  pace against a late-changing block.
- **System:** gather information, keep emotional variance low and change the
  chosen solution without changing the team's execution standard.
- **Evidence:** fewer repeated errors after disruption, late shot changes that
  remain controlled, sensible distribution under poor reception and smaller
  performance swings after emotional events.
- **Failure mode:** a passive low-risk team. Composure should protect difficult
  choices, not prevent them.

### Ispayk — end the rally through an acknowledged advantage

- **Education:** large-frame terminal attacking, arm speed, jump reach, block
  timing and shot variety. Ispaykano development creates players who can win a
  known confrontation, not only surprise an opponent.
- **Supply:** terminal pins and physical net players, complicated by the fallen
  flagship's tendency to retain or recruit veterans. Body type remains uniform;
  the physique bias and volleyball education create the frame distribution.
- **System:** concentrate responsibility in the strongest pin matchup, commit
  forcefully at the net and dare the opponent to stop a visible plan.
- **Evidence:** high pin share, repeat sets to a winning hitter, high terminal
  contact and block pressure, with greater exposure when that first plan stalls.
- **Failure mode:** “everyone is stronger.” Its leverage should be concentrated,
  scouted and counterable through matchup denial and rally extension.

### A'ace — purchase several answers and demand immediate return

- **Education:** A'ace should have little or no singular native training
  specialty. Excellent facilities may raise floors or accelerate development,
  but they must not manufacture three unrelated glamour skills in every local
  player for free.
- **Supply:** the club roster, not the birth population, is the signature:
  expensive stars imported from several traditions, strong positional coverage
  and less shared developmental history.
- **System:** select ambitious solutions based on the stars currently on court,
  applying pressure across serve, pin attack and block without waiting years to
  build a single inherited style.
- **Evidence:** several individually elite weapons, substitutions or rotations
  that change the mode of attack, high immediate ceiling, and occasional
  coordination costs when those weapons must improvise together.
- **Failure mode:** a tactic with every aggressive axis simply above average.
  That has no decision or counter. A'ace should gain optionality from roster
  construction and pay for it in integration, not receive a universal tactical
  multiplier.

### What the matrix implies for the current data

This is a draft target, not a claim that the implementation already expresses
every row. It identifies four immediate data questions for calibration:

1. Raise Pāwa Hitō libero and Spëddigh opposite positional affinities toward at
   least neutral, then test the resulting archetypes rather than assuming that
   increased headcount proves quality.
2. Decide whether Landavol's lack of specialty produces observable adaptability
   or merely absence. Adaptation belongs in team decisions, not in free player
   attribute points.
3. Remove or reinterpret A'ace's native `attack_power`, `serve_power` and
   `block_timing` package. Those attributes currently encode purchased roster
   strength as a birthplace trait.
4. Give A'ace tactical tradeoffs. Its current regional principles sit above
   neutral on almost every aggressive axis, so it risks becoming “good at all
   choices” rather than a high-capability roster whose integration can be
   attacked.

---

## 6. Observation contract

Regional identity should be visible without exposing raw bonuses. Scouting and
playback can express it at three levels:

- **Before the match:** describe roster evidence separately from club habits.
  “Three Xérvyan servers” is capability; “targets seams after establishing line”
  is observed tactical behavior.
- **During the rally:** cognition, movement and choices should expose intent.
  The opponent sees Bloc wait before committing, Spëddigh release early, Pāwa
  reorganize again and Xérvu alter a previously established serve pattern.
- **After a sample:** aggregate reports should name evidence, not stereotypes:
  tempo distribution, repeated-transition availability, serve sequence entropy,
  block commitment timing and execution variance under pressure.

A useful scouting sentence follows this grammar:

> **They can** [roster capability], **they prefer** [team decision], **so we
> observe** [measured rally signature], **and we can answer by** [counter].

Examples:

- “They can serve six credible variations, they prefer changing the receiver's
  starting assumption, so we observe late movement and more out-of-system sets;
  we can answer by simplifying seam ownership.”
- “They can rebuild approaches repeatedly, they prefer recommitting after every
  dig, so we observe third-transition swings that remain organized; we can
  answer by ending continuation with disciplined tooling coverage rather than
  trying to outlast them.”

This phrasing stops regional identity from becoming immutable flavor text. It
always points to something the simulation must produce and something the player
can contest.

---

## 7. Required regional tests

Regional balance cannot be signed off from one scalar power score. Generation
and play need separate tests before being tested together.

### Generation tests

For each region, generate a large equal-talent cohort with controlled age,
position and body type, then report:

- attribute deltas by role against the world baseline;
- positional frequency and best-seven depth;
- body-type frequency, which must remain equal across regions;
- archetype checks such as Pāwan libero continuation and Spëddigh opposite
  transition value;
- equal-potential conservation, so identity does not silently become strength.

The important comparison is often paired: the same role, body type and talent
from two regions. That isolates learned skill from physique and roster quality.

### Tactical tests

Give every regional principle set the **same neutral roster** and simulate live
rallies. Measure the decisions and visible match fingerprints:

- serve risk, ace and error rate;
- attack distribution and pin focus;
- chosen tempo and tempo variation;
- transition release and conversion;
- block commitment, touches and tools conceded;
- rally length, continuation rate and emotional volatility.

This proves that tactics themselves create differences rather than borrowing
them from roster attributes.

### Combined matchup tests

Finally combine native, imported and mixed rosters with regional tactics. The
acceptance target is not a perfectly circular win-rate table. It is:

- similarly strong regions have comparable overall pull across many opponents;
- their advantages occur through different rally events;
- roster-system fit matters without overpowering raw capability;
- imports retain individual identity while gradually learning club tactics;
- a viewer can often infer the opponent's tactical tradition after 20-30
  rallies, but cannot infer every player's birthplace from body or position.

These tests also expose whether a regional attribute is too rarely used to buy
its share of the specialty budget. If a supposed strength does not move a
decision, execution margin or observable rally statistic, it is flavor rather
than balance weight.

---

## 8. Implementation order

1. Wire career fixtures to a real opponent definition containing club region,
   roster source and principles.
2. Apply `preferred_principles(club_region)` to region-authored opponents and
   preserve club-specific overrides.
3. Revisit major-region position affinities, beginning with Pāwa libero and
   Spëddigh opposite, without changing the uniform body-type rule.
4. Add controlled generation reports that separate skill, body, position and
   talent effects.
5. Extend the live identity calibration to all regional principle sets using a
   shared neutral roster.
6. Run combined regional matchups only after both isolated layers pass.

Do not tune regional win rates before this separation exists. Otherwise a weak
tactical identity may be disguised by stronger generated players, or a weak
generation package may be compensated by an overly powerful tactic, leaving
both systems individually wrong.
