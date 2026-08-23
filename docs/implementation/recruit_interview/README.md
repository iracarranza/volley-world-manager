# Recruit interview — implementation specification

Status: implementation authority for the first interview build.

Design authority: `docs/design/RECRUITMENT_AND_THE_OFFER.md` and, for time,
`docs/design/THE_DAY_AND_THE_CLOCK.md`.

This is not a new design pass. It translates those decisions onto current source
and names the migration order so an implementation agent does not have to infer
which existing button/function actually owns recruitment.

---

## 0. Current source truth

Verified on the branch this document was written from.

| concern | current owner | current truth |
|---|---|---|
| prospect board/report | `scenes/screens/scouting_screen.gd` | built |
| manager marks | `MARK_*` in scouting screen | annotations only; `would sign` is not a transaction |
| household terms | `scripts/data/recruit_offer.gd` | pure/recomputed; built |
| offer preview in report | `scouting_screen._offer_terms()` | duplicates assembly at screen level |
| transaction | `CareerManager.offer_place(player_id)` | computes room **then immediately signs** |
| roster mutation | `CareerManager.sign_transfer(player_id)` | register/remove/save |
| manager day | `career.day_of_week`, `advance_day()` | built |
| first appointment | `hold_drill_session()` | day-pinned; built |
| within-day block cursor | none | not built |
| interview | none | not built |

The important migration fact is therefore:

```text
scouting report "Offer a place"
    -> CareerManager.offer_place
        -> sign_transfer
            -> roster mutation
```

Do not mistake the green `would sign` board mark for this path.

---

## 1. Target contract

Recruitment becomes:

```text
SCOUT
  -> [optional INTERVIEW]
  -> PREPARE / REVIEW OFFER
  -> MAKE OFFER
  -> candidate response
  -> roster mutation only after acceptance
```

The interview is an across-the-table visit. It is not a trial, attribute reveal,
negotiation score, persuasion minigame or second scouting report.

Two people own turns. The manager may ask/answer/commit; the recruit may answer,
ask, change subject, return to unresolved material or end the visit.

Visible truth is limited to:
- actual spoken exchange;
- checkable documents;
- topic state `□ / ✓ / ? / ×`;
- explicit manager-facing notes/promises.

Never expose:
- trust/interest delta;
- signing probability;
- hidden personality/need values;
- `+/-` line feedback;
- interview completion percentage;
- correct/incorrect dialogue choices.

---

## 2. Authority split

### 2.1 `RecruitOffer` remains the household calculator

Do not turn it into a stored offer object. It continues deriving current room,
roommates, floor use, food wording and concerns from current club + candidate
state.

### 2.2 `CareerManager` becomes the recruitment transaction boundary

Move screen-owned term assembly behind a public read:

```gdscript
func offer_terms(player_id: int) -> Dictionary
```

It must be pure with respect to roster/market state. It may call existing private
service helpers; UI must no longer call `_week_service()` directly.

Refactor current `offer_place(player_id)` so **reviewing terms cannot sign**.
Keep the name for the actual commit path if practical, but its contract becomes:

```text
validate candidate still available
-> recompute terms at commit time
-> obtain candidate decision when/if that decision model exists
-> only on acceptance call sign_transfer
-> return outcome + terms
```

No stored room assignment is necessary at this seam: current housing itself
remains authority.

### 2.3 Interview state records conversation, not evaluation

Add a serialisable `RecruitInterviewState` (Resource or dictionary-backed model)
keyed by prospect id. Allowed first-draft fields:

```text
prospect_id
visit_count
last_week/day[/block when clock exists]
exchanges[]           # speaker + authored/selected utterance key/text
subjects{}            # topic -> □/✓/?/× + short factual note
manager_notes[]       # human-readable notes
promises[]            # explicit commitments made in conversation
asked_question_keys[] # prevents repetition farming
context_fingerprint   # identifies whether relevant club facts changed
```

Forbidden fields:

```text
trust
success
interest_delta
persuasion_score
answer_quality
completion
promise_points
```

`promises[]` is a manager-visible record of what was said, not a generic hidden
mechanic. Later systems may read the actual expectation they model; do not make
all promises feed one score.

Persist interview state with career data so a later visit does not reset history.

---

## 3. Topics and evidence

First draft topics come only from fields/systems already present. Do not add a
new player preference merely to make a question possible.

Minimum topic families:

```text
ROLE
- primary position / intended use
- playing-time expectation when current data can support it
- position flexibility when current player data can support it

CAREER
- why available / current situation when source data exists
- ambition / responsibility only through existing traits/history

LIFE HERE
- housing + roommates
- food/table
- distance from home
- existing care/equipment facts when applicable

CLUB
- why manager wants them (manager-authored statement)
- current squad/competition facts
- plans only when manager explicitly commits to them
```

A topic absent underlying data is absent from the first draft. Do not fill the
screen with invented generic questions.

Statements are evidence. A line may be selected from deterministic templates
using current candidate/club facts, but it must not print the hidden input
verbatim as diagnosis (`ambition = 82`, etc.).

Repeating the same question with unchanged context returns/reference the prior
answer; it does not reroll certainty.

---

## 4. Topic-state semantics

Use exactly the design marks:

```text
□  not discussed
✓  discussed; clear shared understanding / acceptance
?  discussed; unresolved / conditional / genuinely uncertain
×  explicit objection / disagreement remains
```

These are transcript state, not goodness.

Examples:
- `✓ Playing time — understands role is competitive` is valid.
- `× Playing time — requires guaranteed start; manager declined` is valid.
- `? Roommate — room known, occupant may change` is valid.

No code may convert these marks into a universal interview score.

---

## 5. Conversation engine

Create a dedicated module, e.g.

```text
scripts/systems/recruit_interview_system.gd
```

Keep deterministic conversation policy out of the screen.

Suggested pure API:

```gdscript
static func begin_or_resume(state, prospect, club_context) -> Dictionary
static func manager_options(state, prospect, club_context) -> Array[Dictionary]
static func apply_manager_turn(state, option_key, prospect, club_context) -> Dictionary
static func candidate_turn(state, prospect, club_context) -> Dictionary
static func context_fingerprint(prospect, club_context) -> String
```

Return structured turns:

```text
speaker
text
subject
subject_state_delta?  # semantic mark, not numeric score
promise?              # explicit manager commitment only
opens_document?       # dossier / housing / offer
ends_visit?
```

Stable inputs => stable available information. No RNG reroll for persistence.
If variation is wanted, key it deterministically from prospect + visit + turn,
never current wall-clock or reload order.

Candidate-owned turns are mandatory. The player must not be able to run an
uninterrupted questionnaire forever.

---

## 6. UI

Add a distinct interview scene, not a popup inside the scouting report:

```text
scenes/screens/recruit_interview_screen.gd
scenes/screens/recruit_interview_screen.tscn
```

Visual hierarchy:

```text
                     candidate

               current spoken exchange

          dossier   housing   offer

                     manager

                questions / replies
```

Requirements:
- candidate + current exchange dominate the composition;
- documents stay closed until consulted/relevant;
- no permanent CA/PA/attribute/personality surround;
- candidate can take the next turn;
- small interview pad exposes subjects + `□✓?×` + notes/promises;
- no success/probability/trust meter;
- do not narrate the player's thought or tell them what a line means.

Existing scouting report remains scouting. Its action area should expose
`Interview` and `Make offer` as distinct verbs where candidate is recruitable.
Interview may be optional or candidate-requested per design; do not make it a
mandatory checklist gate.

On return from interview, refresh the existing report/board; do not duplicate
prospect state into the interview screen.

---

## 7. Offer migration

Work in this order:

### A. Centralise terms
1. Add `CareerManager.offer_terms(player_id)`.
2. Move `_offer_terms()` assembly out of `scouting_screen.gd`.
3. Make scouting report read public terms.
4. Assert read is mutation-free.

### B. Separate offer from signing
1. Keep `sign_transfer` as low-level roster mutation.
2. Make `offer_place` the commit transaction, not the preview.
3. Ensure no caller can reach `sign_transfer` merely by opening/reviewing terms.
4. Return explicit outcome enum/string (`accepted`, `declined`, `unavailable`,
   etc.) rather than encoding it in prose.

Do **not** invent a candidate acceptance probability in this migration. If no
existing governed acceptance model is present, preserve current acceptance as a
known first-draft limitation and leave a named seam for candidate decision. The
interview must not fabricate a hidden score to solve a separate unsigned design.

### C. Wire interview
1. Board opens interview for `_open_id`.
2. `CareerManager` fetches/persists state by prospect id.
3. Screen calls conversation system; screen never derives hidden candidate truth.
4. End visit returns to board with state intact.
5. Offer terms are recomputed when viewed/committed; interview does not freeze
   housing/food facts.

---

## 8. Time / appointment dependency

`THE_DAY_AND_THE_CLOCK.md` is explicit:

```text
block cursor/tick
-> compliance
-> interview as second manager appointment
-> extract shared activity contract from drill + interview
```

Therefore:
- do not invent an interview-duration constant before the block cursor exists;
- do not create the generic `Activity` schema in advance;
- conversation/UI/state work can be built and tested independently;
- production time-charging waits for the clock's block authority, then interview
  occupies manager blocks through the same emerging appointment contract as the
  drill session.

This is a dependency, not a design question.

---

## 9. Persistence / invalidation

Interview state survives save/load.

If a prospect leaves the market, state may remain historical but cannot create a
new transaction.

`context_fingerprint` should include only facts that can make a previous answer
meaningfully stale, using already-existing data, e.g. relevant housing/room
occupancy, served food state, squad composition, candidate availability and date.
Do not include every career field.

Changed context enables a meaningful follow-up; unchanged context does not reset
answers or clear `?`/`×` automatically.

---

## 10. Certification

### Architectural invariants
- opening terms mutates nothing;
- opening/interacting with interview does not sign;
- roster mutation occurs only after explicit Make Offer commit path;
- interview UI never reads private manager helper `_week_service`;
- no trust/success/probability numeric state exists;
- repeated same question + unchanged context does not reveal new factual truth;
- save/load preserves interview subjects/exchanges/notes;
- offer terms recompute from current household at view + commit;
- manager marks remain annotations, not transactions.

### Fixtures
Cover at least:
1. recruit with no concerns;
2. crowded/overfull room;
3. fresh/private room;
4. unfamiliar food;
5. homesick/distant recruit;
6. resumed unchanged interview;
7. resumed interview after housing/squad context change;
8. candidate disappears from transfer pool before offer;
9. interview with several `?`/`×` states can still end without forced completion;
10. direct Make Offer remains possible where interview is optional.

### Presentation review
Render the interview scene at minimum supported viewport and normal desktop size.
Verify current exchange remains primary and dossier/housing/offer are secondary,
not permanently-open dashboard panels.

---

## 11. First-draft completion

Interview first draft is complete when:

```text
board -> distinct interview scene -> persistent two-way exchange
     -> manager-readable subject state / notes
     -> return to board -> separate Make Offer transaction
```

and the architectural invariants above hold.

It does **not** require:
- a universal acceptance probability model;
- the full live block clock if that dependency is still being built;
- voice acting / elaborate animation;
- every possible life/career topic;
- a generic relationship/trust system.

Keep those as separate systems rather than filling their absence with hidden
numbers inside recruitment.
