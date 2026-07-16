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
acorn create <repo> <issue#> --no-run     # Prepare the spec (PROMPT.md + labels) without running the pipeline
acorn list                                 # List all specs across all repos
acorn list <repo> [--deps]                 # List specs for a specific repo (optional dependency counts)
acorn status [repo]                        # Show run dashboard (RUN: running/done/failed/stopped/idle)
acorn approve <repo> <slug>               # Mark spec as approved for implementation
acorn spec-complete <repo> <slug>         # Mark SPEC.md as ready for review
acorn clean <repo> <slug> [--yes] [--force] # Stop pipeline + delete spec (refuses if SPEC.md exists and issue open; --force overrides)
acorn issue create <repo> <title> [--body <text>] [--raw] [--label <name>]... [--assignee <login>]...
acorn issue plan <repo> <title> [options] [--lite | --quick]  # Create issue + immediately start spec generation
acorn issue clarify <repo> <issue#>       # Mark issue as human-clarified (triage -> ready-for-spec)
acorn issue label <repo> <issue#> <label> # Manually set lifecycle label
acorn issue split <repo> <issue#> [--yes] [--model <model>]  # Analyze issue for splitting into sub-issues
acorn issue depends <repo> <issue#> [--blocked-by <issue#>] [--remove-blocked-by <issue#>]
acorn deps graph <repo> <issue#> [<issue#>...]   # Show wave execution order for batch
```

**Issue template format:** When using `acorn issue create` without `--body`/`--body-file`/`--raw`, an interactive template prompts for: Job Story (JTBD), Promise, Constraints, Acceptance Criteria, Context. All sections are optional. When creating issues programmatically, use `--body` with this markdown structure:

```markdown
## Job Story
When [situation], I want to [action], so I can [outcome].

## Promise
After this ships: [guarantee]

## Constraints
[boundaries]

## Acceptance Criteria
- [ ] [condition]

## Context
[additional info]
```

Encourage the user to clarify underspecified Job Story or Promise sections before creating the issue.

**How it works:**
1. `acorn create` fetches the GitHub issue, downloads any images to `.specs/<slug>/images/`, and generates a lean `PROMPT.md` with requirements + discussion (image URLs rewritten to local paths so agents can view them via the Read tool). The stage plan is code, not prose.
2. acorn drives the pipeline itself, headlessly: it shells out to `claude -p` and `codex exec` in parallel for each stage (no tmux, no interactive Claude, no Task tool). It runs detached in the background, logging to `.specs/<slug>/pipeline.log`.
3. The pipeline stages (mode-dependent):
   - **Full**: 3 recon → 4 drafts → 1 evaluation → 1 synthesis → 4 red team → 1 final spec
   - **Lite**: 3 recon → 1 draft → 1 validation → 1 final spec
   - **Quick**: 3 recon → 1 direct spec
   - Per-stage models come from a configurable panel: recon → Sonnet, synthesis → Opus, full-mode final SPEC.md → Fable, drafters/red-team spread across Codex/Opus/Sonnet/Fable (Fable 5 is Anthropic's most capable model, reserved for the highest-value reasoning voices and the final deliverable). `gpt-*` entries run as real Codex agents; if the codex CLI is absent they degrade to a Claude fallback with a warning. Override any stage with `ACORN_PANEL_<key>`.
4. Output lands in `.specs/<slug>/plans/SPEC.md`. Monitor via `acorn status` (RUN column) or `tail -f .specs/<slug>/pipeline.log`.

**Spec directory layout:**
```
~/Projects/<repo>/main/.specs/<slug>/
  PROMPT.md          # Lean requirements + discussion (agents Read this)
  pipeline.log       # Headless pipeline output; ends with PIPELINE_EXIT=<code>
  meta.json          # Metadata (repo, issue, slug, created_at, mode)
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

**Status values:** Actual lifecycle label from GitHub (for example: `triage`, `spec-in-progress`, `implementing`, `done`). Fallback for unlabeled legacy issues: `planning`, `review`, `unknown`.

**Label lifecycle:** `triage` → `ready-for-spec` → `spec-in-progress` → `spec-review` → `spec-approved` → `implementing` → `in-review` → `done`

**Clarification labels:** `ai-drafted` → `human-clarified` (orthogonal to spec lifecycle)

**Execution:** `acorn create` runs the pipeline headlessly in the background (a detached process, pid recorded in `.specs/<slug>/pipeline.pid`). `acorn status` shows the RUN state (running/done/failed/stopped/idle) from the pid file + log. `acorn clean` stops an in-flight run before deleting the spec. Mode is stored in `meta.json` and shown in `acorn list`.

For full command reference, use the `/acorn` command.
