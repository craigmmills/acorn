# Dry Run: Spec and Implement All `ready-for-spec` Issues in Candles

## Task Summary

The user wants to:
1. Discover all open issues labeled `ready-for-spec` in the `candles` repo
2. Analyze dependencies and order them so recon never sees stale code
3. Generate specs via acorn in dependency order
4. Kick off implementations after specs complete

This is a **spec + implementation** workflow. The user explicitly said "kick off implementations after specs are done," so no need to ask about scope.

---

## Step 1: Discover Issues

### Command to fetch issues

```bash
gh issue list -R <owner>/candles -l "ready-for-spec" --state open --json number,title,body,labels,comments
```

I would determine `<owner>` from the git remote of the candles repo:

```bash
cd ~/Projects/candles/main
git remote get-url origin
# Expected output: git@github.com:<owner>/candles.git
```

### Pre-flight: Check for existing specs

Before processing, I would check whether any of these issues already have specs in progress:

```bash
acorn list candles
```

Any issues showing status `planning` or `review` would be flagged to the user and excluded from the batch unless they explicitly want to re-spec (which would require `acorn clean candles <slug> --yes` first).

### Expected output

A list of issues with their numbers, titles, bodies, labels, and comments. For this dry run, let's assume we get a representative set of issues. The actual issues would drive everything below.

---

## Step 2: Analyze Dependencies and Determine Order

### Explicit dependency scan

For each issue body and comment thread, I would scan for:
- "depends on #X", "blocked by #X", "after #X", "requires #X"
- "blocks #Y", "prerequisite for #Y"
- GitHub linked issues (via the `comments` field or cross-references)

### Implicit dependency analysis

I would read each issue body and reason about what parts of the codebase each issue touches:

- **Database schema changes** are foundational -- any issue adding tables, columns, or migrations must come before issues that query those new structures.
- **New API endpoints or services** must come before issues that consume those APIs.
- **Shared utilities, types, or config changes** must come before issues that use them.
- **UI components** that depend on new backend functionality must come after that backend work.
- If two issues modify the same files but don't logically depend on each other, I would still flag the overlap as a potential merge conflict risk.

### Cycle detection

If the dependency graph has cycles (A depends on B, B depends on A), I would stop and flag this to the user:

> "Issues #X and #Y have a circular dependency -- #X references #Y and vice versa. These likely need to be restructured. Should we split one of them, or can you clarify which should come first?"

### Build the wave plan

I would construct an execution plan grouping issues into waves. Issues within a wave have no dependencies on each other and can run in parallel. Waves execute sequentially.

**Example plan (illustrative -- actual plan depends on real issues):**

```
Wave 1 (parallel):
  #12 - Add OHLCV aggregation pipeline (full)
    Reasoning: Foundational data pipeline, other features likely depend on
    aggregated candle data. Complex architectural decision (full mode).

  #18 - Add health check endpoint (quick)
    Reasoning: Independent infrastructure concern, touches 1-2 files,
    straightforward implementation. No dependencies.

Wave 2 (parallel, after wave 1 is merged):
  #15 - Add WebSocket streaming for live candles (lite)
    Reasoning: Depends on #12's aggregation pipeline to produce the data
    it streams. Clear scope but non-trivial (lite mode).

  #21 - Add configurable retention policy (lite)
    Reasoning: Depends on #12's data model being in place. Well-defined
    feature touching ~5 files (lite mode).

Wave 3 (after wave 2 is merged):
  #24 - Add candle comparison dashboard (lite)
    Reasoning: Depends on #15 WebSocket streaming and #12 aggregation.
    Must see both in the codebase before recon runs.
```

### Why ordering matters (addressing the user's concern)

The user specifically said "I don't want recon seeing stale code." This is exactly right. Acorn's recon stage (Stage 0) scans the live codebase to understand architecture, relevant code, and conventions. If Issue B depends on code that Issue A will introduce, then B's recon must run *after* A's implementation is merged into main. Running them simultaneously would mean B's recon examines a codebase that doesn't yet have A's changes, producing a spec based on incomplete information.

The wave structure solves this:
- Wave 1 specs run against the current codebase
- Wave 1 implementations get merged into main
- Wave 2 specs run against the updated codebase (now including Wave 1 changes)
- And so on

---

## Step 3: Select Pipeline Mode Per Issue

For each issue, I would assess complexity and assign a mode:

| Signal | Mode |
|--------|------|
| Architectural decisions, multiple subsystems, vague requirements | `full` |
| Clear scope, 3-8 files, standard feature work | `lite` |
| Small, well-defined, 1-3 files, obvious implementation | `quick` |

I would present the reasoning for each choice so the user can override if they disagree. When in doubt, I default to `lite`.

---

## Step 4: Present the Plan for User Confirmation

Before executing anything, I would present the full plan to the user in this format:

```
=== Candles: Spec + Implement Pipeline ===

Source: All open issues labeled "ready-for-spec"
Found: 5 issues (0 already have specs in progress)
Mode: Spec + Implementation (dependency-ordered waves)

Wave 1 (parallel — 2 specs):
  #12 - Add OHLCV aggregation pipeline     [full]   foundational data model
  #18 - Add health check endpoint          [quick]  independent, trivial scope

Wave 2 (parallel, after Wave 1 merged — 2 specs):
  #15 - Add WebSocket streaming            [lite]   depends on #12 aggregation
  #21 - Add configurable retention policy  [lite]   depends on #12 data model

Wave 3 (after Wave 2 merged — 1 spec):
  #24 - Add candle comparison dashboard    [lite]   depends on #15 streaming

Concerns:
  - None identified. All issues have clear acceptance criteria.
  - (Or: #24 looks large — consider running `acorn issue split candles 24`
    before speccing.)

Estimated timeline:
  - Wave 1 specs: ~15-30 min (full + quick running in parallel)
  - Wave 1 implementation + merge: depends on review speed
  - Wave 2 specs: ~10-20 min (2x lite in parallel)
  - Wave 2 implementation + merge: depends on review speed
  - Wave 3 spec: ~10-15 min (1x lite)
  - Wave 3 implementation + merge: depends on review speed

Shall I proceed with this plan, or would you like to adjust anything?
```

I would **wait for user confirmation** before executing. They might want to:
- Change a mode (e.g., "make #15 full, it's more complex than it looks")
- Drop an issue ("skip #18 for now")
- Reorder ("actually #21 doesn't depend on #12, move it to Wave 1")
- Split an issue ("yeah, #24 is too big, split it first")

---

## Step 5: Execute the Pipeline — Wave by Wave

### Wave 1: Spec Generation

After user confirmation, I would launch Wave 1 specs:

```bash
# Launch specs in parallel
acorn create candles 12              # full mode (default)
acorn create candles 18 --quick      # quick mode
```

Both commands create tmux sessions, generate PROMPT.md files, and auto-trigger the planning agents.

### Wave 1: Monitoring

I would then enter a monitoring loop:

```bash
# Check status periodically
acorn status candles
```

For more granular checks:

```bash
# Check recon progress
ls ~/Projects/candles/main/.specs/add-ohlcv-aggregation-pipeline/recon/
ls ~/Projects/candles/main/.specs/add-health-check-endpoint/recon/

# Check if SPEC.md has landed
ls ~/Projects/candles/main/.specs/add-ohlcv-aggregation-pipeline/plans/SPEC.md
ls ~/Projects/candles/main/.specs/add-health-check-endpoint/plans/SPEC.md
```

I would report progress to the user:

```
Wave 1 Progress:
  #12 - Add OHLCV aggregation pipeline: recon complete, drafts in progress...
  #18 - Add health check endpoint: SPEC.md ready (quick mode finishes fast)
```

If a session dies or gets stuck, I would inform the user:

```
Session for #12 appears to have died. Options:
  1. Re-run: acorn clean candles add-ohlcv-aggregation-pipeline --yes && acorn create candles 12
  2. Debug: tmux attach -t candles_specs_add-ohlcv-aggregation-pipeline_claude
```

### Wave 1: Spec Review Checkpoint

When all Wave 1 specs show status `review`:

```
Wave 1 specs complete:
  #12 - Add OHLCV aggregation pipeline    -> SPEC.md ready (full mode)
  #18 - Add health check endpoint         -> SPEC.md ready (quick mode)

Specs are at:
  ~/Projects/candles/main/.specs/add-ohlcv-aggregation-pipeline/plans/SPEC.md
  ~/Projects/candles/main/.specs/add-health-check-endpoint/plans/SPEC.md

Ready to proceed with Wave 1 implementation. I'll approve these specs,
create worktrees, and start implementation agents.
```

### Wave 1: Implementation Handoff

1. **Approve specs:**
```bash
acorn approve candles add-ohlcv-aggregation-pipeline
acorn approve candles add-health-check-endpoint
```

2. **Create worktrees:**
```bash
dev wt candles add-ohlcv-aggregation-pipeline
dev wt candles add-health-check-endpoint
```

3. **Start agent sessions:**
```bash
dev candles/add-ohlcv-aggregation-pipeline/pi
dev candles/add-health-check-endpoint/pi
```

4. **Send specs to agents.** Each agent would be instructed to:
```
Read ~/Projects/candles/main/.specs/add-ohlcv-aggregation-pipeline/plans/SPEC.md
and implement it in this worktree. Follow all implementation instructions in the spec.
Commit your work when done and let me know it's ready for review.
```

5. **Monitor implementation progress:**
```bash
dev pi-status candles/add-ohlcv-aggregation-pipeline --messages 1
dev pi-status candles/add-health-check-endpoint --messages 1
```

### Wave 1: Merge Before Wave 2

**This is critical for the user's requirement that recon doesn't see stale code.**

When Wave 1 implementations are complete:

```bash
# Review and merge each implementation into main
cd ~/Projects/candles/main
git merge add-ohlcv-aggregation-pipeline
git merge add-health-check-endpoint

# Clean up finished worktrees
COMPOSE_PROJECT_NAME=candles-add-ohlcv-aggregation-pipeline docker compose down -v
dev cleanup candles/add-ohlcv-aggregation-pipeline

COMPOSE_PROJECT_NAME=candles-add-health-check-endpoint docker compose down -v
dev cleanup candles/add-health-check-endpoint
```

Now the main branch has all Wave 1 changes. Wave 2 recon will see the updated codebase.

### Waves 2 and 3: Same Pattern

The same cycle repeats for each subsequent wave:

**Wave 2:**
```bash
# Specs (run after Wave 1 is merged)
acorn create candles 15 --lite
acorn create candles 21 --lite

# Monitor until specs complete...
# Approve, create worktrees, implement...
# Merge into main, cleanup...
```

**Wave 3:**
```bash
# Spec (run after Wave 2 is merged)
acorn create candles 24 --lite

# Monitor until spec complete...
# Approve, create worktree, implement...
# Merge into main, cleanup...
```

---

## Step 7: Final Summary

After all waves complete, I would present:

```
=== Candles Pipeline Complete ===

All 5 issues have been specced and implemented:

Wave 1 (merged):
  #12 - Add OHLCV aggregation pipeline     [full]   -> implemented & merged
  #18 - Add health check endpoint          [quick]  -> implemented & merged

Wave 2 (merged):
  #15 - Add WebSocket streaming            [lite]   -> implemented & merged
  #21 - Add configurable retention policy  [lite]   -> implemented & merged

Wave 3 (merged):
  #24 - Add candle comparison dashboard    [lite]   -> implemented & merged

All worktrees have been cleaned up. The main branch has all changes.
GitHub issues have been updated with spec-approved labels.
```

---

## Monitoring Strategy Summary

Throughout the entire pipeline, I use these tools to stay informed:

| Tool | Purpose |
|------|---------|
| `acorn status candles` | Dashboard of all spec sessions (running/done/dead) |
| `ls .specs/<slug>/recon/` | Check if recon stage completed |
| `ls .specs/<slug>/plans/SPEC.md` | Check if final spec landed |
| `dev pi-status <session> --messages 1` | Check implementation agent's latest output |
| `dev queue-status <session> -m` | Check if agent has pending queue messages |

I would proactively report status after each significant milestone (recon done, spec done, implementation done, merge done) rather than waiting for the user to ask.

---

## Key Design Decisions

1. **Wave structure over flat parallelism:** The user explicitly wants dependency-aware ordering. Even if some issues *could* run in parallel, if one depends on another's code changes, they must be in separate waves.

2. **Merge between spec waves, not just implementation waves:** Both spec generation (recon) and implementation need to see the latest code. I merge Wave N's implementations before starting Wave N+1's specs.

3. **User confirmation before execution:** The skill mandates presenting the plan and waiting. This is not optional -- the user needs to validate mode choices, ordering, and scope before I start burning agent time.

4. **Fail-fast on problems:** If I discover cycles, underspecified issues, or issues that look too large, I surface these *before* any specs run. It's cheaper to fix an issue than re-spec it.

5. **Implementation in the same wave order as specs:** The wave structure applies to both phases. This ensures implementation agents also see the right version of the codebase.
