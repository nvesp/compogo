# COMPOGO Hybrid Godot headless Gameserver and Client

## Build - /scripts/build.fish

### Normal mode (default) - Run this for normal everyday builds

- **Run normal mode to check for stale metadata/protocol drift**
- Drift check ON
- Prevents stale builds
- Validates message IDs
- Validates Rules
- Builds Server if protocol drift passes
- Builds Client if protocol drift passes
- Does not regenerate protocol artifacts
- Does not stamp versions
- Does not rebuild enums
- Safe for CI and everyday builds

### Protocol update mode (--update-protocol) - Only run this when you intentionally update the protocol

- **Run with --update-protocol to align drift and update the protocol**
- Drift check OFF
- Regenerates enums
- Validates message IDs
- Validates Rules
- Stamps protocol version
- Copies artifacts
- Builds server/client
- Updates version.txt
- Used only when you intentionally change the protocol
