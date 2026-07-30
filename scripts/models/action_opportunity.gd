class_name ActionOpportunity
extends RefCounted

var action_type: StringName = &""
var side: StringName = &""
var player_id: int = -1

var contact_position: Vector2 = Vector2.ZERO
var contact_time: float = 0.0
var travel_time: float = 0.0
var arrival_margin: float = 0.0

## Diagnostic decomposition. Contact reach now comes from player dimensions,
## action, body state, balance, and stability in ContactEnvelopeSystem.
var available_time: float = 0.0
var target_distance_meters: float = 0.0
var movement_capacity_meters: float = 0.0
var center_distance_deficit_meters: float = 0.0
var contact_reach_meters: float = 0.0
var contact_height_meters: float = 1.0
var standing_reach_meters: float = 0.0
var maximum_contact_height_meters: float = 0.0
var vertical_margin_meters: float = 0.0
var standing_reachable: bool = false
var jump_reachable: bool = false
var requires_jump: bool = false
var required_takeoff_time_seconds: float = 0.0
var takeoff_time_seconds: float = 0.0
var recovery_time_seconds: float = 0.0
var used_reaching_extension: bool = false
var maximum_speed_mps: float = 0.0
var acceleration_mps2: float = 0.0
var direction_change_delay_seconds: float = 0.0
var modeled_start_speed_mps: float = 0.0
var directional_start_speed_mps: float = 0.0
var directional_velocity_overcredit_mps: float = 0.0
## Attack-only takeoff evidence. These are resolved from the actual run-up,
## not copied from static player ratings.
var approach_speed_mps: float = 0.0
var approach_quality: float = 0.0
var approach_alignment: float = 1.0
var lateral_control: float = 1.0
var jump_multiplier: float = 1.0

var reachable: bool = false
var arrival_balance: float = 0.0
var physical_feasibility: float = 0.0
var technical_difficulty: float = 0.0
## This records tactical relevance; the later decision system owns selection.
var tactical_priority: float = 0.0
## X is the low estimate and Y is the high estimate.
var expected_quality: Vector2 = Vector2.ZERO
