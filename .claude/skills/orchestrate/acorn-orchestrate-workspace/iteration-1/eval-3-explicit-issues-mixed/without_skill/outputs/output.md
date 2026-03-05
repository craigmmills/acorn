# Dry Run: Acorn Spec Generation for Replay Issues 12, 15, and 23

## Task Analysis

The user wants to run acorn on three replay issues to generate specs only (no implementation). The issues have different complexity levels:

| Issue | Description | Complexity Assessment | Recommended Mode |
|-------|-------------|----------------------|------------------|
| #12 | Big auth overhaul | High — architectural, cross-cutting | **Full** (default) |
| #15 | Adding a config option | Low — simple, bounded change | **Quick** (`--quick`) |
| #23 | New API endpoint | Moderate — new feature, standard pattern | **Lite** (`--lite`) |

## Decision-Making: Mode Selection

### Issue #12 — Auth Overhaul (Full mode)

The user described this as a "big auth overhaul." Authentication is a cross-cutting concern that touches middleware, database schemas, session management, API routes, and potentially frontend components. This is exactly the type of issue the Full pipeline was designed for:
- 3 Opus recon agents will map out all the auth-related code paths
- 4 diverse draft plans will explore different architectural approaches (e.g., JWT vs session-based, migration strategies)
- The evaluation stage will score each approach on criteria like security, migration risk, and backward compatibility
- Synthesis combines the best elements
- 4 red team agents will probe for security gaps, edge cases, and migration pitfalls
- Final spec incorporates adversarial findings

**Mode: Full (default, no flag needed)**

### Issue #15 — Adding a Config Option (Quick mode)

Adding a config option is a bounded, well-understood change. It typically involves:
- Adding a field to a config schema/type
- Reading it in the relevant service
- Possibly adding a migration or default value
- Updating docs/validation

This does not warrant 14 agents and 6 stages. The Quick pipeline (3 Sonnet recon + 1 Opus direct spec) is sufficient. Recon will identify the config system and conventions, then a single spec generation pass is all that is needed.

**Mode: Quick (`--quick`)**

### Issue #23 — New API Endpoint (Lite mode)

A new API endpoint is a standard feature with moderate complexity. It involves route definition, handler logic, validation, database queries, tests, and documentation. It follows established patterns but needs proper planning. The Lite pipeline (3 Sonnet recon, 1 draft, 1 validation, 1 final spec) provides enough rigor without the overhead of the full pipeline.

**Mode: Lite (`--lite`)**

## Commands I Would Execute

### Step 1: Launch All Three Spec Pipelines

All three commands are independent and can be run in parallel:

```bash
# Issue #12 — Full pipeline (auth overhaul, high complexity)
acorn create replay 12

# Issue #15 — Quick pipeline (config option, low complexity)
acorn create replay 15 --quick

# Issue #23 — Lite pipeline (API endpoint, moderate complexity)
acorn create replay 23 --lite
```

Each command will:
1. Fetch the GitHub issue via `gh issue view replay/<issue#>`
2. Download any images from the issue body to `.specs/<slug>/images/`
3. Generate a `PROMPT.md` with the issue content + mode-specific planning methodology
4. Write `meta.json` with metadata (repo, issue number, mode, session info)
5. Create a tmux session named `replay_specs_<slug>_claude`
6. Launch `claude` inside the session with `--dangerously-skip-permissions`
7. After a 5-second delay, auto-trigger the agent with a mode-specific message telling it to read PROMPT.md

### Step 2: Verify Sessions Started

After launching, I would immediately check that all three sessions are running:

```bash
acorn status replay
```

Expected output would show three sessions with `planning` status:

```
replay specs:
  <issue-12-slug>    planning   full    replay#12
  <issue-15-slug>    planning   quick   replay#15
  <issue-23-slug>    planning   lite    replay#23
```

If any session failed to start, I would investigate with:

```bash
# Check the specific tmux session
tmux list-sessions | grep replay_specs
```

### Step 3: Monitor Progress

Since these are spec-only tasks running asynchronously, I would set up a monitoring loop. The Quick pipeline (#15) should finish first, then Lite (#23), then Full (#12).

**Expected completion order and approximate timing:**
1. Issue #15 (Quick) — ~5-10 minutes (2 stages, 4 agents)
2. Issue #23 (Lite) — ~15-25 minutes (4 stages, 6 agents)
3. Issue #12 (Full) — ~30-60 minutes (6 stages, 14 agents)

**Monitoring commands:**

```bash
# Check status of all three
acorn status replay

# Check individual agent progress
dev pi-status replay_specs_<issue-15-slug>_claude --messages 1
dev pi-status replay_specs_<issue-23-slug>_claude --messages 1
dev pi-status replay_specs_<issue-12-slug>_claude --messages 1
```

I would check status periodically. When a session shows status `review`, the SPEC.md is ready.

### Step 4: Report Results

As each pipeline completes, I would report to the user:

```bash
# List completed specs
acorn list replay
```

For each completed spec, I would read the SPEC.md and provide a summary:

```bash
# Read the generated specs (once status shows "review")
cat ~/Projects/replay/main/.specs/<issue-12-slug>/plans/SPEC.md
cat ~/Projects/replay/main/.specs/<issue-15-slug>/plans/SPEC.md
cat ~/Projects/replay/main/.specs/<issue-23-slug>/plans/SPEC.md
```

## What I Would Present to the User

### Before Execution

> I will run acorn on the three replay issues with mode selection based on complexity:
>
> - **Issue #12** (auth overhaul) -- **Full pipeline** (6 stages, 14 agents). This is a cross-cutting architectural change that benefits from diverse draft plans and adversarial red-teaming.
> - **Issue #15** (config option) -- **Quick pipeline** (2 stages, 4 agents). A simple, bounded change that does not need extensive planning overhead.
> - **Issue #23** (API endpoint) -- **Lite pipeline** (4 stages, 6 agents). A standard feature with moderate complexity -- enough rigor without the full treatment.
>
> All three will run concurrently in separate tmux sessions. I will monitor their progress and report back as each finishes.

### During Execution

I would check `acorn status replay` periodically and report progress, e.g.:

> Status update:
> - Issue #15 (config option, quick): SPEC.md ready for review
> - Issue #23 (API endpoint, lite): Stage 2/4 -- draft in progress
> - Issue #12 (auth overhaul, full): Stage 1/6 -- recon agents running

### After Completion

> All three specs are complete and ready for review:
>
> | Issue | Spec Location | Mode | Status |
> |-------|--------------|------|--------|
> | #12 | `.specs/<slug>/plans/SPEC.md` | Full | review |
> | #15 | `.specs/<slug>/plans/SPEC.md` | Quick | review |
> | #23 | `.specs/<slug>/plans/SPEC.md` | Lite | review |
>
> You can review each spec and approve with `acorn approve replay <slug>` when ready.

## Output Artifacts (Per Issue)

### Issue #12 (Full Pipeline)
```
~/Projects/replay/main/.specs/<issue-12-slug>/
  PROMPT.md
  meta.json
  images/            (if issue has images)
  recon/
    architecture.md
    relevant_code.md
    conventions.md
  plans/
    draft_plan_1.md
    draft_plan_2.md
    draft_plan_3.md
    draft_plan_4.md
    evaluation.md
    master_plan.md
    red_team_1.md
    red_team_2.md
    red_team_3.md
    red_team_4.md
    SPEC.md
```

### Issue #15 (Quick Pipeline)
```
~/Projects/replay/main/.specs/<issue-15-slug>/
  PROMPT.md
  meta.json
  images/            (if issue has images)
  recon/
    architecture.md
    relevant_code.md
    conventions.md
  plans/
    SPEC.md
```

### Issue #23 (Lite Pipeline)
```
~/Projects/replay/main/.specs/<issue-23-slug>/
  PROMPT.md
  meta.json
  images/            (if issue has images)
  recon/
    architecture.md
    relevant_code.md
    conventions.md
  plans/
    draft_plan_1.md
    validation.md
    SPEC.md
```

## Error Handling Considerations

- **If an issue does not exist:** `acorn create` would fail when fetching via `gh issue view`. I would report the error and skip that issue.
- **If a spec already exists for an issue:** acorn would likely warn or refuse. I would check with `acorn list replay` first and inform the user.
- **If a tmux session fails to start:** I would check `tmux list-sessions` and retry the specific `acorn create` command.
- **If an agent stalls or crashes:** I would check `dev pi-status <session> --messages 1` and potentially restart with a new `acorn create` (after cleaning up with `acorn clean replay <slug> --force`).

## Summary

The key decision here is mode selection based on the user's complexity hints:

| Signal | Mode | Rationale |
|--------|------|-----------|
| "big auth overhaul" | Full | Architectural, security-critical, needs diverse perspectives and adversarial review |
| "just adding a config option" | Quick | Simple, bounded, well-understood pattern |
| "new API endpoint" | Lite | Standard feature, moderate complexity, needs validation but not full treatment |

Three concurrent `acorn create` commands, each with the appropriate mode flag, followed by periodic status monitoring until all specs reach `review` status.
