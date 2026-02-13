# acorn

Turns GitHub issues into agent-ready implementation specs.

Ideas start small. Acorn grows them into something an agent can build.

## What It Does

Acorn takes a GitHub issue and runs it through a 5-stage multi-agent planning pipeline to produce a detailed implementation specification (`SPEC.md`). The pipeline launches 13 Claude sub-agents across 5 stages — reconnaissance, drafting, evaluating, synthesizing, red-teaming, and finalizing — to produce a spec that's ready to hand to a developer or agent for implementation.

**The pipeline:**

```
GitHub Issue
    |
    v
acorn create <repo> <issue#>
    |-- Fetches issue (title, body, comments)
    |-- Generates PROMPT.md with requirements + planning methodology
    |-- Sets GitHub label: spec-in-progress
    |-- Starts a detached Claude Code session in tmux
    |
    v
5-Stage Multi-Agent Planning (13 sub-agents)
    |-- Stage 0: 3 agents explore the codebase (architecture, relevant code, conventions)
    |-- Stage 1: 4 agents draft plans with distinct architectural lenses
    |-- Stage 2: 1 agent scores all drafts against a structured rubric
    |-- Stage 3: 1 agent synthesizes a master plan using scored drafts
    |-- Stage 4: 4 agents adversarially red-team the master plan
    |-- Stage 5: 1 agent produces final SPEC.md with requirements traceability
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
          meta.json    <-- metadata (repo, issue, session info)
          recon/
            architecture.md    <-- Stage 0: project structure & tech stack
            relevant_code.md   <-- Stage 0: files & APIs relevant to the feature
            conventions.md     <-- Stage 0: coding patterns & constraints
          plans/
            draft_plan_1.md    <-- Stage 1: Minimal Surgery lens
            draft_plan_2.md    <-- Stage 1: Clean Architecture lens
            draft_plan_3.md    <-- Stage 1: Robustness-First lens
            draft_plan_4.md    <-- Stage 1: Developer Experience lens
            evaluation.md      <-- Stage 2: rubric scores for all drafts
            master_plan.md     <-- Stage 3: synthesized master plan
            red_team_1.md      <-- Stage 4: Requirements Auditor
            red_team_2.md      <-- Stage 4: Ambiguity Hunter
            red_team_3.md      <-- Stage 4: Codebase Validator
            red_team_4.md      <-- Stage 4: Contradiction & Edge Case Finder
            SPEC.md            <-- Stage 5: final implementation spec
```

## Usage

### Create a spec from a GitHub issue

```bash
acorn create myapp 42
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
```

This kills the associated tmux session and deletes the spec directory.

### Create a GitHub issue

```bash
acorn issue create myapp "Add user authentication" \
  --body "We need OAuth2 login with Google and GitHub providers" \
  --label "feature" \
  --assignee "username"
```

Options:
- `--body <text>` — Issue body text
- `--body-file <path>` — Read body from a file (mutually exclusive with `--body`)
- `--label <name>` — Add a label (repeatable)
- `--assignee <login>` — Assign a user (repeatable)

### Create an issue and start planning immediately

```bash
acorn issue plan myapp "Add user authentication" \
  --body "We need OAuth2 login with Google and GitHub providers"
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

The `PROMPT.md` generated by Acorn contains embedded instructions for a 5-stage multi-agent planning methodology. When Claude Code reads it and you say "let's draft this", it orchestrates:

0. **Stage 0 — Codebase Reconnaissance**: 3 sub-agents explore the actual codebase from different angles (architecture, relevant code, conventions) to ground all subsequent work in reality
1. **Stage 1 — Diverse Parallel Drafting**: 4 sub-agents each independently draft a complete implementation plan, each with a distinct architectural lens (Minimal Surgery, Clean Architecture, Robustness-First, Developer Experience)
2. **Stage 2 — Rubric-Based Evaluation**: 1 sub-agent scores all 4 drafts against a structured rubric (requirements coverage, implementability, codebase consistency, completeness, feasibility, risk identification)
3. **Stage 3 — Weighted Synthesis**: 1 sub-agent reads all drafts plus the evaluation scores and synthesizes a master plan, using scores to guide trade-offs
4. **Stage 4 — Adversarial Red Team**: 4 sub-agents each attack the master plan from a different angle (requirements auditing, ambiguity hunting, codebase validation, contradiction/edge case finding)
5. **Stage 5 — Final Spec**: 1 sub-agent incorporates all red team findings into the final `plans/SPEC.md` with a requirements traceability matrix and red team resolution log

**Total: 13 sub-agent launches. No shortcuts.**

The orchestrator agent's only job is to launch sub-agents and confirm completion — it never writes plan content itself. This keeps its context window clean while leveraging 13 independent 200k-token contexts for thorough analysis.

## Command Reference

```
acorn create <repo> <issue-number> [--no-auto]
    Create a spec from a GitHub issue, start a planning session, and auto-trigger planning

acorn list [repo]
    List all specs and their status (optionally filtered by repo)

acorn approve <repo> <slug>
    Approve a completed spec for implementation

acorn clean <repo> <slug> [--remove-labels] [--yes]
    Remove a spec directory and kill its session

acorn issue create <repo> <title> [options]
    Create a new GitHub issue

acorn issue plan <repo> <title> [options] [--no-auto]
    Create a GitHub issue and immediately start spec creation
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
`acorn create` is idempotent — it won't overwrite an existing PROMPT.md. To regenerate, clean first: `acorn clean <repo> <slug> --yes` then re-run create.

**Auto-trigger doesn't fire**
The auto-trigger sends the planning prompt to Claude Code via tmux after a ~5 second delay. If Claude Code hasn't finished initializing, attach to the session and send the trigger manually: say "let's draft this".
