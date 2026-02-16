## Acorn — Issue-to-Spec Pipeline

Acorn turns GitHub issues into agent-ready implementation specs via a multi-agent planning pipeline with 3 speed modes.

**When to use:** Whenever you need to plan a feature, break down an issue, or generate an implementation spec before coding.

**Pipeline modes:**
| Mode | Flag | Stages | Agents | Best For |
|------|------|--------|--------|----------|
| Full | _(default)_ | 6 | 14 | Complex features, architectural decisions |
| Lite | `--lite` | 4 | 6 | Standard features, moderate complexity |
| Quick | `--quick` | 2 | 4 | Simple features, time-sensitive changes |

**Common commands:**
```bash
acorn create <repo> <issue#>              # Full pipeline (default)
acorn create <repo> <issue#> --lite       # Lite pipeline (4 stages, 6 agents)
acorn create <repo> <issue#> --quick      # Quick pipeline (2 stages, 4 agents)
acorn create <repo> <issue#> --no-auto    # Don't auto-trigger planning
acorn list                                 # List all specs across all repos
acorn list <repo>                          # List specs for a specific repo
acorn status [repo]                        # Show session dashboard (running/dead/no-session)
acorn approve <repo> <slug>               # Mark spec as approved for implementation
acorn clean <repo> <slug> [--yes]         # Kill session + delete spec directory
acorn issue create <repo> <title> [--body <text>] [--label <name>]... [--assignee <login>]...
acorn issue plan <repo> <title> [options] [--lite | --quick]  # Create issue + immediately start spec generation
```

**How it works:**
1. `acorn create` fetches the GitHub issue, downloads any images to `.specs/<slug>/images/`, and generates a `PROMPT.md` with requirements + mode-specific planning methodology (image URLs rewritten to local paths so agents can view them via the Read tool)
2. A detached Claude Code session launches in tmux and auto-triggers planning
3. The orchestrator agent runs the pipeline (mode-dependent):
   - **Full**: 3 recon → 4 drafts → 1 evaluation → 1 synthesis → 4 red team → 1 final spec
   - **Lite**: 3 recon (Sonnet) → 1 draft → 1 validation → 1 final spec
   - **Quick**: 3 recon (Sonnet) → 1 direct spec
4. Output lands in `.specs/<slug>/plans/SPEC.md`

**Spec directory layout:**
```
~/Projects/<repo>/main/.specs/<slug>/
  PROMPT.md          # Generated requirements + planning methodology
  meta.json          # Metadata (repo, issue, session info)
  images/            # Downloaded images from GitHub issue (auto-extracted)
    <hash>.png         (URLs rewritten in PROMPT.md to local paths)
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

**Session management:** Creates tmux sessions named `<repo>_specs_<slug>_claude` running Claude Code. Mode is stored in `meta.json` and shown in `acorn list`.

For full command reference, use the `/acorn` command.
