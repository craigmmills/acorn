# Notification System for Replay -- Issue Decomposition

## Analysis: Why This Needs Splitting

This request describes a "full notification system" that covers at least five distinct functional areas:

1. **Core notification infrastructure** -- the plumbing that generates, stores, and delivers notifications
2. **Specific notification triggers** -- processing complete, shared with you, comments on your replays
3. **In-app notification UI** -- how users see and interact with notifications in the product
4. **User notification preferences** -- per-channel (email vs in-app) configuration
5. **Admin panel for notification templates** -- admin-facing template management

These span different subsystems (backend infrastructure, frontend UI, email delivery, admin tooling), have different users (end users vs admins), and several could ship independently and provide value. Cramming all of this into a single issue would produce a sprawling spec that tries to design everything at once.

I would decompose this into **4 issues** with clear boundaries and a dependency chain.

---

## Proposed Decomposition

| # | Issue | Depends On | Ships Independently? |
|---|-------|------------|---------------------|
| 1 | Core notification infrastructure | -- | Yes (backend only, enables everything else) |
| 2 | In-app notification center & triggers | Issue 1 | Yes (users start seeing notifications) |
| 3 | User notification preferences & email delivery | Issues 1, 2 | Yes (users get control + email channel) |
| 4 | Admin notification template management | Issue 1 | Yes (admin tooling, parallel with 2/3) |

---

## Issue 1: Core Notification Infrastructure

### Title
Add core notification infrastructure with event-driven delivery pipeline

### Body

```markdown
## Job Story
When the replay platform needs to inform users about events (processing complete, shares, comments), there is currently no system to generate, store, route, or deliver those notifications -- so I want a foundational notification infrastructure that can accept events, resolve them into per-user notifications, persist them, and fan out to delivery channels, so that all future notification features have a reliable, extensible backbone to build on.

## Promise
After this ships: the platform has an internal notification service that can accept typed events, create notification records per recipient, persist them in the database, and expose them via an API. No user-facing UI ships in this issue -- this is the backend foundation.

## Constraints
- Must not couple to any specific delivery channel (email, in-app, push) -- channels are pluggable
- Must support multiple notification types with a type registry pattern (not hardcoded if/else)
- Must not introduce new external service dependencies without justification (prefer existing database and queue infrastructure)
- Notification records must be associated with a user and have read/unread state
- Must handle at-least-once delivery semantics; duplicate suppression is nice-to-have
- Historical notification retention policy is out of scope (can be added later)

## Acceptance Criteria
- [ ] Database schema exists for notifications (id, user_id, type, payload, read/unread, timestamps)
- [ ] Database schema exists for notification types/templates (type key, default template, channel defaults)
- [ ] A notification service module can accept a typed event and resolve it into one or more user notifications
- [ ] Notifications are persisted to the database on creation
- [ ] An internal API or service method can list notifications for a user (paginated, with read/unread filter)
- [ ] An internal API or service method can mark notifications as read (individually and bulk)
- [ ] The notification type registry supports adding new types without modifying core service logic
- [ ] Unit tests cover notification creation, retrieval, and read-state transitions
- [ ] Integration test demonstrates end-to-end: event in, notification record created, retrievable via API

## Context
This is the first issue in a 4-part notification system buildout. Issues 2-4 depend on this infrastructure. The design should anticipate multiple delivery channels (in-app, email) and user preferences, but does not need to implement them yet. The notification types that will be needed initially are: replay processing complete, replay shared with user, and comment on user's replay.
```

### Command

```bash
acorn issue create replay "Add core notification infrastructure with event-driven delivery pipeline" --label ready-for-spec --body "$(cat <<'BODY'
## Job Story
When the replay platform needs to inform users about events (processing complete, shares, comments), there is currently no system to generate, store, route, or deliver those notifications -- so I want a foundational notification infrastructure that can accept events, resolve them into per-user notifications, persist them, and fan out to delivery channels, so that all future notification features have a reliable, extensible backbone to build on.

## Promise
After this ships: the platform has an internal notification service that can accept typed events, create notification records per recipient, persist them in the database, and expose them via an API. No user-facing UI ships in this issue -- this is the backend foundation.

## Constraints
- Must not couple to any specific delivery channel (email, in-app, push) -- channels are pluggable
- Must support multiple notification types with a type registry pattern (not hardcoded if/else)
- Must not introduce new external service dependencies without justification (prefer existing database and queue infrastructure)
- Notification records must be associated with a user and have read/unread state
- Must handle at-least-once delivery semantics; duplicate suppression is nice-to-have
- Historical notification retention policy is out of scope (can be added later)

## Acceptance Criteria
- [ ] Database schema exists for notifications (id, user_id, type, payload, read/unread, timestamps)
- [ ] Database schema exists for notification types/templates (type key, default template, channel defaults)
- [ ] A notification service module can accept a typed event and resolve it into one or more user notifications
- [ ] Notifications are persisted to the database on creation
- [ ] An internal API or service method can list notifications for a user (paginated, with read/unread filter)
- [ ] An internal API or service method can mark notifications as read (individually and bulk)
- [ ] The notification type registry supports adding new types without modifying core service logic
- [ ] Unit tests cover notification creation, retrieval, and read-state transitions
- [ ] Integration test demonstrates end-to-end: event in, notification record created, retrievable via API

## Context
This is the first issue in a 4-part notification system buildout. Issues 2-4 depend on this infrastructure. The design should anticipate multiple delivery channels (in-app, email) and user preferences, but does not need to implement them yet. The notification types that will be needed initially are: replay processing complete, replay shared with user, and comment on user's replay.
BODY
)"
```

---

## Issue 2: In-App Notification Center and Event Triggers

### Title
Add in-app notification center with replay processing, sharing, and comment triggers

### Body

```markdown
## Job Story
When a replay I'm watching finishes processing, someone shares a replay with me, or someone comments on one of my replays, I want to see a notification appear in the app in real time so I can stay informed and take action without constantly checking or refreshing.

## Promise
After this ships: users see a notification indicator (e.g., bell icon with unread count) in the app, can open a notification center to view their notifications, and notifications are created automatically for three event types: replay processing complete, replay shared, and new comment on owned replay. Notifications appear within a few seconds of the triggering event.

## Constraints
- Depends on the core notification infrastructure (Issue 1) being in place
- Must integrate with the existing replay processing pipeline, sharing flow, and comment system -- not replace or modify their core behavior
- Must not block or slow down the triggering actions (notification creation should be async)
- Real-time delivery to the in-app UI is desired but a polling fallback is acceptable for v1
- Push notifications (mobile/desktop) are out of scope for this issue
- Email delivery is out of scope (handled in a separate issue)

## Acceptance Criteria
- [ ] A notification bell/icon is visible in the main app navigation showing unread count
- [ ] Clicking the notification icon opens a notification center showing recent notifications (paginated or infinite scroll)
- [ ] Each notification displays: type icon, human-readable message, timestamp, and read/unread state
- [ ] Clicking a notification marks it as read and navigates to the relevant resource (the replay or comment)
- [ ] A "mark all as read" action is available
- [ ] When a replay finishes processing, the owner receives an in-app notification
- [ ] When a user shares a replay with another user, the recipient receives an in-app notification
- [ ] When someone comments on a user's replay, the replay owner receives an in-app notification
- [ ] Notifications appear in the UI within 10 seconds of the triggering event (via WebSocket, SSE, or polling)
- [ ] The notification center handles the empty state gracefully (no notifications yet)
- [ ] Users do not receive notifications for their own actions (e.g., commenting on your own replay)

## Context
This is Issue 2 of 4 in the notification system. Depends on Issue 1 (core notification infrastructure). The three event triggers here (processing complete, share, comment) are the initial set requested by users. Additional trigger types can be added later via the notification type registry from Issue 1.
```

### Command

```bash
acorn issue create replay "Add in-app notification center with replay processing, sharing, and comment triggers" --label ready-for-spec --body "$(cat <<'BODY'
## Job Story
When a replay I'm watching finishes processing, someone shares a replay with me, or someone comments on one of my replays, I want to see a notification appear in the app in real time so I can stay informed and take action without constantly checking or refreshing.

## Promise
After this ships: users see a notification indicator (e.g., bell icon with unread count) in the app, can open a notification center to view their notifications, and notifications are created automatically for three event types: replay processing complete, replay shared, and new comment on owned replay. Notifications appear within a few seconds of the triggering event.

## Constraints
- Depends on the core notification infrastructure (Issue 1) being in place
- Must integrate with the existing replay processing pipeline, sharing flow, and comment system -- not replace or modify their core behavior
- Must not block or slow down the triggering actions (notification creation should be async)
- Real-time delivery to the in-app UI is desired but a polling fallback is acceptable for v1
- Push notifications (mobile/desktop) are out of scope for this issue
- Email delivery is out of scope (handled in a separate issue)

## Acceptance Criteria
- [ ] A notification bell/icon is visible in the main app navigation showing unread count
- [ ] Clicking the notification icon opens a notification center showing recent notifications (paginated or infinite scroll)
- [ ] Each notification displays: type icon, human-readable message, timestamp, and read/unread state
- [ ] Clicking a notification marks it as read and navigates to the relevant resource (the replay or comment)
- [ ] A "mark all as read" action is available
- [ ] When a replay finishes processing, the owner receives an in-app notification
- [ ] When a user shares a replay with another user, the recipient receives an in-app notification
- [ ] When someone comments on a user's replay, the replay owner receives an in-app notification
- [ ] Notifications appear in the UI within 10 seconds of the triggering event (via WebSocket, SSE, or polling)
- [ ] The notification center handles the empty state gracefully (no notifications yet)
- [ ] Users do not receive notifications for their own actions (e.g., commenting on your own replay)

## Context
This is Issue 2 of 4 in the notification system. Depends on Issue 1 (core notification infrastructure). The three event triggers here (processing complete, share, comment) are the initial set requested by users. Additional trigger types can be added later via the notification type registry from Issue 1.
BODY
)"
```

---

## Issue 3: User Notification Preferences and Email Delivery Channel

### Title
Add user notification preferences with per-type email vs in-app channel control

### Body

```markdown
## Job Story
When I'm receiving notifications in the app, I want to control which types of notifications I receive via email versus only in-app, so I can avoid inbox clutter for low-priority events while making sure I never miss important ones like someone sharing a replay with me.

## Promise
After this ships: users can access a notification preferences page from their settings, toggle each notification type on/off per channel (email and in-app independently), and the system respects those preferences when delivering notifications. Email notifications are sent for events where the user has opted in, using the notification template system.

## Constraints
- Depends on Issue 1 (core notification infrastructure) and Issue 2 (in-app notifications and triggers)
- Must not require users to configure preferences before notifications work -- sensible defaults must exist (e.g., all types enabled for in-app, only high-priority types enabled for email)
- Email sending must use a transactional email service or SMTP integration -- building a custom email sender from scratch is not acceptable
- Must not send email for notifications that the user has already seen in-app (or at minimum, respect a short delay before sending email to allow in-app consumption)
- Unsubscribe links in emails are required
- Bulk email operations and marketing emails are out of scope

## Acceptance Criteria
- [ ] A "Notification Preferences" section exists in user settings
- [ ] Users can toggle each notification type (processing complete, shared, comment) independently for each channel (in-app, email)
- [ ] Default preferences are applied for new users (all in-app on, email on for shares and comments, email off for processing complete)
- [ ] The notification delivery pipeline checks user preferences before sending to each channel
- [ ] Email notifications are sent for events where the user has email enabled for that type
- [ ] Emails include the notification content, a link to the relevant resource, and an unsubscribe link
- [ ] Changes to preferences take effect immediately for subsequent notifications
- [ ] Users who disable all channels for a type stop receiving that notification entirely
- [ ] Email delivery failures are logged and do not block in-app notification delivery
- [ ] Preference changes are persisted in the database and survive across sessions

## Context
This is Issue 3 of 4 in the notification system. Depends on Issues 1 and 2. The preferences model should be extensible -- when new notification types are added to the registry (Issue 1), they should automatically appear in the preferences UI with their default channel settings. The email templates used here will be manageable via the admin panel (Issue 4).
```

### Command

```bash
acorn issue create replay "Add user notification preferences with per-type email vs in-app channel control" --label ready-for-spec --body "$(cat <<'BODY'
## Job Story
When I'm receiving notifications in the app, I want to control which types of notifications I receive via email versus only in-app, so I can avoid inbox clutter for low-priority events while making sure I never miss important ones like someone sharing a replay with me.

## Promise
After this ships: users can access a notification preferences page from their settings, toggle each notification type on/off per channel (email and in-app independently), and the system respects those preferences when delivering notifications. Email notifications are sent for events where the user has opted in, using the notification template system.

## Constraints
- Depends on Issue 1 (core notification infrastructure) and Issue 2 (in-app notifications and triggers)
- Must not require users to configure preferences before notifications work -- sensible defaults must exist (e.g., all types enabled for in-app, only high-priority types enabled for email)
- Email sending must use a transactional email service or SMTP integration -- building a custom email sender from scratch is not acceptable
- Must not send email for notifications that the user has already seen in-app (or at minimum, respect a short delay before sending email to allow in-app consumption)
- Unsubscribe links in emails are required
- Bulk email operations and marketing emails are out of scope

## Acceptance Criteria
- [ ] A "Notification Preferences" section exists in user settings
- [ ] Users can toggle each notification type (processing complete, shared, comment) independently for each channel (in-app, email)
- [ ] Default preferences are applied for new users (all in-app on, email on for shares and comments, email off for processing complete)
- [ ] The notification delivery pipeline checks user preferences before sending to each channel
- [ ] Email notifications are sent for events where the user has email enabled for that type
- [ ] Emails include the notification content, a link to the relevant resource, and an unsubscribe link
- [ ] Changes to preferences take effect immediately for subsequent notifications
- [ ] Users who disable all channels for a type stop receiving that notification entirely
- [ ] Email delivery failures are logged and do not block in-app notification delivery
- [ ] Preference changes are persisted in the database and survive across sessions

## Context
This is Issue 3 of 4 in the notification system. Depends on Issues 1 and 2. The preferences model should be extensible -- when new notification types are added to the registry (Issue 1), they should automatically appear in the preferences UI with their default channel settings. The email templates used here will be manageable via the admin panel (Issue 4).
BODY
)"
```

---

## Issue 4: Admin Panel for Notification Template Management

### Title
Add admin panel for managing notification templates

### Body

```markdown
## Job Story
When I'm an admin and need to update the wording, formatting, or channel defaults of a notification (e.g., changing the email subject line for share notifications, or adjusting the in-app message copy), I want to edit notification templates through an admin interface so I can make copy changes without requiring a code deployment.

## Promise
After this ships: admins can view all registered notification types, edit their in-app and email templates (subject, body, variables), preview rendered templates with sample data, and update channel defaults -- all through a dedicated admin panel page. Template changes take effect for subsequent notifications without redeployment.

## Constraints
- Depends on Issue 1 (core notification infrastructure and type registry)
- Can be built in parallel with Issues 2 and 3 as long as Issue 1 is complete
- Must not allow admins to create or delete notification types through the UI -- type registration is code-driven
- Template editing must support variable interpolation (e.g., {{user_name}}, {{replay_title}}) but must not allow arbitrary code execution
- Must include a preview/test mode before saving changes
- Access must be restricted to admin-role users only
- Template versioning or history is nice-to-have but not required for v1

## Acceptance Criteria
- [ ] An "Notification Templates" page exists in the admin panel, accessible only to admin-role users
- [ ] The page lists all registered notification types with their current template content
- [ ] Admins can edit the in-app message template for each notification type
- [ ] Admins can edit the email template (subject and body) for each notification type
- [ ] Templates support variable interpolation with a defined set of variables per type
- [ ] A preview mode renders the template with sample data before saving
- [ ] Saved template changes take effect for all subsequent notifications (no deploy needed)
- [ ] Admins can reset a template to its default (code-defined) version
- [ ] Admins can edit the default channel settings per notification type (which channels are on by default for new users)
- [ ] Invalid template syntax (e.g., undefined variables) is caught and reported on save, not at notification send time
- [ ] The admin panel is not accessible to non-admin users (returns 403 or redirects)

## Context
This is Issue 4 of 4 in the notification system. Depends on Issue 1 (notification type registry and template schema). Can be implemented in parallel with Issues 2 and 3. The templates managed here are consumed by the delivery pipeline in Issue 3 (email) and Issue 2 (in-app).
```

### Command

```bash
acorn issue create replay "Add admin panel for managing notification templates" --label ready-for-spec --body "$(cat <<'BODY'
## Job Story
When I'm an admin and need to update the wording, formatting, or channel defaults of a notification (e.g., changing the email subject line for share notifications, or adjusting the in-app message copy), I want to edit notification templates through an admin interface so I can make copy changes without requiring a code deployment.

## Promise
After this ships: admins can view all registered notification types, edit their in-app and email templates (subject, body, variables), preview rendered templates with sample data, and update channel defaults -- all through a dedicated admin panel page. Template changes take effect for subsequent notifications without redeployment.

## Constraints
- Depends on Issue 1 (core notification infrastructure and type registry)
- Can be built in parallel with Issues 2 and 3 as long as Issue 1 is complete
- Must not allow admins to create or delete notification types through the UI -- type registration is code-driven
- Template editing must support variable interpolation (e.g., {{user_name}}, {{replay_title}}) but must not allow arbitrary code execution
- Must include a preview/test mode before saving changes
- Access must be restricted to admin-role users only
- Template versioning or history is nice-to-have but not required for v1

## Acceptance Criteria
- [ ] An "Notification Templates" page exists in the admin panel, accessible only to admin-role users
- [ ] The page lists all registered notification types with their current template content
- [ ] Admins can edit the in-app message template for each notification type
- [ ] Admins can edit the email template (subject and body) for each notification type
- [ ] Templates support variable interpolation with a defined set of variables per type
- [ ] A preview mode renders the template with sample data before saving
- [ ] Saved template changes take effect for all subsequent notifications (no deploy needed)
- [ ] Admins can reset a template to its default (code-defined) version
- [ ] Admins can edit the default channel settings per notification type (which channels are on by default for new users)
- [ ] Invalid template syntax (e.g., undefined variables) is caught and reported on save, not at notification send time
- [ ] The admin panel is not accessible to non-admin users (returns 403 or redirects)

## Context
This is Issue 4 of 4 in the notification system. Depends on Issue 1 (notification type registry and template schema). Can be implemented in parallel with Issues 2 and 3. The templates managed here are consumed by the delivery pipeline in Issue 3 (email) and Issue 2 (in-app).
BODY
)"
```

---

## Dependency Graph

```
Issue 1: Core notification infrastructure
   |
   +---> Issue 2: In-app notification center & triggers
   |        |
   |        +---> Issue 3: User preferences & email delivery
   |
   +---> Issue 4: Admin template management (parallel with 2 & 3)
```

## Recommended Implementation Order

1. **Issue 1** first -- everything depends on it
2. **Issue 2** and **Issue 4** can be worked in parallel after Issue 1 ships
3. **Issue 3** after Issue 2 (it extends the delivery pipeline with preferences and the email channel)

## Suggested Spec Pipeline Modes

| Issue | Recommended Mode | Rationale |
|-------|-----------------|-----------|
| 1 - Core infrastructure | `acorn create replay <N>` (full) | Foundational architecture decisions, schema design, extensibility patterns -- worth the full 14-agent treatment |
| 2 - In-app notifications | `acorn create replay <N> --lite` | Moderate complexity, integrates with existing UI and event flows |
| 3 - Preferences & email | `acorn create replay <N> --lite` | Moderate complexity, integrates preferences model with delivery pipeline |
| 4 - Admin templates | `acorn create replay <N> --lite` | Standard CRUD admin panel with template rendering |

---

## Questions I Would Ask Before Creating These Issues

Before actually running the commands, I would want the user to confirm:

1. **Does this decomposition make sense?** Four issues feels right for the scope, but the user might want to combine 2 and 3 (in-app + preferences) or split differently.

2. **Are the three notification triggers correct?** The user mentioned: processing complete, shared with you, and comments on your replays. Are there others they forgot to mention (e.g., mentions, followed replay updated)?

3. **Does an admin panel already exist?** If replay already has an admin section, Issue 4 should note that context. If not, this issue might need to include bootstrapping the admin panel infrastructure.

4. **What email infrastructure exists?** If replay already has transactional email (e.g., for account verification), Issue 3 should build on that. If not, the scope of Issue 3 grows significantly.

5. **Are the default preference settings right?** I assumed all in-app notifications on and selective email -- the user might have different opinions about defaults.

Once the user confirms the decomposition and addresses these questions, the four `acorn issue create` commands above would be run in sequence, with the dependency issue numbers updated in the Context sections to reference the actual GitHub issue numbers.
