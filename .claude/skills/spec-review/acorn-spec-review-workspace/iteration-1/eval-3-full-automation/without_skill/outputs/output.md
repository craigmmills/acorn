# End-to-End Spec Review and Implementation Handoff: Issue #15 — Add Notification Infrastructure

## Phase 1: Orientation and Artifact Discovery

### Step 1.1: Verify spec status and metadata

**Command (dry run):**
```bash
acorn list replay
```

**Simulated output:**
```
REPO   SLUG                              ISSUE  MODE  STATUS   SESSION
replay add-notification-infrastructure   #15    full  review   replay_specs_add-notification-infrastructure_claude (dead)
```

The spec shows status `review`, meaning the planning pipeline has completed and SPEC.md exists. The session is dead (expected — the planning agent finished its work).

### Step 1.2: Confirm all full-mode artifacts exist

**Command (dry run):**
```bash
ls -la ~/Projects/replay/main/.specs/add-notification-infrastructure/
ls -la ~/Projects/replay/main/.specs/add-notification-infrastructure/recon/
ls -la ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/
```

**Simulated output:**
```
~/Projects/replay/main/.specs/add-notification-infrastructure/
  PROMPT.md
  meta.json
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

All 14-agent full-mode artifacts are present: 3 recon files, 4 drafts, 1 evaluation, 1 synthesis (master_plan), 4 red team reports, and the final SPEC.md.

---

## Phase 2: Red Team Report Review

Before reading SPEC.md itself, I would review the red team reports to understand what adversarial concerns were raised and whether the final spec addressed them. This is critical for full-mode reviews — the red team stage is the primary quality gate.

### Step 2.1: Read red team reports

**Command (dry run):**
```bash
# Read all four red team reports
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/red_team_1.md
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/red_team_2.md
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/red_team_3.md
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/red_team_4.md
```

**Simulated red team findings (consolidated):**

| Agent | Focus Area | Key Findings | Severity |
|-------|-----------|--------------|----------|
| Red Team 1 | Security & Auth | Notification payloads must sanitize user-generated content to prevent XSS in email/push templates; webhook signing secrets need rotation strategy | Medium |
| Red Team 2 | Scale & Performance | Bulk notification fan-out (e.g., system-wide announcements) needs rate limiting and batching to avoid overwhelming downstream providers; missing backpressure mechanism on the notification queue | High |
| Red Team 3 | Edge Cases & Reliability | No dead-letter queue specified for failed notifications; retry policy lacks exponential backoff with jitter; no idempotency key to prevent duplicate sends on retry | High |
| Red Team 4 | Integration & Migration | Missing migration strategy for existing users (default preference population); no feature flag for gradual rollout; webhook endpoint validation (URL reachability check) not specified | Medium |

### Step 2.2: Check evaluation scores

**Command (dry run):**
```bash
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/evaluation.md
```

**Simulated evaluation summary:**
```
Draft Scores (1-10):
  Draft 1 (event-driven architecture): 8.2 — Strong event bus design, weak on preference management
  Draft 2 (provider abstraction):      7.5 — Excellent provider layer, overcomplicated routing
  Draft 3 (queue-first approach):       8.7 — Best reliability story, clean separation of concerns
  Draft 4 (monolith-friendly):          6.8 — Pragmatic but insufficient scalability consideration

Recommendation: Draft 3 as primary basis, incorporating Draft 1's event taxonomy and Draft 2's provider abstraction layer.
```

---

## Phase 3: SPEC.md Review

### Step 3.1: Read the final spec

**Command (dry run):**
```bash
cat ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/SPEC.md
```

**Simulated SPEC.md structure and content summary:**

The SPEC.md would contain the following major sections, synthesized from the master plan with red team remediation:

#### 1. Overview
- **Issue:** #15 — Add Notification Infrastructure
- **Scope:** Build a notification system supporting email, in-app, and webhook channels with user preference management and reliable delivery guarantees.

#### 2. Architecture

```
GitHub Events / App Events
        |
   Event Bus (internal pub/sub)
        |
   Notification Router
   (preference check + channel selection)
        |
   +---------+---------+---------+
   | Email   | In-App  | Webhook |
   | Provider| Store   | Dispatcher|
   +---------+---------+---------+
        |         |          |
   [SES/SMTP] [Postgres] [HTTP POST]
        |         |          |
   Dead Letter Queue (failed notifications)
```

#### 3. Database Schema
- `notification_preferences` — per-user, per-event-type channel preferences
- `notifications` — notification log with status tracking (pending/sent/failed/read)
- `notification_templates` — channel-specific templates with variable interpolation
- `webhook_endpoints` — registered webhook URLs with signing secrets

#### 4. Implementation Plan (ordered tasks)
1. Database migrations for notification tables
2. Event taxonomy definition (enum of notification event types)
3. Core notification service with provider abstraction
4. Email provider (SES integration with template rendering)
5. In-app notification storage and read/unread API
6. Webhook dispatcher with HMAC signing
7. User preference management API (CRUD endpoints)
8. Notification router (preference lookup + fan-out)
9. Queue worker with retry policy (exponential backoff + jitter)
10. Dead-letter queue for permanently failed notifications
11. Bulk notification support with rate limiting
12. Default preference population migration for existing users
13. Feature flag for gradual rollout

#### 5. Red Team Remediation
The spec explicitly addresses red team findings:
- **XSS prevention:** Template rendering uses context-aware escaping (HTML for email, plaintext for webhooks)
- **Backpressure:** Queue worker uses concurrency limiter (max 10 concurrent sends) with configurable rate limit
- **Dead-letter queue:** Failed notifications after 3 retries move to DLQ with alerting
- **Retry policy:** Exponential backoff with jitter (base 1s, max 5min, factor 2)
- **Idempotency:** Each notification gets a UUID idempotency key; providers deduplicate on this key
- **Migration:** Existing users get default preferences (all channels enabled) via data migration
- **Feature flag:** `NOTIFICATIONS_ENABLED` feature flag gates the entire system
- **Webhook validation:** URL reachability check on registration (HEAD request, must return 2xx)
- **Secret rotation:** Webhook signing secrets support rotation with grace period (old key valid for 24h)

#### 6. Testing Strategy
- Unit tests for router logic, preference resolution, template rendering
- Integration tests for each provider (email via SES sandbox, webhook via httpbin)
- End-to-end test for full notification lifecycle
- Load test for bulk fan-out scenario

#### 7. Files to Create/Modify
- `src/services/notifications/` — new directory for notification service
- `src/services/notifications/index.ts` — main service entry point
- `src/services/notifications/router.ts` — preference-aware routing
- `src/services/notifications/providers/email.ts` — SES email provider
- `src/services/notifications/providers/in-app.ts` — in-app notification store
- `src/services/notifications/providers/webhook.ts` — webhook dispatcher
- `src/services/notifications/queue.ts` — queue worker with retry logic
- `src/services/notifications/templates.ts` — template rendering
- `src/api/routes/notifications.ts` — REST API endpoints
- `src/api/routes/preferences.ts` — preference management endpoints
- `src/db/migrations/XXXX_add_notification_tables.ts` — schema migration
- `src/db/migrations/XXXX_populate_default_preferences.ts` — data migration
- `tests/services/notifications/` — test suite

---

## Phase 3.2: Review Assessment

### Checklist

| Criterion | Pass/Fail | Notes |
|-----------|-----------|-------|
| All red team findings addressed in final spec | PASS | All 4 red team reports have corresponding remediation sections |
| Clear implementation ordering with dependencies | PASS | 13 ordered tasks with logical dependency chain |
| Database schema fully specified | PASS | 4 tables with columns, indices, and constraints described |
| Testing strategy covers unit/integration/e2e | PASS | All three levels specified with concrete examples |
| File manifest matches project conventions | PASS | Follows existing `src/services/` and `src/api/routes/` patterns per recon/conventions.md |
| No obvious gaps or contradictions | PASS | Architecture diagram matches implementation plan |
| Feature flag / rollout strategy | PASS | Feature flag specified with gradual rollout |
| Migration strategy for existing data | PASS | Default preference population migration included |
| Error handling and failure modes | PASS | DLQ, retries with backoff, idempotency keys |
| Scope creep beyond issue requirements | PASS | Stays within notification infrastructure scope |

### Verdict: APPROVED

The spec is comprehensive, addresses all red team concerns, follows project conventions, and has a clear implementation plan. No blocking issues found.

---

## Phase 4: Approve the Spec

### Step 4.1: Mark spec as approved

**Command (dry run):**
```bash
acorn approve replay add-notification-infrastructure
```

**Simulated output:**
```
Approved: add-notification-infrastructure
  Status: review → approved
  Label:  spec-review → spec-approved (on issue #15)
```

This updates `meta.json` with `"status": "approved"` and changes the GitHub label on issue #15 from `spec-review` to `spec-approved`.

---

## Phase 5: Create Worktree and Launch Implementation Agent

### Step 5.1: Create the worktree

**Command (dry run):**
```bash
dev wt replay add-notification-infrastructure
```

**Simulated output:**
```
Creating worktree: ~/Projects/replay/add-notification-infrastructure/
Branch: add-notification-infrastructure
Worktree created from main at abc1234
tmux session: replay_add-notification-infrastructure
```

This creates:
- A new git worktree at `~/Projects/replay/add-notification-infrastructure/`
- A local branch `add-notification-infrastructure` tracking the current `main` HEAD
- A tmux session `replay_add-notification-infrastructure`

### Step 5.2: Launch the implementation agent

**Command (dry run):**
```bash
dev replay/add-notification-infrastructure/pi
```

**Simulated output:**
```
Starting pi sub-session: replay_add-notification-infrastructure_pi
Launching Claude Code agent...
```

This creates a `pi` sub-session within the worktree's tmux session and starts a Claude Code agent inside it.

### Step 5.3: Send implementation instructions to the agent

**Command (dry run):**
```bash
# The agent is now running in the pi session. Send it the implementation prompt via tmux:
tmux send-keys -t replay_add-notification-infrastructure_pi "Read the approved implementation spec at ~/Projects/replay/main/.specs/add-notification-infrastructure/plans/SPEC.md and implement it in this worktree. This is for issue #15 in the replay repo. Follow the implementation plan ordering exactly. Commit your work as you go with meaningful commit messages. When done, let me know it's ready for review and merge into main." Enter
```

This sends the implementation instructions to the agent running in the pi session. The agent will:
1. Read SPEC.md from the main worktree's `.specs/` directory
2. Implement the notification infrastructure following the 13-step plan
3. Commit work incrementally
4. Signal completion

---

## Phase 6: Monitoring (Post-Handoff)

After launching the agent, I would periodically check on its progress:

### Check agent status
```bash
dev pi-status replay/add-notification-infrastructure --messages 1
```

### Check if work is queued
```bash
dev queue-status replay/add-notification-infrastructure -m
```

### When the agent signals completion, review the work
```bash
# Switch to the worktree and review commits
cd ~/Projects/replay/add-notification-infrastructure
git log --oneline main..HEAD
git diff main..HEAD --stat
```

### Run tests in Docker (isolated to this worktree)
```bash
cd ~/Projects/replay/add-notification-infrastructure
COMPOSE_PROJECT_NAME=replay-add-notification-infrastructure docker compose run --rm test
```

### If everything passes, merge into main
```bash
cd ~/Projects/replay/main
git merge add-notification-infrastructure
```

### Clean up
```bash
# Kill Docker environment for the feature
COMPOSE_PROJECT_NAME=replay-add-notification-infrastructure docker compose down -v

# Remove worktree + branch + session
dev cleanup replay/add-notification-infrastructure
```

---

## Summary of Actions Taken (Dry Run)

| Step | Action | Command | Status |
|------|--------|---------|--------|
| 1 | Check spec status | `acorn list replay` | Confirmed: full mode, status=review |
| 2 | Verify all artifacts | `ls .specs/add-notification-infrastructure/` | All 14-agent artifacts present |
| 3 | Review red team reports | Read `red_team_{1..4}.md` | 4 reports with Medium/High findings |
| 4 | Review evaluation scores | Read `evaluation.md` | Draft 3 selected as primary basis (8.7/10) |
| 5 | Review SPEC.md | Read `SPEC.md` | Comprehensive spec with 13 implementation tasks |
| 6 | Assess red team remediation | Cross-reference findings vs spec | All findings addressed |
| 7 | Approve spec | `acorn approve replay add-notification-infrastructure` | Status: approved, label: spec-approved |
| 8 | Create worktree | `dev wt replay add-notification-infrastructure` | Worktree + branch created |
| 9 | Launch agent | `dev replay/add-notification-infrastructure/pi` | Pi session started |
| 10 | Send instructions | `tmux send-keys` with implementation prompt | Agent working on implementation |

The entire flow from spec review to agent handoff would take approximately 5-10 minutes of human review time, with the agent then working autonomously on implementation.
