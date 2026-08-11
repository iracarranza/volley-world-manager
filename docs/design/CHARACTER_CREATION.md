# Character creation

Who the manager is, and why the game should know.

## The problem, stated as it was observed

A save currently begins with a career name, a club name, a region, a seat and an
identity. Four of those five describe the *organisation*. The manager is a text
field.

That is not a missing feature so much as a missing addressee. Every screen in
this game is an object on a desk — a journal somebody keeps, a clipboard
somebody carries, a board somebody scrawls on minutes before a match. All of
those imply a somebody, and the interface has been drawing that person's
handwriting for months without ever saying who they are. `docs/BACKLOG.md`'s
"A character for the manager" entry is the same observation from the art side.

## What it must not be

**Not a stat block.** The moment the manager has numbers, every decision is
being made *by* the numbers rather than by the person reading the screen, and
the game stops being about judgement. Football Manager's coaching attributes are
the thing to avoid here, not the thing to copy.

**Not a portrait editor.** The rig can draw a body and it is a *voli's* body.
Building a second character pipeline for somebody who never steps on court is
the most expensive possible way to answer "who am I".

**Not a difficulty selector wearing a costume.** If a background grants +10% to
something, it is a difficulty setting and should be labelled as one.

## The proposal: three questions, and none of them is a number

### 1. Where you are from

One region, from the same fourteen. It is not the region you manage in and it
should frequently differ — a Landavoli managing in Taktikã is a specific and
interesting position, and it is the position most managers in a real league are
in.

What it does, mechanically, is small and entirely already-built:
`VolleyballRegions` carries naming traditions, demonyms, and principle weights.
A manager from a region reads that region's volis *slightly* better — a small
term in `ScoutingSystem.confidence` for volis whose `home_region` matches yours,
which is exactly the per-region knowledge term `SCOUTING.md` §"Scouting has no
geography" already asks for on staff members. The manager becomes the first
staff member rather than a separate concept.

And it is where your own name comes from, which is the part that matters more.

### 2. What you did before

Three or four backgrounds, and each one is a **starting position, not a bonus**.

| background | what it actually changes |
|---|---|
| **You played** | you know one position's volis better and the rest worse; your first club is somewhere you played |
| **You coached youth** | your starting squad skews young; you begin knowing your own roster unusually well and the world badly |
| **You analysed** | you start with a second scout instead of a better one; two readings from day one rather than one confident one |
| **You paid for it** | you found the club; more money, no standing, nobody has heard of you |

Every row is a redistribution. None is strictly better than another, and each
one is legible as a sentence about a person rather than as a modifier.

The fourth pairs exactly with the founding route in
`CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3 — founding is the hard route and
it should have a reason attached to it.

### 3. What you are called

Name, drawn by default from your region's naming tradition, which already
exists in `DEFINITIONS[region].names`. Offered rather than imposed: the
generated name is in the field when you arrive and you can type over it.

This is the whole of the "editor". No face, no body, no sliders.

## Where the manager appears

Answering "who am I" is worth very little if the answer is never on screen
again. Three places, all cheap, all things that already draw text:

- **The journal is yours.** Its heading currently names the club. It should name
  you, because a journal is kept by a person.
- **The board is in your hand.** `MEDIUM_BOARD` already says every mark on the
  whiteboard was made by one person minutes ago. That person now has a name.
- **Volis address you.** The cogniticon vocabulary is non-verbal by design, but
  the scouting folders and the transfer flow both produce text, and text about a
  person can use their name.

## What this needs

1. A `ManagerProfile` resource on the career: region, background, name. Three
   fields and a round-trip.
2. A fourth step in `new_career_screen`, before the region choice — you exist
   before the club does.
3. The scouting familiarity term, which is one line in `confidence()` and is
   already on `SCOUTING.md`'s list under a different name.
4. The background effects, each of which is a change to a call already being
   made at career creation: roster age skew, scout count, starting finances,
   starting region knowledge.

Nothing here needs new art, new simulation, or a new screen after the first.

## Deliberately unresolved

- Whether the manager ages, retires, or can be sacked. Sacking implies a board,
  a board implies expectations, and expectations imply a season structure this
  game has not settled. Worth leaving until the Sixnet calendar is real.
- Whether background is visible to other clubs — whether "you played" makes a
  voli more willing to sign. It should, eventually; it needs the retention loop
  in `ACCOMMODATIONS_AND_CARE.md` §6 to exist first, because that is where a
  voli's reasons for staying or leaving get added up.
- Whether a second save in the same world can be a *different* manager, which
  is the most interesting version of this and the one that needs the world to
  outlive a career.
