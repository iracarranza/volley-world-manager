# The title screen

The screen every session opens on, and the only one that is a **place** rather
than an object. Held ahead of the training work deliberately (`BACKLOG.md` §6a):
it sets the reading for everything after it.

> The earlier "ui write up" that started this is not recoverable verbatim -- it
> was a chat message and the conversation was compacted. What is written here is
> the concept as most recently stated, plus what is verifiable in the code today.
> Anything from the original writeup not restated here has been lost and should
> be re-confirmed before it is treated as settled.

## 1. One room, two functions

**Office and bedroom at once**, drawn top-down and abstracted.

Not a rendering of a room. Drawn in the journal's *materials* -- its paper, its
ruled lines, its ink, its stitches -- but not as a journal object: **no pages, no
outer cover, no spine.** The journal is a hand and a set of textures here, not a
book being depicted.

| Side | What is there |
|---|---|
| **Right** | The desk, seen with its chair. The journal sits on the **corner** of it. |
| **Left** | The floating shapes, and the player voli asleep in bed, in a randomly chosen pose. |

The two halves are the two things a manager's life is: the desk they work at and
the bed they do not get enough time in. §0.9 of `TACTICS_AND_TRAINING.md` makes
the day's hours a contested resource -- sleep is one of the claimants on training
time -- so a title screen showing both is the game's central tension stated
before a single button is pressed. It is not decoration that happens to be
thematic; it is the thesis.

## 2. What already exists

More than it looks. `scenes/components/ui_backdrop.gd` already draws, on every
screen:

- ruled paper lines across the sheet
- two torn paper scraps, angled, with lighter patches where tape held them
- a court doodle and a ball doodle in ink
- **a starburst sun in Molten, a crescent moon in Mikasa** -- the one element on
  the sheet that changes with the light
- a run of stitches

**Those are the floating shapes.** They exist, they are drawn by hand in code,
and they already obey the theme. The work is not to invent them; it is to
promote them from wallpaper into set dressing -- to arrange them as things in a
room rather than marks on a page behind one.

The sun and moon earn a second job here for free: the title screen is a bedroom,
and whether it is day or night outside the window is the same switch that
already picks between them.

Also in place:

- `PlayerActor3D` -- the voli rig, reading height, wingspan, stride and body
  type, with per-part colouring.
- `scripts/data/face_expressions.gd` -- eyes and mouths composing into named
  expressions.
- `body_type` on every generated voli, with the whole generation system behind
  it (`ATTRIBUTE_FIRST_GENERATION.md`, `BODY_TYPES.md`).

So the body a creator would produce already has a renderer. That was the open
question in the character-creator review and this concept closes it.

## 3. The medium rule has to be amended, not broken

`CLAUDE.md` says: *only the journal wears the stitched/scrapbook treatment.* Read
literally, this concept violates it -- a title screen in journal textures is
exactly what that rule forbids.

It does not violate the *reason* for the rule. That rule is about **objects on
the desk**: the clipboard is paper somebody drew on, the folders are card, and
each is a different medium so that picking one up feels like picking up a
different thing. The title screen is not an object on the desk. It is **the room
the desk is in**, and a room may be drawn in the journal's hand without being
the journal, the same way a sketchbook's cover and its pages are the same paper
doing two jobs.

State it that way in the rule, or the next pass will "fix" this back.

## 4. Which voli, and where it comes from

**Selecting a save changes the voli rendered.** This is the detail that makes the
screen belong to a career rather than to the game, and it has one concrete
obstacle.

`CareerManager._metadata()` writes career name, organization, type, region,
identity, week, date, reputation, next fixture and a timestamp. **Nothing about a
body.** No height, no `body_type`, no colouring, no face, no handedness. So as
things stand the title screen cannot draw the voli of a save it has not loaded,
and loading a full career JSON on every hover in the save list is not a thing to
do.

The fix is small and should be first: **add the manager voli's appearance to the
saved metadata block.** `list_save_metadata()` already reads every save's
metadata without loading its career, so once the fields are there the screen gets
them for free.

## 5. The sleeping pose is new work, and it does not look like it

Every pose in `player_actor_3d.gd` is keyed to a `RallyEvent.EventType` -- serve,
reception, set, attack, block, defence. **Sleeping is not a volleyball action**,
so it is the first pose in the game that is not one, and "a randomly chosen pose"
means several of them. Curled, sprawled, face-down, one arm off the edge. That is
a genuine addition to the rig's vocabulary and should be estimated as one rather
than assumed to come along with the screen.

**Randomly chosen needs a seed, not a roll.** If the pose re-rolls on every
return to the title, the voli twitches into a new position every time the player
backs out of a menu, which reads as a glitch rather than as sleep. Seed it from
the save and the in-world date: stable while you are looking at it, different
tomorrow. That is the same determinism the rest of the engine holds itself to,
and it turns a random pose into a small fact about that career.

## 6. A 2D room with a 3D voli in it

The room is hand-drawn 2D -- that is what `_draw` on a backdrop is, and it is
what makes the paper read as paper. The voli is a 3D rig. Those compose through a
`SubViewport`, and there is precedent in this repository already: the match
centre runs `SubViewportContainer/SubViewport/MatchCourt3D` inside an otherwise
flat screen.

The alternative -- drawing the voli flat as well -- throws away the body-type
system, which is most of what makes one save's voli distinguishable from
another's. Not worth it.

The composite needs deciding: a 3D body under a top-down 2D room wants either a
steep camera or an orthographic one, and the paper textures will read oddly
against a perspective figure. Worth a test render before the layout is committed.

## 7. The voli is not only asleep

**Helping during drills.** The same figure turns up in the §0.9 session, working.
This matters more than it sounds: it is what stops the title screen's voli from
being a portrait. A face you only ever see sleeping is decoration; a face you see
asleep at the title and then feeding balls at a session is a person who has a
day, and the day is the game.

It also gives the manager's parameters somewhere to land. §0.9's assistant coach
runs the sessions the player skips -- so the sessions the player *attends* are
where their own voli is visible on the floor, and that is the observable
consequence the character-creator review asked for in place of a hidden coaching
bonus.

## 8. Open

- The original writeup's other title-screen requirements, lost to compaction.
- Where the menu itself sits in a room that is now a picture. The existing screen
  is a brand column and a menu panel; neither is furniture.
- Whether the bed's occupant is the manager or a squad voli. "Player voli"
  reads as the manager's own avatar, which is what the character-creator concept
  implies, but the two readings put very different figures in the bed.
- Day or night: the sun/moon switch is currently the *theme*, not the *clock*.
  A bedroom argues they should be the same thing; a player who prefers Molten and
  plays at night would then be told it is morning.
