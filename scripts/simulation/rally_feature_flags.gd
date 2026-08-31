class_name RallyFeatureFlags
extends RefCounted

## NOTE why each flag exists, and the evidence it was promoted on --
## docs/review/RALLY_FEATURE_FLAGS.md

## NOTE production rollout switches; keep closed until a calibration gate opens one
const ENABLE_CONTINUOUS_RECEPTION_EVENTS: bool = false
const ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_SETTER_EVENTS: bool = false
const ALLOW_DEVELOPMENT_SETTER_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_ATTACK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_ATTACK_OVERRIDE: bool = true

## NOTE Gate 48 added the selection boundary, Gate 49 the promotion path
const ENABLE_CONTINUOUS_BLOCK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_BLOCK_OVERRIDE: bool = true

## NOTE M4/M5 physical platform contact, promoted to production
const ENABLE_PHYSICAL_PLATFORM_DIG: bool = true
## NOTE keeps the retired apex/spoil dig arm alive for the paired census
const ALLOW_DEVELOPMENT_PLATFORM_DIG_OVERRIDE: bool = true

## NOTE the third and last platform family on the shared physical authority
const ENABLE_PHYSICAL_RECEPTION: bool = true

## NOTE Gate E, and the only rollout that promotes a *decision* rather than a contact
const ENABLE_GEOMETRIC_ATTACK: bool = true
const ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK: bool = true

## NOTE one attack shape for both sides of the net: one flight per ball, one rule
const ENABLE_UNIFIED_ATTACK_SHAPE: bool = false

## NOTE roll-against-swing decided on the set delivered, not on an estimate
const ENABLE_DELIVERED_SET_SHOT_CHOICE: bool = false

## NOTE one speed model for every player in every subsystem
const ENABLE_UNIFIED_SPEED_MODEL: bool = false

## NOTE decides the block contest on when the blocker jumped, not only how tall
const ENABLE_BLOCK_JUMP_TIMING: bool = false

## NOTE lets the opponent hitter walk to their mark before the set is released
const ENABLE_OPPONENT_APPROACH_WINDOW: bool = false

## NOTE stages the wall where the ball crosses the tape, not where the hitter jumped
const ENABLE_BLOCK_CROSSING_READ: bool = false

## NOTE reception quality off a serve, computed one way for both sides
const ENABLE_UNIFIED_RECEPTION_SKILL: bool = false

## NOTE stops billing a hitter for lateness to a contact they were spared
const ENABLE_CLAMPED_ARRIVAL_MARGIN: bool = true

## NOTE reads the hitter's lane off the contact they actually struck
const ENABLE_CLAMPED_CONTACT_LANE: bool = true

## NOTE lets the home middle attack
const ENABLE_HOME_MIDDLE_OFFENSE: bool = true

## NOTE lets the tempo call actually vary
const ENABLE_LIVE_TEMPO_CALL: bool = true

## NOTE lets the back row swing
const ENABLE_HOME_PIPE_OFFENSE: bool = true

## NOTE lets a hitter ask how tight they want it, not just where along the net
const ENABLE_HITTER_TIGHTNESS: bool = true

## NOTE pays the hitter for reading the pass, the way the blocker already is
const ENABLE_HITTER_PRESET_WINDOW: bool = false

## NOTE makes the run-up point at the net
const ENABLE_PERPENDICULAR_APPROACH: bool = true

## NOTE times a set by how high it was put up, not by a ground-to-ground lob
const ENABLE_SET_HEIGHT_TIMING: bool = true
