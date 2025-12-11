using Godot;
using System;
using System.Collections.Generic;

// Usage in server code:
//  if (pos.Length() <= RulesLoader.MaxRadius)
//  {
//   // Valid move
//  }

public static class RulesLoader
{
    private static Dictionary<string, object> rules;

    public static void LoadRules(string path = "res://shared/rules.json")
    {
        var file = new FileAccess();
        if (!FileAccess.FileExists(path))
        {
            GD.PrintErr("Rules file not found!");
            return;
        }

        var jsonText = FileAccess.Open(path, FileAccess.ModeFlags.Read).GetAsText();
        var json = Json.ParseString(jsonText);
        rules = (Dictionary<string, object>)json;
        GD.Print("Rules loaded successfully");
    }

    public static float MaxRadius =>
        Convert.ToSingle(((Dictionary<string, object>)((Dictionary<string, object>)rules["movement"]))["max_radius"]);

    public static float MaxSpeed =>
        Convert.ToSingle(((Dictionary<string, object>)((Dictionary<string, object>)rules["movement"]))["max_speed"]);

    public static int BaseDamage =>
        Convert.ToInt32(((Dictionary<string, object>)((Dictionary<string, object>)rules["combat"]))["base_damage"]);
}
