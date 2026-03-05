# Issue Craft Response: API Rate Limiting for Candles

## Understanding the Idea

The user wants to add API rate limiting to the candles project because some clients are making thousands of requests per minute, degrading the experience for other users. They mentioned Redis (already in the stack) and tier-based limits (free vs paid).

Before drafting, there are a few things worth clarifying, but the user has given enough detail to produce a solid draft. I would note my assumptions explicitly and let them correct anything that is off.

**Assumptions I am making (would call these out to the user):**

- "Clients" means API consumers identified by API key or auth token
- "Free vs paid tiers" implies an existing concept of user tiers in the system
- The rate limit response should follow standard HTTP conventions (429 status, `Retry-After` header, `X-RateLimit-*` headers)
- Redis is the right place to track counters (user suggested it, and it is already running)
- The limits should be applied per-client, not globally

## Scope Check

This reads as a single issue. Rate limiting with tier-based configuration is a cohesive feature -- the tiers are not useful without the rate limiter, and the rate limiter needs tier awareness from the start. No split needed.

## Draft Issue

Here is the complete issue I would present to the user for review:

---

**Title:** Add tiered API rate limiting to protect service quality

---

### Job Story

When I am using the candles API during normal operations, I want the system to enforce per-client request limits, so that a single abusive or misconfigured client cannot degrade response times and availability for everyone else.

### Promise

After this ships: every API request is subject to a per-client rate limit based on the client's tier (free or paid). Clients exceeding their limit receive a clear 429 response with rate limit metadata. Other clients' request latency and availability are unaffected by any single client's traffic spike.

### Constraints

- Must use the existing Redis instance for rate limit counters (no new infrastructure)
- Existing API response contracts must not change for requests within limits
- Must not add more than 5ms of latency to requests under the rate limit
- Rate limit configuration (thresholds per tier) must be adjustable without code changes (config or environment variables)
- This issue covers server-side enforcement only; client-side SDKs or dashboard UI for viewing usage are out of scope

### Acceptance Criteria

- [ ] Every API request is checked against a per-client rate limit before processing
- [ ] Free-tier clients have a configurable request limit (e.g., 60 requests/minute)
- [ ] Paid-tier clients have a separate, higher configurable request limit (e.g., 600 requests/minute)
- [ ] Clients exceeding their rate limit receive an HTTP 429 (Too Many Requests) response
- [ ] 429 responses include a `Retry-After` header indicating when the client can retry
- [ ] All API responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers
- [ ] Rate limit counters are stored in Redis with appropriate TTLs (no manual cleanup needed)
- [ ] If Redis is temporarily unavailable, requests are allowed through (fail-open) rather than blocking all traffic
- [ ] Rate limit thresholds are configurable via environment variables or config file without redeployment
- [ ] Exceeding the rate limit for one client does not affect request processing for other clients
- [ ] Rate limit check adds no more than 5ms p99 latency to normal requests

### Context

- Redis is already running in the infrastructure and available to the application
- The immediate trigger is clients making thousands of requests per minute, impacting other users' experience
- The user mentioned Redis specifically for counters, which aligns well with sliding window or token bucket implementations
- Tier information (free vs paid) presumably comes from the existing auth/user system
- Standard algorithms to consider: sliding window log, sliding window counter, or token bucket -- the spec agent should evaluate tradeoffs

---

## Presented to User for Confirmation

I would show the above draft and ask:

> Does this capture what you want? A couple of things I want to confirm:
>
> 1. How are clients identified today -- API key, auth token, or something else?
> 2. Do you have specific numbers in mind for the free and paid limits, or should those just be configurable?
> 3. I assumed fail-open (allow requests if Redis goes down) rather than fail-closed (reject everything). Is that right for your use case?
> 4. Are there any endpoints that should be exempt from rate limiting (e.g., health checks)?

## Final Command

Once the user confirms, the command to create the issue would be:

```bash
acorn issue create candles "Add tiered API rate limiting to protect service quality" --label ready-for-spec --body "$(cat <<'EOF'
## Job Story
When I am using the candles API during normal operations, I want the system to enforce per-client request limits, so that a single abusive or misconfigured client cannot degrade response times and availability for everyone else.

## Promise
After this ships: every API request is subject to a per-client rate limit based on the client's tier (free or paid). Clients exceeding their limit receive a clear 429 response with rate limit metadata. Other clients' request latency and availability are unaffected by any single client's traffic spike.

## Constraints
- Must use the existing Redis instance for rate limit counters (no new infrastructure)
- Existing API response contracts must not change for requests within limits
- Must not add more than 5ms of latency to requests under the rate limit
- Rate limit configuration (thresholds per tier) must be adjustable without code changes (config or environment variables)
- This issue covers server-side enforcement only; client-side SDKs or dashboard UI for viewing usage are out of scope

## Acceptance Criteria
- [ ] Every API request is checked against a per-client rate limit before processing
- [ ] Free-tier clients have a configurable request limit (e.g., 60 requests/minute)
- [ ] Paid-tier clients have a separate, higher configurable request limit (e.g., 600 requests/minute)
- [ ] Clients exceeding their rate limit receive an HTTP 429 (Too Many Requests) response
- [ ] 429 responses include a `Retry-After` header indicating when the client can retry
- [ ] All API responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset` headers
- [ ] Rate limit counters are stored in Redis with appropriate TTLs (no manual cleanup needed)
- [ ] If Redis is temporarily unavailable, requests are allowed through (fail-open) rather than blocking all traffic
- [ ] Rate limit thresholds are configurable via environment variables or config file without redeployment
- [ ] Exceeding the rate limit for one client does not affect request processing for other clients
- [ ] Rate limit check adds no more than 5ms p99 latency to normal requests

## Context
- Redis is already running in the infrastructure and available to the application
- The immediate trigger is clients making thousands of requests per minute, impacting other users' experience
- Standard algorithms to consider: sliding window log, sliding window counter, or token bucket -- the spec agent should evaluate tradeoffs
- Tier information (free vs paid) presumably comes from the existing auth/user system
EOF
)"
```

After creation, the next step would be: `acorn create candles <issue#>` to kick off spec generation.

Since I drafted most of the content from the user's rough idea, the `ai-drafted` label would be automatically applied. If the user feels they provided the core substance and wants to indicate that, they could run `acorn issue clarify candles <issue#>` to swap the label to `human-clarified`.
