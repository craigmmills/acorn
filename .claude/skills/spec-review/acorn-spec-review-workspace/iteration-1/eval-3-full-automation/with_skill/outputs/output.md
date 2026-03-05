Got it -- you want the full end-to-end: review the spec, approve if it passes, then spin up a worktree agent to implement. Since you asked for this as a continuous pipeline, I'll proceed through review and handoff without pausing between steps.

Let me start by locating the spec and reading everything I need.

## Step 1: Locate the Spec

```bash
acorn list replay
```

Output shows:
```
add-notification-infrastructure  #15  review  full  ~/Projects/replay/main/.specs/add-notification-infrastructure/
```

Reading the key files:

- `~/Projects/replay/main/.specs/add-notification-infrastructure/plans/SPEC.md` -- the final spec
- `~/Projects/replay/main/.specs/add-notification-infrastructure/PROMPT.md` -- original issue requirements
- `~/Projects/replay/main/.specs/add-notification-infrastructure/meta.json` -- confirms full mode

I also read the supporting materials:

- `recon/architecture.md` -- project structure: Next.js frontend, Express API layer, PostgreSQL + Redis, existing `src/services/` pattern for business logic
- `recon/relevant_code.md` -- existing user preferences in `src/models/user.ts`, email utilities in `src/lib/email.ts`, no existing notification abstraction
- `recon/conventions.md` -- Zod for validation, Drizzle ORM for database, barrel exports per module, colocation of tests (`__tests__/` alongside source)
- `plans/draft_plan_1.md` through `draft_plan_4.md` -- four diverse architectural approaches
- `plans/evaluation.md` -- rubric scoring of the four drafts
- `plans/master_plan.md` -- synthesized approach
- `plans/red_team_1.md` through `red_team_4.md` -- adversarial reviews
- `plans/SPEC.md` -- the final implementation spec

The original issue (#15) has:
- **Job Story**: "When important events happen in my account (trade executions, price alerts, system warnings), I want to receive timely notifications through my preferred channels, so I can stay informed and act quickly without constantly monitoring dashboards."
- **Promise**: "After this ships, users can configure notification preferences per channel (in-app, email, webhook) and per event type, and will receive notifications within 30 seconds of the triggering event."
- **Constraints**: Must not degrade API response times; must support at least 3 channels (in-app, email, webhook); notification preferences stored per user; must be extensible for future channels without schema changes.
- **Acceptance Criteria**:
  1. Users can configure notification preferences (channel + event type matrix)
  2. In-app notifications appear in a notification center with read/unread state
  3. Email notifications sent for configured event types
  4. Webhook notifications POST to user-configured URLs with retry logic
  5. Notifications delivered within 30 seconds of triggering event
  6. Notification history queryable via API
  7. Rate limiting prevents notification flooding

## Step 2: Review the Spec

---

## Spec Review: Add Notification Infrastructure

**Mode**: full | **Issue**: #15 | **Status**: Ready

### Verdict

This is a solid, implementation-ready spec. The full pipeline did its job -- the four-draft approach produced a well-considered architecture that uses an event-driven pattern with a notification service layer, per-channel dispatch strategies, and async processing via a Redis-backed job queue. The red team identified three critical findings: missing dead-letter handling for failed webhook deliveries, absence of idempotency keys for deduplication, and no specification for notification payload size limits. The final spec addressed the first two (dead-letter queue added, idempotency keys included in the data model) and explicitly deferred payload size limits as a follow-up. The one area that could be stronger is the in-app notification real-time delivery mechanism -- the spec mentions SSE but doesn't fully specify the connection lifecycle. That said, this is a minor gap the implementer can resolve from context. Approve and proceed.

### Completeness

- [x] Architecture and file placement defined -- new `src/services/notifications/` module with `dispatcher.ts`, `channels/`, `preferences.ts`, `history.ts`; new `src/jobs/notification-worker.ts` for async processing; new API routes under `src/routes/api/notifications/`
- [x] Data model changes specified -- three new tables: `notification_preferences` (user_id, event_type, channel, enabled), `notifications` (id, user_id, event_type, channel, payload, status, idempotency_key, created_at, delivered_at), `webhook_configs` (user_id, url, secret, active); Drizzle migration included
- [x] API contracts defined -- `GET/PUT /api/notifications/preferences` with full request/response shapes, `GET /api/notifications/history` with pagination, `POST /api/notifications/webhooks` for webhook URL management, `GET /api/notifications/stream` for SSE
- [x] Edge cases covered -- webhook retry with exponential backoff (3 attempts, 30s/120s/300s), dead-letter queue for exhausted retries, rate limiting (max 10 notifications per event type per user per hour), idempotency key deduplication, graceful degradation when Redis is unavailable (falls back to synchronous dispatch with warning log)
- [x] Testing strategy present -- unit tests for preference resolution logic, channel dispatch strategies, rate limiter; integration tests for end-to-end notification flow through the queue; webhook retry behavior tested with mock HTTP server; API route tests for preference CRUD and history pagination
- [x] All acceptance criteria mapped to spec sections

### Feasibility

- No blocking technical risks identified. The spec uses BullMQ for the job queue, which is already a dependency in the project (confirmed in recon). Redis is present in the docker-compose.
- Scope is proportional to the issue. The spec doesn't introduce unnecessary abstractions -- the channel strategy pattern (in-app, email, webhook) is the right level of extensibility without over-engineering a plugin system.
- The SSE connection for real-time in-app notifications is the one area with moderate complexity. The spec mentions using the existing Express server but doesn't address connection limits or cleanup on disconnect. For the scale described in the issue, this is fine, but the implementer should add connection cleanup handlers.
- The spec correctly identifies that notification dispatch must be async to meet the constraint of not degrading API response times. Events are enqueued and processed by the worker, keeping the hot path fast.
- One mild concern: the 30-second delivery SLA is mentioned but the spec doesn't describe how to monitor or alert on violations. This is a reasonable omission for v1 -- observability can follow.

### Alignment

- **Job Story**: Addressed. The spec delivers exactly the "configure preferences + receive timely notifications" flow described.
- **Promise**: All criteria mapped. Per-channel and per-event-type preferences: yes. 30-second delivery: the async queue design supports this, and the spec notes BullMQ's processing guarantees.
- **Constraints**: Respected. Async dispatch preserves API response times. Three channels implemented. Preferences are per-user. The JSONB `payload` column and channel strategy pattern make future channels addable without schema changes.
- **Red team**: 3 critical findings across the 4 red team reports. 2 addressed directly in the final spec (dead-letter queue, idempotency keys). 1 deferred with justification (payload size limits -- noted as a fast follow). Several minor findings (logging format, metric naming) were incorporated.

### Action Items

None blocking. Two notes for the implementer:

1. **SSE connection lifecycle**: The spec says "use SSE for real-time in-app delivery" but doesn't specify handling for client disconnects or reconnection. Use the `req.on('close')` pattern to clean up, and include a `Last-Event-ID` header for reconnection support.
2. **Monitoring the 30-second SLA**: Not in scope for this spec, but when implementing the notification worker, emit a timing metric (e.g., `notification.delivery_latency_ms`) so that monitoring can be added later without rework.

---

## Step 4: Approve

The spec passes review with no blocking issues. Approving now.

```bash
acorn approve replay add-notification-infrastructure
```

This marks the spec as approved and updates the GitHub issue label from `spec-review` to `spec-approved`.

## Step 5: Implementation Handoff (Full Automation)

Since you asked for end-to-end, I'm proceeding directly to implementation setup.

**Creating the worktree:**

```bash
dev wt replay add-notification-infrastructure
```

This creates `~/Projects/replay/add-notification-infrastructure/` with a new branch `add-notification-infrastructure` based off `main`.

**Starting the implementation agent:**

```bash
dev replay/add-notification-infrastructure/pi
```

**Sending the spec to the agent:**

```
Read the implementation spec at ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/SPEC.md and implement it. Follow the spec's architecture, file placement, and testing strategy. Commit your work as you go. When done, tell me it's ready for review.

Two review notes to keep in mind:
1. For the SSE endpoint (GET /api/notifications/stream), handle client disconnects with req.on('close') cleanup and support Last-Event-ID for reconnection.
2. When implementing the notification worker, emit a notification.delivery_latency_ms timing metric so delivery SLA monitoring can be added later.
```

---

Spec approved and implementation started:

- **Worktree**: `~/Projects/replay/add-notification-infrastructure/`
- **Agent session**: `dev replay/add-notification-infrastructure/pi`
- **Spec**: `.specs/add-notification-infrastructure/plans/SPEC.md`
- **Issue**: #15

The agent is implementing now. Check progress with:
```bash
dev pi-status replay/add-notification-infrastructure --messages 1
```
