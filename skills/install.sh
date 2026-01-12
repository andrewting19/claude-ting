#!/bin/bash
# Install skills to ~/.claude/skills/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.claude/skills"

mkdir -p "$TARGET_DIR"

for skill_dir in "$SCRIPT_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        echo "Installing $skill_name..."
        rm -rf "$TARGET_DIR/$skill_name"
        cp -r "$skill_dir" "$TARGET_DIR/$skill_name"
    fi
done

echo "Done. Installed skills to $TARGET_DIR"
ls -la "$TARGET_DIR"
