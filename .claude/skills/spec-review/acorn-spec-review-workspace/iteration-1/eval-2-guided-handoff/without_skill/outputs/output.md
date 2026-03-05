# Acorn Spec Review & Implementation Handoff: Rate Limiting (candles #18)

## Step 1: Check Spec Status

First I would verify the spec status and locate the files:

```bash
acorn list candles
```

**Expected output:**

```
candles specs:
  rate-limiting  #18  quick  review  .specs/rate-limiting/plans/SPEC.md
```

The status `review` confirms the agent finished and SPEC.md was written. The mode `quick` matches what you mentioned -- this used the 2-stage pipeline (3 Sonnet recon agents, 1 Opus direct spec).

I would also check the session to confirm the agent is done and not still working:

```bash
acorn status candles
```

**Expected output:**

```
candles:
  rate-limiting  session: candles_specs_rate-limiting_claude  status: dead (exited)
```

A dead/exited session confirms the agent completed its work.

---

## Step 2: Read the Spec

I would read the full spec and its supporting recon files:

```bash
# Read the spec itself
cat ~/Projects/candles/main/.specs/rate-limiting/plans/SPEC.md

# Also read recon for context on what the agents discovered
cat ~/Projects/candles/main/.specs/rate-limiting/recon/architecture.md
cat ~/Projects/candles/main/.specs/rate-limiting/recon/relevant_code.md
cat ~/Projects/candles/main/.specs/rate-limiting/recon/conventions.md
```

**Plausible SPEC.md contents for a quick-mode rate limiting spec:**

```markdown
# Implementation Spec: Rate Limiting (Issue #18)

## Overview
Add rate limiting to the candles API to prevent abuse and ensure fair usage
across clients. Implement a sliding window rate limiter backed by Redis with
per-endpoint and per-client controls.

## Architecture

### Approach: Redis Sliding Window
Use Redis sorted sets for a sliding window rate limiter. Each request adds a
timestamped entry; expired entries are pruned on each check. This provides
accurate rate tracking without the burst issues of fixed windows.

### Components
1. **Rate limit middleware** (`src/middleware/rate-limit.ts`)
   - Express/Koa middleware that intercepts requests before handlers
   - Extracts client identity (API key from header, fallback to IP)
   - Calls Redis to check/increment the window
   - Returns 429 with `Retry-After` header when limit exceeded

2. **Rate limit configuration** (`src/config/rate-limits.ts`)
   - Per-endpoint limit definitions
   - Default: 100 requests/minute for general endpoints
   - Elevated: 300 requests/minute for read-only data endpoints
   - Strict: 10 requests/minute for write/mutation endpoints

3. **Redis rate limit service** (`src/services/rate-limit.service.ts`)
   - `checkRateLimit(key: string, limit: number, windowMs: number): Promise<RateLimitResult>`
   - Returns `{ allowed: boolean, remaining: number, resetAt: number }`
   - Uses MULTI/EXEC for atomic check-and-increment

4. **Rate limit response headers**
   - `X-RateLimit-Limit`: max requests in window
   - `X-RateLimit-Remaining`: requests left
   - `X-RateLimit-Reset`: UTC epoch when window resets
   - `Retry-After`: seconds until next allowed request (on 429 only)

## Implementation Steps

### Step 1: Rate limit service
Create `src/services/rate-limit.service.ts` with the Redis sliding window
logic. Use the existing Redis connection from the project's Redis client.

### Step 2: Configuration
Create `src/config/rate-limits.ts` with endpoint-to-limit mappings.
Use environment variables for overrides:
- `RATE_LIMIT_DEFAULT` (default: 100)
- `RATE_LIMIT_WINDOW_MS` (default: 60000)

### Step 3: Middleware
Create `src/middleware/rate-limit.ts`. Wire it into the app's middleware
chain in `src/app.ts` or equivalent entry point.

### Step 4: Tests
- Unit tests for the rate limit service (mock Redis)
- Integration tests for the middleware (test 429 behavior)
- Verify correct headers on both allowed and rejected requests

## Edge Cases
- Redis unavailable: fail open (allow request, log warning)
- Missing API key: fall back to IP-based limiting
- Distributed deployments: Redis handles coordination naturally

## Acceptance Criteria (from issue)
- [ ] Requests are rate-limited per client
- [ ] 429 response includes Retry-After header
- [ ] Rate limits are configurable per endpoint
- [ ] System degrades gracefully if Redis is down
```

---

## Step 3: Review Assessment

Here is my assessment of this spec:

### What looks good

- **Clear architecture**: The sliding window approach via Redis sorted sets is a well-established pattern. It avoids the burst-at-boundary problem of fixed windows.
- **Fail-open design**: Correctly specified that Redis unavailability should not block requests -- this is the right call for a rate limiter.
- **Standard headers**: Uses the conventional `X-RateLimit-*` and `Retry-After` headers.
- **Testability**: Clear separation between the Redis service, config, and middleware makes each layer independently testable.
- **Matches acceptance criteria**: Every criterion from the issue is addressed in the spec.

### Things I would flag for your consideration

1. **Quick mode limitations**: This used quick mode (2 stages, no red team review). A full-mode spec would have had 4 red team agents stress-testing the design. For rate limiting, the quick spec is likely sufficient since this is a well-understood pattern, but worth noting.

2. **No mention of key expiry**: The spec should clarify that Redis sorted set keys get a TTL equal to the window size, so stale keys don't accumulate forever. This is an implementation detail the implementer should know about.

3. **Client identity extraction**: The spec says "API key from header, fallback to IP" but does not specify which header. The implementer will need to know if candles uses `Authorization`, `X-API-Key`, or something else. Worth checking against the existing codebase.

4. **No mention of rate limit bypass**: Should internal services or health check endpoints be exempt? Typically yes -- this is worth confirming.

These are minor items that the implementer can resolve during implementation by checking the existing codebase. None are blockers.

### Verdict

**The spec looks good for implementation.** The quick-mode pipeline produced a clean, actionable spec for a well-understood feature. I would recommend approving it.

---

## Step 4: Approve the Spec

With your agreement, I would run:

```bash
acorn approve candles rate-limiting
```

**Expected output:**

```
Approved: rate-limiting
Label updated: spec-approved
```

This marks the spec as approved and updates the GitHub issue label from `spec-review` to `spec-approved`.

---

## Step 5: Start Implementation

Here is the sequence to get implementation going:

### 5a. Create a worktree for the feature

```bash
dev wt candles rate-limiting
```

This creates:
- A new git worktree at `~/Projects/candles/rate-limiting/`
- A new branch `rate-limiting` off of `main`
- A tmux session `candles_rate-limiting`

### 5b. Start the agent session

```bash
dev candles/rate-limiting/pi
```

This opens (or attaches to) the `pi` sub-session inside the `candles_rate-limiting` tmux session. This is where the implementation agent will run.

### 5c. Give the agent its instructions

Inside the agent session, you would provide an initial prompt like:

```
Read the implementation spec at ~/Projects/candles/main/.specs/rate-limiting/plans/SPEC.md
and implement the rate limiting feature described there. Also read the recon files in
~/Projects/candles/main/.specs/rate-limiting/recon/ for codebase context.

Work incrementally: implement the rate limit service first, then config, then middleware,
then tests. Commit after each logical step.
```

The agent reads the SPEC.md from the `main` worktree (where acorn wrote it) and implements in the `rate-limiting` worktree.

### 5d. Monitor progress

From your main session, you can check on the agent:

```bash
dev pi-status candles_rate-limiting --messages 1
```

And check if it has queued questions:

```bash
dev queue-status candles_rate-limiting -m
```

### 5e. When implementation is complete

Once the agent confirms it is done:

```bash
# Review from main
cd ~/Projects/candles/main
git log rate-limiting --oneline

# If satisfied, merge locally
git merge rate-limiting

# Clean up the worktree, branch, and session
COMPOSE_PROJECT_NAME=candles-rate-limiting docker compose down -v
dev cleanup candles/rate-limiting
```

---

## Summary of Commands (in order)

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `acorn list candles` | Verify spec exists and status is `review` |
| 2 | `acorn status candles` | Confirm agent session is finished |
| 3 | Read SPEC.md + recon files | Review the spec content |
| 4 | `acorn approve candles rate-limiting` | Mark spec as approved |
| 5 | `dev wt candles rate-limiting` | Create implementation worktree |
| 6 | `dev candles/rate-limiting/pi` | Start agent sub-session |
| 7 | Provide implementation prompt | Agent begins work |
| 8 | `dev pi-status ...` | Monitor agent progress |
| 9 | `git merge rate-limiting` | Merge when done |
| 10 | `dev cleanup candles/rate-limiting` | Clean up worktree + session |

Would you like me to proceed with the approval step, or do you want to address any of the review items I flagged first?
