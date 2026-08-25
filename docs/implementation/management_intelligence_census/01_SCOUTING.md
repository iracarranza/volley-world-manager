# Scouting — Design to Implementation

## Current shape

Recruitment scouting is one of the more mature management-intelligence systems.

`SCOUTING.md` records that the fog is a view over `VolleyballPlayer` truth, deterministic for a given belief, and centered rather than clamp-biased. Repeated observation narrows uncertainty; potential has separate knowability; confidence is player-facing; category/profile fogging exists.

The backlog later records **per-channel knowability** and **beliefs with an owner** as closed. Therefore older passages in `SCOUTING.md` that describe ownerless club beliefs are historical implementation notes, not current-state authority.

## Census

| Designed behavior | State | Notes |
|---|---|---|
| Truth remains on Voli; scout sees a view | LIVE | Correct single-source architecture. |
| Deterministic estimates | LIVE | Prevents reopen/reroll exploit. |
| Observation narrows uncertainty | LIVE | Existing confidence machinery. |
| Potential remains harder to know | LIVE | Separate scale/floor. |
| Per-channel knowability | LIVE | Backlog explicitly records closure. |
| Per-scout belief ownership | LIVE | Backlog explicitly records closure. |
| Two scouts can disagree | LIVE/PARTIAL | Ownership enables it; full UI comparison surface not audited. |
| Regional knowledge/network | DATA_ONLY | Staff region facts exist; design says no regional term was consumed. No later closure found. |
| Freshness widens old estimates | ABSENT | Design/backlog still identifies as open. |
| Persistent scout claim history | ABSENT | Required for manager learning who was right. |
| Scout specialization | PARTIAL/UNKNOWN | Per-scout ownership enables it; no closure evidence established here. |
| Rare trait discovery only on demonstration | PARTIAL | Design is explicit; traits/evidence exist, complete discovery pipeline not proven. |
| Investigation assignments cost scout time | ABSENT | Depends on appointment/day cost. |
| 1★–5★ question-specific query ladder | ABSENT/PARTIAL | Some prerequisites exist; full ladder intentionally downstream. |
| Club familiarity from scout tenure | DATA_ONLY | `weeks_employed` was designed as future consumer; no live consumer established here. |
| Form-vs-underlying diagnosis | PARTIAL | Requires wheel talent/current split as shared quantity. |

## Important distinction

There are two scouting/adaptation concepts and they should not be merged:

1. **Recruitment scouting** — epistemic uncertainty about a Voli, mediated by staff beliefs.
2. **Opponent reading** — players learning repeated match geometry through `situation_experience` and read modifiers.

Both concern knowledge, but they have different owners, clocks, and consequences.

## Highest-value remaining scouting work

1. Freshness that widens stale estimates.
2. Regional knowledge/network terms.
3. Persistent scout report history.
4. Demonstration-gated rare trait/signature discovery.
5. Investigation assignments once scout-time can be charged honestly.
6. Query ladder only as prerequisites become real.

Do not add more scouting prose/UI before these quantities have owners.