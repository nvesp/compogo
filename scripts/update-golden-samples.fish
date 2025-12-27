#!/usr/bin/env fish

# update_golden_samples.fish — Regenerate canonical message payloads
# Usage: fish scripts/update_golden_samples.fish
# Regenerates all golden samples and validates against schema

set ROOT (pwd)
set SHARED "$ROOT/shared"
set GOLDEN "$SHARED/golden"
set GOLDEN_MD "$SHARED/GOLDEN_SAMPLES.md"

function ensure_golden_dir
    mkdir -p $GOLDEN
    echo "Golden samples directory ready: $GOLDEN"
end

function get_protocol_version
    jq -r '.protocol_version' $SHARED/rules.json
end

function get_schema_version
    jq -r '.schema_version' $SHARED/rules.json
end

function generate_connect_samples
    set pversion (get_protocol_version)
    
    # Positive: Valid CONNECT
    echo '{
  "id": 0,
  "seq": 1,
  "payload": {
    "protocol_version": '$pversion',
    "username": "TestPlayer",
    "client_id": "client-uuid-1234"
  }
}' > $GOLDEN/CONNECT_$pversion.json
    
    echo "Generated CONNECT_$pversion.json (positive)"
    
    # Negative: Protocol version mismatch
    echo '{
  "id": 0,
  "seq": 1,
  "payload": {
    "protocol_version": 0.010,
    "username": "TestPlayer",
    "client_id": "client-uuid-1234"
  }
}' > $GOLDEN/ERROR_CONNECT_VERSION_MISMATCH_$pversion.json
    
    echo "Generated ERROR_CONNECT_VERSION_MISMATCH_$pversion.json (negative)"
end

function generate_handshake_ack_samples
    set pversion (get_protocol_version)
    set sversion (get_schema_version)
    
    # Positive: Valid HANDSHAKE_ACK
    echo '{
  "id": 1,
  "seq": 1,
  "payload": {
    "player_id": 42,
    "protocol_version": '$pversion',
    "schema_version": "'$sversion'",
    "map_bounds": {
      "max_radius": 100.0
    },
    "tick": 1000,
    "existing_players": [
      {
        "id": 1,
        "username": "ExistingPlayer",
        "x": 50.0,
        "y": 30.0,
        "health": 100,
        "status": "idle"
      }
    ]
  }
}' > $GOLDEN/HANDSHAKE_ACK_$pversion.json
    
    echo "Generated HANDSHAKE_ACK_$pversion.json (positive)"
end

function generate_move_samples
    set pversion (get_protocol_version)
    
    # Positive: Valid MOVE
    echo '{
  "id": 2,
  "seq": 2,
  "payload": {
    "x": 45.5,
    "y": 32.0,
    "timestamp_client_ms": 1702988400500
  }
}' > $GOLDEN/MOVE_$pversion.json
    
    echo "Generated MOVE_$pversion.json (positive)"
    
    # Negative: Out of bounds
    echo '{
  "id": 2,
  "seq": 2,
  "payload": {
    "x": 150.0,
    "y": 0.0,
    "timestamp_client_ms": 1702988400500
  }
}' > $GOLDEN/ERROR_MOVE_OUT_OF_BOUNDS_$pversion.json
    
    echo "Generated ERROR_MOVE_OUT_OF_BOUNDS_$pversion.json (negative; should fail validation)"
end

function generate_attack_samples
    set pversion (get_protocol_version)
    
    # Positive: Valid ATTACK
    echo '{
  "id": 3,
  "seq": 3,
  "payload": {
    "target_id": 1,
    "is_critical": false
  }
}' > $GOLDEN/ATTACK_$pversion.json
    
    echo "Generated ATTACK_$pversion.json (positive)"
    
    # Negative: Target ID out of range
    echo '{
  "id": 3,
  "seq": 3,
  "payload": {
    "target_id": -1,
    "is_critical": false
  }
}' > $GOLDEN/ERROR_ATTACK_INVALID_TARGET_$pversion.json
    
    echo "Generated ERROR_ATTACK_INVALID_TARGET_$pversion.json (negative; should fail validation)"
end

function generate_snapshot_samples
    set pversion (get_protocol_version)
    
    # Positive: Valid SNAPSHOT
    echo '{
  "id": 4,
  "seq": 1000,
  "payload": {
    "tick": 1001,
    "players": [
      {
        "id": 1,
        "username": "Alice",
        "x": 50.0,
        "y": 30.0,
        "health": 100,
        "status": "moving"
      },
      {
        "id": 42,
        "username": "Bob",
        "x": 45.5,
        "y": 32.0,
        "health": 85,
        "status": "idle"
      }
    ],
    "events": [
      {
        "type": "damage_dealt",
        "attacker_id": 1,
        "target_id": 42,
        "damage": 50,
        "is_critical": false
      }
    ]
  }
}' > $GOLDEN/SNAPSHOT_$pversion.json
    
    echo "Generated SNAPSHOT_$pversion.json (positive)"
end

function generate_error_samples
    set pversion (get_protocol_version)
    
    # PROTOCOL_VERSION_MISMATCH error
    echo '{
  "id": 5,
  "seq": 9999,
  "payload": {
    "code": "PROTOCOL_VERSION_MISMATCH",
    "reason": "Client version 0.010 incompatible with server 0.020",
    "offending_seq": 1
  }
}' > $GOLDEN/ERROR_PROTOCOL_VERSION_MISMATCH_$pversion.json
    
    echo "Generated ERROR_PROTOCOL_VERSION_MISMATCH_$pversion.json"
    
    # INVALID_MOVE error
    echo '{
  "id": 5,
  "seq": 9999,
  "payload": {
    "code": "INVALID_MOVE",
    "reason": "Target position (150.0, 0.0) exceeds max_radius 100.0",
    "offending_seq": 2
  }
}' > $GOLDEN/ERROR_INVALID_MOVE_$pversion.json
    
    echo "Generated ERROR_INVALID_MOVE_$pversion.json"
    
    # INVALID_ATTACK error
    echo '{
  "id": 5,
  "seq": 9999,
  "payload": {
    "code": "INVALID_ATTACK",
    "reason": "Target 999 not found or already dead",
    "offending_seq": 3
  }
}' > $GOLDEN/ERROR_INVALID_ATTACK_$pversion.json
    
    echo "Generated ERROR_INVALID_ATTACK_$pversion.json"
end

function generate_disconnect_samples
    set pversion (get_protocol_version)
    
    # Positive: Valid DISCONNECT
    echo '{
  "id": 6,
  "seq": 100,
  "payload": {
    "reason": "player_quit",
    "message": "User closed game"
  }
}' > $GOLDEN/DISCONNECT_$pversion.json
    
    echo "Generated DISCONNECT_$pversion.json (positive)"
end

function validate_positive_samples
    echo ""
    echo "Validating positive samples against schema..."
    
    set pversion (get_protocol_version)
    set schema_file "$SHARED/message_ids.json"
    
    # Simple jq validation: check that each positive sample matches the payload_schema
    # This is a light validation; full JSON Schema validation requires ajv
    for sample in $GOLDEN/*_$pversion.json
        set basename (basename $sample)
        if string match -q "*ERROR*" $basename
            continue
        end
        
        echo "  Validating $basename..."
        
        # Extract message type from filename
        set msg_type (string split "_" $basename)[1]
        
        # Basic jq check: does it parse?
        if jq empty $sample 2>/dev/null
            echo "  $basename is valid JSON"
        else
            echo "  $basename is NOT valid JSON"
            return 1
        end
    end
end

function validate_negative_samples
    echo ""
    echo "Validating negative samples (should fail schema)..."
    
    set pversion (get_protocol_version)
    
    for sample in $GOLDEN/ERROR*_$pversion.json
        set basename (basename $sample)
        
        echo "  Checking $basename (should be invalid)..."
        
        # For negative samples, we just verify they parse as JSON
        # Actual schema validation failure is tested in CI with ajv
        if jq empty $sample 2>/dev/null
            echo "$basename parses as JSON (CI will validate against schema)"
        else
            echo "$basename is malformed JSON"
            return 1
        end
    end
end

function generate_documentation
    set pversion (get_protocol_version)
    set sversion (get_schema_version)
    
    echo ""
    echo "📝 Generating golden samples documentation..."
    
    echo "# Golden Samples

This directory contains canonical message payloads for cross-language serialization testing.

## Sample Naming Convention

- **Positive samples:** \`MESSAGE_TYPE_PROTOCOLVERSION.json\`
- **Negative samples:** \`ERROR_MESSAGE_TYPE_PROTOCOLVERSION.json\`

## Samples Generated (Protocol v$pversion)

### System Messages

- \`CONNECT_$pversion.json\` — Valid connection request (should pass validation)
- \`ERROR_CONNECT_VERSION_MISMATCH_$pversion.json\` — Invalid: protocol version mismatch (should fail)
- \`HANDSHAKE_ACK_$pversion.json\` — Valid handshake acknowledgment
- \`ERROR_PROTOCOL_VERSION_MISMATCH_$pversion.json\` — Protocol mismatch error message
- \`DISCONNECT_$pversion.json\` — Graceful disconnect

### Movement Messages

- \`MOVE_$pversion.json\` — Valid movement within bounds
- \`ERROR_MOVE_OUT_OF_BOUNDS_$pversion.json\` — Invalid: coordinates exceed max_radius (should fail)
- \`ERROR_INVALID_MOVE_$pversion.json\` — Movement validation error from server

### Combat Messages

- \`ATTACK_$pversion.json\` — Valid attack on target
- \`ERROR_ATTACK_INVALID_TARGET_$pversion.json\` — Invalid: negative target ID (should fail)
- \`ERROR_INVALID_ATTACK_$pversion.json\` — Attack validation error from server

### Broadcast Messages

- \`SNAPSHOT_$pversion.json\` — Valid authoritative state snapshot

## Validation Requirements

### Positive Samples

All positive samples must pass schema validation. Run:

\`\`\`bash
ajv validate -s ../message_ids.json -d CONNECT_$pversion.json
ajv validate -s ../message_ids.json -d MOVE_$pversion.json
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

- Protocol Version: $pversion Current (Schema Version: $sversion)
" > $GOLDEN_MD
    
    echo "Generated GOLDEN_SAMPLES.md"
end

function main
    echo "Regenerating golden samples for Compogo protocol..."
    
    ensure_golden_dir
    
    generate_connect_samples
    generate_handshake_ack_samples
    generate_move_samples
    generate_attack_samples
    generate_snapshot_samples
    generate_error_samples
    generate_disconnect_samples
    
    validate_positive_samples
    or return 1
    
    validate_negative_samples
    or return 1
    
    generate_documentation
    
    echo ""
    echo "All golden samples regenerated successfully"
    echo "Location: $GOLDEN/"
    echo "Documentation: $GOLDEN_MD"
end

main