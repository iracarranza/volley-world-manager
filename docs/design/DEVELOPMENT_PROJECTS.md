# Development Projects

Status: **Product direction. One ingredient of it has since landed.**

`VolleyballPlayer.position_training_target` is serialized both ways,
`GameManager.set_position_training()` assigns it, and `FamiliaritySystem` reads
it so that repeated training moves a voli toward a position they were not
generated for. The Team tab's Individual Training sub-tab is its interface. That
is the *opportunity* leg of the formula below and nothing else — there is no
tactical-need model, no latent-potential surface that shows a manager what a
voli could become, and no project that spans seasons. The fantasy in the first
section is still ahead of the code.

Otherwise intentionally separate from the rally architecture work.

## Core fantasy

The fantasy is not “change positions.”

It is:

> See what an athlete could become before anyone else does.

The manager identifies ingredients that are not yet obvious in a player's
current role, then creates the circumstances in which those ingredients can
become a valuable responsibility, playstyle, or eventual position.

## Development formula

**Tactical Need + Latent Potential + Opportunity = Development Project**

1. **Tactical need:** What does the manager's system lack?
2. **Latent potential:** Which visible and hidden traits suggest that a player
   could satisfy that need eventually?
3. **Opportunity:** Can the club provide training, minutes, mentorship, and a
   suitable competitive environment long enough for the experiment to work?

The important decision is not:

> Can they play this position?

It is:

> Does this athlete have the ingredients to become what my system needs?

## Reference examples

### Football Manager

A team needs an inverted right wing-back and has no suitable right-back. A
young left winger has intelligence, work rate, and positional discipline, but
is unlikely to become the starting winger. The manager redirects that player's
development toward the inverted wing-back responsibility.

### Volleyball

- **Future setter:** The team needs a blocking setter. A recruit is tall,
  vocal, and coachable but technically raw. The club develops them toward
  setting over several seasons.
- **Six-rotation outside:** A current outside hitter contributes only as an
  attacker. Serve receive, floor defense, transition play, and game reading are
  developed until the player can remain on court through every rotation.
- **Defensive specialist:** A reserve outside hitter has elite anticipation but
  limited offense. Repeated defensive responsibilities gradually shift their
  useful role.

## Haikyuu parallels

- **Koganegawa:** He was not chosen because he was already a finished setter.
  The team needed one, and he possessed height, leadership, coachability, and
  long-term potential.
- **Hinata:** His development was not a direct Middle-to-Opposite switch. He
  first developed serve receive, defense, shot selection, and game reading.
  The eventual positional change was an outcome of accumulated capability.

## Proposed system

Players undertake **Development Projects** instead of training positions
directly.

Example projects:

- Future Setter
- Six-Rotation Outside
- Blocking Opposite
- Transition Middle
- Defensive Specialist
- Offensive Libero

A project develops a connected set of responsibilities over time. Progress may
unlock new tactical uses, playstyles, role familiarity, or eventually a new
primary position. A position change is evidence of completed development, not
the development mechanic itself.

## Scouting implication

Scouting should emphasize developmental projections rather than treating the
current position as destiny.

Example report:

| Projection | Potential |
|---|---:|
| Blocking Opposite | ★★★★★ |
| Setter | ★★★★☆ |
| Middle | ★★★☆☆ |
| Libero | ★☆☆☆☆ |

Current position: **Outside Hitter**

These projections should be uncertain and evidence-driven. Better scouts and
coaches reveal ingredients sooner or estimate them more accurately; they do not
guarantee the outcome.

## Player reward

The player is rewarded for identifying possibilities before they become
obvious, committing scarce development opportunities, and shaping a roster
around convictions that may take seasons to prove correct.

## Future design questions

- Which traits are visible, hidden, scoutable, or only revealed through use?
- How do match minutes and assigned responsibilities differ from training?
- What makes a project stall, branch, fail, or produce an unexpected role?
- How do coaching quality, mentorship, age, adaptability, and personality
  affect the development curve?
- How should tactical familiarity grow without becoming direct position XP?
- When does the game recognize an emergent playstyle or primary-role change?
