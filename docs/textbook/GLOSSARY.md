# Glossary

Short refreshers for terms that recur across the textbook. For full explanation, follow [INDEX.md](INDEX.md).

## Godot / GDScript

### Annotation
A `@...` marker that changes how Godot treats a declaration, e.g. `@export` or `@export_range`.

### Autoload
A script/scene Godot creates at startup under `/root` so it persists across screen/scene changes. VWM uses managers such as `CareerManager` and `GameManager` this way.

### `await`
Suspends the current GDScript function until a signal/awaitable event occurs while the engine continues running. Used in rendering/frame-sensitive code such as sticker baking.

### Class
A definition of data/behavior. `class_name RallyState` gives a GDScript class a globally recognizable type name.

### `class_name`
Declares a global GDScript class name for a script.

### `const`
A named value that the script does not reassign. Constants can hold numbers, Strings, preloaded scripts/scenes, Arrays, etc.

### `Control`
Godot's UI-oriented Node family. Buttons, Labels, Containers, panels and many VWM screens derive from `Control`.

### Container
A `Control` that lays out its child Controls. Examples: `VBoxContainer`, `HBoxContainer`, `MarginContainer`, `PanelContainer`, `ScrollContainer`.

### Dictionary
Key/value collection (`{}`). Flexible and useful for dynamic records, but keys/types are checked mostly at runtime.

### `emit` / signal emission
Publishing a Godot signal so connected callbacks are invoked. In GDScript: `my_signal.emit(value)`.

### `extends`
Declares inheritance, e.g. `extends Resource`, `extends Button`.

### Exported property
A property annotated with `@export...` so Godot understands it as editor/resource data and can expose it in the Inspector.

### Inspector
The Godot editor panel used to view/edit properties of the selected Node/Resource.

### Instance
One runtime object created from a class/scene. A `.tscn` scene definition and a Node instantiated from it are not the same thing.

### `instantiate()`
Creates a runtime scene instance from a `PackedScene`.

### Local Scene Tree
The authored scene hierarchy in the editor.

### Node
A runtime object that can live in Godot's SceneTree and have children/lifecycle/input/rendering behavior.

### `null`
Absence of an object/value. A cast or lookup can legitimately return `null`; whether that is acceptable depends on the contract.

### `preload()`
Loads a resource when the script is parsed/loaded. Common for scripts/scenes known ahead of time.

### `res://`
Path prefix for files inside the Godot project/resources.

### Resource
A Godot data object that does not need to live in the SceneTree. VWM uses Resources heavily for players, teams, careers, events, fixtures, etc.

### RefCounted
Lightweight Godot object whose lifetime is managed by reference count. Many VWM stateless/system/helper classes extend it rather than Node.

### Remote Scene Tree
The actual runtime Node hierarchy visible in Godot's debugger while the game is running. Essential for code-built screens/components.

### Scene (`.tscn`)
A serialized tree of Nodes that can be edited and instantiated.

### Signal
Godot's event/message mechanism. One object emits; other objects can connect callbacks without the producer needing direct knowledge of them.

### Static function
A function called on the class/script rather than a specific instance. VWM uses many static system calculations.

### StyleBox
Godot Theme resource describing rectangular UI appearance/margins/borders/corners/shadows for states such as normal/hover/pressed.

### SubViewport
A separate render target that can render a scene off-screen. VWM uses one to bake 3D player poses into 2D sticker images.

### Theme
Godot resource that defines styles/fonts/colors/constants for Control types and variations.

### Theme Type Variation
A named variation (e.g. a VWM button/card role) that lets Controls reuse shared Theme styles without custom overrides everywhere.

### `user://`
Godot's platform-specific writable application-data directory. Appropriate for saves/settings/caches.

### `var`
Declares mutable data. `var x := expression` asks GDScript to infer the static type; `var x: Type = ...` states it explicitly.

### Variant
Godot's general-purpose value type. Dictionaries and many dynamic APIs return Variant; cast/check before assuming a specific object/type.

### Vector2 / Vector3
Two-/three-component vector value types used for positions, directions and velocities. Meaning/units depend on subsystem convention.

## VWM architecture

### Action opportunity
A possible action for one player at a particular time/contact geometry. `ActionOpportunity`/related records carry physical availability rather than final choice.

### Action choice
Selection among legal/physically feasible actions using player information, ability/tendencies and tactics. Choice should not widen physical feasibility.

### Attribute ceiling
A player's per-attribute developmental maximum. Distinct from current rating and from the scalar potential summary.

### Authoritative
The layer/value that actually decides the simulated fact. Diagnostics, presentation and shadow candidates may describe alternatives without being authoritative.

### Authored game abstraction
A deliberately chosen simplified model magnitude whose exact value is not derived/measured. Must be documented honestly rather than presented as empirical fact.

### Ball / trajectory authority
The contact creates an outgoing launch; free flight and interactions determine what happens next. Intended recipient/presentation endpoint must not rewrite it.

### Body centre vs contact point
The athlete's body position and the ball-contact coordinate are different physical facts. M3 derives platform stand-off from body/contact geometry.

### Certification
Evidence that a subsystem/boundary satisfies explicit invariants. Isolated certification, live integration, production promotion and legacy retirement are distinct stages.

### Contact number
The team's ordinary contact count after possession (1/2/3). It is context, **not** synonymous with reception/set/attack action type.

### Controlled fixture
A hand/seed-authored deterministic situation designed to exercise a specific legal branch or invariant.

### Coverage
In current rally docs, often attack/block coverage: the attacking team trying to keep a blocked ball alive. Distinct from opponent floor defence/dig.

### Derived value
A magnitude that follows mathematically from other accepted facts (e.g. projectile velocity at time).

### Development rollout
A path that can be exercised/certified in explicit development fixtures without necessarily being production-authoritative in ordinary rallies.

### Event
`RallyEvent`: a resolved action record for playback/statistics/analysis. Not the complete physical world state.

### Feasibility
What ball/body/rules make possible. Physical feasibility is separate from tactical preference/responsibility and from legality.

### Free flight
An authoritative ball flight constructed from a resolved launch and allowed to continue toward its natural terminal unless physically intercepted/interacted with.

### Intended recipient
A tactical/decision intent for where a ball should be useful. It is not the physical endpoint or guaranteed actual interceptor.

### Legacy authority
Older mechanism that still decides behavior while a replacement is shadow/development-only. A migration is not complete until authority is promoted/retired explicitly.

### Manager
A stateful coordinator/service such as `CareerManager` or `GameManager`.

### Measured value
A value produced by a known instrument/observation with understood units/provenance.

### Model
A data-focused class, usually a Resource under `scripts/models/`.

### Normalized court coordinate
Many court positions represented from roughly `0..1` in x/y, converted to metres/screen pixels when needed. Do not confuse normalized units with metres.

### Perception / estimate
What an actor/manager currently believes about truth. Rally reads and scouting reports can be imperfect without changing underlying truth.

### Persistent state
State carried across relevant time/phase boundaries rather than reconstructed from a convenient endpoint.

### Playback
Visual presentation of already-resolved state/events. It must not secretly decide physical ownership, launch, movement feasibility or outcome.

### Probe
Purpose-built measurement/certification tool, often under `tools/`. A good probe can falsify its hypothesis and names units/fixture conditions.

### Realised prefix / segment
The exact portion of an authoritative free flight actually played before a later contact. It retains the source flight ID/launch and does not rewrite the source.

### Responsibility
Which actor should claim/own a team action among physically viable candidates. Assignment/proximity can inform it but cannot override impossibility.

### Shadow system
Historical/current diagnostic architecture that computes a candidate without owning official outcome. Useful for comparison/calibration, not automatically live authority.

### System
A calculation/behavior module, often mostly stateless and frequently implemented as a RefCounted class with static methods.

### T1 / T2 / T3
M4's shared platform-contact relations: T1 outgoing pace, T2 reachable redirection envelope, T3 technique-driven angular execution error.

### Tactical home
A desired movement/reference position, not a teleport/reset command.

### Truth label
Textbook labels such as VERIFIED, PARTIALLY IMPLEMENTED, PROPOSED, HISTORICAL used to keep current source, future design and migration history distinct.
