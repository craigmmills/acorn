---
name: acorn-spec-review
description: >
  Structured spec review and implementation handoff workflow for acorn-generated SPEC.md files.
  Evaluates specs across three dimensions — completeness (architecture, data model, API contracts,
  edge cases, testing strategy), feasibility (technical risks, scope creep, performance), and
  alignment (Job Story match, promise fulfillment, constraint respect, red team findings) — then
  handles approval and optional worktree-based implementation handoff. This skill contains the
  complete review rubric, the approval workflow via acorn CLI, and the implementation handoff
  protocol (worktree creation, agent dispatch, spec delivery) — you cannot perform a thorough
  spec review or coordinate the handoff without it. You MUST use this skill whenever the user
  wants to review a spec, check if a spec is ready, approve a spec, or move from spec to
  implementation. Trigger phrases include "review this spec", "is this spec ready?", "approve
  and implement", "check the spec for gaps", "kick off implementation", "spec looks good,
  implement it", "implement this", or anything about evaluating spec quality. Also use this
  skill automatically as part of end-to-end workflows — if the user asked to "spec and implement"
  an issue, the review + handoff should happen without extra prompting once the spec lands.
---

# Acorn Spec Review & Implementation Handoff

You're reviewing an acorn-generated SPEC.md to determine whether it's ready for implementation, and then optionally handing it off to an implementation agent. A spec that gets approved and shipped without review is a spec that ships its blind spots too.

## When This Kicks In

Two scenarios:

1. **Explicit review request**: The user says "review the spec for X" or "is the spec for issue 42 ready?"
2. **Part of a larger flow**: The user asked for end-to-end (e.g., "spec and implement issue 42"). After the spec lands, you review it and hand off automatically — no need to pause and ask "should I review now?"

Detect the context from the conversation. If the user's original request implied implementation follows speccing, treat review + handoff as a continuous pipeline.

## Step 1: Locate the Spec

Find the SPEC.md and its supporting materials:

```bash
# Check what specs exist
acorn list <repo>

# The spec lives here:
ls ~/Projects/<repo>/main/.specs/<slug>/plans/SPEC.md

# Supporting materials:
ls ~/Projects/<repo>/main/.specs/<slug>/recon/       # architecture.md, relevant_code.md, conventions.md
ls ~/Projects/<repo>/main/.specs/<slug>/plans/        # drafts, evaluation, red team reports
ls ~/Projects/<repo>/main/.specs/<slug>/PROMPT.md     # original requirements
ls ~/Projects/<repo>/main/.specs/<slug>/meta.json     # metadata including mode
```

Read the SPEC.md. Also read PROMPT.md (contains the original issue requirements) and meta.json (tells you which mode was used — this calibrates your expectations).

## Step 2: Review the Spec

Evaluate across three dimensions. Think of yourself as a tech lead doing a final review before greenlighting work for a sprint.

### Completeness

Is anything missing that an implementation agent would need?

- **Architecture**: Does the spec describe where new code goes, what gets modified, and how components connect? An implementer shouldn't have to guess at file placement or module boundaries.
- **Data model**: If there are new tables, schemas, or data structures — are they defined? Are migrations mentioned?
- **API contracts**: If there are new or modified endpoints/interfaces — are request/response shapes specified?
- **Edge cases**: Does the spec address error states, empty states, boundary conditions? (Check this against the acceptance criteria from the original issue.)
- **Testing strategy**: Does the spec mention what to test and how? Unit tests, integration tests, what scenarios to cover?
- **Missing sections**: Compare against the original issue's acceptance criteria. Is every criterion addressed somewhere in the spec?

### Feasibility

Will this actually work as described?

- **Technical risks**: Are there assumptions that might not hold? Dependencies that might not exist? Libraries being used in ways they don't support?
- **Scope creep**: Did the spec add significant scope beyond what the issue asked for? If so, is it justified, or did the planning agents gold-plate?
- **Performance implications**: If the spec introduces new queries, API calls, or data processing — are there potential performance concerns not addressed?
- **Dependency conflicts**: Does this spec assume code or infrastructure from another issue that hasn't been implemented yet? Check the issue's dependency chain.
- **Complexity vs. value**: Is the approach proportional to the problem? A 500-line spec for a config change is a smell.

### Alignment

Does this spec actually solve the original problem?

- **Job Story match**: Read the original issue's Job Story. Does the spec deliver on that specific user need, or did it drift to solving a different (possibly related) problem?
- **Promise fulfillment**: Will implementing this spec result in the Promise being true? Go criterion by criterion.
- **Constraint respect**: Does the spec stay within the constraints from the original issue? If it violates any, is there justification?
- **Red team findings**: If the spec was generated in full mode, check the red team reports in the plans/ directory. Were critical findings addressed in the final spec, or were they dropped?

## Step 3: Present the Review

Structure your review clearly. Don't just say "looks good" — even good specs benefit from a summary.

### Format

```
## Spec Review: <title>

**Mode**: full/lite/quick | **Issue**: #N | **Status**: Ready / Needs Work

### Verdict
One paragraph summary. Is this ready to implement as-is, or does it need changes?

### Completeness
- [x] Architecture and file placement defined
- [x] Data model changes specified
- [ ] API contracts incomplete — /api/notifications endpoint missing response shape
- [x] Edge cases covered
- [x] Testing strategy present

### Feasibility
- No blocking technical risks identified
- Scope is proportional to the issue
- Note: Redis dependency assumed but not verified — check if Redis is in docker-compose

### Alignment
- Job Story: Addressed ✓
- Promise: All criteria mapped to spec sections ✓
- Constraints: Respected ✓
- Red team: 2/3 critical findings addressed, 1 deferred (noted in spec)

### Action Items (if any)
1. Add response shape for /api/notifications endpoint
2. Verify Redis is available in the docker-compose setup
```

Use checkboxes for completeness items — it makes gaps scannable. Be specific about what's missing, not just that something is missing.

### Calibrate to Mode

A quick-mode spec (2 stages, no red team, no drafts) won't have the same depth as a full-mode spec. Don't penalize a quick spec for lacking multi-perspective analysis — it's designed for simpler issues. But DO flag if the issue complexity seems to have outgrown the mode chosen.

## Step 4: Decide What Happens Next

Based on your review:

**If the spec is ready (no blocking issues):**
- Approve it: `acorn approve <repo> <slug>`
- If the user wants implementation, proceed to Step 5

**If the spec needs minor fixes:**
- List the specific fixes needed
- Ask: "Should I flag these for the implementer to handle, or fix the spec first?"
- Minor gaps (like a missing error message format) can often be noted as implementation guidance rather than spec rewrites

**If the spec has significant gaps:**
- Present the issues clearly
- Suggest: "This might benefit from re-speccing with a different mode" or "The original issue might need clarification before re-speccing"
- Don't approve — the user should decide how to proceed

## Step 5: Implementation Handoff

This step only runs if the user wants implementation. There are two modes:

### Full Automation (user asked for it upfront)

If the original conversation implied end-to-end ("spec and implement", "full pipeline", "plan it then build it"), proceed without asking:

1. **Approve the spec:**
   ```bash
   acorn approve <repo> <slug>
   ```

2. **Create the worktree:**
   ```bash
   dev wt <repo> <feature-branch>
   ```
   Use a branch name derived from the issue slug — e.g., if the slug is `add-auth-system`, use that as the branch name.

3. **Start the implementation agent:**
   ```bash
   dev <repo>/<feature-branch>/pi
   ```

4. **Send the spec to the agent.** The spec lives in the main worktree, so tell the agent where to find it:
   ```
   Read the implementation spec at ~/Projects/<repo>/main/.specs/<slug>/plans/SPEC.md and implement it.
   Follow the spec's architecture, file placement, and testing strategy.
   Commit your work as you go. When done, tell me it's ready for review.
   ```

5. **Report to the user:**
   ```
   Spec approved and implementation started:
   - Worktree: ~/Projects/<repo>/<feature-branch>/
   - Agent session: dev <repo>/<feature-branch>/pi
   - Spec: .specs/<slug>/plans/SPEC.md

   The agent is implementing now. Check progress with:
     dev pi-status <repo>/<feature-branch> --messages 1
   ```

### Guided Handoff (default)

If the user didn't ask for full automation, walk them through the steps:

1. "I've approved the spec. Here's how to start implementation:"
2. Show the commands they'd run (worktree creation, agent start, spec path)
3. Offer to run each step if they want, but let them drive

### Review Notes for the Implementer

Whether automated or guided, include any review notes that would help the implementer. Things like:
- "The spec doesn't specify the error format for the rate limit endpoint — use the existing error envelope pattern from the auth module"
- "Redis connection pooling isn't mentioned — check if the existing pool supports the expected load"
- "The spec says 'use existing auth middleware' but doesn't name it — it's `requireAuth` in `src/middleware/auth.ts`"

These notes bridge the gap between what the spec says and what the implementer needs to know.

## Important Principles

**Review is not re-speccing.** You're checking quality and completeness, not rewriting the spec. If you find yourself wanting to redesign the architecture, that's a sign the spec needs to go back through the pipeline, not that you should fix it inline.

**Perfection is the enemy of shipping.** A spec that addresses 90% of concerns is usually good enough to implement — the remaining 10% can be noted for the implementer. Only block approval for genuinely blocking issues (missing data model, wrong architecture, doesn't solve the stated problem).

**Context determines automation level.** Pay attention to what the user originally asked for. "Review the spec" means stop after review. "Spec it, review it, and implement it" means go all the way through without stopping.

**Preserve traceability.** When you approve a spec, the label changes to `spec-approved` on the GitHub issue. When you hand off to an implementer, make sure they know which issue and spec they're working from. The chain should be unbroken: issue → spec → implementation.
