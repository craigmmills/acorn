# Setup — Install Acorn Globally

Use this skill to install the acorn CLI and make Claude aware of it in every project.

## When to Use

When the user asks to set up acorn, install acorn, or says something like "set up acorn" or "install acorn globally".

## Step 1: Symlink the Binary

```bash
sudo ln -sf ~/Projects/acorn/main/bin/acorn /usr/local/bin/acorn
```

Verify it works:

```bash
acorn --help
```

## Step 2: Append Acorn Block to Global Claude Config

Append Acorn's global context block to the end of `~/.claude/CLAUDE.md`. Only add it if the block isn't already present:

```bash
ACORN_ROOT=~/Projects/acorn/main
ACORN_BLOCK=$ACORN_ROOT/claude/global/CLAUDE.md
TARGET=~/.claude/CLAUDE.md

if ! grep -q "BEGIN ACORN GLOBAL CONTEXT" "$TARGET" 2>/dev/null; then
  {
    echo ""
    echo "<!-- BEGIN ACORN GLOBAL CONTEXT -->"
    cat "$ACORN_BLOCK"
    echo "<!-- END ACORN GLOBAL CONTEXT -->"
  } >> "$TARGET"
fi
```

## Step 3: Symlink Commands and Skills

```bash
# Acorn command reference
ln -sf ~/Projects/acorn/main/claude/commands/acorn.md ~/.claude/commands/acorn.md

# Acorn setup skill (this file)
ln -sf ~/Projects/acorn/main/.claude/skills/setup ~/.claude/skills/acorn-setup
```

## Step 4: Fix Git Remote to SSH

```bash
git --git-dir=$HOME/Projects/acorn/.bare remote set-url origin git@github.com:craigmmills/acorn.git
```

Verify:

```bash
git --git-dir=$HOME/Projects/acorn/.bare remote -v
```

## Step 5: Verify Installation

```bash
acorn --help
grep "ACORN GLOBAL CONTEXT" ~/.claude/CLAUDE.md
ls -la ~/.claude/commands/acorn.md
ls -la ~/.claude/skills/acorn-setup
git --git-dir=$HOME/Projects/acorn/.bare remote -v | grep -q "git@github.com"
```

## What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| acorn binary | `/usr/local/bin/acorn` | CLI tool (symlink to repo) |
| Global Claude config | `~/.claude/CLAUDE.md` | Acorn block appended (idempotent) |
| /acorn command | `~/.claude/commands/acorn.md` | Full command reference (symlink to repo) |
| /acorn-setup skill | `~/.claude/skills/acorn-setup/` | This bootstrap skill (symlink to repo) |
