using Godot;
using System;

public partial class Node2d : Node2D
{
	public override void _Ready()
	{
	// loading rules and settings
	GD.Print($"Max speed: { RulesLoader.Rules.Movement.MaxSpeed }");
	}
}
