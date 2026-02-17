# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository shares Claude Code configuration (settings, commands, skills) across multiple machines via Git + symlinks. Files here are symlinked into `~/.claude/` so that changes propagate through commit & push.

## Setup & Sync Commands

```bash
# Initial setup: symlink repo files → ~/.claude/
./setup.sh

# Import unmanaged skills/commands from ~/.claude/ into repo, then link
./setup.sh --import

# Dry run (preview changes without modifying anything)
DRY_RUN=1 ./setup.sh

# Pull latest from other machines and re-link
git pull && ./setup.sh
```

The `sync-config` skill automates push/pull workflows via natural language.

## Architecture

### Symlink Model

`setup.sh` creates symlinks from `~/.claude/` pointing into this repo:
- `claude/settings.json` → `~/.claude/settings.json`
- `claude/commands/*.md` → `~/.claude/commands/*.md`
- `skills/*/` → `~/.claude/skills/*/`

The `--import` flag does the reverse: copies unmanaged files from `~/.claude/` into the repo before linking.

### Directory Layout

- **`claude/settings.json`** — Permissions and plugin config (shared across machines)
- **`claude/commands/`** — Custom slash commands (`.md` files)
- **`skills/`** — Skill definitions, each with a `SKILL.md` and optional supporting files

## Conventions

- `setup.sh` backs up existing files as `.bak` before replacing them and is safe to re-run (skips already-correct links).
- Skills are imported from both `~/.claude/skills/` and `~/.agents/skills/`.
