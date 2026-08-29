# Character creation — place flow, manager origin, club jobs, founding, and UI voice

This focused addendum to `docs/design/CHARACTER_CREATION.md` records decisions settled after the six-question VOLLEYBALL redesign. It should be folded into the main character-creation spec when that file is next consolidated.

## Player-owned confirmation voice

The questionnaire can be conversational without returning to the earlier problem of prose telling the player what they think.

- **Player-owned actions may speak conversationally.**
- **World/UI description stays concrete.**
- **Do not synthesize facts into authored emotional meaning on the player's behalf.**

Good confirmation language includes `This feels right.`, `That looks good.`, `I like that.`, `Yeah, let's do that.`, `Yup, that's my volleyball.`, `Yup, this is me!`, `Yup, this is home.`, `I'll start here.`, `That sounds right.`, `I'm okay with that.`, `Show me the openings.`, `Let's build one.`, `I'll take the job.`, and `Let's start this club.`

General rule:

> **The game asks plainly. The player may answer conversationally. The world reports what is true.**

## `Surprise me!`

Every visual tactical question may offer **Surprise me!**. It randomly selects one real answer, reveals it and shows its preview, but does not auto-advance. The player may confirm or reroll. VOLLEYBALL may also randomize all six questions before showing the completed montage. The same interaction may be used where randomization is meaningful elsewhere in creation.

---

# 01 — YOU

## 01A — Who are you?

Keep the existing appearance editor: name, body type, Vegi variety where applicable, colourway, coat/marking, face, height, arm proportion, leg proportion, handedness, and live rotating preview. Appearance remains visual only.

Confirmation: **Yup, this is me!**

Home region is not selected until PLACE, so 01 must not silently choose geography to generate a name. Manual naming works immediately; regional-name suggestions can become available after HOME is known.

## 01B — What did you do before this?

- **You played** — prior knowledge leans toward players and relationships from competition.
- **You coached** — prior knowledge leans toward training, staff, development and coaching relationships.
- **You analysed** — prior knowledge leans toward match records, tactical observations and broader but less personal team knowledge.
- **You're new to this** — no prior competitive-volleyball career; a distinct harder outsider/journeyman start.

`You coached youth` becomes `You coached` unless a real youth structure later justifies the narrower wording. `You paid for it` is removed: founding is an institutional route in CLUB, not manager biography.

Newcomer skips professional standing. It may have no professional standing, very few contacts, no prior volleyball records and limited job access. Do not compensate with a hidden bonus merely to equalize starts. Make the harder start explicit. Suitable confirmation: **I'm okay with that.**

## 01C — How established were you?

Played, Coached and Analysed reveal a stepped control:

```text
●──────────●──────────●
Obscure    Known      Established
```

- **Obscure** — legitimate career, few wider relationships, narrow prior information, lower-status openings, little portable reputation. This is a true journeyman-style start and does not imply low competence.
- **Known** — default middle position: some contacts, ordinary recognition, normal vacancy range and moderate prior information.
- **Established** — broad professional network, wider credible information, stronger openings and potentially greater institutional expectations. It does not improve manager decision-making or tactics by fiat.

Decomposition:

```text
BACKGROUND → what kind of prior knowledge/relationships exist
STANDING   → how broad the network, reputation, information and job access are
```

Background must not regenerate or alter whichever existing club the player later chooses. The world exists before the manager arrives.

---

# Regional tactical presets

Regional tactical identities are weighted tendencies, not character classes or six absolute questionnaire answers. During Q1–Q6 regional examples are optional secondary information. After Q6, **See how the regions play** can introduce the world map before PLACE.

Information hierarchy:

1. **Regional tradition** — broad, stable public knowledge.
2. **Club identity** — regionally influenced but historically/managerially variable.
3. **Current match tactics** — volatile and learned through current evidence.

---

# 03 — PLACE

Major/minor classification remains visible for both home and working-region selection.

## 03A — Where are you from?

Use the reusable world-map/globe surface plus an accessible Major/Minor grouped list. Selection recenters the world view and opens the regional profile/montage. Major/minor is institutional status, not land area.

Confirmation: **Yup, this is home.**

## 03B — Where does your career begin?

Reuse the same map with HOME marked. There is no separate `begin at home` action; selecting HOME again naturally means staying there.

The current vacancy solution is **B now, C as target**:

- **Now:** before confirming a working region, show how many managerial vacancies exist and how many are available to this manager's professional standing.
- **Target:** eventually permit a genuinely unemployed start in which the manager searches/applies dynamically across the world.

Example:

```text
SPËDDIGH
Major region

Open manager positions      3
Open to your standing       1
```

Confirmation: **I'll start here.**

After HOME and WORK exist, expose geographic distance and tactical familiarity separately. Distance ultimately derives from world geography; tactical familiarity derives from Q1–Q6 versus the working region's weighted tradition. Do not infer cultural/emotional meaning from geographic distance.

The same world surface should later support encyclopedia browsing, transfers, visits, Sixnet/academy geography and records.

---

# 04 — CLUB

CLUB asks how the manager enters an institution. Existing-club and founding routes should feel categorically different:

> **A job opening asks which institution you are willing to inherit. Founding asks what institution you are willing to begin.**

## 04A — Entry route

Where both routes exist:

### Look for a job
Start as manager of an existing club.

Action: **Show me the openings.**

### Found a club
Start a new institution in the selected region.

Action: **Let's build one.**

If founding is unavailable, do not show a dead choice merely to explain its absence.

---

# 04J — EXISTING-CLUB / JOB ROUTE

## 04J-1 — Job openings

Question: **Where do you want to work?**

The player chooses among actual managerial vacancies compatible with region and standing, not every club. A vacancy should expose enough factual information to understand the inherited institution.

### Vacancy identity

Club, region, vacancy status and—where world history supports it—reason/duration of vacancy.

### SPORT

Measured sporting position: circuit/competition standing, interregional record, regional-strength contribution, academy selections or other settled competition metrics. A club contributes evidence toward its region's Sixnet standing; the club itself does not qualify for Sixnet.

### CLUB

Operating condition: finances, contracted squad, roster depth, training facilities, staffing and other institutional resources.

### VOLI LIFE

Voli living conditions are first-class club metrics rather than flavor. Do not collapse them into one wellbeing score. Relevant dimensions include:

- food quality and, where useful, familiarity/variety;
- housing quality and privacy/crowding;
- free time;
- training load;
- medical/recovery/care provision;
- social structure, e.g. communal versus independent;
- stability of routines/housing/staff arrangements.

Some dimensions should create real tradeoffs rather than all scaling upward with wealth: training time versus free time, private rooms versus capacity/cost, individualized food versus operational expense, communal scheduling versus autonomy.

### CLUB PRIORITIES

Separate what the institution values from what it currently achieves. A club may strongly value food while currently providing only a middling standard.

### BOARD EXPECTATIONS

Separate three concepts:

```text
CURRENT CONDITION → what is true now
CLUB PRIORITY      → what the institution tends to value
BOARD EXPECTATION  → what the manager is accountable for
```

Expectations may be sporting, institutional or voli-living, but every displayed expectation must correspond to an actual enforced/measured system. Not every club is judged on every metric.

This permits distinct institutions: an elite club may demand sporting results and expensive living standards; a development club may prioritize academy selections and development; a small club may prioritize solvency, retention and acceptable living conditions.

> **Club success is plural, but club expectations are specific.**

### Squad information

`View squad` exposes names, ages, positions, contracts and public career information. It does not grant omniscient hidden knowledge. Background shapes the type of deeper evidence already known; standing shapes breadth.

### Club volleyball

Show current club tactical tendencies alongside the player's Q1–Q6 philosophy without synthesizing a verdict. The discrepancy itself is information.

### Accepting the vacancy

If creation guarantees the selected appointment, avoid `Apply for this job.` Prefer **I want this job.** for selection and a compact factual appointment review followed by **I'll take the job.** Later-career employment can use genuine applications/rejections once that system exists.

Do not ask for releases, transfer targets, starter choices or detailed squad plans during creation. Those belong to the first days of actually managing the inherited club.

---

# 04F — FOUNDING ROUTE

Founding should not become a conventional budget/facilities slider sheet. The player chooses a small number of consequential starting circumstances and institutional priorities; the world generates a viable but imperfect club from them.

A founding route must begin with enough volis, staff and infrastructure for ordinary club loops to function immediately. Difficulty comes from compromises, limited resources, thin depth, low standing and lack of institutional history—not from withholding core gameplay.

## 04F-1 — Starting place

The working region was already selected in PLACE, so do not ask for region again. Instead offer a small number of legitimate founding situations/sites generated inside that region.

A starting situation is a bundle of world facts rather than a facilities rating. It may combine:

- district/local location;
- available training space;
- accommodation availability;
- operating cost;
- travel position;
- local volleyball/institutional context.

Example:

```text
Vål district
Existing training hall
Shared accommodation available
Higher operating cost

North coast
Basic municipal court
Cheap housing
Longer travel

Tressa outskirts
Converted warehouse court
Moderate housing
Growing local volleyball scene
```

Long-term world geography can make these sites richer; the initial implementation only needs a few coherent generated situations.

## 04F-2 — Starting backing

Ask **How is the club starting out?** rather than asking for the manager's personal wealth.

Use a small discrete resource tier rather than detailed sliders, provisionally:

- **Bare start** — very limited resources, but core club operations function.
- **Modest backing** — enough resources for a stable small club.
- **Strong backing** — substantial initial financing/infrastructure.

Professional standing and club capital are separate. An Established manager can found a tiny club; an Obscure manager can have external backing.

Show the factual consequences before confirmation, e.g. starting funds, training space, accommodation, care provision and staff capacity. No hidden bonuses.

**Strong backing remains an explicit design question:** its institutional source should eventually matter. Government/civic support, private backing, members, manager capital or other sources may create different obligations. `More money` should not become a strictly dominant founding answer. Until funding-source obligations are designed, do not falsely imply that backing tiers are complete difficulty design.

## 04F-3 — Early club priorities

This is the founding route's principal identity choice. A vacancy inherits a VOLI LIFE profile; a founder establishes the first priorities.

Avoid direct sliders and avoid allowing the player to maximize every condition. The club's actual starting conditions should derive from:

```text
starting site
+ backing/resources
+ selected priorities
→ feasible starting conditions
```

A priority directs scarce resources and organizational effort; it does not guarantee an `Excellent` rating.

### One sporting emphasis

Provisionally choose one:

- **Competitive results** — greater early emphasis on people/resources capable of winning now.
- **Player development** — greater institutional emphasis on development and future representative value.
- **Squad continuity / sustainable building** — greater emphasis on retention, continuity and institutional stability.

These are priorities, not permanent club classes.

### Two living/institutional priorities

Choose two from a concise set such as:

- Good food
- Comfortable housing
- More free time
- Strong care
- Better training
- Privacy
- Communal club life

The preview should immediately expose resulting tradeoffs in the projected VOLI LIFE profile. A Bare start that prioritizes food may achieve good food while accepting shared housing/basic care. A better-backed club can achieve a higher condition from the same priority.

The founder should be able to create clubs with materially different lives rather than one optimal rich-club endpoint.

## 04F-4 — Initial squad and staff generation

Do **not** require the player to recruit an entire roster or hire every staff member during character creation.

Generate a plausible founding squad from:

- region;
- starting site/resources;
- available/free-agent population;
- sporting priority;
- manager background, standing and professional network;
- selected volleyball;
- labor-market conditions.

The squad should be viable but imperfect. It should not be an optimized translation of Q1–Q6. The opening management problem is deliberately:

> **This is my volleyball. These are the people I've managed to assemble. How do I reconcile the two?**

Offer `View starting squad` before final confirmation. The player may go back/reroll the setup rather than individually drafting a full roster in onboarding.

Background influences the causal route by which people are known/available rather than granting raw bonuses: Played can draw on player relationships; Coached on training/staff networks; Analysed on evidence about less-famous players; Established broadens who will consider the new institution; Newcomer relies more heavily on local/genuinely available/free-agent labor.

Staff works similarly. Generate a minimum viable staff according to resources/network and expose remaining vacancies as early-game work. A Bare start still functions; it simply contains compromises.

## 04F-5 — Club name and lightweight identity

A founded club should be named here rather than in SIGNATURE because naming is part of constituting the institution. Existing clubs already have names.

Allow manual entry plus regionally appropriate generated suggestions because geography is now known.

Do not require a full crest/kit design editor before play. A generated/rerollable lightweight visual identity can be enough initially; deeper customization may happen in-game.

## 04F-6 — Founding review

Before creation, show the new institution factually:

```text
NEW CLUB

Vål Nyr VC
Spëddigh · Vål district

START
Backing             Modest
Training             Basic
Squad                10 volis
Staff                3 filled · 1 vacant

EARLY PRIORITIES
Player development
Good food
Free time

VOLI LIFE
Food                 Good
Housing privacy      Low
Free time            Good
Training load        Moderate
Care                 Basic

VOLLEYBALL
[Q1–Q6 summary]

[ View squad ]
[ View club ]
```

Confirmation: **Let's start this club.**

## Founding priorities are not permanent promises

Founding choices establish initial allocation, conditions, reputation and historical origin. They are not immutable traits.

A club founded around free time can later become demanding. A development club can become a wealthy win-now institution. Repeated managerial actions should eventually outweigh the declaration made in character creation.

This preserves the broader rule that club identity is historical and behavioral rather than a permanent class selected on day one.

## Founding flow summary

```text
04A — CLUB
[ Look for a job ] / [ Found a club ]
                         ↓
                   Let's build one.
                         ↓
04F-1 — STARTING PLACE
Choose a generated founding situation in the selected region
                         ↓
04F-2 — BACKING
Bare / Modest / Strong (funding-source obligations still to design)
                         ↓
04F-3 — EARLY PRIORITIES
1 sporting emphasis + 2 living/institutional priorities
                         ↓
WORLD GENERATION
Facilities + VOLI LIFE + viable imperfect squad + minimum staff + finances
                         ↓
04F-4 — INSPECT SQUAD / STAFF
No full onboarding recruitment draft
                         ↓
04F-5 — CLUB NAME
Name + lightweight generated visual identity
                         ↓
04F-6 — REVIEW
SPORT + CLUB + VOLI LIFE + PRIORITIES + SQUAD + STAFF + VOLLEYBALL
                         ↓
              [ Let's start this club. ]
```
