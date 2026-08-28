extends Node
## Final desk-object readability correction for the canonical low-poly office.
## Runs after the procedural office builder so it changes the actual modeled scene,
## without reopening the locked Desk camera.

func _ready() -> void:
	call_deferred("_apply")

func _apply() -> void:
	var office := get_parent() as Node3D
	if office == null:
		return

	# Journal: move modestly inward and expose the navy cover. The original
	# JournalPageEdge was almost the full footprint, making the Journal read as
	# a pale clipboard/tablet instead of a bound book.
	var journal := office.find_child("Journal", true, false) as Node3D
	if journal != null:
		journal.position = Vector3(0.80, 0.84, -1.40)

	var page_edge := office.find_child("JournalPageEdge", true, false) as Node3D
	if page_edge != null:
		page_edge.position = Vector3(0.80, 0.861, -1.205)
		_set_box_size(page_edge, Vector3(0.29, 0.012, 0.028))

	# Clipboard remains readable but no longer owns the same left-center focal zone.
	var clipboard := office.find_child("TrainingClipboard", true, false) as Node3D
	if clipboard != null:
		clipboard.position = Vector3(1.10, 0.84, -1.43)
	var clip := office.find_child("ClipboardClip", true, false) as Node3D
	if clip != null:
		clip.position = Vector3(1.10, 0.86, -1.59)

func _set_box_size(node: Node3D, size: Vector3) -> void:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is BoxMesh:
			var box := (mesh as BoxMesh).duplicate() as BoxMesh
			box.size = size
			(node as MeshInstance3D).mesh = box
