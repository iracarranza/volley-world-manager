# The tactical whiteboard

**The match centre has two presentations of one match, and they are not a
graphics setting.** `ABSTRACTION_AND_MANIFESTATION.md` is the general rule —
2D is the manager's compressed, actionable representation and 3D is where that
representation is *observed* becoming bodies — and the match centre is its
precedent. The court view is technically optional and is not decoration:
spacing, approach geometry, block timing and responsibility are often read
faster by watching than by reading a figure, which is why a court view that lies
about where a body could have been is a bad diagnostic instrument rather than a
cosmetic flaw.

Two things that rule does **not** license. The screen is still called the match
centre; only engine-flavoured labels like `3D MATCH ENGINE` want replacing. And
the vocabulary is not universal — match, drills and housing share the
*principle* and keep their own native language, so there is no global 2D/3D
toggle to build.

A fourth medium, and the one the whole match centre is made of — lock-in,
playback and the report after it.

## Why the match centre stops being the journal

The journal's argument is that it was kept by hand, over time, in private, and
everything in it is a record of something that already happened. The match
centre is the opposite on all three counts: it is written in front of the squad,
it is about the next ninety minutes, and it is wiped when they walk out.

Giving it a running stitch says it is a page in the diary. That is the same
mistake that once made the clipboard read as the journal with a different
outline, and it is worth restating why that happened: **a medium is a whole
material, not a border.** `drawn` failed as a clipboard because only its edge
changed. `board` will fail the same way if it is implemented by branching off
`MEDIUM_FORM` — the two share exactly one property, the absence of a halftone
screen, and nothing else.

| medium | substrate | divisions | who made the marks |
|---|---|---|---|
| `sewn` — the journal | halftone, warm cream, per-patch tint | running stitch | everything, by hand |
| `form` — the clipboard | flat stock, cooler, unscreened | printed hairlines, square corners, faint grid | only the annotation |
| `drawn` — default | halftone, pen edge | broad-nib pen | by hand |
| `board` — the match centre | melamine: cool near-white with a green cast, a faint wiped smear, no screen at all | marker rules drawn edge to edge; magnets, not borders | all of it, in four marker colours, minutes ago |

The smear is not decoration. It is the one thing that says the surface has been
used and will be used again, which is the whole difference between a whiteboard
and a sheet of paper.

## The two hands

**Yatra One** is the display face. Fat, uneven, bouncing — the only face in the
game that looks like a chisel-tip marker held at the wrong angle. Headings, slot
numbers, names, letter grades, condition states. Never running text; it has no
stamina for it.

**Short Stack** is the body face, as it is everywhere else, and labels are the
same face set uppercase and letterspaced. A whiteboard has two hands, not three.
Every figure sets in tabular figures, because the board is mostly columns.

Cherry Bomb One stays the heading face for the rest of the game and does not
appear here.

## The four markers

A tray holds four pens, so the palette is four.

| marker | means | and never means |
|---|---|---|
| black | everything unmarked | severity |
| blue | structure — court lines, slot numbers, rules | "good" |
| green | grade A or S; condition Working | anything else |
| amber | condition Laboured | a grade; there is no amber grade |
| red | grade D or E; condition Spent | structure |

One colour never carries two meanings. That is what lets a viewer read severity
off the board without reading any of the words.

## The lock-in board

The first inhabitant of the medium. Its content, its grade bands and the one
missing data field are specified in
`docs/design/CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §2 — including the
measurement that produced the bands and the reason there have to be two sets of
them.

The rule that governs everything on it: **figures, not sentences.** A board does
not editorialise. It says *7 aces, week 4* and lets the manager work out what
that means about who they should have brought. Announcing that a region serves
well, in the screen before the match that would have taught them, hands over the
conclusion and removes the reason to have watched.

Card anatomy, in short:

- **Condition** — the state word (`Working` / `Laboured` / `Spent`, the model's
  own three branches) with the raw fatigue beside it and a bar whose two
  hairlines are `LABOURED_ONSET` and `SPENT_ONSET` read from the constants, so
  the bar can never disagree with the word next to it.
- **Form, Conf** — `current_form` and `match_confidence` on a signed step. Those
  step boundaries are the same kind of threshold as the grades and need the same
  distribution work before they are chosen.
- **Slot** — `position_familiarity`, raw, for the slot they are in. A red `!`
  only when the slot they are actually in is low.
- **Six grades** — the Team wheel written out, because a card is too small for a
  wheel and a grade is what you compare across six cards.

## Playback and the report

Not yet drafted, and they are the rest of the medium. Two things are already
decided by the above and should not be re-litigated when they are:

- The caption layer is on the board too, and inherits *figures, not sentences*.
  A caption naming the term that decided a contact is a figure with a label. A
  caption characterising a team is not.
- The post-match report is the same surface after the match rather than a new
  object. It is the one place a whiteboard is allowed to be full.

## The whiteboard already existed, and it is recoverable

`scenes/components/whiteboard.gd` was a real class -- `UIWhiteboard` -- until
commit `4ddb38e` ("The workspace is graph paper worked in pencil, not a
whiteboard") renamed it to `worksheet.gd` and converted the training medium to
squared paper. That conversion was right for the *clipboard*: a whiteboard does
not get clipped to one, so the two are alternatives rather than a stack.

But it took the whiteboard's drawing with it, and when `MEDIUM_BOARD` was built
later it was rebuilt from this document rather than recovered from the code that
had already solved it. The two disagreed:

| | recovered original | rebuilt | which is right |
|---|---|---|---|
| nib min ratio | 0.34 | 0.88 | the original -- 0.88 is a ballpoint |
| tip angle | 31 deg | *absent* | the original |
| wander | 1.15 px | 0.62 px | the original; marker skates on melamine |
| stroke width | 7.0 | 7.4 | either |
| alpha | 0.72 | -- | the original, and unrecovered |

Ratio and wander are restored. **Still unrecovered:** the chisel *angle* -- how
the tip is held, which is what makes a stroke's width depend on its direction
rather than merely vary -- and `MARKER_ALPHA`, a marker laid over melamine being
translucent in a way a pen on paper is not. Both are in
`git show 4ddb38e^:scenes/components/whiteboard.gd`.

Also in there and worth reading before the lock-in screen and the match centre
are restyled: the **wipe**. The original's third principle was that a board
remembers -- a wipe never takes everything, so the previous layout stays as a
faint smear under the new one, and a phase change squeegees rather than cuts.
That is the property `CLAUDE.md` lists as "a wiped smear", it is the one that
makes the medium feel like a board rather than a dark page, and nothing in
`MEDIUM_BOARD` implements it.

### The roster cards, and the rest of the furniture

Also wanted back, and also in that history rather than in this document.
`7a31566` ("Roster tray, sticky note, and serve folded into the phases that own
it") is the commit that built the tray of roster cards and the sticky note; they
were not carried into the current lock-in screen, which grew its own list.

So the recovery list for the board is four things and only one of them is a
colour:

1. the chisel **angle** and `MARKER_ALPHA` -- `4ddb38e^:whiteboard.gd`
2. the **wipe**: a board remembers, a phase change squeegees
3. the **roster cards** and the sticky note -- `7a31566`
4. the four-marker palette, `MARKER_RED` among them

Read all four before restyling anything. The lock-in screen currently has a
list where it wants a tray, and a tray of cards is a different object -- you
pick one up, you do not scroll it.
