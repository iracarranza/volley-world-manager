# Glossary

## Action opportunity

A possible volleyball action available to one player during a time window. In the persistent foundation, `ActionOpportunity` stores action type, player, timing, target, feasibility, and related data.

## Autoload

A Godot script or scene created once and made globally accessible. This project configures `GameManager` and `CareerManager` as Autoloads.

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

## Class

A definition of data and behavior. `class_name RallyEvent` makes `RallyEvent` a named GDScript type.

## Cogniticon

A mark showing what a voli is attending to, as distinct from an expression, which shows a surface emotional state. Motion is owned by `CogniticonMotion`.

## Contact window

The time interval during which a player can reach and legally act on the ball.

## Contrast ratio

`(lighter + 0.05) / (darker + 0.05)` computed on luminances, running 1.0 to 21.0. Every regional kit must score at least 1.6 against the court floor.

## Deterministic seed

A number used to initialize random generation so the same inputs can reproduce the same sequence of random values.

## Dictionary

A collection of key-value pairs. Dictionaries are flexible but easier to misuse than typed Resources; verify exact keys.

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

## Free zone

The clear area around the court in which no structural geometry may stand: 5 m from the sidelines and 8 m behind the end lines.

## Head-normalised coordinates

Feature positions expressed on `[-1, 1]` against the head's own semi-axes, so one set of numbers serves every head size.

## Kit

What a club wears. Home strips are per region in `RegionalKits.KITS`; the away strip is universal and light. Presentation data only.

## Manager

A stateful coordinator, such as `CareerManager` or `GameManager`.

## Model

A data-focused class, usually a `Resource`, stored under `scripts/models/`.

## Normalized court coordinates

Two-dimensional court positions expressed mainly from `0.0` to `1.0`, then converted to court distance or screen coordinates elsewhere.

## Opportunity window

The measured interval during which movement, timing, and body feasibility make
an action available. A window can close after a corrected ball read even when
it was open earlier.

## Perceived flight

A player-specific estimate of ball destination and arrival time. It is distinct
from the authoritative `BallFlight` used to grade the resulting contact.

## Persistent state

State carried forward from one simulation moment to the next. A player remains where movement left them until another rule changes that position.

## Playback

Visual presentation of already-resolved simulation records. Playback should display results; it should not secretly decide gameplay outcomes.

## Primitive

One of the mesh shapes `BodyTypeModels.build_mesh` can construct. An unrecognised `shape` silently produces a capsule.

## Probe

A tool that measures and prints a table rather than asserting. Headless-safe. Distinct from a gate, which fails the suite, and a render harness, which produces images.

## Produce

One of five shapes a `Vegi` grows in: `Tomato`, `Aubergine`, `Pear`, `Stalk`, `Pepper`. Derived from the player id, presentation only, and never named where a user can read it.

## Resource

A Godot data object that can be typed, saved, duplicated, and passed around without being part of the scene tree.

## Scene

A saved tree of Nodes. Scenes define user interfaces, screens, and reusable visual components.

## Scheduler

A structure that orders future simulation moments by time and priority.

## Signal

A message emitted by one object that other objects may connect to without tight direct coupling.

## Silhouette

The complete `Dictionary` describing one voli's body, returned by `BodyTypeModels.silhouette()`.

## Spec

A `Dictionary` describing a single mesh: a `shape` key plus that shape's parameters.

## System

A mostly stateless calculation module, such as `CoverageCalculator` or `VolleyballTrainingSystem`.

## Tactical home

A preferred position for a phase of play. It is a movement goal, not a command to teleport or reset a player.

## Trim

How far a kit's marks sit from the kit in value. Always lighter, because every home kit is dark.

## Variant

Godot's general-purpose value type. It allows flexibility but provides fewer guarantees than a specific static type.

## Venue

The room around the court -- walls, roof, seating, light and atmosphere. Eight exist, each keyed to a region.
