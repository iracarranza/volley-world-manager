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

The targeted continuation pass uses the requested evidence labels. **DIRECT
MATCH** means the new physical event and commentary category align without
normalizing the quote. **PBP** and **ANALYST** identify the broadcast layer.
**TERM VALIDATED** / **TERM NOT VALIDATED** apply only to the literal term, not
to a related volleyball phenomenon. **OPTIONAL / OFTEN SILENT** and **UI /
DIAGNOSTIC** retain their existing routing meanings.

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
| Platform dime | PARTIAL / TERM NOT VALIDATED | Named moment | S7–S9 validate `dime` for reception, but none says the compound `platform dime`. Do not treat the compound term as validated. |
| Scramble pass | DIRECT MATCH | PBP / named moment | S5 directly calls the setter scrambling after two passers converge and the first contact sends the offense out of system. |

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
| Called play followed | ANALYST / DIRECT MATCH | Analyst | S11 explicitly links an outside attack to a huddle request. S12 independently follows a huddle instruction to keep McCage in front with replay analysis that the resulting overload opened the outside attack. The tactical effect remains commentator inference. |
| No active play / default offense | ANALYST EVIDENCE / UI | Analyst | Internal tactical context, not a live contact. |
| Called play abandoned | ANALYST EVIDENCE | Analyst | Useful causal context; not standalone PBP. |
| Routine set | MATCH | PBP | Corpus supports compact setter→hitter/location calls. |
| Quick / fast-tempo set | MATCH | PBP | Tempo is explicitly called when visually salient. |
| Emergency / out-of-system set | DIRECT MATCH | PBP / Analyst | S5 and S9 directly show setters salvaging off-target first contacts. The old S1 “Free ball coming” row has been relabelled because it is a return over the net, not a set. |
| Set accuracy % | UI / DIAGNOSTIC | — | Tactical display. |
| Requested vs achieved tempo | ANALYST / DIRECT MATCH | Analyst | S6 says the tempo was not fast enough and that Ewert had to slow down and wait; S7 independently identifies an early hitter and a set behind him. |
| Setter early/late timing | ANALYST / DIRECT MATCH | Analyst | S6 and S7 explicitly discuss hitter/setter timing and connection. Keep numerical timing in UI, but the visible mismatch is broadcast-natural analysis. |
| Dime | PARTIAL | Named moment | `Dime` is TERM VALIDATED for reception in S7–S9. No targeted source uses it for a high-quality set isolating a hitter, so the setter-specific placeholder remains unresolved. |
| Save set | ANALYST / DIRECT MATCH | Named moment / Analyst | S9 describes Orro turning an off-net pass into “almost a perfect set even in an imperfect situation”; S5 independently calls Sekita's scramble. |
| Telegraphed | ANALYST / DIRECT MATCH | Analyst | S6 explicitly calls a pipe predictable; S8 explains that an out-of-system outside set was known in advance. The exact word `telegraphed` remains unvalidated. |

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
│   └── seam        [DIRECT MATCH]
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
| Seam kill | DIRECT MATCH | PBP / named moment | S5 explicitly calls Lucarelli hammering the ball into an open seam on a pipe kill. |
| Emergency tip | ANALYST / DIRECT MATCH | PBP / named moment / Analyst | S12 distinguishes a planned in-system tip from an off-system hitter who “kind of had to tip.” The emergency condition is the analyst's inference from the poor setup; a specifically non-approach example remains unvalidated. |
| Cross-court bullet | PARTIAL / TERM NOT VALIDATED | Named moment | Cross-court attack and emphatic hard-crosscourt calls are supported; the exact compound label was not found. |
| Attack quality % | UI / DIAGNOSTIC | — | Do not require live spoken percentage. |
| Hitter early/late | ANALYST / DIRECT MATCH | Analyst | S6 and S7 explicitly identify a hitter waiting for the ball or arriving early. Exact measurements remain UI / DIAGNOSTIC. |

The scoring category `attack_error` can remain, but it should never force one generic physical description such as “goes wide.”

---

## Blocking

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Block forms | MATCH / OPTIONAL | PBP | Observable, but not every formed block needs a call. |
| Stuff block | MATCH | PBP | Directly represented. |
| Roof | MATCH | PBP / named moment | Directly represented as a stuff-block concept. |
| Block touch / soft touch | MATCH / TERM NOT VALIDATED | PBP | Touch/off-hands/deflection behavior is directly represented. The exact term `soft block` is not; two corpus physical labels were corrected to avoid implying that it was spoken. |
| Missed / no block | MATCH | PBP / Analyst | “No block” / incomplete close is directly represented. |
| Late block | MATCH | PBP / Analyst | Physical outcome supported. |
| Primary close % | UI / DIAGNOSTIC | — | Keep numerical value out of routine speech. |
| Assistant close % | UI / DIAGNOSTIC | — | Same. |
| Block quality % | UI / DIAGNOSTIC | — | Same. |
| Got tooled | PARTIAL / TERM NOT VALIDATED | Named moment | Tool phenomenon is represented; the exact phrase `got tooled` was not found. |
| Funnel | DIRECT MATCH / ANALYST / TERM VALIDATED | Analyst / named moment | S11 explicitly says Brazil is blocking line and “trying to funnel everything cross court.” S13 independently says USA is trying to funnel the ball to libero Morgan Hentz. Both statements are analyst inferences about defensive intent, separate from the observed attack path. |
| Beaten by tempo | ANALYST / DIRECT MATCH | Analyst | S8 says Japan's speed leaves “no time to close up the seam”; S9 says the tempo is too quick after the decoy holds the middle. The exact phrase `beaten by tempo` is not validated. |
| Block touch intentionally creates dig chance | PARTIAL / ANALYST | Analyst | S5 praises a deflection that goes directly to Leal. S11 directly describes good touches slowing attacks for back-court defense. Neither source says a particular block touch was deliberately directed to a defender, so the intent-specific placeholder remains. |

A stuff block, `ROOF` tag, block-point result, and analyst reaction are four representations of one event. They should not automatically create four independent spoken lines.

---

## Floor defense

| VWM concept | Status | Speaker | Mapping / action |
|---|---|---|---|
| Routine dig | MATCH / OPTIONAL | PBP | Often minimally called; can be silent in dense rallies. |
| Exceptional / sprawl dig | MATCH / TERM NOT VALIDATED | PBP / named moment | Exceptional defensive saves are strongly represented; exact `sprawl dig` label is not validated. |
| Failed dig | MATCH | PBP | Observable result can be called; exact causes need event data. |
| Defensive control % | UI / DIAGNOSTIC | — | Tactical display. |
| Defender movement distance | UI / DIAGNOSTIC | — | Tactical display. |
| No defensive plan | ANALYST EVIDENCE / UI | Analyst | Internal tactical state. |
| Defender outside assignment | ANALYST EVIDENCE / PARTIAL | Analyst | S10 says Sekita stepped in and “probably should have stayed where he was,” directly linking movement away from his effective position to the missed dig. It does not prove a formal team assignment, so the VWM assignment placeholder remains. |
| Assignment fit | ANALYST EVIDENCE | Analyst | Same. |
| Missed the easy one | ANALYST / DIRECT MATCH | Analyst / named moment | S7 says Fornal should have handled a float serve easily; S10 independently says a jump float should have been dealt with and identifies Lavia's indecision. |

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

- Platform dime — TERM NOT VALIDATED; `dime` alone is validated for reception
- Dime as a set — PARTIAL; `dime` is TERM VALIDATED only for reception
- Cross-court bullet — TERM NOT VALIDATED
- Got tooled — TERM NOT VALIDATED; `tool`, `off the block`, and `off the hands` are supported equivalents
- Soft block — TERM NOT VALIDATED; `touch`, `off the hands`, and `deflection` are supported equivalents
- Sprawl dig — TERM NOT VALIDATED; the physical action is supported
- Funnel — TERM VALIDATED for intentional block-defense shaping
- Beaten by tempo — TERM NOT VALIDATED; the causal phenomenon is a DIRECT MATCH

### Remaining research backlog

- Whiff / hitter completely misses a delivered set — CORPUS GAP
- Block touch intentionally creating a dig opportunity — PARTIAL; direct intent remains a gap
- Dime used for a high-quality set — CORPUS GAP
- Defender leaving a formal called assignment — PARTIAL; only effective-position evidence was found

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
| Block funnel | MERGE with the physical funnel event; do not create a second line |
| Reception seam conflict | MERGE with physical reception event |
| Attack recycled | MERGE with attack-coverage event |

---

## Targeted research placeholders

Only placeholders with direct new support are closed. PARTIAL and CORPUS GAP
items remain explicit rather than being promoted through analogy.

| Target | Classification | Evidence / disposition |
|---|---|---|
| Attack whiff / hitter misses delivered ball | CORPUS GAP | NOT FOUND. S5 says “a little whiff” about an ambiguous middle-net play after a broken contact, not a hitter completely missing a delivered set. Placeholder retained. |
| Setter saves a bad first contact | DIRECT MATCH / ANALYST | RESOLVED by S5 and S9. |
| Blocker explicitly beaten by attack tempo | DIRECT MATCH / ANALYST | RESOLVED by S8's “no time to close up the seam” and supported independently by S9. |
| Predictable / telegraphed set | DIRECT MATCH / ANALYST | RESOLVED for `predictable` by S6 and for blocker foreknowledge by S8; exact `telegraphed` remains TERM NOT VALIDATED. |
| Kill through defensive seam | DIRECT MATCH / PBP | RESOLVED by S5. |
| Intentional block funnel | DIRECT MATCH / ANALYST / TERM VALIDATED | RESOLVED independently by S11 and S13. Both commentators infer intent; the videos establish the observed attack/block-defense action, not the teams' private tactical language. |
| Late successful / scramble reception | DIRECT MATCH / PBP | RESOLVED by S5's conflicted reception and deep emergency second contact. |
| Defender misses despite apparently easy ball | DIRECT MATCH / ANALYST | RESOLVED independently by S7 and S10. |
| Emergency second-contact setter | DIRECT MATCH / PBP / ANALYST | RESOLVED by S5 (libero setting from deep) and S6 (non-setter forced to take second contact). |
| Emergency/non-approach tip | DIRECT MATCH / ANALYST | RESOLVED for an emergency/out-of-system tip by S12: the analyst contrasts the play with an in-system tip and says the hitter “kind of had to tip.” A strictly zero-approach example remains NOT FOUND. |
| Hitter/setter timing mismatch | DIRECT MATCH / ANALYST | RESOLVED independently by S6 and S7. |
| Defender leaving assignment | PARTIAL / ANALYST | S10 directly supports leaving an effective position, but a formal called assignment remains an inference. Placeholder retained at the assignment level. |
| Called offensive play/pattern | DIRECT MATCH / ANALYST | RESOLVED by S11's huddle request followed immediately by the requested outside attack and independently by S12's huddle instruction followed by the described overload. S7/S9 remain visible-pattern evidence only. |
| Block touch intentionally creates dig chance | PARTIAL / ANALYST | S5 supports a useful deflection to a defender, and S11 directly ties good block touches to slowing attacks for back-court defense. Deliberate direction of a particular touch is still NOT FOUND. Placeholder retained at the intent level. |

### Terminology validation

| Exact term | Classification | Corpus result |
|---|---|---|
| `platform dime` | TERM NOT VALIDATED | NOT FOUND in 28 screened broadcasts. Independent uses of `dime` omit `platform`. |
| `dime` | TERM VALIDATED | S7: “He dimed that ball”; S8: “Dime pass”; S9: “passed a dime.” The expanded search found the same reception usage repeatedly, but no setter usage. |
| `got tooled` | TERM NOT VALIDATED | NOT FOUND in 28 screened broadcasts. Close equivalents `tool`, `tools the block`, `off the block`, and `off the hands` occur. |
| `soft block` | TERM NOT VALIDATED | NOT FOUND in 28 screened broadcasts. Close equivalents `block touch`, `touch`, `off the hands`, and `slow it down` occur. |
| `sprawl dig` | TERM NOT VALIDATED | NOT FOUND in 28 screened broadcasts. Physical sprawls/diving saves are called `dig`, `save`, `pancake`, or `one-arm stab`. |
| `cross-court bullet` | TERM NOT VALIDATED | NOT FOUND in 28 screened broadcasts. `Bullet` is used independently for hard attacks and serves; `cross-court shot` is used independently. |
| `funnel` | TERM VALIDATED | S11 uses `funnel` for a block taking line to channel attacks cross-court; S13 independently uses it for channeling the ball toward libero Morgan Hentz. |
| `beaten by tempo` | TERM NOT VALIDATED | NOT FOUND verbatim in 28 screened broadcasts. S8's close equivalent says speed is used to beat the block and leaves no time to close the seam. |

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

Do **not** collect another broad corpus first. Search specifically for the four unresolved intent/usage gaps above, preserve verbatim source wording, and return `NOT FOUND` rather than inventing examples. The current corpus is already sufficient to support the error-subtype split, selective PBP salience, analyst-evidence layer, and removal of routine percentages from spoken commentary.
