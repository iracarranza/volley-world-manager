# P1-C1 — What You Are Building

Status: **VERIFIED**, except sections explicitly marked **PROPOSED**
Keywords: game loop, volleyball management, tactics, match, career, player growth, legibility, diegetic interface
Primary sources: `project.godot`; `scenes/application.gd`; `scripts/managers/game_manager.gd`; `scripts/managers/career_manager.gd`

## Prerequisites

None. This is the first chapter. If you have never opened the project, do that
alongside reading — every claim here names a file you can look at.

## Learning goals

After this chapter you should be able to:

1. state what the product is in one sentence, without using the word "simulation";
2. name the two loops and explain the causal chain that joins them;
3. distinguish a **statistical** improvement from a **legible** one, and say why this project insists on the second;
4. describe the difference between the rally model that exists and the one being built;
5. locate the runtime entry point yourself.

## Vocabulary

| Term | Meaning |
|---|---|
| **Voli** | A player, in project vocabulary. "Player" means the person holding the controller. |
| **Management loop** | Roster, training, careers, fixtures, transfers, lineups, tactical preparation. |
| **Match loop** | Serve, reception, set, attack, block, defence, continuation, scoring. |
| **Legibility** | Whether a change in the numbers produces a change a viewer can *see and attribute*. |
| **Diegetic** | Presented as an object in the game's world rather than as an abstract menu. |
| **Phase-by-phase** | The current rally model: resolve serve, then reception, then set, in order. |
| **Persistent state** | The proposed model: positions and velocities evolve, and actions become available. |

## 1. The product in one sentence

> Volley World Manager is a Godot 4 management game in which the user builds and
> develops a volleyball team, prepares tactics, and observes those choices
> resolve into rallies and match outcomes.

### 1.1 Why the verb is "observes"

Note the verb **observes**. The user does not play the rally. Everything they
did earlier has to survive into something watchable, or it did not happen as far
as they are concerned. That single constraint drives most of the architecture in
this book.

## 2. The two loops, and the chain between them

The **management loop** is roster decisions, training, careers, fixtures,
transfers, lineups and tactical preparation. The **match loop** is serve,
reception, setting, attacking, blocking, defence, continuation and scoring.

These loops must not feel independent:

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

### 2.1 Reading the chain

Read that as a **causal chain with no gaps**. Every arrow is a place where a
management decision could quietly stop mattering, and every one of them is a
place this project has had to defend.

## 3. Legible improvement, not statistical improvement

The design goal is not "higher attributes increase a hidden percentage."
Improvement must create perceptible consequences:

- a faster defender can reach an additional ball;
- a better setter can arrive sooner and preserve more attack options;
- a more perceptive hitter can recognise a defended lane;
- a more familiar team can execute a complex tempo reliably;
- better scouting can reveal information the user can act upon.

### 3.1 The distinction, worked

Suppose training raises a defender's `lateral_speed` by 4.

**A statistical implementation** multiplies their dig success chance by 1.03.
Over a season this is real and invisible: the user cannot point at a rally and
say *that* is what the training bought.

**A legible implementation** lets the defender's movement model carry them
further in the time available, so a ball that was previously out of reach is now
inside their window. The user sees a dig that would not have happened. The
number changed *one specific thing they can name*.

> **Why this is hard, and why it is the whole point.** The legible version
> requires the ball, the body and the clock to be modelled well enough that
> "further in the same time" is meaningful. The statistical version requires
> only a multiplier. Most of Part 4 exists because the project chose the first.

> **Checkpoint.** Pick another attribute — `composure`, say — and write down what
> its legible consequence would have to be. If you cannot name one, that is a
> genuine design finding, not a failure of the exercise.

## 4. Current versus desired rally model

**VERIFIED:** the current live simulator resolves a whole rally into an ordered
event list. It uses considerable spatial and tactical calculation, but much of
the control flow still advances **phase by phase**.

### 4.1 The proposed model

**PROPOSED:** the destination is a **persistent state** simulation. Position and
velocity determine reachable actions; a chosen action changes ball state; the
ball's future path creates new movement decisions; movement then changes the
next action set.

The difference is not cosmetic. In a phase model, "who receives this serve?" is
answered by a function that picks a receiver. In a persistent model, nobody
answers it — the receiver is whoever can physically get there, which means the
question can have the answer *nobody*, and the rally has to cope.

### 4.2 Why the labels matter

> **Reading the labels.** **VERIFIED** and **PROPOSED** are not decoration. This
> book is used by people making changes, and a claim about behaviour that does
> not exist yet is the most expensive kind of error. See
> [VERIFICATION_RULES.md](../VERIFICATION_RULES.md).

## 5. The interface is a desk

One more product fact, because it governs where UI work belongs: the interface
is not a dashboard. It is a **desk with objects on it** — a journal, a
clipboard, a cork board, a planner, a folder, a phone. Each object has its own
material and its own way of being marked.

### 5.1 Names are load-bearing

This is why you will see names like `journal_screen.gd` rather than
`player_list_screen.gd`. The names are load-bearing; see
[`DIEGETIC_MANAGEMENT.md`](../../design/DIEGETIC_MANAGEMENT.md) before changing
anything an interface touches.

## 6. Common misconceptions

**"The match is the game."** The match is where management choices become
visible. A change that improves the rally but severs it from a management
decision has made the product worse.

**"Higher attribute, better outcome, done."** That is the statistical model §3
rejects.

**"The persistent rally engine is how it works now."** It is partially built and
guarded behind flags. Read the status labels.

**"The screens are menus."** They are objects with materials. A page built as a
bare container gets no background and is unreadable in one of the two themes.

## 7. Check yourself

1. Why does the product sentence use "observes" rather than "plays"? *(The user never controls a rally; every earlier decision must survive into something watchable.)*
2. Give a legible consequence for a higher `jump_reach`. *(The hitter contacts the ball above a block that previously reached it.)*
3. In a persistent model, what can "who receives this serve?" return that a phase model cannot? *(Nobody — and the rally must handle that.)*
4. A chapter says a feature is **PROPOSED**. Can you rely on it in code today? *(No.)*
5. Where is the runtime entry point configured? *(`project.godot`, `run/main_scene`.)*

## Beginner checkpoint

Open `project.godot` and find `run/main_scene`. Then open that scene and its
attached script. This is how you replace a vague idea of "the game" with a
traceable runtime path — and it is exactly what the next chapter does in detail.

## Where this leads

- [P1-C2 Godot Project and Runtime](02_godot_project_and_runtime.md) — the entry point, in full
- [P1-C4 Following a User Action](04_following_a_user_action.md) — one decision traced end to end
- [P4-C1 Current Rally Pipeline](../part_04_match_engine/01_current_rally_pipeline.md) — the phase model as it exists
- [P4-C2 Persistent Rally State](../part_04_match_engine/02_persistent_rally_state.md) — the model being built
