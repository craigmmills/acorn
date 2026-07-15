# Acorn Phase 1 design — model dispatcher + panel + structured output

_Design for review. No code written yet._

## Goal

Establish the reusable primitive and single source of truth that the heterogeneous panel needs, and close the one structured-output gap, without yet touching the tmux/Task orchestration (that's Phase 2). Phase 1 is shippable on its own and de-risks Phase 2.

## The hard constraint that shapes this phase

The current pipeline runs as an **interactive Claude Code orchestrator launching Task sub-agents. The Task tool can only spawn Claude models** (fable/sonnet/opus/haiku). It cannot launch a Codex/GPT agent. So true cross-vendor heterogeneity (a `gpt-5.6-sol` drafter next to an Opus drafter) is **impossible until acorn orchestrates headlessly itself** — which is Phase 2.

Therefore Phase 1 splits the work honestly:

- **Buildable now:** the `run_agent` dispatcher (the primitive), the panel config as single source of truth, rerouting the existing headless call (split analysis) through it with structured output, and de-homogenizing the *Claude-tier* assignments the interactive pipeline already supports (recon → Fable instead of Opus).
- **Unlocked by Phase 2:** Codex/GPT drafters and red-teamers, because those require acorn to shell out to `codex exec` directly rather than begging a Claude orchestrator to do it.

This is why Phase 1 is worth doing first: it builds and tests the exact dispatcher Phase 2 will orchestrate with, so Phase 2 becomes "wire the pipeline through a proven primitive" rather than a big-bang rewrite.

---

## 1. `run_agent` — the dispatcher

Single function; the only place in acorn that knows how to call a model.

```
run_agent <model> <out_file> [--format text|json] [--schema <file>] [--cwd <dir>]
# prompt is read from stdin
# returns 0 on success (final answer written to out_file), non-zero on failure
```

### Routing (by model name)
| Model name pattern | Backend | Invocation |
|---|---|---|
| `fable`, `sonnet`, `opus`, `haiku`, `claude-*` | Claude | `claude -p --model <m>` |
| `gpt-*`, `codex`, `codex-*`, `spark` | Codex | `codex exec -m <m> --skip-git-repo-check -a never -s read-only` |

`spark` is expanded to `gpt-5.3-codex-spark` (matches the plugin's alias map).

### Output handling
- `--format text` (default, for markdown generation like recon/drafts/spec):
  - Claude: `claude -p --model <m>` → raw stdout → `out_file`
  - Codex: `codex exec … -o <out_file>` (writes final message only; no JSONL parsing)
- `--format json [--schema <file>]` (for split analysis and any structured stage):
  - Claude: `claude -p --model <m> --output-format json` → `jq -r '.result'` → then validate the inner JSON with `jq -e` against required keys (Claude can't hard-constrain, so instruct-and-validate; the prompt gets the schema appended)
  - Codex: `codex exec … --output-schema <file> -o <out_file>` (hard-constrained JSON — strictly better than Claude here)

### Graceful degradation
Detect Codex once (`command -v codex` + a cached `codex login status` check). If a Codex model is requested but Codex is unavailable/unauthed:
- default: `warn` and substitute the configured Claude fallback (`ACORN_CODEX_FALLBACK`, default `opus`), so a machine without Codex still runs a Claude-only panel;
- `ACORN_STRICT_PANEL=1`: `die` instead, for CI where the panel must be exact.

### Prompt dialects
The plugin's `gpt-5-4-prompting` skill says Codex wants compact, XML-tagged operator prompts; Claude wants prose. `run_agent` stays dumb (passes the prompt through). Where a stage's prompt is vendor-sensitive (drafters, red team), the caller supplies a family-appropriate variant — kept in the panel/prompt tables, not hardcoded in prose. For the single split-analysis prompt, one well-formed prompt works for both.

---

## 2. Panel config — single source of truth

One associative array replaces the ~12 `Use model "opus"` strings frozen across the planning blocks.

```bash
declare -A ACORN_PANEL=(
  # full pipeline
  [full:recon]=fable            # was opus — recon is bulk scanning, Fable's lane
  [full:draft:minimal]=gpt-5.6-sol      # (Phase 2) surgical precision
  [full:draft:architecture]=opus
  [full:draft:robustness]=sonnet
  [full:draft:dx]=fable
  [full:evaluate]=opus
  [full:synthesize]=opus
  [full:redteam:1]=gpt-5.6-sol          # (Phase 2) cross-vendor adversary
  [full:redteam:2]=opus
  [full:redteam:3]=sonnet
  [full:redteam:4]=fable
  [full:spec]=opus
  # lite / quick
  [lite:recon]=fable   [lite:draft]=opus   [lite:validate]=sonnet   [lite:spec]=opus
  [quick:recon]=fable  [quick:spec]=opus
  # headless helpers
  [split]=sonnet
)
```

- Accessor `panel_model <key>` returns the model, applying (a) env override `ACORN_PANEL_<KEY>` (e.g. `ACORN_PANEL_full_recon=haiku`), then (b) an optional `~/.config/acorn/panel.env` file, then (c) codex-availability degradation.
- **In Phase 1**, only keys the interactive pipeline can honor (the Claude-tier ones) are wired into planning-block prose via interpolation (replacing hardcoded `Use model "opus"`). The `gpt-*` keys sit in the table, documented as "Phase 2 (headless) only", and degrade to their Claude fallback if referenced early.

---

## 3. Reroute split analysis through `run_agent` (closes audit bug #5)

`analyze_issue_for_split` becomes:
```
printf '%s' "$full_prompt" | run_agent "$(panel_model split)" "$out" --format json --schema "$SPLIT_SCHEMA"
```
Deletes the 3-tier fence-scraper (raw jq / ```json / generic fence). On Codex the `--output-schema` constraint makes malformed output nearly impossible; on Claude the envelope + key validation replaces the guesswork. `--model` override still flows through.

---

## 4. Tests (the seam with zero coverage today)

New `test/test_run_agent.sh`:
- Stub `claude` and `codex` as shell functions; assert `run_agent` calls the right binary with the right `-m`/`--model` and the right flags per `--format`.
- Assert JSON path extracts `.result` (Claude) and validates against schema.
- Assert degradation: Codex model + `codex` absent → Claude fallback (and → `die` under `ACORN_STRICT_PANEL=1`).
- Assert `panel_model` honors env override → config file → default precedence.

Update `test/test_split.sh` stubs to the `run_agent`/`--output-format json` shape. Label/deps/images suites untouched.

---

## Deliverables & sequence
1. `run_agent` + `panel_model` + `ACORN_PANEL` table + codex detection (new ~90 lines).
2. Reroute `analyze_issue_for_split`; delete the scraper.
3. Interpolate Claude-tier panel models into planning-block prose (recon → Fable etc.), replacing the 12 hardcoded strings — the achievable homogeneity fix.
4. `test/test_run_agent.sh` + split-test stub update.
5. README/command-doc: document the panel, the `fable/sonnet/opus/gpt-*` model surface, `ACORN_PANEL_*` overrides, and the Codex dependency (optional, degrades gracefully).

## Locked decisions (2026-07-15)
- **Codex = soft dependency.** Degrade to Claude fallback (`ACORN_CODEX_FALLBACK`, default `opus`) with a `warn`; `ACORN_STRICT_PANEL=1` turns degradation into `die` for CI. acorn stays runnable on machines without Codex.
- **Recon tier = Fable 5** across full/lite/quick (was Opus in full mode). Bulk codebase scanning is Fable's lane.
- **Edit planning-block prose now.** Interpolate the Claude-tier panel models into the planning blocks in Phase 1 (recon → Fable, etc.), replacing the ~12 hardcoded `Use model "opus"` strings. Accepts editing that prose twice (Phase 2 restructures it) in exchange for the recon savings landing now.

## Build order (locked)
1. `run_agent` + `panel_model` + `ACORN_PANEL` table + one-time Codex detection + soft-degrade logic.
2. Reroute `analyze_issue_for_split` through `run_agent --format json --schema`; delete the 3-tier scraper.
3. Interpolate Claude-tier panel models into `planning_block_{full,lite,quick}` prose (recon → Fable; keep evaluate/synthesize/spec on Opus; drafters/red-team Claude tiers as tabled). Leave `gpt-*` entries dormant, labeled Phase-2-only, degrading to fallback if referenced.
4. `test/test_run_agent.sh` (dispatch/format/degrade/precedence) + update `test/test_split.sh` stubs.
5. Docs: panel table, model surface (`fable/sonnet/opus/haiku/gpt-*`), `ACORN_PANEL_*` overrides, optional Codex dependency.
