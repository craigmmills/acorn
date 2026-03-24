---
name: acorn-orchestrate
description: >
  Multi-issue pipeline orchestrator that analyzes dependencies between GitHub issues,
  groups them into parallelizable waves, selects the right acorn pipeline mode (full/lite/quick)
  for each issue's complexity, and coordinates batch spec generation followed by optional
  implementation handoff. This skill contains the complete methodology for dependency analysis,
  wave ordering, mode selection heuristics, progress monitoring, and review checkpoints — none
  of which you can replicate without it. You MUST use this skill whenever the user mentions
  processing, speccing, or planning MORE THAN ONE issue at a time — whether by label
  ("spec the ready-for-spec issues"), by explicit list ("run acorn on issues 42, 45, 51"),
  by milestone ("process the v2.0 issues"), or by backlog ("process the backlog"). Also use
  it when the user says "plan the next sprint", "batch spec", "spec and implement all of these",
  or refers to any multi-issue acorn workflow. Even if they just mention a GitHub label in the
  context of planning work, this is the right skill. Do NOT use for single-issue acorn commands.
---

# Acorn Orchestrate — Batch Spec & Implementation Pipeline

You are orchestrating a batch of GitHub issues through acorn's spec pipeline and optionally into implementation. Your job is to analyze issues, determine the right order and pipeline mode for each, run them efficiently, and keep the user informed throughout.

The user's global CLAUDE.md already has full acorn command reference and dev session manager docs. This skill focuses on the **orchestration logic** — the decisions and coordination that turn a pile of issues into an ordered, dependency-aware pipeline.

## How This Gets Invoked

The user will typically say something like:
- "Spec all the ready-for-spec issues in replay"
- "Process the backlog for candles"
- "Spec and implement issues labeled ready-for-spec in replay"
- "Run acorn on issues 42, 45, and 51 in myrepo"

They may also specify upfront whether they want **spec-only** or **spec + implementation**. If they don't say, ask once at the start — it affects how you plan the pipeline.

## Step 1: Discover Issues

Determine the source of issues based on what the user said:

**Label-based (most common):**
```bash
gh issue list -R <owner>/<repo> -l "<label>" --state open --json number,title,body,labels,comments
```

**Explicit issue numbers:**
The user provides specific numbers. Fetch each one:
```bash
gh issue view <number> -R <owner>/<repo> --json number,title,body,labels,comments
```

**If no issues are found**, tell the user and stop. Don't guess or suggest creating issues — that's a separate workflow.

**Skip issues that already have specs in progress.** Check `acorn list <repo>` first — if an issue already has a spec with status `planning` or `review`, mention it to the user and exclude it from the batch unless they explicitly ask to re-spec it (which means cleaning and re-creating).

## Step 2: Analyze Dependencies & Determine Order

This is the critical step. You need to figure out which issues depend on which, so specs run in the right order — an issue's recon step should see the codebase as it will exist after its dependencies are implemented.

### Check explicit dependencies first
Use acorn's dependency management to query GitHub's blocked-by/blocking relationships:

```bash
# Check each issue for existing dependencies
acorn issue depends <repo> <issue#>
```

Also scan issue bodies and comments for dependency signals:
- "depends on #X", "blocked by #X", "after #X", "requires #X"
- "blocks #Y", "prerequisite for #Y"
- GitHub's own linked issues

If you discover dependencies that aren't tracked yet, add them:
```bash
acorn issue depends <repo> <issue#> --blocked-by <other_issue#>
```

### Then analyze for implicit dependencies
Read all the issue bodies and think about what each issue touches in the codebase:
- Do two issues modify the same files or modules?
- Does one issue create an API/schema/component that another consumes?
- Does one issue change infrastructure (DB schema, auth, routing) that others build on?

Build a dependency graph. If there are cycles, flag them to the user — cycles usually mean the issues need to be restructured.

### Generate the wave execution plan
Use `acorn deps graph` to compute wave ordering from the dependency graph:

```bash
acorn deps graph <repo> <issue#> [<issue#>...]
```

This outputs issues grouped into parallelizable waves based on their blocked-by relationships. If you need to adjust, you can also construct waves manually.

### Present as an ordered execution plan
Group issues into **waves** — each wave contains issues that can run in parallel (no dependencies between them), and waves execute sequentially:

```
Wave 1 (parallel):
  #42 - Add user authentication (full) — foundational, other issues depend on auth
  #48 - Update CI pipeline (quick) — independent infrastructure

Wave 2 (parallel, after wave 1):
  #45 - Add user profile page (lite) — depends on #42 auth
  #47 - Add admin dashboard (lite) — depends on #42 auth

Wave 3 (sequential, after wave 2):
  #51 - Add user settings (lite) — depends on #45 profile page
```

## Step 3: Select Pipeline Mode Per Issue

Assess each issue and assign a pipeline mode. The goal is to match effort to complexity — don't burn 14 Opus agents on a config change, but don't shortchange an architectural overhaul with a quick spec.

**Use `full` (6 stages, 14 agents) when:**
- The issue involves significant architectural decisions or new patterns
- Multiple subsystems are affected and need to coordinate
- There are non-obvious edge cases or security implications
- The issue is vague or underspecified — the extra draft diversity helps explore the solution space
- You'd describe it as "big and hairy"

**Use `lite` (4 stages, 6 agents) when:**
- The scope is clear but non-trivial — a solid feature with known boundaries
- It touches 3-8 files across a couple of modules
- The approach is relatively straightforward but benefits from validation
- This is the default for "normal" feature work

**Use `quick` (2 stages, 4 agents) when:**
- The change is small and well-defined (config changes, simple CRUD, small UI tweaks)
- The implementation path is obvious to anyone familiar with the codebase
- It touches 1-3 files
- Time sensitivity outweighs thoroughness

When in doubt, lean toward `lite` — it's the sweet spot between speed and rigor.

## Step 4: Present the Plan

Before executing anything, show the user the full plan:

1. The wave-ordered list with mode assignments and reasoning
2. Whether this is spec-only or spec + implementation
3. Estimated parallel sessions (how many specs will run concurrently)
4. Any concerns (cycles, underspecified issues, issues that might need splitting)

Wait for the user to confirm or adjust. They might want to change a mode, reorder things, or drop an issue.

## Step 5: Execute the Pipeline

Run each wave using acorn:

```bash
# For each issue in the current wave, kick off in parallel:
acorn create <repo> <issue#>              # full mode
acorn create <repo> <issue#> --lite       # lite mode
acorn create <repo> <issue#> --quick      # quick mode
```

After launching a wave, move to monitoring.

## Step 6: Monitor Progress

Use `acorn status <repo>` to check on running sessions. Report progress to the user periodically:

```bash
acorn status <repo>
```

For more detail on a specific session, check what's been produced:
```bash
# Check if recon is done
ls ~/Projects/<repo>/main/.specs/<slug>/recon/

# Check if SPEC.md has landed
ls ~/Projects/<repo>/main/.specs/<slug>/plans/SPEC.md
```

When a session's status shows `review`, that spec is ready. When all specs in a wave are done, report the wave as complete and start the next wave.

If a session dies or gets stuck, tell the user and suggest options:
- Re-run with `acorn clean <repo> <slug> --yes && acorn create <repo> <issue#> [--mode]`
- Attach to debug: `tmux attach -t <session-name>`

## Step 7: Review Checkpoint

When all specs are complete, present a summary:

```
All specs complete:
  #42 - Add user authentication    → SPEC.md ready (full mode)
  #45 - Add user profile page      → SPEC.md ready (lite mode)
  #47 - Add admin dashboard        → SPEC.md ready (lite mode)
  #48 - Update CI pipeline         → SPEC.md ready (quick mode)
  #51 - Add user settings          → SPEC.md ready (lite mode)
```

If the user chose spec-only, you're done. Remind them they can review with `acorn approve <repo> <slug>` when ready.

## Step 8: Implementation Handoff (if requested)

If the user opted for spec + implementation, coordinate worktree creation and agent dispatch in dependency order using the same wave structure.

### For each wave:

1. **Approve the specs** in the current wave: `acorn approve <repo> <slug>` for each
2. **Create worktrees** for each issue in the wave: `dev wt <repo> <feature-branch>`
3. **Start agent sessions** in each worktree: `dev <repo>/<feature-branch>/pi`
4. **Send the spec to each agent.** The SPEC.md lives in the main worktree at `~/Projects/<repo>/main/.specs/<slug>/plans/SPEC.md`. Instruct each agent to read it and implement accordingly.

Independent implementations within a wave can run concurrently. Before starting the next wave, the user (or main orchestrator) needs to:
- Review and merge completed implementations into main
- Clean up finished worktrees: `dev cleanup <repo>/<feature-branch>`

This ensures each new wave's agents see the updated codebase with prior wave changes already merged.

### Checking agent progress
Before nudging or checking on a worktree agent, always read its status first:
```bash
dev pi-status <repo>/<feature-branch> --messages 1
```

## Important Principles

**Don't over-automate.** Present the plan, get confirmation, then execute. The user wants to stay in control of the big picture — your job is to do the analysis and coordination work so they don't have to think about ordering and mode selection.

**Dependency ordering matters more than speed.** It's tempting to parallelize everything, but a spec whose recon step examines stale code produces a worse spec. Get the ordering right even if it means some issues wait.

**Surface problems early.** If an issue looks too big (might need splitting), too vague (missing acceptance criteria), or conflicts with another issue, say so before you start running specs. It's cheaper to fix an issue than to re-spec it.

**Keep the user oriented.** With multiple specs running across multiple sessions, it's easy to lose track. Proactively report status — don't wait to be asked.

**Suggest splitting when appropriate.** If an issue looks like it's doing too much (multiple unrelated changes, or a scope that would benefit from being broken into independently shippable pieces), suggest running `acorn issue split <repo> <issue#>` before speccing it. It's better to split early than to get a bloated spec that tries to do everything at once.
