# acorn

Turns GitHub issues into agent-ready implementation specs.

Ideas start small. Acorn grows them into something an agent can build.

## What It Does

Acorn takes a GitHub issue and runs it through a multi-agent planning pipeline to produce a detailed implementation specification (`SPEC.md`). Three pipeline modes let you trade thoroughness for speed:

| Mode | Flag | Stages | Agents | Recon Model | Planning Model | Best For |
|------|------|--------|--------|-------------|----------------|----------|
| Full | _(default)_ | 6 | 14 | Sonnet | Mixed (Opus + Sonnet + Fable) | Complex features, architectural decisions |
| Lite | `--lite` | 4 | 6 | Sonnet | Opus (Sonnet validation) | Standard features, moderate complexity |
| Quick | `--quick` | 2 | 4 | Sonnet | Opus | Simple features, time-sensitive changes |

All modes ground planning in actual codebase reconnaissance. The difference is how many competing drafts, evaluations, and adversarial reviews are performed. Per-stage models come from a configurable [model panel](#model-panel) rather than being fixed; the models above are the defaults.

## Workflows

Acorn covers the full lifecycle from rough idea to running implementation. You can enter at any point.

### Idea to Issue

You have a vague idea — "we need better error handling" or "add dark mode". The `/acorn-issue-craft` skill walks you through a conversational refinement process: it draws out requirements, pushes back on vagueness, structures everything into a JTBD (Jobs to Be Done) template with Job Story, Promise, Constraints, and Acceptance Criteria, then creates the GitHub issue via `acorn issue create`.

```
"I want to add notifications" → /acorn-issue-craft → structured GitHub issue
```

### Issue to Spec

You have a well-defined GitHub issue. `acorn create` fetches it, downloads any images, and runs a multi-agent planning pipeline headlessly in the background that produces `SPEC.md`.

```
acorn create myapp 42 [--lite | --quick]
```

### Spec to Implementation

Acorn's responsibility ends at spec approval (`acorn approve`). The `/acorn-spec-review` skill evaluates the spec across completeness, feasibility, and alignment dimensions, then runs `acorn approve`. Implementation handoff is optional and uses [cashew](https://github.com/andrewxhill/cashew)'s `dev` commands (`dev wt`, `dev <repo>/<branch>/pi`) to create worktrees and dispatch agents — this is cashew's domain, not acorn's.

```
/acorn-spec-review → review → acorn approve → [cashew: dev wt + agent dispatch]
```

### Batch Processing

Multiple issues to process? `/acorn-orchestrate` analyzes dependencies between issues, groups them into parallelizable waves, selects the right pipeline mode for each issue's complexity, and coordinates batch spec generation.

```
/acorn-orchestrate → dependency analysis → wave ordering → parallel spec generation
```

**The pipeline:**

```
GitHub Issue
    |
    v
acorn create <repo> <issue#> [--lite | --quick]
    |-- Fetches issue (title, body, comments)
    |-- Downloads any images from the issue to .specs/<slug>/images/
    |-- Generates a lean PROMPT.md with requirements + discussion
    |   (image URLs rewritten to local paths for agent visibility)
    |-- Sets GitHub label: spec-in-progress
    |-- (Issues created via `acorn issue create` start at `triage`)
    |-- Runs the pipeline headlessly in the background,
    |   logging to .specs/<slug>/pipeline.log
    |
    v
Multi-Agent Planning (mode-dependent; acorn shells out to claude -p / codex exec)
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
| **claude** | Claude Code CLI — runs the planning pipeline (`claude -p`) | See [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) |
| **codex** | Codex CLI — runs `gpt-*` panel entries (soft dependency; falls back to Claude if absent) | See Codex CLI docs, then `codex login` |
| **curl** | Downloads images from GitHub issues | Pre-installed on macOS and most Linux |

On Linux, replace `brew install` with your package manager (e.g., `apt install gh jq`).

### Verify dependencies

```bash
gh --version
jq --version
claude --version
codex --version   # optional; enables real Codex agents in the pipeline
```

### GitHub authentication

Acorn uses `gh` for all GitHub operations. You must be authenticated:

```bash
gh auth login
gh auth status   # confirm you're logged in
```

## Installation

### Easiest: `/acorn-setup` skill

If you already have the repo cloned and Claude Code running, invoke `/acorn-setup` — it handles the binary symlink, global config, commands, skills, and git remote in one go.

### With Cashew (recommended)

If you already have [cashew](https://github.com/andrewxhill/cashew) installed, `dev` is already in place. Just add acorn:

```bash
git clone git@github.com:craigmmills/acorn.git
ln -s "$(pwd)/acorn/bin/acorn" /usr/local/bin/acorn

# Register /acorn command with Claude Code
ln -sf "$(pwd)/acorn/claude/commands/acorn.md" ~/.claude/commands/acorn.md

# Install Claude Code skills
ln -sf "$(pwd)/acorn/.claude/skills/setup" ~/.claude/skills/acorn-setup
ln -sf "$(pwd)/acorn/.claude/skills/orchestrate" ~/.claude/skills/acorn-orchestrate
ln -sf "$(pwd)/acorn/.claude/skills/issue-craft" ~/.claude/skills/acorn-issue-craft
ln -sf "$(pwd)/acorn/.claude/skills/spec-review" ~/.claude/skills/acorn-spec-review

# Append acorn global context to Claude config (idempotent)
if ! grep -q "BEGIN ACORN GLOBAL CONTEXT" ~/.claude/CLAUDE.md 2>/dev/null; then
  { echo ""; echo "<!-- BEGIN ACORN GLOBAL CONTEXT -->"; cat "$(pwd)/acorn/claude/global/CLAUDE.md"; echo "<!-- END ACORN GLOBAL CONTEXT -->"; } >> ~/.claude/CLAUDE.md
fi

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

# Install Claude Code skills
mkdir -p ~/.claude/skills
ln -sf "$(pwd)/acorn/.claude/skills/setup" ~/.claude/skills/acorn-setup
ln -sf "$(pwd)/acorn/.claude/skills/orchestrate" ~/.claude/skills/acorn-orchestrate
ln -sf "$(pwd)/acorn/.claude/skills/issue-craft" ~/.claude/skills/acorn-issue-craft
ln -sf "$(pwd)/acorn/.claude/skills/spec-review" ~/.claude/skills/acorn-spec-review

# Append acorn global context to Claude config (idempotent)
if ! grep -q "BEGIN ACORN GLOBAL CONTEXT" ~/.claude/CLAUDE.md 2>/dev/null; then
  { echo ""; echo "<!-- BEGIN ACORN GLOBAL CONTEXT -->"; cat "$(pwd)/acorn/claude/global/CLAUDE.md"; echo "<!-- END ACORN GLOBAL CONTEXT -->"; } >> ~/.claude/CLAUDE.md
fi
```

### Verify installation

```bash
acorn --help
claude --version
grep "ACORN GLOBAL CONTEXT" ~/.claude/CLAUDE.md
ls -la ~/.claude/skills/acorn-*
```

### Cashew compatibility

Acorn is designed to work alongside cashew's `dev` session manager:

- **Project layout**: Both use `~/Projects/<repo>/main/` (auto-detects `~/Projects` or `~/projects`)
- **Background pipelines**: Acorn runs each spec pipeline as a detached background process (logged to `.specs/<slug>/pipeline.log`), so it doesn't tie up a terminal or a `dev` session
- **No conflicts**: Acorn's `.specs/` directory lives inside `main/` and doesn't interfere with cashew worktrees

## Claude Code Skills

Acorn ships four Claude Code skills that extend its capabilities beyond the CLI:

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `/acorn-setup` | "set up acorn", "install acorn" | Bootstrap the full acorn installation (binary, config, skills, git remote) |
| `/acorn-issue-craft` | "I want to add...", "create an issue for..." | Conversational refinement of rough ideas into structured JTBD issues |
| `/acorn-orchestrate` | "spec the ready-for-spec issues", "batch spec" | Multi-issue pipeline with dependency analysis, wave ordering, and mode selection |
| `/acorn-spec-review` | "review this spec", "approve and implement" | Spec quality review across completeness/feasibility/alignment + implementation handoff |

Skills are installed as symlinks to the repo (see Installation) and are available in any Claude Code session.

## Project Layout Convention

Acorn expects your projects to live at `~/Projects/<repo>/main/` (or `~/projects/<repo>/main/`). This is the directory where `gh` commands run and where `.specs/` directories are created.

```
~/Projects/
  myapp/
    main/              <-- repo checkout (acorn operates here)
      .specs/          <-- created by acorn
        42-add-auth/
          PROMPT.md    <-- lean requirements + discussion for agents to Read
          meta.json    <-- metadata (repo, issue_number, issue_title, slug, created_at, mode)
          pipeline.log <-- background pipeline output (tail -f to follow)
          pipeline.pid <-- pid of the running pipeline (used by status / clean)
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
3. Create `.specs/42-add-authentication/PROMPT.md` with the lean requirements + discussion
4. Create lifecycle labels on the repo if they don't exist
5. Set the issue label to `spec-in-progress`
6. Post a comment on the issue with the spec location
7. Run the planning pipeline headlessly in a detached background process (acorn shells out to `claude -p` and `codex exec` for each stage), logging to `.specs/42-add-authentication/pipeline.log`

`acorn create` returns immediately; the pipeline keeps running in the background. Monitor it anytime:

```bash
# Follow the pipeline log
tail -f ~/Projects/myapp/main/.specs/42-add-authentication/pipeline.log

# Check run-state across all specs
acorn status
```

To prepare the spec (PROMPT.md + labels) without launching the pipeline:

```bash
acorn create myapp 42 --no-run
```

### List all specs

```bash
# List specs across all repos
acorn list

# List specs for a specific repo
acorn list myapp
```

Output shows repo, issue number, slug, status, mode, age, clarification status, and path.

**Status values:**
- Actual lifecycle label from GitHub when present (`triage`, `ready-for-spec`, `spec-in-progress`, `spec-review`, `spec-approved`, `implementing`, `in-review`, `done`)
- Legacy fallback for unlabeled issues:
  - `planning` — PROMPT.md exists, agent is working
  - `review` — plans/SPEC.md exists, ready for human review
  - `unknown` — spec directory exists but state is unclear

### Pipeline dashboard

```bash
# Show pipeline run-state across all repos
acorn status

# Filter to a specific repo
acorn status myapp
```

Output columns:

| Column | Description |
|--------|-------------|
| REPO | Repository name |
| SLUG | Issue slug (e.g., `42-add-authentication`) |
| RUN | Pipeline run-state: `running`, `done`, `failed`, `stopped`, or `idle` (derived from `pipeline.pid` being alive and `PIPELINE_EXIT` in `pipeline.log`) |
| STATUS | Lifecycle status label (or legacy fallback: `planning`/`review`/`unknown`) |
| MODE | Pipeline mode (`full`/`lite`/`quick`) |
| SPEC | Whether `plans/SPEC.md` exists yet |

### Mark a spec as ready for review

After the planning pipeline has produced `plans/SPEC.md`:

```bash
acorn spec-complete myapp 42-add-authentication
```

This sets the GitHub label to `spec-review` and posts a review-ready comment.

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

# Also remove lifecycle + clarification labels from the issue
acorn clean myapp 42-add-authentication --remove-labels --yes

# Force delete even if SPEC.md exists and issue is still open
acorn clean myapp 42-add-authentication --force --yes
```

This stops any in-flight pipeline (it kills the pid recorded in `pipeline.pid`) and deletes the spec directory.

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

### Mark an issue as human-clarified

```bash
acorn issue clarify myapp 42
# Output: Marked issue #42 in myapp as human-clarified and ready-for-spec
```

This swaps the clarification label from `ai-drafted` to `human-clarified` and transitions lifecycle from `triage` to `ready-for-spec` (without regressing issues already further along).

### Manually set lifecycle label

```bash
acorn issue label myapp 42 implementing
acorn issue label myapp 42 in-review
acorn issue label myapp 42 done
```

Use this when work advances outside the spec pipeline and you want labels to reflect actual state.

### Split an issue into sub-issues

```bash
acorn issue split myapp 42
```

Uses AI analysis (Sonnet by default, via the model panel) to evaluate whether an issue should be decomposed into smaller, independently implementable sub-issues. If splitting is recommended:

1. Displays the analysis with rationale and proposed sub-issues
2. Asks for confirmation (or use `--yes` to skip)
3. Creates the sub-issues on GitHub
4. Posts a reference comment on the parent issue linking to the new sub-issues

Options:
- `--yes` — Skip confirmation prompt and create sub-issues automatically
- `--model <model>` — Override the AI model used for analysis (default: `sonnet`). Accepts a model alias (`fable`, `sonnet`, `opus`) or a full model name.

```bash
# Auto-confirm sub-issue creation
acorn issue split myapp 42 --yes

# Use a different model for analysis
acorn issue split myapp 42 --model opus
```

## GitHub Label Lifecycle

Acorn manages these labels automatically (creates them if they don't exist):

| Label | Set By | Meaning |
|-------|--------|---------|
| `triage` | `acorn issue create` | New issue awaiting clarification |
| `ready-for-spec` | `acorn issue clarify` | Clarified and ready for spec work |
| `spec-in-progress` | `acorn create` | Planning pipeline is running |
| `spec-review` | `acorn spec-complete` / `acorn issue label` | Spec is ready for review |
| `spec-approved` | `acorn approve` | Spec approved for implementation |
| `implementing` | `acorn issue label` | Implementation in progress |
| `in-review` | `acorn issue label` | Implementation/PR review in progress |
| `done` | `acorn issue label` | Work complete |

### Clarification Labels

These are orthogonal to lifecycle labels and indicate issue clarification status:

| Label | Set By | Meaning |
|-------|--------|---------|
| `ai-drafted` | `acorn issue create`, `acorn issue plan` | Issue was drafted by AI and needs human clarification |
| `human-clarified` | `acorn issue clarify` | Issue has been reviewed and clarified by a human |

## How the Planning Pipeline Works

The stage plan lives in `bin/acorn` as code, not as prose in `PROMPT.md`. When you run `acorn create`, acorn itself drives each stage headlessly, shelling out to `claude -p` and `codex exec` in parallel and writing artifacts to `recon/*.md` and `plans/*.md`, ending at `plans/SPEC.md`. `PROMPT.md` is kept lean: just the requirements and discussion each agent reads.

### Full Pipeline (default)

6 stages, 14 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Sonnet sub-agents explore the actual codebase from different angles (architecture, relevant code, conventions)
1. **Stage 1 — Diverse Parallel Drafting**: 4 agents each independently draft a complete implementation plan with a distinct architectural lens, spread across vendors and models for genuine diversity (Codex, Opus, Sonnet, Fable per the model panel)
2. **Stage 2 — Rubric-Based Evaluation**: 1 Opus agent scores all 4 drafts against a structured rubric
3. **Stage 3 — Weighted Synthesis**: 1 Opus agent synthesizes a master plan using scored drafts
4. **Stage 4 — Adversarial Red Team**: 4 agents each attack the master plan from a different angle, spread across vendors and models (Codex, Opus, Sonnet, Fable)
5. **Stage 5 — Final Spec**: 1 Fable sub-agent produces `plans/SPEC.md` with traceability matrix and red team resolution log (the final deliverable runs on Anthropic's most capable model)

### Lite Pipeline (`--lite`)

4 stages, 6 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Sonnet sub-agents (same recon as full)
1. **Stage 1 — Comprehensive Draft**: 1 Opus sub-agent drafts a single plan balancing all four architectural lenses
2. **Stage 2 — Combined Validation**: 1 Sonnet sub-agent performs requirements coverage, codebase fact-check, ambiguity audit, and edge case analysis
3. **Stage 3 — Final Spec**: 1 Opus sub-agent incorporates validation findings into `plans/SPEC.md`

### Quick Pipeline (`--quick`)

2 stages, 4 sub-agent launches:

0. **Stage 0 — Codebase Reconnaissance**: 3 Sonnet sub-agents (same recon as full)
1. **Stage 1 — Direct Spec**: 1 Opus sub-agent reads recon + requirements and produces `plans/SPEC.md` directly

### Orchestrator Design

Acorn itself is the orchestrator: `bin/acorn` launches each stage's agents (via `claude -p` / `codex exec`), waits for them, and moves to the next stage. No agent writes the stage plan or coordinates the others; each agent works in its own fresh context and only produces its artifact.

### Model panel

Which model runs each stage is defined by a **panel** (a single table in `bin/acorn`) rather than hardcoded per stage. Defaults: recon uses Sonnet (1M context, capable, mid-cost; recon is bulk codebase scanning, so it doesn't warrant a premium model), synthesis and evaluation use Opus, and drafters and red-team spread across Opus/Sonnet/Fable so competing plans come from genuinely different models. Claude Fable 5 is Anthropic's *most capable* (and most expensive) model, so it is placed on the highest-value reasoning voices: one drafter, one red-teamer, and (in full mode) the **final `SPEC.md`** itself (the deliverable). Lite and quick modes keep their final spec on Opus to stay fast; override with `ACORN_PANEL_lite_spec=fable` if you want the top model there too.

Override any stage with an environment variable named `ACORN_PANEL_<key>`, where `<key>` is the stage key with `:` and `-` replaced by `_`. Examples:

```bash
ACORN_PANEL_full_recon=haiku      acorn create myapp 42     # cheaper recon
ACORN_PANEL_full_draft_dx=opus    acorn create myapp 42     # all-Opus drafters
```

**Model surface.** Claude tiers use their aliases (`fable`, `sonnet`, `opus`, `haiku`) or full names (`claude-fable-5`); these auto-track the latest model in each family. Codex/GPT models (`gpt-5.6-sol`, `gpt-5.3-codex-spark`, or the `spark` alias) route through the Codex CLI as real Codex agents in the pipeline (drafters and red-teamers spread across Codex, Opus, Sonnet, and Fable for genuine cross-vendor diversity).

**Codex is a soft dependency.** The pipeline runs `gpt-*` panel entries as real Codex agents (acorn shells out to `codex exec`), so those stages genuinely run on Codex when the CLI is installed and authenticated (`codex login`). If the codex CLI is absent or unauthed, those entries degrade to a Claude fallback (`ACORN_CODEX_FALLBACK`, default `opus`) with a warning and the pipeline continues. Set `ACORN_STRICT_PANEL=1` to make a missing Codex a hard error instead, or `ACORN_CODEX=0` to force Claude-only.

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
acorn create <repo> <issue-number> [--no-run] [--lite | --quick]
    Create a spec from a GitHub issue and run the planning pipeline headlessly in the background
    --lite    Use lite 4-stage pipeline (6 agents, Sonnet recon)
    --quick   Use quick 2-stage pipeline (4 agents, Sonnet recon)
    --no-run  Prepare the spec (PROMPT.md + labels) without launching the pipeline

acorn list [repo]
    List all specs and their status (optionally filtered by repo)

acorn status [repo]
    Show pipeline dashboard (run-state, mode, and whether SPEC.md exists)

acorn approve <repo> <slug>
    Approve a completed spec for implementation

acorn spec-complete <repo> <slug>
    Mark a completed SPEC.md as ready for review (`spec-review`)

acorn clean <repo> <slug> [--remove-labels] [--yes] [--force]
    Stop any in-flight pipeline and remove the spec directory (refuses if SPEC.md exists and issue is open; use --force to override)

acorn issue create <repo> <title> [options]
    Create a new GitHub issue

acorn issue plan <repo> <title> [options] [--no-run] [--lite | --quick]
    Create a GitHub issue and immediately start spec creation

acorn issue clarify <repo> <issue-number>
    Mark an issue as human-clarified (and move triage -> ready-for-spec when applicable)

acorn issue label <repo> <issue-number> <label>
    Manually set lifecycle label (`triage`, `ready-for-spec`, `spec-in-progress`, `spec-review`, `spec-approved`, `implementing`, `in-review`, `done`)

acorn issue split <repo> <issue-number> [--yes] [--model <model>]
    Analyze an issue and recommend splitting into sub-issues
    --yes       Skip confirmation and create sub-issues automatically
    --model     Override the AI model for analysis (default: sonnet)
```

## Testing

```bash
# Run unit tests (no network calls to GitHub API)
bash test/test_images.sh
bash test/test_labels.sh
bash test/test_split.sh
bash test/test_dependencies.sh
bash test/test_run_agent.sh
bash test/test_pipeline.sh

# Run full suites including integration tests
# (creates temporary GitHub issues, verifies image/label flows, cleans up)
INTEGRATION=1 bash test/test_images.sh
INTEGRATION=1 bash test/test_labels.sh
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

**Pipeline doesn't produce SPEC.md**
Follow the log to see where it stopped: `tail -f ~/Projects/<repo>/main/.specs/<slug>/pipeline.log`. Check run-state with `acorn status`. To re-run from scratch, clean first: `acorn clean <repo> <slug> --force --yes` then re-run create.

**PROMPT.md already exists**
`acorn create` is idempotent — it won't overwrite an existing PROMPT.md. To regenerate, clean first: `acorn clean <repo> <slug> --force --yes` then re-run create.

**Codex entries fell back to Claude**
If the `codex` CLI is missing or unauthenticated, `gpt-*` panel entries degrade to the Claude fallback (`ACORN_CODEX_FALLBACK`, default `opus`) with a warning. Install and authenticate Codex (`codex login`) to run them for real, set `ACORN_STRICT_PANEL=1` to make it a hard error, or `ACORN_CODEX=0` to force Claude-only.
