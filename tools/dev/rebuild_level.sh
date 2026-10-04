#!/bin/sh
# Regenerates scenes/level/mausoleum.tscn from the jam map and bakes its navmesh.
# Usage: tools/dev/rebuild_level.sh [path/to/Godot]
set -e
cd "$(dirname "$0")/../.."
GODOT="${1:-${GODOT:-godot}}"
"$GODOT" --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/build_level.gd 2>&1 | grep -E "err=|^  |SCRIPT ERROR" || true
"$GODOT" --headless --path . -s res://tools/dev/run.gd -- --runner=res://tools/dev/bake_navmesh_runner.gd --scene=res://scenes/level/mausoleum.tscn 2>&1 | grep -E "baked|err=|SCRIPT ERROR" || true
