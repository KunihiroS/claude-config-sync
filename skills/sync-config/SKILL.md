---
name: sync-config
description: Sync Claude Code settings, skills, and commands to the Git repository. Use when asked to share, sync, push, or pull configuration.
allowed-tools: Bash, Read
---

Config sync skill for Claude Code.

Determine the repo directory dynamically:

```bash
REPO_DIR="$(git -C "$(dirname "$(readlink -f ~/.claude/skills/sync-config)")" rev-parse --show-toplevel 2>/dev/null || echo "")"
```

If REPO_DIR is empty (e.g. readlink -f unavailable on macOS), fall back:

```bash
REPO_DIR="$(cd "$(dirname "$(readlink ~/.claude/skills/sync-config)")" && git rev-parse --show-toplevel)"
```

Use the resolved REPO_DIR for all operations below.

## A. Push (share changes from this machine)

Triggered by: "share", "sync", "push", "added a new skill", etc.

### Steps

1. Import unmanaged skills and commands:
   ```bash
   cd "$REPO_DIR" && ./setup.sh --import
   ```

2. Check for changes:
   ```bash
   cd "$REPO_DIR" && git status && git diff
   ```

3. If no changes, report "Already in sync, no changes." and stop.

4. Summarize changes and ask the user for confirmation.

5. After approval, commit and push:
   ```bash
   cd "$REPO_DIR" && git add -A && git commit -m "<summary of changes>" && git push
   ```

6. Report completion.

## B. Pull (fetch changes from another machine)

Triggered by: "update", "pull", "get latest", etc.

### Steps

1. Pull and re-link:
   ```bash
   cd "$REPO_DIR" && git pull && ./setup.sh
   ```

2. Report the result.
