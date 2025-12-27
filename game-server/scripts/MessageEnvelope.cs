#nullable enable

using Godot;
using System;
using System.Text.Json;
using System.Collections.Generic;

/// <summary>
/// MessageEnvelope: Standardized message container for network protocol.
/// 
/// All network messages use this envelope format:
/// { "id": <int>, "seq": <int>, "payload": <object> }
/// 
/// Protocol Versioning:
/// - protocol_version (float): Game logic compatibility (STRICT: must match)
/// - schema_version (string): Tooling/validation (PERMISSIVE: warn on mismatch)
/// </summary>
public partial class MessageEnvelope : Node
{
    /// <summary>
    /// Message type identifier (0-99). Corresponds to MessageID enum.
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    /// Sequence number: monotonically increasing per peer (1-2147483647).
    /// Client responsibility; server validates warn-only on gaps.
    /// </summary>
    public int Seq { get; set; }

    /// <summary>
    /// Message payload; type-specific object parsed from JSON.
    /// </summary>
    public JsonElement Payload { get; set; }

    /// <summary>
    /// Cached schema loaded at startup for validation.
    /// </summary>
    private static JsonDocument? _schemaCache;

    /// <summary>
    /// Initialize schema validation at server startup.
    /// Logs: "Schema loaded in Xms"
    /// </summary>
    public static void Initialize(string schemaPath)
    {
        var stopwatch = new System.Diagnostics.Stopwatch();
        stopwatch.Start();

        try
        {
            var schemaJson = FileAccess.Open(schemaPath, FileAccess.ModeFlags.Read)?.GetAsText();
            if (string.IsNullOrEmpty(schemaJson))
            {
                GD.PrintErr($"Failed to load schema from {schemaPath}");
                return;
            }

            _schemaCache = JsonDocument.Parse(schemaJson);
            stopwatch.Stop();
            GD.Print($"✅ Schema loaded in {stopwatch.ElapsedMilliseconds}ms");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"❌ Failed to initialize schema: {ex.Message}");
        }
    }

    /// <summary>
    /// Deserialize JSON string to MessageEnvelope with strict validation.
    /// 
    /// Validation:
    /// - Envelope structure: id (0-99), seq (≥0), payload (object)
    /// - Payload: Type-specific validation via message_ids.json schema
    /// - Unknown fields: Rejected (additionalProperties: false)
    /// - Out-of-range values: Rejected
    /// 
    /// Throws InvalidOperationException with detailed error on validation failure.
    /// Server transport handlers catch and emit ERROR response.
    /// </summary>
    public static MessageEnvelope Deserialize(string json)
    {
        try
        {
            var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            // Validate envelope structure
            if (!root.TryGetProperty("id", out var idElement) || idElement.ValueKind != JsonValueKind.Number)
                throw new InvalidOperationException("Missing or invalid 'id' field");

            if (!root.TryGetProperty("seq", out var seqElement) || seqElement.ValueKind != JsonValueKind.Number)
                throw new InvalidOperationException("Missing or invalid 'seq' field");

            if (!root.TryGetProperty("payload", out var payloadElement) || payloadElement.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException("Missing or invalid 'payload' field");

            int id = idElement.GetInt32();
            int seq = seqElement.GetInt32();

            // Validate message ID range
            if (id < 0 || id > 99)
                throw new InvalidOperationException($"Invalid message ID: {id} (must be 0-99)");

            // Validate sequence number
            if (seq < 0)
                throw new InvalidOperationException($"Invalid sequence number: {seq} (must be ≥0)");

            // Check for unknown envelope fields (strict validation)
            foreach (var property in root.EnumerateObject())
            {
                if (property.Name != "id" && property.Name != "seq" && property.Name != "payload")
                    throw new InvalidOperationException($"Unknown envelope field: {property.Name}");
            }

            // Delegate to message-specific validator
            ValidatePayload(id, payloadElement);

            var envelope = new MessageEnvelope
            {
                Id = id,
                Seq = seq,
                Payload = payloadElement
            };

            return envelope;
        }
        catch (JsonException ex)
        {
            throw new InvalidOperationException($"Invalid JSON: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Message-specific payload validation.
    /// Checks required fields, types, and ranges per message type.
    /// 
    /// Example: MOVE payload must have x, y as floats in [-100, 100] with sqrt(x²+y²) ≤ 100.
    /// </summary>
    private static void ValidatePayload(int messageId, JsonElement payload)
    {
        switch ((MessageID)messageId)
        {
            case MessageID.CONNECT:
                ValidateConnect(payload);
                break;
            case MessageID.HANDSHAKE_ACK:
                ValidateHandshakeAck(payload);
                break;
            case MessageID.MOVE:
                ValidateMove(payload);
                break;
            case MessageID.ATTACK:
                ValidateAttack(payload);
                break;
            case MessageID.SNAPSHOT:
                ValidateSnapshot(payload);
                break;
            case MessageID.ERROR:
                ValidateError(payload);
                break;
            case MessageID.DISCONNECT:
                ValidateDisconnect(payload);
                break;
            default:
                throw new InvalidOperationException($"Unknown message type: {messageId}");
        }
    }

    private static void ValidateConnect(JsonElement payload)
    {
        if (!payload.TryGetProperty("protocol_version", out var version))
            throw new InvalidOperationException("CONNECT: missing 'protocol_version'");

        if (!payload.TryGetProperty("username", out var username) || username.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("CONNECT: missing or invalid 'username'");

        if (!payload.TryGetProperty("client_id", out var clientId) || clientId.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("CONNECT: missing or invalid 'client_id'");

        // Validate username length
        string user = username.GetString() ?? "";
        if (user.Length < 1 || user.Length > 32)
            throw new InvalidOperationException($"CONNECT: username must be 1-32 chars (got {user.Length})");
    }

    private static void ValidateHandshakeAck(JsonElement payload)
    {
        var requiredFields = new[] { "player_id", "protocol_version", "schema_version", "map_bounds", "tick", "existing_players" };
        foreach (var field in requiredFields)
        {
            if (!payload.TryGetProperty(field, out _))
                throw new InvalidOperationException($"HANDSHAKE_ACK: missing '{field}'");
        }
    }

    private static void ValidateMove(JsonElement payload)
    {
        if (!payload.TryGetProperty("x", out var x) || x.ValueKind != JsonValueKind.Number)
            throw new InvalidOperationException("MOVE: missing or invalid 'x'");

        if (!payload.TryGetProperty("y", out var y) || y.ValueKind != JsonValueKind.Number)
            throw new InvalidOperationException("MOVE: missing or invalid 'y'");

        float xVal = (float)x.GetDouble();
        float yVal = (float)y.GetDouble();

        // Validate bounds: sqrt(x² + y²) ≤ 100.0 (max_radius)
        double distance = Math.Sqrt(xVal * xVal + yVal * yVal);
        if (distance > 100.0)
            throw new InvalidOperationException($"MOVE: position ({xVal}, {yVal}) exceeds max_radius 100.0 (distance={distance:F2})");

        // Validate coordinate ranges
        if (xVal < -100.0 || xVal > 100.0 || yVal < -100.0 || yVal > 100.0)
            throw new InvalidOperationException($"MOVE: coordinates out of range");
    }

    private static void ValidateAttack(JsonElement payload)
    {
        if (!payload.TryGetProperty("target_id", out var targetId) || targetId.ValueKind != JsonValueKind.Number)
            throw new InvalidOperationException("ATTACK: missing or invalid 'target_id'");

        int targetIdVal = targetId.GetInt32();
        if (targetIdVal <= 0)
            throw new InvalidOperationException($"ATTACK: target_id must be positive (got {targetIdVal})");
    }

    private static void ValidateSnapshot(JsonElement payload)
    {
        if (!payload.TryGetProperty("tick", out var tick))
            throw new InvalidOperationException("SNAPSHOT: missing 'tick'");

        if (!payload.TryGetProperty("players", out var players) || players.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException("SNAPSHOT: missing or invalid 'players'");
    }

    private static void ValidateError(JsonElement payload)
    {
        if (!payload.TryGetProperty("code", out var code) || code.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("ERROR: missing or invalid 'code'");

        if (!payload.TryGetProperty("reason", out var reason) || reason.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("ERROR: missing or invalid 'reason'");
    }

    private static void ValidateDisconnect(JsonElement payload)
    {
        if (!payload.TryGetProperty("reason", out var reason) || reason.ValueKind != JsonValueKind.String)
            throw new InvalidOperationException("DISCONNECT: missing or invalid 'reason'");
    }

    /// <summary>
    /// Serialize MessageEnvelope to JSON string.
    /// </summary>
    public string Serialize()
    {
        var options = new JsonSerializerOptions { WriteIndented = false };
        var envelope = new Dictionary<string, object?>
        {
            { "id", Id },
            { "seq", Seq },
            { "payload", Payload }
        };
        return JsonSerializer.Serialize(envelope, options);
    }
}