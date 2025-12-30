#!/usr/bin/env fish

# RUN from compogo/godot folder
# Paths
set ROOT (pwd)
set SHARED "$ROOT/shared"
set SERVER "$ROOT/game-server"
set CLIENT "$ROOT/web-client"
set SERVER_SCRIPTS "$SERVER/scripts"
set CLIENT_SCRIPTS "$CLIENT/scripts"
set SERVER_EXPORT "$SERVER/export"
set CLIENT_EXPORT "$CLIENT/export"

function validate_rules
    set RULES_FILE "$SHARED/rules.json"
    set SCHEMA_FILE "$SHARED/rules.schema.json"

    if not test -f $RULES_FILE
        echo "❌ Rules file missing"
        exit 1
    end
    if not test -f $SCHEMA_FILE
        echo "❌ Schema file missing"
        exit 1
    end

    ajv validate -s $SCHEMA_FILE -d $RULES_FILE
    if test $status -ne 0
        echo "Rules validation failed"
        exit 1
    else
        echo "Rules validated successfully"
    end
end

function generate_message_enums
    set pversion (jq -r '.protocol_version' $SHARED/rules.json)
    set sversion (jq -r '.schema_version' $SHARED/rules.json)
    
    echo "Generating message enums (protocol_version: $pversion, schema_version: $sversion)..."
    
    # Generate C# MessageID enum
    set csharp_file "$SERVER_SCRIPTS/MessageIDcs"
    echo "// Auto-generated from shared/message_ids.json; DO NOT EDIT" > $csharp_file
    echo "// Protocol Version: $pversion | Schema Version: $sversion" >> $csharp_file
    echo "" >> $csharp_file
    echo "public enum MessageID : int" >> $csharp_file
    echo "{" >> $csharp_file
    
    jq -r '.messages[] | "    \(.name) = \(.id),"' $SHARED/message_ids.json >> $csharp_file
    
    echo "}" >> $csharp_file
    echo "" >> $csharp_file
    echo "public enum ErrorCode : int" >> $csharp_file
    echo "{" >> $csharp_file
    
    jq -r '.error_codes | to_entries[] | "    \(.key) = \(.value),"' $SHARED/message_ids.json >> $csharp_file
    
    echo "}" >> $csharp_file
    
    echo "Generated $csharp_file"
    
    # Generate GDScript MessageID constants
    set gdscript_file "$CLIENT_SCRIPTS/MessageID.gd" 
    echo "# Auto-generated from shared/message_ids.json; DO NOT EDIT" > $gdscript_file
    echo "# Protocol Version: $pversion | Schema Version: $sversion" >> $gdscript_file
    echo "" >> $gdscript_file
    echo "# System Messages (0-9)" >> $gdscript_file
    echo "# Movement Messages (10-19)" >> $gdscript_file
    echo "# Combat Messages (30-39)" >> $gdscript_file
    echo "# Broadcast Messages (40-49)" >> $gdscript_file
    echo "" >> $gdscript_file
    
    jq -r '.messages[] | "const \(.name) = \(.id)"' $SHARED/message_ids.json >> $gdscript_file
    
    echo "" >> $gdscript_file
    echo "# Error Codes" >> $gdscript_file
    
    jq -r '.error_codes | to_entries[] | "const ERROR_\(.key) = \(.value)"' $SHARED/message_ids.json >> $gdscript_file
    
    echo "Generated $gdscript_file"
    
    # Validate no duplicate IDs
    set dup_count (jq '.messages | group_by(.id) | map(select(length > 1)) | length' $SHARED/message_ids.json)
    if test $dup_count -gt 0
        echo "ERROR: Duplicate message IDs detected in message_ids.json"
        exit 1
    end
end

function stamp_protocol_version
    set pversion (jq -r '.protocol_version' $SHARED/rules.json)
    set sversion (jq -r '.schema_version' $SHARED/rules.json)
    
    echo "Stamping protocol version: $pversion (schema: $sversion)..."
    
    # Generate C# ProtocolVersion class
    set cs_file "$SERVER_SCRIPTS/ProtocolVersion.cs"
    echo "// Auto-generated from shared/rules.json; DO NOT EDIT" > $cs_file
    echo "public static class ProtocolVersion" >> $cs_file
    echo "{" >> $cs_file
    echo "    public const double PROTOCOL_VERSION = $pversion;" >> $cs_file
    echo "    public const string SCHEMA_VERSION = \"$sversion\";" >> $cs_file
    echo "}" >> $cs_file
    echo "Generated $cs_file"
    
    # Generate GDScript ProtocolVersion constants
    set gd_file "$CLIENT_SCRIPTS/ProtocolVersion.gd"
    echo "# Auto-generated from shared/rules.json; DO NOT EDIT" > $gd_file
    echo "const PROTOCOL_VERSION = $pversion" >> $gd_file
    echo "const SCHEMA_VERSION = \"$sversion\"" >> $gd_file
    echo "Generated $gd_file"
    
    # Stamp version file in shared folder
    echo "v$pversion" > $SHARED/protocol_version.txt
end

function copy_protocol_artifacts
    echo "Copying protocol artifacts to export folders..."
    
    # Copy generated enums and version info
    for target in $SERVER_EXPORT $CLIENT_EXPORT
        mkdir -p $target
        cp $SHARED/rules.json $target/ 2>/dev/null || true
        cp $SHARED/message_ids.json $target/ 2>/dev/null || true
        cp $SHARED/protocol_version.txt $target/ 2>/dev/null || true
    end
    
    echo "Protocol artifacts copied to export folders"
end

function validate_message_ids_json
    echo "Validating message_ids.json structure..."
    
    if not jq empty $SHARED/message_ids.json 2>/dev/null
        echo "message_ids.json is not valid JSON"
        exit 1
    end
    
    # Check required fields
    set has_messages (jq 'has("messages")' $SHARED/message_ids.json)
    set has_errors (jq 'has("error_codes")' $SHARED/message_ids.json)
    
    if test "$has_messages" != "true" -o "$has_errors" != "true"
        echo "message_ids.json missing required fields (messages, error_codes)"
        exit 1
    end
    
    echo "message_ids.json is valid"
end

function build_server
    set pversion (jq '.protocol_version' $SHARED/rules.json)
    echo "Exporting server build v$pversion..."
    godot-mono --headless --export "Linux/X11" $SERVER_EXPORT/server-v$pversion.x86_64
end

function build_client
    echo "Exporting web client build..."
    godot-mono --headless --export "HTML5" $CLIENT_EXPORT/index.html
end

# CHECK protocol drift function
function check_protocol_drift
    set current_sversion (jq '.protocol_version' $SHARED/rules.json)
    set last_sversion (cat $SERVER_EXPORT/version.txt)
    if test "$current_sversion" != "$last_sversion"
        echo "Server Protocol drift detected: $last_sversion -> $current_sversion"
        exit 1
    else
        echo "No server protocol drift detected"
    end
end

# CHECK schema drift function
function check_schema_drift
    set current_sversion (jq '.schema_version' $SHARED/rules.json)
    set last_sversion (cat $SERVER_EXPORT/version.txt)
    if test "$current_sversion" != "$last_sversion"
        echo "Server Protocol drift detected: $last_sversion -> $current_sversion"
        exit 1
    else
        echo "No server protocol drift detected"
    end
end

function git_stamp_version
    set gversion (mrun "jq '.protocol_version' $SHARED/rules.json")
    git add .
    git commit -m "Bump protocol version to v$gversion"
    git tag -a "v$gversion" -m "Protocol version v$gversion"
end

# Combined workflow
#validate_rules fix these 
validate_message_ids_json
generate_message_enums
stamp_protocol_version
copy_protocol_artifacts
check_protocol_drift
#build_server still working on export templates
#build_client still working on export templates


echo "Build process complete."
