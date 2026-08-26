# Commentary event routing research specification

This is a read-only implementation map and a technical specification derived
from the broadcast corpus. It deliberately does not contain commentator copy,
production-code changes, or UI changes.

## Outcome

The simulation already exposes most facts needed for broadcast-natural routing.
The central problem is separation: physical events, analyst evidence,
diagnostics, and rendered prose currently share the same path. A future
implementation should route facts first, allow silence, and ensure that one
physical event does not speak through several independent layers.

## Current code-path map

| Location | Current responsibility | Research implication |
|---|---|---|
| `scripts/models/rally_event.gd:22` | Defines serve, reception, set decision, set, attack, block, dig, point, and attack-coverage events. | The physical event spine is suitable, but `headline`/`detail` at lines 43–45 mix facts with presentation. |
| `scripts/models/rally_result.gd:6` | Stores terminal result, active play, whether it was followed, key factors, analysis, headline, and explanation. | It already carries tactical evidence, but factors/result prose can duplicate contact-level narration. |
| `scripts/simulation/rally_simulator.gd:2656` | Computes `set_path_whiff`; later publishes set path, tempo, approach, attack type/direction, and timing metadata. | Whiff, emergency-tip, timing-mismatch, and attack-subtype routing can be fact-driven even though whiff wording remains a corpus gap. |
| `scripts/simulation/rally_simulator.gd:3209` and `:5742` | Resolves block outcomes including stuff, touch, tool, recycle, miss, and funnel. | Physical block outcome can drive PBP; block intent, defensive target, and causal success should remain separate analyst evidence. |
| `scripts/simulation/rally_simulator.gd:2068` | Records whether the selected play was followed. | This can support analyst routing only when the observable route/effect also exists; S11/S12 show the broadcast analogue. |
| `scripts/simulation/rally_simulator.gd:14047` | Writes event headline/detail strings during simulation. | Future commentary should consume structured facts instead of treating simulator-authored prose as the event contract. |
| `scripts/data/rally_explanations.gd:1` | Centralizes outcome/factor text. | It can remain a diagnostic/result resource, but factor strings should not automatically become independent spoken lines. |
| `scenes/main/main.gd:1565` | Iterates every rally event and renders a caption before skipping `SET_DECISION` animation at line 1628. | The present path effectively requires speech for every event; routing must happen before caption display. |
| `scenes/main/main.gd:1869` | Prepends named-action text and rewrites block headlines/details. | This creates another narration owner and can convert internal outcomes into claims not selected by a commentary router. |
| `scenes/main/main.gd:2175` | Shows result headline/explanation, named moments, every key factor, quality percentages, movement timing, and block-read values. | Result and diagnostic layers can repeat the same rally fact; they need dedupe groups and explicit UI-only routing. |

## Required fact contract

A future router should receive structured records. Field names below describe a
contract, not a requested production edit.

| Field | Purpose |
|---|---|
| `physical_event_id` | Stable identity shared by PBP, analyst evidence, result, replay, and UI representations of one contact/outcome. |
| `event_type` and `event_subtype` | Physical taxonomy such as serve error net/long/wide; kill line/cross/tool/seam; attack error net/long/wide/antenna/whiff. |
| `observable_facts` | Actor, contact, path, outcome, positions, and success that can support PBP. |
| `analyst_evidence` | Tempo effect, visible timing mismatch, inferred funnel intent, assignment fit, play-followed state, or adaptation. |
| `inference_basis` | What observation supports an analyst inference, so private intent is not presented as directly observed fact. |
| `diagnostics` | Percentages, distances, seconds, internal IDs, and engine traces. Defaults to UI only. |
| `salience` | Whether PBP is required, optional, or normally silent. |
| `dedupe_group` | Identity used to prevent contact, factor, named moment, and point result from producing redundant speech. |
| `commentary_status` | One of PBP, ANALYST, OPTIONAL / OFTEN SILENT, UI / DIAGNOSTIC, or suppressed. |
| `evidence_status` | DIRECT MATCH, PARTIAL, CORPUS GAP, or applicable terminology status. |

## Routing sequence

1. The simulator emits physical facts and tactical evidence without deciding
   how many spoken lines they create.
2. A subtype classifier normalizes only supported physical distinctions. An
   unresolved label such as attack whiff may remain a simulation fact without
   claiming broadcast validation.
3. A salience pass selects zero or one PBP candidate for each physical event.
   Routine reception, routine dig, block formation, and dense-rally contacts may
   validly produce silence.
4. Analyst candidates are built only from causal evidence with an explicit
   inference basis. They are generally delayed until replay, stoppage, or after
   the point.
5. The dedupe pass groups contact, named action, key factor, and result by
   `physical_event_id`/`dedupe_group`; at most one owns the primary spoken fact.
6. Diagnostics remain available to tactical UI without becoming speech.
7. The renderer displays only selected commentary objects. It must not recreate
   event wording from raw block outcomes or append every factor automatically.

## Evidence-backed routing matrix

| Fact family | Default route | Notes |
|---|---|---|
| Serve and physical serve-error subtype | PBP | Error should retain net/long/wide distinction. |
| Routine clean reception | OPTIONAL / OFTEN SILENT | Both a minimal call and an explicit silence case exist. |
| Exceptional/poor/conflicted reception | PBP | Quality percentage and arrival margin stay diagnostic. |
| Setter decision or called-play state | ANALYST | S11/S12 support selective analysis when a huddle request/instruction is visibly followed. |
| Delivered set | PBP, optional analyst | Numerical accuracy/tempo stays UI; visible rescue or timing mismatch may feed analyst evidence. |
| Attack and physical error subtype | PBP | Emergency tip is supported; whiff remains a fact with `CORPUS GAP`. |
| Stuff, touch, tool, funnel | PBP for physical outcome; ANALYST for cause/intent | `funnel` is validated, but intention is an inference. A touch is not automatically an intentional funnel. |
| Routine dig | OPTIONAL / OFTEN SILENT | Exceptional saves are more salient. |
| Defender assignment/position | ANALYST | Formal assignment abandonment remains PARTIAL. |
| Attack coverage/recycle | PBP when salient | Coverage event and recycled factor must share a dedupe group. |
| Point result | PBP | Cause should be inherited from the decisive physical event rather than generating a second generic description. |
| Percentages, metres, seconds, read values | UI / DIAGNOSTIC | No routine spoken analogue is required. |

## Dedupe rules

- A stuff block, named `roof`, block-point result, factor, and analyst reaction
  are representations of one outcome, not five mandatory lines.
- A tool/off-hands attack owns the physical point; the block touch must not also
  announce a defensive success.
- Successful attack coverage owns the recycle event; an `attack_recycled`
  factor may inform analysis but should not repeat it.
- Called-play-followed state is tactical context on the resulting attack, not a
  separate contact.
- A seam kill can carry both attack direction and point cause in one physical
  event.
- Result summaries may add score consequence, but should suppress any physical
  description already owned by the decisive event.

## Silence policy

Silence is a valid selected result, not missing data. It should be favored when:

- the contact is routine and the next contact is more informative;
- a dense rally would become less intelligible if every dig/set were called;
- analyst evidence is weak, redundant, or depends on private intent not stated
  by the broadcast evidence;
- a named-action/result layer already owns the same fact;
- only diagnostic measurements distinguish the event.

## Acceptance checks for a future implementation

- Every spoken candidate traces to one structured physical fact or one explicit
  analyst inference basis.
- One physical event cannot produce duplicate PBP through event, named-action,
  factor, and result paths.
- `SET_DECISION` is not rendered merely because it exists in the event list.
- Routine-event tests include expected silence.
- Long-rally tests show commentary density decreasing as contacts accumulate.
- Exact percentages, arrival seconds, movement distances, and internal IDs do
  not enter spoken output by default.
- Funnel tests distinguish physical direction, block outcome, intended plan,
  and analyst inference.
- Whiff, setter-`dime`, formal assignment abandonment, and intentional directed
  block-touch tests remain research-gated rather than borrowing nearby wording.
