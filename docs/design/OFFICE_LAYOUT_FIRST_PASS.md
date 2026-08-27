# Office Layout — First Pass

## Status

Implementation-oriented first pass for the canonical manager office-bedroom.

This document turns the office-space design into a buildable spatial contract. It is deliberately more concrete than the higher-level UI documents, but it does **not** pretend that untested dimensions, camera transforms, or final art direction are settled. The first canonical Godot room should use this as its greybox brief; render evidence may move exact measurements while preserving the relationships below.

The room is one place. Main menu, load transition, Desk, calendar focus, visitor arrival, interview framing, and wider office views are cameras/states of that place, not separately authored rooms.

---

## 1. Canonical room proposition

The manager lives and works in a compact **office-bedroom**.

The room has two immediately legible halves:

- **work:** desk, calendar, wall history, phone/records and archive;
- **life:** bed and personal space.

The main-menu view is the widest recurring statement of that fact. Ordinary Desk mode intentionally crops most of the room away.

The room should feel modest enough that a visitor can enter and the manager can pull up a chair for a face-to-face conversation without revealing a hidden formal meeting room. Interviews are informal use of the existing room.

---

## 2. Coordinate convention for the greybox

Use one room-local coordinate system for all physical placement.

Recommended Godot convention for the first scene:

- `+X` = desk-right when the manager is seated;
- `-X` = desk-left;
- `+Z` = away from the desk wall / toward the room interior;
- `-Z` = desk wall;
- `+Y` = up.

The room origin should be a stable architectural point, preferably floor centre, rather than a camera or desk-object origin.

Every meaningful prop should have a room-space transform or a named anchor derived from one. Screen-space coordinates must not become a second source of spatial truth.

---

## 3. First greybox envelope

Start with a compact rectangular room approximately **4.8 m wide × 4.0 m deep × 2.6 m high**.

These measurements are a greybox hypothesis, not final canon. They are chosen to make the existing desk/bed thesis physically plausible while leaving enough floor space for an informal visitor chair and camera framing.

Do not tune the room by independently making each camera pretty. Tune the room until all required cameras work against the same geometry.

### First-pass plan

```text
                         DESK / HISTORY WALL
        -X                                      +X

   ┌──────────────────────────────────────────────────┐
   │                            framed history        │
   │                     calendar                    │
   │                                  window          │
   │                       ┌────────────────────┐     │
   │                       │       DESK         │     │
   │                       │                    │     │
   │                       └────────────────────┘     │
   │                              manager chair       │
   │                                                  │
   │  ┌──────────────┐               ○ guest chair   │
   │  │     BED      │                                │
   │  │              │        flexible conversation  │
   │  └──────────────┘               space            │
   │                                                  │
   │  archive / storage                         DOOR  │
   └──────────────────────────────────────────────────┘
                         ROOM INTERIOR / +Z
```

The diagram establishes relationships, not exact handedness of every centimetre. The title authority's major reading remains: **bed on the left, desk on the right** in the broad overhead composition.

---

## 4. Zone map

### 4.1 Desk zone — right / work side

The desk is the dominant object of the work half and the default career focal point.

It must have enough wall adjacency that the calendar and accumulated framed club history can remain visually connected to it.

The manager chair has a stable physical location. The title/load view may show it; Desk mode effectively occupies or looks through its position.

### 4.2 Calendar + history wall — beside/above the desk

The calendar is **wall-mounted by the desk**.

It is not a free-floating scheduling screen and not a Training child. Focusing it may expand into the full Calendar workspace, but the interaction begins from a known physical object.

The same wall provides a controlled field for club-history frames. Leave intentionally empty wall capacity in a new career. The wall should be able to become visibly richer without becoming unreadable.

### 4.3 Bed / personal zone — left side

The bed is in the same room. This is an office-bedroom, not an office with abstracted off-screen quarters.

The bed is visible in the broad main-menu/office view but ordinarily absent from seated Desk framing.

Potential interaction authority:

- sleep / intentionally pass a large span of time;
- manager sleeping representation on the main menu;
- possibly a route into personal appearance/presentation if a nearby mirror is later accepted.

The bed must not become the only save mechanism.

### 4.4 Archive / storage zone

The archive belongs away from the primary desk interaction field but inside the same room.

Its physical fullness may increase with career history. This should be readable at broad office scale without requiring a numerical label.

Detailed archive interaction is not required for the first canonical scene.

### 4.5 Door / arrival zone

The door must be visible from a plausible camera pan away from the desk.

It is primarily an **arrival/event anchor**:

- visitor enters;
- interview candidate arrives;
- future staff/person interactions may begin here.

Do not make the door a generic navigation menu merely because it exists. Leaving the office should be contextual when there is somewhere meaningful to go.

### 4.6 Flexible conversation zone

There is no formal interview station.

When somebody visits, the manager can pull up or turn a chair and have a face-to-face conversation in available floor space near the desk. The room should therefore preserve one useful conversational composition without permanently staging two chairs as an interview set.

The guest chair may normally sit against a wall, beside the desk, or otherwise out of the primary circulation path and move into place for an interview.

### 4.7 Window

The window has one stable architectural location.

It provides orientation and later supports:

- time-of-day light;
- weather/atmosphere;
- regional/club-office variation.

It must not migrate between title, Desk and interview compositions.

---

## 5. Canonical object inventory

### Architecture

- floor;
- desk/history wall;
- remaining walls;
- door + frame;
- window + frame.

### Fixed / large furniture

- desk;
- manager chair;
- bed;
- archive/storage object;
- movable guest chair.

### Wall objects

- calendar;
- framed-history anchor field;
- any pre-existing canonical decorative/history items once verified against their owning design docs.

### Desk objects

The existing Desk implementation should be used as evidence when fixing exact desk-object anchors. At minimum preserve the identity of:

- Journal;
- Training Clipboard;
- Scouting access/object;
- telephone;
- answering machine;
- Housing Folder;
- meal/kitchen planning object;
- encyclopedia/books/reference material;
- lamp / mug / small supporting props where retained.

The canonical scene must stop title and Desk from owning independent versions of these positions.

### Candidate future personal object

- mirror, **not yet canonical**.

A mirror is a strong candidate for viewing/changing manager appearance because it belongs to the bedroom half rather than system settings, but it should not be added merely to fill a wall.

---

## 6. Dynamic career-state surfaces

The room is allowed to change. Its **geography does not**.

### 6.1 Framed club history — automatic accretion

As club history is created, meaningful pictures become framed **automatically**.

Examples include:

- winning competitions;
- fan-favourite / club-icon Volis;
- important club events;
- especially significant team moments or seasons.

The player does not need to manually curate history for the office to age. Later rearrangement/customization may be allowed, but automatic framing is the baseline behavior.

The frame system should distinguish between:

- event eligibility: the simulation/history decides that something merits preservation;
- visual placement: the office chooses an available frame anchor/layout;
- optional player arrangement: a later presentation/customization layer.

A new career should have meaningful negative space. A long career should visibly carry history.

### 6.2 Archive growth

The archive physically fills as records accumulate.

Its visual stages can be coarse rather than continuous. The point is environmental evidence of history, not an inventory meter disguised as boxes.

### 6.3 Desk accretion

The desk and its objects may accumulate:

- sticky notes;
- temporary papers;
- current reminders;
- small career-specific traces.

Accretion must not destroy object recognition or clickable footprints. Persistent workspace objects remain immediately legible.

### 6.4 Job changes

Changing clubs should expose the distinction between **manager-owned history** and **club-owned room**.

A future job-change transition may show:

1. personal material being packed;
2. old office becoming bare;
3. arrival in a new, slightly different office-bedroom;
4. retained possessions being placed again.

Different clubs may vary room dimensions/materials/furnishings within a stable interaction grammar. The player should recognize where work, calendar, sleep, storage and arrival happen without every club owning an identical room mesh.

Exact ownership rules for individual pictures/trophies/archives remain a later design decision.

---

## 7. Camera authority

All cameras below must render the **same unchanged room state**.

### C0 — Main menu / save-selection overhead

Purpose:

- establish office-bedroom thesis;
- show bed, part/all of desk and chair, and enough room context to make it a place;
- sit beneath the existing floating title/menu graphics rather than forcing the menu labels into physical room geometry;
- reflect the selected/current career's office state where save metadata permits it.

Target character: high, graphic, likely orthographic or low-perspective distortion.

Required visibility:

- bed;
- desk + chair;
- meaningful slice of room architecture;
- dynamic history/clutter where readable;
- other elements only if composition permits.

### C1 — Load transition midpoint

Purpose:

- continuity proof, not a permanent gameplay camera.

The camera moves/rotates from C0 toward C2 while **nothing in the room relocates**.

This frame should be included in every early continuity render set.

### C2 — Ordinary Desk

Purpose:

- default management home;
- desk objects dominate;
- calendar and some wall pictures may remain visible;
- bed, archive and door ordinarily fall outside the composition.

Required visibility:

- desk work surface;
- persistent desk objects;
- wall-mounted calendar;
- wall-history material if composition permits.

### C3 — Calendar focus

Purpose:

- make the wall-mounted calendar the subject;
- preserve enough desk/wall context that the player understands this as looking at an office object, not teleporting to a detached app.

The full scheduling UI may then expand from this focus.

### C4 — Door / arrival

Purpose:

- visitor entrance;
- contextual attention shift when somebody comes into the office.

This should be reachable as a camera pan/reframe, not player traversal.

### C5 — Interview / face-to-face

Purpose:

- informal conversation after the visitor enters and a chair is pulled up;
- candidate/visitor becomes the primary subject;
- office remains unmistakably the same room.

No permanent interview set.

### C6 — Office wide / arrangement

Purpose:

- inspect the room as a whole;
- possible future decoration/rearrangement interface;
- access non-desk room objects if/when they become interactive.

This is a view switch, not free movement.

### Candidate C7 — Bed / personal focus

Only add if bed interaction or personal-space interaction proves valuable. Do not create a camera solely because every object appears to need one.

---

## 8. Camera behavior rule

There is **no free room traversal** in the target interaction model.

The manager's attention is represented by camera focus and panning:

```text
Desk
  -> calendar selected       -> calendar focus
  -> phone/desk event        -> local desk reframe
  -> somebody enters         -> pan to door
  -> visitor sits            -> interview framing
  -> room arrangement chosen -> office-wide framing
```

Camera motion should preserve orientation. A pan must not silently cross the room axis and make left/right relationships invert.

---

## 9. Main-menu continuity contract

The main menu is not merely themed after the office. It is a broad/top-down view of the same office-bedroom associated with the selected/current career, underneath the existing floating menu graphics.

The intended load sequence is:

```text
MAIN MENU
broad office-bedroom view
        |
select/load career
        |
selected career state is the room being shown
        |
camera descends / rotates toward desk
        |
menu graphics leave
        |
DESK
same desk, same room, same objects
```

The current title/Desk mismatch must not be repaired by hand-authoring a better imitation. Both views should ultimately derive from the canonical office scene or canonical room/object data.

---

## 10. First canonical Godot scene target

Recommended scene responsibility:

```text
CanonicalOffice
|
+-- Architecture
|   +-- Floor
|   +-- Walls
|   +-- Door
|   +-- Window
|
+-- DeskZone
|   +-- Desk
|   +-- ManagerChair
|   +-- DeskObjectAnchors
|
+-- SleepZone
|   +-- Bed
|
+-- StorageZone
|   +-- Archive
|
+-- WallZone
|   +-- CalendarAnchor
|   +-- HistoryFrameAnchors
|
+-- FlexibleSeating
|   +-- GuestChair
|
+-- DynamicState
|   +-- HistoryFrames
|   +-- ArchiveState
|   +-- DeskAccretion
|
+-- Cameras
    +-- MainMenu
    +-- TransitionMid
    +-- Desk
    +-- Calendar
    +-- Door
    +-- Interview
    +-- OfficeWide
```

Names may adapt to existing scene conventions. The architectural requirement is a single room truth, not this exact node spelling.

---

## 11. Greybox render packet

Before materials or decoration work, produce a fixed render packet from one scene state:

1. **Main Menu** — broad/top-down office-bedroom;
2. **Transition 50%** — camera halfway from Main Menu to Desk;
3. **Desk** — ordinary seated work composition;
4. **Calendar** — calendar focus;
5. **Door Arrival** — visitor-entry composition;
6. **Interview** — guest chair pulled into informal face-to-face position;
7. **Office Wide** — whole-room spatial audit.

Render at least one version with simple object labels or high-contrast greybox materials so continuity can be audited without aesthetic ambiguity.

The packet passes only if a reviewer can track the same desk, chair, calendar, bed, door, window, archive and major desk-object anchors through the relevant views without a spatial contradiction.

---

## 12. Continuity checklist

### Room

- [ ] One room footprint under every office-related camera.
- [ ] Desk orientation never changes.
- [ ] Bed remains on the established personal/left side in broad views.
- [ ] Door remains fixed relative to desk.
- [ ] Window remains fixed relative to desk.
- [ ] Calendar remains wall-mounted by the desk.
- [ ] Archive remains in its established storage zone.
- [ ] Conversation floor space exists without inventing another room.

### Desk

- [ ] Main-menu desk and Desk-mode desk are the same geometry/data.
- [ ] Major desk objects retain side/order/neighbour relationships.
- [ ] No object teleports during load transition.
- [ ] No object rotates merely because the camera changes.
- [ ] Dynamic notes/clutter do not obscure workspace identity.

### Cameras

- [ ] Main Menu composition works beneath the existing menu graphics.
- [ ] Transition midpoint does not invert the desk.
- [ ] Desk view shows desk + calendar + eligible wall history without requiring the whole room.
- [ ] Door view is reachable by coherent pan/reframe.
- [ ] Interview view uses flexible seating in the same room.
- [ ] Office-wide view explains the geography implied by all close views.

### Career state

- [ ] New-career room has deliberate empty history space.
- [ ] Framed club-history pictures can accumulate automatically.
- [ ] Archive has visible growth capacity.
- [ ] Desk has controlled accretion capacity.
- [ ] Long-career state does not make navigation illegible.
- [ ] Job-change design can distinguish room/club property from manager-kept material later.

---

## 13. First render/model acceptance test

The first 3D pass is **not** accepted because it looks attractive.

It is accepted when:

1. all seven greybox views can be rendered from one unchanged room;
2. Main Menu -> midpoint -> Desk reads as one continuous camera move;
3. no primary object changes relative position during that move;
4. the ordinary Desk composition is useful without exposing the entire bedroom;
5. the wide view clearly explains where the bed, door, archive, window and flexible guest space are;
6. the interview composition feels plausible without a dedicated meeting area;
7. the wall has credible capacity for automatic club-history accretion;
8. the room still has enough negative space to age over a career.

Only after this passes should the room receive a serious material, lighting, regional-variation, decoration or animation pass.

---

## 14. Unresolved before final spatial canon

These questions should be answered by greybox evidence rather than prose where possible:

- exact room dimensions and proportions;
- exact wall/window/door offsets;
- exact desk dimensions if existing Desk geometry does not already settle them;
- exact archive form and footprint;
- guest chair's resting position;
- frame-anchor count and layout strategy;
- whether a mirror earns canonical room space;
- whether the bed needs a dedicated focus camera;
- which existing framed-wall concepts are already authoritative elsewhere in the repo;
- how much selected-save office state can be represented on the main menu without loading the full career;
- whether main-menu room rendering should remain a 2D/3D composite or become a direct render of the canonical 3D room.

The next step is therefore **not another conceptual office document**. It is to build and render the greybox, compare the required cameras, and revise this file from visual evidence.
