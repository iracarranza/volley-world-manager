# Scouting

> An elite scout should not simply become a better search engine. They should
> become someone whose judgment the manager learns to trust.

Reviewed against `scripts/systems/scouting_system.gd`, which turns out to
already implement the hard half of this and to be missing one architectural
thing that everything else in the spec depends on.

## The half that is built, and built right

`ScoutingSystem` is not a stub. It already satisfies most of *scouting =
uncertainty reduction*, and it does so under three stated rules that are worth
repeating because the rest of this document has to preserve them:

1. **The fog is a view, never a copy.** Nothing writes an estimate onto a voli.
   `VolleyballPlayer` keeps the truth and every function is a pure
   transformation. One fact, one source.
2. **It is deterministic.** The estimate for a given voli and attribute is
   always the same number, hashed rather than drawn — otherwise a player closes
   and reopens the panel until the prospect looks good and the estimate is a
   slot machine.
3. **It is centred, and clamping breaks that.** `_fold` reflects off 1 and 100
   instead of clamping, because a symmetric error on a voli at 96 clamped to 100
   throws away half the distribution and makes every elite prospect read low.
   The suite measures this rather than trusting it.

Mapped against the spec:

| spec | code | state |
|---|---|---|
| repeated observation narrows the estimate | `OBSERVATION_WEEKS_TO_SATURATE`, `OBSERVATION_WEIGHT` | live |
| a range at first, a figure later | `reported_band` / `reports_precisely`, `PRECISE_REPORT_CONFIDENCE = 0.80` | live |
| potential stays uncertain | its own scale *and* floor — a floor alone made potential and ability equally knowable below 0.78 confidence, and the suite caught it | live |
| confidence stated to the player | `confidence_summary` — Certain / Confident / Fair read / Hazy / Guesswork | live |
| a bad scout gives a blurrier roster, not worse volis | `MAX_ERROR_POINTS`, and the whole design | live |
| the club's whole wheel, fogged | `fogged_profile` | live |

So the spec's headline example — *first observation B− to A, extended
observation B+ with high confidence* — is a thing this code does today.

## The gap everything else hangs off: beliefs have no owner

`scout_rating(staff)` returns **the best scout you employ**, and
`reported_value` salts its hash with `(player_id, attribute_key)` only.

The consequence is precise: **the club holds exactly one belief about each voli,
and two scouts cannot disagree.** The spec's *two scouts can observe the same
voli and legitimately reach different conclusions* is not a tuning change; it is
a change of what a belief belongs to.

The fix is small in code and large in meaning: salt the estimate with the
scout's id, and make confidence a per-scout quantity. Everything else in the
spec then becomes a function over *that*:

- **specialisation** is a per-channel multiplier on that scout's `error_width`;
- **knowledge and freshness** are per-region terms in that scout's confidence;
- **club familiarity** is a term that grows with `weeks_employed`;
- **two reports side by side** is just calling the same function twice.

Worth noting what survives: the "best, not sum" rule was chosen so that hiring
two mediocre scouts could not add up to a good one, and per-scout beliefs
*improve* on it rather than breaking it. Two scouts stop being a bigger number
and become two readings — which is the design goal, arrived at structurally.

**Three other systems are waiting on this one change**, which is worth stating
because it moves the item's priority above what its own section argues for:

- **Scout failure.** *"You scouted the wrong Kovarik"* is unrepresentable while
  there is one club belief per voli — there is no per-scout belief for the wrong
  one to live in. `STAFF_AND_FALLIBILITY.md` §3. (Volis only acquired surnames
  recently, so two confusably-named people are possible at all for the first
  time.)
- **The club's belief about an allergy**, which is a scouting belief with a
  different subject and must not be built as a second system with the same
  defect. `ACCOMMODATIONS_AND_CARE.md` §2.
- **Two reports side by side**, which this section already names.

## The rest of the gaps, cheapest first

### Different information takes different observation — the cheapest item here

Height immediate, athleticism quick, technique several viewings, behaviour
longer, adaptability and composure much longer, potential never certain, rare
traits only when demonstrated.

Today every observable attribute shares one `MAX_ERROR_POINTS` and only
potential is treated differently. This is a **per-channel knowability
multiplier** on `error_width` and nothing more — a table from attribute (or
attribute category) to a scalar. It is perhaps twenty lines, it makes scouting
feel completely different, and the machinery it plugs into is already correct.

*Build this first.* It is the largest change in the player's experience per line
of code in the whole spec.

The one entry that is not a multiplier is **rare traits, discovered only when
demonstrated**. That is not reduced uncertainty; it is a different epistemology —
you either saw them do it or you did not, and no amount of watching a voli who
has never had the chance will tell you.

That pairs exactly with what rare traits are for. `TRAITS.md` puts them at
roughly 2-4 per 260-voli cohort, assigned independently of quality, so most of
them sit on volis who may never demonstrate them. A rare capability that can only
be found by having been there when it happened is the strongest version of the
scouting fantasy this game can offer: not a number that narrows, but a thing you
saw.

### Scouting has no geography

`confidence()` takes `on_roster`, `weeks_observed`, `scout_rating`. There is no
regional term at all, and the scout's own `home_region` / `club_region` are
carried on `VolleyballStaffMember` and read by nothing.

Network / knowledge / freshness per region is a dictionary on the staff member
plus one term in `confidence()`. The data model for "where they are from and
where they are now" already exists for exactly this reason — the staff member's
comment says origin is not decoration for every role.

### Freshness has to widen, not merely stop narrowing

This is the subtlest thing in the spec and it needs stating as a rule:
**uncertainty that only ever falls is a countdown timer, not knowledge.**

`weeks_observed` only grows. A voli you scouted heavily two seasons ago and have
not seen since is, today, permanently well known — and they have trained, aged,
changed club and changed form since. Freshness must apply to *player estimates*
as well as to a scout's regional knowledge: time since last observation widens
the band back out, and it should widen faster on the things that change fastest
(form, condition) than on the things that do not (height, hand).

That single rule is also what stops the whole market becoming solved by season
four.

### Skill as question specificity is the largest genuinely new build

The 1★–5★ ladder is a *query vocabulary*, and the tiers are honest about their
own cost:

| tier | needs |
|---|---|
| 1★ broad | a sort over what the club already sees |
| 2★ conventional | grades and price — grades need `TEAM_ATTRIBUTE_WHEEL.md` step 3 |
| 3★ behavioural / physical | traits as a queryable type — `TRAITS.md` step 1 |
| 4★ developmental | position conversion potential, which `position_familiarity` and `FamiliaritySystem.similarity` half-support |
| 5★ interpretive | **other clubs' opinions of a voli**, which requires club entities and a public view that does not exist |

5★ is the one to be careful about. *"Find someone other clubs see as an OH who
could become the unconventional opposite our system needs"* requires the game to
model a consensus the manager can be right against. That is a real, buildable
thing — a public view is the aggregate of what everyone has observed — but it is
downstream of clubs existing, and it should not be promised earlier than that.

### Investigation assignments need a clock

*How good are they actually · what is their ceiling · why is their form poor ·
would they accept our dorms* — each of these is a good question and each needs
to cost something, or a manager asks all of them about everyone. The cost is
scout-weeks, which means it wants the day/appointment system that is already
sitting in the backlog. Until then an investigation is free and therefore not a
decision.

The accommodation questions are the interesting ones and they connect straight
to the club design: *would they tolerate our facilities* is a query against the
voli preference model that `CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §3 now
specifies — food, room, social time, hours. Those preferences should be scoutable
on exactly the same uncertainty machinery as attributes.

### Club familiarity is the same defect as `Early Riser`

`weeks_employed` is exported, saved, and read by nothing — the comment says it
is carried because future systems will need tenure and inventing it twice is how
one fact gets two sources. Correct instinct, and it now has its first customer.

What "understands what you are building" means concretely is available: the
manager's philosophy *is* `TeamPrinciples`, plus the traits they have signed
before, plus which signings worked. All three are in the save.

## Form versus underlying quality is where scouting and the wheel become one system

This is the most important connection in the two documents and it is worth being
explicit.

A strong scout's best trick, per the spec, is *"performance appears suppressed by
tactical role."* That is an estimate of **the gap the team wheel is being built
to display** — the difference between what a voli is and what they are currently
producing, made of tactical fit, role utilisation, form, confidence, fatigue and
context.

So the sequence is fixed by dependency, not preference: **build the wheel's
talent-versus-current split first, and the scout's most characterful ability
becomes a read on a quantity that already exists.** Building it the other way
round means inventing a suppression model for scouts and then discovering the
wheel needs the same one.

It also produces the spec's undervalued and overvalued players for free. A voli
whose current sits well below their talent is undervalued by the public view,
which only sees current. Nothing has to be authored.

## Two risks the spec does not name

### 1. Disagreement is noise unless the game keeps score

If two scouts disagree and the manager never finds out who was right, the second
opinion is a coin flip with extra words. What turns *a better search engine* into
*judgment you learn to trust* is *time plus a record*: the game has to remember
what each scout claimed, and let the truth arrive later.

That is a small persistent structure — scout id, voli id, week, what they said —
and it is the mechanism the spec's design goal actually requires. Without it the
whole specialisation and opinion layer is flavour. With it, a scout who was right
about three unconventional conversions is a character.

### 2. Per-scout bias collides with a rule that is currently tested

The existing fog is deliberately **centred**: a scout is as likely to overrate as
underrate, because a fog with a bias is a systematic lie that moves the whole
population's apparent quality with your scout's rating. The suite asserts it.

A specialist who is *systematically optimistic about athletes* is more
characterful than one who is merely more precise about them — and it breaks that
rule as written. The resolution is a restatement, not an exception: **bias may be
a property of a scout, never of the system.** The centredness test then becomes
"centred across scouts", and any individual scout may lean. That is a change to
what the suite asserts and it should be made deliberately, in one commit, with
the old assertion's reasoning preserved — it was protecting something real.

## Order

1. **Per-channel knowability.** Twenty lines, biggest experiential change, no
   architectural risk.
2. **Freshness that widens.** The rule that stops the market being solved.
3. **Give beliefs an owner** — salt by scout, confidence per scout. Everything
   below depends on it.
4. **Specialisation** as per-channel width scaling, and the centredness rule
   restated as centred-across-scouts.
5. **Geography** — knowledge, network and freshness per region on the staff
   member.
6. **The scout record**, so disagreement resolves and a scout can earn trust.
7. **Club familiarity**, off `weeks_employed` and `TeamPrinciples`.
8. **Form versus underlying**, after the wheel's talent/current split exists.
9. **Investigations**, when the day model can charge for them.
10. **The query ladder**, tier by tier, with 5★ waiting on clubs.

## Medium

The spec above says nothing about what this screen is made of, which is why the
screen was made of the wrong thing for as long as it existed. `CLAUDE.md` calls
it "Scouting folders" and `TITLE_SCREEN.md` has said since the medium rule was
first written that *"the clipboard is paper somebody drew on, **the folders are
card**"* — and there was no `card` medium, so the screen fell through to the
`drawn` default and rendered as the planner with different words on it.

`MEDIUM_CARD` is that medium. Its three claims, so that a later pass does not
"simplify" it back into a variant of one of the others:

**The substrate is the material.** Manila is unbleached pulp with the fibre
still in it. Every other medium's texture is something *done* to a surface — a
halftone is a printing screen, a form and a board are manufactured featureless —
and this one is the sheet itself. `UICardStock` and `card_fibre.gdshader` carry
it: short dark specks a pixel across, pale flecks where a bundle never took the
dye, and a slow mottle from how the pulp settled. Screen-space rather than
per-panel, because the folders came out of one box.

**There is no border.** What reads as a folder's edge is a **fold** on one side
and the thickness of the stock seen end-on on the other three. `UICreasedEdge`
draws exactly that: a valley and a lit shoulder for the crease, short inward
bands for the cut sides, and nothing on the folded side — the asymmetry is what
makes the eye read a folded sheet rather than a rectangle. No stitch, no nib, no
printed hairline.

**The hand is a pencil.** Each medium allows exactly one instrument, which is
how a hover affordance stays inside the object's vocabulary: cloth allows
nothing, paper takes a highlighter, a form takes marker and red pen over
machine-set type, a board takes four markers and a wipe. A folder is annotated
in pencil, because its contents change and pencil comes off. So hovering a
control here drags a graphite line under it — grey and slightly cold, skipping
where the tooth of the card stood proud of the tip.

### What the screen does with it

A drawer of folders down the left and the open one on the right. The tabs are
staggered on a three-position cut, which is not decoration: third-cut stock
alternates left, centre and right precisely because a column of tabs at one
position is a column you cannot read past the first entry.

The open folder stands **taller** than the rest rather than being coloured.
It was a toggle first, so the theme's pressed state — accent — said *this one is
open*; on a screen where one of the three marks is called "sign" and gets the
same accent when set, that put two different facts in one colour. A folder
pulled proud of the drawer is what you actually do to the one you are reading.

Inside is the six-category report, each figure with the word a scout would use
instead of it. The bands are measured against the distribution rather than
picked — 1,584 category scores off 24 generated rosters give p25 52, p50 63,
p75 72, so "worth the trip" at 72 is the top quarter and "not there yet" at 48
is the bottom sixth. The first draft guessed 68 and 42 from a half-remembered
"centred near 50"; 42 sits below the fifth percentile and a scout would have had
almost nothing bad to say about anybody.

That measurement also turned up a live defect. The category list was written
`Setting & Control` and `Mental & Tactical`, but `summary_profile` keys them
`Setting / Control` and `Mental / Tactical` — both spellings are load-bearing and
documented at `CATEGORY_ALIASES`, where the last thing to get it wrong was
`ScoutingSystem.KNOWABILITY`'s entry for the least observable category. A
`.get(category, 50.0)` answered for the missing keys, so every prospect read
*exactly* 50.0 on two of six categories, 264 of 264. The fallback is gone: a
category that stops being returned now prints "missing".


---

# Addendum: the board, the marks, and what is actually pinned to it

## The marks are annotations and must keep looking like it

`MARK_SIGN` / `MARK_WATCH` / `MARK_PASS` are **pin colours on a slip** — a
verdict a manager wrote down — not buttons that do anything. A brief once
proposed replacing "Sign" with a real recruitment action; that would have
deleted a working annotation, and the actual unilateral transaction was
`sign_transfer` on the transfers tab, on a different screen.

They stopped *reading* as annotations the moment a real action
(`Offer a place`) joined them in the panel footer: four identical adjacent
buttons, one of them a mark literally called *sign*, beside a button that signs.
Fixed presentationally rather than structurally — the word became **would
sign**, the group got the label **Pinned as**, the action was pushed to the far
end, and the pin colour moved *beside* the chosen word as a nine-pixel head
rather than tinting the lettering.

That last one took two attempts and the lesson generalises: **`MARK_PINS` are
colours chosen to read on cork, and a popup panel is not cork.** As 11px type on
the Mikasa panel the green sat at about 3.1:1 against 6.1 for the amber and 4.1
for the grey — so the most important of the three was the least legible. A value
read off the wrong surface. `RECRUITMENT_AND_THE_OFFER.md` §5.

## The board is currently showing the market

`_prospects()` checks `career.scouted_players` first — and **that field does not
exist on `career_state`**, so the check has always fallen through. It used to
fall through to the club's own roster, which meant a manager could open a slip
about somebody already asleep in their own Bunkhouse; it now falls through to
the transfer pool, which is at least somebody signable.

Neither is scouting. Until `scouted_players` is real, the board is a shop window
with pins in it rather than the imperfect-knowledge workspace this document
describes, and none of the freshness, specialisation or observation-cost work
above has anywhere to show itself.

**This belongs immediately after "give beliefs an owner"** in the order below: a
belief needs an owner, and then it needs to be about somebody a scout actually
went and looked at.

## What the offer added to the panel

The prospect panel now carries a third section, *If they came here* — the
proposed room, the floor arithmetic, what the club's paste means to this voli,
and what they would raise about it. It is scouting-adjacent rather than
scouting: everything in it is a fact about **the club**, computed at open, with
no uncertainty model over it. Documented in `RECRUITMENT_AND_THE_OFFER.md` §2.

The panel takes the whole page for a recruit and stays a window for anybody
else, because a report you can act on is a thing you sit down with.
