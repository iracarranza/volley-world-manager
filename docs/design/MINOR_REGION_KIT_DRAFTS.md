# Minor region kits — construction drafts

Written 2026-08-16, on `6b1f316`. **Nothing here is applied.**

`regional_kits.gd` says it plainly:

> **Named, rather than silently borrowed.** Six minor regions have no drawn strip
> yet, and the honest state is that they wear the reference build — not that they
> wear Landavol's. The distinction matters the day one of them gets its own: this
> constant is the list of what is still owed.

This is that list, paid. Unlike the principles question next door, this one has
**no simulation risk at all** — a kit decides nothing and predicts nothing, which
is why the table lives outside `regions.gd` in the first place. The only thing a
wrong answer here costs is a shirt that reads badly.

---

## 1. What the vocabulary can and cannot say

Read out of `player_actor_3d.gd::_build_kit_marks` rather than assumed, because
three of the drafts below started as things the format cannot express.

A mark is `[size: Vector3, offset: Vector3]`, built as a `BoxMesh` parented to the
torso. That means:

- **axis-aligned only.** No rotation is passed, so there is no diagonal, no
  chevron, no sash, no V. Every existing pattern is horizontals, verticals, or
  boxes, and that is not a style choice — it is the whole available alphabet.
- **`marks_for` mirrors each mark round the body**, negating `x` and `z` for the
  back face. A mark listed at front-right therefore appears correctly on the
  wearer's right when seen from behind. Left–right pairs on the *front* must be
  listed twice, as `panels` does.
- **`z = 0.112` is just clear of the torso surface**; the chest field is about
  0.42 across and 0.5 tall.

Adding rotation is a two-line change (a third tuple element, defaulting to zero)
and would open diagonals for a later pass. **It is deliberately not proposed
here**, because none of the six drafts needs it and adding an axis nothing uses is
the defect this project has a document about.

### One stale figure found in passing

`_build_kit_marks`'s comment says *"eight boxes at the very most, on a rig that
already builds forty."* `ticks` generates eight *front* marks and `marks_for`
mirrors every one, so a Spëddigh voli wears **sixteen**. The comment counts the
front of the shirt. Twice the stated figure is still cheap and the conclusion
holds; the number is simply wrong and should read sixteen.

---

## 2. What the existing eight already own

A new construction is only worth having if it is not one of these at distance and
in grayscale.

| pattern | region | silhouette | property it owns |
|---|---|---|---|
| `reference` | Landavol | placket + one chest bar | the canonical strip |
| `ticks` | Spëddigh | 8 short bars, paired, tight | compression and repetition |
| `panels` | Pāwa Hitō | 2 broad flanking verticals | mass and motion |
| `columns` | Blôc du Larg | 3 narrow full-height verticals | even structure |
| `rhythm` | Xérvu | 5 wide horizontals, uneven gaps | a beat that is not a metronome |
| `seams` | Taktikã | 2 thin horizontals + 1 vertical | geometric exactness |
| `heritage` | Ĭspayk | 1 broad chest band | age, and nothing added since |
| `sponsored` | A'ace | chest bar + 2 small + lower bar | commerce, applied to a shirt |

**Every one of the eight is symmetric about the centreline, and every one puts
something on it.** Those are the two largest unclaimed properties, and two of the
drafts below take one each.

Other unclaimed properties: a frame with nothing inside it; a spacing that
*changes* across the shirt; vertical top- or bottom-weighting; a count past ten.

---

## 3. Draft 1 — five constructions and one rule

The recommendation. Each says something abstract and true about how the region
plays, in the register the existing eight use — `columns` is not a picture of a
wall, it is evenness.

### `offset` — Tãul ys Feynt (deception)

**Asymmetry, the largest unclaimed property in the table.** The reference build,
made wrong on purpose: the placket sits off the centreline and the chest bar runs
from one side and stops before it reaches the other. It reads as an ordinary strip
until you actually look at it, which is the region's entire thesis about a
volleyball.

```gdscript
"offset": [
    [Vector3(0.035, 0.34, 0.01), Vector3(0.065, 0.02, 0.115)],
    [Vector3(0.17, 0.035, 0.01), Vector3(-0.075, 0.20, 0.108)],
],
```

`trim: 0.26` — the quietest in the world. You are not supposed to notice.

### `strata` — Lo-ong Ralī (endurance defence)

**A spacing that changes**, which nothing else has. Thin full-width horizontals
whose gaps tighten as they descend — 0.075 down to 0.035. Xérvu's `rhythm` is
uneven and keeps a beat; this is monotonically compressing, and at distance the
two do not read alike because one is five wide bars and this is six thin ones
converging.

Generated rather than listed, per the file's own rule that a pattern whose
character is a count and a spacing must not be writable one position at a time.

```gdscript
"strata":
    var gap := [0.075, 0.065, 0.055, 0.045, 0.035]
    var y := 0.20
    front.append([Vector3(0.34, 0.014, 0.01), Vector3(0.0, y, 0.112)])
    for step in gap:
        y -= float(step)
        front.append([Vector3(0.34, 0.014, 0.01), Vector3(0.0, y, 0.112)])
```

`trim: 0.32`.

### `repeat` — Bompaçao (the platform)

**A count past ten**, which nothing else reaches. Twelve identical small squares
in an even three-by-four field: one mark, made thousands of times, which is
literally what the region does to its passers. Spëddigh's `ticks` is *compressed*
— short bars crowded in pairs; this is *uniform* — the same square, the same gap,
everywhere, with no grouping at all.

```gdscript
"repeat":
    for row in range(4):
        for col in [-1.0, 0.0, 1.0]:
            front.append([
                Vector3(0.05, 0.05, 0.011),
                Vector3(col * 0.12, 0.18 - float(row) * 0.10, 0.112),
            ])
```

`trim: 0.38` — barrio courts, and the loudest of the five.

### `lead` — Rhėn Tempaol (first tempo)

**Top-weighting.** Three bars crowded above the chest line and *nothing at all
below it* — a shirt whose whole construction has already happened by the time your
eye reaches the middle. Every existing pattern is either centred or runs the full
height, so an empty lower half is unclaimed and it is exactly the region: it is
over before you are ready.

```gdscript
"lead": [
    [Vector3(0.30, 0.022, 0.011), Vector3(0.0, 0.215, 0.112)],
    [Vector3(0.30, 0.022, 0.011), Vector3(0.0, 0.175, 0.112)],
    [Vector3(0.30, 0.022, 0.011), Vector3(0.0, 0.135, 0.112)],
],
```

`trim: 0.30`.

### `corners` — Kutré Lyn (placement)

**Nothing on the centreline** — the second unclaimed property, and the one that
makes this kit unmistakable at any distance. Four small marks at the four corners
of the chest field, and the middle of the shirt is empty. A tradition that treats
the hard swing as an admission of failure does not put anything through the
middle.

Listed four times rather than two, because `marks_for` mirrors to the *back*, not
to the other side of the front.

```gdscript
"corners": [
    [Vector3(0.055, 0.055, 0.011), Vector3(-0.145, 0.19, 0.112)],
    [Vector3(0.055, 0.055, 0.011), Vector3(0.145, 0.19, 0.112)],
    [Vector3(0.055, 0.055, 0.011), Vector3(-0.145, -0.19, 0.112)],
    [Vector3(0.055, 0.055, 0.011), Vector3(0.145, -0.19, 0.112)],
],
```

`trim: 0.44` — technical schools, crisply marked.

### Zaitgaist — a rule, not an entry

**It should not get a table row, and giving it one would be the defect.**

Its specialty comes from `region_overlay`, rewritten each season by
`SixnetLeague.apply_influence_drift()` to mirror whoever last won. Tradition
resistance is 0.0. Position affinity is flat *on purpose*. Writing a permanent
construction for the region defined by not having one is a contradiction in the
data.

So `pattern_for("Zaitgaist")` should return **the reigning Sixnet champion's
pattern**, falling back to `reference` before a champion exists — and that
fallback is finally honest, because "no zeitgeist yet" is the true state in
season one.

`trim: 0.22`, its own and lowest in the world, kept even when the pattern is
borrowed. **The construction is this season's; the making of it is cheap.** That
one detail is also what stops a Zaitgaist side being mistaken for the champion's
on court: same build, fainter marks.

> This is the second system in two days where Zaitgaist's answer turns out to be
> *look it up from the champion* rather than *store seven numbers* — see
> `MINOR_REGION_PRINCIPLES_DRAFTS.md` §4. Two unrelated systems reaching the same
> rule independently is the best evidence available that the rule is right rather
> than convenient.

---

## 4. Draft 2 — the tier wears a tier

The alternative worth stating, because it is coherent and cheaper and might be
truer.

Give all six minors **one shared reduced language**: a single mark, in a different
place per region. No generated patterns, no counts, one box each.

| region | mark |
|---|---|
| Tãul ys Feynt | one short bar, off-centre, high |
| Lo-ong Ralī | one thin bar, full width, low |
| Bompaçao | one square, centred |
| Rhėn Tempaol | one bar at the collar line |
| Kutré Lyn | one square, upper left |
| Zaitgaist | none at all |

**The claim:** a minor programme has one club shop and buys plain shirts. The
*tier* becomes visible on court — you can tell a Sixnet side from a minor side
before you can tell which minor side — and that is a real piece of information a
manager would want.

**The cost:** the six regions become hard to tell apart from each other, which is
the opposite of what the kit system was built for. And it decides, visually, that
the minor tier is lesser — which `REGIONAL_STRENGTH_AND_MINOR_REGIONS.md` is
careful *not* to say about Bompaçao ("the most likely of these to mount a Sixnet
challenge").

Cheap to build, hard to undo once players have learned to read it.

---

## 5. Draft 3 — inherit from the connected major

The third option, and the one with a mechanism already in the codebase.

Every minor region has a connected major and a `REGION_TRADITION_RESISTANCE`
value, and influence drift already moves specialty between them. So a minor's kit
could be **its connected major's construction at its own trim**, exactly as Draft 1
proposes for Zaitgaist alone:

| region | connected major | inherited build |
|---|---|---|
| Tãul ys Feynt | Taktikã | `seams` |
| Lo-ong Ralī | Pāwa Hitō | `panels` |
| Bompaçao | Blôc du Larg | `columns` |
| Rhėn Tempaol | Spëddigh | `ticks` |
| Kutré Lyn | Xérvu | `rhythm` |
| Zaitgaist | — | the champion's |

Zero new geometry. Consistent with a system that already exists. And **wrong**, on
inspection: Lo-ong Ralī in Pāwa Hitō's broad athletic panels is a mountain
defensive tradition wearing a power region's shirt, and the doc is explicit that
Pāwa Hitō is the region Lo-ong Ralī was designed as the *contrast* to. Adjacency
governs how traditions drift, not what a club has always worn.

Listed because it looks obviously correct until you check one row, which is the
reason to check rows.

---

## 6. Recommendation

**Draft 1.** Five constructions, each taking a property the table does not yet
have, plus the Zaitgaist rule. Roughly forty lines in `regional_kits.gd`, two of
them generated patterns in `marks_for`, no change to `player_actor_3d.gd` and no
change to anything the simulator reads.

Verification is a render, not a suite: `tools/venue_probe.tscn` draws the kits and
is the instrument all eight existing patterns were reviewed in. The one thing to
check that a render will not tell you is `_test_regional_kits`, and it has two
clauses that touch this:

- the **court-floor contrast** check reads `KITS`, and all fourteen colours are
  already in the table and already passing. **This draft adds no colours.**
- `_check(not marks.is_empty(), "%s's kit is built from marks")` runs for every
  region, which is the clause the Zaitgaist rule has to survive. It does: with no
  champion the lookup falls to `reference`, which has marks. Worth knowing before
  writing the rule, because a lookup that returned an empty pattern name would
  fail this on a table that looks complete.

Ship the stale `eight boxes` comment correction with it.
