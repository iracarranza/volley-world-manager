# Broadcast corpus → VWM commentary matrix mapping

This document maps the researched broadcast corpus onto the existing Volley World Manager commentary/event concepts **without generating replacement dialogue**. Exact corpus wording remains in `commentary_corpus.csv` / `commentary_corpus.md`; this file only classifies how that evidence should affect the event matrix.

## Status key

- **MATCH** — researched commentary maps cleanly to the VWM event.
- **MATCH / OPTIONAL** — real broadcasts sometimes call it and sometimes skip it.
- **SPLIT** — the current VWM event groups physically different outcomes that broadcasters distinguish.
- **MERGE** — multiple VWM announcement layers describe the same physical event and should not independently speak.
- **ANALYST EVIDENCE** — useful causal/tactical state for the second commentator, not a standalone PBP event.
- **UI / DIAGNOSTIC** — useful simulation data, but not routine spoken commentary.
- **PARTIAL** — the phenomenon is represented but the exact VWM term/usage is not validated.
- **RESEARCH** — no sufficiently close corpus evidence yet.
- **CORPUS GAP** — explicitly absent from the current corpus.

## Core broadcast rule

The simulation event stream and spoken commentary stream should not be identical. A blank PBP line is valid; a blank analyst line should be normal.

The play-by-play commentator should primarily describe observable physical events. The analyst should draw selectively from causal/tactical evidence. Percentages, metres, seconds, assignment IDs, exchange counts, and similar measurements should default to tactical UI rather than speech.

---

## Serve and reception

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Serve in play | MATCH | PBP | Corpus supports short server/serve identification. Pressure/risk values should remain diagnostic. |
| Generic serve error | SPLIT | PBP | Split into net / long / wide / fallback-other. Corpus directly distinguishes all three physical miss types. |
| Serve pressure % | UI / DIAGNOSTIC | — | Do not require spoken percentage. |
| Selected serve risk % | UI / DIAGNOSTIC | — | Tactical display data. |
| Ace | MATCH | PBP / named moment | Directly represented. |
| Routine reception | MATCH / OPTIONAL | PBP | Corpus includes both a minimal call and an explicit no-call case. Do not force a sentence on every clean pass. |
| Excellent reception | MATCH | PBP | Qualitative good/perfect-pass distinction is represented. Exact quality % need not be spoken. |
| Poor reception / shank | MATCH | PBP / named moment | Troubled pass/shank behavior is represented. |
| Reception seam conflict | MATCH | PBP / Analyst | Directly represented by neither passer taking ownership. |
| Arrival margin | UI / DIAGNOSTIC | — / Analyst evidence | Preserve for causality; not routine PBP. |
| Nearby support count | UI / DIAGNOSTIC | — | Preserve in analysis UI. |
| Platform dime | PARTIAL | Named moment | Exceptional reception is represented; exact VWM label is not validated by current corpus. |
| Scramble pass | RESEARCH | PBP / named moment | `[RESEARCH: late successful reception / scramble pass]` |

### Required serve subtype structure

```text
serve_error
├── net
├── long
├── wide
└── other
```

`serve_error` should remain a scoring/result category, but physical commentary should use the subtype.

---

## Setter decision and second contact

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Setter decision | ANALYST EVIDENCE | Analyst | The invisible tactical decision should not require PBP speech. |
| Called play followed | ANALYST EVIDENCE | Analyst | Useful interpretation after the delivered set/attack. |
| No active play / default offense | ANALYST EVIDENCE / UI | Analyst | Internal tactical context, not a live contact. |
| Called play abandoned | ANALYST EVIDENCE | Analyst | Useful causal context; not standalone PBP. |
| Routine set | MATCH | PBP | Corpus supports compact setter→hitter/location calls. |
| Quick / fast-tempo set | MATCH | PBP | Tempo is explicitly called when visually salient. |
| Emergency / out-of-system set | PARTIAL | PBP | One strong high-ball example exists; one corpus row labelled emergency set is actually a free-ball return and should not be used as set evidence. |
| Set accuracy % | UI / DIAGNOSTIC | — | Tactical display. |
| Requested vs achieved tempo | ANALYST EVIDENCE | Analyst | `[RESEARCH: commentary on visible tempo adjustment / mismatch]` |
| Setter early/late timing | ANALYST EVIDENCE / UI | Analyst | Causal evidence; exact spoken treatment not yet researched. |
| Dime | RESEARCH | Named moment | `[RESEARCH: high-quality set isolating hitter from second blocker]` |
| Save set | RESEARCH | Named moment / Analyst | `[RESEARCH: setter salvages poor first contact]` |
| Telegraphed | RESEARCH | Analyst | `[RESEARCH: predictable set / blockers reading setter]` |

Avoid broadcast lines that merely expose engine state such as “assignment activated.” Keep the engine state, research the spoken form separately.

---

## Attacking

The existing broad `attack_error` category is too coarse for commentary.

### Required physical taxonomy

```text
attack
├── in_play
│   ├── hard_attack
│   ├── line
│   ├── cross
│   ├── tip
│   └── roll
├── kill
│   ├── generic
│   ├── line
│   ├── cross
│   ├── tip
│   ├── roll
│   ├── tool
│   └── seam        [RESEARCH]
└── error
    ├── net
    ├── long
    ├── wide
    ├── antenna
    ├── whiff       [CORPUS GAP]
    └── other
```

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Generic attack / swing | MATCH | PBP | Physical action belongs to PBP. |
| Generic kill | MATCH | PBP | Use when no more specific subtype is important. |
| Line shot / line kill | MATCH | PBP / named moment | Directly represented. |
| Cross-court attack | MATCH | PBP / named moment | Directly represented. |
| Tip | MATCH | PBP / named moment | Directly represented. |
| Roll shot | MATCH | PBP / named moment | Directly represented. |
| Tool / off hands | MATCH | PBP / named moment | Directly represented as off-block-and-out behavior. |
| Attack into net | MATCH | PBP | Directly represented. |
| Attack long | MATCH | PBP | Directly represented. |
| Attack wide | MATCH | PBP | Directly represented. |
| Antenna/contact fault | MATCH | PBP | Directly represented. |
| Whiff / missed delivered set | CORPUS GAP | PBP | `[RESEARCH: hitter completely misses delivered set]` |
| Seam kill | RESEARCH | PBP / named moment | `[RESEARCH: kill through defensive seam]` |
| Emergency tip | RESEARCH | PBP / named moment | `[RESEARCH: emergency/non-approach tip]` |
| Cross-court bullet | PARTIAL | Named moment | Cross-court attack is supported; this exact emphatic label is not corpus-validated. |
| Attack quality % | UI / DIAGNOSTIC | — | Do not require live spoken percentage. |
| Hitter early/late | ANALYST EVIDENCE / UI | Analyst | Causal evidence for timing failures. |

The scoring category `attack_error` can remain, but it should never force one generic physical description such as “goes wide.”

---

## Blocking

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Block forms | MATCH / OPTIONAL | PBP | Observable, but not every formed block needs a call. |
| Stuff block | MATCH | PBP | Directly represented. |
| Roof | MATCH | PBP / named moment | Directly represented as a stuff-block concept. |
| Block touch / soft touch | MATCH | PBP | Directly represented as touch/off-hands slowing the attack. |
| Missed / no block | MATCH | PBP / Analyst | “No block” / incomplete close is directly represented. |
| Late block | MATCH | PBP / Analyst | Physical outcome supported. |
| Primary close % | UI / DIAGNOSTIC | — | Keep numerical value out of routine speech. |
| Assistant close % | UI / DIAGNOSTIC | — | Same. |
| Block quality % | UI / DIAGNOSTIC | — | Same. |
| Got tooled | PARTIAL | Named moment | Tool phenomenon is represented; exact VWM label not validated. |
| Funnel | RESEARCH | Analyst / named moment | `[RESEARCH: intentional block funnel into floor defense]` |
| Beaten by tempo | RESEARCH | Analyst | Late/no block is represented, but explicit causal tempo language is not yet established. |

A stuff block, `ROOF` tag, block-point result, and analyst reaction are four representations of one event. They should not automatically create four independent spoken lines.

---

## Floor defense

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Routine dig | MATCH / OPTIONAL | PBP | Often minimally called; can be silent in dense rallies. |
| Exceptional / sprawl dig | MATCH / PARTIAL | PBP / named moment | Exceptional defensive saves are strongly represented; exact `sprawl dig` label is not validated. |
| Failed dig | MATCH | PBP | Observable result can be called; exact causes need event data. |
| Defensive control % | UI / DIAGNOSTIC | — | Tactical display. |
| Defender movement distance | UI / DIAGNOSTIC | — | Tactical display. |
| No defensive plan | ANALYST EVIDENCE / UI | Analyst | Internal tactical state. |
| Defender outside assignment | ANALYST EVIDENCE | Analyst | Preserve causal evidence; research broadcast phrasing separately. |
| Assignment fit | ANALYST EVIDENCE | Analyst | Same. |
| Missed the easy one | RESEARCH | Analyst / named moment | `[RESEARCH: defender fails despite comfortable arrival margin]` |

---

## Attack coverage

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Home attack coverage | MATCH | PBP | Directly represented. |
| Opponent attack coverage | MATCH | PBP | Same physical concept. |
| Transition attack coverage | MATCH | PBP | Same physical concept; exchange number need not be spoken. |
| Cover named action | MATCH | Named moment | Direct phenomenon supported. |
| Attack recycled factor | MERGE | — | Same physical event as successful coverage; do not generate separate commentary automatically. |
| Coverage quality % | UI / DIAGNOSTIC | — | Tactical display. |

---

## Overpasses

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Overpass | MATCH | PBP | Directly and immediately recognized in corpus. |
| Home / opponent overpass control | MATCH | PBP | Can be represented by who takes the crossed ball. |
| Overpass attack | MATCH AS SEQUENCE | PBP | Corpus supports overpass immediately followed by a finish. Avoid explanatory definition text. |

The commentators do not need to explain that an overpass is “a ball that crossed the net”; that belongs to rules/analysis UI, not live speech.

---

## Transition and long-rally pacing

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Transition offense | MATCH | PBP | Broad transition/return-to-team calls are represented. |
| Exchange number | UI / DIAGNOSTIC | — | No evidence that the booth should repeatedly speak exchange numbers. Keep as timeline metadata if useful. |
| Long rally | MATCH | PBP | Corpus shows shorter survival calls as rally density rises. |
| Point-ending analyst reaction | MATCH / OPTIONAL | Analyst | Two-person booth evidence supports selective post-whistle reaction. |

Important pacing rule: commentary should become **shorter**, not more verbose, during dense extended rallies.

---

## Named-action status

### Corpus-supported physical vocabulary / behavior

- Ace — MATCH
- Shank — MATCH
- Tip — MATCH
- Roll shot — MATCH
- Line shot — MATCH
- Tool off block — MATCH
- Roof — MATCH
- Cover — MATCH

### Phenomenon supported; exact VWM label not validated

- Platform dime — PARTIAL
- Dime — PARTIAL / needs targeted setter evidence
- Cross-court bullet — PARTIAL
- Got tooled — PARTIAL
- Soft block — PARTIAL
- Sprawl dig — PARTIAL

### Research backlog

- Scramble pass
- Save set
- Telegraphed
- Seam kill
- Emergency tip
- Funnel
- Beaten by tempo
- Missed the easy one
- Whiff / missed set

A corpus gap does **not** mean remove the mechanic or VWM-specific term; it means do not claim real-broadcast validation yet.

---

## Point-ending announcements: reclassification

Point-ending categories should store result and cause rather than own generic prose.

### Service points

```text
home_point / opponent_point
└── cause
    ├── service_ace
    ├── serve_net
    ├── serve_long
    ├── serve_wide
    └── serve_other
```

### Attack points

```text
home_point / opponent_point
└── cause
    ├── kill_generic
    ├── kill_line
    ├── kill_cross
    ├── kill_tip
    ├── kill_roll
    ├── kill_tool
    ├── stuff_block
    ├── attack_net
    ├── attack_long
    ├── attack_wide
    ├── attack_antenna
    ├── attack_whiff       [RESEARCH]
    └── other
```

### Called-play / improvised / default-offense kill

These should **not** be separate physical point-ending dialogue keys.

```text
RESULT: home_kill
TACTICAL_CONTEXT:
    called_play_followed
    called_play_abandoned
    no_called_play
```

The PBP commentator receives the physical kill. The tactical context becomes optional analyst evidence.

### Long-rally safety resolution

The exchange-limit home win/loss paths are simulation-specific. Mark them:

`[DESIGN REVIEW: determine whether the safety-resolution mechanic should have an explicit broadcast analogue before researching wording]`

### Transition loss

Currently described as not emitted by a rally-ending path:

`[DEAD / UNREACHABLE: no dialogue research until a live path uses it]`

### Unmapped outcome

Keep as a rare defensive fallback, not a source for normal commentator voice.

---

## Rally-factor commentary → analyst evidence

The existing factor strings should be reclassified rather than independently appended as prose.

| Existing factor | New role |
|---|---|
| Good pass | Optional PBP / reception evidence |
| Poor pass | PBP-capable reception evidence |
| Play followed | Analyst evidence |
| Play abandoned | Analyst evidence |
| Fast-tempo failure | Analyst evidence |
| Strong opponent block | Analyst evidence |
| Strong opponent defense | Analyst evidence |
| Attack control | Analyst evidence / redundant with physical result |
| Default offense | Analyst evidence / UI |
| Opponent adaptation | Analyst evidence |
| Defensive assignment fit | Analyst evidence |
| Defensive assignment stretch | Analyst evidence |
| Block touch | MERGE with physical block-touch event |
| Block funnel | MERGE with physical funnel event if retained |
| Reception seam conflict | MERGE with physical reception event |
| Attack recycled | MERGE with attack-coverage event |

---

## Targeted research placeholders

### High priority

- `[RESEARCH: attack whiff / hitter misses delivered ball]`
- `[RESEARCH: setter saves a bad first contact]`
- `[RESEARCH: blocker explicitly beaten by attack tempo]`
- `[RESEARCH: setter/set described as telegraphed or predictable]`
- `[RESEARCH: kill through defensive seam]`
- `[RESEARCH: intentional block funnel]`
- `[RESEARCH: late successful / scramble reception]`
- `[RESEARCH: defender misses despite ample arrival time]`

### Medium priority

- `[RESEARCH: emergency second-contact setter]`
- `[RESEARCH: emergency/non-approach tip]`
- `[RESEARCH: analyst discussion of hitter/setter timing mismatch]`
- `[RESEARCH: analyst discussion of defender leaving assignment]`
- `[RESEARCH: analyst discussion of called offensive play/pattern]`
- `[RESEARCH: block touch intentionally creating a dig opportunity]`

### Terminology validation

- `[VALIDATE TERM: platform dime]`
- `[VALIDATE TERM: dime]`
- `[VALIDATE TERM: got tooled]`
- `[VALIDATE TERM: soft block]`
- `[VALIDATE TERM: sprawl dig]`
- `[VALIDATE TERM: cross-court bullet]`

---

## Recommended commentator routing matrix

| Event | PBP | Analyst | UI diagnostics |
|---|---|---|---|
| Routine serve | yes | rarely | pressure / risk |
| Serve error subtype | yes | optional | pressure / risk |
| Routine reception | optional | rarely | quality / arrival |
| Bad / exceptional reception | yes | optional | quality / arrival / seam |
| Setter decision | no | optional | full tactical state |
| Delivered set | yes | optional | accuracy / tempo |
| Attack | yes | optional | quality / timing |
| Attack error subtype | yes | optional | quality / timing |
| Block stuff / touch | yes | optional | close / quality |
| Routine dig | optional | usually no | control / arrival |
| Exceptional dig | yes | optional | control / arrival |
| Coverage | yes | rarely | recycle quality |
| Tactical adaptation | no | yes | full evidence |
| Assignment fit / stretch | no | yes | responsibility data |
| Point result | yes | optional | result metadata |

## Next research pass

Do **not** collect another broad corpus first. Search specifically for the unresolved placeholders above, preserve verbatim source wording, and return `NOT FOUND` rather than inventing examples. The current corpus is already sufficient to support the error-subtype split, selective PBP salience, analyst-evidence layer, and removal of routine percentages from spoken commentary.
