using Godot;
using System;
using System.ComponentModel;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;

// Usage in server code:
//  if (pos.Length() <= RulesLoader.MaxRadius)
//  {
//   // Valid move
//  }

public class RulesLoader
{
	private static Rules rules;
	public static Rules Rules => rules;
		public static void InitializeDefaultRules()
		{
			rules = new Rules
			{
				ProtocolVersion = 0.01,
				Movement = new Movement { MaxRadius = 100, MaxSpeed = 20.0 },
				Combat = new Combat { BaseDamage = 50, CriticalMultiplier = 1.5 },
			};
		GD.Print("Default rules initialized successfully!");
		}


	/* FIXME: Re-enable JSON loading later, use manual defaults for now.
		public static void LoadRules(string path = "res://../shared/rules.json")
	{
		if (!FileAccess.FileExists(path))
		{
			GD.PrintErr("Rules file not found!");
			return;
		}

		var jsonText = FileAccess.Open(path, FileAccess.ModeFlags.Read).GetAsText();
		try
		{
			var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
			rules = JsonSerializer.Deserialize<Rules>(jsonText, options);
			if (rules == null)
			{
				GD.PrintErr("Failed to deserialize rules JSON.");
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"Error deserializing rules.json: {ex.Message}");
		}
	}


	public static float MaxRadius =>
		rules?.Movement != null ? (float)rules.Movement.MaxRadius : 0f;

	public static float MaxSpeed =>
		rules?.Movement != null ? (float)rules.Movement.MaxSpeed : 0f;

	public static int BaseDamage =>
		rules?.Combat != null ? rules.Combat.BaseDamage : 0;
	*/
}
