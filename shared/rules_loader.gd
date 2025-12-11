# res://shared/rules_loader.gd
extends Node

var rules = {}

#Usage in client code:
#  if new_pos.length() <= RulesLoader.get_max_radius():
#      player.position = new_pos

func load_rules(path: String = "res://shared/rules.json") -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if file:
        var text = file.get_as_text()
        var data = JSON.parse_string(text)
        if typeof(data) == TYPE_DICTIONARY:
            rules = data
            print("Rules loaded successfully")
        else:
            push_error("Failed to parse rules JSON")

func get_max_radius() -> float:
    return rules.get("movement", {}).get("max_radius", 100.0)

func get_max_speed() -> float:
    return rules.get("movement", {}).get("max_speed", 10.0)

func get_base_damage() -> int:
    return rules.get("combat", {}).get("base_damage", 5)
