# Handling: "replay needs a way to share stuff with other people"

## Initial Assessment

The user's request is extremely vague. "Share stuff" and "other people" are undefined -- this could mean anything from sharing trade data with teammates, to generating public links for dashboards, to exporting CSV files, to real-time collaboration. Before creating a GitHub issue, I need to ask clarifying questions to understand what they actually want.

## What I Would Ask the User

Before drafting anything, I would respond with something like:

---

That's a broad request -- let me ask a few questions so we can write a sharp issue:

1. **What kind of "stuff" are people sharing?** For example: trading opportunities, portfolio views, charts, watchlists, configuration/settings, analysis reports, or something else?

2. **Who are "other people"?** Teammates on the same account? Other users on the platform? External people who don't have a Replay account?

3. **How should sharing work?** For example: copy a shareable link, invite by email, export a file they can send, real-time collaborative view, or something else?

4. **What's the trigger?** When does someone think "I need to share this"? Are they looking at something specific and want a colleague's input? Are they distributing a report on a schedule?

5. **Are there any privacy/permission concerns?** Should shared content be read-only? Should it expire? Should there be access controls?

6. **What's the urgency / scope preference?** Is this a quick MVP (e.g., "copy link to clipboard") or a full sharing system with permissions?

---

## Assumptions (if the user doesn't answer and says "just write something reasonable")

If the user pushes back and says to just draft something, I would make explicit assumptions:

- **Assumption 1:** "Stuff" means trading opportunities or portfolio views -- the core data objects in the app.
- **Assumption 2:** "Other people" means teammates within the same organization/account.
- **Assumption 3:** Sharing means generating a shareable link that another authenticated user can open to see the same view.
- **Assumption 4:** Shared views are read-only by default.
- **Assumption 5:** This is an MVP -- no granular permissions, no expiration, no external/unauthenticated sharing yet.

## Draft Issue

Based on those assumptions, here is what I would present to the user for confirmation:

---

**Title:** Add shareable links for trading views

**Body:**

```markdown
## Job Story
When I'm looking at a trading opportunity or portfolio view in Replay and want a colleague's input, I want to generate a shareable link I can send them, so I can get feedback without having to screenshot or describe what I'm seeing.

## Promise
After this ships: any authenticated user in the same organization can open a shared link and see the exact same view (data + layout) that the sharer was looking at when they created the link.

## Constraints
- Shared links must only be accessible to authenticated users in the same organization -- no public/unauthenticated access in this iteration.
- Shared views are read-only; the recipient cannot modify the sharer's data or layout.
- Sharing must not duplicate or fork underlying data -- it should reference the same source.
- Existing navigation, URLs, and deep-linking behavior must not break.

## Acceptance Criteria
- [ ] User can generate a shareable link from any trading opportunity or portfolio view via a "Share" action
- [ ] The generated link can be copied to clipboard with a single click
- [ ] An authenticated teammate who opens the link sees the same view (data, filters, layout) the sharer had
- [ ] An unauthenticated user or user outside the organization who opens the link receives an appropriate error or redirect to login
- [ ] Shared links remain valid as long as the underlying data exists (no arbitrary expiration in v1)
- [ ] The share action is discoverable in the UI without cluttering existing workflows

## Context
This is scoped as an MVP for internal team sharing. Future iterations could add: granular permissions, expiration, external/public sharing, and real-time collaborative views. The assumption is that "sharing" means link-based, read-only access for same-org teammates.

Assumptions made due to vague initial request -- please confirm or correct:
- "Stuff" = trading opportunities and portfolio views
- "Other people" = authenticated teammates in the same org
- Mechanism = shareable link (not export, not real-time collab)
- Read-only access, no permissions UI in v1
```

---

## Confirmation Step

I would present this draft and explicitly ask:

> Here's the draft issue. Before I create it, please review:
>
> 1. Does the Job Story match what you had in mind?
> 2. Are the assumptions at the bottom correct?
> 3. Anything to add or change in the acceptance criteria?
>
> Once you confirm (or tell me what to adjust), I'll create it.

## Final Command (after user confirms)

```bash
acorn issue create replay "Add shareable links for trading views" --body "$(cat <<'EOF'
## Job Story
When I'm looking at a trading opportunity or portfolio view in Replay and want a colleague's input, I want to generate a shareable link I can send them, so I can get feedback without having to screenshot or describe what I'm seeing.

## Promise
After this ships: any authenticated user in the same organization can open a shared link and see the exact same view (data + layout) that the sharer was looking at when they created the link.

## Constraints
- Shared links must only be accessible to authenticated users in the same organization -- no public/unauthenticated access in this iteration.
- Shared views are read-only; the recipient cannot modify the sharer's data or layout.
- Sharing must not duplicate or fork underlying data -- it should reference the same source.
- Existing navigation, URLs, and deep-linking behavior must not break.

## Acceptance Criteria
- [ ] User can generate a shareable link from any trading opportunity or portfolio view via a "Share" action
- [ ] The generated link can be copied to clipboard with a single click
- [ ] An authenticated teammate who opens the link sees the same view (data, filters, layout) the sharer had
- [ ] An unauthenticated user or user outside the organization who opens the link receives an appropriate error or redirect to login
- [ ] Shared links remain valid as long as the underlying data exists (no arbitrary expiration in v1)
- [ ] The share action is discoverable in the UI without cluttering existing workflows

## Context
This is scoped as an MVP for internal team sharing. Future iterations could add: granular permissions, expiration, external/public sharing, and real-time collaborative views. The assumption is that "sharing" means link-based, read-only access for same-org teammates.
EOF
)"
```

If the user also wants to immediately kick off spec generation, I would append `--lite` or `--quick` depending on perceived complexity, or suggest:

```bash
acorn issue plan replay "Add shareable links for trading views" --body "..." --lite
```

## Summary of Approach

| Step | Action |
|------|--------|
| 1. Identify vagueness | "share stuff" and "other people" are completely undefined |
| 2. Ask clarifying questions | 6 targeted questions covering what, who, how, when, permissions, scope |
| 3. State assumptions explicitly | If user doesn't clarify, document every assumption in the issue itself |
| 4. Draft complete issue | All 5 JTBD template sections filled with specific, testable content |
| 5. Present for confirmation | Show full draft, ask user to review before creating |
| 6. Execute command | Run `acorn issue create` only after user confirms |
