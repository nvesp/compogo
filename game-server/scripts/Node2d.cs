using Godot;
using System;

public partial class Node2d : Node2D
{
	public override void _Ready()
	{
	// loading rules and settings
	RulesLoader.InitializeDefaultRules();
	GD.Print($"Max speed: { RulesLoader.Rules.Movement.MaxSpeed }");
	}
}
