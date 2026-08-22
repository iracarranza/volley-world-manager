# 11 — Voli Stickers: 3D Rig to 2D Bake

Status: **VERIFIED CORE PIPELINE**

`UIVoliSticker` is a good example of the kind of system this textbook is meant to teach: it uses several Godot-specific ideas, but every one of them has an immediate reason to exist.

The job is simple to state:

> Take VWM's real posed 3D player body and turn it into a small 2D sticker that can sit on a worksheet/board while preserving the player's build, kit, handedness, pose, and view angle.

The resulting pipeline is roughly:

```text
player profile + pose request
→ queue
→ configure real PlayerActor3D
→ render it in a hidden SubViewport
→ read the image back
→ crop / shade / quantize
→ trace body + arm contours
→ build Sticker object
→ cache it
→ emit sticker_ready
```

The important point is that the worksheet does **not** redraw a generic stick figure from simulation metadata. It bakes the same underlying 3D player rig the rest of the game already owns.

## Start from the public boundary

The class begins:

```gdscript
class_name UIVoliSticker
extends Node
```

and exposes a request function that receives a key, event/pose information, a player profile, and view angles.

Before reading `_bake()`, read that boundary first:

```text
input:
  identity/profile
  event type
  pose phase/elevation
  camera yaw/pitch
  optional headshot

output later:
  cached Sticker + sticker_ready signal
```

That tells you this is an asynchronous producer, not a function that simply returns a texture immediately.

## Why the request is queued

The baker owns one reusable hidden viewport and one reusable player actor.

If several screens request many stickers, rebuilding an entire render rig for every request would be wasteful. Instead, `request()` checks whether the sticker already exists or is already pending, then appends a job to `_queue`.

Conceptually:

```text
request arrives
→ already baked? stop
→ already queued? stop
→ append job
→ if no worker active, start _pump()
```

**GDScript reminder — persistent members**

`_queue`, `_baked`, and `_working` are member variables. They survive after `request()` returns. That is what makes queueing possible.

The caller does not block waiting for completion. Completion is announced with the `sticker_ready` signal.

## `_pump()` and why frame timing matters

The pump takes jobs from the queue and calls `_bake()`.

A render job may need to wait for Godot to draw frames after the player pose/camera changes. This is why the code uses patterns such as:

```gdscript
await get_tree().process_frame
await RenderingServer.frame_post_draw
```

**GDScript reminder — `await`**

`await` suspends this function until the awaited event occurs. Here that is correctness, not cosmetic delay: changing a 3D pose and immediately reading the viewport texture can return an image from before the renderer processed the change.

The pump also deliberately yields between actual render jobs so a batch of sticker requests does not turn one main-loop frame into a multi-second freeze.

This is a useful distinction:

```text
algorithm works
≠
algorithm can safely run all its work in one frame
```

## The hidden render world

`_ensure_rig()` creates the bake setup only when first needed:

```gdscript
_viewport = SubViewport.new()
_viewport.transparent_bg = true
_viewport.own_world_3d = true
add_child(_viewport)

_actor = ACTOR_SCENE.instantiate() as PlayerActor3D
_viewport.add_child(_actor)

_camera = Camera3D.new()
_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
_viewport.add_child(_camera)
```

A `SubViewport` is a separate render target. It can render a scene into a texture even though that scene is not being shown directly as the main game view.

`own_world_3d = true` is important: the bake gets its own 3D world rather than accidentally sharing the parent scene's world and seeing unrelated court objects/lights.

**Godot reminder — runtime-created hierarchy**

You will not find this complete camera/light/viewport setup authored in a `.tscn`. The script creates it at runtime. The player itself *is* instantiated from `player_actor_3d.tscn`, so understanding the full system requires both scene and script inspection.

## Why the camera is orthographic

The bake camera uses:

```gdscript
_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
```

Orthographic projection removes perspective size distortion. That is useful because the sticker is meant to behave like a flat cutout/drawing, not a photograph whose near hand becomes much larger than the far shoulder.

It also lets the code derive physical sticker scale from the camera's world-space size and the crop rather than choosing a new arbitrary display height for every pose.

## Configure the actual player before posing

The bake does not render one generic body. It configures `PlayerActor3D` from the requested profile, including the player's id and physical/cosmetic profile.

This matters because VWM's player identity influences visible properties. An earlier version effectively configured every bake as the same player id, which produced different heights/poses of what was otherwise the same-looking voli.

The larger lesson is:

> if the visual output claims to represent a specific player, the player's real identity/profile must cross the boundary into the render system.

Do not recreate that identity downstream from partial metadata if the canonical profile already exists.

## Pose, then let the renderer catch up

The actor is posed using the same player rig behavior, then the code waits for frames before reading the viewport.

One historical bug is particularly instructive: the pose call itself can rotate the player to face the contact direction. For a court actor, that is correct. For a sticker requested from a chosen viewing angle, it overwrote the camera-facing orientation the baker wanted.

The fix was not to weaken the player's real pose behavior. The baker reapplies its **presentation yaw after posing**.

That is an important VWM boundary:

```text
court/player pose authority remains correct
↓
sticker renderer adapts presentation afterward
```

Presentation should accommodate authoritative state rather than changing the authoritative system merely because one view needs a different framing.

## The image is read back from the viewport

After the render is complete:

```gdscript
var image := _viewport.get_texture().get_image()
```

Now the system has ordinary image data rather than a live 3D scene.

From here, the sticker pipeline can crop, recolor/quantize, trace contours, and package the result for 2D drawing.

This boundary is conceptually clean:

```text
3D phase ends at image readback
2D image/contour phase begins
```

## Why the body is rendered flat

The source comments record an important visual experiment: a small lit/posterized 3D body became muddy because directional shading consumed too many of the few pixels available.

The final design instead relies on:

- flat body colors;
- silhouette/contour for form;
- limited palette quantization for a printed-ink look;
- separate shadow and border passes.

The sticker is therefore intentionally not "a tiny screenshot of the 3D voli."

It is a transformed representation:

```text
real rig geometry
+ real pose/identity
+ deliberately flattened rendering language
```

## The three visual layers

The class describes the finished sticker as three conceptual passes:

1. shadow — offset contour indicating thickness above the paper;
2. body — flat/quantized color image;
3. border — constant-weight traced die-cut edge.

That difference matters because VWM's worksheet drawing language treats court/net marks as drawing **in** the paper, while the voli sticker should read as an object sitting **on** the paper.

The visual style is therefore architecture, not just decoration: it distinguishes categories of information.

## Cache: why a render system needs one

A cold worksheet may request many stickers. The same player/pose/view/palette can be requested again across screens or sessions.

The baker therefore has:

```text
memory cache
+
disk cache at user://sticker_cache
```

**Godot reminder — `user://`**

`user://` is Godot's writable per-user application-data location. Unlike `res://`, it is appropriate for runtime-generated cache/save data.

The disk-cache key is derived from the inputs that change the appearance, not merely from the caller's friendly request key.

The job signature includes profile values, event/pose/view data, theme mode, and a fingerprint of source files that determine the bake's appearance.

That solves a subtle stale-cache problem:

```text
same request parameters
but sticker rendering code changed
→ old cached image must NOT silently survive
```

Instead of requiring a human to remember to bump a cache version number, the implementation fingerprints the relevant source files.

## Canonical signatures and Dictionary ordering

The job's `profile` is a Dictionary. Two Dictionaries may contain the same logical key/value pairs but have been inserted in a different order.

The cache signature sorts profile keys before joining them.

This is a small but important deterministic-programming lesson:

> a canonical representation must not depend on incidental construction order when order is not part of the meaning.

The same principle appears later in simulation fingerprints and controlled fixtures.

## Why preview tools may disable disk caching

Preview tools exist to inspect a rig that may have just changed. Serving yesterday's cached bake would make the tool lie about the current code.

So the system can disable disk cache for those contexts.

This is a general measurement rule:

```text
optimization that reuses old output
must not invalidate the instrument used to inspect new output
```

## Stop rendering when idle

After the queue drains, the baker disables the viewport's continuous rendering.

The rig stays allocated because rebuilding it is expensive, but there is no reason to render an invisible posed player every frame forever.

This separates two costs:

```text
keep reusable objects alive
≠
keep expensive processing active
```

That pattern is useful far beyond stickers.

## What belongs where

A useful authority map is:

```text
PlayerActor3D
owns actual player rig + poses

UIVoliSticker
owns how that rig becomes a sticker

worksheet / board
owns where and why the sticker is displayed
```

If a blocker pose is physically wrong, fix the pose/rig authority.

If the sticker contour is ugly but the pose is correct, fix `UIVoliSticker`.

If the sticker is placed at the wrong tactical location on a worksheet, fix the worksheet/consumer coordinate mapping.

Do not solve all three in the baker because it happens to touch the pixels.

## How to inspect the system in Godot

Open:

```text
scenes/components/player_actor_3d.tscn
```

to inspect the authored player hierarchy.

Open:

```text
scenes/components/voli_sticker.gd
```

to inspect the runtime-created bake rig and cache/image pipeline.

The hidden SubViewport and Camera3D are created by code, so you should not expect them to appear in the authored player scene.

For visual experiments, use the relevant preview/tool scene with disk caching disabled where appropriate; otherwise a cache hit may hide the change you are trying to inspect.

## Source-reading exercise

Read `request()`, `_pump()`, `_ensure_rig()`, and the beginning of `_bake()` and try to answer:

1. Why can `request()` return before the sticker exists?
2. What prevents duplicate requests?
3. Why is one actor/viewport reused?
4. Why does rendering require `await`?
5. Which data determines whether a disk-cache entry is still valid?
6. Why is view yaw reapplied after posing rather than changing `PlayerActor3D`?
7. Which bugs would belong in the player rig, sticker baker, and worksheet respectively?

If you can answer those from the source, you are not merely reading GDScript anymore—you are tracing ownership, lifetime, asynchronous work, caching, and presentation boundaries across a real Godot subsystem.