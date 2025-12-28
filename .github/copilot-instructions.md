<!-- Copilot / AI agent instructions for the compogo (Godot) workspace -->
# Compogo AI Agent Quickstart

## Architecture Overview

**Compogo** is a hybrid multiplayer game with server (C#/Godot), web client (GDScript/Godot), and web portal (PHP).

### Core Components

- **game-server/** — Godot + C# server; headless mode; dual-transport (ENet port 12345, WebSocket port 12346)
  - `game-server/compogo-server.csproj` — .NET 8.0, Godot.NET.Sdk/4.5.1
  - `game-server/scripts/RulesLoader.cs` — hardcoded defaults; JSON loader disabled (path resolution issues in Godot)
  - `game-server/scripts/RulesModels.cs` — `Rules`, `Movement`, `Combat` POCOs
  - `game-server/scripts/Node2d.cs` — example usage: `RulesLoader.Rules.Movement.MaxSpeed`

- **web-client/** — Godot + GDScript; HTML5 export; WebSocket transport
  - `web-client/scripts/RulesLoader.gd` — JSON loader with fallback; exposes `get_nested(path, default)`
  - `web-client/network/websocket_client.gd` — WebSocket adapter to protocol envelopes
  - Offline mode (`--offline`) runs single-player without transport

- **website/** — PHP frontend and API backend; linked to website database
  - `website/` — PHP templating, HTML, CSS, JS
  - `website/api/` — REST endpoints (validate against `shared/rules.json` and protocol semantics)
  - Connects to `website-database/` for user accounts, sessions, profiles

- **shared/** — Protocol, rules, and golden samples
  - `shared/rules.json` — canonical game rules (movement, combat)
  - `shared/rules.schema.json` — JSON Schema validation
  - `shared/PROTOCOL.md` — full message spec, versioning, error codes, examples
  - `shared/message_ids.json` — message type definitions
  - `shared/golden/` — canonical JSON payloads for cross-language serialization tests

- **Databases**
  - `website-database/` — website user accounts, sessions, profiles
  - `game-database/` — game data (player inventory, stats, persistence, accounts)

- **Deployment & Operations**
  - `ops/` — CI/CD scripts, Docker, orchestration
  - `ops/nginx/` — TLS termination, reverse proxy config (routes `/ws` to WebSocket, game traffic to ENet proxy)
  - `scripts/` — Fish build scripts; validate and copy `shared/rules.json` to `game-server/export/` and `web-client/export/`

### Data Flow

1. **Game rules source:** `shared/rules.json` (single source of truth)
2. **Client & server init:** both load rules via `RulesLoader` (hardcoded fallback if file missing)
3. **Protocol versioning:** `protocol_version` (strict match) and `schema_version` (permissive warn)
4. **Validation:** rules drive `max_radius`, `max_speed`, `base_damage`, `critical_multiplier`
5. **Golden samples:** cross-language serialization tests in `shared/golden/`; regenerate after rule changes
6. **Exported copies:** Fish build scripts sync `shared/rules.json` to `game-server/export/rules.json` and `web-client/export/rules.json`

---

## Network Protocol (see `shared/PROTOCOL.md`)

### Envelope Format

All messages use a standardized JSON envelope:

```json
{ "id": <int32>, "seq": <int32>, "payload": <object> }
```

- **id:** Message type (0–49 assigned; see `shared/message_ids.json`)
- **seq:** Monotonically increasing per peer; client increments before each send; no reset across session except on reconnect
- **payload:** Message-specific fields; structure varies by `id`

### Versioning Semantics

- **protocol_version (float):** Game logic compatibility (movement rules, damage calc, etc.)
  - **STRICT:** Client and server must match exactly
  - **Mismatch behavior:** Hard disconnect with error `PROTOCOL_VERSION_MISMATCH`
  - **Bump policy:** Only on breaking game mechanic changes

- **schema_version (string):** Message structure and tooling (new fields, validation updates)
  - **PERMISSIVE:** Client warns on mismatch but continues
  - **Mismatch behavior:** Log warning; display optional UI; continue operation
  - **Bump policy:** On message schema changes that don't affect game logic

### Message Categories

| ID Range | Category | Examples |
|----------|----------|----------|
| 0–9 | System | CONNECT (0), HANDSHAKE_ACK (1), ERROR (5), DISCONNECT (6) |
| 2–3 | Movement/Combat | MOVE (2), ATTACK (3) |
| 4 | Broadcast | SNAPSHOT (4) — state updates at 30 Hz |

### Key Message Specs

**CONNECT** (Client → Server, seq=1)
```json
{ "id": 0, "seq": 1, "payload": { "protocol_version": 0.020, "username": "Alice", "client_id": "uuid" } }
```
- Server validates: version match, username unique, client_id deduplication
- Response: `HANDSHAKE_ACK` (match) or `ERROR` (mismatch/invalid)

**MOVE** (Client → Server)
```json
{ "id": 2, "seq": N, "payload": { "x": <float>, "y": <float>, "timestamp_client_ms": <int64> } }
```
- Server validation: sqrt(x² + y²) ≤ 100.0 (max_radius), speed ≤ 20.0 (max_speed)
- Rate limit: max 1 MOVE per tick
- Response: `SNAPSHOT` or `ERROR(INVALID_MOVE)`

**ATTACK** (Client → Server)
```json
{ "id": 3, "seq": N, "payload": { "target_id": <int32>, "is_critical": <bool> } }
```
- Damage: base 50; crit multiplies by 2.0 (from rules)
- Rate limit: max 2 ATTACK per tick
- Response: `SNAPSHOT` or `ERROR(INVALID_ATTACK)`

**SNAPSHOT** (Server → Clients, 30 Hz)
```json
{ "id": 4, "seq": N, "payload": { "tick": <int32>, "players": [...], "events": [...] } }
```
- Authoritative state; clients trust server snapshot for truth
- Events: damage_dealt, player_joined, player_left, kill

### Error Codes

- `PROTOCOL_VERSION_MISMATCH` — disconnect + upgrade prompt
- `INVALID_MOVE` — out of bounds or speed exceeded; client rollback + resend
- `INVALID_ATTACK` — target not found or dead; discard, continue
- `RATE_LIMITED` — too many inputs; queue client-side, retry next tick
- `UNAUTHORIZED` — auth token invalid; redirect to login
- `INTERNAL_SERVER_ERROR` — exponential backoff reconnect

---

## Development Patterns

### Rules and Validation

When adding/changing game rules:
1. Update `shared/rules.json` (values)
2. Update `shared/rules.schema.json` (schema)
3. Decide: is this a breaking game change? → bump `protocol_version`; or tooling/schema change? → bump `schema_version`
4. Add example golden samples to `shared/golden/` (positive and negative)
5. Update `game-server/scripts/RulesModels.cs` POCO classes (if new top-level rule sections)
6. Update both `RulesLoader` implementations (C# and GDScript) with new default values
7. Update `shared/PROTOCOL.md` validation table and rules reference
8. Ensure Fish build scripts copy updated `shared/rules.json` to export folders

### Message Protocol Changes

When adding or modifying message types:
1. Define message in `shared/message_ids.json` (assign ID, name, direction)
2. Document message in `shared/PROTOCOL.md` (payload schema, validation, examples, error codes)
3. Create positive golden sample `shared/golden/message_MESSAGETYPE_PROTOCOLVERSION.json`
4. Create negative samples for common errors (e.g., `message_MOVE_INVALID_OOB_0.020.json`)
5. Implement handler in server C# code (validate, respond with SNAPSHOT or ERROR)
6. Implement handler in web client GDScript (envelope parsing, send, wait for response)
7. Implement handler in native client C# (reuse server message types; add prediction/reconciliation)
8. Test with golden samples for serialization round-trip

### Code Access Patterns

**C# (server):**
```csharp
RulesLoader.Rules.Movement.MaxSpeed  // static access to loaded rules
RulesLoader.Rules.Combat.BaseDamage
```

**GDScript (client):**
```gdscript
RulesLoader.get_nested(["movement", "max_speed"], 20.0)  // safe nested access
RulesLoader.get_nested(["combat", "base_damage"], 50)
```

### Server Transport Setup

- **ENet peer:** port 12345, native clients
- **WebSocket peer:** port 12346, web/browser clients
- Both feeds → same `GameplayService` (normalize envelopes)
- Optional proxy (Dockerized, in `ops/`) translates WebSocket ↔ ENet if server ENet-only
- Nginx reverse proxy (in `ops/nginx/`) terminates TLS, routes `/ws` to WebSocket, game to proxy

### Rate Limits & Validation

- **Movement:** max 1 MOVE per tick; position sqrt(x² + y²) ≤ 100.0; speed (distance/time) ≤ 20.0
- **Combat:** max 2 ATTACK per tick; target exists and alive
- **Protocol:** seq gaps > 5 warn (don't disconnect); duplicates deduplicated
- **Client-side:** validate locally for UX; trust server SNAPSHOT for truth

---

## Building and Deployment

### Compile C# Server

```bash
dotnet build game-server/compogo-server.csproj
```

- Output: .NET assembly consumed by Godot editor
- Target: `Godot.NET.Sdk/4.5.1`, `net8.0`

### Run in Godot Editor

- Open `game-server/project.godot` or `web-client/project.godot` in Godot 4.5+
- Press Play; logs to console
- No automated tests (manual playtests only)

### Export for Deployment

**Before export:** Run Fish build script to copy and validate `shared/rules.json`:
```bash
fish scripts/bootstrap-shared.fish  # validates and syncs rules to export folders
```

**Server:** Export headless Linux x86_64 binary; Dockerize with `ops/Dockerfile`

**Web client:** Export HTML5 preset; test Chrome/Firefox; deploy to static host or CDN

### Website & API

- REST endpoints in `website/api/` must validate payloads against `shared/rules.json` and protocol semantics
- Website database (`website-database/`) for accounts, sessions, profiles
- Game database (`game-database/`) for inventory, stats, persistence
- Both databases separate; coordinate schema migrations

---

## Key Files Reference

**Rules & Schema:**
- `game-server/scripts/RulesLoader.cs` — C# rules loader (currently uses hardcoded defaults; JSON loader is commented out).
- `game-server/scripts/RulesModels.cs` — C# POCOs for rules.
- `web-client/scripts/RulesLoader.gd` — GDScript loader + helper `get_nested()`.
- `shared/rules.json` — game rules (movement, combat values)
- `shared/rules.schema.json` — JSON Schema for rules validation

**Protocol & Messages:**
- `shared/PROTOCOL.md` — full message spec, versioning, error codes, rate limits, examples
- `shared/message_ids.json` — message type registry
- `shared/golden/` — canonical JSON payloads for serialization tests

**Build & Deployment:**
- `game-server/compogo-server.csproj` — .NET 8.0, Godot.NET.Sdk/4.5.1
- `scripts/` — Fish build scripts (validate and export rules)
- `ops/nginx/` — reverse proxy, TLS, routing config

**Transport & Networking:**
- `web-client/network/websocket_client.gd` — WebSocket transport adapter
- Server ENet peer: port 12345
- Server WebSocket peer: port 12346

---

## PR Checklist for AI Agents

**Protocol or Rule Changes:**
- [ ] Update `shared/rules.json` and `shared/rules.schema.json`
- [ ] Decide: `protocol_version` (breaking) or `schema_version` (non-breaking)
- [ ] Add golden samples (positive & negative) to `shared/golden/`
- [ ] Update `shared/PROTOCOL.md` with new message specs or validation rules
- [ ] Update both `RulesLoader` implementations (C# and GDScript) with defaults
- [ ] Update `shared/message_ids.json` if adding new message types

**Server Code (C#):**
- [ ] Ensure `RulesModels.cs` POCOs match `shared/rules.json`
- [ ] Implement handlers in server code (validate, respond, broadcast)
- [ ] Keep `game-server/compogo-server.csproj` on Godot.NET.Sdk/4.5.1, net8.0 unless upgrade coordinated

**Web Client Code (GDScript):**
- [ ] Implement envelope parsing and message handlers
- [ ] Use `RulesLoader.get_nested()` for safe rule access
- [ ] Test WebSocket transport paths

**Website/API Code (PHP):**
- [ ] Validate all inputs against `shared/rules.json` and protocol semantics
- [ ] Document API endpoints that differ from in-game protocol
- [ ] Ensure database migrations coordinated with game database schema

**Export & Sync:**
- [ ] Run Fish build scripts to validate and sync `shared/rules.json` to export folders
- [ ] Verify no hardcoded paths break during export

**Testing:**
- [ ] Golden sample round-trip serialization (C# and GDScript)
- [ ] Manual playtests in Godot editor
- [ ] Protocol version mismatch behavior
- [ ] Rate limit enforcement
