# Drift Dimensions — what audit mode checks

v1 covers **3 dimensions deterministically** + **2 intent-change signals**. Each dimension is a self-contained check; adding dimensions is additive (write a new entry, reference it in `audit.md` Step 3).

## Dimension 1: Hook integrity

**Input:** `config.installed.hooks[]` (list of `{path, sha256}` pairs recorded at kickoff).

**Probe:** `audit_probe.sh` emits `hooks_present[]` with current sha256 for each file under `.claude/hooks/`.

**Checks:**

| Condition | Severity | Title |
|---|---|---|
| File listed in config but missing on disk | `BREACH` | Hook file deleted |
| File present, sha256 mismatch with config | `DRIFT` | Hook file modified outside kickoff |
| File on disk not in config | `DRIFT` | Unrecorded hook file added |

**Suggested fix:**
- Missing → *"Re-install from template (kickoff idempotent write)."*
- Modified → *"Review diff, then either `absorb` (update config hash) or `revert` (reinstall template)."*
- Unrecorded → *"Add to config.installed.hooks and ratify hash."*

## Dimension 2: Threat model coverage

**Input:** `config.intent.threat_model.sources[]`.

**Probe:** `recent_tool_usage[]` from `audit_probe.sh` — best-effort grep of recent session transcripts for tool names. If transcripts not accessible, fall back to static grep of project source for external-fetch patterns:

```
grep -rE "(WebFetch|urllib|requests\.get|fetch\(|axios\.|http\.Get|httpClient\.)" --include="*.{py,ts,tsx,js,jsx,go,rs,rb,java,kt,swift}" .
```

**Checks:**

| Condition | Severity | Title |
|---|---|---|
| `sources` = `["none"]` but external-fetch patterns found | `DRIFT` | Unexpected external fetch in codebase |
| `sources` excludes `tool-outputs` but `WebFetch`/`curl` called in recent sessions | `DRIFT` | Tool output ingest not modeled in threat profile |
| Current tier = `minimal` and any of the above fires | `DRIFT` | Threat model understates tier; upgrade recommended |

**Suggested fix:**
- *"Re-run threat model questions (Q5–Q7) and recompute tier. Upgrading `minimal` → `standard` adds the PostToolUse injection-scan hook."*

## Dimension 3: Secret exposure

**Input:** (none — check reality every time).

**Probe:** `audit_probe.sh` emits `secret_scan.findings[]`, each `{path, tracked}`. It prefers `gitleaks detect --no-git --redact` if installed, else a regex fallback. The regex set is shared with `hook-pretool-secret-scan.py` (AWS, GitHub classic + fine-grained PAT, Anthropic, OpenAI, Slack, Google, private-key blocks). Use the emitted `tracked` flag — do NOT re-scan here.

**Checks (drive the BREACH/DRIFT split off the `tracked` flag):**

| Condition | Severity | Title |
|---|---|---|
| Any finding with `tracked: true` | `BREACH` | Secret detected in git-tracked file |
| Findings exist but all `tracked: false` (untracked / gitignored, e.g. local `.env`) | `DRIFT` | Secret in untracked file — rotate if it ever leaked |
| No findings | `OK` | Secret scan clean |

**Suggested fix:**
- BREACH → *"Rotate the exposed credential immediately. Remove from git history (`git filter-repo` or BFG). Add to `.gitignore` if appropriate."*

## Intent-change signal 1: Stack shift

**Check:** compare `config.intent.stack.primary_language` (recorded at kickoff) with current probe `stack.primary_language`.

| Condition | Severity | Title |
|---|---|---|
| Mismatch | `INTENT-CHANGE` | Primary language shifted from X to Y |
| Added language (was mono, now multi) | `INTENT-CHANGE` | Additional primary language adopted |

**Suggested action:** *"Re-interview stack questions. Existing installs remain; recomputed plan is offered on confirm."*

## Intent-change signal 2: Kind shift

**Check:** heuristic signals vs recorded `config.intent.kind`:

- Was `library`, now has `api/`, `server.ts`, `manage.py runserver`, `FastAPI()`, or a Dockerfile exposing a port → now `service`.
- Was `cli`, now has a frontend framework (`next.config`, `vite.config`, `angular.json`) → now `app`.
- Was `service`, now has LLM SDK imports (`anthropic`, `openai`, `langchain`, `llamaindex`) + autonomous loop patterns → now `agent`.

| Condition | Severity | Title |
|---|---|---|
| Detected kind differs from config | `INTENT-CHANGE` | Project kind appears to have shifted |

**Suggested action:** *"Re-interview Q2 (kind). If confirmed, tier may upgrade; new installs will be offered."*

---

## Dimensions deferred to v1.5+

Listed here so future contributors know where to add.

- **Permissions drift** — diff `settings.json` permissions against recorded kickoff baseline; flag widened allowlists.
- **CLAUDE.md section drift** — hash each markered section at kickoff; flag modifications.
- **Dep advisories** — run `{npm,pnpm,yarn} audit` / `pip-audit` / `cargo audit`; any `high`/`critical` → DRIFT.
- **Convention adherence** — for last N commits, % matching declared commit style.
- **Testing posture** — coverage delta from declared baseline; tests-per-feature ratio.
- **Inactivity** — last commit older than 90 days; drift toward abandonment.

## Adding a new dimension (recipe)

1. Append a section to this file with the same `Input / Probe / Checks / Suggested fix` format.
2. Add the probe logic to `scripts/audit_probe.sh` (emit under a new JSON key).
3. Reference the new dimension in `audit.md` Step 3.
4. Bump `schema_version` in `project-config.json` if the new dimension needs new config fields; handle migration in kickoff.
