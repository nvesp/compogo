#!/usr/bin/env fish

\\ Run from compogo/godot/
\\ deprecated: uses resource_paths in project.godot
\\ instead of symlinks to shared folder

# Paths
set ROOT (pwd)
set SERVER "$ROOT/game-server"
set CLIENT "$ROOT/web-client"
set SHARED "$ROOT/shared"

function make_symlink --argument dir
    set target "$dir/shared"
    if test -L $target
        echo "🔗 Symlink already exists in $dir"
    else if test -e $target
        echo "⚠️ $target exists but is not a symlink, skipping"
    else
        ln -s ../shared $target
        echo "✅ Created symlink: $target -> ../shared"
    end
end

function clear_cache --argument dir
    set cache "$dir/.godot"
    if test -d $cache
        rm -rf $cache
        echo "🧹 Cleared cache: $cache"
    else
        echo "ℹ️ No cache found in $dir"
    end
end

# Ensure shared folder exists
if not test -d $SHARED
    echo "❌ Shared directory not found at $SHARED"
    exit 1
end

# Create symlinks
make_symlink $SERVER
make_symlink $CLIENT

# Clear Godot import caches
clear_cache $SERVER
clear_cache $CLIENT

echo "🚀 Bootstrap complete. Restart Godot editor to re-import shared resources."
