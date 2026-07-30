# Glossary

## Action opportunity

A possible volleyball action available to one player during a time window. In the persistent foundation, `ActionOpportunity` stores action type, player, timing, target, feasibility, and related data.

## Autoload

A Godot script or scene created once and made globally accessible. This project configures `GameManager` and `CareerManager` as Autoloads.

## Ball trajectory

The path and timing of a ball flight. `BallTrajectory` stores start, control, and end positions along with start time, duration, and apex height.

## Ball contact signature

A calculated description of contact speed, angles, signed spin, and flight
stability. It characterizes what players must read without performing an
aerodynamic simulation.

## Ball flight estimate

One player's current belief about a flight's destination and arrival time. It
may differ from authoritative `BallFlight` truth because of recognition delay,
ability, novelty, and familiarity.

## Class

A definition of data and behavior. `class_name RallyEvent` makes `RallyEvent` a named GDScript type.

## Contact window

The time interval during which a player can reach and legally act on the ball.

## Deterministic seed

A number used to initialize random generation so the same inputs can reproduce the same sequence of random values.

## Dictionary

A collection of key-value pairs. Dictionaries are flexible but easier to misuse than typed Resources; verify exact keys.

## Event

In this project, a `RallyEvent` is a record consumed by playback and analysis. It is not the complete physical state of the rally.

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

## Resource

A Godot data object that can be typed, saved, duplicated, and passed around without being part of the scene tree.

## Scene

A saved tree of Nodes. Scenes define user interfaces, screens, and reusable visual components.

## Scheduler

A structure that orders future simulation moments by time and priority.

## Signal

A message emitted by one object that other objects may connect to without tight direct coupling.

## System

A mostly stateless calculation module, such as `CoverageCalculator` or `VolleyballTrainingSystem`.

## Tactical home

A preferred position for a phase of play. It is a movement goal, not a command to teleport or reset a player.

## Variant

Godot's general-purpose value type. It allows flexibility but provides fewer guarantees than a specific static type.
