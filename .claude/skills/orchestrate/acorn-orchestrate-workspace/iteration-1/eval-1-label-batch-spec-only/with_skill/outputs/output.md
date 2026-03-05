# Dry Run: Batch Spec Generation for `ready-for-spec` Issues in Replay

**Task:** Analyze all `ready-for-spec` issues in the `replay` repo, determine dependencies, assign pipeline modes (full/lite/quick), and spec each one. Spec-only -- no implementation.

**Skill used:** `acorn-orchestrate` (Batch Spec & Implementation Pipeline)

---

## Phase 1: Discovery

### Step 1a: Check existing specs to avoid duplicates

**Command I would run:**
```bash
acorn list replay
```

**Purpose:** Identify any issues that already have specs with status `planning` or `review`. These would be excluded from the batch unless the user explicitly asks to re-spec them.

**Expected output:** A table showing any existing specs, their statuses, and pipeline modes. If none exist, the output would be empty or indicate no specs found.

### Step 1b: Fetch all open issues labeled `ready-for-spec`

**Command I would run:**
```bash
gh issue list -R <owner>/replay -l "ready-for-spec" --state open --json number,title,body,labels,comments
```

**Purpose:** Pull the full set of candidate issues for spec generation. The `--json` flag ensures I get structured data including the issue body (for dependency analysis) and comments (for additional context or explicit dependency mentions).

**What I would do with the results:**
- Parse each issue's number, title, body, labels, and comments
- If zero issues are returned, I would report to the user: "No open issues with the `ready-for-spec` label found in replay. Nothing to process." and stop.
- If any issues already have specs in `planning` or `review` status (from step 1a), I would note them: "Issues #X, #Y already have specs in progress -- skipping unless you want to re-spec them."

### Example: Hypothetical issues discovered

For this dry run, I'll work through the full pipeline with a realistic set of hypothetical issues to demonstrate the complete decision-making process:

| # | Title | Complexity Signal |
|---|-------|-------------------|
| 12 | Migrate session storage from cookie-based to Redis-backed sessions | Infrastructure, schema change, touches auth |
| 15 | Add WebSocket support for live replay streaming | New subsystem, architectural, protocol design |
| 18 | Add "share replay" button with link generation | Clear feature, moderate scope |
| 21 | Fix timestamp display to respect user timezone preferences | Small, well-scoped UI fix |
| 24 | Implement replay annotation system with collaborative editing | Large feature, real-time sync, permissions |
| 27 | Add CSV export for replay event data | Standard feature, clear scope |
| 30 | Update Docker Compose config for multi-service health checks | Config change, small |

---

## Phase 2: Dependency Analysis

### Step 2a: Scan for explicit dependency signals

I would read each issue body and all comments, searching for:
- "depends on #X", "blocked by #X", "after #X", "requires #X"
- "blocks #Y", "prerequisite for #Y"
- GitHub linked issues (in the `comments` or PR references)

**Example findings from hypothetical issues:**

- **#18 (share replay)** body mentions: "Share links should respect session auth -- see #12 for the session migration"
- **#24 (annotations)** body mentions: "Annotations stream via WebSocket -- depends on #15 being implemented first"
- **#24 (annotations)** also mentions: "Annotation permissions tie into session auth from #12"

### Step 2b: Analyze implicit dependencies

Even without explicit mentions, I would read all issue bodies and reason about what each touches:

| Issue | Subsystems Touched | Creates/Changes Shared Infrastructure |
|-------|-------------------|--------------------------------------|
| #12 (Redis sessions) | Auth, session management, Redis infra | YES -- changes how sessions work, other features depend on session auth |
| #15 (WebSocket streaming) | Network layer, new WebSocket subsystem | YES -- creates WS infrastructure that #24 consumes |
| #18 (share button) | UI, link generation, auth (read) | No -- consumes auth but doesn't change it |
| #21 (timezone fix) | UI, date formatting utilities | No -- isolated UI concern |
| #24 (annotations) | New annotation model, WebSocket, permissions | No -- consumes WS and auth infra from #12/#15 |
| #27 (CSV export) | Data access layer, export utilities | No -- reads replay data, independent |
| #30 (Docker config) | Infrastructure/config | No -- independent DevOps concern |

### Step 2c: Build dependency graph

```
#12 (Redis sessions)
  |
  +---> #18 (share button) -- needs session auth
  |
  +---> #24 (annotations) -- needs session auth + permissions
  |
#15 (WebSocket streaming)
  |
  +---> #24 (annotations) -- needs WebSocket infrastructure

#21 (timezone fix)      -- independent
#27 (CSV export)        -- independent
#30 (Docker config)     -- independent
```

**Cycle check:** No cycles detected. The graph is a clean DAG.

### Step 2d: Group into waves

**Wave 1 (parallel -- no dependencies, can all run simultaneously):**
- #12 - Migrate session storage to Redis (foundational -- #18 and #24 depend on this)
- #15 - Add WebSocket support for live streaming (foundational -- #24 depends on this)
- #21 - Fix timezone display (independent, small)
- #27 - Add CSV export (independent)
- #30 - Update Docker Compose config (independent)

**Wave 2 (after Wave 1 completes):**
- #18 - Add share replay button (depends on #12 -- needs session auth patterns in codebase)
- #24 - Implement annotation system (depends on #12 and #15 -- needs both session auth and WebSocket infra)

**Rationale for wave ordering:** Even though we're only generating specs (not implementing), the spec pipeline's recon stage analyzes the actual codebase. Since #18 and #24 don't yet have their dependency code in the codebase, their recon results won't be affected by wave ordering. However, maintaining dependency ordering in specs is still valuable because:
1. The specs for #18 and #24 should reference the planned approaches from #12 and #15
2. If we later move to implementation, the wave structure is already correct
3. In practice for spec-only, we could run all 7 in parallel since recon reads current codebase state -- but I would flag this choice to the user

**Decision point I would present to the user:** "Since this is spec-only, all 7 issues could technically run in parallel (recon reads the current codebase, not a future state). However, I recommend keeping the wave structure so dependent specs can reference the plans from their prerequisites. Your call -- run all 7 in parallel, or keep the 2-wave structure?"

---

## Phase 3: Pipeline Mode Selection

### Mode assignments with reasoning

| Issue | Mode | Reasoning |
|-------|------|-----------|
| **#12** - Redis session migration | **full** | Architectural change affecting auth infrastructure. Touches session management, Redis configuration, potentially database schema, middleware. Multiple subsystems affected. Security implications (session handling). Non-obvious edge cases (session migration, backwards compatibility, invalidation). This is foundational -- getting it wrong cascades. |
| **#15** - WebSocket live streaming | **full** | New subsystem introduction. Requires protocol design decisions (WS message format, reconnection strategy, backpressure). Touches network layer, potentially requires new server infrastructure. Architectural -- multiple valid approaches that need exploring through draft diversity. |
| **#18** - Share replay button | **lite** | Clear feature scope with known boundaries. Involves UI component, link generation service, auth integration. Touches maybe 4-6 files across UI and API layers. Straightforward but benefits from validation (security of share links, expiration handling). |
| **#21** - Timezone display fix | **quick** | Small, well-defined change. Implementation path is obvious: update date formatting utilities to respect user timezone preference. Likely touches 1-3 files (date utility, UI components using it, possibly a user preference model). |
| **#24** - Annotation system | **full** | Large feature with multiple complex aspects: data model for annotations, real-time collaborative editing (conflict resolution), WebSocket integration, permissions model. Multiple subsystems, non-obvious edge cases (concurrent edits, offline sync, permission inheritance). Needs the full 14-agent treatment to explore the solution space. |
| **#27** - CSV export | **lite** | Standard feature with clear scope. Involves data access patterns, export formatting, possibly streaming for large datasets. Not trivial (data volume, encoding, field selection) but the approach is relatively straightforward. Benefits from validation step. |
| **#30** - Docker Compose health checks | **quick** | Config change with well-defined scope. Touches 1-2 files (docker-compose.yml, possibly a health check script). Implementation path is obvious to anyone familiar with Docker Compose health check syntax. |

### Summary by mode
- **Full (14 agents):** #12, #15, #24 -- 3 architecturally complex issues
- **Lite (6 agents):** #18, #27 -- 2 standard features
- **Quick (4 agents):** #21, #30 -- 2 small/well-defined changes

### Concerns I would flag

1. **Issue #24 might benefit from splitting.** "Implement replay annotation system with collaborative editing" packs a lot into one issue: the annotation data model, the collaborative editing with conflict resolution, the WebSocket integration, and the permissions model. I would suggest: "Consider running `acorn issue split replay 24` before speccing -- the collaborative editing piece alone could be its own issue, separate from basic annotations."

2. **Issue #12 has migration implications.** The session migration from cookies to Redis implies a data migration or dual-mode transition period. I would flag: "Does issue #12 include a migration strategy for existing sessions, or should that be a separate issue?"

---

## Phase 4: Present the Plan to the User

Before executing anything, I would present the following plan and wait for confirmation:

---

**Batch Spec Plan for `replay` -- 7 issues, spec-only**

```
Wave 1 (5 issues, parallel):
  #12 - Migrate session storage to Redis         (full)  -- foundational, auth infra
  #15 - Add WebSocket support for live streaming  (full)  -- foundational, new subsystem
  #21 - Fix timezone display                      (quick) -- independent, small UI fix
  #27 - Add CSV export for replay data            (lite)  -- independent, standard feature
  #30 - Update Docker Compose health checks       (quick) -- independent, config change

Wave 2 (2 issues, parallel, after Wave 1):
  #18 - Add share replay button                   (lite)  -- depends on #12
  #24 - Implement annotation system               (full)  -- depends on #12, #15

Parallel sessions: up to 5 concurrent (Wave 1), then 2 concurrent (Wave 2)
Mode: spec-only (no implementation)
```

**Concerns:**
- Issue #24 is large -- consider splitting with `acorn issue split replay 24` before speccing
- Issue #12 migration strategy may warrant its own sub-issue

**Ready to proceed? You can:**
- Change a mode (e.g., "make #27 quick instead of lite")
- Reorder or drop issues
- Split an issue first
- Run everything in a single wave (since spec-only, recon reads current codebase)
- Confirm as-is

---

## Phase 5: Execute the Pipeline

After user confirmation, I would execute each wave.

### Wave 1 execution

**Commands I would run (all launched rapidly in sequence -- they run asynchronously via tmux):**

```bash
acorn create replay 12                # full mode (default)
acorn create replay 15                # full mode (default)
acorn create replay 21 --quick        # quick mode
acorn create replay 27 --lite         # lite mode
acorn create replay 30 --quick        # quick mode
```

Each `acorn create` command:
1. Fetches the GitHub issue
2. Downloads any images to `.specs/<slug>/images/`
3. Generates `PROMPT.md` with requirements + mode-specific planning methodology
4. Creates a tmux session named `replay_specs_<slug>_claude`
5. Launches Claude Code inside the tmux session
6. After 5 seconds, sends the auto-trigger message to start the pipeline

**Expected sessions created:**
- `replay_specs_migrate-session-storage-redis_claude` (or similar slug)
- `replay_specs_websocket-live-streaming_claude`
- `replay_specs_fix-timezone-display_claude`
- `replay_specs_csv-export-replay-data_claude`
- `replay_specs_docker-compose-health-checks_claude`

---

## Phase 6: Monitor Progress

### Monitoring commands I would run periodically

**Overall status:**
```bash
acorn status replay
```

This shows all running sessions with their current status (planning/review/dead).

**Per-issue progress checks (when I want more detail):**

```bash
# Check if recon is done for full-mode issues (they take longer)
ls ~/Projects/replay/main/.specs/migrate-session-storage-redis/recon/
ls ~/Projects/replay/main/.specs/websocket-live-streaming/recon/

# Check if SPEC.md has landed for quick-mode issues (finish fastest)
ls ~/Projects/replay/main/.specs/fix-timezone-display/plans/SPEC.md
ls ~/Projects/replay/main/.specs/docker-compose-health-checks/plans/SPEC.md
```

### Expected completion order (by mode speed)

1. **Quick issues finish first** (~5-10 min): #21 (timezone), #30 (Docker config)
2. **Lite issues next** (~15-25 min): #27 (CSV export)
3. **Full issues last** (~30-60 min): #12 (Redis sessions), #15 (WebSocket)

### Progress reports to user

I would provide periodic updates like:

```
Wave 1 progress (5 issues):
  #21 - Fix timezone display          [quick]  -- DONE (SPEC.md ready)
  #30 - Docker Compose health checks  [quick]  -- DONE (SPEC.md ready)
  #27 - CSV export for replay data    [lite]   -- recon complete, draft in progress
  #12 - Redis session migration       [full]   -- recon complete, 4 drafts in progress
  #15 - WebSocket live streaming      [full]   -- recon complete, 2/4 drafts written

Waiting for Wave 1 to complete before starting Wave 2.
```

### Handling failures

If a session dies or gets stuck, I would:

1. Report it: "#15 WebSocket spec session appears to have died."
2. Suggest options:
   ```bash
   # Option A: Clean and retry
   acorn clean replay websocket-live-streaming --yes
   acorn create replay 15

   # Option B: Attach to debug
   tmux attach -t replay_specs_websocket-live-streaming_claude
   ```
3. Let the user decide before taking action.

### Wave 1 completion

When all 5 Wave 1 specs reach `review` status, I would report:

```
Wave 1 complete (all 5 specs ready):
  #12 - Migrate session storage to Redis         -- SPEC.md ready (full mode)
  #15 - Add WebSocket support for live streaming  -- SPEC.md ready (full mode)
  #21 - Fix timezone display                      -- SPEC.md ready (quick mode)
  #27 - Add CSV export for replay data            -- SPEC.md ready (lite mode)
  #30 - Update Docker Compose health checks       -- SPEC.md ready (quick mode)

Starting Wave 2...
```

### Wave 2 execution

```bash
acorn create replay 18 --lite         # lite mode, depends on #12
acorn create replay 24                # full mode (default), depends on #12, #15
```

**Expected sessions:**
- `replay_specs_share-replay-button_claude`
- `replay_specs_annotation-system-collaborative_claude`

**Same monitoring pattern as Wave 1.**

---

## Phase 7: Final Review Checkpoint

When all specs across both waves are complete, I would present the final summary:

```
All specs complete -- 7 issues processed across 2 waves:

Wave 1:
  #12 - Migrate session storage to Redis         -- SPEC.md ready (full mode)
  #15 - Add WebSocket support for live streaming  -- SPEC.md ready (full mode)
  #21 - Fix timezone display                      -- SPEC.md ready (quick mode)
  #27 - Add CSV export for replay data            -- SPEC.md ready (lite mode)
  #30 - Update Docker Compose health checks       -- SPEC.md ready (quick mode)

Wave 2:
  #18 - Add share replay button                   -- SPEC.md ready (lite mode)
  #24 - Implement annotation system               -- SPEC.md ready (full mode)

Specs live at:
  ~/Projects/replay/main/.specs/<slug>/plans/SPEC.md

When you're ready to review, approve specs with:
  acorn approve replay <slug>

The dependency order for future implementation would be:
  Wave 1: #12, #15, #21, #27, #30 (parallel)
  Wave 2: #18, #24 (parallel, after Wave 1 merged)
```

Since this is spec-only, no implementation or worktree creation would happen. The user reviews specs at their own pace and approves them individually with `acorn approve`.

---

## Decision-Making Summary

### Key decisions made and rationale

1. **Wave structure over full parallelism:** Even for spec-only, I maintained dependency-ordered waves so dependent specs can reference prerequisite plans. I flagged that all-parallel is an option for the user.

2. **Mode assignment discipline:** Used `full` only for genuinely architectural issues (3 of 7). Used `lite` for standard features that benefit from validation (2 of 7). Used `quick` for well-scoped small changes (2 of 7). This balances thoroughness with efficiency -- no point burning 14 Opus agents on a Docker config change.

3. **Proactive concern flagging:** Identified #24 as a potential split candidate and #12 as having migration concerns, both before any spec work starts. Cheaper to fix issue scoping problems before speccing.

4. **User control at every decision point:** Presented the full plan before execution, offered specific adjustment options, and would wait for confirmation. The orchestration skill emphasizes "don't over-automate."

### Commands that would have been run (in order)

```bash
# Discovery
acorn list replay
gh issue list -R <owner>/replay -l "ready-for-spec" --state open --json number,title,body,labels,comments

# Wave 1 execution (after user confirms plan)
acorn create replay 12
acorn create replay 15
acorn create replay 21 --quick
acorn create replay 27 --lite
acorn create replay 30 --quick

# Monitoring (repeated periodically)
acorn status replay

# Wave 2 execution (after Wave 1 completes)
acorn create replay 18 --lite
acorn create replay 24

# Final monitoring
acorn status replay
```

Total: 7 spec sessions, max 5 concurrent, 2 waves, estimated total time ~45-75 minutes depending on full-mode spec completion speed.
