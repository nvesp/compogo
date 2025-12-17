#!/usr/bin/env fish

# RUN from compogo/godot folder
# Paths
set ROOT "C:/cygwin64/home/nvesp/projects/compogo/godot"
set SHARED "$ROOT/shared"
set SERVER "$ROOT/game-server"
set CLIENT "$ROOT/web-client"
set SERVER_EXPORT "$SERVER/export"
set CLIENT_EXPORT "$CLIENT/export"

# function validate_rules
#    set RULES_FILE "$SHARED/rules.json"
#    set SCHEMA_FILE "$SHARED/rules.schema.json"
#
#   if not test -f $RULES_FILE
#      echo "❌ Rules file missing"
#        exit 1
#    end
#    if not test -f $SCHEMA_FILE
#        echo "❌ Schema file missing"
#        exit 1
#    end
#
#    ajv validate -s $SCHEMA_FILE -d $RULES_FILE
#    if test $status -ne 0
#        echo "❌ Rules validation failed"
#        exit 1
#    else
#        echo "✅ Rules validated successfully"
#    end
#end

function copy_rules
    for target in $SERVER_EXPORT $CLIENT_EXPORT
        mkdir -p $target
        cp $SHARED/rules.json $target/rules.json
        echo "📦 Copied rules.json to $target"
    end
end

function stamp_version
    set version (jq '.protocol_version' $SHARED/rules.json)
    echo "🔖 Protocol version: v$version"
    echo v$version > $SERVER_EXPORT/version.txt
    echo v$version > $CLIENT_EXPORT/version.txt
end

function build_server
    set version (jq '.protocol_version' $SHARED/rules.json)
    echo "🚀 Exporting server build v$version..."
    godot-mono --headless --export "Linux/X11" $SERVER_EXPORT/server-v$version.x86_64
end

function build_client
    echo "🚀 Exporting web client build..."
    godot-mono --headless --export "HTML5" $CLIENT_EXPORT/index.html
end

function check_protocol_drift
    set current_version (jq '.protocol_version' $SHARED/rules.json)
    set last_version (cat $SERVER_EXPORT/version.txt)
    if test "$current_version" != "$last_version"
        echo "❌ Protocol drift detected: $last_version -> $current_version"
        exit 1
    else
        echo "✅ No protocol drift detected"
    end
end

function git_stamp_version
    set version (jq '.protocol_version' $SHARED/rules.json)
    git add .
    git commit -m "Bump protocol version to v$version"
    git tag -a "v$version" -m "Protocol version v$version"
end

# Combined workflow
#validate_rules
copy_rules
stamp_version
check_protocol_drift
build_server
build_client

echo "✅ Build process complete."

