# Commentary corpus audit

This is a research/data audit. It does not propose or adapt Volley World
Manager dialogue.

## Scope

- Reviewed every one of the 74 pre-existing corpus records against its source
  description, physical-event label, exact-commentary field, and immediate
  context.
- Screened English caption tracks from 20 additional official Volleyball World
  full-match uploads. Together with the eight captioned full matches already in
  the targeted set, the negative-search pool contains 28 broadcasts.
- Replayed the retained S11–S13 candidates against the video, including the
  rally before/after the analyst comment when the comment concerned intent or a
  prior huddle.
- Added seven evidence records. The corpus now contains 81 records from 13
  retained sources.

## Machine-readable integrity

Post-update checks:

| Check | Result |
|---|---|
| CSV data rows | 81 |
| Markdown table data rows | 81 |
| CSV/Markdown field-for-field equality | PASS |
| Columns per record | 6 for every row |
| Duplicate full records | 0 |
| Timestamp format | `HH:MM:SS` for every row |
| Blank required fields | 0 |

The CSV remains canonical. The Markdown table is a field-for-field review view,
not a separately edited paraphrase.

## Corrections and classification safeguards

| Record or concept | Audit result |
|---|---|
| S7 00:09:27 physical label | Corrected `offensive overload / called pattern` to `offensive overload / visible pattern`. The booth identifies what it sees; it does not establish a prior call. |
| S11 01:46:42 caption name | Corrected the obvious auto-caption split `Jose Maria` to player name `Rosamaria`, verified from the picture. |
| S1 00:22:37 | Retains `free-ball return after poor reception`; it is not evidence for an emergency set. |
| S2/S3 block-touch rows | Retain `block touch`; neither commentator says `soft block`. |
| S5 00:02:14 | Retains an explicit nonmatch label. The tentative “little whiff” follows a broken middle-net play and is not a hitter missing a delivered set. |
| S7–S9 `dime` rows | Correctly limited to reception. They do not validate a setter-specific use. |
| S10 01:30:38 | Supports leaving an effective position, not proof of a formal defensive assignment. |
| S12 00:29:29 | Supports an emergency/out-of-system tip. The hitter still has some approach, so a strictly non-approach tip remains unvalidated. |
| S11/S13 funnel rows | The video supplies the physical sequence; intentional funneling is the analyst's stated inference. It is not independently observable proof of the team's private terminology. |
| S11 01:31:23 | Directly links block touches with slowing attacks for back-court defense, but does not say a particular touch was deliberately aimed at a defender. |

## Rejected near-matches

- `missed everything`, `miss`, and `no touch` candidates were attack-out/no-block
  descriptions rather than a hitter failing to contact a delivered set.
- Ordinary approach tips, power tips, setter dumps, and controlled roll shots
  were rejected for the emergency-tip gap.
- `bullet` occurred for serves and hard attacks, but not as the compound
  `cross-court bullet`.
- `tool`, `tools the block`, and `tooling the block` were common; `got tooled`
  was not found.
- Good block touches and balls slowed for defense were found; deliberate
  direction of a particular block touch to create a dig was not.
- Assignment/responsibility discussion was found, but not an analyst explicitly
  saying a floor defender abandoned a formal called assignment.

## Remaining corpus gaps

1. Hitter completely misses a delivered set.
2. `dime` used for a high-quality set.
3. Floor defender leaves a formal called assignment.
4. A particular block touch is described as deliberately directed to create a
   dig opportunity.

These remain `CORPUS GAP` or `PARTIAL`; no wording has been inferred for them.
