# Character creation — place flow and UI voice

This is a focused addendum to `docs/design/CHARACTER_CREATION.md`, recording decisions settled after the six-question VOLLEYBALL redesign. It should be folded into the main character-creation spec when that file is next consolidated.

## Player-owned confirmation voice

The questionnaire can be conversational without returning to the earlier problem of prose telling the player what they think.

The distinction is:

- **Player-owned actions may speak conversationally.** The player chooses to press the button, so the line can sound like their response.
- **World/UI description stays concrete.** It presents information and lets the player interpret it.
- **Do not synthesize facts into authored emotional meaning on the player's behalf.**

Good confirmation language includes:

- `This feels right.`
- `That looks good.`
- `I like that.`
- `Yeah, let's do that.`
- `Yup, that's my volleyball.`
- `Yup, this is me!`
- `Yup, this is home.`
- `I'll start here.`

The exact phrase may vary between pages. The variation should feel like ordinary affirmative reactions, not six different pieces of flavor writing.

Avoid turning factual relationships into narrated conclusions. For example, after home and work regions are selected, prefer:

```text
Bompaçao → Spëddigh
Distance from home: Far
Tactical familiarity: High

Shared: Targeted serving · Combination offense
Different: Transition offense · Block commitment
```

over prose such as `Your volleyball has a lot in common with local tradition, even though you've come a long way from home.` The figures/labels already contain the useful information.

The general writing rule is:

> **The game asks plainly. The player may answer conversationally. The world reports what is true.**

## `Surprise me!`

Every visual tactical question may offer a lightweight random-choice action:

> **Surprise me!**

It means `choose one of these answers for me`, not `use a neutral/balanced default`.

When pressed:

1. randomly select one of the three actual answers;
2. reveal that answer;
3. switch the preview to its demonstration;
4. do **not** immediately advance;
5. allow the player to accept it with the normal conversational confirmation or press `Surprise me!` again.

`02 — VOLLEYBALL` may also offer a whole-section `Surprise me!` escape hatch. That randomizes Q1–Q6, then shows the completed-volleyball montage so the player can accept the generated identity or edit individual answers.

This is especially important for a player who wants the management/world experience without arriving with a volleyball philosophy.

## Regional tactical presets

Regional tactical identities should be visible, but they must not become character classes.

### During Q1–Q6

Regional examples are optional/secondary. A curious player may open a small `How do different regions approach this?` detail, but the questionnaire should not lead with fourteen region presets. The primary task is still to watch the three demonstrations and react to them.

### After Q6

This is the main regional-comparison moment. After `Yup, that's my volleyball.`, the player may choose something like:

> **See how the regions play**

This can introduce the world map immediately before `03 — PLACE`.

Regional comparison should expose concrete correspondences rather than a single dominant percentage. For example:

```text
Spëddigh
Common: Target the reception · Read the blockers · Combination offense
Less common: Aggressive serves · Isolation offense
```

If an internal similarity score exists, it is supporting data rather than the headline.

### Regional presets are weighted tendencies

Do not define a region as six absolute questionnaire answers. Each question should instead have a regional distribution/weighting: a typical tendency, other common approaches, and unusual approaches.

This preserves variation between clubs and managers inside the same region.

The information hierarchy is:

1. **Regional tradition** — broad, relatively stable public knowledge; visible in creation and encyclopedia browsing.
2. **Club identity** — influenced by region but historically/managerially variable; requires reasonably current knowledge.
3. **Current match tactics** — specific and volatile; learned through scouting, observation, reports and recent matches.

A regional montage should therefore show representative authored examples, not imply every club or rally in the region behaves identically.

## 03 — PLACE

Major/minor classification remains visible when choosing both home region and working region. It is not merely a difficulty fact; it is part of the world's institutional geography.

The intended sequence is:

### 03A — Where are you from?

The player gets their first meaningful look at the world map.

The long-term interface is a reusable rotatable world map/globe with:

- region selection;
- rotation and zoom;
- terrain/topography;
- region boundaries and labels;
- major/minor status;
- academy/Sixnet markers for major regions;
- club/institution markers at appropriate zoom levels;
- recentering on selection;
- access to the same regional profile/montage used elsewhere.

The currently calculated/topographical map is a development seam, not final geography/art. Character creation should define the interaction contract without freezing unfinished coastlines, proportions or terrain rendering.

Major/minor should not be encoded by geographic area: a minor volleyball region can occupy a large land area. Institutional markers and labels should communicate volleyball status instead.

The map must not be the only selection mechanism. An accessible region list, grouped as **Major regions** and **Minor regions**, should remain available alongside or below it.

Selecting a home region rec enters the world view and opens its regional profile/montage. The player confirms with a player-owned response such as:

> **Yup, this is home.**

### 03B — Where does your career begin?

Reuse the same map. The chosen home region remains marked, but the question is now about the working/club region.

There is no separate `begin at home` action. Selecting the home region again naturally means staying home; selecting somewhere else means moving.

Use one confirmation regardless of relationship:

> **I'll start here.**

### Derived relationships

After both selections exist, expose **geographic distance** and **tactical difference/familiarity as separate dimensions**.

Do not collapse them into one `fit` score.

Examples:

```text
HOME     Bompaçao
WORK     Spëddigh

Distance from home     Far
Tactical familiarity   High
```

or:

```text
HOME     Landavol
WORK     Rhėn Tempaol

Distance from home     Close
Tactical familiarity   Low
```

Distance should ultimately derive from actual world geography rather than a hand-authored near/medium/far table. Tactical familiarity should derive from the player's Q1–Q6 choices against the working region's weighted volleyball tradition.

Do not infer cultural familiarity, language, comfort, or emotional meaning from distance unless those become separate modeled systems.

## Permanent world-map role

The expensive map work should not exist only for onboarding. The same world surface can later support:

- new-career home-region selection;
- new-career working-region selection;
- encyclopedia/world exploration;
- club and transfer geography;
- visits/travel;
- Sixnet regional context;
- academy geography;
- historical/world records.

The creation flow is therefore the player's introduction to a permanent world-navigation surface, not a disposable picker.
