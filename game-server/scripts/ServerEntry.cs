using Godot;
using System;

public partial class ServerEntry : Node2D
{
	public override void _Ready()
	{
	// loading rules and 
	var schemaPath = "res://../shared/message_ids.json";
	RulesLoader.InitializeDefaultRules();
	GD.Print($"Max speed: { RulesLoader.Rules.Movement.MaxSpeed }");
	MessageEnvelope.Initialize(schemaPath);
	}
}
