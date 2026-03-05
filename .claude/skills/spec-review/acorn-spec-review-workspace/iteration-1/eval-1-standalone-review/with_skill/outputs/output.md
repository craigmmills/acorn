# Spec Review Simulation: Shareable Links Feature (replay #42)

This document simulates a full spec review following the `acorn-spec-review` skill, applied to a hypothetical "shareable links" SPEC.md for the replay repo. Since no actual SPEC.md or repo exists, each step describes what I would do, what I would look for, and then produces the actual review artifact the skill prescribes.

---

## Step 1: Locate the Spec

### What I would do

Run the following commands to gather all materials:

```bash
# Verify the spec exists and check its status
acorn list replay

# Read the spec itself
# File: ~/Projects/replay/main/.specs/add-shareable-links/plans/SPEC.md

# Read supporting materials
# ~/Projects/replay/main/.specs/add-shareable-links/PROMPT.md        (original requirements)
# ~/Projects/replay/main/.specs/add-shareable-links/meta.json         (metadata + mode)
# ~/Projects/replay/main/.specs/add-shareable-links/recon/architecture.md
# ~/Projects/replay/main/.specs/add-shareable-links/recon/relevant_code.md
# ~/Projects/replay/main/.specs/add-shareable-links/recon/conventions.md
```

Since this was generated in **lite mode**, I would expect to find:

```
.specs/add-shareable-links/
  PROMPT.md
  meta.json
  recon/
    architecture.md       # Stage 0: 3 Sonnet recon agents
    relevant_code.md
    conventions.md
  plans/
    draft_plan_1.md       # Stage 1: 1 Opus draft
    validation.md         # Stage 2: 1 Opus validation
    SPEC.md               # Stage 3: 1 Opus final spec
```

No red team reports (those only exist in full mode). No multiple drafts or evaluation rubric (those are full mode artifacts). The lite pipeline runs 4 stages with 6 agents total: 3 Sonnet recon, 1 Opus draft, 1 Opus validation, 1 Opus final spec.

### What meta.json would look like

```json
{
  "repo": "replay",
  "issue": 42,
  "slug": "add-shareable-links",
  "mode": "lite",
  "session": "replay_specs_add-shareable-links_claude",
  "created": "2026-03-04T14:22:00Z",
  "status": "review"
}
```

### What I would read

I would read all of the following files using the Read tool (in parallel where possible):

1. **SPEC.md** -- the primary artifact under review
2. **PROMPT.md** -- to understand the original issue requirements, Job Story, Promise, Constraints, and Acceptance Criteria
3. **meta.json** -- to confirm the mode (lite) and calibrate expectations
4. **recon/architecture.md** -- to understand what the recon agents found about the codebase structure
5. **recon/relevant_code.md** -- to understand which existing code the spec should reference
6. **recon/conventions.md** -- to verify the spec follows project patterns

I would also fetch the original GitHub issue to cross-reference:

```bash
gh issue view 42 --repo <org>/replay
```

---

## Step 2: Review the Spec

Below is the detailed evaluation across the three dimensions the skill requires. I am simulating plausible findings for a "shareable links" feature.

### What a "shareable links" feature likely involves

Based on the feature name and typical replay app context (a debugging/session replay tool), this feature probably enables:
- Generating unique, shareable URLs for replay sessions
- Access control (public vs. authenticated vs. token-gated links)
- Link expiration settings
- Embedding metadata in the link (timestamp, annotation focus)
- Analytics/tracking for shared links

### Completeness Review

**Architecture and file placement**: I would check whether the spec defines:
- Where the link generation logic lives (e.g., a new service module, or extension of an existing sharing module)
- Database model for storing share links (table name, columns, indexes)
- API route definitions (e.g., `POST /api/sessions/:id/share`, `GET /api/share/:token`)
- Frontend component placement (share button, share modal, link copy UX)

A plausible gap: The spec might define the API endpoints but not specify where the route handlers go within the existing folder structure. Recon should have caught this -- I would cross-reference against `recon/architecture.md`.

**Data model**: I would check for:
- A `share_links` table definition (id, session_id, token, created_by, expires_at, access_level, created_at)
- Migration strategy (does the spec mention creating a migration file?)
- Index on the token column for fast lookups
- Foreign key relationship to the sessions table

A plausible gap: The spec might not specify whether soft-delete is needed for revoked links, or how link revocation interacts with the data model.

**API contracts**: I would verify:
- Request/response shapes for creating a share link
- Request/response shapes for resolving a share link (when someone visits the URL)
- Error responses (expired link, revoked link, session not found, unauthorized)
- Rate limiting considerations for link creation

A plausible gap: The response shape for the resolution endpoint might be underspecified -- does it return the full session data, a redirect URL, or a session token?

**Edge cases**: Checking against the original issue's acceptance criteria:
- What happens when a link expires while someone is viewing the session?
- What if the original session is deleted after a link was shared?
- Can the creator of a link revoke it? How?
- What if a user generates multiple links for the same session?
- Maximum link count per session or per user?

**Testing strategy**: I would look for:
- Unit tests for link generation/validation logic
- Integration tests for the API endpoints
- Tests for expiration behavior
- Tests for access control enforcement
- Frontend component tests (if applicable)

A plausible finding: Lite mode specs sometimes have a testing section that says "test the main flows" without specifying exact test scenarios. This is acceptable for lite mode but worth noting.

**Acceptance criteria coverage**: I would map each acceptance criterion from the original issue to a section in the spec to ensure nothing was dropped.

### Feasibility Review

**Technical risks**: I would evaluate:
- Token generation strategy -- is it using crypto-safe random tokens? Is the token length sufficient to prevent brute-force?
- Whether the spec assumes any libraries or utilities that don't exist in the codebase
- If the spec proposes a new database table, whether the migration approach is compatible with the project's existing migration tooling (checked against `recon/conventions.md`)

A plausible concern: If the spec proposes using short UUIDs or nanoid for tokens, I would flag whether that library is already a dependency or needs to be added.

**Scope creep**: I would check whether the spec expanded beyond the original issue. For a "shareable links" feature, common scope creep includes:
- Adding full-blown permissions/roles system when the issue only asked for simple sharing
- Building an analytics dashboard for shared link usage when the issue only asked for link generation
- Adding social media preview/OG tag generation when not requested

**Performance implications**:
- The share link resolution endpoint will be public-facing and potentially high-traffic -- is caching mentioned?
- Database query patterns -- does the lookup use the indexed token column?
- If the spec proposes loading full session data on link resolution, is there concern about payload size?

**Dependency conflicts**: Does this spec assume any other issues have been implemented first? For instance, does it assume a sessions API that might still be in development?

### Alignment Review

**Job Story match**: I would read the original issue's Job Story (e.g., "When I find an interesting replay session, I want to share it with a colleague via a URL, so they can see exactly what I'm seeing without needing to navigate the app themselves") and verify the spec delivers on this specific need.

A plausible concern: The spec might have drifted toward building a general "collaboration" feature rather than the specific "share via URL" capability the Job Story describes.

**Promise fulfillment**: If the Promise is "After this ships, any user can generate a shareable URL for a replay session that works for recipients without an account," I would verify:
- The spec supports unauthenticated access to shared links
- The spec generates a URL (not just a token)
- The UX flow is complete from generation to consumption

**Constraint respect**: If the original issue had constraints like "No changes to the auth system" or "Must work with existing session permissions," I would verify the spec honors these.

**Red team findings**: Since this is lite mode, there are no red team reports. Instead, there is a validation report (`plans/validation.md`). I would read that to see what the validation agent flagged and whether those findings were incorporated into the final SPEC.md.

---

## Step 3: The Review

Below is the actual review output in the format the skill prescribes. This is what I would present to the user.

---

## Spec Review: Add Shareable Links

**Mode**: lite | **Issue**: #42 | **Status**: Ready (with minor notes)

### Verdict

The spec is solid and ready for implementation. It covers the core sharing workflow end-to-end -- link generation, resolution, access control, and expiration. The architecture is well-placed within the existing codebase structure, and the data model is clearly defined. There are two minor gaps (noted below) that are small enough to handle as implementation guidance rather than requiring a spec rewrite. The lite mode pipeline produced a spec proportional to the feature's complexity -- this did not need full mode.

### Completeness

- [x] Architecture and file placement defined -- new `ShareLinkService` in `src/services/`, route handlers in `src/routes/share.ts`, frontend modal in `src/components/ShareModal/`
- [x] Data model changes specified -- `share_links` table with token, session_id, created_by, expires_at, access_level columns; migration file referenced
- [ ] API contracts mostly complete -- `POST /api/sessions/:id/share` request/response defined, but the `GET /api/share/:token` resolution endpoint does not specify the response shape (redirect vs. inline session data vs. embed token)
- [x] Edge cases covered -- expiration, revocation, deleted sessions, duplicate links
- [x] Testing strategy present -- unit tests for token generation, integration tests for API endpoints, expiration behavior tests
- [ ] Missing detail: no mention of what happens to in-progress viewers when a link is revoked mid-session (minor -- can be handled at implementation time)

### Feasibility

- No blocking technical risks identified
- Token generation uses `crypto.randomBytes(32)` which is already available in Node.js -- no new dependencies needed
- Scope is proportional to the issue -- no gold-plating detected
- Database migration approach aligns with existing Knex migration patterns found in recon
- Note: The resolution endpoint could see high traffic if links are shared publicly. The spec mentions Redis caching for resolved links, which is appropriate. Verify Redis is available in the docker-compose setup for this service.

### Alignment

- Job Story: Addressed -- the spec delivers the "share via URL" workflow described in the issue
- Promise: The spec supports unauthenticated access for "public" links, fulfilling the promise that recipients don't need accounts
- Constraints: Respected -- no changes to the existing auth system; share links use a parallel token-based access path
- Validation report: The validation agent flagged that the spec didn't address rate limiting on link creation. The final SPEC.md added a rate limit of 10 links per session per user, which is reasonable.

### Action Items

1. **Clarify the resolution endpoint response** -- The `GET /api/share/:token` endpoint needs a defined response shape. Based on the existing session API patterns in `recon/relevant_code.md`, this should likely return a redirect to the session viewer with an embedded access token, rather than returning raw session data. The implementer should follow the existing pattern in `src/routes/sessions.ts`.
2. **Link revocation during active viewing** -- The spec handles revocation (DELETE endpoint, soft-delete on the record) but doesn't specify behavior for someone currently viewing a shared session when the link is revoked. Recommendation for the implementer: let the current viewing session continue but block new page loads/refreshes. This matches typical behavior in similar tools.

---

## Step 4: Decision

The spec is **ready to approve**. The two action items above are minor implementation details, not architectural gaps. They can be communicated to the implementer as guidance notes rather than requiring a spec revision.

Since the user explicitly said "don't implement anything yet," I would **not** proceed to Step 5 (implementation handoff). I would not run `acorn approve` either, since the user only asked for an assessment of readiness -- they didn't say "approve it."

Here is what I would say to the user:

> The spec looks good. It is ready to approve. There are two minor gaps -- the resolution endpoint response shape and link-revocation-during-viewing behavior -- but both are small enough to note for the implementer rather than re-speccing.
>
> When you're ready, approve it with:
> ```bash
> acorn approve replay add-shareable-links
> ```
>
> If you want me to kick off implementation after that, just say the word and I will create the worktree and hand off to an agent.

---

## Simulation Notes

### What the skill guided me to do vs. what a generic review would look like

The skill provided a structured, repeatable framework that ensured I:

1. **Read all supporting materials**, not just the SPEC.md. The PROMPT.md (original issue requirements) and recon reports are critical context that a generic review might skip.

2. **Calibrated to mode**. Because this was lite mode, I did not penalize the spec for lacking multiple draft perspectives or red team adversarial analysis. I checked the validation report instead. A generic review might not know about the different pipeline modes.

3. **Used the three-dimensional framework** (Completeness, Feasibility, Alignment) which ensures coverage of both technical and product concerns. A generic review might focus on one dimension and miss the others.

4. **Produced scannable output** with checkboxes, clear section headers, and specific action items. The format is designed so the user can quickly see "what's done, what's not, and what do I do next."

5. **Respected the user's intent**. The user said "don't implement anything yet," so I stopped at Step 4 and did not auto-approve or trigger implementation. The skill explicitly handles this: "Context determines automation level."

6. **Preserved traceability**. The review references the issue number, the spec slug, the pipeline mode, and specific file paths so the full chain from issue to spec to review is traceable.

### What the review would look like without the skill

Without the skill, a generic Claude response would likely:
- Read the SPEC.md and give a general "this looks good" or "here are some concerns"
- Miss the supporting materials (PROMPT.md, recon reports, meta.json)
- Not calibrate to the pipeline mode
- Not use a structured format with checkboxes
- Potentially offer to implement immediately without checking user intent
- Not provide the specific `acorn approve` command or handoff instructions
