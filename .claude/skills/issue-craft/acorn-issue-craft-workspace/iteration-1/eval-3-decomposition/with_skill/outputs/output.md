# Issue Craft: Notification System for Replay

## DRY RUN — No commands executed

---

## Step 1: Understanding the Idea

The user wants a notification system for the Replay application covering:

- **What**: A notification system that alerts users to events (replay processing complete, shares, comments) with delivery channel preferences (email vs in-app) and admin-managed templates.
- **Who**: End users who create, watch, and collaborate on replays; admins who manage the platform.
- **Why**: Users currently have no way to know when things happen that matter to them (a replay finishes, someone shares with them, comments appear). They have to manually check, which means missed events and slower collaboration.

### Clarifying Questions I Would Ask

Before proceeding, I would ask the user:

1. "Does Replay already have any notification infrastructure — even basic things like flash messages or email sends? Or is this completely greenfield?"
2. "When you say 'in-app' notifications, do you mean a notification bell/dropdown in the UI, or something else like toast popups?"
3. "For the admin template panel — is this for customizing the email/in-app message copy and layout, or more about defining new notification types?"
4. "Are there any existing email providers in the stack (SendGrid, SES, etc.) or is that a decision still to be made?"

However, following the skill's guidance for when a user provides a clear-enough picture, I'll make reasonable assumptions and note them explicitly.

### Assumptions

- No existing notification infrastructure exists; this is greenfield.
- "In-app" means a notification bell/dropdown with a list of notifications, plus unread count.
- Admin templates cover email subject/body and in-app message text for each notification type.
- Email delivery will use whatever transactional email provider the spec agent recommends (the issue should describe the problem, not prescribe the solution).
- WebSocket or polling for real-time in-app notification delivery is an implementation detail for the spec agent.

---

## Step 2: Scope Check — This Needs Splitting

This idea clearly needs decomposition. Here's why:

- **Multiple independent user-facing outcomes**: A user can benefit from in-app notifications without email, and vice versa. Notification preferences are usable only after at least one delivery channel exists. Admin templates are a separate admin-facing feature entirely.
- **Different subsystems**: Backend event/notification infrastructure, in-app UI components, email delivery pipeline, user preferences UI/API, admin panel — these are distinct areas.
- **Natural shipping boundaries**: You could ship in-app notifications alone and it would be immediately useful. Email can layer on after. Preferences make sense once both channels exist. Admin templates are an operational concern that can come last.
- **The acceptance criteria span unrelated areas**: Processing events, real-time UI, email rendering, preference management, and admin CRUD are all different concerns.

### Proposed Decomposition: 5 Issues

| # | Issue | Depends On | Rationale |
|---|-------|------------|-----------|
| 1 | Core notification infrastructure & event system | None | Foundation: event producers, notification storage, data model |
| 2 | In-app notification UI | #1 | First delivery channel: bell icon, dropdown, mark-as-read |
| 3 | Email notification delivery | #1 | Second delivery channel: email rendering and sending |
| 4 | User notification preferences | #1, #2, #3 | Preferences only make sense once both channels exist |
| 5 | Admin notification template management | #1, #3 | Admin panel for managing notification copy/templates |

---

## Step 3: Drafted Issues

### Issue 1: Add core notification infrastructure and event system

```markdown
## Job Story
When events happen that matter to a user — a replay finishes processing, someone shares a replay with them, or someone comments on their replay — I want those events captured and stored as notifications, so I can be informed through various delivery channels without polling or manually checking.

## Promise
After this ships: every notifiable event (replay processing complete, replay shared, comment added) produces a persisted notification record linked to the target user, with a consistent data model that downstream delivery channels (in-app, email) can consume. Events are produced reliably even under high load, and no notification is lost or duplicated.

## Constraints
- This issue covers the backend infrastructure only — no UI, no email sending, no user-facing delivery.
- Must not couple to a specific delivery mechanism; the notification model should be channel-agnostic.
- Must not add latency to the actions that produce notifications (replay processing, sharing, commenting) — event production should be asynchronous.
- Notification types must be extensible — adding a new event type in the future should not require schema changes.
- Must work with the existing database infrastructure (PostgreSQL/TimescaleDB).

## Acceptance Criteria
- [ ] A `notifications` table (or equivalent) exists with fields for: recipient user, notification type, payload/metadata, read status, created timestamp
- [ ] Replay processing completion produces a notification for the user who owns the replay
- [ ] Sharing a replay produces a notification for the recipient user
- [ ] Adding a comment on a replay produces a notification for the replay owner (and does NOT notify the commenter if they are the owner)
- [ ] Notifications are created asynchronously — the triggering action (share, comment, etc.) does not block on notification creation
- [ ] Notification payloads include enough context to render a human-readable message (replay title, sharer name, comment excerpt, etc.)
- [ ] API endpoints exist to: list notifications for the authenticated user (paginated), mark a notification as read, mark all as read
- [ ] Duplicate notifications are not created for the same event (idempotency)
- [ ] A notification type registry or enum exists that documents all supported types

## Context
This is the foundation for the full notification system. Issues #2-#5 (in-app UI, email delivery, user preferences, admin templates) all depend on this infrastructure being in place. Design the data model and event production with those downstream consumers in mind, but do not implement them here.
```

---

### Issue 2: Add in-app notification UI with real-time updates

```markdown
## Job Story
When I'm using Replay and something happens that I should know about — a replay finishes processing, someone shares a replay with me, or someone comments on my replay — I want to see a notification appear in the app without refreshing, so I can stay informed and respond quickly without leaving what I'm doing.

## Promise
After this ships: users see a notification bell in the app header with an unread count badge. Clicking it opens a dropdown showing recent notifications. New notifications appear in real-time without page refresh. Clicking a notification navigates to the relevant content (the replay, the comment, etc.) and marks it as read.

## Constraints
- Must use the notification API from the core infrastructure (Issue #1) — do not create a separate data store.
- Real-time delivery mechanism (WebSocket, SSE, polling) is an implementation decision, but the UI must update without manual refresh.
- Must work on both desktop and mobile viewport sizes.
- Must not introduce a new frontend framework or component library — use whatever the existing app uses.
- Notification dropdown should show at most 20 recent notifications with a "view all" link if more exist.
- Unread count badge should cap at "99+" for display purposes.

## Acceptance Criteria
- [ ] A notification bell icon appears in the app header for authenticated users
- [ ] The bell displays an unread count badge when there are unread notifications
- [ ] Clicking the bell opens a dropdown listing recent notifications (most recent first)
- [ ] Each notification shows: icon by type, human-readable message, relative timestamp ("2 min ago")
- [ ] Unread notifications are visually distinct from read ones
- [ ] Clicking a notification marks it as read and navigates to the relevant content
- [ ] A "mark all as read" action is available in the dropdown
- [ ] New notifications appear in real-time — when a notification is created server-side, it appears in the dropdown and the unread count increments without page refresh
- [ ] The dropdown is scrollable if there are many notifications
- [ ] A "view all" link navigates to a full-page notification history view
- [ ] Empty state is handled gracefully ("No notifications yet")

## Context
Depends on Issue #1 (core notification infrastructure) being complete. This is the first user-facing delivery channel. The notification content/copy will initially use hardcoded templates; Issue #5 (admin templates) will make them configurable later.
```

---

### Issue 3: Add email notification delivery

```markdown
## Job Story
When something important happens on a replay I care about — it finishes processing, someone shares one with me, or someone comments — I want to receive an email notification, so I can stay informed even when I'm not actively using the app.

## Promise
After this ships: users receive well-formatted email notifications for each event type. Emails include enough context to understand what happened (who, what, where) and a direct link back to the relevant content in Replay. Emails are delivered within 60 seconds of the triggering event. Emails are not sent for events the user triggered themselves (e.g., no email for your own comment).

## Constraints
- Must consume notifications from the core infrastructure (Issue #1) — do not create separate event detection.
- Must not send duplicate emails for the same notification.
- Must include an unsubscribe link in every email (CAN-SPAM / GDPR compliance).
- Must handle email delivery failures gracefully (retry with backoff, dead-letter after N failures).
- Email templates should be stored in a format that the admin panel (Issue #5) can later manage — avoid hardcoding HTML in application code.
- Must not send email for notifications already read in-app (if read within a short grace period — e.g., 2 minutes).

## Acceptance Criteria
- [ ] Email is sent for "replay processing complete" events — includes replay title and direct link
- [ ] Email is sent for "replay shared with you" events — includes sharer name, replay title, and direct link
- [ ] Email is sent for "comment on your replay" events — includes commenter name, comment excerpt, and direct link
- [ ] Emails render correctly in major email clients (Gmail, Outlook, Apple Mail)
- [ ] Each email contains a working unsubscribe link
- [ ] Emails are delivered within 60 seconds of the triggering event under normal conditions
- [ ] No duplicate emails are sent for the same notification
- [ ] Self-triggered events (e.g., commenting on your own replay) do not generate emails
- [ ] Failed email deliveries are retried with exponential backoff (at least 3 attempts)
- [ ] Email delivery status (sent, failed, bounced) is logged for observability

## Context
Depends on Issue #1 (core notification infrastructure). Works alongside Issue #2 (in-app notifications) as the second delivery channel. Issue #4 (user preferences) will allow users to opt out of email for specific notification types — until then, all users receive emails for all notification types by default. Issue #5 (admin templates) will make the email copy and layout admin-configurable.
```

---

### Issue 4: Add user notification preferences

```markdown
## Job Story
When I'm receiving notifications from Replay, I want to control which types of notifications I receive and through which channels (email vs in-app), so I can reduce noise from things I don't care about while still getting alerted to what matters to me.

## Promise
After this ships: users can visit a notification preferences page and toggle each notification type on or off per delivery channel (email, in-app). Preferences take effect immediately — changing a setting stops or starts delivery for that channel within seconds. Default preferences are sensible (all notifications enabled for both channels) so new users don't miss anything.

## Constraints
- Must integrate with both the in-app notification system (Issue #2) and email delivery (Issue #3) — preferences gate delivery, they don't prevent notification creation.
- Notifications are still created in the core system regardless of preferences — preferences only control delivery to channels.
- Must not require a page reload to save preferences.
- Must handle the case where a user has never set preferences (use defaults).
- The unsubscribe link in emails (from Issue #3) should link to this preferences page, pre-filtered to email settings.
- Must not introduce a separate auth flow — use the existing authenticated session.

## Acceptance Criteria
- [ ] A "Notification Preferences" page is accessible from user settings
- [ ] The page shows a matrix: rows are notification types (processing complete, shared with you, comment on replay), columns are channels (in-app, email)
- [ ] Each cell is a toggle (on/off) — users can independently control each type per channel
- [ ] Default state for new users: all notifications enabled for all channels
- [ ] Toggling a preference saves immediately (no separate save button needed) with visual confirmation
- [ ] After disabling email for a notification type, no emails are sent for that type (in-app still works if enabled)
- [ ] After disabling in-app for a notification type, no in-app notifications appear for that type (email still works if enabled)
- [ ] The unsubscribe link in notification emails navigates to this preferences page
- [ ] Preferences persist across sessions (stored server-side, not in local storage)
- [ ] API endpoint exists to read and update notification preferences for the authenticated user

## Context
Depends on Issue #1 (core notification infrastructure), Issue #2 (in-app notifications), and Issue #3 (email delivery) — preferences gate delivery across both channels, so both need to exist first. This could technically ship after just one channel exists, but the UI makes most sense when both channels are available to toggle.
```

---

### Issue 5: Add admin panel for notification template management

```markdown
## Job Story
When I'm an admin managing the Replay platform, I want to edit the content and layout of notification messages (both email and in-app) without deploying code, so I can update copy, fix typos, adjust messaging for campaigns, and localize notifications without involving engineering.

## Promise
After this ships: admins can view, edit, and preview all notification templates from an admin panel. Changes to templates take effect immediately for new notifications without a deploy. Each template supports variables (user name, replay title, etc.) that are dynamically populated. Admins can see which variables are available for each template type.

## Constraints
- Must support both email templates (HTML + plain text) and in-app message templates (plain text or light markdown).
- Must not allow template edits to break notification delivery — template validation must catch syntax errors before saving.
- Must preserve a revision history of template changes (who changed what, when) for audit purposes.
- Must be restricted to admin-role users only — regular users must not access this panel.
- Must not allow deletion of system-required templates — only editing.
- Template variables must be documented and validated (e.g., `{{user.name}}`, `{{replay.title}}`).

## Acceptance Criteria
- [ ] Admin panel includes a "Notification Templates" section accessible only to admin-role users
- [ ] All notification types are listed with their email and in-app templates
- [ ] Each template can be edited in-place with a rich text/code editor
- [ ] Available template variables are displayed alongside the editor for each notification type
- [ ] A preview function renders the template with sample data before saving
- [ ] Template syntax errors are caught and displayed on save attempt (template is not saved if invalid)
- [ ] Template changes take effect immediately for new notifications (no deploy required)
- [ ] A revision history shows past versions of each template with author and timestamp
- [ ] Admins can revert to a previous template version
- [ ] Email templates support both HTML and plain-text variants
- [ ] Non-admin users receive a 403 when attempting to access the template management API

## Context
Depends on Issue #1 (core notification infrastructure) for the notification type registry and on Issue #3 (email delivery) for the email template format. The initial email and in-app templates will be created as part of Issues #2 and #3 respectively — this issue makes them editable by admins without code changes.
```

---

## Step 4: Presentation and Dependency Summary

### Dependency Graph

```
Issue #1: Core notification infrastructure
  |
  +---> Issue #2: In-app notification UI
  |       |
  +---> Issue #3: Email notification delivery
  |       |         |
  |       |         +---> Issue #5: Admin notification template management
  |       |
  +-------+---------> Issue #4: User notification preferences
```

### Recommended Implementation Order

1. **Issue #1** (Core infrastructure) — Foundation, no dependencies
2. **Issue #2** (In-app UI) and **Issue #3** (Email delivery) — Can be parallelized, both depend only on #1
3. **Issue #4** (User preferences) — After both delivery channels exist
4. **Issue #5** (Admin templates) — After email delivery exists

### Pipeline Mode Recommendations

| Issue | Suggested Acorn Mode | Rationale |
|-------|---------------------|-----------|
| #1 Core infrastructure | `--lite` | Standard backend work — data model, events, API. Well-scoped but needs thoughtful design. |
| #2 In-app notification UI | `--lite` | Full-stack but focused. Real-time aspect adds some complexity. |
| #3 Email notification delivery | `--lite` | Standard backend + email templates. Well-understood domain. |
| #4 User notification preferences | `--quick` | Straightforward CRUD + UI. Clear requirements, minimal ambiguity. |
| #5 Admin notification template management | `--lite` | Admin panel with revision history and template validation has moderate complexity. |

---

## Step 5: Acorn Commands (DRY RUN — NOT EXECUTED)

Below are the exact commands that would be run. Each issue body is formatted for the `--body` flag.

### Issue 1

```bash
acorn issue create replay "Add core notification infrastructure and event system" \
  --label ready-for-spec \
  --body "## Job Story
When events happen that matter to a user — a replay finishes processing, someone shares a replay with them, or someone comments on their replay — I want those events captured and stored as notifications, so I can be informed through various delivery channels without polling or manually checking.

## Promise
After this ships: every notifiable event (replay processing complete, replay shared, comment added) produces a persisted notification record linked to the target user, with a consistent data model that downstream delivery channels (in-app, email) can consume. Events are produced reliably even under high load, and no notification is lost or duplicated.

## Constraints
- This issue covers the backend infrastructure only — no UI, no email sending, no user-facing delivery.
- Must not couple to a specific delivery mechanism; the notification model should be channel-agnostic.
- Must not add latency to the actions that produce notifications (replay processing, sharing, commenting) — event production should be asynchronous.
- Notification types must be extensible — adding a new event type in the future should not require schema changes.
- Must work with the existing database infrastructure (PostgreSQL/TimescaleDB).

## Acceptance Criteria
- [ ] A notifications table (or equivalent) exists with fields for: recipient user, notification type, payload/metadata, read status, created timestamp
- [ ] Replay processing completion produces a notification for the user who owns the replay
- [ ] Sharing a replay produces a notification for the recipient user
- [ ] Adding a comment on a replay produces a notification for the replay owner (and does NOT notify the commenter if they are the owner)
- [ ] Notifications are created asynchronously — the triggering action (share, comment, etc.) does not block on notification creation
- [ ] Notification payloads include enough context to render a human-readable message (replay title, sharer name, comment excerpt, etc.)
- [ ] API endpoints exist to: list notifications for the authenticated user (paginated), mark a notification as read, mark all as read
- [ ] Duplicate notifications are not created for the same event (idempotency)
- [ ] A notification type registry or enum exists that documents all supported types

## Context
This is the foundation for the full notification system. The in-app UI, email delivery, user preferences, and admin template management issues all depend on this infrastructure being in place. Design the data model and event production with those downstream consumers in mind, but do not implement them here."
```

### Issue 2

```bash
acorn issue create replay "Add in-app notification UI with real-time updates" \
  --label ready-for-spec \
  --body "## Job Story
When I'm using Replay and something happens that I should know about — a replay finishes processing, someone shares a replay with me, or someone comments on my replay — I want to see a notification appear in the app without refreshing, so I can stay informed and respond quickly without leaving what I'm doing.

## Promise
After this ships: users see a notification bell in the app header with an unread count badge. Clicking it opens a dropdown showing recent notifications. New notifications appear in real-time without page refresh. Clicking a notification navigates to the relevant content (the replay, the comment, etc.) and marks it as read.

## Constraints
- Must use the notification API from the core infrastructure issue — do not create a separate data store.
- Real-time delivery mechanism (WebSocket, SSE, polling) is an implementation decision, but the UI must update without manual refresh.
- Must work on both desktop and mobile viewport sizes.
- Must not introduce a new frontend framework or component library — use whatever the existing app uses.
- Notification dropdown should show at most 20 recent notifications with a 'view all' link if more exist.
- Unread count badge should cap at '99+' for display purposes.

## Acceptance Criteria
- [ ] A notification bell icon appears in the app header for authenticated users
- [ ] The bell displays an unread count badge when there are unread notifications
- [ ] Clicking the bell opens a dropdown listing recent notifications (most recent first)
- [ ] Each notification shows: icon by type, human-readable message, relative timestamp ('2 min ago')
- [ ] Unread notifications are visually distinct from read ones
- [ ] Clicking a notification marks it as read and navigates to the relevant content
- [ ] A 'mark all as read' action is available in the dropdown
- [ ] New notifications appear in real-time — when a notification is created server-side, it appears in the dropdown and the unread count increments without page refresh
- [ ] The dropdown is scrollable if there are many notifications
- [ ] A 'view all' link navigates to a full-page notification history view
- [ ] Empty state is handled gracefully ('No notifications yet')

## Context
Depends on the core notification infrastructure issue being complete. This is the first user-facing delivery channel. The notification content/copy will initially use hardcoded templates; the admin templates issue will make them configurable later."
```

### Issue 3

```bash
acorn issue create replay "Add email notification delivery" \
  --label ready-for-spec \
  --body "## Job Story
When something important happens on a replay I care about — it finishes processing, someone shares one with me, or someone comments — I want to receive an email notification, so I can stay informed even when I'm not actively using the app.

## Promise
After this ships: users receive well-formatted email notifications for each event type. Emails include enough context to understand what happened (who, what, where) and a direct link back to the relevant content in Replay. Emails are delivered within 60 seconds of the triggering event. Emails are not sent for events the user triggered themselves.

## Constraints
- Must consume notifications from the core infrastructure issue — do not create separate event detection.
- Must not send duplicate emails for the same notification.
- Must include an unsubscribe link in every email (CAN-SPAM / GDPR compliance).
- Must handle email delivery failures gracefully (retry with backoff, dead-letter after N failures).
- Email templates should be stored in a format that the admin panel can later manage — avoid hardcoding HTML in application code.
- Must not send email for notifications already read in-app (if read within a short grace period, e.g., 2 minutes).

## Acceptance Criteria
- [ ] Email is sent for 'replay processing complete' events — includes replay title and direct link
- [ ] Email is sent for 'replay shared with you' events — includes sharer name, replay title, and direct link
- [ ] Email is sent for 'comment on your replay' events — includes commenter name, comment excerpt, and direct link
- [ ] Emails render correctly in major email clients (Gmail, Outlook, Apple Mail)
- [ ] Each email contains a working unsubscribe link
- [ ] Emails are delivered within 60 seconds of the triggering event under normal conditions
- [ ] No duplicate emails are sent for the same notification
- [ ] Self-triggered events (e.g., commenting on your own replay) do not generate emails
- [ ] Failed email deliveries are retried with exponential backoff (at least 3 attempts)
- [ ] Email delivery status (sent, failed, bounced) is logged for observability

## Context
Depends on the core notification infrastructure issue. Works alongside the in-app notifications issue as the second delivery channel. The user preferences issue will allow users to opt out of email for specific notification types — until then, all users receive emails for all notification types by default. The admin templates issue will make the email copy and layout admin-configurable."
```

### Issue 4

```bash
acorn issue create replay "Add user notification preferences" \
  --label ready-for-spec \
  --body "## Job Story
When I'm receiving notifications from Replay, I want to control which types of notifications I receive and through which channels (email vs in-app), so I can reduce noise from things I don't care about while still getting alerted to what matters to me.

## Promise
After this ships: users can visit a notification preferences page and toggle each notification type on or off per delivery channel (email, in-app). Preferences take effect immediately — changing a setting stops or starts delivery for that channel within seconds. Default preferences are sensible (all notifications enabled for both channels) so new users don't miss anything.

## Constraints
- Must integrate with both the in-app notification system and email delivery — preferences gate delivery, they don't prevent notification creation.
- Notifications are still created in the core system regardless of preferences — preferences only control delivery to channels.
- Must not require a page reload to save preferences.
- Must handle the case where a user has never set preferences (use defaults).
- The unsubscribe link in emails should link to this preferences page, pre-filtered to email settings.
- Must not introduce a separate auth flow — use the existing authenticated session.

## Acceptance Criteria
- [ ] A 'Notification Preferences' page is accessible from user settings
- [ ] The page shows a matrix: rows are notification types (processing complete, shared with you, comment on replay), columns are channels (in-app, email)
- [ ] Each cell is a toggle (on/off) — users can independently control each type per channel
- [ ] Default state for new users: all notifications enabled for all channels
- [ ] Toggling a preference saves immediately (no separate save button needed) with visual confirmation
- [ ] After disabling email for a notification type, no emails are sent for that type (in-app still works if enabled)
- [ ] After disabling in-app for a notification type, no in-app notifications appear for that type (email still works if enabled)
- [ ] The unsubscribe link in notification emails navigates to this preferences page
- [ ] Preferences persist across sessions (stored server-side, not in local storage)
- [ ] API endpoint exists to read and update notification preferences for the authenticated user

## Context
Depends on the core notification infrastructure, in-app notifications, and email delivery issues. Preferences gate delivery across both channels, so both need to exist first."
```

### Issue 5

```bash
acorn issue create replay "Add admin panel for notification template management" \
  --label ready-for-spec \
  --body "## Job Story
When I'm an admin managing the Replay platform, I want to edit the content and layout of notification messages (both email and in-app) without deploying code, so I can update copy, fix typos, adjust messaging for campaigns, and localize notifications without involving engineering.

## Promise
After this ships: admins can view, edit, and preview all notification templates from an admin panel. Changes to templates take effect immediately for new notifications without a deploy. Each template supports variables (user name, replay title, etc.) that are dynamically populated. Admins can see which variables are available for each template type.

## Constraints
- Must support both email templates (HTML + plain text) and in-app message templates (plain text or light markdown).
- Must not allow template edits to break notification delivery — template validation must catch syntax errors before saving.
- Must preserve a revision history of template changes (who changed what, when) for audit purposes.
- Must be restricted to admin-role users only — regular users must not access this panel.
- Must not allow deletion of system-required templates — only editing.
- Template variables must be documented and validated.

## Acceptance Criteria
- [ ] Admin panel includes a 'Notification Templates' section accessible only to admin-role users
- [ ] All notification types are listed with their email and in-app templates
- [ ] Each template can be edited in-place with a rich text/code editor
- [ ] Available template variables are displayed alongside the editor for each notification type
- [ ] A preview function renders the template with sample data before saving
- [ ] Template syntax errors are caught and displayed on save attempt (template is not saved if invalid)
- [ ] Template changes take effect immediately for new notifications (no deploy required)
- [ ] A revision history shows past versions of each template with author and timestamp
- [ ] Admins can revert to a previous template version
- [ ] Email templates support both HTML and plain-text variants
- [ ] Non-admin users receive a 403 when attempting to access the template management API

## Context
Depends on the core notification infrastructure issue for the notification type registry and on the email delivery issue for the email template format. The initial email and in-app templates will be created as part of the in-app UI and email delivery issues respectively — this issue makes them editable by admins without code changes."
```

---

## Post-Creation Steps

After all 5 issues are created (suppose they receive numbers #101 through #105), the follow-up would be:

1. Update each issue's Context section with actual issue numbers for cross-references (e.g., "Depends on #101").
2. Report to the user:

> Created issues #101, #102, #103, #104, #105 for the Replay notification system.
>
> - **#101** Core notification infrastructure (no dependencies) — start here
> - **#102** In-app notification UI (depends on #101)
> - **#103** Email notification delivery (depends on #101)
> - **#104** User notification preferences (depends on #101, #102, #103)
> - **#105** Admin notification template management (depends on #101, #103)
>
> Issues #102 and #103 can be specced and implemented in parallel after #101 is complete.
>
> To spec them in dependency order:
> ```bash
> acorn create replay 101 --lite
> # After #101 is done, in parallel:
> acorn create replay 102 --lite
> acorn create replay 103 --lite
> # After both are done:
> acorn create replay 104 --quick
> acorn create replay 105 --lite
> ```
>
> Since these issues were primarily AI-drafted, they have the `ai-drafted` label. If you'd like to review and refine any of them, you can swap to `human-clarified` with `acorn issue clarify replay <issue#>`.

---

## Notes on the Skill's Influence on This Output

The skill guided this output in several specific ways:

1. **Scope check before drafting**: Rather than trying to write one massive issue, the skill's "Check the Scope" step identified multiple independent user-facing outcomes and different subsystems, leading to the 5-issue decomposition.

2. **JTBD structure enforced**: Every issue follows the Job Story / Promise / Constraints / Acceptance Criteria / Context template. The skill's guidance on making each section purposeful (not mechanical) shaped the specificity of promises and testability of acceptance criteria.

3. **Clarifying questions considered**: The skill advises asking questions but also says to make reasonable assumptions and note them explicitly when enough information is provided. The assumptions section reflects this balance.

4. **Dependency ordering**: The skill requires presenting multiple issues "in the order they'd be implemented (noting dependencies)." The dependency graph and implementation order address this directly.

5. **Concrete acceptance criteria**: The skill's examples of good vs bad criteria ("WebSocket connection establishes within 2 seconds" vs "it works correctly") pushed each criterion to be specific and independently verifiable.

6. **Problem over solution**: The skill advises describing problems, not solutions. The issues describe what users need without prescribing specific technologies (e.g., "real-time delivery mechanism is an implementation decision" rather than "use WebSockets").

7. **Labels and next steps**: The skill specifies adding `ready-for-spec` labels and suggesting `acorn issue clarify` for AI-drafted issues, both reflected in the commands and post-creation guidance.
