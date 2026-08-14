# The desk, the phone, and what is wrong with a voli

A response to the desk/tone/quirks brief. Written as a reply rather than as a
spec: the parts I think are right and why, the parts I think are wrong and what
I would do instead, and the one place the brief contradicts something that was
built earlier the same week.

Nothing here is built yet. `docs/BACKLOG.md` is where the agreed items go.

---

## 0. The headline: §2 and §3 undo work from this session, and should

`MEDIUM_CARD` — manila stock, a fold and three cut edges, pencil on hover — was
built this session **for scouting**, because `TITLE_SCREEN.md` had said "the
folders are card" since the medium rule was first written and there had never
been a `card` to be made of. The scouting screen is now a drawer of folders.

§2 says scouting should be a cork board. §3 says the folder metaphor should move
to housing.

**I agree with both**, and the swap is cheap, because the medium is a separate
layer from the screen. `MEDIUM_CARD` is not thrown away — it moves to housing,
which is what §3 asks for. What gets rebuilt is one screen's layout, not the
substrate, the edge component, the stock colours or the pencil.

But the *reason* §2 is right is worth stating, because it is not "cork looks
more like scouting":

> A folder is a **container for one subject**. A board is a **surface where
> things accumulate and relate to each other**.

Scouting is the second thing. The brief's own list — connections between
players, clubs, agents and regions; unsolicited discoveries; reports awaiting
review — are all statements about *more than one voli at once*. My drawer is a
decent shortlist and it structurally forbids all of that: it can show you
exactly one open folder, because that is what a drawer is for.

Housing is the first thing. There is one property. Everything in §3's list is a
document about that one property. That is a folder.

So the swap is not a preference. Each metaphor is currently attached to the
system whose information shape it does not fit.

### The one thing that will go wrong

**Cork is already built and already in use.** `UICorkBoard` is the *training
clipboard's backing* — a clipboard is board with a smaller sheet clamped to it,
and the cork shows round all four edges.

If scouting becomes a cork board, cork does two jobs on one desk. That is
precisely the failure this repository keeps making and keeps documenting: the
clipboard first shipped as the journal with a different border, the whiteboard
was drafted with a warning not to build it off the form, and `SCOUTING.md` now
opens with the scouting screen having read as the planner. Three instances. A
fourth is available here for free.

The distinction has to be structural, not tonal:

| | training | scouting |
|---|---|---|
| what the cork is | a **backing**, mostly hidden under one clipped sheet | the **surface**, mostly visible |
| what is on it | one sheet, clamped, square to the board | many small things, pinned, at angles |
| the fastener | a steel clamp, one, at the top | pins, many, one per item |
| what it is for | writing on, standing up | arranging, and looking at all at once |

That is a real difference and it survives being drawn. But it has to be decided
before the board is built, because "scouting is cork too" is how you get two
clipboards.

---

## 1. §1, §10 — same language, different workspace

Agreed, and it is already the working rule; §1 mostly names it well. Two
additions I would make explicit, because both have already cost time here:

**The persistent grammar is a list, and it should be written down.** "Typography
hierarchy, colour meanings, controls, navigation, player identity, rating and
uncertainty presentation" is the right list. It is not currently enforced
anywhere — `UIStyleSystem` enforces *materials*, and the invariants above are
convention. The gap is how the scouting screen ended up with a 150px caption
column while the kitchen uses 84.

**A medium owns four things, not one.** Substrate, stock, divisions, and whose
hand made the marks. Every time this repo has produced two objects that read as
one, it was because only the fourth was changed, or only the edge. The desk
vocabulary in §1 should carry that table for each new object *before* it is
drawn.

### The ambient desk

The strongest idea in the brief, and the cheapest to get wrong.

The good version: the desk's state is **derived from real club state**, so
papers accumulating means there is genuinely a pile of unread things. The bad
version is a decorative layer that has to be kept in sync by hand, which drifts
in a week and then lies to the player.

Rule: nothing on the desk is a prop. Every object's appearance is a function of
data that already exists, or it is not drawn. A journal that looks marked-up
because there are unread entries is honest; a journal that looks marked-up
because it is week 12 is set dressing.

---

## 4. §4 — kitchen, and the problem it exposes in what I just built

§4's rule is right: *the desk holds the thing you would use to access the
responsibility, not a model of the room.*

This indicts the current work more sharply than the brief realises. I have just
built a **block of tofu you paint with a piping nozzle**. A manager does not
stand in the kitchen holding a piping bag. Taken literally, the block is exactly
the miniature-of-the-location §4 forbids — and the nozzle makes it worse,
because it puts the manager's hands in the food.

There is a resolution that keeps every line of it, and I think it is better than
what I built rather than a rescue of it:

> **It is not a block. It is a plan of a block, on a meal-plan pad, and you are
> marking it up.**

Everything survives that reading and several things improve:

- The three-quarter drawing becomes a **printed diagram** on the pad — the way a
  seating plan or a pitch diagram is printed on a form. Still the same
  projection, still the same click-to-place.
- The nozzle becomes a **marker width**, which is what it always was mechanically
  (a radius in cells).
- The paste gauges become an **allocation**, not a spoon. You are dividing the
  week's delivery on paper. That is a stronger fit for the existing rule that
  *only manual instruction guarantees the ratio* — you did not cook it exactly,
  you **specified** it exactly, in writing, and the kitchen followed the sheet.
- The desk object is a meal-plan pad, which is on §4's own list.

The one snag: the clipboard is already `form`, and a meal-plan pad made of
`form` is the two-objects-one-material trap again. The distinction I would draw
is **carbon-copy order pad** versus **session clipboard**: a pad is small, gummed
at the top, printed in one colour on tinted stock, and the sheet you keep is the
smudged second copy. That is a different object from a clipboard even though
both came off a press. It needs its own medium row before anything is drawn.

**I have not made this change.** The current build works and is worth seeing
before it is reframed; the reframe is layout and language, not model.

---

## 5–9. The phone

I think this is the best section in the brief and I would build it close to as
written. Four notes.

**§6, the intrusion panel must never take the input you were mid-way through.**
The concrete failure: the phone rings while the pointer is down, dragging a
nozzle across the block or a voli across the whiteboard. If the panel is a modal
that grabs focus, it eats the release, and the drag either never ends or ends
somewhere the player did not put it. The rule is: the panel is a decoration that
becomes clickable. It never grabs focus, never takes a scrim, and never fires
during a held pointer — a call arriving mid-drag waits for the button to come up.
This is a sentence now and a week later.

**§7, agreed without reservation**, and it is the part most games get wrong.
One caveat: "repeatedly ignoring a specific person could eventually affect
whether they volunteer informal information" is a **counter**, and a counter is a
number, and a number will eventually be surfaced by somebody adding a helpful
tooltip. Keep the mechanic; keep it off every screen, under §19's rule. The only
place it should ever be legible is in the caller's behaviour.

**§8, the split is right and the interesting half is what voicemail *loses*.**
The example is exactly the shape: live, the scout tells you Mendoza's agent has
been calling clubs and asks whether to look into it; on tape, you get "something
strange is happening with Mendoza" and have to spend the follow-up yourself. The
cost of not answering is a **turn**, not a penalty. That is the right currency
and it is one the day model does not have yet — which makes the phone dependent
on the day/hours work in the backlog, and worth sequencing after it.

**§9, agreed, and it is load-bearing rather than flavour.** If every call
matters, the ring is a notification and answering is automatic. The snail racing
call is what makes the confidential call land. I would go further than the brief:
some calls should be *actively not worth answering*, and the player should learn
that and be wrong about it occasionally.

---

## 11–12. Tone

Agreed, and the boundary in §12 — *impossible presentation, plausible
consequences* — is the right one and is stated better than I would have stated
it.

The three levels map onto machinery that already exists. Ordinary is the
simulation. Exaggerated is `TRAITS.md` and the rare/physical traits, which
already do "freakishly long limbs" and "attacks without an approach" as real
attribute consequences. Unexplained is new.

One risk worth naming: **`_test_world_aging`**. Twenty seasons, and it is the
only gate that notices a generation change leaking talent. If quirks touch
generation or simulation at all — and §15 says at least some do — they have to be
inside that gate, or a quirk that quietly raises everyone's ceiling will not be
caught by any of the other 1,600 checks.

---

## 13–19. Quirks

The layering is good and I would keep the six-way split as written. Attributes /
behavioural traits / rare traits / physical traits / personality / quirks, with
quirks answering *what the hell is going on with you*, is a clean division and
each layer has a different job.

### §19 is right, and it creates the problem §19 does not solve

"Do not quantify the mystery" is correct. The community-argument test —
*"I'm pretty sure Lurks makes blockers lose track of attackers, but I can't
prove it"* — is exactly the target.

But an effect that is invisible to the player **and unmeasured by the developer**
is indistinguishable from an effect that does not exist. That is this
repository's §0 failure in its purest form: a knob that cannot reach its own
stated range, doing nothing, silently. `ScoutingSystem.KNOWABILITY`'s entry for
the least observable category did nothing at all for months because a key was
spelled two ways, and a gate passed the whole time because it asserted the
function rather than the game.

The resolution is not to show the player a number. It is:

> Every quirk with a volleyball shadow gets a **measurement in the suite** and
> **no number in the interface**.

`Lurks` needs a gate that says: against low-awareness opponents, recognition of a
lurking attacker is measurably later than for an identical non-lurker; against
high-awareness opponents, it is not. That is a distribution, it is testable, and
the player never sees a percentage. A quirk without such a gate is either
characterisation-only — which §18 says half of them should be, and that is fine
and should be *declared* — or it is a bug waiting to be found by nobody.

So each quirk should carry one of two labels in its data: **characterisation** or
**shadowed**, and `shadowed` implies a gate exists. That is enforceable.

### §15, Lurks, and the cogniticons

The chain in §15 — quiet movement, low communicative body language, lower
attentional salience, opponents allocate less attention, poor-awareness opponents
lose track — is the right derivation and it lands on machinery that exists.
Translucency meaning *this observer has poor awareness of this player* rather
than *this player is transparent* is the correct reading and is consistent with
what cogniticons already are.

`Faces the Wrong Way` (§16) is the strongest of the lot for the same reason:
orientation and attention being decoupled is a real thing the perception model
can represent, and the opponent being wrong about it is an inference error rather
than a deception stat. If only one quirk gets a volleyball shadow first, I would
build that one, because it forces the perception model to separate two things it
may currently conflate.

### §18's distribution, and which third will rot

~50% characterisation / ~35% small consequence / ~15% genuinely ambiguous.

The 15% is the bucket that will not survive contact. Emergent ambiguity is very
hard to author and very easy to fail to notice; if `Knows` is implemented as "a
tag that sometimes fires", it will either never fire or fire constantly, and
either way nobody will report it as broken because it is *supposed* to be
inexplicable.

That third should be **authored events with a hand-written trigger**, not emergent
behaviour, at least to begin with. "Don't serve to 14" is a scripted scene with a
condition on it. Emergence can come later, once there is something to compare
against.

### Two small ones

**`Keeps Rocks` and `Collects` are the best ideas in §16** and neither needs a
mechanic. A record of a career expressed as a shelf of worthless objects is worth
more than most attributes for making a generated voli memorable, and it costs a
list.

**`Has a Nemesis`** wants the ambient desk from §1. The vending machine being
replaced is a desk event, not a squad screen event, and the two features make
each other better.

---

## What I would do, in order

1. **Finish the food work as it stands.** None of it is wasted under any reading
   of §4 — the model layer, the stores, the ratio-from-a-picture inversion and
   the projection are all independent of whether the object is a block or a plan
   of a block. Reframing it is layout and language.
2. **Write the medium row for the cork board and for the meal-plan pad**, both
   before either is drawn, with all four properties filled in — because the
   fourth instance of the two-objects-one-material failure is currently a free
   action.
3. **Swap the two metaphors.** Housing takes `MEDIUM_CARD` and becomes the
   property folder, with the existing floor plan reading as the plan enclosed
   with the lease. Scouting becomes the board.
4. **The desk itself**, which does not exist yet and which everything above
   assumes.
5. **Quirks, characterisation-only first.** Names, behaviours, social events, a
   `characterisation` / `shadowed` label, and no volleyball effects at all in the
   first pass. Then `Faces the Wrong Way` as the first shadowed one, with its
   gate.
6. **The phone**, after the day model, because its real currency is a turn spent
   and there are no turns yet.

## What I disagree with

Only one thing outright, and it is small: §4's list of access objects treats the
kitchen as an unsolved problem. I think it is solved by the pad reading above,
and I think the painted block is a better answer than a cafeteria menu or a
grocery ledger, because it is the only one of the four that makes the *decision*
visible rather than listing it.

Everything else I would build as written, with the two guards above: the cork has
to be structurally distinct from the clipboard's cork, and every shadowed quirk
has to be measured somewhere the player never looks.


---

# Addendum: the phone is a two-way interface, and calls are ordinary

Added after a later brief. The sections above design the phone as something that
*happens to you*; this is the half where you pick it up.

## The rule that changes the feel

**Phone calls are not rare. *Important* phone calls are rare.**

Ringing indicates a **synchronous** channel, not an important message. An
ordinary week holds several calls and most of them are not decisions:

> Scout: *"They aren't playing Savi tonight. Want me to stay?"*
> Chef: *"We're nearly out of Xérvyan paste."*
> Assistant: *"Still drilling short defence today?"*
> Voli: *"Can I swap rooms with Nara?"*
> Staff: *"We're taking break early for the snail racing finals. Coming?"*

and occasionally:

> Scout: *"Don't put this in writing. I think Uva wants out."*

The uncertainty is the value. The player decides whether to interrupt what they
were doing, and should sometimes be wrong. §9 above already argued this; the
addition is that it applies to *volume*, not only to the ratio of important
calls. Some calls should be actively not worth answering.

## Outgoing

```
PHONE
  CALL              staff · volis · scouts · other clubs · recruitment contacts
  ANSWERING MACHINE saved and missed
  RECENT            who you have been talking to
```

**Scout** — ask for progress, change the assignment, clarify a report, ask about
one voli, change the criteria, ask what they personally think, call them home,
sort out a mistake. Instead of a `[Clarify]` button on a report:

> *"Are you sure this is the right Kovarik?"*

**Coach / staff** — discuss training, change today's emphasis, ask about a voli,
clarify a responsibility, ask what is actually being drilled, deal with an error.

**Volis** — check in, discuss role, development, a living arrangement, a
roommate, follow up on something said before. The phone is *another* channel, not
a replacement for being in the room.

**Recruitment** — arrange an interview, follow up, modify an offer, ask for a
decision, answer a concern, contact another club. This is what joins the cork
board to the phone without a new screen between them.

## Phone against inbox

| | inbox | phone |
|---|---|---|
| persistence | keeps | passes |
| register | formal | conversational |
| timing | whenever | now |
| importance | legible | unknown until answered |
| good for | reports, documents, decisions that keep | clarification, things happening this minute |

The **answering machine** bridges them: a missed synchronous thing becomes
something you can come back to, minus what live conversation would have given
you. §8 above has the shape — live, the scout tells you what he suspects and
asks whether to look into it; on tape, *"something strange is happening with
Mendoza"* and you spend the follow-up yourself.

## Against the live clock

Ringing occupies real seconds, and pausing must freeze the remaining ring
window rather than rewind it. Miss the call, then pause, and you may investigate
what happened; you may not retroactively answer.

This is also where the interruption contract lands: a call is `attention` or
`interrupt` depending on the caller and the subject, and only `interrupt` stops
a fast-forward. See `THE_DAY_AND_THE_CLOCK.md` §3.3 — design all four levels,
drive two, ship no preferences screen.

## And it is how staff failure reaches the player

Not `SCOUT FAILURE EVENT [Resolve]`. The answering machine:

> *"Boss? Call me when you get this. I think I may have gone to the wrong hall."*

then a call back, then a conversation. `STAFF_AND_FALLIBILITY.md` §5.

## Still sequenced after the day model

Unchanged from §"What I would do, in order" above, and for the same reason: the
cost of not answering is **a turn**, not a penalty, and there are no turns until
the clock exists.
