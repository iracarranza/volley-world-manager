# P1-C1 — What You Are Building

Status: **VERIFIED**, except sections explicitly marked **PROPOSED**
Keywords: game loop, volleyball management, tactics, match, career, player growth
Primary sources: `project.godot`; `scenes/application.gd`; `scripts/managers/game_manager.gd`; `scripts/managers/career_manager.gd`

## Learning goals

After this chapter, you should be able to explain the game's two main layers and why management choices must become visible in match decisions.

## The product in one sentence

Volley World Manager is a Godot 4 management game in which the user builds and develops a volleyball team, prepares tactics, and observes those choices resolve into rallies and match outcomes.

## The two connected loops

The management loop includes roster decisions, training, careers, fixtures, transfers, lineups, and tactical preparation. The match loop includes serve, reception, setting, attacking, blocking, defense, continuation, and scoring.

These loops should not feel independent:

```text
training and recruitment
        ↓
player capabilities and knowledge
        ↓
available tactical choices and information
        ↓
movement, contacts, and rally outcomes
        ↓
results and new management decisions
```

The design goal is not merely “higher attributes increase a hidden percentage.” Improvement should create perceptible consequences:

- a faster defender can reach an additional ball;
- a better setter can arrive sooner and preserve more attack options;
- a more perceptive hitter can recognize a defended lane;
- a more familiar team can execute a complex tempo reliably;
- better scouting can reveal information the user can act upon.

## Current versus desired rally model

**VERIFIED:** the current live simulator resolves a whole rally into an ordered event list. It uses considerable spatial and tactical calculation, but much of the control flow still advances phase by phase.

**PROPOSED:** the destination is a persistent state simulation. Position and velocity determine reachable actions; a chosen action changes ball state; the ball's future path creates new movement decisions; movement then changes the next action set.

## Beginner checkpoint

Open `project.godot` and find `run/main_scene`. Then open that scene and its attached script. This is how you start replacing a vague idea of “the game” with a traceable runtime path.
