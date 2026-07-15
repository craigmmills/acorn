# Acorn — GitHub Issue to Implementation Spec

Turns GitHub issues into agent-ready implementation specs via a multi-agent planning pipeline with 3 speed modes.

## Quick Reference

```bash
acorn create <repo> <issue-number> [--no-auto] [--lite | --quick]  # Create spec from issue, start planning
acorn list [repo] [--deps]                                           # List all specs and their status (optional dependency counts)
acorn status [repo]                                                  # Show session dashboard
acorn approve <repo> <slug>                                          # Approve a completed spec
acorn spec-complete <repo> <slug>                                    # Mark SPEC.md as ready for review
acorn clean <repo> <slug> [--remove-labels] [--yes] [--force]        # Remove spec + kill session
acorn issue create <repo> <title> [options]                          # Create a GitHub issue (interactive template)
acorn issue plan <repo> <title> [options] [--lite | --quick]         # Create issue + start spec immediately
acorn issue clarify <repo> <issue-number>                            # Swap ai-drafted -> human-clarified, triage -> ready-for-spec
acorn issue label <repo> <issue-number> <label>                      # Manually set lifecycle label
acorn issue split <repo> <issue-number> [--yes] [--model <model>]    # Analyze issue and optionally create sub-issues
acorn issue depends <repo> <issue#> [--blocked-by <issue#>[,<issue#>...]] [--remove-blocked-by <issue#>[,<issue#>...]]
acorn deps graph <repo> <issue#> [<issue#>...]                        # Build wave execution plan from dependency graph
```

## Pipeline Modes

| Mode | Flag | Stages | Agents | Recon | Planning | Best For |
|------|------|--------|--------|-------|----------|----------|
| Full | _(default)_ | 6 | 14 | Opus | Opus | Complex features |
| Lite | `--lite` | 4 | 6 | Sonnet | Opus | Standard features |
| Quick | `--quick` | 2 | 4 | Sonnet | Opus | Simple features |

## Workflow

1. **Start spec**: `acorn create <repo> <issue#> [--lite | --quick]` — fetches the issue, generates PROMPT.md, launches Claude Code in a detached tmux session, and auto-triggers the planning pipeline.
2. **Monitor**: `tmux attach -t <session>` to watch progress.
3. **Mark ready for review**: `acorn spec-complete <repo> <slug>` — sets `spec-review` after `plans/SPEC.md` is ready.
4. **Review/Approve**: Review `plans/SPEC.md`, then run `acorn approve <repo> <slug>` to set `spec-approved`.
5. **Clean up**: `acorn clean <repo> <slug> --yes` — kills session and removes spec directory. **Safety:** refuses to delete if SPEC.md exists and the issue is still open (use `--force` to override).

## Options for create / issue plan

- `--lite` — Use lite 4-stage pipeline (6 agents, Sonnet recon + Opus planning)
- `--quick` — Use quick 2-stage pipeline (4 agents, Sonnet recon + Opus direct spec)
- `--no-auto` — Don't auto-trigger the planning pipeline
- `--headless` — Run the pipeline in-process (no tmux, no Task tool). acorn fans out the stages itself, routing `gpt-*` panel entries to real Codex agents (which the session/Task flow can't launch). Runs in the foreground until the spec lands. Currently supports `--quick` only.

## Options for issue create/plan

- `--body <text>` — Issue body text (bypasses interactive template)
- `--body-file <path>` — Read body from a file (bypasses interactive template)
- `--raw` — Skip the interactive template prompt
- `--label <name>` — Add a label (repeatable)
- `--assignee <login>` — Assign a user (repeatable)
- `--blocked-by <issue#>[,<issue#>...]` — Add blocked-by dependencies after issue creation

### Structured issue template

When `--body`, `--body-file`, and `--raw` are all absent, `acorn issue create` enters interactive mode and prompts for five optional sections:

1. **Job Story** — JTBD format: "When [situation], I want to [action], so I can [outcome]"
2. **Promise** — "After this ships: [specific user-facing guarantee]"
3. **Constraints** — What must not change, what's out of scope
4. **Acceptance Criteria** — Specific, testable conditions that prove the promise is met
5. **Context** — Examples, screenshots, links, prior art (optional)

All sections are optional — press Enter to skip. If all sections are skipped, the issue is created with no body.

When creating issues from Claude Code, fill in these sections programmatically via `--body`:

```bash
acorn issue create repo "Title" --body "## Job Story

When [situation], I want to [action], so I can [outcome].

## Promise

After this ships: [guarantee]

## Constraints

[boundaries]

## Acceptance Criteria

- [ ] [condition]

## Context

[additional info]"
```

Ask the user for clarification when Job Story or Promise sections feel underspecified.

## `acorn issue clarify <repo> <issue-number>`

Swaps `ai-drafted` to `human-clarified` and transitions lifecycle `triage` → `ready-for-spec` when the issue is still at triage (or unlabeled). If already beyond triage, lifecycle is left unchanged.

## `acorn issue label <repo> <issue-number> <label>`

Manual lifecycle override for any valid lifecycle label:
`triage`, `ready-for-spec`, `spec-in-progress`, `spec-review`, `spec-approved`, `implementing`, `in-review`, `done`.

## `acorn issue split <repo> <issue-number> [--yes] [--model <model>]`

Analyzes an existing GitHub issue and recommends whether it should be split into smaller sub-issues.

**Options:**
- `--yes` — Auto-accept split recommendations and skip confirmation prompt
- `--model <model>` — Override the analysis model (default: `sonnet`; accepts `fable`/`sonnet`/`opus` or a full model name)

**Flow:**
1. Fetch issue title/body/comments from GitHub
2. Send content to Claude (`claude -p`) for one-shot split analysis
3. Display recommendation, reasoning, and proposed sub-issues (title + scope)
4. If split is recommended, ask for confirmation (unless `--yes`)
5. On acceptance, create sub-issues and post a summary comment on the parent

If no split is recommended (or recommendation is invalid with fewer than 2 sub-issues), acorn leaves the original issue unchanged and prints next-step guidance to run `acorn create`.

## Dependency Management

### View dependencies
```bash
acorn issue depends <repo> <issue#>
```

### Add blocked-by relationships
```bash
acorn issue depends <repo> <issue#> --blocked-by <issue#>[,<issue#>...]
```

### Remove blocked-by relationships
```bash
acorn issue depends <repo> <issue#> --remove-blocked-by <issue#>[,<issue#>...]
```

### Create issue with dependencies
```bash
acorn issue create <repo> "title" --blocked-by 5,12
acorn issue plan <repo> "title" --blocked-by 5,12
```

### View wave execution order
```bash
acorn deps graph <repo> <issue#> [<issue#>...]
```

### List with dependency info
```bash
acorn list [repo] --deps
```

## Spec status values

| Status | Meaning |
|--------|---------|
| lifecycle label | Actual GitHub lifecycle label (`triage`, `ready-for-spec`, `spec-in-progress`, `spec-review`, `spec-approved`, `implementing`, `in-review`, `done`) |
| `planning` | Legacy fallback: PROMPT.md exists and no lifecycle label found |
| `review` | Legacy fallback: plans/SPEC.md exists and no lifecycle label found |
| `unknown` | Legacy fallback: no lifecycle label + no local state signal |

## Session dashboard

`acorn status [repo]` shows a live dashboard of all spec sessions:

| Column | Shows |
|--------|-------|
| REPO | Repository name |
| SLUG | Spec slug (truncated to 40 chars) |
| SESSION | `running` / `dead` / `no-session` |
| BACKEND | Session backend from meta.json (always `tmux`) |
| STATUS | Lifecycle label (or legacy fallback `planning` / `review` / `unknown`) |
| ATTACH | `tmux attach -t <session>` command (if running) |

## Pipeline stages by mode

**Full (default):**

| Stage | Agents | Purpose |
|-------|--------|---------|
| 0. Recon | 3 parallel (Opus) | Explore codebase: architecture, relevant code, conventions |
| 1. Draft | 4 parallel (Opus) | Independent plans with distinct lenses (Minimal, Clean, Robust, DX) |
| 2. Evaluate | 1 (Opus) | Score all drafts against structured rubric |
| 3. Synthesize | 1 (Opus) | Merge best ideas using evaluation scores |
| 4. Red Team | 4 parallel (Opus) | Adversarial attack: requirements audit, ambiguity, codebase validation, edge cases |
| 5. Final Spec | 1 (Opus) | Produce SPEC.md with traceability matrix and red team resolution log |

**Lite (`--lite`):**

| Stage | Agents | Purpose |
|-------|--------|---------|
| 0. Recon | 3 parallel (Sonnet) | Explore codebase: architecture, relevant code, conventions |
| 1. Draft | 1 (Opus) | Single comprehensive plan balancing all 4 lenses |
| 2. Validate | 1 (Opus) | Combined requirements-coverage + codebase-fact-check + ambiguity-audit + edge-cases |
| 3. Final Spec | 1 (Opus) | Produce SPEC.md with validation resolution log |

**Quick (`--quick`):**

| Stage | Agents | Purpose |
|-------|--------|---------|
| 0. Recon | 3 parallel (Sonnet) | Explore codebase: architecture, relevant code, conventions |
| 1. Direct Spec | 1 (Opus) | Read recon + requirements → produce SPEC.md directly |

## Project layout

Specs are created at `~/Projects/<repo>/main/.specs/<issue#>-<slug>/`:
```
.specs/<slug>/
  PROMPT.md              # Generated requirements + planning methodology
  meta.json              # Metadata (repo, issue, session info, mode)
  images/                # Downloaded images from the GitHub issue
    <hash>.png             (auto-downloaded, URLs rewritten in PROMPT.md)
  recon/                         Full  Lite  Quick
    architecture.md               Y     Y     Y
    relevant_code.md              Y     Y     Y
    conventions.md                Y     Y     Y
  plans/
    draft_plan_1..4.md            Y     -     -
    draft.md                      -     Y     -
    evaluation.md                 Y     -     -
    master_plan.md                Y     -     -
    validation.md                 -     Y     -
    red_team_1..4.md              Y     -     -
    SPEC.md                       Y     Y     Y
```

## Image handling

Issues with screenshots, mockups, or diagrams are automatically handled:
- Images are downloaded to `images/` and URLs in PROMPT.md are rewritten to local paths
- Planning agents can view images via the Read tool (Claude Code supports PNG, JPG, etc.)
- The Architecture recon agent (Stage 0) is instructed to examine images when present
- Failed downloads are graceful — original URLs are preserved in PROMPT.md

## GitHub label lifecycle

| Label | Set By | Meaning |
|-------|--------|---------|
| `triage` | `acorn issue create` | New issue awaiting clarification |
| `ready-for-spec` | `acorn issue clarify` | Clarified and ready for spec creation |
| `spec-in-progress` | `acorn create` | Planning pipeline is running |
| `spec-review` | `acorn spec-complete` / `acorn issue label` | Spec is ready for review |
| `spec-approved` | `acorn approve` | Spec approved for implementation |
| `implementing` | `acorn issue label` | Implementation in progress |
| `in-review` | `acorn issue label` | Implementation/PR review in progress |
| `done` | `acorn issue label` | Work complete |
| `ai-drafted` | `acorn issue create`, `acorn issue plan` | Issue drafted by AI |
| `human-clarified` | `acorn issue clarify` | Issue clarified by a human |

## Dependencies

Requires: `gh` (authenticated), `jq`, `tmux`, `claude` (Claude Code CLI).
