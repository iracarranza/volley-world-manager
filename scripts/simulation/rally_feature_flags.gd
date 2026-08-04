class_name RallyFeatureFlags
extends RefCounted

## Production rollout switches. Keep disabled until the corresponding
## calibration gate explicitly authorizes live use.
const ENABLE_CONTINUOUS_RECEPTION_EVENTS: bool = false
const ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_SETTER_EVENTS: bool = false
const ALLOW_DEVELOPMENT_SETTER_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_ATTACK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_ATTACK_OVERRIDE: bool = true
## Gate 48 added the selection boundary; Gate 49 added the promotion path
## behind an explicit development fixture and OS.is_debug_build().
const ENABLE_CONTINUOUS_BLOCK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_BLOCK_OVERRIDE: bool = true

## Gate E: the geometric attack. Where the other rollouts promote one *contact*,
## this one replaces how an attack is decided and resolved end to end -- course,
## power, swing, flight, block intersection and in/out.
##
## Open on all three attack paths: the home first ball, the opponent transition
## swing and the home continuation. Each one now takes its landing point, its
## in/out and its block result from a trajectory intersected against a wall
## rather than from a quality scalar against a threshold, and the opponent can
## miss a swing for the first time.
##
## Two things are deliberately still legacy behind this flag, because promoting
## them is a separate question from promoting the outcome. The drawn arc stays
## on `solve_launch_arc`, a ground-to-ground solver, while the resolver launches
## from three metres up -- handing it the resolver's elevation would draw spikes
## leaving the hand at a negative angle. And the serve still resolves through
## `_serve_execution`; the geometric serve flies alongside it and is recorded,
## but a serve is not an attack and gets its own gate.
##
## Production is still closed, and this is the gate refusing the promotion
## rather than the promotion being unfinished. Opened across all three paths,
## the symmetry estimator moves from 0.558 to 0.671 -- the home side wins two
## attacks for every one the opponent wins, against a 0.12 bound. The promotion
## did not create that tilt; it removed what was hiding it. The legacy path ends
## a large share of attacks at the block, and a ball that never reaches the
## floor never asks which side's floor defence is modelled better. Once the
## geometric swing puts those balls down, every rally runs through the home
## side's claimant search, arrival margins, posture reads and support counts on
## one side of the net and through `_choose_opponent_defender` and a flat dig
## contest on the other, and the difference between the two shows up as points.
##
## So the promotion waits on the floor defence, not on itself. Development
## builds run it today through `ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK`, which is
## where Gates 42, 48 and 49 each sat before their own production flip.
const ENABLE_GEOMETRIC_ATTACK: bool = false
const ALLOW_DEVELOPMENT_GEOMETRIC_ATTACK: bool = true
