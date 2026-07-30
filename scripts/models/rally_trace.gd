class_name RallyTrace
extends Resource

## Developer-facing evidence from a simulation or shadow calculation. Traces
## explain calculations but never determine official rally outcomes.
@export var trace_type: StringName = &""
@export var seed_value: int = 0
@export var entries: Array[Dictionary] = []
@export var summary: Dictionary = {}


static func create(kind: StringName, seed: int) -> RallyTrace:
	var trace := RallyTrace.new()
	trace.trace_type = kind
	trace.seed_value = seed
	return trace


func add_entry(entry: Dictionary) -> void:
	entries.append(entry.duplicate(true))


func to_dict() -> Dictionary:
	return {
		"trace_type": String(trace_type),
		"seed_value": seed_value,
		"entries": entries.duplicate(true),
		"summary": summary.duplicate(true),
	}
