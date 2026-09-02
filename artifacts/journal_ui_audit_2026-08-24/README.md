# Journal UI render audit — 2026-08-24

## Scope and standard

This audit reviews the existing `journal_shot.tscn` output without changing the
production UI or probe. The standard is `docs/design/DIEGETIC_MANAGEMENT.md`:
the journal is organized working knowledge, dense is allowed, and its craft
layer should personalize that information architecture rather than replace it.

Rendered artifacts:

- [Mikasa / dark — Club / Staff](journal_mikasa_club.png)
- [Mikasa / dark — Team / Overview](journal_mikasa_team.png)
- [Molten / light — Club / Staff](journal_molten_club.png)
- [Molten / light — Team / Overview](journal_molten_team.png)

## Probe coverage caveat

The probe successfully renders four 1280×720 images in both themes. Club opens
on **Staff**, but Team opens on **Overview**. Consequently these artifacts do
**not** show a roster row, a selected voli, or a voli detail pane. They cannot
validate whether Team currently reads as “roster → selected voli → details.”
The visible Team page instead reads as “club summary → starting six / attribute
chart → club facts.” This is a probe-coverage gap, not evidence that the
unrendered roster flow is unclear. No probe repair was needed and no code was
changed.

## Classification

### KEEP — the craft treatment improves comprehension or identity

- **The journal/cloth page is a coherent enclosing object in both themes.** The
  stitched perimeter and restrained halftone establish “working book” without
  breaking the major left/content/right columns. The border remains peripheral
  rather than masquerading as data.
- **Paper tabs communicate section grouping conventionally.** Staff,
  Accommodations, and Sponsorships read as local Club subsections; Overview,
  Individual Training, and Team Training do the same for Team. The selected tab
  joining the page is a useful physical metaphor, not decoration substituting
  for structure.
- **The dark Club detail card provides effective focus.** Its solid inset panel
  isolates the selected staff member's report from the textured ground, and its
  title (“The desk · Luka Tunsen”) links the selection to the detail area.
- **The radar chart is a justified drawn/worksheet element.** It turns seven
  grades into a fast profile while the numbered legend retains exact labels and
  values. The craft rendering supplements rather than replaces information.
- **Typography has identity while remaining readable at primary sizes.** Names,
  page titles, and normal body copy are legible in both themes, and the bolder
  display face usefully marks top-level facts such as Probe VC and the Club
  sidebar headings.

### NEUTRAL — decorative but harmless

- **Irregular tab and panel outlines** are noticeable but do not distort hit
  targets or text alignment in these static renders.
- **The dotted fabric/paper texture** is mostly low contrast. It adds material
  character but conveys no information; at current strength it is generally
  harmless, though it is closer to the readability limit in the light theme.
- **Background desk props and the light-theme starburst** sit outside the working
  page and do not compete strongly with page content.
- **The circular “L” monogram** adds staff identity but communicates less than a
  portrait or role icon would. It does not currently obstruct the report.
- **The yellow Navigation pull-tab** is visually prominent but has nearby
  keyboard guidance, so its physical-object styling does not by itself damage
  comprehension.

### CHANGE — the aesthetic treatment reduces clarity or usability

1. **Selection state is not visible in the Club staff list.** Luka is selected,
   as proved only by the right-side heading, yet Luka's row has no highlight,
   marker, inset, underline, or differing surface. The large handwritten scores
   (36/40/54/76) attract more attention than selection. A conventional selected
   row treatment would communicate state substantially better and would preserve
   the staff-list → selected-staff → report hierarchy.
2. **The Club list is visually loose rather than scannably tabular.** Names,
   roles, report snippets, scores, and origin/tenure occupy implied columns with
   inconsistent baselines and large vertical gaps. The craft layout avoids a
   “table” appearance at the cost of comparison speed. Subtle row bands/rules,
   consistent column headers, and stronger alignment would be more functional
   while still fitting a journal.
3. **Small secondary copy loses contrast, especially on textured surfaces.** The
   light theme's grey inactive tabs and small origin/tenure text are faint; the
   dark theme's cyan-grey inactive labels and radar/legend copy are also
   recessive. Texture directly behind small type makes this worse. Decoration
   should be reduced beneath text or secondary text contrast raised.
4. **Team Overview's title hierarchy is ambiguous.** “Team” is a tiny page label
   at the top edge while “Probe VC” dominates beneath it; “The six who start” is
   detached above a large mostly empty middle column. The result scans as several
   fragments rather than a clear overview. Conventional section headings and
   tighter grouping would communicate the same content better.
5. **Team density is badly unbalanced.** The left summary is text-heavy, the
   center uses a small radar chart in a very large empty region, and the right
   Club facts are cramped against the edge. On Club, the detail/report occupies
   only a shallow strip while most of the lower right page is empty. This feels
   compositionally motivated rather than task motivated: scarce space is not
   allocated according to information importance.
6. **The Staff box on Team looks distressed/disabled rather than informational.**
   Heavy crosshatching and a rough stitched frame compete with four short rows,
   particularly in the dark theme where it resembles an unavailable control.
   A simple ruled list or clean inset would distinguish data from decoration.
7. **Click affordances are inconsistent.** Top tabs look clickable, but staff
   rows do not; the disabled-looking “Interview candidates” button has a very
   strong outline while the actually selectable rows have none. Static imagery
   cannot prove hover behavior, but resting-state affordance is insufficient.
8. **The handmade display face is overextended into dense operational copy.** It
   is pleasant for headings and names, but numerals, small labels, long depth
   chart lines, and report snippets would scan faster in a calmer text face.
   The visual voice is being applied uniformly instead of being reserved to
   personalize the book.
9. **The light theme exposes the craft layer more strongly than the dark theme.**
   Pale halftone across almost the entire page, irregular outlines, pastel
   shadows, and the decorative starburst collectively create more visual noise.
   None is individually severe, but together they make the actual hierarchy
   flatter than in Mikasa/dark.

## Required flow judgments

- **Club / Staff:** The broad three-part structure is recoverable: staff list on
  the left, selected staff heading and report on the right. It does not read
  clearly enough at the selection transition because the selected row is
  visually identical to every other row. “Reports” is also represented by one
  unlabelled card rather than a clearly named report region.
- **Team:** Not assessable for “roster → selected voli → details” from this probe.
  Both Team artifacts are Overview and contain no roster selection/detail UI.

## Highest-priority findings

1. **Add an unmistakable selected state to Luka's row** in the left side of both
   Club screenshots; the right report currently supplies the only selection cue.
2. **Extend the probe's Team coverage to the roster/detail state before judging
   or changing that flow;** the current Team screenshots only show Overview.
3. **Rebalance the Team Overview's three columns,** especially the oversized
   empty center around the radar chart and the cramped Club sidebar at right.
4. **Remove or quiet the distressed crosshatching behind Team's Staff list** and
   keep texture away from small secondary text in both themes.
5. **Use conventional alignment/rules and a calmer body face for dense list
   data,** particularly Club staff comparisons and Team depth-chart lines, while
   retaining craft typography for headings and identity.
