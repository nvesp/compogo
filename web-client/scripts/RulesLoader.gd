extends Node

var rules: Dictionary = {}

func initialize_default_rules() -> void:
	rules = {
		"protocol_version": 0.020,
		"movement": {
			"max_radius": 100.0,
			"max_speed": 20.0
		},
		"combat": {
			"base_damage": 50,
			"critical_multiplier": 1.5
		}
	}
	print("Default rules initialized successfully!")

func load_rules(path: String = "res://../shared/rules.json") -> void:
	if not FileAccess.file_exists(path):
		printerr("Rules file not found: %s" % path)
		initialize_default_rules()
		print("Default rules initialized instead")
		return

	var text: String = FileAccess.get_file_as_string(path)
	var res = JSON.parse_string(text)
	var parsed = res
	if typeof(parsed) == TYPE_DICTIONARY:
		rules = parsed
		print("Loaded rules from %s" % path)
	else:
		printerr("Rules JSON root is not a Dictionary")
		initialize_default_rules()
		print("Default rules initialized instead")

func get_nested(path: Array, default = null):
	var cur = rules
	for k in path:
		if typeof(cur) != TYPE_DICTIONARY:
			return default
		if not cur.has(k):
			return default
		cur = cur[k]
	return cur
