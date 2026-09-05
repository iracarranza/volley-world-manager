# P7-C2 — Kits, Colour and Marks

Status: **VERIFIED**
Keywords: kit, strip, region, contrast ratio, luminance, pattern, trim, marks, grayscale legibility
Primary sources: `scripts/data/regional_kits.gd`; `tests/test_runner.gd`; `scenes/components/player_actor_3d.gd`; `tools/run_venue_probe.gd`

## Prerequisites

- [P7-C1 The Voli Body](01_the_voli_body.md) — you are dressing the body built there
- [P1-C3 Repository Map](../part_01_project/03_repository_map.md) — why `scripts/data/` and not `scripts/world/`

## Learning goals

After this chapter you should be able to:

1. add a kit for a new region and prove it is legible;
2. compute the contrast ratio a kit must clear, by hand;
3. explain why kits are distinguished by **construction** rather than by hue;
4. say why the away strip is universal and light;
5. recognise the failure mode this whole system was built to prevent.

## Vocabulary

| Term | Meaning |
|---|---|
| **Kit / strip** | What a club wears. Home kits are per-region; the away kit is universal. |
| **Luminance** | Perceived brightness of a colour, `0.0`–`1.0`. Godot: `Color.get_luminance()`. |
| **Contrast ratio** | `(lighter + 0.05) / (darker + 0.05)` on luminances. Runs `1.0` (identical) to `21.0`. |
| **Pattern** | How a shirt is *built* — panels, ticks, bands. Survives grayscale. |
| **Trim** | How far the marks sit from the kit in value. Always lighter, because the kits are dark. |
| **Marks** | The drawn elements of a pattern, in front/back pairs. |
| **Reference** | `Landavol`'s pattern — the canonical strip every other kit deviates from. |

## 1. Where a kit lives, and why it lives there

`RegionalKits` (`scripts/data/regional_kits.gd`) owns every visual fact about a
club's clothing. Its header states the boundary this whole part rests on:

> a kit colour "decides nothing and predicts nothing; it is only how a club is
> drawn."

It is therefore kept off `regions.gd`, which the simulator reads. Two benefits
follow: a renderer can be rewritten without touching simulation data, and a
region can gain a strip without raising a save-format question.

**Before this file existed, every club in the world wore the same two colours.**
`player_actor_3d.gd` painted the torso from `UIPalette` keyed on `is_home_team`
alone, so a Xérvyan side and a Hitōuen side were the same teal. That is the
problem this chapter's system solves.

## 2. The home kits

Fourteen regions, one colour each:

```gdscript
const KITS := {
	"Landavol": Color("35393A"),
	"Spëddigh": Color("1F4E6B"),
	"Pāwa Hitō": Color("26355C"),
	...
	"Zaitgaist": Color("3E464E"),
}
```

**Every one is dark, and nothing sits in the middle.** That is a constraint, not
a coincidence. A kit is seen against a terracotta floor, and a midtone
disappears into it.

## 3. The gate: contrast against the floor, measured with the right instrument

`tests/test_runner.gd` asserts every kit separates from the court:

```gdscript
var floor_colour := Color(0.7451, 0.5098, 0.3725)
var lighter: float = maxf(kit.get_luminance(), floor_colour.get_luminance())
var darker: float = minf(kit.get_luminance(), floor_colour.get_luminance())
_check(
	(lighter + 0.05) / (darker + 0.05) >= 1.6,
	"%s's kit separates from the court floor" % region_name,
)
```

### Why 1.6, and why not 3

This is the most instructive number in the file, and the reasoning is worth
following closely because it is a pattern you will meet again.

The gate first shipped at **3:1** and **twelve of fourteen kits failed it**. The
figure had been carried over from the *court surface* pass — which compares a
floor against its own painted lines — and had never been measured against a
kit at all.

The real spread of working kits is **1.85 (Spëddigh) to 5.61 (A'ace)**. The
midtones the gate exists to catch — a tan, an olive, a mid grey — all score
**1.09 to 1.12**. So `1.6` sits below every real kit and well above every
failing one.

> **The general rule, from [`FAILURE_MODES.md`](../../FAILURE_MODES.md) §0:**
> *before shipping a threshold, measure the distribution it acts on.* A
> threshold outside its distribution does nothing, and does nothing silently. A
> threshold that rejects most of a working population is the same error with the
> sign flipped.

There is a second layer to the same mistake. The *first* kit palette was chosen
against the interface's own background, and nine of fourteen failed once they
were put on a court. **The ground you evaluate against is part of the
measurement.**

### Worked example: checking a kit by hand

Suppose you propose `Color("6B5A44")`, a mid tan, for a new region.

1. Its luminance is roughly `0.13`; the floor's is roughly `0.31`.
2. Contrast is `(0.31 + 0.05) / (0.13 + 0.05)` = `0.36 / 0.18` = **`2.0`**.
3. That clears `1.6`, so it passes — but it sits near the bottom of the range,
   below Spëddigh's `1.85`… which means you should look at it on a court before
   trusting the arithmetic.

The gate is a floor, not a certificate. It catches disasters; it does not
promise a good kit.

## 4. Construction, not colour

Once every kit is dark and clears the floor, hue can no longer tell them apart
without making them louder — and louder undoes the contrast work. So the real
identity is structural:

```gdscript
const BUILD := {
	"Landavol": {"pattern": "reference", "trim": 0.34},
	"Spëddigh": {"pattern": "ticks", "trim": 0.40},
	...
}
```

> "Panels, seams, bands and their spacing are value structure, so a side stays
> nameable in a black-and-white frame and at the distance a match is actually
> watched from."

**The grayscale test is the real test.** If you desaturate a frame and cannot
name the two sides, the kits have failed regardless of what the contrast gate
says.

Two details that carry design intent:

- `Landavol` is `"reference"` — *"not an absence of design: a placket and a
  collar, cleanly made, so it reads as the canonical strip rather than as one
  nobody finished."* A default must look chosen.
- `Spëddigh` is `"ticks"` — *"compressed and repeated… the same thing the region
  does to a rally."* A pattern is allowed to argue the region's identity.

## 5. The away strip

```gdscript
const AWAY_KIT := Color("E4E0D6")
```

One light colour for everybody. The reasoning is forced: every home kit is dark
by necessity, and *"two dark teams on one terracotta floor and nobody can tell
who touched the ball."*

Note what the header says about the future: the eventual version keeps each
region's **construction** in dark trim on this light ground. That is why the
pattern tables are keyed by **region** and not by kit colour — the data is
already shaped for a change that has not been made yet.

> **Reading tip.** When a table is keyed by something more specific than it
> currently needs, that is usually a deliberate affordance. Check the header
> before "simplifying" it.

## 6. Marks come in pairs

The suite also asserts that marks exist in front/back pairs:

> "Marks come in front/back pairs, because half of any frame is backs and a
> chest-only pattern left the closeup showing twelve unmarked shirts."

This is a good example of a bug that is invisible in the tool you design in
(a front-facing preview) and obvious in the product (a match, from behind).

## 7. Adding a kit: the procedure

1. **Add the colour** to `KITS`, dark, and away from the terracotta midtones.
2. **Add the construction** to `BUILD` — a `pattern` and a `trim`. Do not reuse
   another region's pattern; the point is that they differ.
3. **Add marks** in front/back pairs.
4. **Run the suite.** The contrast and pair gates are in `test_runner.gd`:
   ```bash
   godot --headless --path . --script res://tests/test_runner.gd
   ```
5. **Render it on a court**, because the gate is a floor and not a certificate:
   ```bash
   godot --path . res://tools/venue_probe.tscn
   ```
6. **Desaturate the render** and confirm you can still name the side.

## 8. Common mistakes

**Picking the colour against the wrong ground.** Nine of fourteen failed this
way once. Judge a kit against `Color(0.7451, 0.5098, 0.3725)`, not against your
editor's background.

**Widening a threshold to make a failure go away.** The 3:1 gate was wrong and
the *right* fix was to measure the distribution and re-derive it — not to
recolour twelve working kits. When a gate fails broadly, suspect the gate.

**Putting a kit colour where the simulator can read it.** If a rally would
resolve differently after you delete a value, it is not presentation data.

**Distinguishing kits by hue.** It does not survive distance, and the fix
(saturation) undoes the contrast work.

## 9. Check yourself

1. A kit scores `1.4` against the floor. What is the fix, and what is *not* the fix? *(Darken or lighten the kit; do not lower the gate.)*
2. Why is the away kit not per-region? *(Every home kit is dark, so the away side must be the light one; two dark sides are indistinguishable on terracotta.)*
3. You add a pattern that only marks the chest. What will the match look like? *(Half of every frame is backs — twelve unmarked shirts.)*
4. Why are `BUILD` and `MARKS` keyed by region rather than by colour? *(So construction survives a future change to a shared light away ground.)*
5. Compute the contrast for a kit of luminance `0.25`. *(`(0.31+0.05)/(0.25+0.05)` = `1.2` — a fail.)*

## Where this leads

- [P7-C3 The Court and the Venue](03_the_court_and_venue.md) — the ground you have been measuring against
- [P7-C5 Rendering, Probes and Validation](05_rendering_probes_and_validation.md) — `run_venue_probe.gd` in full
- [`UI_VISUAL_SYSTEM.md`](../../design/UI_VISUAL_SYSTEM.md) — the wider colour system
