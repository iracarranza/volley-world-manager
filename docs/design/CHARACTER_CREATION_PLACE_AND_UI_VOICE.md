# Character creation — place flow, manager origin, club jobs, and UI voice

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
- `That sounds right.`
- `I'm okay with that.`
- `Show me the openings.`
- `Let's build one.`

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

The same interaction can be used for non-tactical creation choices where randomization is meaningful, including background and a choice among compatible starting job openings.

---

# 01 — YOU

The revised YOU step should separate appearance from professional origin. It should not alter the state of whichever club the player later chooses.

## 01A — Who are you?

Keep the existing manager appearance editor:

- name;
- body type;
- Vegi variety where applicable;
- colourway;
- coat/marking;
- face;
- height;
- arm proportion;
- leg proportion;
- handedness;
- live rotating manager preview.

Appearance remains visual only. The manager never enters the volleyball simulator as an athlete.

Confirmation:

> **Yup, this is me!**

### Name generation and region order

Home region is not selected until `03 — PLACE`, so 01 should not silently preselect a region merely to generate a culturally appropriate name.

The name field can be entered manually in 01. After HOME is selected in 03, a regional-name suggestion can become available if the player wants one or left the field blank.

## 01B — What did you do before this?

Use four professional-origin choices:

### You played

You know volleyball through the people you played with and against.

Its starting-information shape should lean toward player/person knowledge and relationships from competitive play.

### You coached

You know volleyball through training players and working with staff.

Its starting-information shape should lean toward training histories, staff relationships, development context, and people encountered through coaching work.

`You coached youth` should become simply `You coached` unless/until a real youth structure exists that makes the narrower description meaningful.

### You analysed

You know volleyball through studying teams and matches.

Its starting-information shape should lean toward match records, tactical observations, and broader but less personal club/team knowledge.

### You're new to this

You have not worked in competitive volleyball before.

This is a distinct outsider/journeyman-style start and does **not** use the professional-standing control below. It may be genuinely harder. Do not invent a compensating hidden bonus merely to make all origins mathematically equal.

The UI should say the consequence plainly, for example:

```text
Professional standing     None
Existing contacts         Very few
Prior volleyball records  None
Job access                Limited

A harder way to begin.
```

A suitable confirmation is:

> **I'm okay with that.**

The human player may be new to volleyball without choosing a fictional manager who is new to professional volleyball; the newcomer route is a roleplaying/difficulty choice, not an onboarding requirement.

## 01C — How established were you?

For `You played`, `You coached`, and `You analysed`, expose a stepped professional-standing control:

```text
HOW ESTABLISHED WERE YOU?

●──────────●──────────●
Obscure    Known      Established
```

This is one continuum, so a stepped slider/segmented line is preferable to three unrelated cards.

### Obscure

A legitimate career with little wider recognition.

Consequences may include:

- few existing professional relationships;
- narrow starting information outside the manager's immediate history;
- lower-status openings willing to hire the manager;
- prestigious openings generally unavailable;
- little reputation carrying between regions.

An obscure player/coach/analyst is not necessarily bad at what they did. Their work simply generated little professional standing.

### Known

The default/middle start.

Consequences may include:

- some existing contacts;
- ordinary recognition inside relevant professional circles;
- a normal range of starting vacancies;
- a moderate amount of prior information consistent with the chosen background.

### Established

A substantial prior professional career.

Consequences may include:

- a broader professional network;
- more clubs/managers already familiar with the manager;
- broader credible prior information;
- stronger clubs willing to offer or consider openings;
- greater expectations around the appointment when such systems exist.

Established must not mean `better manager decisions` or hidden tactical bonuses. It means **the world already has more evidence about the manager**.

A compact consequence display can use factual labels such as:

```text
Obscure       Fewer contacts · smaller job market · less starting information
Known         Some contacts · normal job market · some starting information
Established   More contacts · stronger job market · broader starting information
```

The combination of background and standing creates starting histories without fixed character classes: an obscure former player, established coach, obscure analyst, and established analyst can all produce different knowledge/relationship shapes.

General decomposition:

```text
BACKGROUND → what kind of prior knowledge/relationships exist
STANDING   → how broad the network, reputation, information, and job access are
```

This replaces the old background effects that regenerated or altered the future club. `You paid for it` is removed from manager background because founding a club belongs to `04 — CLUB`.

Likewise, backgrounds should not retroactively change an existing club's roster age, scout count, staff, or identity after the player selects a vacancy. The world exists before the manager arrives.

`Surprise me!` can randomize background and, for the first three backgrounds, a sensible standing value. The result should be revealed before confirmation.

A general background confirmation can use:

> **That sounds right.**

---

# Regional tactical presets

Regional tactical identities should be visible, but they must not become character classes.

## During Q1–Q6

Regional examples are optional/secondary. A curious player may open a small `How do different regions approach this?` detail, but the questionnaire should not lead with fourteen region presets. The primary task is still to watch the three demonstrations and react to them.

## After Q6

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

## Regional presets are weighted tendencies

Do not define a region as six absolute questionnaire answers. Each question should instead have a regional distribution/weighting: a typical tendency, other common approaches, and unusual approaches.

This preserves variation between clubs and managers inside the same region.

The information hierarchy is:

1. **Regional tradition** — broad, relatively stable public knowledge; visible in creation and encyclopedia browsing.
2. **Club identity** — influenced by region but historically/managerially variable; requires reasonably current knowledge.
3. **Current match tactics** — specific and volatile; learned through scouting, observation, reports and recent matches.

A regional montage should therefore show representative authored examples, not imply every club or rally in the region behaves identically.

---

# 03 — PLACE

Major/minor classification remains visible when choosing both home region and working region. It is not merely a difficulty fact; it is part of the world's institutional geography.

The intended sequence is:

## 03A — Where are you from?

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

Selecting a home region recenters the world view and opens its regional profile/montage. The player confirms with:

> **Yup, this is home.**

## 03B — Where does your career begin?

Reuse the same map. The chosen home region remains marked, but the question is now about the working/club region.

There is no separate `begin at home` action. Selecting the home region again naturally means staying home; selecting somewhere else means moving.

Use one confirmation regardless of relationship:

> **I'll start here.**

## Derived relationships

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

---

# 04 — CLUB

The established-club route should be framed as choosing a **job opening**, not choosing which club the player owns or simply `takes`.

The world exists before the manager. Existing clubs have squads, staff, facilities, histories, relationships, current tactical identities, and vacancies independent of the player.

## 04A — How are you entering club management?

Where the selected working region permits both routes, offer:

### Take a job

Start as manager of an existing club.

Confirmation/action:

> **Show me the openings.**

### Found a club

Start a new institution in the selected region.

Confirmation/action:

> **Let's build one.**

If founding is not available in the selected region, do not show a dead/disabled choice merely to explain its absence. Proceed to the available job opening(s).

`You paid for it` no longer belongs in 01 because this is the correct place for the institutional founding decision.

## 04B — Job openings

The player is choosing among vacancies compatible with their region and professional standing.

The question can simply be:

> **Where do you want to work?**

Each selectable opening should clearly identify itself as a managerial vacancy rather than a club-ownership card.

Example information structure:

```text
Vål Tressa VC
Manager vacancy

Squad             11 contracted volis
Club resources    Strong
Accommodation     Established
Recent finish     4th

Club volleyball
Target reception · Floor defense · Combination offense

Your volleyball
Target reception · Read the attack · Combination offense

[ View squad ]
[ View club ]
```

Only show information the world actually knows. If vacancy history is modeled, factual fields such as `Previous manager: resigned` or `Vacancy open: 3 weeks` are acceptable. Do not add prose about a proud institution waiting for a new direction.

The roster should be inspectable before committing. A lightweight summary is useful for players who do not want a full roster study; `View squad` should expose the actual players for those who do.

The starting job market should be filtered by manager standing rather than presenting every club as equally available:

- **Obscure** managers primarily see lower-status openings;
- **Known** managers see the normal starting market;
- **Established** managers may have access to stronger openings;
- **Newcomers** have a deliberately limited first job market.

This does not require every opening to be procedurally contested during character creation. If selecting an opening guarantees the appointment, avoid a button labeled `Apply` because it promises interviews/rejection/competition that do not exist.

Prefer a player-owned confirmation such as:

> **I want this job.**

Later-career job changes may use a real application/hiring process when that system exists.

`Surprise me!` can choose among currently available openings, reveal the chosen vacancy, and allow the player to inspect or reroll before confirming.

## Club identity versus manager volleyball

An existing club's tactical identity should be visible alongside the player's Q1–Q6 preferences without a concluding paragraph interpreting the mismatch.

For example:

| | Your volleyball | Club |
|---|---|---|
| Serving | Target reception | Controlled serves |
| Defense | Read the attack | Floor defense |
| Transition | Attack in transition | Reset the play |
| Offense | Combination | Combination |

The disagreement itself is the information. Do not append a sentence telling the player that changing the club will be difficult or exciting.

This is also where the game first makes clear that **regional tradition and club identity are not the same thing**. A club can be unusual within its own region.

## Founding route

Founding should not turn onboarding into a large facilities/economics questionnaire. The selected work region supplies geography/material grammar; starting resources generate an initial modest physical state.

The exact initial-squad mechanism remains unresolved, but founding must begin with enough volis, staff, and infrastructure for the normal club loops to function immediately. Difficulty should come from weak/thin resources, low standing, limited depth, and a new institution's lack of history—not from withholding the game's core systems behind an empty roster.

Major-region founding remains the intended hard institutional route; minor-region difficulty is structurally different and should not require founding to create it.
