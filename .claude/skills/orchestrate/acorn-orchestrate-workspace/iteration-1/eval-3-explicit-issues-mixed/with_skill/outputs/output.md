# Acorn Orchestrate — Dry Run Output

## Task

Run acorn on issues #12, #15, and #23 in `replay`. Spec only.

- Issue #12: Big auth overhaul
- Issue #15: Adding a config option
- Issue #23: New API endpoint

## Workflow Selection

The user explicitly said "spec only," so no implementation handoff is needed. The pipeline ends after Step 7 (Review Checkpoint).

---

## Step 1: Discover Issues

Since the user provided explicit issue numbers, I would fetch each one individually.

### Check for existing specs first

```bash
acorn list replay
```

This tells me if any of #12, #15, or #23 already have specs in `planning` or `review` status. If so, I would report those to the user and exclude them from the batch unless they explicitly ask to re-spec (which requires `acorn clean` first).

### Fetch each issue

```bash
gh issue view 12 -R craigmills/replay --json number,title,body,labels,comments
gh issue view 15 -R craigmills/replay --json number,title,body,labels,comments
gh issue view 23 -R craigmills/replay --json number,title,body,labels,comments
```

All three commands would run in parallel since they are independent. The output gives me the full issue body, labels, and comment thread for each, which I need for dependency analysis.

**If any issue is not found** (e.g., wrong repo, closed, etc.), I would report that to the user and proceed with the remaining issues.

---

## Step 2: Analyze Dependencies & Determine Order

### Explicit dependency scan

I would scan all three issue bodies and their comments for dependency signals:
- "depends on #X", "blocked by #X", "after #X", "requires #X"
- "blocks #Y", "prerequisite for #Y"
- GitHub linked issues

### Implicit dependency analysis

Based on the user's descriptions:

- **Issue #12 (auth overhaul)**: This is foundational infrastructure. Auth changes typically affect middleware, session management, user models, and route guards. Any endpoint or feature that relies on authentication would be affected. A "big auth overhaul" suggests changes to how the entire app handles identity, permissions, or session tokens.

- **Issue #15 (config option)**: Adding a config option is typically self-contained. It touches configuration files, possibly a settings UI, and the code that reads the config. Unless this config option relates to auth (e.g., configuring an auth provider), it is likely independent.

- **Issue #23 (new API endpoint)**: A new API endpoint often depends on auth (for route protection, permission checks, session validation). If the auth overhaul changes how endpoints authenticate requests, then this endpoint's spec should account for the new auth patterns, not the old ones.

### Dependency graph (likely result)

```
#12 (auth overhaul)
  └── #23 (new API endpoint) — likely depends on #12 if the endpoint is authenticated

#15 (config option) — likely independent
```

### Execution plan (presented to user)

```
Wave 1 (parallel):
  #12 - Auth overhaul (full)      — foundational; other issues may depend on auth patterns
  #15 - Add config option (quick) — independent, small scope

Wave 2 (after wave 1):
  #23 - New API endpoint (lite)   — likely depends on #12's auth changes for route protection
```

**Note:** The exact dependency determination would depend on reading the actual issue bodies. If #23's issue body makes no reference to authentication and the endpoint is unauthenticated, I would move it to Wave 1 instead. I would also check whether the config option in #15 relates to auth — if it does (e.g., "add config option for OAuth redirect URL"), it might need to be in Wave 2 as well.

I would present this analysis transparently to the user, showing my reasoning for each dependency decision so they can correct me if I got it wrong.

---

## Step 3: Select Pipeline Mode Per Issue

### Issue #12 — Auth overhaul: `full` mode

Reasoning:
- The user described this as a "big auth overhaul" — this is the textbook case for full mode
- Auth changes are architecturally significant, touching multiple subsystems (middleware, models, routes, session management, possibly database schema)
- Security implications are non-trivial and benefit from the 4-draft diversity and red-team review that full mode provides
- "Big and hairy" is the exact phrase the skill uses to describe full-mode candidates

### Issue #15 — Config option: `quick` mode

Reasoning:
- Adding a config option is a small, well-defined change
- The implementation path is straightforward: add the config key, read it where needed, possibly add a UI element
- Likely touches 1-3 files
- This is exactly the kind of change where the quick pipeline (2 stages, 4 agents) is appropriate
- Spending 14 Opus agents on a config change would be wasteful

### Issue #23 — New API endpoint: `lite` mode

Reasoning:
- A new API endpoint is "normal" feature work — clear scope, non-trivial implementation
- It involves defining the route, handler, validation, database queries, tests, and documentation
- Likely touches 3-8 files across a couple of modules (routes, controllers, models, tests)
- The approach is relatively straightforward but benefits from validation
- Lite mode (4 stages, 6 agents) is the sweet spot here

---

## Step 4: Present the Plan

I would present the following to the user and wait for confirmation:

```
Execution Plan (spec-only):

Wave 1 (parallel — 2 specs):
  #12 - Auth overhaul           → full mode (6 stages, 14 agents)
      Reason: Architectural overhaul with security implications, benefits from
      draft diversity and red-team adversarial review.

  #15 - Add config option       → quick mode (2 stages, 4 agents)
      Reason: Small, well-defined change. Quick pipeline matches the scope.

Wave 2 (after wave 1 — 1 spec):
  #23 - New API endpoint        → lite mode (4 stages, 6 agents)
      Reason: Standard feature work. Runs after #12 so the recon step sees the
      new auth patterns that the endpoint will need to integrate with.

Parallel sessions: max 2 concurrent (wave 1)
Mode: Spec only — no implementation handoff

Concerns:
  - If #23 does not require authentication, it can move to Wave 1 for faster
    parallel execution. Let me know if you'd like to adjust.
  - If #12 is very large in scope, consider running `acorn issue split replay 12`
    first to break it into independently shippable pieces (e.g., "migrate session
    management" + "add new permission model" + "update route guards").
```

I would then **wait for the user to confirm or adjust** before proceeding. They might:
- Change a mode (e.g., "make #23 full mode too, it's more complex than I described")
- Reorder (e.g., "#23 doesn't need auth, put it in wave 1")
- Drop an issue (e.g., "#15 isn't urgent, skip it for now")
- Request splitting (e.g., "good idea on splitting #12, do that first")

---

## Step 5: Execute the Pipeline

After user confirmation, I would execute each wave.

### Wave 1

```bash
# Launch both specs in parallel
acorn create replay 12              # full mode (default)
acorn create replay 15 --quick      # quick mode
```

Both commands would run in the same message block since they are independent. Each creates a tmux session, generates PROMPT.md, and auto-triggers the planning agent.

### Monitor Wave 1

```bash
acorn status replay
```

I would check status periodically. For more granular progress:

```bash
# Check #12 recon progress (full mode starts with 3 recon agents)
ls ~/Projects/replay/main/.specs/auth-overhaul/recon/

# Check #15 — quick mode is fast, might finish before #12's recon is done
ls ~/Projects/replay/main/.specs/add-config-option/plans/SPEC.md

# Check #12 draft progress
ls ~/Projects/replay/main/.specs/auth-overhaul/plans/
```

I would report to the user as milestones are hit:
- "#15 (config option, quick mode) -- SPEC.md ready for review"
- "#12 (auth overhaul, full mode) -- recon complete, drafts in progress"
- "#12 (auth overhaul, full mode) -- red team review in progress"
- "#12 (auth overhaul, full mode) -- SPEC.md ready for review"

If a session dies or gets stuck:

```bash
# Check what happened
acorn status replay

# Re-run if needed
acorn clean replay <slug> --yes
acorn create replay <issue#> [--mode-flag]

# Or attach to debug
tmux attach -t replay_specs_<slug>_claude
```

### Wave 2 (after Wave 1 completes)

Once both #12 and #15 show status `review`:

```bash
acorn create replay 23 --lite       # lite mode
```

### Monitor Wave 2

```bash
acorn status replay

# Check progress
ls ~/Projects/replay/main/.specs/new-api-endpoint/recon/
ls ~/Projects/replay/main/.specs/new-api-endpoint/plans/SPEC.md
```

---

## Step 6: Monitor Progress

Throughout the pipeline, I would use `acorn status replay` as the primary monitoring tool, supplemented by checking for specific artifacts in the `.specs/` directories.

Status progression for each issue:
- `planning` -- agent is actively working
- `review` -- SPEC.md has been produced and is ready for human review

I would proactively report to the user rather than waiting to be asked, especially for:
- Completions (SPEC.md landed)
- Failures (session died, agent stuck)
- Wave transitions (all specs in wave N done, starting wave N+1)

---

## Step 7: Review Checkpoint

When all three specs are complete, I would present the final summary:

```
All specs complete:
  #12 - Auth overhaul              -> SPEC.md ready (full mode)
  #15 - Add config option          -> SPEC.md ready (quick mode)
  #23 - New API endpoint           -> SPEC.md ready (lite mode)

Specs are located at:
  ~/Projects/replay/main/.specs/auth-overhaul/plans/SPEC.md
  ~/Projects/replay/main/.specs/add-config-option/plans/SPEC.md
  ~/Projects/replay/main/.specs/new-api-endpoint/plans/SPEC.md

To review and approve:
  acorn approve replay auth-overhaul
  acorn approve replay add-config-option
  acorn approve replay new-api-endpoint
```

Since the user specified spec-only, this is the end of the pipeline. No implementation handoff (Step 8) would occur.

---

## Decision-Making Summary

| Decision | Rationale |
|----------|-----------|
| Spec only, no implementation | User explicitly said "spec only" |
| #12 gets `full` mode | "Big auth overhaul" = architectural, security-critical, multi-subsystem |
| #15 gets `quick` mode | "Adding a config option" = small, well-defined, 1-3 files |
| #23 gets `lite` mode | "New API endpoint" = standard feature work, clear scope |
| #23 waits for Wave 2 | New endpoint likely needs to integrate with the new auth patterns from #12 |
| #15 runs in Wave 1 | Config option is independent of auth changes |
| Splitting suggestion for #12 | "Big" auth overhauls can often be decomposed; worth asking |

## Commands Summary (in execution order)

```bash
# Pre-flight
acorn list replay
gh issue view 12 -R craigmills/replay --json number,title,body,labels,comments
gh issue view 15 -R craigmills/replay --json number,title,body,labels,comments
gh issue view 23 -R craigmills/replay --json number,title,body,labels,comments

# Wave 1 (parallel)
acorn create replay 12              # full
acorn create replay 15 --quick      # quick

# Monitoring
acorn status replay

# Wave 2 (after wave 1 completes)
acorn create replay 23 --lite       # lite

# Monitoring
acorn status replay

# Final review commands for user
acorn approve replay auth-overhaul
acorn approve replay add-config-option
acorn approve replay new-api-endpoint
```
