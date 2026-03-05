# Dry Run: Batch Spec Generation for `replay` Ready-for-Spec Issues

## Task Summary

The user wants to process all `ready-for-spec` labeled issues in the `replay` repository through acorn's spec pipeline. The workflow is spec-only (no implementation). Pipeline mode should be chosen per-issue based on complexity: `full` for architecturally complex work, `lite` for standard features, `quick` for small/simple changes.

---

## Step 1: Discover Issues

### Commands I Would Run

**1a. Check for existing specs already in progress:**

```bash
acorn list replay
```

This shows any specs that are already in `planning`, `review`, or `approved` status. Issues with active specs should be excluded from the batch unless the user explicitly wants to re-spec them (which would require `acorn clean` first).

**1b. Fetch all open issues with the `ready-for-spec` label:**

```bash
gh issue list -R <owner>/replay -l "ready-for-spec" --state open --json number,title,body,labels,comments
```

Note: I would need to determine the GitHub owner/org for the replay repo. This would be resolved from the git remote in `~/Projects/replay/main/`:

```bash
cd ~/Projects/replay/main && git remote get-url origin
```

**1c. Cross-reference results:**

Compare the `gh issue list` results against `acorn list replay` output. Any issue that already has a spec with status `planning` or `review` would be flagged to the user and excluded from the batch.

### Expected Output

A list of issues, each with: number, title, body text, labels, and any comments. For this dry run, I'll assume we get a set of issues and proceed with the analysis framework.

---

## Step 2: Analyze Each Issue for Dependencies and Complexity

For each issue returned, I would:

1. **Read the full issue body and all comments** to understand scope
2. **Scan for explicit dependency signals** in issue bodies and comments:
   - "depends on #X", "blocked by #X", "after #X", "requires #X"
   - "blocks #Y", "prerequisite for #Y"
   - GitHub linked issues / cross-references
3. **Analyze for implicit dependencies** by reasoning about what each issue touches:
   - Do two issues modify the same files or modules?
   - Does one issue create an API/schema/component that another consumes?
   - Does one issue change infrastructure (DB schema, auth, routing) that others build on?
4. **Assess complexity** to assign pipeline mode

### Dependency Analysis Framework

For each pair of issues (A, B), I would ask:
- Does A create something B needs? (A must come first)
- Do A and B touch the same subsystem? (potential conflict, may need ordering)
- Are A and B completely independent? (can run in parallel)

If cycles are detected (A depends on B, B depends on A), I would flag this to the user as a problem that likely means the issues need restructuring.

### Complexity Assessment Criteria

**Full mode (6 stages, 14 agents) -- assigned when:**
- Issue involves significant architectural decisions or introduces new patterns
- Multiple subsystems are affected and need to coordinate
- There are non-obvious edge cases or security implications
- Issue is vague or underspecified (extra draft diversity helps explore the solution space)
- Major DB schema changes, new authentication flows, large refactors

**Lite mode (4 stages, 6 agents) -- assigned when:**
- Scope is clear but non-trivial -- a solid feature with known boundaries
- Touches 3-8 files across a couple of modules
- Approach is relatively straightforward but benefits from validation
- Default for "normal" feature work

**Quick mode (2 stages, 4 agents) -- assigned when:**
- Change is small and well-defined (config changes, simple CRUD, small UI tweaks)
- Implementation path is obvious to anyone familiar with the codebase
- Touches 1-3 files
- Time sensitivity outweighs thoroughness

When in doubt, I would lean toward `lite` as the default.

### Splitting Recommendation

If any issue looks like it is doing too much (multiple unrelated changes, or a scope that would benefit from being broken into independently shippable pieces), I would suggest running `acorn issue split replay <issue#>` before speccing it. Better to split early than get a bloated spec.

---

## Step 3: Build the Execution Plan

### Plan Structure

I would organize issues into **waves** -- groups of issues that can run in parallel within the wave, with waves executing sequentially to respect dependencies.

**Example plan format (what I would present to the user):**

```
============================================================
  Batch Spec Plan for replay -- ready-for-spec issues
  Mode: spec-only (no implementation)
============================================================

Pre-flight checks:
  - acorn list replay: [N existing specs found / none]
  - Issues fetched: [N issues with ready-for-spec label]
  - Issues excluded: [any already being specced]

Splitting recommendations:
  - #XX "[title]" -- this issue covers [reason]. Consider splitting
    with `acorn issue split replay XX` before speccing.

Dependency graph:
  #A -> #B (B depends on A because [reason])
  #C -> #D (D depends on C because [reason])
  #E, #F, #G -- independent of each other and all above

Wave 1 (parallel -- no dependencies):
  #A  - "[title]"  (full)   -- [1-line justification for mode]
  #E  - "[title]"  (quick)  -- [1-line justification for mode]
  #F  - "[title]"  (lite)   -- [1-line justification for mode]

Wave 2 (parallel -- depends on wave 1):
  #B  - "[title]"  (lite)   -- depends on #A; [mode justification]
  #G  - "[title]"  (lite)   -- [mode justification]

Wave 3 (after wave 2):
  #C  - "[title]"  (full)   -- depends on #B; [mode justification]

Wave 4 (after wave 3):
  #D  - "[title]"  (quick)  -- depends on #C; [mode justification]

Parallel sessions at peak: [N]
Estimated total waves: [N]
============================================================
```

### User Confirmation

I would present this plan and **wait for the user to confirm or adjust** before executing anything. The user might want to:
- Change a mode assignment (e.g., "make #45 full instead of lite")
- Reorder issues
- Drop an issue from the batch
- Request splitting of a large issue first
- Override a dependency assessment

---

## Step 4: Execute the Pipeline (Wave by Wave)

### Wave 1 Execution

For each issue in wave 1, I would run the acorn create command with the appropriate mode flag:

```bash
# Launch all wave 1 specs in parallel
acorn create replay <issue_A> --full       # or no flag, since full is default
acorn create replay <issue_E> --quick
acorn create replay <issue_F> --lite
```

Each `acorn create` command:
1. Fetches the GitHub issue
2. Downloads any images to `.specs/<slug>/images/`
3. Generates `PROMPT.md` with requirements + mode-specific planning methodology
4. Creates a tmux session named `replay_specs_<slug>_claude`
5. Launches Claude Code inside the session
6. Auto-sends a trigger message telling the agent to read PROMPT.md and execute the pipeline

### Monitoring Wave 1

After launching, I would enter a monitoring loop:

```bash
# Check overall status
acorn status replay

# For more granular checks on individual specs:
ls ~/Projects/replay/main/.specs/<slug>/recon/          # Recon done?
ls ~/Projects/replay/main/.specs/<slug>/plans/SPEC.md   # Final spec landed?
```

I would report progress to the user periodically:

```
Wave 1 progress:
  #A  - "[title]" (full)  -- planning (recon complete, drafts in progress)
  #E  - "[title]" (quick) -- review (SPEC.md ready!)
  #F  - "[title]" (lite)  -- planning (recon complete, draft in progress)
```

**If a session dies or gets stuck**, I would tell the user and suggest:
```bash
# Option 1: Clean and re-run
acorn clean replay <slug> --yes && acorn create replay <issue#> [--mode-flag]

# Option 2: Attach to debug
tmux attach -t <session-name>
```

### Wave 1 Completion

When all specs in wave 1 show status `review` (meaning SPEC.md has been generated), I would announce wave 1 completion and move to wave 2.

### Wave 2+ Execution

Same pattern: launch all issues in the wave in parallel, monitor, report, wait for completion, then proceed to the next wave.

```bash
# Wave 2
acorn create replay <issue_B> --lite
acorn create replay <issue_G> --lite

# Monitor
acorn status replay

# Wave 3
acorn create replay <issue_C>  # full mode (default)

# Monitor
acorn status replay

# Wave 4
acorn create replay <issue_D> --quick

# Monitor
acorn status replay
```

---

## Step 5: Final Summary Report

When all waves are complete and all specs show `review` status, I would present a final summary:

```
============================================================
  All specs complete for replay
============================================================

  #A  - "[title]"    -> SPEC.md ready (full mode)
  #B  - "[title]"    -> SPEC.md ready (lite mode)
  #C  - "[title]"    -> SPEC.md ready (full mode)
  #D  - "[title]"    -> SPEC.md ready (quick mode)
  #E  - "[title]"    -> SPEC.md ready (quick mode)
  #F  - "[title]"    -> SPEC.md ready (lite mode)
  #G  - "[title]"    -> SPEC.md ready (lite mode)

Spec locations:
  ~/Projects/replay/main/.specs/<slug-A>/plans/SPEC.md
  ~/Projects/replay/main/.specs/<slug-B>/plans/SPEC.md
  ...

Next steps:
  - Review specs: read each SPEC.md
  - Approve when ready: acorn approve replay <slug>
  - Specs are currently in 'review' status (label: spec-review)
============================================================
```

---

## Decision-Making Process: How I Would Classify Issues

Here is a detailed breakdown of my reasoning framework for mode selection, applied to the types of issues commonly found in a monorepo like replay:

### Would get `full` mode:
- **New authentication/authorization system** -- foundational, security-sensitive, touches many subsystems
- **Database schema redesign or migration** -- affects data layer across the entire app
- **New API surface area** (REST/GraphQL endpoints with complex business logic) -- multiple subsystems coordinate
- **Major refactoring** (e.g., splitting a monolith module, changing state management approach) -- architectural
- **Underspecified issues** where the "how" is not obvious -- the 4 diverse drafts in full mode help explore the solution space
- **Anything involving concurrency, caching strategy, or distributed systems concerns**

### Would get `lite` mode:
- **Standard feature with clear scope** (new page, new component with API integration, adding a report)
- **Moderate API changes** (adding endpoints to an existing pattern, extending existing schemas)
- **Integration with third-party services** (clear interface but needs validation of approach)
- **Bug fixes that require understanding root cause across multiple files**
- **Anything that touches 3-8 files in a couple of modules** -- the default "normal work" choice

### Would get `quick` mode:
- **Config changes** (environment variables, feature flags, deployment settings)
- **Simple CRUD operations** following existing patterns
- **UI tweaks** (copy changes, styling, small component adjustments)
- **Documentation-only changes**
- **Adding a field to an existing form/model** that follows established patterns
- **Dependency updates** with clear migration paths

---

## Error Handling and Edge Cases

### No issues found
If `gh issue list` returns no issues with the `ready-for-spec` label, I would inform the user: "No open issues found with the `ready-for-spec` label in replay. Nothing to spec."

### All issues already have specs
If `acorn list replay` shows all discovered issues already have specs in `planning` or `review`, I would list them and ask the user if they want to re-spec any (which requires `acorn clean` first).

### Circular dependencies detected
I would flag the cycle to the user and suggest restructuring the issues before proceeding. Example: "Issues #12 and #15 appear to have a circular dependency -- #12 mentions needing the API from #15, but #15's schema changes depend on #12's data model. These likely need to be restructured into a shared foundation issue plus two independent features."

### Issue too large / needs splitting
If an issue body describes multiple unrelated changes or has a scope that would produce a sprawling spec, I would recommend: "Issue #XX looks like it covers both [thing A] and [thing B] which are fairly independent. Consider running `acorn issue split replay XX` before speccing to get cleaner, more focused specs."

### Session failures mid-wave
If `acorn status replay` shows a session as `dead` or stuck, I would:
1. Report it to the user immediately
2. Suggest re-running: `acorn clean replay <slug> --yes && acorn create replay <issue#> [--mode]`
3. Continue monitoring other sessions in the wave -- one failure does not block the rest of the wave
4. Only block the next wave if the failed spec is a dependency for issues in that wave

---

## Key Principles Guiding This Plan

1. **Dependency ordering matters more than speed.** A spec whose recon step examines stale code (before a dependency is implemented) produces a worse spec. Since this is spec-only (no implementation between waves), the dependency ordering primarily matters for issues where understanding one spec's design decisions would inform another's recon. In practice, for spec-only runs, more issues can often be parallelized than in spec+implement workflows, since the codebase does not change between waves. However, I would still order them if one issue's design fundamentally shapes another's solution space.

2. **Present the plan, get confirmation, then execute.** The user stays in control of the big picture.

3. **Surface problems early.** Flag splitting candidates, vague issues, or conflicts before starting specs.

4. **Keep the user oriented.** With multiple specs running across multiple tmux sessions, proactively report status rather than waiting to be asked.

5. **Match effort to complexity.** Don't burn 14 Opus agents on a config change, but don't shortchange an architectural overhaul with a quick spec.
