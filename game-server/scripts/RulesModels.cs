using System;

public class Rules
{
    public double ProtocolVersion { get; set; }
    public Movement Movement { get; set; }
    public Combat Combat { get; set; }
}

public class Movement
{
    public double MaxRadius { get; set; }
    public double MaxSpeed { get; set; }
}

public class Combat
{
    public int BaseDamage { get; set; }
    public double CriticalMultiplier { get; set; }
}
public class Program
{
    public static void Main()
    {
        // Example usage
        Rules rules = new Rules
        {
            ProtocolVersion = 0.01,
            Movement = new Movement { MaxRadius = 100.0, MaxSpeed = 20.0 },
            Combat = new Combat { BaseDamage = 50, CriticalMultiplier = 1.5 }
        };

        double maxRadius = rules.Movement.MaxRadius;
        double maxSpeed = rules.Movement.MaxSpeed;
        int baseDamage = rules.Combat.BaseDamage;
        double criticalMultiplier = rules.Combat.CriticalMultiplier;

        Console.WriteLine($"Max Radius: {maxRadius}");
        Console.WriteLine($"Max Speed: {maxSpeed}");
        Console.WriteLine($"Base Damage: {baseDamage}");
        Console.WriteLine($"Critical Multiplier: {criticalMultiplier}");
    }
}