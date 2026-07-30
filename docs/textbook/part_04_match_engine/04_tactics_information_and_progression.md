# P4-C4 — Tactics, Information, and Progression

Status: current supporting systems **VERIFIED**; integration model **PROPOSED**
Keywords: tactics, familiarity, scouting, perception, progression, options, information
Primary sources: `scripts/models/offensive_play.gd`; `scripts/models/defensive_plan.gd`; `scripts/systems/familiarity_system.gd`; `scripts/systems/attribute_profile_system.gd`; `scripts/tactics/play_validator.gd`; `scripts/tactics/tactical_demand.gd`

## The user needs options and information

Player improvement should affect at least three layers:

1. **Physical possibility:** which locations the player can reach in time.
2. **Execution reliability:** how well a reachable action is performed.
3. **Decision information:** which opportunities, risks, and opponent patterns are visible or correctly interpreted.

If progression changes only a final probability, the user may not feel agency. If it unlocks an additional set, reveals a vulnerable seam, or makes a demanding defensive assignment viable, the change becomes understandable.

## Capability gates

**PROPOSED:** each opportunity can report requirements and reasons:

```text
Pipe attack
- physically reachable: yes
- timing window: narrow
- familiarity requirement: satisfied
- setter accuracy requirement: marginal
- user-visible confidence: 62%
- alternative: high outside ball, 84%
```

The user need not see raw formulas. They should see actionable differences.

## Knowledge should be stateful

`Familiarity` already supplies execution and read-related modifiers. The fuller design should distinguish:

- team-system familiarity;
- player-role familiarity;
- opponent scouting confidence;
- in-match exposure and adaptation;
- individual perception and decision-making.

Hidden truth and known information should be separate. The simulator may know an opponent favors Zone 4; the user and players should only exploit that to the degree scouting and recognition permit.

## Tactical instructions as preferences

An offensive play or defensive plan should influence intent and decision ranking, not teleport players or guarantee a scripted contact. A called quick attack can fail to become available if the pass or movement destroys its timing window. A disciplined setter may then choose the safest available alternative.

## Visible progression examples

- training increases transition speed, causing a previously late hitter to enter the candidate list;
- improved court vision exposes the secondary hitter as a better option against an adapted block;
- greater familiarity narrows the uncertainty shown for a fast tempo;
- better anticipation starts movement earlier, improving arrival posture;
- improved ball control adds viable target choices rather than only increasing “success.”

## Required UI support

**PROPOSED:** the tactical UI should explain unavailable, risky, and newly available choices using short reasons. Post-rally analysis should identify the decision and physical constraint that mattered, using `RallyTrace` rather than reverse-engineering a story from the final score.
