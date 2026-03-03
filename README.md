# acorn

Turns GitHub issues into agent-ready implementation specs.

Ideas start small. Acorn grows them into something an agent can build.

## What It Does

Acorn takes a GitHub issue and runs it through a multi-agent planning pipeline to produce a detailed implementation specification (`SPEC.md`). Three pipeline modes let you trade thoroughness for speed:

| Mode | Flag | Stages | Agents | Recon Model | Planning Model | Best For |
|------|------|--------|--------|-------------|----------------|----------|
| Full | _(default)_ | 6 | 14 | Opus | Opus | Complex features, architectural decisions |
| Lite | `--lite` | 4 | 6 | Sonnet | Opus | Standard features, moderate complexity |
| Quick | `--quick` | 2 | 4 | Sonnet | Opus | Simple features, time-sensitive changes |

All modes ground planning in actual codebase reconnaissance. The difference is how many competing drafts, evaluations, and adversarial reviews are performed.

**The pipeline:**

```
GitHub Issue
    |
    v
acorn create <repo> <issue#> [--lite | --quick]
    |-- Fetches issue (title, body, comments)
    |-- Downloads any images from the issue to .specs/<slug>/images/
    |-- Generates PROMPT.md with requirements + planning methodology
    |   (image URLs rewritten to local paths for agent visibility)
    |-- Sets GitHub label: spec-in-progress
    |-- Starts a detached Claude Code session in tmux
    |
    v
Multi-Agent Planning (mode-dependent)
    |
    v
acorn approve <repo> <slug>
    |-- Verifies SPEC.md exists
    |-- Sets GitHub label: spec-approved
```

## Dependencies

Install these before using Acorn:

| Dependency | Purpose | Install |
|------------|---------|---------|
| **gh** | GitHub CLI — fetches issues, manages labels, posts comments | `brew install gh` then `gh auth login` |
| **jq** | JSON parsing | `brew install jq` |
| **tmux** | Session management for detached agent sessions | `brew install tmux` |
| **claude** | Claude Code CLI — runs the planning pipeline | See [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) |
| **curl** | Downloads images from GitHub issues | Pre-installed on macOS and most Linux |

On Linux, replace `brew install` with your package manager (e.g., `apt install gh jq tmux`).

### Verify dependencies

```bash
gh --version
jq --version
tmux -V
claude --version
```

### GitHub authentication

Acorn uses `gh` for all GitHub operations. You must be authenticated:

```bash
gh auth login
gh auth status   # confirm you're logged in
```

## Installation

### With Cashew (recommended)

If you already have [cashew](https://github.com/andrewxhill/cashew) installed, `dev` is already in place. Just add acorn:

```bash
git clone git@github.com:craigmmills/acorn.git
ln -s "$(pwd)/acorn/bin/acorn" /usr/local/bin/acorn

# Register /acorn command with Claude Code
ln -sf "$(pwd)/acorn/claude/commands/acorn.md" ~/.claude/commands/acorn.md

acorn --help
```

### Standalone (without Cashew)

```bash
# Clone the repo
git clone git@github.com:craigmmills/acorn.git

# Add to your PATH (pick one)

# Option A: Symlink into a directory already on your PATH
ln -s "$(pwd)/acorn/bin/acorn" /usr/local/bin/acorn

# Option B: Add to PATH in your shell profile (~/.zshrc or ~/.bashrc)
export PATH="$HOME/path/to/acorn/bin:$PATH"

# Register /acorn command with Claude Code
mkdir -p ~/.claude/commands
ln -sf "$(pwd)/acorn/claude/commands/acorn.md" ~/.claude/commands/acorn.md
```

### Verify installation

```bash
acorn --help
claude --version
```

### Cashew compatibility

Acorn is designed to work alongside cashew's `dev` session manager:

- **Project layout**: Both use `~/Projects/<repo>/main/` (auto-detects `~/Projects` or `~/projects`)
- **Sessions**: Acorn creates tmux sessions named `<repo>_specs_<slug>_claude` — these show up in `dev` session listings
- **No conflicts**: Acorn's `.specs/` directory lives inside `main/` and doesn't interfere with cashew worktrees

## Project Layout Convention

Acorn expects your projects to live at `~/Projects/<repo>/main/` (or `~/projects/<repo>/main/`). This is the directory where `gh` commands run and where `.specs/` directories are created.

```
~/Projects/
  myapp/
    main/              <-- repo checkout (acorn operates here)
      .specs/          <-- created by acorn
        42-add-auth/
          PROMPT.md    <-- generated requirements + planning methodology
          meta.json    <-- metadata (repo, issue, session info, mode)
          images/      <-- downloaded images from the GitHub issue
            <hash>.png   (auto-downloaded, referenced in PROMPT.md)
          recon/                        Full  Lite  Quick
            architecture.md              Y     Y     Y
            relevant_code.md             Y     Y     Y
            conventions.md               Y     Y     Y
          plans/
            draft_plan_1..4.md           Y     -     -
            draft.md                     -     Y     -
            evaluation.md                Y     -     -
            master_plan.md               Y     -     -
            validation.md                -     Y     -
            red_team_1..4.md             Y     -     -
            SPEC.md                      Y     Y     Y
```

## Usage

### Create a spec from a GitHub issue

```bash
# Full pipeline (default) — 14 agents, 6 stages
acorn create myapp 42

# Lite pipeline — 6 agents, 4 stages
acorn create myapp 42 --lite

# Quick pipeline — 4 agents, 2 stages
acorn create myapp 42 --quick
```

This will:
1. Fetch issue #42 from the `myapp` repo
2. Generate a slug (e.g., `42-add-authentication`)
3. Create `.specs/42-add-authentication/PROMPT.md` with full requirements and planning instructions
4. Create lifecycle labels on the repo if they don't exist
5. Set the issue label to `spec-in-progress`
6. Post a comment on the issue with the spec location
7. Start a detached tmux session with Claude Code
8. Automatically trigger the planning pipeline after ~5 seconds

Monitor or attach anytime:

```bash
# Attach to the session (session name is printed by acorn create)
tmux attach -t <session-name>
```

To opt out of auto-triggering:

```bash
acorn create myapp 42 --no-auto
```

### List all specs

```bash
# List specs across all repos
acorn list

# List specs for a specific repo
acorn list myapp
```

Output shows repo, issue number, slug, status, age, and path.

**Status values:**
- `planning` — PROMPT.md exists, agent is working
- `review` — plans/SPEC.md exists, ready for human review
- `approved` — spec has been approved for implementation
- `unknown` — spec directory exists but state is unclear

### Approve a spec

After reviewing the generated `plans/SPEC.md`:

```bash
acorn approve myapp 42-add-authentication
```

This sets the GitHub label to `spec-approved` and posts an approval comment on the issue.

### Clean up a spec

```bash
# Interactive confirmation
acorn clean myapp 42-add-authentication

# Skip confirmation
acorn clean myapp 42-add-authentication --yes

# Also remove lifecycle labels from the issue
acorn clean myapp 42-add-authentication --remove-labels --yes

# Force delete even if SPEC.md exists and issue is still open
acorn clean myapp 42-add-authentication --force --yes
```

This kills the associated tmux session and deletes the spec directory.

**Safety check:** If `plans/SPEC.md` exists and the GitHub issue is still open, `clean` will refuse to delete the spec directory — this prevents accidental loss of generated specs before implementation. Use `--force` to override.

### Create a GitHub issue

By default, `acorn issue create` enters interactive mode and prompts for a structured template:

```bash
acorn issue create myapp "Add user authentication"
# Prompts for: Job Story, Promise, Constraints, Acceptance Criteria, Context
# All sections are optional — press Enter to skip
```

To bypass the template and provide the body directly:

```bash
acorn issue create myapp "Add user authentication" \
  --body "We need OAuth2 login with Google and GitHub providers" \
  --label "feature" \
  --assignee "username"
```

To create an issue with no body (skip template entirely):

```bash
acorn issue create myapp "Add user authentication" --raw
```

Options:
- `--body <text>` — Issue body text (bypasses interactive template)
- `--body-file <path>` — Read body from a file (bypasses interactive template)
- `--raw` — Skip the interactive template prompt
- `--label <name>` — Add a label (repeatable)
- `--assignee <login>` — Assign a user (repeatable)

#### Template sections

The interactive template collects five optional sections, optimized for AI spec generation:

| Section | Format | Purpose |
|---------|--------|---------|
| Job Story | "When [situation], I want [action], so I can [outcome]" | Captures problem, user, and motivation |
| Promise | "After this ships: [guarantee]" | Defines desired behavior as commitment |
| Constraints | Free text | What must not change, out of scope |
| Acceptance Criteria | Free text | Testable conditions proving promise is met |
| Context | Free text | Examples, links, prior art |

### Create an issue and start planning immediately

```bash
acorn issue plan myapp "Add user authentication"
# Interactive template prompts, then immediately starts spec generation

# With direct body (bypasses template)
acorn issue plan myapp "Add user authentication" \
  --body "We need OAuth2 login with Google and GitHub providers"

# With lite or quick mode
acorn issue plan myapp "Add user authentication" --lite
```

This combines `issue create` + `create` — it creates the GitHub issue and immediately starts spec generation.

## GitHub Label Lifecycle

Acorn manages these labels automatically (creates them if they don't exist):

| Label | Set By | Meaning |
|-------|--------|---------|
| `ready-for-spec` | Manual | Issue is ready for spec creation |
| `spec-in-progress` | `acorn create` | Planning pipeline is running |
| `spec-review` | Manual | Spec is ready for review |
| `spec-approved` | `acorn approve` | Spec approved for implementation |

## How the Planning Pipeline Works

The `PROMPT.md` generated by Acorn contains embedded instructions for the planning methodology (mode-dependent). When Claude Code reads it and you say "let's draft this", it orchestrates the pipeline.

### Full Pipeline (default)

6 stages, 14 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Opus sub-agents explore the actual codebase from different angles (architecture, relevant code, conventions)
1. **Stage 1 — Diverse Parallel Drafting**: 4 Opus sub-agents each independently draft a complete implementation plan with a distinct architectural lens (Minimal Surgery, Clean Architecture, Robustness-First, Developer Experience)
2. **Stage 2 — Rubric-Based Evaluation**: 1 Opus sub-agent scores all 4 drafts against a structured rubric
3. **Stage 3 — Weighted Synthesis**: 1 Opus sub-agent synthesizes a master plan using scored drafts
4. **Stage 4 — Adversarial Red Team**: 4 Opus sub-agents each attack the master plan from a different angle
5. **Stage 5 — Final Spec**: 1 Opus sub-agent produces `plans/SPEC.md` with traceability matrix and red team resolution log

### Lite Pipeline (`--lite`)

4 stages, 6 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Sonnet sub-agents (same recon as full)
1. **Stage 1 — Comprehensive Draft**: 1 Opus sub-agent drafts a single plan balancing all four architectural lenses
2. **Stage 2 — Combined Validation**: 1 Opus sub-agent performs requirements coverage, codebase fact-check, ambiguity audit, and edge case analysis
3. **Stage 3 — Final Spec**: 1 Opus sub-agent incorporates validation findings into `plans/SPEC.md`

### Quick Pipeline (`--quick`)

2 stages, 4 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Sonnet sub-agents (same recon as full)
1. **Stage 1 — Direct Spec**: 1 Opus sub-agent reads recon + requirements and produces `plans/SPEC.md` directly

### Orchestrator Design

The orchestrator agent's only job is to launch sub-agents and confirm completion — it never writes plan content itself. This keeps its context window clean while leveraging independent 200k-token contexts for thorough analysis.

### Image Extraction

When a GitHub issue contains images (screenshots, mockups, diagrams), `acorn create` automatically:

1. **Extracts** image URLs from the issue body and comments (`![alt](url)` syntax)
2. **Downloads** images to `.specs/<slug>/images/` with deterministic hash-based filenames
3. **Rewrites** the URLs in `PROMPT.md` to local paths so planning agents can view them

This means planning agents can actually **see** screenshots and mockups via Claude Code's Read tool, rather than just seeing markdown URL text. The Architecture recon agent (Stage 0) is specifically instructed to examine any images in the `images/` directory.

Supported formats: PNG, JPG, JPEG, GIF, WebP, SVG. GitHub asset UUID URLs (from drag-and-drop uploads) are also handled.

If a download fails, the original remote URL is preserved in PROMPT.md and the pipeline continues normally.

## Command Reference

```
acorn create <repo> <issue-number> [--no-auto] [--lite | --quick]
    Create a spec from a GitHub issue, start a planning session, and auto-trigger planning
    --lite    Use lite 4-stage pipeline (6 agents, Sonnet recon)
    --quick   Use quick 2-stage pipeline (4 agents, Sonnet recon)

acorn list [repo]
    List all specs and their status (optionally filtered by repo)

acorn approve <repo> <slug>
    Approve a completed spec for implementation

acorn clean <repo> <slug> [--remove-labels] [--yes] [--force]
    Remove a spec directory and kill its session (refuses if SPEC.md exists and issue is open; use --force to override)

acorn issue create <repo> <title> [options]
    Create a new GitHub issue

acorn issue plan <repo> <title> [options] [--no-auto] [--lite | --quick]
    Create a GitHub issue and immediately start spec creation
```

## Testing

```bash
# Run unit tests (no network calls to GitHub API)
bash test/test_images.sh

# Run full suite including integration test
# (creates a temporary GitHub issue, runs acorn create, verifies image pipeline, cleans up)
INTEGRATION=1 bash test/test_images.sh
```

## Troubleshooting

**"Missing required command(s): claude"**
Install Claude Code. See [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code).

**"Missing required command(s): gh"**
Install the GitHub CLI: `brew install gh` and authenticate with `gh auth login`.

**"Repo path not found: ~/Projects/myapp/main"**
Acorn expects your repo at `~/Projects/<repo>/main/` (or `~/projects/<repo>/main/`). Clone or move your repo there. If using cashew, `dev new <repo> <git-url>` sets this up automatically.

**"Failed to fetch issue #42"**
Make sure `gh` is authenticated and has access to the repo. Run `gh auth status` and check `gh issue view 42` from within the repo.

**Session doesn't start**
Ensure tmux is installed (`brew install tmux`).

**PROMPT.md already exists**
`acorn create` is idempotent — it won't overwrite an existing PROMPT.md. To regenerate, clean first: `acorn clean <repo> <slug> --force --yes` then re-run create.

**Auto-trigger doesn't fire**
The auto-trigger sends the planning prompt to Claude Code via tmux after a ~5 second delay. If Claude Code hasn't finished initializing, attach to the session and send the trigger manually: say "let's draft this".
