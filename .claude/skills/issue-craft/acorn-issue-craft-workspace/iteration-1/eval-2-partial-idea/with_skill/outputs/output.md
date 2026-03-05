# Issue Craft Output — API Rate Limiting for Candles

## Step 1: Understanding the Idea

**User input:**
> I want to add an API rate limiting system to candles. We're getting hammered by some clients making thousands of requests per minute and it's affecting other users. Should probably use Redis for the counters since we already have it running. Need different limits for free vs paid tiers.

**What I understand:**
- **What**: A rate limiting system for the candles API that throttles abusive clients
- **Who**: All API consumers benefit (they stop getting degraded service), and the platform operators benefit (infrastructure stays healthy)
- **Why**: Some clients are making thousands of requests/minute, degrading the experience for everyone else
- **Existing infrastructure**: Redis is already running, so using it for rate limit counters is practical

**What the user told us explicitly:**
- Redis-backed counters (they already have Redis)
- Tiered limits: free vs paid
- The triggering problem: clients making thousands of req/min, impacting others

**What the user did NOT specify (gaps I need to fill):**
- What the actual rate limits should be (requests per window for each tier)
- What window strategy to use (fixed window, sliding window, token bucket)
- What happens when a client hits the limit (HTTP 429? Retry-After header?)
- How clients are identified (API key? IP? User ID?)
- Whether there's an existing auth/tier system or if that needs to be built too
- Whether rate limits apply per-endpoint or globally
- Monitoring/alerting when limits are hit
- Whether there's an admin override or whitelist mechanism

## Step 2: Scope Check

This is a single, cohesive issue. Rate limiting is one system with one purpose — all the pieces (Redis counters, tier lookup, middleware, response headers) are tightly coupled and wouldn't be independently useful if shipped separately. There's no natural split here.

However, if there's no existing tier/auth system, that would be a prerequisite issue. I'm assuming the candles API already has some form of API key authentication and knows which tier a client belongs to. I'll note this assumption explicitly.

## Step 3: Draft Issue

---

### Title

**Add Redis-backed API rate limiting with tiered limits**

### Full Issue Body

```markdown
## Job Story
When our API is under heavy load from a few clients making thousands of requests per minute, I want the system to automatically throttle excessive usage per client based on their subscription tier, so that service quality remains consistent for all users and no single client can degrade the experience for others.

## Promise
After this ships: clients exceeding their tier's rate limit receive HTTP 429 responses with a Retry-After header indicating when they can resume. Free-tier clients are limited to a lower request ceiling than paid-tier clients. Clients staying within their limits see no change in API behavior or latency. Rate limit state is tracked in Redis and survives application restarts.

## Constraints
- Must use the existing Redis instance for rate limit counters (no new infrastructure dependencies)
- Must not add more than 5ms of latency to requests that are within their rate limit
- Existing API response formats and status codes for successful requests must not change
- Rate limiting middleware must be applied consistently across all API endpoints
- Must not require changes to client authentication flow — tier identification should use the existing auth/API key system
- Building a new subscription/tier management system is out of scope — this assumes the API can already determine a client's tier from their credentials

## Acceptance Criteria
- [ ] Rate limiting middleware is applied to all API endpoints
- [ ] Requests exceeding the rate limit return HTTP 429 (Too Many Requests) with a JSON error body
- [ ] 429 responses include a `Retry-After` header with the number of seconds until the client can retry
- [ ] Responses include standard rate limit headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- [ ] Free-tier and paid-tier clients have different rate limit ceilings (configurable, not hardcoded)
- [ ] Rate limit counters are stored in Redis with appropriate TTLs matching the rate limit window
- [ ] Rate limiting continues to function correctly if the application restarts mid-window (Redis state persists)
- [ ] If Redis is temporarily unavailable, requests are allowed through (fail-open) rather than blocking all traffic
- [ ] Rate limit overhead adds no more than 5ms latency to in-limit requests
- [ ] Rate limit hits are logged with client identifier and endpoint for operational visibility
- [ ] Rate limit configuration (limits per tier, window size) can be changed without code deployment (e.g., environment variables or config file)

## Context
- **Triggering problem**: Some clients are currently making thousands of requests per minute, causing service degradation for other users. This is an operational urgency, not a hypothetical need.
- **Infrastructure**: Redis is already running in the stack, making it the natural choice for distributed rate limit counters.
- **Algorithm consideration**: A sliding window or token bucket approach provides smoother rate limiting than fixed windows (which allow bursts at window boundaries). The spec agent should evaluate tradeoffs.
- **Client identification**: This issue assumes clients are identified by API key through the existing auth system. If clients can currently hit the API without authentication, that's a separate prerequisite issue.
- **Future consideration**: More granular per-endpoint limits or burst allowances could be added later but are not in scope here.
```

---

## Step 4: Presentation to User

I would present the draft above and ask:

> Does this capture what you want? A few things I assumed that you might want to adjust:
>
> 1. **I assumed you already have an auth system** that can identify clients and their tier. If that doesn't exist yet, we'd need a separate issue for that first.
> 2. **I proposed fail-open behavior** if Redis goes down (allow requests through rather than blocking everyone). Some teams prefer fail-closed for security. Which do you prefer?
> 3. **I left the actual numbers unspecified** (e.g., 100 req/min for free, 1000 req/min for paid) and instead made them configurable. Do you want specific defaults baked into the issue?
> 4. **I included rate limit response headers** (X-RateLimit-Limit, etc.) since clients will need visibility into their remaining quota. Is that something you want, or is it overkill for now?
>
> Anything to add or change?

## Step 5: Acorn Command (DRY RUN — would execute after user confirms)

```bash
acorn issue create candles "Add Redis-backed API rate limiting with tiered limits" --label ready-for-spec --body "## Job Story
When our API is under heavy load from a few clients making thousands of requests per minute, I want the system to automatically throttle excessive usage per client based on their subscription tier, so that service quality remains consistent for all users and no single client can degrade the experience for others.

## Promise
After this ships: clients exceeding their tier's rate limit receive HTTP 429 responses with a Retry-After header indicating when they can resume. Free-tier clients are limited to a lower request ceiling than paid-tier clients. Clients staying within their limits see no change in API behavior or latency. Rate limit state is tracked in Redis and survives application restarts.

## Constraints
- Must use the existing Redis instance for rate limit counters (no new infrastructure dependencies)
- Must not add more than 5ms of latency to requests that are within their rate limit
- Existing API response formats and status codes for successful requests must not change
- Rate limiting middleware must be applied consistently across all API endpoints
- Must not require changes to client authentication flow — tier identification should use the existing auth/API key system
- Building a new subscription/tier management system is out of scope — this assumes the API can already determine a client's tier from their credentials

## Acceptance Criteria
- [ ] Rate limiting middleware is applied to all API endpoints
- [ ] Requests exceeding the rate limit return HTTP 429 (Too Many Requests) with a JSON error body
- [ ] 429 responses include a \`Retry-After\` header with the number of seconds until the client can retry
- [ ] Responses include standard rate limit headers: \`X-RateLimit-Limit\`, \`X-RateLimit-Remaining\`, \`X-RateLimit-Reset\`
- [ ] Free-tier and paid-tier clients have different rate limit ceilings (configurable, not hardcoded)
- [ ] Rate limit counters are stored in Redis with appropriate TTLs matching the rate limit window
- [ ] Rate limiting continues to function correctly if the application restarts mid-window (Redis state persists)
- [ ] If Redis is temporarily unavailable, requests are allowed through (fail-open) rather than blocking all traffic
- [ ] Rate limit overhead adds no more than 5ms latency to in-limit requests
- [ ] Rate limit hits are logged with client identifier and endpoint for operational visibility
- [ ] Rate limit configuration (limits per tier, window size) can be changed without code deployment (e.g., environment variables or config file)

## Context
- **Triggering problem**: Some clients are currently making thousands of requests per minute, causing service degradation for other users. This is an operational urgency, not a hypothetical need.
- **Infrastructure**: Redis is already running in the stack, making it the natural choice for distributed rate limit counters.
- **Algorithm consideration**: A sliding window or token bucket approach provides smoother rate limiting than fixed windows (which allow bursts at window boundaries). The spec agent should evaluate tradeoffs.
- **Client identification**: This issue assumes clients are identified by API key through the existing auth system. If clients can currently hit the API without authentication, that's a separate prerequisite issue.
- **Future consideration**: More granular per-endpoint limits or burst allowances could be added later but are not in scope here."
```

After issue creation, I would report:

> Created issue #N. Since I drafted most of the content, the `ai-drafted` label was automatically added. If you feel the substance came from you, run `acorn issue clarify candles N` to swap it to `human-clarified`.
>
> To generate a spec: `acorn create candles N`

---

## Skill Execution Analysis

### What the user gave us (partial idea)
The user provided a conversational description with:
- The core problem (clients hammering the API)
- A technology preference (Redis)
- A business requirement (tiered limits)

### What the skill helped add
Following the skill's instructions, I:

1. **Extracted the real need** from "add rate limiting" — the actual problem is service degradation for other users, not rate limiting as an abstract goal
2. **Filled gaps with reasonable assumptions** (fail-open behavior, API key identification, configurable limits) and noted them explicitly for the user to confirm or override
3. **Added edge cases the user didn't mention**:
   - What happens when Redis goes down (fail-open vs fail-closed)
   - Rate limit response headers so clients have visibility
   - Latency budget for the middleware
   - Configuration without redeployment
   - Logging for operational visibility
   - Application restart resilience
4. **Pushed upstream on the solution**: The user said "use Redis" — I kept that as a constraint since it's justified (already running), but framed the issue around the problem (service degradation) rather than just the solution (rate limiting)
5. **Checked scope**: Confirmed this is one cohesive issue, not something that needs splitting
6. **Surfaced a potential prerequisite**: The auth/tier system dependency — if it doesn't exist, that's a separate issue
7. **Proposed clarifying questions** rather than just shipping the draft — the skill emphasizes refinement before creation
