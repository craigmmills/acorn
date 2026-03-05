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

# Acorn orchestrate skill
ln -sf ~/Projects/acorn/main/.claude/skills/orchestrate ~/.claude/skills/acorn-orchestrate

# Acorn issue-craft skill
ln -sf ~/Projects/acorn/main/.claude/skills/issue-craft ~/.claude/skills/acorn-issue-craft

# Acorn spec-review skill
ln -sf ~/Projects/acorn/main/.claude/skills/spec-review ~/.claude/skills/acorn-spec-review
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
ls -la ~/.claude/skills/acorn-orchestrate
ls -la ~/.claude/skills/acorn-issue-craft
ls -la ~/.claude/skills/acorn-spec-review
git --git-dir=$HOME/Projects/acorn/.bare remote -v | grep -q "git@github.com"
```

## What Gets Installed

| Component | Location | Purpose |
|-----------|----------|---------|
| acorn binary | `/usr/local/bin/acorn` | CLI tool (symlink to repo) |
| Global Claude config | `~/.claude/CLAUDE.md` | Acorn block appended (idempotent) |
| /acorn command | `~/.claude/commands/acorn.md` | Full command reference (symlink to repo) |
| /acorn-setup skill | `~/.claude/skills/acorn-setup/` | This bootstrap skill (symlink to repo) |
| /acorn-orchestrate skill | `~/.claude/skills/acorn-orchestrate/` | Batch spec & implementation pipeline (symlink to repo) |
| /acorn-issue-craft skill | `~/.claude/skills/acorn-issue-craft/` | Idea-to-issue crafting workflow (symlink to repo) |
| /acorn-spec-review skill | `~/.claude/skills/acorn-spec-review/` | Spec review & implementation handoff (symlink to repo) |
