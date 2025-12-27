<!-- Copilot / AI agent instructions for the compogo (Godot) workspace -->
# Quickstart for AI coding agents

- **Repo layout (high level):** this workspace contains two Godot projects that share a small runtime contract:
  - `game-server/` — Godot project using C# (.NET) server code. See `game-server/compogo-server.csproj` and `game-server/project.godot`.
  - `web-client/` — Godot client using GDScript. See `web-client/project.godot` and `web-client/scripts/`.
  - `shared/` — shared runtime data (notably `shared/rules.json` and `shared/rules.schema.json`). Both projects copy/export a rules.json under their `export/` folders.

- **Big picture / data flow:** both client and server read the same game rules model from `shared/rules.json` (or fall back to in-code defaults). The rules drive movement/combat checks and protocol compatibility.

- **Key files to inspect when making changes:**
  - `game-server/scripts/RulesLoader.cs` — C# rules loader (currently uses hardcoded defaults; JSON loader is commented out).
  - `game-server/scripts/RulesModels.cs` — C# POCOs for rules.
  - `web-client/scripts/RulesLoader.gd` — GDScript loader + helper `get_nested()`.
  - `shared/rules.json` and `shared/rules.schema.json` — canonical source and schema for rule values.
  - `game-server/compogo-server.csproj` — C#/.NET target and Godot SDK version (Godot.NET.Sdk/4.5.1, net8.0).

- **Important repository invariants and patterns (do not change lightly):**
  - The `protocol_version` in `shared/rules.json` is used for compatibility checks between client and server. Changes to the schema should update `shared/rules.schema.json` and bump `protocol_version`.
  - Both server and client include a local fallback `initialize_default_rules()` implementation. The server's JSON loader is currently disabled — be aware when synchronizing behavior.
  - Default JSON path used in code: `res://../shared/rules.json` (both loaders reference a similar relative path).

- **Build / run / debug notes (repo-specific):**
  - To compile the C# server code (outside Godot):

    dotnet build game-server/compogo-server.csproj

  - To run or debug either Godot project, open the corresponding `project.godot` in the Godot editor (recommended). The C# assembly produced by `dotnet build` will be consumed by Godot when the project is run.
  - There are no CI test suites in the repo; run manual playtests in Godot for behavior checks.

- **Common-code patterns & examples:**
  - C# access to rules: `RulesLoader.Rules.Movement.MaxSpeed` (see `game-server/scripts/Node2d.cs`).
  - GDScript access: the loader stores a Dictionary and exposes `get_nested(path_array, default)` for safe nested access (see `web-client/scripts/RulesLoader.gd`).
  - When adding or changing rules, update `shared/rules.json` and the schema (`shared/rules.schema.json`) and ensure exported copies under each project's `export/` are kept in sync.

- **When editing code generateables (PR guidance for AI):**
  - Prefer minimal, focused diffs. If touching rule shapes, include: updated `shared/rules.schema.json`, bump `protocol_version`, and example default values in both `RulesLoader` implementations.
  - Don't re-enable the server JSON loader without validating path resolution inside Godot (server code currently uses hardcoded defaults to avoid runtime FileAccess issues).

- **Quick pointers for reviewers:**
  - Verify that `protocol_version` changes are intentional and accompanied by schema updates.
  - For C# changes, ensure `game-server/compogo-server.csproj` remains targeting `Godot.NET.Sdk/4.5.1` and `net8.0` unless there's a coordinated upgrade.

If anything here is unclear or you want the file to call out other repo parts (network protocol, server entry points, or export rules), tell me which area to expand.
