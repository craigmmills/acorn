## Acorn — Issue-to-Spec Pipeline

Acorn turns GitHub issues into agent-ready implementation specs via a 5-stage, 13-agent planning pipeline.

**When to use:** Whenever you need to plan a feature, break down an issue, or generate an implementation spec before coding.

**Common commands:**
```bash
acorn create <repo> <issue#>           # Fetch issue, generate PROMPT.md, start planning session
acorn create <repo> <issue#> --no-auto # Same but don't auto-trigger planning
acorn list                              # List all specs across all repos
acorn list <repo>                       # List specs for a specific repo
acorn approve <repo> <slug>            # Mark spec as approved for implementation
acorn clean <repo> <slug> [--yes]      # Kill session + delete spec directory
acorn issue create <repo> <title> [--body <text>] [--label <name>]... [--assignee <login>]...
acorn issue plan <repo> <title> [options]  # Create issue + immediately start spec generation
```

**How it works:**
1. `acorn create` fetches the GitHub issue, generates a `PROMPT.md` with requirements + planning methodology
2. A detached Claude Code session launches in tmux and auto-triggers planning
3. The orchestrator agent runs 5 stages:
   - Stage 0: 3 parallel codebase recon agents (architecture, relevant code, conventions)
   - Stage 1: 4 parallel drafts with distinct lenses (Minimal Surgery, Clean Architecture, Robustness-First, Developer Experience)
   - Stage 2: 1 rubric-based evaluator scores all drafts
   - Stage 3: 1 synthesizer creates master plan using scored drafts
   - Stage 4: 4 parallel adversarial red team agents (requirements audit, ambiguity hunting, codebase validation, contradiction/edge case finding)
   - Stage 5: 1 final spec with requirements traceability matrix
4. Output lands in `.specs/<slug>/plans/SPEC.md`

**Spec directory layout:**
```
~/Projects/<repo>/main/.specs/<slug>/
  PROMPT.md          # Generated requirements + planning methodology
  meta.json          # Metadata (repo, issue, session info)
  recon/
    architecture.md    # Stage 0: project structure & tech stack
    relevant_code.md   # Stage 0: relevant files & APIs
    conventions.md     # Stage 0: coding patterns & constraints
  plans/
    draft_plan_1..4.md   # Stage 1: diverse drafts
    evaluation.md        # Stage 2: rubric scores
    master_plan.md       # Stage 3: synthesis
    red_team_1..4.md     # Stage 4: adversarial findings
    SPEC.md              # Stage 5: final implementation spec
```

**Status values:** `planning` (agent working), `review` (SPEC.md ready), `approved` (greenlit for implementation), `unknown`

**Label lifecycle:** `ready-for-spec` → `spec-in-progress` → `spec-review` → `spec-approved`

**Session management:** Creates tmux sessions named `<repo>_specs_<slug>_claude` running Claude Code.

For full command reference, use the `/acorn` command.
