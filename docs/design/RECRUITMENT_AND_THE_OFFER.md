# Recruitment: the offer, and the interview in front of it

Signing somebody is asking them to join a **volleyball household**, not only a
side. This document is what that means mechanically, what is built, and what the
interview has to be when it arrives.

Status: **the offer is built; the interview is not.** `RecruitOffer` and
`CareerManager.offer_place` shipped; the offer sheet is on the scouting board's
prospect panel. The interview is the next build and is also the second manager
appointment the day model is waiting for.

---

## 0. Two corrections that reshaped this

Both were found by reading the code rather than the brief, and both changed
what the work was.

**"Sign" on the scouting board was never a button.** `MARK_SIGN` is one of three
*marks* — a pin colour on a slip, a verdict a manager wrote down. It works. The
brief that proposed replacing it would have deleted a functioning annotation.
See §5.

**The unilateral thing was `sign_transfer`, on the transfers tab.** One click,
free, no fee, no negotiation, no consent, and **no check that there was a bed**.
That was the actual target.

The rule this leaves behind: *before redesigning an interaction, find the
function that performs it.* The screen that looks like the transaction and the
function that is the transaction were on different pages.

---

## 1. What recruiting has to ask

Not only *is this voli good and can we afford them*, but:

> Do I want this person in our household, do they want to live here, and can the
> organisation actually provide the life and the role we are describing?

A club here is where a voli plays, trains, eats, sleeps, socialises, recovers and
lives. A transaction that asks only about the first two is asking a fraction of
the question.

So the verbs are:

```
SCOUT      →   INTERVIEW   →   MAKE OFFER
```

with the middle one optional (§4).

---

## 2. The offer sheet — built

`scripts/data/recruit_offer.gd` computes what joining would actually be, from
tables that already existed. It stores nothing and invents no attribute.

| what | from |
|---|---|
| the proposed room, the seat in it, who is already there | `Accommodation.STRUCTURES`, `rooms_occupied` |
| floor capacity, used, remaining, whether it crowds | `floor_used`, `crowding` |
| what the club's paste means to them | `FoodSupply.comfort_share` against the served block |
| what they would raise | derived from the above plus `homesick` |

**No preference attribute was invented.** Inventing a "sharing preference" and
then guessing its bands is `FAILURE_MODES.md` §0 in its most tempting form: a
knob that reads plausibly and can be checked against nothing. Every line is a
*reading* of a field the generator already fills.

**It is a function, not a record.** Terms are recomputed from the club whenever
asked, so an offer cannot go stale against a squad that grew or a supply line
that stopped — and nothing has to migrate when the interview arrives in front of
it.

### 2.1 The presentation rule this established

> **A physical fact about a room is countable and shows as a number. A judgment
> about a person is not, and shows as a sentence.**

```
Room     Bunkhouse 6, theirs alone
Floor    5, 1 in it uses 2, 3 left
The table    nothing on the block is theirs
"I'd have the room to myself, then?"
"What is it you eat here?"
```

Floor is arithmetic a manager could do themselves and being coy about it is
hiding a sum. What a voli makes of the table is not 0.43. The share exists and
drives the simulation; the manager gets the sentence.

The words are banded on `FoodSupply`'s **own** floor and ceiling, not on three
thresholds chosen for prose — so a sentence that disagrees with the discomfort
the voli's recovery is actually charged is a test failure, not a cosmetic drift.

### 2.2 Concerns are usually nothing

A list that always has four items is a form. A list that is normally empty and
occasionally says *"What is it you eat here?"* is a conversation. Every concern
is true of *this club and this person* — a crowded room, a Row that nobody meets
in, a block with none of their food on it, a long way from home — and a recruit
with none has nothing to ask.

### 2.3 The seam

`CareerManager.offer_place(player_id)` is one named function and that is its
point. When the interview exists it wraps this call and charges the manager's
time. When a voli gets a say, the refusal happens here. Neither needs the screen
rebuilt.

It returns the terms rather than storing them, because nothing reads a stored
offer yet and a record nothing reads is §0 at schema altitude. The room and the
table are computed for the sentence the manager is told, which *is* a read.

---

## 3. The interview — not built

### 3.1 It is a visit, not a trial

Scouting answers *how good is this voli and how might they fit*. The interview
answers *what would it actually be like for this voli to join this club*, and it
runs **both ways**: the manager evaluates the voli, and the voli evaluates the
club.

| scouting can estimate | the interview is for |
|---|---|
| ability, potential, role, physique | ambitions, expected responsibility |
| traits, tendencies, unusual capability | playing time, willingness to convert |
| likely system fit | why they are leaving |
| likely accommodation fit | housing, roommates, food, equipment |
| likely interest | care expectations, actual interest, worries |

**Volis speak.** Their statements are evidence, not a database read-out. An
interview that lists hidden variables is a spec sheet with quotation marks.

### 3.2 The voli asks too

*Where would I play? Am I starting? Why do you want me? Who would I live with?
Would I have my own room? What does everyone eat? Can you accommodate my
allergy? Who would be coaching me? What are you building? Who else are you
signing?*

The answers set expectations. **They are not locks.** Tell a recruit they are
the starting opposite and you can still bench them; there is no
`CANNOT_BENCH: RECRUITMENT_PROMISE`. The voli remembers, and reacts.

### 3.3 Not a persuasion minigame

There must be no correct dialogue option with a hidden `+15`. The meaningful
decision is **what am I willing to tell this person**, and the recruit weighs
the answer against their own personality, needs, career, alternatives, the
club's actual conditions and the manager's history.

A manager may overpromise. The consequence is that it was a promise.

### 3.4 No promise ledger

Tempting and wrong. A persistent per-voli record of manager statements is the
shape `THE_DESK_AND_THE_PHONE.md` §7 already warned about — *a counter is a
number, and a number will eventually be surfaced by somebody adding a helpful
tooltip.*

It is also unnecessary. The consequences are already systemic: a voli promised
allergy-safe food does not need a stored
`manager_promised_no_pawan` to notice whether the food stopped making them ill.
The simulation is the record. Where a promise genuinely has no simulated
consequence — *you'll start* — the reaction belongs to playing time actually
observed, not to a remembered sentence.

This does **not** prohibit the interview pad from carrying a visible
`Promises` section. That is the manager's human-readable note of an explicit
commitment made in this conversation, not a generic trust score or a hidden
numeric ledger. It records *what was said*; simulation consequences should
still come from the relevant expectation and the club's later behaviour rather
than from a universal `promise_points` system.

### 3.5 Why the interview is the next build

It is the **second manager appointment**. The drill session
(`hold_drill_session`, `training_day_is_today`) is the first. With two, the
shared temporal contract — start block, duration, manager occupation,
interruption and cancellation behaviour — can be *extracted from two working
systems* rather than invented in advance. See `THE_DAY_AND_THE_CLOCK.md` §11.

### 3.6 The screen must look like an interview

The interview is a **distinct conversational scene**, not the scouting
spreadsheet with a dialogue box attached to one side. The current exchange and
the person across the table are the primary visual objects. Previous exchanges
may recede; the player should not be surrounded by permanent CA/PA, attribute,
interest or personality panels while somebody is speaking.

The useful model is an across-the-table visit:

```
                         recruit

                  current exchange

            dossier   housing   offer

                         manager

                  questions / replies
```

The papers are not decorative. They divide kinds of knowledge:

- **documents** show facts the manager can actually check — a room, an occupant,
  a training schedule, an offer term;
- **conversation** shows what either person says, asks, accepts, resists or does
  not know.

When housing becomes relevant, pull the housing sheet forward. When role becomes
relevant, the manager can consult the dossier or rotation information. Do not
leave those data permanently open around the dialogue. The interview is a
conversation that occasionally needs management information, not a management
screen that happens to contain a conversation.

The candidate also owns turns. They can change the subject, ask a question,
return to something unresolved, or force the manager to answer rather than
letting the player drive an uninterrupted questionnaire.

### 3.7 The interview pad shows conversation state, not success

The player needs enough explicit state to manage the interview without being
told how the simulation evaluates it. A small interview pad is the primary
legibility device.

Use four marks:

| mark | meaning |
|---|---|
| `□` | not discussed |
| `✓` | discussed; there is a clear shared understanding / acceptance |
| `?` | discussed; unresolved, conditional or genuinely uncertain |
| `×` | discussed; an explicit objection or disagreement remains |

`×` does **not** mean "the recruit is unhappy" and `✓` does not mean "good
answer". Both report what happened in the exchange. If the recruit says a
competitive role is reasonable, that topic can close with `✓`. If they say they
will only move as a guaranteed starter and the manager will not offer that,
`×` is truthful. If neither person can answer yet, `?` stays `?`.

Example:

```
ROLE
✓ Primary position — Opposite
? Playing time — wants regular role
□ Position flexibility

LIFE HERE
✓ Housing — Bunkhouse 6, private room
? Distance from home
□ Food

PROMISES
• Playing time — regular starter
• Primary position — opposite
```

The `Promises` block is deliberately separate from the topic marks. A topic can
be settled without a promise (`✓ Playing time — understands role is
competitive`), and a promise records something the manager actively put on the
table. Ordinary facts do not become promises.

Do not add labels such as `YOU TOLD THEM`, `THEY WERE EXPLICIT`, `CONCERN
RESOLVED` or `INTERVIEW GOING WELL` when the mark and the note already show it.
The pad should resemble operational shorthand an interviewer would plausibly
write, not a translated transcript or a diagnostic overlay.

### 3.8 No interview-success meter

Do not expose:

- interview success / completion percentage;
- signing probability produced by the interview;
- trust, interest or relationship deltas;
- `+/-` feedback after a line;
- green/red "correct" responses;
- hidden-variable tooltips explaining what a reply changed.

Mechanically important feedback comes from several weaker but truthful signals
working together:

- the recruit's actual language;
- which questions they choose to ask next;
- whether they return to a subject;
- the pad's `□ / ✓ / ? / ×` state;
- pauses, posture and expression as secondary emphasis.

Expression must not become a meter encoded in animation. A smile is not `+5`;
crossed arms are not a universal failure state. The words and the direction of
the conversation carry the important information, while performance gives it
texture.

A recruit shifting from *whether this works* to concrete logistics — arrival,
housing, training — can be meaningful evidence that the conversation changed,
but it still is not an omniscient declaration that they will sign.

### 3.9 The checklist is not a completion objective

Nothing should reward the player for mechanically turning every `□` into a
`✓`. The interview is bounded by the manager appointment and by the other
person's participation, not by an arbitrary visible `questions remaining`
counter.

An interview occupies real manager time. The player can spend that time going
deep on one subject or broad across several, while the recruit also consumes the
conversation with their own questions and answers. The exact within-block pacing
belongs to the appointment implementation; the UI should not expose a question
budget merely because a bound exists.

Some `?` states are **genuinely irresolvable today**:

- the recruit does not yet know whether living far from home will suit them;
- playing time depends on preseason or another signing;
- the manager cannot yet name a roommate;
- the recruit is considering two clubs and has not decided what matters most.

Repeating a question does not roll again for more truth. The recruit may refer
back to what they already said or ask why the manager is circling it. A useful
follow-up asks a genuinely different thing; repetition cannot farm certainty.

A later interview can matter when something changed — the room is now known,
another player signed, preseason clarified a role, the recruit asks to speak
again. With no new context, a second visit should not reset the conversation or
turn uncertainty into information by persistence alone.

The intended managerial decision is therefore not *have I completed the
interview?* It is:

> I know these things, these remain uncertain, and we disagree here. Is that
> enough for me to make an offer, wait, or walk away?

There is no interview-completeness percentage.

### 3.10 Clear speech is still not ground truth

A `✓` means the conversation reached a clear understanding; it does not mean a
hidden personality variable has been revealed with certainty. A recruit can
sincerely say they are comfortable competing for a place and later discover
that being benched bothers them. They can think communal housing will be fine
and be wrong about themselves.

Keep three things distinct:

1. **facts** the club can inspect in its own records;
2. **claims / expectations** the recruit or manager states in the interview;
3. **beliefs** held by scouts, staff or the club about the person.

The interview improves what the manager knows because another person has told
them something and because concrete club facts have been discussed. It does not
turn a person into a fully revealed database row.

---

## 4. Interviews are not always required

```
SCOUT
  ↓
enough information?
  ├── yes → OFFER
  └── no  → INTERVIEW → OFFER or walk away
```

A voli may also request one before accepting. They earn their cost when the
signing is expensive, the region unfamiliar, the housing need unusual, a role
conversion is involved, an allergy is claimed, the personality is uncertain, or
the roommate situation is complicated.

Because interviews are usually skipped, **the offer sheet remains the primary
signing surface**. The interview is nevertheless its own conversational scene:
it does not duplicate the offer sheet as a second spreadsheet. It establishes
questions, answers, disagreements and commitments; the player then returns to
the offer with whatever the conversation actually established.

---

## 5. The board stays a board

The scouting corkboard is an imperfect-knowledge workspace: pin, mark, arrange,
compare. It is **not** the signing interface, and the three marks must keep
reading as annotations.

They stopped reading that way the moment a real action joined them in the
footer — four identical adjacent buttons, one of them a mark literally called
*sign*, beside a button that signs. Fixed by three things:

- the word: `sign` → **`would sign`**, because every mark is a verdict and the
  imperative only read as one while signing lived on another screen;
- the group is **named** — *Pinned as* — so the row says what kind of thing it
  is before the words are read;
- the action is pushed to the far end by an expanding spacer.

And the pin colour goes **beside** the chosen word as a nine-pixel head, not
into the lettering. Two attempts got there: tinting all three said *here are
three coloured words* when the truth is *one pin is stuck in this card*; tinting
only the chosen one left `3f7d52` as 11px type on the Mikasa panel at ~3.1:1,
against 6.1 for the amber and 4.1 for the grey. The error under both is
familiar — **`MARK_PINS` are colours picked to read on cork, and a popup panel
is not cork.** A value read off the wrong surface.

---

## 6. Where this is thin

**The board shows the market, not what your scouts found.** `_prospects()`
checks `career.scouted_players`, and that field **does not exist on
`career_state`**, so the check always falls through — now to the transfer pool,
which is at least somebody you could sign. Until it is real, the board is a shop
window with pins in it rather than the imperfect-knowledge workspace
`SCOUTING.md` describes.

**Beliefs have no owner.** `scout_rating(staff)` returns the best scout you
employ and estimates salt by `(player_id, attribute_key)` only, so the club holds
exactly one belief per voli and two scouts cannot disagree. That single change
unblocks three things: scout failure (`STAFF_AND_FALLIBILITY.md`), two reports
side by side (`SCOUTING.md` §3), and the club-belief third of the allergy split
(`ACCOMMODATIONS_AND_CARE.md` §2).

**Nothing about money.** `offer_place` charges nothing and negotiates nothing.
The asking figure is drawn on the card and ignored by the transaction.

---

## 7. The target fantasy

Sometimes:

> We can afford this excellent voli and we technically have room. But their
> room is crowded, they would not get on with the roommate, there is no floor
> left for the equipment they care about, our regular ratio does not suit them,
> they need an allergy accommodation, our chef is barely up to it, and the role
> they want belongs to somebody else. Do I still want them here?

And sometimes:

> This one is not the biggest name available. But they love the food, they
> already know one of the roommates, they like communal housing, our equipment
> suits them, they fit the tactical role exactly, and they actually want to live
> here.

A poor club should still be able to sign an exceptional voli it happens to suit.
A rich one should still be able to be a terrible fit.

---

## 8. Order

*Within this system.* `docs/BACKLOG.md` has volleyball fidelity as the
project's primary track and the interview as the one off-court item still open;
everything after item 1 below is held.

1. **The interview**, wrapping `offer_place`, charging manager time.
2. **`scouted_players`** — so the board is scouting rather than a market.
3. **Beliefs with an owner** — `SCOUTING.md` #3.
4. Money: a fee, a wage, and a negotiation that can fail.
