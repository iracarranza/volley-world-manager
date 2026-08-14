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

~~**Not a portrait editor.**~~ **Retracted.** The bullet read: *the rig can draw
a body and it is a voli's body; building a second character pipeline for
somebody who never steps on court is the most expensive possible way to answer
"who am I".* Its own argument is what overturned it. There is no second
pipeline. `PlayerActor3D` draws six body types, five Vegi varieties, a colourway
table per body, five coats and nine faces, and **every one of those axes was
already a hash of a player id** — right for the forty volis the world generates,
wrong for the one the player is. The editor is the hash with a name on it.

What the bullet was actually protecting still holds and is now stated as its
own rule: a body here is **what you look like, not what you are good at**.
Height, arm length and leg length are drawn and read by nothing else. The
manager never steps on court, so none of the three reaches the simulator.

**Not a difficulty selector wearing a costume.** If a background grants +10% to
something, it is a difficulty setting and should be labelled as one.

## The proposal: four questions, and none of them is a number

### 0. What you look like

A voli, drawn with the rig that draws everybody else, and asked **first** —
before the club, before the region, before the philosophy. Nine axes, all of
them already authored:

| axis | where it comes from | what it was before |
|---|---|---|
| body type | `BodyTypeModels.MODELLED` | `physical_profile.body_type` |
| variety (Vegi only) | `PRODUCE` | `hash("vegi:%d")` |
| colourway | `PALETTES[body]` | `hash("palette:%s:%d")` |
| coat | `MARKINGS[body]` | `hash("marks:%d")` |
| face | `FaceExpressions.GRID` | `hash` per voli |
| height | 150–220 cm | `physical_profile.height_cm` |
| arm length | 0.80–1.26 × height | `wingspan_cm` |
| leg length | 0.86–1.16 × expected | `stride_length_m` |
| handedness | right / left | the clipboard's mirror |

**The two limb axes are proportions, not measurements**, and that is
load-bearing. The rig derives `arm_length_scale` from wingspan over height and
`leg_length_scale` from stride over what that height would ordinarily give — so
a slider dragged to "long-armed" means long-armed *for your size*, and the arms
keep their character when the height changes. Stored as centimetres the two
sliders would fight, and the one that lost would be whichever the rig read
second.

Their ends are the rig's own clamps restated, which is the §0 rule applied
before rather than after: `PlayerActor3D` clamps `arm_length_scale` to
0.78–1.24 and `leg_length_scale` to 0.86–1.16 *silently*, so a slider whose two
ends both land on a clamp is a control that does nothing and looks exactly like
one that works. There is a suite check that drags each slider to both ends,
draws the body, and fails if the two bodies are the same.

Also asked here: **your name**, offered from the region's naming tradition once
that is chosen, and **your coaching principles** — the seven axes that used to
be step three. Philosophy before geography changes what the third question
means: choosing a region *after* saying what you believe makes the alignment
number a consequence you walk into rather than a default you were handed. The
principles page therefore shows no regional fit or cohesion. Selecting a region
on the following page prompts you to confirm its alignment, familiarity and
starting cohesion before continuing.

### 1. Where you are from

One region, from the same fourteen — but asked as **two questions, tier
first**. Major or minor, and then which one.

The tier used to be a suffix: a "· minor" appended to six of fourteen tiles in
one grid. It is the largest single fact about a save — how many clubs there are,
whether founding is on the table, whether your best volis are watched by
academies that are not yours — and a fact that large answered by reading a badge
is a fact the interface declined to ask about. Two pages of eight and six also
give each region room for its own line, which fourteen tiles in a five-column
grid did not.

**One region still answers both questions today.** It is where you are from and
where you take a seat, and the doc's own next paragraph says those should
frequently differ — a Landavoli managing in Taktikã is a specific and
interesting position, and it is the position most managers in a real league are
in. The second picker is a straightforward reuse of the first and has not been
built; `create_career` already takes the two separately.

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
generated name is in the field when you arrive and you can type over it. It
lives on the first step now, beside the body, because a name and a face are one
answer.

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

1. ~~A `ManagerProfile` resource on the career: region, background, name.~~
   Built, and it now carries the body as well —
   `ManagerProfile.sanitise_appearance` bounds it and
   `appearance_profile` translates it into the dictionary
   `PlayerActor3D.configure` already takes.
2. ~~A step in `new_career_screen`, before the region choice — you exist before
   the club does.~~ Built. The builder is five questions: **you**, philosophy,
   origin (tier then region), foundation, signature.
3. The scouting familiarity term, which is one line in `confidence()` and is
   already on `SCOUTING.md`'s list under a different name. **Not built.**
   `manager_region` is stored and read by nothing.
4. The background effects, each of which is a change to a call already being
   made at career creation: roster age skew, scout count, starting finances,
   starting region knowledge. **Not built, and not asked for on screen** —
   `BACKGROUNDS` is a full table with a dominance gate over it and no question
   in the builder that sets it, so every save is `played`. It is the obvious
   next step and it is a *mechanical* question rather than an appearance one,
   which is why it did not come in with the body.

Nothing here needs new art or new simulation. The measurement instrument is
`tools/character_creation_shot.tscn`, which chooses four bodies, reads the
silhouette back out of the rig and fails loudly if a choice did not arrive —
the same argument the posture sheet makes, for the same reason: a picker whose
value never reaches the model and a picker that works look identical in a
still.

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
