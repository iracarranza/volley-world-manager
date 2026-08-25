# Design Authority Index

Purpose: reduce drift as the design corpus grows. This is an index, not a replacement for the source documents.

## Core sporting authority

| Subject | Primary design authority |
|---|---|
| Volleyball fidelity standard | `docs/design/VOLLEYBALL_FIDELITY.md` |
| Setter choice / offensive concentration | `docs/design/SETTER_DECISION.md` |
| Tactics, training, familiarity | `docs/design/TACTICS_AND_TRAINING.md` |
| Off-ball movement | `docs/design/OFF_BALL_MOVEMENT.md` |
| Tempo / approach | `docs/design/TEMPO_AND_APPROACH.md` |
| Ball launch | `docs/design/BALL_LAUNCH_KINEMATICS.md` |
| Attack/defense scaling | `docs/design/ATTACK_DEFENCE_SCALING.md` |
| Traits | `docs/design/TRAITS.md` |
| Player-facing style | `docs/design/PLAYER_STYLE_SCOUTING_AND_TRAITS.md` |
| Recruitment scouting | `docs/design/SCOUTING.md` |
| Signature vocabulary | `docs/design/SIGNATURE_VOCABULARY.md` |
| Match-training visual authoring | `docs/design/TRAINING_PLAY_DESIGNER.md` |
| Match presentation / broadcast integration | `docs/implementation/PRESENTATION_INTEGRATION_SPEC.md` |

Implementation evidence does not replace these design authorities. Canonical M9
causal evidence lives under `docs/review/m9_tactical_causality/`; the pre-merge
presentation disposition and resulting authority order live under
`docs/review/presentation_integration/`.

## Management/world authority

Use the dedicated design documents for club/region/roster, day/clock, recruitment/offer, staff/fallibility, accommodations/care, academy proof, SixNet, journal/knowledge and desk/phone. `docs/BACKLOG.md` owns cross-document implementation ordering when a subsystem's own design order conflicts with project-level priority.

## Terminology

### Attribute / rating
A capability quantity. High normally means more competent at the named skill. Do not use for temperament axes where high is not inherently better.

### Trait
Individual behavioral pull, unusual physical fact, or exceptional/restricted capability depending on trait class. Traits can affect what a Voli attempts or how they resolve a decision junction.

### Temperament
Non-ability behavioral axis such as ego/aggression. Do not fold into Overall merely because it is numeric.

### Tactic
Managerial intent. A tactic biases/structures decisions; it does not guarantee physical outcomes.

### Natural system-fit band
Comfort/capability region derived from ratings/body. It is not learned tactical familiarity.

### Learned preference / tactical comfort
What this Voli/pair/slot has learned to execute in this system: coordinates, tempos, loci, postures. Intended to be trainable separately from ability.

### Position familiarity
How familiar a Voli is with a structural position. Already live. Do not use as a synonym for tactical comfort.

### Pair familiarity
General knowledge between two Volis, already modeled by `PairFamiliarity`. Do not use as a synonym for tempo-specific setter–hitter comfort or social chemistry.

### Situation experience / exposure
Accumulated experience with tagged volleyball situations. Used for read/adaptation. Not the same as recruitment scouting observation.

### Match confidence
Point-to-point belief/state during the current match. Distinct from scouting confidence and from career satisfaction.

### Scouting confidence
Certainty in a scout/report belief. Epistemic quantity; it must not modify the Voli's true ability.

### Match flow
Team-level current match state used by decisions. Do not use as a synonym for individual match confidence.

### Style description
Derived player-facing interpretation of observed behavior/capability. Never authoritative causal state.

### Signature capability
Underlying attributes/body/state that make an exceptional action physically/technically possible.

### Signature vocabulary
Unusual solutions a Voli has developed/possesses. Vocabulary is not an attribute and does not guarantee manifestation.

### Signature manifestation
A signature actually becoming available/occurring because capability, vocabulary, state and valid rally context align.

### Focus
In `SIGNATURE_VOCABULARY.md`, a Tier-1 match state. Do not confuse with **training focus**, the attribute-training allocation control described in `TACTICS_AND_TRAINING.md`.

### Familiarity
**Never use this word unqualified in new architecture prose.** Specify `position familiarity`, `pair familiarity`, `situation familiarity/read`, or `tactical comfort` because all four are different quantities.

## Known documentation-history hazard

Several design documents deliberately retain historical arguments after the implementation they describe has changed. Status headers and later backlog closure notes outrank old "current" paragraphs inside preserved history.

Example: `SCOUTING.md` contains an older section saying beliefs have no owner; `docs/BACKLOG.md` later records beliefs-with-owner as closed. Do not reopen the defect from the historical paragraph.

Likewise, `SETTER_DECISION.md` explicitly labels its original "nobody chooses" premise as history because shared option decision work later landed.

## New-document rule

Before adding a new design authority:

1. identify whether an existing document already owns the concept;
2. state whether the new file extends, supersedes, or merely indexes that authority;
3. name the authoritative data owner if implementation is implied;
4. avoid creating a second noun for an existing quantity;
5. preserve TBD slots rather than filling conceptual symmetry with speculative mechanics.
