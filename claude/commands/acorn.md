# Acorn — GitHub Issue to Implementation Spec

Turns GitHub issues into agent-ready implementation specs via a multi-agent planning pipeline with 3 speed modes.

## Quick Reference

```bash
acorn create <repo> <issue-number> [--no-auto] [--lite | --quick]  # Create spec from issue, start planning
acorn list [repo]                                                    # List all specs and their status
acorn approve <repo> <slug>                                          # Approve a completed spec
acorn clean <repo> <slug> [--remove-labels] [--yes]                  # Remove spec + kill session
acorn issue create <repo> <title> [options]                          # Create a GitHub issue
acorn issue plan <repo> <title> [options] [--lite | --quick]         # Create issue + start spec immediately
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
3. **Review**: When status shows `review`, read `plans/SPEC.md` in the spec directory.
4. **Approve**: `acorn approve <repo> <slug>` — sets the `spec-approved` label on the issue.
5. **Clean up**: `acorn clean <repo> <slug> --yes` — kills session and removes spec directory.

## Options for create / issue plan

- `--lite` — Use lite 4-stage pipeline (6 agents, Sonnet recon + Opus planning)
- `--quick` — Use quick 2-stage pipeline (4 agents, Sonnet recon + Opus direct spec)
- `--no-auto` — Don't auto-trigger the planning pipeline

## Options for issue create/plan

- `--body <text>` — Issue body text
- `--body-file <path>` — Read body from a file
- `--label <name>` — Add a label (repeatable)
- `--assignee <login>` — Assign a user (repeatable)

## Spec status values

| Status | Meaning |
|--------|---------|
| `planning` | PROMPT.md exists, agent is working |
| `review` | plans/SPEC.md exists, ready for human review |
| `approved` | Spec has been approved for implementation |

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

## GitHub label lifecycle

| Label | Set By | Meaning |
|-------|--------|---------|
| `spec-in-progress` | `acorn create` | Planning pipeline is running |
| `spec-approved` | `acorn approve` | Spec approved for implementation |

## Dependencies

Requires: `gh` (authenticated), `jq`, `tmux`, `claude` (Claude Code CLI).
