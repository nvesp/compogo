#!/usr/bin/env fish

# RUN from compogo/godot folder
# Paths
set ROOT (pwd)
set SHARED "$ROOT/shared"
set SERVER "$ROOT/game-server"
set CLIENT "$ROOT/web-client"
set SERVER_SCRIPTS "$SERVER/scripts"
set CLIENT_SCRIPTS "$CLIENT/scripts"
set CLIENT_NETWORK "$CLIENT/network"
set SERVER_EXPORT "$SERVER/export"
set CLIENT_EXPORT "$CLIENT/export"

#.----------------------------.
#| Helper-Functions           |
#'----------------------------'
function die
    echo "ERROR: $argv"
    exit 1
end

function banner
    echo ""
    echo "========================================"
    echo "$argv"
    echo "========================================"
end

#.----------------------------.
#| Validation                 |
#'----------------------------'
function validate_rules
    set RULES_FILE "$SHARED/rules.json"
    set SCHEMA_FILE "$SHARED/rules.schema.json"

    test -f $RULES_FILE  ; or die "Rules file missing"
    test -f $SCHEMA_FILE ; or die "Schema file missing"

    ajv validate -s $SCHEMA_FILE -d $RULES_FILE
    test $status -eq 0 ; or die "Rules validation failed"

    echo "Rules validated successfully"
end

function validate_message_ids_json
    echo "Validating message_ids.json structure..."

    jq empty $SHARED/message_ids.json 2>/dev/null ; or die "message_ids.json is not valid JSON"

    set has_messages (jq 'has("messages")' $SHARED/message_ids.json)
    set has_errors   (jq 'has("error_codes")' $SHARED/message_ids.json)

    if test "$has_messages" != "true" -o "$has_errors" != "true"
        die "message_ids.json missing required fields (messages, error_codes)"
    end

    echo "message_ids.json is valid"
end

#.--------------------------------.
#| Drift-Checks(Normal Mode Only) |
#'--------------------------------'
function check_protocol_drift
    set current (jq -r '.protocol_version' $SHARED/rules.json)
    set last    (cat $SERVER_EXPORT/protocol_version.txt 2>/dev/null)

    if test "$current" != "$last"
        die "Protocol drift detected: $last -> $current"
    end

    echo "No protocol drift detected"
end

function check_schema_drift
    set current (jq -r '.schema_version' $SHARED/rules.json)
    set last    (cat $SERVER_EXPORT/schema_version.txt 2>/dev/null)

    if test "$current" != "$last"
        die "Schema drift detected: $last -> $current"
    end

    echo "No schema drift detected"
end

#.----------------------------.
#| Protocol-Update Functions  |
#'----------------------------'
function generate_message_enums
    set pversion (jq -r '.protocol_version' $SHARED/rules.json)
    set sversion (jq -r '.schema_version' $SHARED/rules.json)

    echo "Generating message enums (protocol_version: $pversion, schema_version: $sversion)..."

    # C# enums
    set csharp_file "$SERVER_SCRIPTS/MessageID.cs"
    echo "// Auto-generated from rules.json; DO NOT EDIT" > $csharp_file
    echo "// Protocol Version: $pversion | Schema Version: $sversion" >> $csharp_file
    echo "" >> $csharp_file
    echo "// System Messages (0-9)" >> $gdscript_file
    echo "// Movement Messages (10-19)" >> $gdscript_file
    echo "// Combat Messages (30-39)" >> $gdscript_file
    echo "// Broadcast Messages (40-49)" >> $gdscript_file
    echo "" >> $csharp_file
    echo "public enum MessageID : int {" >> $csharp_file
    jq -r '.messages[] | "    \(.name) = \(.id),"' $SHARED/message_ids.json >> $csharp_file
    echo "}" >> $csharp_file
    echo "" >> $csharp_file
    echo "public enum ErrorCode : int {" >> $csharp_file
    jq -r '.error_codes | to_entries[] | "    \(.key) = \(.value),"' $SHARED/message_ids.json >> $csharp_file
    echo "}" >> $csharp_file

    # GDScript enums
    set gdscript_file "$CLIENT_NETWORK/MessageID.gd"
    echo "# Auto-generated from rules.json; DO NOT EDIT" > $gdscript_file
    echo "# Protocol Version: $pversion | Schema Version: $sversion" >> $gdscript_file
    echo "" >> $gdscript_file
    echo "# System Messages (0-9)" >> $gdscript_file
    echo "# Movement Messages (10-19)" >> $gdscript_file
    echo "# Combat Messages (30-39)" >> $gdscript_file
    echo "# Broadcast Messages (40-49)" >> $gdscript_file
    jq -r '.messages[] | "const \(.name) = \(.id)"' $SHARED/message_ids.json >> $gdscript_file
    echo "" >> $gdscript_file
    jq -r '.error_codes | to_entries[] | "const ERROR_\(.key) = \(.value)"' $SHARED/message_ids.json >> $gdscript_file

    # Duplicate ID check
    set dup_count (jq '.messages | group_by(.id) | map(select(length > 1)) | length' $SHARED/message_ids.json)
    test $dup_count -eq 0 ; or die "ERROR: Duplicate message IDs detected in message_ids.json"

    echo "Message enums generated"
end

function stamp_protocol_version
    set pversion (jq -r '.protocol_version' $SHARED/rules.json)
    set sversion (jq -r '.schema_version' $SHARED/rules.json)

    echo "Stamping protocol version: $pversion (schema: $sversion)..."

    # C# Game-Server - Generate C# ProtocolVersion class
    set cs_file "$SERVER_SCRIPTS/ProtocolVersion.cs"
    echo "// Auto-generated; DO NOT EDIT" > $cs_file
    echo "public static class ProtocolVersion {" >> $cs_file
    echo "    public const double PROTOCOL_VERSION = $pversion;" >> $cs_file
    echo "    public const string SCHEMA_VERSION = \"$sversion\";" >> $cs_file
    echo "}" >> $cs_file
    echo "Generated $cs_file"

    # GDScript Web-Client - Generate GDScript ProtocolVersion constants
    set gd_file "$CLIENT_SCRIPTS/ProtocolVersion.gd"
    echo "# Auto-generated from shared/rules.json; DO NOT EDIT" > $gd_file
    echo "const PROTOCOL_VERSION = $pversion" >> $gd_file
    echo "const SCHEMA_VERSION = \"$sversion\"" >> $gd_file
    echo "Generated $gd_file"

    # Shared version files
    echo "$pversion" > $SHARED/protocol_version.txt
    echo "$sversion" > $SHARED/schema_version.txt
end

function copy_protocol_artifacts
    echo "Copying protocol artifacts to export folders..."

    for target in $SERVER_EXPORT $CLIENT_EXPORT
        mkdir -p $target
        cp $SHARED/rules.json            $target/ 2>/dev/null || true
        cp $SHARED/message_ids.json      $target/ 2>/dev/null || true
        cp $SHARED/protocol_version.txt  $target/ 2>/dev/null || true
        cp $SHARED/schema_version.txt    $target/ 2>/dev/null || true
    end

    echo "Protocol artifacts copied to export folders"
end

#.----------------------------.
#| Build-Steps                |
#'----------------------------'
function build_server
    set pversion (jq -r '.protocol_version' $SHARED/rules.json)
    echo "Exporting server build v$pversion..."
    godot-mono --headless --export "Linux/X11" $SERVER_EXPORT/server-v$pversion.x86_64
end

function build_client
    echo "Exporting web client build..."
    godot-mono --headless --export "HTML5" $CLIENT_EXPORT/index.html
end

#.----------------------------.
#| Main-Entry-Point           |
#'----------------------------'
set MODE "normal"

if test "$argv[1]" = "--update-protocol"
    set MODE "update"
end

banner "Build Mode: $MODE"

if test "$MODE" = "normal"
    banner "Normal Mode: Drift Check + Validation + Build Only"
    validate_rules
    validate_message_ids_json
    check_protocol_drift
    check_schema_drift
    #build_server - still working on server export template
    #build_client - still working on client export template
    echo "Normal build complete (no protocol rebuild performed)"
    exit 0
end

if test "$MODE" = "update"
    banner "Protocol Update Mode: Full Regeneration + Build"
    validate_rules
    validate_message_ids_json
    generate_message_enums
    stamp_protocol_version
    copy_protocol_artifacts
    #build_server - still working on server export template
    #build_client - still working on client export template
    echo "Protocol update build complete"
    exit 0
end
