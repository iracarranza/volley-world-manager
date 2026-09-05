# Part 7 — Art, 3D Assets and the Drawn World

Everything a viewer actually sees. This part explains how a voli's body is
built, how a club is dressed, how the room around the court is made, and — most
importantly — **how to change any of it without breaking the checks that guard
it**.

## Why this part exists

Parts 1 to 6 explain a simulation. This part explains a *renderer*, and the two
obey different rules. A simulation is judged by whether its numbers are right.
A drawn body is judged by whether a person looking at it believes it, which is
not a property you can assert in a commit message — it has to be rendered and
looked at.

That difference produces the single most important habit in this part:

> **Render it. Do not reason about it.**

Every chapter here carries at least one worked failure where careful reasoning
produced a confident, wrong answer that one screenshot would have caught in
seconds.

## The chapters

1. [The Voli Body](01_the_voli_body.md) — silhouettes, body types, produce
   variants, and the mesh primitive vocabulary
2. [Kits, Colour and Marks](02_kits_colour_and_marks.md) — dressing a club, and
   the contrast gate that governs it
3. [The Court and the Venue](03_the_court_and_venue.md) — the room, its
   lighting, and its cameras
4. [Faces, Expressions and Cogniticons](04_faces_and_expressions.md) — the face
   rig and the marks that show what a voli is thinking
5. [Rendering, Probes and Validation](05_rendering_probes_and_validation.md) —
   the tool suite, and how to prove a change is right

## Prerequisites

- [P1-C3 Repository Map](../part_01_project/03_repository_map.md) — where art
  code lives relative to simulation code
- [P2-C1 GDScript Basics](../part_02_gdscript/01_gdscript_basics.md) —
  `const`, `static func`, and `preload`
- [P2-C3 Collections, Types and Null](../part_02_gdscript/03_collections_types_and_null.md)
  — every asset in this part is described by a `Dictionary` spec

## The one boundary that governs this whole part

**Presentation data must not live on a file the simulator reads.**

`RegionalKits` states the rule directly in its own header: a kit colour "decides
nothing and predicts nothing; it is only how a club is drawn." It is kept off
`regions.gd` — the table the world and simulation are built from — so that a
renderer can be rewritten without touching a file the simulator reads, and so a
region can gain a strip without raising a save-format question.

Apply the same test to anything you add here. Ask: *if I deleted this value,
would a rally resolve differently?* If yes, it does not belong in this part. If
no, it must not be stored where the simulator can reach it.

## Design documents behind this part

The textbook explains how the code works. These explain *why it is shaped that
way*, and you should read the relevant one before making a substantial change:

| Subject | Document |
|---|---|
| How a voli stands and dresses | [`THE_VOLI_BODY.md`](../../design/THE_VOLI_BODY.md) |
| Body types as a design system | [`BODY_TYPES.md`](../../design/BODY_TYPES.md) |
| Anything visual at all | [`UI_VISUAL_SYSTEM.md`](../../design/UI_VISUAL_SYSTEM.md) |
| What a voli is showing | [`COGNITICONS.md`](../../design/COGNITICONS.md) |
| Paired 2D/3D views | [`ABSTRACTION_AND_MANIFESTATION.md`](../../design/ABSTRACTION_AND_MANIFESTATION.md) |
