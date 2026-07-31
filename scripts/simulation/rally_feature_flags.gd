class_name RallyFeatureFlags
extends RefCounted

## Production rollout switches. Keep disabled until the corresponding
## calibration gate explicitly authorizes live use.
const ENABLE_CONTINUOUS_RECEPTION_EVENTS: bool = false
const ALLOW_DEVELOPMENT_RECEPTION_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_SETTER_EVENTS: bool = false
const ALLOW_DEVELOPMENT_SETTER_OVERRIDE: bool = true
const ENABLE_CONTINUOUS_ATTACK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_ATTACK_OVERRIDE: bool = true
## Gate 48 adds only the selection boundary. No block contact is promotable
## yet -- the development override stays false until Gate 49 reviews and
## implements the promotion path behind an explicit debug fixture.
const ENABLE_CONTINUOUS_BLOCK_EVENTS: bool = false
const ALLOW_DEVELOPMENT_BLOCK_OVERRIDE: bool = false
