# The world

**Read this first.** It is the canonical reference for what is true in this
setting, organised as the world rather than as a record of decisions. It is
deliberately short on argument -- the reasoning lives in the documents it points
at.

| document | holds |
| --- | --- |
| this file | what is true, and what this world refuses to be |
| `STYLE_AND_SETTING.md` | product direction, tone, naming conventions, the population model |
| `GEOGRAPHY.md` | the land, the colony rule, the panel map |
| `../design/CLUB_LIFE.md` | volis, staff, sponsorships, where conflict comes from |
| `../design/ACCOMMODATIONS_AND_CARE.md` | food, flavour, lodging |
| `scripts/data/regions.gd` | the regions as data -- names, demonyms, adjacency, traditions |

Where a claim here and a claim there disagree, the specific document wins and
this one is stale.

## 1. The premise, in four sentences

Volleyball is this world's dominant cultural medium, and it holds that place by a
founding agreement -- **the Charter** -- rather than by accident. Community clubs
feed regional programs which feed a handful of elite academies, and the six
flagship academy slots are contested every year at the **Sixnet Championship**.
You manage an up-and-coming academy, and you are arguably alien, which everyone
knows about academy managers generally and nobody remarks on. Everyone who is not
a manager is human.

## 2. The shape of the world

The world is a volleyball: **18 panels in 6 groups of 3**. That is not decoration
-- it supplies adjacency (regions sharing a seam are neighbours) and a distance
metric that already has a job (import cost follows seam distance).

A group of three panels is a **neighbourhood**: one core region, its minor
neighbour, and a panel of sea or a flagship-holder. It is never drawn as a sphere;
the readable form is a flattened panel pattern, like a shoe upper or a sail plan.

## 3. The fourteen inhabited regions

Eight **majors** contest the Sixnet's bracket. Six **minors** raise players, run
no academy worth managing, and each sit beside one core region. Ĭspayk and A'ace
are majors that stand outside the geography entirely.

### Majors

| region | demonym | land | teaches |
| --- | --- | --- | --- |
| Landavol | Landavoli | braided river plains, roads everywhere | nothing in particular, and that is its identity |
| Spëddigh | Spëddish | glacial fjords, no room to sprawl | tempo pressure, rapid transition |
| Pāwa Hitō | Hitōuen | steep volcanic archipelago | conditioning, relentless transition attack |
| Blôc du Larg | Largôis | broad tidal shelf, enormous tides | net control, patient structure |
| Xérvu | Xérvyan | high dry plateau above an escarpment | serving, toss discipline, first strike |
| Taktikã | Taktikãni | cold altiplano and salt flats | composed intelligence, reading ahead |
| Ĭspayk | Ĭspaykano | volcanic islands in the storm track | the set-and-spike; a fallen flagship |
| A'ace | A'ace'ni | desert coast, largely reclaimed | nothing yet; it buys what it needs |

### Minors

| region | demonym | beside | land |
| --- | --- | --- | --- |
| Tãul ys Feynt | Tãulwyr | Taktikã | slate valleys, low ceilings |
| Lo-ong Ralī | Ralīpa | Pāwa Hitō | thin-air plateau, three days from anywhere |
| Bompaçao | Bompaçano | Blôc du Larg | hot river delta, concrete courts |
| Rhėn Tempaol | Rhėni | Spëddigh *(colony; see below)* | temperate island in Pāwa Hitō's seas |
| Kutré Lyn | Kutrén | Xérvu | limestone karst, corners everywhere |
| Zaitgaist | Zaitgaister | Landavol | walkable enclave city, no hinterland |

**Rhėn Tempaol is a colony**, which is why it sits in Pāwa Hitō's seas while the
adjacency table links it to Spëddigh. That is the only political relationship in
the setting, it is administrative rather than moral, and it exists so the map can
have two layers. See `GEOGRAPHY.md` §2.

**A demonym is civic, never ethnic.** A Xérvyan is anyone from Xérvu. Volis move
between regions constantly, and the word for *from there* has to survive that.

**And it is formed in that region's own grammar, not in English.** The table above
once read Landavolan, Pāwan, Largen, Feyntish -- one language's three suffixes
applied to fourteen places, which made every people on the map sound as though the
same outsider had named them. Feyntwyr counts people the way that tradition counts
them; Ralīpa is the place plus *the person of it*. Civic did not change; whose
grammar does the building did. `regions.gd` `DEMONYMS` is the authority and the
suite gates it.

## 4. Volis

*Voli* is the umbrella term for the people on court. The word exists because
"player" already means the person holding the controller.

- **Bodies vary widely and visibly**, and nothing in the world treats that as
  remarkable. Body type is a silhouette, an appetite and a set of tolerances, and
  never a line anyone divides along.
- **They speak in a bodily and domestic register**, not a professional one. "I
  think I'm allergic to Xérvyan food." "Our physio stretched my arms out too
  long." The second is not necessarily a metaphor.
- **They can be wrong about themselves.** Every utterance is caused by real state;
  the voli's explanation of that state may not be. Translating one into the other
  is what a scout and a physio are for.

## 5. What people eat

Two layers, and the split is the point.

- **Blocks** are manufactured food -- industrial, shipped, bought by the case.
  They carry nutrition, morale, cost, and how much flavour they can hold.
- **Pastes** are grown, and they are where a region tastes of itself. Flavour is
  the culture here; the meal is not.

**This inverts our world's arrangement, where a dish *is* a heritage.** Here the
heritage is in the ingredient, and the same block turns up on every shelf on the
ball wearing whatever a region put on it.

Growing and making are two different maps over the same panels: land grows
flavour, capital builds factories, and they do not coincide. Each core region
sells a paste its minor neighbour grows. Ĭspayk grows its own and exports most of
it. A'ace grows nothing and imports everything.

## 6. How things are named

Three devices, used at three levels, and they do not need to agree.

- **Regions** are English volleyball puns in foreign spelling. Pāwa Hitō is
  "power hitter", Kutré Lyn is "cut and line", Spëddigh is "speed dig". A one-off
  joke that does not scale, and does not need to.
- **Places** describe terrain, weather or work, in the region's own spelling. The
  target is *Saint Kitts and Nevis* -- strange to the ear, trivially decodable
  once somebody tells you. This is the device that scales to a thousand clubs.
- **Products** come from one of two mouths:
  - the **label**, spelled in the factory's orthography -- Chutum Üch is
    Spëddigh-made by its umlaut, Blan'deral is A'aceni by its apostrophe;
  - the **nickname**, spelled however the speaker spells -- Supergruel is mildly
    derisive, Vollyslommy is *slommy*, the babytalk word for food you give a small
    creature you are spoiling.

A **minor region shares its major neighbour's spelling**, which is what makes two
places read as one written language. A **colony takes its administrator's
spelling** while its people keep their own naming tradition.

## 7. What this world does not have

The most load-bearing section, and the one most likely to be violated by
well-meaning future work. Each of these was decided against on purpose.

- **No sociopolitical substrate driving conflict.** No class, no status economy,
  no group grievance. This is the deliberate absence that everything else here
  rests on.
- **No division over bodies.** Body types are simply accepted. They are never a
  prejudice, a stereotype, or a thing a region has opinions about.
- **No extraction narrative in trade.** A region growing what another sells is two
  ordinary jobs in two places, not exploitation. Distance costs money; that is all
  it means.
- **No grievance engine.** Social conflict is **allocation**: one finite thing,
  more than one legitimate claim, nobody behaving badly. Two volis both being
  right. See `CLUB_LIFE.md` §1b.
- **No regional cuisine.** Culture lives in flavour, not in dishes. A block that
  starts reading as somebody's home cooking is a drift.
- **No mystery about the manager.** "Arguably alien" is an accepted fact of the
  role, never a puzzle to solve or a joke to explain, and it is never confirmed or
  denied on the page.
- **No permanent flagships.** Nothing in the bracket is owned. A legendary
  program can fall out; money can buy in.

  Two numbers, and they are not the same number. **Eight** regions hold Sixnet
  bracket slots — four upper, four lower. **Six** contest the championship: the
  four seeded, plus the two who come up through the lower bracket's round robin,
  which is what makes the name honest. This line said "the six Sixnet slots"
  until 2026-08-06, which read as a slot count and contradicted §3 of this same
  page; `STYLE_AND_SETTING.md` §"The six flagship slots aren't permanent" has
  always had it right. (`Regions.SIXNET_PARTICIPANTS`,
  `SixnetLeague.UPPER_SLOT_IDS` / `LOWER_SLOT_IDS` /
  `QUALIFIER_ADVANCE_COUNT = 2`.)

  Ĭspayk and A'ace each hold a *starting* slot, both at the bottom of their
  bracket — `lower_4` for the fallen flagship, `upper_4` for the one that bought
  its way to the top table — and from their first season on they promote and
  relegate like anybody else. "Always starts" is a starting condition, not a pin.
- **No spiralling failure.** Failure is legible and gentle. A lost sponsorship
  costs morale and standing, never the club's survival. A bad month of meals is a
  bad month.
- **No solved systems.** Anything in the cozy half must stay expressive rather
  than optimal; the moment it acquires a correct answer it has changed halves.

## 8. Tone

Earnest and warm. Comedic where it is light -- a supplement-flavour tantrum, a
block everyone calls slommy -- and sincere where it is not, like a young voli's
development arc. Closer to a cozy management sim with real stakes than a satire
of one.

The test that catches most drift: **would this fit in a world where somebody says
"the cat can have a lil slommy" about a professional athlete's dinner?** If it
reads as bleak, ironic, or aggrieved, it is in the wrong world.
