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

### 3.5 Why the interview is the next build

It is the **second manager appointment**. The drill session
(`hold_drill_session`, `training_day_is_today`) is the first. With two, the
shared temporal contract — start block, duration, manager occupation,
interruption and cancellation behaviour — can be *extracted from two working
systems* rather than invented in advance. See `THE_DAY_AND_THE_CLOCK.md` §11.

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

Because interviews are usually skipped, **the offer sheet is the primary
surface** and the interview *unlocks topics on it* rather than being a parallel
flow with its own presentation. Same content, one screen, and the skip case
costs nothing.

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

1. **The interview**, wrapping `offer_place`, charging manager time.
2. **`scouted_players`** — so the board is scouting rather than a market.
3. **Beliefs with an owner** — `SCOUTING.md` #3.
4. Money: a fee, a wage, and a negotiation that can fail.
