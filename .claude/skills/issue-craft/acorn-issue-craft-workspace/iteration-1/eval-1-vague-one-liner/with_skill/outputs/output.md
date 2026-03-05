# Issue Craft: Dry Run Evaluation

## Input
**User said:** "replay needs a way to share stuff with other people"
**Repo:** replay

---

## Step 1: Understanding the Idea

This is a classic vague one-liner. Following the skill's guidance for this situation: "Don't just ask 20 questions. Make reasonable assumptions and present a draft: 'Here's what I think you mean -- correct me where I'm wrong.' Then refine."

Before jumping to a draft, I need to unpack what's ambiguous here:

| Dimension | What's unclear | Possible interpretations |
|-----------|---------------|--------------------------|
| **"share"** | Mechanism entirely unspecified | Share links, export data, invite collaborators, email reports, copy to clipboard, public URLs, permission-based access |
| **"stuff"** | What artifact is being shared? | Charts, dashboards, trading strategies, backtest results, opportunity alerts, watchlists, individual candle data, analysis configurations |
| **"other people"** | Relationship to the recipient | Teammates on the same account, external collaborators, the general public, specific individuals via email/link |
| **"a way"** | Singular or multiple mechanisms? | One sharing button, a whole sharing system, export functionality, collaboration features |

### What I would ask the user (efficient, conversational -- not an interrogation)

Rather than 20 questions, I'd ask 2-3 targeted ones:

> Here's what I want to nail down before I draft this:
>
> 1. **What are people sharing?** When you picture someone hitting "share," what are they looking at on screen? A chart? A dashboard? A backtest result? A specific trade setup?
>
> 2. **Who are they sharing with, and how?** Is this "send a link to a teammate who also uses replay" or "send a screenshot-like thing to someone on Discord/Slack who doesn't have an account"?
>
> 3. **What's the pain right now?** Are people currently screenshotting things and pasting them in chat? Or is there literally no way to show someone else what you're looking at?

---

## Step 2: Scope Check

Even without answers, this idea has clear signs of being multiple issues:

- **Sharing within the app** (authenticated users seeing each other's content) is a different feature than **sharing outside the app** (public/unauthenticated links)
- **What** is being shared matters: sharing a chart view is fundamentally different from sharing a trading strategy or a watchlist
- Read-only sharing vs. collaborative editing are different features
- The backend (generating shareable links, access control, permissions) is separable from the frontend (share buttons, share dialogs, link previews)

I'd flag this to the user: "This could easily be 2-4 issues depending on what you mean. Let me draft what I think the core use case is, and we can decide whether to split from there."

---

## Step 3: Draft Issue (Based on Reasonable Assumptions)

Since the user hasn't answered clarifying questions yet, I'd make reasonable assumptions and present a draft. My assumptions:

### Assumptions (stated explicitly)

1. **The most common "share" need is sharing a chart view or dashboard state** -- this is the most frequent thing users want to show others in trading tools.
2. **The recipient is someone external** (not necessarily a replay user) -- the simplest and most universal form of sharing.
3. **Read-only sharing via link** is the starting point -- not real-time collaboration.
4. **The pain is that people currently screenshot and lose context** -- no interactive sharing exists.

### Draft presented to user

> Here's what I think you mean -- correct me where I'm wrong:

---

### Issue Draft

**Title:** Add shareable links for chart views

**Body:**

```markdown
## Job Story
When I'm looking at a chart setup or analysis in replay that I want to discuss
with someone, I want to generate a shareable link that captures my current view,
so I can send it to another person and they can see exactly what I'm seeing
without me having to screenshot and lose interactivity.

## Promise
After this ships: any user can generate a unique URL for their current chart
view. Recipients who open the link see a read-only version of that exact chart
state -- same symbols, timeframe, indicators, and annotations. The link works
whether or not the recipient has a replay account.

## Constraints
- Read-only sharing only -- recipients cannot modify the shared view
- Shared links do not expose the sharer's account details, watchlists, or
  trading history beyond what is explicitly in the shared view
- No real-time collaboration or co-editing in this issue (future scope)
- Shared views are point-in-time snapshots; they do not live-update
- Must not require the recipient to create an account to view

## Acceptance Criteria
- [ ] User can click a "Share" button on any chart view to generate a unique URL
- [ ] The generated URL encodes the chart's symbol, timeframe, indicator
      configuration, and any annotations
- [ ] Opening the shared URL renders a read-only chart matching the original
      view state
- [ ] Shared links are accessible without authentication
- [ ] Shared links remain valid for at least 30 days after creation
- [ ] Private account data (positions, P&L, order history) is never included in
      shared views
- [ ] The share dialog provides a "Copy link" button that copies the URL to the
      clipboard

## Context
This is a foundational sharing feature. Future issues may build on this to add:
- Sharing dashboards (multi-chart layouts)
- Authenticated sharing with edit permissions
- Embedding shared views in external sites
- Sharing trading strategies or backtest results

Assumption: the primary use case is sending chart views to people via chat
(Slack, Discord, etc.) for discussion. If the actual need is different (e.g.,
sharing strategies, collaborative analysis), this issue should be revised.
```

---

## Step 4: Present and Refine

I would present the draft above and ask:

> Does this capture what you want? A few things I'd want to check:
>
> - Is it charts you want to share, or something else (strategies, backtests, watchlists)?
> - Should the shared view be a static snapshot, or should it show live-updating data?
> - Is "anyone with the link can see it" right, or do you need access controls (only specific people)?
>
> Also, if you want to share multiple types of things (charts AND strategies AND dashboards), I'd recommend splitting this into separate issues so each one gets a focused spec. We can start with whichever is most important.

### Likely refinement paths

Depending on user response, the issue might evolve:

| If they say... | I would adjust... |
|---|---|
| "Yeah, charts is right" | Proceed as drafted, maybe tighten the acceptance criteria |
| "Actually I mean sharing strategies/setups" | Rewrite the Job Story around strategy sharing; different data model |
| "I want to share everything" | Propose decomposition: Issue 1 = chart views, Issue 2 = strategies, Issue 3 = dashboards |
| "It needs to be live, not a snapshot" | Change Promise and add constraints around WebSocket/real-time considerations; flag complexity increase |
| "Only for team members" | Add authentication requirement, remove "no account needed" criterion |

---

## Step 5: Final Command (once user confirms)

Assuming the user confirms the draft as-is:

```bash
acorn issue create replay "Add shareable links for chart views" --label ready-for-spec --body "$(cat <<'EOF'
## Job Story
When I'm looking at a chart setup or analysis in replay that I want to discuss with someone, I want to generate a shareable link that captures my current view, so I can send it to another person and they can see exactly what I'm seeing without me having to screenshot and lose interactivity.

## Promise
After this ships: any user can generate a unique URL for their current chart view. Recipients who open the link see a read-only version of that exact chart state -- same symbols, timeframe, indicators, and annotations. The link works whether or not the recipient has a replay account.

## Constraints
- Read-only sharing only -- recipients cannot modify the shared view
- Shared links do not expose the sharer's account details, watchlists, or trading history beyond what is explicitly in the shared view
- No real-time collaboration or co-editing in this issue (future scope)
- Shared views are point-in-time snapshots; they do not live-update
- Must not require the recipient to create an account to view

## Acceptance Criteria
- [ ] User can click a "Share" button on any chart view to generate a unique URL
- [ ] The generated URL encodes the chart's symbol, timeframe, indicator configuration, and any annotations
- [ ] Opening the shared URL renders a read-only chart matching the original view state
- [ ] Shared links are accessible without authentication
- [ ] Shared links remain valid for at least 30 days after creation
- [ ] Private account data (positions, P&L, order history) is never included in shared views
- [ ] The share dialog provides a "Copy link" button that copies the URL to the clipboard

## Context
This is a foundational sharing feature. Future issues may build on this to add:
- Sharing dashboards (multi-chart layouts)
- Authenticated sharing with edit permissions
- Embedding shared views in external sites
- Sharing trading strategies or backtest results

Assumption: the primary use case is sending chart views to people via chat (Slack, Discord, etc.) for discussion. If the actual need is different (e.g., sharing strategies, collaborative analysis), this issue should be revised.
EOF
)"
```

Since this issue would be primarily AI-drafted (I wrote most of the content from a vague one-liner), the `ai-drafted` label would be automatically added by acorn. I'd mention to the user:

> Created issue #XX. Since I drafted most of this from your one-liner, it's tagged `ai-drafted`. If you've reviewed it and the substance reflects what you actually want, you can run `acorn issue clarify replay XX` to mark it as human-reviewed.
>
> To generate a spec: `acorn create replay XX`

---

## Summary of Skill Application

| Skill Principle | How It Was Applied |
|---|---|
| **"Don't just ask 20 questions"** | Asked 3 targeted questions, then moved to a draft with stated assumptions |
| **"Make reasonable assumptions and present a draft"** | Assumed chart-sharing via links based on most common sharing pattern in trading tools |
| **"Correct me where I'm wrong"** | Explicitly flagged assumptions in the Context section and in the refinement questions |
| **Push back on vagueness** | Called out that "share stuff" has at least 4 dimensions of ambiguity; proposed specific interpretation |
| **Check scope for splitting** | Identified this could be 2-4 issues; recommended starting with one and expanding |
| **Job Story quality** | Grounded in a real situation (looking at a chart, wanting to discuss it), specific action (generate a link), concrete outcome (other person sees exactly what I see) |
| **Promise is testable** | "Generate a unique URL" + "read-only version of that exact chart state" + "works without an account" -- all verifiable |
| **Constraints prevent scope creep** | Explicitly excluded: collaboration, live-updating, account-required access |
| **Acceptance criteria are independently verifiable** | Each criterion is a single testable condition with clear pass/fail |
| **Label management** | `ready-for-spec` label applied; noted `ai-drafted` auto-label and suggested `acorn issue clarify` path |
