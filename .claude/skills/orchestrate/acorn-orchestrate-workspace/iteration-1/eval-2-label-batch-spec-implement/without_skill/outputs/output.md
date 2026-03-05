# Dry Run: Spec and Implement All `ready-for-spec` Issues in Candles

## Task Summary

The user asked to:
1. Find all issues labeled `ready-for-spec` in the `candles` repo
2. Order them by dependencies so recon agents see fresh code (not stale)
3. Run acorn spec pipelines in dependency order
4. Kick off implementations after specs complete

This is a **spec + implementation** workflow, not spec-only. The user explicitly said "kick off implementations after specs are done."

---

## Step 1: Discover Issues

### Command: Fetch all `ready-for-spec` issues

```bash
gh issue list -R <owner>/candles -l "ready-for-spec" --state open --json number,title,body,labels,comments
```

This returns all open issues with the `ready-for-spec` label. I need the full body and comments to analyze dependencies.

### Command: Check for existing specs in progress

```bash
acorn list candles
```

This shows any specs that are already in `planning` or `review` status. If any of the `ready-for-spec` issues already have active specs, I would:
- Report them to the user
- Exclude them from the batch unless the user explicitly asks to re-spec (which requires `acorn clean candles <slug> --yes` first)

### Analysis

At this point I would have a concrete list of issues. For the sake of this dry run, let me describe what I would do with them regardless of the specific issues returned.

For each issue, I would extract:
- Issue number and title
- Full body text (for dependency analysis)
- Comments (for additional context and dependency signals)
- Existing labels (to check for `ai-drafted` vs `human-clarified` and other status labels)

---

## Step 2: Analyze Dependencies and Determine Order

### Check explicit dependency references

I would scan every issue body and comment thread for dependency signals:
- "depends on #X", "blocked by #X", "after #X", "requires #X"
- "blocks #Y", "prerequisite for #Y"
- GitHub linked issues / cross-references

### Analyze implicit dependencies

For each issue, I would determine what it touches in the codebase:
- Which files, modules, or subsystems does it modify?
- Does it create new APIs, DB schemas, types, or components that other issues consume?
- Does it change foundational infrastructure (database schema, auth, routing, shared types) that others build on?

To do this analysis properly, I may also need to look at the candles codebase structure:

```bash
ls ~/Projects/candles/main/
```

Understanding the project layout helps me determine which issues touch overlapping areas.

### Build dependency graph

I would construct a directed acyclic graph (DAG) where edges represent "must complete before" relationships. If cycles are detected, I would flag them to the user as an issue that needs restructuring before proceeding.

### Group into waves

Issues are grouped into **waves** -- each wave contains issues that can run in parallel (no mutual dependencies), and waves run sequentially:

```
Wave 1 (parallel):
  #A - [foundational/infrastructure issue] (mode) -- no dependencies
  #B - [independent issue] (mode) -- no dependencies

Wave 2 (parallel, after wave 1 completes):
  #C - [depends on #A] (mode)
  #D - [depends on #A] (mode)

Wave 3 (after wave 2):
  #E - [depends on #C and #D] (mode)
```

The key constraint the user emphasized: **recon must not see stale code.** This means:
- Wave N+1 specs must NOT start until Wave N implementations are **merged into main**
- This is because acorn's recon agents read the codebase in `~/Projects/candles/main/`, and if Wave 1's changes aren't merged yet, Wave 2's recon will analyze the pre-Wave-1 codebase and produce specs based on outdated assumptions

This has a significant implication: **for dependent issues, we cannot just spec them all upfront.** We must:
1. Spec Wave 1
2. Implement Wave 1
3. Merge Wave 1 into main
4. THEN spec Wave 2 (so recon sees the updated code)
5. Implement Wave 2
6. Merge Wave 2
7. Continue...

For independent issues (within the same wave), we can spec and implement them in parallel since they don't affect each other's code areas.

---

## Step 3: Select Pipeline Mode Per Issue

For each issue I would assess complexity and assign a mode:

| Criteria | Mode | Flag |
|----------|------|------|
| Architectural decisions, multiple subsystems, vague scope | **full** | _(default)_ |
| Clear scope, non-trivial, 3-8 files, standard feature work | **lite** | `--lite` |
| Small, well-defined, 1-3 files, obvious implementation path | **quick** | `--quick` |

When in doubt, I would default to `lite` as the sweet spot between speed and rigor.

I would also flag any issues that look too big (candidates for `acorn issue split candles <issue#>`) or too vague (missing acceptance criteria or unclear job story) before starting.

---

## Step 4: Present the Plan to the User

Before executing anything, I would present the full plan. Here is the template of what I would show:

```
=== Execution Plan: candles ready-for-spec issues ===

Mode: Spec + Implementation (dependency-ordered waves)

Wave 1 (parallel — no dependencies):
  #<N> - <title> (<mode>) — <reasoning for mode>
  #<M> - <title> (<mode>) — <reasoning for mode>

Wave 2 (after Wave 1 merged into main):
  #<P> - <title> (<mode>) — depends on #<N>; <reasoning>

Wave 3 (after Wave 2 merged into main):
  #<Q> - <title> (<mode>) — depends on #<P>; <reasoning>

Concerns:
  - [Any issues that look too big and might need splitting]
  - [Any issues with missing acceptance criteria]
  - [Any detected dependency cycles]

Process for each wave:
  1. Run acorn create for all issues in the wave (parallel within wave)
  2. Monitor until all SPEC.md files land (acorn status candles)
  3. Review specs with user
  4. Approve specs (acorn approve candles <slug>)
  5. Create worktrees and start implementation agents
  6. Monitor implementations
  7. Review, merge into main, clean up worktrees
  8. Proceed to next wave

Estimated concurrent sessions: <N> (max wave width)

Proceed? (User confirms or adjusts)
```

I would **wait for user confirmation** before executing. They might want to:
- Change a mode assignment
- Reorder issues
- Drop an issue from the batch
- Split a large issue first

---

## Step 5: Execute the Spec Pipeline (Wave by Wave)

### Wave 1: Spec Phase

For each issue in Wave 1, kick off acorn:

```bash
acorn create candles <issue_A> --lite       # (or whatever mode was assigned)
acorn create candles <issue_B> --quick      # parallel with above
```

These run as detached tmux sessions. Each one:
1. Fetches the GitHub issue
2. Downloads any images
3. Generates PROMPT.md with the mode-specific planning methodology
4. Launches a Claude Code session that auto-triggers the pipeline
5. Recon agents examine the codebase, then drafts, validation, and final SPEC.md

### Wave 1: Monitor Specs

```bash
acorn status candles
```

I would poll periodically and report progress:

```bash
# Check if recon is done for a specific spec
ls ~/Projects/candles/main/.specs/<slug>/recon/

# Check if SPEC.md has landed
ls ~/Projects/candles/main/.specs/<slug>/plans/SPEC.md
```

When a session's status shows `review`, that spec is done. I would report as each completes:

```
Progress update:
  #A - recon complete, drafting in progress...
  #B - SPEC.md ready (review)
```

If a session dies or gets stuck, I would tell the user and suggest:
```bash
# Re-run a failed spec
acorn clean candles <slug> --yes && acorn create candles <issue#> --<mode>

# Or debug manually
tmux attach -t candles_specs_<slug>_claude
```

### Wave 1: Review Checkpoint

When all Wave 1 specs are complete:

```
Wave 1 specs complete:
  #A - <title> → SPEC.md ready (<mode>)
  #B - <title> → SPEC.md ready (<mode>)

Ready to approve and begin implementation?
```

---

## Step 6: Implementation Phase (Wave by Wave)

### Wave 1: Approve and Implement

1. **Approve specs:**
```bash
acorn approve candles <slug_A>
acorn approve candles <slug_B>
```

2. **Create worktrees:**
```bash
dev wt candles <feature-branch-A>
dev wt candles <feature-branch-B>
```

3. **Start implementation agents:**
```bash
dev candles/<feature-branch-A>/pi
dev candles/<feature-branch-B>/pi
```

4. **Send specs to each agent.** Each agent needs to be told to read the SPEC.md and implement it:

For the agent in worktree `<feature-branch-A>`:
```
Read the implementation spec at ~/Projects/candles/main/.specs/<slug_A>/plans/SPEC.md and implement it in this worktree. Commit your work when complete.
```

### Wave 1: Monitor Implementations

```bash
dev pi-status candles/<feature-branch-A> --messages 1
dev pi-status candles/<feature-branch-B> --messages 1
```

I would check periodically and report progress. Before nudging any agent, I always read its last message first (per the user's rule in CLAUDE.md).

### Wave 1: Merge and Clean Up

When implementations are complete and reviewed:

```bash
# Merge into main
cd ~/Projects/candles/main
git merge <feature-branch-A>

# Kill Docker environment for the feature
COMPOSE_PROJECT_NAME=candles-<feature-branch-A> docker compose down -v

# Remove worktree + branch + session
dev cleanup candles/<feature-branch-A>
```

Repeat for each feature branch in Wave 1.

**Critical:** Wave 2 specs must NOT start until Wave 1 merges are complete. This is what the user meant by "order them by dependencies -- I don't want recon seeing stale code."

### Subsequent Waves

For Wave 2, 3, etc., repeat the same cycle:
1. Spec (acorn create) -- now recon sees the updated codebase with Wave 1 changes
2. Monitor specs
3. Review checkpoint
4. Approve specs
5. Create worktrees, start implementation agents
6. Monitor implementations
7. Merge, clean up
8. Proceed to next wave

---

## Step 7: Final Summary

After all waves are complete, I would present a final summary:

```
=== All waves complete ===

Wave 1 (merged):
  #A - <title> — implemented and merged
  #B - <title> — implemented and merged

Wave 2 (merged):
  #C - <title> — implemented and merged

Wave 3 (merged):
  #D - <title> — implemented and merged

All ready-for-spec issues in candles have been specced and implemented.
Worktrees cleaned up. Main branch has all changes.
```

---

## Key Decision Points and Reasoning

### Why not spec everything upfront?

The user explicitly said "order them by dependencies -- I don't want recon seeing stale code." This means the dependency ordering applies to the **spec phase**, not just implementation. If issue #C depends on #A, and we spec #C before #A is implemented and merged, then #C's recon agents will examine the pre-#A codebase and produce a spec based on code that will change. This leads to specs that reference files, APIs, or patterns that no longer exist after #A ships.

The correct approach is the wave-by-wave cycle: spec wave -> implement wave -> merge wave -> spec next wave.

### Why present the plan before executing?

The user may disagree with mode assignments, dependency ordering, or want to drop/add issues. It is cheaper to adjust the plan than to re-spec after a wrong decision. The orchestration skill explicitly says "don't over-automate -- present the plan, get confirmation, then execute."

### Why check `acorn list` first?

Some issues might already have specs in progress from a previous run. Launching a duplicate spec session wastes resources and could conflict. Always check existing state before creating new sessions.

### Why use `dev review-loop` pattern for implementation monitoring?

The user's CLAUDE.md specifies this as the standard pattern for monitoring worktree agents. It involves periodic checking with sleep intervals, and never nudging without reading the agent's last message first.

### What if an issue looks too big?

I would suggest `acorn issue split candles <issue#>` before speccing it. A bloated spec that tries to do everything is worse than two focused specs that each ship independently.

### What if there are no dependencies?

If all issues are truly independent (touching different parts of the codebase with no shared infrastructure), then everything runs in a single wave -- all specs in parallel, then all implementations in parallel. This is the fastest path but only valid when there are genuinely no dependencies.

---

## Commands Summary (Quick Reference)

| Phase | Command | Purpose |
|-------|---------|---------|
| Discovery | `gh issue list -R <owner>/candles -l "ready-for-spec" --state open --json number,title,body,labels,comments` | Fetch all target issues |
| Discovery | `acorn list candles` | Check for existing specs |
| Spec | `acorn create candles <N> [--lite\|--quick]` | Launch spec pipeline |
| Monitor | `acorn status candles` | Check session status |
| Monitor | `ls ~/Projects/candles/main/.specs/<slug>/plans/SPEC.md` | Check if spec landed |
| Approve | `acorn approve candles <slug>` | Mark spec for implementation |
| Implement | `dev wt candles <branch>` | Create feature worktree |
| Implement | `dev candles/<branch>/pi` | Start implementation agent |
| Monitor | `dev pi-status candles/<branch> --messages 1` | Check agent progress |
| Merge | `git merge <branch>` (from main) | Merge implementation |
| Cleanup | `COMPOSE_PROJECT_NAME=candles-<branch> docker compose down -v` | Tear down Docker env |
| Cleanup | `dev cleanup candles/<branch>` | Remove worktree + branch + session |
