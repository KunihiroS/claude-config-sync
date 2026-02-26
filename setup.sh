#!/bin/bash
set -euo pipefail

# Claude Code Config Sync — Setup Script
#
# Creates symlinks from this repository into ~/.claude/ so that
# settings, commands, and skills stay in sync across machines.
#
# Usage:
#   ./setup.sh              Create symlinks from repo → ~/.claude/
#   ./setup.sh --import     Import unmanaged skills/commands into repo, then link
#   DRY_RUN=1 ./setup.sh    Dry run (show what would happen without making changes)
#
# Safety:
#   - Existing files are backed up with .bak suffix
#   - Already-correct symlinks are skipped
#   - Works on both Linux and macOS (no readlink -f dependency)

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN="${DRY_RUN:-0}"
IMPORT_MODE=0

for arg in "$@"; do
    case "$arg" in
        --import) IMPORT_MODE=1 ;;
        --dry-run) DRY_RUN=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() { echo "[setup] $*"; }
warn() { echo "[setup] WARNING: $*" >&2; }

# Resolve absolute path — portable replacement for readlink -f
resolve_path() {
    local target="$1"
    if [ -L "$target" ]; then
        local link_target
        link_target="$(readlink "$target")"
        if [[ "$link_target" = /* ]]; then
            resolve_path "$link_target"
        else
            resolve_path "$(dirname "$target")/$link_target"
        fi
    elif [ -d "$target" ]; then
        (cd "$target" && pwd)
    elif [ -f "$target" ]; then
        echo "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
    else
        echo "$target"
    fi
}

# Create a symlink, backing up any existing file
# $1: source path (inside repo)
# $2: destination path (inside ~/.claude/)
create_link() {
    local src="$1"
    local dest="$2"

    if [ -L "$dest" ]; then
        local current_target
        current_target="$(resolve_path "$dest")"
        if [ "$current_target" = "$(resolve_path "$src")" ]; then
            log "OK (already linked): $dest"
            return
        else
            warn "$dest is a symlink to $current_target, replacing..."
            [ "$DRY_RUN" = "1" ] && return
            rm "$dest"
        fi
    elif [ -e "$dest" ]; then
        log "Backing up: $dest → ${dest}.bak"
        [ "$DRY_RUN" = "1" ] || mv "$dest" "${dest}.bak"
    fi

    [ "$DRY_RUN" = "1" ] && { log "DRY RUN: ln -s $src $dest"; return; }

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    log "Created: $dest → $src"
}

echo "========================================"
echo " Claude Code Config Setup"
echo " Repository: $REPO_DIR"
echo " Target:     $CLAUDE_DIR"
[ "$DRY_RUN" = "1" ] && echo " Mode:       DRY RUN (no changes)"
[ "$IMPORT_MODE" = "1" ] && echo " Import:     ON (auto-import new skills/commands)"
echo "========================================"
echo ""

# =============================================================
# --import: Import unmanaged skills and commands into the repo
# =============================================================
if [ "$IMPORT_MODE" = "1" ]; then
    echo "--- Importing new commands ---"
    mkdir -p "$REPO_DIR/claude/commands"
    if [ -d "$CLAUDE_DIR/commands" ]; then
        for cmd_file in "$CLAUDE_DIR/commands"/*.md; do
            [ -f "$cmd_file" ] || continue
            [ -L "$cmd_file" ] && continue  # Already a symlink → managed
            cmd_name="$(basename "$cmd_file")"
            if [ -e "$REPO_DIR/claude/commands/$cmd_name" ]; then
                log "SKIP (already in repo): $cmd_name"
            else
                log "Importing command: $cmd_name"
                [ "$DRY_RUN" = "1" ] || cp "$cmd_file" "$REPO_DIR/claude/commands/"
            fi
        done
    fi

    echo ""
    echo "--- Importing new skills ---"
    mkdir -p "$REPO_DIR/skills"
    # Scan both ~/.claude/skills/ and ~/.agents/skills/
    for search_dir in "$CLAUDE_DIR/skills" "$HOME/.agents/skills"; do
        [ -d "$search_dir" ] || continue
        for skill_entry in "$search_dir"/*/; do
            [ -d "$skill_entry" ] || continue
            # If it's a symlink pointing into this repo, it's already managed
            if [ -L "${skill_entry%/}" ]; then
                local_target="$(resolve_path "${skill_entry%/}")"
                case "$local_target" in
                    "$REPO_DIR"*) continue ;;
                esac
            fi
            skill_name="$(basename "$skill_entry")"
            if [ -d "$REPO_DIR/skills/$skill_name" ]; then
                log "SKIP (already in repo): $skill_name"
            else
                log "Importing skill: $skill_name (from $search_dir)"
                if [ -L "${skill_entry%/}" ]; then
                    real_path="$(resolve_path "${skill_entry%/}")"
                    [ "$DRY_RUN" = "1" ] || cp -r "$real_path" "$REPO_DIR/skills/$skill_name"
                else
                    [ "$DRY_RUN" = "1" ] || cp -r "$skill_entry" "$REPO_DIR/skills/$skill_name"
                fi
            fi
        done
    done
    echo ""
fi

# =============================================================
# Main: Create symlinks from repo → ~/.claude/
# =============================================================

echo "--- Linking settings ---"
if [ -f "$REPO_DIR/claude/settings.json" ]; then
    create_link "$REPO_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
elif [ -f "$REPO_DIR/claude/settings.json.example" ]; then
    log "No settings.json found. Copying from settings.json.example..."
    [ "$DRY_RUN" = "1" ] || cp "$REPO_DIR/claude/settings.json.example" "$REPO_DIR/claude/settings.json"
    create_link "$REPO_DIR/claude/settings.json" "$CLAUDE_DIR/settings.json"
else
    warn "No settings.json or settings.json.example found, skipping."
fi

echo ""
echo "--- Linking commands ---"
mkdir -p "$CLAUDE_DIR/commands"
for cmd_file in "$REPO_DIR/claude/commands"/*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name="$(basename "$cmd_file")"
    create_link "$cmd_file" "$CLAUDE_DIR/commands/$cmd_name"
done

echo ""
echo "--- Linking skills for Claude Code ---"
mkdir -p "$CLAUDE_DIR/skills"
for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    create_link "$skill_dir" "$CLAUDE_DIR/skills/$skill_name"
done

echo ""
echo "--- Linking skills for Alternative Agents ---"
AGENT_DIR="$HOME/.agents"
mkdir -p "$AGENT_DIR/skills"
for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    create_link "$skill_dir" "$AGENT_DIR/skills/$skill_name"
done

echo ""
echo "========================================"
echo " Setup complete!"
echo ""
echo " Verify with:"
echo "   ls -la $CLAUDE_DIR/settings.json"
echo "   ls -la $CLAUDE_DIR/commands/"
echo "   ls -la $CLAUDE_DIR/skills/"
echo "   ls -la $HOME/.agents/skills/"
echo "========================================"
