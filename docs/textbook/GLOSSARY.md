# Glossary

## Action opportunity

A possible volleyball action available to one player during a time window. In the persistent foundation, `ActionOpportunity` stores action type, player, timing, target, feasibility, and related data.

## Attributable delta

A difference between two measurements that can be explained, because both ends were measured on named commits. A delta with only one end is not attributable.

## Autoload

A Godot script or scene created once and made globally accessible. This project configures `GameManager` and `CareerManager` as Autoloads.

## Balance probe

`tools/run_rally_balance_probe.gd`. One shared instrument reporting rally-population rates against values the sport has real figures for. Shared deliberately, so two attempts at the same problem are comparable.

## Ball contact signature

A calculated description of contact speed, angles, signed spin, and flight
stability. It characterizes what players must read without performing an
aerodynamic simulation.

## Ball flight estimate

One player's current belief about a flight's destination and arrival time. It
may differ from authoritative `BallFlight` truth because of recognition delay,
ability, novelty, and familiarity.

## Ball trajectory

The path and timing of a ball flight. `BallTrajectory` stores start, control, and end positions along with start time, duration, and apex height.

## Body type

One of six morphologies a voli may have: `Vegi`, `Avi`, `Cani`, `Feli`, `Ursi`, `Simi`. Stored on `VolleyballPlayer.body_type` and readable by the simulation, unlike a produce variant.

## Capability gate

A reported requirement explaining why a tactical option is available, marginal or absent -- and what the alternative is. Shows actionable differences rather than coefficients.

## Claimant

The player selected to play a given ball.

## Class

A definition of data and behavior. `class_name RallyEvent` makes `RallyEvent` a named GDScript type.

## Cogniticon

A mark showing what a voli is attending to, as distinct from an expression, which shows a surface emotional state. Motion is owned by `CogniticonMotion`.

## Contact window

The time interval during which a player can reach and legally act on the ball.

## Continuity contract

The five conditions every contact must satisfy so that ball position, actor movement, outgoing trajectory, next opportunities and drawn playback all agree. See P4-C3.

## Contrast ratio

`(lighter + 0.05) / (darker + 0.05)` computed on luminances, running 1.0 to 21.0. Every regional kit must score at least 1.6 against the court floor.

## Deadline

The arrival time a launched ball imposes on everyone who might play it. Players move because of a deadline, not because a phase granted permission.

## Deterministic seed

A number used to initialize random generation so the same inputs can reproduce the same sequence of random values.

## Development project

A multi-season programme training responsibilities toward a possible future role. A new position is a possible result, not the button pressed at the start.

## Development-only

Enabled by an explicit fixture flag and off in production. Persistent rally slices are promoted this way before any production rollout.

## Dictionary

A collection of key-value pairs. Dictionaries are flexible but easier to misuse than typed Resources; verify exact keys.

## Diegetic

Presented as an object in the game's world rather than as an abstract menu. The interface is a desk with objects on it.

## Envelope (camera)

The volume every camera preset must remain inside, set by the tightest enclosed venue rather than per venue.

## Envelope (motion)

A motion curve expressed in real seconds rather than as a fraction of its window, so it plays at the same rate whatever the window's duration.

## Event

In this project, a `RallyEvent` is a record consumed by playback and analysis. It is not the complete physical state of the rally.

## Expression

A named face such as `happy` or `deadpan`. Derived from an eye state and a mouth shape via `FaceExpressions.GRID`, never authored directly.

## Extra

An optional named part appended to a body spec -- an ear, a brow, a rib, a crown blade. The main extension point for changing how a body looks.

## Familiarity

Accumulated knowledge -- of a team system, a role, or an opponent. Supplies execution and read-related modifiers.

## Foreknowledge

Information the resolver holds that an actor must not read. The block migration's central constraint: a blocker must not receive the selected attack lane.

## Free zone

The clear area around the court in which no structural geometry may stand: 5 m from the sidelines and 8 m behind the end lines.

## Head-normalised coordinates

Feature positions expressed on `[-1, 1]` against the head's own semi-axes, so one set of numbers serves every head size.

## Hidden truth

What the simulator knows, as distinct from what the user and players are entitled to act on.

## Kit

What a club wears. Home strips are per region in `RegionalKits.KITS`; the away strip is universal and light. Presentation data only.

## Known information

What the user and players may act on, limited by scouting confidence and recognition.

## Latent potential

Traits that could support a responsibility the player's current position does not use.

## Lathe

A mesh made by revolving a 2D outline about the vertical axis. Called `profile` in the body spec vocabulary.

## Legibility

Whether a change in the numbers produces a change a viewer can see and attribute. The project's central design requirement: improvement must be perceptible, not merely statistical.

## Luminance

Perceived brightness of a colour, 0.0 to 1.0. `Color.get_luminance()`.

## Management loop

Roster decisions, training, careers, fixtures, transfers, lineups and tactical preparation.

## Manager

A stateful coordinator, such as `CareerManager` or `GameManager`.

## Match loop

Serve, reception, setting, attacking, blocking, defence, continuation and scoring.

## Model

A data-focused class, usually a `Resource`, stored under `scripts/models/`.

## Normalized court coordinates

Two-dimensional court positions expressed mainly from `0.0` to `1.0`, then converted to court distance or screen coordinates elsewhere.

## Opportunity

A possible action with timing and feasibility. States that an action can be attempted and how favourable the setup is -- never that it will succeed.

## Opportunity window

The measured interval during which movement, timing, and body feasibility make
an action available. A window can close after a corrected ball read even when
it was open earlier.

## Perceived flight

A player-specific estimate of ball destination and arrival time. It is distinct
from the authoritative `BallFlight` used to grade the resulting contact.

## Persistent state

State carried forward from one simulation moment to the next. A player remains where movement left them until another rule changes that position.

## Phase model

A resolver that knows which volleyball phase comes next. The current live rally simulator is one; the persistent design replaces it with a scheduler.

## Playback

Visual presentation of already-resolved simulation records. Playback should display results; it should not secretly decide gameplay outcomes.

## Predecessor

The measurement taken before a change, on a named commit. Without it a later measurement has nothing to be compared against.

## Primitive

One of the mesh shapes `BodyTypeModels.build_mesh` can construct. An unrecognised `shape` silently produces a capsule.

## Probe

A tool that measures and prints a table rather than asserting. Headless-safe. Distinct from a gate, which fails the suite, and a render harness, which produces images.

## Produce

One of five shapes a `Vegi` grows in: `Tomato`, `Aubergine`, `Pear`, `Stalk`, `Pepper`. Derived from the player id, presentation only, and never named where a user can read it.

## Promotion

Allowing a shadow decision to become authoritative, normally behind a development-only flag first.

## Recognition time

How long before a player has read a ball flight at all. Part of `BallFlightEstimate`, and one reason perception differs from truth.

## Reference semantics

Two variables pointing at the same Resource, so mutating through one changes what the other sees. Use `duplicate(true)` to isolate.

## Render harness

A tool that photographs rather than measures, writing PNGs to `user://`. Needs a rendering context; cannot run headless.

## Resource

A Godot data object that can be typed, saved, duplicated, and passed around without being part of the scene tree.

## Role projection

An uncertain, evidence-based estimate of a player's future positional fit. Not destiny.

## Rollout policy

The guarded selection between a legacy and a persistent source for one contact. Production flags remain off.

## Runtime trace

Following an actual call path from a visible scene to a state change, rather than searching for a plausible function name. Necessary here because superseded paths still parse.

## Sampling gate

A check that emits a variable number of assertions. The reason the suite total moves without anything breaking, and the reason to read the FAIL line instead.

## Scene

A saved tree of Nodes. Scenes define user interfaces, screens, and reusable visual components.

## Scheduler

A structure that orders future simulation moments by time and priority.

## Schema drift

Dictionary keys quietly diverging between the code that writes them and the code that reads them. The main cost of using a Dictionary for a long-lived concept.

## Shadow decision

A persistent decision computed and compared against the live one, but not used for outcomes. The stage before promotion.

## Signal

A message emitted by one object that other objects may connect to without tight direct coupling.

## Silhouette

The complete `Dictionary` describing one voli's body, returned by `BodyTypeModels.silhouette()`.

## Spec

A `Dictionary` describing a single mesh: a `shape` key plus that shape's parameters.

## Stop condition

A signal to stop and investigate rather than continue: unrelated files changing, unstable deterministic tests, a UI script owning simulation state, or a temporary fallback hiding invalid data.

## System

A mostly stateless calculation module, such as `CoverageCalculator` or `VolleyballTrainingSystem`.

## Tactical home

A preferred position for a phase of play. It is a movement goal, not a command to teleport or reset a player.

## Tactical need

A responsibility a team's system lacks, and one of the three ingredients of a development project.

## Trim

How far a kit's marks sit from the kit in value. Always lighter, because every home kit is dark.

## user://

Godot's per-user writable data location, separate from the project repository. Career saves and rendered probe output both go here.

## Variant

Godot's general-purpose value type. It allows flexibility but provides fewer guarantees than a specific static type.

## Venue

The room around the court -- walls, roof, seating, light and atmosphere. Eight exist, each keyed to a region.

## Vertical slice

A change connecting data, calculation, result and visible or testable evidence. Preferred over adding several unused abstractions, because it is falsifiable immediately.

## Voli

A player, in project vocabulary. "Player" is reserved for the person holding the controller.
