# Golden Samples

This directory contains canonical message payloads for cross-language serialization testing.

## Sample Naming Convention

- **Positive samples:** \`MESSAGE_TYPE_PROTOCOLVERSION.json\`
- **Negative samples:** \`ERROR_MESSAGE_TYPE_PROTOCOLVERSION.json\`

## Samples Generated (Protocol v0.020)

### System Messages

- \`CONNECT_0.020.json\` — Valid connection request (should pass validation)
- \`ERROR_CONNECT_VERSION_MISMATCH_0.020.json\` — Invalid: protocol version mismatch (should fail)
- \`HANDSHAKE_ACK_0.020.json\` — Valid handshake acknowledgment
- \`ERROR_PROTOCOL_VERSION_MISMATCH_0.020.json\` — Protocol mismatch error message
- \`DISCONNECT_0.020.json\` — Graceful disconnect

### Movement Messages

- \`MOVE_0.020.json\` — Valid movement within bounds
- \`ERROR_MOVE_OUT_OF_BOUNDS_0.020.json\` — Invalid: coordinates exceed max_radius (should fail)
- \`ERROR_INVALID_MOVE_0.020.json\` — Movement validation error from server

### Combat Messages

- \`ATTACK_0.020.json\` — Valid attack on target
- \`ERROR_ATTACK_INVALID_TARGET_0.020.json\` — Invalid: negative target ID (should fail)
- \`ERROR_INVALID_ATTACK_0.020.json\` — Attack validation error from server

### Broadcast Messages

- \`SNAPSHOT_0.020.json\` — Valid authoritative state snapshot

## Validation Requirements

### Positive Samples

All positive samples must pass schema validation. Run:

\`\`\`bash
ajv validate -s ../message_ids.json -d CONNECT_0.020.json
ajv validate -s ../message_ids.json -d MOVE_0.020.json
# ... etc
\`\`\`

### Negative Samples

Negative samples must **fail** schema validation with specific error messages. They serve as regression tests to ensure validators are working correctly.

## Maintenance

Regenerate samples whenever:
- [message_ids.json](../message_ids.json) payload schemas change
- [rules.json](../rules.json) values change (max_radius, max_speed, damage, etc.)

Run:

\`\`\`bash
fish scripts/update_golden_samples.fish
\`\`\`

Then commit updated samples to version control.

## Protocol Version History

- Protocol Version: 0.020 Current (Schema Version: 0.1.0)

