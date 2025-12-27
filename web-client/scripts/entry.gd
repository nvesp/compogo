extends Node2D

func _ready() -> void:
	RulesLoader.load_rules()
	var protocol = RulesLoader.get_nested(["protocol_version"], 0.01)
	var max_speed = RulesLoader.get_nested(["movement", "max_speed"], 20.0)
	print("Max speed: %s" % str(max_speed))
	print("PROTOCOL VERSION: %s" % str(protocol))
