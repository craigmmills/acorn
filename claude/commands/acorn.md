# Acorn — GitHub Issue to Implementation Spec

Turns GitHub issues into agent-ready implementation specs via a 5-stage multi-agent planning pipeline (20 sub-agents).

## Quick Reference

```bash
acorn create <repo> <issue-number> [--no-auto]    # Create spec from issue, start planning
acorn list [repo]                                   # List all specs and their status
acorn approve <repo> <slug>                         # Approve a completed spec
acorn clean <repo> <slug> [--remove-labels] [--yes] # Remove spec + kill session
acorn issue create <repo> <title> [options]         # Create a GitHub issue
acorn issue plan <repo> <title> [options]           # Create issue + start spec immediately
```

## Workflow

1. **Start spec**: `acorn create <repo> <issue#>` — fetches the issue, generates PROMPT.md, launches a pi agent in a detached tmux session, and auto-triggers the 5-stage planning pipeline.
2. **Monitor**: Use `dev pi-status <session>` or `tmux attach -t <session>` to watch progress.
3. **Review**: When status shows `review`, read `plans/SPEC.md` in the spec directory.
4. **Approve**: `acorn approve <repo> <slug>` — sets the `spec-approved` label on the issue.
5. **Clean up**: `acorn clean <repo> <slug> --yes` — kills session and removes spec directory.

## Options for issue create/plan

- `--body <text>` — Issue body text
- `--body-file <path>` — Read body from a file
- `--label <name>` — Add a label (repeatable)
- `--assignee <login>` — Assign a user (repeatable)
- `--no-auto` — Don't auto-trigger the planning pipeline

## Spec status values

| Status | Meaning |
|--------|---------|
| `planning` | PROMPT.md exists, agent is working |
| `review` | plans/SPEC.md exists, ready for human review |
| `approved` | Spec has been approved for implementation |

## Project layout

Specs are created at `~/Projects/<repo>/main/.specs/<issue#>-<slug>/`:
```
.specs/<slug>/
  PROMPT.md           # Generated requirements + planning methodology
  meta.json           # Metadata (repo, issue, session info)
  plans/
    draft_plan_1..6.md   # Stage 1: independent drafts
    critique_1..6.md     # Stage 2: critiques
    master_plan_draft.md # Stage 3: synthesis
    simulation_1..6.md   # Stage 4: dry-run simulations
    SPEC.md              # Stage 5: final implementation spec
```

## GitHub label lifecycle

| Label | Set By | Meaning |
|-------|--------|---------|
| `spec-in-progress` | `acorn create` | Planning pipeline is running |
| `spec-approved` | `acorn approve` | Spec approved for implementation |

## Dependencies

Requires: `gh` (authenticated), `jq`, `tmux`, `pi` (with message-queue extension).
