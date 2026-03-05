# Simulated Spec Review Output

**User prompt:** "The acorn spec for rate limiting in candles is done (issue #18, quick mode). Can you review it and if it looks good, walk me through getting implementation started?"

**Skill triggered:** `acorn-spec-review` -- matches "review" + "walk me through getting implementation started" (guided handoff, not full automation).

**Context detection:** The user said "walk me through," which maps to the **Guided Handoff** path (Step 5, second variant). They did NOT ask for full end-to-end automation. I should stop after review and present steps, letting them drive.

---

## Step 1: Locate the Spec

I would run these commands to find and read the spec materials:

```bash
acorn list candles
```

Expected output:
```
candles specs:
  rate-limiting (#18)  quick  review  .specs/rate-limiting/plans/SPEC.md
```

Then I would read these files in parallel:

- `~/Projects/candles/main/.specs/rate-limiting/plans/SPEC.md` -- the spec itself
- `~/Projects/candles/main/.specs/rate-limiting/PROMPT.md` -- original issue requirements
- `~/Projects/candles/main/.specs/rate-limiting/meta.json` -- mode and metadata
- `~/Projects/candles/main/.specs/rate-limiting/recon/architecture.md` -- project structure context
- `~/Projects/candles/main/.specs/rate-limiting/recon/relevant_code.md` -- relevant existing code
- `~/Projects/candles/main/.specs/rate-limiting/recon/conventions.md` -- coding patterns

Since this is quick mode, there would be NO drafts, evaluation, master plan, or red team reports in `plans/`. Quick mode produces only: 3 recon files + 1 direct SPEC.md.

**meta.json** would contain something like:
```json
{
  "repo": "candles",
  "issue": 18,
  "slug": "rate-limiting",
  "mode": "quick",
  "session": "candles_specs_rate-limiting_claude",
  "created": "2026-03-05T14:22:00Z"
}
```

**PROMPT.md** would contain the original GitHub issue content (Job Story, Promise, Constraints, Acceptance Criteria) plus the quick-mode planning methodology block.

**Simulated SPEC.md content** (plausible for a rate limiting feature in a trading/candles API):

The spec would describe adding request rate limiting to the candles API to prevent abuse and ensure fair usage. It would likely cover:
- A middleware-based approach using a token bucket or sliding window algorithm
- Redis as the backing store for rate limit counters
- Per-API-key rate limits with configurable thresholds
- Response headers (X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset)
- 429 Too Many Requests responses when limits are exceeded

---

## Step 2: Review the Spec

Here is the review I would produce, calibrated for quick mode (I would not penalize the spec for lacking multi-perspective drafts or red team analysis, since quick mode is designed for simpler issues with only 2 stages):

---

## Spec Review: Rate Limiting

**Mode**: quick | **Issue**: #18 | **Status**: Ready (with minor notes)

### Verdict

The spec is solid for a quick-mode output. It correctly identifies a middleware-based approach for rate limiting, uses Redis for distributed counter storage, and specifies the standard rate limit response headers. The architecture is straightforward and appropriate for the problem. There are a couple of minor gaps (noted below) that don't block implementation but should be flagged for the implementer. The issue complexity is well-suited to quick mode -- rate limiting is a well-understood pattern that doesn't need multi-perspective analysis.

### Completeness

- [x] Architecture and file placement defined -- middleware in `src/middleware/rate-limit.ts`, config in `src/config/rate-limit.ts`, integration in the Express/Fastify app entry point
- [x] Data model changes specified -- Redis key schema (`ratelimit:<api-key>:<window>`) with TTL-based expiry, no database migrations needed
- [x] API contracts defined -- 429 response shape, rate limit headers on all responses
- [ ] Error response format not fully specified -- the spec says "return 429 with error message" but doesn't explicitly define whether to use the existing error envelope pattern (e.g., `{ error: { code, message, details } }`) or a custom shape
- [x] Edge cases covered -- handles missing API key (falls back to IP-based limiting), Redis unavailability (fail-open vs. fail-closed decision documented)
- [ ] Testing strategy present but thin -- mentions "unit tests for the middleware and integration tests for the rate limit flow" but doesn't specify: test for concurrent requests hitting the same window, test for Redis failure fallback behavior, test for header correctness

### Feasibility

- No blocking technical risks identified
- Scope is proportional to the issue -- this is a standard rate limiting implementation, not over-engineered
- Redis dependency: the spec assumes Redis is available. This is likely fine for candles (needs verification that Redis is in the docker-compose and that the existing connection pool / client is accessible from the middleware layer)
- The token bucket algorithm choice is sound for API rate limiting -- no concerns about the algorithmic approach
- Performance: Redis INCR + EXPIRE is O(1), no performance concerns at expected scale

### Alignment

- **Job Story**: Addressed -- the spec delivers protection against API abuse and ensures fair usage across API consumers
- **Promise**: The spec fulfills the promise of rate-limited API access with clear feedback to consumers via headers and 429 responses
- **Constraints**: Respected -- stays within the existing middleware pattern, uses already-available Redis infrastructure
- **Red team**: N/A (quick mode -- no red team stage). The absence of adversarial review is acceptable given the straightforward nature of rate limiting, though it means edge cases like race conditions in the sliding window implementation got less scrutiny

### Action Items

1. **Minor (for implementer):** Clarify error response format -- use the existing error envelope pattern from the codebase (check `src/middleware/` or `src/utils/errors.ts` for the standard shape)
2. **Minor (for implementer):** Flesh out test scenarios during implementation -- specifically add tests for concurrent request handling, Redis failover behavior, and rate limit header accuracy across sequential requests
3. **Verify (before implementation):** Confirm Redis is available in the docker-compose setup and that the existing Redis client/pool is importable from the middleware layer

---

## Step 3: Decide What Happens Next

The spec is ready. The action items are minor and can be handled by the implementer rather than requiring a spec rewrite. I would approve it.

---

## Step 4: Guided Handoff

Since the user asked to be "walked through" implementation, this is the guided handoff path. Here is what I would present:

---

The spec looks good -- no blocking issues. Here is what I would do and say:

**Approve the spec:**

```bash
acorn approve candles rate-limiting
```

This marks the spec as approved and updates the GitHub issue label from `spec-review` to `spec-approved`.

**Then I'd walk the user through the implementation steps:**

I've approved the spec. Here is how to start implementation:

**1. Create a worktree for the feature:**

```bash
dev wt candles rate-limiting
```

This creates a new git worktree at `~/Projects/candles/rate-limiting/` with a `rate-limiting` branch.

**2. Start the implementation agent:**

```bash
dev candles/rate-limiting/pi
```

This opens a Claude Code session in the worktree.

**3. Send the spec to the agent:**

Once the agent is up, give it this instruction:

```
Read the implementation spec at ~/Projects/candles/main/.specs/rate-limiting/plans/SPEC.md and implement it.
Follow the spec's architecture, file placement, and testing strategy.
Commit your work as you go. When done, tell me it's ready for review.
```

**Implementation notes for the agent** (these bridge gaps I found in the review):

- The spec doesn't pin down the error response format for 429s. Use whatever error envelope pattern already exists in the candles codebase -- check `src/middleware/` or `src/utils/errors.ts` for the standard shape.
- The testing strategy in the spec is light. Make sure to include: (a) concurrent request tests against the same rate limit window, (b) Redis connection failure fallback tests, (c) verification that X-RateLimit-* headers are accurate across sequential requests within a window.
- Verify that the Redis client/pool used elsewhere in the codebase is accessible from the middleware layer before creating a new connection.

**4. Monitor progress:**

```bash
dev pi-status candles/rate-limiting --messages 1
```

Want me to run any of these steps?

---

## Summary of Skill Behavior

| Skill Step | What Happened |
|---|---|
| **Trigger detection** | "review" + "walk me through" matched the skill. Context = explicit review request + guided handoff (NOT full automation). |
| **Step 1: Locate** | Would read SPEC.md, PROMPT.md, meta.json, and all recon files. Noted quick mode = no drafts/red-team to review. |
| **Step 2: Review** | Evaluated across completeness, feasibility, alignment. Calibrated expectations for quick mode. Found 2 minor gaps (error format, thin test strategy) and 1 verification item (Redis availability). None blocking. |
| **Step 3: Present** | Used the prescribed checklist format with checkboxes, specific descriptions of gaps, and clear verdict. |
| **Step 4: Decide** | Spec is ready -- minor gaps noted for implementer. Approved. |
| **Step 5: Handoff** | Guided path (user said "walk me through"). Showed each command, explained what it does, included implementation notes bridging review gaps, offered to run steps on user's signal. |

### Key decisions the skill guided:

1. **Mode calibration**: Did not penalize the quick-mode spec for lacking multi-perspective analysis or red team reports. Noted the absence of red team as informational, not a deficiency.
2. **Guided vs. automated**: The user's phrasing ("walk me through") correctly routed to guided handoff rather than full automation. I presented commands and let the user drive.
3. **Action items as implementer notes**: The two minor gaps were flagged as notes for the implementer rather than blocking approval. This follows the "perfection is the enemy of shipping" principle from the skill.
4. **Traceability preserved**: The handoff instructions include the full spec path, issue number, and worktree naming derived from the slug, maintaining the issue-to-spec-to-implementation chain.
