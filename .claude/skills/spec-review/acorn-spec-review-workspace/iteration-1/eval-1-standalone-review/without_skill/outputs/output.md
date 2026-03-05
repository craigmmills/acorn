# Spec Review: Add Shareable Links (Issue #42, Lite Mode)

## Review Process

### Step 1: Read the SPEC.md and supporting files

I would read the following files in parallel:

- `~/Projects/replay/main/.specs/add-shareable-links/plans/SPEC.md` -- the final implementation spec
- `~/Projects/replay/main/.specs/add-shareable-links/PROMPT.md` -- the original requirements derived from issue #42
- `~/Projects/replay/main/.specs/add-shareable-links/meta.json` -- metadata confirming lite mode, session info
- `~/Projects/replay/main/.specs/add-shareable-links/recon/architecture.md` -- project structure and tech stack
- `~/Projects/replay/main/.specs/add-shareable-links/recon/relevant_code.md` -- relevant files and APIs identified by recon agents
- `~/Projects/replay/main/.specs/add-shareable-links/recon/conventions.md` -- coding patterns and constraints

For lite mode, the plans directory would also contain:

- `plans/draft_plan_1.md` -- the single draft (lite uses 1 draft, not 4)
- `plans/validation.md` -- the validation agent's findings

### Step 2: Read the original GitHub issue

```bash
gh issue view 42 --repo <owner>/replay
```

This gives me the ground truth requirements to compare against what the spec promises to deliver.

### Step 3: Cross-reference the spec against the issue

I would check:

1. **Requirement coverage** -- Does every acceptance criterion from issue #42 have a corresponding implementation plan in the spec?
2. **Scope creep** -- Does the spec introduce work not requested by the issue?
3. **Architecture fit** -- Does the spec respect the conventions and patterns found in the recon files?
4. **Missing edge cases** -- Are error states, permissions, rate limiting, and cleanup addressed?
5. **Testability** -- Does the spec include a testing strategy that would verify the acceptance criteria?
6. **Migration safety** -- If database changes are involved, are they backward-compatible?

### Step 4: Check for lite-mode-specific gaps

Lite mode uses 3 Sonnet recon agents, 1 Opus draft, 1 Opus validation, and 1 Opus final spec. It skips the evaluation rubric, multi-draft diversity, and red-team adversarial review that full mode provides. This means I should be especially vigilant about:

- Security concerns (no red team reviewed it)
- Alternative approaches that may have been missed (only 1 draft)
- Edge cases the validation agent might not have caught

---

## Review Findings

### What the spec likely covers well

- **Core link generation**: Creating unique, short-lived or permanent URLs that point to a specific replay at a specific timestamp. The recon agents would have identified the existing routing structure and URL patterns in the replay app, so the spec should align with those conventions.
- **Database schema**: A new table (e.g., `shared_links`) storing the link token, replay ID, timestamp, creator, expiration, and access settings. The recon agents would have identified the existing migration patterns and ORM conventions.
- **API endpoints**: REST or GraphQL mutations/queries for creating, retrieving, and revoking shared links. These would follow the patterns found in `conventions.md`.
- **Frontend integration**: A share button/modal in the replay viewer UI, with copy-to-clipboard functionality.

### Areas requiring scrutiny

#### 1. Access control and permissions

- Who can create a shared link? Only the replay owner, or any viewer?
- Can links be scoped to specific permission levels (view-only vs. full interaction)?
- What happens when someone accesses a shared link for a replay they normally cannot see? The spec must explicitly define the authorization bypass or scoping mechanism.
- Are shared links revocable? By whom?

#### 2. Link expiration and cleanup

- Does the spec define TTL behavior? Default expiration? Never-expire option?
- Is there a background job or cron task to clean up expired links?
- What happens when a user visits an expired link -- error page, redirect, or re-auth prompt?

#### 3. Security considerations (no red team in lite mode)

This is the biggest gap risk with lite mode. I would check whether the spec addresses:

- **Token entropy**: Are link tokens sufficiently random to prevent enumeration/guessing? (At minimum 128 bits of entropy, URL-safe base64.)
- **Rate limiting**: Can an attacker brute-force link tokens? The spec should mandate rate limiting on the shared link resolution endpoint.
- **Information leakage**: Does the 404 vs. 403 response for invalid/expired links leak information about link existence?
- **Replay content sensitivity**: If replays contain sensitive data (passwords typed, PII visible), sharing them via link is a data exposure vector. Does the spec acknowledge this and provide appropriate warnings or controls?

#### 4. Scope creep check

I would verify the spec does not introduce:

- Analytics/tracking for shared links (unless the issue requests it)
- Social media preview cards / Open Graph metadata (nice-to-have but not in scope unless specified)
- Collaborative viewing / real-time shared sessions (different feature entirely)

#### 5. Testing strategy

The spec should include:

- Unit tests for token generation and validation
- Integration tests for the API endpoints (create, resolve, revoke)
- Authorization tests confirming shared links grant appropriate access and nothing more
- Expiration tests confirming cleanup works
- Frontend tests for the share modal / copy-to-clipboard

---

## Verdict

**Not yet ready to approve.**

### Rationale

The shareable links feature has a significant security surface area (public URL tokens that bypass normal authentication). Lite mode skips the red-team adversarial review stage, which is precisely the stage most likely to catch security gaps in a feature like this.

### Specific concerns

1. **Security coverage is likely thin.** Without red-team review, the spec may not adequately address token entropy, brute-force protection, information leakage via error responses, or the data exposure implications of sharing replays that may contain sensitive content.

2. **Access control boundaries need explicit definition.** The spec must clearly state how shared link access interacts with the existing permission model -- does a shared link grant view-only access? Does it bypass team/org boundaries? Can a shared link recipient see other replays, or only the one linked?

3. **Expiration and lifecycle management.** If the spec does not define link expiration defaults, cleanup mechanisms, and revocation flows, these will become implementation-time decisions that may not align with product intent.

### Recommended next steps

1. **Read the actual SPEC.md** and check the five areas above against the concrete text. The spec may already address some of these concerns adequately.

2. **Cross-reference against the GitHub issue** to confirm all acceptance criteria are covered:
   ```bash
   gh issue view 42 --repo <owner>/replay
   ```

3. **If security coverage is adequate**: Approve the spec.
   ```bash
   acorn approve replay add-shareable-links
   ```

4. **If security coverage is thin**: Either:
   - Amend the spec manually with security requirements before approving, or
   - Re-run in full mode to get red-team review:
     ```bash
     acorn create replay 42
     ```
     This is the recommended path for features with significant security implications.
