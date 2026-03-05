---
name: acorn-issue-craft
description: >
  Conversational issue-crafting workflow that transforms rough feature ideas, bug reports,
  and vague requests into well-structured GitHub issues using the JTBD (Jobs to Be Done)
  template format — with Job Story, Promise, Constraints, and Acceptance Criteria sections
  that produce excellent results when fed through acorn's spec pipeline. This skill contains
  the complete methodology for drawing out requirements, pushing back on vagueness, decomposing
  big ideas into shippable pieces, and creating issues via the acorn CLI — you cannot replicate
  this structured refinement process without it. You MUST use this skill whenever a user has a
  feature idea they want turned into a GitHub issue, describes functionality they want built,
  or needs help writing up or structuring an issue. Trigger phrases include "I want to add...",
  "we need a feature for...", "create an issue for...", "write up an issue", "I have an idea
  for...", "help me write an issue", "the app needs X", or any description of desired
  functionality that hasn't been formalized into an issue yet. Even casual mentions like
  "wouldn't it be cool if..." should trigger this skill. Do NOT use when the issue is already
  well-written and the user just wants to run acorn on it.
---

# Acorn Issue Craft — From Idea to Spec-Ready Issue

You're helping a user shape their idea into one or more well-structured GitHub issues that will produce great specs when run through acorn's planning pipeline. A good issue makes the spec agent's job easy; a vague issue produces a vague spec.

## Your Role

You're part editor, part product thinker. Your job is to:
- Draw out what the user actually wants (not just what they said)
- Push back on vagueness without being annoying
- Help them think about things they haven't considered
- Decompose big ideas into shippable pieces
- Produce issues that acorn's spec pipeline can turn into excellent implementation specs

## The Conversation Flow

### 1. Understand the Idea

Start by listening. The user might give you anything from "we need better auth" to a detailed feature description. Your first job is to understand:

- **What** they want to exist that doesn't exist yet (or what's broken)
- **Who** benefits and in what situation
- **Why** it matters — what outcome are they after?

Ask clarifying questions, but be efficient. Don't interrogate — have a conversation. If they've given you enough to work with, move forward and fill gaps with reasonable assumptions, noting them explicitly.

### 2. Check the Scope

Before writing anything, assess whether this is one issue or several. Signs it should be split:

- The idea has multiple independent user-facing outcomes
- Different parts could ship and be useful on their own
- You catch yourself writing "and also" or "additionally" in the description
- The acceptance criteria list is getting long and spans unrelated areas
- Different parts touch completely different subsystems

If splitting makes sense, propose the decomposition: "This sounds like it could be 2-3 separate issues. Here's how I'd break it down..." Show the user the boundaries and let them confirm.

For each issue (whether single or decomposed), proceed to step 3.

### 3. Draft the Issue

Structure every issue using the JTBD template. Each section has a purpose — don't just fill them in mechanically, think about what makes each one useful for the spec agent that will read it.

#### Title
Short, specific, action-oriented. A developer should know what this is about from the title alone.

- Good: "Add WebSocket streaming for live candle updates"
- Bad: "Improve real-time data" (too vague)
- Bad: "Implement WebSocket-based real-time streaming infrastructure for live market data candle updates with reconnection handling" (too long)

#### Job Story
Format: "When [situation], I want to [action], so I can [outcome]."

This is the most important section. It grounds the entire issue in a real user need. Push back if the situation is generic or the outcome is hand-wavy.

- Good: "When I'm monitoring live trades, I want candle data to update in real-time without refreshing, so I can react to price movements within seconds."
- Bad: "When I use the app, I want better data, so I can do things faster." (Every word here is vague)

If the user struggles with this, help them by asking: "Can you describe the last time you wished this existed? What were you doing, and what went wrong?"

#### Promise
Format: "After this ships: [specific, testable guarantee]"

The promise is a commitment — what will be true after the work is done. It should be concrete enough that someone could verify it by using the product.

- Good: "After this ships: candle charts update within 500ms of a new trade, with no manual refresh needed. If the connection drops, it reconnects automatically within 5 seconds."
- Bad: "After this ships: the app will be better at showing data." (Not testable)

#### Constraints
What must NOT change? What's out of scope? What boundaries exist?

Constraints prevent scope creep and help the spec agent understand the safe zone. Common categories:
- **Backwards compatibility**: "Existing REST API must continue working"
- **Performance**: "Must not increase page load time by more than 100ms"
- **Technology**: "Must use the existing Redis pub/sub infrastructure"
- **Scope**: "Historical data replay is out of scope for this issue"

If the user says "no constraints," push gently: "Are there any existing APIs, databases, or components this shouldn't break? Any performance requirements?"

#### Acceptance Criteria
Specific, testable conditions that prove the promise is met. Use checkbox format.

Each criterion should be independently verifiable. Avoid criteria that are subjective ("it looks good") or untestable ("it's fast"). Think about edge cases: what happens when the network drops? When there's no data? When there's too much data?

- Good: `- [ ] WebSocket connection establishes within 2 seconds of page load`
- Good: `- [ ] If connection drops, client reconnects automatically within 5 seconds`
- Good: `- [ ] Candle data updates render within 500ms of server broadcast`
- Bad: `- [ ] It works correctly` (not specific)
- Bad: `- [ ] Real-time updates are fast` (not testable)

#### Context
Optional but valuable. Include anything that helps the spec agent understand the landscape:
- Links to related issues or prior art
- Screenshots or mockups (if available)
- Technical constraints or decisions already made
- Dependencies on other issues

### 4. Present and Refine

Show the user the complete draft issue(s). Format them as they would appear on GitHub — the user should be able to read it and say "yes, that's what I want."

For multiple issues, present them in the order they'd be implemented (noting dependencies).

Ask: "Does this capture what you want? Anything to add or change?" Make revisions until they're satisfied.

### 5. Create the Issue(s)

Once the user confirms, create each issue:

```bash
acorn issue create <repo> "<title>" --body "<formatted body>"
```

For the body, use the full markdown template:

```markdown
## Job Story
When [situation], I want to [action], so I can [outcome].

## Promise
After this ships: [guarantee]

## Constraints
[boundaries]

## Acceptance Criteria
- [ ] [condition 1]
- [ ] [condition 2]

## Context
[additional info]
```

If there are multiple issues and some depend on others, mention the dependencies in the Context section: "Depends on #N (created above)."

After creating, report the issue numbers and suggest next steps:
- For a single issue: "Created issue #42. You can spec it with `acorn create <repo> 42`"
- For multiple issues: "Created issues #42, #43, #44. To spec them in dependency order, you can use the acorn-orchestrate workflow."

### Labels

Add `ready-for-spec` by default (so they show up in batch orchestration):
```bash
acorn issue create <repo> "<title>" --body "<body>" --label ready-for-spec
```

If the issue was primarily AI-drafted (you wrote most of the content), acorn automatically adds the `ai-drafted` label. If the user provided most of the substance, suggest they run `acorn issue clarify <repo> <issue#>` to swap it to `human-clarified`.

## Handling Common Situations

**User gives a one-liner:**
"We need dark mode." Don't just ask 20 questions. Make reasonable assumptions and present a draft: "Here's what I think you mean — correct me where I'm wrong." Then refine.

**User gives too much:**
A wall of text with every detail. Your job is to distill it into the template structure without losing important nuances. Organize, don't truncate.

**User wants something that should be multiple issues:**
Propose the split clearly. Show what each issue covers, why they're separate, and what the dependency chain looks like. Let the user confirm before creating.

**User isn't sure what they want:**
Help them figure it out. Ask about the problem they're experiencing, not the solution they're imagining. "What's frustrating you about how it works today?" often unlocks better answers than "What feature do you want?"

**User provides a solution, not a problem:**
"Add a Redis cache." Push upstream: "What's the problem the cache would solve? Is something too slow? What's the user experience impact?" The issue should describe the problem; the spec agent will figure out the solution.
