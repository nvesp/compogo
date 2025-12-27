# Compogo Game Protocol Specification

## Overview

This document defines the network protocol for Compogo, hybrid game server (C#/Godot) and web client (GDScript/Godot) Godot Engine projects. The protocol uses a standardized envelope format with versioning for game logic and tooling.

## Versioning

### Protocol Version

- **Field:** `protocol_version` (float64, e.g., 0.020)
- **Scope:** Game logic compatibility
- **Enforcement:** **STRICT** Client and server must match exactly; mismatch triggers hard disconnect
- **Bump Policy:** Increment only on breaking game mechanic changes (movement rules, damage calculation, etc.)
- **Client Behavior on Mismatch:** Display error, disconnect, and inform user that auto-update is required

**Example:** Client protocol_version 0.019 connecting to server 0.020 triggers ERROR(PROTOCOL_VERSION_MISMATCH) and hard disconnect.

### Schema Version

- **Field:** `schema_version` (string, e.g., "1.0.0")
- **Scope:** Tooling, validation, and message structure
- **Enforcement:** **PERMISSIVE** Client warns on mismatch but does NOT disconnect
- **Bump Policy:** Increment on message schema changes (new fields, validation updates, etc.) that don't affect game logic
- **Client Behavior on Mismatch:** Log warning, display optional UI notification, but continue operation

**Example:** Client schema_version "1.0.0" connected to server schema_version "1.1.0"; client logs "Warning: schema version mismatch (1.0.0 vs 1.1.0)" but continues normal gameplay.

---

## Envelope Format

All messages use a standardized envelope:

```json
{
  "id": <integer>,
  "seq": <integer>,
  "payload": <object>
}
```

## Envelope Fields

| FIELD   | TYPE   | REQUIRED | DESCRIPTION                                       |
| ------- | ------ | -------- | ------------------------------------------------- |
| id      | int32  | YES      | Message type identifier (0-99)                    |
| seq     | int32  | YES      | Monotonically increasing sequence number per peer |
| payload | object | YES      | Message-specific-fields; structure varies by id   |

## Sequence Number (Seq)

### Client Responsibility

- **Increment before each send; globally monotonic per session**
- **No Reset:** Continues across entire session; resets to 1 on reconnect
- **Server Validation:** Warn-only on gaps (>5) or duplicates; do NOT disconnect on seq anomalies
- **Use Cases:** Message deduplication on reconnect, out-of-order detection, request-response pairing
  
### Example Seq Flow

- Client sends `CONNECT seq=1`
- Client sends `MOVE seq=2` (after ACK)
- Client sends `MOVE seq=3`
- Server receives `MOVE seq=3`, then `MOVE seq=2` (out-of-order); warns, processes both

---

## System Messages (ID 0–9)

### CONNECT (ID 0)

- **Direction:** Client -> Server  
- **Purpose:** Initiate connection; exchange protocol version and identity

- ### Payload Schema

 ```json
{
  "protocol_version": <float64>,
  "username": <string 1–32 alphanumeric>,
  "client_id": <string UUID or session ID>
}
```

- ### Server Validation

- `protocol_version` must match server **eg:** (0.020)
- `username` must be unique and not already in session
- `client_id` enables deduplication on reconnect

- ### Server Response

- **Match** -> `HANDSHAKE_ACK`
- **Version mismatch** -> (`ERROR_PROTOCOL_VERSION_MISMATCH`, reason="Client 0.019 incompatible with server 0.020")
- **Username exists** -> (`ERROR_PLAYER_ALREADY_CONNECTED`, reason="Username already exists on this server")

### HANDSHAKE_ACK (ID 1)

- **Direction:** Server -> Client
- **Purpose:** Confirm connection; supply initial state

- ### Payload Schema

```json
{
  "player_id": <int32>,
  "protocol_version": <float64>,
  "schema_version": <string>,
  "map_bounds": { "max_radius": <float64> },
  "tick": <int32>,
  "existing_players": [ { "id", "username", "x", "y", "health", "status" }, ... ]
}
```

- ### Client Behavior

- **Check protocol_version:** hard disconnect if mismatch
- **Check schema_version:** log warning if mismatch, but continue
- Store `player_id`, render map bounds
- Populate initial player list

### ERROR (ID 5)

- **Direction:** Server -> Client
- **Purpose:** Report validation failure or protocol violation

- ### Payload Schema

### Error Codes & Triggers

| CODE                      | TRIGGER                         | CLIENT ACTION                    | SEVERITY |
| ------------------------- | ------------------------------- | -------------------------------- | -------- |
| PROTOCOL_VERSION_MISMATCH | CONNECT version != server       | Disconnect; show upgrade prompt  | FATAL    |
| INVALID_MOVE              | Out of bounds OR speed exceeded | Rollback; re-send corrected MOVE | WARN     |
| INVALID_ATTACK            | Target not found OR dead        | Discard; continue                | WARN     |
| RATE_LIMITED              | >1 MOVE/tick OR >2 ATTACK/tick  | Que client-side; retry next tick | WARN     |
| UNAUTHORIZED              | Auth token invalid/expired      | Redirect to login                | FATAL    |
| INTERNAL_SERVER_ERROR     | Server exception                | Exponential backoff reconnect    | FATAL    |

### DISCONNECT (ID 6)

- **Direction:** Client <-> Server
- **Purpose:** Graceful session termination

- ### Payload Schema

```json
{
  "reason": <string "player_quit" | "inactivity" | "protocol_error" | "maintenance">,
  "message": <string optional>
}
```

---

## Movement Messages (ID 10–19)

### MOVE (ID 2)

- **Direction:** Client -> Server
- **Purpose:** Movement input; server validates and broadcasts

- ### Payload Schema

```json
{  "x": <float32 -100.0 to +100.0>,  
   "y": <float32 -100.0 to +100.0>,  
   "timestamp_client_ms": <int64 optional>
}
```

- ### Server Validation

- **Bounds:** sqrt(x² + y²) ≤ 100.0 (`max_radius`)
- **Speed:** If timestamp provided, estimated speed = distance / time; if > 20.0 -> `INVALID_MOVE`
- **Rate:** Max 1 MOVE per tick per peer

- ### Server Response

- `SNAPSHOT` (with updated position) or `ERROR`

## Combat Messages (ID 30–39)

### ATTACK (ID 3)

- **Direction:** Client -> Server
- **Purpose:** Attack target; server validates and applies damage

- ### Payload Schema

```json
{
  "target_id": <int32>,
  "is_critical": <boolean optional>
}
```

- ### Damage Calculation

- **Base damage:** 50 (`rules.combat.base_damage`) `base_damage` = `rules.combat.base_damage`
- **If is_critical:** 2.0 (`rules.combat.is_critical`) `damage` = `base_damage` × 2.0 = 100
- **Else:** `damage` = 50

- ### Server Validation

- Target exists and `health` > 0
- Apply `damage`; broadcast in `SNAPSHOT`

- ### Server Response

- `SNAPSHOT` (with updated `health`) or `ERROR`

---

## Broadcast Messages (ID 40–49)

### SNAPSHOT (ID 4)

- **Direction:** Server -> Clients
- **Purpose:** Authoritative state broadcast
- **Broadcast Frequency:** 30 Hz (every ~33 ms)

- ### Payload Schema

```json
{
  "tick": <int32>,
  "players": [ { "id", "username", "x", "y", "health", "status" }, ... ],
  "events": [ { "type", "attacker_id", "target_id", "damage", "is_critical" }, ... ]
}
```

- ### Events

- **damage_dealt:** { attacker_id, target_id, damage, is_critical }
- **player_joined:** { id, username }
- **player_left:** { id }
- **kill:** { attacker_id, target_id }

## Data Type Mapping

| DOMAIN         | FIELD                | C# TYPE | GDSCRIPT TYPE | RANGE              | NOTES                                         |
| -------------- | -------------------- | ------- | ------------- | ------------------ | --------------------------------------------- |
| COORDS         | x,y                  | float   | float         | [-100, 0, +100, 0] | Float32 on wire; cartesian distance validated |
| IDs            | player_id, target_id | int32   | int           | 1-2,147,483,647    | Positive; server-assigned                     |
| Health         | health               | int32   | int           | 0-100              | Clamped; 0 = dead                             |
| Damage         | damage               | int32   | int           | 50-100             | 50 base; 100 crit                             |
| Tick           | tick                 | int32   | int           | 0- 2,147,483,647   | Wraps at 2^31                                 |
| Version        | protocol_version     | float64 | float         | 0.010+             | Must match exactly                            |
| Schema Version | schema_version       | string  | string        | "1.0.0"+           | Warn on mismatch                              |

## Validation Rules

- Tied to `shared/rules.json`

| Rule                | Value | Applied To | Validation                                         |
| ------------------- | ----- | ---------- | -------------------------------------------------- |
| max_radius          | 100.0 | MOVE       | sqrt(c2 + y2) < 100.0 -> INVALID_MOVE if exceeded  |
| max_speed           | 20.0  | MOVE       | distance / time < 20.0 -> INVALID_MOVE if exceeded |
| base_damage         | 50    | ATTACK     | Applied each hit; crit doubles to 100              |
| critical_multiplier | 2.0   | ATTACK     | Damage = base x multiplier if is_critical          |

---

## Golden Samples

- Golden samples are canonical message payloads stored in `shared/golden/` for cross-language serialization testing.

### Sample Naming Convention

- **Positive samples:** message_MESSAGETYPE_PROTOCOLVERSION.json
- **Example:** message_MOVE_0.020.json

- **Negative samples:** message_MESSAGETYPE_ERROR_PROTOCOLVERSION.json
- **Example:** message_MOVE_INVALID_OOB_0.020.json

### Validation Requirements

- **Positive samples:** Must pass schema validation (ajv or equivalent)
- **Negative samples:** Must fail validation with documented error code
- **Maintenance:** Regenerate samples after any `message_ids.json` or `rules.json` changes via fish `scripts/update_golden_samples.fish`

### Compression Policy

- Individual .json files per message type per version (current)
- Consider compression (.tar.gz or .jsonl) only if sample count exceeds 50

## Message Flow Examples

### Example 1: Successful Connection Handshake

```json
Client -> Server: CONNECT seq=1
  { "protocol_version": 0.020, "username": "Alice", "client_id": "abc123" }

Server validates: version OK, username unique
  ↓

Server -> Client: HANDSHAKE_ACK seq=1
  { "player_id": 42, "protocol_version": 0.020, "schema_version": "1.0.0", 
    "map_bounds": { "max_radius": 100.0 }, "tick": 1000, 
    "existing_players": [ ... ] }

Client receives: Stores player_id=42, renders initial state
```

### Example 2: Movement with validation

```json
Client -> Server: MOVE seq=2
  { "x": 45.5, "y": 32.0, "timestamp_client_ms": 1702988400500 }

Server validates: 
  - sqrt(45.5² + 32.0²) ≈ 55.5 ≤ 100.0 ✓
  - Speed check: distance=55.5, time=50ms, speed≈1110 m/s (excessive!)
  ↓

Server -> Client: ERROR seq=N
  { "code": "INVALID_MOVE", "reason": "Movement speed exceeds max_speed (20.0)", 
    "offending_seq": 2 }

Client: Rolls back position to last SNAPSHOT, displays "Movement too fast"
```

### Example 3: Version mismatch ( hard disconnect)

```json
Client (v0.019) -> Server (v0.020): CONNECT seq=1
  { "protocol_version": 0.019, ... }

Server validates: 0.019 ≠ 0.020
  ↓

Server -> Client: ERROR seq=N
  { "code": "PROTOCOL_VERSION_MISMATCH", 
    "reason": "Client version 0.019 incompatible with server 0.020" }

Client: Disconnect immediately, show user "Game update required"
```

### Example 4: Schema Version Mismatch (Warning only)

```json
Client (schema v1.0.0) receives HANDSHAKE_ACK with schema_version: "1.1.0"

Client: Logs warning "Schema version mismatch: 1.0.0 vs 1.1.0"
        Continues normal gameplay
        Optionally shows UI notification (optional)
```

## BUILD AND TEST

- ### BUILD
- `fish scripts/build.fish`
- **Generates:** `shared/MessageID.cs`, `shared/MessageID.gd`, `shared/ProtocolVersion.cs`, `shared/ProtocolVersion.gd`
- **Injects:** `protocol_version`, `schema_version` as constants

- ### GOLDEN SAMPLES
- `fish scripts/update_golden_samples.fish`
- **Regenerates:** `shared/golden/message_*.json` files
- **Validates:** positive samples pass, negative samples fail with correct error codes

- ### CI validation
- **CI ensures:**
- `message_ids.json` schema is valid
- `rules.json` matches `rules.schema.json`
- `protocol_version` and schema_version are consistent across artifacts
- Generated enums match `message_ids.json`
- Golden samples are valid (positive) and invalid (negative) as expected

## FUTURE MIGRATIONS

- ### Schema extraction (at > 5kb)

- if `message_ids.json` exceeds 5KB, migrate to external schemas:

```json
shared/
  message_ids.json (references only)
  schemas/
    CONNECT.schema.json
    HANDSHAKE_ACK.schema.json
    MOVE.schema.json
    ... (one per message type)
```

- use JSON Schema $ref for references; update C# and GDscript `RulesLoader`classes to resolve refs.

## Client Implementation (Godot/GDscript) Notes

## Phase 1 Client Checklist

- [ ] Implement `CONNECT` with `protocol_version` check
- [ ] Implement `HANDSHAKE_ACK` handler; check `protocol_version` (hard disconnect) and `schema_version` (warn)
- [ ] Implement `MOVE` sender; validate bounds locally before sending
- [ ] Implement `ATTACK` sender; validate target exists before sending
- [ ] `SNAPSHOT` receiver; interpolate positions; `update_health`
- [ ] Implement `ERROR` handler; display error messages
- [ ] Implement `seq` counter; increment before each send
- [ ] Implement exponential backoff reconnect on disconnect
- [ ] Implement rollback on `INVALID_MOVE` error

### GDScript Type Safety (4.0+)

**Use native GDscript type annotations to catch errors:**

```gdscript
# MessageEnvelope.gd
extends Node

static func deserialize(json_string: String) -> Dictionary:
    """Parse JSON envelope and validate structure."""
    var data = JSON.parse_string(json_string)
    
    # Type checks with assert (dev); warn only (prod)
    assert(typeof(data.id) == TYPE_INT, "Message id must be int")
    assert(data.has("seq"), "Message must have seq field")
    assert(typeof(data.payload) == TYPE_DICTIONARY, "Payload must be dict")
    
    return data

static func serialize(message: Dictionary) -> String:
    """Encode envelope to JSON string."""
    assert(message.has("id") and message.has("seq") and message.has("payload"))
    return JSON.stringify(message)
```

### Connection Handling

```gdscript
# websocket_client.gd
extends Node

var socket: WebSocketPeer
var connected: bool = false
var seq: int = 0

func _ready() -> void:
    socket = WebSocketPeer.new()

func send_message(msg_id: int, payload: Dictionary) -> void:
    """Send message with auto-incremented seq."""
    seq += 1
    var envelope: Dictionary = {
        "id": msg_id,
        "seq": seq,
        "payload": payload
    }
    var json = MessageEnvelope.serialize(envelope)
    socket.send_text(json)

func _on_message_received(message: String) -> void:
    """Handle incoming envelope."""
    var envelope = MessageEnvelope.deserialize(message)
    
    match envelope.id:
        MessageID.ERROR:
            handle_error(envelope.payload)
        MessageID.HANDSHAKE_ACK:
            handle_handshake(envelope.payload)
        MessageID.SNAPSHOT:
            handle_snapshot(envelope.payload)
        _:
            push_warning("Unknown message id: ", envelope.id)
```

### Error Handling

```gdscript
func handle_error(payload: Dictionary) -> void:
    """Process ERROR message based on code."""
    var code = payload.get("code", "UNKNOWN")
    var reason = payload.get("reason", "Unknown error")
    
    match code:
        "PROTOCOL_VERSION_MISMATCH":
            # FATAL: hard disconnect
            disconnect_fatal("Version mismatch; upgrade required")
        "INVALID_MOVE":
            # WARN: rollback and retry
            rollback_to_last_snapshot()
            display_toast("Invalid move; try again")
        "RATE_LIMITED":
            # WARN: queue locally and retry
            queue_message_retry()
        _:
            display_toast("Error: %s" % reason)

func disconnect_fatal(message: String) -> void:
    """Hard disconnect for fatal errors (protocol mismatch)."""
    connected = false
    socket.close()
    show_fatal_modal(message)  # Block reconnect
```

### Schema Version Handling

```gdscript
func handle_handshake(payload: Dictionary) -> void:
    """Handshake: validate protocol_version (fatal), warn on schema_version mismatch."""
    var server_protocol = payload.get("protocol_version", 0.0)
    var server_schema = payload.get("schema_version", "0.0.0")
    
    if server_protocol != RulesLoader.protocol_version:
        # FATAL: protocol_version mismatch
        var msg = "Client protocol %.3f ≠ server %.3f; upgrade required" % [
            RulesLoader.protocol_version,
            server_protocol
        ]
        handle_error({"code": "PROTOCOL_VERSION_MISMATCH", "reason": msg})
        return
    
    if server_schema != RulesLoader.schema_version:
        # WARNING: schema_version mismatch (non-fatal)
        push_warning(
            "Schema version mismatch: client %s, server %s (non-fatal)" %
            [RulesLoader.schema_version, server_schema]
        )
        # Continue connection; may show UI warning
        show_schema_warning("Schema version mismatch (non-fatal)")
    
    # Connection successful
    connected = true
    spawn_players(payload.get("existing_players", []))
```

---

## Server Implementation (Godot-Mono/C#) Notes

## Phase 1 Server Checklist

- [ ] Implement `CONNECT` handler; validate `protocol_version`, check `username` uniqueness
- [ ] Implement `HANDSHAKE_ACK` sender; include `schema_version` in payload
- [ ] Implement `MOVE` handler; validate `bounds`, `speed`, `rate_limit`
- [ ] Implement `ATTACK` handler; validate target, calculate damage, broadcast update
- [ ] Implement `SNAPSHOT` generator; broadcast at 30 Hz with all players
- [ ] Implement `ERROR` sender; all validation failures trigger `ERROR`
- [ ] Implement `seq` tracking; warn on gaps >5, handle duplicates
- [ ] Load `message_ids.json` schema at startup; log "Schema loading time in ms"
- [ ] Hard disconnect on `protocol_version` mismatch

### Strict Validation with MessageEnvelope

```csharp
// MessageEnvelope.cs
public class MessageEnvelope
{
    public int Id { get; set; }
    public int Seq { get; set; }
    public JObject Payload { get; set; }
    
    /// Deserialize JSON and validate against schema.
    /// Throws InvalidOperationException on validation failure.
    public static MessageEnvelope Deserialize(string json)
    {
        try
        {
            var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            
            // Validate envelope structure
            if (!root.TryGetProperty("id", out var idEl) || idEl.ValueKind != JsonValueKind.Number)
                throw new InvalidOperationException("Missing or invalid 'id' field");
            if (!root.TryGetProperty("seq", out var seqEl) || seqEl.ValueKind != JsonValueKind.Number)
                throw new InvalidOperationException("Missing or invalid 'seq' field");
            if (!root.TryGetProperty("payload", out var payloadEl) || payloadEl.ValueKind != JsonValueKind.Object)
                throw new InvalidOperationException("Missing or invalid 'payload' field");
            
            var envelope = new MessageEnvelope
            {
                Id = idEl.GetInt32(),
                Seq = seqEl.GetInt32(),
                Payload = JObject.Parse(payloadEl.GetRawText())
            };
            
            // Message-specific validation
            ValidatePayload(envelope.Id, envelope.Payload);
            
            return envelope;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Failed to deserialize message: {ex.Message}", ex);
        }
    }
    
    /// Validate payload structure and field values against schema.
    /// Throws InvalidOperationException on validation failure.
    private static void ValidatePayload(int messageId, JObject payload)
    {
        switch (messageId)
        {
            case MessageID.CONNECT:
                ValidateConnect(payload);
                break;
            case MessageID.MOVE:
                ValidateMove(payload);
                break;
            case MessageID.ATTACK:
                ValidateAttack(payload);
                break;
            default:
                // Allow unknown messages (forward compatibility)
                break;
        }
    }
    
    private static void ValidateConnect(JObject payload)
    {
        RequiredField(payload, "protocol_version", JsonValueKind.Number);
        RequiredField(payload, "username", JsonValueKind.String);
        RequiredField(payload, "client_id", JsonValueKind.String);
        
        var version = payload["protocol_version"].Value<double>();
        if (version != RulesLoader.Rules.ProtocolVersion)
            throw new InvalidOperationException(
                $"protocol_version mismatch: client {version} != server {RulesLoader.Rules.ProtocolVersion}"
            );
    }
    
    private static void ValidateMove(JObject payload)
    {
        RequiredField(payload, "x", JsonValueKind.Number);
        RequiredField(payload, "y", JsonValueKind.Number);
        
        var x = payload["x"].Value<float>();
        var y = payload["y"].Value<float>();
        var distance = MathF.Sqrt(x * x + y * y);
        
        if (distance > RulesLoader.Rules.Movement.MaxRadius)
            throw new InvalidOperationException(
                $"Position ({x}, {y}) exceeds max_radius {RulesLoader.Rules.Movement.MaxRadius}"
            );
    }
    
    private static void RequiredField(JObject obj, string fieldName, JsonValueKind expectedType)
    {
        if (!obj.ContainsKey(fieldName))
            throw new InvalidOperationException($"Missing required field: {fieldName}");
        if (obj[fieldName].Type != JTokenType.Property || obj[fieldName].Type != expectedType)
            throw new InvalidOperationException($"Invalid type for field: {fieldName}");
    }
}

// In ServerEntry._Ready():
public override void _Ready()
{
    // Load and cache schema at startup
    var schemaPath = "res://../shared/message_ids.json";
    GD.Print($"[Server] Loading protocol schema from {schemaPath}...");
    var startTime = Time.GetTicksMsec();
    // Schema initialization happens here
    var elapsed = Time.GetTicksMsec() - startTime;
    GD.Print($"[Server] Schema loaded in {elapsed}ms");
}
```

### Handling Validation Errors

```csharp
// In ServerEntry message handler
private void OnMessageReceived(int peerId, byte[] data)
{
    var json = Encoding.UTF8.GetString(data);
    
    try
    {
        var envelope = MessageEnvelope.Deserialize(json);
        
        // Update last_seq for dedup check
        if (LastSeqReceived.ContainsKey(peerId) && envelope.Seq <= LastSeqReceived[peerId])
        {
            GD.PrintErr($"[Server] Duplicate or out-of-order seq {envelope.Seq} from peer {peerId}");
            // Process anyway (idempotency)
        }
        LastSeqReceived[peerId] = envelope.Seq;
        
        ProcessMessage(peerId, envelope);
    }
    catch (InvalidOperationException ex)
    {
        GD.PrintErr($"[Server] Validation error from peer {peerId}: {ex.Message}");
        SendError(peerId, "VALIDATION_FAILED", ex.Message);
    }
}

private void SendError(int peerId, string code, string reason)
{
    var error = new JObject
    {
        ["id"] = MessageID.ERROR,
        ["seq"] = 9999,
        ["payload"] = new JObject
        {
            ["code"] = code,
            ["reason"] = reason,
            ["offending_seq"] = LastSeqReceived.TryGetValue(peerId, out var seq) ? seq : 0
        }
    };
    
    var json = error.ToString(Formatting.None);
    var bytes = Encoding.UTF8.GetBytes(json);
    MultiplayerPeer.SendBytesUniqueKey(peerId, bytes);
}
```

---

## Logging & Observability

### Phase 1 (MVP): Simple Startup Log

**Server startup:**

```json
[Server] Schema loaded in 5ms
[Server] Protocol version: 0.020
[Server] Listening on 127.0.0.1:12346 (WebSocket)
```

Per-message logging (validation failures only):

```json
[Server] Validation error from peer 42: Position (150.0, 0.0) exceeds max_radius 100.0
[Server] Duplicate seq 5 from peer 42 (processing idempotently)
```

### Phase 2: Detailed Metrics

- Per-message validation latency
- Bandwidth (snapshot size, delta compression ratio)
- Connection stats (packet loss, RTT, reconnect attempts)
- Error rate per error code

## Protocol Versioning & Bumps

### When to Bump `protocol_version` (Game Logic)

- **Rule changes:** `max_speed`, `max_radius`, `damage` formulas
- `SNAPSHOT` state semantics change
- Handshake behavior change
- **Result:** Clients with old version hard-disconnect; **auto-update required**

### When to Bump `schema_version` (Tooling & Validation)

- Envelope structure change (new optional fields, etc.)
- Payload field removed (breaking)
- Field type change (breaking)
- New required field added (breaking)
- New optional field added (backward compatible)

### On Bump Workflow

1. Update `shared/rules.json`: increment `protocol_version` and/or `schema_version`
2. Run build: `fish scripts/build.fish`
   - Generates new enums (`MessageID.cs`, `MessageID.gd`)
   - Stamps new version into `ProtocolVersion.cs/ProtocolVersion.gd`
   - Copies artifacts to `export/` for CI
3. Regenerate golden samples: `fish scripts/update_golden_samples.fish`
4. Commit updates to git
5. Create git tag: `git tag v0.021` (if protocol_version bumped)
6. **If `protocol_version` bumped:** Document that client auto-update is required

---

## FAQ

- Q: What happens if I bump `protocol_version`?
- A: All old clients disconnect with "Version mismatch" error; they must auto-update.

- Q: What happens if I bump `schema_version`?
- A: Clients log a warning but continue normal gameplay. Tooling (tests, CI) must revalidate.

- Q: How often should I regenerate golden samples?
- A: After any `message_ids.json` or `rules.json` change; use `update_golden_samples.fish` script

- Q: Can I test negative samples locally?
- A: Yes; each negative sample has an expected error code (e.g., `INVALID_MOVE`). CI validates both positive (pass) and negative (fail with code..)

---

## See also Shared-PROTOCOL files for rules validation etc.

- [shared/message_ids.json](message_ids.json) - Authoritative message enum/consts definitions and payload schemas
- [shared/rules.json](rules.json) - Game rule constants (max_radius, max_speed, etc.)
- [shared/MessageID.gd](MessageID.gd) - GDscript message enums generated by build.fish
- [shared/MessageID.cs](MessageID.cs) - C# message consts generated by build.fish
- [shared/golden/](golden/) - Canonical test message samples per protocol version
- [scripts/build.fish](../scripts/build.fish) - Build orchestration (enum generation, artifact copying, compile server and client)
- [scripts/update_golden_samples.fish](../scripts/update_golden_samples.fish) — Golden sample regeneration
- [README.MD](../README.MD) — Build prerequisites and deployment instructions
