extends SceneTree

const MANIFEST_PATH := "res://docs/textbook/source_manifest.json"

var failures: Array[String] = []


func _init() -> void:
	_validate_manifest()
	if failures.is_empty():
		print("TEXTBOOK VALIDATION PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("TEXTBOOK VALIDATION FAILED: %d issue(s)" % failures.size())
	quit(1)


func _validate_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		failures.append("Missing manifest: %s" % MANIFEST_PATH)
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		failures.append("Could not open manifest: %s" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Manifest is not valid JSON object data")
		return
	var manifest: Dictionary = parsed
	for relative_path in manifest.get("book_files", []):
		_validate_file_exists(str(relative_path), "book file")
	for source_value in manifest.get("sources", []):
		if not source_value is Dictionary:
			failures.append("Source manifest entry is not a Dictionary")
			continue
		_validate_source(source_value)


func _validate_file_exists(relative_path: String, kind: String) -> void:
	var resource_path := "res://%s" % relative_path
	if not FileAccess.file_exists(resource_path):
		failures.append("Missing %s: %s" % [kind, relative_path])


func _validate_source(entry: Dictionary) -> void:
	var relative_path := str(entry.get("path", ""))
	if relative_path.is_empty():
		failures.append("Source entry has no path")
		return
	var resource_path := "res://%s" % relative_path
	if not FileAccess.file_exists(resource_path):
		failures.append("Missing source: %s" % relative_path)
		return
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		failures.append("Could not read source: %s" % relative_path)
		return
	var source_text := file.get_as_text()
	for symbol_value in entry.get("symbols", []):
		var symbol := str(symbol_value)
		if source_text.find(symbol) < 0:
			failures.append("Missing symbol '%s' in %s" % [symbol, relative_path])
