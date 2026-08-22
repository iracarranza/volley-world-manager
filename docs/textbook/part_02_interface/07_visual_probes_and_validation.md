# 07 — Visual Probes and Render Validation

Status: **VERIFIED METHOD**

Some questions cannot be answered by unit tests alone:

- Does a spike pose read clearly at match scale?
- Does a sticker silhouette still separate the arms from the torso?
- Does a dark-theme card preserve hierarchy?
- Does a gait foot visibly skate?

VWM uses dedicated preview/probe scenes so those questions can be asked in a controlled environment instead of by repeatedly playing a career and hoping the right frame appears.

## A preview is an instrument

A good preview fixes irrelevant variables and exposes the one you are judging.

Examples in `tools/` and `tools/preview/` include scenes for body types, stance transitions, animation frames, gait/plant behavior, poses and other visual checks.

A preview should answer a sentence such as:

> Draw this same blocker at the important phases of the jump so I can compare arm geometry.

not:

> Show me lots of stuff that looks useful.

## Visual versus numeric proof

A visual system can often be instrumented numerically too.

The foot-plant work is a strong pattern:

```text
visual symptom: shoe appears to skate
→ define measurable displacement while foot should be planted
→ probe multiple directions/speeds
→ compare before/after
→ still inspect the rendered movement
```

Numbers catch regressions that the eye may miss; the eye catches semantic/readability failures that a metric may not represent.

Use both when appropriate.

## Headless probes versus rendered previews

A Godot project can run with `--headless`, which is excellent for deterministic simulation and many code-level checks.

But a headless pass cannot tell you whether:

- text hierarchy reads well;
- an arm silhouette is clear;
- two shades are visually distinguishable;
- a transition feels abrupt.

Conversely, a screenshot looking good does not prove the underlying state is correct.

VWM boundary:

```text
headless test/probe
→ semantic/numeric correctness

rendered preview
→ visual legibility/presentation
```

Do not substitute one for the other.

## Runtime frame timing matters

Some visual systems need actual frames to advance.

`UIVoliSticker._bake()` uses `await get_tree().process_frame` and `RenderingServer.frame_post_draw` before reading the viewport image. A static script call cannot replace that sequence because the renderer has not produced the pixels yet.

Transition previews likewise may need to drive elapsed time explicitly because a still sheet has no natural animation clock.

**GDScript reminder:** `await` suspends only the current coroutine/function path; the engine continues processing until the awaited signal/event occurs.

## Cold versus warm performance

Sticker baking has two very different cases:

```text
cold request
→ pose + render + readback + contour work

warm request
→ cache/file read
```

A useful performance probe names which case it is measuring. Otherwise an optimization may merely have warmed a cache.

The same principle applies throughout development: state the initial condition.

## Screenshot fixtures

For a screenshot/preview fixture, control:

- viewport size;
- theme;
- player/profile data;
- camera angle;
- pose/event phase;
- seed where randomness exists;
- whether caches are enabled.

A fixture that changes all of these between runs cannot isolate a visual regression.

## Inspecting frame stalls

`Application`'s startup comments record a useful debugging pattern: a title-screen freeze was traced to screens that eagerly built sticker-heavy worksheets before the first useful frame.

The fix came from asking **where time was spent**, not from reducing random visual detail.

When the UI stalls:

1. determine whether the main thread is blocked;
2. measure construction/render frame times;
3. identify the expensive subsystem;
4. decide whether the work must happen now, can be cached, or can be made lazy;
5. verify the visible result is unchanged.

## A visual change still needs authority discipline

If a player's spike looks too low, first determine whether:

- the simulation's contact elevation is wrong;
- playback is ignoring correct elevation;
- the pose uses the wrong phase;
- camera/projection makes correct geometry unreadable.

Do **not** raise the drawn player if the simulation says the athlete never reached that height. Presentation may expose truth, not invent it.

This is one of the most important habits in VWM.

## Keeping tools honest

Preview tools sometimes deliberately bypass caches or force clocks. Record that explicitly.

For example, sticker preview tooling may disable disk cache because a tool intended to show a just-edited rig must not silently display yesterday's bake.

An instrument that is convenient but stale is worse than no instrument.

## Building a new preview

A useful pattern:

```gdscript
extends Node

func _ready() -> void:
    # construct deterministic fixture
    # print measurements
    # arrange visible samples if rendered
    # exit automatically if this is a headless probe
```

Keep fixture construction separate from production code. The preview should *call* the system under test, not recreate its algorithm.

## What belongs in a regression test

Once a visual investigation discovers a semantic invariant, move that invariant into an automated check if possible.

Examples:

- cache fingerprint changes when a pose source changes;
- a transition duration matches the simulation recovery duration;
- a player at contact retains the correct ground offset;
- theme change clears baked palette-dependent stickers.

Leave subjective composition (“this looks pleasantly balanced”) to review, but automate the facts underneath it.

## Source trail

- `tools/`
- `tools/preview/`
- `scenes/components/voli_sticker.gd`
- `scenes/components/player_actor_3d.gd`
- `scripts/systems/ui_style_system.gd`
- `tests/test_runner.gd`
- relevant `docs/review/` visual/pose notes

Part III moves from presentation into the objects being presented: players, attributes, body geometry, generation, regions and career state.